"""Firestore writes via the Firebase Admin SDK.

The Admin SDK uses a service-account credential and bypasses security rules, so
this trusted backend can write scores that the client rules forbid. Everything
is scoped under the shared-database-safe path: match-chat/app/...
"""

from __future__ import annotations

import logging

import firebase_admin
from firebase_admin import credentials, firestore

import scoring

log = logging.getLogger("poller.firestore")


class FirestoreSync:
    def __init__(self, config) -> None:
        self.cfg = config
        cred = credentials.Certificate(config.service_account)
        firebase_admin.initialize_app(cred)
        self.db = firestore.client()

    def _tournament_ref(self):
        return (
            self.db.collection("match-chat")
            .document("app")
            .collection("tournaments")
            .document(self.cfg.tournament_id)
        )

    def _matches_col(self):
        return self._tournament_ref().collection("matches")

    def ensure_tournament(self) -> None:
        ref = (
            self.db.collection("match-chat")
            .document("app")
            .collection("tournaments")
            .document(self.cfg.tournament_id)
        )
        ref.set(
            {
                "name": self.cfg.tournament_name,
                "sport": "soccer",
                "isDefault": True,
                "order": 0,
            },
            merge=True,
        )

    def upsert_matches(self, docs: list) -> int:
        """Merge-write a batch of match docs, keyed by API fixture id.

        Merge means the app's own commentCount/predictionCount/archived fields
        are left untouched. Returns the number written.
        """
        if not docs:
            return 0
        batch = self.db.batch()
        col = self._matches_col()
        for doc in docs:
            ref = col.document(str(doc["apiFixtureId"]))
            batch.set(ref, doc, merge=True)
        batch.commit()
        return len(docs)

    def update_score(self, doc: dict) -> None:
        """Merge-write a single match's live score/status."""
        ref = self._matches_col().document(str(doc["apiFixtureId"]))
        ref.set(doc, merge=True)

    def recompute_standings(self) -> int:
        """Recompute the prediction leaderboard from finished matches and their
        predictions, and write it to tournaments/{tid}/standings/current so the
        app reads a precomputed standing instead of doing it client-side (#8).

        Mirrors lib/services/leaderboard_service.dart: 5/3/1 scoring, sorted by
        points then exact hits then name, with dense (equal points share a rank)
        ranking. Returns the number of ranked players.
        """
        col = self._matches_col()
        acc: dict = {}
        counted = 0
        # The schedule is ~100 matches, so a single full read + Python-side
        # filter is cheaper than maintaining a status index.
        for mdoc in col.stream():
            m = mdoc.to_dict() or {}
            if m.get("status") != "finished":
                continue
            score_a, score_b = m.get("scoreA"), m.get("scoreB")
            if score_a is None or score_b is None:
                continue
            counted += 1
            for pdoc in col.document(mdoc.id).collection("predictions").stream():
                p = pdoc.to_dict() or {}
                uid = p.get("userId") or pdoc.id
                pa, pb = p.get("scoreA"), p.get("scoreB")
                if pa is None or pb is None:
                    continue
                pts = scoring.points(pa, pb, score_a, score_b)
                a = acc.setdefault(
                    uid,
                    {
                        "userId": uid,
                        "displayName": "",
                        "favoriteTeam": None,
                        "points": 0,
                        "exact": 0,
                        "scored": 0,
                    },
                )
                a["points"] += pts
                a["scored"] += 1
                if pts == scoring.EXACT_POINTS:
                    a["exact"] += 1
                if p.get("displayName"):
                    a["displayName"] = p["displayName"]
                if p.get("favoriteTeam"):
                    a["favoriteTeam"] = p["favoriteTeam"]

        entries = sorted(
            acc.values(),
            key=lambda e: (-e["points"], -e["exact"], e["displayName"].lower()),
        )
        rank = 0
        prev = None
        for i, e in enumerate(entries):
            if prev is None or e["points"] != prev:
                rank = i + 1
                prev = e["points"]
            e["rank"] = rank

        self._tournament_ref().collection("standings").document("current").set(
            {
                "entries": entries,
                "matchesCounted": counted,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            }
        )
        return len(entries)

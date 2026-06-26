"""Firestore writes via the Firebase Admin SDK.

The Admin SDK uses a service-account credential and bypasses security rules, so
this trusted backend can write scores that the client rules forbid. Everything
is scoped under the shared-database-safe path: match-chat/app/...
"""

from __future__ import annotations

import logging

import firebase_admin
from firebase_admin import credentials, firestore

log = logging.getLogger("poller.firestore")


class FirestoreSync:
    def __init__(self, config) -> None:
        self.cfg = config
        cred = credentials.Certificate(config.service_account)
        firebase_admin.initialize_app(cred)
        self.db = firestore.client()

    def _matches_col(self):
        return (
            self.db.collection("match-chat")
            .document("app")
            .collection("tournaments")
            .document(self.cfg.tournament_id)
            .collection("matches")
        )

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

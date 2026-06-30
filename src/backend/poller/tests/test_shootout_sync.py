import os
import tempfile
import unittest

from cache import Cache
from mapping import to_match_doc, to_shootout
from poller import _shootout_is_complete, _write_live


class _Budget:
    exhausted = False


class _Api:
    def __init__(self, responses):
        self.budget = _Budget()
        self.responses = list(responses)
        self.event_calls = 0

    def events(self, fixture_id):
        self.event_calls += 1
        return self.responses.pop(0)


class _Firestore:
    def __init__(self):
        self.writes = []

    def update_score(self, doc):
        self.writes.append(doc)


def _fixture(short="P", penalty_a=0, penalty_b=0):
    return {
        "fixture": {
            "id": 456,
            "date": "2026-06-29T18:00:00+00:00",
            "status": {"short": short},
            "venue": {},
        },
        "league": {"round": "Round of 32"},
        "teams": {
            "home": {"id": 10, "name": "Home"},
            "away": {"id": 20, "name": "Away"},
        },
        "goals": {"home": 1, "away": 1},
        "score": {"penalty": {"home": penalty_a, "away": penalty_b}},
    }


def _kick(team_id, player, scored, round_number):
    return {
        "type": "Goal",
        "detail": "Penalty" if scored else "Missed Penalty",
        "comments": "Penalty Shootout",
        "team": {"id": team_id},
        "player": {"name": player},
        "time": {"elapsed": 120, "extra": round_number},
    }


class ShootoutSyncTests(unittest.TestCase):
    def setUp(self):
        handle, self.path = tempfile.mkstemp()
        os.close(handle)
        os.unlink(self.path)
        self.cache = Cache(self.path)
        self.cache.set(456, "live", 1, 1, goals_recorded=True)

    def tearDown(self):
        for path in (self.path, f"{self.path}.tmp"):
            if os.path.exists(path):
                os.unlink(path)

    def test_schedule_mapping_keeps_shootout_separate_from_match_score(self):
        doc = to_match_doc(_fixture("PEN", 4, 3), {})

        self.assertEqual((doc["scoreA"], doc["scoreB"]), (1, 1))
        self.assertEqual(doc["shootout"]["scoreA"], 4)
        self.assertEqual(doc["shootout"]["scoreB"], 3)
        self.assertEqual(doc["shootout"]["state"], "finished")
        self.assertNotIn("attempts", doc["shootout"])

    def test_parser_preserves_api_kick_order_and_misses(self):
        events = [
            _kick(10, "Home one", True, 1),
            _kick(20, "Away one", False, 1),
        ]
        result = to_shootout(_fixture("P", 1, 0), events)

        self.assertEqual([a["sequence"] for a in result["attempts"]], [0, 1])
        self.assertEqual([a["team"] for a in result["attempts"]], ["A", "B"])
        self.assertEqual([a["scored"] for a in result["attempts"]], [True, False])

    def test_miss_is_written_even_when_penalty_tally_does_not_change(self):
        first = [_kick(10, "Home one", True, 1)]
        with_miss = first + [_kick(20, "Away one", False, 1)]
        api = _Api([first, with_miss])
        fs = _Firestore()

        self.assertTrue(_write_live(api, fs, self.cache, _fixture("P", 1, 0)))
        self.assertTrue(_write_live(api, fs, self.cache, _fixture("P", 1, 0)))

        self.assertEqual(api.event_calls, 2)
        self.assertEqual(len(fs.writes), 2)
        self.assertEqual(len(fs.writes[-1]["shootout"]["attempts"]), 2)
        self.assertFalse(fs.writes[-1]["shootout"]["attempts"][-1]["scored"])

    def test_unchanged_live_attempts_do_not_rewrite_firestore(self):
        events = [_kick(10, "Home one", True, 1)]
        api = _Api([events, events])
        fs = _Firestore()

        self.assertTrue(_write_live(api, fs, self.cache, _fixture("P", 1, 0)))
        self.assertFalse(_write_live(api, fs, self.cache, _fixture("P", 1, 0)))
        self.assertEqual(api.event_calls, 2)
        self.assertEqual(len(fs.writes), 1)

    def test_decisive_final_sequence_is_marked_complete(self):
        # Home wins 4-2 after four kicks each; Away's fifth cannot catch up.
        outcomes = [
            (10, True),
            (20, True),
            (10, True),
            (20, False),
            (10, True),
            (20, True),
            (10, True),
            (20, False),
        ]
        events = [
            _kick(team, f"Player {i}", scored, i // 2 + 1)
            for i, (team, scored) in enumerate(outcomes)
        ]
        shootout = to_shootout(_fixture("PEN", 4, 2), events)

        self.assertTrue(_shootout_is_complete(shootout))

        api = _Api([events])
        fs = _Firestore()
        self.assertTrue(_write_live(api, fs, self.cache, _fixture("PEN", 4, 2)))
        self.assertTrue(self.cache.shootout_recorded(456))


if __name__ == "__main__":
    unittest.main()

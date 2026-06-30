import os
import tempfile
import unittest

from cache import Cache
from poller import _write_live


class _Budget:
    exhausted = False


class _Api:
    def __init__(self, events):
        self.budget = _Budget()
        self._events = list(events)
        self.event_calls = 0

    def events(self, fixture_id):
        self.event_calls += 1
        return self._events.pop(0)


class _Firestore:
    def __init__(self):
        self.writes = []

    def update_score(self, doc):
        self.writes.append(doc)


def _fixture(home, away):
    return {
        "fixture": {"id": 123, "status": {"short": "2H"}},
        "teams": {"home": {"id": 10}, "away": {"id": 20}},
        "goals": {"home": home, "away": away},
    }


def _goal(team_id, player, minute):
    return {
        "type": "Goal",
        "detail": "Normal Goal",
        "team": {"id": team_id},
        "player": {"name": player},
        "time": {"elapsed": minute, "extra": None},
    }


class GoalSyncTests(unittest.TestCase):
    def setUp(self):
        handle, self.path = tempfile.mkstemp()
        os.close(handle)
        os.unlink(self.path)
        self.cache = Cache(self.path)

    def tearDown(self):
        for path in (self.path, f"{self.path}.tmp"):
            if os.path.exists(path):
                os.unlink(path)

    def test_daily_sync_clears_goal_flag_when_score_advanced_offline(self):
        self.cache.set(123, "live", 0, 1, goals_recorded=True)

        # daily_sync calls set without an explicit goals_recorded value.
        self.cache.set(123, "live", 1, 1)

        self.assertFalse(self.cache.goals_recorded(123))

        events = [_goal(20, "Away scorer", 29), _goal(10, "Home scorer", 71)]
        api = _Api([events])
        fs = _Firestore()

        self.assertTrue(_write_live(api, fs, self.cache, _fixture(1, 1)))
        self.assertEqual(api.event_calls, 1)
        self.assertEqual(len(fs.writes[0]["goals"]), 2)
        self.assertTrue(self.cache.goals_recorded(123))

    def test_daily_sync_preserves_goal_flag_for_status_only_change(self):
        self.cache.set(123, "live", 2, 1, goals_recorded=True)

        self.cache.set(123, "finished", 2, 1)

        self.assertTrue(self.cache.goals_recorded(123))

    def test_partial_event_list_is_retried_until_complete(self):
        self.cache.set(123, "live", 0, 1, goals_recorded=True)
        self.cache.set(123, "live", 1, 1)
        partial = [_goal(20, "Away scorer", 29)]
        complete = partial + [_goal(10, "Home scorer", 71)]
        api = _Api([partial, complete])
        fs = _Firestore()

        self.assertFalse(_write_live(api, fs, self.cache, _fixture(1, 1)))
        self.assertFalse(self.cache.goals_recorded(123))
        self.assertEqual(fs.writes, [])

        self.assertTrue(_write_live(api, fs, self.cache, _fixture(1, 1)))
        self.assertEqual(api.event_calls, 2)
        self.assertEqual(len(fs.writes[0]["goals"]), 2)
        self.assertTrue(self.cache.goals_recorded(123))

    def test_live_score_change_with_partial_events_marks_backfill_pending(self):
        self.cache.set(123, "live", 0, 1, goals_recorded=True)
        partial = [_goal(20, "Away scorer", 29)]
        api = _Api([partial])
        fs = _Firestore()

        self.assertTrue(_write_live(api, fs, self.cache, _fixture(1, 1)))

        self.assertEqual(fs.writes[0]["scoreA"], 1)
        self.assertNotIn("goals", fs.writes[0])
        self.assertFalse(self.cache.goals_recorded(123))

    def test_score_correction_to_zero_clears_stale_goals(self):
        self.cache.set(123, "live", 1, 0, goals_recorded=True)
        api = _Api([])
        fs = _Firestore()

        self.assertTrue(_write_live(api, fs, self.cache, _fixture(0, 0)))
        self.assertEqual(api.event_calls, 0)
        self.assertEqual(fs.writes[0]["goals"], [])
        self.assertTrue(self.cache.goals_recorded(123))


if __name__ == "__main__":
    unittest.main()

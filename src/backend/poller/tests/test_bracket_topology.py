import unittest

from bracket_topology import bracket_metadata, world_cup_2026_metadata
from mapping import to_match_doc


def _fixture(round_name, city, date="2026-06-29T20:30:00+00:00"):
    return {
        "fixture": {
            "id": 123,
            "date": date,
            "status": {"short": "NS"},
            "venue": {"name": "Stadium", "city": city},
        },
        "league": {"round": round_name},
        "teams": {
            "home": {"id": 1, "name": "Home"},
            "away": {"id": 2, "name": "Away"},
        },
        "goals": {"home": None, "away": None},
        "score": {},
    }


class WorldCup2026BracketTopologyTests(unittest.TestCase):
    def test_round_of_32_uses_fifa_bracket_order(self):
        cases = {
            "Boston": (74, 0),
            "New-York": (77, 1),
            "Inglewood": (73, 2),
            "Monterrey": (75, 3),
            "Toronto": (83, 4),
            "Los Angeles": (84, 5),
            "San-Francisco": (81, 6),
            "Seattle": (82, 7),
            "Houston": (76, 8),
            "Mexico City": (79, 10),
            "Atlanta": (80, 11),
            "Miami": (86, 12),
            "Vancouver": (85, 14),
            "Kansas City": (87, 15),
        }
        for city, (match_number, slot) in cases.items():
            with self.subTest(city=city):
                metadata = world_cup_2026_metadata(
                    _fixture("Round of 32", city)
                )
                self.assertEqual(metadata["matchNumber"], match_number)
                self.assertEqual(metadata["roundIndex"], 1)
                self.assertEqual(metadata["bracketSlot"], slot)

    def test_dallas_round_of_32_matches_are_disambiguated_by_date(self):
        m78 = world_cup_2026_metadata(
            _fixture("Round of 32", "Dallas", "2026-06-30T17:00:00+00:00")
        )
        m88 = world_cup_2026_metadata(
            _fixture("Round of 32", "Dallas", "2026-07-03T18:00:00+00:00")
        )
        self.assertEqual((m78["matchNumber"], m78["bracketSlot"]), (78, 9))
        self.assertEqual((m88["matchNumber"], m88["bracketSlot"]), (88, 13))

    def test_round_of_16_order_preserves_quarter_final_branches(self):
        cases = {
            "Philadelphia": (89, 0),
            "Houston": (90, 1),
            "Dallas": (93, 2),
            "Seattle": (94, 3),
            "New-York": (91, 4),
            "Mexico City": (92, 5),
            "Atlanta": (95, 6),
            "Vancouver": (96, 7),
        }
        for city, (match_number, slot) in cases.items():
            with self.subTest(city=city):
                metadata = world_cup_2026_metadata(
                    _fixture("Round of 16", city)
                )
                self.assertEqual(metadata["matchNumber"], match_number)
                self.assertEqual(metadata["roundIndex"], 2)
                self.assertEqual(metadata["bracketSlot"], slot)

    def test_third_place_has_a_match_number_but_no_main_bracket_slot(self):
        metadata = world_cup_2026_metadata(
            _fixture("3rd Place Final", "Miami")
        )
        self.assertEqual(metadata, {"matchNumber": 103})

    def test_remaining_rounds_follow_the_published_main_bracket(self):
        cases = [
            ("Quarter-finals", "Boston", 97, 3, 0),
            ("Quarter-finals", "Los Angeles", 98, 3, 1),
            ("Quarter-finals", "Miami", 99, 3, 2),
            ("Quarter-finals", "Kansas City", 100, 3, 3),
            ("Semi-finals", "Dallas", 101, 4, 0),
            ("Semi-finals", "Atlanta", 102, 4, 1),
            ("Final", "New-York", 104, 5, 0),
        ]
        for round_name, city, match_number, round_index, slot in cases:
            with self.subTest(match_number=match_number):
                metadata = world_cup_2026_metadata(_fixture(round_name, city))
                self.assertEqual(
                    metadata,
                    {
                        "matchNumber": match_number,
                        "roundIndex": round_index,
                        "bracketSlot": slot,
                    },
                )

    def test_unknown_fixture_and_other_tournaments_fail_closed(self):
        fixture = _fixture("Round of 32", "Unknown City")
        self.assertEqual(world_cup_2026_metadata(fixture), {})
        self.assertEqual(bracket_metadata("another-cup", fixture), {})

    def test_match_document_is_annotated_during_world_cup_sync(self):
        doc = to_match_doc(
            _fixture("Round of 16", "Houston"),
            {},
            "world-cup-2026",
        )
        self.assertEqual(doc["matchNumber"], 90)
        self.assertEqual(doc["roundIndex"], 2)
        self.assertEqual(doc["bracketSlot"], 1)

    def test_unrecognized_world_cup_fixture_clears_stale_topology(self):
        doc = to_match_doc(
            _fixture("Round of 16", "Unknown City"),
            {},
            "world-cup-2026",
        )
        self.assertIsNone(doc["matchNumber"])
        self.assertIsNone(doc["roundIndex"])
        self.assertIsNone(doc["bracketSlot"])


if __name__ == "__main__":
    unittest.main()

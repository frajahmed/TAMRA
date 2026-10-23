from django.test import SimpleTestCase

from profiles.calculations import (
    basal_metabolic_rate,
    daily_calorie_target,
    macro_targets,
    round_half_up,
)


class CalculationTests(SimpleTestCase):
    """Same cases as app/test/core/nutrition_test.dart – app and server must agree."""

    def test_bmr(self):
        self.assertAlmostEqual(basal_metabolic_rate("female", 70, 170, 30), 1451.5)
        self.assertAlmostEqual(basal_metabolic_rate("male", 70, 170, 30), 1617.5)

    def test_targets_match_app(self):
        self.assertEqual(daily_calorie_target("female", 70, 170, 30, "sedentary", "maintain"), 1742)
        self.assertEqual(daily_calorie_target("male", 80, 180, 40, "moderate", "lose"), 2182)
        self.assertEqual(daily_calorie_target("female", 70, 170, 30, "sedentary", "lose"), 1452)
        self.assertEqual(daily_calorie_target("female", 70, 170, 30, "light", "gain"), 2296)

    def test_safe_minimum(self):
        # very small, old, inactive person who wants to lose weight
        self.assertGreaterEqual(
            daily_calorie_target("female", 40, 145, 90, "sedentary", "lose"), 1200
        )
        self.assertGreaterEqual(
            daily_calorie_target("male", 45, 150, 90, "sedentary", "lose"), 1500
        )

    def test_macros(self):
        self.assertEqual(macro_targets(2000), {"protein_g": 150, "carbs_g": 200, "fat_g": 67})

    def test_round_half_up(self):
        self.assertEqual(round_half_up(2181.5), 2182)
        self.assertEqual(round_half_up(1451.49), 1451)

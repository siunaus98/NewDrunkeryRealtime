"""Rebuild only the dishes changed by the center -> west -> east menu pass."""
from generate_cohesive_art import ingredients, dishes

CHANGED = {
    "drink_double_ferment", "drink_sunwheel_infusion",
    "dish_white_plate", "dish_sand_potato_plate", "dish_fowl_sand_roll",
    "dish_red_double_roast", "dish_dill_sand_potato_cup", "dish_dill_fowl_pot",
    "dish_qingmei_sweet_bowl", "dish_qingmei_seared_cup",
    "dish_sandworm_royal_heat_plate", "dish_scorpion_sunplate",
}

if __name__ == "__main__":
    dishes(ingredients(write=False), only_names=CHANGED)
    print(f"Updated {len(CHANGED)} dish icons and their world/plated variants.")

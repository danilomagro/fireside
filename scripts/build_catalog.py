"""Build Harvested.lua, the generated half of the Fireside catalog.

Sources, in order of trust:
  1. an in-game harvest: the "harvest" table Fireside writes to its
     SavedVariables in debug mode (/fire log on, then open a profession window);
  2. scripts/wowhead_camp_objects.json, collected from the Wowhead Forever
     database: every camping object, its recipe, skill and reagents.

Live data wins where both know a recipe: the client is the ground truth.

Usage:
    python scripts/build_catalog.py
    python scripts/build_catalog.py --harvest "<WoW>/_classic_beta_/WTF/Account/<id>/SavedVariables/Fireside.lua"
"""

import argparse
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SOURCE = REPO / "scripts" / "wowhead_camp_objects.json"
OUT = REPO / "Harvested.lua"

# Wowhead item id -> catalog key in Data.lua.
ITEM_TO_KEY = {
    279960: "lodestone", 279948: "rock_garden", 279952: "molten_foundry",
    279944: "sharpening_wheel", 279988: "anvil", 279955: "master_forge",
    279956: "mana_well", 279970: "fermenter",
    279972: "faction_banner", 279973: "faction_banner", 279943: "spinning_wheel", 279959: "loom",
    279978: "camp_tent", 279941: "tanning_rack", 279945: "sewing_machine",
    279962: "incense_candle", 279964: "greenhouse", 279947: "seed_hybridizer",
    279979: "camp_chair", 279969: "field_guide", 279938: "trappers_workbench",
    279976: "enchanted_lute", 279985: "arcane_salvager", 279987: "arcane_forge",
    279950: "reagent_bot", 279949: "repair_bot", 279989: "anarchists_workbench",
    279968: "first_aid_kit", 279940: "toxin_study", 279951: "plague_doctors_laboratory",
    279967: "fish_bowl", 279965: "fishing_rack", 279966: "fishing_hut",
    279981: "basic_campfire", 279961: "journeyman_campfire", 279974: "expert_campfire",
    279957: "cookies_feast", 279982: "iron_oven",
}

# Recipe names an in-game harvest reports -> catalog key, for the few that
# differ from the item name.
RECIPE_ALIASES = {
    "basic campfire": "basic_campfire",
    "journeyman campfire": "journeyman_campfire",
    "expert campfire": "expert_campfire",
}


def readable_effect(text):
    """Turn Wowhead's scaling lists into ranges and drop what the UI shows apart."""
    if not text:
        return None

    def span(match):
        values = re.findall(r"\[([^\]]*)\]", match.group(0))
        return values[0] if len(values) == 1 else f"{values[0]}-{values[-1]}"

    text = re.sub(r"(?:\[[0-9.%]+\])+", span, text)
    text = re.sub(r",? mutually exclusive with [^.]+\.?", ".", text)
    text = re.sub(r"\s*\(\d+ Min Cooldown\)", "", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text.rstrip(" .") + "."


def lua_quote(value):
    return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"') + '"'


def load_wowhead():
    records = {}
    for row in json.loads(SOURCE.read_text(encoding="utf-8")):
        key = ITEM_TO_KEY.get(row["item"])
        if not key:
            print(f"  skipping unmapped item {row['item']} {row['itemName']}", file=sys.stderr)
            continue
        tier = int(re.search(r"\d+", row["rank"]).group(0)) if row.get("rank") else None
        recipe = {
            "spellID": row["spell"],
            "itemID": row["item"],
            "itemName": row["itemName"],
            "skillLine": row["skillLine"],
            "skill": row["learnedAt"] if row["learnedAt"] and row["learnedAt"] < 9999 else None,
            "tier": tier,
            "creates": row.get("creates") or 1,
            "effect": readable_effect(row.get("use")),
            "reagents": [{"itemID": r[0], "name": r[1], "count": r[2]} for r in row["reagents"]],
        }
        if row.get("faction"):
            records.setdefault(key, {"variants": {}})["variants"][row["faction"]] = recipe
        else:
            records[key] = recipe
    return records


def load_harvest(path):
    """Read the recipes table out of a Fireside SavedVariables file."""
    sys.path.insert(0, str(REPO / "scripts"))
    from svreader import load_saved_variables

    db = load_saved_variables(path)
    return db.get("harvest", {}).get("recipes", {}) or {}


def merge_harvest(records, harvest):
    for name, rec in harvest.items():
        key = RECIPE_ALIASES.get(name.lower())
        if not key:
            key = next((k for item, k in ITEM_TO_KEY.items() if records.get(k, {}).get("itemName", "").lower() == name.lower()), None)
        target = records.get(key) if key else None
        if not target or "variants" in target:
            continue
        target["spellID"] = rec.get("recipeID") or target["spellID"]
        target["itemID"] = rec.get("outputItemID") or target["itemID"]
        if rec.get("reagents"):
            target["reagents"] = [
                {"itemID": r["itemID"], "name": r.get("name") or "?", "count": r.get("quantity", 1)}
                for r in rec["reagents"]
            ]


def render_recipe(recipe, indent):
    pad = " " * indent
    lines = [f"{pad}spellID = {recipe['spellID']},", f"{pad}itemID = {recipe['itemID']},"]
    lines.append(f"{pad}skillLine = {recipe['skillLine']},")
    if recipe.get("skill"):
        lines.append(f"{pad}skill = {recipe['skill']},")
    if recipe.get("tier"):
        lines.append(f"{pad}tier = {recipe['tier']},")
    lines.append(f"{pad}creates = {recipe['creates']},")
    if recipe.get("effect"):
        lines.append(f"{pad}effect = {lua_quote(recipe['effect'])},")
    lines.append(f"{pad}reagents = {{")
    for r in recipe["reagents"]:
        lines.append(f"{pad}    {{ itemID = {r['itemID']}, name = {lua_quote(r['name'])}, count = {r['count']} }},")
    lines.append(f"{pad}}},")
    return lines


def render(records):
    lines = [
        "local _, ns = ...",
        "",
        "-- GENERATED by scripts/build_catalog.py - do not edit by hand.",
        "-- Recipe and item ids, skill lines, reagents and effects for every camping",
        "-- object, from the Wowhead Forever database and in-game harvests. Names,",
        "-- grouping and exclusive-with lines stay in Data.lua.",
        "ns.Data = ns.Data or {}",
        "ns.Data.harvested = {",
    ]
    for key in sorted(records):
        record = records[key]
        lines.append(f"    {key} = {{")
        if "variants" in record:
            lines.append("        variants = {")
            for faction in sorted(record["variants"]):
                lines.append(f"            {faction} = {{")
                lines.extend(render_recipe(record["variants"][faction], 16))
                lines.append("            },")
            lines.append("        },")
        else:
            lines.extend(render_recipe(record, 8))
        lines.append("    },")
    lines.append("}")
    lines.append("")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--harvest", help="Fireside SavedVariables file with an in-game harvest")
    args = parser.parse_args()

    records = load_wowhead()
    if args.harvest:
        merge_harvest(records, load_harvest(args.harvest))

    OUT.write_text(render(records), encoding="utf-8")
    print(f"{len(records)} camping objects written to {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

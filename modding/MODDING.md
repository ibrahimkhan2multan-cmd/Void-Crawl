# VOIDBORN modding guide

A mod is a **.zip** file. Import it in the game: **Main menu → MODS → IMPORT MOD (.zip)**, pick the zip with the phone's file picker.
Mods are data only (no code), so they can add content but cannot crash or harm the game. Broken entries are skipped and shown in red in the MODS screen.

## Zip layout

```
mymod.zip
  mod.json      (required)
  items.json    (optional)
  sets.json     (optional)
  codes.json    (optional)
```
The files may also sit inside one folder in the zip. Anything can alternatively be put inside `mod.json` under the keys `items`, `sets`, `codes`.
Limits: zip max 4 MB, each file max 512 KB, 120 items, 12 sets, 40 codes per mod.

## mod.json
```json
{ "id": "sunfire", "name": "Sunfire Pack", "version": "1.0", "author": "You", "description": "Short text" }
```
`id`: 2–20 characters, a–z, 0–9 and `_`. Installing a mod with the same id updates the old one.

## items.json
Each key is the item id (a–z, 0–9, `_`).
```json
{
  "sunfire_blade": { "name": "Sunfire Blade", "slot": "weapon", "kind": "sword",
                     "dmg": [12, 16], "interval": 0.4, "range": 2.8, "arc": 120,
                     "color": "#ffaa33", "drops": true },
  "solar_boots":   { "name": "Solar Boots", "slot": "boots", "speed": 11, "def": 2, "color": "#ffd24a" }
}
```
- `slot`: `weapon`, `helm`, `armor`, `trinket`, `boots`
- weapon `kind`: `sword axe dagger bow spear hammer crossbow staff` (bow, crossbow, staff are ranged)
- weapon stats: `dmg [min,max]` (1–300), `interval` seconds between hits (0.15–2.5), `range` (1.5–20), `arc` degrees (20–200, melee)
- other stats (any item): `def hp speed crit atk_pct cdr leech coin regen` (whole numbers, clamped to sensible limits)
- `color`: `"#rrggbb"` or `[r,g,b]`
- `drops`: `true` (default) = can drop as random loot, `false` = only via codes
Rarity and item level scale the stats automatically, like base-game gear.

## sets.json
A set needs exactly four pieces, one per slot, defined in the same mod.
```json
{ "sunborn": { "name": "Sunborn Regalia", "mission": "forge", "color": "#c98a2a", "glow": "#ffcc55",
    "pieces": { "helm": "sun_helm", "armor": "sun_plate", "boots": "sun_greaves", "trinket": "sun_charm" },
    "b2": { "def": 10, "hp": 20 },
    "b4": { "atk_pct": 14, "kill_heal": 2, "speed": 6 },
    "flavor": "Warm as a summer noon." } }
```
- `mission`: where the set drops (`crypt`, `forge`, `frost`, `delve`) or `""` for codes only
- `b2` / `b4`: bonuses for wearing 2 / 4 pieces. Keys: `def hp speed crit atk_pct cdr leech coin regen kill_heal nova_pct dodge_wave`
- Set pieces never drop randomly; they come from the set's dungeon bosses and rare drops. Wearing 4 pieces shows the hero aura in your colours.

## codes.json
```json
{ "SUNFIRE": { "msg": "The sun answers.", "coins": 200,
               "items": [ { "base": "sunfire_blade", "rarity": 3, "ilvl": 5 } ] } }
```
Optional rewards: `coins xp points potions bombs` and `items` (rarity 0–4: common, uncommon, rare, epic, legendary). A mod cannot replace a built-in code.

## Turning mods off / removing
In the MODS screen use ON/OFF or REMOVE. Gear from a disabled mod is put safely away and comes back when the mod is turned on again.

`SunfirePack.zip` in this folder is a complete working example.

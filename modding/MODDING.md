# VOIDBORN modding guide (v2)

A mod is a **.zip** file. Import it in the game: **Main menu → MODS → IMPORT MOD (.zip)**, then pick the zip with the phone's file picker
(or tap **INSTALL EXAMPLE** to see a complete mod working).

Mods are **data only** - JSON, no code. A mod can add content but cannot run programs, touch files or crash the game.
Everything is validated and clamped; a broken entry is skipped and shown in red in the MODS screen while the rest of the pack still works.

## What a mod can add

| File | Adds |
|---|---|
| `items.json` | weapons, helms, armour, leggings, boots, trinkets |
| `sets.json` | 4- or 5-piece armour sets (leggings optional) with 2/4/5-piece bonuses and auras |
| `codes.json` | promo codes that give coins, XP, items |
| `mobs.json` | **new enemies** (a built-in body reshaped, recoloured and re-tuned) |
| `levels.json` | **new dungeons** that appear in DUNGEONS, with their own enemies and boss |
| `perks.json` | **new perks** the player can buy and slot |
| `pets.json` | **new pets** that can hatch from eggs |
| `buttons.json` | **buttons** on the main menu and/or the pause menu |
| `menus.json` | **menu windows** - draggable pop-up windows with text and buttons |

## Zip layout

```
mymod.zip
  mod.json      (required: id, name, ...)
  items.json    sets.json    codes.json
  mobs.json     levels.json  perks.json
  buttons.json  menus.json   (all optional)
```
The files may sit inside one folder in the zip. Any of them can alternatively live inside `mod.json` under the same key.
Limits per mod: zip 4 MB, each file 512 KB, 120 items, 12 sets, 40 codes, 24 mobs, 8 levels, 24 perks, 12 pets, 6 buttons, 12 menus, 30 elements per menu.

Every id you invent (items, mobs, levels, perks, menus ...) is automatically prefixed with your mod id (`sunfire__sun_wisp`),
so mods can never overwrite each other or the base game. Inside your own files just use the short id.

## mod.json
```json
{ "id": "sunfire", "name": "Sunfire Pack", "version": "1.0", "author": "You", "description": "Short text" }
```
`id`: 2-20 characters, a-z, 0-9 and `_`. Installing a mod with the same id updates the old one.

## items.json
```json
{
  "sunfire_blade": { "name": "Sunfire Blade", "slot": "weapon", "kind": "sword",
                     "dmg": [12, 16], "interval": 0.4, "range": 2.8, "arc": 120,
                     "color": "#ffaa33", "drops": true },
  "solar_boots":   { "name": "Solar Boots", "slot": "boots", "speed": 11, "def": 2, "color": "#ffd24a" }
}
```
- `slot`: `weapon`, `helm`, `armor`, `legs`, `trinket`, `boots`
- weapon `kind`: `sword axe dagger bow spear hammer crossbow staff` (bow, crossbow, staff are ranged)
- weapon stats: `dmg [min,max]` (1-300), `interval` seconds between hits (0.15-2.5), `range` (1.5-20), `arc` degrees (20-200, melee)
- other stats (any item): `def hp speed crit atk_pct cdr leech coin regen` (whole numbers, clamped)
- `color`: `"#rrggbb"` or `[r,g,b]`
- `drops`: `true` (default) = can drop as random loot, `false` = only via codes

## sets.json
A set needs four pieces (`helm armor boots trinket`), one per slot, defined in the same mod. A fifth piece, `legs`, is optional - add it to make a 5-piece set with a `b5` bonus.
```json
{ "sunborn": { "name": "Sunborn Regalia", "mission": "sunken_furnace", "color": "#c98a2a", "glow": "#ffcc55",
    "pieces": { "helm": "sun_helm", "armor": "sun_plate", "boots": "sun_greaves", "trinket": "sun_charm" },
    "b2": { "def": 10, "hp": 20 },
    "b4": { "atk_pct": 14, "kill_heal": 2, "speed": 6 },
    "b5": { "atk_pct": 8, "hp": 40 },
    "flavor": "Warm as a summer noon." } }
```
- `mission`: where the set drops - `crypt`, `forge`, `frost`, `delve`, **a level from your own pack**, or `""` for codes only
- `b2` / `b4` / `b5`: bonuses for 2 / 4 / 5 pieces (`b5` only matters if the set has a `legs` piece). Keys: `def hp speed crit atk_pct cdr leech coin regen kill_heal nova_pct dodge_wave`
- Worn pieces get the game's armour models in your colours; 4 pieces show the hero aura.

## codes.json
```json
{ "SUNFIRE": { "msg": "The sun answers.", "coins": 200,
               "items": [ { "base": "sunfire_blade", "rarity": 3, "ilvl": 5 } ] } }
```
Rewards: `coins xp points potions bombs` and `items` (rarity 0-6: Common, Uncommon, Rare, Epic, Legendary, Mythic, Voidborn). Each code works once per save. A mod cannot replace a built-in code.

## mobs.json  (new enemies)
A mob borrows one of the game's bodies (`model`) so it already has a full animated rig, then you retune and recolour it.
```json
{ "sun_wisp": { "name": "Sun Wisp", "model": "wisp", "tint": "#ff9a2a", "glow": "#ffd24a",
                "hp": 36, "dmg": 12, "speed": 3.8, "scale": 1.0, "xp": 20, "coins": [3, 7],
                "spawn": [ { "pool": "ember", "weight": 2.0, "depth": 1 } ] } }
```
- `model`: `husk slinger spiderling wisp brute shieldbearer embermite cultist necromancer frostwraith icearcher yeti hound bat slime`
- `ai` (optional, default = the model's own): `melee ranged dasher slam swarm exploder`. Bosses cannot be made by mods.
- numbers (clamped): `hp` 10-900, `dmg` 1-80, `speed` 1.2-7, `scale` 0.6-2.4, `xp` 1-400, `coins [min,max]`, `item_chance` 0-0.8, `potion_chance` 0-0.5,
  `windup` 0.25-1.5 (seconds of warning before it hits), `reach` 1-16, `cooldown` 0.5-6. Anything you leave out comes from the model.
- colours: `tint` recolours the whole body, `glow` the eyes/magic, `robe` / `body` where the model uses them
- `spawn` (optional): add the mob to the random pool of a built-in dungeon type: `pool` = `crypt ember frost mixed`
  (`ember` = Emberdeep Forge, `frost` = Frostmaw Caverns, `mixed` = Endless Delve, `crypt` = Crypt and others), `weight` 0.2-8, `depth` 0-3 = how deep into the dungeon before it appears.
  Without `spawn` the mob only appears in levels that list it.

## levels.json  (new dungeons)
```json
{ "sunken_furnace": { "name": "The Sunken Furnace", "biome": "Sunfire Depths",
    "blurb": "A drowned forge where sun-touched knights guard a molten heart.",
    "palette": "ember", "pool": "ember", "cols": 4, "rows": 4, "path_len": 8,
    "recommended_level": 6, "xp": 1800, "coins": 600, "unlock": "forge",
    "boss": "colossus", "boss_title": "THE SUN-FORGED", "boss_sub": "Heart of the Sunken Furnace",
    "mobs": ["sun_wisp", "ember_knight"] } }
```
- `palette`: `crypt` (default), `ember` (lava/forge look), `frost` (ice look)
- `pool`: base enemy mix `crypt ember frost mixed`, or `none` to use **only** your own `mobs` (needs at least one)
- `mobs`: your mobs (ids from `mobs.json`) added to this dungeon's enemies
- `cols`/`rows` 3-5 and `path_len` (clamped) set the dungeon size; the generator makes a new layout every run and always checks it is solvable
- `boss`: `warden`, `colossus` or `frostmaw`; `boss_title` / `boss_sub` change the banner text
- `unlock`: dungeon that must be completed first: `tutorial crypt forge frost delve` or another level of your pack (default `tutorial`)
- `recommended_level` 1-30, `xp` 50-8000, `coins` 20-3000 (first-clear rewards)
The level shows up in **DUNGEONS** after the base ones, and sets with `"mission": "<level id>"` drop there.

## pets.json
A pet is a companion that follows the player, fights on its own, can be levelled up, and respawns 10 seconds after it falls. Mod pets hatch from the normal eggs by their `rarity`, so a rarity-3 pet joins the pool of other rarity-3 pets. If a mod is switched off its pets are put away (never deleted) and come back when it is turned on again.
```json
{ "ember_cub": { "name": "Ember Cub", "rarity": 2, "style": "quad", "ai": "ranged",
    "hp": 100, "dmg": 9, "interval": 0.9, "reach": 9, "speed": 6.4,
    "color": "#c8481e", "color2": "#ffb347", "glow": "#ffcc55",
    "passive": { "atk_pct": 3, "coin": 4 }, "blurb": "A sunbaked cub that spits sparks." } }
```
- `style` (the body): `quad bird blob imp golem orb drake hydra`. `ai`: `melee` or `ranged`.
- `rarity` 0-6 (Common .. Voidborn). `hp` 20-1000, `dmg` 1-60, `interval` 0.35-3 s between attacks, `reach` 1.5-12, `speed` 3-8.5, `scale` 0.55-1.4, `float` 0-1.6 (hover height).
- Ranged pets may add `pierce` 0-3 and `fan` 1-3 (bolts per shot).
- `color`, `color2`, `glow`: body, accent and glow colours.
- `passive`: bonus the player gets while the pet is active (same keys as perks). It is capped by the pet's rarity.

## perks.json
Perks are passive bonuses bought with coins in **PERKS** (main menu) and slotted - the player starts with 3 slots and can buy more in UPGRADES.
```json
{ "sunlit": { "name": "Sunlit Edge", "desc": "Blades gleam with borrowed daylight.", "cost": 260,
              "bonus": { "atk_pct": 8 }, "color": "#ffcc55" } }
```
`bonus` keys are the same as set bonuses (`def hp speed crit atk_pct cdr leech coin regen kill_heal nova_pct dodge_wave`), clamped; `cost` 10-5000 coins.
If the mod is turned off the perk simply stops working (the player keeps owning it) and returns when the mod is back on.

## buttons.json  (menu buttons)
```json
{ "hub_btn": { "label": "SUNFIRE HUB", "where": "both", "color": "#ffaa33",
               "action": { "type": "menu", "menu": "hub" } } }
```
- `label`: up to 18 characters
- `where`: `main` (a column in the top-right of the main menu, headed "FROM MODS"), `pause` (listed in the pause menu during a dungeon) or `both`
- up to 6 buttons per screen are shown across all mods
- `action`: see **Actions** below

## menus.json  (draggable menu windows)
A menu is a floating window with a title bar you can **drag with your finger**, an X to close, and a list of elements.
Several windows can be open at once (up to 6); tapping a window brings it to the front.
```json
{ "hub": { "title": "Sunfire Hub", "color": "#ffaa33", "width": 360, "x": 0.5, "y": 0.4, "draggable": true,
    "elements": [
      { "type": "text", "text": "Level {level}  -  {coins} coins  -  perks {perks}", "size": 19 },
      { "type": "divider" },
      { "type": "button", "label": "Enter the Sunken Furnace", "action": { "type": "mission", "mission": "sunken_furnace" } },
      { "type": "button", "label": "Open Perks", "action": { "type": "perks" } },
      { "type": "button", "label": "Close", "color": "#8888aa", "action": { "type": "close" } } ] } }
```
- window: `title`, `color`, `width` 240-600, `x`/`y` start position as a fraction of the screen (0 = left/top, 1 = right/bottom), `draggable` (default true)
- elements (max 30):
  - `text` - `text` (max 300 chars, `\n` for a new line), optional `size` 14-30, `color`, `center`
  - `button` - `label`, optional `color`, and an `action`
  - `divider` - a thin line
- text updates live with these tokens: `{level} {coins} {kills} {bosses} {deaths} {potions} {bombs} {perks}`

## Actions (for buttons and menu buttons)
| `type` | extra keys | what it does |
|---|---|---|
| `message` | `text`, optional `title` | opens a small window with the text |
| `code` | `code` | redeems that promo code (once per save) and shows the result - use it to give rewards |
| `mission` | `mission` | starts a dungeon: one of your levels, or `crypt forge frost delve`. Locked ones say so. Main menu only |
| `perks` | - | opens the Perks screen |
| `menu` | `menu` | opens another of your menu windows |
| `close` | - | closes the window the button is in |

Actions cannot run code, so a mod button can never do more than the list above.

## Turning mods off / removing
In the MODS screen use ON/OFF or REMOVE. Items from a disabled mod are put safely away and come back when it is turned on again;
mobs, dungeons, perks, buttons and menus vanish while it is off. Saved progress is never lost.

## Tips
- Start from `SunfirePack.zip` in this folder - it uses every feature. Unzip it, edit the JSON, zip it again (files at the top level or inside one folder), import it.
- Keep ids short and lowercase. If something doesn't show up, open MODS: problems are listed under the pack in red with the entry name.
- JSON needs double quotes and no trailing commas. `"#rrggbb"` colours need the quotes.

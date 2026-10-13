class_name VCRoomTemplates
extends RefCounted
## Hand-designed room layouts. Every template is a square of odd size; the door of each
## side is the centre tile of that edge (3 tiles wide). The generator always carves a
## guaranteed lane from each used door towards the room, so decorations near the edge
## can never block a route.
##
## Legend:  #  rock wall         .  floor            P  pillar (solid)
##          S  sarcophagus       T  overgrown tree     k  crystal cluster (solid)
##          c  breakable crate   t  standing brazier   e  enemy spawn candidate
##          x  chest spot        b  bone pile (decor)

const COMBAT := {
	"crossroads_hall": {"themes": ["crypt"], "rows": [
		"###############",
		"#.............#",
		"#.P....e....P.#",
		"#.............#",
		"#.....c.c.....#",
		"#.............#",
		"#.e.........e.#",
		"#.............#",
		"#.e.........e.#",
		"#.............#",
		"#.....c.c.....#",
		"#.............#",
		"#.P....e....P.#",
		"#.............#",
		"###############"]},
	"pillar_court": {"themes": ["ruins", "overgrown"], "rows": [
		"###############",
		"#.............#",
		"#..P..P.P..P..#",
		"#.............#",
		"#..P.e...e.P..#",
		"#.............#",
		"#..e.......e..#",
		"#.............#",
		"#..e.......e..#",
		"#.............#",
		"#..P.e...e.P..#",
		"#.............#",
		"#..P..P.P..P..#",
		"#.............#",
		"###############"]},
	"ring_chamber": {"themes": ["crypt"], "rows": [
		"###############",
		"#.............#",
		"#.e....t....e.#",
		"#.............#",
		"#...#######...#",
		"#...#######...#",
		"#...#######...#",
		"#t..#######..t#",
		"#...#######...#",
		"#...#######...#",
		"#...#######...#",
		"#.............#",
		"#.e....t....e.#",
		"#.............#",
		"###############"]},
	"hollow_cavern": {"themes": ["cavern"], "rows": [
		"###############",
		"####.......####",
		"###.........###",
		"##...........##",
		"#....##.##....#",
		"#....#...#....#",
		"#.............#",
		"#.e....e....e.#",
		"#.k.........k.#",
		"#....#...#....#",
		"#....##.##....#",
		"##...........##",
		"###....e....###",
		"####.......####",
		"###############"]},
	"crypt_gallery": {"themes": ["crypt"], "rows": [
		"###############",
		"#.............#",
		"#.SS.e...e.SS.#",
		"#.............#",
		"#.SS.......SS.#",
		"#.............#",
		"#.............#",
		"#..e.......e..#",
		"#.............#",
		"#.............#",
		"#.SS.......SS.#",
		"#.............#",
		"#.SS.e...e.SS.#",
		"#.............#",
		"###############"]},
	"ruined_arena": {"themes": ["ruins"], "rows": [
		"###############",
		"#.............#",
		"#.c.....e...c.#",
		"#..##.....##..#",
		"#..#.......#..#",
		"#.............#",
		"#.....e.e.....#",
		"#.e.........e.#",
		"#.....e.e.....#",
		"#.............#",
		"#..#.......#..#",
		"#..##.....##..#",
		"#.c.....e...c.#",
		"#.............#",
		"###############"]},
	"overgrown_garden": {"themes": ["overgrown"], "rows": [
		"###############",
		"#.T.........T.#",
		"#.............#",
		"#....T...T....#",
		"#.............#",
		"#.e.........e.#",
		"#.............#",
		"#.....e.e.....#",
		"#.............#",
		"#.e.........e.#",
		"#.............#",
		"#....T...T....#",
		"#.............#",
		"#.T.........T.#",
		"###############"]},
	"shattered_crossing": {"themes": ["cavern", "ruins"], "rows": [
		"###############",
		"#.............#",
		"#.e.#.....#.e.#",
		"#...#.....#...#",
		"#.............#",
		"#.............#",
		"#.....e.e.....#",
		"#.............#",
		"#.....e.e.....#",
		"#.............#",
		"#.............#",
		"#...#.....#...#",
		"#.e.#.....#.e.#",
		"#.............#",
		"###############"]},
}

const SPECIAL := {
	"start_crypt": {"rows": [
		"#############",
		"#...........#",
		"#.t.......t.#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#...........#",
		"#.c.......c.#",
		"#...........#",
		"#############"]},
	"treasure_vault": {"rows": [
		"###########",
		"#.........#",
		"#.c.....c.#",
		"#.........#",
		"#...k.k...#",
		"#....x....#",
		"#...k.k...#",
		"#.........#",
		"#.c.....c.#",
		"#.........#",
		"###########"]},
	"checkpoint_shrine": {"rows": [
		"###########",
		"#.........#",
		"#.t.....t.#",
		"#.........#",
		"#.........#",
		"#.........#",
		"#.........#",
		"#.........#",
		"#.t.....t.#",
		"#.........#",
		"###########"]},
}

const BOSS_SIZE := 25

## Boss arena is built from rules rather than typed out: wall ring, eight pillars at
## fixed radius, four braziers, a clear central disc and a clear lane to the entrance.
static func boss_arena_rows() -> Array:
	var n := BOSS_SIZE
	var rows: Array = []
	var c := n / 2
	for y in n:
		var line := ""
		for x in n:
			var ch := "."
			if x == 0 or y == 0 or x == n - 1 or y == n - 1:
				ch = "#"
			else:
				var dx := x - c
				var dy := y - c
				var d := sqrt(float(dx * dx + dy * dy))
				if d > 11.2:
					ch = "#"        # round the corners
				elif absi(dx) == 7 and absi(dy) == 7:
					ch = "P"
				elif (absi(dx) == 8 and absi(dy) == 3) or (absi(dx) == 3 and absi(dy) == 8):
					ch = "P"
				elif (absi(dx) == 5 and absi(dy) == 5):
					ch = "t"
			line += ch
		rows.append(line)
	return rows

static func get_rows(template_id: String) -> Array:
	if COMBAT.has(template_id):
		return COMBAT[template_id]["rows"]
	if SPECIAL.has(template_id):
		return SPECIAL[template_id]["rows"]
	if template_id == "boss_arena":
		return boss_arena_rows()
	return []

static func combat_ids_for_theme(theme: String) -> Array:
	var out: Array = []
	for id in COMBAT:
		if theme in COMBAT[id]["themes"]:
			out.append(id)
	out.sort()
	return out

static func all_combat_ids() -> Array:
	var ids: Array = COMBAT.keys()
	ids.sort()
	return ids

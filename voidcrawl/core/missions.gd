class_name VCMissions
extends RefCounted
## Mission definitions. Adding a mission = adding an entry here (plus, optionally, a new
## layout/biome in the dungeon generator). The dungeon generator reads these keys.

const ORDER := ["tutorial", "crypt"]

const DATA := {
	"tutorial": {
		"name": "Initiation",
		"biome": "Gloomhollow",
		"blurb": "Learn the basics in the antechamber below the Hollow Crypt.",
		"layout": "tutorial",
		"fixed_seed": 4242,
		"recommended_level": 1,
		"xp": 120,
		"coins": 40,
		"unlock": "",
		"objectives": [
			{"id": "move", "text": "Move to the glowing marker", "type": "reach_marker"},
			{"id": "attack", "text": "Defeat the training husk", "type": "kills", "count": 1},
			{"id": "chest", "text": "Open the treasure chest", "type": "chest", "count": 1},
			{"id": "equip", "text": "Open your pack and equip the new item", "type": "equip", "count": 1},
			{"id": "dodge", "text": "Dodge-roll through the danger", "type": "dodge", "count": 1},
			{"id": "clear", "text": "Defeat the guardians (0/3)", "type": "kills", "count": 3},
			{"id": "exit", "text": "Step through the Void Gate", "type": "exit"},
		],
	},
	"crypt": {
		"name": "Crypt of the Hollow Warden",
		"biome": "Gloomhollow",
		"blurb": "Descend through crypts, caves and ruins. A hidden Warden guards the Void Gate.",
		"layout": "procedural",
		"cols": 4, "rows": 4, "path_len": 8,
		"fixed_seed": 0,
		"recommended_level": 2,
		"xp": 650,
		"coins": 220,
		"unlock": "tutorial",
		"objectives": [
			{"id": "find", "text": "Find the Warden's lair", "type": "enter_boss"},
			{"id": "boss", "text": "Defeat the Hollow Warden", "type": "boss"},
			{"id": "exit", "text": "Step through the Void Gate", "type": "exit"},
		],
	},
}

static func get_mission(id: String) -> Dictionary:
	return DATA.get(id, {})

static func is_unlocked(id: String, completed: Array) -> bool:
	var m := get_mission(id)
	if m.is_empty():
		return false
	var req: String = m.get("unlock", "")
	return req == "" or completed.has(req)

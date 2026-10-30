extends RefCounted
## Looks for coplanar overlapping faces (z-fighting) on every creature, the hero in all gear, and props.

const GP := preload("res://voidcrawl/tests/test_gameplay.gd")

static func run(t: Node) -> void:
	t.section("visuals: z-fighting audit")
	var holder := Node3D.new()
	t.add_child(holder)
	var total := 0
	for id in VCEnemyDefs.DEFS:
		if String(VCEnemyDefs.DEFS[id]["ai"]) == "boss" and id != "warden":
			pass
		var e := VCEnemy.new() if String(VCEnemyDefs.DEFS[id]["ai"]) != "boss" else VCBoss.new()
		e.setup(String(id), 3, 0)
		holder.add_child(e)
		await t.get_tree().process_frame
		var hits := VCZAudit.find(e.rig)
		if not hits.is_empty():
			print("  z-fight in ", id, ": ", _brief(hits))
		t.check("no z-fighting on %s" % id, hits.is_empty())
		total += hits.size()
		e.queue_free()
	for kind in ["crate", "barrel"]:
		var b := VCBreakable.new()
		b.setup(kind, 2.0, 0.8)
		holder.add_child(b)
		await t.get_tree().process_frame
		var hb := VCZAudit.find(b)
		if not hb.is_empty():
			print("  z-fight in ", kind, ": ", _brief(hb))
		t.check("no z-fighting on %s" % kind, hb.is_empty())
		b.queue_free()
	holder.queue_free()
	# the hero: bare, in each set, and in randomly generated gear of every rarity
	var m: VCMission = await GP._launch(t, "tutorial")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var bad := 0
	var cases := 0
	var sets: Array = VCSets.DEFS.keys()
	for variant in sets.size() + 24:
		VC.profile.equipment.clear()
		var P: VCProfile = VC.profile
		P.equipment.clear()
		if variant == 0:
			pass
		elif variant < sets.size() + 1:
			for sl in [1, 2, 5, 4, 3]:
				P.equipment[sl] = VCSets.make_piece(rng, String(sets[variant - 1]), 6, 3, sl, 100 + sl)
		else:
			for sl in [0, 1, 2, 5, 4, 3]:
				P.equipment[sl] = VCItems.generate(rng, 6, rng.randi_range(0, 6), sl, 0.0, 200 + sl)
		m.player.refresh_stats(false)
		m.player.refresh_visuals()
		await t.get_tree().process_frame
		var hits := VCZAudit.find(m.player.rig)
		cases += 1
		if not hits.is_empty():
			bad += 1
			print("  z-fight on hero variant ", variant, ": ", _brief(hits))
	t.check("hero has no z-fighting bare, in every set and in %d random outfits (%d cases)" % [24, cases], bad == 0, "%d cases flickered" % bad)
	m.queue_free()
	await t.get_tree().process_frame

static func _brief(hits: Array) -> String:
	var parts: Array = []
	for h in hits.slice(0, 60):
		parts.append("%s <> %s [%s%s @%.2f]" % [h["a"], h["b"], h["side"], h["axis"], float(h["at"])])
	return "; ".join(parts) + (" (+%d)" % (hits.size() - 60) if hits.size() > 60 else "")

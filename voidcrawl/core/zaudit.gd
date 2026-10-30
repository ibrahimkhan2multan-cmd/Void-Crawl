class_name VCZAudit
extends RefCounted
## Finds z-fighting: two axis-aligned boxes whose outward-facing sides lie in (almost) the same plane and
## overlap. Those flicker on a real phone. Used by the tests and the tester menu.

const EPS := 0.004
const MIN_AREA := 0.0006

static func _world_aabb(mi: MeshInstance3D) -> Variant:
	if mi.mesh == null:
		return null
	var gt := mi.global_transform
	var b := gt.basis
	# only axis-aligned parts (no rotation, or 90-degree turns) are checked
	for c in [b.x, b.y, b.z]:
		var n: Vector3 = (c as Vector3).abs()
		var mx := maxf(n.x, maxf(n.y, n.z))
		if mx < 0.0001 or (n.x + n.y + n.z) - mx > 0.002 * mx:
			return null
	var aabb := gt * mi.mesh.get_aabb()
	return aabb

## Returns an Array of {a, b, axis, side, at} for every flickering pair under `root`.
static func find(root: Node, skip_names: Array = []) -> Array:
	var boxes: Array = []
	var names: Array = []
	_collect(root, boxes, names, skip_names)
	var out: Array = []
	for i in boxes.size():
		var A: AABB = boxes[i]
		for j in range(i + 1, boxes.size()):
			var B: AABB = boxes[j]
			if not A.grow(EPS).intersects(B.grow(EPS)):
				continue
			for ax in 3:
				for side in [0, 1]:
					if ax == 1 and side == 0:
						continue      # downward faces are never seen from the camera
					var ca: float = (A.position[ax] if side == 0 else A.end[ax])
					var cb: float = (B.position[ax] if side == 0 else B.end[ax])
					if absf(ca - cb) > EPS:
						continue
					var o1 := (ax + 1) % 3
					var o2 := (ax + 2) % 3
					var w := minf(A.end[o1], B.end[o1]) - maxf(A.position[o1], B.position[o1])
					var h := minf(A.end[o2], B.end[o2]) - maxf(A.position[o2], B.position[o2])
					if w > 0.0 and h > 0.0 and w * h > MIN_AREA and not _buried(boxes, i, j, ax, side, ca, A, B):
						out.append({"a": names[i], "b": names[j], "axis": "xyz"[ax], "side": "-" if side == 0 else "+", "at": ca, "area": w * h})
	return out

## True when the shared face is hidden inside a third box (so nothing can flicker there).
static func _buried(boxes: Array, i: int, j: int, ax: int, side: int, plane: float, A: AABB, B: AABB) -> bool:
	var o1 := (ax + 1) % 3
	var o2 := (ax + 2) % 3
	var c := Vector3.ZERO
	c[ax] = plane + (-0.02 if side == 0 else 0.02)       # just outside the face
	c[o1] = (maxf(A.position[o1], B.position[o1]) + minf(A.end[o1], B.end[o1])) * 0.5
	c[o2] = (maxf(A.position[o2], B.position[o2]) + minf(A.end[o2], B.end[o2])) * 0.5
	for k in boxes.size():
		if k == i or k == j:
			continue
		var K: AABB = boxes[k]
		if K.has_point(c):
			return true
	return false

static func _collect(n: Node, boxes: Array, names: Array, skip: Array) -> void:
	if n is Node3D and not (n as Node3D).visible:
		return
	if n is MeshInstance3D and not skip.has(n.name):
		var mi := n as MeshInstance3D
		# glow/transparent/billboard helpers never z-fight in a way that matters
		var ab = _world_aabb(mi)
		if ab != null and mi.transparency < 0.01:
			boxes.append(ab)
			var ab2: AABB = ab
			names.append("%s[%.2fx%.2fx%.2f @%.2f,%.2f,%.2f]" % [mi.get_parent().name if mi.get_parent() != null else "", ab2.size.x, ab2.size.y, ab2.size.z, ab2.get_center().x, ab2.get_center().y, ab2.get_center().z])
	for c in n.get_children():
		_collect(c, boxes, names, skip)

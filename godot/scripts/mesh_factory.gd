extends RefCounted
## All geometry is generated locally; no external models, images or font files.
static func material(emission: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.86
	if emission:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

static func boxes(parts: Array) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for part in parts:
		var box := BoxMesh.new()
		box.size = part[1]
		var arrays: Array = box.get_mesh_arrays()
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var ix: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var start: int = vertices.size()
		for i in range(v.size()):
			vertices.append(v[i] + Vector3(part[0]))
			normals.append(n[i])
			colors.append(Color(part[2]))
		for i in ix:
			indices.append(start + i)
	var output: Array = []
	output.resize(Mesh.ARRAY_MAX)
	output[Mesh.ARRAY_VERTEX] = vertices
	output[Mesh.ARRAY_NORMAL] = normals
	output[Mesh.ARRAY_COLOR] = colors
	output[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, output)
	mesh.surface_set_material(0, material())
	return mesh

static func mesh_node(parent: Node3D, parts: Array, node_name: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = boxes(parts)
	parent.add_child(node)
	return node

static func soldier() -> ArrayMesh:
	return boxes([
		[Vector3(0,1.18,0),Vector3(0.64,0.72,0.38),Color("663433")],
		[Vector3(0,0.80,0),Vector3(0.64,0.18,0.44),Color("33313a")],
		[Vector3(0,1.75,0),Vector3(0.36,0.38,0.34),Color("bd947a")],
		[Vector3(0,1.97,0.02),Vector3(0.46,0.17,0.40),Color("363741")],
		[Vector3(-0.43,1.26,0),Vector3(0.19,0.65,0.23),Color("4c3537")],
		[Vector3(0.43,1.26,0),Vector3(0.19,0.65,0.23),Color("4c3537")],
		[Vector3(0.57,1.18,-0.40),Vector3(0.065,2.1,0.065),Color("92765d")],
		[Vector3(0.57,2.35,-0.40),Vector3(0.14,0.32,0.08),Color("c0c1c5")]])

static func leg() -> ArrayMesh:
	return boxes([[Vector3(0,-0.38,0),Vector3(0.23,0.74,0.28),Color("35303a")],
		[Vector3(0,-0.75,-0.07),Vector3(0.26,0.15,0.40),Color("26242b")]])

static func hero(parent: Node3D) -> Dictionary:
	var rig: Dictionary = {}
	var root := Node3D.new()
	root.name = "Vanguard"
	parent.add_child(root)
	rig["root"] = root
	var torso := Node3D.new()
	root.add_child(torso)
	torso.position.y = 1.1
	rig["torso"] = torso
	mesh_node(torso, [
		[Vector3(0,0.24,0),Vector3(0.68,0.78,0.4),Color("3c3f46")],
		[Vector3(0,-0.16,0),Vector3(0.72,0.16,0.46),Color("a33733")],
		[Vector3(-0.24,0.54,-0.02),Vector3(0.19,0.13,0.49),Color("878078")],
		[Vector3(0.24,0.54,-0.02),Vector3(0.19,0.13,0.49),Color("878078")],
		[Vector3(0,0.27,-0.23),Vector3(0.14,0.42,0.08),Color("bc8b50")]],"Armor")
	mesh_node(torso, [
		[Vector3(0,0.94,0),Vector3(0.37,0.40,0.35),Color("e1b393")],
		[Vector3(0,1.13,0.035),Vector3(0.43,0.19,0.39),Color("22212a")],
		[Vector3(0,1.04,-0.18),Vector3(0.45,0.065,0.045),Color("b5423a")],
		[Vector3(-0.095,0.96,-0.182),Vector3(0.05,0.025,0.018),Color("14161a")],
		[Vector3(0.095,0.96,-0.182),Vector3(0.05,0.025,0.018),Color("14161a")]],"Head")
	for side in [-1,1]:
		var key: String = "left" if side < 0 else "right"
		var arm := Node3D.new()
		torso.add_child(arm)
		arm.position = Vector3(side * 0.46,0.49,0)
		rig[key + "_arm"] = arm
		mesh_node(arm, [
			[Vector3(0,-0.1,0),Vector3(0.32,0.25,0.42),Color("62606a")],
			[Vector3(0,-0.48,0),Vector3(0.24,0.55,0.28),Color("41434a")],
			[Vector3(0,-0.78,-0.02),Vector3(0.23,0.20,0.25),Color("794536")]],key + "ArmMesh")
		var leg_root := Node3D.new()
		root.add_child(leg_root)
		leg_root.position = Vector3(side * 0.21,0.91,0)
		rig[key + "_leg"] = leg_root
		var leg_mesh := MeshInstance3D.new()
		leg_mesh.mesh = leg()
		leg_root.add_child(leg_mesh)
	var weapon := Node3D.new()
	torso.add_child(weapon)
	weapon.position = Vector3(0.52,-0.12,-0.15)
	rig["weapon"] = weapon
	mesh_node(weapon, [
		[Vector3(0,0,-0.45),Vector3(0.08,0.08,2.5),Color("4b4143")],
		[Vector3(0,0,-1.53),Vector3(0.30,0.13,0.12),Color("bfa06a")],
		[Vector3(0,0,-1.85),Vector3(0.18,0.065,0.55),Color("dcdbd3")],
		[Vector3(0,0.0,-1.50),Vector3(0.09,0.4,0.06),Color("b43b36")]],"Polearm")
	return rig

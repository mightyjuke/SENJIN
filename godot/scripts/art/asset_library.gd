extends RefCounted
## Explicit imported glTF contract. Blender is an authoring tool, never a runtime dependency.
const ROOT: String = "res://assets/models/"
static var _scenes: Dictionary = {}
static var _meshes: Dictionary = {}

static func scene(id: String) -> PackedScene:
	if not _scenes.has(id):
		var resource: Resource = load(ROOT + id + ".glb")
		assert(resource is PackedScene, "Missing Blender export: " + id)
		_scenes[id] = resource
	return _scenes[id] as PackedScene

static func mesh(id: String) -> Mesh:
	if not _meshes.has(id):
		var root: Node = scene(id).instantiate()
		var instances: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
		assert(instances.size() == 1, "Batched asset must contain one mesh: " + id)
		var instance: MeshInstance3D = instances[0] as MeshInstance3D
		assert(instance.transform.is_equal_approx(Transform3D.IDENTITY), "Bake mesh transforms in Blender: " + id)
		_meshes[id] = instance.mesh
		root.free()
	return _meshes[id] as Mesh

static func place(parent: Node3D, id: String, at: Vector3, yaw: float = 0.0, size: float = 1.0) -> Node3D:
	var node: Node3D = scene(id).instantiate() as Node3D
	parent.add_child(node)
	node.position = at
	node.rotation.y = yaw
	node.scale = Vector3.ONE * size
	return node

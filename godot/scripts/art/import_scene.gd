@tool
extends EditorScenePostImport
## glTF stores linear COLOR_0. Compatibility expects sRGB vertex paint; Forward+/Mobile
## can decode the same stored sRGB data using vertex_color_is_srgb. Convert once here,
## not per-frame or by modifying the Blender exports. Keep skin arrays and named binds.
func _post_import(scene: Node) -> Object:
	for child in scene.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = child as MeshInstance3D
		var source: ArrayMesh = instance.mesh as ArrayMesh
		assert(source != null and source.get_blend_shape_count() == 0, "Asset pipeline expects rigid armor skinning, not morph targets")
		var builder := ImporterMesh.new()
		for surface in range(source.get_surface_count()):
			var arrays: Array = source.surface_get_arrays(surface)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for i in range(colors.size()):
				colors[i] = colors[i].linear_to_srgb()
			arrays[Mesh.ARRAY_COLOR] = colors
			var material: StandardMaterial3D = source.surface_get_material(surface).duplicate() as StandardMaterial3D
			assert(material != null)
			material.vertex_color_use_as_albedo = true
			material.vertex_color_is_srgb = true
			material.emission_enabled = false
			builder.add_surface(source.surface_get_primitive_type(surface), arrays, [], {}, material)
		# Explicit low-poly crowd meshes handle character LOD; never simplify a skin blindly.
		if instance.skin == null:
			builder.generate_lods(60.0, 25.0, [])
		instance.mesh = builder.get_mesh()
	return scene

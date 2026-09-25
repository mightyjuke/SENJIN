@tool
extends EditorScenePostImport
## Preserve glTF's physical textures and color spaces. Do not apply the older kit's
## vertex-paint conversion to textured materials or replace their metallic response.
func _post_import(scene: Node) -> Object:
	for child in scene.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = child as MeshInstance3D
		assert(instance.mesh != null, "PBR mesh missing")
		for surface in range(instance.mesh.get_surface_count()):
			var material: StandardMaterial3D = instance.mesh.surface_get_material(surface) as StandardMaterial3D
			assert(material != null and material.albedo_texture != null, "PBR albedo not imported")
			assert(material.normal_texture != null and material.normal_enabled, "PBR tangent normals not imported")
			assert(material.roughness_texture != null and material.metallic_texture != null, "PBR ORM maps missing")
			material.vertex_color_use_as_albedo = false
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			material.roughness = 1.0
			material.metallic = 1.0
	return scene

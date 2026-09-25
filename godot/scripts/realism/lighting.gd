extends RefCounted
## The same PBR sky/sun setup works in Compatibility and Mobile; no SDFGI, SSR,
## volumetric fog or Forward+-only ambient occlusion is required by this scene.
const SKY_TEXTURE = preload("res://assets/realism/textures/battlefield_sky.exr")
const GROUND_ALBEDO = preload("res://assets/realism/textures/ground_albedo.png")
const GROUND_ORM = preload("res://assets/realism/textures/ground_orm.png")
const GROUND_NORMAL = preload("res://assets/realism/textures/ground_normal.png")

static func environment() -> Environment:
	var env := Environment.new()
	var sky := Sky.new()
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = SKY_TEXTURE
	panorama.energy_multiplier = 0.5
	sky.sky_material = panorama
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color("a2a8ab")
	env.fog_density = 0.0018
	return env

static func sun(shadows: bool = true) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.name = "IronOathSun"
	light.rotation_degrees = Vector3(-31,-42,0)
	light.light_color = Color("fff0d9")
	light.light_energy = 1.15
	light.shadow_enabled = shadows
	light.shadow_bias = 0.035
	light.shadow_normal_bias = 0.7
	light.directional_shadow_max_distance = 32
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	return light

static func ground() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = GROUND_ALBEDO
	mat.roughness_texture = GROUND_ORM
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	mat.roughness = 1.0
	mat.ao_enabled = true
	mat.ao_texture = GROUND_ORM
	mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.normal_enabled = true
	mat.normal_texture = GROUND_NORMAL
	mat.normal_scale = 0.25
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * 0.35
	mat.uv1_world_triplanar = true
	mat.albedo_color = Color(0.48,0.48,0.48,1)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat

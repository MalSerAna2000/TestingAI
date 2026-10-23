@tool
class_name WorldAeroAtmosphere3D
extends AeroAtmosphere3D
## Global dynamic atmosphere coupling WindManager directly into Godot Aerodynamic Physics v0.9.1.


func _init() -> void:
	super._init()
	per_influencer_positioning = false
	override_wind = true
	override_density = false
	density = 1.225


func is_inside_atmosphere(_position: Vector3) -> bool:
	return true


func get_wind_at_position(world_pos: Vector3) -> Vector3:
	if Engine.is_editor_hint():
		return wind
	var live_w: Vector3 = WindManager.get_wind_at_position(world_pos)
	wind = live_w
	return live_w

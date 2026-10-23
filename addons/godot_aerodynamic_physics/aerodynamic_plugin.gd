@tool
extends EditorPlugin

# Глухая заглушка плагина Godot Aerodynamic Physics.
# Настоящий плагин скачивается с Asset Library (godot_aerodynamic_physics, v0.9.1+).
# Типы узлов AeroBody3D / AeroInfluencer3D предоставляются скриптами-заглушками
# (aero_body_3d.gd, aero_influencer_3d.gd) с class_name, поэтому сцены остаются
# совместимыми с настоящим плагином при его установке.

const WARN := "[Aerodynamic Physics STUB] Настоящий плагин не установлен. "\
"Скачайте godot_aerodynamic_physics (v0.9.1+) из Asset Library Godot и замените addons/godot_aerodynamic_physics."

func _enter_tree() -> void:
	print(WARN)

func _exit_tree() -> void:
	pass

func _has_main_screen() -> bool:
	return false

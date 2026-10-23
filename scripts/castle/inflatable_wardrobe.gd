extends Node3D
class_name InflatableWardrobe

## 3x3x3m inflatable PVC wardrobe inside the castle to the left of the gate.
## Contains the pink silk ruffled maid dress, light-blue silk stockings, and white heels.

var interact_area: Area3D
var label_3d: Label3D
var player_inside_zone: Node3D = null


func _ready() -> void:
	var pvc_mat: Material = load("res://assets/materials/mat_throne_velvet_pvc.tres")
	var silk_mat: Material = load("res://assets/materials/mat_maid_pink_silk.tres")

	var static_col := AnimatableBody3D.new()
	static_col.name = "WardrobeBody"
	static_col.sync_to_physics = false
	static_col.collision_layer = 8 # Layer 4: DarkGodAndProps
	static_col.collision_mask = 0
	static_col.add_to_group("pvc_surface")
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(3.0, 3.0, 3.0)
	cs.shape = bx
	cs.position = Vector3(0.0, 1.5, 0.0)
	static_col.add_child(cs)
	add_child(static_col)

	if ResourceLoader.exists("res://assets/models/inflatable_wardrobe_3m.glb"):
		var packed: PackedScene = load("res://assets/models/inflatable_wardrobe_3m.glb")
		if packed:
			var inst: Node = packed.instantiate()
			var idx: int = 0
			for child in inst.get_children():
				if child is MeshInstance3D:
					(child as MeshInstance3D).material_override = pvc_mat if idx == 0 else silk_mat
					idx += 1
			add_child(inst)
	else:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(3.0, 3.0, 3.0)
		mi.mesh = bm
		mi.position = Vector3(0.0, 1.5, 0.0)
		mi.material_override = pvc_mat
		add_child(mi)

	interact_area = Area3D.new()
	interact_area.name = "WardrobeInteractArea"
	interact_area.collision_layer = 64
	interact_area.collision_mask = 2 # Player
	var trig_cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 3.4
	trig_cs.shape = sph
	trig_cs.position = Vector3(0.0, 1.5, 1.6)
	interact_area.add_child(trig_cs)
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	add_child(interact_area)

	label_3d = Label3D.new()
	label_3d.position = Vector3(0.0, 3.45, 0.6)
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.font_size = 42
	label_3d.outline_size = 10
	label_3d.modulate = Color(1.0, 0.78, 0.90)
	label_3d.text = "Надувной шкаф (3×3×3 м)\n[Подойди вплотную: надеть наряд горничной]"
	add_child(label_3d)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_inside_zone = body
		GameState.set_maid_outfit(not GameState.maid_outfit_equipped)
		AudioManager.play_3d("silk_rustle", global_position, 2.0, 0.06)
		_refresh_label()


func _on_body_exited(body: Node3D) -> void:
	if body == player_inside_zone:
		player_inside_zone = null


func _refresh_label() -> void:
	if GameState.maid_outfit_equipped:
		label_3d.text = "Комплект горничной НАДЕТ!\n(Розовое шелковое платье, чулки, каблуки)"
	else:
		label_3d.text = "Надувной шкаф (3×3×3 м)\n[Подойди: надеть комплект горничной]"

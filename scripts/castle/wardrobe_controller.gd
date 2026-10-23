class_name WardrobeController
extends Node3D
## 3x3x3m Inflatable Wardrobe left of the gates inside the hall.
## Houses the complete Maid Set:
##   - Pink silk dress with ruffles down to ankles ("розовое шелковое платье с оборками, подол до пяток")
##   - Light-blue silk stockings ("голубые шелковые чулки")
##   - White heels ("белые каблуки")

signal maid_set_interacted(player_node: Node)

var _display_hanger: Node3D
var _interact_area: Area3D
var _bob_t: float = 0.0


func _ready() -> void:
	_build_wardrobe_geometry()


func _build_wardrobe_geometry() -> void:
	var pvc_mat: Material = load("res://assets/materials/mat_castle_pvc.tres")
	var pink_mat: Material = load("res://assets/materials/mat_maid_pink_silk.tres")
	var blue_mat: Material = load("res://assets/materials/mat_maid_blue_silk.tres")
	var white_mat: Material = load("res://assets/materials/mat_yumik_pajama.tres")

	var wmesh := MeshInstance3D.new()
	wmesh.name = "WardrobeBodyMesh"
	wmesh.mesh = load("res://assets/models/castle_wardrobe_3m.obj")
	wmesh.material_override = pvc_mat
	add_child(wmesh)

	# Visible hanging Maid Dress + Stockings + White Heels inside open front alcove!
	_display_hanger = Node3D.new()
	_display_hanger.name = "MaidOutfitDisplay"
	_display_hanger.position = Vector3(0.0, 2.25, 1.58)
	add_child(_display_hanger)

	var bodice := MeshInstance3D.new()
	bodice.mesh = load("res://assets/models/yumik_maid_bodice.obj")
	bodice.material_override = pink_mat
	_display_hanger.add_child(bodice)

	var skirt := MeshInstance3D.new()
	skirt.mesh = load("res://assets/models/yumik_maid_skirt_hem.obj")
	skirt.position = Vector3(0.0, -0.52, 0.0)
	skirt.material_override = pink_mat
	_display_hanger.add_child(skirt)

	for sx in [-0.14, 0.14]:
		var stocking := MeshInstance3D.new()
		stocking.mesh = load("res://assets/models/yumik_limb_segment.obj")
		stocking.position = Vector3(sx, -1.42, 0.0)
		stocking.material_override = blue_mat
		_display_hanger.add_child(stocking)

		var heel := MeshInstance3D.new()
		heel.mesh = load("res://assets/models/yumik_white_heel.obj")
		heel.position = Vector3(sx, -1.88, 0.04)
		heel.material_override = white_mat
		_display_hanger.add_child(heel)

	var label := Label3D.new()
	label.text = "Надувной шкаф\n[Комплект горничной]"
	label.font_size = 42
	label.modulate = Color(1.0, 0.82, 0.90)
	label.outline_size = 10
	label.position = Vector3(0.0, 3.45, 0.4)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

	_interact_area = Area3D.new()
	_interact_area.name = "WardrobeTrigger"
	_interact_area.collision_layer = 128
	_interact_area.collision_mask = 16 | 32
	var sph := SphereShape3D.new()
	sph.radius = 2.85
	var csh := CollisionShape3D.new()
	csh.shape = sph
	csh.position = Vector3(0.0, 1.5, 1.2)
	_interact_area.add_child(csh)
	_interact_area.body_entered.connect(_on_body_entered)
	add_child(_interact_area)


func _process(delta: float) -> void:
	_bob_t += delta
	if is_instance_valid(_display_hanger):
		_display_hanger.visible = not GameState.maid_outfit_equipped
		_display_hanger.rotation.y = sin(_bob_t * 1.4) * 0.18


func _on_body_entered(body: Node3D) -> void:
	if body != null and body.is_in_group("player_yumik"):
		if body.has_method("toggle_maid_outfit_from_wardrobe"):
			body.toggle_maid_outfit_from_wardrobe()
		maid_set_interacted.emit(body)

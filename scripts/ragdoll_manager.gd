extends Node
class_name RagdollManager

# ----------------------------------------------------------------
# Рагдолл Юмика (PhysicalBone3D-подобная конструкция из тел и шарниров).
# Активируется при: удержании "Не отпускай меня", сидении на троне,
# нахождении в воздухе > 1 с, падении/ударе.
# ----------------------------------------------------------------

var _active_targets: Dictionary = {}  # CharacterBody3D -> {bodies, joints}

func activate(target: Node3D, impulse: Vector3 = Vector3.ZERO) -> void:
	if _active_targets.has(target):
		return
	var holder = target.get_node_or_null("RagdollHolder")
	if not holder:
		holder = target
	var origin = target.global_transform.origin
	var up = target.global_transform.basis.y
	var fwd = target.global_transform.basis.z

	var parts = {}
	var radius = 0.22
	var make = func(name: String, pos: Vector3, size: float) -> RigidBody3D:
		var b = RigidBody3D.new()
		b.name = name
		b.mass = 4.0 if name != "torso" else 12.0
		b.linear_damp = 0.2
		b.angular_damp = 0.3
		b.gravity_scale = 1.0
		b.global_position = origin + pos
		var shape = CapsuleShape3D.new()
		shape.radius = radius
		shape.height = size
		var col = CollisionShape3D.new()
		col.shape = shape
		b.add_child(col)
		var mesh = MeshInstance3D.new()
		mesh.mesh = CapsuleMesh.new()
		mesh.mesh.radius = radius
		mesh.mesh.height = size
		b.add_child(mesh)
		holder.add_child(b)
		parts[name] = b
		return b

	torso = make("torso", Vector3(0, 0.05, 0), 0.9)
	head = make("head", Vector3(0, 0.75, 0), 0.5)
	l_arm = make("l_arm", Vector3(0.35, 0.1, 0), 0.6)
	l_fore = make("l_fore", Vector3(0.65, 0.1, 0), 0.55)
	r_arm = make("r_arm", Vector3(-0.35, 0.1, 0), 0.6)
	r_fore = make("r_fore", Vector3(-0.65, 0.1, 0), 0.55)
	l_leg = make("l_leg", Vector3(0.18, -0.55, 0), 0.85)
	l_shin = make("l_shin", Vector3(0.18, -1.15, 0), 0.8)
	r_leg = make("r_leg", Vector3(-0.18, -0.55, 0), 0.85)
	r_shin = make("r_shin", Vector3(-0.18, -1.15, 0), 0.8)

	var pin = func(a: RigidBody3D, b: RigidBody3D, pos: Vector3):
		var j = PinJoint3D.new()
		j.node_a = a.get_path()
		j.node_b = b.get_path()
		j.position_a = a.global_transform.origin
		j.position_b = b.global_transform.origin
		j.setup()
		holder.add_child(j)
		return j

	pin(torso, head, Vector3(0, 0.75, 0))
	pin(torso, l_arm, Vector3(0.35, 0.1, 0))
	pin(l_arm, l_fore, Vector3(0.65, 0.1, 0))
	pin(torso, r_arm, Vector3(-0.35, 0.1, 0))
	pin(r_arm, r_fore, Vector3(-0.65, 0.1, 0))
	pin(torso, l_leg, Vector3(0.18, -0.55, 0))
	pin(l_leg, l_shin, Vector3(0.18, -1.15, 0))
	pin(torso, r_leg, Vector3(-0.18, -0.55, 0))
	pin(r_leg, r_shin, Vector3(-0.18, -1.15, 0))

	if impulse.length() > 0:
		torso.apply_central_impulse(impulse)

	# отключаем контроллер персонажа
	if target is CharacterBody3D:
		target.collision_layer = 0
		target.collision_mask = 0
		target.set_physics_process(false)
		var mesh = target.get_node_or_null("BodyMesh")
		if mesh: mesh.visible = false

	_active_targets[target] = {
		"bodies": [torso, head, l_arm, l_fore, r_arm, r_fore, l_leg, l_shin, r_leg, r_shin],
		"holder": holder,
	}

func deactivate(target: Node3D) -> void:
	if not _active_targets.has(target):
		return
	var data = _active_targets[target]
	for b in data["bodies"]:
		b.queue_free()
	# удаляем шарниры держания (deferred safe handled by queue_free of holder children?)
	_holder_cleanup(data["holder"], target)
	if target is CharacterBody3D:
		target.collision_layer = 1
		target.collision_mask = 14
		target.set_physics_process(true)
		var mesh = target.get_node_or_null("BodyMesh")
		if mesh: mesh.visible = true
	_active_targets.erase(target)

func _holder_cleanup(holder: Node, target: Node3D) -> void:
	# шарниры созданы как дети holder-а; удаляем PinJoint3Damong holder children created this session
	for child in holder.get_children():
		if child is PinJoint3D:
			child.queue_free()

func is_active(target: Node3D) -> bool:
	return _active_targets.has(target)

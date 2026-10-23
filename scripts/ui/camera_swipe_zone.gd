extends Control
class_name CameraSwipeZone

## Right-half screen multi-touch swipe zone for 3rd-person camera rotation.

signal camera_swiped(delta_px: Vector2)

var active_touch_id: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and active_touch_id == -1:
			active_touch_id = st.index
		elif not st.pressed and st.index == active_touch_id:
			active_touch_id = -1
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == active_touch_id:
			camera_swiped.emit(sd.relative)
			accept_event()

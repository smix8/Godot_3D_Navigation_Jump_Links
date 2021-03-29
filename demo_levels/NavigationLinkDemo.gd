extends Node3D

### Setup for controls and camera for all demo scenes

@export var debug_print : bool = false


var _player : Node3D
var _camera : Camera3D
var _camera_anchor : Node3D
var _camera_y_rotation = 0.0
var _debug_nodes : Array = []

@onready var _navigation : Node = get_node("JumpLinkNavigation")
@onready var _move_target_marker : Node3D = get_node("MoveTargetMarker")


func _ready() -> void:
	
	_camera_anchor = get_node("CameraAnchor")
	_camera = _camera_anchor.get_node("Camera")
	_camera_y_rotation = _camera_anchor.rotation_degrees.y
	
	_player = get_node("JumpLinkAgents/Robi_JumpLinkAgent")
	_player.set_navigation(_navigation)
	_player.add_debug()

	var _robina = get_node("JumpLinkAgents/Robina_JumpLinkAgent")
	_robina.set_navigation(_navigation)
	_robina.start_following(_player)
	_robina.add_debug()
	
	_move_target_marker.global_transform.origin = _player.global_transform.origin
	
	set_process_input(true)


func _unhandled_input(event) -> void:
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var from = _camera.project_ray_origin(event.position)
		var to = from + _camera.project_ray_normal(event.position) * 100
		var _target_point : Vector3 = _navigation.get_closest_point_to_segment(from, to)
		
		_player.set_movement_target(_target_point)
		_move_target_marker.global_transform.origin = _target_point
	
	if event is InputEventMouseMotion:
		if event.button_mask & (MOUSE_BUTTON_MASK_MIDDLE + MOUSE_BUTTON_MASK_RIGHT):
			_camera_y_rotation += event.relative.x * 0.005
			_camera_anchor.set_rotation(Vector3(0, _camera_y_rotation, 0))
			
			if debug_print and OS.is_debug_build():
				print("Camera Rotation: ", _camera_y_rotation)


func _on_Toggle_Debug_pressed() -> void:
	
	var _debug_nodes = get_tree().get_nodes_in_group("jump_links_debug")
	for _debug_node in _debug_nodes:
		_debug_node.visible = !_debug_node.visible


func _on_Button_pressed() -> void:
	_on_Toggle_Debug_pressed()

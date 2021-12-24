extends Spatial

class_name JumpLink, "res://addons/navigation_jump_links/icons/JumpLink.png"

##############################################################################
### Holds a pair of JumpLinkPosition nodes to mark JumpingPosition and LandingPosition
### Adding an optional JumpLinkPath node enables jump trajectory pathfollow.
##############################################################################

signal timecost_changed
signal link_interacted

var _jump_material = preload("res://addons/navigation_jump_links/debug/JumpLinkPositionJumpingMaterial.tres")
var _land_material = preload("res://addons/navigation_jump_links/debug/JumpLinkPositionLandingMaterial.tres")
var _link_position_template = preload("res://addons/navigation_jump_links/nodes/JumpLinkPosition.tscn")

export(float) var timecost = 1.0 setget _set_timecost, get_timecost
export(String) var animation = ""

onready var _link_jump_position : Position3D = get_node("JumpingPosition")
onready var _link_land_position : Position3D = get_node("LandingPosition")

var _jumplinkpath : Path = null


func _ready() -> void:
	
	if has_node("JumpLinkPath"):
		_jumplinkpath = get_node("JumpLinkPath")
	
	
	if not Engine.editor_hint:
		_link_jump_position.visible = false
		_link_land_position.visible = false

	
func get_jumping_position() -> Position3D:
	return _link_jump_position


func get_landing_position() -> Position3D:
	return _link_land_position


func get_distance() -> float:
	return _link_jump_position.global_transform.origin.distance_to(_link_land_position.global_transform.origin)


func get_timecost() -> float:
	return timecost


func get_weighted_distance() -> float:
	return get_distance() * get_timecost()


func _enter_tree() -> void:
	
	add_to_group("jump_links")
	
	if self == get_tree().get_edited_scene_root():
		### don't create childnode structure while we are alone in a scene, e.g. user opened addon node directly
		return
	
	if not get_node("JumpingPosition"):
		var _new_link_start_pos = _link_position_template.instance()
		add_child(_new_link_start_pos)
		_new_link_start_pos.set_name("JumpingPosition")
		_new_link_start_pos.translation.z = 1.0
		_new_link_start_pos.set_owner(get_tree().get_edited_scene_root())
		_new_link_start_pos.add_to_group("jump_links_debug")
	
	_link_jump_position = get_node("JumpingPosition")
	
	if not get_node("LandingPosition"):
		var _new_link_end_pos = _link_position_template.instance()
		add_child(_new_link_end_pos)
		_new_link_end_pos.set_name("LandingPosition")
		_new_link_end_pos.translation.z = -1.0
		_new_link_end_pos.set_owner(get_tree().get_edited_scene_root())
		_new_link_end_pos.add_to_group("jump_links_debug")
	
	_link_land_position = get_node("LandingPosition")

	_link_jump_position.visible = true
	_link_land_position.visible = true

	add_debug()
	

func interact(_agent : Spatial) -> void:
	emit_signal("link_interacted", _link_jump_position, _jumplinkpath, _agent, animation)


func _set_timecost(new_timecost : float) -> void:
	
	if timecost != new_timecost:
		timecost = abs(new_timecost)
		emit_signal("timecost_changed", self)


func add_debug() -> void:
	
	var _draw_path_geometry = ImmediateGeometry.new()
	var _path_draw_material = SpatialMaterial.new()
	
	_draw_path_geometry.cast_shadow = false
	
	add_child(_draw_path_geometry)

	_draw_path_geometry.set_name("JumpLinkDebugDraw")
	_draw_path_geometry.add_to_group("jump_links_debug")
	_draw_path_geometry.set_material_override(load("res://addons/navigation_jump_links/debug/PathDrawMaterial.tres"))
	_draw_path_geometry.clear()
	_draw_path_geometry.begin(Mesh.PRIMITIVE_POINTS, null)
	_draw_path_geometry.add_vertex(_link_jump_position.transform.origin)
	_draw_path_geometry.add_vertex(_link_land_position.transform.origin)
	_draw_path_geometry.end()
	_draw_path_geometry.begin(Mesh.PRIMITIVE_LINE_STRIP, null)
	if has_node("JumpLinkPath") and get_node("JumpLinkPath").is_class("Path"):
		for x in get_node("JumpLinkPath").curve.get_baked_points():
			_draw_path_geometry.add_vertex(x)
	else:
		_draw_path_geometry.add_vertex(_link_jump_position.transform.origin)
		_draw_path_geometry.add_vertex(_link_land_position.transform.origin)
	_draw_path_geometry.end()
	_draw_path_geometry.visible = false

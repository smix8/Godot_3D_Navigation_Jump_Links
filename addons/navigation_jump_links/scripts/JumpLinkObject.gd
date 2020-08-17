tool
extends Area

class_name JumpLinkObject, "res://addons/navigation_jump_links/icons/JumpLinkObject.png"

##############################################################################
### Extended Area node that groups an infinite number of JumpLink children and controls their usage.
##############################################################################

signal weight_changed

export(float) var weight_cost = 1.0 setget _set_weight_cost, get_weight_cost
export(String) var required_tag

var _jump_points : Array = []
var _jump_links : Array = []
var _jump_point_to_land_point : Dictionary = {}
var _jump_costs : Dictionary = {}

var _jump_link_template = preload("res://addons/navigation_jump_links/nodes/JumpLink.tscn")
var _jump_link_object_mesh_template = preload("res://addons/navigation_jump_links/debug/JumpLinkObjectMesh.tscn")
var _jump_link_object_mesh_material = preload("res://addons/navigation_jump_links/debug/JumpLinkObjectMaterial.tres")


func _set_weight_cost(new_weight : float) -> void:

	if weight_cost != new_weight:
		weight_cost = abs(new_weight)
		emit_signal("weight_changed", self)


func get_weight_cost() -> float:
	return weight_cost


func _enter_tree() -> void:
	
	add_to_group("jump_link_objects")
	
	if self == get_tree().get_edited_scene_root():
		### don't create childnode structure while we are alone in a scene, e.g. user opened addon node directly
		return
	
	var _new_jump_link_object_mesh : MeshInstance
	if not has_node("JumpLinkObjectMesh"):
		_new_jump_link_object_mesh = _jump_link_object_mesh_template.instance()
		add_child(_new_jump_link_object_mesh)
		_new_jump_link_object_mesh.set_name("JumpLinkObjectMesh")
		_new_jump_link_object_mesh.set_owner(get_tree().get_edited_scene_root())
		_new_jump_link_object_mesh.set_surface_material(0, _jump_link_object_mesh_material)
		_new_jump_link_object_mesh.visible = true
		
	
	if not has_node("JumpLinkObjectCollision"):
		var _new_jump_link_object_collision : CollisionShape
		_new_jump_link_object_collision = CollisionShape.new()
		add_child(_new_jump_link_object_collision)
		_new_jump_link_object_collision.set_name("JumpLinkObjectCollision")
		_new_jump_link_object_collision.set_owner(get_tree().get_edited_scene_root())
		_new_jump_link_object_collision.make_convex_from_brothers()

	if not has_node("LinksContainer"):
		var _new_link_container : Spatial = Spatial.new()
		add_child(_new_link_container)
		_new_link_container.set_name("LinksContainer")
		_new_link_container.set_owner(get_tree().get_edited_scene_root())
		_new_link_container.set_meta("_edit_lock_", true)
	
	if get_node("LinksContainer").get_child_count() == 0:
		var _new_jump_link = _jump_link_template.instance()
		get_node("LinksContainer").add_child(_new_jump_link)
		_new_jump_link.set_owner(get_tree().get_edited_scene_root())

	add_debug()


func _ready() -> void:
	
	add_to_group("jump_link_objects")
	
	_jump_points.clear()
	_jump_links.clear()
	
	for _jump_link_node in get_node("LinksContainer").get_children():
		for link_position in _jump_link_node.get_children():
			var _jump_point : Spatial = _jump_link_node.get_node("JumpingPosition")
			var _land_point : Spatial = _jump_link_node.get_node("LandingPosition")
			_jump_points.append(_jump_point)
			_jump_links.append(_jump_link_node)
			_jump_point_to_land_point[_jump_point] = _land_point
			_jump_costs[_jump_point] = _jump_link_node.timecost
			
		_jump_link_node.connect("link_interacted", self, "_on_link_interacted")
		
	if not Engine.editor_hint:
		get_node("JumpLinkObjectMesh").visible = false


func get_jump_points() -> Array:
	return _jump_points


func get_jump_links() -> Array:
	return _jump_links


func get_required_tag() -> String:
	return required_tag


func is_agent_allowed(_agent) -> bool:
	if required_tag == "":
		return true
	elif required_tag in _agent.get_jumplink_tags():
		return true
	else:
		return false


func _on_link_interacted(_link_jump_position, _jumplinkpath, _agent, _animation) -> void:
	
	### used in point&click movement
	### when an _agent interacts with a jumpposition the collision area, e.g. a player pressing a prompt button while in the area
	
	if not is_agent_allowed(_agent):
		return
		
	if not _link_jump_position:
		_link_jump_position = _get_closest_jump_position(_agent)
	_agent.jump_link(_link_jump_position, _jump_point_to_land_point[_link_jump_position], _jumplinkpath, self, _animation)


func interact(_agent : Spatial) -> void:
	
	### used when an _agent interacts with a the collision area, e.g. a player pressing a prompt button
	
	if not is_agent_allowed(_agent):
		return

	var _closest_start_jump_node = _get_closest_jump_position(_agent)
	var _end_jump_node = _jump_point_to_land_point.get(_closest_start_jump_node)
		
	_agent.jump_link(_closest_start_jump_node, _end_jump_node, self)


func get_interact_position(_agent : Spatial) -> Vector3:
	return _get_closest_jump_position(_agent).global_transform.origin


func _get_closest_jump_position(_agent : Spatial) -> Spatial:
	
	### when a player interacts with the collision area from withing reach we don't have a dedicated start position and pick the closest one
	
	var _closest_jump_node
	var _closest_distance = 11111111.0
	
	for _jump_node in _jump_points:
		
		if _agent.global_transform.origin.distance_to(_jump_node.global_transform.origin) < _closest_distance:
			_closest_distance = _agent.global_transform.origin.distance_to(_jump_node.global_transform.origin)
			_closest_jump_node = _jump_node

	return _closest_jump_node


func add_debug() -> void:
	
	### visualization of jumplink connections and points with debug on
	
	for _jump_point in _jump_points:
		
		var begin = _jump_point.transform.origin
		var end = _jump_links[_jump_point].transform.origin
		var _dir : Vector3 = end - begin
		
		var _draw_path_geometry = ImmediateGeometry.new()
		
		add_child(_draw_path_geometry)

		_draw_path_geometry.set_name("JumpLinkObjectDebugDraw")
		_draw_path_geometry.add_to_group("jump_links_debug")
		_draw_path_geometry.set_material_override(load("res://addons/navigation_jump_links/debug/PathDrawMaterial.tres"))
		_draw_path_geometry.clear()
		_draw_path_geometry.begin(Mesh.PRIMITIVE_POINTS, null)
		_draw_path_geometry.add_vertex(begin)
		_draw_path_geometry.add_vertex(end)
		_draw_path_geometry.end()
		_draw_path_geometry.begin(Mesh.PRIMITIVE_LINE_STRIP, null)
		_draw_path_geometry.add_vertex(begin)
		_draw_path_geometry.add_vertex(end)
		_draw_path_geometry.end()

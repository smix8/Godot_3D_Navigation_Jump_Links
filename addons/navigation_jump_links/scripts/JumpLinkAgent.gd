
class_name JumpLinkAgent

extends Node3D

@icon("res://addons/navigation_jump_links/icons/JumpLinkAgent.png")

##############################################################################
### Template for agents that want to use JumpLink nodes
### Has basic pathmoving and follow target functionality
### Can be extended and customized as long as core functions and signals are kept intact
##############################################################################

signal used_jump_link
signal started_jumping
signal stopped_jumping
signal started_movement
signal stopped_movement

### print (a lot) of debug messages for the agents movement behaviour
@export var debug_print : bool = false
### draw lines to visualize agents current movement path
@export var debug_draw_path : bool = true
### distance required to allow interactions with a JumpLinkObjects collision area
@export var link_interaction_range : float = 0.5

### distance to landing node before agent is considered as successfully "landed" after a jump
@export var jump_to_landing_distance : float = 0.25

### time in seconds before the first  followlink in queue gets automatically removed
### prevents agents from getting stucked under bad circumstance
### shouldn't be set to low or otherwise an agent will make unnecessary path calls when traversing a large navmesh
@export var follow_target_link_timeout : float = 5.0

### time in seconds before a following agent updates path to target
### set as high as possible to preserver performance
### set as low as needed to react fast enough to target position changes
@export var follow_update_interval : float = 1.0

### string tags, if matched and found on jumplinkobjects permits usage of jumplink
@export var jumplink_tags : Array[String]


@export var movement_speed : float = 6.0

### jumplinknavigation
var _navigation : JumpLinkNavigation

### jumplinks
var _jumping_link : bool = false
var _jump_link_start_transform : Transform
var _jump_link_end_transform : Transform
var _jump_process_time : float = 0.001
var _jumplink_nodepath : Array
var _jumplink_pathfollow : PathFollow3D
var jump_link_timecost = 1.0

### following
var _follow_target : Node3D
var following : bool = false
var _follow_check_distance_interval = 0.5
var _is_following_target_link : bool = false
var _follow_target_link_timeout_counter : float = 0.0
var _follow_target_used_links : Array

### path movement
var _path : Array = []
var _target_pos : Vector3
var _link_to_interact
var _move_target


func _ready() -> void:
	
	add_to_group("jump_link_agents")
	set_process(false)


func set_navigation(_new_navigation_node : JumpLinkNavigation) -> void:
	_navigation = _new_navigation_node
	set_process(true)


func get_jumplink_tags() -> Array:
	return jumplink_tags


func _get_follow_target():
	return _follow_target


func get_movement_speed() -> float:
	return movement_speed
	

func _process(_delta : float) -> void:

	if _jumping_link:
		_process_jump_link(_delta)
		### we are traveling along a linkpath, cancel normal behaviour
		return
	
	_process_follow_target(_delta)
	
	_process_movement(_delta)
	
	_process_follow_links(_delta)
	
	_process_bailout(_delta)
	
	_process_debug_pathdraw(_delta)


func _process_debug_pathdraw(_delta : float) -> void:
	
	if debug_draw_path and has_node("DrawMovementPath"):
		if _path.size() > 0:
			var _draw_path_geometry = get_node("DrawMovementPath")
			_draw_path_geometry.clear()
			_draw_path_geometry.begin(Mesh.PRIMITIVE_LINE_STRIP, null)
			for x in _path:
				_draw_path_geometry.add_vertex(x)
			_draw_path_geometry.end()


func _process_bailout(_delta : float) -> void:
	
	### delete the first follow link in queue after some time to prevent an agent to get stuck indefinitely under bad circumstance
	
	if _is_following_target_link:
		_follow_target_link_timeout_counter -= _delta #* get_parent().get_speed_multiply_factor()
		if _follow_target_link_timeout_counter < 0.0:
			## timeout
			_follow_target_link_timeout_counter = follow_target_link_timeout
			_follow_target_used_links.pop_front()
			_is_following_target_link = false
			if debug_print and OS.is_debug_build():
				print( "'%s' gave up following link" % get_name() )


func jump_link(_start_jump_link_node, _end_jump_link_node, _jumplinkpath, jump_node, _animation = "") -> bool:
	
	
	if _jumping_link:
		return false
	
	### customize pathfollow behaviour here
	if _jumplinkpath:
		_jumplink_pathfollow = PathFollow3D.new()
		_jumplink_pathfollow.set_loop(false)
		_jumplinkpath.add_child(_jumplink_pathfollow)
		
	### play jump animation on agent here
	if _animation:
		if has_node("AnimationPlayer"):
			if get_node("AnimationPlayer").has_animation(_animation):
				get_node("AnimationPlayer").play(_animation)
	
	_jump_link_start_transform = _start_jump_link_node.global_transform
	_jump_link_end_transform = _end_jump_link_node.global_transform
	jump_link_timecost = jump_node._jump_costs[_start_jump_link_node]
		
	_jump_process_time = 0.0
	_jumping_link = true
	emit_signal("used_jump_link", _start_jump_link_node, jump_node)
	set_process(true)
	emit_signal("started_jumping")
	return true
	

func _on_jumping_ended() -> void:
	if _is_following_target_link:
		_follow_target_used_links.pop_front()
		_is_following_target_link = false
	emit_signal("stopped_jumping")
	

func _process_follow_links(_delta) -> void:
	
	if not _follow_target_used_links.size() > 0:
		### no links to follow
		return
	
	if not _is_following_target_link:
		
		### add custom behaviour here how to react with a new link
		
		# _follow_target_used_links[0] -> first link array in queue
		# _follow_target_used_links[0][0] -> JumpLink JumpingPosition
		# _follow_target_used_links[0][1] -> JumpLinkObject
		
		### we don't follow a linknode, pick the first in queue
		_is_following_target_link = true
		_link_to_interact = _follow_target_used_links[0][0]
		_update_path(_follow_target_used_links[0][0].global_transform.origin)


func _process_follow_target(_delta) -> void:
	
	if not _follow_target:
		return
	
	var _follow_target_distance = global_transform.origin.distance_to(_follow_target.global_transform.origin)
	

	if _follow_target_distance > 2.0:
		if not following:
			following = true
	
	if following:
		if global_transform.origin.distance_to(_follow_target.global_transform.origin) <= 2.0:
			following = false
			stop_movement()
			return
		
		_follow_check_distance_interval += _delta
		
		if _follow_check_distance_interval >= follow_update_interval:
			_follow_check_distance_interval = 0.0
			
			set_movement_target(_follow_target.global_transform.origin)


func start_following(_new_follow_target) -> void:
	
	_follow_target = _new_follow_target
	following = true
	_follow_check_distance_interval = 0.0


func stop_following() -> void:

	following = false
	_follow_target = null


func stop_movement() -> void:
	_path = []
	emit_signal("stopped_movement")


func can_use_jump_link(jump_node) -> bool:
	
	return jump_node.get_required_tag() in jumplink_tags


func _process_movement(_delta) -> void:
	
	if _link_to_interact:
		
		if global_transform.origin.distance_to(_link_to_interact.global_transform.origin) < link_interaction_range:
			### _link_to_interact.get_parent() -> JumpLink node
			_link_to_interact.get_parent().interact(self)
			_link_to_interact = null
			return
	
	if _path.size() > 1:
		var to_walk = _delta * movement_speed
		var to_watch = Vector3.UP
		while to_walk > 0 and _path.size() >= 2:
			var pfrom = _path[_path.size() - 1]
			var pto = _path[_path.size() - 2]
			to_watch = (pto - pfrom).normalized()
			var d = pfrom.distance_to(pto)
			if d <= to_walk:
				_path.remove(_path.size() - 1)
				to_walk -= d
			else:
				_path[_path.size() - 1] = pfrom.linear_interpolate(pto, to_walk / d)
				to_walk = 0
		
		var atpos = _path[_path.size() - 1]
		var atdir = to_watch
		atdir.y = 0
		
		var t = Transform()
		t.origin = atpos
		t = t.looking_at(atpos + atdir, Vector3.UP)
		set_transform(t)
		
	if _path.size() <= 1:
		stop_movement()


func _process_jump_link(_delta) -> void:
	
	### jump from start to end point over time
	if _jump_process_time <= 0.0:
		### make sure we have no div with zero
		_jump_process_time = 0.00001
		
	_jump_process_time += _delta
	
	if _jumplink_pathfollow:
		### we are following a pathfollow curve3d with unit_offset range 0.0-1.0
		_jumplink_pathfollow.unit_offset = _jump_process_time / jump_link_timecost
		global_transform = _jumplink_pathfollow.global_transform
	else:
		global_transform = _jump_link_start_transform.interpolate_with(_jump_link_end_transform, _jump_process_time / jump_link_timecost)
	
	### emergency break in case we move so insanely fast that we overshoot jump_to_land_distance threshold in a single frame
	if _jump_process_time >= jump_link_timecost or ( global_transform.origin.distance_to(_jump_link_end_transform.origin) <= jump_to_landing_distance ):

		if _jumplink_pathfollow:
			_jumplink_pathfollow.queue_free()
		global_transform = _jump_link_end_transform
		### close enougth to endpoint, stop jumping and continue path
		_jumping_link = false
		_on_jumping_ended()
		### refresh path after jump
		_move(_move_target)


func set_movement_target(_new_target : Vector3) -> void:
	
	if debug_print and OS.is_debug_build():
		print("----------------------------")
		print("moving to new target")
		
	if _jumping_link:
		_move_target = _new_target
		return
	
	### reset everything and move to new target
	_move_target = _new_target
	_follow_target_used_links = []
	_link_to_interact = null
	_is_following_target_link = false
	_jumping_link = false
	_path = []
	
	_move(_move_target)
	

func _move(_target_pos : Vector3) -> void:
	emit_signal("started_movement")
	var _jumplink_path_and_link = _navigation.get_jumplink_path(self, _target_pos)
	# _jumplink_path_and_link[0] -> _path
	# _jumplink_path_and_link[1] -> jumpnode
	# _jumplink_path_and_link[2] -> _shortest_node_path
	_path = Array(_jumplink_path_and_link[0]) # Vector3 array too complex to use, convert to regular array.
	_path.invert()
	_link_to_interact = _jumplink_path_and_link[1]
	set_process(true)


func _update_path(_target_position : Vector3) -> void:
	
	var p = _navigation.get_simple_path(global_transform.origin, _target_position, true)
	_path = Array(p)
	_path.invert()
	
	set_process(true)
	

func add_debug() -> void:
	
	var _draw_path_geometry = ImmediateGeometry3D.new()
	
	_draw_path_geometry.cast_shadow = false
	add_child(_draw_path_geometry)
	_draw_path_geometry.set_as_toplevel(true)
	_draw_path_geometry.global_transform = Transform()
	_draw_path_geometry.set_name("DrawMovementPath")
	_draw_path_geometry.add_to_group("jump_links_debug")
	_draw_path_geometry.set_material_override(load("res://addons/navigation_jump_links/debug/AgentPathDrawMaterial.tres"))
	_draw_path_geometry.visible = false

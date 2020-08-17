tool
extends Navigation

class_name JumpLinkNavigation, "res://addons/navigation_jump_links/icons/JumpLinkNavigation.png"

##############################################################################
### Extended Navigation node that creates the jumplink mapping at scene start
### It can replace default Navigation nodes completely
### JumpLinkAgent's internally call JumpLinkNavigation.get_jumplink_path() to aquire a jumplink path Array from this node
##############################################################################

export(bool) var draw_path = false
export(bool) var debug_print = false

var _building_navmesh_links : bool = false

var _navmesh_mappings : Dictionary = {
	"default" : {
			"node_edges" : {},
			"node_weights" : {},
			"navmesh_to_jumplink_start" : {},
			"navmesh_to_jumplink_end" : {},
			"navmesh_to_navmesh_jumplink_connections" : {},
			"node_path_mapping" : {}
		}
	}


func _ready() -> void:
	
	add_to_group("jump_link_navigations")

	### need to wait to idle frame so every jumplinkobject is ready inside scene no matter the child position
	call_deferred("build_navmesh_links")


func build_navmesh_links():
	
	_building_navmesh_links = true
	
	var _time : int = OS.get_system_time_msecs()
	
	var _all_jump_link_object_nodes : Array = get_tree().get_nodes_in_group("jump_link_objects")
	if not _all_jump_link_object_nodes:
		return
	var _all_jump_link_nodes : Array = get_tree().get_nodes_in_group("jump_links")
	if not _all_jump_link_nodes:
		return
		
	### get all the available navigation mesh children and map all possible combinations	
	var _navmeshes : Array = []
	var _navmesh_children = get_children()
	for _navmesh_child in _navmesh_children:
		if _navmesh_child.is_class("NavigationMeshInstance"):
			_navmeshes.append(_navmesh_child)
	
	### collect all agent tags found in the scene
	var _agent_tags : Array = []
	for _jump_link_object_node in _all_jump_link_object_nodes:
		var _required_tag : String = _jump_link_object_node.get_required_tag()
		if not _required_tag in _agent_tags and _required_tag != "":
			_agent_tags.append(_required_tag)
	
	### create dict structure for each agent tag found in the scene
	for _agent_tag in _agent_tags:
		_navmesh_mappings[_agent_tag] = {
			"node_edges" : {},
			"node_weights" : {},
			"navmesh_to_jumplink_start" : {},
			"navmesh_to_jumplink_end" : {},
			"navmesh_to_navmesh_jumplink_connections" : {},
			"node_path_mapping" : {}
		}
	
	### create a path mapping for each agent tag found in the scene
	for _mapping_tag in _navmesh_mappings.keys():
			
		### map jumplink jumping position and weights
		for _jump_link_object_node in _all_jump_link_object_nodes:
			
			var _jump_link_object_tag : String  = _jump_link_object_node.get_required_tag()
			
			var _jump_links : Array = _jump_link_object_node.get_jump_links()
	
			for _jump_link in _jump_links:
				
				var _start_pos_node : Spatial = _jump_link.get_jumping_position()
				var _end_pos_node : Spatial = _jump_link.get_landing_position()
				
				var _start_pos_node_navmesh : NavigationMeshInstance = get_closest_point_owner(_start_pos_node.global_transform.origin)
				if _start_pos_node.get_override_navmesh():
					_start_pos_node_navmesh = _start_pos_node.get_override_navmesh()
	
				var _end_pos_node_navmesh : NavigationMeshInstance = get_closest_point_owner(_end_pos_node.global_transform.origin)
				if _end_pos_node.get_override_navmesh():
					_end_pos_node_navmesh = _end_pos_node.get_override_navmesh()
				
				if _jump_link_object_tag == "" or _jump_link_object_tag == _mapping_tag:
					_add_node_edge(_mapping_tag, _start_pos_node, _end_pos_node)
					var _jumplink_connection = [_start_pos_node, _end_pos_node, _jump_link, _jump_link_object_node]
					_add_node_weight(_mapping_tag, _start_pos_node, _end_pos_node, _calc_jumplink_connection_cost(_jumplink_connection))
	
		### map jumplink nodes to navmeshes and reverse
		for _jump_link_object_node in _all_jump_link_object_nodes:
			
			var _jump_link_object_tag : String  = _jump_link_object_node.get_required_tag()
			
			var _jump_links : Array = _jump_link_object_node.get_jump_links()
			
			for _jump_link in _jump_links:
	
				var _start_pos_node : Spatial = _jump_link.get_jumping_position()
				var _end_pos_node : Spatial =_jump_link.get_landing_position()
				
				var _start_pos_node_navmesh : NavigationMeshInstance = get_closest_point_owner(_start_pos_node.global_transform.origin)
				if _start_pos_node.get_override_navmesh():
					_start_pos_node_navmesh = _start_pos_node.get_override_navmesh()
	
				var _end_pos_node_navmesh : NavigationMeshInstance = get_closest_point_owner(_end_pos_node.global_transform.origin)
				if _end_pos_node.get_override_navmesh():
					_end_pos_node_navmesh = _end_pos_node.get_override_navmesh()
				
				if not _start_pos_node_navmesh in _navmesh_mappings[_mapping_tag]["navmesh_to_jumplink_start"]:
					_navmesh_mappings[_mapping_tag]["navmesh_to_jumplink_start"][_start_pos_node_navmesh] = []
				if not _end_pos_node_navmesh in _navmesh_mappings[_mapping_tag]["navmesh_to_jumplink_end"]:
					_navmesh_mappings[_mapping_tag]["navmesh_to_jumplink_end"][_end_pos_node_navmesh] = []

				if _jump_link_object_tag == "" or _jump_link_object_tag == _mapping_tag:
						
					if not _start_pos_node in _navmesh_mappings[_mapping_tag]["navmesh_to_jumplink_start"][_start_pos_node_navmesh]:
						_navmesh_mappings[_mapping_tag]["navmesh_to_jumplink_start"][_start_pos_node_navmesh].append(_start_pos_node)
					if not _end_pos_node in _navmesh_mappings[_mapping_tag]["navmesh_to_jumplink_end"][_end_pos_node_navmesh]:
						_navmesh_mappings[_mapping_tag]["navmesh_to_jumplink_end"][_end_pos_node_navmesh].append(_end_pos_node)
	
	
		### map jumplink landing position and weights
		for _jump_link_object_node in _all_jump_link_object_nodes:
			
			var _jump_link_object_tag : String  = _jump_link_object_node.get_required_tag()
			
			var _jump_links : Array = _jump_link_object_node.get_jump_links()
			
			for _jump_link in _jump_links:
				
				var _start_pos_node : Spatial = _jump_link.get_jumping_position()
				var _end_pos_node : Spatial =_jump_link.get_landing_position()
				
				var _start_pos_node_navmesh : NavigationMeshInstance = get_closest_point_owner(_start_pos_node.global_transform.origin)
				if _start_pos_node.get_override_navmesh():
					_start_pos_node_navmesh = _start_pos_node.get_override_navmesh()
	
				var _end_pos_node_navmesh : NavigationMeshInstance = get_closest_point_owner(_end_pos_node.global_transform.origin)
				if _end_pos_node.get_override_navmesh():
					_end_pos_node_navmesh = _end_pos_node.get_override_navmesh()
				
				if _jump_link_object_tag == "" or _jump_link_object_tag == _mapping_tag:
						
					for _start_jumplink in _navmesh_mappings[_mapping_tag]["navmesh_to_jumplink_start"][_end_pos_node_navmesh]:
						_add_node_edge(_mapping_tag, _end_pos_node, _start_jumplink)
						var _path : PoolVector3Array = get_simple_path(_end_pos_node.global_transform.origin, _start_jumplink.global_transform.origin)
						_add_node_weight(_mapping_tag, _end_pos_node, _start_jumplink, _get_path_length(_path))
					
	
		### map jumplink nodepaths and calc costs (path len / timecost / weight)
	
		for _startnavmesh in _navmeshes:
			if not _startnavmesh in _navmesh_mappings[_mapping_tag]["node_path_mapping"]:
				_navmesh_mappings[_mapping_tag]["node_path_mapping"][_startnavmesh] = {}
			for _targetnavmesh in _navmeshes:
				#print("-------------------------")
				#print("Navmesh: %s -> %s" % [_startnavmesh.name, _targetnavmesh.name])
				if not _targetnavmesh in _navmesh_mappings[_mapping_tag]["node_path_mapping"][_startnavmesh]:
					_navmesh_mappings[_mapping_tag]["node_path_mapping"][_startnavmesh][_targetnavmesh] = {}
					
				for _start_jumplink in _navmesh_mappings[_mapping_tag]["navmesh_to_jumplink_start"][_startnavmesh]:

					if not _start_jumplink in _navmesh_mappings[_mapping_tag]["node_path_mapping"][_startnavmesh][_targetnavmesh]:
						_navmesh_mappings[_mapping_tag]["node_path_mapping"][_startnavmesh][_targetnavmesh][_start_jumplink] = {}
						
					for _end_jumplink in _navmesh_mappings[_mapping_tag]["navmesh_to_jumplink_end"][_targetnavmesh]:
						if not _end_jumplink in _navmesh_mappings[_mapping_tag]["node_path_mapping"][_startnavmesh][_targetnavmesh][_start_jumplink]:
							_navmesh_mappings[_mapping_tag]["node_path_mapping"][_startnavmesh][_targetnavmesh][_start_jumplink][_end_jumplink] = {}
						
						var _shortest_node_path : Array = _jumplink_dijsktra(_mapping_tag, _start_jumplink, _end_jumplink)
						_navmesh_mappings[_mapping_tag]["node_path_mapping"][_startnavmesh][_targetnavmesh][_start_jumplink][_end_jumplink]["nodepath"] = _shortest_node_path
						#print("Link: %s -> %s:" % [_start_jumplink, _end_jumplink])
						#print(_node_path_mapping[_startnavmesh][_targetnavmesh][_start_jumplink][_end_jumplink]["nodepath"])
						
						var _total_cost : float = 0.0
						var _inx : int = 0
						for _node in _shortest_node_path:
							if _inx + 1 < _shortest_node_path.size():
								_total_cost += _navmesh_mappings[_mapping_tag]["node_weights"][_shortest_node_path[_inx]][_shortest_node_path[_inx + 1]]
								_inx += 1
	
						_navmesh_mappings[_mapping_tag]["node_path_mapping"][_startnavmesh][_targetnavmesh][_start_jumplink][_end_jumplink]["pathcost"] = _total_cost
						#print("cost: %s" % _node_path_mapping[_startnavmesh][_targetnavmesh][_start_jumplink][_end_jumplink]["pathcost"])
						#print("-------------------------")

	if debug_print:
		_time = OS.get_system_time_msecs() - _time
		var _time_in_seconds : float = _time / 1000.0
		print("build_navmesh_links took '%s' secs to complete" % _time_in_seconds)
		
	_building_navmesh_links = false


func get_jumplink_path(_agent : Spatial, _target_pos : Vector3) -> Array:
	
	if _building_navmesh_links:
		### rebuilding maps and recalculating costs, meanwhile fall back to default pathfinding
		return [ get_simple_path(_agent.global_transform.origin, _target_pos), null ]
		
	var _agent_pos : Vector3 = _agent.global_transform.origin
	var _agent_pos_navmesh = get_closest_point_owner(_agent_pos)
	var _target_pos_navmesh = get_closest_point_owner(_target_pos)
	
	var _jumplink = null
	var _path : PoolVector3Array = []
	
	_path = get_simple_path(_agent_pos, _target_pos)
	var _path_len : float = _get_path_length(_path)
	
	var _shortest_node_path : Array = []
	var _shortest_node_path_cost : float = 1111111111.1
	
	var _agent_tags : Array = ["default"]
	_agent_tags += _agent.get_jumplink_tags()

	for _mapping_tag in _agent_tags:
		if not _mapping_tag in _navmesh_mappings:
			if OS.is_debug_build():
				print("warning - wrong agent tag - at least one agent uses tag '%s' which doesn't exist on any of the scenes jumplinks" % _mapping_tag)
			continue
		for _start_jumplink in _navmesh_mappings[_mapping_tag]["node_path_mapping"][_agent_pos_navmesh][_target_pos_navmesh].keys():
			
			### we use direct line distances instead of real pathlens for _agent->firstnode, lastnode->_target which is less accurate
			### reason is that get_simple_path() can sometimes return values that get agents stuck in a loop when developers use only one large navmesh
			
			var _agent_to_start_distance : float = _agent_pos.distance_to(_start_jumplink.global_transform.origin)
			
			for _end_jumplink in _navmesh_mappings[_mapping_tag]["node_path_mapping"][_agent_pos_navmesh][_target_pos_navmesh][_start_jumplink].keys():
				
				var _precalculated_pathcost : float = _navmesh_mappings[_mapping_tag]["node_path_mapping"][_agent_pos_navmesh][_target_pos_navmesh][_start_jumplink][_end_jumplink]["pathcost"]
				
				var _end_to_target_distance : float = _target_pos.distance_to(_end_jumplink.global_transform.origin)
				
				var _total_path_cost : float = _agent_to_start_distance + _precalculated_pathcost + _end_to_target_distance
				
				if _total_path_cost <  _shortest_node_path_cost:
					### update with our current pathcost winner
					_shortest_node_path_cost = _total_path_cost
					_shortest_node_path = _navmesh_mappings[_mapping_tag]["node_path_mapping"][_agent_pos_navmesh][_target_pos_navmesh][_start_jumplink][_end_jumplink]["nodepath"]
	
	if _shortest_node_path:
		if _agent_pos_navmesh != _target_pos_navmesh:
			_path = get_simple_path(_agent_pos, _shortest_node_path[0].global_transform.origin)
			_jumplink = _shortest_node_path[0]
		elif _shortest_node_path_cost < _path_len: ### we are on the same navmesh, see if we are still faster with links compared to walking
			_path = get_simple_path(_agent_pos, _shortest_node_path[0].global_transform.origin)
			_jumplink = _shortest_node_path[0]

	### make sure a duplicated nodepath Array is returned to protect the saved path ref in the dictionary from changes
	return [_path, _jumplink, _shortest_node_path.duplicate()]


func _get_path_length(_path : PoolVector3Array) -> float:
	
	var _sum : float = 0.0
	if _path.size() > 1:
		var _old_vector : Vector3 = _path[0]
		for vec3 in _path:
			var vec = vec3 - _old_vector
			_old_vector = vec3
			_sum += vec.length()
	
	return _sum


func _add_node_edge(_mapping_tag, from_node, to_node) -> void:

	if not from_node in _navmesh_mappings[_mapping_tag]["node_edges"]:
		_navmesh_mappings[_mapping_tag]["node_edges"][from_node] = []
	if not to_node in _navmesh_mappings[_mapping_tag]["node_edges"][from_node]:
		_navmesh_mappings[_mapping_tag]["node_edges"][from_node].append(to_node)


func _add_node_weight(_mapping_tag, from_node, to_node, node_weight) -> void:
	
	if not from_node in _navmesh_mappings[_mapping_tag]["node_weights"]:
		_navmesh_mappings[_mapping_tag]["node_weights"][from_node] = {}
	_navmesh_mappings[_mapping_tag]["node_weights"][from_node][to_node] = node_weight


func _jumplink_dijsktra(_mapping_tag, from_node : Spatial, to_node : Spatial) -> Array:
		
	var _shortest_node_paths : Dictionary = { from_node : [null, 0] }
	var _current_node : Spatial = from_node
	var _visited_nodes : Array = []
	
	while _current_node != to_node:

		_visited_nodes.append(_current_node)
		
		var destinations : Array = _navmesh_mappings[_mapping_tag]["node_edges"][_current_node]
		
		var weight_to_current_node = _shortest_node_paths[_current_node][1]
		var current_shortest_weight : float
		
		for next_node in destinations:
			
			var _weight = _navmesh_mappings[_mapping_tag]["node_weights"][_current_node][next_node] + weight_to_current_node
			
			if not next_node in _shortest_node_paths:
				_shortest_node_paths[next_node] = [_current_node, _weight]
			else:
				current_shortest_weight = _shortest_node_paths[next_node][1]
				if current_shortest_weight > _weight:
					_shortest_node_paths[next_node] = [_current_node, _weight]

		var next_destinations
		for node in _shortest_node_paths:
			if not node in _visited_nodes:
				next_destinations = { node: _shortest_node_paths[node] }
		
		if not next_destinations:
			print("no navmeshroute possible from '%s' to '%s'" % [from_node, to_node])
			return []
		# next node is the destination with the lowest weight
		var _smallest_weight : float = 1111111111.1
		var _smallest_node
		for k in next_destinations:
			if next_destinations[k][1] < _smallest_weight:
				_smallest_node = k
				_smallest_weight = next_destinations[k][1]
			
		_current_node = _smallest_node

	var _node_connection_path : Array = []
	var _next_node : Spatial
	
	while not _current_node == null:
		_node_connection_path.append(_current_node)
		_next_node = _shortest_node_paths[_current_node][0]
		_current_node = _next_node
	_node_connection_path.invert()
	
	return _node_connection_path
	

func _calc_jumplink_connection_cost(_jumplink_connection) -> float:
	# _jumplink_connection[0] -> _start_pos_node
	# _jumplink_connection[1] -> _end_pos_node
	# _jumplink_connection[2] -> _jump_link_node
	# _jumplink_connection[3] -> _jump_link_object_node
	var _distance : float = _jumplink_connection[0].global_transform.origin.distance_to(_jumplink_connection[1].global_transform.origin)
	var _timecost : float = _jumplink_connection[2].get_timecost()
	var _weight_cost : float = _jumplink_connection[3].get_weight_cost()
	
	return (_distance * _timecost) * _weight_cost

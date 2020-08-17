extends Position3D

class_name JumpLinkPosition, "res://addons/navigation_jump_links/icons/JumpLinkPosition.png"

##############################################################################
### Template positionmarker for a JumpLink's JumpingPosition or LandingPosition
##############################################################################

export(NodePath) var override_navmesh_path

var _override_navmesh : NavigationMeshInstance = null

func _ready():
	if override_navmesh_path:
		_override_navmesh = get_node(override_navmesh_path)


func get_override_navmesh():
	return _override_navmesh

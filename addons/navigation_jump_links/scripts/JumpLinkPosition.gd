
class_name JumpLinkPosition

extends Position3D

@icon("res://addons/navigation_jump_links/icons/JumpLinkPosition.png")

##############################################################################
### Template positionmarker for a JumpLink's JumpingPosition or LandingPosition
##############################################################################

@export var override_navmesh_path : NodePath

var _override_navmesh : NavigationRegion3D = null

func _ready():
	if override_navmesh_path:
		_override_navmesh = get_node(override_navmesh_path)


func get_override_navmesh():
	return _override_navmesh

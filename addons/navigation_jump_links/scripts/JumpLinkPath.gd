extends Path

class_name JumpLinkPath, "res://addons/navigation_jump_links/icons/JumpLinkPath.png"

##############################################################################
### Optional Path node with a Curve3D for Pathfollow support to customize jump trajectory
##############################################################################

func _enter_tree() -> void:
	_setup_curve()


func _ready() -> void:
	_setup_curve()


func _setup_curve() -> void:
	
	### create a new Curve3D resource if empty to prevent errors
	
	var _curve
	_curve = get_curve()
	
	if not _curve:
		var _new_curve = Curve3D.new()
		set_curve(_new_curve)
		
	_curve = get_curve()
	
	### make sure that jumppoint and landpoint are first and last index in curve if missing
	### also turn path enter and exit vectors towards the direction of the positions
	### everything else like additional pathpoints and curve handlers is up to designers
	
	var _link_jump_position = get_parent().get_jumping_position()
	var _link_land_position = get_parent().get_landing_position()
	
	if not _curve.get_point_position(0) == _link_jump_position.transform.origin:
		_curve.add_point(_link_jump_position.transform.origin, _link_jump_position.transform.basis.z, _link_jump_position.transform.basis.z, 0)
		
	if not _curve.get_point_position(_curve.get_point_count()-1) == _link_land_position.transform.origin:
		_curve.add_point(_link_land_position.transform.origin, -_link_land_position.transform.basis.z, -_link_land_position.transform.basis.z, -1)

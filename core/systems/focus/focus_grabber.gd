@tool
@icon("res://assets/editor-icons/center-focus-strong-sharp.svg")
extends BehaviorNode
class_name FocusGrabber

@export_category("Target")
## The target node to focus when the parent signal fires
@export var target: Control = get_parent()
## Whether or not to grab focus, even if there is a current focus node
@export var forced := false


## Fires when the given signal is emitted. This should be overriden in a child
## class.
func _on_signal(_arg1: Variant = null, _arg2: Variant = null, _arg3: Variant = null, _arg4: Variant = null):
	var current_focus := target.get_tree().get_root().gui_get_focus_owner()
	if not forced and current_focus:
		return
	target.grab_focus.call_deferred()

@tool
@icon("res://assets/editor-icons/special-effects-bold.svg")
extends BehaviorNode
class_name Effect

## Effects are UI functionality that can be attached to nodes and react to signals
##
## This class is meant to act as a base class for other effects. Effects listen
## for a given signal and perform some action when that signal is triggered.

## Emitted when the effect starts
signal effect_started
## Emitted when the effect finishes
signal effect_finished

func _init() -> void:
	ready.connect(_on_ready)


func _on_ready() -> void:
	notify_property_list_changed()
	if Engine.is_editor_hint():
		return
	if on_signal != "":
		get_parent().connect(on_signal, _on_signal)


## Invoked whenever the configured parent signal fires. This should be overridden
## in a child class.
func _on_signal(_arg1: Variant = null, _arg2: Variant = null, _arg3: Variant = null, _arg4: Variant = null):
	pass


# Customize editor properties that we expose. Here we dynamically look up
# the parent node's signals so we can display them in a list.
func _get_property_list():
	# By default, `on_signal` is not visible in the editor.
	var property_usage := PROPERTY_USAGE_NO_EDITOR

	var parent_signals := []
	if get_parent() != null:
		property_usage = PROPERTY_USAGE_DEFAULT
		for sig in get_parent().get_signal_list():
			parent_signals.push_back(sig["name"])

	var properties := []
	properties.append(
			{
				"name": "on_signal",
				"type": TYPE_STRING,
				"usage": property_usage,  # See above assignment.
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": ",".join(parent_signals)
			}
	)

	return properties

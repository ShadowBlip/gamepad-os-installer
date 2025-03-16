@tool
@icon("res://assets/editor-icons/transition-right.svg")
extends BehaviorNode
class_name StateUpdater

## Update the state of a state machine when a signal fires
##
## The [StateUpdater] can be added as a child to any node that exposes signals.
## Upon entering the scene tree, the [StateUpdater] connects to a given signal
## on its parent, and will update the configured state machine's state to the
## given state, allowing menus to react to state changes (e.g. changing menus)

## Possible state actions to take
enum ACTION {
	PUSH, ## Pushes the state on top of the state stack
	POP, ## Removes the state at the top of the state stack
	REPLACE, ## Replaces the state at the top of the state stack
	SET, ## Removes all states and sets the given state
}

## The state machine instance to use for managing state changes
@export var state_machine: StateMachine
## The state to change to when the given signal is emitted.
@export var state: State
## Whether to push, pop, replace, or set the state when the signal has fired.
@export var action: ACTION = ACTION.PUSH


func _on_signal(_arg1: Variant = null, _arg2: Variant = null, _arg3: Variant = null, _arg4: Variant = null):
	# Switch to the given state
	var sm := state_machine as StateMachine

	# Manage the state based on the given action
	match action:
		ACTION.PUSH:
			sm.push_state(state)
		ACTION.POP:
			# Only pop the stack when no dialogs are showing
			var popups := get_tree().get_nodes_in_group("popup")
			for popup in popups:
				if (popup as Control).is_visible_in_tree():
					return
			
			# Never pop the last item in the stack
			if sm.stack_length() > 1:
				sm.pop_state()
		ACTION.REPLACE:
			sm.replace_state(state)
		ACTION.SET:
			var states := [state] as Array[State]
			sm.set_state(states)

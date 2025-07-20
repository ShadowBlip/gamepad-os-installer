extends Control

var state_machine := load("res://core/ui/menus/global_state_machine.tres") as StateMachine
var install_state := load("res://core/ui/menus/install_progress_state.tres") as State

@onready var tree := %Tree as Tree
@onready var next_button := %NextButton as Button


## Sets the installer to use
func set_installer(installer: Installer) -> void:
	# Listen for next button pressed
	next_button.button_up.connect(_on_next_pressed)

	# Only enable the next button when an item is selected
	var on_selected := func():
		next_button.disabled = false
	tree.item_selected.connect(on_selected)

	# Configure the tree view
	var root := tree.create_item() as TreeItem
	var columns := PackedStringArray(["Name", "Model", "Size"])
	for i in range(columns.size()):
		var column_name := columns[i]
		tree.set_column_title(i, column_name)
		tree.set_column_title_alignment(i, HORIZONTAL_ALIGNMENT_LEFT)

	var disks := installer.get_available_disks()
	for disk in disks:
		var disk_item := root.create_child()
		disk_item.set_text(0, disk.name)
		disk_item.set_text(1, disk.model)
		disk_item.set_text(2, disk.size)
		disk_item.set_metadata(0, disk)


## Invoked when the Next button is pressed
func _on_next_pressed() -> void:
	var item := tree.get_selected() as TreeItem
	if not item:
		push_warning("No item was selected!")
		return
	
	# Get the disk from the selected tree item
	var disk := item.get_metadata(0) as Installer.Disk
	print("Selected disk: " + disk.path)

	# Check if the given disk already has an installation or not
	var dialog := get_tree().get_first_node_in_group("dialog") as Dialog
	if disk.install_found:
		var msg := "WARNING: " + disk.name + " appears to have another system deployed, " + \
			"would you like to repair the install?"
		dialog.open(msg, "Yes", "No")
		var should_repair := await dialog.choice_selected as bool
		
		# TODO: Implement repair
		if should_repair:
			return

	# Warn the user before bootstrapping
	var msg := "WARNING: " + disk.name + " will now be formatted. All data on the disk will be lost." + \
		" Do you wish to proceed?"
	dialog.open(msg, "No", "Yes")
	var should_stop := await dialog.choice_selected as bool
	if should_stop:
		next_button.grab_focus.call_deferred()
		return

	# Start the installation
	var options := install_state.get_meta("options") as Installer.Options
	options.target_disk = disk
	state_machine.set_state([install_state])

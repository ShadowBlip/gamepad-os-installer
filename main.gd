extends Control

@export var installer: Installer
@export var dry_run: bool

@onready var dialog := %Dialog as Dialog
@onready var progress_dialog := %ProgressDialog as ProgressDialog
@onready var disk_menu := %DiskSelectMenu
@onready var install_menu := %InstallProgressMenu
@onready var logo := %Logo as TextureRect


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Allow the installer to add Godot nodes to the scene tree
	installer.child_added.connect(_on_child_added)
	installer.child_removed.connect(_on_child_removed)
	installer.dry_run = dry_run

	# Configure the interface for the installer
	var config := installer.get_configuration()
	if config:
		if config.logo:
			logo.texture = config.logo
		if config.theme:
			self.theme = config.theme

	# Set the installer logic to use
	disk_menu.set_installer(installer)
	install_menu.set_installer(installer, dry_run)

	# Run the installer
	run()


## Run the installer
func run():
	if not DirAccess.dir_exists_absolute("/sys/firmware/efi/efivars"):
		var msg := "Legacy BIOS installs are not supported. You must boot the installer in UEFI mode.\n\n" + \
			"Would you like to restart the computer now?"
		dialog.open(msg, "Yes", "No")
		var should_reboot := await dialog.choice_selected as bool
		
		if should_reboot:
			OS.execute("reboot", [])
			return
		
		get_tree().quit(1)
		return

	if installer.get_available_disks().size() == 0:
		var msg := "No available disks were detected. Unable to proceed with installation.\n\n" + \
			"Would you like to restart the computer now?"
		dialog.open(msg, "OK", "Cancel")
		var should_reboot := await dialog.choice_selected as bool
		
		if should_reboot:
			OS.execute("reboot", [])
			return

		get_tree().quit(1)
		return


func _on_child_added(node: Node) -> void:
	add_child(node)


func _on_child_removed(node: Node) -> void:
	remove_child(node)

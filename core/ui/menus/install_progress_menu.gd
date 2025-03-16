extends Control

var install_state := load("res://core/ui/menus/install_progress_state.tres") as State

var _installer: Installer
var _dry_run: bool

@onready var progress_bar := %ProgressBar as ProgressBar
@onready var status_label := %StatusLabel as Label
@onready var tab_container := %TabContainer as TabContainer
@onready var log := %LogText as RichTextLabel


func _ready() -> void:
	install_state.state_entered.connect(_on_state_entered)


func set_installer(installer: Installer, dry_run: bool = false) -> void:
	installer.install_progressed.connect(_on_install_progressed)
	installer.install_completed.connect(_on_install_completed)
	installer.install_stage_started.connect(_on_install_stage_started)
	installer.log_written.connect(_on_log_written)
	_installer = installer
	_dry_run = dry_run


func _on_state_entered(_from: State) -> void:
	if not _installer:
		push_error("No installer implementation selected!")
		return
	if not install_state.has_meta("disk"):
		push_error("No `Disk` was found in state metadata!")
		return
	var disk := install_state.get_meta("disk") as Installer.Disk
	print("Starting installation to disk: ", disk.path)
	_installer.install(disk, _dry_run)


func _on_install_progressed(percent: float) -> void:
	progress_bar.value = percent


func _on_install_stage_started(stage: String) -> void:
	status_label.text = stage


func _on_log_written(text: String) -> void:
	log.text += text


func _on_install_completed(status: Installer.STATUS, error: String) -> void:
	var dialog := get_tree().get_first_node_in_group("dialog") as Dialog
	await get_tree().create_timer(1.0).timeout
	match status:
		Installer.STATUS.OK:
			status_label.text = "Installation completed successfully"
			progress_bar.value = 100
			dialog.open("Installation is complete. Reboot?" + error, "OK", "Cancel")
			var should_reboot := await dialog.choice_selected as bool
			if should_reboot:
				OS.execute("sudo", ["reboot"])
		Installer.STATUS.FAILED:
			status_label.text = "Installation failed"
			dialog.open("Installation failed with error:\n\n" + error, "OK", "", false)
			await dialog.choice_selected
			dialog.open("Reboot?", "OK", "Cancel")
			var should_reboot := await dialog.choice_selected as bool
			if should_reboot:
				OS.execute("sudo", ["reboot"])

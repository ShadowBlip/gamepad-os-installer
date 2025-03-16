extends Control

var network_manager := load("res://core/systems/network/network_manager.tres") as NetworkManagerInstance

@onready var status_label := %StatusLabel as Label
@onready var next_button := %NextButton as Button
@onready var wifi_tree := %WifiNetworkTree as WifiNetworkTree


func _ready() -> void:
	# Listen for connectivity changes
	network_manager.connectivity_changed.connect(_on_connectivity_changed)
	_on_connectivity_changed(network_manager.connectivity)

	# Check to see if a wifi challenge is required
	wifi_tree.challenge_required.connect(_on_challenge_required)


func _on_connectivity_changed(status: int) -> void:
	print("Network connectivity: " + str(status))
	match status:
		network_manager.NM_CONNECTIVITY_FULL:
			next_button.disabled = false
			status_label.text = "Connected to the internet"
		network_manager.NM_CONNECTIVITY_LIMITED:
			next_button.disabled = false
			status_label.text = "Limited network connectivity. Connect to a network:"
		network_manager.NM_CONNECTIVITY_PORTAL:
			next_button.disabled = true
			status_label.text = "Portal access points not supported. Connect to a network:"
		network_manager.NM_CONNECTIVITY_NONE:
			next_button.disabled = true
			status_label.text = "Connect to a network:"
		network_manager.NM_CONNECTIVITY_UNKNOWN:
			next_button.disabled = true
			status_label.text = "Unknown connectivity. Connect to a network:"


func _on_challenge_required(callback: Callable) -> void:
	var dialog := get_tree().get_first_node_in_group("password")
	if not dialog or not dialog is PasswordDialog:
		push_warning("No password dialog was found!")
		return
	var password_dialog := dialog as PasswordDialog
	password_dialog.open("Enter this wireless network's password")
	var result = await password_dialog.choice_selected
	if not result is Array or (result as Array).is_empty():
		push_warning("Failed to get signal results")
		return
	var accepted := result[0] as bool
	var password := result[1] as String

	if not accepted:
		wifi_tree.grab_focus.call_deferred()
		return

	callback.call(password)

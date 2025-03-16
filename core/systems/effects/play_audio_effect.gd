@tool
extends Effect
class_name PlayAudioEffect

@export_category("AudioSteamPlayer")
@export_file("*.ogg") var audio

var stream = load(audio)

@onready var audio_player := $AudioStreamPlayer as AudioStreamPlayer


func _ready() -> void:
	var on_finished := func():
		effect_finished.emit()
	audio_player.finished.connect(on_finished)


# Fires when the given signal is emitted
func _on_signal(_arg1: Variant = null, _arg2: Variant = null, _arg3: Variant = null, _arg4: Variant = null):
	play_sound()


func play_sound() -> void:
	audio_player.stream = stream
	audio_player.play()

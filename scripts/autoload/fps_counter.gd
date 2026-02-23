extends CanvasLayer

@onready var label: Label = $FPSLabel

var frame_count: int = 0
var time_elapsed: float = 0.0
var fps: int = 0

func _ready() -> void:
	label.text = "FPS: 0"

func _process(delta: float) -> void:
	time_elapsed += delta
	frame_count += 1

	if time_elapsed >= 0.1:  # Update every 0.1 seconds
		fps = int(frame_count / time_elapsed)
		label.text = "FPS: %d" % fps
		frame_count = 0
		time_elapsed = 0.0

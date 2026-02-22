class_name AudioEntry
extends Resource

## Single audio file configuration entry

@export var name: String = ""  ## Descriptive name (e.g., "MENU_HOVER", "FOOTSTEP_WOOD_1")
@export_file("*.ogg", "*.wav", "*.mp3") var path: String = ""
@export var volume_db: float = 0.0
@export var max_distance: float = 20.0  ## For 3D spatial audio only
@export_enum("Master", "Music", "SFX", "Voice") var bus: String = "Master"
@export_range(0.1, 3.0, 0.1) var pitch_scale: float = 1.0
@export var preload_on_startup: bool = false  ## Preload for frequently used audio
@export var spatial: bool = false  ## true = AudioStreamPlayer3D, false = AudioStreamPlayer

class_name AudioConfig
extends Resource

## Configuration Resource for centralized audio management.
## Holds all audio file paths and playback settings.
## Edit audio_config.tres in the Inspector to modify settings.

@export var entries: Dictionary = {}  ## AudioID (int) -> AudioEntry

extends Node

## LocaleManager — two independent localisation layers.
##
## game language   (setting key: "general/language")
##   Controls all in-scene UI text: mission statements, Noé prompt subtitles, etc.
##   Accessed via LocaleManager.g("key").
##
## subtitle language   (setting key: "subtitles/language")
##   Controls every timed, audio-synced subtitle array.
##   Accessed via LocaleManager.s("content_id").
##
## Both fall back to "en" if the requested locale file is missing.
## SettingsManager.settings_changed is monitored; changing either language setting
## at runtime reloads the corresponding data immediately.

signal game_language_changed(lang_code: String)
signal subtitle_language_changed(lang_code: String)

const _GAME_LOCALE_PATH:     String = "res://resources/locale/game/%s.json"
const _SUBTITLE_LOCALE_PATH: String = "res://resources/locale/subtitles/%s.json"

var _game_strings:  Dictionary = {}
var _subtitle_data: Dictionary = {}
var _game_lang:     String = "en"
var _subtitle_lang: String = "en"


func _ready() -> void:
	var raw_game: Variant = SettingsManager.get_setting("general/language")
	var raw_sub:  Variant = SettingsManager.get_setting("subtitles/language")
	_reload_game_language(raw_game as String if raw_game is String else "en")
	_reload_subtitle_language(raw_sub as String if raw_sub is String else "en")
	SettingsManager.settings_changed.connect(_on_settings_changed)


## Returns the game-language string for [param key].
## Falls back to "[[key]]" so missing translations are immediately visible in-game.
func g(key: String) -> String:
	return _game_strings.get(key, "[[%s]]" % key) as String


## Returns the typed subtitle array for [param content_id].
## Each element is a Dictionary with keys: start (float), end (float), text (String).
func s(content_id: String) -> Array[Dictionary]:
	var raw: Variant = _subtitle_data.get(content_id, [])
	if not raw is Array:
		push_warning("LocaleManager: '%s' is not an array in subtitle locale." % content_id)
		return []
	var result: Array[Dictionary] = []
	result.assign(raw)
	return result


# --- Private ---

func _reload_game_language(lang_code: String) -> void:
	if lang_code.is_empty():
		lang_code = "en"
	var data: Dictionary = _load_json(_GAME_LOCALE_PATH % lang_code)
	if data.is_empty() and lang_code != "en":
		push_warning("LocaleManager: no game locale for '%s', falling back to 'en'." % lang_code)
		data = _load_json(_GAME_LOCALE_PATH % "en")
	_game_strings = data
	_game_lang = lang_code
	game_language_changed.emit(lang_code)


func _reload_subtitle_language(lang_code: String) -> void:
	if lang_code.is_empty():
		lang_code = "en"
	var data: Dictionary = _load_json(_SUBTITLE_LOCALE_PATH % lang_code)
	if data.is_empty() and lang_code != "en":
		push_warning("LocaleManager: no subtitle locale for '%s', falling back to 'en'." % lang_code)
		data = _load_json(_SUBTITLE_LOCALE_PATH % "en")
	_subtitle_data = data
	_subtitle_lang = lang_code
	subtitle_language_changed.emit(lang_code)


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("LocaleManager: locale file not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("LocaleManager: cannot open: %s" % path)
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_warning("LocaleManager: failed to parse JSON at: %s" % path)
		return {}
	return parsed as Dictionary


func _on_settings_changed() -> void:
	var new_game: Variant = SettingsManager.get_setting("general/language")
	var new_sub:  Variant = SettingsManager.get_setting("subtitles/language")
	var new_game_str: String = new_game as String if new_game is String else "en"
	var new_sub_str:  String = new_sub  as String if new_sub  is String else "en"
	if new_game_str != _game_lang:
		_reload_game_language(new_game_str)
	if new_sub_str != _subtitle_lang:
		_reload_subtitle_language(new_sub_str)

class_name PauseMenu
extends CanvasLayer

## In-game pause overlay.
## Instantiated lazily by GameManager on the first Escape press.
## Renders above subtitles (128) and below the scene transition fade (200).

signal resume_requested

# Fonts
var _fjalla: Font = preload("res://assets/fonts/fjalla_one.ttf")
var _roboto: Font = preload("res://assets/fonts/roboto_condensed_medium.ttf")

# UI references — populated by _build_ui()
var _bg: ColorRect = null
var _vbox: VBoxContainer = null
var _resume_btn: Button = null
var _settings_btn: Button = null
var _hover_panels: Dictionary = {}
var _hover_tweens: Dictionary = {}
var _settings_overlay: Control = null

# Prevents re-triggering during 0.2s fade-in / 0.15s fade-out animations.
var _busy: bool = false


func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()
	LocaleManager.game_language_changed.connect(_on_language_changed)


# ---------------------------------------------------------------------------
# UI Construction — no async, all synchronous
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# Full-screen darkening overlay.  Starts transparent; animated on open.
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.0, 0.0, 0.0, 0.0)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	# Menu container — left-anchored, mirrors main menu position.
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 12)
	_vbox.set_anchor(SIDE_LEFT, 0.0)
	_vbox.set_anchor(SIDE_TOP, 0.0)
	_vbox.set_anchor(SIDE_RIGHT, 1.0)
	_vbox.set_anchor(SIDE_BOTTOM, 1.0)
	_vbox.set_offset(SIDE_LEFT, 240.0)
	_vbox.set_offset(SIDE_TOP, 365.0)
	_vbox.set_offset(SIDE_RIGHT, 0.0)
	_vbox.set_offset(SIDE_BOTTOM, 0.0)
	add_child(_vbox)

	# Title
	var title := Label.new()
	title.text = "SVEN KILLER DEMO"
	var ts := LabelSettings.new()
	ts.font = _fjalla
	ts.font_size = 100
	ts.font_color = Color(0.98, 0.98, 0.98, 1.0)
	ts.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	ts.shadow_offset = Vector2(5.0, 5.0)
	ts.outline_color = Color(0.0, 0.0, 0.0, 0.28)
	ts.outline_size = 3
	title.label_settings = ts
	_vbox.add_child(title)

	# Spacer between title and buttons
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 20.0)
	_vbox.add_child(spacer)

	# Buttons
	_resume_btn = _make_button(LocaleManager.g("ui_resume"))
	_settings_btn = _make_button(LocaleManager.g("ui_settings_btn"))
	_vbox.add_child(_resume_btn)
	_vbox.add_child(_settings_btn)

	# Insert a hover-highlight panel before each button (identical to main_menu.gd pattern).
	# Panels render behind their button via z-order; positions are set after layout in animate_in.
	for btn: Button in [_resume_btn, _settings_btn]:
		var panel := Panel.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.1, 0.0)
		panel.add_theme_stylebox_override("panel", style)
		_vbox.add_child(panel)
		_vbox.move_child(panel, btn.get_index())
		_hover_panels[btn] = panel
		btn.mouse_entered.connect(_on_btn_hover.bind(btn))
		btn.mouse_exited.connect(_on_btn_unhover.bind(btn))

	_resume_btn.pressed.connect(_on_resume_pressed)
	_settings_btn.pressed.connect(_on_settings_pressed)


func _make_button(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.add_theme_font_override("font", _roboto)
	btn.add_theme_font_size_override("font_size", 34)
	btn.clip_text = false
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_color_override("font_color",         Color(0.98, 0.98, 0.98, 1.0))
	btn.add_theme_color_override("font_hover_color",   Color(0.98, 0.98, 0.98, 1.0))
	btn.add_theme_color_override("font_focus_color",   Color(0.98, 0.98, 0.98, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.98, 0.98, 0.98, 1.0))
	btn.add_theme_color_override("font_shadow_color",  Color(0.0, 0.0, 0.0, 0.8))
	btn.add_theme_constant_override("shadow_offset_x", 8)
	btn.add_theme_constant_override("shadow_offset_y", 8)
	btn.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.0))
	btn.add_theme_constant_override("outline_size", 0)
	return btn


func _update_hover_panels() -> void:
	for btn: Button in _hover_panels.keys():
		var panel: Panel = _hover_panels[btn]
		panel.position = btn.position - Vector2(10.0, 4.0)
		panel.size    = btn.size    + Vector2(20.0, 8.0)


# ---------------------------------------------------------------------------
# Animation
# ---------------------------------------------------------------------------

func animate_in() -> void:
	_busy = true
	visible = true
	_vbox.modulate.a = 0.0
	_bg.color.a = 0.0

	# Wait one frame so VBoxContainer computes button positions before we overlay panels.
	await get_tree().process_frame
	_update_hover_panels()

	var tw := create_tween().set_parallel(true)
	tw.tween_property(_vbox, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(_bg, "color:a", 0.82, 0.2).set_ease(Tween.EASE_OUT)
	await tw.finished
	_busy = false


func animate_out() -> void:
	_busy = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_vbox, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
	tw.tween_property(_bg, "color:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
	await tw.finished
	visible = false
	_busy = false


func force_hide() -> void:
	## Instantly hide with no animation — called during scene transitions.
	if _settings_overlay != null and is_instance_valid(_settings_overlay):
		_settings_overlay.queue_free()
		_settings_overlay = null
	if _resume_btn:
		_resume_btn.disabled = false
	if _settings_btn:
		_settings_btn.disabled = false
	if _vbox:
		_vbox.modulate.a = 1.0
	_bg.color.a = 0.82
	visible = false
	_busy = false


# ---------------------------------------------------------------------------
# Input — Escape closes the pause menu
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _busy:
		return
	# When the settings overlay is open, let it handle its own Escape.
	if _settings_overlay != null and is_instance_valid(_settings_overlay):
		return
	if event.is_action_pressed("pause") or (event is InputEventKey and event.keycode == KEY_K and event.pressed and not event.echo):
		get_viewport().set_input_as_handled()
		_on_resume_pressed()


# ---------------------------------------------------------------------------
# Hover highlight animations
# ---------------------------------------------------------------------------

func _on_btn_hover(btn: Button) -> void:
	AudioManager.play_sfx(AudioManager.AudioID.MENU_HOVER, linear_to_db(0.35))
	if _hover_tweens.has(btn) and is_instance_valid(_hover_tweens[btn]):
		_hover_tweens[btn].kill()
	var panel: Panel = _hover_panels[btn]
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		var tw := create_tween()
		tw.tween_property(style, "bg_color:a", 0.45, 0.15).set_ease(Tween.EASE_OUT)
		_hover_tweens[btn] = tw


func _on_btn_unhover(btn: Button) -> void:
	if _hover_tweens.has(btn) and is_instance_valid(_hover_tweens[btn]):
		_hover_tweens[btn].kill()
	var panel: Panel = _hover_panels[btn]
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		var tw := create_tween()
		tw.tween_property(style, "bg_color:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
		_hover_tweens[btn] = tw


# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

func _on_resume_pressed() -> void:
	AudioManager.play_sfx(AudioManager.AudioID.MENU_CLICK, -13.5)
	resume_requested.emit()


func _on_settings_pressed() -> void:
	AudioManager.play_sfx(AudioManager.AudioID.MENU_CLICK, -13.5)
	if _settings_overlay != null and is_instance_valid(_settings_overlay):
		return
	_resume_btn.disabled = true
	_settings_btn.disabled = true
	var packed: PackedScene = load("res://scenes/ui/settings_menu.tscn")
	if not packed:
		push_error("PauseMenu: could not load settings_menu.tscn")
		_resume_btn.disabled = false
		_settings_btn.disabled = false
		return
	_settings_overlay = packed.instantiate() as Control
	add_child(_settings_overlay)
	_settings_overlay.closed.connect(_on_settings_closed, CONNECT_ONE_SHOT)


func _on_settings_closed() -> void:
	_settings_overlay = null
	_resume_btn.disabled = false
	_settings_btn.disabled = false


func _on_language_changed(_lang_code: String) -> void:
	if _resume_btn:
		_resume_btn.text = LocaleManager.g("ui_resume")
	if _settings_btn:
		_settings_btn.text = LocaleManager.g("ui_settings_btn")

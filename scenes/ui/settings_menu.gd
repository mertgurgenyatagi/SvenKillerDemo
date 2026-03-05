extends Control

## Settings menu overlay — built programmatically to match cinematic aesthetic.

signal closed

# Fonts
var roboto_font: Font = preload("res://assets/fonts/roboto_condensed_medium.ttf")
var roboto_regular: Font = preload("res://assets/fonts/roboto_condensed.ttf")
var fjalla_font: Font = preload("res://assets/fonts/fjalla_one.ttf")

# Tab state
var current_tab: int = 0
var tab_buttons: Array[Button] = []
var content_container: VBoxContainer = null
var _controls: Dictionary = {}

# Stored label nodes for live language refresh
var _header_title: Label = null
var _reset_btn: Button = null
var _back_btn: Button = null

# Constants
const PANEL_WIDTH: int = 920
const PANEL_HEIGHT: int = 580


func _ready() -> void:
	_build_ui()
	_switch_tab(0)
	LocaleManager.game_language_changed.connect(_on_language_changed)

	# Fade in
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)


func _get_tab_labels() -> Array[String]:
	return [
		LocaleManager.g("ui_tab_general"),
		LocaleManager.g("ui_tab_video"),
		LocaleManager.g("ui_tab_graphics"),
		LocaleManager.g("ui_tab_audio"),
		LocaleManager.g("ui_tab_subtitles"),
	]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or (event is InputEventKey and event.keycode == KEY_K and event.pressed and not event.echo):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


# --- UI Construction ---

func _build_ui() -> void:
	# Dim background
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	# Main panel
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-PANEL_WIDTH / 2.0, -PANEL_HEIGHT / 2.0)
	panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.06, 0.08, 0.95)
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_color = Color(0.25, 0.25, 0.28, 0.5)
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	# Root vertical layout inside panel
	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 12)
	panel.add_child(root_vbox)

	# Header row
	_build_header(root_vbox)

	# Separator
	var sep1: HSeparator = HSeparator.new()
	sep1.add_theme_stylebox_override("separator", _create_separator_style())
	root_vbox.add_child(sep1)

	# Content row (tabs + settings)
	var content_row: HBoxContainer = HBoxContainer.new()
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 16)
	root_vbox.add_child(content_row)

	# Tab sidebar
	_build_tab_sidebar(content_row)

	# Vertical separator
	var vsep: VSeparator = VSeparator.new()
	vsep.add_theme_stylebox_override("separator", _create_separator_style())
	content_row.add_child(vsep)

	# Content area
	var content_scroll: ScrollContainer = ScrollContainer.new()
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_row.add_child(content_scroll)

	content_container = VBoxContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_theme_constant_override("separation", 16)
	content_scroll.add_child(content_container)

	# Bottom separator
	var sep2: HSeparator = HSeparator.new()
	sep2.add_theme_stylebox_override("separator", _create_separator_style())
	root_vbox.add_child(sep2)

	# Footer row
	_build_footer(root_vbox)


func _build_header(parent: VBoxContainer) -> void:
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	parent.add_child(header)

	var title: Label = Label.new()
	var title_settings: LabelSettings = LabelSettings.new()
	title_settings.font = fjalla_font
	title_settings.font_size = 42
	title_settings.font_color = Color(0.95, 0.95, 0.95, 1.0)
	title_settings.shadow_color = Color(0, 0, 0, 0.4)
	title_settings.shadow_offset = Vector2(2, 2)
	title.label_settings = title_settings
	title.text = LocaleManager.g("ui_settings")
	_header_title = title
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn: Button = Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.add_theme_font_override("font", roboto_font)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	close_btn.add_theme_color_override("font_hover_color", Color(0.95, 0.95, 0.95, 1.0))
	close_btn.mouse_entered.connect(_on_button_hover)
	close_btn.pressed.connect(_on_button_pressed)
	close_btn.pressed.connect(_on_back_pressed)
	header.add_child(close_btn)


func _build_tab_sidebar(parent: HBoxContainer) -> void:
	var sidebar: VBoxContainer = VBoxContainer.new()
	sidebar.custom_minimum_size.x = 170
	sidebar.add_theme_constant_override("separation", 4)
	parent.add_child(sidebar)

	var tab_labels := _get_tab_labels()
	for i in tab_labels.size():
		var btn: Button = Button.new()
		btn.text = tab_labels[i]
		btn.flat = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_font_override("font", roboto_font)
		btn.add_theme_font_size_override("font_size", 20)
		btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(0.85, 0.85, 0.85, 1.0))
		btn.add_theme_color_override("font_pressed_color", Color(0.95, 0.95, 0.95, 1.0))

		# Style for normal state (transparent bg)
		var normal_style: StyleBoxFlat = StyleBoxFlat.new()
		normal_style.bg_color = Color(0, 0, 0, 0)
		normal_style.content_margin_left = 12
		normal_style.content_margin_right = 12
		normal_style.content_margin_top = 8
		normal_style.content_margin_bottom = 8
		btn.add_theme_stylebox_override("normal", normal_style)
		btn.add_theme_stylebox_override("hover", normal_style.duplicate())
		btn.add_theme_stylebox_override("pressed", normal_style.duplicate())
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

		btn.mouse_entered.connect(_on_button_hover)
		btn.pressed.connect(_on_button_pressed)
		btn.pressed.connect(_switch_tab.bind(i))
		sidebar.add_child(btn)
		tab_buttons.append(btn)


func _build_footer(parent: VBoxContainer) -> void:
	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	parent.add_child(footer)

	_reset_btn = _create_footer_button(LocaleManager.g("ui_reset_defaults"))
	_reset_btn.pressed.connect(_on_reset_defaults_pressed)
	footer.add_child(_reset_btn)

	# Spacer
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	_back_btn = _create_footer_button(LocaleManager.g("ui_back"))
	_back_btn.pressed.connect(_on_back_pressed)
	footer.add_child(_back_btn)


func _create_footer_button(text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.flat = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_override("font", roboto_font)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.95, 0.95, 0.95, 1.0))

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.6)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", style)

	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = Color(0.18, 0.18, 0.22, 0.8)
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.mouse_entered.connect(_on_button_hover)
	btn.pressed.connect(_on_button_pressed)
	return btn


# --- Tab Switching ---

func _switch_tab(index: int) -> void:
	current_tab = index
	_update_tab_visuals()

	# Clear content
	for child in content_container.get_children():
		child.queue_free()
	_controls.clear()

	# Rebuild after clearing
	await get_tree().process_frame

	match index:
		0: _build_general_tab()
		1: _build_video_tab()
		2: _build_graphics_tab()
		3: _build_audio_tab()
		4: _build_subtitles_tab()

	_load_current_values()


func _update_tab_visuals() -> void:
	for i in tab_buttons.size():
		var btn: Button = tab_buttons[i]
		var style: StyleBoxFlat = btn.get_theme_stylebox("normal") as StyleBoxFlat
		if i == current_tab:
			btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1.0))
			style.border_width_left = 2
			style.border_color = Color(0.7, 0.7, 0.7, 0.8)
			style.bg_color = Color(0.1, 0.1, 0.12, 0.4)
		else:
			btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
			style.border_width_left = 0
			style.bg_color = Color(0, 0, 0, 0)


# --- Tab Builders ---

func _build_general_tab() -> void:
	_add_option_row(LocaleManager.g("setting_language"), "general/language",
		SettingsManager.LANGUAGE_LABELS, SettingsManager.LANGUAGE_CODES)


func _build_video_tab() -> void:
	_add_option_row(LocaleManager.g("setting_display_mode"), "video/display_mode",
		[LocaleManager.g("opt_fullscreen"), LocaleManager.g("opt_windowed"), LocaleManager.g("opt_borderless_windowed")],
		SettingsManager.DISPLAY_MODE_VALUES)
	_add_option_row(LocaleManager.g("setting_resolution"), "video/resolution_index",
		SettingsManager.RESOLUTION_LABELS)
	_add_toggle_row(LocaleManager.g("setting_vsync"), "video/vsync")
	_add_option_row(LocaleManager.g("setting_fps_limit"), "video/fps_limit",
		[LocaleManager.g("opt_fps_unlimited"), "30", "60", "120", "144", "240"],
		SettingsManager.FPS_LIMIT_OPTIONS)
	_add_slider_row(LocaleManager.g("setting_brightness"), "video/brightness", 0.5, 1.5, 0.05)


func _build_graphics_tab() -> void:
	_add_option_row(LocaleManager.g("setting_anti_aliasing"), "graphics/anti_aliasing",
		[LocaleManager.g("opt_aa_off"), LocaleManager.g("opt_fxaa"),
		LocaleManager.g("opt_msaa_2x"), LocaleManager.g("opt_msaa_4x"), LocaleManager.g("opt_msaa_8x")])


func _build_audio_tab() -> void:
	_add_slider_row(LocaleManager.g("setting_master_volume"), "audio/master_volume", 0.0, 1.0, 0.01, true)
	_add_slider_row(LocaleManager.g("setting_music_volume"), "audio/music_volume", 0.0, 1.0, 0.01, true)
	_add_slider_row(LocaleManager.g("setting_sfx_volume"), "audio/sfx_volume", 0.0, 1.0, 0.01, true)
	_add_slider_row(LocaleManager.g("setting_voice_volume"), "audio/voice_volume", 0.0, 1.0, 0.01, true)


func _build_subtitles_tab() -> void:
	_add_toggle_row(LocaleManager.g("setting_subtitles"), "subtitles/enabled")
	_add_option_row(LocaleManager.g("setting_language"), "subtitles/language",
		SettingsManager.LANGUAGE_LABELS, SettingsManager.LANGUAGE_CODES)
	_add_option_row(LocaleManager.g("setting_text_size"), "subtitles/text_size",
		[LocaleManager.g("opt_small"), LocaleManager.g("opt_medium"), LocaleManager.g("opt_large")])


# --- Control Builders ---

func _add_option_row(label_text: String, setting_key: String,
		display_labels: Array, values: Array = []) -> OptionButton:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)

	var label: Label = _create_label(label_text)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var option: OptionButton = OptionButton.new()
	_style_option_button(option)
	option.custom_minimum_size.x = 260

	for i in display_labels.size():
		option.add_item(str(display_labels[i]), i)
		if not values.is_empty() and i < values.size():
			option.set_item_metadata(i, values[i])

	option.item_selected.connect(_on_option_changed.bind(setting_key, values))

	row.add_child(label)
	row.add_child(option)
	content_container.add_child(row)
	_controls[setting_key] = option
	return option


func _add_slider_row(label_text: String, setting_key: String,
		min_val: float, max_val: float, step_val: float,
		show_percent: bool = false) -> HSlider:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)

	var label: Label = _create_label(label_text)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var slider: HSlider = HSlider.new()
	_style_slider(slider)
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step_val
	slider.custom_minimum_size.x = 200
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var value_label: Label = _create_label("")
	value_label.custom_minimum_size.x = 55
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var key_copy: String = setting_key
	var is_percent: bool = show_percent
	slider.value_changed.connect(func(val: float) -> void:
		if is_percent:
			value_label.text = str(roundi(val * 100)) + "%"
		else:
			value_label.text = str(snapped(val, step_val))
		SettingsManager.set_setting(key_copy, val)
	)

	row.add_child(label)
	row.add_child(slider)
	row.add_child(value_label)
	content_container.add_child(row)
	_controls[setting_key] = slider
	return slider


func _add_toggle_row(label_text: String, setting_key: String) -> CheckButton:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)

	var label: Label = _create_label(label_text)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var toggle: CheckButton = CheckButton.new()
	toggle.add_theme_font_override("font", roboto_font)
	toggle.add_theme_font_size_override("font_size", 18)
	toggle.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1.0))

	var key_copy: String = setting_key
	toggle.toggled.connect(func(pressed: bool) -> void:
		SettingsManager.set_setting(key_copy, pressed)
	)

	row.add_child(label)
	row.add_child(toggle)
	content_container.add_child(row)
	_controls[setting_key] = toggle
	return toggle


# --- Load Values into Controls ---

func _load_current_values() -> void:
	for key in _controls.keys():
		var control: Control = _controls[key]
		var value: Variant = SettingsManager.get_setting(key)

		if control is HSlider:
			(control as HSlider).set_value_no_signal(value as float)
			# Trigger the label update manually
			(control as HSlider).value_changed.emit(value as float)
		elif control is CheckButton:
			(control as CheckButton).set_pressed_no_signal(value as bool)
		elif control is OptionButton:
			_select_option_by_value(control as OptionButton, value)

	# Disable resolution when not windowed
	_update_resolution_enabled()


func _select_option_by_value(option: OptionButton, value: Variant) -> void:
	# Try metadata match first
	for i in option.item_count:
		var meta: Variant = option.get_item_metadata(i)
		if meta != null and meta == value:
			option.select(i)
			return
	# Fallback: treat value as index
	if value is int and value >= 0 and value < option.item_count:
		option.select(value as int)


# --- Callbacks ---

func _on_option_changed(index: int, setting_key: String, values: Array) -> void:
	var actual_value: Variant
	if values.is_empty():
		actual_value = index
	else:
		actual_value = values[index]
	SettingsManager.set_setting(setting_key, actual_value)

	if setting_key == "video/display_mode":
		_update_resolution_enabled()


func _update_resolution_enabled() -> void:
	if not _controls.has("video/resolution_index"):
		return
	var res_option: OptionButton = _controls["video/resolution_index"] as OptionButton
	var mode: Variant = SettingsManager.get_setting("video/display_mode")
	res_option.disabled = (mode != DisplayServer.WINDOW_MODE_WINDOWED)


func _on_back_pressed() -> void:
	SettingsManager.save_settings()
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
	await tween.finished
	closed.emit()
	queue_free()


func _on_reset_defaults_pressed() -> void:
	SettingsManager.reset_to_defaults()
	_load_current_values()


func _on_language_changed(_lang_code: String) -> void:
	_refresh_ui_text()


func _refresh_ui_text() -> void:
	if _header_title:
		_header_title.text = LocaleManager.g("ui_settings")
	if _reset_btn:
		_reset_btn.text = LocaleManager.g("ui_reset_defaults")
	if _back_btn:
		_back_btn.text = LocaleManager.g("ui_back")
	var labels := _get_tab_labels()
	for i in tab_buttons.size():
		tab_buttons[i].text = labels[i]
	_switch_tab(current_tab)


func _on_button_hover() -> void:
	# Play hover sound (35% volume)
	AudioManager.play_sfx(AudioManager.AudioID.MENU_HOVER, linear_to_db(0.35))


func _on_button_pressed() -> void:
	# Play click sound (15% volume)
	AudioManager.play_sfx(AudioManager.AudioID.MENU_CLICK, -13.5)


# --- Styling Helpers ---

func _create_label(text: String) -> Label:
	var label: Label = Label.new()
	var settings: LabelSettings = LabelSettings.new()
	settings.font = roboto_font
	settings.font_size = 20
	settings.font_color = Color(0.85, 0.85, 0.85, 1.0)
	settings.shadow_color = Color(0, 0, 0, 0.3)
	settings.shadow_offset = Vector2(1, 1)
	label.label_settings = settings
	label.text = text
	return label


func _style_option_button(option: OptionButton) -> void:
	option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	option.add_theme_font_override("font", roboto_regular)
	option.add_theme_font_size_override("font_size", 18)
	option.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	option.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	option.add_theme_color_override("font_focus_color", Color(0.9, 0.9, 0.9, 1.0))
	option.mouse_entered.connect(_on_button_hover)
	option.pressed.connect(_on_button_pressed)

	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.12, 0.15, 0.9)
	normal.corner_radius_top_left = 3
	normal.corner_radius_top_right = 3
	normal.corner_radius_bottom_left = 3
	normal.corner_radius_bottom_right = 3
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	normal.border_width_bottom = 1
	normal.border_width_top = 1
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_color = Color(0.25, 0.25, 0.3, 0.4)
	option.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.16, 0.16, 0.2, 0.95)
	hover.border_color = Color(0.35, 0.35, 0.4, 0.6)
	option.add_theme_stylebox_override("hover", hover)

	option.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _style_slider(slider: HSlider) -> void:
	# Grabber
	var grabber: StyleBoxFlat = StyleBoxFlat.new()
	grabber.bg_color = Color(0.55, 0.55, 0.58, 1.0)
	grabber.corner_radius_top_left = 2
	grabber.corner_radius_top_right = 2
	grabber.corner_radius_bottom_left = 2
	grabber.corner_radius_bottom_right = 2
	slider.add_theme_stylebox_override("grabber_area", grabber)

	var grabber_highlight: StyleBoxFlat = grabber.duplicate()
	grabber_highlight.bg_color = Color(0.7, 0.7, 0.73, 1.0)
	slider.add_theme_stylebox_override("grabber_area_highlight", grabber_highlight)

	# Slider track
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Color(0.15, 0.15, 0.18, 1.0)
	track.corner_radius_top_left = 2
	track.corner_radius_top_right = 2
	track.corner_radius_bottom_left = 2
	track.corner_radius_bottom_right = 2
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	slider.add_theme_stylebox_override("slider", track)


func _create_separator_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.23, 0.4)
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

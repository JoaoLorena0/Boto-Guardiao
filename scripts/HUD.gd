extends CanvasLayer
class_name GameHUD

signal upgrade_selected(kind: String)
signal start_requested
signal quit_requested
signal restart_requested
signal leaderboard_name_submitted(player_name: String)
signal pause_resume_requested
signal sfx_volume_changed(value: float)
signal music_volume_changed(value: float)

@onready var pollution_bar: ProgressBar = $StatusPanel/MarginContainer/VBoxContainer/PollutionBar
@onready var status_panel: PanelContainer = $StatusPanel
@onready var score_label: Label = $StatusPanel/MarginContainer/VBoxContainer/InfoGrid/ScoreLabel
@onready var wave_label: Label = $StatusPanel/MarginContainer/VBoxContainer/InfoGrid/WaveLabel
@onready var health_label: Label = $StatusPanel/MarginContainer/VBoxContainer/InfoGrid/HealthLabel
@onready var special_label: Label = $StatusPanel/MarginContainer/VBoxContainer/InfoGrid/SpecialLabel
@onready var power_up_label: Label = $StatusPanel/MarginContainer/VBoxContainer/PowerUpLabel
@onready var combo_label: Label = $ComboLabel
@onready var mission_label: Label = $MissionLabel
@onready var game_over_panel: Control = $GameOverPanel
@onready var game_over_message: Label = $GameOverPanel/MarginContainer/VBoxContainer/GameOverMessage
@onready var name_input: LineEdit = $GameOverPanel/MarginContainer/VBoxContainer/NameInput
@onready var leaderboard_label: Label = $GameOverPanel/MarginContainer/VBoxContainer/LeaderboardLabel
@onready var upgrade_panel: PanelContainer = $UpgradePanel
@onready var upgrade_button_1: Button = $UpgradePanel/MarginContainer/VBoxContainer/UpgradeButton1
@onready var upgrade_button_2: Button = $UpgradePanel/MarginContainer/VBoxContainer/UpgradeButton2
@onready var upgrade_button_3: Button = $UpgradePanel/MarginContainer/VBoxContainer/UpgradeButton3
@onready var start_menu: Control = $StartMenu
@onready var start_button: Button = $StartMenu/MainPanel/MarginContainer/VBoxContainer/StartButton
@onready var quit_button: Button = $StartMenu/MainPanel/MarginContainer/VBoxContainer/QuitButton
@onready var wave_banner: Control = $WaveBanner
@onready var wave_banner_label: Label = $WaveBanner/WaveBannerLabel
@onready var wave_banner_subtitle: Label = $WaveBanner/WaveBannerSubtitle

var current_upgrade_options: Array[String] = []
var upgrade_buttons: Array[Button] = []
var wave_banner_tween: Tween
var leaderboard_submitted: bool = false
var restart_enabled: bool = false
var boss_bar_panel: PanelContainer
var boss_bar_label: Label
var boss_bar: ProgressBar
var special_meter_panel: PanelContainer
var special_meter_label: Label
var special_meter_bar: ProgressBar
var special_meter_state: Label
var special_max_cooldown: float = 8.0
var special_was_ready: bool = true
var pause_panel: Control
var pause_continue_button: Button
var pause_quit_button: Button
var sfx_slider: HSlider
var music_slider: HSlider
var mobile_controls: Control
var mobile_controls_enabled: bool = false
var mobile_pressed_actions: Dictionary = {}
var fullscreen_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_layout_for_viewport)
	upgrade_buttons = [upgrade_button_1, upgrade_button_2, upgrade_button_3]
	upgrade_button_1.pressed.connect(_on_upgrade_button_1_pressed)
	upgrade_button_2.pressed.connect(_on_upgrade_button_2_pressed)
	upgrade_button_3.pressed.connect(_on_upgrade_button_3_pressed)
	start_button.pressed.connect(_on_start_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	name_input.text_submitted.connect(_on_name_input_submitted)
	status_panel.visible = true
	mission_label.visible = true
	upgrade_panel.visible = false
	wave_banner.visible = false
	_create_special_meter()
	_create_boss_bar()
	_create_pause_panel()
	_create_mobile_controls()
	_create_fullscreen_button()
	_layout_for_viewport()

func _input(event: InputEvent) -> void:
	if game_over_panel.visible and event.is_action_pressed("ui_accept") and leaderboard_submitted and restart_enabled:
		get_viewport().set_input_as_handled()
		restart_requested.emit()

func update_pollution(current: int, max_value: int) -> void:
	pollution_bar.max_value = max_value
	pollution_bar.value = current

func update_score(score: int) -> void:
	score_label.text = "PTS " + str(score).pad_zeros(6)

func update_wave(wave: int) -> void:
	wave_label.text = "ONDA " + str(wave).pad_zeros(2)
	if wave > 1:
		show_wave_banner(wave)

func update_health(current: int, max_value: int) -> void:
	health_label.text = "VIDA " + str(current) + "/" + str(max_value)

func update_special(ready: bool, cooldown_left: float) -> void:
	if special_meter_bar != null:
		_update_special_meter(ready, cooldown_left)

	if ready:
		special_label.text = "ESP PRONTO"
	else:
		var blocks: int = mini(4, maxi(0, 4 - ceili(cooldown_left * 0.5)))
		var bar: String = ""
		for i in range(4):
			if i < blocks:
				bar += "+"
			else:
				bar += "-"
		special_label.text = "ESP " + str(ceili(cooldown_left)) + "s"

func update_power_up(text: String) -> void:
	if text == "":
		power_up_label.text = ""
	else:
		power_up_label.text = "POWER " + text.to_upper()

func update_combo(text: String) -> void:
	combo_label.text = text
	if text != "":
		_pulse_label(combo_label)

func update_mission(text: String) -> void:
	mission_label.text = text
	_pulse_label(mission_label)

func show_game_over(message: String, current_score: int, leaderboard: Array[Dictionary]) -> void:
	leaderboard_submitted = false
	restart_enabled = false
	game_over_message.text = message + "\nPONTOS " + str(current_score).pad_zeros(6)
	leaderboard_label.text = _format_leaderboard(leaderboard)
	name_input.text = ""
	name_input.visible = true
	game_over_panel.visible = true
	_refresh_mobile_controls_visibility()
	game_over_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween: Tween = create_tween()
	tween.tween_property(game_over_panel, "modulate:a", 1.0, 0.22)
	name_input.grab_focus()

func hide_game_over() -> void:
	game_over_panel.visible = false
	game_over_panel.modulate = Color.WHITE
	leaderboard_submitted = false
	restart_enabled = false
	_refresh_mobile_controls_visibility()

func show_submitted_leaderboard(leaderboard: Array[Dictionary]) -> void:
	leaderboard_submitted = true
	restart_enabled = false
	name_input.visible = false
	leaderboard_label.text = _format_leaderboard(leaderboard)
	game_over_message.text += "\nPressione Enter para jogar de novo."
	await get_tree().create_timer(0.15, true).timeout
	restart_enabled = true

func show_start_menu() -> void:
	start_menu.visible = true
	_refresh_mobile_controls_visibility()
	start_button.grab_focus()

func hide_start_menu() -> void:
	start_menu.visible = false
	_refresh_mobile_controls_visibility()

func show_pause_panel() -> void:
	if pause_panel == null:
		return

	pause_panel.visible = true
	_refresh_mobile_controls_visibility()
	pause_continue_button.grab_focus()

func hide_pause_panel() -> void:
	if pause_panel == null:
		return

	pause_panel.visible = false
	_refresh_mobile_controls_visibility()

func show_wave_banner(wave: int) -> void:
	if wave_banner_tween != null:
		wave_banner_tween.kill()

	wave_banner.visible = true
	wave_banner.modulate = Color(1.0, 1.0, 1.0, 0.0)
	wave_banner.scale = Vector2(1.18, 1.18)
	wave_banner_label.text = "ONDA " + str(wave).pad_zeros(2)
	if wave % 5 == 0:
		wave_banner_subtitle.text = "CHEFE SE APROXIMA"
	else:
		wave_banner_subtitle.text = "MAIS INIMIGOS NO RIO"

	wave_banner_tween = create_tween()
	wave_banner_tween.tween_property(wave_banner, "modulate:a", 1.0, 0.12)
	wave_banner_tween.parallel().tween_property(wave_banner, "scale", Vector2.ONE, 0.18)
	wave_banner_tween.tween_interval(0.55)
	wave_banner_tween.tween_property(wave_banner, "modulate:a", 0.0, 0.34)
	wave_banner_tween.tween_callback(Callable(wave_banner, "hide"))

func show_wave_event(text: String) -> void:
	if wave_banner_tween != null:
		wave_banner_tween.kill()

	wave_banner.visible = true
	wave_banner.modulate = Color(1.0, 1.0, 1.0, 0.0)
	wave_banner.scale = Vector2(1.12, 1.12)
	wave_banner_label.text = text
	wave_banner_subtitle.text = "O RIO MUDOU"

	wave_banner_tween = create_tween()
	wave_banner_tween.tween_property(wave_banner, "modulate:a", 1.0, 0.12)
	wave_banner_tween.parallel().tween_property(wave_banner, "scale", Vector2.ONE, 0.18)
	wave_banner_tween.tween_interval(0.75)
	wave_banner_tween.tween_property(wave_banner, "modulate:a", 0.0, 0.34)
	wave_banner_tween.tween_callback(Callable(wave_banner, "hide"))

func show_upgrade_choices(options: Array[String]) -> void:
	_refresh_mobile_controls_visibility()
	current_upgrade_options = options
	for i in range(upgrade_buttons.size()):
		var button: Button = upgrade_buttons[i]
		if i < current_upgrade_options.size():
			button.visible = true
			button.text = _format_upgrade(current_upgrade_options[i])
			_style_upgrade_button(button, current_upgrade_options[i])
		else:
			button.visible = false

	upgrade_panel.visible = true
	_refresh_mobile_controls_visibility()
	upgrade_button_1.grab_focus()

func hide_upgrade_choices() -> void:
	upgrade_panel.visible = false
	_refresh_mobile_controls_visibility()

func _select_upgrade(index: int) -> void:
	if index < 0 or index >= current_upgrade_options.size():
		return

	var selected: String = current_upgrade_options[index]
	hide_upgrade_choices()
	upgrade_selected.emit(selected)

func _on_upgrade_button_1_pressed() -> void:
	_select_upgrade(0)

func _on_upgrade_button_2_pressed() -> void:
	_select_upgrade(1)

func _on_upgrade_button_3_pressed() -> void:
	_select_upgrade(2)

func _on_start_button_pressed() -> void:
	hide_start_menu()
	start_requested.emit()

func _on_quit_button_pressed() -> void:
	quit_requested.emit()

func _on_pause_continue_pressed() -> void:
	pause_resume_requested.emit()

func _on_pause_quit_pressed() -> void:
	quit_requested.emit()

func _on_sfx_slider_changed(value: float) -> void:
	sfx_volume_changed.emit(value)

func _on_music_slider_changed(value: float) -> void:
	music_volume_changed.emit(value)

func _on_fullscreen_button_pressed() -> void:
	var current_mode: int = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _on_mobile_action_down(action: String) -> void:
	if not mobile_controls_enabled:
		return

	mobile_pressed_actions[action] = true
	Input.action_press(action)

func _on_mobile_action_up(action: String) -> void:
	if not mobile_pressed_actions.has(action):
		return

	mobile_pressed_actions.erase(action)
	Input.action_release(action)

func _format_upgrade(kind: String) -> String:
	var rarity: String = _get_upgrade_rarity(kind)
	var base_kind: String = _get_upgrade_kind(kind)
	var prefix: String = _get_upgrade_symbol(base_kind) + " [" + rarity.to_upper() + "] "
	var suffix: String = ""
	if rarity == "raro":
		suffix = "\nEfeito aumentado."
	elif rarity == "lendario":
		suffix = "\nEfeito muito aumentado."

	if base_kind == "max_health":
		return prefix + "VIDA MAX\nCura e aumenta vida maxima." + suffix
	elif base_kind == "fire_rate":
		return prefix + "CADENCIA\nAtira mais rapido para sempre." + suffix
	elif base_kind == "spread":
		return prefix + "TIRO ABERTO\nAdiciona disparos diagonais." + suffix
	elif base_kind == "damage":
		return prefix + "DANO\nCada bolha causa mais dano." + suffix
	elif base_kind == "special":
		return prefix + "ESPECIAL\nMais dano e menor recarga." + suffix
	elif base_kind == "dash":
		return prefix + "DASH\nRecarga menor e deslocamento maior." + suffix
	elif base_kind == "bubble_explosion":
		return prefix + "BOLHA EXPLOSIVA\nDano cria explosao curta." + suffix
	elif base_kind == "dash_trail":
		return prefix + "RASTRO\nDash deixa dano na agua." + suffix
	elif base_kind == "shield_heal":
		return prefix + "ESCUDO VIVO\nBloquear pode curar." + suffix
	elif base_kind == "river_burst":
		return prefix + "RIO VIVO\nEspecial tambem limpa poluicao." + suffix

	return prefix + base_kind.to_upper()

func _get_upgrade_symbol(base_kind: String) -> String:
	if base_kind == "max_health":
		return "VIDA"
	elif base_kind == "fire_rate":
		return "RAP"
	elif base_kind == "spread":
		return "SPR"
	elif base_kind == "damage":
		return "DMG"
	elif base_kind == "special":
		return "ESP"
	elif base_kind == "dash":
		return "DASH"
	elif base_kind == "bubble_explosion":
		return "BOOM"
	elif base_kind == "dash_trail":
		return "RSTR"
	elif base_kind == "shield_heal":
		return "CURA"
	elif base_kind == "river_burst":
		return "RIO"

	return "UP"

func _style_upgrade_button(button: Button, kind: String) -> void:
	var rarity: String = _get_upgrade_rarity(kind)
	var fill: Color = Color(0.0745098, 0.172549, 0.258824, 0.96)
	var border: Color = Color(0.384314, 0.870588, 0.960784, 1.0)
	var text_color: Color = Color(0.835294, 1.0, 1.0, 1.0)
	if rarity == "raro":
		fill = Color(0.09, 0.12, 0.31, 0.96)
		border = Color(0.55, 0.55, 1.0, 1.0)
		text_color = Color(0.82, 0.88, 1.0, 1.0)
	elif rarity == "lendario":
		fill = Color(0.25, 0.11, 0.07, 0.96)
		border = Color(1.0, 0.76, 0.26, 1.0)
		text_color = Color(1.0, 0.9, 0.48, 1.0)

	var normal: StyleBoxFlat = _make_button_style(fill, border)
	var hover: StyleBoxFlat = _make_button_style(fill.lightened(0.08), border.lightened(0.12))
	var pressed: StyleBoxFlat = _make_button_style(fill.darkened(0.08), border)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color.lightened(0.08))
	button.add_theme_color_override("font_pressed_color", text_color.darkened(0.08))

func _make_button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	return style

func _create_special_meter() -> void:
	var vbox: VBoxContainer = $StatusPanel/MarginContainer/VBoxContainer
	special_meter_panel = PanelContainer.new()
	special_meter_panel.name = "SpecialMeterPanel"
	special_meter_panel.theme = status_panel.theme
	special_meter_panel.add_theme_stylebox_override("panel", _make_button_style(Color(0.02, 0.06, 0.12, 0.48), Color(0.48, 0.9, 1.0, 0.62)))
	vbox.add_child(special_meter_panel)
	vbox.move_child(special_meter_panel, 4)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 5)
	special_meter_panel.add_child(margin)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	special_meter_label = Label.new()
	special_meter_label.custom_minimum_size = Vector2(38.0, 20.0)
	special_meter_label.text = "ESP"
	special_meter_label.label_settings = _make_meter_label_settings(Color(0.82, 1.0, 1.0, 1.0), 13)
	row.add_child(special_meter_label)

	special_meter_bar = ProgressBar.new()
	special_meter_bar.custom_minimum_size = Vector2(170.0, 18.0)
	special_meter_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	special_meter_bar.max_value = 1.0
	special_meter_bar.value = 1.0
	special_meter_bar.show_percentage = false
	special_meter_bar.add_theme_stylebox_override("background", _make_button_style(Color(0.015, 0.04, 0.08, 0.96), Color(0.18, 0.36, 0.48, 1.0)))
	special_meter_bar.add_theme_stylebox_override("fill", _make_button_style(Color(0.48, 0.96, 1.0, 1.0), Color(0.86, 1.0, 1.0, 1.0)))
	row.add_child(special_meter_bar)

	special_meter_state = Label.new()
	special_meter_state.custom_minimum_size = Vector2(58.0, 20.0)
	special_meter_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	special_meter_state.text = "PRONTO"
	special_meter_state.label_settings = _make_meter_label_settings(Color(1.0, 0.86, 0.25, 1.0), 12)
	row.add_child(special_meter_state)

func _make_meter_label_settings(font_color: Color, font_size: int) -> LabelSettings:
	var settings: LabelSettings = LabelSettings.new()
	settings.font = status_panel.get_theme_default_font()
	settings.font_size = font_size
	settings.font_color = font_color
	settings.outline_size = 3
	settings.outline_color = Color(0.0313726, 0.0470588, 0.0823529, 1.0)
	return settings

func _update_special_meter(ready: bool, cooldown_left: float) -> void:
	if not ready and special_was_ready and cooldown_left > 0.0:
		special_max_cooldown = cooldown_left
	elif cooldown_left > special_max_cooldown:
		special_max_cooldown = cooldown_left

	if ready:
		special_was_ready = true
		special_meter_bar.value = 1.0
		special_meter_state.text = "PRONTO"
		special_meter_state.label_settings = _make_meter_label_settings(Color(1.0, 0.86, 0.25, 1.0), 12)
		special_meter_panel.add_theme_stylebox_override("panel", _make_button_style(Color(0.06, 0.12, 0.18, 0.68), Color(1.0, 0.86, 0.25, 0.95)))
		special_meter_bar.add_theme_stylebox_override("fill", _make_button_style(Color(1.0, 0.86, 0.25, 1.0), Color(1.0, 0.96, 0.62, 1.0)))
		_pulse_special_meter()
		return

	special_was_ready = false
	var progress: float = 1.0 - cooldown_left / maxf(special_max_cooldown, 1.0)
	special_meter_bar.value = maxf(0.0, minf(progress, 1.0))
	special_meter_state.text = str(ceili(cooldown_left)) + "s"
	special_meter_state.label_settings = _make_meter_label_settings(Color(0.82, 1.0, 1.0, 1.0), 12)
	special_meter_panel.add_theme_stylebox_override("panel", _make_button_style(Color(0.02, 0.06, 0.12, 0.48), Color(0.48, 0.9, 1.0, 0.62)))
	special_meter_bar.add_theme_stylebox_override("fill", _make_button_style(Color(0.35, 0.72, 1.0, 1.0), Color(0.72, 0.96, 1.0, 1.0)))

func _pulse_special_meter() -> void:
	if special_meter_panel == null:
		return

	special_meter_panel.scale = Vector2(1.035, 1.035)
	var tween: Tween = create_tween()
	tween.tween_property(special_meter_panel, "scale", Vector2.ONE, 0.12)

func show_boss_bar(current: int, max_value: int) -> void:
	if boss_bar_panel == null:
		return

	boss_bar.max_value = max_value
	boss_bar.value = current
	boss_bar_label.text = "CHEFE  " + str(current) + "/" + str(max_value)
	boss_bar_panel.visible = true
	boss_bar_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)

func update_boss_bar(current: int, max_value: int) -> void:
	if boss_bar_panel == null:
		return

	boss_bar.max_value = max_value
	boss_bar.value = current
	boss_bar_label.text = "CHEFE  " + str(current) + "/" + str(max_value)
	if current <= 0:
		hide_boss_bar()
	else:
		boss_bar_panel.visible = true

func hide_boss_bar() -> void:
	if boss_bar_panel == null:
		return

	var tween: Tween = create_tween()
	tween.tween_property(boss_bar_panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(Callable(boss_bar_panel, "hide"))

func show_danger_indicator(y_position: float, is_boss: bool) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var marker: Control = Control.new()
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.custom_minimum_size = Vector2(88.0, 30.0)
	marker.position = Vector2(viewport_size.x - 96.0, minf(maxf(y_position - 15.0, 42.0), viewport_size.y - 52.0))
	add_child(marker)

	var label: Label = Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.theme = status_panel.theme
	label.label_settings = _make_warning_label_settings(is_boss)
	if is_boss:
		label.text = "<< CHEFE"
	else:
		label.text = "<<"
	marker.add_child(label)

	var tween: Tween = create_tween()
	tween.tween_property(marker, "position:x", marker.position.x - 18.0, 0.18)
	tween.tween_property(marker, "position:x", marker.position.x, 0.18)
	tween.tween_interval(0.2)
	tween.tween_property(marker, "modulate:a", 0.0, 0.22)
	tween.tween_callback(Callable(marker, "queue_free"))

func _make_warning_label_settings(is_boss: bool) -> LabelSettings:
	var settings: LabelSettings = LabelSettings.new()
	settings.font = status_panel.get_theme_default_font()
	if is_boss:
		settings.font_size = 18
		settings.font_color = Color(1.0, 0.35, 0.55, 1.0)
		settings.outline_size = 5
	else:
		settings.font_size = 22
		settings.font_color = Color(1.0, 0.86, 0.25, 1.0)
		settings.outline_size = 4
	settings.outline_color = Color(0.0313726, 0.0470588, 0.0823529, 1.0)
	return settings

func _create_boss_bar() -> void:
	boss_bar_panel = PanelContainer.new()
	boss_bar_panel.name = "BossBarPanel"
	boss_bar_panel.visible = false
	boss_bar_panel.theme = status_panel.theme
	boss_bar_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	boss_bar_panel.add_theme_stylebox_override("panel", _make_button_style(Color(0.03, 0.06, 0.12, 0.65), Color(1.0, 0.32, 0.55, 0.9)))
	add_child(boss_bar_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	boss_bar_panel.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	boss_bar_label = Label.new()
	boss_bar_label.text = "CHEFE"
	boss_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar_label.label_settings = _make_warning_label_settings(true)
	box.add_child(boss_bar_label)

	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(360.0, 14.0)
	boss_bar.show_percentage = false
	var bg_style: StyleBoxFlat = _make_button_style(Color(0.035, 0.055, 0.09, 0.96), Color(0.28, 0.08, 0.18, 1.0))
	var fill_style: StyleBoxFlat = _make_button_style(Color(0.92, 0.12, 0.34, 1.0), Color(1.0, 0.42, 0.65, 1.0))
	boss_bar.add_theme_stylebox_override("background", bg_style)
	boss_bar.add_theme_stylebox_override("fill", fill_style)
	box.add_child(boss_bar)

func _create_pause_panel() -> void:
	pause_panel = Control.new()
	pause_panel.name = "PausePanel"
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel.visible = false
	pause_panel.theme = status_panel.theme
	add_child(pause_panel)

	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0156863, 0.0313726, 0.0588235, 0.66)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(dim)

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Panel"
	panel.theme = status_panel.theme
	panel.add_theme_stylebox_override("panel", _make_button_style(Color(0.04, 0.09, 0.15, 0.86), Color(0.38, 0.87, 0.96, 1.0)))
	pause_panel.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title: Label = Label.new()
	title.text = "PAUSADO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.label_settings = _make_warning_label_settings(false)
	box.add_child(title)

	var sfx_label: Label = Label.new()
	sfx_label.text = "SFX"
	sfx_label.label_settings = _make_meter_label_settings(Color(0.82, 1.0, 1.0, 1.0), 13)
	box.add_child(sfx_label)

	sfx_slider = HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.value = 1.0
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	box.add_child(sfx_slider)

	var music_label: Label = Label.new()
	music_label.text = "MUSICA"
	music_label.label_settings = _make_meter_label_settings(Color(0.82, 1.0, 1.0, 1.0), 13)
	box.add_child(music_label)

	music_slider = HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.05
	music_slider.value = 1.0
	music_slider.value_changed.connect(_on_music_slider_changed)
	box.add_child(music_slider)

	pause_continue_button = Button.new()
	pause_continue_button.custom_minimum_size = Vector2(260.0, 42.0)
	pause_continue_button.text = "CONTINUAR"
	pause_continue_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.0745098, 0.172549, 0.258824, 0.96), Color(0.384314, 0.870588, 0.960784, 1.0)))
	pause_continue_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.1, 0.22, 0.32, 0.96), Color(0.56, 0.96, 1.0, 1.0)))
	pause_continue_button.pressed.connect(_on_pause_continue_pressed)
	box.add_child(pause_continue_button)

	pause_quit_button = Button.new()
	pause_quit_button.custom_minimum_size = Vector2(260.0, 42.0)
	pause_quit_button.text = "SAIR"
	pause_quit_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.0745098, 0.172549, 0.258824, 0.96), Color(1.0, 0.32, 0.55, 0.95)))
	pause_quit_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.14, 0.18, 0.26, 0.96), Color(1.0, 0.55, 0.7, 1.0)))
	pause_quit_button.pressed.connect(_on_pause_quit_pressed)
	box.add_child(pause_quit_button)

func _create_mobile_controls() -> void:
	mobile_controls_enabled = _is_mobile_browser()

	mobile_controls = Control.new()
	mobile_controls.name = "MobileControls"
	mobile_controls.process_mode = Node.PROCESS_MODE_ALWAYS
	mobile_controls.visible = false
	mobile_controls.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(mobile_controls)

	var dpad: Control = Control.new()
	dpad.name = "DPad"
	dpad.mouse_filter = Control.MOUSE_FILTER_PASS
	mobile_controls.add_child(dpad)

	_add_mobile_button(dpad, "MoveUpButton", "^", "move_up")
	_add_mobile_button(dpad, "MoveLeftButton", "<", "move_left")
	_add_mobile_button(dpad, "MoveRightButton", ">", "move_right")
	_add_mobile_button(dpad, "MoveDownButton", "v", "move_down")

	var actions: Control = Control.new()
	actions.name = "ActionButtons"
	actions.mouse_filter = Control.MOUSE_FILTER_PASS
	mobile_controls.add_child(actions)

	_add_mobile_button(actions, "ShootButton", "TIRO", "shoot")
	_add_mobile_button(actions, "DashButton", "DASH", "dash")
	_add_mobile_button(actions, "SpecialButton", "ESP", "special")

	_refresh_mobile_controls_visibility()

func _create_fullscreen_button() -> void:
	fullscreen_button = Button.new()
	fullscreen_button.name = "FullscreenButton"
	fullscreen_button.process_mode = Node.PROCESS_MODE_ALWAYS
	fullscreen_button.text = "TELA"
	fullscreen_button.focus_mode = Control.FOCUS_NONE
	fullscreen_button.custom_minimum_size = Vector2(82.0, 38.0)
	fullscreen_button.theme = status_panel.theme
	fullscreen_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.035, 0.09, 0.14, 0.64), Color(0.38, 0.87, 0.96, 0.78)))
	fullscreen_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.06, 0.14, 0.2, 0.82), Color(0.56, 0.96, 1.0, 1.0)))
	fullscreen_button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.02, 0.06, 0.1, 0.86), Color(1.0, 0.86, 0.25, 1.0)))
	fullscreen_button.add_theme_color_override("font_color", Color(0.84, 1.0, 1.0, 1.0))
	fullscreen_button.add_theme_font_size_override("font_size", 12)
	fullscreen_button.pressed.connect(_on_fullscreen_button_pressed)
	add_child(fullscreen_button)

func _add_mobile_button(parent: Control, node_name: String, label: String, action: String) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.theme = status_panel.theme
	button.custom_minimum_size = Vector2(62.0, 62.0)
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.035, 0.09, 0.14, 0.58), Color(0.38, 0.87, 0.96, 0.76)))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.05, 0.12, 0.18, 0.72), Color(0.56, 0.96, 1.0, 0.94)))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.02, 0.06, 0.1, 0.88), Color(1.0, 0.86, 0.25, 1.0)))
	button.add_theme_color_override("font_color", Color(0.84, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.9, 0.45, 1.0))
	button.add_theme_font_size_override("font_size", 13)
	button.button_down.connect(_on_mobile_action_down.bind(action))
	button.button_up.connect(_on_mobile_action_up.bind(action))
	parent.add_child(button)
	return button

func _is_mobile_browser() -> bool:
	if not OS.has_feature("web"):
		return false

	var detected_mobile: Variant = JavaScriptBridge.eval("""
		/Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)
		|| (navigator.maxTouchPoints > 1 && window.matchMedia('(pointer: coarse)').matches)
	""", true)
	return bool(detected_mobile)

func _refresh_mobile_controls_visibility() -> void:
	if mobile_controls == null:
		return

	var should_show: bool = mobile_controls_enabled \
		and not start_menu.visible \
		and not game_over_panel.visible \
		and not upgrade_panel.visible \
		and (pause_panel == null or not pause_panel.visible)
	mobile_controls.visible = should_show
	if not should_show:
		_release_mobile_actions()

func _release_mobile_actions() -> void:
	for action in mobile_pressed_actions.keys():
		Input.action_release(str(action))
	mobile_pressed_actions.clear()

func _get_upgrade_rarity(kind: String) -> String:
	var parts: PackedStringArray = kind.split(":")
	if parts.size() >= 2:
		return parts[0]

	return "comum"

func _get_upgrade_kind(kind: String) -> String:
	var parts: PackedStringArray = kind.split(":")
	if parts.size() >= 2:
		return parts[1]

	return kind

func _pulse_label(label: Label) -> void:
	label.scale = Vector2(1.18, 1.18)
	var tween: Tween = create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.14)

func _format_leaderboard(entries: Array[Dictionary]) -> String:
	var text: String = "PLACAR DE LIDERES\n"
	if entries.is_empty():
		return text + "1. JOGADOR 000000"

	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var player_name: String = str(entry["name"])
		var player_score: int = int(entry["score"])
		text += str(i + 1) + ". " + player_name.rpad(10) + " " + str(player_score).pad_zeros(6)
		if i < entries.size() - 1:
			text += "\n"

	return text

func _on_name_input_submitted(player_name: String) -> void:
	if leaderboard_submitted:
		return

	leaderboard_name_submitted.emit(player_name)

func _layout_for_viewport() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size

	_set_rect(status_panel, Vector2(12.0, 10.0), Vector2(352.0, 176.0))
	_set_centered_rect($GameOverPanel/MarginContainer, Vector2(560.0, 300.0), Vector2(0.0, 10.0))
	_set_centered_rect(upgrade_panel, Vector2(544.0, 352.0), Vector2(0.0, 0.0))
	_set_centered_rect(wave_banner, Vector2(460.0, 140.0), Vector2(0.0, -20.0))
	_set_centered_rect($StartMenu/MainPanel, Vector2(372.0, 300.0), Vector2(0.0, 0.0))
	if pause_panel != null:
		pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		_set_centered_rect(pause_panel.get_node("Panel") as Control, Vector2(340.0, 330.0), Vector2(0.0, 0.0))
	if boss_bar_panel != null:
		_set_centered_rect(boss_bar_panel, Vector2(420.0, 64.0), Vector2(0.0, 68.0 - size.y * 0.5))
	if mobile_controls != null:
		mobile_controls.set_anchors_preset(Control.PRESET_FULL_RECT)
		_layout_mobile_controls(size)
	if fullscreen_button != null:
		_set_rect(fullscreen_button, Vector2(maxf(size.x - 96.0, 12.0), 58.0), Vector2(82.0, 38.0))

	_set_rect(
		$StartMenu/ControlsPanel,
		Vector2(maxf(size.x - 300.0, 20.0), maxf(size.y - 230.0, 220.0)),
		Vector2(280.0, 214.0)
	)
	_set_rect(combo_label, Vector2(maxf(size.x * 0.5 - 171.0, 12.0), 16.0), Vector2(342.0, 42.0))
	_set_rect(mission_label, Vector2(maxf(size.x - 294.0, 12.0), 16.0), Vector2(280.0, 32.0))

func _set_centered_rect(control: Control, rect_size: Vector2, offset: Vector2) -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var safe_size: Vector2 = Vector2(
		minf(rect_size.x, maxf(size.x - 32.0, 260.0)),
		minf(rect_size.y, maxf(size.y - 32.0, 180.0))
	)
	var position: Vector2 = (size - safe_size) * 0.5 + offset
	_set_rect(control, position, safe_size)

func _set_rect(control: Control, position: Vector2, rect_size: Vector2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.offset_left = position.x
	control.offset_top = position.y
	control.offset_right = position.x + rect_size.x
	control.offset_bottom = position.y + rect_size.y

func _layout_mobile_controls(size: Vector2) -> void:
	var margin: float = clampf(size.x * 0.025, 12.0, 18.0)
	var gap: float = clampf(size.x * 0.01, 5.0, 8.0)
	var max_side_by_width: float = (size.x - margin * 2.0 - 16.0 - gap * 4.0) / 6.0
	var button_size: float = clampf(minf(size.y * 0.11, max_side_by_width), 40.0, 72.0)
	var dpad_size: float = button_size * 3.0 + gap * 2.0
	var bottom_y: float = size.y - dpad_size - margin
	var dpad: Control = mobile_controls.get_node("DPad") as Control
	var actions: Control = mobile_controls.get_node("ActionButtons") as Control

	_set_rect(dpad, Vector2(margin, bottom_y), Vector2(dpad_size, dpad_size))
	_set_rect(dpad.get_node("MoveUpButton") as Control, Vector2(button_size + gap, 0.0), Vector2(button_size, button_size))
	_set_rect(dpad.get_node("MoveLeftButton") as Control, Vector2(0.0, button_size + gap), Vector2(button_size, button_size))
	_set_rect(dpad.get_node("MoveRightButton") as Control, Vector2((button_size + gap) * 2.0, button_size + gap), Vector2(button_size, button_size))
	_set_rect(dpad.get_node("MoveDownButton") as Control, Vector2(button_size + gap, (button_size + gap) * 2.0), Vector2(button_size, button_size))

	var action_width: float = button_size * 3.0 + gap * 2.0
	var action_height: float = button_size * 2.0 + gap
	var action_x: float = size.x - action_width - margin
	var action_y: float = size.y - action_height - margin
	_set_rect(actions, Vector2(action_x, action_y), Vector2(action_width, action_height))
	_set_rect(actions.get_node("ShootButton") as Control, Vector2(button_size + gap, 0.0), Vector2(button_size * 2.0 + gap, button_size))
	_set_rect(actions.get_node("DashButton") as Control, Vector2(0.0, button_size + gap), Vector2(button_size, button_size))
	_set_rect(actions.get_node("SpecialButton") as Control, Vector2(button_size + gap, button_size + gap), Vector2(button_size * 2.0 + gap, button_size))

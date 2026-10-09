extends Node
class_name GameManager

signal score_changed(score: int)
signal wave_changed(wave: int)
signal upgrade_choices_requested(options: Array[String])
signal combo_changed(text: String)
signal mission_changed(text: String)

var score: int = 0
var wave: int = 1
var combo_count: int = 0
var combo_timer: float = 0.0
var combo_window: float = 2.4
var mission_kills: int = 0
var mission_goal: int = 20
var mission_reward_ready: bool = false
var mission_type: String = "kills"
var mission_start_score: int = 0
var mission_clean_failed: bool = false
var leaderboard_path: String = "user://leaderboard.dat"
var upgrade_pool: Array[String] = [
	"max_health",
	"fire_rate",
	"spread",
	"damage",
	"special",
	"dash",
	"bubble_explosion",
	"dash_trail",
	"shield_heal",
	"river_burst",
]

@onready var spawner: Node = $"../EnemySpawner"

func _is_entry_higher(a: Dictionary, b: Dictionary) -> bool:
	return int(a["score"]) > int(b["score"])

func _ready() -> void:
	add_to_group("game_manager")
	_start_new_mission()

func _process(delta: float) -> void:
	if combo_timer > 0.0:
		combo_timer = maxf(combo_timer - delta, 0.0)
		if combo_timer <= 0.0:
			combo_count = 0
			combo_changed.emit("")

func add_score(amount: int) -> void:
	combo_count += 1
	combo_timer = combo_window
	var multiplier: int = 1 + floori(float(combo_count) / 8.0)
	score += amount * multiplier
	score_changed.emit(score)
	if combo_count >= 2:
		combo_changed.emit("COMBO x" + str(combo_count) + "  +" + str(multiplier) + "x")

	if mission_type == "kills":
		mission_kills += 1
	elif mission_type == "combo":
		mission_kills = maxi(mission_kills, combo_count)
	elif mission_type == "score":
		mission_kills = score - mission_start_score

	_update_mission_progress()

func add_risk_score(amount: int) -> void:
	add_score(amount)
	combo_timer = combo_window + 0.6

func next_wave() -> void:
	if mission_type == "clean_wave":
		if not mission_clean_failed:
			mission_kills += 1
			_update_mission_progress()
		elif not mission_reward_ready:
			_start_new_mission()

	wave += 1
	wave_changed.emit(wave)

	if spawner.has_method("set_difficulty"):
		spawner.call("set_difficulty", wave)

	if wave % 5 == 0:
		upgrade_choices_requested.emit(_roll_upgrade_choices())

func _roll_upgrade_choices() -> Array[String]:
	var available: Array[String] = []
	var choices: Array[String] = []

	for i in range(upgrade_pool.size()):
		available.append(upgrade_pool[i])

	while choices.size() < 3 and not available.is_empty():
		var index: int = randi_range(0, available.size() - 1)
		choices.append(_with_rarity(available[index]))
		available.remove_at(index)

	return choices

func consume_mission_reward() -> void:
	if mission_reward_ready:
		mission_reward_ready = false
		_start_new_mission()

func request_bonus_reward() -> void:
	upgrade_choices_requested.emit(_roll_upgrade_choices())

func record_pollution_taken() -> void:
	if mission_type == "clean_wave":
		mission_clean_failed = true
		_update_mission_progress()

func record_power_up_collected() -> void:
	if mission_type == "powerups":
		mission_kills += 1
		_update_mission_progress()

func _start_new_mission() -> void:
	var chapter: int = 1 + int(float(wave - 1) / 5.0)
	var roll: int = randi_range(0, 4)
	if roll == 0:
		mission_type = "kills"
		mission_goal = 12 + chapter * 5
	elif roll == 1:
		mission_type = "combo"
		mission_goal = 6 + chapter * 2
	elif roll == 2:
		mission_type = "clean_wave"
		mission_goal = 1
	elif roll == 3:
		mission_type = "powerups"
		mission_goal = 2
	else:
		mission_type = "score"
		mission_goal = 120 + chapter * 90

	mission_kills = 0
	mission_start_score = score
	mission_clean_failed = false
	_update_mission_progress()

func _update_mission_progress() -> void:
	if mission_reward_ready:
		return

	if mission_kills >= mission_goal:
		mission_reward_ready = true
		mission_changed.emit("MISSAO COMPLETA")
		upgrade_choices_requested.emit(_roll_upgrade_choices())
		return

	mission_changed.emit(_format_mission_text())

func _format_mission_text() -> String:
	if mission_type == "kills":
		return "MISSAO ABATER " + str(mission_kills) + "/" + str(mission_goal)
	elif mission_type == "combo":
		return "MISSAO COMBO " + str(mission_kills) + "/" + str(mission_goal)
	elif mission_type == "clean_wave":
		if mission_clean_failed:
			return "MISSAO RIO LIMPO FALHOU"
		return "MISSAO RIO LIMPO 0/1"
	elif mission_type == "powerups":
		return "MISSAO COLETAR " + str(mission_kills) + "/" + str(mission_goal)
	elif mission_type == "score":
		return "MISSAO PTS " + str(mission_kills) + "/" + str(mission_goal)

	return "MISSAO " + str(mission_kills) + "/" + str(mission_goal)

func submit_score(player_name: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = load_leaderboard()
	var clean_name: String = player_name.strip_edges()
	if clean_name == "":
		clean_name = "JOGADOR"

	entries.append({"name": clean_name.substr(0, 10).to_upper(), "score": score})
	entries.sort_custom(Callable(self, "_is_entry_higher"))
	while entries.size() > 5:
		entries.remove_at(entries.size() - 1)

	_save_leaderboard(entries)
	return entries

func load_leaderboard() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not FileAccess.file_exists(leaderboard_path):
		return entries

	var file: FileAccess = FileAccess.open(leaderboard_path, FileAccess.READ)
	if file == null:
		return entries

	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line == "":
			continue

		var parts: PackedStringArray = line.split("|")
		if parts.size() >= 2 and parts[1].is_valid_int():
			entries.append({"name": parts[0].substr(0, 10).to_upper(), "score": parts[1].to_int()})
		elif line.is_valid_int():
			entries.append({"name": "JOGADOR", "score": line.to_int()})

	entries.sort_custom(Callable(self, "_is_entry_higher"))
	while entries.size() > 5:
		entries.remove_at(entries.size() - 1)

	return entries

func _save_leaderboard(entries: Array[Dictionary]) -> void:
	var file: FileAccess = FileAccess.open(leaderboard_path, FileAccess.WRITE)
	if file == null:
		return

	for entry in entries:
		file.store_line(str(entry["name"]) + "|" + str(entry["score"]))

func _with_rarity(kind: String) -> String:
	var roll: float = randf()
	if wave >= 10 and roll < 0.08:
		return "lendario:" + kind
	elif wave >= 5 and roll < 0.24:
		return "raro:" + kind

	return "comum:" + kind

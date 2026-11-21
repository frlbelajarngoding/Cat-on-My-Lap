class_name TaskManager
extends Node
# ============================================================
# TASK MANAGER (Penjadwal & pengatur semua tugas hari ini)
# ------------------------------------------------------------
# Tugas:
#   1. Saat scene dimuat: ambil jadwal hari ini (TaskSchedule),
#      buat instance scene tiap tugas yang dibutuhkan.
#   2. Saat jam game mencapai jadwal: antrekan tugas, lalu aktifkan
#      bila boleh (belum aktif, syarat "after" terpenuhi, dan batas
#      suara bersamaan belum penuh).
#   3. Menguras meter kucing akibat SUARA tiap frame (GDD bagian E).
#   4. Mengatur Badai (Day 4).
#   5. Melacak tugas A yang wajib selesai sebelum hari boleh ditutup.
#
# Berbicara dengan Cat HANYA lewat Events (meter_penalty/meter_recovery).
# ============================================================

# Pengurasan meter (% per detik) menurut fase suara.
# Fase 4 (tugas gagal): penalti sekali (di Task), dan suara terus menguras
# sebesar fase 3 sampai dimatikan.
const PHASE_DRAIN := {1: 0.0, 2: 0.5, 3: 1.5, 4: 1.5}
# Tiap suara aktif tambahan menambah drain suara sebesar ini (+25%).
const EXTRA_SOUND_STACK := 0.25
# Day 1: drain suara dikurangi separuh sebagai masa belajar.
const DAY1_SOUND_MULT := 0.5
# Selama badai, tugas yang sudah selesai muncul lagi setelah jeda ini (detik).
const STORM_RESPAWN_DELAY := 1.5

# Tombol debug 1-9 untuk memunculkan tugas (hanya build debug).
const DEBUG_KEYS := {
	KEY_1: "water_plant", KEY_2: "fish", KEY_3: "kettle", KEY_4: "cat_bowl",
	KEY_5: "vitamin", KEY_6: "alarm", KEY_7: "phone", KEY_8: "microwave", KEY_9: "laptop",
}

# True setelah jam habis tapi tugas A belum selesai semua.
# Diatur DayManager; dipakai untuk pesan di panel quest.
var overtime := false

var _day := 1
var _tasks: Dictionary = {}          # id -> Task
var _schedule: Array = []            # kejadian yang belum waktunya
var _pending: Array = []             # tugas yang sudah waktunya, menunggu giliran
var _required: Array = []            # id tugas A hari ini
var _done: Dictionary = {}           # id tugas A yang sudah selesai
var _running := false
var _storm_left := 0.0
var _storm_ids: Array = []
var _storm_respawn: Dictionary = {}  # id -> sisa jeda respawn
var _log_line := ""
var _hud_timer := 0.0

@onready var hud: DayHUD = $"../HUD"

func _ready() -> void:
	_day = GameState.current_day
	_schedule = TaskSchedule.for_day(_day)
	_build_roster()

	Events.day_started.connect(func(_d: int) -> void: _running = true)
	Events.time_changed.connect(_on_time_changed)
	Events.task_completed.connect(_on_task_completed)
	Events.task_late.connect(func(id: String) -> void: _log("%s TERLAMBAT" % _name_of(id)))
	Events.task_penalty.connect(func(_id: String, amount: float, reason: String) -> void:
		_log("-%.0f%%: %s" % [amount, reason]))
	Events.day_failed.connect(func(_d: int, _r: String) -> void: _shutdown())
	Events.day_succeeded.connect(func(_d: int) -> void: _shutdown())

# Buat instance scene untuk setiap tugas unik yang ada di jadwal hari ini.
func _build_roster() -> void:
	for entry in _schedule:
		for id in entry["tasks"]:
			if _tasks.has(id):
				continue
			var def: Dictionary = TaskCatalog.DEFS[id]
			var task := (load(def["scene"]) as PackedScene).instantiate() as Task
			task.task_id = id   # harus diisi sebelum add_child (dibaca di _ready Task)
			add_child(task)
			_tasks[id] = task
			if def["category"] == "A":
				_required.append(id)

# ---------- Jadwal ----------

func _on_time_changed(hour: int, minute: int) -> void:
	var now := hour + minute / 60.0
	while not _schedule.is_empty() and float(_schedule[0]["hour"]) <= now:
		var entry: Dictionary = _schedule.pop_front()
		if entry.has("storm"):
			_start_storm(entry)
		else:
			for id in entry["tasks"]:
				_pending.append({"id": id, "after": entry.get("after", "")})

func _process(delta: float) -> void:
	if not _running:
		return
	_try_spawn_pending()
	_update_storm(delta)
	_apply_sound_drain(delta)
	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.2
		_refresh_hud()

# Aktifkan tugas antrean yang sudah boleh jalan (urut kedatangan).
func _try_spawn_pending() -> void:
	var i := 0
	while i < _pending.size():
		var id: String = _pending[i]["id"]
		if _can_spawn(id, _pending[i]):
			_pending.remove_at(i)
			(_tasks[id] as Task).activate()
		else:
			i += 1

func _can_spawn(id: String, entry: Dictionary) -> bool:
	var task := _tasks[id] as Task
	if task.is_active():
		return false
	var after: String = entry["after"]
	if after != "" and not _done.has(after):
		return false
	# Tugas bersuara tunduk pada batas suara bersamaan hari ini.
	if float(TaskCatalog.DEFS[id].get("sound", 0.0)) > 0.0:
		if _active_sound_count() >= TaskSchedule.sound_limit(_day):
			return false
	return true

func _active_sound_count() -> int:
	var count := 0
	for id in _tasks:
		if (_tasks[id] as Task).is_sounding():
			count += 1
	return count

# ---------- Suara ----------

# Drain meter per frame dari semua suara yang sedang aktif.
func _apply_sound_drain(delta: float) -> void:
	var count := 0
	var rate := 0.0
	for id in _tasks:
		var task := _tasks[id] as Task
		if task.is_sounding():
			count += 1
			rate += PHASE_DRAIN[task.sound_phase]
	if count == 0 or rate <= 0.0:
		return
	rate *= 1.0 + EXTRA_SOUND_STACK * (count - 1)
	if _day == 1:
		rate *= DAY1_SOUND_MULT
	Events.meter_penalty.emit(rate * delta, "suara")

# ---------- Badai ----------

func _start_storm(entry: Dictionary) -> void:
	_storm_left = float(entry["storm"])
	_storm_ids = entry["tasks"]
	_log("BADAI!")
	for id in _storm_ids:
		(_tasks[id] as Task).activate()

# Selama badai, tugas yang selesai muncul lagi setelah jeda singkat.
func _update_storm(delta: float) -> void:
	if _storm_left <= 0.0:
		return
	_storm_left -= delta
	if _storm_left <= 0.0:
		_storm_respawn.clear()
		return
	for id in _storm_ids:
		var task := _tasks[id] as Task
		if task.is_active():
			continue
		_storm_respawn[id] = float(_storm_respawn.get(id, STORM_RESPAWN_DELAY)) - delta
		if _storm_respawn[id] <= 0.0:
			_storm_respawn.erase(id)
			task.activate()

# ---------- Penyelesaian ----------

func _on_task_completed(id: String, clean: bool) -> void:
	_log("%s selesai%s" % [_name_of(id), " (+1%)" if clean else ""])
	if id in _required:
		_done[id] = true
		if all_required_done():
			Events.required_tasks_done.emit()

# True jika semua tugas A hari ini sudah selesai (syarat menutup hari).
func all_required_done() -> bool:
	for id in _required:
		if not _done.has(id):
			return false
	return true

func _shutdown() -> void:
	_running = false
	for id in _tasks:
		(_tasks[id] as Task).deactivate()
	hud.set_quest_text("")

# ---------- Panel quest & debug ----------

func _name_of(id: String) -> String:
	return TaskCatalog.DEFS[id]["name"]

func _log(text: String) -> void:
	_log_line = text
	print("[Tugas] ", text)

func _refresh_hud() -> void:
	var lines: PackedStringArray = []
	if overtime:
		lines.append("== HARI BELUM BISA DITUTUP, selesaikan tugas harian ==")
	for id in _tasks:
		var task := _tasks[id] as Task
		if task.is_active():
			lines.append(task.status_text())
	if _log_line != "":
		lines.append(">> " + _log_line)
	hud.set_quest_text("\n".join(lines))

func _unhandled_input(event: InputEvent) -> void:
	if not (OS.is_debug_build() and event is InputEventKey and event.pressed):
		return
	var key := event as InputEventKey
	if DEBUG_KEYS.has(key.keycode):
		var id: String = DEBUG_KEYS[key.keycode]
		if _tasks.has(id):
			(_tasks[id] as Task).activate()
		else:
			_log("Debug: '%s' tidak ada di Day %d" % [id, _day])

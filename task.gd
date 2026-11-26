class_name Task
extends Node2D
# ============================================================
# TASK (Satu tugas: item + zona + langkah-langkahnya)
# ------------------------------------------------------------
# Skrip ini ditempel di root scene tugas (scenes/tasks/*.tscn).
# Anak-anak scene adalah item (Draggable) dan zona (TaskZone).
# Isi tugas (langkah, durasi suara, penalti) dibaca dari TaskCatalog.
#
# Siklus:
#   IDLE --activate()--> ACTIVE --langkah terakhir selesai--> IDLE
# Tugas B memakai instance yang sama berulang kali.
#
# Saat ACTIVE, Task:
#   1. menjalankan langkah satu per satu (tap/hold/hover/put/...)
#   2. menghitung fase suara (1-4) bila tugas bersuara
#   3. menghukum sekali bila terlambat (fase 4 atau lewat batas jam)
#   4. melaporkan penalti ke Cat lewat Events.meter_penalty
# Pengurasan meter akibat SUARA dihitung TaskManager (butuh data
# semua suara aktif sekaligus).
# ============================================================

enum State { IDLE, ACTIVE }

# Di atas kecepatan ini (px/s) gerakan dianggap CEPAT (GDD bagian C).
const FAST_SPEED := 300.0
# Klik yang dilepas dalam waktu ini (detik) dihitung tap.
const TAP_MAX_TIME := 0.3
# Jeda minimal antar penalti tumpah, supaya tidak dihukum tiap frame.
const SPILL_COOLDOWN := 1.5
# Bonus meter (%) bila tugas selesai tanpa penalti sama sekali.
const CLEAN_BONUS := 1.0

# ID tugas (kunci di TaskCatalog.DEFS). Diisi TaskManager.
var task_id: String = ""

var def: Dictionary = {}
var state: State = State.IDLE
# 0 = tidak bersuara, 1-3 = suara naik, 4 = GAGAL (suara tetap bunyi).
var sound_phase: int = 0
var is_late := false

var _steps: Array = []
var _step_index := 0
var _timer := 0.0          # waktu hold/hover pada langkah sekarang
var _pour_timer := 0.0
var _pellets := 0
var _spill_cooldown := 0.0
var _elapsed := 0.0        # waktu sejak diaktifkan (untuk fase suara)
var _clean := true         # false setelah penalti apa pun
var _hand_speed := 0.0
var _now := 6.0            # jam game terakhir (dari Events.time_changed)
var _day := 1
var _items: Array[Draggable] = []
var _zones: Array[TaskZone] = []

var _alert_item: Draggable = null   # benda yang sedang bergetar karena bunyi
var _hint_item: Draggable = null    # benda yang sedang diberi outline putih
var _hint_zone: TaskZone = null     # zona tujuan yang sedang diberi outline putih
var _sound_player: AudioStreamPlayer = null   # pemutar suara alarm (looping) yang harus dimatikan

func _ready() -> void:
	if not TaskCatalog.DEFS.has(task_id):
		push_error("Task: id '%s' tidak ada di TaskCatalog" % task_id)
		return
	def = TaskCatalog.DEFS[task_id]
	_day = GameState.current_day
	var from_days: Dictionary = def.get("items_from_day", {})
	for child in get_children():
		if child is Draggable:
			var item := child as Draggable
			_items.append(item)
			# Benda yang baru ada mulai hari tertentu (mis. lemari obat Day 4).
			var key := String(item.name)
			if from_days.has(key) and _day < int(from_days[key]):
				item.set_enabled(false)
		elif child is TaskZone:
			var zone := child as TaskZone
			_zones.append(zone)
			zone.visible = zone.show_when_idle
	Events.hand_moved.connect(func(s: float) -> void: _hand_speed = s)
	Events.time_changed.connect(func(h: int, m: int) -> void: _now = h + m / 60.0)
	Events.item_dropped.connect(_on_item_dropped)

# ---------- Siklus hidup ----------

func is_active() -> bool:
	return state == State.ACTIVE

# True jika tugas sedang menghasilkan suara (dihitung TaskManager).
func is_sounding() -> bool:
	return state == State.ACTIVE and sound_phase > 0

# Mulai tugas. Dipanggil TaskManager sesuai jadwal.
func activate() -> void:
	if state == State.ACTIVE or def.is_empty():
		return
	state = State.ACTIVE
	_steps = _steps_for_day()
	_step_index = 0
	_reset_step_progress()
	_pellets = 0
	_elapsed = 0.0
	_clean = true
	is_late = false
	sound_phase = 1 if _sound_duration() > 0.0 else 0
	for zone in _zones:
		zone.show()
	Events.task_started.emit(task_id)
	if sound_phase > 0:
		Events.sound_phase_changed.emit(task_id, sound_phase)
		
	_play_task_sound(GameState.current_day)

# Hentikan paksa (hari gagal / berakhir).
func deactivate() -> void:
	state = State.IDLE
	sound_phase = 0
	_reset_visuals()

func _complete() -> void:
	var was_clean := _clean and not is_late
	state = State.IDLE
	sound_phase = 0
	_reset_visuals()
	if was_clean:
		Events.meter_recovery.emit(CLEAN_BONUS)
	Events.task_completed.emit(task_id, was_clean)
	AudioManager.play_sfx("click", 0.05, -2.0)

func _reset_visuals() -> void:
	_stop_task_sound()
	if _hint_item:
		_hint_item.set_highlight(false)
		_hint_item = null
	if _hint_zone:
		_hint_zone.set_highlight(false)
		_hint_zone = null
	if _alert_item:
		_alert_item.set_alert(0.0)
		_alert_item = null
	for zone in _zones:
		zone.visible = zone.show_when_idle
	for item in _items:
		item.reset_to_home()

func _steps_for_day() -> Array:
	var by_day: Dictionary = def.get("steps_by_day", {})
	var best_day := -1
	for d in by_day:
		if int(d) <= _day and int(d) > best_day:
			best_day = int(d)
	return by_day[best_day] if best_day >= 0 else def["steps"]

func _sound_duration() -> float:
	return float(def.get("sound", 0.0))

# ---------- Loop utama ----------

func _process(delta: float) -> void:
	if state != State.ACTIVE:
		return
	_update_sound(delta)
	_update_alert()
	_update_highlight()
	_update_deadline()
	_spill_cooldown = maxf(0.0, _spill_cooldown - delta)
	_update_step(delta)

# Fase suara: durasi dibagi tiga (fase 1, 2, 3). Lewat durasi = fase 4 (gagal).
func _update_sound(delta: float) -> void:
	var duration := _sound_duration()
	if duration <= 0.0:
		return
	_elapsed += delta
	var phase := mini(4, 1 + int(_elapsed / (duration / 3.0)))
	if phase == sound_phase:
		return
	sound_phase = phase
	Events.sound_phase_changed.emit(task_id, phase)
	if phase == 4:
		_become_late()

# Tugas A: lewat batas jam game = terlambat.
func _update_deadline() -> void:
	var deadline := float(def.get("deadline", 0.0))
	if deadline <= 0.0 or is_late:
		return
	if _day in def.get("no_deadline_days", []):
		return
	if _now >= deadline:
		_become_late()

# Terlambat: penalti SEKALI. Suara (bila ada) tetap bunyi sampai dimatikan.
func _become_late() -> void:
	if is_late:
		return
	is_late = true
	Events.task_late.emit(task_id)
	var amount := float(def.get("penalty", 0.0))
	if amount > 0.0:
		_penalize(amount, "%s terlambat" % def["name"])
	else:
		_clean = false

func _penalize(amount: float, reason: String) -> void:
	_clean = false
	Events.meter_penalty.emit(amount, reason)
	Events.task_penalty.emit(task_id, amount, reason)

# audido
func _play_task_sound(phase_level: int = 1) -> void:
	# Sesuaikan volume berdasarkan fase (Fase 1 pelan, Fase 3 nyaring)
	var vol_db := -10.0
	if phase_level == 2:
		vol_db = -4.0
	elif phase_level >= 3:
		vol_db = 2.0

	match task_id: # sesuaikan dengan nama variabel ID tugas di task.gd Anda
		"alarm":
			_stop_task_sound()
			_sound_player = AudioManager.play_sfx("alarm", 0.0, vol_db)
		"phone", "laptop", "microwave", "kettle":
			# Gunakan click/alert sementara jika file RAW belum dikonversi ke .wav/.ogg
			AudioManager.play_sfx("click", 0.1, vol_db)
		"water_plant":
			AudioManager.play_sfx("water", 0.05, 0.0)

# Matikan suara looping (alarm) saat tugas selesai / dibatalkan.
func _stop_task_sound() -> void:
	if _sound_player and is_instance_valid(_sound_player):
		_sound_player.stop()
	_sound_player = null

# ---------- Penilaian langkah ----------

func _update_step(delta: float) -> void:
	if _step_index >= _steps.size():
		return
	var step: Dictionary = _steps[_step_index]
	var item := _item_of(step)
	if item == null:
		return

	# Tumpah / berisik: bergerak cepat sambil membawa item.
	if step.has("spill") and item.is_held and _hand_speed > FAST_SPEED and _spill_cooldown <= 0.0:
		_spill_cooldown = SPILL_COOLDOWN
		_penalize(float(step["spill"]), "Gerakan terlalu cepat (%s)" % item.item_name)

	var strict: bool = step.get("strict", false)
	match step["type"]:
		"hold":
			if item.is_held and not (strict and _hand_speed > FAST_SPEED):
				_timer += delta
				if _timer >= float(step["seconds"]):
					_finish_step()
			else:
				_timer = 0.0
		"hover":
			var zone := _zone_of(step)
			var inside := item.is_held and zone != null and zone.contains_point(item.global_position)
			if inside and _hand_speed <= FAST_SPEED:
				_timer += delta
				if _timer >= float(step["seconds"]):
					_finish_step()
			elif strict:
				_timer = 0.0   # gerak cepat / keluar zona mengulang dari nol
		"pour":
			var zone := _zone_of(step)
			if item.is_held and zone != null and zone.contains_point(item.global_position):
				_pour_timer += delta
				if _pour_timer >= float(step.get("interval", 0.8)):
					_pour_timer = 0.0
					_pellets += 1
					if _pellets == int(step["limit"]) + 1:
						_penalize(float(step.get("overfeed_penalty", 3.0)), "Overfeed")
			else:
				_pour_timer = 0.0

# Langkah yang dinilai saat item DILEPAS: tap, put, release, pour.
func _on_item_dropped(item: Draggable, _impact_speed: float) -> void:
	if state != State.ACTIVE or _step_index >= _steps.size():
		return
	var step: Dictionary = _steps[_step_index]
	if _item_of(step) != item:
		return
	_timer = 0.0   # lepas = hitungan hold/hover berhenti
	match step["type"]:
		"tap":
			if item.last_hold_time <= TAP_MAX_TIME:
				_finish_step()
		"put":
			var zone := _zone_of(step)
			if zone != null and zone.contains_point(item.global_position):
				if step.get("stay", false):
					item.keep_here()
				_finish_step()
		"release":
			_finish_step()
		"pour":
			if _pellets >= int(step["limit"]):
				_finish_step()

func _finish_step() -> void:
	var step: Dictionary = _steps[_step_index]
	if step.get("toggle", false):
		var item := _item_of(step)
		if item:
			item.toggle()
	_step_index += 1
	_reset_step_progress()
	if _step_index >= _steps.size():
		_complete()

func _reset_step_progress() -> void:
	_timer = 0.0
	_pour_timer = 0.0

func _item_of(step: Dictionary) -> Draggable:
	return get_node_or_null(NodePath(step["item"])) as Draggable

func _zone_of(step: Dictionary) -> TaskZone:
	if not step.has("zone"):
		return null
	return get_node_or_null(NodePath(step["zone"])) as TaskZone

# ---------- Teks untuk panel quest ----------

func status_text() -> String:
	var text: String = def["name"]
	var deadline := float(def.get("deadline", 0.0))
	if deadline > 0.0 and not (_day in def.get("no_deadline_days", [])):
		text += " (batas %s)" % _format_hour(deadline)
	if sound_phase > 0:
		text += " [suara %d/4]" % sound_phase
	if is_late:
		text += " TERLAMBAT"
	if _step_index < _steps.size():
		var step: Dictionary = _steps[_step_index]
		text += " > %s%s" % [step.get("hint", ""), _progress_text(step)]
	return text

func _progress_text(step: Dictionary) -> String:
	match step["type"]:
		"hold", "hover":
			return " (%.1f/%.1f dtk)" % [_timer, float(step["seconds"])]
		"pour":
			return " (pelet %d/%d)" % [_pellets, int(step["limit"])]
	return ""

func _format_hour(hour: float) -> String:
	return "%02d:%02d" % [int(hour), int((hour - floorf(hour)) * 60.0)]

# Benda yang SEDANG BUNYI bergetar/berkedip. Suara palsu tidak punya ini,
# jadi pemain bisa belajar membedakannya (GDD Day 4).
func _update_alert() -> void:
	var target: Draggable = null
	if is_sounding() and _step_index < _steps.size():
		target = _item_of(_steps[_step_index])
		if target and target.is_held:
			target = null
	if _alert_item and _alert_item != target:
		_alert_item.set_alert(0.0)
	_alert_item = target
	if target:
		target.set_alert(minf(float(sound_phase) / 3.0, 1.0))   # makin keras makin kuat

# Outline putih pada benda yang harus disentuh di langkah sekarang.
# Hilang saat benda dipegang, muncul lagi bila dilepas sebelum langkah selesai.
func _update_highlight() -> void:
	var target: Draggable = null
	var zone: TaskZone = null
	if _step_index < _steps.size():
		var step: Dictionary = _steps[_step_index]
		target = _item_of(step)
		zone = _zone_of(step)
		if target and target.is_held:
			target = null
	if _hint_item and _hint_item != target:
		_hint_item.set_highlight(false)
	_hint_item = target
	if target:
		target.set_highlight(true)
	if _hint_zone and _hint_zone != zone:
		_hint_zone.set_highlight(false)
	_hint_zone = zone
	if zone:
		zone.set_highlight(true)

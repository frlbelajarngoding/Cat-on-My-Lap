class_name DayManager
extends Node
# ============================================================
# DAY MANAGER (Pengatur siklus harian)
# ------------------------------------------------------------
# Alur satu hari:
#   mulai -> jam berjalan -> (gagal ATAU jam habis = sukses)
#   sukses: minum obat -> blackout -> hari berikut / ending
#   gagal : efek (dikerjakan Effect Glitch) -> ulang
# Data lintas-scene disimpan di GameState (autoload).
# ============================================================

enum Phase { RUNNING, DAY_ENDING, FAILED, FINISHED }

# Lama animasi "minum obat" (detik). Ganti dengan animasi asli nanti.
@export var medicine_duration: float = 2.5
# Lama fade ke hitam setelah minum obat.
@export var fade_duration: float = 1.0
# Jeda setelah gagal, memberi waktu efek glitch/rewind (detik).
@export var fail_delay: float = 2.0

var phase: Phase = Phase.RUNNING

# Toleransi terbaru kucing, disalin dari Events (tanpa referensi ke Cat).
var _tolerance: float = 0.0

@onready var clock: GameClock = $GameClock
@onready var hud: DayHUD = $"../HUD"
@onready var tasks: TaskManager = $"../TaskManager"

func _ready() -> void:
	Events.tolerance_changed.connect(func(value: float, _max: float) -> void: _tolerance = value)
	Events.cat_woke_up.connect(_fail.bind("Kucingnya bangun!"))
	Events.cat_fell.connect(_fail.bind("Kucingnya jatuh!"))
	Events.task_failed.connect(_fail)
	Events.day_time_ended.connect(_on_day_time_ended)

	# Tunggu 1 frame supaya semua node lain (HUD, Cat) selesai _ready()
	# dan sudah terhubung ke signal sebelum hari dimulai.
	await get_tree().process_frame
	_start_day()

func _start_day() -> void:
	phase = Phase.RUNNING
	Events.day_started.emit(GameState.current_day)
	clock.start()

# ---------- GAGAL ----------

# Dipanggil oleh kucing bangun/jatuh atau Events.task_failed.
func _fail(reason: String) -> void:
	if phase != Phase.RUNNING:
		return   # abaikan kegagalan ganda atau kegagalan saat hari berakhir
	phase = Phase.FAILED
	clock.stop()
	hud.show_status(reason)
	# Effect Glitch/Rewind mendengarkan sinyal ini.
	Events.day_failed.emit(GameState.current_day, reason)

	await get_tree().create_timer(fail_delay).timeout
	GameState.fail_day()
	get_tree().reload_current_scene()

# ---------- SUKSES ----------

# Jam mencapai akhir hari (22:00). Hari hanya bisa ditutup bila semua tugas A
# (mangkuk kucing, vitamin, dll.) selesai. Bila belum, jam berhenti di 22:00 dan
# pemain masih harus menyelesaikannya, dengan meter kucing tetap berjalan.
func _on_day_time_ended() -> void:
	if phase != Phase.RUNNING:
		return
	if not tasks.all_required_done():
		tasks.overtime = true
		await Events.required_tasks_done
		tasks.overtime = false
		if phase != Phase.RUNNING:
			return   # kucing keburu bangun/jatuh saat lembur
	_finish_day()

func _finish_day() -> void:
	phase = Phase.DAY_ENDING
	Events.day_succeeded.emit(GameState.current_day)

	# Placeholder animasi minum obat (Cutscene dapat menggantinya).
	hud.show_status("Minum obat...")
	await get_tree().create_timer(medicine_duration).timeout
	await hud.fade_to_black(fade_duration)

	# Simpan toleransi akhir hari untuk besok.
	var has_next := GameState.advance_day(_tolerance)
	if has_next:
		get_tree().reload_current_scene()
	else:
		_show_ending()

# Semua hari selesai. Cutscene Ending nanti mengambil alih lewat signal.
func _show_ending() -> void:
	phase = Phase.FINISHED
	Events.game_completed.emit()
	hud.show_status("ENDING\nTekan R untuk main lagi")

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	# Setelah ending, R mengulang game dari Day 1.
	if phase == Phase.FINISHED and event.keycode == KEY_R:
		GameState.new_game()
		get_tree().reload_current_scene()
	# Tombol debug (hanya aktif di editor / build debug).
	if OS.is_debug_build():
		if event.keycode == KEY_F1:
			Events.task_failed.emit("Debug: tugas gagal")
		elif event.keycode == KEY_F2:
			clock.time_hours = clock.end_hour - 0.01   # loncat ke akhir hari
		elif event.keycode == KEY_F3:
			clock.speed_scale = 1.0 if clock.speed_scale > 1.0 else 4.0   # jam x4 / normal
		elif event.keycode == KEY_F4:
			# Ganti ke hari berikutnya (1..MAX_DAY) untuk mencoba jadwal tiap hari.
			GameState.current_day = GameState.current_day % GameState.MAX_DAY + 1
			GameState.carried_tolerance = 0.0
			get_tree().reload_current_scene()

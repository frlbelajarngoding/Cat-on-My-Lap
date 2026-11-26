class_name DayManager
extends Node
# ============================================================
# DAY MANAGER (Pengatur siklus harian)
# ------------------------------------------------------------
# Alur satu hari:
#   mulai -> jam berjalan -> (gagal ATAU jam habis = sukses)
#   sukses: minum obat -> blackout -> hari berikut / ending
#   gagal : hold -> rewind (FX) -> reload scene
# Data lintas-scene disimpan di GameState (autoload).
# Efek visual dikerjakan FX; ending dikerjakan EndingCutscene.
# ============================================================

enum Phase { RUNNING, DAY_ENDING, FAILED, FINISHED }

# Lama animasi "minum obat" (detik). Ganti dengan animasi asli nanti.
@export var medicine_duration: float = 2.5
# Lama fade ke hitam setelah minum obat.
@export var fade_duration: float = 1.0
# Jeda setelah gagal sebelum rewind dimulai: memberi waktu animasi
# kucing bangun/jatuh selesai dan pemain membaca alasan gagal (detik).
@export var fail_delay: float = 1.0

var phase: Phase = Phase.RUNNING

# Toleransi terbaru kucing, disalin dari Events (tanpa referensi ke Cat).
var _tolerance: float = 0.0

@onready var clock: GameClock = $GameClock
@onready var hud: DayHUD = $"../HUD"
@onready var tasks: TaskManager = $"../TaskManager"
# Boleh null: bila scene FX belum dipasang, game tetap jalan tanpa efek.
@onready var fx: FXLayer = get_node_or_null("../FX")

func _ready() -> void:
	Events.tolerance_changed.connect(func(value: float, _max: float) -> void: _tolerance = value)
	Events.cat_woke_up.connect(_fail.bind("Kucingnya bangun!"))
	Events.cat_fell.connect(_fail.bind("Kucingnya jatuh!"))
	Events.task_failed.connect(_fail)
	Events.day_time_ended.connect(_on_day_time_ended)
	Events.task_completed.connect(_on_task_completed)
	# Cat meng-emit nilai awal SEBELUM DayManager terhubung, jadi isi manual.
	_tolerance = GameState.start_tolerance()

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
		return
	phase = Phase.FAILED
	clock.stop()
	hud.show_status(reason)
	Events.day_failed.emit(GameState.current_day, reason)

	# Day 1 (tutorial): restart langsung tanpa jeda panjang dan tanpa penalti.
	var delay := 0.6 if GameState.is_forgiving_day() else fail_delay
	await get_tree().create_timer(delay).timeout
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
	var done_day := GameState.current_day
	var end_tolerance := _tolerance   # simpan SEKARANG, sebelum animasi akhir hari
	Events.day_succeeded.emit(done_day)

	if done_day >= GameState.MAX_DAY:
		# Day 5: lampu dimatikan -> kabel tertarik -> ending (tanpa "minum obat").
		hud.show_status("Kabelnya tertarik...")
		await get_tree().create_timer(1.5).timeout
		# Bila memakai EndingCutscene, layar tidak di-fade (efek CRT-off butuh gambar game).
		if get_node_or_null("../EndingCutscene") == null:
			await hud.fade_to_black(fade_duration)
	else:
		hud.show_status("Minum obat...")
		await get_tree().create_timer(medicine_duration).timeout
		await hud.fade_to_black(fade_duration)
		# Interlude: teks pendek di layar hitam sebelum hari berikutnya.
		await hud.play_interlude(DayStory.interlude_for(done_day))

	var has_next := GameState.advance_day(end_tolerance)
	if has_next:
		get_tree().reload_current_scene()
	else:
		_show_ending()

# Semua hari selesai. EndingCutscene mengambil alih lewat Events.game_completed.
func _show_ending() -> void:
	phase = Phase.FINISHED
	get_tree().paused = true   # bekukan Cat, Hand, Player, jam, tugas (FX & cutscene tetap jalan)
	Events.game_completed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
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
		elif event.keycode == KEY_F5 and phase == Phase.RUNNING:
			# Langsung ke ending untuk mengetes cutscene tanpa main 5 hari.
			clock.stop()
			Events.day_succeeded.emit(GameState.current_day)   # menghentikan semua tugas
			_show_ending()

# Tugas "lamp" selesai: bila semua tugas A lain juga beres, ending langsung
# dimulai tanpa menunggu jam 22:00. call_deferred memastikan TaskManager
# sudah mencatat tugas ini (urutan penerimaan signal tidak dijamin).
func _on_task_completed(id: String, _clean: bool) -> void:
	if id == "lamp":
		_try_lamp_ending.call_deferred()

func _try_lamp_ending() -> void:
	if phase == Phase.RUNNING and tasks.all_required_done():
		clock.stop()
		_finish_day()

class_name EndingCutscene
extends CanvasLayer
# ============================================================
# ENDING CUTSCENE (twist: pemain = pengamat di balik layar)
# ------------------------------------------------------------
# Dipicu Events.game_completed (dari DayManager, game sudah di-pause).
# Urutan:
#   1. Layar game "dimatikan" (FX.play_crt_off).
#   2. Gelap total sebentar.
#   3. Pantulan "pemain" samar muncul di layar monitor.
#   4. Log observasi diketik baris demi baris (data dari GameState).
#   5. Baris terakhir + glitch: pemain adalah operator. Tekan R = ulang.
# process_mode = ALWAYS karena game sedang di-pause.
# ============================================================

# Detik per karakter saat mengetik log.
@export var type_speed: float = 0.035
# Jeda setelah tiap baris selesai diketik (detik).
@export var line_pause: float = 0.9
# Transparansi pantulan: samar di awal, lebih jelas saat twist.
@export var reflection_alpha: float = 0.22
@export var reflection_alpha_reveal: float = 0.45

var _running := false       # mencegah cutscene berjalan dua kali
var _can_restart := false   # R baru berlaku setelah cutscene selesai

@onready var black: ColorRect = $Black            # penutup hitam penuh
@onready var reflection: Control = $Reflection    # siluet pantulan pemain (placeholder)
@onready var log_label: Label = $LogLabel         # log observasi gaya terminal
@onready var prompt_label: Label = $PromptLabel   # petunjuk "Tekan R"
@onready var fx: FXLayer = get_node_or_null("../FX")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()   # tersembunyi sampai ending benar-benar dimulai
	black.modulate.a = 0.0
	reflection.modulate.a = 0.0
	log_label.text = ""
	prompt_label.hide()
	Events.game_completed.connect(_play)

func _play() -> void:
	if _running:
		return
	_running = true
	show()   # tampilkan cutscene sekarang

	# 1. Layar game dimatikan ala CRT.
	if fx:
		await fx.play_crt_off()

	# Tutup dengan hitam milik cutscene dulu, baru kembalikan efek ke normal,
	# supaya tidak ada kedipan gambar game satu frame.
	black.modulate.a = 1.0
	if fx:
		fx.reset_crt()

	# 2. Gelap total.
	await _wait(1.2)

	# 3. Pantulan "pemain" muncul perlahan di layar yang mati.
	if Events.has_signal("glitch_requested"):
		Events.glitch_requested.emit(0.5, 0.4)
	create_tween().tween_property(reflection, "modulate:a", reflection_alpha, 2.5)
	await _wait(2.0)

	# 4. Log observasi diketik.
	var lines := _build_lines()
	for i in lines.size():
		await _type_line(lines[i])
		await _wait(line_pause)

	# 5. Twist: pantulan makin jelas + glitch besar.
	if Events.has_signal("glitch_requested"):
		Events.glitch_requested.emit(1.0, 0.6)
	create_tween().tween_property(reflection, "modulate:a", reflection_alpha_reveal, 1.0)
	await _wait(1.5)
	prompt_label.show()
	_can_restart = true

# Isi log. Nilai diambil dari GameState supaya terasa personal.
# carried_tolerance setelah Day 5 = tingkat stres akhir subjek (meter toleransi = stres).
func _build_lines() -> PackedStringArray:
	var stress := roundi(GameState.carried_tolerance)
	return PackedStringArray([
		"> SESI OBSERVASI #07 ........ SELESAI",
		"> SUBJEK: bertahan 5/5 hari",
		"> TINGKAT STRES AKHIR: %d%%" % stress,
		"> PERCOBAAN ULANG: %d" % GameState.attempts,
		"> PENSTABIL STRES: KUCING [aktif]",
		"",
		"Kucing itu bukan sekadar peliharaan.",
		"Dia alasan subjek tetap tenang.",
		"",
		"> OPERATOR: terdeteksi di depan layar.",
	])

# Mengetik satu baris ke LogLabel (efek mesin ketik lewat visible_ratio).
func _type_line(line: String) -> void:
	var prev_len := log_label.text.length()
	log_label.text += line + "\n"
	var total := log_label.text.length()
	log_label.visible_ratio = float(prev_len) / float(total)
	var tw := create_tween()
	tw.tween_property(log_label, "visible_ratio", 1.0, maxf(0.05, line.length() * type_speed))
	await tw.finished

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

# R = main lagi dari Day 1 (hanya setelah cutscene selesai).
func _unhandled_input(event: InputEvent) -> void:
	if _can_restart and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		GameState.new_game()
		GameState.transition = "next_day"   # scene baru fade-in dari hitam
		get_tree().paused = false           # WAJIB: reload saat paused = game baru ikut beku
		get_tree().reload_current_scene()

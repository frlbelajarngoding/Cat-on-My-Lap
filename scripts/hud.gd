class_name DayHUD
extends CanvasLayer
# ============================================================
# HUD (Jam, hari, teks status, blackout)
# ------------------------------------------------------------
# Hanya menampilkan. Logika hari ada di DayManager.
# DayManager memanggil show_status() dan fade_to_black().
# ============================================================

@onready var day_label: Label = $DayLabel
@onready var clock_label: Label = $ClockLabel
@onready var status_label: Label = $StatusLabel
@onready var blackout: ColorRect = $Blackout
@onready var quest_label: Label = $QuestLabel

func _ready() -> void:
	blackout.modulate.a = 0.0   # mulai transparan
	status_label.hide()
	Events.time_changed.connect(_on_time_changed)
	Events.day_started.connect(_on_day_started)

# Format jam "HH:MM". hour % 24 supaya jam 24 tampil sebagai 00.
func _on_time_changed(hour: int, minute: int) -> void:
	clock_label.text = "%02d:%02d" % [hour % 24, minute]

func _on_day_started(day: int) -> void:
	day_label.text = "Day %d" % [day]

# Menampilkan teks di tengah layar (mis. "Minum obat...").
func show_status(text: String) -> void:
	status_label.text = text
	status_label.show()

# Mengisi panel quest (daftar tugas aktif). Diisi TaskManager.
func set_quest_text(text: String) -> void:
	quest_label.text = text

# Layar memudar jadi hitam. Pemanggil bisa: await hud.fade_to_black(1.0)
func fade_to_black(duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(blackout, "modulate:a", 1.0, duration)
	await tw.finished

# Menyembunyikan teks status (mis. "Déjà vu..." setelah beberapa detik).
func hide_status() -> void:
	status_label.hide()

# Dipakai FX saat rewind: jam HUD berputar mundur. hours = jam desimal (7.5 = 07:30).
func show_rewind_clock(hours: float) -> void:
	var h := floori(hours)
	var m := floori((hours - h) * 60.0)
	clock_label.text = "%02d:%02d" % [h % 24, m]

# Dipakai FX saat rewind pada mode RESTART_ALL: angka Day berputar mundur.
func show_rewind_day(day: int) -> void:
	day_label.text = "Day %d" % day

# Interlude: teks muncul satu per satu di layar hitam (setelah fade_to_black).
# Gunakan: await hud.play_interlude(lines)
func play_interlude(lines: PackedStringArray, seconds_per_line: float = 2.2) -> void:
	for line in lines:
		status_label.text = line
		status_label.modulate.a = 0.0
		status_label.show()
		var tw := create_tween()
		tw.tween_property(status_label, "modulate:a", 1.0, 0.5)
		tw.tween_interval(seconds_per_line)
		tw.tween_property(status_label, "modulate:a", 0.0, 0.5)
		await tw.finished
	status_label.hide()
	status_label.modulate.a = 1.0

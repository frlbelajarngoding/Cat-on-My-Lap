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

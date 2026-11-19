class_name GameClock
extends Node
# ============================================================
# GAME CLOCK (Jam internal game)
# ------------------------------------------------------------
# Memutar jam game dari start_hour sampai end_hour, lalu memberi
# tahu lewat Events. Tidak tahu apa pun soal kucing atau tugas.
# Skala: seconds_per_hour detik nyata = 1 jam game.
# Default 8 detik/jam: hari 06:00-24:30 berlangsung sekitar 2,5 menit.
# ============================================================

# Jam mulai hari (06:00, sama dengan alarm pertama).
@export var start_hour: float = 6.0
# Jam berakhirnya hari. 24.5 = 00:30, memberi waktu mematikan alarm tengah malam.
@export var end_hour: float = 24.5
# Detik nyata per 1 jam game. Makin kecil = hari makin cepat.
@export var seconds_per_hour: float = 8.0

# Waktu game saat ini dalam jam desimal (mis. 7.5 = 07:30).
# Boleh dibaca sistem lain (mis. cek apakah di rentang 7-9).
var time_hours: float = 6.0
# True selama jam berjalan.
var running := false

# Cache supaya signal hanya dikirim saat nilainya berganti.
var _last_hour := -1
var _last_total_minute := -1

func _ready() -> void:
	time_hours = start_hour

# Mulai hari baru dari start_hour.
func start() -> void:
	time_hours = start_hour
	_last_hour = -1
	_last_total_minute = -1
	running = true
	_broadcast()

# Hentikan jam (saat gagal / blackout).
func stop() -> void:
	running = false

func _process(delta: float) -> void:
	if not running:
		return
	time_hours += delta / seconds_per_hour
	if time_hours >= end_hour:
		time_hours = end_hour
		_broadcast()
		running = false
		Events.day_time_ended.emit()
		return
	_broadcast()

# Memancarkan signal hanya jika jam/menit benar-benar berganti.
func _broadcast() -> void:
	var hour := floori(time_hours)
	var minute := floori((time_hours - hour) * 60.0)
	var total_minute := hour * 60 + minute
	if hour != _last_hour:
		_last_hour = hour
		Events.hour_reached.emit(hour)       # alarm: 6, 12, 18, 24
	if total_minute != _last_total_minute:
		_last_total_minute = total_minute
		Events.time_changed.emit(hour, minute)

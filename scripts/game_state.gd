extends Node
# ============================================================
# GAME STATE (Autoload / Singleton)
# ------------------------------------------------------------
# Menyimpan data yang HARUS bertahan saat scene di-reload:
# hari saat ini dan toleransi yang terbawa dari hari sebelumnya.
# Dipanggil oleh DayManager (menulis) dan Cat (membaca).
# ============================================================

# Mode saat gagal:
#   RETRY_DAY   = ulang dari pagi di hari yang sama
#   RESTART_ALL = kembali ke Day 1 (sesuai catatan "start from day 1")
enum FailMode { RETRY_DAY, RESTART_ALL }

# Hari terakhir; setelah ini ending dimainkan.
const MAX_DAY := 5
# Toleransi awal tidak boleh melebihi ini (supaya tidak langsung bangun).
const MAX_CARRY := 95.0

# Pilih mode gagal (bisa diganti saat playtest).
var fail_mode: FailMode = FailMode.RETRY_DAY
# Toleransi yang bertambah setiap kali gagal (mode RETRY_DAY).
var fail_penalty: float = 5.0
# Kenaikan sensitivitas kucing/gangguan per hari (hari 1 = 1.0).
var sensitivity_per_day: float = 0.15

# Hari saat ini (1..MAX_DAY).
var current_day: int = 1
# Toleransi di awal hari ini. Juga dipakai Cat sebagai LANTAI toleransi
# (tidak bisa turun di bawah nilai ini sepanjang hari).
var carried_tolerance: float = 0.0
# Jumlah gagal sejak game dimulai (untuk statistik / narasi).
var attempts: int = 0

# Mulai game dari awal (Day 1, toleransi 0). attempts tidak direset.
func new_game() -> void:
	current_day = 1
	carried_tolerance = 0.0

# Dipanggil saat hari sukses. Menyimpan toleransi akhir hari sebagai
# toleransi awal besok. Return true bila masih ada hari berikutnya.
func advance_day(end_tolerance: float) -> bool:
	current_day += 1
	carried_tolerance = minf(end_tolerance, MAX_CARRY)
	return current_day <= MAX_DAY

# Dipanggil saat hari gagal. Menentukan kondisi untuk percobaan berikutnya.
func fail_day() -> void:
	attempts += 1
	match fail_mode:
		FailMode.RETRY_DAY:
			# Tetap di hari ini, tapi meter makin "menurun".
			carried_tolerance = minf(carried_tolerance + fail_penalty, MAX_CARRY)
		FailMode.RESTART_ALL:
			new_game()

# Pengali sensitivitas untuk Cat: makin banyak hari, makin sensitif.
func sensitivity_for_day() -> float:
	return 1.0 + (current_day - 1) * sensitivity_per_day

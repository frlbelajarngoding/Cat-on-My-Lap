extends Node
# ============================================================
# GAME STATE (Autoload / Singleton)
# ------------------------------------------------------------
# Data yang HARUS bertahan saat scene di-reload + tabel penyeimbang
# per hari (GDD). Meter di GDD = 100 - tolerance di kode.
# ============================================================

enum FailMode { RETRY_DAY, RESTART_ALL }

const MAX_DAY := 5
const MAX_CARRY := 95.0

# Meter kucing di AWAL hari (%) menurut GDD.
const START_METER_BY_DAY := {1: 100.0, 2: 90.0, 3: 80.0, 4: 70.0, 5: 60.0}
# Pengali gangguan Cat. Day 1 sangat longgar ("hampir mustahil gagal").
const SENSITIVITY_BY_DAY := {1: 0.5, 2: 1.0, 3: 1.1, 4: 1.2, 5: 1.3}
# Distorsi visual/audio dasar per hari (0..1). Dipakai FX dan tim audio.
const DISTORTION_BY_DAY := {1: 0.0, 2: 0.0, 3: 0.06, 4: 0.12, 5: 0.22}
# Bar meter hanya terlihat sampai hari ini.
const METER_BAR_LAST_DAY := 5
# Hari "tutorial": gagal tanpa penalti dan restart langsung.
const FORGIVING_DAYS := [1]

var fail_mode: FailMode = FailMode.RETRY_DAY
# Tolerance tambahan tiap kali gagal (mode RETRY_DAY), tidak berlaku di FORGIVING_DAYS.
var fail_penalty: float = 5.0

var current_day: int = 1
# Tolerance akhir hari sebelumnya (atau hasil penalti gagal).
var carried_tolerance: float = 0.0
var attempts: int = 0
# Alasan scene dimuat ulang ("", "rewind", "next_day"). Dipakai FX bila ada.
var transition: String = ""

func new_game() -> void:
	current_day = 1
	carried_tolerance = 0.0

func advance_day(end_tolerance: float) -> bool:
	current_day += 1
	carried_tolerance = minf(end_tolerance, MAX_CARRY)
	return current_day <= MAX_DAY

func fail_day() -> void:
	attempts += 1
	match fail_mode:
		FailMode.RETRY_DAY:
			if is_forgiving_day():
				return   # Day 1: ulang tanpa penalti
			carried_tolerance = minf(start_tolerance() + fail_penalty, MAX_CARRY)
		FailMode.RESTART_ALL:
			new_game()

# Tolerance di awal hari ini = yang lebih buruk antara tabel GDD dan sisa kemarin.
# Cat memakainya sebagai tolerance awal sekaligus LANTAI hari itu.
func start_tolerance() -> float:
	var base := 100.0 - float(START_METER_BY_DAY.get(current_day, 60.0))
	return minf(maxf(base, carried_tolerance), MAX_CARRY)

func sensitivity_for_day() -> float:
	return float(SENSITIVITY_BY_DAY.get(current_day, 1.3))

func distortion_for_day() -> float:
	return float(DISTORTION_BY_DAY.get(current_day, 0.22))

func is_meter_bar_visible() -> bool:
	return current_day <= METER_BAR_LAST_DAY

func is_forgiving_day() -> bool:
	return current_day in FORGIVING_DAYS

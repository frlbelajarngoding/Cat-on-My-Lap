class_name TaskSchedule
extends RefCounted
# ============================================================
# TASK SCHEDULE (Jadwal tugas per hari)
# ------------------------------------------------------------
# for_day(day) mengembalikan daftar kejadian terurut jam:
#   {"hour": 13.5, "tasks": ["alarm", "phone"]}
# Satu kejadian dengan banyak tugas = suara bersamaan (Day 2: 13:30 & 17:00).
#
# Kunci opsional:
#   "after": id tugas yang harus selesai dulu (vitamin menunggu mangkuk).
#   "storm": detik lamanya badai. Semua tugas dalam daftar dimunculkan
#            lagi dan lagi selama waktu itu (Day 4, 14:00).
#
# 1 jam game = 15 detik nyata (lihat GameClock), jadi tugas B yang
# berdurasi 12-15 detik kira-kira 1 jam game. Jarak antar kejadian
# dibuat >= 1 jam agar tidak menumpuk tanpa sengaja.
# ============================================================

# Batas suara bersamaan per hari (GDD bagian E).
const SOUND_LIMIT_BY_DAY := {1: 1, 2: 2, 3: 3, 4: 4, 5: 4}

static func sound_limit(day: int) -> int:
	return SOUND_LIMIT_BY_DAY.get(day, 4)

static func for_day(day: int) -> Array:
	var e: Array = []

	# ----- Kategori A: muncul sekali, wajib selesai sebelum hari ditutup -----
	e.append(_at(7.5, ["water_plant"]))
	if day >= 2:
		e.append(_at(8.5, ["fish"]))        # Day 2: akuarium tiba-tiba ada
	if day >= 3:
		e.append(_at(11.0, ["kettle"]))
	# Tugas penutup hari: mangkuk kucing, lalu vitamin.
	e.append(_at(20.0, ["cat_bowl"]))
	e.append({"hour": 20.0, "tasks": ["vitamin"], "after": "cat_bowl"})
	# Hari terakhir: tugas pamungkas = matikan lampu (memicu ending).
	if day >= GameState.MAX_DAY:
		e.append({"hour": 20.0, "tasks": ["lamp"], "after": "vitamin"})

	# ----- Kategori B: berulang. Frekuensi naik tiap hari -----
	match day:
		1:
			# Jeda tenang: 11:00-15:30 (mencakup 13:00) dan 16:30-19:00 (mencakup 18:00).
			e.append(_at(9.0, ["alarm"]))
			e.append(_at(11.0, ["laptop"]))
			e.append(_at(15.5, ["alarm"]))
			e.append(_at(19.0, ["laptop"]))
		2:
			# Microwave BELUM ada (GDD: baru Day 3). Dua suara bersamaan: 13:30 dan 17:00.
			e.append(_at(8.0, ["alarm"]))
			e.append(_at(9.5, ["laptop"]))
			e.append(_at(10.5, ["phone"]))
			e.append(_at(13.5, ["alarm", "phone"]))
			e.append(_at(15.0, ["laptop"]))
			e.append(_at(16.0, ["alarm"]))
			e.append(_at(17.0, ["phone", "laptop"]))
			e.append(_at(18.5, ["alarm"]))
			e.append(_at(19.0, ["laptop"]))
		3:
			e.append(_at(7.0, ["alarm"]))
			e.append(_at(8.0, ["laptop"]))
			e.append(_at(9.0, ["phone"]))
			e.append(_at(10.0, ["microwave"]))
			e.append(_at(12.0, ["laptop", "phone"]))
			e.append(_at(13.5, ["alarm", "microwave", "phone"]))   # tiga suara
			e.append(_at(15.0, ["laptop"]))
			e.append(_at(16.0, ["phone", "microwave"]))
			e.append(_at(17.5, ["laptop", "alarm"]))
			e.append(_at(18.5, ["phone", "laptop"]))
		4:
			# Suara palsu pertama di 07:00. Sebelum dan sesudahnya sepi (sampai 09:00)
			# supaya pemain sempat sadar polanya: benda sumbernya TIDAK bergetar.
			e.append(_fake(7.0, "phone"))
			e.append(_at(9.0, ["microwave", "laptop"]))
			e.append(_at(10.0, ["alarm", "phone"]))
			e.append(_at(12.0, ["laptop", "microwave"]))
			# Badai 14:00: telepon, alarm, microwave bersamaan 25 detik.
			e.append({"hour": 14.0, "tasks": ["phone", "alarm", "microwave"], "storm": 25.0})
			e.append(_at(16.0, ["phone", "laptop", "alarm"]))
			e.append(_fake(17.0, "alarm"))
			e.append(_at(17.5, ["microwave", "laptop"]))
			e.append(_at(18.5, ["phone", "alarm"]))
			e.append(_at(19.5, ["laptop", "microwave"]))
			e.append(_at(20.5, ["alarm", "laptop"]))
		_:
			# Day 5: frekuensi tertinggi + banyak suara palsu.
			e.append(_at(6.5, ["alarm", "laptop"]))
			e.append(_at(7.5, ["phone", "microwave"]))
			e.append(_fake(8.0, "phone"))
			e.append(_at(9.0, ["laptop", "alarm", "phone"]))
			e.append(_at(10.5, ["microwave", "laptop"]))
			e.append(_fake(11.5, "alarm"))
			e.append(_at(12.0, ["alarm", "phone", "laptop"]))
			e.append(_at(13.5, ["microwave", "phone"]))
			e.append(_fake(14.5, "microwave"))
			e.append(_at(15.0, ["laptop", "alarm", "microwave"]))
			e.append(_at(16.5, ["phone", "laptop"]))
			e.append(_fake(17.0, "phone"))
			e.append(_at(18.0, ["alarm", "microwave", "phone"]))
			e.append(_at(19.5, ["laptop", "phone"]))

	e.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["hour"] < b["hour"])
	return e

static func _at(hour: float, tasks: Array) -> Dictionary:
	return {"hour": hour, "tasks": tasks}

# Suara palsu: terdengar seperti sumber_id tapi TIDAK ada tugasnya.
# "tasks": [] wajib ada karena TaskManager._build_roster membaca kunci ini.
static func _fake(hour: float, source_id: String, seconds: float = 8.0) -> Dictionary:
	return {"hour": hour, "tasks": [], "fake": source_id, "seconds": seconds}

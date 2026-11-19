extends Node
# ============================================================
# EVENTS (Autoload / Singleton)
# ------------------------------------------------------------
# "Kotak surat" signal global. Skrip lain tidak perlu saling
# menyimpan referensi; cukup emit/connect lewat Events.
# Contoh: Events.hand_moved.emit(100.0)
#         Events.hand_moved.connect(fungsi_saya)
# @warning_ignore dipakai karena signal ini di-emit dari skrip
# lain, sehingga Godot mengira signal-nya "tidak terpakai".
# ============================================================

# ---------- Dipancarkan oleh Core Controller (Player & Hand) ----------

# Kecepatan geser torso (nilai absolut, px/detik). Dari player.gd.
@warning_ignore("unused_signal")
signal torso_moved(speed: float)

# Kecepatan tangan (px/detik, sudah dihaluskan). Dari hand.gd.
@warning_ignore("unused_signal")
signal hand_moved(speed: float)

# Dipancarkan saat tangan berhasil mengambil sebuah item.
@warning_ignore("unused_signal")
signal item_grabbed(item: Draggable)

# Dipancarkan saat item dilepas. impact_speed = kecepatan tangan
# saat dilepas (semakin besar = semakin kasar).
@warning_ignore("unused_signal")
signal item_dropped(item: Draggable, impact_speed: float)

# ---------- Dipancarkan oleh Cat (Logic Meter Toleransi & State) ----------

# Dipancarkan setiap nilai toleransi berubah. Dipakai UI (progress bar)
# dan sistem lain (mis. Daily Loop Manager untuk menyimpan nilai antar-hari).
@warning_ignore("unused_signal")
signal tolerance_changed(value: float, max_value: float)

# Dipancarkan saat state kucing berganti. Nilainya int dari enum Cat.State.
@warning_ignore("unused_signal")
signal cat_state_changed(new_state: int, old_state: int)

# Kondisi gagal: kucing terbangun karena toleransi penuh.
@warning_ignore("unused_signal")
signal cat_woke_up

# Kondisi gagal: kucing jatuh dari pangkuan karena diguncang keras.
@warning_ignore("unused_signal")
signal cat_fell

# ---------- Dipancarkan oleh GameClock & DayManager (System Time & Daily Loop) ----------

# Dipancarkan setiap menit-game berganti. Dipakai HUD dan sistem tugas
# (mis. ikan hanya boleh diberi makan jam 07:00-09:00).
@warning_ignore("unused_signal")
signal time_changed(hour: int, minute: int)

# Dipancarkan sekali tiap jam-game baru. Dipakai alarm (jam 6, 12, 18, 24).
@warning_ignore("unused_signal")
signal hour_reached(hour: int)

# Jam game sudah mencapai batas akhir hari.
@warning_ignore("unused_signal")
signal day_time_ended

# Hari baru dimulai (day = 1..MAX_DAY).
@warning_ignore("unused_signal")
signal day_started(day: int)

# Hari berhasil diselesaikan. Dipakai Effect/Cutscene (animasi minum obat).
@warning_ignore("unused_signal")
signal day_succeeded(day: int)

# Hari gagal. Dipakai Effect Glitch/Rewind (screen-tear, suara rewind).
@warning_ignore("unused_signal")
signal day_failed(day: int, reason: String)

# Semua hari selesai. Dipakai Cutscene Ending.
@warning_ignore("unused_signal")
signal game_completed

# Dipancarkan oleh Logic Sistem Tugas bila tugas gagal
# (ikan mati, alarm terlewat, dll). Otomatis menggagalkan hari.
@warning_ignore("unused_signal")
signal task_failed(reason: String)

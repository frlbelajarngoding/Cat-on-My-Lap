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

# ---------- Dipancarkan oleh Logic Sistem Tugas (Task & TaskManager) ----------

# Tugas mulai (muncul / suara mulai berbunyi). id = kunci di TaskCatalog.
@warning_ignore("unused_signal")
signal task_started(task_id: String)

# Tugas selesai. clean = true bila tanpa penalti (dapat bonus +1%).
@warning_ignore("unused_signal")
signal task_completed(task_id: String, clean: bool)

# Tugas terlambat (suara masuk fase 4 / lewat batas jam). Penalti SUDAH
# dikenakan sekali dan tugas tetap berjalan. BUKAN game over: berbeda
# dengan task_failed di atas yang langsung menggagalkan hari.
@warning_ignore("unused_signal")
signal task_late(task_id: String)

# Penalti sekali (tumpah, overfeed, terlambat...). Untuk toast/feedback.
@warning_ignore("unused_signal")
signal task_penalty(task_id: String, amount: float, reason: String)

# Fase suara sebuah tugas berubah (1 pelan, 2 sedang, 3 nyaring, 4 gagal).
# 0 tidak pernah dikirim. Dipakai audio: mulai/ubah/hentikan suara.
@warning_ignore("unused_signal")
signal sound_phase_changed(task_id: String, phase: int)

# Semua tugas A hari ini selesai. Dipakai DayManager untuk menutup hari.
@warning_ignore("unused_signal")
signal required_tasks_done

# ---------- Perintah ke meter kucing (didengarkan Cat) ----------

# Tambah toleransi (meter kucing turun). amount dalam % meter. Dipakai
# penalti sekali maupun drain per-frame dari suara.
@warning_ignore("unused_signal")
signal meter_penalty(amount: float, reason: String)

# Kurangi toleransi (meter kucing pulih), mis. bonus tugas bersih.
@warning_ignore("unused_signal")
signal meter_recovery(amount: float)

# ---------- Dipancarkan oleh Effect Glitch, Rewind & Cutscene ----------

# Minta efek glitch sesaat. Sistem mana pun boleh memanggil tanpa
# mengenal FX: Events.glitch_requested.emit(0.5, 0.3)
# strength 0..1, duration dalam detik.
@warning_ignore("unused_signal")
signal glitch_requested(strength: float, duration: float)

# Rewind dimulai / selesai. Dipakai audio atau sistem lain yang perlu tahu.
# from_day -> to_day sama bila mode RETRY_DAY.
@warning_ignore("unused_signal")
signal rewind_started(from_day: int, to_day: int)
@warning_ignore("unused_signal")
signal rewind_finished

# Suara palsu dimulai: tim audio memutar suara milik tugas `source_id`
# selama `duration` detik. Tidak ada tugas dan tidak ada getaran benda.
@warning_ignore("unused_signal")
signal fake_sound_started(source_id: String, duration: float)

# ---------- Dipancarkan oleh PauseMenu ----------

# Game di-pause / dilanjutkan lewat menu pause. Dipakai audio atau sistem yang perlu tahu.
@warning_ignore("unused_signal")
signal game_paused
@warning_ignore("unused_signal")
signal game_resumed

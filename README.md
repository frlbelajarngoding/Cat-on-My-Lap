Link Download Game
-------------------------------------------------------
Klik "CatOnMyLap.zip" di link ini (release paling atas itu yg paling baru):

https://github.com/frlbelajarngoding/Cat-on-My-Lap/releases



Deadline Budak Godot
-------------------------------------------------------
Core Controller & Input System ------------ Farrel (13-14)

Logic Meter Toleransi & Kucing State ------ Daffa  (14-15)

System Time & Daily Loop Manager ------- Farrel (15-16)

Logic Sistem Tugas ------------------------- Daffa  (16-20)

Effect Glitch, Rewind & Cutscene Ending -- Farrel (19-21)

Debugging & Build Optimization ---------- Daffa  (22-26)

*help logis sistem tugas knp deadlinenya lama bgt aku takut - jundi

*bersiaplah ga tidur - frl

History
--------------------------------------------------------
Logic Sistem Toleransi & State Kucing\
Baru:
1. scripts/cat.gd and scenes/cat.tscn.

Ganti:
1. events.gd: nambah sinyal tolerance_changed, cat_state_changed, cat_woke_up, and cat_fell
2. player.tscn: ditambah node Cat
3. main.tscn dan main.gd: bar, teks game over, and teks debug

Logic Sistem Tugas (Quest harian)\
Baru:
1. scripts/task_catalog.gd: data semua tugas (langkah, suara, batas jam, penalti) sesuai Katalog Tugas di GDD.
2. scripts/task_schedule.gd: jadwal tugas per hari (Day 1-5), batas suara bersamaan, badai Day 4.
3. scripts/task.gd: mesin langkah satu tugas (tap, hold, hover, put, release, pour), fase suara 1-4, penalti terlambat.
4. scripts/task_manager.gd: penjadwal, antrean, drain meter dari suara, badai, syarat menutup hari.
5. scripts/task_zone.gd: area tujuan (telinga, pot, akuarium, dll).
6. scenes/tasks/*.tscn: 9 tugas (siram tanaman, ikan, ketel, mangkuk kucing, vitamin, alarm, telepon, microwave, laptop). Posisi item bisa digeser langsung di editor.

Ganti:
1. draggable.gd: tambah follow_hand (tuas/pintu yang tidak ikut tangan), last_hold_time (deteksi tap), keep_here(), toggle(), reset_to_home(), label_text, tint.
2. hand.gd: item follow_hand = false tidak ikut bergerak. Masuk group "hand".
3. player.gd: masuk group "player" (untuk zona telinga/mulut).
4. cat.gd: dengar Events.meter_penalty dan Events.meter_recovery.
5. events.gd: sinyal task_started, task_completed, task_late, task_penalty, sound_phase_changed, required_tasks_done, meter_penalty, meter_recovery.
6. game_clock.gd: hari jadi 06:00-22:00, 15 detik/jam (4 menit, sesuai GDD). Tambah speed_scale.
7. day_manager.gd: hari tidak bisa ditutup sebelum semua tugas A selesai. Tombol debug F3 dan F4.
8. hud.gd dan hud.tscn: panel quest (QuestLabel).
9. main.tscn: tambah TaskManager. Remote dan Phone uji coba dihapus (diganti item tugas).

Tombol debug (hanya build debug): 1-9 memunculkan tugas (1 tanaman, 2 ikan, 3 ketel, 4 mangkuk, 5 vitamin, 6 alarm, 7 telepon, 8 microwave, 9 laptop), F1 gagal, F2 loncat ke akhir hari, F3 jam x4, F4 ganti hari.

Aset Visual (tahap 1)\
Baru:
1. assets/sprites/*.png: 15 sprite yang sudah dipangkas dari kanvas transparan dan dikembalikan ke ukuran 1x (jam weker, telepon, laci, microwave, meja, rak buku, kaleng air, pakan ikan, tanaman, lampu, sofa, remote, 3 lapisan akuarium).

Ganti:
1. draggable.gd: slot texture dan sprite_scale. Kotak tangkap otomatis mengikuti ukuran gambar.
2. scenes/tasks/*.tscn: item yang sudah punya aset memakai gambar. Furnitur milik satu tugas (akuarium, tanaman, laci) ada di scene tugasnya, jadi baru muncul di hari tugas itu muncul.
3. main.tscn: Sofa (ColorRect) diganti sprite, tambah Bookshelf, Lamp, LowTable.
4. project.godot: texture filter Nearest supaya pixel art tidak blur.

Aturan skala: semua sprite digambar 1x lalu ditampilkan dengan scale 2 (layar 640x360).
Belum ada aset: kucing, badan/tangan pemain, tuas kompor, laptop, toples kucing, gelas, botol vitamin, tutup pakan, mangkuk microwave, dinding/lantai. Healthbar masih .aseprite (perlu di-export ke PNG).


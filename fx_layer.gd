class_name FXLayer
extends CanvasLayer
# ============================================================
# FX LAYER (Glitch, Rewind, CRT-off, Fade-in) - TANPA SHADER
# ------------------------------------------------------------
# Semua efek memakai overlay ColorRect yang dibuat lewat kode:
#  1. AMBIENT : glitch tipis mengikuti toleransi kucing + kedipan acak.
#  2. BURST   : lonjakan glitch sesaat (glitch_burst / Events.glitch_requested).
#  3. REWIND  : dipanggil DayManager saat hari gagal (play_rewind).
#  4. CRT-OFF : dipanggil EndingCutscene (play_crt_off).
# Cara kerja glitch: pita warna acak + getaran layar (world & HUD).
# process_mode = ALWAYS supaya tetap jalan saat game di-pause.
# ============================================================

@export_group("Ambient")
# Matikan semua glitch ambient (otomatis dimatikan saat rewind/ending).
@export var ambient_enabled: bool = true
# Intensitas glitch ambient maksimum saat toleransi mendekati penuh.
@export var ambient_max: float = 0.25
# Kedipan glitch acak mulai dari hari ini.
@export var flicker_from_day: int = 3

@export_group("Glitch Look")
# Jumlah pita glitch maksimum di layar.
@export var bar_count: int = 8
# Seberapa sering pola glitch berganti per detik (makin kecil = makin patah-patah).
@export var tear_fps: float = 14.0
# Getaran layar maksimum (px) pada intensitas 1.0. Isi 0 untuk mematikan getaran.
@export var shake_pixels: float = 5.0

@export_group("Rewind")
# Hantaman glitch sebelum rewind (detik).
@export var fail_hit_duration: float = 0.35
# Lama jam berputar mundur (detik).
@export var rewind_duration: float = 2.2
# Warna dan kekuatan tint saat rewind.
@export var rewind_tint: Color = Color(0.4, 0.6, 1.0, 0.28)

@export_group("CRT Off")
# Lama tirai menutup vertikal lalu horizontal (detik).
@export var crt_squash_time: float = 0.35
@export var crt_shrink_time: float = 0.25

# Warna pita glitch (dipilih acak).
const BAR_COLORS := [
	Color(1.0, 1.0, 1.0, 0.25),
	Color(0.0, 1.0, 1.0, 0.30),
	Color(1.0, 0.0, 1.0, 0.30),
	Color(0.0, 0.0, 0.0, 0.50),
]

# ---------- Nilai publik (bisa di-tween) ----------
var burst: float = 0.0           # lonjakan glitch sesaat (0..1)
var rewind_amount: float = 0.0   # kekuatan efek rewind (0..1)
var crt_v: float = 1.0           # tinggi area terlihat (1 = normal, 0 = tertutup)
var crt_h: float = 1.0           # lebar area terlihat

var _ambient: float = 0.0          # glitch ambient saat ini (dihaluskan)
var _ambient_target: float = 0.0   # target dari toleransi kucing
var _flicker_timer: float = 6.0    # hitung mundur kedipan berikutnya
var _tick: float = 0.0             # hitung mundur ganti pola glitch
var _glitching := false            # True bila overlay glitch sedang tampil
var _burst_tween: Tween

# Overlay yang dibuat lewat kode.
var _tint: ColorRect
var _fade: ColorRect
var _bars: Array[ColorRect] = []
var _crt_top: ColorRect
var _crt_bottom: ColorRect
var _crt_left: ColorRect
var _crt_right: ColorRect
var _crt_line: ColorRect

var _tol_target := 0.0   # glitch dari toleransi
var _day_base := 0.0     # glitch dasar hari ini (GameState.DISTORTION_BY_DAY)

@onready var rewind_sfx: AudioStreamPlayer = $RewindSfx
@onready var glitch_sfx: AudioStreamPlayer = $GlitchSfx
@onready var crt_off_sfx: AudioStreamPlayer = $CrtOffSfx
@onready var hud: DayHUD = $"../HUD"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlays()

	# Glitch ambient mengikuti toleransi (kuadrat: baru terasa saat sudah tinggi).
	_day_base = GameState.distortion_for_day()
	_ambient_target = _day_base
	Events.tolerance_changed.connect(func(value: float, max_value: float) -> void:
		_tol_target = pow(value / max_value, 2.0) * ambient_max
		_ambient_target = maxf(_day_base, _tol_target))
	Events.glitch_requested.connect(glitch_burst)
	Events.task_late.connect(func(_id: String) -> void: glitch_burst(0.4, 0.25))

	_flicker_timer = randf_range(4.0, 9.0)
	_handle_arrival()

func _exit_tree() -> void:
	# canvas_transform hidup di viewport (tidak ikut dihapus saat scene di-reload),
	# jadi kembalikan ke normal supaya scene berikutnya tidak miring.
	get_viewport().canvas_transform = Transform2D.IDENTITY

# Membuat semua overlay. Urutan add_child = urutan gambar (yang terakhir paling depan).
func _build_overlays() -> void:
	_tint = _make_rect(Color(rewind_tint.r, rewind_tint.g, rewind_tint.b, 0.0))
	for i in bar_count:
		var bar := _make_rect(Color.WHITE)
		bar.hide()
		_bars.append(bar)
	_fade = _make_rect(Color.BLACK)
	_fade.modulate.a = 0.0
	_crt_top = _make_rect(Color.BLACK)
	_crt_bottom = _make_rect(Color.BLACK)
	_crt_left = _make_rect(Color.BLACK)
	_crt_right = _make_rect(Color.BLACK)
	_crt_line = _make_rect(Color.WHITE)
	for r in [_crt_top, _crt_bottom, _crt_left, _crt_right, _crt_line]:
		r.hide()

# Membuat ColorRect yang TIDAK menelan klik mouse (Mouse Filter = Ignore).
func _make_rect(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r

# Dipanggil sekali saat scene baru dimuat: lanjutkan efek dari scene sebelumnya.
func _handle_arrival() -> void:
	var transition := GameState.transition
	GameState.transition = ""   # sudah "dibaca", kosongkan
	match transition:
		"next_day":
			# Layar sebelumnya hitam (fade HUD) -> pudar masuk.
			var size := get_viewport().get_visible_rect().size
			_fade.size = size
			_fade.modulate.a = 1.0
			create_tween().tween_property(_fade, "modulate:a", 0.0, 1.0)
		"rewind":
			# Lanjutan rewind: mulai dari glitch penuh lalu memudar = efek déjà vu.
			rewind_amount = 1.0
			glitch_burst(1.0, 1.0)
			create_tween().tween_property(self, "rewind_amount", 0.0, 1.2)
			await get_tree().process_frame   # tunggu HUD selesai _ready
			hud.show_status("Déjà vu...")
			await get_tree().create_timer(1.2).timeout
			if hud.status_label.text == "Déjà vu...":   # jangan hapus pesan lain
				hud.hide_status()

func _process(delta: float) -> void:
	var size := get_viewport().get_visible_rect().size
	_tint.size = size
	_fade.size = size

	# Ambient dihaluskan; bila dimatikan, turun ke 0.
	var target := _ambient_target if ambient_enabled else 0.0
	_ambient = lerpf(_ambient, target, 1.0 - exp(-2.0 * delta))
	_update_flicker(delta)

	# Rewind menambah kekuatan glitch dan menebalkan tint biru.
	var level := clampf(maxf(_ambient, burst) + rewind_amount * 0.5, 0.0, 1.0)
	_tint.color.a = rewind_tint.a * rewind_amount

	# Pola glitch hanya diganti tiap 1/tear_fps detik (patah-patah, bukan mulus).
	if level > 0.001:
		_tick -= delta
		if _tick <= 0.0:
			_tick = 1.0 / tear_fps
			_randomize_bars(level, size)
			_apply_shake(level)
			_glitching = true
	elif _glitching:
		_clear_glitch()

	_update_crt(size)

# Kedipan glitch acak (detak jam "tidak sinkron"), makin sering di hari akhir.
func _update_flicker(delta: float) -> void:
	if not ambient_enabled or GameState.current_day < flicker_from_day:
		return
	_flicker_timer -= delta
	if _flicker_timer <= 0.0:
		var days_over := GameState.current_day - flicker_from_day
		_flicker_timer = randf_range(5.0, 10.0) / (1.0 + 0.3 * days_over)
		glitch_burst(0.25 + 0.05 * GameState.current_day, 0.15, false)

# ---------- Glitch: pita acak + getaran ----------

# Acak ulang posisi, ukuran, dan warna pita. Makin tinggi level, makin banyak
# dan makin tebal pitanya.
func _randomize_bars(level: float, size: Vector2) -> void:
	for bar in _bars:
		if randf() < level * 0.9:
			var h := randf_range(3.0, 10.0 + 30.0 * level)
			bar.size = Vector2(size.x * randf_range(0.3, 1.0), h)
			bar.position = Vector2(randf_range(0.0, size.x - bar.size.x), randf() * (size.y - h))
			bar.color = BAR_COLORS.pick_random()
			bar.show()
		else:
			bar.hide()

# Menggeser dunia game dan HUD sedikit secara acak. Overlay di layer ini tidak ikut bergetar.
func _apply_shake(level: float) -> void:
	var s := Vector2(randf_range(-1.0, 1.0), randf_range(-0.3, 0.3)) * shake_pixels * level
	get_viewport().canvas_transform = Transform2D(0.0, s)   # Node2D di layer 0
	hud.offset = s                                          # HUD (CanvasLayer)

# Kembalikan semuanya ke normal saat glitch selesai.
func _clear_glitch() -> void:
	_glitching = false
	for bar in _bars:
		bar.hide()
	get_viewport().canvas_transform = Transform2D.IDENTITY
	hud.offset = Vector2.ZERO

# ---------- 2. BURST ----------

# Lonjakan glitch: langsung ke `strength`, lalu memudar dalam `duration` detik.
func glitch_burst(strength: float = 0.8, duration: float = 0.3, with_sound: bool = true) -> void:
	burst = maxf(burst, strength)
	if _burst_tween:
		_burst_tween.kill()
	_burst_tween = create_tween()
	_burst_tween.tween_property(self, "burst", 0.0, duration).set_ease(Tween.EASE_OUT)
	if with_sound:
		_play(glitch_sfx)

# ---------- 3. REWIND ----------

# Dipanggil DayManager saat hari gagal. Gunakan: await fx.play_rewind(...)
# Jam HUD berputar mundur dari from_hour ke to_hour; bila from_day != to_day
# (mode RESTART_ALL) angka Day ikut mundur.
func play_rewind(from_hour: float, to_hour: float, from_day: int, to_day: int) -> void:
	ambient_enabled = false

	# Hantaman glitch saat gagal.
	glitch_burst(1.0, fail_hit_duration)
	await get_tree().create_timer(fail_hit_duration).timeout

	# Suara rewind + teks.
	_play(rewind_sfx)
	hud.show_status("<< MENGULANG >>")

	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "rewind_amount", 1.0, rewind_duration * 0.3)
	tw.tween_method(hud.show_rewind_clock, from_hour, to_hour, rewind_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if from_day != to_day:
		tw.tween_method(func(d: float) -> void: hud.show_rewind_day(roundi(d)),
			float(from_day), float(to_day), rewind_duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	# rewind_amount sengaja dibiarkan 1.0; scene baru melanjutkannya (_handle_arrival).

# ---------- 4. CRT OFF ----------

# Dipanggil EndingCutscene. Glitch sebentar, tirai hitam menutup dari atas-bawah
# sampai tersisa garis putih, lalu garis menyempit ke tengah dan hilang.
func play_crt_off() -> void:
	ambient_enabled = false
	glitch_burst(0.9, 0.5)
	await get_tree().create_timer(0.5).timeout
	_play(crt_off_sfx)
	var tw := create_tween()
	tw.tween_property(self, "crt_v", 0.005, crt_squash_time) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "crt_h", 0.0, crt_shrink_time).set_ease(Tween.EASE_IN)
	await tw.finished

# Mengembalikan area terlihat ke normal (dipanggil EndingCutscene setelah
# ia menutup layar dengan hitam miliknya).
func reset_crt() -> void:
	crt_v = 1.0
	crt_h = 1.0

# Menata 4 tirai hitam + garis putih sesuai crt_v dan crt_h.
func _update_crt(size: Vector2) -> void:
	var active := crt_v < 1.0 or crt_h < 1.0
	for r in [_crt_top, _crt_bottom, _crt_left, _crt_right]:
		r.visible = active
	# Garis putih hanya muncul saat tirai atas-bawah hampir bertemu.
	_crt_line.visible = active and crt_v < 0.05 and crt_h > 0.01
	if not active:
		return

	var cover_v := size.y * (1.0 - crt_v) * 0.5   # tinggi tiap tirai atas/bawah
	var cover_h := size.x * (1.0 - crt_h) * 0.5   # lebar tiap tirai kiri/kanan
	_crt_top.position = Vector2.ZERO
	_crt_top.size = Vector2(size.x, cover_v)
	_crt_bottom.position = Vector2(0.0, size.y - cover_v)
	_crt_bottom.size = Vector2(size.x, cover_v)
	_crt_left.position = Vector2.ZERO
	_crt_left.size = Vector2(cover_h, size.y)
	_crt_right.position = Vector2(size.x - cover_h, 0.0)
	_crt_right.size = Vector2(cover_h, size.y)

	_crt_line.size = Vector2(size.x * crt_h, 2.0)
	_crt_line.position = (size - _crt_line.size) * 0.5

# Memutar suara bila file audionya sudah dipasang di Inspector (aman bila kosong).
func _play(player: AudioStreamPlayer) -> void:
	if player.stream:
		player.play()

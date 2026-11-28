class_name Hand
extends Node2D
# ============================================================
# HAND (Tangan kiri / kanan)
# ------------------------------------------------------------
# Ada dua instance (HandLeft dan HandRight). Player menentukan
# mana yang AKTIF. Tangan aktif:
# 1. Mengikuti kursor mouse dengan lag, dibatasi jangkauan dari bahunya.
# 2. Menghitung kecepatan untuk dilaporkan ke Cat.
# 3. Mengambil (LMB ditekan) dan menjatuhkan (LMB dilepas) Draggable.
# Tangan tidak aktif: beristirahat di dekat bahu, redup, tidak melapor.
# Hanya tangan aktif yang masuk group "hand" (dicari sistem lain).
# ============================================================

enum HandSide { LEFT, RIGHT }

# Sisi tangan ini. Menentukan bahu yang dipakai (ShoulderLeft / ShoulderRight).
@export var side: HandSide = HandSide.RIGHT
# Jarak maksimum tangan dari bahu (px). Menentukan item mana yang terjangkau.
@export var max_reach: float = 140.0
# Kecepatan tangan mengejar mouse. Makin kecil = makin lambat/berat.
@export var follow_speed: float = 12.0

@export_group("Inactive Hand")
# Posisi istirahat tangan tidak aktif, relatif terhadap bahunya.
# Kiri: x negatif (mis. -8), kanan: x positif (mis. 8).
@export var rest_offset: Vector2 = Vector2(0, 50)
# Kecepatan tangan tidak aktif kembali ke posisi istirahat.
@export var rest_follow_speed: float = 6.0
# Transparansi tangan tidak aktif (penanda visual mana yang sedang dipakai).
@export_range(0.0, 1.0) var inactive_alpha: float = 0.55

@export_group("Shake")
# Petunjuk diegetic: tangan bergetar saat bergerak terlalu cepat.
# Mulai bergetar di shake_start_speed, getaran penuh di shake_full_speed
# (samakan dengan Task.FAST_SPEED = 300).
@export var shake_start_speed: float = 180.0
@export var shake_full_speed: float = 300.0
@export var shake_pixels: float = 2.5

# True bila tangan ini yang sedang dikendalikan. Diatur Player.
var is_active := false
# Item yang sedang dipegang; null jika tangan kosong.
var held_item: Draggable = null
# Kecepatan tangan saat ini (px/detik), sudah dihaluskan.
var hand_speed := 0.0
# Posisi tangan pada frame sebelumnya, untuk menghitung kecepatan.
var _prev_pos := Vector2.ZERO

# Bahu milik tangan ini: ShoulderLeft atau ShoulderRight (node saudara).
@onready var shoulder: Marker2D = get_node("../ShoulderLeft" if side == HandSide.LEFT else "../ShoulderRight") as Marker2D
@onready var grab_area: Area2D = $GrabArea   # area deteksi item yang bisa diambil
@onready var sprite: Sprite2D = $Sprite2D    # gambar tangan

func _ready() -> void:
	_prev_pos = global_position
	sprite.modulate.a = inactive_alpha   # Player yang mengaktifkan salah satunya
	Events.game_resumed.connect(_on_game_resumed)

# Dipanggil Player saat tangan ini diaktifkan / dinonaktifkan.
func set_active(on: bool) -> void:
	is_active = on
	sprite.modulate.a = 1.0 if on else inactive_alpha
	if on:
		add_to_group("hand")   # supaya sistem lain bisa menemukan tangan AKTIF
		# Langsung muncul di bawah kursor. Bila "berjalan" dari posisi istirahat,
		# kecepatannya terbaca sangat tinggi dan mengganggu kucing.
		global_position = _clamp_to_reach(get_global_mouse_position())
		_prev_pos = global_position
		hand_speed = 0.0
	else:
		remove_from_group("hand")

func _process(delta: float) -> void:
	if not is_active:
		_rest(delta)
		return

	# 1. Target = posisi mouse, tapi dibatasi jangkauan lengan dari bahu.
	var target := _clamp_to_reach(get_global_mouse_position())

	# 2. Gerak halus menuju target. Rumus 1 - exp(-k*delta) membuat
	#    kecepatan gerak tidak bergantung pada FPS.
	global_position = global_position.lerp(target, 1.0 - exp(-follow_speed * delta))

	# 3. Kecepatan = jarak yang ditempuh / waktu. maxf mencegah pembagian nol.
	#    lerp 0.25 menghaluskan angka agar tidak loncat-loncat (jitter).
	var raw_speed := global_position.distance_to(_prev_pos) / maxf(delta, 0.0001)
	hand_speed = lerpf(hand_speed, raw_speed, 0.25)
	_prev_pos = global_position
	var over := clampf((hand_speed - shake_start_speed) / (shake_full_speed - shake_start_speed), 0.0, 1.0)
	sprite.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_pixels * over

	# 4. Item yang dipegang menempel di posisi tangan. Benda tetap
	#    (tuas, pintu, laptop: follow_hand = false) tidak ikut bergerak.
	if held_item and held_item.follow_hand:
		held_item.global_position = global_position

	# Laporkan kecepatan tangan ke sistem lain (hanya tangan aktif yang melapor).
	Events.hand_moved.emit(hand_speed)

# Tangan tidak aktif: kembali ke posisi istirahat di dekat bahunya.
func _rest(delta: float) -> void:
	var target := shoulder.global_position + rest_offset
	global_position = global_position.lerp(target, 1.0 - exp(-rest_follow_speed * delta))
	sprite.position = Vector2.ZERO
	_prev_pos = global_position
	hand_speed = 0.0

# Input yang belum "dimakan" oleh UI. Hanya tangan AKTIF yang bereaksi.
func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
	if event.is_action_pressed("grab"):
		_try_grab()
	elif event.is_action_released("grab"):
		_release()

# Membatasi sebuah titik agar tidak lebih jauh dari max_reach dari bahu.
# Jika di luar jangkauan, titik ditarik ke tepi lingkaran jangkauan.
func _clamp_to_reach(point: Vector2) -> Vector2:
	var offset := point - shoulder.global_position
	if offset.length() > max_reach:
		offset = offset.normalized() * max_reach
	return shoulder.global_position + offset

# Mengambil item terdekat yang menimpa GrabArea. Tidak melakukan apa pun
# bila tangan sudah memegang sesuatu atau tidak ada item di dekatnya.
func _try_grab() -> void:
	if held_item:
		return
	var best: Draggable = null
	var best_dist := INF
	# Cari Draggable terdekat dari pusat tangan.
	for area in grab_area.get_overlapping_areas():
		if area is Draggable:
			var d := global_position.distance_to(area.global_position)
			if d < best_dist:
				best_dist = d
				best = area
	if best:
		held_item = best
		held_item.on_grabbed()
		Events.item_grabbed.emit(held_item)

# Melepas item yang dipegang dan melaporkan seberapa kasar pelepasannya.
func _release() -> void:
	if not held_item:
		return
	var item := held_item
	held_item = null   # kosongkan dulu sebelum memanggil fungsi lain
	item.on_dropped()
	# hand_speed dipakai sebagai ukuran "kekerasan" drop.
	Events.item_dropped.emit(item, hand_speed)

# Setelah pause, mouse sudah pindah (ke tombol Continue). Tanpa sinkronisasi,
# tangan "berlari" ke mouse, kecepatannya terbaca tinggi, dan kucing terganggu.
func _on_game_resumed() -> void:
	if not is_active:
		return
	hand_speed = 0.0
	# Event lepas klik terjadi saat pause dan tidak sampai ke tangan.
	# Jadi bila LMB sudah tidak ditekan, lepaskan item sekarang (impact 0).
	if held_item and not Input.is_action_pressed("grab"):
		_release()
	global_position = _clamp_to_reach(get_global_mouse_position())
	_prev_pos = global_position

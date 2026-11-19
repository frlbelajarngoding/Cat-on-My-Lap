class_name Hand
extends Node2D
# ============================================================
# HAND (Tangan)
# ------------------------------------------------------------
# Tugas:
# 1. Mengikuti kursor mouse dengan lag, dibatasi jangkauan lengan.
# 2. Menghitung kecepatan tangan untuk dilaporkan ke Cat.
# 3. Mengambil (LMB ditekan) dan menjatuhkan (LMB dilepas) Draggable.
# ============================================================

# Jarak maksimum tangan dari bahu (px). Menentukan item mana yang terjangkau.
@export var max_reach: float = 140.0
# Kecepatan tangan mengejar mouse. Makin kecil = makin lambat/berat.
@export var follow_speed: float = 12.0

# Item yang sedang dipegang; null jika tangan kosong.
var held_item: Draggable = null
# Kecepatan tangan saat ini (px/detik), sudah dihaluskan.
var hand_speed := 0.0
# Posisi tangan pada frame sebelumnya, untuk menghitung kecepatan.
var _prev_pos := Vector2.ZERO

@onready var shoulder: Marker2D = $"../Shoulder"  # titik bahu milik Player (node saudara)
@onready var grab_area: Area2D = $GrabArea        # area deteksi item yang bisa diambil

func _ready() -> void:
	_prev_pos = global_position

func _process(delta: float) -> void:
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

	# 4. Item yang dipegang selalu menempel di posisi tangan.
	if held_item:
		held_item.global_position = global_position

	# Laporkan kecepatan tangan ke sistem lain (Cat).
	Events.hand_moved.emit(hand_speed)

# Input yang belum "dimakan" oleh UI. Dipakai untuk klik ambil/lepas.
func _unhandled_input(event: InputEvent) -> void:
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

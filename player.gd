extends Node2D
# ============================================================
# PLAYER (Torso + Dua Lengan)
# ------------------------------------------------------------
# Tugas:
# 1. Menggeser torso kiri/kanan di sofa (tombol A/D) dengan
#    akselerasi dan batas sofa.
# 2. Mengatur dua tangan (kiri/kanan): hanya SATU yang aktif
#    (mengikuti mouse). Ganti dengan Q / E / klik kanan.
# 3. Menggambar kedua lengan (Line2D) dari bahu ke tangan.
# 4. Memberi tahu sistem lain kecepatan torso lewat Events.
# ============================================================

@export_group("Torso Movement")
# Kecepatan geser maksimum torso (px/detik).
@export var max_speed: float = 120.0
# Seberapa cepat torso mencapai max_speed. Makin kecil = makin "berat".
@export var acceleration: float = 250.0
# Seberapa cepat torso berhenti saat tombol dilepas.
@export var deceleration: float = 400.0
# Batas geser ke kiri, relatif terhadap posisi awal (nilai negatif).
@export var min_x: float = -70.0
# Batas geser ke kanan, relatif terhadap posisi awal.
@export var max_x: float = 70.0
# Kemiringan visual torso saat bergerak (radian). Hanya efek tampilan.
@export var lean_amount: float = 0.08

@export_group("Hands")
# Jeda minimal (detik) antar pergantian tangan, supaya tidak bisa di-spam.
@export var switch_cooldown: float = 0.2

#var rate = deceleration

# Kecepatan horizontal torso saat ini (px/detik). Negatif = ke kiri.
var velocity_x := 0.0
# Tangan yang sedang aktif (mengikuti mouse).
var active_hand: Hand = null

# Posisi X awal Player; dipakai sebagai acuan batas min_x/max_x.
var _origin_x := 0.0
var _switch_timer := 0.0

@onready var torso: Sprite2D = $Torso               # sprite badan
@onready var shoulder_left: Marker2D = $ShoulderLeft
@onready var shoulder_right: Marker2D = $ShoulderRight
@onready var arm_left: Line2D = $ArmLeft            # garis lengan kiri
@onready var arm_right: Line2D = $ArmRight          # garis lengan kanan
@onready var hand_left: Hand = $HandLeft
@onready var hand_right: Hand = $HandRight

func _ready() -> void:
	# Simpan posisi awal sebagai titik tengah sofa.
	_origin_x = position.x
	add_to_group("player")   # dipakai TaskZone yang menempel di badan (telinga, mulut)
	_set_active(hand_right)  # tangan kanan aktif di awal

# Pergerakan dihitung di physics process agar konsisten (delta tetap).
func _physics_process(delta: float) -> void:
	# dir: -1 (A / kiri), 0 (tidak ada input), +1 (D / kanan)
	var dir := Input.get_axis("move_left", "move_right")
	var target_speed := dir * max_speed
	# Ada input -> pakai acceleration; tidak ada -> pakai deceleration (mengerem).
	var rate := acceleration if dir != 0.0 else deceleration
	# Ubah kecepatan secara bertahap menuju target, bukan langsung.
	velocity_x = move_toward(velocity_x, target_speed, rate * delta)

	# Hitung posisi baru lalu batasi agar tidak keluar dari sofa.
	var new_x := position.x + velocity_x * delta
	var clamped_x := clampf(new_x, _origin_x + min_x, _origin_x + max_x)
	if not is_equal_approx(new_x, clamped_x):
		velocity_x = 0.0   # menabrak ujung sofa -> kecepatan di-nol-kan
	position.x = clamped_x

	# Miringkan sprite mengikuti arah gerak (halus lewat lerp).
	torso.rotation = lerpf(torso.rotation, (velocity_x / max_speed) * lean_amount, 0.15)

	# Laporkan kecepatan torso (selalu positif) ke sistem lain (Cat).
	Events.torso_moved.emit(absf(velocity_x))
	
	

func _process(delta: float) -> void:
	_switch_timer = maxf(0.0, _switch_timer - delta)
	# Gambar ulang kedua lengan setiap frame.
	_draw_arm(arm_left, shoulder_left, hand_left)
	_draw_arm(arm_right, shoulder_right, hand_right)

# Garis dari bahu ke tangan. to_local() mengubah posisi dunia ke koordinat lokal Line2D.
func _draw_arm(arm: Line2D, shoulder: Marker2D, hand: Node2D) -> void:
	arm.points = PackedVector2Array([
		arm.to_local(shoulder.global_position),
		arm.to_local(hand.global_position)
	])

# ---------- Ganti tangan ----------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("hand_left"):
		_try_switch(hand_left)
	elif event.is_action_pressed("hand_right"):
		_try_switch(hand_right)
	elif event.is_action_pressed("hand_swap"):
		_try_switch(hand_right if active_hand == hand_left else hand_left)

# Ganti tangan hanya bila tangan sekarang KOSONG dan jeda sudah lewat.
func _try_switch(target: Hand) -> void:
	if target == active_hand or _switch_timer > 0.0:
		return
	if active_hand != null and active_hand.held_item != null:
		return   # lepas dulu benda yang dipegang
	_set_active(target)
	_switch_timer = switch_cooldown

func _set_active(target: Hand) -> void:
	active_hand = target
	hand_left.set_active(target == hand_left)
	hand_right.set_active(target == hand_right)

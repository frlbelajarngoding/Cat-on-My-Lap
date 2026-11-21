extends Node2D
# ============================================================
# PLAYER (Torso + Lengan)
# ------------------------------------------------------------
# Tugas:
# 1. Menggeser torso kiri/kanan di sofa (tombol A/D) dengan
#    akselerasi dan batas sofa.
# 2. Menggambar lengan (Line2D) dari bahu ke tangan.
# 3. Memberi tahu sistem lain kecepatan torso lewat Events.
# ============================================================

@export_group("Torso Movement")
# Kecepatan geser maksimum torso (px/detik).
@export var max_speed: float = 120.0
# Seberapa cepat torso mencapai max_speed. Makin kecil = makin "berat".
@export var acceleration: float = 250.0
# Seberapa cepat torso berhenti saat tombol dilepas.
@export var deceleration: float = 400.0
# Batas geser ke kiri, relatif terhadap posisi awal (nilai negatif).
@export var min_x: float = -120.0
# Batas geser ke kanan, relatif terhadap posisi awal.
@export var max_x: float = 120.0
# Kemiringan visual torso saat bergerak (radian). Hanya efek tampilan.
@export var lean_amount: float = 0.08

# Kecepatan horizontal torso saat ini (px/detik). Negatif = ke kiri.
var velocity_x := 0.0
# Posisi X awal Player; dipakai sebagai acuan batas min_x/max_x.
var _origin_x := 0.0

@onready var torso: Sprite2D = $Torso        # sprite badan
@onready var shoulder: Marker2D = $Shoulder  # titik pangkal lengan
@onready var arm: Line2D = $Arm              # garis yang menggambarkan lengan
@onready var hand: Node2D = $Hand            # node tangan (hand.gd)

func _ready() -> void:
	# Simpan posisi awal sebagai titik tengah sofa.
	_origin_x = position.x
	add_to_group("player")   # dipakai TaskZone yang menempel di badan (telinga, mulut)

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

# Gambar ulang lengan setiap frame: garis dari bahu ke tangan.
func _process(_delta: float) -> void:
	# to_local() mengubah posisi dunia menjadi koordinat lokal Line2D.
	arm.points = PackedVector2Array([
		arm.to_local(shoulder.global_position),
		arm.to_local(hand.global_position)
	])

extends Node2D

@export_group("Torso Movement")
@export var max_speed: float = 120.0      # kecepatan maksimum geser torso
@export var acceleration: float = 250.0   # makin kecil = makin "berat"
@export var deceleration: float = 400.0
@export var min_x: float = -120.0         # batas kiri sofa (relatif ke posisi awal)
@export var max_x: float = 120.0          # batas kanan sofa
@export var lean_amount: float = 0.08     # kemiringan visual torso (radian)

var velocity_x := 0.0
var _origin_x := 0.0

@onready var torso: Sprite2D = $Torso
@onready var shoulder: Marker2D = $Shoulder
@onready var arm: Line2D = $Arm
@onready var hand: Node2D = $Hand

func _ready() -> void:
	_origin_x = position.x

func _physics_process(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	var target_speed := dir * max_speed
	var rate := acceleration if dir != 0.0 else deceleration
	velocity_x = move_toward(velocity_x, target_speed, rate * delta)

	var new_x := position.x + velocity_x * delta
	var clamped_x := clampf(new_x, _origin_x + min_x, _origin_x + max_x)
	if not is_equal_approx(new_x, clamped_x):
		velocity_x = 0.0   # nabrak ujung sofa
	position.x = clamped_x

	# Miring sedikit biar terasa seperti condong
	torso.rotation = lerpf(torso.rotation, (velocity_x / max_speed) * lean_amount, 0.15)

	Events.torso_moved.emit(absf(velocity_x))

func _process(_delta: float) -> void:
	# Gambar lengan dari bahu ke tangan
	arm.points = PackedVector2Array([
		arm.to_local(shoulder.global_position),
		arm.to_local(hand.global_position)
	])

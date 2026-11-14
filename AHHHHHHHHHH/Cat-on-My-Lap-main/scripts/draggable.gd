class_name Draggable
extends Area2D

@export var item_name: String = "item"
@export var return_time: float = 0.25   # lama item kembali ke tempat asal setelah di-drop

var home_position: Vector2
var is_held := false
var _tween: Tween

func _ready() -> void:
	home_position = global_position
	# Layer 2 = layer item. Item tidak perlu mendeteksi apa pun.
	collision_layer = 2
	collision_mask = 0

func on_grabbed() -> void:
	if _tween:
		_tween.kill()
	is_held = true
	z_index = 10

func on_dropped() -> void:
	is_held = false
	z_index = 0
	# Sementara: item kembali ke posisi asal. Nanti bisa diganti oleh Logic Sistem Tugas.
	_tween = create_tween()
	_tween.tween_property(self, "global_position", home_position, return_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

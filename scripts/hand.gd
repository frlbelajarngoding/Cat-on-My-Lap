class_name Hand
extends Node2D

@export var max_reach: float = 140.0     # jangkauan lengan dari bahu
@export var follow_speed: float = 12.0   # makin kecil = tangan makin lambat/berat

var held_item: Draggable = null
var hand_speed := 0.0
var _prev_pos := Vector2.ZERO

@onready var shoulder: Marker2D = $"../Shoulder"
@onready var grab_area: Area2D = $GrabArea

func _ready() -> void:
	_prev_pos = global_position

func _process(delta: float) -> void:
	# 1. Target = posisi mouse, tapi dibatasi jangkauan dari bahu
	var target := _clamp_to_reach(get_global_mouse_position())

	# 2. Gerak halus (frame-rate independent)
	global_position = global_position.lerp(target, 1.0 - exp(-follow_speed * delta))

	# 3. Hitung kecepatan tangan, dihaluskan supaya tidak jitter
	var raw_speed := global_position.distance_to(_prev_pos) / maxf(delta, 0.0001)
	hand_speed = lerpf(hand_speed, raw_speed, 0.25)
	_prev_pos = global_position

	# 4. Item yang dipegang mengikuti tangan
	if held_item:
		held_item.global_position = global_position

	Events.hand_moved.emit(hand_speed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("grab"):
		_try_grab()
	elif event.is_action_released("grab"):
		_release()

func _clamp_to_reach(point: Vector2) -> Vector2:
	var offset := point - shoulder.global_position
	if offset.length() > max_reach:
		offset = offset.normalized() * max_reach
	return shoulder.global_position + offset

func _try_grab() -> void:
	if held_item:
		return
	var best: Draggable = null
	var best_dist := INF
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

func _release() -> void:
	if not held_item:
		return
	var item := held_item
	held_item = null
	item.on_dropped()
	Events.item_dropped.emit(item, hand_speed)   # hand_speed = "kekerasan" drop

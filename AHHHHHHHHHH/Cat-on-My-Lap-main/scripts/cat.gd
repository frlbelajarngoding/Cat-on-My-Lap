class_name Cat
extends Node2D

# Kucing di atas pangkuan. Mendengarkan gerakan torso & tangan lewat Events,
# lalu menghitung "toleransi" (0 = tenang, max = bangun).
#
# State:
#   SLEEPING -> tidur nyenyak
#   RESTLESS -> mulai terganggu (peringatan, masih aman)
#   AWAKE    -> bangun (gagal)
#   FALLEN   -> jatuh dari pangkuan (gagal)

enum State { SLEEPING, RESTLESS, AWAKE, FALLEN }

const STATE_COLORS := {
	State.SLEEPING: Color(0.95, 0.65, 0.30),
	State.RESTLESS: Color(1.00, 0.88, 0.30),
	State.AWAKE: Color(1.00, 0.25, 0.25),
	State.FALLEN: Color(0.50, 0.50, 0.50),
}

@export_group("Tolerance")
@export var max_tolerance: float = 100.0
@export var calm_decay: float = 6.0            # toleransi turun per detik saat tenang
@export var restless_threshold: float = 40.0   # di atas ini -> RESTLESS
@export var calm_threshold: float = 25.0       # di bawah ini -> kembali SLEEPING (hysteresis)

@export_group("Torso Disturbance")
@export var torso_deadzone: float = 15.0       # px/detik; di bawah ini dianggap tidak mengganggu
@export var torso_weight: float = 0.12         # poin toleransi per (px/detik) per detik

@export_group("Hand Disturbance")
@export var hand_deadzone: float = 80.0
@export var hand_weight: float = 0.04

@export_group("Drop Impact")
@export var drop_deadzone: float = 150.0       # item dilepas pelan -> tidak mengganggu
@export var drop_weight: float = 0.03          # lonjakan instan = (impact - deadzone) * weight

@export_group("Fall")
@export var violent_hand_speed: float = 1200.0 # kecepatan tangan (relatif) yang dianggap mengguncang keras
@export var violent_time_to_fall: float = 0.25 # detik mengguncang keras sebelum kucing jatuh

# Pengali sensitivitas. Dipakai Logic Sistem Tugas, mis. 1.5 selama tugas berisiko.
var sensitivity: float = 1.0

var state: State = State.SLEEPING
var tolerance: float = 0.0

var _torso_speed := 0.0
var _hand_speed := 0.0
var _violent_timer := 0.0
var _time := 0.0
var _base_scale := Vector2.ONE

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_base_scale = sprite.scale
	sprite.modulate = STATE_COLORS[State.SLEEPING]
	Events.torso_moved.connect(func(s: float) -> void: _torso_speed = s)
	Events.hand_moved.connect(func(s: float) -> void: _hand_speed = s)
	Events.item_dropped.connect(_on_item_dropped)
	Events.tolerance_changed.emit(tolerance, max_tolerance)

func is_alive() -> bool:
	return state == State.SLEEPING or state == State.RESTLESS

func _process(delta: float) -> void:
	if not is_alive():
		return
	_time += delta

	# hand_speed dari Hand ikut naik saat torso bergeser (Hand adalah child Player),
	# jadi kurangi dengan kecepatan torso supaya tidak terhitung dua kali.
	var rel_hand := maxf(0.0, _hand_speed - _torso_speed)

	# 1. Gangguan per detik dari gerakan kanan-kiri dan goncangan tangan
	var gain := 0.0
	gain += maxf(0.0, _torso_speed - torso_deadzone) * torso_weight
	gain += maxf(0.0, rel_hand - hand_deadzone) * hand_weight
	gain *= sensitivity

	# 2. Naik karena gangguan, turun karena tenang
	_set_tolerance(tolerance + (gain - calm_decay) * delta)

	# 3. Mengguncang terlalu keras terlalu lama -> kucing jatuh
	if rel_hand > violent_hand_speed:
		_violent_timer += delta
	else:
		_violent_timer = maxf(0.0, _violent_timer - delta)
	if _violent_timer >= violent_time_to_fall:
		_set_state(State.FALLEN)
		return

	_evaluate_state()
	_animate()

func _on_item_dropped(_item: Draggable, impact_speed: float) -> void:
	if not is_alive():
		return
	# Item dilepas sambil tangan bergerak cepat = guncangan mendadak
	var jolt := maxf(0.0, impact_speed - drop_deadzone) * drop_weight * sensitivity
	if jolt > 0.0:
		_set_tolerance(tolerance + jolt)
		_evaluate_state()

func _set_tolerance(value: float) -> void:
	var v := clampf(value, 0.0, max_tolerance)
	if is_equal_approx(v, tolerance):
		return
	tolerance = v
	Events.tolerance_changed.emit(tolerance, max_tolerance)

func _evaluate_state() -> void:
	if tolerance >= max_tolerance:
		_set_state(State.AWAKE)
	elif state == State.SLEEPING and tolerance >= restless_threshold:
		_set_state(State.RESTLESS)
	elif state == State.RESTLESS and tolerance <= calm_threshold:
		_set_state(State.SLEEPING)

func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	var old := state
	state = new_state
	Events.cat_state_changed.emit(state, old)

	create_tween().tween_property(sprite, "modulate", STATE_COLORS[state], 0.2)

	match state:
		State.AWAKE:
			_play_wake()
			Events.cat_woke_up.emit()
		State.FALLEN:
			_play_fall()
			Events.cat_fell.emit()

# --- Visual placeholder (ganti dengan AnimatedSprite2D nanti) ---

func _animate() -> void:
	match state:
		State.SLEEPING:
			# Bernapas pelan
			sprite.position = Vector2.ZERO
			sprite.scale = _base_scale * (1.0 + sin(_time * 2.0) * 0.03)
		State.RESTLESS:
			# Gemetar, makin kuat saat toleransi makin tinggi
			var ratio := tolerance / max_tolerance
			sprite.scale = _base_scale
			sprite.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * (1.0 + ratio * 3.0)

func _play_wake() -> void:
	sprite.position = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(sprite, "scale", _base_scale * 1.3, 0.12)
	tw.tween_property(sprite, "scale", _base_scale * 1.15, 0.12)

func _play_fall() -> void:
	sprite.position = Vector2.ZERO
	sprite.scale = _base_scale
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sprite, "position:y", 140.0, 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(sprite, "rotation", 1.6, 0.6)

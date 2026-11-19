class_name Cat
extends Node2D
# ============================================================
# CAT (Logic Meter Toleransi & State Kucing)
# ------------------------------------------------------------
# Kucing berada di pangkuan. Statenya ditentukan oleh "tolerance":
#   0 = tenang, max_tolerance = kucing bangun (gagal).
# Gerakan cepat menaikkan tolerance, diam menurunkannya perlahan.
#
# State:
#   SLEEPING -> tidur tenang
#   RESTLESS -> gelisah (peringatan, masih aman)
#   AWAKE    -> bangun (GAGAL)
#   FALLEN   -> jatuh dari pangkuan (GAGAL)
#
# Alur state:
#   SLEEPING -> RESTLESS (tolerance >= restless_threshold)
#   RESTLESS -> SLEEPING (tolerance <= calm_threshold)
#   SLEEPING/RESTLESS -> AWAKE (tolerance >= max_tolerance)
#   SLEEPING/RESTLESS -> FALLEN (tangan mengguncang keras terlalu lama)
# Catatan: restless_threshold > calm_threshold sengaja dibuat
# berbeda (hysteresis) agar state tidak bolak-balik tiap frame.
# ============================================================

enum State { SLEEPING, RESTLESS, AWAKE, FALLEN }

# Warna placeholder tiap state (diterapkan ke modulate sprite).
const STATE_COLORS := {
	State.SLEEPING: Color(0.95, 0.65, 0.30),
	State.RESTLESS: Color(1.00, 0.88, 0.30),
	State.AWAKE: Color(1.00, 0.25, 0.25),
	State.FALLEN: Color(0.50, 0.50, 0.50),
}

@export_group("Tolerance")
# Nilai maksimum toleransi; mencapai ini = kucing bangun.
@export var max_tolerance: float = 100.0
# Toleransi yang berkurang per detik saat kucing tidak terganggu.
@export var calm_decay: float = 6.0
# Toleransi di atas nilai ini -> state RESTLESS.
@export var restless_threshold: float = 40.0
# Toleransi di bawah nilai ini -> kembali SLEEPING dari RESTLESS.
@export var calm_threshold: float = 25.0

@export_group("Torso Disturbance")
# Kecepatan torso (px/s) di bawah ini dianggap tidak mengganggu.
@export var torso_deadzone: float = 15.0
# Poin toleransi per (px/s di atas deadzone) per detik.
@export var torso_weight: float = 0.12

@export_group("Hand Disturbance")
# Kecepatan tangan relatif (px/s) di bawah ini dianggap aman.
@export var hand_deadzone: float = 80.0
# Poin toleransi per (px/s di atas deadzone) per detik.
@export var hand_weight: float = 0.04

@export_group("Drop Impact")
# Item dilepas dengan kecepatan di bawah ini -> tidak mengganggu.
@export var drop_deadzone: float = 150.0
# Lonjakan instan toleransi = (impact - deadzone) * drop_weight.
@export var drop_weight: float = 0.03

@export_group("Fall")
# Kecepatan tangan relatif yang dianggap mengguncang keras (px/s).
@export var violent_hand_speed: float = 1200.0
# Lama (detik) mengguncang keras sebelum kucing jatuh.
@export var violent_time_to_fall: float = 0.25

# Pengali sensitivitas seluruh gangguan. 1.0 = normal.
# Dipakai Logic Sistem Tugas, mis. 1.5 selama tugas berisiko,
# atau dinaikkan per hari agar makin sulit.
var sensitivity: float = 1.0

# State kucing saat ini.
var state: State = State.SLEEPING
# Toleransi saat ini (0..max_tolerance).
var tolerance: float = 0.0
# Batas bawah toleransi hari ini = toleransi terbawa dari hari sebelumnya.
# Toleransi tidak bisa turun di bawah nilai ini (meter stres tidak kembali ke 0).
var tolerance_floor: float = 0.0

var _torso_speed := 0.0   # kecepatan torso terakhir dari Events
var _hand_speed := 0.0    # kecepatan tangan terakhir dari Events
var _violent_timer := 0.0 # akumulasi waktu guncangan keras
var _time := 0.0          # penghitung waktu untuk animasi bernapas
var _base_scale := Vector2.ONE  # skala awal sprite, acuan animasi

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Ambil kondisi hari ini dari GameState (autoload).
	tolerance_floor = GameState.carried_tolerance
	tolerance = tolerance_floor
	sensitivity = GameState.sensitivity_for_day()
	
	_base_scale = sprite.scale
	sprite.modulate = STATE_COLORS[State.SLEEPING]
	# Simpan kecepatan terbaru setiap kali Player/Hand memancarkannya.
	Events.torso_moved.connect(func(s: float) -> void: _torso_speed = s)
	Events.hand_moved.connect(func(s: float) -> void: _hand_speed = s)
	Events.item_dropped.connect(_on_item_dropped)
	# Umumkan nilai awal supaya UI langsung tersinkron.
	Events.tolerance_changed.emit(tolerance, max_tolerance)

# True jika kucing belum gagal (masih bisa dilanjutkan).
func is_alive() -> bool:
	return state == State.SLEEPING or state == State.RESTLESS

# Loop utama logika: hitung gangguan, update toleransi, evaluasi state.
func _process(delta: float) -> void:
	if not is_alive():
		return   # setelah gagal, hentikan semua perhitungan
	_time += delta

	# hand_speed dari Hand ikut naik saat torso bergeser (Hand adalah child Player),
	# jadi kurangi dengan kecepatan torso supaya tidak terhitung dua kali.
	var rel_hand := maxf(0.0, _hand_speed - _torso_speed)

	# 1. Gangguan per detik dari gerakan torso dan goncangan tangan.
	#    maxf(0, speed - deadzone): hanya kecepatan di atas deadzone yang dihitung.
	var gain := 0.0
	gain += maxf(0.0, _torso_speed - torso_deadzone) * torso_weight
	gain += maxf(0.0, rel_hand - hand_deadzone) * hand_weight
	gain *= sensitivity

	# 2. Toleransi naik karena gangguan, turun karena tenang (calm_decay).
	_set_tolerance(tolerance + (gain - calm_decay) * delta)

	# 3. Mengguncang terlalu keras terlalu lama -> kucing jatuh.
	#    Timer naik saat guncangan keras, turun perlahan saat tidak.
	if rel_hand > violent_hand_speed:
		_violent_timer += delta
	else:
		_violent_timer = maxf(0.0, _violent_timer - delta)
	if _violent_timer >= violent_time_to_fall:
		_set_state(State.FALLEN)
		return

	_evaluate_state()
	_animate()

# Dipanggil saat item dilepas. Pelepasan kasar = lonjakan toleransi instan.
func _on_item_dropped(_item: Draggable, impact_speed: float) -> void:
	if not is_alive():
		return
	# Item dilepas sambil tangan bergerak cepat = guncangan mendadak.
	var jolt := maxf(0.0, impact_speed - drop_deadzone) * drop_weight * sensitivity
	if jolt > 0.0:
		_set_tolerance(tolerance + jolt)
		_evaluate_state()

# Mengubah toleransi (dibatasi 0..max) dan memberi tahu UI/sistem lain.
# Signal hanya dikirim jika nilainya benar-benar berubah.
func _set_tolerance(value: float) -> void:
	var v := clampf(value, tolerance_floor, max_tolerance)
	if is_equal_approx(v, tolerance):
		return
	tolerance = v
	Events.tolerance_changed.emit(tolerance, max_tolerance)

# Menentukan state berdasarkan nilai toleransi saat ini.
func _evaluate_state() -> void:
	if tolerance >= max_tolerance:
		_set_state(State.AWAKE)
	elif state == State.SLEEPING and tolerance >= restless_threshold:
		_set_state(State.RESTLESS)
	elif state == State.RESTLESS and tolerance <= calm_threshold:
		_set_state(State.SLEEPING)

# Pusat perubahan state: memancarkan signal, mengubah warna, dan memicu
# animasi/event gagal. Tidak melakukan apa pun jika state-nya sama.
func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	var old := state
	state = new_state
	Events.cat_state_changed.emit(state, old)

	# Warna sprite berganti halus (0.2 detik).
	create_tween().tween_property(sprite, "modulate", STATE_COLORS[state], 0.2)

	# Kondisi gagal memicu animasi dan signal khusus.
	match state:
		State.AWAKE:
			_play_wake()
			Events.cat_woke_up.emit()
		State.FALLEN:
			_play_fall()
			Events.cat_fell.emit()

# ---------- Visual placeholder (nanti ganti dengan AnimatedSprite2D) ----------

# Animasi berulang per frame sesuai state.
func _animate() -> void:
	match state:
		State.SLEEPING:
			# Bernapas pelan: skala naik-turun mengikuti gelombang sin.
			sprite.position = Vector2.ZERO
			sprite.scale = _base_scale * (1.0 + sin(_time * 2.0) * 0.03)
		State.RESTLESS:
			# Gemetar acak, makin kuat saat toleransi makin tinggi.
			var ratio := tolerance / max_tolerance
			sprite.scale = _base_scale
			sprite.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * (1.0 + ratio * 3.0)

# Animasi sekali jalan: kucing "kaget" (membesar lalu mengecil sedikit).
func _play_wake() -> void:
	sprite.position = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(sprite, "scale", _base_scale * 1.3, 0.12)
	tw.tween_property(sprite, "scale", _base_scale * 1.15, 0.12)

# Animasi sekali jalan: kucing jatuh ke bawah sambil berputar (paralel).
func _play_fall() -> void:
	sprite.position = Vector2.ZERO
	sprite.scale = _base_scale
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sprite, "position:y", 140.0, 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(sprite, "rotation", 1.6, 0.6)

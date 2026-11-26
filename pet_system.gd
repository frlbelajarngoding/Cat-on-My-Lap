class_name PetSystem
extends Node
# ============================================================
# PET SYSTEM (Elus kucing, Day 4+)
# ------------------------------------------------------------
# Tahan LMB dengan TANGAN KOSONG di atas kepala kucing dan gerakkan
# pelan (di bawah max_speed). Meter pulih recovery_per_second tiap detik.
# Berisiko karena tugas lain terus menumpuk. Pemulihan tidak bisa
# melewati lantai meter hari itu (aturan Cat).
# ============================================================

@export var from_day: int = 4
# Di atas kecepatan ini bukan elusan lagi (GDD: 60 px/s).
@export var max_speed: float = 60.0
# Di bawah ini = diam, bukan mengelus.
@export var min_speed: float = 8.0
# Pemulihan meter per detik (GDD: 0,8%).
@export var recovery_per_second: float = 0.8

@onready var zone: TaskZone = $PetZone

func _ready() -> void:
	if GameState.current_day < from_day:
		zone.hide()
		set_process(false)
		return

func _process(delta: float) -> void:
	# Tangan aktif sekarang bisa berganti: cari setiap frame (hanya tangan aktif di group "hand").
	var hand := get_tree().get_first_node_in_group("hand") as Hand
	if hand == null or hand.held_item != null:
		return
	if not Input.is_action_pressed("grab"):
		return
	if not zone.contains_point(hand.global_position):
		return
	var s := hand.hand_speed
	if s >= min_speed and s <= max_speed:
		Events.meter_recovery.emit(recovery_per_second * delta)

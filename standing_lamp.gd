extends Node2D
# ============================================================
# STANDING LAMP (dekorasi: ada dari Day 1, mati; Day 5 menyala)
# Saat tugas "lamp" selesai: lampu padam dan roboh (kabel tertarik).
# ============================================================

const OFF_COLOR := Color(0.30, 0.28, 0.22)
const ON_COLOR := Color(1.0, 0.9, 0.5)

@onready var shade: ColorRect = $Shade

func _ready() -> void:
	shade.color = ON_COLOR if GameState.current_day >= GameState.MAX_DAY else OFF_COLOR
	Events.task_completed.connect(_on_task_completed)

func _on_task_completed(id: String, _clean: bool) -> void:
	if id != "lamp":
		return
	shade.color = OFF_COLOR
	# Kabel tertarik: lampu miring/roboh + glitch (bila FX dipakai).
	create_tween().tween_property(self, "rotation", 0.5, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if Events.has_signal("glitch_requested"):
		Events.glitch_requested.emit(1.0, 0.6)
		

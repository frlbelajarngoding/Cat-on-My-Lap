extends Node2D

@onready var label: Label = $DebugLabel
@onready var tolerance_bar: ProgressBar = $ToleranceBar
@onready var game_over_label: Label = $GameOverLabel

var torso_speed := 0.0
var hand_speed := 0.0
var tolerance := 0.0
var max_tolerance := 100.0
var cat_state: int = Cat.State.SLEEPING
var game_over := false

func _ready() -> void:
	Events.torso_moved.connect(func(s): torso_speed = s)
	Events.hand_moved.connect(func(s): hand_speed = s)
	Events.item_grabbed.connect(func(item): print("Grabbed: ", item.item_name))
	Events.item_dropped.connect(func(item, impact):
		print("Dropped: ", item.item_name, " | impact: ", snappedf(impact, 0.1)))

	Events.tolerance_changed.connect(_on_tolerance_changed)
	Events.cat_state_changed.connect(func(new_state, _old): cat_state = new_state)
	Events.cat_woke_up.connect(_end_game.bind("Kucingnya bangun!"))
	Events.cat_fell.connect(_end_game.bind("Kucingnya jatuh!"))

func _process(_delta: float) -> void:
	label.text = "Torso: %.0f px/s\nHand: %.0f px/s\nCat: %s\nTolerance: %.0f / %.0f" % [
		torso_speed, hand_speed, Cat.State.keys()[cat_state], tolerance, max_tolerance]

func _on_tolerance_changed(value: float, max_value: float) -> void:
	tolerance = value
	max_tolerance = max_value
	tolerance_bar.max_value = max_value
	tolerance_bar.value = value
	tolerance_bar.modulate = Color.GREEN.lerp(Color.RED, value / max_value)

func _end_game(reason: String) -> void:
	game_over = true
	game_over_label.text = "%s\nTekan R untuk mengulang" % reason
	game_over_label.show()

func _unhandled_input(event: InputEvent) -> void:
	if game_over and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()

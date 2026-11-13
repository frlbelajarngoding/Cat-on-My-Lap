extends Node2D

@onready var label: Label = $DebugLabel

var torso_speed := 0.0
var hand_speed := 0.0

func _ready() -> void:
	Events.torso_moved.connect(func(s): torso_speed = s)
	Events.hand_moved.connect(func(s): hand_speed = s)
	Events.item_grabbed.connect(func(item): print("Grabbed: ", item.item_name))
	Events.item_dropped.connect(func(item, impact):
		print("Dropped: ", item.item_name, " | impact: ", snappedf(impact, 0.1)))

func _process(_delta: float) -> void:
	label.text = "Torso: %.0f px/s\nHand: %.0f px/s" % [torso_speed, hand_speed]

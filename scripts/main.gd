extends Node2D
# ============================================================
# MAIN (Scene debug / UI sementara)
# ------------------------------------------------------------
# Menampilkan data real-time (kecepatan, state, toleransi),
# progress bar toleransi, dan layar game over dengan restart (R).
# Nantinya bisa digantikan oleh UI final dan Daily Loop Manager.
# ============================================================

@onready var label: Label = $DebugLabel               # teks debug pojok layar
@onready var game_over_label: Label = $GameOverLabel  # teks saat gagal

# Salinan lokal data dari Events, hanya untuk ditampilkan.
var torso_speed := 0.0
var hand_speed := 0.0
var cat_state: int = Cat.State.SLEEPING

func _ready() -> void:
	# Simpan data kecepatan untuk ditampilkan di label debug.
	Events.torso_moved.connect(func(s): torso_speed = s)
	Events.hand_moved.connect(func(s): hand_speed = s)
	# Log ke Output untuk membantu debugging interaksi item.
	Events.item_grabbed.connect(func(item): print("Grabbed: ", item.item_name))
	Events.item_dropped.connect(func(item, impact):
		print("Dropped: ", item.item_name, " | impact: ", snappedf(impact, 0.1)))

	Events.cat_state_changed.connect(func(new_state, _old): cat_state = new_state)
	# .bind() menyisipkan teks alasan sebagai argumen _end_game.
	Events.cat_woke_up.connect(_end_game.bind("Kucingnya bangun!"))
	Events.cat_fell.connect(_end_game.bind("Kucingnya jatuh!"))

# Perbarui teks debug setiap frame.
#func _process(_delta: float) -> void:
	#label.text = "Torso: %.0f px/s\nHand: %.0f px/s\nCat: %s\nTolerance: %.0f / %.0f" % [
		#torso_speed, hand_speed, Cat.State.keys()[cat_state], tolerance, max_tolerance]

# Menampilkan layar game over dengan alasan kegagalan.
func _end_game(reason: String) -> void:
	game_over_label.text = "%s\nMengulang hari..." % reason
	game_over_label.show()

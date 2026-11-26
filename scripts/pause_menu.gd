class_name PauseMenu
extends CanvasLayer
# ============================================================
# PAUSE MENU (Tombol pause + layar pause)
# ------------------------------------------------------------
# - Tombol pause di pojok kiri atas selama game berjalan.
# - Esc (ui_cancel) juga membuka / menutup pause.
# - Saat pause: layer hitam transparan + tombol di tengah:
#   Continue, New Game, Home.
# Pause hanya boleh saat hari sedang berjalan (DayManager.Phase.RUNNING),
# supaya tidak bentrok dengan fade, rewind, interlude, dan ending.
# process_mode = ALWAYS karena menu ini harus hidup saat game di-pause.
# Tambahkan sebagai anak dari root scene game (saudara DayManager).
# ============================================================

# Transparansi layer hitam saat pause. 0 = bening, 1 = hitam pekat.
# Diatur programmer lewat Inspector, bukan oleh pemain.
@export_range(0.0, 1.0, 0.01) var dim_opacity: float = 0.65:
	set(value):
		dim_opacity = value
		if is_node_ready():
			_apply_dim()

# Scene Home / Title yang dituju tombol Home (pilih title_screen.tscn).
@export_file("*.tscn") var home_scene: String = ""

# Tombol keyboard untuk pause / lanjut. Default Esc.
@export var pause_action: StringName = &"ui_cancel"

# True selama menu ini yang sedang mem-pause game.
var _is_open := false

@onready var pause_button: Button = $PauseButton
@onready var overlay: Control = $Overlay
@onready var dim: ColorRect = $Overlay/Dim
@onready var continue_button: Button = $Overlay/Center/Buttons/ContinueButton
@onready var new_game_button: Button = $Overlay/Center/Buttons/NewGameButton
@onready var home_button: Button = $Overlay/Center/Buttons/HomeButton
# Boleh null (mis. saat scene ini dites sendirian): pause dianggap boleh.
@onready var day_manager: DayManager = get_node_or_null("../DayManager") as DayManager

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_dim()
	overlay.hide()

	# Supaya Space / Enter tidak ikut menekan tombol pause tanpa sengaja.
	pause_button.focus_mode = Control.FOCUS_NONE

	pause_button.pressed.connect(open_pause)
	continue_button.pressed.connect(resume)
	new_game_button.pressed.connect(_on_new_game_pressed)
	home_button.pressed.connect(_on_home_pressed)

# Tombol pause disembunyikan bila game sedang tidak boleh di-pause
# (blackout, rewind, ending, atau saat menu sudah terbuka).
func _process(_delta: float) -> void:
	pause_button.visible = not _is_open and _can_pause()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(pause_action):
		return
	if _is_open:
		resume()
		get_viewport().set_input_as_handled()
	elif _can_pause():
		open_pause()
		get_viewport().set_input_as_handled()

# ---------- Buka / tutup ----------

func open_pause() -> void:
	if _is_open or not _can_pause():
		return
	_is_open = true
	overlay.show()
	get_tree().paused = true
	Events.game_paused.emit()
	continue_button.grab_focus()   # navigasi keyboard / controller

func resume() -> void:
	if not _is_open:
		return
	_is_open = false
	overlay.hide()
	get_tree().paused = false
	Events.game_resumed.emit()

# Pause hanya saat hari berjalan dan tidak ada sistem lain yang sudah mem-pause.
func _can_pause() -> bool:
	if get_tree().paused:
		return false
	if day_manager == null:
		return true
	return day_manager.phase == DayManager.Phase.RUNNING

# ---------- Tombol ----------

# New Game: ulang dari Day 1. Unpause DULU, kalau tidak scene baru ikut beku.
func _on_new_game_pressed() -> void:
	_is_open = false
	get_tree().paused = false
	GameState.start_fresh()
	get_tree().reload_current_scene()

# Home: kembali ke Title Screen. Unpause DULU, alasannya sama.
func _on_home_pressed() -> void:
	if home_scene.is_empty():
		push_error("PauseMenu: 'home_scene' belum diisi di Inspector.")
		return
	_is_open = false
	get_tree().paused = false
	get_tree().change_scene_to_file(home_scene)

# Warna hitam dengan alpha = dim_opacity. Alpha ada di warnanya (bukan modulate)
# supaya tidak tercampur dengan efek lain.
func _apply_dim() -> void:
	dim.color = Color(0.0, 0.0, 0.0, dim_opacity)

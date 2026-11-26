class_name TitleScreen
extends Control
# ============================================================
# TITLE SCREEN (Home)
# ------------------------------------------------------------
# Judul game + tombol Play dan Exit (persegi panjang, di tengah).
# Hanya menampilkan menu; data game ada di GameState.
# Slot asset untuk tim visual (cukup isi Texture di Inspector):
#   - BackgroundArt : gambar latar penuh layar
#   - TitleLogo     : logo / judul game
# Selama Texture kosong, placeholder (ColorRect / Label) tampil.
# Begitu Texture diisi, placeholder otomatis tersembunyi.
# ============================================================

# Scene game yang dimuat tombol Play (pilih main.tscn di Inspector).
@export_file("*.tscn") var game_scene: String = ""

# Mencegah klik ganda saat pindah scene.
var _busy := false

@onready var background_placeholder: ColorRect = $BackgroundPlaceholder
@onready var background_art: TextureRect = $BackgroundArt
@onready var title_label: Label = $TitleLabel
@onready var title_logo: TextureRect = $TitleLogo
@onready var play_button: Button = $Center/Buttons/PlayButton
@onready var exit_button: Button = $Center/Buttons/ExitButton

func _ready() -> void:
	# Placeholder hanya tampil selama asset belum dipasang.
	background_placeholder.visible = background_art.texture == null
	title_label.visible = title_logo.texture == null

	play_button.pressed.connect(_on_play_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	# Build web tidak bisa menutup game lewat quit(), jadi sembunyikan Exit.
	exit_button.visible = not OS.has_feature("web")

	# Fokus awal supaya menu bisa dipakai dengan keyboard (panah + Enter).
	play_button.grab_focus()

func _on_play_pressed() -> void:
	if _busy:
		return
	if game_scene.is_empty():
		push_error("TitleScreen: 'game_scene' belum diisi di Inspector.")
		return
	_busy = true
	GameState.start_fresh()   # Day 1, tanpa sisa toleransi, fade-in dari hitam
	get_tree().change_scene_to_file(game_scene)

func _on_exit_pressed() -> void:
	get_tree().quit()

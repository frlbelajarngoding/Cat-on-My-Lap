class_name TaskZone
extends Node2D
# ============================================================
# TASK ZONE (Area tujuan item)
# ------------------------------------------------------------
# Persegi tak terlihat secara fisik (tanpa collision) yang dipakai
# Task untuk menjawab "apakah titik ini ada di dalam area?".
# Contoh: tanah pot, akuarium, telinga, piring microwave.
#
# Digambar sebagai kotak transparan + label sebagai PLACEHOLDER.
# Nanti ganti dengan sprite asli; logikanya tetap contains_point().
# ============================================================

# Ukuran area (px), berpusat di posisi node.
@export var size: Vector2 = Vector2(60, 40)
# Teks placeholder di atas area.
@export var label_text: String = ""
# Warna isi placeholder.
@export var color: Color = Color(0.3, 0.9, 0.5, 0.25)
# True = zona menempel pada Player dan ikut bergeser saat torso
# condong (untuk telinga/mulut, yang ada di badan pemain).
@export var attach_to_player: bool = false
# True = tetap terlihat walau tugasnya belum aktif (penanda benda diam,
# mis. pot dan akuarium). False = hanya terlihat saat tugas aktif.
@export var show_when_idle: bool = false

# Outline putih saat zona ini adalah tujuan langkah tugas sekarang (diatur Task).
@export var outline_color: Color = Color.WHITE
@export var outline_width: float = 2.0

var _highlight := false
var _player: Node2D = null
var _offset := Vector2.ZERO   # jarak awal zona dari Player

func _ready() -> void:
	set_process(attach_to_player)
	if attach_to_player:
		# Tunggu akhir frame supaya Player pasti sudah siap.
		_bind_player.call_deferred()

func _bind_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player:
		_offset = global_position - _player.global_position

func _process(_delta: float) -> void:
	if _player:
		global_position = _player.global_position + _offset
	if _highlight:
		queue_redraw()   # outline berkedip

# Dipanggil Task: true = tampilkan outline putih berkedip.
func set_highlight(on: bool) -> void:
	if on == _highlight:
		return
	_highlight = on
	# Saat menyala, gambar di atas semua benda (mis. tanaman yang z_index-nya 999).
	z_index = 1000 if on else 0
	set_process(attach_to_player or on)
	queue_redraw()

# True jika titik dunia p berada di dalam area ini.
func contains_point(p: Vector2) -> bool:
	return Rect2(global_position - size * 0.5, size).has_point(p)

func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, color)
	draw_rect(rect, Color(color.r, color.g, color.b, 0.8), false, 1.0)
	if _highlight:
		var blink := 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.006)
		var c := Color(outline_color.r, outline_color.g, outline_color.b, outline_color.a * blink)
		draw_rect(rect.grow(outline_width * 0.5), c, false, outline_width)
	if label_text != "":
		draw_string(ThemeDB.fallback_font, Vector2(-size.x * 0.5, -size.y * 0.5 - 3.0),
			label_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 9, Color(1, 1, 1, 0.9))

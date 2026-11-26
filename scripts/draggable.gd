class_name Draggable
extends Area2D
# ============================================================
# DRAGGABLE (Item yang bisa diambil)
# ------------------------------------------------------------
# Dasar untuk semua item: telepon, kaleng air, tuas kompor, dll.
# Hand yang menggerakkan item saat dipegang; skrip ini hanya
# mengatur status (dipegang/tidak) dan perilaku setelah dilepas.
# Logic Sistem Tugas (Task) membaca status ini untuk menilai langkah.
# ============================================================

# Nama item, dipakai untuk identifikasi (debug / sistem tugas).
@export var item_name: String = "item"
# Lama (detik) item kembali ke posisi asal setelah dilepas.
@export var return_time: float = 0.25
# False = item TIDAK ikut tangan saat dipegang. Dipakai untuk benda
# tetap yang cuma diklik/ditahan: tuas kompor, pintu microwave, laptop.
@export var follow_hand: bool = true
# Gambar item. Kosong = tetap pakai ikon placeholder.
@export var texture: Texture2D
# Pembesaran gambar. Aset 1x dikali 2 agar pas dengan layar 640x360.
@export var sprite_scale: float = 2.0
# Teks dan warna placeholder (kosongkan label_text bila sudah ada gambar).
@export var label_text: String = ""
@export var tint: Color = Color.WHITE

# Posisi awal item di dunia; tujuan kembali setelah di-drop.
var home_position: Vector2
# True selama item dipegang tangan.
var is_held := false
# Berapa lama (detik) item dipegang pada pegangan terakhir.
# Dipakai untuk membedakan klik cepat (tap) dari tahan.
var last_hold_time := 0.0
# Status tampilan ganda (mis. pintu terbuka). Diubah lewat toggle().
var toggled := false
# Waktu (ms) saat item terakhir diambil.
var _grab_msec := 0
# Tween animasi kembali; disimpan agar bisa dibatalkan.
var _tween: Tween

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Catat posisi awal sebagai "rumah" item.
	home_position = global_position
	# Layer 2 = layer item (dideteksi GrabArea milik Hand).
	# Mask 0 = item tidak mendeteksi apa pun.
	collision_layer = 2
	collision_mask = 0
	if texture:
		sprite.texture = texture
		sprite.scale = Vector2.ONE * sprite_scale
		# Kotak tangkap mengikuti ukuran gambar. Dibuat baru per item karena
		# shape di draggable.tscn dipakai bersama oleh semua instance.
		var shape := RectangleShape2D.new()
		shape.size = texture.get_size() * sprite_scale
		$CollisionShape2D.shape = shape
	sprite.modulate = tint
	if label_text != "":
		var label := Label.new()
		label.text = label_text
		label.add_theme_font_size_override("font_size", 8)
		label.custom_minimum_size = Vector2(70, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(-35, 11)
		add_child(label)

# Dipanggil Hand saat item diambil.
func on_grabbed() -> void:
	# Batalkan animasi kembali yang mungkin masih berjalan.
	if _tween:
		_tween.kill()
	is_held = true
	_grab_msec = Time.get_ticks_msec()
	z_index = 10   # tampil di atas objek lain selama dipegang

# Dipanggil Hand saat item dilepas.
func on_dropped() -> void:
	is_held = false
	z_index = 0
	last_hold_time = (Time.get_ticks_msec() - _grab_msec) / 1000.0
	if not follow_hand:
		return   # benda tetap: tidak ada yang perlu dikembalikan
	# Item meluncur kembali ke posisi asal. Task bisa membatalkannya
	# lewat keep_here() bila item memang harus tetap di tempat baru.
	_tween = create_tween()
	_tween.tween_property(self, "global_position", home_position, return_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# Item tetap di posisinya sekarang (batalkan animasi kembali).
# Dipanggil Task tepat setelah on_dropped() pada langkah "stay".
func keep_here() -> void:
	if _tween:
		_tween.kill()

# Ganti tampilan ganda (mis. pintu tertutup <-> terbuka).
# Placeholder: item jadi setengah transparan saat toggled.
func toggle() -> void:
	toggled = not toggled
	sprite.modulate.a = 0.35 if toggled else tint.a

# Kembalikan item ke kondisi awal setelah tugas selesai.
func reset_to_home() -> void:
	if toggled:
		toggle()
	if is_held or not follow_hand:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "global_position", home_position, return_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

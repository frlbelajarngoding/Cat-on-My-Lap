class_name Draggable
extends Area2D
# ============================================================
# DRAGGABLE (Item yang bisa diambil)
# ------------------------------------------------------------
# Dasar untuk semua item: remote, telepon, tongkat, makanan, dll.
# Hand yang menggerakkan item saat dipegang; skrip ini hanya
# mengatur status (dipegang/tidak) dan perilaku setelah dilepas.
# Logic Sistem Tugas dapat meng-extend/mengganti on_dropped().
# ============================================================

# Nama item, dipakai untuk identifikasi (debug / sistem tugas).
@export var item_name: String = "item"
# Lama (detik) item kembali ke posisi asal setelah dilepas.
@export var return_time: float = 0.25

# Posisi awal item di dunia; tujuan kembali setelah di-drop.
var home_position: Vector2
# True selama item dipegang tangan.
var is_held := false
# Tween animasi kembali; disimpan agar bisa dibatalkan.
var _tween: Tween

func _ready() -> void:
	# Catat posisi awal sebagai "rumah" item.
	home_position = global_position
	# Layer 2 = layer item (dideteksi GrabArea milik Hand).
	# Mask 0 = item tidak mendeteksi apa pun.
	collision_layer = 2
	collision_mask = 0

# Dipanggil Hand saat item diambil.
func on_grabbed() -> void:
	# Batalkan animasi kembali yang mungkin masih berjalan.
	if _tween:
		_tween.kill()
	is_held = true
	z_index = 10   # tampil di atas objek lain selama dipegang

# Dipanggil Hand saat item dilepas.
func on_dropped() -> void:
	is_held = false
	z_index = 0
	# Sementara: item meluncur kembali ke posisi asal.
	# Nanti bisa diganti oleh Logic Sistem Tugas (mis. item jatuh, ditaruh di microwave).
	_tween = create_tween()
	_tween.tween_property(self, "global_position", home_position, return_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

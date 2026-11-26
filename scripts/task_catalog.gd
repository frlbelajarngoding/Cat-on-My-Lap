class_name TaskCatalog
extends RefCounted
# ============================================================
# TASK CATALOG (Data tugas, mengikuti "Katalog Tugas" di GDD)
# ------------------------------------------------------------
# Semua angka penyeimbang (durasi suara, batas jam, penalti)
# ada di sini supaya mudah di-tuning tanpa menyentuh logika.
#
# Field tiap tugas:
#   name        nama tampilan
#   category    "A" = sekali sehari, ada batas jam. Wajib selesai
#               sebelum hari ditutup.
#               "B" = berulang kali sehari.
#   scene       scene berisi item (Draggable) dan zona (TaskZone)
#   sound       detik dari suara mulai sampai GAGAL (fase 4).
#               0 = tanpa suara. Dibagi rata jadi fase 1, 2, 3.
#   deadline    jam game batas tugas A (17.0 = 17:00). 0 = tanpa batas
#   no_deadline_days   hari yang batasnya dimatikan (Day 1 = tutorial)
#   penalty     % meter yang hilang SEKALI saat tugas gagal/terlambat
#   steps       langkah berurutan (lihat daftar tipe di bawah)
#   steps_by_day   langkah pengganti, berlaku SEJAK hari tertentu
#
# Tipe langkah (semua mengacu ke nama node anak di scene tugas):
#   tap     item dilepas dalam <= 0,3 detik (klik cepat)
#   hold    item dipegang "seconds" detik
#   hover   item dipegang di dalam "zone" selama "seconds" detik
#           (hanya terhitung saat tangan pelan)
#   put     item dilepas di dalam "zone"
#   release item dilepas di mana saja (otomatis kembali ke tempatnya)
#   pour    item dipegang di atas "zone", pelet jatuh tiap "interval"
#           detik. Selesai saat dilepas dengan pelet >= "limit".
#
# Opsi langkah:
#   strict  true = gerakan cepat mengulang hitungan dari nol
#   spill   penalti (%) tiap tangan bergerak cepat sambil membawa item
#   stay    item tetap di tempat setelah langkah selesai
#   toggle  item berganti tampilan (pintu buka/tutup) saat langkah selesai
#   hint    petunjuk singkat di panel quest
# ============================================================

const DEFS := {
	# ---------------------------------------------------------
	# KATEGORI A
	# ---------------------------------------------------------
	"water_plant": {
		"name": "Siram tanaman", "category": "A",
		"scene": "res://scenes/tasks/water_plant.tscn",
		"sound": 0.0, "deadline": 17.0, "no_deadline_days": [1], "penalty": 3.0,
		"steps": [
			{"type": "hover", "item": "WaterCan", "zone": "PotZone", "seconds": 5.0, "spill": 2.0,
				"hint": "Bawa kaleng ke pot PELAN, tahan di atas tanah"},
			{"type": "release", "item": "WaterCan",
				"hint": "Lepas kaleng"},
		],
	},
	"fish": {
		"name": "Beri makan ikan", "category": "A",
		"scene": "res://scenes/tasks/fish.tscn",
		"sound": 0.0, "deadline": 17.0, "penalty": 3.0,
		"steps": [
			{"type": "put", "item": "FishLid", "zone": "LidSpot", "stay": true,
				"hint": "Buka tutup pakan, taruh di samping"},
			{"type": "pour", "item": "FishCan", "zone": "AquariumZone",
				"interval": 0.8, "limit": 3, "overfeed_penalty": 3.0,
				"hint": "Tahan pakan di atas akuarium. Lepas setelah 3 pelet!"},
		],
	},
	"kettle": {
		"name": "Ketel", "category": "A",
		"scene": "res://scenes/tasks/kettle.tscn",
		"sound": 20.0, "penalty": 5.0,
		"steps": [
			{"type": "hold", "item": "Lever", "seconds": 2.0,
				"hint": "Condong jauh ke kiri (A), tahan tuas kompor"},
		],
	},
	"cat_bowl": {
		"name": "Mangkuk kucing", "category": "A",
		"scene": "res://scenes/tasks/cat_bowl.tscn",
		"sound": 0.0, "deadline": 21.5, "penalty": 3.0,
		"steps": [
			{"type": "hover", "item": "CatJar", "zone": "BowlZone", "seconds": 2.0, "spill": 2.0,
				"hint": "Bawa toples ke mangkuk di meja, tuang pelan"},
			{"type": "release", "item": "CatJar",
				"hint": "Kembalikan toples"},
		],
	},
	"vitamin": {
		"name": "Vitamin", "category": "A",
		"scene": "res://scenes/tasks/vitamin.tscn",
		"sound": 0.0, "deadline": 22.0, "penalty": 0.0,
		"items_from_day": {"Cabinet": 4},
		"steps": [
			{"type": "hover", "item": "Bottle", "zone": "GlassSpot", "seconds": 1.5,
				"hint": "Tuang pil: tahan botol di atas gelas"},
			{"type": "release", "item": "Bottle",
				"hint": "Kembalikan botol"},
			{"type": "hover", "item": "Glass", "zone": "MouthZone", "seconds": 1.5,
				"hint": "Minum: bawa gelas ke mulut"},
			{"type": "put", "item": "Glass", "zone": "TableZone",
				"hint": "Taruh gelas kembali di meja"},
		],
		# Day 4+: vitamin disimpan di lemari, jadi ada langkah buka dan tutup.
		"steps_by_day": {
			4: [
				{"type": "tap", "item": "Cabinet", "toggle": true,
					"hint": "Buka lemari obat (klik)"},
				{"type": "hover", "item": "Bottle", "zone": "GlassSpot", "seconds": 1.5,
					"hint": "Ambil vitamin, tuang pil di atas gelas"},
				{"type": "release", "item": "Bottle",
					"hint": "Kembalikan botol"},
				{"type": "tap", "item": "Cabinet", "toggle": true,
					"hint": "Tutup lemari (klik)"},
				{"type": "hover", "item": "Glass", "zone": "MouthZone", "seconds": 1.5,
					"hint": "Minum: bawa gelas ke mulut"},
				{"type": "put", "item": "Glass", "zone": "TableZone",
					"hint": "Taruh gelas kembali di meja"},
			],
		},
	},
	"lamp": {
		"name": "Matikan lampu", "category": "A",
		"scene": "res://scenes/tasks/lamp.tscn",
		"sound": 0.0, "penalty": 0.0,
		"steps": [
			{"type": "hold", "item": "Switch", "seconds": 2.0, "strict": true,
				"hint": "Tahan saklar lampu pelan-pelan..."},
		],
	},
	# ---------------------------------------------------------
	# KATEGORI B
	# ---------------------------------------------------------
	"alarm": {
		"name": "Alarm weker", "category": "B",
		"scene": "res://scenes/tasks/alarm.tscn",
		"sound": 15.0, "penalty": 5.0,
		"steps": [
			{"type": "hold", "item": "Alarm", "seconds": 2.0,
				"hint": "Angkat weker, tahan 2 detik"},
			{"type": "put", "item": "Alarm", "zone": "TableZone",
				"hint": "Taruh lagi di meja"},
		],
	},
	"phone": {
		"name": "Telepon", "category": "B",
		"scene": "res://scenes/tasks/phone.tscn",
		"sound": 12.0, "penalty": 5.0,
		"steps": [
			{"type": "hover", "item": "Handset", "zone": "EarZone", "seconds": 3.0, "strict": true,
				"hint": "Angkat gagang ke telinga, tahan 3 dtk tanpa gerak cepat"},
			{"type": "put", "item": "Handset", "zone": "CradleZone",
				"hint": "Taruh gagang kembali"},
		],
	},
	"microwave": {
		"name": "Microwave", "category": "B",
		"scene": "res://scenes/tasks/microwave.tscn",
		"sound": 15.0, "penalty": 5.0,
		"steps": [
			{"type": "tap", "item": "Door", "toggle": true,
				"hint": "Klik pintu untuk membuka"},
			{"type": "put", "item": "Bowl", "zone": "PlateZone", "stay": true, "spill": 2.0,
				"hint": "Ambil mangkuk, taruh di piring (jangan cepat)"},
			{"type": "tap", "item": "Door", "toggle": true,
				"hint": "Klik pintu untuk menutup"},
		],
	},
	"laptop": {
		"name": "Notifikasi laptop", "category": "B",
		"scene": "res://scenes/tasks/laptop.tscn",
		"sound": 12.0, "penalty": 3.0,
		"steps": [
			{"type": "tap", "item": "Notif",
				"hint": "Klik cepat notifikasi laptop"},
		],
	},
}

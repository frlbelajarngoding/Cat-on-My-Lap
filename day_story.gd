class_name DayStory
extends RefCounted
# ============================================================
# DAY STORY (Teks interlude antar hari)
# Kunci = hari yang BARU SELESAI. Ganti dengan naskah final.
# ============================================================

const INTERLUDES := {
	1: ["Hari 1 selesai.", "Kucingnya masih tidur.", "Obatnya sudah diminum."],
	2: ["Hari 2 selesai.", "Ada akuarium di sudut ruangan.", "Rasanya kemarin belum ada..."],
	3: ["Hari 3 selesai.", "Jam berdetak tidak sinkron.", "Hari ini... pernah terjadi?"],
	4: ["Hari 4 selesai.", "Ada suara yang tidak punya sumber.", "Tinggal satu hari lagi."],
}

static func interlude_for(day: int) -> PackedStringArray:
	return PackedStringArray(INTERLUDES.get(day, []))

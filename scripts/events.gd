extends Node

# Dipancarkan oleh Core Controller, didengarkan oleh Logic Meter Toleransi dkk.
@warning_ignore("unused_signal")
signal torso_moved(speed: float)               # px/detik, gerakan A/D
@warning_ignore("unused_signal")
signal hand_moved(speed: float)                # px/detik, kecepatan tangan (sudah dihaluskan)
@warning_ignore("unused_signal")
signal item_grabbed(item: Draggable)
@warning_ignore("unused_signal")
signal item_dropped(item: Draggable, impact_speed: float)

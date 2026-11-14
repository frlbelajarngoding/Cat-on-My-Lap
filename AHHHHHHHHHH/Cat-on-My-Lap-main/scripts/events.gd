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

# Dipancarkan oleh Cat (Logic Meter Toleransi & Kucing State).
@warning_ignore("unused_signal")
signal tolerance_changed(value: float, max_value: float)
@warning_ignore("unused_signal")
signal cat_state_changed(new_state: int, old_state: int)   # nilai enum Cat.State
@warning_ignore("unused_signal")
signal cat_woke_up
@warning_ignore("unused_signal")
signal cat_fell

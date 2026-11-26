extends Node

var bgm_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_CHANNELS := 8

var bgm_tracks := {
	1: preload("res://assets/audio/bgm/BGM_CatOnYourLap.ogg"),
	2: preload("res://assets/audio/bgm/BGM_CatOnYourLap-2.ogg"),
	3: preload("res://assets/audio/bgm/BGM_CatOnYourLap-3.ogg"),
	4: preload("res://assets/audio/bgm/BGM_CatOnYourLap-4.ogg"),
	5: preload("res://assets/audio/bgm/BGM_CatOnYourLap-5.ogg"),
}

var sfx_library := {
	"alarm": preload("res://assets/audio/sfx/Alarm.ogg"),
	"cat_purr": preload("res://assets/audio/sfx/cat.wav"),
	"cat_alert": preload("res://assets/audio/sfx/cat6.wav"),
	"click": preload("res://assets/audio/sfx/click.mp3"),
	"glitch": preload("res://assets/audio/sfx/glitch.mp3"),
	"glitch_heavy": preload("res://assets/audio/sfx/glitch2.mp3"),
	"lamp": preload("res://assets/audio/sfx/lamp.wav"),
	"move": preload("res://assets/audio/sfx/move.wav"),
	"water": preload("res://assets/audio/sfx/water.wav"),
}

func _ready() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	add_child(bgm_player)
	
	for i in range(MAX_SFX_CHANNELS):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_players.append(p)

func play_bgm_for_day(day: int) -> void:
	var track = bgm_tracks.get(clamp(day, 1, 5))
	if not track:
		return
	if bgm_player.stream != track:
		bgm_player.stream = track
		bgm_player.play()
	elif not bgm_player.playing:
		bgm_player.play()

func stop_bgm() -> void:
	bgm_player.stop()

func play_sfx(sfx_name: String, pitch_variance: float = 0.0, volume_db: float = 0.0) -> AudioStreamPlayer:
	if not sfx_library.has(sfx_name):
		return null
	for p in sfx_players:
		if not p.playing:
			p.stream = sfx_library[sfx_name]
			p.volume_db = volume_db
			p.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
			p.play()
			return p
	return null

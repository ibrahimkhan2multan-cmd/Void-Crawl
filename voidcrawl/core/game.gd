extends Node
## Autoload "VC": holds the player profile, the in-progress run, settings, audio and
## scene hand-off. Everything global lives here; gameplay scenes talk to this node.

signal profile_changed

const MENU_SCENE := "res://voidcrawl/scenes/main_menu.tscn"
const MISSION_SCENE := "res://voidcrawl/scenes/mission.tscn"

var profile: VCProfile
var run: Dictionary = {}          # in-progress dungeon state (see VCMission); empty if none
var pending: Dictionary = {}      # {"mission": id, "seed": int, "resume": bool} for the next mission scene

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cache: Dictionary = {}
var _music_players: Array[AudioStreamPlayer] = []
var _music_cache: Dictionary = {}
var _music_active := 0
var _current_music := ""
var _want_music := ""
var _audio_mutex := Mutex.new()
var _audio_task := -1
var _audio_ready := false
var play_audio := true            # tests turn this off
var autosave := true              # tests turn this off

const SFX_NAMES := ["swing", "hit", "crit", "hurt", "dodge", "coin", "pickup", "chest", "levelup", "enemy_die",
	"ability", "shoot", "enemy_shoot", "click", "back", "boss_roar", "heal", "door", "telegraph", "checkpoint",
	"victory", "defeat"]
const MUSIC_NAMES := ["menu", "dungeon", "boss"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(true)
	VCSettings.load_settings()
	VCSettings.apply(get_viewport())
	VCCrashGuard.on_start()
	_register_input()
	_setup_audio()
	var loaded := VCSave.load_save()
	if loaded.is_empty():
		profile = VCProfile.new_game()
		run = {}
	else:
		profile = loaded["profile"]
		run = loaded["run"]

# ---------------------------------------------------------------- input ---
func _register_input() -> void:
	var map := {
		"vc_attack": [KEY_J, KEY_Z],
		"vc_dodge": [KEY_K, KEY_X],
		"vc_ability": [KEY_L, KEY_C],
		"vc_heal": [KEY_H, KEY_Q],
		"vc_bomb": [KEY_B, KEY_V],
		"vc_sprint": [KEY_SHIFT],
		"vc_pause": [KEY_ESCAPE, KEY_P],
		"vc_inventory": [KEY_I, KEY_TAB],
		"vc_interact": [KEY_E, KEY_F],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_forward": [KEY_W, KEY_UP],
		"move_backward": [KEY_S, KEY_DOWN],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			if not InputMap.action_has_event(action, ev):
				InputMap.action_add_event(action, ev)

# ---------------------------------------------------------------- audio ---
func _setup_audio() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		m.volume_db = -80.0
		add_child(m)
		_music_players.append(m)
	# synthesise audio on a worker thread so the first frames are not delayed
	_audio_task = WorkerThreadPool.add_task(_synth_all, false, "voidcrawl audio synth")

func _synth_all() -> void:
	for n in SFX_NAMES:
		var s := VCAudioSynth.make_sfx(n)
		_audio_mutex.lock()
		_sfx_cache[n] = s
		_audio_mutex.unlock()
	for n in MUSIC_NAMES:
		var s := VCAudioSynth.make_music(n)
		_audio_mutex.lock()
		_music_cache[n] = s
		_audio_mutex.unlock()
	_audio_mutex.lock()
	_audio_ready = true
	_audio_mutex.unlock()

func _get_sfx(name: String) -> AudioStream:
	_audio_mutex.lock()
	var s: AudioStream = _sfx_cache.get(name)
	_audio_mutex.unlock()
	return s   # null until the worker has produced it; the sound is simply skipped

func play_sfx(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not play_audio:
		return
	var s := _get_sfx(name)
	if s == null:
		return
	for p in _sfx_players:
		if not p.playing:
			p.stream = s
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return
	# all busy: steal the first
	var q := _sfx_players[0]
	q.stream = s
	q.volume_db = volume_db
	q.pitch_scale = pitch
	q.play()

func play_music(kind: String) -> void:
	_want_music = kind

var _crumb_t := 0.0

func _process(_delta: float) -> void:
	_crumb_t -= _delta
	if _crumb_t <= 0.0 and autosave:
		_crumb_t = 2.0
		VCCrashGuard.crumb()
	if _delta > 0.75 and autosave:
		VCCrashGuard.crumb("HITCH %.2fs" % _delta)
	if _want_music != _current_music and _want_music != "" and play_audio:
		_audio_mutex.lock()
		var s: AudioStream = _music_cache.get(_want_music)
		_audio_mutex.unlock()
		if s != null:
			_crossfade_to(s)
			_current_music = _want_music

func _crossfade_to(s: AudioStream) -> void:
	var old := _music_players[_music_active]
	_music_active = 1 - _music_active
	var nw := _music_players[_music_active]
	nw.stream = s
	nw.volume_db = -60.0
	nw.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(nw, "volume_db", -6.0, 1.6)
	tw.tween_property(old, "volume_db", -60.0, 1.6)
	tw.chain().tween_callback(old.stop)

func stop_music() -> void:
	_want_music = ""
	_current_music = ""
	for m in _music_players:
		m.stop()

func vibrate(ms: int) -> void:
	if bool(VCSettings.get_value("haptics")) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)

# ---------------------------------------------------------------- state ---
func save_now() -> bool:
	return VCSave.save(profile, run)

func has_save() -> bool:
	return VCSave.exists()

func has_run_in_progress() -> bool:
	return not run.is_empty() and run.has("mission") and not bool(run.get("finished", false))

func new_game() -> void:
	profile = VCProfile.new_game()
	run = {}
	save_now()
	profile_changed.emit()

func notify_profile_changed() -> void:
	profile_changed.emit()

func start_mission(mission_id: String, seed_: int = 0, resume: bool = false, extra: Dictionary = {}) -> void:
	pending = {"mission": mission_id, "seed": seed_, "resume": resume}
	pending.merge(extra, true)
	if not resume:
		run = {}
	get_tree().paused = false
	get_tree().change_scene_to_file(MISSION_SCENE)

func goto_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		VCCrashGuard.mark_running(false)
		if profile != null and autosave:
			save_now()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		VCCrashGuard.mark_running(true)

class_name NPC extends CharacterBody2D

@export_range(0, 19) var npc_index: int = 0 # which row (vframe) to use, 0..19
@export var is_static: bool = true
@export_multiline var dialog_text: String = ""
@export var npc_name: String = "" # inspector-friendly name for debugging
enum Dir { DOWN, UP, RIGHT, LEFT }
@export var dir: Dir = Dir.DOWN
@export var path_length: float = 0.0 # pixels to move from origin and back
@export var speed: float = 32.0
@export var walk_frame_rate: float = 6.0

var sprite: Sprite2D = null
var origin: Vector2 = Vector2.ZERO
var travel_progress: float = 0.0
var travel_dir: int = 1
var walk_timer: float = 0.0
var _dialog_was_static: bool = false
var _in_dialog: bool = false
var _dialog_prev_dir: Dir = Dir.DOWN
var _dialog_prev_travel_dir: int = 1
var _dialog_prev_travel_progress: float = 0.0

# horizontal frame layout (same as player)
const HFRAMES: int = 10
const IDLE_DOWN_H: int = 0
const IDLE_UP_H: int = 1
const IDLE_RIGHT_H: int = 2
const WALK_DOWN_START_H: int = 4
const WALK_UP_START_H: int = 6
const WALK_RIGHT_START_H: int = 8
const WALK_FRAME_COUNT: int = 2

func _ready() -> void:
	origin = position

	# the scene uses a Sprite2D with the atlas (hframes=10, vframes=20)
	# so fetch it directly
	sprite = get_node("Sprite2D") as Sprite2D

	_apply_idle_frame()


func _process(delta: float) -> void:
	if is_static or path_length <= 0.0:
		# static: ensure idle frame
		_apply_idle_frame()
		return

	# move along chosen axis between origin and origin + path_length (ping-pong)
	var move_amount := speed * delta
	if dir == Dir.LEFT:
		position.x += -move_amount
	elif dir == Dir.RIGHT:
		position.x += move_amount
	elif dir == Dir.UP:
		position.y += -move_amount
	elif dir == Dir.DOWN:
		position.y += move_amount

	travel_progress += abs(move_amount)
	# reached end, flip direction
	if travel_progress >= path_length:
		travel_progress = 0.0
		match dir:
			Dir.LEFT:
				dir = Dir.RIGHT
			Dir.RIGHT:
				dir = Dir.LEFT
			Dir.UP:
				dir = Dir.DOWN
			Dir.DOWN:
				dir = Dir.UP

	# walking animation
	walk_timer += delta
	var t := int(walk_timer * walk_frame_rate) % WALK_FRAME_COUNT
	match dir:
		Dir.DOWN:
			_set_atlas_frame(npc_index, WALK_DOWN_START_H + t, false)
		Dir.UP:
			_set_atlas_frame(npc_index, WALK_UP_START_H + t, false)
		Dir.RIGHT:
			_set_atlas_frame(npc_index, WALK_RIGHT_START_H + t, false)
		Dir.LEFT:
			_set_atlas_frame(npc_index, WALK_RIGHT_START_H + t, true)


func _apply_idle_frame() -> void:
	# set idle frame according to dir
	match dir:
		Dir.DOWN:
			_set_atlas_frame(npc_index, IDLE_DOWN_H, false)
		Dir.UP:
			_set_atlas_frame(npc_index, IDLE_UP_H, false)
		Dir.RIGHT:
			_set_atlas_frame(npc_index, IDLE_RIGHT_H, false)
		Dir.LEFT:
			_set_atlas_frame(npc_index, IDLE_RIGHT_H, true)


func _set_atlas_frame(vframe: int, hframe: int, flip_h: bool) -> void:
	# Sprite2D with an AtlasTexture: frame = vframe * hframes + hframe
	var s := sprite as Sprite2D
	var frame_idx := vframe * HFRAMES + hframe
	s.frame = frame_idx
	s.flip_h = flip_h


func start_dialog_facing(player_pos: Vector2) -> void:
	# Make NPC temporarily static and face the player
	if _in_dialog:
		return
	# save previous movement/facing state
	_dialog_was_static = is_static
	_dialog_prev_dir = dir
	_dialog_prev_travel_dir = travel_dir
	_dialog_prev_travel_progress = travel_progress
	is_static = true
	# choose facing based on player relative position
	var d: Vector2 = player_pos - global_position
	if abs(d.x) > abs(d.y):
		dir = Dir.RIGHT if d.x > 0 else Dir.LEFT
	else:
		dir = Dir.DOWN if d.y > 0 else Dir.UP
	_in_dialog = true
	_apply_idle_frame()
	var display_name = npc_name
	if display_name == "":
		display_name = str(name)
	print("[NPC] %s start_dialog_facing: player_pos=%s, npc_pos=%s, facing=%s" % [display_name, str(player_pos), str(global_position), str(dir)])


func end_dialog() -> void:
	# restore previous movement/static state
	if not _in_dialog:
		return
	# restore saved state
	is_static = _dialog_was_static
	# restore previous facing and movement progress so NPC resumes where it left off
	dir = _dialog_prev_dir
	travel_dir = _dialog_prev_travel_dir
	travel_progress = _dialog_prev_travel_progress
	_in_dialog = false
	_apply_idle_frame()
	var display_name2 = npc_name
	if display_name2 == "":
		display_name2 = str(name)
	print("[NPC] %s end_dialog: restored is_static=%s" % [display_name2, str(is_static)])

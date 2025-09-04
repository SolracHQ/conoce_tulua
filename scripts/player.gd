class_name RPG2DPlayer extends CharacterBody2D

@export var move_speed: float = 100.0

var sprite: Node = null
var textbox: Node = null

enum Dir {DOWN, UP, RIGHT, LEFT}
var last_dir: Dir = Dir.DOWN
enum Axis {X, Y}
var last_input_axis: Axis = Axis.Y

var walk_timer: float = 0.0
const WALK_FRAME_RATE: float = 6.0 # how fast walking frames toggle

# Frame indices (atlas with hframes=10)
const TOTAL_FRAMES: int = 10

const IDLE_DOWN_FRAME: int = 0
const IDLE_UP_FRAME: int = 1
const IDLE_RIGHT_FRAME: int = 2

const WALK_DOWN_START: int = 4
const WALK_UP_START: int = 6
const WALK_RIGHT_START: int = 8
const WALK_FRAME_COUNT: int = 2

@export var talk_distance: float = 20.0 # pixels

var action_pressed_last: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# try common node names first, then find the first Sprite2D/AnimatedSprite2D child
	sprite = get_node_or_null("Sprite2D")
	if not sprite:
		printerr("[Player] Error: No Sprite2D child found")

	if sprite:
		_set_sprite(IDLE_DOWN_FRAME, false)

	# find Textbox child if present
	textbox = get_node_or_null("Textbox")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Read input, apply movement, update animation, then handle action
	var direction := _read_input()

	velocity = direction.normalized() * move_speed

	_update_animation(direction, delta)

	_handle_action()


func _read_input() -> Vector2:
	# Reads input into a direction vector and enforces single-axis movement.
	var direction := Vector2.ZERO
	# read horizontal input directly into direction
	if Input.is_action_pressed("right"):
		direction.x = 1
		last_input_axis = Axis.X
	elif Input.is_action_pressed("left"):
		direction.x = -1
		last_input_axis = Axis.X

	# read vertical input directly into direction
	if Input.is_action_pressed("down"):
		direction.y = 1
		last_input_axis = Axis.Y
	elif Input.is_action_pressed("up"):
		direction.y = -1
		last_input_axis = Axis.Y

	# enforce single-axis movement (retro RPG style). When both axes pressed,
	# prefer the last axis the player pressed.
	if direction.x != 0 and direction.y != 0:
		if last_input_axis == Axis.X:
			direction.y = 0
		else:
			direction.x = 0

	return direction


func _update_animation(direction: Vector2, delta: float) -> void:
	# Animation / facing logic
	if direction != Vector2.ZERO:
		# determine primary axis of movement
		var cur_dir: Dir
		if abs(direction.x) > abs(direction.y):
			cur_dir = Dir.RIGHT if direction.x > 0 else Dir.LEFT
		else:
			cur_dir = Dir.DOWN if direction.y > 0 else Dir.UP

		last_dir = cur_dir

		walk_timer += delta
		var frame_delta := int(walk_timer * WALK_FRAME_RATE) % WALK_FRAME_COUNT # 0..(WALK_FRAME_COUNT-1)

		match cur_dir:
			Dir.DOWN:
				_set_sprite(WALK_DOWN_START + frame_delta, false) # walking down
			Dir.UP:
				_set_sprite(WALK_UP_START + frame_delta, false) # walking up
			Dir.RIGHT:
				_set_sprite(WALK_RIGHT_START + frame_delta, false) # walking right
			Dir.LEFT:
				_set_sprite(WALK_RIGHT_START + frame_delta, true) # use right-walk frames flipped for left
	else:
		# idle: reset walk timer and use last known facing
		walk_timer = 0.0
		match last_dir:
			Dir.DOWN:
				_set_sprite(IDLE_DOWN_FRAME, false) # facing down (default)
			Dir.UP:
				_set_sprite(IDLE_UP_FRAME, false) # facing up
			Dir.RIGHT:
				_set_sprite(IDLE_RIGHT_FRAME, false) # facing right
			Dir.LEFT:
				_set_sprite(IDLE_RIGHT_FRAME, true) # facing left by flipping right frame


func _handle_action() -> void:
	# Handle action button for talking / textbox interaction
	var action_now := Input.is_action_pressed("action")
	if action_now and not action_pressed_last:
		if textbox and textbox.is_busy():
			textbox.advance_page()
		else:
			var facing_vec := Vector2.ZERO
			match last_dir:
				Dir.DOWN:
					facing_vec = Vector2(0, 1)
				Dir.UP:
					facing_vec = Vector2(0, -1)
				Dir.RIGHT:
					facing_vec = Vector2(1, 0)
				Dir.LEFT:
					facing_vec = Vector2(-1, 0)

			var space := get_tree().get_current_scene()
			if space:
				var best := _find_facing_npc(space, facing_vec)
				if best and textbox:
					# tell NPC to stop and face the player
					if best.has_method("start_dialog_facing"):
						best.call("start_dialog_facing", global_position)
					print("[Player] opening dialog for NPC=%s" % [str(best.name)])
					textbox.open(best)
				else:
					print("[Player] No NPC found to talk to")

	# store previous action state
	action_pressed_last = action_now


func _physics_process(_delta: float) -> void:
	move_and_slide()


func _set_sprite(frame: int, flip_h: bool) -> void:
	if not sprite:
		return

	# AnimatedSprite2D and Sprite2D both expose 'frame' and 'flip_h' in Godot 4.
	if sprite is AnimatedSprite2D:
		var a := sprite as AnimatedSprite2D
		a.frame = frame
		a.flip_h = flip_h
	elif sprite is Sprite2D:
		var s := sprite as Sprite2D
		# This scene uses an AtlasTexture with hframes=10, so Sprite2D.frame exists.
		s.frame = frame
		s.flip_h = flip_h


func _collect_npcs_recursive(node: Node) -> Array:
	var out := []
	# collect nodes that are NPCs (by class_name)
	if node is NPC:
		out.append(node)
	for c in node.get_children():
		out += _collect_npcs_recursive(c)
	return out


func _find_facing_npc(space: Node, facing_vec: Vector2) -> NPC:
	# gather NPCs and return the closest one in facing direction within talk_distance
	var candidates := []
	candidates += _collect_npcs_recursive(space)
	var best: Node = null
	var best_dist := 1e9
	for c in candidates:
		if c and c is NPC:
			var rel: Vector2 = c.global_position - global_position
			var d: float = rel.length()
			if d <= talk_distance and rel.normalized().dot(facing_vec) > 0.6:
				print("[Player] candidate NPC=%s dist=%.2f dot=%.2f" % [str(c.name), d, rel.normalized().dot(facing_vec)])
				if d < best_dist:
					best_dist = d
					best = c
	return best


func _get_npc_dialog(n: Node) -> String:
	if not n:
		return "..."
	# prefer typed access if the node is an NPC
	if n is NPC:
		var txt: String = str((n as NPC).dialog_text)
		if txt == "":
			return "..."
		return txt
	# fallback to property access
	if "dialog_text" in n:
		var t: String = str(n.get("dialog_text"))
		return t if t != "" else "..."
	return "..."

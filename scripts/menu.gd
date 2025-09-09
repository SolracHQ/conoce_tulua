extends Node

# Menu controller: toggles menu UI with the "menu" action, shows/hides
# the Credits scene when the Creditos button is pressed, and exits on Salir.

var credits_instance: Node = null
const CREDITS_PATH: String = "res://ui/Credits.tscn"

func _ready() -> void:
	# get nodes
	var center = $CenterContainer
	var credit_btn = $CenterContainer/VBoxContainer/creditos
	var salir_btn = $CenterContainer/VBoxContainer/salir

	# connect signals
	if credit_btn:
		credit_btn.connect("pressed", Callable(self, "_on_creditos_pressed"))
	else:
		printerr("[Menu] creditos button not found")

	if salir_btn:
		salir_btn.connect("pressed", Callable(self, "_on_salir_pressed"))
	else:
		printerr("[Menu] salir button not found")

	# start hidden by default (optional). If you prefer visible, change to 'true'.
	center.visible = false


func _process(_delta: float) -> void:
	# Toggle menu visibility when the player presses the 'menu' action.
	# If the menu is visible and the player presses movement or action,
	# hide the menu so the game effectively 'unpauses'.
	var center = $CenterContainer
	if center.visible and (Input.is_action_just_pressed("action") or Input.is_action_just_pressed("right") or Input.is_action_just_pressed("left") or Input.is_action_just_pressed("up") or Input.is_action_just_pressed("down")):
		print("[Menu] Hiding menu due to player input")
		center.visible = false
		if credits_instance:
			credits_instance.queue_free()
			credits_instance = null
		return

	# Assumption: an input action named "menu" exists in Project
	# Settings -> Input Map.
	if Input.is_action_just_pressed("menu"):
		print("[Menu] Toggling menu visibility")
		center.visible = not center.visible

		# when hiding the menu, also remove the credits scene if it's present
		if not center.visible and credits_instance:
			credits_instance.queue_free()
			credits_instance = null


func _on_creditos_pressed() -> void:
	# Toggle the Credits scene as a child of the current scene.
	if credits_instance:
		credits_instance.queue_free()
		credits_instance = null
		return

	var res = load(CREDITS_PATH)
	if not res:
		printerr("[Menu] Failed to load %s" % CREDITS_PATH)
		return

	credits_instance = res.instantiate()

	# Prefer adding the credits to the current scene root so a Node2D Credits node
	# is placed in the right canvas/layer. Fall back to adding as a child of this
	# menu node if there's no current scene.
	var root = get_tree().get_current_scene()
	if root:
		root.add_child(credits_instance)
	else:
		add_child(credits_instance)


func _on_salir_pressed() -> void:
	get_tree().quit()


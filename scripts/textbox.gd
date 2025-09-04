extends CanvasLayer

class_name Textbox

# Simple dialog textbox controller.
# Shows a RichTextLabel and paginates by visible lines (3 lines per page).

@export var lines_per_page: int = 2

var rlabel: RichTextLabel
var panel: Panel
var is_open: bool = false
var full_text: String = ""
var current_line: int = 0
var source_node: NPC = null

signal dialog_opened(source)
signal dialog_closed(source)

func _ready() -> void:
	# find children
	rlabel = $MarginContainer/MarginContainer/text as RichTextLabel
	panel = $MarginContainer/Panel as Panel
	if rlabel:
		rlabel.autowrap_mode = TextServer.AUTOWRAP_WORD
		rlabel.bbcode_enabled = false
	# hide at start
	visible = false

func open(source: NPC) -> void:
	# Only accept NPC nodes. If invalid input is provided, log and do nothing.
	if not source or not (source is NPC):
		printerr("[Textbox] open: expected NPC, got %s" % [str(source)])
		return

	# set source and dialog text
	source_node = source as NPC
	full_text = source_node.dialog_text if source_node.dialog_text != "" else "..."
	# assign to label and reset
	rlabel.text = full_text
	# force update so line counts are valid
	rlabel.queue_redraw()
	current_line = 0
	is_open = true
	visible = true
	emit_signal("dialog_opened", source_node)
	print("[Textbox] open: source=%s, full_text_len=%d" % [str(source_node), full_text.length()])
	_show_current_page()

func close() -> void:
	# call source cleanup if available
	if source_node and source_node.has_method("end_dialog"):
		source_node.call("end_dialog")
	emit_signal("dialog_closed", source_node)
	source_node = null
	is_open = false
	visible = false
	print("[Textbox] close: closed and notified source")

func _show_current_page() -> void:
	if not rlabel:
		return
	# ensure rlabel contains full text so wrapped lines are accurate
	rlabel.text = full_text
	rlabel.queue_redraw()
	var total_lines = rlabel.get_line_count()
	var start = current_line
	var end = min(total_lines - 1, start + lines_per_page - 1)
	# compute char range for start..end and set substring accordingly
	var lr_start = rlabel.get_line_range(start)
	var lr_end = rlabel.get_line_range(end)
	var first_idx = int(lr_start.x)
	# Treat lr_end.y as an exclusive index (end of range)
	var last_excl = int(lr_end.y)
	if first_idx < 0:
		first_idx = 0
	var total_chars = rlabel.get_total_character_count()
	if last_excl <= 0:
		# fallback to whole text (use exclusive end)
		last_excl = total_chars
	# clamp to total chars
	if last_excl > total_chars:
		last_excl = total_chars
	var count = last_excl - first_idx
	if count <= 0:
		# nothing for this page, show whole
		rlabel.visible_characters = -1
	else:
		# assign substring to maintain wrapping
		var s = full_text.substr(first_idx, count)
		rlabel.text = s
	var end_incl = max(0, last_excl - 1)
	print("[Textbox] _show_current_page: start=%d end=%d count=%d current_line=%d total_lines=%d" % [first_idx, end_incl, count, current_line, total_lines])

func advance_page() -> bool:
	# returns true if there are more pages, false if closed after last
	if not is_open:
		return false
	# recompute total lines on full text
	rlabel.text = full_text
	rlabel.queue_redraw()
	var total_lines = rlabel.get_line_count()
	current_line += lines_per_page
	if current_line >= total_lines:
		close()
		return false
	else:
		_show_current_page()
	print("[Textbox] advance_page: moved to current_line=%d" % current_line)
	return true

func is_busy() -> bool:
	return is_open

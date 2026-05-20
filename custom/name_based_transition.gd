@tool
class_name NameBasedTransition
extends Transition
## Automatically set Transition properties parsed from the name
## supported properties:
## - to 	-> to 				# must be a unique name in the state-chart
## - on 	-> event 			# the event; quoted: 'event name', or unquoted: `event_name`
## - after 	-> delay_in_seconds # a valid number optionally suffixed with `s` or `ms`
## e.g. A transition named "to Finished on 'queue_empty' after 200ms" yields
## - to: Finished
## - event: 'queue_empty'
## - delay_in_seconds: 0.2

static var _item_was_quoted := false

@export_tool_button("Name -> Properties") var apply_name = _apply_name_as_settings
@export_tool_button("Properties -> Name") var apply_props = _update_name_from_settings
@export var verbose: bool

var _parsed_name: String
var _parsed_props: Dictionary

@onready var state_chart := find_parent("StateChart")


static func trim_trailing_zeroes(num: String) -> String:
	# check for '00' but only trim '0' to keep the last zero
	while num.ends_with('00'):
		num = num.trim_suffix('0')
	return num


static func _parse_name(input: String) -> Dictionary:
	input = input.strip_edges()
	var props := { }
	var expect_key := true
	var current_key := ""
	while not input.is_empty():
		if expect_key:
			var key := _parse_key(input)
			if not key or key.is_empty():
				break
			input = input.trim_prefix(key).strip_edges()
			current_key = key
			expect_key = false
		else:
			_item_was_quoted = false
			var item := _parse_item(input)
			if not item or item.is_empty():
				CLog.e('no item for "%s" in "%s"' % [current_key, input])
				break
			var to_remove := len(item)
			if _item_was_quoted:
				to_remove += 2
			input = input.substr(to_remove).strip_edges()
			props[current_key] = item
			expect_key = true
	return props


static func _parse_key(input: String) -> String:
	if input.begins_with("to "):
		return "to"
	if input.begins_with("after "):
		return "after"
	if input.begins_with("on "):
		return "on"
	return ""


static func _parse_item(input: String) -> String:
	if input.begins_with("'"):
		_item_was_quoted = true
		return input.get_slice("'", 1)
	if input.begins_with('"'):
		_item_was_quoted = true
		return input.get_slice('"', 1)
	return input.get_slice(' ', 0)


func _ready():
	if not Engine.is_editor_hint():
		return
	if not self.guard:
		self.guard = NoGuard.new()


func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_PATH_RENAMED:
		_apply_name_as_settings(true)


func log_verbose(...args):
	if not verbose:
		return
	CLog.o.callv(args)


## TODO: integrate with editor undo/redo
func _update_name_from_settings():
	var items := PackedStringArray()
	var target := get_node_or_null(to)
	if target:
		items.push_back("to %s" % target.name)
	if not event.is_empty():
		items.push_back(
			"on '%s'" % event,
		)
	if delay_in_seconds != "0.0":
		items.push_back("after %fs" % float(delay_in_seconds))
	name = " ".join(items)


## TODO: integrate with editor undo/redo
func _apply_name_as_settings(check_previous := false):
	if not check_previous or name != _parsed_name:
		_parsed_props = _parse_name(name)
		_parsed_name = name
		log_verbose("parsed name: '%s' into props: %s" % [_parsed_name, _parsed_props])
	if not _parsed_props or _parsed_props.is_empty():
		return
	_apply_props(_parsed_props)


func _apply_props(props: Dictionary) -> void:
	if props.has("to"):
		_set_transition_path(props.to)
	else:
		self.to = self.property_get_revert("to")
	if props.has("on"):
		self.event = props.on
	else:
		self.event = ""
	if props.has("after"):
		_set_delay(props.after)
	else:
		self.delay_in_seconds = "0.0"
	property_list_changed.emit()


func _find_transition_target(root: Node, target_name: String) -> Node:
	var candidates := root.find_children(target_name)
	if candidates.is_empty():
		return null
	log_verbose("candidates:", candidates)
	var current := candidates[0]
	var shortest: int = get_path_to(candidates[0]).get_name_count()
	for i in range(1, len(candidates)):
		var length := get_path_to(candidates[i]).get_name_count()
		if shortest < length:
			continue
		shortest = length
		current = candidates[i]
	return current


func _set_transition_path(target_name: String):
	state_chart = state_chart if state_chart else find_parent("StateChart")
	if not state_chart:
		return
	var target := _find_transition_target(state_chart, target_name)
	if target:
		self.to = get_path_to(target)


func _set_delay(delay: String):
	if delay.ends_with("ms"):
		var num = float(delay.split("ms", false)[0])
		var dstr := "%f" % (num / 1000.0)
		self.delay_in_seconds = trim_trailing_zeroes(dstr)
	elif delay.ends_with("s"):
		var num = float(delay.split("ms", false)[0])
		var dstr := "%f" % num
		self.delay_in_seconds = trim_trailing_zeroes(dstr)
	else:
		self.delay_in_seconds = delay

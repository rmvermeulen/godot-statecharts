@tool
class_name NoGuard
extends Guard
## This guard lets anything pass, equivalent to null but explicit


## Returns true if the guard is satisfied, false otherwise.
func is_satisfied(_context_transition: Transition, _context_state: StateChartState) -> bool:
	return true


## Returns the triggers which should trigger the guard's evaluation.
## This is a bit mask of [StateChart.TriggerType].
func get_supported_trigger_types() -> int:
	const T = StateChart.TriggerType
	return T.EVENT | T.STATE_ENTER | T.STATE_CHANGE

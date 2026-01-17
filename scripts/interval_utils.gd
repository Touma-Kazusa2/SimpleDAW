extends RefCounted

static func merge_intervals(intervals: Array) -> Array:
	if intervals.is_empty():
		return []
	intervals.sort_custom(func(a, b): return a[0] < b[0])
	var merged: Array = []
	var current = intervals[0].duplicate()
	for i in range(1, intervals.size()):
		var next = intervals[i]
		if next[0] <= current[1]:
			current[1] = max(current[1], next[1])
		else:
			merged.append(current)
			current = next.duplicate()
	merged.append(current)
	return merged

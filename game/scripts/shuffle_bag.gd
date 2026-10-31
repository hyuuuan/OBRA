class_name ShuffleBag
extends RefCounted
## Which line of a pool to say next: the weighting thesis §4.5.4.4 specifies.
##
##   "High Priority: Unseen dialogue lines (Base weight +100).
##    Low Priority: Recently played lines (Weight drops to 0, slowly recovers over time).
##    Result: A player repeating Level 1 three times will hear Lolo tell three different
##    stories about the rice terraces."
##
## A line never heard weighs its base plus 100, so every unheard line comes before any heard
## one. A heard line drops to nothing the moment it is said and recovers in a straight line
## over the pool's later picks, reaching its full base after as many picks as the pool has
## lines -- so nothing repeats while anything fresher is waiting, and the oldest-heard line is
## the first to come back. The base is the line's authored priority plus one, so a priority-0
## line still counts.
##
## "Over time" is counted in later picks, not in hours (the team's choice, 2026-10-31): a
## player replaying back to back would otherwise hear the same few lines, and a count is
## deterministic, so the order can be tested. The counts live in the save (PlayerProfile
## note_pool_pick / picks_since), so they carry across sessions.
##
## ⚠ DETERMINISTIC, NOT RANDOM. The heaviest line wins, and ties go to the higher priority,
## then the earlier line in the file. The manuscript's own result -- three replays, three
## stories -- needs only the order; a die roll would let a replay hear the same line twice.

const UNSEEN_BONUS := 100.0


## A line's weight now. `heard` is how many times it has been said; `since` how many picks
## the pool has made since it was last said; `pool_size` the number of lines in the pool.
static func weight(priority: int, heard: int, since: int, pool_size: int) -> float:
	var base := float(priority + 1)
	if heard <= 0:
		return base + UNSEEN_BONUS
	return base * clampf(float(since) / float(maxi(pool_size, 1)), 0.0, 1.0)


## The index of the line to say, from `candidates` -- each {id, priority} -- with the save's
## record of what this pool has said. -1 for an empty pool.
static func pick(candidates: Array, pool: String, profile: Node) -> int:
	var best := -1
	var best_weight := -1.0
	var best_priority := 0
	for index in range(candidates.size()):
		var candidate: Dictionary = candidates[index]
		var id := String(candidate.get("id", ""))
		var priority := int(candidate.get("priority", 0))
		var heard := int(profile.call("dialogue_heard_count", id)) if profile != null else 0
		var since := int(profile.call("picks_since", pool, id)) if profile != null else 0
		var w := weight(priority, heard, since, candidates.size())
		if w > best_weight or (is_equal_approx(w, best_weight) and priority > best_priority):
			best = index
			best_weight = w
			best_priority = priority
	return best

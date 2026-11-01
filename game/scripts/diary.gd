class_name Diary
extends RefCounted
## Lola's diary: every entry the game hides, in the order she wrote them (config/diary.json), and
## which of them this player has found (the profile's `diary_pages`).
##
## WHY A DIARY AT ALL. Mayon is a painting coming apart because she is forgetting it, and a
## player who has only met her through four bright paintings arrives at the summit without the
## one fact that makes it land. One entry a painting, each a little further along, says it from
## her side and in her hand -- never with a name for what she has.
##
## ⚠ STATIC, NOT AN AUTOLOAD, for the reason Motion gives: autoload names do not compile in the
## scripts a `--script` probe loads up front. The profile is looked up on the tree at call time.

const PATH := "res://config/diary.json"

static var _entries: Array[Dictionary] = []


## Every entry, in the order she wrote them.
static func entries() -> Array[Dictionary]:
	if _entries.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			for entry: Variant in (parsed as Dictionary).get("entries", []):
				if entry is Dictionary:
					_entries.append(entry)
	return _entries


static func entry(entry_id: String) -> Dictionary:
	for found in entries():
		if String(found.get("id", "")) == entry_id:
			return found
	return {}


## The entries this player has found, in the order she wrote them -- not the order they were
## found in, so a page picked up out of turn still sits where it belongs in the book.
static func found() -> Array[Dictionary]:
	var profile := _profile()
	var out: Array[Dictionary] = []
	for each in entries():
		if profile != null and bool(profile.call(&"has_diary_page", String(each.get("id", "")))):
			out.append(each)
	return out


## A page's words, whichever way it was written down.
static func page_text(page: Variant) -> String:
	return String((page as Dictionary).get("text", "")) if page is Dictionary else String(page)


static func page_anchor(page: Variant) -> String:
	return String((page as Dictionary).get("anchor", "")) if page is Dictionary else ""


static func _profile() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(^"PlayerProfile")

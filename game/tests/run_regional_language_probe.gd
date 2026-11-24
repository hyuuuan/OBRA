extends SceneTree
## Every level has a line in its region's own language (cultural panel, Chapter 5 Table 34).
##
##	godot --headless --path game --script res://tests/run_regional_language_probe.gd
##
## The lines are data, so this reads the dialogue files and nothing else. A regional line is one
## carrying a `"lang"` code. For each level it holds:
##
##  * the level has one in ITS region's language -- Tuwali in Payyo, Cebuano in Piyesta, Waray in
##    Dagat, Tagalog in Dilim, Bikol in Mayon -- and at least one of them is lore, a story beat
##    everybody hears, not a hint only one route reaches (Dilim's "Tabi-tabi po" is a hint at the
##    nuno's mound, which is why Dilim has a second one);
##  * that line is glossed: its hook says more than the one line, so an English line follows --
##    or the line says its own meaning and is marked `"gloss": "inline"` ("Tabi-tabi po. Excuse
##    me -- I only need to pass.");
##  * every tagged line is in docs/REGIONAL_LINES.md exactly as shown, so the list the team
##    checks with speakers cannot drift from what the game says.

const CHECKS := 4
const LIST_PATH := "res://../docs/REGIONAL_LINES.md"
const LEVELS := {
	"res://config/dialogue_l1.json": "ifk",
	"res://config/dialogue_l2.json": "ceb",
	"res://config/dialogue_l3.json": "war",
	"res://config/dialogue_l4.json": "tgl",
	"res://config/dialogue_l5.json": "bcl",
}
## Every code a line may carry. `fil` is Filipino, the family's own, which the house speaks.
const KNOWN := ["ifk", "ceb", "war", "tgl", "bcl", "fil"]

var checked := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var list := FileAccess.get_file_as_string(LIST_PATH)
	var missing_level: Array[String] = []
	var unglossed: Array[String] = []
	var unlisted: Array[String] = []
	var unknown: Array[String] = []
	for path: String in LEVELS:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		var lines: Array = (parsed as Dictionary).get("lines", []) if parsed is Dictionary else []
		var per_hook := {}
		for line_value: Variant in lines:
			var hook := String((line_value as Dictionary).get("at", ""))
			per_hook[hook] = int(per_hook.get(hook, 0)) + 1
		var told_everyone := false
		for line_value: Variant in lines:
			var line: Dictionary = line_value
			if not line.has("lang"):
				continue
			var code := String(line["lang"])
			var id := String(line.get("id", "?"))
			if code not in KNOWN:
				unknown.append("%s (%s)" % [id, code])
			if not list.contains(String(line.get("text", ""))):
				unlisted.append(id)
			if int(per_hook.get(String(line.get("at", "")), 0)) < 2 \
					and String(line.get("gloss", "")) != "inline":
				unglossed.append(id)
			if code == String(LEVELS[path]) and String(line.get("kind", "")) == "lore":
				told_everyone = true
		if not told_everyone:
			missing_level.append("%s (%s)" % [path.get_file(), LEVELS[path]])
	_check(missing_level.is_empty(), "every level says a line in its own region's language",
		"Payyo, Piyesta, Dagat, Dilim, Mayon" if missing_level.is_empty()
		else "MISSING: %s" % ", ".join(missing_level))
	_check(unglossed.is_empty(), "and every regional line is followed by its meaning",
		"glossed" if unglossed.is_empty() else "ALONE: %s" % ", ".join(unglossed))
	_check(not list.is_empty() and unlisted.is_empty(), "every regional line is on the speakers' list",
		"docs/REGIONAL_LINES.md" if unlisted.is_empty() else "NOT LISTED: %s" % ", ".join(unlisted))
	_check(unknown.is_empty(), "and every one names a language the list knows",
		", ".join(KNOWN) if unknown.is_empty() else "UNKNOWN: %s" % ", ".join(unknown))
	if checked != CHECKS:
		failures += 1
		print("  FAIL\tevery check ran\t%d of %d" % [checked, CHECKS])
	if failures == 0:
		print("OBRA_REGIONAL_LANGUAGE_OK")
		quit(0)
	else:
		print("OBRA_REGIONAL_LANGUAGE_FAILED=%d" % failures)
		quit(1)


func _check(ok: bool, what: String, detail: String) -> void:
	checked += 1
	if not ok:
		failures += 1
	print("  %s\t%s\t%s" % ["OK" if ok else "FAIL", what, detail])

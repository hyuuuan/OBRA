class_name EndingResolver
extends RefCounted
## Resolves the player's accumulated profile into exactly one ending.
##
## The game design defines four endings driven by the routes the player took across
## the five levels combined with their telemetry (class diversity, redraw rate).
## Several conditions can hold at once, so the resolver is **total and deterministic**:
## it evaluates a fixed precedence order and always returns one ending.
##
## Precedence (first match wins), and why:
##   1. A — Masterpiece:      the most demanding ending; every condition must hold,
##                            so it can never be masked by a broader one below it.
##   2. B — Rushed Sketch:    its low-diversity condition is mutually exclusive with
##                            A's high-diversity one; ordered above C so a player who
##                            rushed *and* protected reads as the rush they committed to.
##   3. C — Protector:        route-only condition, broader than A and B.
##   4. D — Persevering:      the telemetry-only fallback for a player who kept
##                            redrawing without committing to a route.
##   5. D is also the default when nothing else matches, so the result is total.
##
## Static and pure: it reads a profile and returns data, touching no scene state, which
## keeps it directly testable.

const ENDING_A := "A_masterpiece"
const ENDING_B := "B_rushed_sketch"
const ENDING_C := "C_protectors_canvas"
const ENDING_D := "D_persevering_spirit"

const TITLES := {
	ENDING_A: "The Masterpiece",
	ENDING_B: "The Rushed Sketch",
	ENDING_C: "The Protector's Canvas",
	ENDING_D: "The Persevering Spirit",
}

## Thresholds from the game design; kept named so tuning is one edit.
const ROUTE_COMMITMENT := 3       # levels taken on one route to count as committed
const HIGH_DIVERSITY := 25        # classes drawn/accepted for the Masterpiece
const LOW_DIVERSITY := 10         # below this the player rushed
const HIGH_REDRAW_RATE := 0.4     # sustained redrawing without route commitment
const TOTAL_FLOWERS := 5          # hidden collectibles across the five levels


## Resolve from an explicit set of values. `profile` is the PlayerProfile autoload
## (or any object exposing the same API); pass it and nothing else in normal use.
static func resolve(profile) -> String:
	if profile == null:
		return ENDING_D
	return resolve_values(
		int(profile.route_count("artist")),
		int(profile.route_count("pragmatist")),
		int(profile.route_count("protector")),
		int(profile.class_diversity()),
		float(profile.redraw_rate()),
		int(profile.collectible_count())
	)


## The pure decision, separated so tests can drive it without building a profile.
static func resolve_values(
	artist: int,
	pragmatist: int,
	protector: int,
	class_diversity: int,
	redraw_rate: float,
	collectibles: int
) -> String:
	if artist >= ROUTE_COMMITMENT and collectibles >= TOTAL_FLOWERS and class_diversity > HIGH_DIVERSITY:
		return ENDING_A
	if pragmatist >= ROUTE_COMMITMENT and class_diversity < LOW_DIVERSITY:
		return ENDING_B
	if protector >= ROUTE_COMMITMENT:
		return ENDING_C
	if redraw_rate >= HIGH_REDRAW_RATE:
		return ENDING_D
	return ENDING_D  # total by construction: perseverance is the default reading


static func title_for(ending_id: String) -> String:
	return String(TITLES.get(ending_id, ending_id))


## Full explanation of a resolution — the inputs that produced it, for the ending
## screen and for telemetry.
static func explain(profile) -> Dictionary:
	if profile == null:
		return {"ending": ENDING_D, "title": title_for(ENDING_D)}
	var ending := resolve(profile)
	return {
		"ending": ending,
		"title": title_for(ending),
		"route_counts": profile.route_counts(),
		"class_diversity": profile.class_diversity(),
		"roster_size": profile.roster_size(),
		"redraw_rate": profile.redraw_rate(),
		"collectibles": profile.collectible_count(),
	}

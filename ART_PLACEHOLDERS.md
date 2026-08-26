# Placeholder art — everything in the world a developer drew in code

**What this is.** Every prop in Level 1 that has no art. Each one was drawn with rectangles,
circles and lines by a developer so the level could be built and tested, and each one is
waiting to be replaced. None of them is a design; they are stand-ins that hold the right
amount of space in the right place.

> **Updated 22 August.** Four of these are no longer placeholders. The atlas turned out to
> be a labelled tileset with most of it unreferenced — a thatch panel, bamboo wall panels,
> a plank door, a post-and-beam frame, a jar, a packed-earth path material and a full set
> of nine-way edge tiles. **The bale, the straw, the baul, and Lola's stool and jar are now
> built from those**, so they are the artist's own pixels rather than a developer's
> rectangles. Their entries below say what they are made of. Everything else on this list
> is still waiting.
>
> The walkable terraces also took the unused packed-earth path material, so the ground you
> stand on stops matching the painted scenery behind it.

**How to use it.** Every entry says what is there now, the exact space it occupies, what its
collision is, and — the part that matters — **what the player has to understand from looking
at it**. A replacement can look like anything as long as it still says that sentence. Where a
prop has states, all its states are listed: a route that leaves a mark on the world needs two
drawings of one object, not one.

**See them.** `godot --path game --script res://tests/run_visual_props.gd` writes one PNG per
prop to `/tmp/obra_prop_*.png`, cropped, with the HUD hidden. Re-run it any time.

**What is NOT on this list**, because it is already yours and is the style everything below
should match: `game/assets/Level1/` — the parallax layers, the texture atlas, the hut and
fence and plant sprites. The terraces and the stair are *composed* in code but take their
pixels from your atlas. Lolo is delivered art now too, tracked in `CONTENT_NEEDED.md` §2
with the rest of the character work.

**Four of the props below and the player character are DONE (2026-08-24)** — the stair
treads, the floating tread, the ruined bridge and the dead tree all draw delivered art now,
and the apo has the twenty-three-pose sheet. Their entries are kept because what each piece
has to COMMUNICATE has not changed, and that is what a redraw has to preserve. Everything
still marked as drawn in code is genuinely still drawn in code.

---

## Three rules that have already cost us

1. **Anchoring.** Terrain is **top-left anchored** — `position` is the upper-left corner.
   Props are **bottom-centre anchored** — `position` is where the thing meets the ground, and
   the art is built upward from y = 0. A prop that anchors differently from the thing it
   stands on has to have its height computed twice.
2. **Art that illustrates a gap must not fill it.** This level has now been defeated twice by
   its own art: once by treads that were centre-anchored, so every riser came out half a
   tread short and the whole stair became walkable, and once by broken stubs that were drawn
   at five times their intended size, so the player saw a complete flight of steps that could
   not be climbed. If a thing is supposed to be missing, it has to look missing.
3. **Nothing may imply an affordance it does not have.** The bulul carry no collision and no
   puzzle function, on purpose. If they are drawn as though they could be climbed or carried,
   players will try, and the refusal will read as a bug instead of as a boundary.

**If you deliver sprites rather than code**, hand back a PNG per prop at the sizes below (or a
clean multiple), plus the anchor point. Dropping a sprite in is a small change in one file per
prop — the file is named in each entry.

---

## Beat 0 — Ang Hagdan, the broken stair

The beat the whole tutorial rests on, and it is two problems in the order the player meets
them. **The paddy is 300 px of water** and the plank floating in it is the way over — set
something that rolls on it and it steadies, locks, and is a step. Then **the stair out of
the paddy is missing three stones**: the rise from the bank to the first surviving stone is
136 px against a 94 px jump, so they draw something to stand on.

### Stair treads · `game/scripts/stair_tread_2d.gd` · 5 in the scene

| | |
|---|---|
| **Now** | Cut stone from your atlas: a walking surface 14 px deep (`STONE_TOP`, region 828,343,84,86) over a riser (`STONE_WALL`, region 217,401,146,125). |
| **Sizes** | Two solid: **96 × 34** at (668, 452) and **64 × 28** at (700, 432). Three broken: **92 × 30**, **88 × 30**, **84 × 30** at (654, 486), (644, 518), (636, 548). |
| **Anchor** | Top-left. `position` is the upper-left corner; `tread_size.y` is how far the stone face drops below the surface you stand on. |
| **Collision** | The two solid ones only, exactly `tread_size`. The broken ones have **none**. |
| **Must read as** | Two surviving steps of a made stair, and three places where a step used to be. Two stones on their own read as two rocks; it is the stubs that make it a stair someone has to repair. |
| **Must not read as** | Five steps. A stub is currently a third of a tread wide, four fifths as tall, darkened to 46% — a scar, not a small ledge. Anything that looks standable invites a jump the player cannot make. |

### The floating tread · `game/scripts/floating_tread_2d.gd` · 1

| | |
|---|---|
| **Now** | **Two** of the missing stones, lodged together: the same stone cap texture twice at ±44, **176 × 22** in all, riding **mid-paddy at (490, 578)** — which leaves a 62 px hop of open water at each end. One tread alone was 88 px, and an 80 px weight standing on it left no deck to land on. |
| **Physics** | A real `RigidBody2D` — mass 2.4, gravity 0.35, angular damp 4, collision **176 × 20**. Loose it rocks and the player passes straight through it; with something that rolls resting on it, it steadies, levels, locks and rides at the waterline, and the weight **beds into the stone flush with the deck** so what you see of your drawing is the rest of it hanging underneath in the water. |
| **Z-order** | Stone at **6**, above `WorldItemRoot`'s **5**, so the drawing sits *into* the plank rather than over it — and `WorldItemRoot` is above the water's **3**, which is what makes a drawing in the paddy visible at all. |
| **Must read as** | One of the missing treads, floated off into the water. Loose, light, and obviously not fixed to anything. |
| **States** | Floating (free, rocks, 8 px awash) · settled (level, solid, deck 8 px proud of the water). **The settled state is the only crossing in Beat 0** and must read as somewhere to put your feet — this is the one prop in the level whose two states the player has to be able to tell apart at a glance. |

---

## Node 1 — the gorge

### Ruined bridge · `game/scripts/ruined_bridge_2d.gd` · 1 at (2400, 240)

| | |
|---|---|
| **Now** | Two leaning posts 96 px tall, 13 px thick, each braced; a frayed rope from each that sags out over the drop and simply stops, at 22% of the 560 px span; two surviving planks (26 × 7) hanging off the near rope. Colours: rope `#8C6B42`, wood `#57402B`, dark `#241A12`. |
| **Collision** | **None.** The whole point is that it does not hold anyone up. |
| **Must read as** | The bridge Lola painted, and what is left of it. It should read left to right as a sentence: a post, rope going out, rope stopping in mid-air — which is the question the dialogue then asks aloud. |

### Dead tree · `game/scripts/dead_tree_2d.gd` · 1 at (2360, 240)

| | |
|---|---|
| **Now** | A plain brown trunk **54 × 300** with a 4 px outline, three bare branches, three grain lines. Felled, it becomes a span **250 × 34** lying across the gorge with eight cross-planks. |
| **Collision** | Standing: the trunk. Felled: a walkable span. It is the Protector route's bridge — chopping it is not clearing an obstacle, it is building the path. |
| **Must read as** | Dead, and big enough to reach across. Bare, not a post. Two states: standing, and fallen into a crossing. |

### Crumbling ledges · `game/scripts/collapsing_platform_2d.gd` · 2 at (2700, 232) and (2890, 232)

| | |
|---|---|
| **Now** | A slab **220 × 34**, centre-anchored, fill `#70614A` with a 3 px dark outline and three cracks. |
| **Behaviour** | 0.85 s of grace after the first footfall, a 3 px shake, then it drops. It does **not** kill — the player loses the climb back, not the run. |
| **Must read as** | Already going. The shake is the warning, but the cracks have to say it before anyone stands on it. |

### Hidden Flower 1 · `game/scripts/hidden_flower_2d.gd` · 1 at (2700, 596), in the cave

| | |
|---|---|
| **Now** | Five circles of radius 7 around a 5.5 radius heart, an 18 px stem, bobbing ±3 px. About **32 × 40**, or 48 across counting the glow. Lit: petals `#FAB8D1`, heart `#FFDB59`, plus a soft glow. Unlit: grey-violet at 55% alpha. |
| **States** | **Bud** (behind a gate wanting a concept from Level 4 — present, plainly not ready) and **lit** (takeable). Both are needed; the difference is the whole reason to come back. |
| **Note** | The same flower design will be reused for Flowers 2–5 in later levels. |

---

## Node 2 — Ang Dayami, the straw

### Straw piles · `game/scripts/straw_pile_2d.gd` · 3 at (3026, 240), (3180, 240), (3296, 240)

**DELIVERED ART.** `level-1-assets/Haybale.png`, keyed off its white page and cut down by
`tools/build_art.py`. Two goes at drawing straw in code came and went first — one fanned
thin diagonal lines out of a crown and read as scratches, one built it from axis-aligned
columns and read as a shaded dome with scratches on it.

| | |
|---|---|
| **Now** | `haybale.png` **208 × 144**, and `haybale_solid.png` beside it — the same picture with the doorway filled by mirroring the straw from the far side of the heap over it, feathered over 30px so the join cannot show. |
| **Sizes** | **208 × 144** at 3180 (1:1 with the art), **104 × 72** at 3026 and 3296 (exactly half, so the pixels stay square). The right-hand one is mirrored so the two smalls are not one sprite printed twice. |
| **One picture, four states** | **Intact** and **combed** draw the solid cut, combed at 0.92 × 0.88. **Tunnelled** draws the cut WITH the mouth — the hole is the tunnel. **Scattered** is still drawn in code: there is no picture of a heap pulled apart, and a heap is a silhouette while scattered straw is a scatter. |
| **The way in** | Read off the art rather than typed here: the mouth is x 292–570 of a source that crops to 22–1004, and y 414–748 of one that crops to 71–748, so `mouth_rect()` is those fractions of whatever size the heap is given. Moving the doorway means redrawing the heap. |
| **Collision** | **None**, deliberately — a solid heap would wall off the only route out of the level. |
| **Must read as** | **Cut straw, never harvested grain.** A build constraint, not a preference: the Protector route scatters it across the terrace, and scattering somebody's *tinawon* harvest is not a neutral image to stage. |

### Inside the heap · `game/scripts/straw_room_2d.gd` · 1 at (1900, −900)

**BUILT, NOT PAINTED — and it took three goes.** A cutaway of the heap read as a close-up of
a haystack. Kent's delivered interior, tiled across the room, read as "a mere drawing". What
was missing both times is that a room is *made*: it has courses, joints, a lintel over the
door and a floor laid in bands. `hub_room.gd` is that argument already won once, so this is
the same argument in straw.

| | |
|---|---|
| **The ruler** | The apo, exactly as in the house: 96px for a child of about 1.30 m puts a **metre at 72 px**, and every number carries the metres it came from. A four-metre wall because that is a barn. A doorway one metre by two. A chest at knee height. |
| **Seen at 2**, like the house | The level is drawn at 1 because it is a valley; a room is somewhere you stand in, so the camera comes in until the room fills the frame and the apo is a fifth of its height. The camera is **pinned at the room's eye level** rather than following her, or the framing slides as she walks. |
| **The wall** | **Thatch on a frame.** A first cut stacked bound *bales* in a running bond, and however much the tone and grain varied, the eye found the boxes before the material — crisp rectangles are right for timber and wrong for straw. So: vertical straw in **clumps** (a run of strands shares a tone and a length), held by horizontal **split-bamboo binding poles** at four heights plus a sill, with nodes and lashings. The structure comes from the frame; the material stays soft. |
| **Lit from the door** | The straw falls a value darker past 62% of the room's length. It is the only thing in here saying the far end is further away — there is nowhere else for light to come from inside a heap. |
| **The floor** | Trodden earth in courses, the way the boards in the house are: bands a shade apart, a hairline joint, grit and wisps of straw walked into it, and the doorway's light spilling across it. |
| **The way out** | An opening with a **pole lintel** over it — a hole with nothing over it reads as damage, not a door — and the valley beyond as three bands: sky, the terrace behind, the earth she is standing on. |
| **Drawn 480 units past the walls she can reach** | The camera sees 400 either side at this zoom and she can walk to the end wall, so a room drawn only as far as it is walkable puts its own edge on screen with the level's sky behind it. Safe to be generous **because the room is not drawn at all while she is somewhere else** — left switched on it painted the whole valley, which is what "the map in the overworld is still black at some parts" was. |
| **In it** | Lola's canvas (the hub's own `level_2.png`, in the stepped gilt the pictures in the house wear, hung with a shadow under it), the **baul**, a **brass key** on the floor, and the **ants**. |

### The ants · `game/scripts/straw_ants_2d.gd` · 5 on the floor of the room

| | |
|---|---|
| **Now** | Drawn and animated in code from `level-1-assets/ant pixel art.webp`. ⚠ **That file is a watermarked stock image** — it is a reference to work from, not an asset to ship. The shape, the three-segment body and the two oranges (`#D1671B`, `#BD4B2F`) are its; the walk is not. |
| **The walk** | A tripod gait — front and back leg on one side swinging with the middle leg on the other, which is what an insect does and what stops six legs paddling in unison. The body only bobs a pixel; the legs are the walk. |
| **Their own node** | So the room does not repaint to animate them: the walls are a couple of thousand units of tiled art, and redrawing all of it sixty times a second to move six legs would be the smallest thing on screen costing the most. |
| **Scenery, and nothing else** | No collision, nothing reads their position, and drawing an ant on the canvas does not make one appear here. |

### The baul · `game/scripts/baul_2d.gd` · 1 at (3238, 240), inside the heap, hidden until found

| | |
|---|---|
| **Now** | **The plank door sprite** (region 910,1001,44,61) scaled to **74 × 52** — boards, a rail top and bottom, a round fitting on the face — with a small brass padlock on the lid line. It was a mud-wall rectangle with two painted bars. Rises into place and fades in when uncovered. |
| **Must read as** | Lola's chest: small, banded, and **locked**. "Locked. Of course." is the line that closes the beat, and the padlock is the whole of Node 3's Pragmatist route — the player will be drawing a key against it. |
| **Declared liberty** | An Ifugao house had no locks. This one is hers, carried up from the lowlands, and the padlock came with it. That is recorded in the build spec rather than smuggled past, so the chest should look like a lowland trunk, not local joinery. |

### Lola's stool and brush jar · inline in `level_1_environment.tscn` · at (2990, 240) and (3014, 240)

**BUILT** — both are sprites from the atlas's small-props row now: a low bamboo bench
(region 1045,1028,70,34 at 0.7 scale) and a bamboo vessel (region 903,917,27,39). They were
two flat polygons of solid brown. No collision. Pure set-dressing, and the only sign that
somebody worked this terrace — which is worth more than their size suggests.

---

## Node 3 — Ang Bale, the house

**The architecture is the puzzle.** Every route answers a real feature of the building, so
each feature below has to be legible or its route stops making sense.

### The bale · `game/scripts/bale_2d.gd` · 1 at (3500, 200)

| Part | Now | Must read as |
|---|---|---|
| Four posts | 16 × 96, at x −102, −34, +34, +102 | The house standing clear of the ground |
| **Halipan** (rat guards) | 46 × 12 discs at y −69, **solid**, wider than the post | The reason "climb the post" is not an answer. A real thing, not a fiction: a disc a rat cannot get past, and neither can a climber |
| Deck | 240 × 22 at y −96 | The floor, out of reach |
| Thatch | A 278 × 92 pyramid from y −118 | The way in, if you can get onto it |
| Attic | A 168 × 55 volume under the roof | The granary the Artist route climbs into, entered **under the eaves** at (+101, −137), never through the door |

**BUILT — no longer a placeholder.** It has walls and a door now, from the atlas's
hut-accent row: a storey of bamboo slats between the deck and the roof with one plank door
in it, and a real thatch roof with a bamboo ridge pole instead of a triangle of rice
terrace. The walls are solid, which is what makes going over the thatch and in under the
eaves the Artist route rather than one of two ways in.

Still a developer's: the four **halipan** discs, which have no source anywhere in the atlas
and are flat trapezoids. They carry the whole reason "climb the post" is not an answer, so
they are the piece of this building most worth drawing properly.

### The bulul · `game/scripts/bulul_2d.gd` · 2 at (3452, 200) and (3496, 200)

| | |
|---|---|
| **Now** | A seated figure about **30 × 51**, arms on knees, in three flat browns on a 30 × 6 base. |
| **Collision** | **ZERO. Zero interaction, zero puzzle function.** It cannot be climbed, pushed, picked up, chopped, drawn on, or required by anything. This is enforced in code and asserted three ways in the audit. |
| **Must read as** | A rice-granary guardian figure, carved and kept by a family. **The most carefully rendered thing in the scene, doing nothing.** That contrast is deliberate and it is the strictest rule in the level: treating a bulul as a collectible or a lever is the exact failure this project has to avoid. |
| **The only thing they do** | Come within 96 px and Lolo says, once: *"Do not. Those are not decoration, and they are not yours."* A refusal, not a hint. Nothing unlocks. |

---

## Terrain and water — composed from your atlas, not invented

Listed so nothing looks forgotten. `terrace_segment_2d.gd` (16 pieces) and `water_area_2d.gd`
(2 pools) tile your own regions; they are not placeholder art, but their proportions are set
in code — a terrace's surface band is 60 px deep and its retaining wall fills the rest of
`segment_size`. If the atlas gains a dedicated dry-straw or timber region, three props above
would rather use it than borrow the rice and mud tiles they use today.

---

## Where to start

1. **The bulul** — small, the one with the least room for error, and the only prop here
   that should stay bespoke rather than be assembled out of tileset parts.
2. **The halipan** — the four rat guards on the bale's posts, still flat trapezoids. They
   carry the whole reason "climb the post" is not an answer.
3. **The gorge set** — the ruined bridge, the dead tree and the crumbling ledges are all
   still drawn from primitives, and the atlas has nothing close to any of them.
4. **The stair and its three stubs** — composed from terrace tiles rather than drawn as a
   stair. It works, but Beat 0 is the first thing a player meets and its whole read is
   "three of these are gone".
5. Hidden Flower 1, then the two characters (tracked in `CONTENT_NEEDED.md` §2).

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
| **In it** | The **baul** at (2076, −900), a **brass key on a nail** at local (−40, −250) — out of reach on purpose, which is the room's whole puzzle — and the **ants**. ⚠ Lola's canvas is NOT in here and has not been since the chain became heap → key → house → painting; it hangs in Ang Bale's interior. |

### The ants · `game/scripts/straw_ants_2d.gd` · 5 on the floor of the room

| | |
|---|---|
| **Now** | Drawn and animated in code from `level-1-assets/ant pixel art.webp`. ⚠ **That file is a watermarked stock image** — it is a reference to work from, not an asset to ship. The shape, the three-segment body and the two oranges (`#D1671B`, `#BD4B2F`) are its; the walk is not. |
| **The walk** | A tripod gait — front and back leg on one side swinging with the middle leg on the other, which is what an insect does and what stops six legs paddling in unison. The body only bobs a pixel; the legs are the walk. |
| **Their own node** | So the room does not repaint to animate them: the walls are a couple of thousand units of tiled art, and redrawing all of it sixty times a second to move six legs would be the smallest thing on screen costing the most. |
| **Scenery, and nothing else** | No collision, nothing reads their position, and drawing an ant on the canvas does not make one appear here. |

### The baul · `game/scripts/baul_2d.gd` · 1 at (2076, −900), inside the straw room, inside the heap, hidden until found

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

### The bale · `game/scripts/bale_2d.gd` · 1 at (3630, 80)

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

**The painted ladder is its own layer (2026-11-01).** The house draws `hut_house.png`, which is
`hut.png` with its ladder lifted off and the wall and deck behind it put back; the ladder is
`props/hut_ladder.png`, the level's `OldLadder` sprite, so it can fade as Payyo's old way up.
Both are cut from `hut.png` by `tools/build_payyo_ladder.py` (`--check` verifies them). A
redelivered hut is re-split by that one command, and the ladder's corner it prints must match
the `OldLadder` position in `level_1_environment.tscn`.

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

## Dagat — what is painted, and the three things that are not

**Updated 21 September.** Level 3's art arrived as 79 files and is in: three parallax bands
(the shore by day, the same sea under a storm, the deep), coral and kelp that sway, bubbles,
fish schools, and the bakunawa itself in 23 poses. `tools/build_dagat.py` cuts the delivery
into `game/assets/Level3/` and **fails if any delivered file is left unused**.

One prop is **authored rather than delivered**: the ink jar on the seabed
(`tools/build_dagat_props.py`). The underwater plate has those jars painted into it — pale
glass, dark cap, blue drop — but they do not ship as a sprite, and the refills were purple
diamonds. (Redrawn 28 September as a glass jar with the ink inside it: it had been a flat white
card.) Drawn in this project's own 8-bit idiom through `pixelart.py`, at `PX = 3` because
at the library's default of 2 it reads as a different game's prop beside art drawn this fine.
It lives in `assets/Level3/authored/` so the generated pipeline cannot delete it.

**Also authored (22 September, redrawn 28 September): the land under the water** —
`land_home.png` and `land_island.png`, same tool, same idiom. The sand plate stops 150 pixels
under the walking surface and the sea goes down a thousand more, and the delivery has no land
seen from the side, so the beach floated over the ruins. It was a tiled wall of dark blocks with a
separate face and a dithered sand lip, which read as a black cobbled wall; each beach is now one
painting of a heap of boulders, darkening with depth, whose seaward edge is where its own stones
stop, with the sand plate's own pixels carried round the sand's shoulder. **A good candidate for
the art team to replace**: the contract is one picture per beach, starting four pixels above the
walking surface (world y 556, plate row 786 in the shore band) and running past the lowest the
camera looks (1867), with its rock edge on the land's collision edge (x 1000 at home, 4500 at the
island), set down from the home ground's west end (x 100) and to the island ground's east end
(x 5380). Both are rows in `DagatBackdrop2D.BANDS`, not the scene.

**And the seabed itself (28 September)**: `seabed_floor.png`, a strip that tiles on its own, the
floor everything on the bed stands on, and `terraces_far.png`, the delivered terraces hazed into
the water and set behind it. The contract for a painted replacement of the floor is its walking
row: `DagatBackdrop2D.SEABED_TOP_ROW + SEABED_WALK` must land on the collision's 1709, and
`run_level3_audit` reads the texture at that row.

**And the small lives** (same tool): gull (4 frames), jelly (4), starfish (2), clam (3), urchin
(2), foam (3), splash (3), wake (3), bubble (2), spark (4). All replaceable by name — a painted
set with the same prefixes and frame counts drops straight in, since `DagatLife2D` and
`DagatProp2D` find frames by prefix.

**And the old jetty (1 November)**, same tool: `jetty.png`, a bamboo pier on the bangka's own
wood and lashing, slats gone and its far end broken off. It is the old way out to sea that fades
as she comes down the beach (`OldJetty`, see LEVEL_3.md). Under its waterline row its posts take
the sea's colour and dither out, because the sea plate is behind it, not over it. Replaceable by
name; a redraw keeps its waterline at row 9 of 46 (×3), which the scene pins to the surface.

**And the bangka (23 September)**, same tool: `bangka_afloat.png` and `bangka_beached.png`.
It is **the one object in the game that is found rather than drawn**, so it is the one that
cannot get its picture from the player's ink — it wore the engine's bare outline, a white
wireframe trapezium, for the whole of the crossing the Artist route is named about.
`level_3.gd._dress_the_bangka` hides the stroke visual and hangs the picture where the ink
was; the strokes themselves are kept, so the collision, the draft, the buoyancy and the seat
are still the numbers `run_level3_boat_probe` measured. ⚠ The ink is **not** under
`DrawingSkin`: for `rig_type "none"` RuntimeRig2D hangs its `SkinRoot` off the RigidBody2D
itself, and hiding the skin node alone leaves the outline drawn over the picture.

**The brush is no longer a placeholder either** — the pickup on the sand is
`assets/hud/brush_full.png`, regioned to its ink and scaled down. It is the same tool the ink
panel carries for the rest of the run, and two pictures of one tool are two things to keep in
step.

**Nothing in Dagat is a developer's rectangle any more (27 September).** The last three, and one
the design listed without naming it, are authored in the same tool and idiom:

| What | Where | How it is drawn | What it has to say |
|---|---|---|---|
| **What the bakunawa had lost** | Where the light leads it, on the Artist route | A page of Lola's diary (2026-11-01, `DIARY.md`): the loose page, `game/assets/hud/diary_page.png`, drawn at 3×. Rises out of the sand on the dive; from the boat it comes up beside the bow, where the apo can see it; fought, it goes off in the creature's coils. (`painting_fragment.png`, the torn canvas corner it replaced, is still built and no longer shown.) | Something the player recognises -- the design asks for "an object from Level 1's house, or a piece of the painting", never a chest. The flower comes up out of it to the apo, and the card says which of the five it is |
| **The next painting** | The island, where the landing sparkles | `NextPainting2D`: the house's own painting for the next level, in the house's gilt -- `Painting2D.draw_gilt` is the one moulding for both -- standing in `sand_mound.png`, glinting on the gold | The thing they crossed the sea for. Scenery, not a door: the level ends on the arrival and the next level is chosen from the house |
| **Lolo's farewell** | The island, after his last line | His own `wave` pose (the design: "reuse the existing wave pose rather than authoring a new one"), then he lifts and thins out -- `Lolo.farewell()`. The level ends only once he has gone | He stops here. Painting first, farewell second, then cut |
| **The paddle** | In the apo's hands, aboard the bangka | `paddle.png`, the hull's own wood. It strokes -- forward, in with a splash, back along the hull, lifted round -- while the boat moves, and rests across the lap when it does not | The apo is rowing. The sheet has no seated pose, and a boat sliding under a figure standing with its arms at its sides reads as a boat being dragged |

**Still open, for the art team rather than for code:** a grieving or turned-away Lolo for the
death reveal, and a dedicated fade for his exit (the design lists both as NEW poses; the wave
and a code fade stand in). And the bakunawa's design lists more states than were delivered: its
attack and hurt play the thrashing clip (hurt is a white flash on it), and calm and subdued play
the searching clip slowed down, subdued tinted grey.

**The sweep cone is not on this list and must not be.** It is drawn in code because it *is*
the stealth rule — the thing `sees()` answers about — and a boundary the player cannot see is
one they learn by being put back. Art may restyle it; it may not replace it with lighting.

## Dilim — what is painted, what is authored, and what is drawn in code

**Updated 1 November.** Level 4's delivery (`Mt Makiling Level 4.zip`) is forest plates and a
labelled tileset and no creature art. The art team has since sent three creatures
(`Creatures.zip`): **the kapre, the manananggal and a white lady**, who is the lean aswang.
Two more sheets supplied on 1 November replace the old/hulking aswang (`aswang_pig`) and
the tikbalang. Every other creature is a developer's: sculpted pixel strips, not code-drawn
bodies, but still stand-ins for an artist's. **See them all at once:**
`godot -t --resolution 1600x900 --path game --script res://tests/run_visual_dilim_creatures.gd`
writes each one beside her, in her light at play framing, to `/tmp/obra_dilim_*.png` and a sheet.
That is the right way to judge them -- Dilim is dark, and a body that reads on a grey background
can vanish in the level.

**Painted (delivered):** the six Makiling plates and four seamless tiles, cut by
`tools/build_dilim.py` (`CONTENT_NEEDED.md` §3 has what is not cut yet).

**Supplied character art:** five character sheets kept as sent in
`LEVEL4_Creatures/ASWANG/` (`kapre.png`, `manananggal.png`, `whitelady.png`, `aswang.png`, `tikbalang.png`), cut by
`tools/build_dilim_delivered.py` into the strips below of the same names: the poses keyed off their
panel, their shadows, labels and the manananggal's legs taken off, each creature scaled once, the
left-facing poses mirrored. No sheet draws a death, so a death is its pose fading out. The white
lady is `aswang_dog_*`; the supplied crawling aswang is `aswang_pig_*`.

**Authored in the project's idiom** (replaceable by name, no code change):

| What | Tool | Files | The contract |
|---|---|---|---|
| Every creature but the five supplied, the kapre's balete, smoke and cigar, and the finale's dead tree | `tools/build_dilim_creatures.py`, on `tools/creature_sculpt.py` (the bodies in `dilim_beasts.py`, `dilim_giants.py`, `dilim_kapre.py`, `dilim_fliers.py`, `dilim_small.py`; the dead tree in `dilim_props.py`) | `assets/Level4/creatures/<kind>_<anim>.png` | A row of square frames, as tall as wide; a strip whose width is not a whole number of its height is one picture (the mound, the tree). Ground kinds stand on the bottom row, fliers are centred -- that point is the creature's position. Chibi like the apo, cel-lit from the upper left, each part edged in a darker tone of its own colour, never black. Each script's own `_draw()` stays as the fallback while a strip is missing |
| Lola's six things | `tools/build_dilim_props.py` | `assets/Level4/props/<id>.png` | 32-px icons, each on a leaf, each told apart by its brightest colour: salt, ash, garlic, candle, lamp oil, the stingray-tail whip. The quick slots and the pickups load them by id |

**The creatures' strips, and what each has to say** -- a delivered strip of the same name replaces
one with no code change:

| Kind | Strips | What it has to say |
|---|---|---|
| Aswang, the lean one and the old one | `aswang_dog_*`, `aswang_pig_*` (the names they had as a dog and a pig): `idle` `run` `windup` `attack` `hurt` `death` | **The lean one is delivered:** the art team's white lady -- long black hair over a pale face, red eyes, a white kimono bloodied at the hem and sleeves -- idle and floating, gliding on her walk cycle, her hair flung out wide in the windup, reaching to strike, her head thrown back when hit. The crawler is also supplied (`aswang.png`, 1 November): pale skin, long black hair, red eyes, a long red tongue and dark waist rags. Its four breathing poses, six rightward walk frames, claw anticipation and three strike poses, and two hurt poses are cut from the sheet; the left-facing hurt is mirrored, and death fades a hurt pose. The animator mirrors all animations to face the player. Both read inside her light (#93) |
| Santelmo | `santelmo_idle`, `santelmo_hot` | A flame that wants her: brighter while it is coming |
| The nuno's mound | `nuno_mound_idle` (one picture) | An earth mound with something left for the nuno -- a thing to be respectful round, never a target |
| Sigbin | `sigbin_*`: the six states | Goat-like, long ears hanging, walking backwards. It shows only as much as the light on it, so in the dark it is a glint -- the windup's glint is its tell, and must stay |
| Tikbalang | **Supplied:** `tikbalang_idle`, `tikbalang_run`, cut from `tikbalang.png` (1 November) | Horse-headed, brown-skinned, long black mane, red eye, black waist cloth and hooves. Four breathing poses while it waits and four running poses during the race. Original colours and dark mane are preserved; spaces between its limbs remain transparent. Stands about 140 px tall, matching its previous scale. |
| Kapre | **Delivered:** `kapre_idle`, `kapre_knocked`, `kapre_falling`, `kapre_walk`. Sculpted: its tree `kapre_tree_idle`, `kapre_tree_felled` (one picture each); `kapre_smoke_idle`; `kapre_cigar_idle` (one picture) | The art team's kapre: small, green-skinned, long grey hair and beard, a hide over one shoulder -- its sheet's "small in form, but still strangely imposing", stood half again her height -- standing on a branch of a balete (a strangler fig, its trunk a lattice of roots) beside the trunk, facing her, its cigar seen end on in its teeth and its face lit by the ember; angry when the cigar is knocked from its mouth, startled looking up as its tree goes under it, then walking off. Drawn in the tree's own frame: the strip's feet stand at `Kapre2D.ART_AT`; the drawn cigar's tip is `CIGAR_TIP`, where its hit area and the ember's own light are; its lips are `FACE_LIGHT_FROM`, where the light on its face starts -- a redrawn kapre keeps all three, or moves them with it (`tools/build_dilim_delivered.py` `KAPRE_*`; `tests/test_build_dilim_delivered.py` holds them together, checks its feet are on the branch, and measures how much of the backdrop's sky the lights show over the drawn tree and kapre). The smoke is six puffs, `PUFF` px square: four billows, a middling and a small one. The cigar alone is the one that falls when it is knocked. The tree lies felled once it is chopped down |
| Tiyanak | `tiyanak_idle`, `tiyanak_true`, `tiyanak_run`; its undergrowth `tiyanak_undergrowth_idle` (one picture, the 480-px span plus 4 px at the sides and top, and 200 px under the ground over the drop, `Tiyanak2D.ART_BELOW`) | A swaddled bundle that cries -- and, lit, what it is: small, hunched, red-eyed. Its undergrowth -- leaf masses, broad leaves and arching fronds over a ground cover solid the whole way, and over the drop a thicket hanging 200 px down past the rim, fading into the dark, so in her light the drop is more bushes and not a hole -- stirs when it cries, and thins once a light has shown what is under it |
| Bungisngis | `bungisngis_*`: the six states, `laugh`, `aside` | A one-eyed giant with a club, always grinning, standing in the crossing like a wall; laughing helpless; sat aside |
| Manananggal | **Delivered:** `manananggal_upper_*`: the six states; `manananggal_lower_idle`, `manananggal_lower_death` | The art team's: a pale, rosy-cheeked girl's upper body in purple, long grey hair, on wide red bat wings -- flapping as it hunts from above, arms out to menace in its windup, diving with a slash of red, recoiling when hit -- severed at the waist, a drip of blood under it; and its legs, purple and white-booted, left standing apart in a hollow |
| Wakwak | `wakwak_*`: the six states | A great dark bird, wings wide, a hooked beak |
| Tik-tik | `tiktik_*`: the six states | A small dark long-beaked bird -- seen only with ash on it, so it carries the ash's grey |
| The finale's dead tree | `dead_tree_idle` (260 x 336), `dead_tree_felled` (380 x 140), one picture each; `DeadTree2D.art_kind = "dead_tree"` in the last clearing | Dead long since, in the balete's bark bleached grey: strands twisted round a dark heart, bark torn off, a hollow at its foot, bare crooked limbs. Felled, a log the length of the 280-px span with its root plate torn up at the west end, its top along the log's 64 px. Drawn among the creatures (`DeadTree2D.DRAWN_Z`), so the walkers meeting it at its root plate are in front of it, not hidden in it. Level 1's dead tree is the delivered one and is untouched |

**Drawn in code** -- each its script's own `_draw()`, marked `PLACEHOLDER` there:

| What | Script | What it has to say |
|---|---|---|
| The night's things | `candle_flame_2d.gd`, `asin_throw_2d.gd`, `abo_dust_2d.gd`, `bawang_ward_2d.gd`, `whip_lash_2d.gd` | A candle stub and flame; salt grains in flight; ash spreading and thinning; a pale ring of garlic on the ground; the whip's arc |
| Her lantern | `held_lantern_2d.gd` | A small iron lantern whose flame shrinks with each stage -- it is her health |
| Her hurt and attack poses | `wanderer_figure.gd` | Hurt: the jump frame leaning back from a blow. Attack: the wave frame's raised arm leaning into a swing, for 0.25 s after every blade swing, in every level |

**Not on this list, and must not be:** the **edge ripple** (`EdgeRipple`) and the **windup glint**
(`Telegraph2D`). The ripple is how a sound is seen -- the design's rule that every audio cue has a
visual, and how a player who cannot hear plays the level -- and the glint is the fair warning
before every strike. Like Dagat's sweep cone, art may restyle them; it may not take them away.
The darkness itself (`DarknessLayer`) is gameplay too: `LightField` decides what is lit.

## Lola's diary (every level)

| | Now | Where | Replace with |
|---|---|---|---|
| **A loose page of her diary** | A 14 × 18 folded sheet with her lines on it, drawn pixel by pixel in the diary book's own five colours, shown at 2×, a little askew and bobbing. It has to say: *a page of a diary, dropped here, worth picking up*. | `game/assets/hud/diary_page.png` (`tools/build_diary_book.py`, `PAGE`), `game/scripts/diary_page_2d.gd` | A hand-drawn loose page of the same book; keep its foot at the bottom edge. |

| **Lolo in her paintings** | Kent's own sheets of him alive (`game/assets/characters/lolo/source/LOLO1-5.png`, not imported), the FRONT pose cut and brought down to 18 px, standing in each painting's foreground -- young in Payyo, old in Mayon. At that size his eyes are lost. | `game/assets/hub/paintings/level_N_lolo.png` (`tools/build_house_lolo.py`), hung by `HouseEpilogue` once Mayon is done | A painter's figure of him drawn into each picture at its scale; keep it on the same foreground spot (`SPOTS`). |
| **Lola walking** | Her side-on "turn" pose, flipped and stepping two pixels every quarter second -- there is no walk cycle. | `Lola2D.walk_to` | A walk cycle with the same foot registration as her other poses. |
| **The empty easel** | Drawn in code: three legs and a bare canvas at the house's scale (96 × 56). | `HouseEpilogue._draw_easel` | An easel sprite, its canvas bare; she paints at its left. |

The book itself (`game/assets/hud/diary_book.png`) is not a placeholder: it is the delivered page
turn from `HUD-assets-ideas/Book-Inventory-Animation.gif`, with its tabs keyed out.

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

## Level 5 (Mayon)

Everything below plays end to end and is replaceable by name. The delivered Mayon art (sky,
volcano, meadow, ground, bell tower, tileset) is used as delivered; these are what it did not
include.

| | Now | Where | Replace with |
|---|---|---|---|
| **Lola** | Dedicated generated painting, turning, flower, returning, and seated poses; a separately cut and outlined portrait. | `game/assets/Level5/people/lola_*.png` (`tools/build_mayon_performance.py`) | Art-directed same-name poses with the same foot registration. |
| **The real room** | **Removed** (2026-11-01): the run ends in the house (`HouseEpilogue`), and `frame_return.gd` went with #182. The room, and Lola's and the apo's seated and pickup poses, are no longer cut into the game; the generated original stays in `LEVEL5_Mayon/authored/frame_room.png`. | -- | Nothing, unless the room comes back. |
| **The apo's performance** | Generated raise, paint, failed, lower and offer poses. Quiet strokes fade over the actual scene. | `game/assets/Level5/people/apo_*.png`, `level_5.gd` | Art-directed poses or animation preserving actor scale and feet. |
| **Memory fragments** | Torn boxes of the finished paintings; the flower's is a scrap of path tile with Payyo's hidden flower. | `game/assets/Level5/fragments/` (`tools/build_mayon_fragments.py`) | Hand-torn fragments; the flower's should look like nothing. |
| **The summit** | Near-white cone and ground; transparent scenery from earlier levels blooms in save order with the player's actual strokes. | `game/assets/Level5/restoration/`, `level_5.gd`, `memory_bloom_2d.gd` | Twelve purpose-drawn, ground-registered restored landscapes. |
| **The old bridge, the old steps** | Dedicated generated rope bridge and eroded basalt stairs, with shader white/blank states. | `game/assets/Level5/props/old_crossing.png`, `old_steps.png` | Art-directed same-size sprites, preserving their walk-line registration. |
| **Sound** | None: Mayon is silent (the synthesized audio was removed 2026-11-01). No recorded Lola voice. | `game/config/audio.json` hooks `mayon_brush`, `mayon_ending` (no file) | Directed recordings or instrumentation, if sound is wanted again; the audit then needs its silence check changed. |


### Mayon overhaul 31 October 2026

Lola is no longer an apo recolour, the room is a painted backdrop, and the apo now raises, attempts, lowers, offers, sits,
and picks up the ordinary brush. Their generated original atlases, prompts, runtime cuts, and
replacement contracts are catalogued in `LEVEL5_Mayon/authored/README.md`.

**Still provisional:** the generated Lola/apo performances, Lola portrait, and room await human
art-direction review, along with the upper-slope plate, three cliff materials, crossing, steps,
column and arch; memory targets are procedural torn crops, and summit scenery reuses earlier
levels' transparent art; weather, brush, and ending audio are synthesized;
there is no recorded Lola voice. No missing artwork prevents finishing the level.

Mayon visual repair (31 October, after user review): restored the earlier detailed grass/cliff
opening treatment; removed the flat polygon backing and straight grass outline. The stacked
memory walls were removed in favour of a shallow climb with overhead fragments. The flower
retains detached one-way rocks. This pass adds no new provisional image or audio sources.

Mayon dedicated edge artwork (31 October): `LEVEL5_Mayon/authored/cliff_edges.png` adds three
new generated end-cap textures, cut into `game/assets/Level5/terrain/edge_meadow.png`,
`edge_basalt.png`, and `edge_ash.png`. These replace the procedural cap outlines and warped
join meshes. They are integrated, preserve alpha, and follow the terrain's whitening/tint.
They join the generated-art review inventory; provenance, prompt, and replacement registration
are in `LEVEL5_Mayon/authored/README.md` and `cliff_edges.prompt.txt`.

Mayon scenery (1 November): generated broadleaf trees, coconut pair and bare snag, plus two
transparent foothill/forest panoramas. Originals are `LEVEL5_Mayon/authored/foothill_trees.png`
and `parallax_ridges.png`; runtime cuts live under `game/assets/Level5/props/` and `backdrop/`.
These join the generated-art review inventory. Exact prompts and replacement registrations
are in `scenery.prompts.json` and the authored README. The scene adds twelve decorative tree
placements; the existing vista owns the new parallax, treeline fade, and summit whitening.

Mayon wind (1 November): `LEVEL5_Mayon/authored/wind_streaks.png` supplies three generated
pixel-art gusts, four frames each. The logical atlas is
`game/assets/Level5/weather/wind_streaks.png`; the full generation/revision prompts and
replacement registration are in the authored README and `wind_streaks.prompts.json`.
These are generated provisional sprites, with no glow or softened pixel edges.

Mayon upper-slope dressing (1 November): `LEVEL5_Mayon/authored/upper_ruins.png` adds six
generated pixel-art props: broken wall, pillar, fallen masonry, boulder, loose rubble and
basalt spires. Runtime cuts are under `game/assets/Level5/props/`, with twenty decorative
placements behind the path. The group whitens at the summit. These join the generated-art
review inventory; the exact prompt and replacement contract are in `upper_ruins.prompt.json`
and the authored README.

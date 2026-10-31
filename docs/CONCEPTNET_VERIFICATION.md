# The ability table, checked against ConceptNet 5.7.0

2026-10-31. Tool: `tools/verify_abilities_conceptnet.py`. Raw results: `docs/conceptnet_verification.json`.
**The ability table was not changed.** How to re-ground it is the team's decision; the
options are at the end.

## The answer, in short

The ability table's 47 ConceptNet entries were built while the ConceptNet API was down.
They are labelled `conceptnet_curated`, described as "documented assertions with approximate
weights". Checked against the full ConceptNet 5.7.0 assertions dump (34 million edges), they
fall into three groups:

| Group | Count | Classes |
|---|---|---|
| **The exact assertion exists** | **13** | bird, bat, butterfly, fish, shark, scorpion, cloud, sun, stairs, key, door, scissors, tree |
| Not as written, but a **close paraphrase** exists | 12 | frog, snake, axe, sword, cannon, fan, ladder, bridge, bucket, umbrella, bread, wheel |
| **No supporting edge** with that meaning | 22 | spider, monkey, octopus, crab, horse, elephant, sea turtle, snail, ant, bee, pig, penguin, boomerang, flashlight, campfire, parachute, hot air balloon, sailboat, submarine, rake, clock, anvil |

Even the 13 that exist **do not carry their curated weights**. For example, bird → fly is
2.83 in ConceptNet, not 6.0, and fish → swim is 2.0, not 6.32. Some curated weights appear to
be borrowed from other edges: ladder's 5.29 is stairs → *climbing*.

**What this means for the thesis.** The manuscript, the appeal letter and the table's own
notes describe these entries as ConceptNet assertions. **That holds for 13 of 47 as written,
for about 25 if close paraphrases count, and never for the curated weights.** The appeal
letter promised the weights would be verified before the final defense; this is that check.

## How it was checked

- **Source:** `conceptnet-assertions-5.7.0.csv.gz`, the release the manuscript's Table 7 cites,
  streamed once (about 50 s).
- **Match:** for each entry, the scan looks for its (start, relation, end) among English
  edges. Parts of speech are ignored, so *climb/v* counts as *climb*.
- **Rank:** it also reports where the edge ranks among that concept's edges on the same
  relation, and the top edge.
- **Close paraphrases:** an end that is the same word in another form (climb / climbing), or a
  phrase built on it (*cross* / *crossing river*), is listed as a close paraphrase for a person
  to judge. It is **never** counted as found.

## Every entry

| Class | Curated assertion | Curated weight | In ConceptNet 5.7.0 | Top edge on that relation |
|---|---|---|---|---|
| bird | bird CapableOf fly | 6.0 | **in 5.7**, weight 2.83, rank 5 of 36 | sing (6.63) |
| bat | bat CapableOf fly | 2.83 | **in 5.7**, weight 1.00, rank 3 of 5 | strike ball (4.47) |
| butterfly | butterfly CapableOf fly | 3.46 | **in 5.7**, weight 2.00, rank 1 of 4 | fly (2.00) |
| spider | spider CapableOf climb | 2.83 | not in 5.7; no close edge | spin webs (2.83) |
| monkey | monkey CapableOf climb | 3.46 | not in 5.7; no close edge | attempt to climb tree (1.00) |
| frog | frog CapableOf jump | 3.46 | not in 5.7; close: *jump in pond* (1.00), *jump into air* (1.00), *jump very high* (1.00) | leap (2.00) |
| fish | fish CapableOf swim | 6.32 | **in 5.7**, weight 2.00, rank 4 of 26 | live underwater (4.00) |
| shark | shark CapableOf swim | 2.83 | **in 5.7**, weight 1.00, rank 2 of 2 | circle swimmer (1.00) |
| octopus | octopus CapableOf swim | 2.0 | not in 5.7; no close edge (no edges on this relation at all) | — |
| crab | crab CapableOf pinch | 2.0 | not in 5.7; no close edge | live on wet rocks (1.00) |
| horse | horse CapableOf gallop | 2.83 | not in 5.7; no close edge | pull cart (3.46) |
| elephant | elephant CapableOf stomp | 2.0 | not in 5.7; no close edge | carry trunk (1.00) |
| snake | snake CapableOf slither | 2.83 | not in 5.7; close: *slither down street* (1.00) | eat egg (1.00) |
| sea_turtle | sea turtle CapableOf swim | 2.83 | not in 5.7; no close edge (no edges on this relation at all) | — |
| snail | snail CapableOf crawl | 2.0 | not in 5.7; no close edge (no edges on this relation at all) | — |
| ant | ant CapableOf carry | 2.83 | not in 5.7; no close edge | build colony (1.00) |
| bee | bee CapableOf pollinate | 2.0 | not in 5.7; no close edge | sting (2.00) |
| pig | pig CapableOf dig | 2.0 | not in 5.7; no close edge | find truffle (2.00) |
| penguin | penguin CapableOf slide | 2.0 | not in 5.7; no close edge (no edges on this relation at all) | — |
| scorpion | scorpion CapableOf sting | 2.83 | **in 5.7**, weight 1.00, rank 1 of 1 | sting (1.00) |
| axe | axe UsedFor chop | 4.0 | not in 5.7; close: *chop wood for building fires* (1.00) | chop wood for building fires (1.00) |
| sword | sword UsedFor cut | 2.83 | not in 5.7; close: *cut off hand* (1.00), *cutting* (1.00) | killing (4.47) |
| cannon | cannon UsedFor shoot | 2.0 | not in 5.7; close: *shoot cannon ball* (3.46), *shooting cannonballs* (3.46), *shoot cannonballs* (2.00) | shoot cannon ball (3.46) |
| boomerang | boomerang UsedFor throw | 2.83 | not in 5.7; no close edge (no edges on this relation at all) | — |
| flashlight | flashlight UsedFor light | 2.83 | not in 5.7; no close edge | seeing in dark (2.00) |
| campfire | campfire UsedFor warm | 2.0 | not in 5.7; no close edge (no edges on this relation at all) | — |
| cloud | cloud UsedFor rain | 1.0 | **in 5.7**, weight 2.00, rank 2 of 30 | bringing rain (2.00) |
| sun | sun UsedFor heat | 1.0 | **in 5.7**, weight 2.83, rank 3 of 29 | light (4.00) |
| fan | fan UsedFor cool | 3.0 | not in 5.7; close: *cool off* (6.00), *cool people down* (2.00), *cooling air* (2.00) | cool off (6.00) |
| ladder | ladder UsedFor climb | 5.29 | not in 5.7; close: *climbing walls* (2.00), *climbing to higher level* (1.00), *climbing tree* (1.00) | painting ceiling (2.83) |
| stairs | stairs UsedFor climb | 3.0 | **in 5.7**, weight 1.00, rank 3 of 17 | climbing (5.29) |
| parachute | parachute UsedFor glide | 2.0 | not in 5.7; no close edge (no edges on this relation at all) | — |
| hot_air_balloon | hot air balloon UsedFor float | 1.0 | not in 5.7; no close edge (no edges on this relation at all) | — |
| bridge | bridge UsedFor cross | 4.0 | not in 5.7; close: *crossing river* (4.00), *cross bay* (3.46), *cross over body of water* (3.46) | crossing river (4.00) |
| sailboat | sailboat UsedFor sail | 2.0 | not in 5.7; no close edge | get to presidio (1.00) |
| submarine | submarine UsedFor dive | 2.0 | not in 5.7; no close edge (no edges on this relation at all) | — |
| key | key UsedFor unlock | 5.29 | **in 5.7**, weight 2.00, rank 16 of 34 | open lock (6.00) |
| door | door UsedFor enter | 3.0 | **in 5.7**, weight 1.00, rank 5 of 22 | separating rooms (2.00) |
| rake | rake UsedFor gather | 3.0 | not in 5.7; no close edge (no edges on this relation at all) | — |
| scissors | scissors UsedFor cut | 5.29 | **in 5.7**, weight 5.66, rank 1 of 12 | cut (5.66) |
| clock | clock UsedFor tell time | 4.0 | not in 5.7; no close edge | keeping time (2.83) |
| anvil | anvil UsedFor forge | 2.0 | not in 5.7; no close edge | stun cartoon character (1.00) |
| bucket | bucket UsedFor carry | 3.0 | not in 5.7; close: *carrying liquids* (4.47), *carry water* (2.83), *carry dirt* (1.00) | carrying liquids (4.47) |
| umbrella | umbrella UsedFor shelter | 3.46 | not in 5.7; close: *shelter from rain* (2.83) | protection from rain (4.47) |
| tree | tree UsedFor shade | 2.0 | **in 5.7**, weight 3.46, rank 1 of 32 | shade (3.46) |
| bread | bread UsedFor feed | 2.0 | not in 5.7; close: *feeding to birds* (1.00) | eating (5.66) |
| wheel | wheel UsedFor roll | 2.83 | not in 5.7; close: *rolling* (2.83) | rolling (2.83) |

## What to do about it (the team's call)

1. **Re-ground by requirement first, weight second.** This is the manuscript's own stated method
   (§3.2.6, §4.2.8). For each class, pick the 5.7.0 edge that best supports the in-game ability,
   and record its real weight and URI. Many classes have a usable edge under a different end:
   - flashlight → *seeing in dark* (2.0)
   - clock → *keeping time* (2.83)
   - bridge → *crossing river* (4.0)
   - fan → *cool off* (6.0)
   - bucket → *carry water* (2.83)
   - umbrella → *shelter from rain* (2.83)

   Classes with no supporting edge become **hand-authored**, stated as such. This keeps every
   ability in the game unchanged and makes every provenance claim true. It needs a person to
   judge each paraphrase.
2. **Keep the abilities, relabel the provenance.** Mark 13 entries as verified, with their
   real weights, and the other 34 as design-authored. This is simpler, but it weakens the
   thesis's ConceptNet claim considerably.
3. **Rebuild automatically from the top edge.** This is what `tools/build_abilities.py` does
   when the API answers. **Not recommended:** the top edges are often unplayable (bird → *sing*,
   bat → *strike ball*, horse → *pull cart*). The manuscript itself argues against
   weight-first selection.

Whichever option is chosen, the manuscript's Section 4.2.8 and Tables 7–9 must report the
verified counts, not the curated ones. `docs/MANUSCRIPT_REVISIONS.md` gives the wording.

## Reproducing it

```
curl -LO https://s3.amazonaws.com/conceptnet/downloads/2019/edges/conceptnet-assertions-5.7.0.csv.gz
python tools/verify_abilities_conceptnet.py --dump conceptnet-assertions-5.7.0.csv.gz --out docs/conceptnet_verification.json
```

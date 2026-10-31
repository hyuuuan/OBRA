"""Build O.B.R.A.'s ability table from the manuscript's Appendix C, verified against ConceptNet 5.7.0.

WHERE THE ABILITIES COME FROM. The thesis (Sections 3.2.6-3.2.7, 4.2.8; Appendix C, titled
"Appendix D" on its own page) attributes abilities to the 50 classes through six
affordance-bearing relations -- CapableOf, UsedFor, HasProperty, HasA, ReceivesAction,
MannerOf -- plus a guarded IsA traversal, selected by game requirement first and assertion
weight second. The table below is that appendix, transcribed row by row: 117 abilities over
49 classes, in the appendix's own modes (Direct 84, Property 8, Part 9, Action 7, Inherited
9), with its bold primaries. Penguin is hand-authored, as the appendix says.

ONE CHANGE FROM THE APPENDIX. The appendix still lists mushroom (hand-authored); the game
replaced it with bread (LEVEL_2.md). Bread is grounded the appendix's way, requirement first:
Piyesta asks it to feed the birds, and ConceptNet has bread -UsedFor-> feeding_to_birds. So
49 of 50 classes are grounded and only penguin is hand-authored.

⚠ THIS REPLACED A CURATED STAND-IN. The old table (one CapableOf/UsedFor verb per class,
"documented assertions with approximate weights", built while api.conceptnet.io was down)
was checked against the 5.7.0 dump on 2026-10-31: 13 of its 47 assertions existed as written
and none carried its curated weight (docs/CONCEPTNET_VERIFICATION.md). Every edge below was
checked against the same dump: all exist, with these weights.

Each row: (class, label, mode, [link, ...]); a link is
(start, relation, end, weight, ConceptNet's own sentence, assertion URI). An Inherited row has
two links (start -IsA-> parent, parent -Rel-> end); its weight is the parent assertion's,
per the appendix's note. Rake's MannerOf edge prints no weight in the appendix; 2.0 is the
dump's, on the verb sense ("to rake is a way to gather").

    python tools/build_abilities.py                 # write game/config/abilities.json
    python tools/build_abilities.py --check         # non-zero if the committed file differs
    python tools/build_abilities.py --dump conceptnet-assertions-5.7.0.csv.gz
                                                    # re-verify every edge against the dump
"""

from __future__ import annotations

import argparse
import gzip
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT))

from shared.entities import DEFAULT_ABILITIES_PATH, load_entities  # noqa: E402

HAND_AUTHORED = {
    "penguin": ("Slide", "Hand-authored: a penguin slides on its belly across ice (no usable "
                "ConceptNet assertion at any depth; guarded from inheriting a bird's flight)."),
}

ROWS: list[tuple] = [
    # bird
    ('bird', 'Fly', 'Direct', [('bird', 'CapableOf', 'fly', 2.83, 'bird can fly', '/a/[/r/CapableOf/,/c/en/bird/,/c/en/fly/]')]),
    ('bird', 'Perch', 'Direct', [('bird', 'CapableOf', 'land_on_branch', 2.0, 'A bird can land on a branch', '/a/[/r/CapableOf/,/c/en/bird/,/c/en/land_on_branch/]')]),
    ('bird', 'Nest', 'Direct', [('bird', 'CapableOf', 'build_nest', 2.83, 'An activity a bird can do is build a nest', '/a/[/r/CapableOf/,/c/en/bird/,/c/en/build_nest/]')]),
    # bat
    ('bat', 'Fly', 'Direct', [('bat', 'CapableOf', 'fly', 1.0, 'An activity a bat can do is fly', '/a/[/r/CapableOf/,/c/en/bat/,/c/en/fly/]')]),
    ('bat', 'Cling', 'Direct', [('bat', 'CapableOf', 'hanging_upside_down', 1.0, 'a bat can be hanging upside down', '/a/[/r/CapableOf/,/c/en/bat/,/c/en/hanging_upside_down/]')]),
    # butterfly
    ('butterfly', 'Flutter', 'Direct', [('butterfly', 'CapableOf', 'fly', 2.0, 'a butterfly can fly', '/a/[/r/CapableOf/,/c/en/butterfly/,/c/en/fly/]')]),
    ('butterfly', 'Alight', 'Direct', [('butterfly', 'CapableOf', 'make_landing', 1.0, 'a butterfly can make a landing', '/a/[/r/CapableOf/,/c/en/butterfly/,/c/en/make_landing/]')]),
    ('butterfly', 'Draft', 'Direct', [('butterfly', 'CapableOf', 'cause_wind', 1.0, 'a butterfly can cause a wind', '/a/[/r/CapableOf/,/c/en/butterfly/,/c/en/cause_wind/]')]),
    # spider
    ('spider', 'Wall Cling', 'Property', [('spider', 'HasProperty', 'sticking_to_wall', 1.0, 'a spider can be sticking to a wall', '/a/[/r/HasProperty/,/c/en/spider/,/c/en/sticking_to_wall/]')]),
    ('spider', 'Web', 'Direct', [('spider', 'CapableOf', 'spin_webs', 2.83, 'An activity a spider can do is spin webs', '/a/[/r/CapableOf/,/c/en/spider/,/c/en/spin_webs/]')]),
    ('spider', 'Venom', 'Direct', [('spider', 'CapableOf', 'inject_venom', 2.0, 'spider can inject venom.', '/a/[/r/CapableOf/,/c/en/spider/,/c/en/inject_venom/]')]),
    # monkey
    ('monkey', 'Hang', 'Property', [('monkey', 'HasProperty', 'hanging_off_tree', 2.0, 'a monkey can be hanging off a tree', '/a/[/r/HasProperty/,/c/en/monkey/,/c/en/hanging_off_tree/]')]),
    ('monkey', 'Swing', 'Direct', [('monkey', 'CapableOf', 'move_from_one_tree_to_another', 1.0, 'A monkey can move from one tree to another', '/a/[/r/CapableOf/,/c/en/monkey/,/c/en/move_from_one_tree_to_another/]')]),
    ('monkey', 'Use Tool', 'Direct', [('monkey', 'CapableOf', 'use_tool', 1.0, 'a monkey can use a tool', '/a/[/r/CapableOf/,/c/en/monkey/,/c/en/use_tool/]')]),
    ('monkey', 'Throw', 'Direct', [('monkey', 'CapableOf', 'throw_banana', 1.0, 'A monkey can throw a banana', '/a/[/r/CapableOf/,/c/en/monkey/,/c/en/throw_banana/]')]),
    # frog
    ('frog', 'Leap', 'Direct', [('frog', 'CapableOf', 'leap', 2.0, 'An activity a frog can do is leap', '/a/[/r/CapableOf/,/c/en/frog/,/c/en/leap/]')]),
    ('frog', 'High Jump', 'Direct', [('frog', 'CapableOf', 'jump_very_high', 1.0, 'A frog can jump very high', '/a/[/r/CapableOf/,/c/en/frog/,/c/en/jump_very_high/]')]),
    ('frog', 'Tongue Grab', 'Direct', [('frog', 'CapableOf', 'catch_flies_with_tongue', 1.0, 'An activity a frog can do is catch flies with its tongue', '/a/[/r/CapableOf/,/c/en/frog/,/c/en/catch_flies_with_tongue/]')]),
    # fish
    ('fish', 'Swim', 'Direct', [('fish', 'CapableOf', 'swim', 2.0, 'Fish can swim', '/a/[/r/CapableOf/,/c/en/fish/,/c/en/swim/]')]),
    ('fish', 'Breathe Underwater', 'Part', [('fish', 'HasA', 'gills', 4.0, 'Fish have gills', '/a/[/r/HasA/,/c/en/fish/,/c/en/gills/]')]),
    ('fish', 'School', 'Direct', [('fish', 'CapableOf', 'school_together', 1.0, 'Fish can school together', '/a/[/r/CapableOf/,/c/en/fish/,/c/en/school_together/]')]),
    # shark
    ('shark', 'Swim', 'Direct', [('shark', 'CapableOf', 'swim', 1.0, 'a shark can swim.', '/a/[/r/CapableOf/,/c/en/shark/,/c/en/swim/]')]),
    ('shark', 'Circle', 'Direct', [('shark', 'CapableOf', 'circle_swimmer', 1.0, 'a shark can circle the swimmer', '/a/[/r/CapableOf/,/c/en/shark/,/c/en/circle_swimmer/]')]),
    ('shark', 'Rough Hide', 'Part', [('shark', 'HasA', 'rough_skin', 1.0, 'A shark has rough skin', '/a/[/r/HasA/,/c/en/shark/,/c/en/rough_skin/]')]),
    # octopus
    ('octopus', 'Grapple', 'Part', [('octopus', 'HasA', 'eight_tentacles', 1.0, 'An octopus has eight tentacles', '/a/[/r/HasA/,/c/en/octopus/,/c/en/eight_tentacles/]')]),
    # crab
    ('crab', 'Armor', 'Part', [('crab', 'HasA', 'external_skeleton', 1.0, 'A crab has an external skeleton', '/a/[/r/HasA/,/c/en/crab/,/c/en/external_skeleton/]')]),
    ('crab', 'Grip', 'Direct', [('crab', 'CapableOf', 'live_on_wet_rocks', 1.0, 'a crab can live on wet rocks', '/a/[/r/CapableOf/,/c/en/crab/,/c/en/live_on_wet_rocks/]')]),
    # horse
    ('horse', 'Haul', 'Direct', [('horse', 'CapableOf', 'pull_cart', 3.46, 'a horse can pull a cart', '/a/[/r/CapableOf/,/c/en/horse/,/c/en/pull_cart/]')]),
    ('horse', 'Gallop', 'Direct', [('horse', 'CapableOf', 'run_quickly', 2.0, 'A horse can run quickly', '/a/[/r/CapableOf/,/c/en/horse/,/c/en/run_quickly/]')]),
    ('horse', 'Vault', 'Direct', [('horse', 'CapableOf', 'jump_fence', 2.0, 'A horse can jump a fence', '/a/[/r/CapableOf/,/c/en/horse/,/c/en/jump_fence/]')]),
    ('horse', 'Carry Rider', 'Action', [('horse', 'ReceivesAction', 'ridden', 1.0, 'a horse can be ridden', '/a/[/r/ReceivesAction/,/c/en/horse/,/c/en/ridden/]')]),
    # elephant
    ('elephant', 'Trunk Grab', 'Part', [('elephant', 'HasA', 'trunk', 3.46, 'an elephant has a trunk', '/a/[/r/HasA/,/c/en/elephant/,/c/en/trunk/]')]),
    ('elephant', 'Tusk Ram', 'Part', [('elephant', 'HasA', 'tusks', 3.46, 'An elephant has tusks', '/a/[/r/HasA/,/c/en/elephant/,/c/en/tusks/]')]),
    ('elephant', 'Lift', 'Direct', [('elephant', 'CapableOf', 'lift_tree', 1.0, 'An activity elephant can do is to lift the tree', '/a/[/r/CapableOf/,/c/en/elephant/,/c/en/lift_tree/]')]),
    ('elephant', 'Heavy', 'Direct', [('elephant', 'CapableOf', 'weight_1000_kilos', 1.0, 'an elephant can weight 1000 kilos', '/a/[/r/CapableOf/,/c/en/elephant/,/c/en/weight_1000_kilos/]')]),
    # snake
    ('snake', 'Slither', 'Direct', [('snake', 'CapableOf', 'slither_down_street', 1.0, 'A snake can slither down the street', '/a/[/r/CapableOf/,/c/en/snake/,/c/en/slither_down_street/]')]),
    ('snake', 'Squeeze', 'Part', [('snake', 'HasA', 'no_legs', 1.0, 'A snake has no legs', '/a/[/r/HasA/,/c/en/snake/,/c/en/no_legs/]')]),
    ('snake', 'Startle', 'Direct', [('snake', 'CapableOf', 'surprise_person', 1.0, 'a snake can surprise a person', '/a/[/r/CapableOf/,/c/en/snake/,/c/en/surprise_person/]')]),
    # sea_turtle
    ('sea_turtle', 'Shell', 'Inherited', [('sea_turtle', 'IsA', 'turtle', 2.0, 'sea turtle is a type of turtle', '/a/[/r/IsA/,/c/en/sea_turtle/n/wn/animal/,/c/en/turtle/n/wn/animal/]'), ('turtle', 'CapableOf', 'hide_in_shell', 1.0, 'A turtle can hide in its shell', '/a/[/r/CapableOf/,/c/en/turtle/,/c/en/hide_in_shell/]')]),
    ('sea_turtle', 'Amphibious', 'Inherited', [('sea_turtle', 'IsA', 'turtle', 2.0, 'sea turtle is a type of turtle', '/a/[/r/IsA/,/c/en/sea_turtle/n/wn/animal/,/c/en/turtle/n/wn/animal/]'), ('turtle', 'CapableOf', 'live_in_water_or_on_land', 1.0, 'A turtle can live in water or on land', '/a/[/r/CapableOf/,/c/en/turtle/,/c/en/live_in_water_or_on_land/]')]),
    # snail
    ('snail', 'Move', 'Inherited', [('snail', 'IsA', 'animal', 1.0, 'a snail is a animal', '/a/[/r/IsA/,/c/en/snail/,/c/en/animal/]'), ('animal', 'CapableOf', 'move_itself_about', 4.0, 'An activity an animal can do is move itself about', '/a/[/r/CapableOf/,/c/en/animal/,/c/en/move_itself_about/]')]),
    # ant
    ('ant', 'Carry', 'Direct', [('ant', 'CapableOf', 'lift_several_times_own_weight', 1.0, 'An ant can lift several times its own weight', '/a/[/r/CapableOf/,/c/en/ant/,/c/en/lift_several_times_own_weight/]')]),
    ('ant', 'Colony', 'Direct', [('ant', 'CapableOf', 'build_colony', 1.0, 'an ant can build a colony', '/a/[/r/CapableOf/,/c/en/ant/,/c/en/build_colony/]')]),
    # bee
    ('bee', 'Sting', 'Direct', [('bee', 'CapableOf', 'sting', 2.0, 'A bee can sting you', '/a/[/r/CapableOf/,/c/en/bee/,/c/en/sting/]')]),
    ('bee', 'Fly', 'Direct', [('bee', 'CapableOf', 'fly', 1.0, 'An activity a bee can do is fly', '/a/[/r/CapableOf/,/c/en/bee/,/c/en/fly/]')]),
    # pig
    ('pig', 'Forage', 'Direct', [('pig', 'CapableOf', 'find_truffles', 2.0, 'a pig can find truffles', '/a/[/r/CapableOf/,/c/en/pig/,/c/en/find_truffles/]')]),
    ('pig', 'Wallow', 'Property', [('pig', 'HasProperty', 'rolling_in_mud', 1.0, 'A pig can be rolling in mud', '/a/[/r/HasProperty/,/c/en/pig/,/c/en/rolling_in_mud/]')]),
    # penguin
    ('penguin', 'Slide', 'Hand-authored', []),
    # scorpion
    ('scorpion', 'Sting', 'Direct', [('scorpion', 'CapableOf', 'sting', 1.0, 'A scorpion can sting', '/a/[/r/CapableOf/,/c/en/scorpion/,/c/en/sting/]')]),
    # circle
    ('circle', 'Roll', 'Property', [('circle', 'HasProperty', 'round', 7.48, 'A circle is round', '/a/[/r/HasProperty/,/c/en/circle/,/c/en/round/]')]),
    # square
    ('square', 'Platform', 'Direct', [('square', 'UsedFor', 'walk_on', 1.0, 'You can use a square to walk on', '/a/[/r/UsedFor/,/c/en/square/,/c/en/walk_on/]')]),
    ('square', 'Block', 'Part', [('square', 'HasA', 'four_sides', 3.46, 'A square has four sides', '/a/[/r/HasA/,/c/en/square/,/c/en/four_sides/]')]),
    # triangle
    ('triangle', 'Wedge', 'Part', [('triangle', 'HasA', 'three_sides', 6.63, 'A triangle has three sides', '/a/[/r/HasA/,/c/en/triangle/,/c/en/three_sides/]')]),
    # axe
    ('axe', 'Chop', 'Direct', [('axe', 'CapableOf', 'cut_down_tree', 1.0, 'an axe can cut down a tree', '/a/[/r/CapableOf/,/c/en/axe/,/c/en/cut_down_tree/]')]),
    ('axe', 'Split', 'Direct', [('axe', 'CapableOf', 'divide_wood_logs', 1.0, 'an axe can divide wood logs', '/a/[/r/CapableOf/,/c/en/axe/,/c/en/divide_wood_logs/]')]),
    # sword
    ('sword', 'Cut', 'Property', [('sword', 'HasProperty', 'sharp', 5.29, 'a sword is sharp', '/a/[/r/HasProperty/,/c/en/sword/,/c/en/sharp/]')]),
    ('sword', 'Strike', 'Direct', [('sword', 'UsedFor', 'killing', 4.47, 'a sword is for killing', '/a/[/r/UsedFor/,/c/en/sword/,/c/en/killing/]')]),
    ('sword', 'Parry', 'Direct', [('sword', 'UsedFor', 'fencing', 2.0, 'a sword is used for fencing', '/a/[/r/UsedFor/,/c/en/sword/,/c/en/fencing/]')]),
    # cannon
    ('cannon', 'Launch', 'Direct', [('cannon', 'CapableOf', 'fire_cannonball', 3.46, 'A cannon can fire a cannonball', '/a/[/r/CapableOf/,/c/en/cannon/,/c/en/fire_cannonball/]')]),
    ('cannon', 'Bombard', 'Direct', [('cannon', 'UsedFor', 'shooting_cannonballs', 3.46, 'a cannon is used for shooting cannonballs', '/a/[/r/UsedFor/,/c/en/cannon/,/c/en/shooting_cannonballs/]')]),
    ('cannon', 'Heavy', 'Property', [('cannon', 'HasProperty', 'heavy', 1.0, 'a cannon is heavy', '/a/[/r/HasProperty/,/c/en/cannon/,/c/en/heavy/]')]),
    # boomerang
    ('boomerang', 'Return', 'Direct', [('boomerang', 'CapableOf', 'return_to_thrower', 1.0, 'A boomerang can return to the thrower', '/a/[/r/CapableOf/,/c/en/boomerang/,/c/en/return_to_thrower/]')]),
    # flashlight
    ('flashlight', 'Illuminate', 'Direct', [('flashlight', 'UsedFor', 'seeing_in_dark', 2.0, 'A flashlight is used for seeing in the dark', '/a/[/r/UsedFor/,/c/en/flashlight/,/c/en/seeing_in_dark/]')]),
    ('flashlight', 'Beam', 'Direct', [('flashlight', 'CapableOf', 'light_path', 1.0, 'A flashlight can light a path', '/a/[/r/CapableOf/,/c/en/flashlight/,/c/en/light_path/]')]),
    ('flashlight', 'Ward', 'Direct', [('flashlight', 'CapableOf', 'keep_wolf_at_bay', 1.0, 'A flashlight can keep a wolf at bay', '/a/[/r/CapableOf/,/c/en/flashlight/,/c/en/keep_wolf_at_bay/]')]),
    # campfire
    ('campfire', 'Burn', 'Inherited', [('campfire', 'IsA', 'fire', 2.0, 'campfire is a type of fire', '/a/[/r/IsA/,/c/en/campfire/n/wn/event/,/c/en/fire/n/wn/event/]'), ('fire', 'CapableOf', 'burn_things', 7.21, 'fire can burn things', '/a/[/r/CapableOf/,/c/en/fire/,/c/en/burn_things/]')]),
    ('campfire', 'Warm', 'Inherited', [('campfire', 'IsA', 'fire', 2.0, 'campfire is a type of fire', '/a/[/r/IsA/,/c/en/campfire/n/wn/event/,/c/en/fire/n/wn/event/]'), ('fire', 'CapableOf', 'warm_hands', 4.0, 'A fire can warm your hands', '/a/[/r/CapableOf/,/c/en/fire/,/c/en/warm_hands/]')]),
    ('campfire', 'Cook', 'Inherited', [('campfire', 'IsA', 'fire', 2.0, 'campfire is a type of fire', '/a/[/r/IsA/,/c/en/campfire/n/wn/event/,/c/en/fire/n/wn/event/]'), ('fire', 'UsedFor', 'cook', 2.83, 'You can use fire to cook', '/a/[/r/UsedFor/,/c/en/fire/,/c/en/cook/]')]),
    # cloud
    ('cloud', 'Rain', 'Direct', [('cloud', 'UsedFor', 'rain', 2.0, 'a cloud is used for rain', '/a/[/r/UsedFor/,/c/en/cloud/,/c/en/rain/]')]),
    ('cloud', 'Shade', 'Direct', [('cloud', 'CapableOf', 'hide_sun', 2.83, 'a cloud can hide the sun', '/a/[/r/CapableOf/,/c/en/cloud/,/c/en/hide_sun/]')]),
    ('cloud', 'Thunder', 'Direct', [('cloud', 'UsedFor', 'thunder', 1.0, 'a cloud is for thunder', '/a/[/r/UsedFor/,/c/en/cloud/,/c/en/thunder/]')]),
    # sun
    ('sun', 'Evaporate', 'Direct', [('sun', 'CapableOf', 'dry_laundry', 6.0, 'The sun can dry your laundry', '/a/[/r/CapableOf/,/c/en/sun/,/c/en/dry_laundry/]')]),
    ('sun', 'Illuminate', 'Direct', [('sun', 'CapableOf', 'shine_brightly', 5.29, 'sun can shine brightly', '/a/[/r/CapableOf/,/c/en/sun/,/c/en/shine_brightly/]')]),
    ('sun', 'Heat', 'Direct', [('sun', 'CapableOf', 'heat_earth', 4.9, 'The sun can heat the earth', '/a/[/r/CapableOf/,/c/en/sun/,/c/en/heat_earth/]')]),
    ('sun', 'Scorch', 'Direct', [('sun', 'CapableOf', 'burn_skin', 3.46, 'the sun can burn your skin', '/a/[/r/CapableOf/,/c/en/sun/,/c/en/burn_skin/]')]),
    # fan
    ('fan', 'Gust', 'Direct', [('fan', 'UsedFor', 'moving_air', 4.47, 'a fan is used for moving the air', '/a/[/r/UsedFor/,/c/en/fan/,/c/en/moving_air/]')]),
    ('fan', 'Cool', 'Direct', [('fan', 'UsedFor', 'cool_off', 6.0, 'You can use a fan to cool off', '/a/[/r/UsedFor/,/c/en/fan/,/c/en/cool_off/]')]),
    # ladder
    ('ladder', 'Climb', 'Action', [('ladder', 'ReceivesAction', 'climbed', 1.0, 'A ladder can be climbed', '/a/[/r/ReceivesAction/,/c/en/ladder/,/c/en/climbed/]')]),
    ('ladder', 'Reach', 'Direct', [('ladder', 'CapableOf', 'reach_roof', 3.46, 'a ladder can reach the roof', '/a/[/r/CapableOf/,/c/en/ladder/,/c/en/reach_roof/]')]),
    ('ladder', 'Bridge Gap', 'Direct', [('ladder', 'UsedFor', 'using_as_bridge', 1.0, 'a ladder is for using as a bridge', '/a/[/r/UsedFor/,/c/en/ladder/,/c/en/using_as_bridge/]')]),
    # stairs
    ('stairs', 'Ascend', 'Direct', [('stairs', 'UsedFor', 'climbing', 5.29, 'stairs is for climbing', '/a/[/r/UsedFor/,/c/en/stairs/,/c/en/climbing/]')]),
    ('stairs', 'Descend', 'Direct', [('stairs', 'UsedFor', 'walking_down', 2.0, 'stairs is for walking down', '/a/[/r/UsedFor/,/c/en/stairs/,/c/en/walking_down/]')]),
    # parachute
    ('parachute', 'Glide', 'Direct', [('parachute', 'CapableOf', 'slow_descent_through_air', 1.0, 'A parachute can slow a descent through air', '/a/[/r/CapableOf/,/c/en/parachute/,/c/en/slow_descent_through_air/]')]),
    # hot_air_balloon
    ('hot_air_balloon', 'Float', 'Inherited', [('hot_air_balloon', 'IsA', 'balloon', 2.0, 'hot-air balloon is a type of balloon', '/a/[/r/IsA/,/c/en/hot_air_balloon/n/wn/artifact/,/c/en/balloon/n/wn/artifact/]'), ('balloon', 'CapableOf', 'rise_into_air', 1.0, 'A balloon can rise into the air', '/a/[/r/CapableOf/,/c/en/balloon/,/c/en/rise_into_air/]')]),
    ('hot_air_balloon', 'Drift', 'Inherited', [('hot_air_balloon', 'IsA', 'balloon', 2.0, 'hot-air balloon is a type of balloon', '/a/[/r/IsA/,/c/en/hot_air_balloon/n/wn/artifact/,/c/en/balloon/n/wn/artifact/]'), ('balloon', 'CapableOf', 'float_through_air', 1.0, 'A balloon can float through the air', '/a/[/r/CapableOf/,/c/en/balloon/,/c/en/float_through_air/]')]),
    # bridge
    ('bridge', 'Span', 'Direct', [('bridge', 'UsedFor', 'crossing_river', 4.0, 'a bridge is for crossing a river', '/a/[/r/UsedFor/,/c/en/bridge/,/c/en/crossing_river/]')]),
    ('bridge', 'Cross Ravine', 'Direct', [('bridge', 'CapableOf', 'bridge_ravine', 2.0, 'a bridge can bridge a ravine', '/a/[/r/CapableOf/,/c/en/bridge/,/c/en/bridge_ravine/]')]),
    ('bridge', 'Arch', 'Property', [('bridge', 'HasProperty', 'arched_to_make_stronger', 1.0, 'A bridge is arched to make it stronger', '/a/[/r/HasProperty/,/c/en/bridge/,/c/en/arched_to_make_stronger/]')]),
    # sailboat
    ('sailboat', 'Wind Sail', 'Action', [('sailboat', 'ReceivesAction', 'propelled_by_wind', 3.46, 'A sailboat is propelled by wind', '/a/[/r/ReceivesAction/,/c/en/sailboat/,/c/en/propelled_by_wind/]')]),
    ('sailboat', 'Sail', 'Inherited', [('sailboat', 'IsA', 'boat', 2.0, 'sailboat is a type of boat', '/a/[/r/IsA/,/c/en/sailboat/n/wn/artifact/,/c/en/boat/n/wn/artifact/]'), ('boat', 'UsedFor', 'travel_on_water', 7.21, 'You can use a boat to travel on the water', '/a/[/r/UsedFor/,/c/en/boat/,/c/en/travel_on_water/]')]),
    # submarine
    ('submarine', 'Submerge', 'Direct', [('submarine', 'CapableOf', 'submerge_under_water', 1.0, 'a submarine can submerge under water.', '/a/[/r/CapableOf/,/c/en/submarine/,/c/en/submerge_under_water/]')]),
    ('submarine', 'Deep Dive', 'Direct', [('submarine', 'CapableOf', 'travel_deep_in_ocean', 1.0, 'a submarine can travel deep in the ocean', '/a/[/r/CapableOf/,/c/en/submarine/,/c/en/travel_deep_in_ocean/]')]),
    ('submarine', 'Torpedo', 'Direct', [('submarine', 'CapableOf', 'shoot_torpedo', 1.0, 'a submarine can shoot a torpedo.', '/a/[/r/CapableOf/,/c/en/submarine/,/c/en/shoot_torpedo/]')]),
    # key
    ('key', 'Unlock', 'Direct', [('key', 'CapableOf', 'open_lock', 6.33, 'A key can open a lock', '/a/[/r/CapableOf/,/c/en/key/,/c/en/open_lock/]')]),
    ('key', 'Open Door', 'Direct', [('key', 'CapableOf', 'open_doors', 6.0, 'a key can open doors', '/a/[/r/CapableOf/,/c/en/key/,/c/en/open_doors/]')]),
    ('key', 'Free', 'Direct', [('key', 'CapableOf', 'free_prisoner', 1.0, 'a key can free a prisoner', '/a/[/r/CapableOf/,/c/en/key/,/c/en/free_prisoner/]')]),
    # door
    ('door', 'Passage', 'Action', [('door', 'ReceivesAction', 'opened', 4.0, 'a door can be opened', '/a/[/r/ReceivesAction/,/c/en/door/,/c/en/opened/]')]),
    ('door', 'Seal', 'Action', [('door', 'ReceivesAction', 'closed', 3.46, 'a door can be closed', '/a/[/r/ReceivesAction/,/c/en/door/,/c/en/closed/]')]),
    ('door', 'Lock', 'Action', [('door', 'ReceivesAction', 'locked', 2.0, 'a door can be locked', '/a/[/r/ReceivesAction/,/c/en/door/,/c/en/locked/]')]),
    # rake
    ('rake', 'Gather', 'Action', [('rake', 'MannerOf', 'gather', 2.0, 'rake is a way to gather', '/a/[/r/MannerOf/,/c/en/rake/v/wn/contact/,/c/en/gather/v/wn/contact/]')]),
    # scissors
    ('scissors', 'Cut', 'Direct', [('scissors', 'UsedFor', 'cut', 5.66, 'scissors are used to cut', '/a/[/r/UsedFor/,/c/en/scissors/,/c/en/cut/]')]),
    ('scissors', 'Sharp Edge', 'Property', [('scissors', 'HasProperty', 'sharp', 2.0, 'Scissors are sharp', '/a/[/r/HasProperty/,/c/en/scissors/,/c/en/sharp/]')]),
    ('scissors', 'Tear Cloth', 'Direct', [('scissors', 'CapableOf', 'tear_cloth', 1.0, 'scissors can tear cloth', '/a/[/r/CapableOf/,/c/en/scissors/,/c/en/tear_cloth/]')]),
    # clock
    ('clock', 'Time', 'Direct', [('clock', 'UsedFor', 'keeping_time', 2.83, 'a clock is used for keeping time', '/a/[/r/UsedFor/,/c/en/clock/,/c/en/keeping_time/]')]),
    ('clock', 'Alarm', 'Direct', [('clock', 'UsedFor', 'set_alarm', 2.83, 'You can use a clock to set an alarm', '/a/[/r/UsedFor/,/c/en/clock/,/c/en/set_alarm/]')]),
    ('clock', 'Tick', 'Direct', [('clock', 'CapableOf', 'continue_to_tick', 2.83, 'a clock can continue to tick', '/a/[/r/CapableOf/,/c/en/clock/,/c/en/continue_to_tick/]')]),
    # anvil
    ('anvil', 'Crush', 'Direct', [('anvil', 'UsedFor', 'stun_cartoon_character', 1.0, 'You can use an anvil to stun a cartoon character', '/a/[/r/UsedFor/,/c/en/anvil/,/c/en/stun_cartoon_character/]')]),
    # bucket
    ('bucket', 'Carry Water', 'Direct', [('bucket', 'UsedFor', 'carrying_liquids', 4.47, 'a bucket is used for carrying liquids', '/a/[/r/UsedFor/,/c/en/bucket/,/c/en/carrying_liquids/]')]),
    ('bucket', 'Douse', 'Direct', [('bucket', 'UsedFor', 'taking_water_to_fire', 1.0, 'a bucket is for taking water to the fire', '/a/[/r/UsedFor/,/c/en/bucket/,/c/en/taking_water_to_fire/]')]),
    ('bucket', 'Helmet', 'Direct', [('bucket', 'UsedFor', 'protecting_head', 1.0, 'a bucket is for protecting your head', '/a/[/r/UsedFor/,/c/en/bucket/,/c/en/protecting_head/]')]),
    # umbrella
    ('umbrella', 'Shield Rain', 'Direct', [('umbrella', 'UsedFor', 'protection_from_rain', 4.47, 'an umbrella is for protection from the rain', '/a/[/r/UsedFor/,/c/en/umbrella/,/c/en/protection_from_rain/]')]),
    ('umbrella', 'Shade', 'Direct', [('umbrella', 'UsedFor', 'keeping_sun_off', 2.83, 'an umbrella is for keeping the sun off you', '/a/[/r/UsedFor/,/c/en/umbrella/,/c/en/keeping_sun_off/]')]),
    ('umbrella', 'Catch Wind', 'Direct', [('umbrella', 'CapableOf', 'break_in_high_wind', 1.0, 'An umbrella may break in high wind', '/a/[/r/CapableOf/,/c/en/umbrella/,/c/en/break_in_high_wind/]')]),
    # tree
    ('tree', 'Grow', 'Direct', [('tree', 'CapableOf', 'grow', 6.0, 'An activity a tree can do is grow', '/a/[/r/CapableOf/,/c/en/tree/,/c/en/grow/]')]),
    ('tree', 'Shade', 'Direct', [('tree', 'UsedFor', 'shade', 3.46, 'a tree is for shade', '/a/[/r/UsedFor/,/c/en/tree/,/c/en/shade/]')]),
    ('tree', 'Climb', 'Direct', [('tree', 'UsedFor', 'climbing', 2.83, 'a tree is used for climbing', '/a/[/r/UsedFor/,/c/en/tree/,/c/en/climbing/]')]),
    # wheel
    ('wheel', 'Roll', 'Direct', [('wheel', 'UsedFor', 'rolling', 2.83, 'a wheel is for rolling', '/a/[/r/UsedFor/,/c/en/wheel/,/c/en/rolling/]')]),
    ('wheel', 'Turn', 'Direct', [('wheel', 'UsedFor', 'turn', 2.0, 'You can use a wheel to turn', '/a/[/r/UsedFor/,/c/en/wheel/,/c/en/turn/]')]),
    # bread
    ('bread', 'Feed', 'Direct', [('bread', 'UsedFor', 'feeding_to_birds', 1.0, 'bread is for Feeding to the birds', '/a/[/r/UsedFor/,/c/en/bread/,/c/en/feeding_to_birds/]')]),
    ('bread', 'Eat', 'Direct', [('bread', 'UsedFor', 'eating', 5.66, 'bread is for eating', '/a/[/r/UsedFor/,/c/en/bread/,/c/en/eating/]')]),
]

PRIMARY: dict[str, str] = {
    'bird': 'Fly',
    'bat': 'Fly',
    'butterfly': 'Flutter',
    'spider': 'Wall Cling',
    'monkey': 'Hang',
    'frog': 'Leap',
    'fish': 'Swim',
    'shark': 'Swim',
    'octopus': 'Grapple',
    'crab': 'Armor',
    'horse': 'Haul',
    'elephant': 'Trunk Grab',
    'snake': 'Slither',
    'sea_turtle': 'Shell',
    'snail': 'Move',
    'ant': 'Carry',
    'bee': 'Sting',
    'pig': 'Forage',
    'penguin': 'Slide',
    'scorpion': 'Sting',
    'circle': 'Roll',
    'square': 'Platform',
    'triangle': 'Wedge',
    'axe': 'Chop',
    'sword': 'Cut',
    'cannon': 'Launch',
    'boomerang': 'Return',
    'flashlight': 'Illuminate',
    'campfire': 'Burn',
    'cloud': 'Rain',
    'sun': 'Evaporate',
    'fan': 'Gust',
    'ladder': 'Climb',
    'stairs': 'Ascend',
    'parachute': 'Glide',
    'hot_air_balloon': 'Float',
    'bridge': 'Span',
    'sailboat': 'Wind Sail',
    'submarine': 'Submerge',
    'key': 'Unlock',
    'door': 'Passage',
    'rake': 'Gather',
    'scissors': 'Cut',
    'clock': 'Time',
    'anvil': 'Crush',
    'bucket': 'Carry Water',
    'umbrella': 'Shield Rain',
    'tree': 'Grow',
    'wheel': 'Roll',
    'bread': 'Feed',
}


def _sentence(links: list[tuple]) -> str:
    """ConceptNet's own wording; an inherited row joins its two assertions."""
    parts = [link[4].strip().rstrip(".") for link in links]
    text = parts[0] if len(parts) == 1 else f"{parts[0]}, and {parts[1][0].lower()}{parts[1][1:]}"
    return text[0].upper() + text[1:] + "."


def build() -> dict:
    entities = load_entities()
    roster = [e.id for e in entities if e.enabled]
    by_class: dict[str, list[dict]] = {}
    for class_id, label, mode, links in ROWS:
        if not links:
            continue  # penguin: hand-authored, below
        by_class.setdefault(class_id, []).append({
            "label": label,
            "mode": mode,
            "relation": links[-1][1],
            "weight": links[-1][3],
            "assertion": _sentence(links),
            "chain": [{"start": f"/c/en/{s}", "relation": r, "end": f"/c/en/{e}", "weight": w,
                       "assertion_uri": uri} for s, r, e, w, _, uri in links],
        })
    abilities: dict[str, dict] = {}
    for class_id in roster:
        if class_id in HAND_AUTHORED:
            label, why = HAND_AUTHORED[class_id]
            abilities[class_id] = {
                "ability": label.lower(), "ability_label": label, "ability_mode": "Hand-authored",
                "ability_relation": "hand_authored", "ability_assertion": why,
                "ability_weight": None, "assertion_uri": None, "concept": None,
                "provenance": "hand_authored",
                "abilities": [{"label": label, "mode": "Hand-authored", "relation": "hand_authored",
                               "weight": None, "assertion": why, "chain": []}],
            }
            continue
        rows = by_class.get(class_id)
        if not rows:
            raise SystemExit(f"no Appendix C row for {class_id!r}")
        primary = next((r for r in rows if r["label"] == PRIMARY[class_id]), None)
        if primary is None:
            raise SystemExit(f"{class_id}: primary {PRIMARY[class_id]!r} is not among its rows")
        abilities[class_id] = {
            "ability": primary["label"].lower(),
            "ability_label": primary["label"],
            "ability_mode": primary["mode"],
            "ability_relation": primary["relation"],
            "ability_assertion": primary["assertion"],
            "ability_weight": primary["weight"],
            "assertion_uri": primary["chain"][-1]["assertion_uri"],
            "concept": primary["chain"][0]["start"],
            "provenance": "conceptnet_5.7",
            "abilities": rows,
        }
    extra = sorted(set(by_class) - set(roster))
    if extra:
        raise SystemExit(f"Appendix C rows for classes not in the roster: {extra}")
    grounded = sum(len(v["abilities"]) for v in abilities.values() if v["provenance"] != "hand_authored")
    return {
        "version": 2,
        "note": (
            "The manuscript's Appendix C, verified against the ConceptNet 5.7.0 assertions dump "
            "(every edge exists with these weights) and built by tools/build_abilities.py. "
            f"{grounded} abilities over {len(abilities) - len(HAND_AUTHORED)} classes through six "
            "relations and a guarded IsA traversal; penguin is hand-authored. The top-level "
            "ability fields are each class's primary; 'abilities' lists them all. Resolved "
            "offline: the game and backend only read this file."
        ),
        "abilities": abilities,
    }


def verify_against_dump(dump: Path) -> int:
    """Every link must exist in the dump with its weight (to 0.01)."""
    want = {}
    for _, _, _, links in ROWS:
        for s, r, e, w, _, _ in links:
            want[(r, f"/c/en/{s}", f"/c/en/{e}")] = w
    starts = {k[1] for k in want}
    found: dict = {}
    with gzip.open(dump, "rt", encoding="utf-8") as handle:
        for line in handle:
            parts = line.split("\t")
            if len(parts) < 5 or not parts[2].startswith("/c/en/") or not parts[3].startswith("/c/en/"):
                continue
            start = "/".join(parts[2].split("/")[:4])
            if start not in starts:
                continue
            key = (parts[1][3:], start, "/".join(parts[3].split("/")[:4]))
            if key in want:
                weight = float(json.loads(parts[4]).get("weight", 0.0))
                found[key] = max(found.get(key, 0.0), weight)
    problems = 0
    for key, weight in want.items():
        if key not in found:
            print("  MISSING", *key)
            problems += 1
        elif abs(found[key] - weight) > 0.01:
            print(f"  WEIGHT  {' '.join(key)}: table {weight}, dump {found[key]:.3f}")
            problems += 1
    print(f"{len(want) - problems} of {len(want)} edges verified against {dump.name}")
    return 1 if problems else 0


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="fail if the committed file differs")
    parser.add_argument("--dump", type=Path, help="re-verify every edge against this dump")
    args = parser.parse_args()
    if args.dump:
        sys.exit(verify_against_dump(args.dump))
    text = json.dumps(build(), indent=2, ensure_ascii=False) + "\n"
    if args.check:
        current = DEFAULT_ABILITIES_PATH.read_text(encoding="utf-8")
        if current.replace("\r\n", "\n") != text:
            print(f"{DEFAULT_ABILITIES_PATH} is out of date: run tools/build_abilities.py")
            sys.exit(1)
        print("abilities.json is up to date")
        return
    DEFAULT_ABILITIES_PATH.write_text(text, encoding="utf-8", newline="\n")
    print("wrote", DEFAULT_ABILITIES_PATH)


if __name__ == "__main__":
    main()

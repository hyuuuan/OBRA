class_name PhysicsLayers
extends RefCounted
## The four 2D physics layers by name, as bits, so nothing writes a bare 2 or 8.
##
## WORLD is the one layer the game had before fighting: ground, walls, drawn things, the player,
## and every hurtbox the weapons query. It is unchanged, so every existing mask-1 query still
## sees exactly what it saw. The other three exist only where a level turns fighting on.

const WORLD := 1
## An enemy's body: what it stands on the world with. Not a weapon target by itself.
const ENEMY_BODY := 2
## What a weapon hits on an enemy. Enemies also sit on WORLD so the existing tool queries find them.
const ENEMY_HURTBOX := 4
## What an enemy's attack hits on the player.
const PLAYER_HURTBOX := 8

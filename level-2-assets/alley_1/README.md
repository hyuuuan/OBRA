# Supplied Alley 1 artwork

The four original files supplied on 2026-10-04 are preserved here unchanged.
Runtime counterparts live in `game/assets/Level2/alley_1/`, following the existing
lowercase per-location asset convention. `banderitas.png` becomes `bandaritas.png`
to match the game's `BandaritaLine2D` terminology.

The runtime `store.png` removes painted pennants and strings with built-in ImageGen.
Cleanup prompt: remove every suspended red flag and string, restore transparent sky
or underlying roof pixels, and preserve the original buildings, shop, poles, lamps,
palette, placement and 1448 x 1086 canvas. This prevents flags remaining after a cut.
No other supplied asset is redrawn.

The upper string of the supplied pennant plate skins the existing live bunting curve.
Its second string is outside the sampled texture strip. Nests, sway, cutting reach,
falling, checkpoint restore and the flight ceiling all retain the original gameplay.

The store's foot row (800) and ground's walking row (895) are registered separately
in `alley_1_room_2d.gd`. This fixes the different vertical margins in the supplied PNGs
without moving the floor or either transition area. Street signs mark the existing
exits, and the onward barrier disappears when all five scraps have been collected.
Both axes now use the same 0.65 scale, so the 1448×1086 artwork keeps its proportions.

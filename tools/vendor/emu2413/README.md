# emu2413 1.6.2 (vendored, unmodified)

The VRC7 (Yamaha OPLL) FM core that `tools/famirender.py` renders the music's FM channels
through. emu2413 is the emulator family FamiTracker itself uses for VRC7, so a module rendered
here sounds like it does in the tracker. It is a **build tool only**: nothing here is compiled
into or shipped with the game, which gets plain WAV files.

- Source: https://github.com/digital-sound-antiques/emu2413, tag `1.6.2`
- Licence: MIT (`LICENSE`, Mitsutaka Okazaki)
- Fetched 2026-11-14, with Kent's approval, as the three files below and nothing else.
- Reviewed before first compile: it includes only `<stdint.h>`, `<math.h>`, `<stdio.h>`,
  `<stdlib.h>` and `<string.h>`; it makes no file, network or process calls (its one `printf` is
  behind `OPLL_DEBUG`); it has no inline assembly; every byte is ASCII.

SHA-256, checked by `tools/famirender.py` before every compile, so a changed file is never
built without someone looking at it first:

```
252462c355ab37afcd741093993dbe5d73a62895090c4ced979b80926687f440  emu2413.c
4c65875f5b6c1302e579c75984fa1657eb847e58c4e25f14c936e2ec81b3933d  emu2413.h
8fb093f26ed0d78c8ca033bbec7063ac5b34c5d2475e6bd121d03ccfaaf2355f  LICENSE
```

To update: fetch the new tag's three files, review them the same way, and change the hashes here
and in `famirender.VENDOR_SHA256` in the same commit.

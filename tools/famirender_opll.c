/*
 * The one loop tools/famirender.py would otherwise run in Python, a sample at a time.
 *
 * An engine tick of VRC7 audio is about 530 samples; calling OPLL_calc through ctypes for each
 * one makes a minute of music take minutes. This file is ours, not emu2413's, so the vendored
 * copy stays byte-for-byte what its hashes say.
 *
 * Bounds are the caller's: `out` is a NumPy int16 array famirender sizes to exactly `n`.
 */
#include <stdint.h>

#include "emu2413.h"

void famiopll_render(OPLL *opll, int16_t *out, int32_t n) {
  for (int32_t i = 0; i < n; i++) {
    out[i] = OPLL_calc(opll);
  }
}

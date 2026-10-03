"""A backend the game started ends when the game does.

The game launches this server as a child process and kills it on the way out. That kill
only happens when the game gets to say goodbye: the window's close button, Quit on the
menus. Stopping a run from the Godot editor, a crash, or a force-quit says nothing, and the
server was left running on port 8000 with nobody to stop it. The next launch found a
healthy server on the port and used it -- whatever code it had been started with. One ran
for eighteen days on the development machine and served the old preprocessing after the
fix for circles read as clocks had been merged, so the game went on reading every circle as
a clock with the fix in the repository.

So the game says who it is when it starts the server (OBRA_GAME_PID), and the server
checks every second that the game is still there. When it is gone, the server exits. A
server started by hand has no OBRA_GAME_PID and is left alone.

Stdlib only, so the game's lifecycle does not depend on the ML stack importing.
"""

from __future__ import annotations

import os
import threading
import time
from collections.abc import Mapping

GAME_PID_ENV = "OBRA_GAME_PID"


def _exists(pid: int) -> bool:
    if os.name == "nt":
        return _exists_on_windows(pid)
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:  # alive, owned by someone else
        return True
    return True


# Win32, by name: SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, and what the calls answer.
_SYNCHRONIZE = 0x00100000
_QUERY_LIMITED = 0x00001000
_WAIT_TIMEOUT = 0x00000102
_ERROR_ACCESS_DENIED = 5


def _exists_on_windows(pid: int, kernel32=None) -> bool:
    """Whether a Windows process is still running.

    os.kill(pid, 0) is not a probe on Windows -- signal 0 is CTRL_C_EVENT -- so ask the system:
    open the process, and see whether it has finished. A process that cannot be opened at all
    is gone, unless the reason is that it belongs to someone else, which means it is there.
    `kernel32` is a parameter so the logic can be tested on a machine that is not Windows.
    """
    if kernel32 is None:
        import ctypes

        kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        get_error = ctypes.get_last_error
    else:
        get_error = kernel32.GetLastError
    handle = kernel32.OpenProcess(_SYNCHRONIZE | _QUERY_LIMITED, False, pid)
    if not handle:
        return get_error() == _ERROR_ACCESS_DENIED
    try:
        return kernel32.WaitForSingleObject(handle, 0) == _WAIT_TIMEOUT
    finally:
        kernel32.CloseHandle(handle)


def exit_with_the_game(
    environ: Mapping[str, str] = os.environ, every: float = 1.0
) -> threading.Thread | None:
    """Start watching the game named in OBRA_GAME_PID; exit this process when it ends.

    Returns the watcher thread, or None when there is no game to watch.
    """
    raw = environ.get(GAME_PID_ENV, "").strip()
    if not raw.isdigit():
        return None
    # Windows too, now. It was skipped here because os.kill(pid, 0) is not a probe there, and
    # a server left behind on Windows -- after a crash, or a run stopped from the editor -- held
    # port 8000 for the next launch. _exists asks Windows properly (_exists_on_windows).
    game_pid = int(raw)
    # When the game is the direct parent, a change of parent is the surest sign it has gone:
    # the orphan is re-parented the moment the game exits, before anything reaps it, while a
    # dead-but-unreaped game still answers os.kill.
    game_is_parent = os.getppid() == game_pid

    def game_is_running() -> bool:
        if game_is_parent and os.getppid() != game_pid:
            return False
        return _exists(game_pid)

    def watch() -> None:
        while game_is_running():
            time.sleep(every)
        os._exit(0)

    watcher = threading.Thread(target=watch, name="exit-with-the-game", daemon=True)
    watcher.start()
    return watcher

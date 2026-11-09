"""Limitation des tentatives de connexion (en mémoire, un seul processus uvicorn)."""

import time

MAX_ATTEMPTS = 8
WINDOW_SECONDS = 300

_failures: dict[str, list[float]] = {}


def _recent(key: str) -> list[float]:
    now = time.monotonic()
    recent = [t for t in _failures.get(key, []) if now - t < WINDOW_SECONDS]
    if recent:
        _failures[key] = recent
    else:
        _failures.pop(key, None)
    return recent


def retry_after(key: str) -> int:
    """Secondes à attendre avant un nouvel essai ; 0 si un essai est permis."""
    recent = _recent(key)
    if len(recent) < MAX_ATTEMPTS:
        return 0
    return int(WINDOW_SECONDS - (time.monotonic() - recent[0])) + 1


def register_failure(key: str) -> None:
    _recent(key)
    _failures.setdefault(key, []).append(time.monotonic())


def reset(key: str) -> None:
    _failures.pop(key, None)

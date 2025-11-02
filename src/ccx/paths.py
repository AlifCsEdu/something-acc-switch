from __future__ import annotations
import os
from pathlib import Path

HOME = Path.home()

def xdg_data() -> Path:
    return Path(os.environ.get("XDG_DATA_HOME", HOME/".local/share"))


def xdg_config() -> Path:
    return Path(os.environ.get("XDG_CONFIG_HOME", HOME/".config"))


def profiles_dir() -> Path:
    env = os.environ.get("CCX_PROFILES")
    if env:
        p = Path(os.path.expanduser(env))
    else:
        p = xdg_data() / "ccx" / "profiles"
    p.mkdir(parents=True, exist_ok=True)
    return p


def config_path() -> Path:
    d = xdg_config() / "ccx"
    d.mkdir(parents=True, exist_ok=True)
    return d / "config.json"


def codex_targets() -> list[Path]:
    targets = [HOME / ".codex" / "auth.json"]
    code_home = os.environ.get("CODEX_HOME")
    if code_home:
        p = Path(os.path.expanduser(code_home)) / "auth.json"
        if p not in targets:
            targets.append(p)
    extra = [e for e in os.environ.get("CCX_TARGETS", "").split(":") if e.strip()]
    for e in extra:
        p = Path(os.path.expanduser(e.strip()))
        if p not in targets:
            targets.append(p)
    for t in targets:
        t.parent.mkdir(parents=True, exist_ok=True)
    return targets

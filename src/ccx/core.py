from __future__ import annotations
import json, os, shutil, time, tarfile, base64, hashlib, tempfile
from pathlib import Path
from typing import Iterable
from .paths import profiles_dir, codex_targets, HOME

CUR_FILE  = profiles_dir() / ".current"
LAST_FILE = profiles_dir() / ".last"
STATS_FILE = profiles_dir() / ".stats.json"

DURABLE = os.environ.get("CCX_DURABLE") == "1"

# placeholder core; will be filled with full content next calls

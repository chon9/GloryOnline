"""painter.render - renders one registered icon to disk. Called by bake.py (one process per icon).

Seeds come from crc32(id), so an icon renders identically whatever subset or order is baked.
"""
import os
import zlib

import numpy as np

from painter import core, frames, registry
from painter.core import Canvas
from painter.keys import CLASS_KEYS, STATUS_KIND
from painter.qa import save

SKILL_PX = 128
STATUS_PX = 64
EMBLEM_PX = 128


def _seed(s):
    return zlib.crc32(s.encode("utf-8")) & 0x7FFFFFFF


def skill_path(out_root, skill_id):
    return os.path.join(out_root, "skills", skill_id.replace(".", "__"))


def status_path(out_root, status_id):
    return os.path.join(out_root, "status", status_id)


def emblem_path(out_root, class_id):
    return os.path.join(out_root, "class", class_id)


def render_skill(sk, out_root):
    """sk: a skill dict from skills.json"""
    registry.discover()
    e = registry.SKILLS[sk["id"]]
    class_id = sk["id"].split(".")[0]
    core.set_key(registry.class_key(class_id))
    s = _seed(sk["id"])
    rng = np.random.default_rng(s)
    cv = Canvas(256, seed=s % 100000)
    res = e["fn"](cv, rng, e["tone"]) or {}
    kind = "ultimate" if sk.get("ultimate") else ("passive" if sk.get("passive") else "skill")
    if kind == "ultimate":
        alpha = frames.frame_ultimate(cv, rng)
    elif kind == "passive":
        alpha = frames.frame_passive(cv)
    else:
        alpha = frames.frame_skill(cv)
    if "bleed" in res:
        res["bleed"](cv)
    base = skill_path(out_root, sk["id"])
    save(cv, alpha, base, SKILL_PX)
    return base + ".png"


def render_status(status_id, out_root):
    registry.discover()
    e = registry.STATUSES[status_id]
    core.set_key(CLASS_KEYS["battle_mage"])  # status icons only use STATUS_PAL; a key is set for the shared ink
    s = _seed("status." + status_id)
    rng = np.random.default_rng(s)
    cv = Canvas(128, seed=s % 100000)
    kind = STATUS_KIND[status_id]
    outer, inner = frames.badge_ground(cv, kind, e["tone"], rng)
    e["fn"](cv, rng, e["tone"])
    frames.badge_finish(cv, outer, inner, kind)
    base = status_path(out_root, status_id)
    save(cv, outer, base, STATUS_PX)
    return base + ".png"


def render_emblem(cls, out_root):
    """cls: a class dict from skills.json"""
    registry.discover()
    e = registry.EMBLEMS[cls["id"]]
    key = registry.class_key(cls["id"])
    core.set_key(key)
    s = _seed("class." + cls["id"])
    rng = np.random.default_rng(s)
    cv = Canvas(256, seed=s % 100000)
    outer, inner = frames.emblem_ground(cv, cls["group_id"], key, rng)
    e["fn"](cv, rng, key)
    alpha = frames.emblem_finish(cv, outer, inner, cls["group_id"], key)
    base = emblem_path(out_root, cls["id"])
    save(cv, alpha, base, EMBLEM_PX)
    return base + ".png"

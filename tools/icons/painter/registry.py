"""painter.registry - decorators that comps files use to register their drawings, and comp auto-discovery.

    from painter import *

    @skill("witch.lava_flask", tone="gold")      # full SkillDef id from tools/icons/skills.json
    def lava_flask(cv, rng, el): ...

    @status("burn", tone="fire")                  # comps/_status.py only
    @emblem("witch")                              # comps/_emblems.py only

Discovery imports every tools/icons/comps/*.py whose name does not start with "_lib_" (those are helper libraries
imported explicitly by the comps that use them). A class comps file may define CLASS_KEY = {...} to override its default
palette key from painter.keys.
"""
import importlib
import os
import sys

SKILLS = {}       # full skill id -> {"fn", "tone", "module"}
STATUSES = {}     # status id -> {"fn", "tone", "module"}
EMBLEMS = {}      # class id -> {"fn", "tone", "module"}
KEY_OVERRIDES = {}  # class id -> key dict (module-level CLASS_KEY in comps/<class_id>.py)

COMPS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "comps")


def _reg(table, key, tone, fn):
    if key in table and table[key]["fn"] is not fn:
        raise ValueError("icon '%s' registered twice (%s and %s)" % (key, table[key]["module"], fn.__module__))
    table[key] = {"fn": fn, "tone": tone, "module": fn.__module__}
    return fn


def skill(skill_id, tone):
    """register a skill composition: fn(cv, rng, el) draws ground + subject; frames are added by the generator.
    May return {"bleed": fn(cv)} for drawing that must sit on top of the frame (e.g. a head breaking the frame)."""
    if "." not in skill_id:
        raise ValueError("@skill needs the full SkillDef id 'class.skill', got '%s'" % skill_id)
    return lambda fn: _reg(SKILLS, skill_id, tone, fn)


def status(status_id, tone):
    """register a status subject: fn(cv, rng, el); the badge ground and bevel come from the generator"""
    return lambda fn: _reg(STATUSES, status_id, tone, fn)


def emblem(class_id, tone=None):
    """register a class emblem subject: fn(cv, rng, key); the crest comes from the generator"""
    return lambda fn: _reg(EMBLEMS, class_id, tone, fn)


_loaded = False


def discover():
    """import every comps module once (idempotent)"""
    global _loaded
    if _loaded:
        return
    root = os.path.dirname(COMPS_DIR)
    if root not in sys.path:
        sys.path.insert(0, root)
    for fn in sorted(os.listdir(COMPS_DIR)):
        if not fn.endswith(".py") or fn == "__init__.py" or fn.startswith("_lib_"):
            continue
        name = fn[:-3]
        mod = importlib.import_module("comps." + name)
        key = getattr(mod, "CLASS_KEY", None)
        if isinstance(key, dict) and not name.startswith("_"):
            KEY_OVERRIDES[name] = key
    _loaded = True


def class_key(class_id):
    from painter.keys import CLASS_KEYS
    if class_id in KEY_OVERRIDES:
        return KEY_OVERRIDES[class_id]
    return CLASS_KEYS[class_id]

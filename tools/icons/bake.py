"""Rongyao icon bake: renders skill bars, status icons and class emblems, writes QA sheets, enforces the SSIM gate.

    python -I tools/icons/bake.py                       # everything that has a comp
    python -I tools/icons/bake.py --classes witch,launcher --no-status --no-emblems
    python -I tools/icons/bake.py --only witch.sweep    # quick iteration on one icon (gate still reported)
    python -I tools/icons/bake.py --check               # no render: gate the PNGs already in assets/icons
    python -I tools/icons/bake.py --update-baseline     # accept the current SSIM maxima as the new baseline

Output: assets/icons/skills/<id with . -> __>.png (+@2x), assets/icons/status/<id>.png, assets/icons/class/<id>.png.
QA sheets go to --qa DIR (default: <tmp>/rongyao_icons_qa): <prefix>_<class>.png (+ _naming.png), <prefix>_status.png,
<prefix>_emblems.png.

Exit code 2 when a gate fails:
  * any pair inside one class bar, the status set or the emblem set scores SSIM > 0.60 (32 px greyscale), or
  * a set's max pair rose more than 0.05 above tools/icons/ssim_baseline.json (regression), or
  * a fully baked class bar is missing a comp for one of its 8 skills (--strict only).
Spec: tools/icons/skills.json, regenerated from the game by tools/icons/export_skills.gd.
"""
import argparse
import json
import os
import sys
import tempfile
import time
from concurrent.futures import ProcessPoolExecutor

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)  # python -I does not add the script dir

from PIL import Image  # noqa: E402

from painter import registry  # noqa: E402
from painter import render as R  # noqa: E402
from painter.qa import gate, qa_sheet  # noqa: E402

REPO = os.path.dirname(os.path.dirname(HERE))
SPEC = os.path.join(HERE, "skills.json")
BASELINE = os.path.join(HERE, "ssim_baseline.json")
LIMIT = 0.60
REGRESSION_MARGIN = 0.05
EMBLEM_CROP = 0.18  # emblems share one crest family: gate the inner area where the weapon lives


def _job(job):
    kind, payload, out = job
    t = time.time()
    try:
        if kind == "skill":
            p = R.render_skill(payload, out)
        elif kind == "status":
            p = R.render_status(payload, out)
        else:
            p = R.render_emblem(payload, out)
        return (kind, payload["id"] if isinstance(payload, dict) else payload, p, time.time() - t, None)
    except Exception as ex:  # report and keep baking the rest
        import traceback
        return (kind, payload["id"] if isinstance(payload, dict) else payload, None, time.time() - t,
                traceback.format_exc() + str(ex))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--classes", default="", help="comma list of class ids (default: every class with comps)")
    ap.add_argument("--only", default="", help="comma list of full skill ids / status ids / class:<id> to render")
    ap.add_argument("--no-status", action="store_true")
    ap.add_argument("--no-emblems", action="store_true")
    ap.add_argument("--no-skills", action="store_true")
    ap.add_argument("--check", action="store_true", help="do not render, only gate existing PNGs")
    ap.add_argument("--out", default=os.path.join(REPO, "assets", "icons"))
    ap.add_argument("--qa", default=os.path.join(tempfile.gettempdir(), "rongyao_icons_qa"))
    ap.add_argument("--prefix", default="mig_icons")
    ap.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 4) - 2))
    ap.add_argument("--update-baseline", action="store_true")
    ap.add_argument("--strict", action="store_true", help="fail when a baked class bar has skills without comps")
    ap.add_argument("--list", default="", help="print a class's 8-skill bar (ids, names, tags, desc, comp status) and exit")
    a = ap.parse_args()

    spec = json.load(open(SPEC, encoding="utf-8"))
    registry.discover()
    if a.list:
        try:
            sys.stdout.reconfigure(encoding="utf-8")
        except Exception:
            pass
        for c in spec["classes"]:
            if c["id"] != a.list:
                continue
            print("%s %s %s | weapon %s %s | key tones: %s" % (c["id"], c["name_cn"], c["name_en"], c["weapon_name_cn"],
                                                            c["weapon_name_en"], ", ".join(registry.class_key(c["id"])["tones"])))
            for s in sorted([s for s in c["skills"] if s["in_bar"]], key=lambda s: s["slot"]):
                print("  slot %d %-44s %s %s%s [%s] comp=%s\n      %s\n      hints %s statuses %s" % (
                    s["slot"], s["id"], s["name_cn"], s["name_en"], " (ULT)" if s["ultimate"] else "", ",".join(s["tags"]),
                    registry.SKILLS.get(s["id"], {}).get("module", "MISSING"), s["desc"], s["hints"], s["statuses"]))
        return
    only = set(x for x in a.only.split(",") if x)
    classes = {c["id"]: c for c in spec["classes"]}
    want = [x for x in a.classes.split(",") if x] or sorted({k.split(".")[0] for k in registry.SKILLS})
    for c in want:
        if c not in classes:
            sys.exit("unknown class id '%s'" % c)

    bars, missing, jobs = {}, {}, []
    if not a.no_skills:
        for cid in want:
            bar = sorted([s for s in classes[cid]["skills"] if s["in_bar"]], key=lambda s: s["slot"])
            bars[cid] = bar
            missing[cid] = [s["id"] for s in bar if s["id"] not in registry.SKILLS]
            for s in bar:
                if s["id"] in registry.SKILLS and (not only or s["id"] in only):
                    jobs.append(("skill", s, a.out))
    status_ids = [s["id"] for s in spec["statuses"]]
    if not a.no_status:
        for sid in status_ids:
            if sid in registry.STATUSES and (not only or sid in only):
                jobs.append(("status", sid, a.out))
    if not a.no_emblems:
        for cid, c in classes.items():
            if cid in registry.EMBLEMS and (not only or "class:" + cid in only):
                jobs.append(("emblem", c, a.out))

    ok = True
    if not a.check and jobs:
        t0 = time.time()
        print("baking %d icons on %d workers" % (len(jobs), a.jobs), flush=True)
        with ProcessPoolExecutor(max_workers=a.jobs) as ex:
            for kind, iid, path, dt, err in ex.map(_job, jobs):
                if err:
                    ok = False
                    print("ERROR %s %s\n%s" % (kind, iid, err), flush=True)
                else:
                    print("  %-7s %-48s %5.1fs" % (kind, iid, dt), flush=True)
        print("baked in %.1fs" % (time.time() - t0))

    # ---------------------------------------------------------------- gates + QA sheets (always on full sets)
    base = json.load(open(BASELINE, encoding="utf-8")) if os.path.exists(BASELINE) else {}
    new_base = dict(base)
    os.makedirs(a.qa, exist_ok=True)

    def check(label, ids, imgs, crop=0.0):
        nonlocal ok
        if len(imgs) < 2:
            return
        g_ok, worst, _ = gate(label, ids, imgs, LIMIT, crop)
        prev = base.get(label)
        if prev is not None and worst > prev + REGRESSION_MARGIN:
            print("SSIM REGRESSION %s: max pair %.3f > baseline %.3f + %.2f" % (label, worst, prev, REGRESSION_MARGIN))
            g_ok = False
        ok = ok and g_ok
        new_base[label] = round(worst, 3)

    def load(p):
        return Image.open(p).convert("RGBA") if os.path.exists(p) else None

    for cid, bar in bars.items():
        items = [(s["id"], load(R.skill_path(a.out, s["id"]) + ".png")) for s in bar]
        items = [(i, im) for i, im in items if im is not None]
        if items:
            qa_sheet(items, os.path.join(a.qa, "%s_%s.png" % (a.prefix, cid)), "skill")
            check("bar:" + cid, [i for i, _ in items], [im for _, im in items])
        if missing[cid]:
            print("MISSING comps for %s: %s" % (cid, ", ".join(missing[cid])))
            if a.strict:
                ok = False
    if not a.no_status:
        items = [(sid, load(R.status_path(a.out, sid) + ".png")) for sid in status_ids]
        miss = [sid for sid, im in items if im is None]
        items = [(i, im) for i, im in items if im is not None]
        if items:
            qa_sheet(items, os.path.join(a.qa, "%s_status.png" % a.prefix), "status")
            check("status", [i for i, _ in items], [im for _, im in items])
        if miss:
            print("MISSING status icons: " + ", ".join(miss))
    if not a.no_emblems:
        items = [(cid, load(R.emblem_path(a.out, cid) + ".png")) for cid in classes]
        miss = [cid for cid, im in items if im is None]
        items = [(i, im) for i, im in items if im is not None]
        if items:
            qa_sheet(items, os.path.join(a.qa, "%s_emblems.png" % a.prefix), "emblem")
            check("emblems", [i for i, _ in items], [im for _, im in items], EMBLEM_CROP)
        if miss:
            print("MISSING emblems: " + ", ".join(miss))
    print("QA sheets in " + a.qa)

    if a.update_baseline:
        # merge: re-read right before writing and update only the sets gated in this run (agents bake in parallel)
        cur = json.load(open(BASELINE, encoding="utf-8")) if os.path.exists(BASELINE) else {}
        for label, v in new_base.items():
            if base.get(label) != v or label not in cur:
                cur[label] = v
        with open(BASELINE, "w", encoding="utf-8", newline="\n") as f:
            json.dump(cur, f, indent=1, sort_keys=True)
        print("baseline updated: " + BASELINE)
    if not ok:
        print("BAKE FAILED")
        sys.exit(2)
    print("BAKE OK")


if __name__ == "__main__":
    main()

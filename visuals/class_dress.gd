class_name ClassDress
extends RefCounted
## Data-driven class "dress" registry for anime player bodies (art bible 2.5).
##
## A dress is a Dictionary describing how a class turns a VRoid CC0 base into its Glory avatar:
##   base         key of BASES (which converted VRoid model)
##   height       target standing height in metres (the whole body is scaled to it; default male 1.84 / female 1.74)
##   proportions  [leg_scale, head_scale] bone-pose scales (bible 2.1: long legs, small head)
##   rim          rim-light colour for the body materials
##   dress        material-name substring -> recolour options (see AnimeBody._dress)
##   anims        abstract anim key -> ordered clip candidates; overrides CharacterVisual.ANIME_ANIM_MAP
##   weapon_anims weapon id -> {key: clips} applied on top of `anims` while that weapon is held (umbrella forms)
##   cull         [{mat, min, max, bone?}] remove base-clothing triangles inside character-space boxes (hoods, ...)
##   face         {expression: weight} persistent VRM expression (blink, joy, angry, sorrow, fun, surprised, a..o)
##   grips        weapon id -> {kind, tilt, roll, pitch, offset, two_hand, scale} overriding the default grip
##   (costume)    the dress file's `static func build(b: AnimeBody) -> void` adds the procedural costume pieces
##                (never the weapon). No Callables/lambdas are stored in dresses: static caches holding lambdas
##                of other scripts crash Godot on exit.
##   palette      {main, second, accent} used by fallback builders and team tinting
##
## Every class with a file `res://visuals/dress/<class_id>.gd` gets that dress automatically: the file
## must `extends RefCounted` and define `static func dress() -> Dictionary`. Files whose name starts with "_"
## are helpers and are skipped. Classes without a file use FALLBACK (a recoloured base). See
## visuals/dress/README.md for the full recipe.

const DRESS_DIR := "res://visuals/dress/"
const BASE_DIR := "res://assets/characters/anime/"

## Converted VRoid CC0 bases (assets/characters/anime/, credits in assets/CREDITS.md).
const BASES: Dictionary = {
	"sakurada": {"file": "vroid_sakurada.glb", "sex": "m"},          # tousled light hair, jacket + tie
	"hairsample_male": {"file": "vroid_hairsample_male.glb", "sex": "m"},   # spiky dark hair, hoodie
	"base_male": {"file": "vroid_base_male.glb", "sex": "m"},        # buzz-cut cap hair (helmets, hoods)
	"avatarsample_d": {"file": "vroid_avatarsample_d.glb", "sex": "f"},     # dark bob, school uniform
	"avatarsample_d_darkness": {"file": "vroid_avatarsample_d_darkness.glb", "sex": "f"},   # dark gothic dress
	"avatarsample_e": {"file": "vroid_avatarsample_e.glb", "sex": "f"},     # small, brown bob, one-piece
	"avatarsample_f": {"file": "vroid_avatarsample_f.glb", "sex": "f"},     # silver short hair, one-piece
	"avatarsample_g": {"file": "vroid_avatarsample_g.glb", "sex": "f"},     # long blonde, one-piece
	"base_female": {"file": "vroid_base_female.glb", "sex": "f"},    # cap hair (helmets, hoods)
	"hairsample_female": {"file": "vroid_hairsample_female.glb", "sex": "f"},   # long hair
	"sendagaya_shino": {"file": "vroid_sendagaya_shino.glb", "sex": "f"},   # long black hair, uniform
}

const GOLD := Color("#D8B25A")
const GOLD_HI := Color("#FFE9A8")
const GOLD_SHADE := Color("#8A5A2B")
const SILVER := Color("#C9D3DE")
const LEATHER := Color("#6B3E22")

## Temporary dresses for classes without a dress file: base + 3-tone clothes palette + hair colour.
## [base, clothes [dark, mid, light], hair [dark, mid, light], iris]
const FALLBACK: Dictionary = {
	"blade_master": ["sakurada", ["#0E1E4A", "#1F5FBF", "#C9D3DE"], ["#8A5A14", "#E8B84A", "#FFF0B0"], "#7FC8FF"],
	"berserker": ["hairsample_male", ["#1A0608", "#9E1B25", "#C08850"], ["#2A0A0A", "#6A1A1A", "#B04040"], "#FF6A5A"],
	"spellblade": ["sendagaya_shino", ["#06282C", "#147A82", "#EDEDE6"], ["#E6E6EE", "#F4F4FA", "#FFFFFF"], "#6FE0E8"],
	"ghostblade": ["avatarsample_d_darkness", ["#0E0A16", "#2A1E3A", "#8A72B0"], ["#3A3050", "#C8C0E0", "#FFFFFF"], "#B48CFF"],
	"battle_mage": ["sakurada", ["#07070B", "#262632", "#ECE6D6"], ["#0B090A", "#211A1C", "#584A4C"], "#C89E8C"],
	"elementalist": ["avatarsample_f", ["#160A22", "#3A2350", "#B08AD0"], ["#B0B8D0", "#E8ECF6", "#FFFFFF"], "#FF9A4A"],
	"witch": ["hairsample_male", ["#0E1440", "#23379A", "#6F86E0"], ["#5D6A86", "#B9C4D8", "#F4F8FF"], "#C8D4FF"],
	"summoner": ["avatarsample_e", ["#0C2E28", "#2F8F7A", "#F2EAD0"], ["#3A2A14", "#7A5A30", "#D0A870"], "#7CF0A0"],
	"sharpshooter": ["hairsample_female", ["#1E120A", "#5A3B28", "#B08A5A"], ["#3A1408", "#8A3A1A", "#D07A4A"], "#E0A050"],
	"spitfire": ["avatarsample_d", ["#1E200E", "#5B6235", "#A4502A"], ["#1A1410", "#3A2A20", "#7A5A40"], "#E0A050"],
	"launcher": ["avatarsample_g", ["#7A3A12", "#F08A24", "#F2C230"], ["#8A3A12", "#E0782C", "#FFD27A"], "#BFE6FF"],
	"mechanic": ["avatarsample_f", ["#1C2026", "#4A525C", "#FF8A1F"], ["#3A2A1A", "#8A6A4A", "#E0C090"], "#FF8A1F"],
	"striker": ["base_male", ["#120808", "#B3262A", "#ECE6DA"], ["#200A08", "#5A1A10", "#A04030"], "#E04030"],
	"qi_master": ["sendagaya_shino", ["#3A6A9A", "#7FC4FF", "#F4F8FF"], ["#0A0E1A", "#1A2238", "#4A5A80"], "#7FC4FF"],
	"grappler": ["base_male", ["#121A36", "#2B3A6E", "#F0EEE6"], ["#14100C", "#2A2018", "#5A4A3A"], "#8AA0E0"],
	"brawler": ["hairsample_male", ["#1E0E26", "#5A2E6E", "#D8B040"], ["#3A2A08", "#C89A20", "#FFE080"], "#D8B040"],
	"assassin": ["avatarsample_d_darkness", ["#0E0E12", "#2A2A30", "#7A1F33"], ["#100A0E", "#2A1A20", "#6A3A48"], "#E04060"],
	"ninja": ["sendagaya_shino", ["#080C1E", "#1A2448", "#C8202A"], ["#06060C", "#14141E", "#3A3A50"], "#E04050"],
	"thief": ["avatarsample_e", ["#0E1E16", "#1F3B2D", "#C8A878"], ["#2A1A0C", "#6A4A28", "#B08A58"], "#A0E070"],
	"warlock": ["avatarsample_f", ["#08080A", "#1C1C22", "#7CFF6B"], ["#1A2A1A", "#7CC070", "#D8FFD0"], "#7CFF6B"],
	"knight": ["base_male", ["#3A4250", "#8E9AAB", "#E8EEF6"], ["#2A2018", "#5A4A38", "#9A8468"], "#8AB0FF"],
	"exorcist": ["avatarsample_d", ["#08080A", "#1A1A1E", "#C8202A"], ["#C8C8D0", "#E8E8F0", "#FFFFFF"], "#E04040"],
	"cleric": ["sakurada", ["#141A3A", "#F2F0EA", "#FFFFFF"], ["#2A2420", "#5A4E44", "#A89480"], "#8AB0FF"],
	"paladin": ["hairsample_female", ["#4A7AB0", "#F2F0EA", "#FFFFFF"], ["#A07A30", "#E8C870", "#FFF4C0"], "#7FC8FF"],
	"unspecialized": ["hairsample_male", ["#0E1226", "#1E2440", "#DCE2EA"], ["#0A0808", "#1E1816", "#4A3E38"], "#B08A70"],
}

static var _cache: Dictionary = {}
static var _scanned := false
static var _files: Dictionary = {}       # class_id -> script path


static func _scan() -> void:
	if _scanned:
		return
	_scanned = true
	var d := DirAccess.open(DRESS_DIR)
	if d == null:
		return
	for f in d.get_files():
		# exported builds list "x.gd.remap" / "x.gdc"
		var fn := f.trim_suffix(".remap")
		if not (fn.ends_with(".gd") or fn.ends_with(".gdc")) or fn.begins_with("_"):
			continue
		var id := fn.get_basename()
		_files[id] = DRESS_DIR + id + ".gd"


## Class ids that have an anime dress (every class of the roster through FALLBACK, plus dress files).
static func class_ids() -> Array[String]:
	_scan()
	var out: Array[String] = []
	for k in FALLBACK.keys():
		out.append(k)
	for k in _files.keys():
		if not k in out:
			out.append(k)
	return out


static func has_class(class_id: String) -> bool:
	_scan()
	return FALLBACK.has(class_id) or _files.has(class_id)


## True when the class has its own hand-built dress file (not the temporary recolour).
static func is_finished(class_id: String) -> bool:
	_scan()
	return _files.has(class_id)


## Resolved dress for a class: dress file (if any) on top of the fallback defaults; `model` is filled in.
static func get_dress(class_id: String) -> Dictionary:
	if _cache.has(class_id):
		return _cache[class_id]
	_scan()
	var d: Dictionary = fallback(class_id)
	if _files.has(class_id):
		var scr := load(_files[class_id]) as Script
		if scr == null or not scr.can_instantiate():
			push_error("ClassDress: cannot load %s, using the fallback dress" % String(_files[class_id]))
		else:
			var custom: Variant = scr.call("dress")
			if custom is Dictionary:
				for k in (custom as Dictionary):
					if k != "build":
						d[k] = custom[k]
				d.erase("fallback")
				if _has_static(scr, "build"):
					d["script"] = scr
			else:
				push_error("ClassDress: %s.dress() must return a Dictionary" % class_id)
	d["id"] = class_id
	var base: Dictionary = BASES.get(String(d.get("base", "sakurada")), BASES["sakurada"])
	d["model"] = BASE_DIR + String(base["file"])
	d["sex"] = base["sex"]
	if not d.has("height"):
		d["height"] = 1.84 if base["sex"] == "m" else 1.74
	_cache[class_id] = d
	return d


## Temporary recolour dress (used as the defaults under every dress file too).
static func fallback(class_id: String) -> Dictionary:
	var f: Array = FALLBACK.get(class_id, FALLBACK["unspecialized"])
	var cl: Array = f[1]
	var hr: Array = f[2]
	var clothes := {"map": [Color(cl[0]), Color(cl[1]), Color(cl[2])], "contrast": 1.3}
	var lower := {"map": [Color(cl[0]).darkened(0.3), Color(cl[0]), Color(cl[1])], "contrast": 1.2}
	return {
		"base": f[0],
		"proportions": [1.06, 0.95],
		"palette": {"main": Color(cl[1]), "second": Color(cl[0]), "accent": Color(cl[2])},
		"dress": {
			"Tops": clothes, "Onepice": clothes, "Accessory": {"map": [Color(cl[0]), Color(cl[2]), Color(cl[2]).lightened(0.4)], "contrast": 1.1},
			"Bottoms": lower,
			"Shoes": {"map": [Color("#120C08"), Color("#3B2416"), Color("#9A7440")], "contrast": 1.2},
			"HAIR": {"map": [Color(hr[0]), Color(hr[1]), Color(hr[2])], "contrast": 1.1, "line": 1.7},
			"EyeIris": {"iris": Color(f[3]).lightened(0.2)},
		},
		"fallback": true,
	}


static func _has_static(scr: Script, method: String) -> bool:
	for m: Dictionary in scr.get_script_method_list():
		if String(m.get("name", "")) == method:
			return true
	return false


## Runs the costume builder of a resolved dress (AnimeBody calls this after the materials are dressed).
static func build_costume(b: AnimeBody, d: Dictionary) -> void:
	if d.has("script"):
		(d["script"] as Script).call("build", b)
	elif d.get("fallback", false):
		_fallback_build(b)


## Minimal costume for unfinished classes: a belt with a gold buckle so the waist reads, nothing else.
static func _fallback_build(b: AnimeBody) -> void:
	var hips := b.bone_pos("Hips")
	b.attach("Hips", AnimeGear.mi(AnimeGear.lathe([Vector2(0.15, -0.022), Vector2(0.155, 0.022)], 24, 1.0, 0.82), AnimeGear.toon(LEATHER)), Transform3D(Basis(), hips + Vector3(0, 0.02, 0)))
	b.attach("Hips", AnimeGear.mi(AnimeGear.extrude(diamond(0.035, 0.04), 0.02, 0.004), AnimeGear.gold()), Transform3D(Basis(), hips + Vector3(0, 0.02, 0.125)))


# ===================================================================== grips
## Grip transforms are T-pose character-space transforms of the weapon node attached to RightHand / LeftHand.
## WeaponFactory convention: origin = fist, blades/shafts along +Y, firearms muzzle along +X with +Y up.

## Melee / pole grip: shaft along local +Y -> character +Z (forward), tilted up by `tilt_deg`, then turned
## toward the body by `yaw_deg` (T-pose space: a shaft pointing at the body stands upright once the arm hangs).
static func grip_xf(b: AnimeBody, left := false, tilt_deg := 0.0, roll_deg := 0.0, yaw_deg := 0.0) -> Transform3D:
	var h := b.bone_pos("LeftHand" if left else "RightHand")
	var bs := Basis(Vector3.RIGHT, PI / 2.0)
	bs = Basis(Vector3.RIGHT, deg_to_rad(-tilt_deg)) * bs
	bs = Basis(Vector3.FORWARD, deg_to_rad(roll_deg)) * bs
	bs = Basis(Vector3.UP, deg_to_rad(-yaw_deg if left else yaw_deg)) * bs
	return Transform3D(bs, h + Vector3(0.075 if left else -0.075, -0.03, 0.0))


## Firearm / fist-weapon grip: local +X (muzzle, knuckles) along the forearm, local +Y up. `roll_deg` turns the
## weapon about its own +X (the forearm axis) - e.g. 180 on one hand so a tonfa rod sits on the pinky side of both
## forearms (the right-hand basis is the left one turned 180 deg about Y, which swaps the thumb/pinky sides).
static func gun_xf(b: AnimeBody, left := false, pitch_deg := 0.0, offset := Vector3(0.06, -0.035, 0.0), roll_deg := 0.0) -> Transform3D:
	var h := b.bone_pos("LeftHand" if left else "RightHand")
	var bs := Basis(Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)) if left else Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1))
	bs = Basis(Vector3(0, 0, 1), deg_to_rad(-pitch_deg if left else pitch_deg)) * bs
	if roll_deg != 0.0:
		bs = bs * Basis(Vector3.RIGHT, deg_to_rad(roll_deg))
	return Transform3D(bs, h + Vector3(offset.x if left else -offset.x, offset.y, offset.z))


## Shield on the back of the left forearm: shield face (+Z) outward, its long axis (+Y) along the forearm.
static func shield_xf(b: AnimeBody) -> Transform3D:
	var lo := b.bone_pos("LeftLowerArm")
	var h := b.bone_pos("LeftHand")
	return Transform3D(Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)), lo.lerp(h, 0.55) + Vector3(0, 0.06, 0))


# ===================================================================== shared costume builders

static func diamond(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, -h), Vector2(w, 0), Vector2(0, h), Vector2(-w, 0)])


static func flame() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-0.03, 0), Vector2(0.03, 0), Vector2(0.02, 0.03), Vector2(0.035, 0.06), Vector2(0.008, 0.045), Vector2(0.0, 0.085), Vector2(-0.012, 0.04), Vector2(-0.032, 0.055), Vector2(-0.02, 0.025)])


## A small V of swept wing blades (original crest, not the show's).
static func wing_crest(s := 1.0) -> PackedVector2Array:
	var p := PackedVector2Array([Vector2(0, -0.05), Vector2(0.03, -0.01), Vector2(0.11, 0.035), Vector2(0.06, 0.005), Vector2(0.09, 0.045),
		Vector2(0.03, 0.02), Vector2(0, 0.06), Vector2(-0.03, 0.02), Vector2(-0.09, 0.045), Vector2(-0.06, 0.005), Vector2(-0.11, 0.035), Vector2(-0.03, -0.01)])
	for i in p.size():
		p[i] *= s
	return p


static func wrap(n: Node3D) -> Node3D:
	var w := Node3D.new()
	w.add_child(n)
	return w


## Lathe ring around a bone (belts, cuffs, bands). y0/y1 relative to `center`.
static func band(b: AnimeBody, bone: String, center: Vector3, r: float, y0: float, y1: float, mat: Material, sz := 1.0, seg := 20) -> MeshInstance3D:
	var m := AnimeGear.mi(AnimeGear.lathe([Vector2(r, y0), Vector2(r * 1.02, y1)], seg, 1.0, sz), mat)
	b.attach(bone, m, Transform3D(Basis(), center))
	return m


## Limb sleeve (forearm guard, greave, boot shaft) from bone `from` toward bone `to`. profile radii along t.
static func limb_guard(b: AnimeBody, bone: String, to_bone: String, radii: Array, t0: float, t1: float, mat: Material, flare_mat: Material = null, seg := 14) -> void:
	var p0 := b.bone_pos(bone)
	var p1 := b.bone_pos(to_bone)
	var axis := (p1 - p0)
	var L := axis.length()
	var dir := axis / L
	var prof: Array = []
	for i in radii.size():
		var t := lerpf(t0, t1, float(i) / (radii.size() - 1))
		prof.append(Vector2(float(radii[i]), t * L))
	var bs := Basis(Quaternion(Vector3.UP, dir))
	b.attach(bone, AnimeGear.mi(AnimeGear.lathe(prof, seg), mat), Transform3D(bs, p0))
	if flare_mat:
		var r_end: float = radii[radii.size() - 1]
		b.attach(bone, AnimeGear.mi(AnimeGear.lathe([Vector2(r_end * 1.02, t1 * L - 0.012), Vector2(r_end * 1.08, t1 * L + 0.006)], seg), flare_mat), Transform3D(bs, p0))


## Coat panel hanging from the waist (Battle Mage style). back = rear panel, else front-side panel.
static func coat_panel(b: AnimeBody, bone: String, side: float, back: bool, mat: Material, trim: Material, bottom := 0.30, angle_back := 155.0, angle_front := 55.0, flare := 0.55) -> void:
	var hips := b.bone_pos("Hips")
	var pts: Array = []
	var w: Array = []
	var sides: Array = []
	var top := hips.y + 0.03
	var steps := 7
	for i in steps:
		var t := float(i) / (steps - 1)
		var y := lerpf(top, bottom, t)
		var fl := 1.0 + t * flare
		var ang := deg_to_rad(angle_back if back else angle_front)
		var rad := 0.165 * fl
		var x := side * sin(ang) * rad
		var z := cos(ang) * rad * 0.85 - (t * t * 0.08 if back else 0.0)
		pts.append(Vector3(x, y, z))
		w.append(lerpf(0.22, 0.34, t) if back else lerpf(0.18, 0.27, t))
		sides.append(Vector3(cos(ang) * side, 0, -sin(ang)))
	b.attach(bone, AnimeGear.mi(AnimeGear.ribbon(pts, w, sides, 0.014), mat), Transform3D.IDENTITY)
	var hp: Array = []
	var hw: Array = []
	var hs: Array = []
	var p_last: Vector3 = pts[steps - 1]
	var s_last: Vector3 = sides[steps - 1]
	var half: float = float(w[steps - 1]) * 0.5
	for i in 5:
		var t := float(i) / 4.0
		hp.append(p_last + s_last * lerpf(-half, half, t) + Vector3(0, 0.01, 0))
		hw.append(0.035)
		hs.append(Vector3.UP)
	b.attach(bone, AnimeGear.mi(AnimeGear.ribbon(hp, hw, hs, 0.02), trim), Transform3D.IDENTITY)


## Swept plate pauldron (2 layers + gold rims + fin). side -1 = right arm, +1 = left arm.
static func pauldron(b: AnimeBody, side: float, plate: Material, trim: Material, big := 1.0, layers := 2, fin := true) -> void:
	var arm := "RightUpperArm" if side < 0 else "LeftUpperArm"
	var sh := b.bone_pos(arm)
	for k in layers:
		var r := (0.085 - k * 0.012) * big
		var prof := [Vector2(0.0, r * 0.62), Vector2(r * 0.62, r * 0.55), Vector2(r * 0.95, r * 0.18), Vector2(r * 1.02, -r * 0.22)]
		var bs := Basis(Vector3.FORWARD, side * deg_to_rad(-30.0 - k * 14.0))
		var at := sh + Vector3(side * (0.035 + k * 0.05), 0.035 - k * 0.035, -0.005)
		b.attach(arm, AnimeGear.mi(AnimeGear.lathe(prof, 7, 1.0, 1.3), plate), Transform3D(bs, at))
		b.attach(arm, AnimeGear.mi(AnimeGear.lathe([Vector2(r * 1.02, -r * 0.24), Vector2(r * 1.08, -r * 0.1)], 7, 1.0, 1.3), trim), Transform3D(bs, at))
	if fin:
		var f := AnimeGear.mi(AnimeGear.extrude(PackedVector2Array([Vector2(0, 0), Vector2(0.03, 0.012), Vector2(0.13, 0.07), Vector2(0.045, -0.005), Vector2(0.012, -0.03)]), 0.01, 0.0), trim)
		b.attach(arm, f, Transform3D(Basis(Vector3.UP, side * -PI * 0.5 + PI) * Basis(Vector3.FORWARD, 0.25), sh + Vector3(side * 0.06, 0.085 * big, -0.05)))


## Cloth strip simulated at runtime (scarf, cape, tails): see AnimeCloth.
static func cloth(b: AnimeBody, bone: String, anchor_xf: Transform3D, opts: Dictionary) -> AnimeCloth:
	var c := AnimeCloth.new(opts)
	var a := Node3D.new()
	a.name = "ClothAnchor"
	b.attach(bone, a, anchor_xf)
	a.add_child(c)
	return c

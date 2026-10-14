extends RefCounted
## Shared UI look (bible section 6, approved look-dev slice): fonts, palette, theme, small style boxes, the status
## table, icon loading (painted icons with procedural fallback) and formatting helpers.
## Used through `const HudStyle := preload("res://ui/hud_style.gd")` by every HUD widget and menu.

const THEME_PATH: String = "res://ui/theme.tres"
const FONT_NAMES: PackedStringArray = ["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "SimHei"]

# fonts (all SIL OFL 1.1, see assets/fonts/*/OFL.txt and assets/CREDITS.md)
const F_SANS: String = "res://assets/fonts/notosanssc/NotoSansSC[wght].ttf"
const F_BRUSH: String = "res://assets/fonts/mashanzheng/MaShanZheng-Regular.ttf"
const F_NUM: String = "res://assets/fonts/teko/Teko[wght].ttf"
const F_CRIT: String = "res://assets/fonts/russoone/RussoOne-Regular.ttf"
const F_TECH: String = "res://assets/fonts/orbitron/Orbitron[wght].ttf"

# icons (ICONS track); missing files fall back to the procedural icons in hud_icons.gd
const ICON_SKILLS: String = "res://assets/icons/skills/"
const ICON_STATUS: String = "res://assets/icons/status/"
const ICON_CLASS: String = "res://assets/icons/class/"

# ------------------------------------------------------------------ palette (bible section 8, UI)
const UI_PANEL: Color = Color(0.055, 0.1, 0.165, 0.88)      # #0E1A2A
const UI_HOLO: Color = Color(0.078, 0.094, 0.125, 0.74)     # #141820
const UI_GOLD: Color = Color("#D8B25A")
const UI_GOLD_HI: Color = Color("#FFE9A8")
const UI_GOLD_SH: Color = Color("#8A5A2B")
const UI_CRYSTAL: Color = Color("#3FA9FF")
const UI_CYAN: Color = Color("#4FD8FF")
const UI_STEEL: Color = Color("#9AA6B8")
const UI_INK: Color = Color(0.02, 0.03, 0.07)
const UI_NEON_A: Color = Color("#C23BFF")
const UI_NEON_B: Color = Color("#FF3B8A")
const C_BUFF: Color = Color("#7CD86B")
const C_DEBUFF: Color = Color("#E0323C")
const C_CC: Color = Color("#A85CFF")
const C_CRIT: Color = Color("#FFC43A")

# legacy names (kept for every widget and other tracks), retuned to the bible palette
const C_PANEL: Color = UI_PANEL
const C_PANEL_SOFT: Color = Color(0.055, 0.1, 0.165, 0.7)
const C_BORDER: Color = UI_GOLD
const C_BORDER_DIM: Color = Color(0.85, 0.7, 0.36, 0.45)
const C_TEXT: Color = Color("#F4F6FA")
const C_TEXT_DIM: Color = Color("#9AA6B8")
const C_GOLD: Color = Color("#FFD36A")
const C_HP: Color = Color("#E0323C")
const C_HP_LOW: Color = Color("#FF5A3A")
const C_HP_ENEMY: Color = Color("#E0323C")
const C_HP_ALLY: Color = Color("#3FCF6A")
const C_MP: Color = Color("#2F7BFF")
const C_SHIELD: Color = Color(0.92, 0.96, 1.0)
const C_TRAIL: Color = Color("#8A1A22")
const C_ALLY: Color = Color("#2F7BFF")
const C_ENEMY: Color = Color("#FF3B4A")
const C_SELF: Color = Color("#FFD36A")
const C_BOSS: Color = Color("#FF8A1F")
const TEAM_NAMES: Array[String] = ["蓝队 Blue", "红队 Red", "绿队 Green", "金队 Gold"]
const TEAM_COLORS: Array[Color] = [Color("#2F7BFF"), Color("#FF3B4A"), Color(0.4, 0.9, 0.45), Color(1.0, 0.82, 0.3)]

const GROUP_COLORS: Dictionary = {
	"swordsman": Color(0.55, 0.78, 1.0), "mage": Color(0.78, 0.55, 1.0), "gunner": Color(1.0, 0.72, 0.32),
	"fighter": Color(1.0, 0.45, 0.35), "nightwalker": Color(0.62, 0.45, 0.85), "priest": Color(1.0, 0.92, 0.55),
	"unspecialized": Color(0.85, 0.85, 0.85),
}

## Status table in StatusSet.IDS / status_mask bit order (ARCHITECTURE §4.2, + wave3 bits 25/26).
## [glyph, name_cn, name_en, color, desc_cn, desc_en]
const STATUS_INFO: Array = [
	["晕", "眩晕", "Stun", Color(1.0, 0.85, 0.2), "无法行动", "Cannot act"],
	["冰", "冰冻", "Freeze", Color(0.45, 0.85, 1.0), "被冰封，无法行动", "Frozen solid, cannot act"],
	["定", "定身", "Root", Color(0.6, 0.45, 0.25), "无法移动", "Cannot move"],
	["默", "沉默", "Silence", Color(0.6, 0.5, 0.85), "无法释放技能", "Cannot cast skills"],
	["睡", "睡眠", "Sleep", Color(0.55, 0.6, 0.95), "无法行动，受伤醒来", "Cannot act; wakes on damage"],
	["盲", "致盲", "Blind", Color(0.45, 0.45, 0.5), "攻击有50%几率落空", "Attacks miss 50% of the time"],
	["乱", "混乱", "Confusion", Color(0.95, 0.5, 0.85), "移动方向颠倒", "Movement inverted"],
	["嘲", "嘲讽", "Taunted", Color(1.0, 0.35, 0.2), "被迫攻击嘲讽者", "Forced to attack the taunter"],
	["缓", "减速", "Slow", Color(0.4, 0.65, 0.9), "移动速度降低", "Movement speed reduced"],
	["速", "加速", "Haste", Color(0.4, 1.0, 0.7), "移动速度提高", "Movement speed increased"],
	["血", "流血", "Bleed", Color(0.85, 0.1, 0.15), "持续受到物理伤害", "Taking damage over time"],
	["毒", "中毒", "Poison", Color(0.45, 0.9, 0.2), "持续受到毒素伤害", "Taking poison damage over time"],
	["燃", "灼烧", "Burn", Color(1.0, 0.5, 0.1), "持续受到火焰伤害", "Taking fire damage over time"],
	["重", "负重", "Weight", Color(0.55, 0.5, 0.45), "移动与跳跃降低", "Movement and jump reduced"],
	["霸", "霸体", "Super Armor", Color(1.0, 0.75, 0.15), "免疫硬直、浮空与击退", "Immune to hitstun, launch and knockback"],
	["隐", "隐身", "Stealth", Color(0.5, 0.45, 0.7), "敌人无法看见", "Invisible to enemies"],
	["无", "无敌", "Invulnerable", Color(1.0, 1.0, 0.85), "免疫所有伤害", "Immune to all damage"],
	["挡", "格挡", "Block", Color(0.7, 0.75, 0.85), "正面物理伤害降低", "Frontal physical damage reduced"],
	["攻", "攻击提升", "Attack Up", Color(1.0, 0.45, 0.3), "物理与法术攻击提高", "Physical and magic attack increased"],
	["防", "防御提升", "Defense Up", Color(0.4, 0.7, 1.0), "防御力提高", "Defense increased"],
	["破", "破防", "Defense Down", Color(0.75, 0.3, 0.3), "防御力降低", "Defense reduced"],
	["魔", "法攻提升", "Magic Up", Color(0.75, 0.45, 1.0), "法术攻击提高", "Magic attack increased"],
	["回", "回复", "Regen", Color(0.4, 1.0, 0.45), "持续回复生命", "Restoring HP over time"],
	["盾", "护盾", "Shield", Color(0.85, 0.95, 1.0), "吸收伤害", "Absorbs damage"],
	["印", "印记", "Mark", Color(1.0, 0.25, 0.4), "被标记", "Marked"],
	["弱", "攻击降低", "Attack Down", Color(0.75, 0.35, 0.3), "物理与法术攻击降低", "Physical and magic attack reduced"],
	["迟", "施法减速", "Cast Slow", Color(0.55, 0.5, 0.8), "施法速度降低", "Cast speed reduced"],
]
const STATUS_IDS: Array[String] = ["stun", "freeze", "root", "silence", "sleep", "blind", "confusion", "taunted",
	"slow", "haste", "bleed", "poison", "burn", "weight", "super_armor", "stealth", "invuln", "block", "atk_up",
	"def_up", "def_down", "matk_up", "regen", "shield", "mark", "atk_down", "cast_slow"]
const NEGATIVE_BITS: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 20, 24, 25, 26]
## Crowd control (purple frame, loudest).
const CC_BITS: Array[int] = [0, 1, 2, 3, 4, 6, 7]

const KEY_LABELS: Array[String] = ["LMB", "RMB", "Q", "E", "R", "F", "1", "2"]
const KEY_LABELS_CN: Array[String] = ["左键", "右键", "Q", "E", "R", "F", "1", "2"]

static var _fonts: Dictionary = {}
static var _theme: Theme = null
static var _tex_cache: Dictionary = {}


# ------------------------------------------------------------------ fonts
static func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var r: Variant = load(path)
		if r is Font:
			return r
	return null


static func _variant(base: Font, weight: int, fallback: Font = null) -> Font:
	var v := FontVariation.new()
	v.base_font = base
	if weight > 0:
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	if fallback != null:
		v.fallbacks = [fallback]
	return v


static func _system(weight: int) -> Font:
	var f := SystemFont.new()
	f.font_names = FONT_NAMES
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	return f


## Body text: Noto Sans SC 500 (bold = 800).
static func font(bold: bool = false) -> Font:
	return sans(800 if bold else 500)


static func sans(weight: int = 500) -> Font:
	var key := "sans%d" % weight
	if not _fonts.has(key):
		var base := _load_font(F_SANS)
		_fonts[key] = _variant(base, weight) if base != null else _system(weight)
	return _fonts[key]


## Teko: condensed numerals (timer, HP numbers, cooldowns).
static func num(weight: int = 600) -> Font:
	var key := "num%d" % weight
	if not _fonts.has(key):
		var base := _load_font(F_NUM)
		_fonts[key] = _variant(base, weight, sans(700)) if base != null else sans(800)
	return _fonts[key]


## Russo One: crits, combo counter, big broadcast digits.
static func crit() -> Font:
	if not _fonts.has("crit"):
		var base := _load_font(F_CRIT)
		_fonts["crit"] = _variant(base, 0, sans(800)) if base != null else sans(800)
	return _fonts["crit"]


## Ma Shan Zheng: brush calligraphy (skill call-outs, titles, the 荣耀 crest).
static func brush() -> Font:
	if not _fonts.has("brush"):
		var base := _load_font(F_BRUSH)
		_fonts["brush"] = _variant(base, 0, sans(800)) if base != null else sans(800)
	return _fonts["brush"]


## Orbitron: techy Latin captions (league broadcast).
static func tech(weight: int = 700) -> Font:
	var key := "tech%d" % weight
	if not _fonts.has(key):
		var base := _load_font(F_TECH)
		_fonts[key] = _variant(base, weight, sans(700)) if base != null else sans(700)
	return _fonts[key]


# ------------------------------------------------------------------ theme
## res://ui/theme.tres (navy glass + gold, built by ui/ui_theme.gd) with HUD label tweaks, else built in code.
static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = null
	if ResourceLoader.exists(THEME_PATH):
		var r: Variant = load(THEME_PATH)
		if r is Theme:
			t = (r as Theme).duplicate() as Theme
	if t == null:
		t = (load("res://ui/ui_theme.gd") as Script).call("build")
	# HUD readability over the 3D scene: outlined labels.
	t.set_color("font_outline_color", "Label", Color(0.01, 0.02, 0.05, 0.92))
	t.set_constant("outline_size", "Label", 4)
	t.set_color("font_color", "Label", C_TEXT)
	t.set_color("font_outline_color", "RichTextLabel", Color(0.01, 0.02, 0.05, 0.92))
	t.set_constant("outline_size", "RichTextLabel", 3)
	_theme = t
	return t


## Flat rounded style box (kept for small chips); panels use GloryStyleBox.
static func panel(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 8, border_w: int = 1,
		margin: float = 8.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin + 2.0
	s.content_margin_right = margin + 2.0
	s.content_margin_top = margin
	s.content_margin_bottom = margin
	s.anti_aliasing = true
	return s


## Navy-glass gold-filigree panel style box (see ui/glory_stylebox.gd for kinds).
static func glory(kind: String = "panel", margin: float = 12.0, accent: Color = Color(0, 0, 0, 0), gems: bool = true) -> StyleBox:
	var sb: StyleBox = (load("res://ui/glory_stylebox.gd") as Script).new()
	sb.set("kind", kind)
	sb.set("gems", gems)
	if accent.a > 0.0:
		sb.set("accent", accent)
	sb.content_margin_left = margin + 2.0
	sb.content_margin_right = margin + 2.0
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	return sb


static func make_label(text: String, size: int = 16, color: Color = C_TEXT, bold: bool = false,
		outline: int = 4) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(bold))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.05, 0.92))
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Label in an explicit font (num / crit / brush / tech).
static func make_label_f(text: String, f: Font, size: int, color: Color = C_TEXT, outline: int = 4) -> Label:
	var l := make_label(text, size, color, false, outline)
	l.add_theme_font_override("font", f)
	return l


# ------------------------------------------------------------------ icons
static func _tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		var r: Variant = load(path)
		if r is Texture2D:
			t = r
	if t == null and FileAccess.file_exists(path):
		# freshly generated, not imported yet
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			t = ImageTexture.create_from_image(img)
	_tex_cache[path] = t
	return t


## Painted skill icon res://assets/icons/skills/<id with . -> __>.png (null -> caller draws the procedural one).
static func skill_icon(s: SkillDef) -> Texture2D:
	if s == null:
		return null
	return _tex(ICON_SKILLS + str(s.id).replace(".", "__") + ".png")


## Painted status icon for a StatusSet bit (null -> procedural badge).
static func status_icon(bit: int) -> Texture2D:
	if bit < 0 or bit >= STATUS_IDS.size():
		return null
	return _tex(ICON_STATUS + STATUS_IDS[bit] + ".png")


## Class emblem res://assets/icons/class/<class_id>.png (null -> procedural crest).
static func class_emblem(class_id: String) -> Texture2D:
	if class_id == "":
		return null
	return _tex(ICON_CLASS + class_id + ".png")


## Cooldown copy of an icon: 45% value, desaturated (drawn inside the radial wipe).
static func icon_cd(t: Texture2D) -> Texture2D:
	if t == null:
		return null
	var key := "cd:" + str(t.get_rid().get_id())
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := t.get_image()
	if img == null or img.is_empty():
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.adjust_bcs(0.45, 1.0, 0.0)
	var out := ImageTexture.create_from_image(img)
	_tex_cache[key] = out
	return out


static func clear_icon_cache() -> void:
	_tex_cache.clear()


## Drops every cached font / theme / texture (call when the last UI goes away, e.g. at quit) so no resource
## outlives the scene tree. Everything is rebuilt lazily on the next use.
static func release() -> void:
	_tex_cache.clear()
	_fonts.clear()
	_theme = null


# ------------------------------------------------------------------ fighter helpers
static func class_color(f: Fighter) -> Color:
	if f == null or not is_instance_valid(f):
		return C_TEXT
	if f.kind == "boss":
		return C_BOSS
	if f.kit != null:
		return f.kit.tint.lerp(Color.WHITE, 0.25)
	var t: Variant = f.mob_def.get("tint", null)
	if t is Color:
		return (t as Color).lerp(Color.WHITE, 0.3)
	return Color(0.85, 0.82, 0.78)


static func group_color(f: Fighter) -> Color:
	if f != null and f.kit != null:
		return GROUP_COLORS.get(f.kit.group_id, C_TEXT)
	return C_TEXT


## "剑客 Blade Master" / mob "骷髅兵 Skeleton".
static func class_name_of(f: Fighter) -> String:
	if f == null:
		return ""
	if f.kit != null:
		return "%s %s" % [f.kit.name_cn, f.kit.name_en]
	if not f.mob_def.is_empty():
		var cn := str(f.mob_def.get("name_cn", ""))
		var en := str(f.mob_def.get("name_en", f.mob_id))
		return (cn + " " + en).strip_edges()
	return ""


static func class_cn(f: Fighter) -> String:
	if f == null:
		return ""
	if f.kit != null:
		return f.kit.name_cn
	return str(f.mob_def.get("name_cn", ""))


static func group_name_of(f: Fighter) -> String:
	if f == null or f.kit == null:
		if f != null and f.kind == "boss":
			return "首领 Boss"
		if f != null and f.kind == "summon":
			return "召唤物 Summon"
		if f != null and f.kind == "mob":
			return "怪物 Monster"
		return ""
	return ("%s %s" % [f.kit.group_cn, f.kit.group_en]).strip_edges()


## One glyph used for minimal class badges.
static func class_glyph(f: Fighter) -> String:
	var cn := class_cn(f)
	if cn != "":
		return cn.substr(0, 1)
	if f != null and f.display_name != "":
		return f.display_name.substr(0, 1)
	return "?"


static func team_color(team: int) -> Color:
	return TEAM_COLORS[posmod(team, TEAM_COLORS.size())]


static func team_name(team: int) -> String:
	return TEAM_NAMES[posmod(team, TEAM_NAMES.size())]


static func status_tooltip(bit: int) -> String:
	if bit < 0 or bit >= STATUS_INFO.size():
		return ""
	var s: Array = STATUS_INFO[bit]
	var kind := "控制 CC" if CC_BITS.has(bit) else ("减益 Debuff" if NEGATIVE_BITS.has(bit) else "增益 Buff")
	return "%s %s  [%s]\n%s  %s" % [s[1], s[2], kind, s[4], s[5]]


static func is_negative_bit(bit: int) -> bool:
	return NEGATIVE_BITS.has(bit)


## Polarity frame colour: CC purple, debuff red, buff green-gold.
static func status_frame_color(bit: int) -> Color:
	if CC_BITS.has(bit):
		return C_CC
	if NEGATIVE_BITS.has(bit):
		return C_DEBUFF
	return C_BUFF


static func fmt_time(seconds: float) -> String:
	var s := maxi(0, int(ceil(seconds)))
	return "%02d:%02d" % [s / 60, s % 60]


static func fmt_num(v: float) -> String:
	var n := int(round(v))
	if absi(n) >= 10000000:
		return "%.1fM" % (n / 1000000.0)
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func hex(c: Color) -> String:
	return c.to_html(false)

extends RefCounted
## Shared HUD look: fonts, theme, palette, style boxes, status table, small formatting helpers.
## Used through `const HudStyle := preload("res://ui/hud_style.gd")` by every HUD widget.

const FONT_NAMES: PackedStringArray = ["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "SimHei"]
const THEME_PATH: String = "res://ui/theme.tres"

# ------------------------------------------------------------------ palette
const C_PANEL: Color = Color(0.055, 0.07, 0.11, 0.82)
const C_PANEL_SOFT: Color = Color(0.05, 0.065, 0.10, 0.62)
const C_BORDER: Color = Color(0.85, 0.72, 0.42, 0.85)       # gold trim
const C_BORDER_DIM: Color = Color(0.55, 0.62, 0.78, 0.45)
const C_TEXT: Color = Color(0.96, 0.95, 0.92)
const C_TEXT_DIM: Color = Color(0.70, 0.74, 0.82)
const C_GOLD: Color = Color(1.0, 0.82, 0.36)
const C_HP: Color = Color(0.26, 0.86, 0.38)
const C_HP_LOW: Color = Color(0.95, 0.26, 0.22)
const C_HP_ENEMY: Color = Color(0.92, 0.25, 0.25)
const C_MP: Color = Color(0.25, 0.55, 1.0)
const C_SHIELD: Color = Color(0.92, 0.96, 1.0)
const C_TRAIL: Color = Color(1.0, 0.92, 0.6)
const C_ALLY: Color = Color(0.36, 0.72, 1.0)
const C_ENEMY: Color = Color(1.0, 0.36, 0.32)
const C_SELF: Color = Color(0.45, 1.0, 0.55)
const C_BOSS: Color = Color(1.0, 0.62, 0.18)
const TEAM_NAMES: Array[String] = ["蓝队 Blue", "红队 Red", "绿队 Green", "金队 Gold"]
const TEAM_COLORS: Array[Color] = [Color(0.36, 0.62, 1.0), Color(1.0, 0.38, 0.32), Color(0.4, 0.9, 0.45), Color(1.0, 0.82, 0.3)]

const GROUP_COLORS: Dictionary = {
	"swordsman": Color(0.55, 0.78, 1.0), "mage": Color(0.78, 0.55, 1.0), "gunner": Color(1.0, 0.72, 0.32),
	"fighter": Color(1.0, 0.45, 0.35), "nightwalker": Color(0.62, 0.45, 0.85), "priest": Color(1.0, 0.92, 0.55),
	"unspecialized": Color(0.85, 0.85, 0.85),
}

## Status table in StatusSet.IDS / status_mask bit order (ARCHITECTURE §4.2).
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
]
const NEGATIVE_BITS: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 20, 24]

const KEY_LABELS: Array[String] = ["LMB", "RMB", "Q", "E", "R", "F", "1", "2"]
const KEY_LABELS_CN: Array[String] = ["左键", "右键", "Q", "E", "R", "F", "1", "2"]

static var _font: Font = null
static var _font_bold: Font = null
static var _theme: Theme = null


static func font(bold: bool = false) -> Font:
	if bold:
		if _font_bold == null:
			var f := SystemFont.new()
			f.font_names = FONT_NAMES
			f.font_weight = 700
			f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
			f.hinting = TextServer.HINTING_LIGHT
			f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			_font_bold = f
		return _font_bold
	if _font == null:
		var f2 := SystemFont.new()
		f2.font_names = FONT_NAMES
		f2.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f2.hinting = TextServer.HINTING_LIGHT
		f2.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_font = f2
	return _font


## NET's res://ui/theme.tres when it exists, otherwise an equivalent theme built in code.
static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = null
	if ResourceLoader.exists(THEME_PATH):
		var r: Variant = load(THEME_PATH)
		if r is Theme:
			t = (r as Theme).duplicate() as Theme
	if t == null:
		t = Theme.new()
	if t.default_font == null:
		t.default_font = font()
	if t.default_font_size <= 0:
		t.default_font_size = 16
	# HUD readability over the 3D scene: outlined labels.
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.9))
	t.set_constant("outline_size", "Label", 4)
	t.set_color("font_color", "Label", C_TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.0))
	t.set_stylebox("panel", "TooltipPanel", panel(Color(0.04, 0.05, 0.08, 0.95), C_BORDER, 6, 1))
	t.set_color("font_color", "TooltipLabel", C_TEXT)
	t.set_stylebox("panel", "PanelContainer", panel(C_PANEL, C_BORDER_DIM, 8, 1))
	t.set_color("default_color", "RichTextLabel", C_TEXT)
	t.set_color("font_outline_color", "RichTextLabel", Color(0, 0, 0, 0.9))
	t.set_constant("outline_size", "RichTextLabel", 3)
	t.set_font("bold_font", "RichTextLabel", font(true))
	_theme = t
	return t


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


static func make_label(text: String, size: int = 16, color: Color = C_TEXT, bold: bool = false,
		outline: int = 4) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(bold))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


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


## One glyph used for portraits and minimal class badges.
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
	var kind := "减益 Debuff" if NEGATIVE_BITS.has(bit) else "增益 Buff"
	return "%s %s  [%s]\n%s  %s" % [s[1], s[2], kind, s[4], s[5]]


static func is_negative_bit(bit: int) -> bool:
	return NEGATIVE_BITS.has(bit)


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

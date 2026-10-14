class_name Hud
extends CanvasLayer
## In-match HUD (owner: HUD). Bound by the match scene:
##   hud.bind(world, match_node, local_uid)   # match_node may be null (sandbox); local_uid 0 = auto
##   hud.set_local_uid(uid)                     # spectating switches
## Listens to Match signals (announce, timer_changed, score_changed, match_ended) and World signals
## (fighter_spawned / fighter_died / fighter_removed). Data widgets refresh at REFRESH_HZ; only the
## 3D overlay (nameplates, reticle) and running animations redraw per frame. All widget nodes are created
## once in _ready (pooled); nothing is allocated per frame.

const HudStyle := preload("res://ui/hud_style.gd")
const HudUnitFrame := preload("res://ui/hud_unit_frame.gd")
const HudSkillBar := preload("res://ui/hud_skill_bar.gd")
const HudTeamFrames := preload("res://ui/hud_team_frames.gd")
const HudBossBar := preload("res://ui/hud_boss_bar.gd")
const HudWorldOverlay := preload("res://ui/hud_world_overlay.gd")
const HudCombo := preload("res://ui/hud_combo.gd")
const HudAnnounce := preload("res://ui/hud_announce.gd")
const HudKillFeed := preload("res://ui/hud_kill_feed.gd")
const HudScoreboard := preload("res://ui/hud_scoreboard.gd")
const HudHelp := preload("res://ui/hud_help.gd")
const HudTop := preload("res://ui/hud_top.gd")
const HudMinimap := preload("res://ui/hud_minimap.gd")
const HudCallout := preload("res://ui/hud_callout.gd")

const REFRESH_HZ: float = 25.0
const SCOREBOARD_HZ: float = 4.0
const DEATH_GRACE: float = 0.4   # client death-poll grace before "Fell" (a kill_event may still name the killer)

var world: World = null
var match_node: Node = null
var local_uid: int = 0              # 0 = auto (world.local_fighter())

# widgets (public for tests / other modules)
var root: Control
var overlay: HudWorldOverlay
var player_frame: HudUnitFrame
var target_frame: HudUnitFrame
var skill_bar: HudSkillBar
var team_frames: HudTeamFrames
var enemy_frames: HudTeamFrames
var boss_bar: HudBossBar
var combo: HudCombo
var announce_banner: HudAnnounce
var warn_banner: HudAnnounce
var kill_feed: HudKillFeed
var scoreboard: HudScoreboard
var help: HudHelp
var top_bar: HudTop
var minimap: HudMinimap
var callout: HudCallout
var spectate_label: Label
var spectate_plate: PanelContainer
var defeat_overlay: Control
var defeat_title: Label
var defeat_sub: Label
var defeat_en: Label
var result_panel: PanelContainer
var result_title: Label
var result_en: Label
var result_sub: Label

var mode: String = ""
var score: Dictionary = {}
var refresh_count: int = 0

var _accum: float = 0.0
var _sb_accum: float = 0.0
var _scoreboard_forced: bool = false
var _help_on: bool = false
var _dead_seen: Dictionary = {}     # uid -> true once reported in the kill feed
var _killer_of: Dictionary = {}     # uid -> killer display name
var _timer_left: float = -1.0
var _raid_elapsed: float = 0.0
var _raid_clock_on: bool = false    # raid clock interpolates only after the first authoritative timer/score
var _pending_deaths: Dictionary = {} # uid -> seconds left before a polled death is reported as "Fell"
var _end_stats: Dictionary = {}     # Match.end_match result.stats (reaches every peer)
var _ended: bool = false
var _local_was_alive: bool = true
var _defeat_t: float = 0.0
var _built: bool = false
var _top_center: Control
var _last_cast_slot: int = -1
var _last_cast_uid: int = 0


func _ready() -> void:
	layer = 10
	_build()


func _exit_tree() -> void:
	if is_inside_tree() and get_tree().root.find_children("*", "CanvasLayer", true, false).filter(func(n: Node) -> bool: return n is Hud and n != self).is_empty():
		HudStyle.release()


func _build() -> void:
	if _built:
		return
	_built = true
	root = Control.new()
	root.name = "HudRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = HudStyle.get_theme()
	add_child(root)

	overlay = HudWorldOverlay.new()
	overlay.name = "WorldOverlay"
	root.add_child(overlay)

	defeat_overlay = _build_defeat()
	root.add_child(defeat_overlay)

	# top-left: player + party
	var tl := VBoxContainer.new()
	tl.name = "TopLeft"
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.add_theme_constant_override("separation", 12)
	tl.position = Vector2(16, 16)
	root.add_child(tl)
	player_frame = HudUnitFrame.new(false, 430.0)
	player_frame.name = "PlayerFrame"
	tl.add_child(player_frame)
	team_frames = HudTeamFrames.new(false)
	team_frames.name = "TeamFrames"
	tl.add_child(team_frames)

	# top-center: match info, boss bar, target frame
	var tc := VBoxContainer.new()
	tc.name = "TopCenter"
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tc.add_theme_constant_override("separation", 8)
	tc.alignment = BoxContainer.ALIGNMENT_BEGIN
	tc.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 10)
	tc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(tc)
	top_bar = HudTop.new()
	top_bar.name = "TopBar"
	top_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tc.add_child(top_bar)
	boss_bar = HudBossBar.new()
	boss_bar.name = "BossBar"
	boss_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boss_bar.visible = false
	tc.add_child(boss_bar)
	# Target frame: compact holo plate tucked right under the match info (own layer, scaled by _layout_target),
	# so it never reaches down into the fight area in the middle of the screen.
	target_frame = HudUnitFrame.new(true, 420.0)
	target_frame.name = "TargetFrame"
	target_frame.visible = false
	root.add_child(target_frame)
	_top_center = tc
	spectate_plate = PanelContainer.new()
	spectate_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spb := HudStyle.glory("plate", 0.0, HudStyle.UI_CYAN)
	spb.content_margin_left = 26.0
	spb.content_margin_right = 26.0
	spb.content_margin_top = 2.0
	spb.content_margin_bottom = 4.0
	spectate_plate.add_theme_stylebox_override("panel", spb)
	spectate_plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	spectate_plate.visible = false
	tc.add_child(spectate_plate)
	spectate_label = HudStyle.make_label("", 18, Color(0.8, 0.94, 1.0), true, 4)
	spectate_label.visible = false
	spectate_label.visibility_changed.connect(func() -> void: spectate_plate.visible = spectate_label.visible)
	spectate_plate.add_child(spectate_label)

	# top-right: kill feed + enemy summary
	var tr := VBoxContainer.new()
	tr.name = "TopRight"
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.add_theme_constant_override("separation", 10)
	tr.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(tr)
	minimap = HudMinimap.new()
	minimap.name = "Minimap"
	minimap.size_flags_horizontal = Control.SIZE_SHRINK_END
	tr.add_child(minimap)
	kill_feed = HudKillFeed.new()
	kill_feed.name = "KillFeed"
	kill_feed.custom_minimum_size = Vector2(360, 0)
	tr.add_child(kill_feed)
	enemy_frames = HudTeamFrames.new(true)
	enemy_frames.name = "EnemyFrames"
	enemy_frames.size_flags_horizontal = Control.SIZE_SHRINK_END
	tr.add_child(enemy_frames)

	# combo counter (right side, below the enemy list: off the fight in the screen centre)
	combo = HudCombo.new()
	combo.name = "Combo"
	combo.anchor_left = 0.70
	combo.anchor_right = 0.70
	combo.anchor_top = 0.60
	combo.anchor_bottom = 0.60
	combo.size = Vector2(320, 140)
	root.add_child(combo)

	# brush-calligraphy skill call-out (left, between the party frames and the skill bar)
	callout = HudCallout.new()
	callout.name = "Callout"
	callout.anchor_top = 0.61
	callout.anchor_bottom = 0.61
	callout.offset_left = 20
	callout.size = Vector2(640, 180)
	callout.scale = Vector2(0.78, 0.78)
	root.add_child(callout)

	# announcement banner
	announce_banner = HudAnnounce.new()
	announce_banner.name = "Announce"
	announce_banner.anchor_left = 0.0
	announce_banner.anchor_right = 1.0
	announce_banner.anchor_top = 0.36
	announce_banner.anchor_bottom = 0.36
	announce_banner.offset_top = -60
	announce_banner.offset_bottom = 60
	root.add_child(announce_banner)
	# boss-mechanic warnings: compact band under the boss bar / match info (positioned by _layout_target),
	# so the boss and its telegraphs in the screen centre stay visible
	warn_banner = HudAnnounce.new()
	warn_banner.name = "MechanicWarning"
	warn_banner.compact = true
	warn_banner.max_hold = 2.5
	warn_banner.size = Vector2(1600, 84)
	root.add_child(warn_banner)

	# bottom-center: skill bar + cast bar
	skill_bar = HudSkillBar.new()
	skill_bar.name = "SkillBar"
	skill_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 14)
	skill_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	skill_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(skill_bar)

	# centered panels
	scoreboard = HudScoreboard.new()
	scoreboard.name = "Scoreboard"
	_center(scoreboard)
	scoreboard.visible = false
	root.add_child(scoreboard)
	help = HudHelp.new()
	help.name = "Help"
	_center(help)
	help.visible = false
	root.add_child(help)
	result_panel = _build_result()
	result_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 118)
	result_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	result_panel.visible = false
	root.add_child(result_panel)
	# world nameplates never draw under these panels
	var keep: Array[Control] = [player_frame, team_frames, enemy_frames, target_frame, minimap, top_bar, boss_bar, kill_feed]
	overlay.keep_out = keep


func _center(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH


const VIGNETTE: String = "shader_type canvas_item;\nvoid fragment() { vec2 d = UV - 0.5; d.x *= 1.6; float v = smoothstep(0.25, 0.85, length(d)); COLOR = vec4(mix(vec3(0.05, 0.0, 0.02), vec3(0.35, 0.02, 0.04), v), 0.18 + 0.55 * v); }"


func _build_defeat() -> Control:
	var c := ColorRect.new()
	c.name = "DefeatOverlay"
	c.color = Color(0.25, 0.0, 0.0, 0.28)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = VIGNETTE
	mat.shader = sh
	c.material = mat
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 0)
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vb.grow_vertical = Control.GROW_DIRECTION_BOTH
	vb.anchor_top = 0.58
	vb.anchor_bottom = 0.58
	c.add_child(vb)
	defeat_title = HudStyle.make_label_f("你已被击败", HudStyle.brush(), 84, Color("#FF6A5A"), 10)
	defeat_title.add_theme_color_override("font_outline_color", Color(0.15, 0.0, 0.02, 0.95))
	defeat_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(defeat_title)
	defeat_en = HudStyle.make_label_f("YOU WERE DEFEATED", HudStyle.tech(800), 20, Color("#FFC0B0"), 4)
	defeat_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(defeat_en)
	defeat_sub = HudStyle.make_label("", 19, HudStyle.C_TEXT, false, 5)
	defeat_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(defeat_sub)
	c.visible = false
	return c


func _build_result() -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "Result"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := HudStyle.glory("panel", 0.0)
	sb.content_margin_left = 60.0
	sb.content_margin_right = 60.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 16.0
	p.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 0)
	vb.custom_minimum_size = Vector2(460, 0)
	p.add_child(vb)
	result_title = HudStyle.make_label_f("", HudStyle.brush(), 92, HudStyle.UI_GOLD_HI, 10)
	result_title.add_theme_color_override("font_outline_color", Color(0.22, 0.1, 0.02, 0.95))
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(result_title)
	result_en = HudStyle.make_label_f("", HudStyle.crit(), 26, HudStyle.UI_GOLD, 5)
	result_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(result_en)
	result_sub = HudStyle.make_label("", 18, HudStyle.C_TEXT, false, 4)
	result_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(result_sub)
	return p


# ================================================================== binding
func bind(p_world: World, p_match: Node, p_local_uid: int) -> void:
	_build()
	_disconnect_all()
	world = p_world
	match_node = p_match
	local_uid = p_local_uid
	_dead_seen.clear()
	_killer_of.clear()
	_ended = false
	_raid_elapsed = 0.0
	_raid_clock_on = false
	_pending_deaths.clear()
	_end_stats = {}
	_timer_left = -1.0
	score = {}
	result_panel.visible = false
	if world != null:
		world.fighter_died.connect(_on_fighter_died)
		world.fighter_removed.connect(_on_fighter_removed)
		world.fighter_spawned.connect(_on_fighter_spawned)
		for f: Fighter in world.fighters:
			if is_instance_valid(f) and not f.is_alive():
				_dead_seen[f.uid] = true
	mode = ""
	if match_node != null:
		if match_node.has_signal("announce"):
			match_node.connect("announce", _on_announce)
		if match_node.has_signal("timer_changed"):
			match_node.connect("timer_changed", _on_timer_changed)
		if match_node.has_signal("score_changed"):
			match_node.connect("score_changed", _on_score_changed)
		if match_node.has_signal("match_ended"):
			match_node.connect("match_ended", _on_match_ended)
		if match_node.has_signal("kill_event"):
			match_node.connect("kill_event", _on_kill_event)
		var st: Variant = match_node.get("settings")
		if st is Dictionary:
			mode = str((st as Dictionary).get("mode", ""))
		var sc: Variant = match_node.get("score")
		if sc is Dictionary:
			score = (sc as Dictionary).duplicate()
			if score.has("clear_time"):
				_raid_elapsed = float(score["clear_time"])
				_raid_clock_on = true
		var tl: Variant = match_node.get("time_left")
		if tl != null and float(tl) > 0.0:
			_timer_left = float(tl)
	top_bar.set_mode(mode)
	top_bar.set_score(score, mode == "raid")
	top_bar.set_timer(_timer_left if mode != "raid" else 0.0, mode == "raid")
	overlay.world = world
	minimap.world = world
	minimap.caption = _map_caption()
	_last_cast_slot = -1
	refresh()


## "地图名 · 模式" under the minimap.
func _map_caption() -> String:
	var mt := HudTop.mode_text(mode).split(" ")[0] if mode != "" else "训练"
	if match_node == null or not is_instance_valid(match_node):
		return mt
	var st: Variant = match_node.get("settings")
	if not (st is Dictionary):
		return mt
	var sd: Dictionary = st
	var nm := ""
	if mode == "raid":
		if str(sd.get("raid_id", "")) != "":
			nm = str(RaidRegistry.get_info(str(sd.get("raid_id", ""))).get("name_cn", ""))
	elif str(sd.get("map_id", "")) != "":
		nm = str(MapRegistry.info(str(sd.get("map_id", ""))).get("name_cn", ""))
	return (nm + " · " + mt) if nm != "" else mt


func set_local_uid(uid: int) -> void:
	local_uid = uid
	refresh()


func _disconnect_all() -> void:
	if world != null and is_instance_valid(world):
		if world.fighter_died.is_connected(_on_fighter_died):
			world.fighter_died.disconnect(_on_fighter_died)
		if world.fighter_removed.is_connected(_on_fighter_removed):
			world.fighter_removed.disconnect(_on_fighter_removed)
		if world.fighter_spawned.is_connected(_on_fighter_spawned):
			world.fighter_spawned.disconnect(_on_fighter_spawned)
	if match_node != null and is_instance_valid(match_node):
		for pair: Array in [["announce", _on_announce], ["timer_changed", _on_timer_changed],
				["score_changed", _on_score_changed], ["match_ended", _on_match_ended], ["kill_event", _on_kill_event]]:
			if match_node.has_signal(pair[0]) and match_node.is_connected(pair[0], pair[1]):
				match_node.disconnect(pair[0], pair[1])


## The fighter the HUD follows (bound uid, else this peer's own fighter).
func get_local_fighter() -> Fighter:
	if world == null or not is_instance_valid(world):
		return null
	if local_uid != 0:
		return world.get_fighter(local_uid)
	return world.local_fighter()


func is_spectating() -> bool:
	var f := get_local_fighter()
	if f == null:
		return world != null and is_instance_valid(world) and world.fighters.size() > 0
	if not is_inside_tree() or multiplayer == null or not multiplayer.has_multiplayer_peer():
		return false
	return not (f.kind == "player" and f.peer == multiplayer.get_unique_id())


func find_boss() -> Fighter:
	if world == null or not is_instance_valid(world):
		return null
	var buid := int(score.get("boss_uid", 0)) if (score.get("boss_uid", 0) is int) else 0
	if buid != 0:
		var bf := world.get_fighter(buid)
		if bf != null and is_instance_valid(bf):
			return bf
	var best: Fighter = null
	for f: Fighter in world.fighters:
		if is_instance_valid(f) and f.kind == "boss":
			if best == null or (f.is_alive() and not best.is_alive()):
				best = f
	return best


# ================================================================== signals
func _on_announce(text: String, seconds: float) -> void:
	if is_mechanic_warning(text):
		warn_banner.show_text(text, seconds, HudStyle.C_GOLD, true)
	else:
		announce_banner.show_text(text, seconds)


## Raid boss call-outs (BossBrain abilities) go to the compact upper band; round / encounter / clear / wipe /
## victory banners stay centred.
const CENTER_KEYWORDS: Array[String] = ["准备出发", "遭遇", "已清除", "团灭", "重新挑战", "通关", "胜", "败", "Round", "局"]


func is_mechanic_warning(text: String) -> bool:
	if mode != "raid" or _ended:
		return false
	var boss := find_boss()
	if boss == null or not is_instance_valid(boss) or not boss.is_alive():
		return false
	for k: String in CENTER_KEYWORDS:
		if text.contains(k):
			return false
	return true


func _on_timer_changed(seconds_left: float) -> void:
	_timer_left = seconds_left
	if mode == "raid":
		# MatchRaid broadcasts the authoritative clear_time through timer_changed
		_raid_elapsed = seconds_left
		_raid_clock_on = true
		top_bar.set_timer(_raid_elapsed, true)
	else:
		top_bar.set_timer(seconds_left, false)


func _on_score_changed(s: Dictionary) -> void:
	score = s.duplicate()
	top_bar.set_score(score, mode == "raid")
	if score.has("clear_time"):
		_raid_elapsed = float(score["clear_time"])
		_raid_clock_on = true
		if mode == "raid":
			top_bar.set_timer(_raid_elapsed, true)


func _on_match_ended(result: Dictionary) -> void:
	_ended = true
	var me := get_local_fighter()
	var my_team := me.team if me != null else 0
	var wt := int(result.get("winner_team", -1))
	var title := ""
	var col := HudStyle.UI_GOLD_HI
	if str(result.get("mode", mode)) == "raid":
		if wt == -1:
			title = "团灭  Wiped"
			col = Color(1, 0.4, 0.35)
		else:
			title = "通关  Cleared"
	elif wt == -1:
		title = "平局  Draw"
		col = HudStyle.C_TEXT
	elif wt == my_team:
		title = "胜利  Victory"
	else:
		title = "失败  Defeat"
		col = Color(1, 0.4, 0.35)
	var parts := HudAnnounce.split_bilingual(title)
	result_title.text = parts[0]
	result_en.text = parts[1].to_upper()
	result_title.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.15))
	var sub := ""
	var ct := float(result.get("clear_time", 0.0))
	if ct > 0.0:
		sub += "通关用时 Clear time  %02d:%02d\n" % [int(ct) / 60, int(ct) % 60]
		_raid_elapsed = ct
	var mvp := int(result.get("mvp_uid", -1))
	var stats: Dictionary = result.get("stats", {})
	_end_stats = stats.duplicate(true)
	_sb_accum = 1.0
	if mvp > 0:
		var mf := world.get_fighter(mvp) if world != null and is_instance_valid(world) else null
		var nm := mf.display_name if mf != null else str((stats.get(mvp, {}) as Dictionary).get("name", "?"))
		sub += "最有价值选手 MVP  %s" % nm
	result_sub.text = sub
	result_panel.visible = true
	_recenter_soon(scoreboard)


## Optional NET signal (clients): kill_event(victim_uid, killer_uid).
func _on_kill_event(victim_uid: int, killer_uid: int) -> void:
	if world == null or not is_instance_valid(world):
		return
	_pending_deaths.erase(victim_uid)
	_report_death(world.get_fighter(victim_uid), world.get_fighter(killer_uid))


func _on_fighter_spawned(_f: Fighter) -> void:
	_accum = 1.0   # refresh on the next frame


func _on_fighter_removed(f: Fighter) -> void:
	_dead_seen.erase(f.uid)
	_pending_deaths.erase(f.uid)


func _on_fighter_died(f: Fighter, killer: Fighter) -> void:
	if f != null:
		_pending_deaths.erase(f.uid)
	_report_death(f, killer)


## Reports polled deaths whose grace period ran out (or all of them when `force`), killer = last attacker.
func flush_pending_deaths(delta: float = 0.0, force: bool = false) -> void:
	if _pending_deaths.is_empty():
		return
	var valid_world := world != null and is_instance_valid(world)
	for uid: int in _pending_deaths.keys():
		var left := float(_pending_deaths[uid]) - delta
		if left > 0.0 and not force:
			_pending_deaths[uid] = left
			continue
		_pending_deaths.erase(uid)
		if not valid_world:
			continue
		var f := world.get_fighter(uid)
		if f == null or not is_instance_valid(f) or f.is_alive():
			continue
		_report_death(f, world.get_fighter(f.last_attacker_uid) if f.last_attacker_uid != 0 else null)


func _report_death(f: Fighter, killer: Fighter) -> void:
	if f == null or not is_instance_valid(f) or _dead_seen.has(f.uid):
		return
	_dead_seen[f.uid] = true
	if f.kind == "summon":
		return
	if killer != null and not is_instance_valid(killer):
		killer = null
	if killer != null and killer.kind == "summon":
		var owner_f := killer.get_owner_fighter()
		if owner_f != null:
			killer = owner_f
	if killer != null:
		_killer_of[f.uid] = killer.display_name
	kill_feed.add_kill(killer, f, get_local_fighter())


# ================================================================== input
func _unhandled_key_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k != null and k.pressed and not k.echo and k.physical_keycode == KEY_F1:
		toggle_help()


func toggle_help() -> void:
	set_help_visible(not _help_on)


func set_help_visible(on: bool) -> void:
	_help_on = on
	help.refresh(get_local_fighter())
	help.visible = on
	_recenter_soon(help)


## Forces the scoreboard open (tests / previews); normally it shows while ` is held.
func set_scoreboard_forced(on: bool) -> void:
	_scoreboard_forced = on
	_sb_accum = 1.0


func _scoreboard_held() -> bool:
	if _scoreboard_forced:
		return true
	if InputMap.has_action("scoreboard"):
		return Input.is_action_pressed("scoreboard")
	return Input.is_physical_key_pressed(KEY_QUOTELEFT)


# ================================================================== update
func _process(delta: float) -> void:
	if not _built:
		return
	if mode == "raid" and _raid_clock_on and not _ended and world != null:
		_raid_elapsed += delta   # interpolation between authoritative timer_changed updates
	flush_pending_deaths(delta)
	overlay.viewer = get_local_fighter()
	var sb_on := _scoreboard_held() or _ended
	if sb_on != scoreboard.visible:
		scoreboard.visible = sb_on and not help.visible
		_sb_accum = 1.0
	if scoreboard.visible:
		_sb_accum += delta
		if _sb_accum >= 1.0 / SCOREBOARD_HZ:
			_sb_accum = 0.0
			_refresh_scoreboard()
	if defeat_overlay.visible:
		_defeat_t += delta
		defeat_overlay.modulate.a = clampf(_defeat_t / 0.5, 0.0, 1.0)
	_accum += delta
	if _accum >= 1.0 / REFRESH_HZ:
		_accum = 0.0
		refresh()
	_layout_target()


## Keeps the target frame centred directly below the top-centre stack (match info / boss bar), scaled for the
## canvas height (0.8 on the 900 px stretch base), so it ends well above the fight in the screen centre.
func _layout_target() -> void:
	if _top_center == null:
		return
	if warn_banner != null:
		var wvp := root.size if root != null and root.size.y > 0.0 else Vector2(1600, 900)
		var wbelow := 10.0
		for c in _top_center.get_children():
			if c is Control and (c as Control).visible:
				wbelow = maxf(wbelow, _top_center.position.y + (c as Control).position.y + (c as Control).size.y)
		if target_frame != null and target_frame.visible:
			wbelow = maxf(wbelow, target_frame.position.y + target_frame.size.y * target_frame.scale.y)
		warn_banner.size = Vector2(wvp.x, 84)
		warn_banner.position = Vector2(0, roundf(wbelow + 4.0))
	if target_frame == null or not target_frame.visible:
		return
	var vp := root.size if root != null and root.size.y > 0.0 else Vector2(1920, 1080)
	var s := clampf(vp.y / 900.0, 0.6, 1.2) * 0.8   # HUD is laid out on the 1600x900 canvas_items base
	target_frame.scale = Vector2(s, s)
	target_frame.size = target_frame.get_combined_minimum_size()
	var below := 10.0
	for c in _top_center.get_children():
		if c is Control and (c as Control).visible:
			below = maxf(below, _top_center.position.y + (c as Control).position.y + (c as Control).size.y)
	target_frame.position = Vector2(roundf((vp.x - target_frame.size.x * s) * 0.5), roundf(below + 6.0))


## Full data refresh (normally ~25 Hz from _process; tests may call it directly).
func refresh() -> void:
	if not _built:
		return
	refresh_count += 1
	var valid_world := world != null and is_instance_valid(world)
	var me := get_local_fighter()
	overlay.world = world if valid_world else null
	overlay.viewer = me
	player_frame.refresh(me, me)
	skill_bar.refresh(me)
	var tgt: Fighter = me.get_target() if me != null else null
	var boss := find_boss()
	boss_bar.refresh(boss, score)
	# the boss bar already shows the boss: no duplicate target frame; nothing but results after the end
	target_frame.refresh(tgt if tgt != boss and not _ended else null, me)
	if _ended:
		boss_bar.visible = false
	combo.set_count(me.combo_count if me != null and me.is_alive() and not _ended else 0)
	minimap.viewer = me
	minimap.world = world if valid_world else null
	minimap.visible = valid_world
	_update_callout(me)
	if mode == "raid":
		top_bar.set_timer(_raid_elapsed, true)
	if not valid_world:
		team_frames.refresh([], me)
		enemy_frames.refresh([], me)
		return
	# team frames + death polling (clients never get died signals)
	var allies: Array = []
	var enemies: Array = []
	var my_team := me.team if me != null else 0
	var a0 := 0
	var t0 := 0
	var a1 := 0
	var t1 := 0
	var pvp := true
	for f: Fighter in world.fighters:
		if not is_instance_valid(f):
			continue
		if f.kind == "mob" or f.kind == "boss":
			pvp = false
		if not f.is_alive():
			# clients: wait a short grace for a reliable kill_event naming the killer
			if not _dead_seen.has(f.uid) and not _pending_deaths.has(f.uid):
				_pending_deaths[f.uid] = DEATH_GRACE
		else:
			_dead_seen.erase(f.uid)   # revived / new round
			_pending_deaths.erase(f.uid)
		if f.kind == "summon" or f.kind == "mob" or f.kind == "boss":
			continue
		if f.team == 0:
			t0 += 1
			a0 += 1 if f.is_alive() else 0
		elif f.team == 1:
			t1 += 1
			a1 += 1 if f.is_alive() else 0
		if f == me:
			continue
		if f.team == my_team:
			allies.append(f)
		else:
			enemies.append(f)
	allies.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.uid < b.uid)
	enemies.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.uid < b.uid)
	team_frames.refresh(allies, me)
	enemy_frames.refresh(enemies if pvp else [], me)
	top_bar.pips.set_counts(a0, t0, a1, t1)
	top_bar.pips.visible = pvp and t1 > 0
	_update_local_state(me)


## Brush call-out when the followed fighter starts a non-basic skill.
func _update_callout(me: Fighter) -> void:
	if me == null or not is_instance_valid(me):
		_last_cast_slot = -1
		return
	var cs := me.cast_slot
	if me.uid != _last_cast_uid:
		_last_cast_uid = me.uid
		_last_cast_slot = cs
		return
	if cs != _last_cast_slot:
		_last_cast_slot = cs
		if cs >= 1 and me.is_alive() and not _ended:
			var sk: SkillDef = me.runner.skill if me.runner != null and me.runner.skill != null else me.get_skill(cs)
			if sk != null:
				callout.show_skill(sk, me.kit.name_cn if me.kit != null else "", me.kit.tint if me.kit != null else HudStyle.UI_GOLD)


func _update_local_state(me: Fighter) -> void:
	var spectating := is_spectating()
	spectate_label.visible = spectating
	if spectating:
		spectate_label.text = "观战中 Spectating%s" % ("  ·  " + me.display_name if me != null else "")
	var dead := me != null and not me.is_alive() and not spectating and not _ended
	if dead and _local_was_alive:
		_defeat_t = 0.0
		var by := str(_killer_of.get(me.uid, ""))
		var sub := ("被 %s 击败  Defeated by %s\n" % [by, by]) if by != "" else ""
		sub += "等待复活  Awaiting revive" if mode == "raid" else "等待下一回合  Waiting for the next round"
		defeat_sub.text = sub
	defeat_overlay.visible = dead
	_local_was_alive = me == null or me.is_alive()


func _refresh_scoreboard() -> void:
	var stats: Dictionary = {}
	if match_node != null and is_instance_valid(match_node):
		var s: Variant = match_node.get("stats")
		if s is Dictionary:
			_merge_stats(stats, s)
	var ss: Variant = score.get("stats", null)
	if ss is Dictionary:
		_merge_stats(stats, ss)
	_merge_stats(stats, _end_stats)
	var mt := HudTop.mode_text(mode) if mode != "" else "训练 Sandbox"
	if mode == "raid":
		mt += "   通关计时 Clear %02d:%02d" % [int(_raid_elapsed) / 60, int(_raid_elapsed) % 60]
	elif _timer_left >= 0.0:
		mt += "   剩余时间 Time %s" % HudStyle.fmt_time(_timer_left)
	scoreboard.refresh(world if world != null and is_instance_valid(world) else null, stats, get_local_fighter(), mt)
	_recenter_soon(scoreboard)


## Merges per-uid stat snapshots into `into`, keeping the max of each numeric counter.
static func _merge_stats(into: Dictionary, src: Dictionary) -> void:
	for k: Variant in src:
		var row: Variant = src[k]
		if not (row is Dictionary):
			continue
		var uid := int(k)
		if not into.has(uid):
			into[uid] = (row as Dictionary).duplicate()
			continue
		var dst: Dictionary = into[uid]
		for key: Variant in row:
			var v: Variant = row[key]
			if (v is int or v is float) and dst.has(key) and (dst[key] is int or dst[key] is float):
				dst[key] = maxf(float(dst[key]), float(v)) if (v is float or dst[key] is float) else maxi(int(dst[key]), int(v))
			elif not dst.has(key):
				dst[key] = v


func _recenter_soon(c: Control) -> void:
	if is_inside_tree() and not get_tree().process_frame.is_connected(_recenter.bind(c)):
		get_tree().process_frame.connect(_recenter.bind(c), CONNECT_ONE_SHOT)


## Shrinks a centered panel to its current minimum size (rows hidden/shown) and re-centers it.
func _recenter(c: Control) -> void:
	if not is_instance_valid(c):
		return
	c.reset_size()
	_center(c)
	if c == scoreboard and _ended:
		# leave room for the result panel above it
		c.anchor_top = 0.62
		c.anchor_bottom = 0.62


## Convenience for previews/tests: shows an announcement as if the Match sent it.
func announce(text: String, seconds: float = 2.0) -> void:
	announce_banner.show_text(text, seconds)

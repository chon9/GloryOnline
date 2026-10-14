"""painter.keys - one palette key per class (ICON_STYLE.md section 1) + the cross-class status palettes.

Every icon of a class uses only its key, so a bar reads as one set. Skills are told apart by composition and value,
not hue. Fields:
  ink / ink_warm            ground (darkest value) / warm dark masses near the bottom
  metal / metal_hi / metal_sh   class metal (trim, collars, guards)
  accent / accent_dk        one signature accent
  tones                     per-skill light: name -> (mid, light, core); the dark end is ink_warm
  cool                      THE one off-key accent of the bar (default: the ultimate's rim). For a cool-keyed class it
                            is warm. Use it on at most one icon.
  emblem                    (light, core) of the soft light mass behind the class emblem weapon

A comps/<class_id>.py may override its class key by defining CLASS_KEY = {...} (full dict) at module level; keys here are
the defaults (bible 2.5 palettes) and are what the emblems use.
"""

_GOLD = ("#D8B25A", "#FFE9A8", "#8A5A2B")
_SILVER = ("#C9D3DE", "#FFFFFF", "#5C6A84")
_BRASS = ("#B9944A", "#FFE7A0", "#6A4A1A")
_BRONZE = ("#B07A3E", "#FFD8A0", "#5A3414")
_STEEL = ("#8E9AAB", "#EEF2F8", "#3E4858")


def _k(ink, ink_warm, metal, accent, accent_dk, cool, tones, emblem):
    return {"ink": ink, "ink_warm": ink_warm, "metal": metal[0], "metal_hi": metal[1], "metal_sh": metal[2],
            "accent": accent, "accent_dk": accent_dk, "cool": cool, "tones": tones, "emblem": emblem}


CLASS_KEYS = {
    # ---------------------------------------------------------------- Swordsman 剑士系
    "blade_master": _k("#060912", "#0B1428", _SILVER, "#1F5FBF", "#08183A", "#FFD86A", {
        "ice": ("#1F6FBF", "#7FE8FF", "#F2FFFF"),
        "azure": ("#163C8A", "#4FA0FF", "#E6F4FF"),
        "steel": ("#46567A", "#CFE6FF", "#FFFFFF"),
        "moon": ("#2E3E66", "#AFC4F0", "#FFFFFF"),
    }, ("#2F9BFF", "#7FE8FF")),
    "berserker": _k("#0A0606", "#1E0A0A", _BRONZE, "#9E1B25", "#3A060A", "#B48CFF", {
        "blood": ("#6A0A12", "#E0323C", "#FFD6D0"),
        "rage": ("#8A2A10", "#FF7A3A", "#FFEAD0"),
        "bronze": ("#6A4418", "#E0A858", "#FFF0D0"),
    }, ("#C8202A", "#FF8A6A")),
    "spellblade": _k("#050B0C", "#0A1A1C", _GOLD, "#147A82", "#04282A", "#FF8A1F", {
        "wave": ("#0E5058", "#4FE0D8", "#EFFFFC"),
        "frost": ("#1A5A8A", "#9FEFFF", "#FFFFFF"),
        "volt": ("#3A3A8A", "#B8F0FF", "#FFFFFF"),
        "gold": ("#8E5E1A", "#FFC85A", "#FFF6DC"),
    }, ("#147A82", "#4FE0D8")),
    "ghostblade": _k("#07050C", "#140C22", _SILVER, "#B48CFF", "#2A1E3A", "#7FE8FF", {
        "ghost": ("#3A1E6A", "#B48CFF", "#F4ECFF"),
        "moon": ("#2A3A6A", "#C8D8FF", "#FFFFFF"),
        "soul": ("#4A1A5A", "#E08CFF", "#FFF0FF"),
    }, ("#7A4CD8", "#B48CFF")),
    # ---------------------------------------------------------------- Mage 法师系
    "battle_mage": _k("#09080C", "#1B120F", _GOLD, "#D2283A", "#4A0810", "#7FE8FF", {
        "gold": ("#8E5E1A", "#FFC85A", "#FFF6DC"),
        "crimson": ("#7E0C1E", "#FF4A4E", "#FFE6DA"),
        "ember": ("#9A3E14", "#FF9E4A", "#FFF2DC"),
        "white": ("#6E5E46", "#F4E4C2", "#FFFFFF"),
    }, ("#D2283A", "#FF8A5A")),
    "elementalist": _k("#08060C", "#1A1026", _GOLD, "#3A2350", "#140A20", "#7FE8FF", {
        "fire": ("#A8301A", "#FF9A3A", "#FFF4C2"),
        "frost": ("#2A72A8", "#9FEFFF", "#FFFFFF"),
        "volt": ("#4A3AA8", "#B8F0FF", "#FFFFFF"),
        "arcane": ("#5A2A8A", "#C89CFF", "#FFF4FF"),
    }, ("#8A4CFF", "#FF9A3A")),
    "witch": _k("#05060E", "#0E0E26", _GOLD, "#6C7BFF", "#14185A", "#FF8A1F", {
        "star": ("#2A2E8A", "#8C9BFF", "#F4F4FF"),
        "arcane": ("#3E1C7E", "#B48CFF", "#F8F0FF"),
        "night": ("#141A5A", "#5A6CE0", "#E0E6FF"),
        "gold": ("#7A561A", "#FFC85A", "#FFF6DC"),
    }, ("#23379A", "#8C9BFF")),
    "summoner": _k("#040A08", "#0A1C16", _GOLD, "#2F8F7A", "#0A2A22", "#FF8A6A", {
        "spirit": ("#14503F", "#6FE0B0", "#F0FFF6"),
        "thorn": ("#2A4A14", "#A8E05A", "#F6FFE0"),
        "cream": ("#6A5A3A", "#F2E6C8", "#FFFFFF"),
    }, ("#2F8F7A", "#6FE0B0")),
    # ---------------------------------------------------------------- Gunner 枪炮系
    "sharpshooter": _k("#0A0706", "#1C120C", _BRASS, "#A8202A", "#3A080C", "#7FE8FF", {
        "muzzle": ("#8A3A10", "#FFC43A", "#FFF6C0"),
        "crimson": ("#7A0C18", "#FF4A4E", "#FFE6DA"),
        "dust": ("#5A3B28", "#D8B48A", "#FFF4E0"),
    }, ("#A4502A", "#FFC43A")),
    "spitfire": _k("#080806", "#16160C", _BRASS, "#A4502A", "#3A1A0A", "#7FE8FF", {
        "blast": ("#A8401A", "#FFB43A", "#FFF6C0"),
        "olive": ("#4A5228", "#C8D07A", "#FFFFE0"),
        "spark": ("#8A6A10", "#FFE45A", "#FFFFF0"),
    }, ("#5B6235", "#FFB43A")),
    "launcher": _k("#0A0705", "#1E120A", _BRASS, "#F08A24", "#4A2008", "#7FE8FF", {
        "blast": ("#A8401A", "#FFB43A", "#FFF6C0"),
        "brass": ("#7A5A1E", "#F2C230", "#FFF6DC"),
        "energy": ("#8A7410", "#FFE45A", "#FFFFF0"),
        "smoke": ("#4A3A2E", "#C8B49A", "#FFF4E6"),
    }, ("#F08A24", "#FFE45A")),
    "mechanic": _k("#06080A", "#12161C", _STEEL, "#FF8A1F", "#4A2008", "#7FE8FF", {
        "spark": ("#A8501A", "#FFB43A", "#FFF6C0"),
        "gunmetal": ("#3A424C", "#B8C2CE", "#FFFFFF"),
        "volt": ("#2A5A8A", "#9FDCFF", "#FFFFFF"),
    }, ("#4A525C", "#FF8A1F")),
    # ---------------------------------------------------------------- Fighter 格斗系
    "striker": _k("#0A0606", "#1E0C0A", _GOLD, "#B3262A", "#3A080A", "#7FE8FF", {
        "fire": ("#9A2A14", "#FF8A4A", "#FFF0D8"),
        "crimson": ("#7A0C14", "#FF4A4E", "#FFE6DA"),
        "white": ("#6E6458", "#ECE6DA", "#FFFFFF"),
    }, ("#B3262A", "#FF8A4A")),
    "qi_master": _k("#050810", "#0A1424", _SILVER, "#7FC4FF", "#0E2A4A", "#FFC85A", {
        "qi": ("#1A4A7A", "#7FC4FF", "#FFFFFF"),
        "jade": ("#14604E", "#9FFFE6", "#F0FFFA"),
        "sky": ("#2A5A9A", "#BFE0FF", "#FFFFFF"),
    }, ("#2F7FD0", "#9FFFE6")),
    "grappler": _k("#05060C", "#0E1226", _SILVER, "#2B3A6E", "#0A1028", "#FF8A4A", {
        "indigo": ("#2B3A6E", "#8CA0E0", "#F0F4FF"),
        "white": ("#5E6478", "#E8ECF4", "#FFFFFF"),
        "impact": ("#6A5A8A", "#D8D0FF", "#FFFFFF"),
    }, ("#2B3A6E", "#8CA0E0")),
    "brawler": _k("#08050A", "#180C1C", _BRASS, "#D8B030", "#3A2A08", "#7FE8FF", {
        "mustard": ("#7A5E14", "#E8C040", "#FFF6D0"),
        "purple": ("#4A1E5E", "#B070D8", "#F6E8FF"),
        "fire": ("#A8401A", "#FF9A3A", "#FFF4C2"),
    }, ("#5A2E6E", "#E8C040")),
    # ---------------------------------------------------------------- Nightwalker 暗夜系
    "assassin": _k("#070506", "#160A0E", _SILVER, "#7A1F33", "#2A0810", "#7FE8FF", {
        "wine": ("#5A0E20", "#E04A6A", "#FFE0E8"),
        "steel": ("#3A4054", "#C8D0E0", "#FFFFFF"),
        "shadow": ("#2A1A30", "#8A6A9A", "#F0E6F6"),
    }, ("#7A1F33", "#E04A6A")),
    "ninja": _k("#05060C", "#0C1020", _SILVER, "#C8202A", "#3A060A", "#FFD86A", {
        "steel": ("#3A4664", "#C8D4EC", "#FFFFFF"),
        "crimson": ("#7A0A14", "#FF4A4E", "#FFE6DA"),
        "sakura": ("#7A2A4A", "#FF9ABA", "#FFF0F4"),
    }, ("#1E2A5A", "#FF4A4E")),
    "thief": _k("#040806", "#0C1A12", _BRASS, "#C8A878", "#2A2010", "#B48CFF", {
        "poison": ("#2A5A14", "#7CFF6B", "#EFFFD6"),
        "tan": ("#6A5438", "#E0C89A", "#FFF8EA"),
        "frost": ("#2A72A8", "#9FEFFF", "#FFFFFF"),
    }, ("#1F3B2D", "#7CFF6B")),
    "warlock": _k("#050605", "#0E140C", _SILVER, "#7CFF6B", "#14300E", "#B48CFF", {
        "curse": ("#2A5A14", "#7CFF6B", "#EFFFD6"),
        "bone": ("#5A4E3A", "#E6D8B8", "#FFFFFF"),
        "void": ("#2A1A3A", "#9A7AC8", "#F0E8FF"),
    }, ("#2A5A14", "#7CFF6B")),
    # ---------------------------------------------------------------- Priest 圣职系
    "knight": _k("#06080C", "#10141C", _STEEL, "#3F7FD0", "#0E2244", "#FFC85A", {
        "steel": ("#4A5468", "#D0D8E6", "#FFFFFF"),
        "azure": ("#1E4A8A", "#7FB4FF", "#F0F6FF"),
        "gold": ("#8E5E1A", "#FFC85A", "#FFF6DC"),
    }, ("#3F7FD0", "#D0D8E6")),
    "exorcist": _k("#070506", "#160A0A", _SILVER, "#C8202A", "#3A060A", "#7FE8FF", {
        "talisman": ("#8A5A1A", "#FFD86A", "#FFFBE6"),
        "crimson": ("#7A0A14", "#FF4A4E", "#FFE6DA"),
        "silver": ("#4A5068", "#D0D6E6", "#FFFFFF"),
    }, ("#C8202A", "#FFD86A")),
    "cleric": _k("#07080C", "#14161E", _GOLD, "#F2F0EA", "#2A2E44", "#7FE8FF", {
        "holy": ("#8A6A1A", "#FFD86A", "#FFFBE6"),
        "heal": ("#2A7A4A", "#7CF0A0", "#F0FFF4"),
        "white": ("#6E6E78", "#F2F0EA", "#FFFFFF"),
    }, ("#FFD86A", "#FFFBE6")),
    "paladin": _k("#06080E", "#101828", _GOLD, "#7FB4FF", "#14284A", "#FF8A6A", {
        "holy": ("#8A6A1A", "#FFD86A", "#FFFBE6"),
        "sky": ("#2A5A9A", "#9FCFFF", "#FFFFFF"),
        "white": ("#6E7484", "#F2F4FA", "#FFFFFF"),
    }, ("#7FB4FF", "#FFD86A")),
    # ---------------------------------------------------------------- 散人
    "unspecialized": _k("#07080E", "#14121A", _GOLD, "#E0232E", "#4A0810", "#7FE8FF", {
        "white": ("#5E5A62", "#F2E6CF", "#FFFFFF"),
        "red": ("#7A0A14", "#FF4A4E", "#FFE6DA"),
        "gold": ("#8E5E1A", "#FFC85A", "#FFF6DC"),
        "blast": ("#A8401A", "#FFB43A", "#FFF6C0"),
    }, ("#E0232E", "#F2E6CF")),
}

# Status palettes: (dark, mid, light, core). Status icons are a cross-class family: the element colour carries meaning.
STATUS_PAL = {
    "gold": ["#1A1206", "#8E5E1A", "#FFC85A", "#FFF6DC"],
    "crimson": ["#1A0608", "#8A1420", "#FF5A56", "#FFE6E0"],
    "wind": ["#061C18", "#1A7A5C", "#8CFFD8", "#F0FFF8"],
    "fire": ["#1E0806", "#A8301A", "#FF9A3A", "#FFF4C2"],
    "ice": ["#06141F", "#2A72A8", "#9FEFFF", "#FFFFFF"],
    "steel": ["#120A0E", "#6A2A34", "#FF6A6A", "#FFE6E6"],
    "cc": ["#120A22", "#5A30A0", "#D8B8FF", "#FFFFFF"],
    "blood": ["#160406", "#7A0A14", "#E0323C", "#FFD6D0"],
    "poison": ["#08140A", "#3A6B1F", "#7CFF6B", "#EFFFD6"],
    "earth": ["#120C06", "#6A4A22", "#D8A858", "#FFF0D0"],
    "holy": ["#16120A", "#8A6A1A", "#FFD86A", "#FFFBE6"],
    "shadow": ["#0C0814", "#3A2460", "#9A7AD8", "#F0E8FF"],
    "arcane": ["#100818", "#5A2A9A", "#C08CFF", "#F8F0FF"],
    "azure": ["#060E1C", "#1E4A8A", "#7FB4FF", "#F0F6FF"],
    "jade": ["#06140C", "#1F7A44", "#7CF0A0", "#F0FFF4"],
    "dream": ["#080A1C", "#2E3A8A", "#9AA8FF", "#F2F4FF"],
    "mark": ["#18060C", "#8A1430", "#FF5A7A", "#FFE6EC"],
    "dusk": ["#0E0A0A", "#4A3A3A", "#B8A8A0", "#F6F0EC"],
}

STATUS_KIND = {
    # badge kind per status id: buff (round, green-gold) / debuff (shield, red) / cc (hexagon, purple)
    "stun": "cc", "freeze": "cc", "root": "cc", "silence": "cc", "sleep": "cc", "confusion": "cc", "taunted": "cc",
    "blind": "debuff", "slow": "debuff", "bleed": "debuff", "poison": "debuff", "burn": "debuff", "weight": "debuff",
    "def_down": "debuff", "mark": "debuff", "atk_down": "debuff", "cast_slow": "debuff",
    "haste": "buff", "super_armor": "buff", "stealth": "buff", "invuln": "buff", "block": "buff", "atk_up": "buff",
    "def_up": "buff", "matk_up": "buff", "regen": "buff", "shield": "buff",
}

STATUS_NAMES = {
    "stun": ("眩晕", "Stun"), "freeze": ("冰冻", "Freeze"), "root": ("定身", "Root"), "silence": ("沉默", "Silence"),
    "sleep": ("睡眠", "Sleep"), "blind": ("致盲", "Blind"), "confusion": ("混乱", "Confusion"),
    "taunted": ("嘲讽", "Taunted"), "slow": ("减速", "Slow"), "haste": ("加速", "Haste"), "bleed": ("流血", "Bleed"),
    "poison": ("中毒", "Poison"), "burn": ("灼烧", "Burn"), "weight": ("负重", "Weight"),
    "super_armor": ("霸体", "Super Armor"), "stealth": ("隐身", "Stealth"), "invuln": ("无敌", "Invulnerable"),
    "block": ("格挡", "Block"), "atk_up": ("攻击提升", "Attack Up"), "def_up": ("防御提升", "Defense Up"),
    "def_down": ("破防", "Defense Down"), "matk_up": ("法攻提升", "Magic Up"), "regen": ("回复", "Regen"),
    "shield": ("护盾", "Shield"), "mark": ("印记", "Mark"), "atk_down": ("攻击降低", "Attack Down"),
    "cast_slow": ("施法减速", "Cast Slow"),
}

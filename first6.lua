--[[
	2t1 Studio UI Library  v3
	Base: DcusUI Series by iksuwu / Morten UI
	Enhanced by JSInvasor

	CORE
	[+] Background blur, open/close animation, stagger reveal
	[+] Live search, sliding tab indicator, ripple, hover lift
	[+] Config system with flags

	NEW IN V3
	[+] Command Palette         (Ctrl+K)
	[+] Config share/import     (base64 string)
	[+] Player list panel       (live, sortable, actions)
	[+] Tooltip system          (hover hints)
	[+] Notification history    (timestamped log)
	[+] Animated grid background
	[+] First-run guided tour
]]

local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting     = game:GetService("Lighting")
local RunService   = game:GetService("RunService")
local TextService  = game:GetService("TextService")
local HttpService  = game:GetService("HttpService")
local Players      = game:GetService("Players")
local Player       = Players.LocalPlayer

local DEFAULT_LOGO = "rbxassetid://122687530154939"

-- ============================================
-- BASE HELPERS
-- ============================================
local function getGuiParent()
	local ok, res = pcall(function() if gethui then return gethui() end end)
	if ok and res then return res end
	local ok2, res2 = pcall(function()
		if syn and syn.protect_gui then
			local gui = Player:WaitForChild("PlayerGui")
			syn.protect_gui(gui)
			return gui
		end
	end)
	if ok2 and res2 then return res2 end
	local ok3, res3 = pcall(function() return game:GetService("CoreGui") end)
	if ok3 and res3 then return res3 end
	return Player:WaitForChild("PlayerGui")
end

local function Create(class, props, children)
	local obj = Instance.new(class)
	for k, v in pairs(props or {}) do obj[k] = v end
	for _, c in pairs(children or {}) do c.Parent = obj end
	return obj
end

local function Tween(obj, time, props, style, dir)
	local t = TweenService:Create(
		obj,
		TweenInfo.new(time, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

-- ============================================
-- BASE64
-- ============================================
local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function b64encode(data)
	return ((data:gsub('.', function(x)
		local r, b = '', x:byte()
		for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0') end
		return r
	end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
		if #x < 6 then return '' end
		local c = 0
		for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0) end
		return B64:sub(c + 1, c + 1)
	end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

local function b64decode(data)
	data = data:gsub('[^' .. B64 .. '=]', '')
	return (data:gsub('=', ''):gsub('.', function(x)
		local r, f = '', (B64:find(x) - 1)
		for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0') end
		return r
	end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
		if #x ~= 8 then return '' end
		local c = 0
		for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0) end
		return string.char(c)
	end))
end

-- ============================================
-- FUZZY MATCH  (for command palette)
-- ============================================
local function fuzzyScore(text, query)
	if query == "" then return 1 end
	text = text:lower()
	query = query:lower()

	-- exact substring gets a big boost
	local sIdx = text:find(query, 1, true)
	if sIdx then
		return 1000 - sIdx - (#text * 0.1)
	end

	-- subsequence match
	local ti, score, streak = 1, 0, 0
	for qi = 1, #query do
		local qc = query:sub(qi, qi)
		local found = false
		while ti <= #text do
			if text:sub(ti, ti) == qc then
				found = true
				streak = streak + 1
				score = score + 10 + streak * 2
				if ti == 1 or text:sub(ti - 1, ti - 1) == " " then score = score + 15 end
				ti = ti + 1
				break
			end
			streak = 0
			ti = ti + 1
		end
		if not found then return nil end
	end
	return score - (#text * 0.05)
end

-- ============================================
-- THEME ENGINE
--
-- Every palette here is deliberately low saturation. The accent carries
-- just enough hue to read as a colour, and the surfaces underneath are
-- tinted a few points toward that same hue rather than being neutral grey.
-- That tint is what stops a dark interface from looking flat.
-- ============================================
local PALETTES = {

	Ash = {
		Label  = "Ash",
		Note   = "Warm neutral, the quiet default",
		accent = Color3.fromRGB(219, 214, 206),
		soft   = Color3.fromRGB(168, 163, 155),
		bgMain    = Color3.fromRGB(18, 17, 16),
		bgPanel   = Color3.fromRGB(23, 22, 20),
		bgElement = Color3.fromRGB(28, 27, 25),
		bgHover   = Color3.fromRGB(37, 35, 33),
		stroke    = Color3.fromRGB(62, 60, 56),
		strokeHot = Color3.fromRGB(116, 112, 105),
		textMain  = Color3.fromRGB(216, 212, 205),
		textDim   = Color3.fromRGB(146, 142, 136),
		textFade  = Color3.fromRGB(104, 101, 96),
	},

	Sage = {
		Label  = "Sage",
		Note   = "Muted green, dry and calm",
		accent = Color3.fromRGB(157, 176, 150),
		soft   = Color3.fromRGB(118, 133, 113),
		bgMain    = Color3.fromRGB(16, 19, 16),
		bgPanel   = Color3.fromRGB(21, 25, 21),
		bgElement = Color3.fromRGB(25, 30, 25),
		bgHover   = Color3.fromRGB(34, 40, 34),
		stroke    = Color3.fromRGB(56, 66, 55),
		strokeHot = Color3.fromRGB(104, 122, 100),
		textMain  = Color3.fromRGB(206, 214, 203),
		textDim   = Color3.fromRGB(137, 148, 134),
		textFade  = Color3.fromRGB(98, 108, 96),
	},

	Slate = {
		Label  = "Slate",
		Note   = "Cool blue grey, the workhorse",
		accent = Color3.fromRGB(146, 164, 186),
		soft   = Color3.fromRGB(108, 123, 142),
		bgMain    = Color3.fromRGB(15, 17, 21),
		bgPanel   = Color3.fromRGB(19, 22, 27),
		bgElement = Color3.fromRGB(23, 27, 33),
		bgHover   = Color3.fromRGB(31, 36, 44),
		stroke    = Color3.fromRGB(53, 60, 72),
		strokeHot = Color3.fromRGB(99, 112, 132),
		textMain  = Color3.fromRGB(202, 210, 222),
		textDim   = Color3.fromRGB(133, 142, 157),
		textFade  = Color3.fromRGB(95, 103, 116),
	},

	Clay = {
		Label  = "Clay",
		Note   = "Terracotta pulled most of the way to grey",
		accent = Color3.fromRGB(192, 146, 126),
		soft   = Color3.fromRGB(144, 109, 94),
		bgMain    = Color3.fromRGB(21, 18, 16),
		bgPanel   = Color3.fromRGB(26, 22, 20),
		bgElement = Color3.fromRGB(32, 27, 24),
		bgHover   = Color3.fromRGB(42, 35, 31),
		stroke    = Color3.fromRGB(70, 59, 52),
		strokeHot = Color3.fromRGB(128, 105, 92),
		textMain  = Color3.fromRGB(220, 210, 202),
		textDim   = Color3.fromRGB(151, 139, 131),
		textFade  = Color3.fromRGB(108, 99, 92),
	},

	Mauve = {
		Label  = "Mauve",
		Note   = "Dusty rose, soft without being sweet",
		accent = Color3.fromRGB(181, 152, 167),
		soft   = Color3.fromRGB(136, 114, 126),
		bgMain    = Color3.fromRGB(20, 17, 20),
		bgPanel   = Color3.fromRGB(25, 21, 25),
		bgElement = Color3.fromRGB(30, 26, 31),
		bgHover   = Color3.fromRGB(40, 34, 41),
		stroke    = Color3.fromRGB(67, 57, 68),
		strokeHot = Color3.fromRGB(123, 105, 122),
		textMain  = Color3.fromRGB(216, 208, 214),
		textDim   = Color3.fromRGB(148, 138, 147),
		textFade  = Color3.fromRGB(106, 98, 106),
	},

	Moss = {
		Label  = "Moss",
		Note   = "Deep olive, heavier than Sage",
		accent = Color3.fromRGB(146, 158, 122),
		soft   = Color3.fromRGB(109, 119, 91),
		bgMain    = Color3.fromRGB(17, 18, 14),
		bgPanel   = Color3.fromRGB(22, 23, 18),
		bgElement = Color3.fromRGB(26, 28, 21),
		bgHover   = Color3.fromRGB(35, 38, 29),
		stroke    = Color3.fromRGB(58, 62, 48),
		strokeHot = Color3.fromRGB(107, 115, 88),
		textMain  = Color3.fromRGB(208, 212, 198),
		textDim   = Color3.fromRGB(139, 145, 128),
		textFade  = Color3.fromRGB(99, 104, 91),
	},

	Fog = {
		Label  = "Fog",
		Note   = "Pale and cool, almost colourless",
		accent = Color3.fromRGB(182, 192, 202),
		soft   = Color3.fromRGB(136, 145, 155),
		bgMain    = Color3.fromRGB(16, 18, 20),
		bgPanel   = Color3.fromRGB(21, 23, 26),
		bgElement = Color3.fromRGB(25, 28, 31),
		bgHover   = Color3.fromRGB(34, 38, 42),
		stroke    = Color3.fromRGB(57, 62, 68),
		strokeHot = Color3.fromRGB(106, 115, 124),
		textMain  = Color3.fromRGB(210, 216, 222),
		textDim   = Color3.fromRGB(140, 147, 155),
		textFade  = Color3.fromRGB(100, 106, 113),
	},

	Sand = {
		Label  = "Sand",
		Note   = "Warm beige, paper under lamplight",
		accent = Color3.fromRGB(201, 184, 156),
		soft   = Color3.fromRGB(151, 138, 117),
		bgMain    = Color3.fromRGB(20, 19, 16),
		bgPanel   = Color3.fromRGB(25, 24, 20),
		bgElement = Color3.fromRGB(30, 29, 24),
		bgHover   = Color3.fromRGB(40, 38, 32),
		stroke    = Color3.fromRGB(68, 64, 55),
		strokeHot = Color3.fromRGB(126, 118, 100),
		textMain  = Color3.fromRGB(222, 216, 205),
		textDim   = Color3.fromRGB(152, 146, 134),
		textFade  = Color3.fromRGB(109, 104, 95),
	},

	Plum = {
		Label  = "Plum",
		Note   = "Restrained violet",
		accent = Color3.fromRGB(160, 145, 176),
		soft   = Color3.fromRGB(120, 109, 133),
		bgMain    = Color3.fromRGB(18, 16, 21),
		bgPanel   = Color3.fromRGB(22, 20, 27),
		bgElement = Color3.fromRGB(27, 24, 33),
		bgHover   = Color3.fromRGB(36, 32, 44),
		stroke    = Color3.fromRGB(61, 55, 73),
		strokeHot = Color3.fromRGB(113, 102, 130),
		textMain  = Color3.fromRGB(212, 206, 220),
		textDim   = Color3.fromRGB(145, 138, 156),
		textFade  = Color3.fromRGB(104, 98, 112),
	},

	Rust = {
		Label  = "Rust",
		Note   = "Burnt orange with the heat taken out",
		accent = Color3.fromRGB(189, 133, 110),
		soft   = Color3.fromRGB(142, 100, 83),
		bgMain    = Color3.fromRGB(21, 17, 15),
		bgPanel   = Color3.fromRGB(26, 21, 19),
		bgElement = Color3.fromRGB(32, 26, 22),
		bgHover   = Color3.fromRGB(43, 34, 29),
		stroke    = Color3.fromRGB(72, 57, 49),
		strokeHot = Color3.fromRGB(131, 102, 87),
		textMain  = Color3.fromRGB(219, 208, 200),
		textDim   = Color3.fromRGB(150, 137, 129),
		textFade  = Color3.fromRGB(107, 97, 91),
	},

	Verdigris = {
		Label  = "Verdigris",
		Note   = "Aged copper, blue leaning green",
		accent = Color3.fromRGB(132, 172, 168),
		soft   = Color3.fromRGB(99, 129, 126),
		bgMain    = Color3.fromRGB(14, 19, 19),
		bgPanel   = Color3.fromRGB(18, 24, 24),
		bgElement = Color3.fromRGB(22, 29, 29),
		bgHover   = Color3.fromRGB(29, 39, 39),
		stroke    = Color3.fromRGB(50, 65, 64),
		strokeHot = Color3.fromRGB(93, 120, 118),
		textMain  = Color3.fromRGB(202, 214, 212),
		textDim   = Color3.fromRGB(133, 149, 147),
		textFade  = Color3.fromRGB(95, 108, 107),
	},

	Ember = {
		Label  = "Ember",
		Note   = "Muted warm red, low and slow",
		accent = Color3.fromRGB(190, 129, 121),
		soft   = Color3.fromRGB(143, 97, 91),
		bgMain    = Color3.fromRGB(21, 16, 16),
		bgPanel   = Color3.fromRGB(26, 20, 20),
		bgElement = Color3.fromRGB(32, 25, 25),
		bgHover   = Color3.fromRGB(43, 33, 33),
		stroke    = Color3.fromRGB(72, 55, 55),
		strokeHot = Color3.fromRGB(131, 99, 96),
		textMain  = Color3.fromRGB(219, 207, 205),
		textDim   = Color3.fromRGB(150, 136, 134),
		textFade  = Color3.fromRGB(107, 96, 95),
	},

	Ink = {
		Label  = "Ink",
		Note   = "Near monochrome, the darkest of the set",
		accent = Color3.fromRGB(168, 172, 180),
		soft   = Color3.fromRGB(124, 128, 135),
		bgMain    = Color3.fromRGB(11, 12, 14),
		bgPanel   = Color3.fromRGB(15, 16, 18),
		bgElement = Color3.fromRGB(18, 20, 23),
		bgHover   = Color3.fromRGB(26, 28, 32),
		stroke    = Color3.fromRGB(45, 48, 54),
		strokeHot = Color3.fromRGB(88, 93, 102),
		textMain  = Color3.fromRGB(198, 202, 210),
		textDim   = Color3.fromRGB(129, 134, 142),
		textFade  = Color3.fromRGB(92, 96, 103),
	},

	Bone = {
		Label  = "Bone",
		Note   = "The brightest accent here, still not white",
		accent = Color3.fromRGB(232, 226, 214),
		soft   = Color3.fromRGB(176, 171, 161),
		bgMain    = Color3.fromRGB(19, 18, 17),
		bgPanel   = Color3.fromRGB(24, 23, 21),
		bgElement = Color3.fromRGB(29, 28, 26),
		bgHover   = Color3.fromRGB(39, 37, 35),
		stroke    = Color3.fromRGB(65, 62, 58),
		strokeHot = Color3.fromRGB(121, 116, 109),
		textMain  = Color3.fromRGB(224, 219, 210),
		textDim   = Color3.fromRGB(152, 147, 140),
		textFade  = Color3.fromRGB(108, 104, 99),
	},
}

local THEME_ORDER = {
	"Ash", "Bone", "Fog", "Ink", "Slate", "Verdigris",
	"Sage", "Moss", "Sand", "Clay", "Rust", "Ember", "Mauve", "Plum",
}

-- live theme. Everything reads through this table, so mutating it in
-- place is enough for hover handlers and anything created later.
local T = {}
local CURRENT_THEME = "Ash"

local function applyPalette(name)
	local p = PALETTES[name] or PALETTES.Ash
	for k, v in pairs(p) do
		if typeof(v) == "Color3" then T[k] = v end
	end
	CURRENT_THEME = PALETTES[name] and name or "Ash"
end

applyPalette(CURRENT_THEME)

-- status colours stay constant across themes; meaning should not shift
-- when someone changes the look of the interface
local GREEN  = Color3.fromRGB(112, 186, 138)
local RED    = Color3.fromRGB(196, 108, 112)
local YELLOW = Color3.fromRGB(202, 172, 110)
local BLUE   = Color3.fromRGB(122, 152, 186)

-- ============================================
-- ICON REGISTRY
-- Reference by name ("sword") or pass a raw id.
-- Library:IconBrowser() shows every icon in a grid.
-- ============================================
local ICONS = {
	-- combat
	sword       = "rbxassetid://10734953822",
	shield      = "rbxassetid://10734950498",
	crosshair   = "rbxassetid://10709790948",
	target      = "rbxassetid://10747362391",
	zap         = "rbxassetid://10709825498",
	flame       = "rbxassetid://10723345591",
	skull       = "rbxassetid://10747371034",
	bomb        = "rbxassetid://10709752996",

	-- vision
	eye         = "rbxassetid://10747384394",
	eyeoff      = "rbxassetid://10747385081",
	scan        = "rbxassetid://10734948496",
	radar       = "rbxassetid://10734938481",
	sun         = "rbxassetid://10734950020",
	moon        = "rbxassetid://10734895698",
	sparkles    = "rbxassetid://10734949856",
	palette     = "rbxassetid://10734907910",

	-- player
	home        = "rbxassetid://10723407389",
	user        = "rbxassetid://10747373176",
	users       = "rbxassetid://10747373176",
	run         = "rbxassetid://10734941257",
	footprints  = "rbxassetid://10723379903",
	heart       = "rbxassetid://10723363467",
	activity    = "rbxassetid://10709752996",
	compass     = "rbxassetid://10709793943",

	-- interface
	gear        = "rbxassetid://10710000090",
	settings    = "rbxassetid://10734950309",
	wrench      = "rbxassetid://10709821338",
	sliders     = "rbxassetid://10734949856",
	toggleon    = "rbxassetid://10734924532",
	layers      = "rbxassetid://10710110498",
	layout      = "rbxassetid://10734884548",
	grid        = "rbxassetid://10734886735",
	box         = "rbxassetid://10709780578",
	package     = "rbxassetid://10734905910",
	puzzle      = "rbxassetid://10734944950",

	-- actions
	search      = "rbxassetid://10734943674",
	filter      = "rbxassetid://10734879532",
	check       = "rbxassetid://10709790644",
	x           = "rbxassetid://10747384394",
	plus        = "rbxassetid://10734898355",
	minus       = "rbxassetid://10734896206",
	refresh     = "rbxassetid://10734937861",
	download    = "rbxassetid://10723345591",
	upload      = "rbxassetid://10723371055",
	copy        = "rbxassetid://10734898355",
	trash       = "rbxassetid://10734923549",
	save        = "rbxassetid://10734943674",
	edit        = "rbxassetid://10734898355",
	link        = "rbxassetid://10734889307",

	-- feedback
	info        = "rbxassetid://10723415903",
	alert       = "rbxassetid://10723345886",
	bell        = "rbxassetid://10722957797",
	clock       = "rbxassetid://10709793671",
	star        = "rbxassetid://10734949856",
	bookmark    = "rbxassetid://10709761889",

	-- navigation
	arrowupdown = "rbxassetid://10709768538",
	arrowright  = "rbxassetid://10709767827",
	arrowleft   = "rbxassetid://10709767256",
	chevronup   = "rbxassetid://10709790644",
	cornerright = "rbxassetid://10709812485",
	move        = "rbxassetid://10734896206",
	maximize    = "rbxassetid://10734892765",

	-- system
	terminal    = "rbxassetid://10734886735",
	command     = "rbxassetid://10734884548",
	keyboard    = "rbxassetid://10723379903",
	code        = "rbxassetid://10734898355",
	cpu         = "rbxassetid://10723345886",
	database    = "rbxassetid://10723345591",
	globe       = "rbxassetid://10734886735",
	wifi        = "rbxassetid://10734955230",
	lock        = "rbxassetid://10734891566",
	unlock      = "rbxassetid://10734892765",
	type        = "rbxassetid://10734924532",
	list        = "rbxassetid://10734898355",
}

-- friendly aliases
ICONS.Sword, ICONS.Shield, ICONS.Eye        = ICONS.sword, ICONS.shield, ICONS.eye
ICONS.Crosshair, ICONS.Gear, ICONS.Wrench   = ICONS.crosshair, ICONS.gear, ICONS.wrench
ICONS.Zap, ICONS.Layers, ICONS.Home         = ICONS.zap, ICONS.layers, ICONS.home
ICONS.arrowupdown, ICONS.cornerright        = ICONS.arrowupdown, ICONS.cornerright
ICONS.Puzzle, ICONS.box, ICONS.search       = ICONS.puzzle, ICONS.box, ICONS.search
ICONS.check, ICONS.info, ICONS.alert        = ICONS.check, ICONS.info, ICONS.alert
ICONS.keyboard, ICONS.users, ICONS.bell     = ICONS.keyboard, ICONS.users, ICONS.bell
ICONS.Command, ICONS.Terminal, ICONS.Star   = ICONS.command, ICONS.terminal, ICONS.star
ICONS.Copy, ICONS.Download, ICONS.Heart     = ICONS.copy, ICONS.download, ICONS.heart
ICONS.Target, ICONS.Sliders, ICONS.Type     = ICONS.target, ICONS.sliders, ICONS.type
ICONS.List                                   = ICONS.list

local DEFAULT_SECTION_ICON = ICONS.zap

-- Resolve an icon reference: "sword" | "rbxassetid://123" | 123 | nil
local function ResolveIcon(ref, fallback)
	if ref == nil then return fallback end
	if typeof(ref) == "number" then return "rbxassetid://" .. ref end
	if typeof(ref) ~= "string" then return fallback end
	if ref:match("^rbxassetid://%d+$") then return ref end
	if ref:match("^%d+$") then return "rbxassetid://" .. ref end
	local key = ref:lower():gsub("[%s%-_]", "")
	return ICONS[key] or ICONS[ref] or fallback
end

local DEFAULT_CATEGORY_ICONS = {
	["Main"] = ICONS.puzzle,  ["Combat"]  = ICONS.sword,  ["Player"]  = ICONS.run,
	["Misc"] = ICONS.box,     ["Settings"]= ICONS.gear,   ["Visuals"] = ICONS.eye,
	["Config"] = ICONS.layers,["Players"] = ICONS.users,  ["World"]   = ICONS.globe,
	["Movement"] = ICONS.run, ["Farm"]    = ICONS.refresh,["Teleport"]= ICONS.compass,
}

-- element type -> palette icon
local TYPE_ICONS = {
	Toggle   = ICONS.toggleon,
	Slider   = ICONS.sliders,
	Dropdown = ICONS.list,
	Button   = ICONS.zap,
	Keybind  = ICONS.keyboard,
	Textbox  = ICONS.type,
	Command  = ICONS.terminal,
}

-- ============================================
-- LIBRARY ROOT
-- ============================================
local Library = {}
Library.__index = Library

Library.ToggleKey    = Enum.KeyCode.RightControl
Library.Flags        = {}
Library.FlagSetters  = {}
Library.ConfigFolder = "2t1Studio"
Library.Keybinds     = {}
Library.BlurEnabled  = true
Library.AnimatedBG   = true
Library.TooltipsOn   = true
Library._blur        = nil
Library._windows     = {}
Library._notifLog    = {}
Library._commands    = {}
Library._registry    = {}    -- searchable elements for palette
Library.Icons        = ICONS
Library.Themes       = PALETTES
Library.ThemeOrder   = THEME_ORDER

-- ============================================
-- THEME SWITCHING
--
-- Instances already on screen were built with the previous palette, so
-- rather than tracking every one of them we walk the interface and swap
-- any colour that matches a role in the outgoing palette. Because the
-- palettes have no duplicate values inside a role set, the match is exact.
-- ============================================
local THEME_PROPS = {
	BackgroundColor3    = true,
	TextColor3          = true,
	ImageColor3         = true,
	Color               = true,   -- UIStroke
	ScrollBarImageColor3= true,
	PlaceholderColor3   = true,
}

local THEME_ROLES = {
	"accent", "soft", "bgMain", "bgPanel", "bgElement", "bgHover",
	"stroke", "strokeHot", "textMain", "textDim", "textFade",
}

local function sameColor(a, b)
	if typeof(a) ~= "Color3" or typeof(b) ~= "Color3" then return false end
	return math.abs(a.R - b.R) < 0.004
		and math.abs(a.G - b.G) < 0.004
		and math.abs(a.B - b.B) < 0.004
end

local function libraryGuis()
	local out = {}
	local parent = getGuiParent()
	for _, name in ipairs({
		"2t1Studio_UI", "2t1Studio_Notifications", "2t1Studio_Keybinds",
		"2t1Studio_Players", "2t1Studio_History", "2t1Studio_Palette",
		"2t1Studio_Tooltip", "2t1Studio_Icons",
	}) do
		local g = parent:FindFirstChild(name) or Player.PlayerGui:FindFirstChild(name)
		if g then out[#out + 1] = g end
	end
	return out
end

function Library:GetTheme()
	return CURRENT_THEME, PALETTES[CURRENT_THEME]
end

function Library:ListThemes()
	local out = {}
	for _, name in ipairs(THEME_ORDER) do
		if PALETTES[name] then out[#out + 1] = name end
	end
	return out
end

function Library:SetTheme(name, instant)
	local target = PALETTES[name]
	if not target then return false end
	if name == CURRENT_THEME then return true end

	-- snapshot the outgoing values before T is mutated
	local prev = {}
	for _, role in ipairs(THEME_ROLES) do prev[role] = T[role] end

	applyPalette(name)

	local dur = instant and 0 or 0.35
	local swapped = 0

	for _, gui in ipairs(libraryGuis()) do
		for _, inst in ipairs(gui:GetDescendants()) do
			for prop in pairs(THEME_PROPS) do
				local ok, current = pcall(function() return inst[prop] end)
				if ok and typeof(current) == "Color3" then
					for _, role in ipairs(THEME_ROLES) do
						if sameColor(current, prev[role]) then
							local newColor = T[role]
							if dur > 0 then
								TweenService:Create(inst,
									TweenInfo.new(dur, Enum.EasingStyle.Quart),
									{ [prop] = newColor }):Play()
							else
								pcall(function() inst[prop] = newColor end)
							end
							swapped = swapped + 1
							break
						end
					end
				end
			end
		end
	end

	Library.Flags["ui_theme"] = name
	if Library._onThemeChanged then pcall(Library._onThemeChanged, name) end

	return true, swapped
end

-- Overrides just the accent while keeping the surfaces of the current theme.
function Library:SetAccent(color, instant)
	if typeof(color) ~= "Color3" then return false end
	local prevAccent = T.accent
	local prevSoft   = T.soft

	T.accent = color
	T.soft   = color:Lerp(Color3.fromRGB(90, 90, 96), 0.4)

	local dur = instant and 0 or 0.3
	for _, gui in ipairs(libraryGuis()) do
		for _, inst in ipairs(gui:GetDescendants()) do
			for prop in pairs(THEME_PROPS) do
				local ok, current = pcall(function() return inst[prop] end)
				if ok and typeof(current) == "Color3" then
					local newColor
					if sameColor(current, prevAccent) then newColor = T.accent
					elseif sameColor(current, prevSoft) then newColor = T.soft end
					if newColor then
						if dur > 0 then
							TweenService:Create(inst,
								TweenInfo.new(dur, Enum.EasingStyle.Quart),
								{ [prop] = newColor }):Play()
						else
							pcall(function() inst[prop] = newColor end)
						end
						break
					end
				end
			end
		end
	end
	Library.Flags["ui_accent"] = color
	return true
end
Library.Icon         = function(_, ref) return ResolveIcon(ref, DEFAULT_SECTION_ICON) end

-- ============================================
-- FILE / CONFIG
-- ============================================
local function hasFileAPI()
	return (writefile and readfile and isfile) and true or false
end

local function ensureFolder()
	if not hasFileAPI() then return false end
	pcall(function()
		if isfolder and not isfolder(Library.ConfigFolder) then
			if makefolder then makefolder(Library.ConfigFolder) end
		end
	end)
	return true
end

local function serializeFlags()
	local data = {}
	for flag, value in pairs(Library.Flags) do
		if typeof(value) == "EnumItem" then
			data[flag] = { __enum = true, name = value.Name }
		elseif typeof(value) == "Color3" then
			data[flag] = { __color = true, r = value.R, g = value.G, b = value.B }
		elseif typeof(value) == "table" then
			data[flag] = { __list = true, items = value }
		else
			data[flag] = value
		end
	end
	return data
end

local function applyFlags(data)
	local applied = 0

	-- the theme has to land before anything else, otherwise every element
	-- gets recoloured twice and the second pass fights the first
	if data.ui_theme and type(data.ui_theme) == "string" then
		pcall(function() Library:SetTheme(data.ui_theme, true) end)
	end

	for flag, value in pairs(data) do
		local setter = Library.FlagSetters[flag]
		if setter then
			local final = value
			if typeof(value) == "table" then
				if value.__enum then
					final = Enum.KeyCode[value.name]
				elseif value.__color then
					final = Color3.new(value.r, value.g, value.b)
				elseif value.__list then
					final = value.items
				end
			end
			local ok = pcall(setter, final)
			if ok then applied = applied + 1 end
		end
	end
	return applied
end

function Library:SaveConfig(name)
	if not hasFileAPI() then return false, "no file api" end
	ensureFolder()
	name = name or "default"
	local ok, encoded = pcall(function() return HttpService:JSONEncode(serializeFlags()) end)
	if not ok then return false, "encode fail" end
	local ok2 = pcall(function()
		writefile(Library.ConfigFolder .. "/" .. name .. ".json", encoded)
	end)
	return ok2
end

function Library:LoadConfig(name)
	if not hasFileAPI() then return false, "no file api" end
	name = name or "default"
	local path = Library.ConfigFolder .. "/" .. name .. ".json"
	if not isfile(path) then return false, "not found" end
	local ok, raw = pcall(function() return readfile(path) end)
	if not ok then return false, "read fail" end
	local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if not ok2 then return false, "decode fail" end
	return true, applyFlags(data)
end

function Library:ListConfigs()
	local out = {}
	if not hasFileAPI() or not listfiles then return out end
	ensureFolder()
	local ok, files = pcall(function() return listfiles(Library.ConfigFolder) end)
	if not ok then return out end
	for _, f in pairs(files) do
		local n = f:match("([^/\\]+)%.json$")
		if n then table.insert(out, n) end
	end
	table.sort(out)
	return out
end

function Library:DeleteConfig(name)
	if not hasFileAPI() or not delfile then return false end
	local path = Library.ConfigFolder .. "/" .. name .. ".json"
	if isfile(path) then
		pcall(function() delfile(path) end)
		return true
	end
	return false
end

-- ---------- SHARE / IMPORT ----------
function Library:ExportConfig()
	local ok, json = pcall(function() return HttpService:JSONEncode(serializeFlags()) end)
	if not ok then return nil end
	local payload = "2T1|" .. json
	local encoded = b64encode(payload)
	if setclipboard then pcall(setclipboard, encoded) end
	return encoded
end

function Library:ImportConfig(str)
	if type(str) ~= "string" or str == "" then return false, "empty" end
	str = str:gsub("%s", "")
	local ok, decoded = pcall(b64decode, str)
	if not ok or not decoded then return false, "bad string" end
	if not decoded:match("^2T1|") then return false, "not a 2t1 config" end
	local json = decoded:sub(5)
	local ok2, data = pcall(function() return HttpService:JSONDecode(json) end)
	if not ok2 then return false, "corrupt data" end
	local n = applyFlags(data)
	return true, n
end

-- ============================================
-- TOOLTIP  (single global instance)
-- ============================================
local Tooltip = { Gui = nil, Frame = nil, Label = nil, Target = nil, Token = 0 }

local function initTooltip()
	if Tooltip.Gui then return end
	local gui = Create("ScreenGui", {
		Name = "2t1Studio_Tooltip", ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 9999, IgnoreGuiInset = true, Parent = getGuiParent()
	})
	local frame = Create("Frame", {
		Size = UDim2.fromOffset(10, 10), BackgroundColor3 = Color3.fromRGB(12, 12, 17),
		BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
		ZIndex = 500, Parent = gui
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 7) }),
		Create("UIStroke", { Color = T.stroke, Thickness = 1, Transparency = 1 })
	})
	local label = Create("TextLabel", {
		Text = "", Font = Enum.Font.GothamMedium, TextSize = 12,
		TextColor3 = Color3.fromRGB(225, 225, 235), BackgroundTransparency = 1,
		TextTransparency = 1, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 1, -16),
		ZIndex = 501, Parent = frame
	})
	Tooltip.Gui, Tooltip.Frame, Tooltip.Label = gui, frame, label
end

local function showTooltip(text)
	if not Library.TooltipsOn then return end
	initTooltip()
	local f, l = Tooltip.Frame, Tooltip.Label
	l.Text = text

	local ts = TextService:GetTextSize(text, 12, Enum.Font.GothamMedium, Vector2.new(240, 400))
	local w = math.min(260, ts.X + 20)
	local h = ts.Y + 16

	local mouse = UIS:GetMouseLocation()
	local vp = workspace.CurrentCamera.ViewportSize
	local px = math.min(mouse.X + 16, vp.X - w - 10)
	local py = mouse.Y + 18
	if py + h > vp.Y - 10 then py = mouse.Y - h - 12 end

	f.Size = UDim2.fromOffset(w, h)
	f.Position = UDim2.fromOffset(px, py)
	f.Visible = true

	local stroke = f:FindFirstChildOfClass("UIStroke")
	Tween(f, 0.16, { BackgroundTransparency = 0.05 })
	Tween(stroke, 0.16, { Transparency = 0.4 })
	Tween(l, 0.16, { TextTransparency = 0 })
end

local function hideTooltip()
	if not Tooltip.Frame then return end
	local f, l = Tooltip.Frame, Tooltip.Label
	local stroke = f:FindFirstChildOfClass("UIStroke")
	Tween(f, 0.12, { BackgroundTransparency = 1 })
	Tween(stroke, 0.12, { Transparency = 1 })
	Tween(l, 0.12, { TextTransparency = 1 })
	task.delay(0.15, function()
		if Tooltip.Frame and Tooltip.Frame.BackgroundTransparency >= 1 then
			Tooltip.Frame.Visible = false
		end
	end)
end

local function AttachTooltip(guiObject, text)
	if not text or text == "" then return end
	guiObject.MouseEnter:Connect(function()
		Tooltip.Token = Tooltip.Token + 1
		local myToken = Tooltip.Token
		task.delay(0.55, function()
			if Tooltip.Token == myToken then showTooltip(text) end
		end)
	end)
	guiObject.MouseLeave:Connect(function()
		Tooltip.Token = Tooltip.Token + 1
		hideTooltip()
	end)
end

-- ============================================
-- NOTIFICATIONS  (+ history)
-- ============================================
local NOTIF_STYLES = {
	info    = { color = BLUE,   bg = Color3.fromRGB(17, 23, 36), stroke = Color3.fromRGB(52, 78, 128) },
	success = { color = GREEN,  bg = Color3.fromRGB(15, 29, 23), stroke = Color3.fromRGB(44, 104, 70) },
	error   = { color = RED,    bg = Color3.fromRGB(32, 17, 21), stroke = Color3.fromRGB(124, 48, 56) },
	warning = { color = YELLOW, bg = Color3.fromRGB(32, 27, 15), stroke = Color3.fromRGB(122, 98, 42) },
}

function Library:Notify(cfg)
	cfg = cfg or {}
	local title    = cfg.Title or "Notification"
	local content  = cfg.Content or ""
	local duration = cfg.Time or 5
	local kind     = (cfg.Type or "info"):lower()
	local style    = NOTIF_STYLES[kind] or NOTIF_STYLES.info

	table.insert(Library._notifLog, 1, {
		Title = title, Content = content, Type = kind,
		Time = os.date("%H:%M:%S"), Stamp = os.time()
	})
	if #Library._notifLog > 60 then table.remove(Library._notifLog) end
	if Library._onNotifLogged then pcall(Library._onNotifLogged) end

	if cfg.Silent then return end

	local parent = getGuiParent()
	local gui = parent:FindFirstChild("2t1Studio_Notifications")
	if not gui then
		gui = Create("ScreenGui", {
			Name = "2t1Studio_Notifications", ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 900, Parent = parent
		})
	end
	local holder = gui:FindFirstChild("Holder")
	if not holder then
		holder = Create("Frame", {
			Name = "Holder", Size = UDim2.new(0, 296, 1, -20),
			Position = UDim2.new(1, -308, 0, 10), BackgroundTransparency = 1, Parent = gui
		}, {
			Create("UIListLayout", {
				VerticalAlignment = Enum.VerticalAlignment.Top,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8)
			})
		})
	end

	local card = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = style.bg,
		BackgroundTransparency = 1, BorderSizePixel = 0,
		ClipsDescendants = true, Parent = holder
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Create("UIStroke", { Color = style.stroke, Thickness = 1.2, Transparency = 1 })
	})
	local cardStroke = card:FindFirstChildOfClass("UIStroke")

	-- subtle vertical sheen so the tint reads as a surface, not flat colour
	Create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(196, 196, 206))
		}),
		Parent = card
	})

	local logo = Create("ImageLabel", {
		Image = DEFAULT_LOGO, Size = UDim2.fromOffset(24, 24),
		Position = UDim2.fromOffset(14, 13), BackgroundTransparency = 1,
		ImageColor3 = Color3.fromRGB(255, 255, 255), ImageTransparency = 1,
		ScaleType = Enum.ScaleType.Fit, Parent = card
	})

	local titleLbl = Create("TextLabel", {
		Text = title, Font = Enum.Font.GothamBold, TextSize = 13,
		TextColor3 = style.color, BackgroundTransparency = 1, TextTransparency = 1,
		Position = UDim2.fromOffset(48, 11), Size = UDim2.new(1, -62, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = card
	})

	local bodyLbl = Create("TextLabel", {
		Text = content, Font = Enum.Font.GothamMedium, TextSize = 12,
		TextColor3 = Color3.fromRGB(206, 210, 220), BackgroundTransparency = 1, TextTransparency = 1,
		Position = UDim2.fromOffset(48, 29), Size = UDim2.new(1, -62, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true, Parent = card
	})

	-- inset progress bar so rounded corners stay clean
	local progressBg = Create("Frame", {
		Size = UDim2.new(1, -28, 0, 3), Position = UDim2.new(0, 14, 1, -10),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 1,
		BorderSizePixel = 0, Parent = card
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	local progress = Create("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = style.color,
		BackgroundTransparency = 1, BorderSizePixel = 0, Parent = progressBg
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	local ts = TextService:GetTextSize(content, 12, Enum.Font.GothamMedium, Vector2.new(234, 10000))
	local targetH = math.max(56, ts.Y + 48)
	bodyLbl.Size = UDim2.new(1, -62, 0, ts.Y)

	Tween(card, 0.45, { Size = UDim2.new(1, 0, 0, targetH), BackgroundTransparency = 0.04 }, Enum.EasingStyle.Back)
	Tween(cardStroke, 0.4, { Transparency = 0.25 })
	Tween(logo, 0.4, { ImageTransparency = 0 })
	Tween(titleLbl, 0.4, { TextTransparency = 0 })
	Tween(bodyLbl, 0.4, { TextTransparency = 0.08 })
	Tween(progressBg, 0.4, { BackgroundTransparency = 0.88 })
	Tween(progress, 0.4, { BackgroundTransparency = 0.15 })
	Tween(progress, duration, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Linear)

	task.delay(duration, function()
		Tween(card, 0.35, { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1 },
			Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Tween(cardStroke, 0.3, { Transparency = 1 })
		Tween(logo, 0.3, { ImageTransparency = 1 })
		Tween(titleLbl, 0.3, { TextTransparency = 1 })
		Tween(bodyLbl, 0.3, { TextTransparency = 1 })
		Tween(progressBg, 0.3, { BackgroundTransparency = 1 })
		Tween(progress, 0.3, { BackgroundTransparency = 1 })
		task.delay(0.4, function() card:Destroy() end)
	end)
end

-- ============================================
-- FLOATING PANEL BASE  (used by player list / history)
-- ============================================
local function CreateFloatingPanel(cfg)
	local name   = cfg.Name or "Panel"
	local title  = cfg.Title or "Panel"
	local icon   = cfg.Icon or ICONS.box
	local w      = cfg.Width or 260
	local h      = cfg.Height or 320
	local pos    = cfg.Position or UDim2.new(0, 30, 0.5, -h / 2)

	local parent = getGuiParent()
	local old = parent:FindFirstChild(name)
	if old then old:Destroy() end

	local gui = Create("ScreenGui", {
		Name = name, ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 800, Parent = parent
	})

	local main = Create("Frame", {
		Size = UDim2.fromOffset(w, h), Position = pos,
		BackgroundColor3 = T.bgMain, BackgroundTransparency = 0.08,
		BorderSizePixel = 0, ClipsDescendants = true, Parent = gui
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 11) }),
		Create("UIStroke", { Color = Color3.fromRGB(70, 70, 82), Thickness = 1.4, Transparency = 0.25 })
	})
	local scale = Create("UIScale", { Scale = 0.9, Parent = main })

	local top = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = Color3.fromRGB(20, 20, 28),
		BackgroundTransparency = 0.4, BorderSizePixel = 0, Parent = main
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 11) }) })

	Create("Frame", {
		Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1),
		BackgroundColor3 = Color3.fromRGB(90, 90, 105), BackgroundTransparency = 0.6,
		BorderSizePixel = 0, Parent = top
	})

	Create("ImageLabel", {
		Image = icon, Size = UDim2.fromOffset(15, 15),
		Position = UDim2.fromOffset(12, 11), BackgroundTransparency = 1,
		ImageColor3 = T.accent, ScaleType = Enum.ScaleType.Fit, ZIndex = 3, Parent = top
	})

	local titleLbl = Create("TextLabel", {
		Text = title, Font = Enum.Font.GothamBold, TextSize = 13,
		TextColor3 = Color3.fromRGB(240, 240, 248), BackgroundTransparency = 1,
		Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -70, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Parent = top
	})

	local closeBtn = Create("TextButton", {
		Text = "", Size = UDim2.fromOffset(20, 20),
		Position = UDim2.new(1, -28, 0.5, -10), BackgroundColor3 = Color3.fromRGB(40, 40, 50),
		BackgroundTransparency = 0.4, AutoButtonColor = false, ZIndex = 4, Parent = top
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	Create("TextLabel", {
		Text = "×", Font = Enum.Font.GothamBold, TextSize = 16,
		TextColor3 = T.textDim, BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = closeBtn
	})

	closeBtn.MouseEnter:Connect(function()
		Tween(closeBtn, 0.15, { BackgroundColor3 = RED, BackgroundTransparency = 0.1 })
	end)
	closeBtn.MouseLeave:Connect(function()
		Tween(closeBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(40, 40, 50), BackgroundTransparency = 0.4 })
	end)

	local body = Create("Frame", {
		Name = "Body", Size = UDim2.new(1, 0, 1, -38), Position = UDim2.fromOffset(0, 38),
		BackgroundTransparency = 1, ClipsDescendants = true, Parent = main
	})

	-- drag
	do
		local dragging, dragStart, startPos
		top.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true; dragStart = input.Position; startPos = main.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then dragging = false end
				end)
			end
		end)
		UIS.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
				local d = input.Position - dragStart
				main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
					startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end)
	end

	local panel = { Gui = gui, Main = main, Body = body, Top = top, Title = titleLbl, Open = false }

	function panel:Show()
		panel.Open = true
		gui.Enabled = true
		scale.Scale = 0.9
		main.BackgroundTransparency = 1
		Tween(scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		Tween(main, 0.3, { BackgroundTransparency = 0.08 })
	end
	function panel:Hide()
		panel.Open = false
		Tween(scale, 0.25, { Scale = 0.92 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Tween(main, 0.22, { BackgroundTransparency = 1 })
		task.delay(0.28, function() if not panel.Open then gui.Enabled = false end end)
	end
	function panel:Toggle()
		if panel.Open then panel:Hide() else panel:Show() end
	end

	closeBtn.MouseButton1Click:Connect(function() panel:Hide() end)

	gui.Enabled = false
	return panel
end

-- ============================================
-- NOTIFICATION HISTORY PANEL
-- ============================================
local HistoryPanel = nil

local function buildHistoryPanel()
	if HistoryPanel then return HistoryPanel end

	local panel = CreateFloatingPanel({
		Name = "2t1Studio_History", Title = "Notifications",
		Icon = ICONS.bell, Width = 300, Height = 340,
		Position = UDim2.new(1, -330, 0, 60)
	})

	local scroll = Create("ScrollingFrame", {
		Size = UDim2.new(1, -12, 1, -46), Position = UDim2.fromOffset(6, 6),
		BackgroundTransparency = 1, ScrollBarThickness = 2,
		ScrollBarImageColor3 = T.accent, ScrollBarImageTransparency = 0.5,
		CanvasSize = UDim2.new(0, 0, 0, 0), Parent = panel.Body
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2) })
	})
	local layout = scroll:FindFirstChildOfClass("UIListLayout")
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
	end)

	local clearBtn = Create("TextButton", {
		Text = "Clear history", Font = Enum.Font.GothamBold, TextSize = 11,
		TextColor3 = T.textDim, BackgroundColor3 = Color3.fromRGB(30, 30, 40),
		BackgroundTransparency = 0.2, AutoButtonColor = false,
		Size = UDim2.new(1, -12, 0, 28), Position = UDim2.new(0, 6, 1, -34),
		Parent = panel.Body
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 7) }),
		Create("UIStroke", { Color = T.stroke, Thickness = 1, Transparency = 0.4 })
	})

	local empty = Create("TextLabel", {
		Text = "Nothing here yet", Font = Enum.Font.GothamMedium, TextSize = 12,
		TextColor3 = T.textFade, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, 40),
		Visible = false, Parent = panel.Body
	})

	local function refresh()
		for _, c in pairs(scroll:GetChildren()) do
			if c:IsA("Frame") then c:Destroy() end
		end
		empty.Visible = (#Library._notifLog == 0)

		for i, entry in ipairs(Library._notifLog) do
			local style = NOTIF_STYLES[entry.Type] or NOTIF_STYLES.info

			local row = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = style.bg,
				BackgroundTransparency = 0.15, BorderSizePixel = 0,
				LayoutOrder = i, Parent = scroll
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Create("UIStroke", { Color = style.stroke, Thickness = 1, Transparency = 0.45 })
			})

			Create("ImageLabel", {
				Image = DEFAULT_LOGO, Size = UDim2.fromOffset(16, 16),
				Position = UDim2.fromOffset(10, 7), BackgroundTransparency = 1,
				ImageColor3 = Color3.fromRGB(255, 255, 255),
				ScaleType = Enum.ScaleType.Fit, Parent = row
			})

			Create("TextLabel", {
				Text = entry.Title, Font = Enum.Font.GothamBold, TextSize = 11.5,
				TextColor3 = style.color, BackgroundTransparency = 1,
				Position = UDim2.fromOffset(32, 6), Size = UDim2.new(1, -84, 0, 15),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd, Parent = row
			})

			Create("TextLabel", {
				Text = entry.Time, Font = Enum.Font.Code, TextSize = 10,
				TextColor3 = Color3.fromRGB(150, 155, 168), BackgroundTransparency = 1,
				Position = UDim2.new(1, -54, 0, 6), Size = UDim2.fromOffset(46, 15),
				TextXAlignment = Enum.TextXAlignment.Right, Parent = row
			})

			Create("TextLabel", {
				Text = entry.Content, Font = Enum.Font.GothamMedium, TextSize = 11,
				TextColor3 = Color3.fromRGB(178, 182, 194), BackgroundTransparency = 1,
				Position = UDim2.fromOffset(32, 23), Size = UDim2.new(1, -44, 0, 18),
				TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
				TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row
			})
		end
	end

	clearBtn.MouseEnter:Connect(function()
		Tween(clearBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(48, 30, 34) })
	end)
	clearBtn.MouseLeave:Connect(function()
		Tween(clearBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(30, 30, 40) })
	end)
	clearBtn.MouseButton1Click:Connect(function()
		Library._notifLog = {}
		refresh()
	end)

	Library._onNotifLogged = function()
		if panel.Open then refresh() end
	end

	local oldShow = panel.Show
	function panel:Show()
		refresh()
		oldShow(panel)
	end

	HistoryPanel = panel
	return panel
end

function Library:ShowHistory()
	buildHistoryPanel():Show()
end
function Library:ToggleHistory()
	local p = buildHistoryPanel()
	p:Toggle()
end

-- ============================================
-- PLAYER LIST PANEL
-- ============================================
local PlayerPanel = nil

local function getDistance(target)
	local myChar = Player.Character
	local tChar = target.Character
	if not myChar or not tChar then return nil end
	local a = myChar:FindFirstChild("HumanoidRootPart")
	local b = tChar:FindFirstChild("HumanoidRootPart")
	if not a or not b then return nil end
	return (a.Position - b.Position).Magnitude
end

local function buildPlayerPanel()
	if PlayerPanel then return PlayerPanel end

	local panel = CreateFloatingPanel({
		Name = "2t1Studio_Players", Title = "Players",
		Icon = ICONS.users, Width = 290, Height = 380,
		Position = UDim2.new(0, 30, 0.5, -190)
	})

	-- sort bar
	local sortBar = Create("Frame", {
		Size = UDim2.new(1, -12, 0, 26), Position = UDim2.fromOffset(6, 4),
		BackgroundColor3 = Color3.fromRGB(24, 24, 32), BackgroundTransparency = 0.35,
		BorderSizePixel = 0, Parent = panel.Body
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })

	local sortMode = "distance"
	local sortButtons = {}

	local function makeSortBtn(text, mode, x, w)
		local b = Create("TextButton", {
			Text = text, Font = Enum.Font.GothamBold, TextSize = 10,
			TextColor3 = T.textFade, BackgroundColor3 = T.accent,
			BackgroundTransparency = 1, AutoButtonColor = false,
			Position = UDim2.fromOffset(x, 3), Size = UDim2.fromOffset(w, 20),
			Parent = sortBar
		}, { Create("UICorner", { CornerRadius = UDim.new(0, 5) }) })
		sortButtons[mode] = b
		return b
	end

	local function refreshSortVisuals()
		for mode, b in pairs(sortButtons) do
			local on = (mode == sortMode)
			Tween(b, 0.15, { BackgroundTransparency = on and 0.85 or 1 })
			Tween(b, 0.15, { TextColor3 = on and T.accent or T.textFade })
		end
	end

	local rowsHolder
	local refreshList

	makeSortBtn("DISTANCE", "distance", 4, 74).MouseButton1Click:Connect(function()
		sortMode = "distance"; refreshSortVisuals(); refreshList()
	end)
	makeSortBtn("NAME", "name", 82, 52).MouseButton1Click:Connect(function()
		sortMode = "name"; refreshSortVisuals(); refreshList()
	end)
	makeSortBtn("TEAM", "team", 138, 52).MouseButton1Click:Connect(function()
		sortMode = "team"; refreshSortVisuals(); refreshList()
	end)

	local countLbl = Create("TextLabel", {
		Text = "0", Font = Enum.Font.GothamBold, TextSize = 10,
		TextColor3 = T.textDim, BackgroundTransparency = 1,
		Position = UDim2.new(1, -40, 0, 3), Size = UDim2.fromOffset(34, 20),
		TextXAlignment = Enum.TextXAlignment.Right, Parent = sortBar
	})

	local scroll = Create("ScrollingFrame", {
		Size = UDim2.new(1, -12, 1, -38), Position = UDim2.fromOffset(6, 34),
		BackgroundTransparency = 1, ScrollBarThickness = 2,
		ScrollBarImageColor3 = T.accent, ScrollBarImageTransparency = 0.5,
		CanvasSize = UDim2.new(0, 0, 0, 0), Parent = panel.Body
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2) })
	})
	rowsHolder = scroll
	local layout = scroll:FindFirstChildOfClass("UIListLayout")
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
	end)

	local rowCache = {}   -- player -> {frame, dist, health, ...}

	local function makeRow(plr, order)
		local row = Create("Frame", {
			Name = plr.Name, Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = T.bgElement, BackgroundTransparency = 0.25,
			BorderSizePixel = 0, LayoutOrder = order, Parent = scroll
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Create("UIStroke", { Color = T.stroke, Thickness = 1, Transparency = 0.55 })
		})
		local stroke = row:FindFirstChildOfClass("UIStroke")

		-- team stripe
		local teamColor = plr.Team and plr.TeamColor and plr.TeamColor.Color or Color3.fromRGB(120, 120, 135)
		local stripe = Create("Frame", {
			Name = "Stripe", Size = UDim2.new(0, 3, 1, -14), Position = UDim2.fromOffset(0, 7),
			BackgroundColor3 = teamColor, BorderSizePixel = 0, Parent = row
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

		local avatar = Create("ImageLabel", {
			Name = "Avatar", Size = UDim2.fromOffset(28, 28),
			Position = UDim2.fromOffset(10, 8), BackgroundColor3 = Color3.fromRGB(30, 30, 40),
			BackgroundTransparency = 0.3, BorderSizePixel = 0,
			Image = "rbxthumb://type=AvatarHeadShot&id=" .. plr.UserId .. "&w=60&h=60",
			Parent = row
		}, {
			Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Create("UIStroke", { Color = teamColor, Thickness = 1.2, Transparency = 0.3 })
		})

		local nameLbl = Create("TextLabel", {
			Name = "PName", Text = plr.DisplayName, Font = Enum.Font.GothamBold, TextSize = 12,
			TextColor3 = Color3.fromRGB(238, 238, 248), BackgroundTransparency = 1,
			Position = UDim2.fromOffset(46, 6), Size = UDim2.new(1, -110, 0, 14),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd, Parent = row
		})

		local userLbl = Create("TextLabel", {
			Name = "UName", Text = "@" .. plr.Name, Font = Enum.Font.GothamMedium, TextSize = 10,
			TextColor3 = T.textFade, BackgroundTransparency = 1,
			Position = UDim2.fromOffset(46, 20), Size = UDim2.new(1, -110, 0, 12),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd, Parent = row
		})

		local distLbl = Create("TextLabel", {
			Name = "Dist", Text = "-", Font = Enum.Font.Code, TextSize = 10,
			TextColor3 = T.textDim, BackgroundTransparency = 1,
			Position = UDim2.new(1, -58, 0, 6), Size = UDim2.fromOffset(52, 14),
			TextXAlignment = Enum.TextXAlignment.Right, Parent = row
		})

		-- health bar
		local hpBg = Create("Frame", {
			Name = "HpBg", Size = UDim2.new(0, 52, 0, 4),
			Position = UDim2.new(1, -58, 0, 24), BackgroundColor3 = Color3.fromRGB(45, 45, 56),
			BorderSizePixel = 0, Parent = row
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

		local hpFill = Create("Frame", {
			Name = "HpFill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = GREEN,
			BorderSizePixel = 0, Parent = hpBg
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

		-- action overlay
		local actions = Create("Frame", {
			Name = "Actions", Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(16, 16, 22), BackgroundTransparency = 1,
			BorderSizePixel = 0, Visible = false, ZIndex = 5, Parent = row
		}, { Create("UICorner", { CornerRadius = UDim.new(0, 8) }) })

		local function actBtn(text, x, w, col, fn)
			local b = Create("TextButton", {
				Text = text, Font = Enum.Font.GothamBold, TextSize = 10,
				TextColor3 = col, BackgroundColor3 = Color3.fromRGB(32, 32, 42),
				BackgroundTransparency = 0.15, AutoButtonColor = false,
				Position = UDim2.fromOffset(x, 11), Size = UDim2.fromOffset(w, 22),
				ZIndex = 6, Parent = actions
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
				Create("UIStroke", { Color = T.stroke, Thickness = 1, Transparency = 0.4 })
			})
			b.MouseEnter:Connect(function() Tween(b, 0.12, { BackgroundColor3 = Color3.fromRGB(46, 46, 58) }) end)
			b.MouseLeave:Connect(function() Tween(b, 0.12, { BackgroundColor3 = Color3.fromRGB(32, 32, 42) }) end)
			b.MouseButton1Click:Connect(fn)
			return b
		end

		actBtn("TELEPORT", 10, 64, T.accent, function()
			local myChar = Player.Character
			local tChar  = plr.Character
			if myChar and tChar and myChar:FindFirstChild("HumanoidRootPart")
			and tChar:FindFirstChild("HumanoidRootPart") then
				myChar.HumanoidRootPart.CFrame = tChar.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
				Library:Notify({ Title = "Teleport", Content = "Teleported to " .. plr.DisplayName, Type = "success", Time = 2 })
			else
				Library:Notify({ Title = "Teleport", Content = "Character not found", Type = "error", Time = 2 })
			end
		end)

		actBtn("SPECTATE", 78, 62, BLUE, function()
			local cam = workspace.CurrentCamera
			if plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then
				cam.CameraSubject = plr.Character:FindFirstChildOfClass("Humanoid")
				Library:Notify({ Title = "Spectate", Content = "Now spectating " .. plr.DisplayName, Type = "info", Time = 2 })
			end
		end)

		actBtn("COPY", 144, 46, T.textMain, function()
			if setclipboard then
				pcall(setclipboard, plr.Name)
				Library:Notify({ Title = "Copied", Content = plr.Name .. " copied to clipboard", Type = "success", Time = 2 })
			end
		end)

		actBtn("RESET", 194, 48, YELLOW, function()
			local cam = workspace.CurrentCamera
			if Player.Character and Player.Character:FindFirstChildOfClass("Humanoid") then
				cam.CameraSubject = Player.Character:FindFirstChildOfClass("Humanoid")
				Library:Notify({ Title = "Camera", Content = "Reset to your character", Type = "info", Time = 2 })
			end
		end)

		local hovering = false
		row.MouseEnter:Connect(function()
			hovering = true
			Tween(row, 0.15, { BackgroundTransparency = 0.1 })
			Tween(stroke, 0.15, { Color = T.strokeHot, Transparency = 0.2 })
			actions.Visible = true
			Tween(actions, 0.18, { BackgroundTransparency = 0.08 })
		end)
		row.MouseLeave:Connect(function()
			hovering = false
			Tween(row, 0.2, { BackgroundTransparency = 0.25 })
			Tween(stroke, 0.2, { Color = T.stroke, Transparency = 0.55 })
			Tween(actions, 0.15, { BackgroundTransparency = 1 })
			task.delay(0.18, function() if not hovering then actions.Visible = false end end)
		end)

		return {
			frame = row, dist = distLbl, hpFill = hpFill,
			stripe = stripe, avatar = avatar, name = nameLbl
		}
	end

	refreshList = function()
		local list = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= Player then table.insert(list, p) end
		end

		if sortMode == "name" then
			table.sort(list, function(a, b) return a.Name:lower() < b.Name:lower() end)
		elseif sortMode == "team" then
			table.sort(list, function(a, b)
				local ta = a.Team and a.Team.Name or "zzz"
				local tb = b.Team and b.Team.Name or "zzz"
				if ta == tb then return a.Name:lower() < b.Name:lower() end
				return ta < tb
			end)
		else
			table.sort(list, function(a, b)
				local da = getDistance(a) or math.huge
				local db = getDistance(b) or math.huge
				return da < db
			end)
		end

		countLbl.Text = tostring(#list)

		-- remove stale
		for plr, data in pairs(rowCache) do
			local stillHere = false
			for _, p in ipairs(list) do if p == plr then stillHere = true break end end
			if not stillHere then
				if data.frame then data.frame:Destroy() end
				rowCache[plr] = nil
			end
		end

		for i, plr in ipairs(list) do
			if not rowCache[plr] then
				rowCache[plr] = makeRow(plr, i)
			else
				rowCache[plr].frame.LayoutOrder = i
			end
		end
	end

	-- live update loop
	local acc = 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not panel.Open then return end
		acc = acc + dt
		if acc < 0.25 then return end
		acc = 0

		for plr, data in pairs(rowCache) do
			if data.frame and data.frame.Parent then
				local d = getDistance(plr)
				data.dist.Text = d and (math.floor(d) .. "m") or "-"
				if d then
					if d < 30 then data.dist.TextColor3 = RED
					elseif d < 120 then data.dist.TextColor3 = YELLOW
					else data.dist.TextColor3 = T.textDim end
				end

				local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
				if hum and hum.MaxHealth > 0 then
					local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
					data.hpFill.Size = UDim2.fromScale(pct, 1)
					if pct > 0.6 then data.hpFill.BackgroundColor3 = GREEN
					elseif pct > 0.3 then data.hpFill.BackgroundColor3 = YELLOW
					else data.hpFill.BackgroundColor3 = RED end
				else
					data.hpFill.Size = UDim2.fromScale(0, 1)
				end

				local tc = plr.Team and plr.TeamColor and plr.TeamColor.Color or Color3.fromRGB(120, 120, 135)
				data.stripe.BackgroundColor3 = tc
				local av = data.avatar:FindFirstChildOfClass("UIStroke")
				if av then av.Color = tc end
			end
		end

		if sortMode == "distance" then
			local list = {}
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= Player then table.insert(list, p) end
			end
			table.sort(list, function(a, b)
				return (getDistance(a) or math.huge) < (getDistance(b) or math.huge)
			end)
			for i, p in ipairs(list) do
				if rowCache[p] then rowCache[p].frame.LayoutOrder = i end
			end
		end
	end)

	Players.PlayerAdded:Connect(function() if panel.Open then task.wait(0.3); refreshList() end end)
	Players.PlayerRemoving:Connect(function() if panel.Open then task.wait(0.1); refreshList() end end)

	local oldShow = panel.Show
	function panel:Show()
		refreshList()
		refreshSortVisuals()
		oldShow(panel)
	end

	refreshSortVisuals()
	PlayerPanel = panel
	return panel
end

function Library:ShowPlayers() buildPlayerPanel():Show() end
function Library:TogglePlayers() buildPlayerPanel():Toggle() end

-- ============================================
-- ICON BROWSER
-- ============================================
local IconPanel = nil

local function buildIconPanel()
	if IconPanel then return IconPanel end

	local panel = CreateFloatingPanel({
		Name = "2t1Studio_Icons", Title = "Icon Browser",
		Icon = ICONS.grid, Width = 320, Height = 400,
		Position = UDim2.new(0.5, -160, 0.5, -200)
	})

	local hint = Create("TextLabel", {
		Text = "Click any icon to copy its name", Font = Enum.Font.GothamMedium,
		TextSize = 11, TextColor3 = T.textFade, BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = panel.Body
	})

	local scroll = Create("ScrollingFrame", {
		Size = UDim2.new(1, -12, 1, -30), Position = UDim2.fromOffset(6, 26),
		BackgroundTransparency = 1, ScrollBarThickness = 2,
		ScrollBarImageColor3 = T.accent, ScrollBarImageTransparency = 0.5,
		CanvasSize = UDim2.new(0, 0, 0, 0), Parent = panel.Body
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(70, 64),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Left
		}),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 2) })
	})
	local grid = scroll:FindFirstChildOfClass("UIGridLayout")
	grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scroll.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + 10)
	end)

	-- collect lowercase keys only, sorted
	local names = {}
	for k in pairs(ICONS) do
		if k == k:lower() then table.insert(names, k) end
	end
	table.sort(names)

	for i, name in ipairs(names) do
		local cell = Create("TextButton", {
			Text = "", AutoButtonColor = false, LayoutOrder = i,
			BackgroundColor3 = T.bgElement, BackgroundTransparency = 0.35,
			BorderSizePixel = 0, Parent = scroll
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Create("UIStroke", { Color = T.stroke, Thickness = 1, Transparency = 0.6 })
		})
		local cs = cell:FindFirstChildOfClass("UIStroke")

		local img = Create("ImageLabel", {
			Image = ICONS[name], Size = UDim2.fromOffset(22, 22),
			Position = UDim2.new(0.5, -11, 0, 10), BackgroundTransparency = 1,
			ImageColor3 = Color3.fromRGB(215, 218, 228),
			ScaleType = Enum.ScaleType.Fit, Parent = cell
		})

		Create("TextLabel", {
			Text = name, Font = Enum.Font.GothamMedium, TextSize = 9.5,
			TextColor3 = T.textFade, BackgroundTransparency = 1,
			Position = UDim2.fromOffset(2, 38), Size = UDim2.new(1, -4, 0, 20),
			TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Parent = cell
		})

		cell.MouseEnter:Connect(function()
			Tween(cell, 0.14, { BackgroundTransparency = 0.1 })
			Tween(cs, 0.14, { Color = T.strokeHot, Transparency = 0.2 })
			Tween(img, 0.14, { ImageColor3 = T.accent })
		end)
		cell.MouseLeave:Connect(function()
			Tween(cell, 0.18, { BackgroundTransparency = 0.35 })
			Tween(cs, 0.18, { Color = T.stroke, Transparency = 0.6 })
			Tween(img, 0.18, { ImageColor3 = Color3.fromRGB(215, 218, 228) })
		end)
		cell.MouseButton1Click:Connect(function()
			if setclipboard then pcall(setclipboard, name) end
			Library:Notify({
				Title = "Icon copied",
				Content = 'Use it as  Icon = "' .. name .. '"',
				Type = "success", Time = 3
			})
		end)
	end

	IconPanel = panel
	return panel
end

function Library:IconBrowser() buildIconPanel():Show() end
function Library:ToggleIconBrowser() buildIconPanel():Toggle() end

-- ============================================
-- THEME BROWSER
-- ============================================
local ThemePanel = nil

local function buildThemePanel()
	if ThemePanel then return ThemePanel end

	local panel = CreateFloatingPanel({
		Name = "2t1Studio_Themes", Title = "Palettes",
		Icon = ICONS.palette, Width = 300, Height = 420,
		Position = UDim2.new(0.5, -150, 0.5, -210)
	})

	local hint = Create("TextLabel", {
		Text = "Click a palette to apply it", Font = Enum.Font.GothamMedium,
		TextSize = 11, TextColor3 = T.textFade, BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = panel.Body
	})

	local scroll = Create("ScrollingFrame", {
		Size = UDim2.new(1, -12, 1, -30), Position = UDim2.fromOffset(6, 26),
		BackgroundTransparency = 1, ScrollBarThickness = 2,
		ScrollBarImageColor3 = T.accent, ScrollBarImageTransparency = 0.5,
		CanvasSize = UDim2.new(0, 0, 0, 0), Parent = panel.Body
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 2) })
	})
	local layout = scroll:FindFirstChildOfClass("UIListLayout")
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
	end)

	local rows = {}

	local function markActive()
		local cur = Library:GetTheme()
		for name, row in pairs(rows) do
			local on = (name == cur)
			local st = row:FindFirstChildOfClass("UIStroke")
			local tick = row:FindFirstChild("Tick")
			Tween(row, 0.18, { BackgroundTransparency = on and 0.05 or 0.35 })
			if st then Tween(st, 0.18, { Transparency = on and 0.15 or 0.6 }) end
			if tick then tick.ImageTransparency = on and 0 or 1 end
		end
	end

	for i, name in ipairs(Library:ListThemes()) do
		local pal = Library.Themes[name]
		if pal then
			local row = Create("TextButton", {
				Name = name, Text = "", AutoButtonColor = false,
				Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = pal.bgElement,
				BackgroundTransparency = 0.35, BorderSizePixel = 0,
				LayoutOrder = i, Parent = scroll
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 9) }),
				Create("UIStroke", { Color = pal.stroke, Thickness = 1.2, Transparency = 0.6 })
			})

			-- swatch strip: accent, soft, surface, stroke
			local strip = Create("Frame", {
				Size = UDim2.fromOffset(52, 38), Position = UDim2.fromOffset(10, 10),
				BackgroundTransparency = 1, Parent = row
			}, {
				Create("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder
				})
			})

			for j, col in ipairs({ pal.accent, pal.soft, pal.bgHover, pal.stroke }) do
				Create("Frame", {
					Size = UDim2.fromOffset(11, 38), BackgroundColor3 = col,
					BorderSizePixel = 0, LayoutOrder = j, Parent = strip
				}, { Create("UICorner", { CornerRadius = UDim.new(0, 3) }) })
			end

			Create("TextLabel", {
				Text = pal.Label or name, Font = Enum.Font.GothamBold, TextSize = 13,
				TextColor3 = pal.textMain, BackgroundTransparency = 1,
				Position = UDim2.fromOffset(74, 10), Size = UDim2.new(1, -110, 0, 16),
				TextXAlignment = Enum.TextXAlignment.Left, Parent = row
			})

			Create("TextLabel", {
				Text = pal.Note or "", Font = Enum.Font.GothamMedium, TextSize = 10.5,
				TextColor3 = pal.textDim, BackgroundTransparency = 1,
				Position = UDim2.fromOffset(74, 28), Size = UDim2.new(1, -110, 0, 24),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Parent = row
			})

			Create("ImageLabel", {
				Name = "Tick", Image = ICONS.check, Size = UDim2.fromOffset(14, 14),
				Position = UDim2.new(1, -26, 0, 10), BackgroundTransparency = 1,
				ImageColor3 = pal.accent, ImageTransparency = 1,
				ScaleType = Enum.ScaleType.Fit, Parent = row
			})

			row.MouseEnter:Connect(function()
				if Library:GetTheme() ~= name then
					Tween(row, 0.14, { BackgroundTransparency = 0.12 })
				end
			end)
			row.MouseLeave:Connect(function()
				if Library:GetTheme() ~= name then
					Tween(row, 0.18, { BackgroundTransparency = 0.35 })
				end
			end)
			row.MouseButton1Click:Connect(function()
				Library:SetTheme(name)
				markActive()
				Library:Notify({
					Title = pal.Label or name,
					Content = pal.Note or "Theme applied",
					Type = "info", Time = 3
				})
			end)

			rows[name] = row
		end
	end

	Library._onThemeChanged = function() markActive() end

	local oldShow = panel.Show
	function panel:Show()
		markActive()
		oldShow(panel)
	end

	markActive()
	ThemePanel = panel
	return panel
end

function Library:ThemeBrowser() buildThemePanel():Show() end
function Library:ToggleThemeBrowser() buildThemePanel():Toggle() end

-- ============================================
-- KEYBIND PANEL
-- ============================================
local KeybindPanel = { Gui = nil, Holder = nil }

function Library:SetKeybindPanel(on)
	if on then
		if KeybindPanel.Gui then KeybindPanel.Gui.Enabled = true; Library:RefreshKeybindPanel(); return end
		local gui = Create("ScreenGui", {
			Name = "2t1Studio_Keybinds", ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 700, Parent = getGuiParent()
		})
		local frame = Create("Frame", {
			Name = "Panel", AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.fromOffset(178, 40),
			BackgroundColor3 = T.bgMain, BackgroundTransparency = 0.12,
			BorderSizePixel = 0, Parent = gui
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 9) }),
			Create("UIStroke", { Color = T.stroke, Thickness = 1, Transparency = 0.35 })
		})
		Create("ImageLabel", {
			Image = ICONS.keyboard, Size = UDim2.fromOffset(12, 12),
			Position = UDim2.fromOffset(11, 9), BackgroundTransparency = 1,
			ImageColor3 = T.accent, ScaleType = Enum.ScaleType.Fit, Parent = frame
		})
		Create("TextLabel", {
			Text = "KEYBINDS", Font = Enum.Font.GothamBold, TextSize = 10.5,
			TextColor3 = T.accent, BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(29, 6), Size = UDim2.new(1, -40, 0, 18), Parent = frame
		})
		Create("Frame", {
			Size = UDim2.new(1, -22, 0, 1), Position = UDim2.fromOffset(11, 27),
			BackgroundColor3 = T.stroke, BackgroundTransparency = 0.4,
			BorderSizePixel = 0, Parent = frame
		})
		local holder = Create("Frame", {
			Name = "Rows", Position = UDim2.fromOffset(11, 33),
			Size = UDim2.new(1, -22, 0, 0), BackgroundTransparency = 1, Parent = frame
		}, { Create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }) })

		local layout = holder:FindFirstChildOfClass("UIListLayout")
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			frame.Size = UDim2.fromOffset(178, 42 + layout.AbsoluteContentSize.Y)
		end)

		KeybindPanel.Gui, KeybindPanel.Holder = gui, holder
		Library:RefreshKeybindPanel()
	else
		if KeybindPanel.Gui then KeybindPanel.Gui.Enabled = false end
	end
end

function Library:RefreshKeybindPanel()
	if not KeybindPanel.Holder then return end
	for _, c in pairs(KeybindPanel.Holder:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	if #Library.Keybinds == 0 then
		Create("TextLabel", {
			Text = "No binds set", Font = Enum.Font.GothamMedium, TextSize = 10,
			TextColor3 = T.textFade, BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 14), Parent = KeybindPanel.Holder
		})
		return
	end
	for i, bind in ipairs(Library.Keybinds) do
		local row = Create("Frame", {
			Size = UDim2.new(1, 0, 0, 15), BackgroundTransparency = 1,
			LayoutOrder = i, Parent = KeybindPanel.Holder
		})
		Create("TextLabel", {
			Text = bind.Name, Font = Enum.Font.GothamMedium, TextSize = 10.5,
			TextColor3 = T.textDim, BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, -52, 1, 0), Parent = row
		})
		Create("TextLabel", {
			Text = bind.Key and bind.Key.Name or "-", Font = Enum.Font.GothamBold, TextSize = 10,
			TextColor3 = T.accent, BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(1, -50, 0, 0), Size = UDim2.fromOffset(50, 15), Parent = row
		})
	end
end

-- ============================================
-- COMMAND PALETTE  (Ctrl + K)
-- ============================================
local Palette = {
	Gui = nil, Main = nil, Input = nil, ResultHolder = nil,
	Open = false, Results = {}, Index = 1, Rows = {}
}

function Library:RegisterCommand(name, desc, fn, icon)
	table.insert(Library._commands, {
		Name = name, Desc = desc or "", Run = fn,
		Icon = icon or ICONS.Terminal, Kind = "Command"
	})
end

local function buildPalette()
	if Palette.Gui then return end

	local gui = Create("ScreenGui", {
		Name = "2t1Studio_Palette", ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 1000, IgnoreGuiInset = true, Parent = getGuiParent()
	})

	local dim = Create("TextButton", {
		Text = "", AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui
	})

	local main = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 110),
		Size = UDim2.fromOffset(520, 56), BackgroundColor3 = Color3.fromRGB(16, 16, 22),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		ClipsDescendants = true, Parent = gui
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 12) }),
		Create("UIStroke", { Color = Color3.fromRGB(80, 80, 95), Thickness = 1.4, Transparency = 1 })
	})
	local mainStroke = main:FindFirstChildOfClass("UIStroke")
	local scale = Create("UIScale", { Scale = 0.95, Parent = main })

	-- search row
	local searchIcon = Create("ImageLabel", {
		Image = ICONS.search, Size = UDim2.fromOffset(17, 17),
		Position = UDim2.fromOffset(18, 19), BackgroundTransparency = 1,
		ImageColor3 = T.textDim, ImageTransparency = 1,
		ScaleType = Enum.ScaleType.Fit, Parent = main
	})

	local input = Create("TextBox", {
		Text = "", PlaceholderText = "Type a command or search settings...",
		PlaceholderColor3 = T.textFade, Font = Enum.Font.GothamMedium, TextSize = 15,
		TextColor3 = Color3.fromRGB(245, 245, 252), TextTransparency = 1,
		BackgroundTransparency = 1, ClearTextOnFocus = false,
		Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -140, 0, 56),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = main
	})

	local hintBox = Create("Frame", {
		Size = UDim2.fromOffset(66, 20), Position = UDim2.new(1, -82, 0, 18),
		BackgroundColor3 = Color3.fromRGB(32, 32, 42), BackgroundTransparency = 1,
		BorderSizePixel = 0, Parent = main
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 5) }) })

	local hintLbl = Create("TextLabel", {
		Text = "ESC close", Font = Enum.Font.Code, TextSize = 10,
		TextColor3 = T.textFade, BackgroundTransparency = 1, TextTransparency = 1,
		Size = UDim2.fromScale(1, 1), Parent = hintBox
	})

	local divider = Create("Frame", {
		Size = UDim2.new(1, -24, 0, 1), Position = UDim2.fromOffset(12, 56),
		BackgroundColor3 = T.stroke, BackgroundTransparency = 1,
		BorderSizePixel = 0, Parent = main
	})

	local resultHolder = Create("ScrollingFrame", {
		Position = UDim2.fromOffset(8, 62), Size = UDim2.new(1, -16, 1, -70),
		BackgroundTransparency = 1, ScrollBarThickness = 2,
		ScrollBarImageColor3 = T.accent, ScrollBarImageTransparency = 0.6,
		CanvasSize = UDim2.new(0, 0, 0, 0), Parent = main
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
		Create("UIPadding", { PaddingRight = UDim.new(0, 6) })
	})
	local rLayout = resultHolder:FindFirstChildOfClass("UIListLayout")
	rLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		resultHolder.CanvasSize = UDim2.new(0, 0, 0, rLayout.AbsoluteContentSize.Y + 6)
	end)

	Palette.Gui, Palette.Main, Palette.Input = gui, main, input
	Palette.ResultHolder = resultHolder
	Palette._dim = dim
	Palette._scale = scale
	Palette._stroke = mainStroke
	Palette._icon = searchIcon
	Palette._hint = hintBox
	Palette._hintLbl = hintLbl
	Palette._divider = divider

	gui.Enabled = false
end

local function paletteCollect()
	local out = {}
	for _, cmd in ipairs(Library._commands) do
		table.insert(out, {
			Name = cmd.Name, Desc = cmd.Desc, Icon = cmd.Icon,
			Kind = "Command", Run = cmd.Run
		})
	end
	for _, e in ipairs(Library._registry) do
		if e.frame and e.frame.Parent then
			table.insert(out, {
				Name = e.name, Desc = e.path or "", Icon = TYPE_ICONS[e.kind] or ICONS.box,
				Kind = e.kind, Run = e.run, Value = e.getValue
			})
		end
	end
	return out
end

local function paletteRender(query)
	local holder = Palette.ResultHolder
	for _, c in pairs(holder:GetChildren()) do
		if c:IsA("TextButton") or c:IsA("Frame") then c:Destroy() end
	end
	Palette.Rows = {}

	local pool = paletteCollect()
	local scored = {}
	for _, item in ipairs(pool) do
		local s = fuzzyScore(item.Name .. " " .. (item.Desc or ""), query)
		if s then table.insert(scored, { item = item, score = s }) end
	end
	table.sort(scored, function(a, b) return a.score > b.score end)

	local shown = {}
	for i = 1, math.min(#scored, 40) do table.insert(shown, scored[i].item) end
	Palette.Results = shown
	Palette.Index = 1

	if #shown == 0 then
		Create("TextLabel", {
			Text = "No results", Font = Enum.Font.GothamMedium, TextSize = 13,
			TextColor3 = T.textFade, BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 44), Parent = holder
		})
	end

	for i, item in ipairs(shown) do
		local row = Create("TextButton", {
			Text = "", AutoButtonColor = false,
			Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = T.accent,
			BackgroundTransparency = 1, LayoutOrder = i, Parent = holder
		}, { Create("UICorner", { CornerRadius = UDim.new(0, 8) }) })

		Create("ImageLabel", {
			Image = item.Icon, Size = UDim2.fromOffset(15, 15),
			Position = UDim2.fromOffset(12, 13), BackgroundTransparency = 1,
			ImageColor3 = T.textDim, ScaleType = Enum.ScaleType.Fit, Parent = row
		})

		Create("TextLabel", {
			Text = item.Name, Font = Enum.Font.GothamBold, TextSize = 13,
			TextColor3 = Color3.fromRGB(235, 235, 245), BackgroundTransparency = 1,
			Position = UDim2.fromOffset(38, 6), Size = UDim2.new(1, -130, 0, 15),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd, Parent = row
		})

		if item.Desc and item.Desc ~= "" then
			Create("TextLabel", {
				Text = item.Desc, Font = Enum.Font.GothamMedium, TextSize = 10.5,
				TextColor3 = T.textFade, BackgroundTransparency = 1,
				Position = UDim2.fromOffset(38, 21), Size = UDim2.new(1, -130, 0, 13),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd, Parent = row
			})
		end

		local kindLbl = Create("TextLabel", {
			Text = (item.Kind or ""):upper(), Font = Enum.Font.Code, TextSize = 9,
			TextColor3 = T.textFade, BackgroundTransparency = 1,
			Position = UDim2.new(1, -88, 0, 14), Size = UDim2.fromOffset(80, 14),
			TextXAlignment = Enum.TextXAlignment.Right, Parent = row
		})

		if item.Value then
			local ok, v = pcall(item.Value)
			if ok and v ~= nil then
				kindLbl.Text = tostring(v):upper()
				kindLbl.TextColor3 = T.accent
			end
		end

		row.MouseEnter:Connect(function()
			Palette.Index = i
			Palette._highlight()
		end)
		row.MouseButton1Click:Connect(function()
			Palette.Index = i
			Palette._run()
		end)

		Palette.Rows[i] = row
	end

	-- resize main
	local resultH = math.min(#shown * 45 + 6, 300)
	local targetH = (#shown > 0 or query ~= "") and (62 + math.max(resultH, 48)) or 56
	Tween(Palette.Main, 0.25, { Size = UDim2.fromOffset(520, targetH) })
	Tween(Palette._divider, 0.2, { BackgroundTransparency = (query ~= "" or #shown > 0) and 0.4 or 1 })

	Palette._highlight()
end

function Palette._highlight()
	for i, row in ipairs(Palette.Rows) do
		local on = (i == Palette.Index)
		Tween(row, 0.12, { BackgroundTransparency = on and 0.9 or 1 })
		local lbl = row:FindFirstChildOfClass("TextLabel")
		if lbl then
			Tween(lbl, 0.12, { TextColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(235, 235, 245) })
		end
		local img = row:FindFirstChildOfClass("ImageLabel")
		if img then Tween(img, 0.12, { ImageColor3 = on and T.accent or T.textDim }) end
	end
	-- scroll into view
	local row = Palette.Rows[Palette.Index]
	if row then
		local holder = Palette.ResultHolder
		local top = row.AbsolutePosition.Y - holder.AbsolutePosition.Y + holder.CanvasPosition.Y
		local bottom = top + row.AbsoluteSize.Y
		if top < holder.CanvasPosition.Y then
			holder.CanvasPosition = Vector2.new(0, top)
		elseif bottom > holder.CanvasPosition.Y + holder.AbsoluteSize.Y then
			holder.CanvasPosition = Vector2.new(0, bottom - holder.AbsoluteSize.Y)
		end
	end
end

function Palette._run()
	local item = Palette.Results[Palette.Index]
	if not item then return end
	Library:ClosePalette()
	task.defer(function()
		if item.Run then pcall(item.Run) end
	end)
end

function Library:OpenPalette()
	buildPalette()
	if Palette.Open then return end
	Palette.Open = true
	Palette.Gui.Enabled = true
	Palette.Input.Text = ""

	Palette._scale.Scale = 0.94
	Palette.Main.BackgroundTransparency = 1
	Tween(Palette._dim, 0.25, { BackgroundTransparency = 0.55 })
	Tween(Palette._scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	Tween(Palette.Main, 0.25, { BackgroundTransparency = 0.02 })
	Tween(Palette._stroke, 0.25, { Transparency = 0.25 })
	Tween(Palette._icon, 0.25, { ImageTransparency = 0 })
	Tween(Palette.Input, 0.25, { TextTransparency = 0 })
	Tween(Palette._hint, 0.25, { BackgroundTransparency = 0.3 })
	Tween(Palette._hintLbl, 0.25, { TextTransparency = 0 })

	paletteRender("")
	task.defer(function() Palette.Input:CaptureFocus() end)
end

function Library:ClosePalette()
	if not Palette.Open then return end
	Palette.Open = false
	Palette.Input:ReleaseFocus()
	Tween(Palette._dim, 0.2, { BackgroundTransparency = 1 })
	Tween(Palette._scale, 0.22, { Scale = 0.96 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Tween(Palette.Main, 0.2, { BackgroundTransparency = 1 })
	Tween(Palette._stroke, 0.2, { Transparency = 1 })
	Tween(Palette._icon, 0.2, { ImageTransparency = 1 })
	Tween(Palette.Input, 0.2, { TextTransparency = 1 })
	Tween(Palette._hint, 0.2, { BackgroundTransparency = 1 })
	Tween(Palette._hintLbl, 0.2, { TextTransparency = 1 })
	for _, row in ipairs(Palette.Rows) do Tween(row, 0.15, { BackgroundTransparency = 1 }) end
	task.delay(0.25, function()
		if not Palette.Open and Palette.Gui then Palette.Gui.Enabled = false end
	end)
end

function Library:TogglePalette()
	if Palette.Open then Library:ClosePalette() else Library:OpenPalette() end
end

-- palette input handling
task.spawn(function()
	buildPalette()
	Palette.Input:GetPropertyChangedSignal("Text"):Connect(function()
		if Palette.Open then paletteRender(Palette.Input.Text) end
	end)
	Palette._dim.MouseButton1Click:Connect(function() Library:ClosePalette() end)

	UIS.InputBegan:Connect(function(input, gpe)
		-- Ctrl+K opens even while typing elsewhere is fine
		if input.KeyCode == Enum.KeyCode.K and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
			Library:TogglePalette()
			return
		end
		if not Palette.Open then return end

		if input.KeyCode == Enum.KeyCode.Escape then
			Library:ClosePalette()
		elseif input.KeyCode == Enum.KeyCode.Down then
			Palette.Index = math.min(Palette.Index + 1, math.max(#Palette.Results, 1))
			Palette._highlight()
		elseif input.KeyCode == Enum.KeyCode.Up then
			Palette.Index = math.max(Palette.Index - 1, 1)
			Palette._highlight()
		elseif input.KeyCode == Enum.KeyCode.Return then
			Palette._run()
		end
	end)
end)

-- ============================================
-- GUIDED TOUR  (first run)
-- ============================================
local Tour = { Gui = nil, Active = false, Step = 1, Steps = {} }

local function buildTour()
	if Tour.Gui then return end

	local gui = Create("ScreenGui", {
		Name = "2t1Studio_Tour", ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 1100, IgnoreGuiInset = true, Parent = getGuiParent()
	})

	-- 4 dark panels forming a hole around the target
	local function shade()
		return Create("Frame", {
			BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 1,
			BorderSizePixel = 0, ZIndex = 10, Parent = gui
		})
	end
	local top, bottom, left, right = shade(), shade(), shade(), shade()

	-- highlight ring
	local ring = Create("Frame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 11, Parent = gui
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Create("UIStroke", { Color = T.accent, Thickness = 2, Transparency = 1 })
	})
	local ringStroke = ring:FindFirstChildOfClass("UIStroke")

	-- tooltip card
	local card = Create("Frame", {
		Size = UDim2.fromOffset(320, 140), BackgroundColor3 = Color3.fromRGB(16, 16, 22),
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 12, Parent = gui
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 12) }),
		Create("UIStroke", { Color = Color3.fromRGB(80, 80, 95), Thickness = 1.4, Transparency = 1 })
	})
	local cardStroke = card:FindFirstChildOfClass("UIStroke")
	local cardScale = Create("UIScale", { Scale = 0.94, Parent = card })

	local stepLbl = Create("TextLabel", {
		Text = "1 / 6", Font = Enum.Font.Code, TextSize = 11,
		TextColor3 = T.textFade, BackgroundTransparency = 1, TextTransparency = 1,
		Position = UDim2.fromOffset(18, 14), Size = UDim2.fromOffset(60, 14),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13, Parent = card
	})

	local titleLbl = Create("TextLabel", {
		Text = "", Font = Enum.Font.GothamBold, TextSize = 15,
		TextColor3 = Color3.fromRGB(245, 245, 252), BackgroundTransparency = 1, TextTransparency = 1,
		Position = UDim2.fromOffset(18, 32), Size = UDim2.new(1, -36, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13, Parent = card
	})

	local bodyLbl = Create("TextLabel", {
		Text = "", Font = Enum.Font.GothamMedium, TextSize = 12.5,
		TextColor3 = T.textMain, BackgroundTransparency = 1, TextTransparency = 1,
		Position = UDim2.fromOffset(18, 56), Size = UDim2.new(1, -36, 0, 46),
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true, ZIndex = 13, Parent = card
	})

	local skipBtn = Create("TextButton", {
		Text = "Skip", Font = Enum.Font.GothamMedium, TextSize = 12,
		TextColor3 = T.textFade, BackgroundTransparency = 1, TextTransparency = 1,
		AutoButtonColor = false, Position = UDim2.fromOffset(14, 0),
		Size = UDim2.fromOffset(50, 30), ZIndex = 13, Parent = card
	})

	local nextBtn = Create("TextButton", {
		Text = "Next", Font = Enum.Font.GothamBold, TextSize = 12,
		TextColor3 = Color3.fromRGB(20, 20, 28), BackgroundColor3 = T.accent,
		BackgroundTransparency = 1, TextTransparency = 1, AutoButtonColor = false,
		Size = UDim2.fromOffset(78, 28), ZIndex = 13, Parent = card
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 7) }) })

	local dots = Create("Frame", {
		Size = UDim2.fromOffset(100, 8), BackgroundTransparency = 1,
		ZIndex = 13, Parent = card
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder
		})
	})

	Tour.Gui = gui
	Tour._parts = { top = top, bottom = bottom, left = left, right = right }
	Tour._ring, Tour._ringStroke = ring, ringStroke
	Tour._card, Tour._cardStroke, Tour._cardScale = card, cardStroke, cardScale
	Tour._stepLbl, Tour._titleLbl, Tour._bodyLbl = stepLbl, titleLbl, bodyLbl
	Tour._skip, Tour._next, Tour._dots = skipBtn, nextBtn, dots

	skipBtn.MouseButton1Click:Connect(function() Library:EndTour() end)
	nextBtn.MouseButton1Click:Connect(function() Library:TourNext() end)

	nextBtn.MouseEnter:Connect(function()
		Tween(nextBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(220, 220, 232) })
	end)
	nextBtn.MouseLeave:Connect(function()
		Tween(nextBtn, 0.15, { BackgroundColor3 = T.accent })
	end)
	skipBtn.MouseEnter:Connect(function()
		Tween(skipBtn, 0.15, { TextColor3 = T.textMain })
	end)
	skipBtn.MouseLeave:Connect(function()
		Tween(skipBtn, 0.15, { TextColor3 = T.textFade })
	end)

	gui.Enabled = false
end

local function tourFocus(targetObj, title, body, stepIdx, total)
	local p = Tour._parts
	local vp = workspace.CurrentCamera.ViewportSize
	local pad = 8

	local pos, size
	if targetObj and targetObj.Parent then
		pos  = targetObj.AbsolutePosition
		size = targetObj.AbsoluteSize
	else
		pos  = Vector2.new(vp.X / 2 - 100, vp.Y / 2 - 50)
		size = Vector2.new(200, 100)
	end

	local x, y = pos.X - pad, pos.Y - pad
	local w, h = size.X + pad * 2, size.Y + pad * 2

	local T = 0.4
	Tween(p.top,    T, { Position = UDim2.fromOffset(0, 0),     Size = UDim2.new(1, 0, 0, math.max(y, 0)) })
	Tween(p.bottom, T, { Position = UDim2.fromOffset(0, y + h), Size = UDim2.new(1, 0, 0, math.max(vp.Y - (y + h), 0)) })
	Tween(p.left,   T, { Position = UDim2.fromOffset(0, y),     Size = UDim2.fromOffset(math.max(x, 0), h) })
	Tween(p.right,  T, { Position = UDim2.fromOffset(x + w, y), Size = UDim2.fromOffset(math.max(vp.X - (x + w), 0), h) })

	Tween(Tour._ring, T, { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h) })

	-- card placement: below target if room, else above
	local cardW, cardH = 320, 150
	local cx = math.clamp(x + w / 2 - cardW / 2, 14, vp.X - cardW - 14)
	local cy
	if y + h + 16 + cardH < vp.Y - 14 then
		cy = y + h + 16
	else
		cy = math.max(y - cardH - 16, 14)
	end

	Tween(Tour._card, T, { Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(cardW, cardH) })

	Tour._stepLbl.Text  = stepIdx .. " / " .. total
	Tour._titleLbl.Text = title
	Tour._bodyLbl.Text  = body

	Tour._skip.Position = UDim2.fromOffset(14, cardH - 40)
	Tour._next.Position = UDim2.fromOffset(cardW - 92, cardH - 40)
	Tour._next.Text = (stepIdx >= total) and "Finish" or "Next"
	Tour._dots.Position = UDim2.fromOffset(cardW / 2 - 50, cardH - 26)

	-- dots
	for _, c in pairs(Tour._dots:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	for i = 1, total do
		Create("Frame", {
			Size = UDim2.fromOffset(i == stepIdx and 14 or 5, 5),
			BackgroundColor3 = i == stepIdx and T.accent or Color3.fromRGB(70, 70, 84),
			BorderSizePixel = 0, LayoutOrder = i, ZIndex = 13, Parent = Tour._dots
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end
end

function Library:StartTour(steps)
	buildTour()
	if Tour.Active then return end
	Tour.Steps = steps or Tour.Steps
	if #Tour.Steps == 0 then return end

	Tour.Active = true
	Tour.Step = 1
	Tour.Gui.Enabled = true

	local p = Tour._parts
	for _, f in pairs(p) do
		f.BackgroundTransparency = 1
		Tween(f, 0.4, { BackgroundTransparency = 0.35 })
	end
	Tour._cardScale.Scale = 0.94
	Tween(Tour._cardScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	Tween(Tour._card, 0.35, { BackgroundTransparency = 0.02 })
	Tween(Tour._cardStroke, 0.35, { Transparency = 0.25 })
	Tween(Tour._ringStroke, 0.35, { Transparency = 0.15 })
	Tween(Tour._stepLbl, 0.35, { TextTransparency = 0 })
	Tween(Tour._titleLbl, 0.35, { TextTransparency = 0 })
	Tween(Tour._bodyLbl, 0.35, { TextTransparency = 0.05 })
	Tween(Tour._skip, 0.35, { TextTransparency = 0 })
	Tween(Tour._next, 0.35, { BackgroundTransparency = 0, TextTransparency = 0 })

	local s = Tour.Steps[1]
	tourFocus(s.Target and s.Target() or nil, s.Title, s.Body, 1, #Tour.Steps)

	-- pulse the ring
	task.spawn(function()
		while Tour.Active do
			Tween(Tour._ringStroke, 0.9, { Transparency = 0.55 })
			task.wait(0.9)
			if not Tour.Active then break end
			Tween(Tour._ringStroke, 0.9, { Transparency = 0.1 })
			task.wait(0.9)
		end
	end)
end

function Library:TourNext()
	if not Tour.Active then return end
	Tour.Step = Tour.Step + 1
	if Tour.Step > #Tour.Steps then
		Library:EndTour()
		return
	end
	local s = Tour.Steps[Tour.Step]
	if s.Before then pcall(s.Before) end
	task.wait(s.Delay or 0)
	tourFocus(s.Target and s.Target() or nil, s.Title, s.Body, Tour.Step, #Tour.Steps)
end

function Library:EndTour()
	if not Tour.Active then return end
	Tour.Active = false

	for _, f in pairs(Tour._parts) do Tween(f, 0.3, { BackgroundTransparency = 1 }) end
	Tween(Tour._ringStroke, 0.25, { Transparency = 1 })
	Tween(Tour._card, 0.25, { BackgroundTransparency = 1 })
	Tween(Tour._cardStroke, 0.25, { Transparency = 1 })
	Tween(Tour._cardScale, 0.25, { Scale = 0.96 })
	Tween(Tour._stepLbl, 0.2, { TextTransparency = 1 })
	Tween(Tour._titleLbl, 0.2, { TextTransparency = 1 })
	Tween(Tour._bodyLbl, 0.2, { TextTransparency = 1 })
	Tween(Tour._skip, 0.2, { TextTransparency = 1 })
	Tween(Tour._next, 0.2, { BackgroundTransparency = 1, TextTransparency = 1 })
	for _, c in pairs(Tour._dots:GetChildren()) do
		if c:IsA("Frame") then Tween(c, 0.2, { BackgroundTransparency = 1 }) end
	end

	task.delay(0.35, function()
		if Tour.Gui then Tour.Gui.Enabled = false end
	end)

	-- mark as seen
	if hasFileAPI() then
		ensureFolder()
		pcall(function() writefile(Library.ConfigFolder .. "/.tour_done", "1") end)
	end
end

function Library:HasSeenTour()
	if not hasFileAPI() then return false end
	local ok, res = pcall(function() return isfile(Library.ConfigFolder .. "/.tour_done") end)
	return ok and res
end

function Library:ResetTour()
	if hasFileAPI() and delfile then
		pcall(function() delfile(Library.ConfigFolder .. "/.tour_done") end)
	end
end

-- ============================================
-- RIPPLE / HOVER
-- ============================================
local function AddRipple(button, host, color)
	host = host or button
	color = color or T.accent
	button.MouseButton1Down:Connect(function(x, y)
		local absPos  = host.AbsolutePosition
		local absSize = host.AbsoluteSize
		local relX = x - absPos.X
		local relY = y - absPos.Y
		local p = Vector2.new(relX, relY)
		local maxDist = math.max(
			(p - Vector2.new(0, 0)).Magnitude,
			(p - Vector2.new(absSize.X, 0)).Magnitude,
			(p - Vector2.new(0, absSize.Y)).Magnitude,
			(p - absSize).Magnitude
		)

		local ripple = Create("Frame", {
			Name = "Ripple", AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(relX, relY), Size = UDim2.fromOffset(0, 0),
			BackgroundColor3 = color, BackgroundTransparency = 0.78,
			BorderSizePixel = 0, ZIndex = 20, Parent = host
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

		Tween(ripple, 0.45, { Size = UDim2.fromOffset(maxDist * 2, maxDist * 2), BackgroundTransparency = 1 })
		task.delay(0.5, function() ripple:Destroy() end)
	end)
end

local function AddHover(frame, stroke, baseColor)
	baseColor = baseColor or T.bgElement
	frame.MouseEnter:Connect(function()
		Tween(frame, 0.18, { BackgroundColor3 = T.bgHover })
		if stroke then Tween(stroke, 0.18, { Color = T.strokeHot }) end
	end)
	frame.MouseLeave:Connect(function()
		Tween(frame, 0.22, { BackgroundColor3 = baseColor })
		if stroke then Tween(stroke, 0.22, { Color = T.stroke }) end
	end)
end

-- ============================================
-- ANIMATED GRID BACKGROUND
-- ============================================
local function CreateGridBackground(parent, config)
	config = config or {}
	local gridColor  = config.GridColor or Color3.fromRGB(35, 35, 45)
	local thickness  = config.LineThickness or 1
	local spacing    = config.Spacing or 18
	local trans      = config.LineTransparency or 0.55

	local clip = Create("Frame", {
		Name = "GridClip", Size = UDim2.new(1, -4, 1, -4),
		Position = UDim2.fromOffset(2, 2), BackgroundTransparency = 1,
		ClipsDescendants = true, ZIndex = 1, Parent = parent
	})
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 11)
	corner.Parent = clip

	-- drifting layer (slightly oversized so the loop is seamless)
	local drift = Create("Frame", {
		Name = "GridDrift", Size = UDim2.new(1, spacing * 2, 1, spacing * 2),
		Position = UDim2.fromOffset(-spacing, -spacing),
		BackgroundTransparency = 1, ZIndex = 1, Parent = clip
	})

	local lines = {}

	for i = 0, math.ceil(520 / spacing) + 2 do
		table.insert(lines, Create("Frame", {
			Name = "GridHLine", Size = UDim2.new(1, 0, 0, thickness),
			Position = UDim2.new(0, 0, 0, i * spacing),
			BackgroundColor3 = gridColor, BackgroundTransparency = trans,
			BorderSizePixel = 0, ZIndex = 1, Parent = drift
		}))
	end
	for i = 0, math.ceil(720 / spacing) + 2 do
		table.insert(lines, Create("Frame", {
			Name = "GridVLine", Size = UDim2.new(0, thickness, 1, 0),
			Position = UDim2.new(0, i * spacing, 0, 0),
			BackgroundColor3 = gridColor, BackgroundTransparency = trans,
			BorderSizePixel = 0, ZIndex = 1, Parent = drift
		}))
	end

	-- soft radial glow that slowly sweeps
	local glow = Create("Frame", {
		Name = "GridGlow", Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1, Parent = clip
	})
	local glowGrad = Create("UIGradient", {
		Rotation = 25,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 0.965),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(1, 1)
		}),
		Offset = Vector2.new(-1, 0), Parent = glow
	})

	-- animation loop
	task.spawn(function()
		local t = 0
		local phase = 0
		while clip.Parent do
			local dt = RunService.RenderStepped:Wait()
			if not Library.AnimatedBG then
				if drift.Position ~= UDim2.fromOffset(-spacing, -spacing) then
					drift.Position = UDim2.fromOffset(-spacing, -spacing)
				end
				glow.BackgroundTransparency = 1
				continue
			end
			glow.BackgroundTransparency = 0

			t = t + dt
			-- slow diagonal drift, loops seamlessly every `spacing`
			local speed = 4.2
			local off = (t * speed) % spacing
			drift.Position = UDim2.fromOffset(-spacing + off, -spacing + off * 0.55)

			-- sweeping glow every ~9s
			phase = phase + dt / 9
			if phase > 1.35 then phase = -0.35 end
			glowGrad.Offset = Vector2.new(phase * 2 - 1, 0)

			-- gentle breathing on line opacity
			local breathe = trans + math.sin(t * 0.55) * 0.06
			for i = 1, #lines, 3 do
				lines[i].BackgroundTransparency = breathe
			end
		end
	end)

	return clip
end

-- ============================================
-- SETTING MANAGER
-- ============================================
function Library.SettingManager()
	local Manager = {}
	function Manager:AddToTab(tab)
		local ui = tab:Section({ Name = "Interface", Icon = "settings", Default = true })

		ui:Keybind({
			Name = "UI Toggle Key", Icon = "keyboard", Flag = "ui_toggle_key", Default = Library.ToggleKey,
			Tooltip = "The key that opens and closes this menu.",
			OnChange = function(new) Library.ToggleKey = new end
		})
		ui:Toggle({
			Name = "Background Blur", Icon = "layers", Flag = "ui_blur", Default = true,
			Tooltip = "Blurs the game behind the interface while it is open.",
			Callback = function(v)
				Library.BlurEnabled = v
				if Library._blur then Tween(Library._blur, 0.3, { Size = v and 14 or 0 }) end
			end
		})
		ui:Toggle({
			Name = "Animated Background", Icon = "sparkles", Flag = "ui_animbg", Default = true,
			Tooltip = "Slow drifting grid and the light sweep behind the panel.",
			Callback = function(v) Library.AnimatedBG = v end
		})
		ui:Toggle({
			Name = "Tooltips", Icon = "info", Flag = "ui_tooltips", Default = true,
			Tooltip = "The hint boxes you are reading right now.",
			Callback = function(v) Library.TooltipsOn = v end
		})
		ui:Toggle({
			Name = "Keybind Panel", Icon = "keyboard", Flag = "ui_keybind_panel", Default = false,
			Tooltip = "Shows a live list of your active keybinds on the left edge.",
			Callback = function(v) Library:SetKeybindPanel(v) end
		})

		-- ---------- appearance ----------
		local look = tab:Section({ Name = "Appearance", Icon = "palette", Default = true })

		look:Paragraph({
			Title = "Palettes",
			Content = "Every palette is low saturation on purpose. The accent carries just enough hue to read as a colour, and the surfaces underneath are tinted a few points toward it. Switching is live."
		})

		local themeNames = Library:ListThemes()
		local themeDrop

		themeDrop = look:Dropdown({
			Name = "Theme", Icon = "palette", Flag = "ui_theme",
			List = themeNames,
			Default = (Library:GetTheme()),
			Tooltip = "Changes the whole interface. Saved with your config.",
			Callback = function(v)
				Library:SetTheme(v)
				local _, pal = Library:GetTheme()
				if pal then
					Library:Notify({
						Title = pal.Label or v,
						Content = pal.Note or "Theme applied",
						Type = "info", Time = 3
					})
				end
			end
		})

		look:ColorPicker({
			Name = "Custom Accent", Icon = "sparkles", Flag = "ui_accent",
			Default = select(2, Library:GetTheme()).accent,
			Tooltip = "Overrides just the highlight colour and leaves the surfaces alone. Pick something desaturated and it will sit nicely on any palette.",
			Callback = function(c) Library:SetAccent(c) end
		})

		look:Button({
			Name = "Reset Accent", Icon = "refresh",
			Tooltip = "Puts the accent back to whatever the current palette defines.",
			Callback = function()
				local name = Library:GetTheme()
				local pal = Library.Themes[name]
				if pal then Library:SetAccent(pal.accent) end
			end
		})

		look:Button({
			Name = "Cycle Theme", Icon = "arrowright",
			Tooltip = "Steps to the next palette in the list.",
			Callback = function()
				local list = Library:ListThemes()
				local cur = Library:GetTheme()
				local idx = 1
				for i, n in ipairs(list) do
					if n == cur then idx = i break end
				end
				local nextName = list[(idx % #list) + 1]
				Library:SetTheme(nextName)
				if themeDrop then themeDrop:Set(nextName) end
				local pal = Library.Themes[nextName]
				Library:Notify({
					Title = pal and pal.Label or nextName,
					Content = pal and pal.Note or "Theme applied",
					Type = "info", Time = 3
				})
			end
		})

		local panels = tab:Section({ Name = "Panels", Icon = "layout", Default = true })

		panels:Button({
			Name = "Player list", Icon = "users", Tooltip = "Everyone in the server with distance, health and quick actions.",
			Callback = function() Library:TogglePlayers() end
		})
		panels:Button({
			Name = "Notification log", Icon = "bell", Tooltip = "Every notification you received, with timestamps.",
			Callback = function() Library:ToggleHistory() end
		})
		panels:Button({
			Name = "Command Palette", Icon = "command", Tooltip = "Also opens with Ctrl+K from anywhere.",
			Callback = function() Library:OpenPalette() end
		})
		panels:Button({
			Name = "Icon Browser", Icon = "grid",
			Tooltip = "Preview every built-in icon and click one to copy its name.",
			Callback = function() Library:ToggleIconBrowser() end
		})
		panels:Button({
			Name = "Theme Browser", Icon = "palette",
			Tooltip = "See every palette side by side and apply one with a click.",
			Callback = function() Library:ToggleThemeBrowser() end
		})

		local misc = tab:Section({ Name = "Interface Actions", Icon = "wrench", Default = false })

		misc:Button({
			Name = "Replay Tour", Icon = "info", Tooltip = "Play the first-run walkthrough again.",
			Callback = function()
				Library:ResetTour()
				if Library._tourSteps then Library:StartTour(Library._tourSteps) end
			end
		})
		misc:Button({
			Name = "Unload Interface", Icon = "x", Tooltip = "Close the interface and clean up everything it created.",
			Callback = function() Library:Unload() end
		})
	end
	return Manager
end

function Library:Unload()
	if Library._blur then
		Tween(Library._blur, 0.3, { Size = 0 })
		task.delay(0.35, function() if Library._blur then Library._blur:Destroy(); Library._blur = nil end end)
	end
	local parent = getGuiParent()
	for _, n in pairs({
		"2t1Studio_UI", "2t1Studio_Notifications", "2t1Studio_Keybinds",
		"2t1Studio_Players", "2t1Studio_History", "2t1Studio_Palette",
		"2t1Studio_Tooltip", "2t1Studio_Tour", "2t1Studio_Icons",
		"2t1Studio_Themes"
	}) do
		local g = parent:FindFirstChild(n) or Player.PlayerGui:FindFirstChild(n)
		if g then g:Destroy() end
	end
end

-- ============================================
-- WINDOW
-- ============================================
function Library:New(config)
	config = config or {}
	local self = setmetatable({}, Library)

	self._searchables = {}
	self._sections    = {}
	self.Open = true

	if not Library._blur then
		local b = Instance.new("BlurEffect")
		b.Name = "2t1Studio_Blur"
		b.Size = 0
		b.Parent = Lighting
		Library._blur = b
	end

	self.Gui = Create("ScreenGui", {
		Name = "2t1Studio_UI", ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 500, Parent = getGuiParent()
	})

	local WIN_W, WIN_H = 600, 420

	self.Main = Create("Frame", {
		Size = UDim2.fromOffset(WIN_W, WIN_H),
		Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = T.bgMain, BackgroundTransparency = 0.06,
		BorderSizePixel = 0, ClipsDescendants = true, Parent = self.Gui
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 12) }),
		Create("UIStroke", { Color = Color3.fromRGB(70, 70, 82), Thickness = 1.5, Transparency = 0.2 })
	})
	local mainStroke = self.Main:FindFirstChildOfClass("UIStroke")
	local scale = Create("UIScale", { Scale = 1, Parent = self.Main })
	self._scale = scale

	local gridCfg = config.Grid or {}
	CreateGridBackground(self.Main, {
		GridColor = gridCfg.Color or Color3.fromRGB(35, 35, 45),
		LineThickness = gridCfg.Thickness or 1,
		Spacing = gridCfg.Spacing or 18,
		LineTransparency = gridCfg.Transparency or 0.55
	})

	-- ---------- TOP BAR ----------
	self.Top = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = Color3.fromRGB(20, 20, 28),
		BackgroundTransparency = 0.35, ZIndex = 2, Parent = self.Main
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 12) }) })

	Create("Frame", {
		Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1),
		BackgroundColor3 = Color3.fromRGB(90, 90, 105), BackgroundTransparency = 0.6,
		BorderSizePixel = 0, ZIndex = 3, Parent = self.Top
	})

	local btnHolder = Create("Frame", {
		Size = UDim2.fromOffset(70, 20), Position = UDim2.new(1, -84, 0, 19),
		BackgroundTransparency = 1, ZIndex = 12, Parent = self.Top
	})
	local function makeDot(x, col, colDark, tip)
		local b = Create("TextButton", {
			Size = UDim2.fromOffset(13, 13), Position = UDim2.fromOffset(x, 3),
			BackgroundColor3 = col, Text = "", AutoButtonColor = false,
			ZIndex = 13, Parent = btnHolder
		}, {
			Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Create("UIStroke", { Color = colDark, Thickness = 1, Transparency = 0.3 })
		})
		AttachTooltip(b, tip)
		return b
	end
	local closeBtn = makeDot(0,  Color3.fromRGB(255, 95, 87),  Color3.fromRGB(200, 70, 60),  "Close and unload")
	local minBtn   = makeDot(22, Color3.fromRGB(255, 189, 46), Color3.fromRGB(200, 150, 30), "Minimise")
	local maxBtn   = makeDot(44, Color3.fromRGB(40, 205, 65),  Color3.fromRGB(30, 160, 50),  "Maximise")

	local logo = Create("ImageLabel", {
		Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(14, 14),
		BackgroundTransparency = 1, Image = DEFAULT_LOGO,
		ScaleType = Enum.ScaleType.Fit, ZIndex = 4, Parent = self.Top
	})

	local titleLbl = Create("TextLabel", {
		Text = config.Title or "2t1 Studio", Font = Enum.Font.GothamBold, TextSize = 17,
		TextColor3 = Color3.fromRGB(255, 255, 255), TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1, Position = UDim2.fromOffset(52, 10),
		Size = UDim2.new(0, 220, 0, 22), ZIndex = 4, Parent = self.Top
	})
	local footerLbl = Create("TextLabel", {
		Text = config.Footer or "Premium Interface", Font = Enum.Font.GothamMedium, TextSize = 11,
		TextColor3 = T.textFade, TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1, Position = UDim2.fromOffset(52, 31),
		Size = UDim2.new(0, 220, 0, 16), ZIndex = 4, Parent = self.Top
	})

	-- ---------- QUICK ACTION BUTTONS ----------
	local quickHolder = Create("Frame", {
		Size = UDim2.fromOffset(88, 26), Position = UDim2.new(1, -186, 0, 16),
		BackgroundTransparency = 1, ZIndex = 6, Parent = self.Top
	})

	local function quickBtn(x, icon, tip, fn)
		local b = Create("TextButton", {
			Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(26, 26),
			Position = UDim2.fromOffset(x, 0), BackgroundColor3 = Color3.fromRGB(30, 30, 40),
			BackgroundTransparency = 0.3, ZIndex = 7, Parent = quickHolder
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 7) }),
			Create("UIStroke", { Color = T.stroke, Thickness = 1, Transparency = 0.45 })
		})
		Create("ImageLabel", {
			Image = icon, Size = UDim2.fromOffset(13, 13),
			Position = UDim2.fromOffset(6.5, 6.5), BackgroundTransparency = 1,
			ImageColor3 = T.textDim, ScaleType = Enum.ScaleType.Fit, ZIndex = 8, Parent = b
		})
		b.MouseEnter:Connect(function()
			Tween(b, 0.15, { BackgroundTransparency = 0.05 })
			local i = b:FindFirstChildOfClass("ImageLabel")
			if i then Tween(i, 0.15, { ImageColor3 = T.accent }) end
		end)
		b.MouseLeave:Connect(function()
			Tween(b, 0.15, { BackgroundTransparency = 0.3 })
			local i = b:FindFirstChildOfClass("ImageLabel")
			if i then Tween(i, 0.15, { ImageColor3 = T.textDim }) end
		end)
		b.MouseButton1Click:Connect(fn)
		AttachTooltip(b, tip)
		return b
	end

	quickBtn(0,  ICONS.command, "Command Palette  (Ctrl+K)", function() Library:OpenPalette() end)
	quickBtn(31, ICONS.users,   "Player list",               function() Library:TogglePlayers() end)
	quickBtn(62, ICONS.bell,    "Notification log",          function() Library:ToggleHistory() end)

	-- ---------- SEARCH ----------
	local searchBox = Create("Frame", {
		Name = "SearchBox", Size = UDim2.fromOffset(140, 26),
		Position = UDim2.new(1, -330, 0, 16), BackgroundColor3 = Color3.fromRGB(28, 28, 38),
		BackgroundTransparency = 0.2, ZIndex = 6, Parent = self.Top
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 7) }),
		Create("UIStroke", { Color = T.stroke, Thickness = 1, Transparency = 0.3 })
	})
	local searchStroke = searchBox:FindFirstChildOfClass("UIStroke")

	Create("ImageLabel", {
		Image = ICONS.search, Size = UDim2.fromOffset(13, 13),
		Position = UDim2.fromOffset(8, 6), BackgroundTransparency = 1,
		ImageColor3 = T.textFade, ScaleType = Enum.ScaleType.Fit, ZIndex = 7, Parent = searchBox
	})

	local searchInput = Create("TextBox", {
		Text = "", PlaceholderText = "Filter...", PlaceholderColor3 = T.textFade,
		Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Color3.fromRGB(240, 240, 245),
		BackgroundTransparency = 1, ClearTextOnFocus = false,
		Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -34, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7, Parent = searchBox
	})
	AttachTooltip(searchBox, "Filters items on the current tab. Press Ctrl+K to search the whole menu.")

	searchInput.Focused:Connect(function()
		Tween(searchStroke, 0.25, { Color = T.accent, Transparency = 0.15 })
	end)
	searchInput.FocusLost:Connect(function()
		Tween(searchStroke, 0.25, { Color = T.stroke, Transparency = 0.3 })
	end)

	-- ---------- CONTAINER ----------
	self.Container = Create("Frame", {
		Size = UDim2.new(1, 0, 1, -58), Position = UDim2.fromOffset(0, 58),
		BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2, Parent = self.Main
	})

	self.Sidebar = Create("Frame", {
		Size = UDim2.new(0, 158, 1, -16), Position = UDim2.fromOffset(10, 8),
		BackgroundColor3 = Color3.fromRGB(19, 19, 26), BackgroundTransparency = 0.35,
		ZIndex = 3, Parent = self.Container
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Create("UIStroke", { Color = T.stroke, Thickness = 1, Transparency = 0.55 })
	})

	self.Indicator = Create("Frame", {
		Name = "Indicator", Size = UDim2.fromOffset(3, 16),
		Position = UDim2.fromOffset(2, 0), BackgroundColor3 = T.accent,
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 10, Parent = self.Sidebar
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	self.SidebarScroll = Create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
		ScrollBarThickness = 0, CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 5, Parent = self.Sidebar
	})

	self.TabHolder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, ZIndex = 5, Parent = self.SidebarScroll
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		Create("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })
	})

	local sidebarLayout = self.TabHolder:FindFirstChildOfClass("UIListLayout")
	local function UpdateSidebarCanvas()
		self.SidebarScroll.CanvasSize = UDim2.new(0, 0, 0, sidebarLayout.AbsoluteContentSize.Y + 16)
	end
	sidebarLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateSidebarCanvas)
	task.spawn(UpdateSidebarCanvas)

	self.Pages = Create("Frame", {
		Size = UDim2.new(1, -188, 1, -16), Position = UDim2.fromOffset(178, 8),
		BackgroundTransparency = 1, ZIndex = 3, Parent = self.Container
	})

	self._activeTabBtn = nil
	self._activeTabDot = nil

	-- ---------- LOCAL SEARCH ----------
	local function ApplySearch(query)
		query = (query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
		for _, entry in ipairs(self._searchables) do
			local frame = entry.frame
			if frame and frame.Parent then
				frame.Visible = (query == "") or (entry.name:find(query, 1, true) ~= nil)
			end
		end
		if query ~= "" then
			for _, sec in ipairs(self._sections) do sec:SetExpanded(true) end
		end
	end
	searchInput:GetPropertyChangedSignal("Text"):Connect(function()
		ApplySearch(searchInput.Text)
	end)

	-- ---------- OPEN / CLOSE ----------
	local function SetBlur(on)
		if not Library._blur then return end
		if not Library.BlurEnabled then Tween(Library._blur, 0.3, { Size = 0 }); return end
		Tween(Library._blur, 0.35, { Size = on and 14 or 0 })
	end

	local function OpenWindow()
		self.Open = true
		self.Main.Visible = true
		scale.Scale = 0.9
		Tween(scale, 0.42, { Scale = 1 }, Enum.EasingStyle.Back)
		Tween(self.Main, 0.3, { BackgroundTransparency = 0.06 })
		Tween(mainStroke, 0.3, { Transparency = 0.2 })
		SetBlur(true)
	end

	local function CloseWindow()
		self.Open = false
		Tween(scale, 0.28, { Scale = 0.92 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Tween(self.Main, 0.25, { BackgroundTransparency = 1 })
		Tween(mainStroke, 0.25, { Transparency = 1 })
		SetBlur(false)
		hideTooltip()
		task.delay(0.32, function()
			if not self.Open then self.Main.Visible = false end
		end)
	end

	self.OpenWindow  = OpenWindow
	self.CloseWindow = CloseWindow

	closeBtn.MouseButton1Click:Connect(function()
		CloseWindow()
		task.delay(0.35, function() Library:Unload() end)
	end)

	local isMin = false
	minBtn.MouseButton1Click:Connect(function()
		isMin = not isMin
		Tween(self.Main, 0.35, { Size = isMin and UDim2.fromOffset(WIN_W, 58) or UDim2.fromOffset(WIN_W, WIN_H) })
		if isMin then self.Container.Visible = false
		else task.delay(0.2, function() self.Container.Visible = true end) end
	end)

	local isMax = false
	maxBtn.MouseButton1Click:Connect(function()
		isMax = not isMax
		Tween(self.Main, 0.35, {
			Size = isMax and UDim2.fromScale(0.88, 0.88) or UDim2.fromOffset(WIN_W, WIN_H),
			Position = UDim2.fromScale(0.5, 0.5)
		})
	end)

	-- ---------- DRAG ----------
	do
		local dragging, dragStart, startPos
		self.Top.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true; dragStart = input.Position; startPos = self.Main.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then dragging = false end
				end)
			end
		end)
		UIS.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
				local d = input.Position - dragStart
				self.Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
					startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end)
	end

	UIS.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == Library.ToggleKey then
			if self.Open then CloseWindow() else OpenWindow() end
		end
	end)

	-- ============================================
	-- REGISTRATION HELPERS
	-- ============================================
	local function RegisterSearch(frame, name)
		table.insert(self._searchables, { frame = frame, name = name:lower() })
	end

	local function RegisterFlag(flag, default, setter)
		if not flag then return end
		Library.Flags[flag] = default
		Library.FlagSetters[flag] = setter
	end

	local function RegisterPalette(info)
		table.insert(Library._registry, info)
	end

	-- ============================================
	-- ELEMENTS
	-- ============================================
	local function CreateElementMethods(target, parentFrame, updateCanvas, ctx)
		ctx = ctx or {}
		local pathStr = (ctx.category and (ctx.category .. " › ") or "")
			.. (ctx.tab and (ctx.tab) or "")
			.. (ctx.section and (" › " .. ctx.section) or "")

		-- draws an optional leading icon and shifts the label to make room
		local function ApplyIcon(bg, ref, label, yOffset)
			local id = ResolveIcon(ref, nil)
			if not id then return nil end
			local img = Create("ImageLabel", {
				Name = "ElementIcon", Image = id,
				Size = UDim2.fromOffset(15, 15),
				Position = UDim2.new(0, 14, 0, yOffset or 0),
				AnchorPoint = yOffset and Vector2.new(0, 0) or Vector2.new(0, 0),
				BackgroundTransparency = 1,
				ImageColor3 = Color3.fromRGB(150, 154, 168),
				ScaleType = Enum.ScaleType.Fit, ZIndex = 7, Parent = bg
			})
			if not yOffset then
				img.Position = UDim2.new(0, 14, 0.5, -7.5)
			end
			if label then
				label.Position = label.Position + UDim2.fromOffset(25, 0)
				label.Size = label.Size - UDim2.fromOffset(25, 0)
			end
			bg.MouseEnter:Connect(function()
				Tween(img, 0.16, { ImageColor3 = Color3.fromRGB(230, 233, 242) })
			end)
			bg.MouseLeave:Connect(function()
				Tween(img, 0.2, { ImageColor3 = Color3.fromRGB(150, 154, 168) })
			end)
			return img
		end

		-- ---------- BUTTON ----------
		function target:Button(cfg)
			local text     = cfg.Name or cfg.Text or "Button"
			local callback = cfg.Callback or function() end

			local bg = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = T.bgElement,
				ClipsDescendants = true, ZIndex = 5, Parent = parentFrame
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Create("UIStroke", { Color = T.stroke, Thickness = 1 })
			})
			local stroke = bg:FindFirstChildOfClass("UIStroke")

			local nameLbl = Create("TextLabel", {
				Text = text, Font = Enum.Font.GothamMedium, TextSize = 13.5, TextColor3 = T.textMain,
				BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(1, -90, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 6, Parent = bg
			})
			ApplyIcon(bg, cfg.Icon, nameLbl)

			local badge = Create("Frame", {
				Size = UDim2.fromOffset(44, 21), Position = UDim2.new(1, -56, 0.5, -10.5),
				BackgroundColor3 = Color3.fromRGB(42, 42, 54), ZIndex = 6, Parent = bg
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
				Create("UIStroke", { Color = Color3.fromRGB(70, 70, 84), Thickness = 1 })
			})
			local badgeTxt = Create("TextLabel", {
				Text = "Run", Font = Enum.Font.GothamBold, TextSize = 11,
				TextColor3 = Color3.fromRGB(240, 240, 248), BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = badge
			})

			local hit = Create("TextButton", {
				Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
				ZIndex = 10, Parent = bg
			})

			AddHover(bg, stroke)
			AddRipple(hit, bg)
			AttachTooltip(bg, cfg.Tooltip)

			hit.MouseButton1Down:Connect(function()
				Tween(badge, 0.15, { BackgroundColor3 = T.accent })
				Tween(badgeTxt, 0.15, { TextColor3 = Color3.fromRGB(20, 20, 28) })
			end)
			hit.MouseButton1Up:Connect(function()
				Tween(badge, 0.28, { BackgroundColor3 = Color3.fromRGB(42, 42, 54) })
				Tween(badgeTxt, 0.28, { TextColor3 = Color3.fromRGB(240, 240, 248) })
				task.spawn(callback)
			end)

			RegisterSearch(bg, text)
			RegisterPalette({
				name = text, path = pathStr, kind = "Button", frame = bg,
				run = function() task.spawn(callback) end
			})
			return bg
		end

		-- ---------- TOGGLE ----------
		function target:Toggle(cfg)
			local text     = cfg.Name or "Toggle"
			local callback = cfg.Callback or function() end
			local state    = cfg.Default or false
			local flag     = cfg.Flag

			local bg = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = T.bgElement,
				ClipsDescendants = true, ZIndex = 5, Parent = parentFrame
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Create("UIStroke", { Color = T.stroke, Thickness = 1 })
			})
			local stroke = bg:FindFirstChildOfClass("UIStroke")

			local nameLbl = Create("TextLabel", {
				Text = text, Font = Enum.Font.GothamMedium, TextSize = 13.5, TextColor3 = T.textMain,
				BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(1, -70, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 6, Parent = bg
			})
			local elemIcon = ApplyIcon(bg, cfg.Icon, nameLbl)

			local tray = Create("Frame", {
				Size = UDim2.fromOffset(34, 4), Position = UDim2.new(1, -50, 0.5, -2),
				BackgroundColor3 = state and T.accent or T.stroke, ZIndex = 6, Parent = bg
			}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

			local knob = Create("Frame", {
				Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5),
				Position = state and UDim2.fromScale(1, 0.5) or UDim2.fromScale(0, 0.5),
				BackgroundColor3 = T.bgElement, ZIndex = 8, Parent = tray
			}, {
				Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Create("UIStroke", { Color = state and T.accent or T.stroke, Thickness = 1.5 })
			})
			local knobStroke = knob:FindFirstChildOfClass("UIStroke")

			local function updateView(val)
				Tween(tray, 0.2, { BackgroundColor3 = val and T.accent or T.stroke })
				Tween(knob, 0.28, { Position = val and UDim2.fromScale(1, 0.5) or UDim2.fromScale(0, 0.5) })
				Tween(knobStroke, 0.2, { Color = val and T.accent or T.stroke })
				if elemIcon then
					Tween(elemIcon, 0.2, {
						ImageColor3 = val and Color3.fromRGB(245, 247, 252) or Color3.fromRGB(150, 154, 168)
					})
				end
			end

			local hit = Create("TextButton", {
				Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
				ZIndex = 10, Parent = bg
			})

			AddHover(bg, stroke)
			AttachTooltip(bg, cfg.Tooltip)

			local api = {}
			function api:Set(val, silent)
				state = val
				updateView(state)
				if flag then Library.Flags[flag] = state end
				if not silent then task.spawn(callback, state) end
			end
			function api:Get() return state end
			function api:Toggle() api:Set(not state) end
			api.SetValue = api.Set

			hit.MouseButton1Click:Connect(function() api:Set(not state) end)

			RegisterFlag(flag, state, function(v) api:Set(v) end)
			RegisterSearch(bg, text)
			RegisterPalette({
				name = text, path = pathStr, kind = "Toggle", frame = bg,
				run = function() api:Set(not state) end,
				getValue = function() return state and "ON" or "OFF" end
			})

			if state then task.spawn(callback, true) end
			return api
		end

		-- ---------- SLIDER ----------
		function target:Slider(cfg)
			local text     = cfg.Name or "Slider"
			local min      = cfg.Min or 0
			local max      = cfg.Max or 100
			local default  = cfg.Default or min
			local rounding = cfg.Rounding or 0
			local suffix   = cfg.Suffix or ""
			local callback = cfg.Callback or function() end
			local flag     = cfg.Flag

			local bg = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = T.bgElement,
				ClipsDescendants = true, ZIndex = 5, Parent = parentFrame
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Create("UIStroke", { Color = T.stroke, Thickness = 1 })
			})
			local stroke = bg:FindFirstChildOfClass("UIStroke")

			local nameLbl = Create("TextLabel", {
				Text = text, Font = Enum.Font.GothamMedium, TextSize = 13.5, TextColor3 = T.textMain,
				BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 7),
				Size = UDim2.new(1, -100, 0, 18), TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 6, Parent = bg
			})
			ApplyIcon(bg, cfg.Icon, nameLbl, 9)

			local valueLbl = Create("TextLabel", {
				Text = tostring(default) .. suffix, Font = Enum.Font.GothamBold, TextSize = 12.5,
				TextColor3 = T.accent, BackgroundTransparency = 1,
				Position = UDim2.new(1, -70, 0, 7), Size = UDim2.fromOffset(56, 18),
				TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6, Parent = bg
			})

			local tray = Create("Frame", {
				Size = UDim2.new(1, -28, 0, 4), Position = UDim2.new(0, 14, 1, -14),
				BackgroundColor3 = Color3.fromRGB(45, 45, 56), ZIndex = 6, Parent = bg
			}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

			local fill = Create("Frame", {
				Size = UDim2.fromScale((default - min) / (max - min), 1),
				BackgroundColor3 = T.accent, ZIndex = 7, Parent = tray
			}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

			local knob = Create("Frame", {
				Size = UDim2.fromOffset(11, 11), AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale((default - min) / (max - min), 0.5),
				BackgroundColor3 = T.bgElement, ZIndex = 8, Parent = tray
			}, {
				Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Create("UIStroke", { Color = T.accent, Thickness = 1.5 })
			})

			local current = default

			local function setValue(val, silent)
				val = math.clamp(val, min, max)
				if rounding == 0 then val = math.floor(val + 0.5)
				else
					local m = 10 ^ rounding
					val = math.floor(val * m + 0.5) / m
				end
				current = val
				local pos = (val - min) / (max - min)
				valueLbl.Text = tostring(val) .. suffix
				Tween(fill, 0.08, { Size = UDim2.fromScale(pos, 1) })
				Tween(knob, 0.08, { Position = UDim2.fromScale(pos, 0.5) })
				if flag then Library.Flags[flag] = val end
				if not silent then task.spawn(callback, val) end
			end

			local function fromInput(input)
				local pos = math.clamp(
					(input.Position.X - tray.AbsolutePosition.X) / tray.AbsoluteSize.X, 0, 1)
				setValue(min + (max - min) * pos)
			end

			local dragging = false
			bg.InputBegan:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1
				or i.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					Tween(knob, 0.15, { Size = UDim2.fromOffset(14, 14) })
					fromInput(i)
				end
			end)
			UIS.InputChanged:Connect(function(i)
				if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
				or i.UserInputType == Enum.UserInputType.Touch) then
					fromInput(i)
				end
			end)
			UIS.InputEnded:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1
				or i.UserInputType == Enum.UserInputType.Touch then
					if dragging then Tween(knob, 0.2, { Size = UDim2.fromOffset(11, 11) }) end
					dragging = false
				end
			end)

			AddHover(bg, stroke)
			AttachTooltip(bg, cfg.Tooltip)

			local api = {}
			function api:Set(v, silent) setValue(v, silent) end
			function api:Get() return current end
			api.SetValue = api.Set

			RegisterFlag(flag, default, function(v) setValue(v) end)
			RegisterSearch(bg, text)
			RegisterPalette({
				name = text, path = pathStr, kind = "Slider", frame = bg,
				run = function()
					if self._focusElement then self._focusElement(bg) end
				end,
				getValue = function() return tostring(current) .. suffix end
			})
			return api
		end

		-- ---------- DROPDOWN ----------
		function target:Dropdown(cfg)
			local text     = cfg.Name or "Dropdown"
			local list     = cfg.List or cfg.Options or {}
			local default  = cfg.Default
			local multi    = cfg.Multi or false
			local callback = cfg.Callback or function() end
			local flag     = cfg.Flag

			local expanded = false
			local selected = multi and {} or nil
			local rowH = 28
			local optButtons = {}

			local bg = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = T.bgElement,
				ClipsDescendants = true, ZIndex = 5, Parent = parentFrame
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Create("UIStroke", { Color = T.stroke, Thickness = 1 })
			})
			local stroke = bg:FindFirstChildOfClass("UIStroke")

			local header = Create("TextButton", {
				Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, Text = "",
				ZIndex = 6, Parent = bg
			})

			local titleLbl2 = Create("TextLabel", {
				Text = text, Font = Enum.Font.GothamMedium, TextSize = 13.5, TextColor3 = T.textMain,
				BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(1, -50, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 7, Parent = header
			})
			do
				local ddIcon = ResolveIcon(cfg.Icon, nil)
				if ddIcon then
					Create("ImageLabel", {
						Name = "ElementIcon", Image = ddIcon, Size = UDim2.fromOffset(15, 15),
						Position = UDim2.new(0, 14, 0, 13), BackgroundTransparency = 1,
						ImageColor3 = Color3.fromRGB(150, 154, 168),
						ScaleType = Enum.ScaleType.Fit, ZIndex = 8, Parent = header
					})
					titleLbl2.Position = UDim2.fromOffset(39, 0)
					titleLbl2.Size = UDim2.new(1, -75, 1, 0)
				end
			end

			local arrow = Create("ImageLabel", {
				Image = ICONS.arrowupdown, Size = UDim2.fromOffset(13, 13),
				Position = UDim2.new(1, -28, 0.5, -6.5), BackgroundTransparency = 1,
				ImageColor3 = T.textDim, ScaleType = Enum.ScaleType.Fit, ZIndex = 7, Parent = header
			})

			local optHolder = Create("Frame", {
				Size = UDim2.new(1, -20, 0, #list * (rowH + 2)),
				Position = UDim2.fromOffset(10, 44), BackgroundTransparency = 1,
				ZIndex = 6, Parent = bg
			}, { Create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) })

			local function refreshTitle()
				if multi then
					local n = 0
					for _ in pairs(selected) do n = n + 1 end
					if n == 0 then titleLbl2.Text = text
					elseif n == 1 then
						for k in pairs(selected) do titleLbl2.Text = text .. " : " .. k end
					else titleLbl2.Text = text .. " : " .. n .. " selected" end
				end
			end

			local function refreshVisuals()
				for value, btn in pairs(optButtons) do
					local on = multi and (selected[value] == true) or (selected == value)
					local box = btn:FindFirstChild("Box")
					local lbl = btn:FindFirstChild("Label")
					local check = box and box:FindFirstChild("Check")
					if lbl then Tween(lbl, 0.15, { TextColor3 = on and Color3.fromRGB(250, 250, 255) or T.textDim }) end
					if box then
						Tween(box, 0.15, { BackgroundColor3 = on and T.accent or Color3.fromRGB(38, 38, 48) })
						local bs = box:FindFirstChildOfClass("UIStroke")
						if bs then Tween(bs, 0.15, { Color = on and T.accent or T.stroke }) end
					end
					if check then check.ImageTransparency = on and 0 or 1 end
				end
			end

			local function select(value)
				if multi then
					if selected[value] then selected[value] = nil else selected[value] = true end
					local out = {}
					for k in pairs(selected) do table.insert(out, k) end
					table.sort(out)
					if flag then Library.Flags[flag] = out end
					refreshTitle(); refreshVisuals()
					task.spawn(callback, out)
				else
					selected = value
					titleLbl2.Text = text .. " : " .. tostring(value)
					if flag then Library.Flags[flag] = value end
					refreshVisuals()
					task.spawn(callback, value)
				end
			end

			local function buildOptions()
				for _, c in pairs(optHolder:GetChildren()) do
					if c:IsA("TextButton") then c:Destroy() end
				end
				optButtons = {}

				for i, value in ipairs(list) do
					local opt = Create("TextButton", {
						Name = "Opt_" .. tostring(value), Text = "",
						Size = UDim2.new(1, 0, 0, rowH), BackgroundColor3 = Color3.fromRGB(26, 26, 34),
						BackgroundTransparency = 0.35, AutoButtonColor = false,
						LayoutOrder = i, ZIndex = 8, Parent = optHolder
					}, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })

					local box = Create("Frame", {
						Name = "Box", Size = UDim2.fromOffset(14, 14),
						Position = UDim2.new(0, 8, 0.5, -7), BackgroundColor3 = Color3.fromRGB(38, 38, 48),
						ZIndex = 9, Parent = opt
					}, {
						Create("UICorner", { CornerRadius = UDim.new(0, multi and 4 or 7) }),
						Create("UIStroke", { Color = T.stroke, Thickness = 1 })
					})

					Create("ImageLabel", {
						Name = "Check", Image = ICONS.check, Size = UDim2.fromOffset(10, 10),
						Position = UDim2.fromOffset(2, 2), BackgroundTransparency = 1,
						ImageColor3 = Color3.fromRGB(20, 20, 28), ImageTransparency = 1,
						ScaleType = Enum.ScaleType.Fit, ZIndex = 10, Parent = box
					})

					Create("TextLabel", {
						Name = "Label", Text = tostring(value), Font = Enum.Font.GothamMedium,
						TextSize = 12.5, TextColor3 = T.textDim, BackgroundTransparency = 1,
						Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -38, 1, 0),
						TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9, Parent = opt
					})

					opt.MouseEnter:Connect(function() Tween(opt, 0.15, { BackgroundTransparency = 0.1 }) end)
					opt.MouseLeave:Connect(function() Tween(opt, 0.15, { BackgroundTransparency = 0.35 }) end)
					opt.MouseButton1Click:Connect(function() select(value) end)

					optButtons[value] = opt
				end

				optHolder.Size = UDim2.new(1, -20, 0, #list * (rowH + 2))
				if expanded then
					Tween(bg, 0.25, { Size = UDim2.new(1, 0, 0, 42 + #list * (rowH + 2) + 10) })
					task.delay(0.3, updateCanvas)
				end
			end

			buildOptions()

			header.MouseButton1Click:Connect(function()
				expanded = not expanded
				local h = expanded and (42 + #list * (rowH + 2) + 10) or 42
				Tween(bg, 0.35, { Size = UDim2.new(1, 0, 0, h) })
				Tween(arrow, 0.35, { Rotation = expanded and 90 or 0 })
				task.delay(0.4, updateCanvas)
			end)

			AddHover(bg, stroke)
			AttachTooltip(bg, cfg.Tooltip)

			local api = {}
			function api:Set(v)
				if multi and typeof(v) == "table" then
					selected = {}
					for _, item in ipairs(v) do selected[item] = true end
					refreshTitle(); refreshVisuals()
					task.spawn(callback, v)
				elseif not multi then
					select(v)
				end
			end
			function api:Get()
				if multi then
					local out = {}
					for k in pairs(selected) do table.insert(out, k) end
					return out
				end
				return selected
			end
			function api:Refresh(newList, keepSel)
				list = newList or {}
				if not keepSel then
					selected = multi and {} or nil
					titleLbl2.Text = text
				end
				buildOptions(); refreshVisuals()
			end
			api.SetValue = api.Set

			RegisterFlag(flag, multi and {} or default, function(v) api:Set(v) end)
			RegisterSearch(bg, text)
			RegisterPalette({
				name = text, path = pathStr, kind = "Dropdown", frame = bg,
				run = function() if self._focusElement then self._focusElement(bg) end end,
				getValue = function()
					if multi then
						local n = 0
						for _ in pairs(selected) do n = n + 1 end
						return n .. " sel"
					end
					return selected and tostring(selected) or "-"
				end
			})

			if default ~= nil then
				task.spawn(function() task.wait(0.05); select(default) end)
			end
			return api
		end

		-- ---------- KEYBIND ----------
		function target:Keybind(cfg)
			local text     = cfg.Name or "Keybind"
			local key      = cfg.Default or Enum.KeyCode.E
			local callback = cfg.Callback or function() end
			local onChange = cfg.OnChange or function() end
			local flag     = cfg.Flag
			local listening = false

			local bind = { Name = text, Key = key }
			table.insert(Library.Keybinds, bind)

			local bg = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = T.bgElement,
				ClipsDescendants = true, ZIndex = 5, Parent = parentFrame
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Create("UIStroke", { Color = T.stroke, Thickness = 1 })
			})
			local stroke = bg:FindFirstChildOfClass("UIStroke")

			local nameLbl = Create("TextLabel", {
				Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = T.textMain,
				BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(1, -90, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 6, Parent = bg
			})
			ApplyIcon(bg, cfg.Icon, nameLbl)

			local display = Create("Frame", {
				Size = UDim2.fromOffset(64, 24), Position = UDim2.new(1, -78, 0.5, -12),
				BackgroundColor3 = Color3.fromRGB(34, 34, 44), ZIndex = 6, Parent = bg
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
				Create("UIStroke", { Color = Color3.fromRGB(70, 70, 84), Thickness = 1 })
			})
			local dStroke = display:FindFirstChildOfClass("UIStroke")

			local keyTxt = Create("TextLabel", {
				Text = key.Name, Font = Enum.Font.GothamBold, TextSize = 11,
				TextColor3 = Color3.fromRGB(240, 240, 248), BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = display
			})

			local hit = Create("TextButton", {
				Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
				ZIndex = 10, Parent = bg
			})

			AddHover(bg, stroke)
			AttachTooltip(bg, cfg.Tooltip or "Click, then press any key to rebind.")

			hit.MouseButton1Click:Connect(function()
				listening = true
				keyTxt.Text = "..."
				Tween(dStroke, 0.2, { Color = T.accent })
				Tween(display, 0.2, { BackgroundColor3 = Color3.fromRGB(48, 48, 60) })
			end)

			UIS.InputBegan:Connect(function(input, gpe)
				if gpe then return end
				if listening and input.UserInputType == Enum.UserInputType.Keyboard then
					listening = false
					key = input.KeyCode
					bind.Key = key
					keyTxt.Text = key.Name
					Tween(dStroke, 0.2, { Color = Color3.fromRGB(70, 70, 84) })
					Tween(display, 0.2, { BackgroundColor3 = Color3.fromRGB(34, 34, 44) })
					if flag then Library.Flags[flag] = key end
					Library:RefreshKeybindPanel()
					task.spawn(onChange, key)
				elseif not listening and input.UserInputType == Enum.UserInputType.Keyboard
				and input.KeyCode == key then
					local t = Tween(display, 0.1, { BackgroundColor3 = T.accent })
					Tween(keyTxt, 0.1, { TextColor3 = Color3.fromRGB(20, 20, 28) })
					t.Completed:Connect(function()
						Tween(display, 0.25, { BackgroundColor3 = Color3.fromRGB(34, 34, 44) })
						Tween(keyTxt, 0.25, { TextColor3 = Color3.fromRGB(240, 240, 248) })
					end)
					task.spawn(callback, key)
				end
			end)

			RegisterFlag(flag, key, function(v)
				if typeof(v) == "EnumItem" then
					key = v; bind.Key = v; keyTxt.Text = v.Name
					Library:RefreshKeybindPanel()
				end
			end)
			RegisterSearch(bg, text)
			RegisterPalette({
				name = text, path = pathStr, kind = "Keybind", frame = bg,
				run = function() if self._focusElement then self._focusElement(bg) end end,
				getValue = function() return key.Name end
			})
			Library:RefreshKeybindPanel()

			local api = {}
			function api:Get() return key end
			return api
		end

		-- ---------- TEXTBOX ----------
		function target:Textbox(cfg)
			local text        = cfg.Name or "Textbox"
			local placeholder = cfg.Placeholder or "Enter..."
			local default     = cfg.Default or ""
			local callback    = cfg.Callback or function() end
			local flag        = cfg.Flag

			local bg = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = T.bgElement,
				ClipsDescendants = true, ZIndex = 5, Parent = parentFrame
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Create("UIStroke", { Color = T.stroke, Thickness = 1 })
			})
			local stroke = bg:FindFirstChildOfClass("UIStroke")

			local lbl = Create("TextLabel", {
				Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = T.textMain,
				BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(1, -90, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 6, Parent = bg
			})
			ApplyIcon(bg, cfg.Icon, lbl)

			local holder = Create("Frame", {
				Size = UDim2.fromOffset(72, 26), Position = UDim2.new(1, -86, 0.5, -13),
				BackgroundColor3 = Color3.fromRGB(15, 15, 20), ClipsDescendants = true,
				ZIndex = 6, Parent = bg
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
				Create("UIStroke", { Color = Color3.fromRGB(60, 60, 74), Thickness = 1 })
			})
			local hStroke = holder:FindFirstChildOfClass("UIStroke")

			local input = Create("TextBox", {
				Text = default, PlaceholderText = placeholder, PlaceholderColor3 = T.textFade,
				Font = Enum.Font.GothamMedium, TextSize = 11,
				TextColor3 = Color3.fromRGB(250, 250, 255), BackgroundTransparency = 1,
				ClearTextOnFocus = false, Size = UDim2.new(1, -10, 1, 0),
				Position = UDim2.fromOffset(5, 0), TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 7, Parent = holder
			})

			AddHover(bg, stroke)
			AttachTooltip(bg, cfg.Tooltip)

			input.Focused:Connect(function()
				Tween(holder, 0.35, { Size = UDim2.fromOffset(220, 26), Position = UDim2.new(1, -234, 0.5, -13) })
				Tween(hStroke, 0.35, { Color = T.accent })
				Tween(lbl, 0.35, { TextTransparency = 0.6 })
			end)
			input.FocusLost:Connect(function(enter)
				Tween(holder, 0.35, { Size = UDim2.fromOffset(72, 26), Position = UDim2.new(1, -86, 0.5, -13) })
				Tween(hStroke, 0.35, { Color = Color3.fromRGB(60, 60, 74) })
				Tween(lbl, 0.35, { TextTransparency = 0 })
				if flag then Library.Flags[flag] = input.Text end
				task.spawn(callback, input.Text, enter)
			end)

			RegisterFlag(flag, default, function(v) input.Text = tostring(v) end)
			RegisterSearch(bg, text)
			RegisterPalette({
				name = text, path = pathStr, kind = "Textbox", frame = bg,
				run = function()
					if self._focusElement then self._focusElement(bg) end
					task.delay(0.35, function() input:CaptureFocus() end)
				end
			})

			local api = {}
			function api:Get() return input.Text end
			function api:Set(v) input.Text = tostring(v) end
			return api
		end

		-- ---------- INPUT + BUTTON ----------
		function target:InputButton(cfg)
			local text        = cfg.Name or "Input"
			local placeholder = cfg.Placeholder or "Value"
			local btnText     = cfg.ButtonText or "Go"
			local callback    = cfg.Callback or function() end

			local bg = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = T.bgElement,
				ClipsDescendants = true, ZIndex = 5, Parent = parentFrame
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Create("UIStroke", { Color = T.stroke, Thickness = 1 })
			})
			local stroke = bg:FindFirstChildOfClass("UIStroke")

			Create("TextLabel", {
				Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = T.textMain,
				BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(0.36, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 6, Parent = bg
			})

			local inputHolder = Create("Frame", {
				Size = UDim2.new(0.38, 0, 0, 26), Position = UDim2.new(0.4, 0, 0.5, -13),
				BackgroundColor3 = Color3.fromRGB(15, 15, 20), ZIndex = 6, Parent = bg
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
				Create("UIStroke", { Color = Color3.fromRGB(60, 60, 74), Thickness = 1 })
			})

			local input = Create("TextBox", {
				Text = "", PlaceholderText = placeholder, PlaceholderColor3 = T.textFade,
				Font = Enum.Font.GothamMedium, TextSize = 11,
				TextColor3 = Color3.fromRGB(250, 250, 255), BackgroundTransparency = 1,
				ClearTextOnFocus = false, Size = UDim2.new(1, -10, 1, 0),
				Position = UDim2.fromOffset(5, 0), ZIndex = 7, Parent = inputHolder
			})

			local btn = Create("TextButton", {
				Text = btnText, Font = Enum.Font.GothamBold, TextSize = 11,
				TextColor3 = Color3.fromRGB(20, 20, 28), BackgroundColor3 = T.accent,
				AutoButtonColor = false, Size = UDim2.fromOffset(50, 24),
				Position = UDim2.new(1, -62, 0.5, -12), ZIndex = 7, Parent = bg
			}, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })

			btn.MouseEnter:Connect(function() Tween(btn, 0.15, { BackgroundColor3 = Color3.fromRGB(220, 220, 232) }) end)
			btn.MouseLeave:Connect(function() Tween(btn, 0.15, { BackgroundColor3 = T.accent }) end)
			btn.MouseButton1Click:Connect(function() task.spawn(callback, input.Text) end)

			AddHover(bg, stroke)
			AttachTooltip(bg, cfg.Tooltip)
			RegisterSearch(bg, text)
			RegisterPalette({
				name = text, path = pathStr, kind = "Textbox", frame = bg,
				run = function() if self._focusElement then self._focusElement(bg) end end
			})

			local api = {}
			function api:Get() return input.Text end
			function api:Set(v) input.Text = tostring(v) end
			return api
		end

		-- ---------- LABEL ----------
		function target:Label(cfg)
			local text = cfg.Text or cfg.Name or "Label"

			local bg = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = T.bgElement,
				BackgroundTransparency = 0.45, ZIndex = 5, Parent = parentFrame
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Create("UIStroke", { Color = T.stroke, Thickness = 1, Transparency = 0.5 })
			})

			local lbl = Create("TextLabel", {
				Text = text, Font = Enum.Font.GothamMedium, TextSize = 12.5,
				TextColor3 = Color3.fromRGB(190, 190, 202), BackgroundTransparency = 1,
				Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 0),
				TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
				ZIndex = 6, Parent = bg
			})

			local function resize()
				local s = TextService:GetTextSize(lbl.Text, lbl.TextSize, lbl.Font,
					Vector2.new(math.max(lbl.AbsoluteSize.X, 10), 10000))
				bg.Size = UDim2.new(1, 0, 0, s.Y + 16)
				lbl.Size = UDim2.new(1, -28, 0, s.Y)
			end
			lbl:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
			task.spawn(resize)

			AttachTooltip(bg, cfg.Tooltip)
			RegisterSearch(bg, text)

			local api = {}
			function api:Set(v) lbl.Text = tostring(v); task.spawn(resize) end
			return api
		end

		-- ---------- PARAGRAPH ----------
		function target:Paragraph(cfg)
			local title   = cfg.Title or "Paragraph"
			local content = cfg.Content or ""

			local bg = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = T.bgElement,
				ZIndex = 5, Parent = parentFrame
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Create("UIStroke", { Color = T.stroke, Thickness = 1 })
			})

			Create("TextLabel", {
				Text = title:upper(), Font = Enum.Font.GothamBold, TextSize = 11.5,
				TextColor3 = T.accent, BackgroundTransparency = 1,
				Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 18),
				TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6, Parent = bg
			})

			Create("Frame", {
				Size = UDim2.new(1, -28, 0, 1), Position = UDim2.fromOffset(14, 28),
				BackgroundColor3 = Color3.fromRGB(60, 60, 74), BackgroundTransparency = 0.4,
				BorderSizePixel = 0, ZIndex = 6, Parent = bg
			})

			local body = Create("TextLabel", {
				Text = content, Font = Enum.Font.GothamMedium, TextSize = 12.5,
				TextColor3 = Color3.fromRGB(165, 165, 178), BackgroundTransparency = 1,
				Position = UDim2.fromOffset(14, 36), Size = UDim2.new(1, -28, 0, 0),
				TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
				TextWrapped = true, ZIndex = 6, Parent = bg
			})

			local function resize()
				local s = TextService:GetTextSize(body.Text, body.TextSize, body.Font,
					Vector2.new(math.max(body.AbsoluteSize.X, 10), 10000))
				bg.Size = UDim2.new(1, 0, 0, s.Y + 48)
				body.Size = UDim2.new(1, -28, 0, s.Y)
			end
			body:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
			task.spawn(resize)

			RegisterSearch(bg, title .. " " .. content)

			local api = {}
			function api:Set(t, c)
				if t then bg:FindFirstChildOfClass("TextLabel").Text = t:upper() end
				if c then body.Text = c end
				task.spawn(resize)
			end
			return api
		end

		-- ---------- COLOR PICKER ----------
		function target:ColorPicker(cfg)
			local text     = cfg.Name or "Color"
			local default  = cfg.Default or Color3.fromRGB(255, 80, 80)
			local callback = cfg.Callback or function() end
			local flag     = cfg.Flag

			local h, s, v = default:ToHSV()
			local expanded = false
			local PICK_H = 132

			local bg = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = T.bgElement,
				ClipsDescendants = true, ZIndex = 5, Parent = parentFrame
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Create("UIStroke", { Color = T.stroke, Thickness = 1 })
			})
			local stroke = bg:FindFirstChildOfClass("UIStroke")

			local header = Create("TextButton", {
				Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, Text = "",
				ZIndex = 6, Parent = bg
			})

			local nameLbl = Create("TextLabel", {
				Text = text, Font = Enum.Font.GothamMedium, TextSize = 13.5, TextColor3 = T.textMain,
				BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(1, -80, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 7, Parent = header
			})
			ApplyIcon(bg, cfg.Icon, nameLbl)

			local swatch = Create("Frame", {
				Size = UDim2.fromOffset(34, 20), Position = UDim2.new(1, -48, 0.5, -10),
				BackgroundColor3 = default, ZIndex = 7, Parent = header
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 5) }),
				Create("UIStroke", { Color = Color3.fromRGB(90, 90, 106), Thickness = 1, Transparency = 0.3 })
			})

			-- picker body
			local body = Create("Frame", {
				Size = UDim2.new(1, -28, 0, PICK_H - 14), Position = UDim2.fromOffset(14, 46),
				BackgroundTransparency = 1, ZIndex = 6, Parent = bg
			})

			local sv = Create("Frame", {
				Size = UDim2.new(1, -40, 1, -26), BackgroundColor3 = Color3.fromHSV(h, 1, 1),
				BorderSizePixel = 0, ZIndex = 7, Parent = body
			}, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })

			local svWhite = Create("Frame", {
				Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0, ZIndex = 8, Parent = sv
			}, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })
			Create("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)
				}), Parent = svWhite
			})

			local svBlack = Create("Frame", {
				Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
				BorderSizePixel = 0, ZIndex = 9, Parent = sv
			}, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })
			Create("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)
				}), Parent = svBlack
			})

			local svCursor = Create("Frame", {
				Size = UDim2.fromOffset(9, 9), AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(s, 1 - v), BackgroundTransparency = 1,
				ZIndex = 11, Parent = sv
			}, {
				Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 })
			})

			local hue = Create("Frame", {
				Size = UDim2.fromOffset(16, 0) + UDim2.new(0, 0, 1, -26),
				Position = UDim2.new(1, -16, 0, 0),
				BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
				ZIndex = 7, Parent = body
			}, { Create("UICorner", { CornerRadius = UDim.new(0, 5) }) })

			Create("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
					ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
					ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
					ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
					ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
					ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
					ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0))
				}), Parent = hue
			})

			local hueCursor = Create("Frame", {
				Size = UDim2.new(1, 4, 0, 3), AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, h), BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0, ZIndex = 9, Parent = hue
			}, {
				Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Create("UIStroke", { Color = Color3.fromRGB(30, 30, 38), Thickness = 1 })
			})

			local hexBox = Create("TextBox", {
				Text = "", PlaceholderText = "#FFFFFF", PlaceholderColor3 = T.textFade,
				Font = Enum.Font.Code, TextSize = 11, TextColor3 = Color3.fromRGB(235, 238, 246),
				BackgroundColor3 = Color3.fromRGB(15, 15, 20), ClearTextOnFocus = false,
				Position = UDim2.new(0, 0, 1, -20), Size = UDim2.new(1, -40, 0, 20),
				ZIndex = 7, Parent = body
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 5) }),
				Create("UIStroke", { Color = Color3.fromRGB(60, 60, 74), Thickness = 1 })
			})

			local current = default

			local function push(silent)
				current = Color3.fromHSV(h, s, v)
				swatch.BackgroundColor3 = current
				sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
				svCursor.Position = UDim2.fromScale(s, 1 - v)
				hueCursor.Position = UDim2.fromScale(0.5, h)
				hexBox.Text = string.format("#%02X%02X%02X",
					math.floor(current.R * 255 + 0.5),
					math.floor(current.G * 255 + 0.5),
					math.floor(current.B * 255 + 0.5))
				if flag then Library.Flags[flag] = current end
				if not silent then task.spawn(callback, current) end
			end
			push(true)

			-- drag handlers
			local dragSV, dragHue = false, false

			local function updateSV(input)
				local rel = Vector2.new(
					math.clamp((input.Position.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1),
					math.clamp((input.Position.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
				)
				s, v = rel.X, 1 - rel.Y
				push()
			end

			local function updateHue(input)
				h = math.clamp((input.Position.Y - hue.AbsolutePosition.Y) / hue.AbsoluteSize.Y, 0, 1)
				push()
			end

			sv.InputBegan:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1
				or i.UserInputType == Enum.UserInputType.Touch then
					dragSV = true; updateSV(i)
				end
			end)
			hue.InputBegan:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1
				or i.UserInputType == Enum.UserInputType.Touch then
					dragHue = true; updateHue(i)
				end
			end)
			UIS.InputChanged:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseMovement
				or i.UserInputType == Enum.UserInputType.Touch then
					if dragSV then updateSV(i) end
					if dragHue then updateHue(i) end
				end
			end)
			UIS.InputEnded:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1
				or i.UserInputType == Enum.UserInputType.Touch then
					dragSV, dragHue = false, false
				end
			end)

			hexBox.FocusLost:Connect(function()
				local hex = hexBox.Text:gsub("#", ""):gsub("%s", "")
				if #hex == 6 and hex:match("^%x+$") then
					local r = tonumber(hex:sub(1, 2), 16) / 255
					local g = tonumber(hex:sub(3, 4), 16) / 255
					local b = tonumber(hex:sub(5, 6), 16) / 255
					h, s, v = Color3.new(r, g, b):ToHSV()
					push()
				else
					push(true)
				end
			end)

			header.MouseButton1Click:Connect(function()
				expanded = not expanded
				Tween(bg, 0.32, { Size = UDim2.new(1, 0, 0, expanded and (42 + PICK_H) or 42) })
				task.delay(0.36, updateCanvas)
			end)

			AddHover(bg, stroke)
			AttachTooltip(bg, cfg.Tooltip)

			local api = {}
			function api:Set(col, silent)
				if typeof(col) ~= "Color3" then return end
				h, s, v = col:ToHSV()
				push(silent)
			end
			function api:Get() return current end
			api.SetValue = api.Set

			RegisterFlag(flag, default, function(val)
				if typeof(val) == "Color3" then api:Set(val) end
			end)
			RegisterSearch(bg, text)
			RegisterPalette({
				name = text, path = pathStr, kind = "Color", frame = bg,
				run = function() if self._focusElement then self._focusElement(bg) end end,
				getValue = function()
					return string.format("#%02X%02X%02X",
						math.floor(current.R * 255 + 0.5),
						math.floor(current.G * 255 + 0.5),
						math.floor(current.B * 255 + 0.5))
				end
			})
			return api
		end

		-- ---------- DIVIDER ----------
		function target:Divider(cfg)
			cfg = cfg or {}
			local label = cfg.Text or cfg.Name

			local holder = Create("Frame", {
				Size = UDim2.new(1, 0, 0, label and 22 or 12),
				BackgroundTransparency = 1, ZIndex = 5, Parent = parentFrame
			})

			if label then
				local txt = label:upper()
				local w = TextService:GetTextSize(txt, 10, Enum.Font.GothamBold, Vector2.new(400, 20)).X
				Create("TextLabel", {
					Text = txt, Font = Enum.Font.GothamBold, TextSize = 10,
					TextColor3 = T.textFade, BackgroundTransparency = 1,
					Position = UDim2.fromOffset(4, 0), Size = UDim2.new(0, w + 4, 1, 0),
					TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7, Parent = holder
				})
				Create("Frame", {
					Size = UDim2.new(1, -(w + 20), 0, 1), Position = UDim2.new(0, w + 14, 0.5, 0),
					BackgroundColor3 = T.stroke, BackgroundTransparency = 0.5,
					BorderSizePixel = 0, ZIndex = 5, Parent = holder
				})
			else
				Create("Frame", {
					Size = UDim2.new(1, -8, 0, 1), Position = UDim2.new(0, 4, 0.5, 0),
					BackgroundColor3 = T.stroke, BackgroundTransparency = 0.5,
					BorderSizePixel = 0, ZIndex = 5, Parent = holder
				})
			end
			return holder
		end
	end

	-- ============================================
	-- FOCUS AN ELEMENT (used by command palette)
	-- ============================================
	local elementOwner = {}   -- frame -> {selectTab = fn, page = page}

	function self._focusElement(frame)
		local owner = elementOwner[frame]
		if owner then
			if owner.expandSection then pcall(owner.expandSection) end
			if owner.selectTab then pcall(owner.selectTab) end
		end
		if not self.Open then self.OpenWindow() end

		task.delay(0.25, function()
			if not frame or not frame.Parent then return end
			-- scroll into view
			local page = owner and owner.page
			if page then
				local rel = frame.AbsolutePosition.Y - page.AbsolutePosition.Y + page.CanvasPosition.Y
				local target = math.max(rel - 40, 0)
				Tween(page, 0.35, { CanvasPosition = Vector2.new(0, target) })
			end
			-- flash highlight
			local flash = Create("Frame", {
				Name = "FocusFlash", Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = T.accent, BackgroundTransparency = 1,
				BorderSizePixel = 0, ZIndex = 30, Parent = frame
			}, { Create("UICorner", { CornerRadius = UDim.new(0, 8) }) })
			task.wait(0.15)
			Tween(flash, 0.2, { BackgroundTransparency = 0.82 })
			task.wait(0.35)
			Tween(flash, 0.5, { BackgroundTransparency = 1 })
			task.delay(0.55, function() flash:Destroy() end)
		end)
	end

	self._elementOwner = elementOwner

	-- ============================================
	-- SELECT TAB
	-- ============================================
	local function SelectTab(tabBtn, tabDot, page, subFrame)
		for _, cat in pairs(self.TabHolder:GetChildren()) do
			if cat:IsA("Frame") then
				local sub = cat:FindFirstChild("SubTabHolder")
				local function reset(sf)
					local b = sf:FindFirstChildOfClass("TextButton")
					local d = sf:FindFirstChild("Dot")
					local hl = sf:FindFirstChild("TabHighlightBg")
					if b then Tween(b, 0.2, { TextColor3 = Color3.fromRGB(140, 140, 155) }) end
					if d then Tween(d, 0.2, { ImageColor3 = Color3.fromRGB(60, 60, 72) }) end
					if hl then
						Tween(hl, 0.2, { BackgroundTransparency = 1 })
						local s = hl:FindFirstChildOfClass("UIStroke")
						if s then Tween(s, 0.2, { Transparency = 1 }) end
					end
				end
				if sub then
					for _, sf in pairs(sub:GetChildren()) do
						if sf:IsA("Frame") then reset(sf) end
					end
				elseif cat:FindFirstChild("TabHighlightBg") then
					reset(cat)
				end
			end
		end

		for _, p in pairs(self.Pages:GetChildren()) do
			if p:IsA("ScrollingFrame") then p.Visible = false end
		end

		if tabBtn then Tween(tabBtn, 0.2, { TextColor3 = Color3.fromRGB(255, 255, 255) }) end
		if tabDot then Tween(tabDot, 0.2, { ImageColor3 = T.accent }) end

		if subFrame then
			local hl = subFrame:FindFirstChild("TabHighlightBg")
			if hl then
				Tween(hl, 0.25, { BackgroundTransparency = 0.9 })
				local s = hl:FindFirstChildOfClass("UIStroke")
				if s then Tween(s, 0.25, { Transparency = 0.6 }) end
			end
			task.spawn(function()
				task.wait()
				local relY = subFrame.AbsolutePosition.Y - self.Sidebar.AbsolutePosition.Y
				self.Indicator.BackgroundTransparency = 0
				Tween(self.Indicator, 0.32, {
					Position = UDim2.fromOffset(2, relY + 6),
					Size = UDim2.fromOffset(3, math.max(subFrame.AbsoluteSize.Y - 12, 10))
				}, Enum.EasingStyle.Back)
			end)
		end

		page.Visible = true
		self._activeTabBtn = tabBtn
		self._activeTabDot = tabDot
		self._activePage = page

		-- stagger reveal
		task.spawn(function()
			local i = 0
			for _, child in ipairs(page:GetChildren()) do
				if child:IsA("Frame") and child.Visible then
					i = i + 1
					local baseTrans = child.BackgroundTransparency
					child.BackgroundTransparency = 1
					local texts = {}
					for _, d in ipairs(child:GetDescendants()) do
						if d:IsA("TextLabel") or d:IsA("TextButton") then
							texts[d] = d.TextTransparency
							d.TextTransparency = 1
						end
					end
					task.delay(i * 0.032, function()
						if not child.Parent then return end
						Tween(child, 0.3, { BackgroundTransparency = baseTrans })
						for d, v in pairs(texts) do
							if d and d.Parent then Tween(d, 0.3, { TextTransparency = v }) end
						end
					end)
				end
			end
		end)
	end

	self._selectTabFn = SelectTab

	-- ============================================
	-- SECTION
	-- ============================================
	local function CreateSection(Page, UpdateCanvas, cfg, ctx)
		local name = cfg.Name or cfg.Title or "Section"
		local desc = cfg.Description or cfg.Desc
		local icon = ResolveIcon(cfg.Icon, DEFAULT_SECTION_ICON)
		local open = cfg.Default
		if open == nil then open = true end
		local expanded = open
		local Section = {}

		local SC = Create("Frame", {
			Name = "Section_" .. name, Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = T.bgPanel, BackgroundTransparency = 0.35,
			ClipsDescendants = true, ZIndex = 5, Parent = Page
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Create("UIStroke", { Color = T.stroke, Thickness = 1, Transparency = 0.45 })
		})

		local HB = Create("TextButton", {
			Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Text = "",
			ZIndex = 7, Parent = SC
		})

		local IL = Create("ImageLabel", {
			Image = icon, Size = UDim2.fromOffset(15, 15),
			Position = UDim2.new(0, 14, 0.5, -7.5), BackgroundTransparency = 1,
			ImageColor3 = T.accent, ScaleType = Enum.ScaleType.Fit, ZIndex = 8, Parent = HB
		})

		local ST = Create("TextLabel", {
			Text = name, Font = Enum.Font.GothamBold, TextSize = 13.5,
			TextColor3 = Color3.fromRGB(238, 238, 248), BackgroundTransparency = 1,
			Position = UDim2.fromOffset(37, 0), Size = UDim2.new(1, -80, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Parent = HB
		})

		local SA = Create("ImageLabel", {
			Image = ICONS.arrowupdown, Size = UDim2.fromOffset(13, 13),
			Position = UDim2.new(1, -28, 0.5, -6.5), BackgroundTransparency = 1,
			ImageColor3 = Color3.fromRGB(200, 200, 215), ScaleType = Enum.ScaleType.Fit,
			ZIndex = 8, Rotation = expanded and 90 or 0, Parent = HB
		})

		local headerH = 40
		if desc then
			Create("TextLabel", {
				Text = desc, Font = Enum.Font.GothamMedium, TextSize = 11,
				TextColor3 = T.textFade, BackgroundTransparency = 1,
				Position = UDim2.fromOffset(37, 25), Size = UDim2.new(1, -80, 0, 14),
				TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Parent = HB
			})
			HB.Size = UDim2.new(1, 0, 0, 48)
			headerH = 48
		end

		local CH = Create("Frame", {
			Size = UDim2.new(1, -16, 0, 0), Position = UDim2.fromOffset(8, headerH + 2),
			BackgroundTransparency = 1, ZIndex = 6, Parent = SC
		}, {
			Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
			Create("UIPadding", {
				PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2)
			})
		})

		local CL = CH:FindFirstChildOfClass("UIListLayout")
		local function UpdateSize()
			local h = CL.AbsoluteContentSize.Y + 10
			Tween(SC, 0.35, { Size = UDim2.new(1, 0, 0, expanded and (headerH + 2 + h) or headerH) })
			task.delay(0.4, UpdateCanvas)
		end

		CL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			if expanded then UpdateSize() end
		end)

		HB.MouseButton1Click:Connect(function()
			expanded = not expanded
			Tween(SA, 0.35, { Rotation = expanded and 90 or 0 })
			Tween(IL, 0.2, { ImageColor3 = expanded and T.accent or Color3.fromRGB(120, 120, 134) })
			Tween(ST, 0.2, { TextColor3 = expanded and Color3.fromRGB(238, 238, 248) or Color3.fromRGB(170, 170, 184) })
			UpdateSize()
		end)

		HB.MouseEnter:Connect(function()
			Tween(SC, 0.15, { BackgroundTransparency = 0.15 })
			Tween(ST, 0.15, { TextColor3 = Color3.fromRGB(255, 255, 255) })
		end)
		HB.MouseLeave:Connect(function()
			Tween(SC, 0.2, { BackgroundTransparency = 0.35 })
			Tween(ST, 0.2, { TextColor3 = expanded and Color3.fromRGB(238, 238, 248) or Color3.fromRGB(170, 170, 184) })
		end)

		local sctx = {
			category = ctx and ctx.category, tab = ctx and ctx.tab, section = name
		}
		CreateElementMethods(Section, CH, UpdateCanvas, sctx)

		-- register ownership for palette focus
		local sectionExpand = function()
			if not expanded then
				expanded = true
				Tween(SA, 0.35, { Rotation = 90 })
				UpdateSize()
			end
		end
		CH.ChildAdded:Connect(function(child)
			if child:IsA("Frame") then
				self._elementOwner[child] = {
					selectTab = ctx and ctx.selectTab,
					page = Page,
					expandSection = sectionExpand
				}
			end
		end)

		if expanded then
			task.spawn(function() task.wait(0.1); UpdateSize() end)
		else
			SC.Size = UDim2.new(1, 0, 0, headerH)
			IL.ImageColor3 = Color3.fromRGB(120, 120, 134)
			ST.TextColor3  = Color3.fromRGB(170, 170, 184)
			SA.Rotation = 0
		end

		function Section:SetExpanded(v)
			if expanded == v then return end
			expanded = v
			Tween(SA, 0.35, { Rotation = expanded and 90 or 0 })
			UpdateSize()
		end
		function Section:IsExpanded() return expanded end

		table.insert(self._sections, Section)
		return Section
	end

	-- ============================================
	-- CATEGORY
	-- ============================================
	local _order = 0

	function self:NewCategory(cfg)
		local Window   = self
		local catName  = cfg.Name or "Category"
		local catIcon  = ResolveIcon(cfg.Icon, DEFAULT_CATEGORY_ICONS[catName] or DEFAULT_SECTION_ICON)
		local open     = cfg.Default
		if open == nil then open = true end
		_order = _order + 1
		local expanded = open
		local Category = {}

		local CC = Create("Frame", {
			Name = "Cat_" .. catName, Size = UDim2.new(1, 0, 0, 32),
			BackgroundTransparency = 1, ClipsDescendants = true,
			LayoutOrder = _order, ZIndex = 5, Parent = self.TabHolder
		})

		local CH = Create("TextButton", {
			Name = "CatHeader", Size = UDim2.new(1, 0, 0, 32),
			BackgroundTransparency = 1, Text = "", ZIndex = 7, Parent = CC
		}, { Create("UICorner", { CornerRadius = UDim.new(0, 7) }) })

		local CI = Create("ImageLabel", {
			Image = catIcon, Size = UDim2.fromOffset(13, 13),
			Position = UDim2.fromOffset(9, 9), BackgroundTransparency = 1,
			ImageColor3 = T.accent, ScaleType = Enum.ScaleType.Fit, ZIndex = 8, Parent = CH
		})

		local CT = Create("TextLabel", {
			Text = catName, Font = Enum.Font.GothamBold, TextSize = 12,
			TextColor3 = Color3.fromRGB(228, 228, 240), BackgroundTransparency = 1,
			Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -50, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Parent = CH
		})

		local CAI = Create("ImageLabel", {
			Image = ICONS.arrowupdown, Size = UDim2.fromOffset(11, 11),
			Position = UDim2.new(1, -20, 0.5, -5.5), BackgroundTransparency = 1,
			ImageColor3 = Color3.fromRGB(170, 170, 185), ScaleType = Enum.ScaleType.Fit,
			ZIndex = 8, Rotation = expanded and 90 or 0, Parent = CH
		})

		local STH = Create("Frame", {
			Name = "SubTabHolder", Size = UDim2.new(1, 0, 0, 0),
			Position = UDim2.fromOffset(0, 34), BackgroundTransparency = 1,
			ZIndex = 5, Parent = CC
		}, {
			Create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
			Create("UIPadding", { PaddingLeft = UDim.new(0, 6) })
		})

		local subLayout = STH:FindFirstChildOfClass("UIListLayout")
		local subOrder = 0

		local function UpdateCatSize()
			local h = subLayout.AbsoluteContentSize.Y
			Tween(CC, 0.3, { Size = UDim2.new(1, 0, 0, expanded and (34 + h + 4) or 32) })
		end

		subLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			if expanded then UpdateCatSize() end
		end)

		local function setCatExpanded(v)
			expanded = v
			Tween(CAI, 0.35, { Rotation = expanded and 90 or 0 })
			Tween(CT, 0.2, { TextColor3 = expanded and Color3.fromRGB(228, 228, 240) or Color3.fromRGB(150, 150, 166) })
			Tween(CI, 0.2, { ImageColor3 = expanded and T.accent or Color3.fromRGB(100, 100, 114) })
			UpdateCatSize()
		end

		CH.MouseButton1Click:Connect(function() setCatExpanded(not expanded) end)
		CH.MouseEnter:Connect(function() Tween(CT, 0.15, { TextColor3 = Color3.fromRGB(255, 255, 255) }) end)
		CH.MouseLeave:Connect(function()
			Tween(CT, 0.15, { TextColor3 = expanded and Color3.fromRGB(228, 228, 240) or Color3.fromRGB(150, 150, 166) })
		end)

		function Category:NewTab(name, tabCfg)
			tabCfg = tabCfg or {}
			local Tab = {}
			subOrder = subOrder + 1

			local STF = Create("Frame", {
				Name = "SubTab_" .. name, Size = UDim2.new(1, -6, 0, 28),
				BackgroundTransparency = 1, LayoutOrder = subOrder, ZIndex = 6, Parent = STH
			})

			Create("Frame", {
				Name = "TabHighlightBg", Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = T.accent, BackgroundTransparency = 1, ZIndex = 6, Parent = STF
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 7) }),
				Create("UIStroke", { Color = T.accent, Thickness = 1, Transparency = 1 })
			})

			local Dot = Create("ImageLabel", {
				Name = "Dot", Image = ICONS.cornerright, Size = UDim2.fromOffset(11, 11),
				Position = UDim2.fromOffset(6, 8), BackgroundTransparency = 1,
				ImageColor3 = Color3.fromRGB(60, 60, 72), ScaleType = Enum.ScaleType.Fit,
				ZIndex = 8, Parent = STF
			})

			local TB = Create("TextButton", {
				Text = name, Font = Enum.Font.GothamMedium, TextSize = 12,
				TextColor3 = Color3.fromRGB(140, 140, 155), BackgroundTransparency = 1,
				Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -24, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9, Parent = STF
			})

			local Page = Create("ScrollingFrame", {
				Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false,
				ScrollBarThickness = 2, ScrollBarImageColor3 = T.accent,
				ScrollBarImageTransparency = 0.4,
				CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 4, Parent = Window.Pages
			}, {
				Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
				Create("UIPadding", {
					PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2),
					PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 6)
				})
			})

			local PL = Page:FindFirstChildOfClass("UIListLayout")
			local function UCS()
				Page.CanvasSize = UDim2.new(0, 0, 0, PL.AbsoluteContentSize.Y + 16)
			end
			PL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UCS)
			task.spawn(UCS)

			local function doSelect()
				if not expanded then setCatExpanded(true) end
				SelectTab(TB, Dot, Page, STF)
			end

			TB.MouseButton1Click:Connect(doSelect)
			TB.MouseEnter:Connect(function()
				if Window._activeTabBtn ~= TB then
					Tween(TB, 0.15, { TextColor3 = Color3.fromRGB(212, 212, 224) })
					Tween(Dot, 0.15, { ImageColor3 = Color3.fromRGB(120, 120, 134) })
				end
			end)
			TB.MouseLeave:Connect(function()
				if Window._activeTabBtn ~= TB then
					Tween(TB, 0.15, { TextColor3 = Color3.fromRGB(140, 140, 155) })
					Tween(Dot, 0.15, { ImageColor3 = Color3.fromRGB(60, 60, 72) })
				end
			end)

			local ctx = { category = catName, tab = name, selectTab = doSelect }

			CreateElementMethods(Tab, Page, UCS, ctx)

			Page.ChildAdded:Connect(function(child)
				if child:IsA("Frame") then
					Window._elementOwner[child] = { selectTab = doSelect, page = Page }
				end
			end)

			function Tab:Section(c) return CreateSection(Page, UCS, c, ctx) end
			function Tab:Select() doSelect() end

			task.spawn(function() task.wait(0.05); UpdateCatSize() end)
			return Tab
		end

		if expanded then
			task.spawn(function() task.wait(0.1); UpdateCatSize() end)
		else
			CC.Size = UDim2.new(1, 0, 0, 32)
			CAI.Rotation = 0
			CT.TextColor3 = Color3.fromRGB(150, 150, 166)
			CI.ImageColor3 = Color3.fromRGB(100, 100, 114)
		end

		function Category:SetExpanded(v) setCatExpanded(v) end
		function Category:IsExpanded() return expanded end
		return Category
	end

	-- ============================================
	-- STANDALONE TAB
	-- ============================================
	function self:NewTab(name)
		local Tab = {}
		_order = _order + 1

		local TabBg = Create("Frame", {
			Name = "SoloTab_" .. name, Size = UDim2.new(1, 0, 0, 32),
			BackgroundColor3 = Color3.fromRGB(28, 28, 36), BackgroundTransparency = 0.3,
			LayoutOrder = _order, ZIndex = 6, Parent = self.TabHolder
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 7) }),
			Create("UIStroke", { Color = T.stroke, Thickness = 1, Transparency = 0.4 })
		})

		Create("Frame", {
			Name = "TabHighlightBg", Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = T.accent, BackgroundTransparency = 1, ZIndex = 6, Parent = TabBg
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 7) }),
			Create("UIStroke", { Color = T.accent, Thickness = 1, Transparency = 1 })
		})

		local Dot = Create("ImageLabel", {
			Name = "Dot", Image = ICONS.cornerright, Size = UDim2.fromOffset(11, 11),
			Position = UDim2.fromOffset(8, 10), BackgroundTransparency = 1,
			ImageColor3 = Color3.fromRGB(60, 60, 72), ScaleType = Enum.ScaleType.Fit,
			ZIndex = 7, Parent = TabBg
		})

		local TabBtn = Create("TextButton", {
			Text = name, Font = Enum.Font.GothamMedium, TextSize = 12.5,
			TextColor3 = Color3.fromRGB(150, 150, 166), BackgroundTransparency = 1,
			Position = UDim2.fromOffset(24, 0), Size = UDim2.new(1, -26, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Parent = TabBg
		})

		local Page = Create("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false,
			ScrollBarThickness = 2, ScrollBarImageColor3 = T.accent,
			ScrollBarImageTransparency = 0.4,
			CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 4, Parent = self.Pages
		}, {
			Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
			Create("UIPadding", {
				PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2),
				PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 6)
			})
		})

		local PL = Page:FindFirstChildOfClass("UIListLayout")
		local function UCS()
			Page.CanvasSize = UDim2.new(0, 0, 0, PL.AbsoluteContentSize.Y + 16)
		end
		PL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UCS)
		task.spawn(UCS)

		local function doSelect() SelectTab(TabBtn, Dot, Page, TabBg) end
		TabBtn.MouseButton1Click:Connect(doSelect)

		local ctx = { category = nil, tab = name, selectTab = doSelect }
		CreateElementMethods(Tab, Page, UCS, ctx)

		Page.ChildAdded:Connect(function(child)
			if child:IsA("Frame") then
				self._elementOwner[child] = { selectTab = doSelect, page = Page }
			end
		end)

		function Tab:Section(c) return CreateSection(Page, UCS, c, ctx) end
		function Tab:Select() doSelect() end
		return Tab
	end

	-- ============================================
	-- BUILT-IN COMMANDS
	-- ============================================
	if #Library._commands == 0 then
		Library:RegisterCommand("Save Config", "Write your current settings to disk", function()
			local ok = Library:SaveConfig("default")
			Library:Notify({
				Title = "Config", Type = ok and "success" or "error",
				Content = ok and "Saved as \"default\"" or "Your executor has no file access", Time = 3
			})
		end, ICONS.download)

		Library:RegisterCommand("Load Config", "Restore your saved settings", function()
			local ok, n = Library:LoadConfig("default")
			Library:Notify({
				Title = "Config", Type = ok and "success" or "error",
				Content = ok and (n .. " settings restored") or "No saved config found", Time = 3
			})
		end, ICONS.layers)

		Library:RegisterCommand("Share Config", "Copy your settings as a shareable code", function()
			local s = Library:ExportConfig()
			Library:Notify({
				Title = "Config Share", Type = s and "success" or "error",
				Content = s and ("Copied to clipboard (" .. #s .. " characters)") or "Could not build the code",
				Time = 4
			})
		end, ICONS.copy)

		Library:RegisterCommand("Toggle Player List", "Show or hide the player panel", function()
			Library:TogglePlayers()
		end, ICONS.users)

		Library:RegisterCommand("Notification Log", "Open the notification history", function()
			Library:ToggleHistory()
		end, ICONS.bell)

		Library:RegisterCommand("Toggle Blur", "Turn the background blur on or off", function()
			Library.BlurEnabled = not Library.BlurEnabled
			if Library._blur then
				Tween(Library._blur, 0.3, { Size = Library.BlurEnabled and 14 or 0 })
			end
			Library:Notify({
				Title = "Blur", Content = Library.BlurEnabled and "Background blur enabled" or "Background blur disabled",
				Type = "info", Time = 2
			})
		end, ICONS.eye)

		Library:RegisterCommand("Icon Browser", "Preview every built-in icon and copy its name", function()
			Library:IconBrowser()
		end, ICONS.grid)

		Library:RegisterCommand("Theme Browser", "Compare every palette and apply one", function()
			Library:ThemeBrowser()
		end, ICONS.palette)

		Library:RegisterCommand("Next Theme", "Step to the following palette", function()
			local list = Library:ListThemes()
			local cur = Library:GetTheme()
			local idx = 1
			for i, n in ipairs(list) do
				if n == cur then idx = i break end
			end
			local nextName = list[(idx % #list) + 1]
			Library:SetTheme(nextName)
			local pal = Library.Themes[nextName]
			Library:Notify({
				Title = pal and pal.Label or nextName,
				Content = pal and pal.Note or "Theme applied",
				Type = "info", Time = 3
			})
		end, ICONS.arrowright)

		Library:RegisterCommand("Replay Tour", "Play the walkthrough again", function()
			Library:ResetTour()
			if Library._tourSteps then Library:StartTour(Library._tourSteps) end
		end, ICONS.info)

		Library:RegisterCommand("Copy Game Link", "Copy this game's URL to your clipboard", function()
			if setclipboard then
				pcall(setclipboard, "https://www.roblox.com/games/" .. game.PlaceId)
				Library:Notify({ Title = "Copied", Content = "Game link copied to clipboard", Type = "success", Time = 2 })
			end
		end, ICONS.copy)

		Library:RegisterCommand("Rejoin Server", "Reconnect to the current server", function()
			game:GetService("TeleportService"):Teleport(game.PlaceId, Player)
		end, ICONS.home)

		Library:RegisterCommand("Unload Interface", "Close everything and clean up", function()
			Library:Unload()
		end, ICONS.alert)
	end

	-- ============================================
	-- TOUR STEPS
	-- ============================================
	Library._tourSteps = {
		{
			Title = "Welcome to 2t1 Studio",
			Body  = "Here is a quick look around. It takes about twenty seconds, and you can leave any time with Skip.",
			Target = function() return self.Main end
		},
		{
			Title = "Navigation",
			Body  = "Categories on the left collapse and expand. Pick a tab and the white marker slides across to follow you.",
			Target = function() return self.Sidebar end
		},
		{
			Title = "Quick filter",
			Body  = "Type here and the current tab narrows down instantly. Useful when a page has a lot on it.",
			Target = function() return searchBox end
		},
		{
			Title = "Command palette",
			Body  = "Press Ctrl+K anywhere to open it. Search every setting in the menu, run commands, jump straight to a control. Arrow keys to move, Enter to pick.",
			Target = function() return quickHolder end
		},
		{
			Title = "Side panels",
			Body  = "These icons open the player list and your notification history. Both panels can be dragged anywhere on screen.",
			Target = function() return quickHolder end
		},
		{
			Title = "You are all set",
			Body  = "Save your setup under Settings, or export it as a code and send it to a friend. Enjoy.",
			Target = function() return self.Top end
		}
	}

	-- ============================================
	-- BOOT
	-- ============================================
	self.Main.Visible = true
	scale.Scale = 0.85
	self.Main.BackgroundTransparency = 1
	mainStroke.Transparency = 1
	titleLbl.TextTransparency = 1
	footerLbl.TextTransparency = 1
	logo.ImageTransparency = 1
	searchBox.BackgroundTransparency = 1
	searchStroke.Transparency = 1
	for _, c in ipairs(quickHolder:GetChildren()) do
		if c:IsA("TextButton") then
			c.BackgroundTransparency = 1
			local i = c:FindFirstChildOfClass("ImageLabel")
			if i then i.ImageTransparency = 1 end
		end
	end

	task.spawn(function()
		Tween(scale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
		Tween(self.Main, 0.35, { BackgroundTransparency = 0.06 })
		Tween(mainStroke, 0.4, { Transparency = 0.2 })
		if Library.BlurEnabled and Library._blur then
			Tween(Library._blur, 0.55, { Size = 14 })
		end
		task.wait(0.1)
		Tween(logo, 0.4, { ImageTransparency = 0 })
		task.wait(0.06)
		Tween(titleLbl, 0.35, { TextTransparency = 0 })
		task.wait(0.05)
		Tween(footerLbl, 0.35, { TextTransparency = 0 })
		task.wait(0.05)
		Tween(searchBox, 0.35, { BackgroundTransparency = 0.2 })
		Tween(searchStroke, 0.35, { Transparency = 0.3 })
		for idx, c in ipairs(quickHolder:GetChildren()) do
			if c:IsA("TextButton") then
				task.delay(idx * 0.05, function()
					Tween(c, 0.3, { BackgroundTransparency = 0.3 })
					local i = c:FindFirstChildOfClass("ImageLabel")
					if i then Tween(i, 0.3, { ImageTransparency = 0 }) end
				end)
			end
		end

		-- first-run tour
		if config.Tour ~= false then
			task.wait(1.1)
			if not Library:HasSeenTour() then
				Library:StartTour(Library._tourSteps)
			end
		end
	end)

	table.insert(Library._windows, self)
	return self
end

return Library

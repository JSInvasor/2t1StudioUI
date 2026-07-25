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
-- THEME
-- ============================================
local ACCENT      = Color3.fromRGB(255, 255, 255)
local BG_MAIN     = Color3.fromRGB(15, 15, 20)
local BG_PANEL    = Color3.fromRGB(18, 18, 25)
local BG_ELEMENT  = Color3.fromRGB(22, 22, 30)
local BG_HOVER    = Color3.fromRGB(28, 28, 38)
local STROKE      = Color3.fromRGB(55, 55, 65)
local STROKE_HOT  = Color3.fromRGB(110, 110, 125)
local TXT_MAIN    = Color3.fromRGB(210, 210, 220)
local TXT_DIM     = Color3.fromRGB(140, 140, 150)
local TXT_FADE    = Color3.fromRGB(100, 100, 112)
local GREEN       = Color3.fromRGB(80, 220, 130)
local RED         = Color3.fromRGB(240, 80, 90)
local YELLOW      = Color3.fromRGB(250, 200, 80)
local BLUE        = Color3.fromRGB(90, 160, 255)

-- ============================================
-- ICONS
-- ============================================
local ICONS = {
	Sword       = "rbxassetid://10734953822",
	Shield      = "rbxassetid://10734950498",
	Eye         = "rbxassetid://10747384394",
	Crosshair   = "rbxassetid://10709790948",
	Gear        = "rbxassetid://10710000090",
	Wrench      = "rbxassetid://10709821338",
	Zap         = "rbxassetid://10709825498",
	Layers      = "rbxassetid://10710110498",
	Home        = "rbxassetid://10723407389",
	ArrowUpDown = "rbxassetid://10709768538",
	ArrowRight  = "rbxassetid://10709790644",
	CornerRight = "rbxassetid://10709812485",
	Puzzle      = "rbxassetid://10734944950",
	Box         = "rbxassetid://10709780578",
	Search      = "rbxassetid://10734943674",
	Check       = "rbxassetid://10709790644",
	Info        = "rbxassetid://10723415903",
	Alert       = "rbxassetid://10723345886",
	Keyboard    = "rbxassetid://10723379903",
	Users       = "rbxassetid://10747373176",
	Bell        = "rbxassetid://10723345886",
	Command     = "rbxassetid://10734884548",
	Terminal    = "rbxassetid://10734886735",
	Star        = "rbxassetid://10734949856",
	Copy        = "rbxassetid://10734898355",
	Download    = "rbxassetid://10723345591",
	Heart       = "rbxassetid://10723363467",
	Target      = "rbxassetid://10709790948",
	Sliders     = "rbxassetid://10734897102",
	Toggle      = "rbxassetid://10734898355",
	Type        = "rbxassetid://10734924532",
	List        = "rbxassetid://10734898355",
}

local DEFAULT_SECTION_ICON = ICONS.Zap
local DEFAULT_CATEGORY_ICONS = {
	["Main"] = ICONS.Puzzle, ["Combat"] = ICONS.Sword, ["Player"] = ICONS.Home,
	["Misc"] = ICONS.Box,    ["Settings"] = ICONS.Gear, ["Visuals"] = ICONS.Eye,
	["Config"] = ICONS.Layers, ["Players"] = ICONS.Users,
}

-- element type -> palette icon
local TYPE_ICONS = {
	Toggle   = ICONS.Toggle,
	Slider   = ICONS.Sliders,
	Dropdown = ICONS.List,
	Button   = ICONS.Zap,
	Keybind  = ICONS.Keyboard,
	Textbox  = ICONS.Type,
	Command  = ICONS.Terminal,
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
		Create("UIStroke", { Color = STROKE, Thickness = 1, Transparency = 1 })
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
	info    = { color = BLUE,   icon = ICONS.Info },
	success = { color = GREEN,  icon = ICONS.Check },
	error   = { color = RED,    icon = ICONS.Alert },
	warning = { color = YELLOW, icon = ICONS.Alert },
}

function Library:Notify(cfg)
	cfg = cfg or {}
	local title    = cfg.Title or "Notification"
	local content  = cfg.Content or ""
	local duration = cfg.Time or 5
	local kind     = (cfg.Type or "info"):lower()
	local style    = NOTIF_STYLES[kind] or NOTIF_STYLES.info

	-- history
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
			Name = "Holder", Size = UDim2.new(0, 290, 1, -20),
			Position = UDim2.new(1, -302, 0, 10), BackgroundTransparency = 1, Parent = gui
		}, {
			Create("UIListLayout", {
				VerticalAlignment = Enum.VerticalAlignment.Top,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8)
			})
		})
	end

	local card = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = BG_MAIN,
		BackgroundTransparency = 1, BorderSizePixel = 0,
		ClipsDescendants = true, Parent = holder
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 9) }),
		Create("UIStroke", { Color = style.color, Thickness = 1, Transparency = 1 })
	})
	local cardStroke = card:FindFirstChildOfClass("UIStroke")

	local accentBar = Create("Frame", {
		Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = style.color,
		BackgroundTransparency = 1, BorderSizePixel = 0, Parent = card
	})

	local icon = Create("ImageLabel", {
		Image = style.icon, Size = UDim2.fromOffset(17, 17),
		Position = UDim2.fromOffset(14, 12), BackgroundTransparency = 1,
		ImageColor3 = style.color, ImageTransparency = 1,
		ScaleType = Enum.ScaleType.Fit, Parent = card
	})

	local titleLbl = Create("TextLabel", {
		Text = title, Font = Enum.Font.GothamBold, TextSize = 13,
		TextColor3 = style.color, BackgroundTransparency = 1, TextTransparency = 1,
		Position = UDim2.fromOffset(40, 10), Size = UDim2.new(1, -52, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = card
	})

	local bodyLbl = Create("TextLabel", {
		Text = content, Font = Enum.Font.GothamMedium, TextSize = 12,
		TextColor3 = TXT_MAIN, BackgroundTransparency = 1, TextTransparency = 1,
		Position = UDim2.fromOffset(40, 28), Size = UDim2.new(1, -52, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true, Parent = card
	})

	local progressBg = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2),
		BackgroundColor3 = STROKE, BackgroundTransparency = 1,
		BorderSizePixel = 0, Parent = card
	})
	local progress = Create("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = style.color,
		BackgroundTransparency = 1, BorderSizePixel = 0, Parent = progressBg
	})

	local ts = TextService:GetTextSize(content, 12, Enum.Font.GothamMedium, Vector2.new(238, 10000))
	local targetH = math.max(52, ts.Y + 42)
	bodyLbl.Size = UDim2.new(1, -52, 0, ts.Y)

	Tween(card, 0.45, { Size = UDim2.new(1, 0, 0, targetH), BackgroundTransparency = 0.05 }, Enum.EasingStyle.Back)
	Tween(cardStroke, 0.4, { Transparency = 0.35 })
	Tween(accentBar, 0.4, { BackgroundTransparency = 0 })
	Tween(icon, 0.4, { ImageTransparency = 0 })
	Tween(titleLbl, 0.4, { TextTransparency = 0 })
	Tween(bodyLbl, 0.4, { TextTransparency = 0.1 })
	Tween(progressBg, 0.4, { BackgroundTransparency = 0.5 })
	Tween(progress, 0.4, { BackgroundTransparency = 0.2 })
	Tween(progress, duration, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Linear)

	task.delay(duration, function()
		Tween(card, 0.35, { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1 },
			Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Tween(cardStroke, 0.3, { Transparency = 1 })
		Tween(accentBar, 0.3, { BackgroundTransparency = 1 })
		Tween(icon, 0.3, { ImageTransparency = 1 })
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
	local icon   = cfg.Icon or ICONS.Box
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
		BackgroundColor3 = BG_MAIN, BackgroundTransparency = 0.08,
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
		ImageColor3 = ACCENT, ScaleType = Enum.ScaleType.Fit, ZIndex = 3, Parent = top
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
		TextColor3 = TXT_DIM, BackgroundTransparency = 1,
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
		Name = "2t1Studio_History", Title = "Notification Log",
		Icon = ICONS.Bell, Width = 300, Height = 340,
		Position = UDim2.new(1, -330, 0, 60)
	})

	local scroll = Create("ScrollingFrame", {
		Size = UDim2.new(1, -12, 1, -46), Position = UDim2.fromOffset(6, 6),
		BackgroundTransparency = 1, ScrollBarThickness = 2,
		ScrollBarImageColor3 = ACCENT, ScrollBarImageTransparency = 0.5,
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
		Text = "Clear Log", Font = Enum.Font.GothamBold, TextSize = 11,
		TextColor3 = TXT_DIM, BackgroundColor3 = Color3.fromRGB(30, 30, 40),
		BackgroundTransparency = 0.2, AutoButtonColor = false,
		Size = UDim2.new(1, -12, 0, 28), Position = UDim2.new(0, 6, 1, -34),
		Parent = panel.Body
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 7) }),
		Create("UIStroke", { Color = STROKE, Thickness = 1, Transparency = 0.4 })
	})

	local empty = Create("TextLabel", {
		Text = "No notifications yet", Font = Enum.Font.GothamMedium, TextSize = 12,
		TextColor3 = TXT_FADE, BackgroundTransparency = 1,
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
				Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = BG_ELEMENT,
				BackgroundTransparency = 0.3, BorderSizePixel = 0,
				LayoutOrder = i, Parent = scroll
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 7) }),
				Create("UIStroke", { Color = STROKE, Thickness = 1, Transparency = 0.6 })
			})

			Create("Frame", {
				Size = UDim2.new(0, 2, 1, -10), Position = UDim2.fromOffset(0, 5),
				BackgroundColor3 = style.color, BorderSizePixel = 0, Parent = row
			}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

			Create("TextLabel", {
				Text = entry.Title, Font = Enum.Font.GothamBold, TextSize = 11.5,
				TextColor3 = style.color, BackgroundTransparency = 1,
				Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -60, 0, 14),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd, Parent = row
			})

			Create("TextLabel", {
				Text = entry.Time, Font = Enum.Font.Code, TextSize = 10,
				TextColor3 = TXT_FADE, BackgroundTransparency = 1,
				Position = UDim2.new(1, -54, 0, 6), Size = UDim2.fromOffset(48, 14),
				TextXAlignment = Enum.TextXAlignment.Right, Parent = row
			})

			Create("TextLabel", {
				Text = entry.Content, Font = Enum.Font.GothamMedium, TextSize = 11,
				TextColor3 = TXT_DIM, BackgroundTransparency = 1,
				Position = UDim2.fromOffset(10, 22), Size = UDim2.new(1, -20, 0, 20),
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
		Icon = ICONS.Users, Width = 290, Height = 380,
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
			TextColor3 = TXT_FADE, BackgroundColor3 = ACCENT,
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
			Tween(b, 0.15, { TextColor3 = on and ACCENT or TXT_FADE })
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
		TextColor3 = TXT_DIM, BackgroundTransparency = 1,
		Position = UDim2.new(1, -40, 0, 3), Size = UDim2.fromOffset(34, 20),
		TextXAlignment = Enum.TextXAlignment.Right, Parent = sortBar
	})

	local scroll = Create("ScrollingFrame", {
		Size = UDim2.new(1, -12, 1, -38), Position = UDim2.fromOffset(6, 34),
		BackgroundTransparency = 1, ScrollBarThickness = 2,
		ScrollBarImageColor3 = ACCENT, ScrollBarImageTransparency = 0.5,
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
			BackgroundColor3 = BG_ELEMENT, BackgroundTransparency = 0.25,
			BorderSizePixel = 0, LayoutOrder = order, Parent = scroll
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Create("UIStroke", { Color = STROKE, Thickness = 1, Transparency = 0.55 })
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
			TextColor3 = TXT_FADE, BackgroundTransparency = 1,
			Position = UDim2.fromOffset(46, 20), Size = UDim2.new(1, -110, 0, 12),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd, Parent = row
		})

		local distLbl = Create("TextLabel", {
			Name = "Dist", Text = "-", Font = Enum.Font.Code, TextSize = 10,
			TextColor3 = TXT_DIM, BackgroundTransparency = 1,
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
				Create("UIStroke", { Color = STROKE, Thickness = 1, Transparency = 0.4 })
			})
			b.MouseEnter:Connect(function() Tween(b, 0.12, { BackgroundColor3 = Color3.fromRGB(46, 46, 58) }) end)
			b.MouseLeave:Connect(function() Tween(b, 0.12, { BackgroundColor3 = Color3.fromRGB(32, 32, 42) }) end)
			b.MouseButton1Click:Connect(fn)
			return b
		end

		actBtn("TELEPORT", 10, 64, ACCENT, function()
			local myChar = Player.Character
			local tChar  = plr.Character
			if myChar and tChar and myChar:FindFirstChild("HumanoidRootPart")
			and tChar:FindFirstChild("HumanoidRootPart") then
				myChar.HumanoidRootPart.CFrame = tChar.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
				Library:Notify({ Title = "Teleport", Content = plr.DisplayName .. " yanina gidildi", Type = "success", Time = 2 })
			else
				Library:Notify({ Title = "Teleport", Content = "Karakter bulunamadi", Type = "error", Time = 2 })
			end
		end)

		actBtn("SPECTATE", 78, 62, BLUE, function()
			local cam = workspace.CurrentCamera
			if plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") then
				cam.CameraSubject = plr.Character:FindFirstChildOfClass("Humanoid")
				Library:Notify({ Title = "Spectate", Content = plr.DisplayName .. " izleniyor", Type = "info", Time = 2 })
			end
		end)

		actBtn("COPY", 144, 46, TXT_MAIN, function()
			if setclipboard then
				pcall(setclipboard, plr.Name)
				Library:Notify({ Title = "Kopyalandi", Content = plr.Name, Type = "success", Time = 2 })
			end
		end)

		actBtn("RESET", 194, 48, YELLOW, function()
			local cam = workspace.CurrentCamera
			if Player.Character and Player.Character:FindFirstChildOfClass("Humanoid") then
				cam.CameraSubject = Player.Character:FindFirstChildOfClass("Humanoid")
				Library:Notify({ Title = "Kamera", Content = "Kendine dondu", Type = "info", Time = 2 })
			end
		end)

		local hovering = false
		row.MouseEnter:Connect(function()
			hovering = true
			Tween(row, 0.15, { BackgroundTransparency = 0.1 })
			Tween(stroke, 0.15, { Color = STROKE_HOT, Transparency = 0.2 })
			actions.Visible = true
			Tween(actions, 0.18, { BackgroundTransparency = 0.08 })
		end)
		row.MouseLeave:Connect(function()
			hovering = false
			Tween(row, 0.2, { BackgroundTransparency = 0.25 })
			Tween(stroke, 0.2, { Color = STROKE, Transparency = 0.55 })
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
					else data.dist.TextColor3 = TXT_DIM end
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
			BackgroundColor3 = BG_MAIN, BackgroundTransparency = 0.12,
			BorderSizePixel = 0, Parent = gui
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 9) }),
			Create("UIStroke", { Color = STROKE, Thickness = 1, Transparency = 0.35 })
		})
		Create("ImageLabel", {
			Image = ICONS.Keyboard, Size = UDim2.fromOffset(12, 12),
			Position = UDim2.fromOffset(11, 9), BackgroundTransparency = 1,
			ImageColor3 = ACCENT, ScaleType = Enum.ScaleType.Fit, Parent = frame
		})
		Create("TextLabel", {
			Text = "KEYBINDS", Font = Enum.Font.GothamBold, TextSize = 10.5,
			TextColor3 = ACCENT, BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(29, 6), Size = UDim2.new(1, -40, 0, 18), Parent = frame
		})
		Create("Frame", {
			Size = UDim2.new(1, -22, 0, 1), Position = UDim2.fromOffset(11, 27),
			BackgroundColor3 = STROKE, BackgroundTransparency = 0.4,
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
			Text = "none", Font = Enum.Font.GothamMedium, TextSize = 10,
			TextColor3 = TXT_FADE, BackgroundTransparency = 1,
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
			TextColor3 = TXT_DIM, BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, -52, 1, 0), Parent = row
		})
		Create("TextLabel", {
			Text = bind.Key and bind.Key.Name or "-", Font = Enum.Font.GothamBold, TextSize = 10,
			TextColor3 = ACCENT, BackgroundTransparency = 1,
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
		Image = ICONS.Search, Size = UDim2.fromOffset(17, 17),
		Position = UDim2.fromOffset(18, 19), BackgroundTransparency = 1,
		ImageColor3 = TXT_DIM, ImageTransparency = 1,
		ScaleType = Enum.ScaleType.Fit, Parent = main
	})

	local input = Create("TextBox", {
		Text = "", PlaceholderText = "Type a command or search settings...",
		PlaceholderColor3 = TXT_FADE, Font = Enum.Font.GothamMedium, TextSize = 15,
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
		TextColor3 = TXT_FADE, BackgroundTransparency = 1, TextTransparency = 1,
		Size = UDim2.fromScale(1, 1), Parent = hintBox
	})

	local divider = Create("Frame", {
		Size = UDim2.new(1, -24, 0, 1), Position = UDim2.fromOffset(12, 56),
		BackgroundColor3 = STROKE, BackgroundTransparency = 1,
		BorderSizePixel = 0, Parent = main
	})

	local resultHolder = Create("ScrollingFrame", {
		Position = UDim2.fromOffset(8, 62), Size = UDim2.new(1, -16, 1, -70),
		BackgroundTransparency = 1, ScrollBarThickness = 2,
		ScrollBarImageColor3 = ACCENT, ScrollBarImageTransparency = 0.6,
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
				Name = e.name, Desc = e.path or "", Icon = TYPE_ICONS[e.kind] or ICONS.Box,
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
			TextColor3 = TXT_FADE, BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 44), Parent = holder
		})
	end

	for i, item in ipairs(shown) do
		local row = Create("TextButton", {
			Text = "", AutoButtonColor = false,
			Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = ACCENT,
			BackgroundTransparency = 1, LayoutOrder = i, Parent = holder
		}, { Create("UICorner", { CornerRadius = UDim.new(0, 8) }) })

		Create("ImageLabel", {
			Image = item.Icon, Size = UDim2.fromOffset(15, 15),
			Position = UDim2.fromOffset(12, 13), BackgroundTransparency = 1,
			ImageColor3 = TXT_DIM, ScaleType = Enum.ScaleType.Fit, Parent = row
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
				TextColor3 = TXT_FADE, BackgroundTransparency = 1,
				Position = UDim2.fromOffset(38, 21), Size = UDim2.new(1, -130, 0, 13),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd, Parent = row
			})
		end

		local kindLbl = Create("TextLabel", {
			Text = (item.Kind or ""):upper(), Font = Enum.Font.Code, TextSize = 9,
			TextColor3 = TXT_FADE, BackgroundTransparency = 1,
			Position = UDim2.new(1, -88, 0, 14), Size = UDim2.fromOffset(80, 14),
			TextXAlignment = Enum.TextXAlignment.Right, Parent = row
		})

		if item.Value then
			local ok, v = pcall(item.Value)
			if ok and v ~= nil then
				kindLbl.Text = tostring(v):upper()
				kindLbl.TextColor3 = ACCENT
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
		if img then Tween(img, 0.12, { ImageColor3 = on and ACCENT or TXT_DIM }) end
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
		Create("UIStroke", { Color = ACCENT, Thickness = 2, Transparency = 1 })
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
		TextColor3 = TXT_FADE, BackgroundTransparency = 1, TextTransparency = 1,
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
		TextColor3 = TXT_MAIN, BackgroundTransparency = 1, TextTransparency = 1,
		Position = UDim2.fromOffset(18, 56), Size = UDim2.new(1, -36, 0, 46),
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true, ZIndex = 13, Parent = card
	})

	local skipBtn = Create("TextButton", {
		Text = "Skip", Font = Enum.Font.GothamMedium, TextSize = 12,
		TextColor3 = TXT_FADE, BackgroundTransparency = 1, TextTransparency = 1,
		AutoButtonColor = false, Position = UDim2.fromOffset(14, 0),
		Size = UDim2.fromOffset(50, 30), ZIndex = 13, Parent = card
	})

	local nextBtn = Create("TextButton", {
		Text = "Next", Font = Enum.Font.GothamBold, TextSize = 12,
		TextColor3 = Color3.fromRGB(20, 20, 28), BackgroundColor3 = ACCENT,
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
		Tween(nextBtn, 0.15, { BackgroundColor3 = ACCENT })
	end)
	skipBtn.MouseEnter:Connect(function()
		Tween(skipBtn, 0.15, { TextColor3 = TXT_MAIN })
	end)
	skipBtn.MouseLeave:Connect(function()
		Tween(skipBtn, 0.15, { TextColor3 = TXT_FADE })
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
			BackgroundColor3 = i == stepIdx and ACCENT or Color3.fromRGB(70, 70, 84),
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
	color = color or ACCENT
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
	baseColor = baseColor or BG_ELEMENT
	frame.MouseEnter:Connect(function()
		Tween(frame, 0.18, { BackgroundColor3 = BG_HOVER })
		if stroke then Tween(stroke, 0.18, { Color = STROKE_HOT }) end
	end)
	frame.MouseLeave:Connect(function()
		Tween(frame, 0.22, { BackgroundColor3 = baseColor })
		if stroke then Tween(stroke, 0.22, { Color = STROKE }) end
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
		local ui = tab:Section({ Name = "Interface", Icon = ICONS.Gear, Default = true })

		ui:Keybind({
			Name = "UI Toggle Key", Flag = "ui_toggle_key", Default = Library.ToggleKey,
			Tooltip = "Menuyu acip kapatan tus.",
			OnChange = function(new) Library.ToggleKey = new end
		})
		ui:Toggle({
			Name = "Background Blur", Flag = "ui_blur", Default = true,
			Tooltip = "Menu acikken oyun arka planini bulaniklastirir.",
			Callback = function(v)
				Library.BlurEnabled = v
				if Library._blur then Tween(Library._blur, 0.3, { Size = v and 14 or 0 }) end
			end
		})
		ui:Toggle({
			Name = "Animated Background", Flag = "ui_animbg", Default = true,
			Tooltip = "Grid arka planinin yavas hareketi ve isik gecisi.",
			Callback = function(v) Library.AnimatedBG = v end
		})
		ui:Toggle({
			Name = "Tooltips", Flag = "ui_tooltips", Default = true,
			Tooltip = "Su an okudugun kutucuklar.",
			Callback = function(v) Library.TooltipsOn = v end
		})
		ui:Toggle({
			Name = "Keybind Panel", Flag = "ui_keybind_panel", Default = false,
			Tooltip = "Ekranin solunda aktif keybind listesi gosterir.",
			Callback = function(v) Library:SetKeybindPanel(v) end
		})

		local panels = tab:Section({ Name = "Panels", Icon = ICONS.Layers, Default = true })

		panels:Button({
			Name = "Player List", Tooltip = "Sunucudaki oyuncular, mesafe, can ve hizli islemler.",
			Callback = function() Library:TogglePlayers() end
		})
		panels:Button({
			Name = "Notification Log", Tooltip = "Kacirdigin bildirimleri zaman damgasiyla gosterir.",
			Callback = function() Library:ToggleHistory() end
		})
		panels:Button({
			Name = "Command Palette", Tooltip = "Ctrl+K ile de acilir.",
			Callback = function() Library:OpenPalette() end
		})

		local misc = tab:Section({ Name = "Interface Actions", Icon = ICONS.Wrench, Default = false })

		misc:Button({
			Name = "Replay Tour", Tooltip = "Ilk acilistaki tanitim turunu tekrar oynatir.",
			Callback = function()
				Library:ResetTour()
				if Library._tourSteps then Library:StartTour(Library._tourSteps) end
			end
		})
		misc:Button({
			Name = "Unload Interface", Tooltip = "Tum arayuzu kapatir ve temizler.",
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
		"2t1Studio_Tooltip", "2t1Studio_Tour"
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
		BackgroundColor3 = BG_MAIN, BackgroundTransparency = 0.06,
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
	local closeBtn = makeDot(0,  Color3.fromRGB(255, 95, 87),  Color3.fromRGB(200, 70, 60),  "Kapat ve kaldir")
	local minBtn   = makeDot(22, Color3.fromRGB(255, 189, 46), Color3.fromRGB(200, 150, 30), "Kucult")
	local maxBtn   = makeDot(44, Color3.fromRGB(40, 205, 65),  Color3.fromRGB(30, 160, 50),  "Tam ekran")

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
		TextColor3 = TXT_FADE, TextXAlignment = Enum.TextXAlignment.Left,
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
			Create("UIStroke", { Color = STROKE, Thickness = 1, Transparency = 0.45 })
		})
		Create("ImageLabel", {
			Image = icon, Size = UDim2.fromOffset(13, 13),
			Position = UDim2.fromOffset(6.5, 6.5), BackgroundTransparency = 1,
			ImageColor3 = TXT_DIM, ScaleType = Enum.ScaleType.Fit, ZIndex = 8, Parent = b
		})
		b.MouseEnter:Connect(function()
			Tween(b, 0.15, { BackgroundTransparency = 0.05 })
			local i = b:FindFirstChildOfClass("ImageLabel")
			if i then Tween(i, 0.15, { ImageColor3 = ACCENT }) end
		end)
		b.MouseLeave:Connect(function()
			Tween(b, 0.15, { BackgroundTransparency = 0.3 })
			local i = b:FindFirstChildOfClass("ImageLabel")
			if i then Tween(i, 0.15, { ImageColor3 = TXT_DIM }) end
		end)
		b.MouseButton1Click:Connect(fn)
		AttachTooltip(b, tip)
		return b
	end

	quickBtn(0,  ICONS.Command, "Command Palette  (Ctrl+K)", function() Library:OpenPalette() end)
	quickBtn(31, ICONS.Users,   "Player List",               function() Library:TogglePlayers() end)
	quickBtn(62, ICONS.Bell,    "Notification Log",          function() Library:ToggleHistory() end)

	-- ---------- SEARCH ----------
	local searchBox = Create("Frame", {
		Name = "SearchBox", Size = UDim2.fromOffset(140, 26),
		Position = UDim2.new(1, -330, 0, 16), BackgroundColor3 = Color3.fromRGB(28, 28, 38),
		BackgroundTransparency = 0.2, ZIndex = 6, Parent = self.Top
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 7) }),
		Create("UIStroke", { Color = STROKE, Thickness = 1, Transparency = 0.3 })
	})
	local searchStroke = searchBox:FindFirstChildOfClass("UIStroke")

	Create("ImageLabel", {
		Image = ICONS.Search, Size = UDim2.fromOffset(13, 13),
		Position = UDim2.fromOffset(8, 6), BackgroundTransparency = 1,
		ImageColor3 = TXT_FADE, ScaleType = Enum.ScaleType.Fit, ZIndex = 7, Parent = searchBox
	})

	local searchInput = Create("TextBox", {
		Text = "", PlaceholderText = "Filter...", PlaceholderColor3 = TXT_FADE,
		Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Color3.fromRGB(240, 240, 245),
		BackgroundTransparency = 1, ClearTextOnFocus = false,
		Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -34, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7, Parent = searchBox
	})
	AttachTooltip(searchBox, "Acik sekmedeki ogeleri filtreler. Tum menude aramak icin Ctrl+K.")

	searchInput.Focused:Connect(function()
		Tween(searchStroke, 0.25, { Color = ACCENT, Transparency = 0.15 })
	end)
	searchInput.FocusLost:Connect(function()
		Tween(searchStroke, 0.25, { Color = STROKE, Transparency = 0.3 })
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
		Create("UIStroke", { Color = STROKE, Thickness = 1, Transparency = 0.55 })
	})

	self.Indicator = Create("Frame", {
		Name = "Indicator", Size = UDim2.fromOffset(3, 16),
		Position = UDim2.fromOffset(2, 0), BackgroundColor3 = ACCENT,
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

		-- ---------- BUTTON ----------
		function target:Button(cfg)
			local text     = cfg.Name or cfg.Text or "Button"
			local callback = cfg.Callback or function() end

			local bg = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = BG_ELEMENT,
				ClipsDescendants = true, ZIndex = 5, Parent = parentFrame
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Create("UIStroke", { Color = STROKE, Thickness = 1 })
			})
			local stroke = bg:FindFirstChildOfClass("UIStroke")

			Create("TextLabel", {
				Text = text, Font = Enum.Font.GothamMedium, TextSize = 13.5, TextColor3 = TXT_MAIN,
				BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(1, -90, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 6, Parent = bg
			})

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
				Tween(badge, 0.15, { BackgroundColor3 = ACCENT })
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
				Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = BG_ELEMENT,
				ClipsDescendants = true, ZIndex = 5, Parent = parentFrame
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Create("UIStroke", { Color = STROKE, Thickness = 1 })
			})
			local stroke = bg:FindFirstChildOfClass("UIStroke")

			Create("TextLabel", {
				Text = text, Font = Enum.Font.GothamMedium, TextSize = 13.5, TextColor3 = TXT_MAIN,
				BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(1, -70, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 6, Parent = bg
			})

			local tray = Create("Frame", {
				Size = UDim2.fromOffset(34, 4), Position = UDim2.new(1, -50, 0.5, -2),
				BackgroundColor3 = state and ACCENT or STROKE, ZIndex = 6, Parent = bg
			}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

			local knob = Create("Frame", {
				Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5),
				Position = state and UDim2.fromScale(1, 0.5) or UDim2.fromScale(0, 0.5),
				BackgroundColor3 = BG_ELEMENT, ZIndex = 8, Parent = tray
			}, {
				Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Create("UIStroke", { Color = state and ACCENT or STROKE, Thickness = 1.5 })
			})
			local knobStroke = knob:FindFirstChildOfClass("UIStroke")

			local function updateView(val)
				Tween(tray, 0.2, { BackgroundColor3 = val and ACCENT or STROKE })
				Tween(knob, 0.28, { Position = val and UDim2.fromScale(1, 0.5) or UDim2.fromScale(0, 0.5) })
				Tween(knobStroke, 0.2, { Color = val and ACCENT or STROKE })
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
				Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = BG_ELEMENT,
				ClipsDescendants = true, ZIndex = 5, Parent = parentFrame
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Create("UIStroke", { Color = STROKE, Thickness = 1 })
			})
			local stroke = bg:FindFirstChildOfClass("UIStroke")

			Create("TextLabel", {
				Text = text, Font = Enum.Font.GothamMedium, TextSize = 13.5, TextColor3 = TXT_MAIN,
				BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 7),
				Size = UDim2.new(1, -100, 0, 18), TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 6, Parent = bg
			})

			local valueLbl = Create("TextLabel", {
				Text = tostring(default) .. suffix, Font = Enum.Font.GothamBold, TextSize = 12.5,
				TextColor3 = ACCENT, BackgroundTransparency = 1,
				Position = UDim2.new(1, -70, 0, 7), Size = UDim2.fromOffset(56, 18),
				TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6, Parent = bg
			})

			local tray = Create("Frame", {
				Size = UDim2.new(1, -28, 0, 4), Position = UDim2.new(0, 14, 1, -14),
				BackgroundColor3 = Color3.fromRGB(45, 45, 56), ZIndex = 6, Parent = bg
			}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

			local fill = Create("Frame", {
				Size = UDim2.fromScale((default - min) / (max - min), 1),
				BackgroundColor3 = ACCENT, ZIndex = 7, Parent = tray
			}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

			local knob = Create("Frame", {
				Size = UDim2.fromOffset(11, 11), AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale((default - min) / (max - min), 0.5),
				BackgroundColor3 = BG_ELEMENT, ZIndex = 8, Parent = tray
			}, {
				Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Create("UIStroke", { Color = ACCENT, Thickness = 1.5 })
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
				Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = BG_ELEMENT,
				ClipsDescendants = true, ZIndex = 5, Parent = parentFrame
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Create("UIStroke", { Color = STROKE, Thickness = 1 })
			})
			local stroke = bg:FindFirstChildOfClass("UIStroke")

			local header = Create("TextButton", {
				Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, Text = "",
				ZIndex = 6, Parent = bg
			})

			local titleLbl2 = Create("TextLabel", {
				Text = text, Font = Enum.Font.GothamMedium, TextSize = 13.5, TextColor3 = TXT_MAIN,
				BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(1, -50, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 7, Parent = header
			})

			local arrow = Create("ImageLabel", {
				Image = ICONS.ArrowUpDown, Size = UDim2.fromOffset(13, 13),
				Position = UDim2.new(1, -28, 0.5, -6.5), BackgroundTransparency = 1,
				ImageColor3 = TXT_DIM, ScaleType = Enum.ScaleType.Fit, ZIndex = 7, Parent = header
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
					if lbl then Tween(lbl, 0.15, { TextColor3 = on and Color3.fromRGB(250, 250, 255) or TXT_DIM }) end
					if box then
						Tween(box, 0.15, { BackgroundColor3 = on and ACCENT or Color3.fromRGB(38, 38, 48) })
						local bs = box:FindFirstChildOfClass("UIStroke")
						if bs then Tween(bs, 0.15, { Color = on and ACCENT or STROKE }) end
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
						Create("UIStroke", { Color = STROKE, Thickness = 1 })
					})

					Create("ImageLabel", {
						Name = "Check", Image = ICONS.Check, Size = UDim2.fromOffset(10, 10),
						Position = UDim2.fromOffset(2, 2), BackgroundTransparency = 1,
						ImageColor3 = Color3.fromRGB(20, 20, 28), ImageTransparency = 1,
						ScaleType = Enum.ScaleType.Fit, ZIndex = 10, Parent = box
					})

					Create("TextLabel", {
						Name = "Label", Text = tostring(value), Font = Enum.Font.GothamMedium,
						TextSize = 12.5, TextColor3 = TXT_DIM, BackgroundTransparency = 1,
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
				Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = BG_ELEMENT,
				ClipsDescendants = true, ZIndex = 5, Parent = parentFrame
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Create("UIStroke", { Color = STROKE, Thickness = 1 })
			})
			local stroke = bg:FindFirstChildOfClass("UIStroke")

			Create("TextLabel", {
				Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = TXT_MAIN,
				BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(1, -90, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 6, Parent = bg
			})

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
			AttachTooltip(bg, cfg.Tooltip or "Tiklayip yeni bir tus ata.")

			hit.MouseButton1Click:Connect(function()
				listening = true
				keyTxt.Text = "..."
				Tween(dStroke, 0.2, { Color = ACCENT })
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
					local t = Tween(display, 0.1, { BackgroundColor3 = ACCENT })
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
				Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = BG_ELEMENT,
				ClipsDescendants = true, ZIndex = 5, Parent = parentFrame
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Create("UIStroke", { Color = STROKE, Thickness = 1 })
			})
			local stroke = bg:FindFirstChildOfClass("UIStroke")

			local lbl = Create("TextLabel", {
				Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = TXT_MAIN,
				BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(1, -90, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 6, Parent = bg
			})

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
				Text = default, PlaceholderText = placeholder, PlaceholderColor3 = TXT_FADE,
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
				Tween(hStroke, 0.35, { Color = ACCENT })
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
				Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = BG_ELEMENT,
				ClipsDescendants = true, ZIndex = 5, Parent = parentFrame
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Create("UIStroke", { Color = STROKE, Thickness = 1 })
			})
			local stroke = bg:FindFirstChildOfClass("UIStroke")

			Create("TextLabel", {
				Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = TXT_MAIN,
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
				Text = "", PlaceholderText = placeholder, PlaceholderColor3 = TXT_FADE,
				Font = Enum.Font.GothamMedium, TextSize = 11,
				TextColor3 = Color3.fromRGB(250, 250, 255), BackgroundTransparency = 1,
				ClearTextOnFocus = false, Size = UDim2.new(1, -10, 1, 0),
				Position = UDim2.fromOffset(5, 0), ZIndex = 7, Parent = inputHolder
			})

			local btn = Create("TextButton", {
				Text = btnText, Font = Enum.Font.GothamBold, TextSize = 11,
				TextColor3 = Color3.fromRGB(20, 20, 28), BackgroundColor3 = ACCENT,
				AutoButtonColor = false, Size = UDim2.fromOffset(50, 24),
				Position = UDim2.new(1, -62, 0.5, -12), ZIndex = 7, Parent = bg
			}, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })

			btn.MouseEnter:Connect(function() Tween(btn, 0.15, { BackgroundColor3 = Color3.fromRGB(220, 220, 232) }) end)
			btn.MouseLeave:Connect(function() Tween(btn, 0.15, { BackgroundColor3 = ACCENT }) end)
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
				Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = BG_ELEMENT,
				BackgroundTransparency = 0.45, ZIndex = 5, Parent = parentFrame
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Create("UIStroke", { Color = STROKE, Thickness = 1, Transparency = 0.5 })
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
				Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = BG_ELEMENT,
				ZIndex = 5, Parent = parentFrame
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Create("UIStroke", { Color = STROKE, Thickness = 1 })
			})

			Create("TextLabel", {
				Text = title:upper(), Font = Enum.Font.GothamBold, TextSize = 11.5,
				TextColor3 = ACCENT, BackgroundTransparency = 1,
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
					TextColor3 = TXT_FADE, BackgroundTransparency = 1,
					Position = UDim2.fromOffset(4, 0), Size = UDim2.new(0, w + 4, 1, 0),
					TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7, Parent = holder
				})
				Create("Frame", {
					Size = UDim2.new(1, -(w + 20), 0, 1), Position = UDim2.new(0, w + 14, 0.5, 0),
					BackgroundColor3 = STROKE, BackgroundTransparency = 0.5,
					BorderSizePixel = 0, ZIndex = 5, Parent = holder
				})
			else
				Create("Frame", {
					Size = UDim2.new(1, -8, 0, 1), Position = UDim2.new(0, 4, 0.5, 0),
					BackgroundColor3 = STROKE, BackgroundTransparency = 0.5,
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
				BackgroundColor3 = ACCENT, BackgroundTransparency = 1,
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
		if tabDot then Tween(tabDot, 0.2, { ImageColor3 = ACCENT }) end

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
		local icon = cfg.Icon or DEFAULT_SECTION_ICON
		local open = cfg.Default
		if open == nil then open = true end
		local expanded = open
		local Section = {}

		local SC = Create("Frame", {
			Name = "Section_" .. name, Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = BG_PANEL, BackgroundTransparency = 0.35,
			ClipsDescendants = true, ZIndex = 5, Parent = Page
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Create("UIStroke", { Color = STROKE, Thickness = 1, Transparency = 0.45 })
		})

		local HB = Create("TextButton", {
			Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Text = "",
			ZIndex = 7, Parent = SC
		})

		local IL = Create("ImageLabel", {
			Image = icon, Size = UDim2.fromOffset(15, 15),
			Position = UDim2.new(0, 14, 0.5, -7.5), BackgroundTransparency = 1,
			ImageColor3 = ACCENT, ScaleType = Enum.ScaleType.Fit, ZIndex = 8, Parent = HB
		})

		local ST = Create("TextLabel", {
			Text = name, Font = Enum.Font.GothamBold, TextSize = 13.5,
			TextColor3 = Color3.fromRGB(238, 238, 248), BackgroundTransparency = 1,
			Position = UDim2.fromOffset(37, 0), Size = UDim2.new(1, -80, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Parent = HB
		})

		local SA = Create("ImageLabel", {
			Image = ICONS.ArrowUpDown, Size = UDim2.fromOffset(13, 13),
			Position = UDim2.new(1, -28, 0.5, -6.5), BackgroundTransparency = 1,
			ImageColor3 = Color3.fromRGB(200, 200, 215), ScaleType = Enum.ScaleType.Fit,
			ZIndex = 8, Rotation = expanded and 90 or 0, Parent = HB
		})

		local headerH = 40
		if desc then
			Create("TextLabel", {
				Text = desc, Font = Enum.Font.GothamMedium, TextSize = 11,
				TextColor3 = TXT_FADE, BackgroundTransparency = 1,
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
			Tween(IL, 0.2, { ImageColor3 = expanded and ACCENT or Color3.fromRGB(120, 120, 134) })
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
		local catIcon  = cfg.Icon or DEFAULT_CATEGORY_ICONS[catName] or DEFAULT_SECTION_ICON
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
			ImageColor3 = ACCENT, ScaleType = Enum.ScaleType.Fit, ZIndex = 8, Parent = CH
		})

		local CT = Create("TextLabel", {
			Text = catName, Font = Enum.Font.GothamBold, TextSize = 12,
			TextColor3 = Color3.fromRGB(228, 228, 240), BackgroundTransparency = 1,
			Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -50, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8, Parent = CH
		})

		local CAI = Create("ImageLabel", {
			Image = ICONS.ArrowUpDown, Size = UDim2.fromOffset(11, 11),
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
			Tween(CI, 0.2, { ImageColor3 = expanded and ACCENT or Color3.fromRGB(100, 100, 114) })
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
				BackgroundColor3 = ACCENT, BackgroundTransparency = 1, ZIndex = 6, Parent = STF
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 7) }),
				Create("UIStroke", { Color = ACCENT, Thickness = 1, Transparency = 1 })
			})

			local Dot = Create("ImageLabel", {
				Name = "Dot", Image = ICONS.CornerRight, Size = UDim2.fromOffset(11, 11),
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
				ScrollBarThickness = 2, ScrollBarImageColor3 = ACCENT,
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
			Create("UIStroke", { Color = STROKE, Thickness = 1, Transparency = 0.4 })
		})

		Create("Frame", {
			Name = "TabHighlightBg", Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = ACCENT, BackgroundTransparency = 1, ZIndex = 6, Parent = TabBg
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 7) }),
			Create("UIStroke", { Color = ACCENT, Thickness = 1, Transparency = 1 })
		})

		local Dot = Create("ImageLabel", {
			Name = "Dot", Image = ICONS.CornerRight, Size = UDim2.fromOffset(11, 11),
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
			ScrollBarThickness = 2, ScrollBarImageColor3 = ACCENT,
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
		Library:RegisterCommand("Save Config", "Aktif ayarlari kaydet", function()
			local ok = Library:SaveConfig("default")
			Library:Notify({
				Title = "Config", Type = ok and "success" or "error",
				Content = ok and "default kaydedildi" or "Kaydedilemedi", Time = 3
			})
		end, ICONS.Download)

		Library:RegisterCommand("Load Config", "Kayitli ayarlari yukle", function()
			local ok, n = Library:LoadConfig("default")
			Library:Notify({
				Title = "Config", Type = ok and "success" or "error",
				Content = ok and (n .. " ayar geri yuklendi") or "Config bulunamadi", Time = 3
			})
		end, ICONS.Layers)

		Library:RegisterCommand("Share Config", "Ayarlari panoya kopyala", function()
			local s = Library:ExportConfig()
			Library:Notify({
				Title = "Config Share", Type = s and "success" or "error",
				Content = s and ("Panoya kopyalandi (" .. #s .. " karakter)") or "Olusturulamadi",
				Time = 4
			})
		end, ICONS.Copy)

		Library:RegisterCommand("Toggle Player List", "Oyuncu panelini ac/kapat", function()
			Library:TogglePlayers()
		end, ICONS.Users)

		Library:RegisterCommand("Notification Log", "Bildirim gecmisini ac", function()
			Library:ToggleHistory()
		end, ICONS.Bell)

		Library:RegisterCommand("Toggle Blur", "Arka plan bulaniklastirmayi ac/kapat", function()
			Library.BlurEnabled = not Library.BlurEnabled
			if Library._blur then
				Tween(Library._blur, 0.3, { Size = Library.BlurEnabled and 14 or 0 })
			end
			Library:Notify({
				Title = "Blur", Content = Library.BlurEnabled and "Acik" or "Kapali",
				Type = "info", Time = 2
			})
		end, ICONS.Eye)

		Library:RegisterCommand("Replay Tour", "Tanitim turunu tekrar oynat", function()
			Library:ResetTour()
			if Library._tourSteps then Library:StartTour(Library._tourSteps) end
		end, ICONS.Info)

		Library:RegisterCommand("Copy Game Link", "Oyun linkini kopyala", function()
			if setclipboard then
				pcall(setclipboard, "https://www.roblox.com/games/" .. game.PlaceId)
				Library:Notify({ Title = "Kopyalandi", Content = "Oyun linki", Type = "success", Time = 2 })
			end
		end, ICONS.Copy)

		Library:RegisterCommand("Rejoin Server", "Sunucuya yeniden baglan", function()
			game:GetService("TeleportService"):Teleport(game.PlaceId, Player)
		end, ICONS.Home)

		Library:RegisterCommand("Unload Interface", "Arayuzu tamamen kapat", function()
			Library:Unload()
		end, ICONS.Alert)
	end

	-- ============================================
	-- TOUR STEPS
	-- ============================================
	Library._tourSteps = {
		{
			Title = "2t1 Studio'ya hos geldin",
			Body  = "Kisa bir tur ile arayuzu tanitalim. Istedigin an Skip ile atlayabilirsin.",
			Target = function() return self.Main end
		},
		{
			Title = "Sekmeler",
			Body  = "Soldaki kategoriler acilip kapanir. Bir sekmeye tikladiginda yanindaki beyaz cizgi kayarak oraya gelir.",
			Target = function() return self.Sidebar end
		},
		{
			Title = "Hizli filtre",
			Body  = "Buraya yazdiginda acik sekmedeki ogeler aninda filtrelenir.",
			Target = function() return searchBox end
		},
		{
			Title = "Command Palette",
			Body  = "Ctrl+K ile her yerden acilir. Tum menudeki ayarlari arayabilir, komut calistirabilirsin. Ok tuslariyla gez, Enter ile sec.",
			Target = function() return quickHolder end
		},
		{
			Title = "Paneller",
			Body  = "Ustteki ikonlardan oyuncu listesini ve bildirim gecmisini acabilirsin. Panelleri surukleyip istedigin yere koyabilirsin.",
			Target = function() return quickHolder end
		},
		{
			Title = "Hazirsin",
			Body  = "Ayarlarini Settings sekmesinden kaydedebilir, arkadaslarinla paylasabilirsin. Iyi eglenceler.",
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

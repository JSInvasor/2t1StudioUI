--[[
	2t1 Studio UI Library
	Base: DcusUI Series by iksuwu / Morten UI
	Enhanced by JSInvasor

	FEATURES
	[+] Background blur (acrylic)
	[+] Open / close animation with element stagger
	[+] Live search across all tabs
	[+] Config system (save / load / autoload)
	[+] Ripple click effect
	[+] Hover lift on elements
	[+] Sliding active-tab indicator
	[+] Rich notifications (icon, progress bar, stacking)
	[+] Keybind list panel
	[+] Multi-select dropdown
	[+] New elements: Divider, Section title, Input+Button, Two-column row
]]

local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting     = game:GetService("Lighting")
local RunService   = game:GetService("RunService")
local TextService  = game:GetService("TextService")
local HttpService  = game:GetService("HttpService")
local Player       = game:GetService("Players").LocalPlayer

local DEFAULT_LOGO = "rbxassetid://122687530154939"

-- ============================================
-- HELPERS
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
-- THEME
-- ============================================
local ACCENT      = Color3.fromRGB(255, 255, 255)
local BG_MAIN     = Color3.fromRGB(15, 15, 20)
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
	CornerRight = "rbxassetid://10709812485",
	Puzzle      = "rbxassetid://10734944950",
	Box         = "rbxassetid://10709780578",
	Search      = "rbxassetid://10734943674",
	Check       = "rbxassetid://10709790644",
	X           = "rbxassetid://10747384394",
	Info        = "rbxassetid://10723415903",
	Alert       = "rbxassetid://10723345886",
	Keyboard    = "rbxassetid://10723379903",
}

local DEFAULT_SECTION_ICON = ICONS.Zap
local DEFAULT_CATEGORY_ICONS = {
	["Main"] = ICONS.Puzzle, ["Combat"] = ICONS.Sword, ["Player"] = ICONS.Home,
	["Misc"] = ICONS.Box,    ["Settings"] = ICONS.Gear, ["Visuals"] = ICONS.Eye,
	["Config"] = ICONS.Layers,
}

-- ============================================
-- LIBRARY ROOT
-- ============================================
local Library = {}
Library.__index = Library
Library.ToggleKey    = Enum.KeyCode.RightControl
Library.Flags        = {}      -- flag -> current value
Library.FlagSetters  = {}      -- flag -> function(value)
Library.ConfigFolder = "2t1Studio"
Library.Keybinds     = {}      -- {Name=, Key=}
Library.BlurEnabled  = true
Library._blur        = nil
Library._windows     = {}

-- ============================================
-- FILE HELPERS (executor)
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

function Library:SaveConfig(name)
	if not hasFileAPI() then return false, "no file api" end
	ensureFolder()
	name = name or "default"
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
	local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
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
			pcall(setter, final)
		end
	end
	return true
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

-- ============================================
-- RIPPLE
-- ============================================
local function AddRipple(button, host, color)
	host = host or button
	color = color or ACCENT
	button.MouseButton1Down:Connect(function(x, y)
		local absPos  = host.AbsolutePosition
		local absSize = host.AbsoluteSize
		local relX = x - absPos.X
		local relY = y - absPos.Y
		local maxDist = math.max(
			(Vector2.new(relX, relY) - Vector2.new(0, 0)).Magnitude,
			(Vector2.new(relX, relY) - Vector2.new(absSize.X, 0)).Magnitude,
			(Vector2.new(relX, relY) - Vector2.new(0, absSize.Y)).Magnitude,
			(Vector2.new(relX, relY) - absSize).Magnitude
		)

		local ripple = Create("Frame", {
			Name = "Ripple",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(relX, relY),
			Size = UDim2.fromOffset(0, 0),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.75,
			BorderSizePixel = 0,
			ZIndex = 20,
			Parent = host
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

		Tween(ripple, 0.45, { Size = UDim2.fromOffset(maxDist * 2, maxDist * 2), BackgroundTransparency = 1 })
		task.delay(0.5, function() ripple:Destroy() end)
	end)
end

-- ============================================
-- HOVER LIFT
-- ============================================
local function AddHover(frame, stroke, baseColor)
	baseColor = baseColor or BG_ELEMENT
	local baseSize = frame.Size
	frame.MouseEnter:Connect(function()
		Tween(frame, 0.18, { BackgroundColor3 = BG_HOVER })
		if stroke then Tween(stroke, 0.18, { Color = STROKE_HOT, Transparency = 0 }) end
	end)
	frame.MouseLeave:Connect(function()
		Tween(frame, 0.22, { BackgroundColor3 = baseColor })
		if stroke then Tween(stroke, 0.22, { Color = STROKE, Transparency = 0 }) end
	end)
end

-- ============================================
-- SETTING MANAGER
-- ============================================
function Library.SettingManager()
	local Manager = {}
	function Manager:AddToTab(tab)
		tab:Paragraph({ Title = "Interface", Content = "Manage the interface, keybinds and visual options." })
		tab:Keybind({
			Name = "UI Toggle Key", Flag = "ui_toggle_key", Default = Library.ToggleKey,
			OnChange = function(new) Library.ToggleKey = new end
		})
		tab:Toggle({
			Name = "Background Blur", Flag = "ui_blur", Default = true,
			Callback = function(v)
				Library.BlurEnabled = v
				if Library._blur then
					Tween(Library._blur, 0.3, { Size = v and 14 or 0 })
				end
			end
		})
		tab:Toggle({
			Name = "Keybind Panel", Flag = "ui_keybind_panel", Default = false,
			Callback = function(v) Library:SetKeybindPanel(v) end
		})
		tab:Button({ Name = "Unload Interface", Callback = function()
			Library:Unload()
		end })
	end
	return Manager
end

function Library:Unload()
	if Library._blur then
		Tween(Library._blur, 0.3, { Size = 0 })
		task.delay(0.35, function() if Library._blur then Library._blur:Destroy() end end)
	end
	local parent = getGuiParent()
	for _, n in pairs({ "2t1Studio_UI", "2t1Studio_Notifications", "2t1Studio_Keybinds" }) do
		local g = parent:FindFirstChild(n) or Player.PlayerGui:FindFirstChild(n)
		if g then g:Destroy() end
	end
end

-- ============================================
-- KEYBIND PANEL
-- ============================================
local KeybindPanel = { Gui = nil, Holder = nil, Rows = {} }

function Library:SetKeybindPanel(on)
	if on then
		if KeybindPanel.Gui then KeybindPanel.Gui.Enabled = true; return end
		local gui = Create("ScreenGui", {
			Name = "2t1Studio_Keybinds", ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = getGuiParent()
		})
		local frame = Create("Frame", {
			Name = "Panel", AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.fromOffset(180, 40),
			BackgroundColor3 = BG_MAIN, BackgroundTransparency = 0.15,
			BorderSizePixel = 0, Parent = gui
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Create("UIStroke", { Color = STROKE, Thickness = 1, Transparency = 0.35 })
		})
		Create("TextLabel", {
			Text = "KEYBINDS", Font = Enum.Font.GothamBold, TextSize = 11,
			TextColor3 = ACCENT, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 14), Parent = frame
		})
		Create("Frame", {
			Size = UDim2.new(1, -24, 0, 1), Position = UDim2.fromOffset(12, 26),
			BackgroundColor3 = STROKE, BorderSizePixel = 0, Parent = frame
		})
		local holder = Create("Frame", {
			Name = "Rows", Position = UDim2.fromOffset(12, 32),
			Size = UDim2.new(1, -24, 0, 0), BackgroundTransparency = 1, Parent = frame
		}, { Create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })

		local layout = holder:FindFirstChildOfClass("UIListLayout")
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			frame.Size = UDim2.fromOffset(180, 42 + layout.AbsoluteContentSize.Y)
		end)

		KeybindPanel.Gui    = gui
		KeybindPanel.Holder = holder
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
	for i, bind in ipairs(Library.Keybinds) do
		local row = Create("Frame", {
			Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
			LayoutOrder = i, Parent = KeybindPanel.Holder
		})
		Create("TextLabel", {
			Text = bind.Name, Font = Enum.Font.GothamMedium, TextSize = 11,
			TextColor3 = TXT_DIM, BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -50, 1, 0), Parent = row
		})
		Create("TextLabel", {
			Text = bind.Key and bind.Key.Name or "-", Font = Enum.Font.GothamBold, TextSize = 11,
			TextColor3 = ACCENT, BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(1, -48, 0, 0), Size = UDim2.fromOffset(48, 16), Parent = row
		})
	end
end

-- ============================================
-- NOTIFICATIONS
-- ============================================
local NOTIF_STYLES = {
	info    = { color = ACCENT, icon = ICONS.Info },
	success = { color = GREEN,  icon = ICONS.Check },
	error   = { color = RED,    icon = ICONS.Alert },
	warning = { color = YELLOW, icon = ICONS.Alert },
}

function Library:Notify(cfg)
	cfg = cfg or {}
	local title    = cfg.Title or "Notification"
	local content  = cfg.Content or ""
	local duration = cfg.Time or 5
	local style    = NOTIF_STYLES[(cfg.Type or "info"):lower()] or NOTIF_STYLES.info

	local parent = getGuiParent()
	local gui = parent:FindFirstChild("2t1Studio_Notifications")
	if not gui then
		gui = Create("ScreenGui", {
			Name = "2t1Studio_Notifications", ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = parent
		})
	end
	local holder = gui:FindFirstChild("Holder")
	if not holder then
		holder = Create("Frame", {
			Name = "Holder", Size = UDim2.new(0, 280, 1, -20),
			Position = UDim2.new(1, -292, 0, 10), BackgroundTransparency = 1, Parent = gui
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
		Image = style.icon, Size = UDim2.fromOffset(18, 18),
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

	local ts = TextService:GetTextSize(content, 12, Enum.Font.GothamMedium, Vector2.new(228, 10000))
	local targetH = math.max(52, ts.Y + 42)
	bodyLbl.Size = UDim2.new(1, -52, 0, ts.Y)

	card.Position = UDim2.new(1, 40, 0, 0)
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
		Tween(card, 0.35, { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
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
-- GRID BACKGROUND
-- ============================================
local function CreateGridBackground(parent, config)
	config = config or {}
	local gridColor  = config.GridColor or Color3.fromRGB(35, 35, 45)
	local thickness  = config.LineThickness or 1
	local spacing    = config.Spacing or 18
	local trans      = config.LineTransparency or 0.5

	local clip = Create("Frame", {
		Name = "GridClip", Size = UDim2.new(1, -4, 1, -4),
		Position = UDim2.fromOffset(2, 2), BackgroundTransparency = 1,
		ClipsDescendants = true, ZIndex = 1, Parent = parent
	})
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 11)
	corner.Parent = clip

	for i = 0, math.ceil(500 / spacing) + 1 do
		Create("Frame", {
			Name = "GridHLine", Size = UDim2.new(1, 0, 0, thickness),
			Position = UDim2.new(0, 0, 0, i * spacing),
			BackgroundColor3 = gridColor, BackgroundTransparency = trans,
			BorderSizePixel = 0, ZIndex = 1, Parent = clip
		})
	end
	for i = 0, math.ceil(700 / spacing) + 1 do
		Create("Frame", {
			Name = "GridVLine", Size = UDim2.new(0, thickness, 1, 0),
			Position = UDim2.new(0, i * spacing, 0, 0),
			BackgroundColor3 = gridColor, BackgroundTransparency = trans,
			BorderSizePixel = 0, ZIndex = 1, Parent = clip
		})
	end
	return clip
end

-- ============================================
-- WINDOW
-- ============================================
function Library:New(config)
	config = config or {}
	local self = setmetatable({}, Library)

	self._searchables = {}
	self._staggerItems = {}
	self.Open = true

	-- Blur
	if not Library._blur then
		local b = Instance.new("BlurEffect")
		b.Name = "2t1Studio_Blur"
		b.Size = 0
		b.Parent = Lighting
		Library._blur = b
	end

	self.Gui = Create("ScreenGui", {
		Name = "2t1Studio_UI", ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = getGuiParent()
	})

	local WIN_W, WIN_H = 580, 400

	self.Main = Create("Frame", {
		Size = UDim2.fromOffset(WIN_W, WIN_H),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = BG_MAIN,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0, ClipsDescendants = true,
		Parent = self.Gui
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

	-- window buttons
	local btnHolder = Create("Frame", {
		Size = UDim2.fromOffset(70, 20), Position = UDim2.new(1, -84, 0, 19),
		BackgroundTransparency = 1, ZIndex = 12, Parent = self.Top
	})
	local function makeDot(x, col, colDark)
		return Create("TextButton", {
			Size = UDim2.fromOffset(13, 13), Position = UDim2.fromOffset(x, 3),
			BackgroundColor3 = col, Text = "", AutoButtonColor = false,
			ZIndex = 13, Parent = btnHolder
		}, {
			Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Create("UIStroke", { Color = colDark, Thickness = 1, Transparency = 0.3 })
		})
	end
	local closeBtn = makeDot(0,  Color3.fromRGB(255, 95, 87),  Color3.fromRGB(200, 70, 60))
	local minBtn   = makeDot(22, Color3.fromRGB(255, 189, 46), Color3.fromRGB(200, 150, 30))
	local maxBtn   = makeDot(44, Color3.fromRGB(40, 205, 65),  Color3.fromRGB(30, 160, 50))

	-- logo + title
	Create("ImageLabel", {
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

	-- ---------- SEARCH ----------
	local searchBox = Create("Frame", {
		Name = "SearchBox", Size = UDim2.fromOffset(150, 26),
		Position = UDim2.new(1, -250, 0, 16), BackgroundColor3 = Color3.fromRGB(28, 28, 38),
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
		Text = "", PlaceholderText = "Search...", PlaceholderColor3 = TXT_FADE,
		Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Color3.fromRGB(240, 240, 245),
		BackgroundTransparency = 1, ClearTextOnFocus = false,
		Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -34, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7, Parent = searchBox
	})

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

	-- ---------- SIDEBAR ----------
	self.Sidebar = Create("Frame", {
		Size = UDim2.new(0, 156, 1, -16), Position = UDim2.fromOffset(10, 8),
		BackgroundColor3 = Color3.fromRGB(19, 19, 26), BackgroundTransparency = 0.35,
		ZIndex = 3, Parent = self.Container
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Create("UIStroke", { Color = STROKE, Thickness = 1, Transparency = 0.55 })
	})

	-- sliding indicator
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
		Size = UDim2.new(1, -186, 1, -16), Position = UDim2.fromOffset(176, 8),
		BackgroundTransparency = 1, ZIndex = 3, Parent = self.Container
	})

	self._activeTabBtn = nil
	self._activeTabDot = nil

	-- ---------- SEARCH LOGIC ----------
	local function ApplySearch(query)
		query = (query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
		for _, entry in ipairs(self._searchables) do
			local frame = entry.frame
			if frame and frame.Parent then
				if query == "" then
					frame.Visible = true
				else
					frame.Visible = (entry.name:find(query, 1, true) ~= nil)
				end
			end
		end
		-- keep sections open while searching
		for _, sec in ipairs(self._sections or {}) do
			if query ~= "" then sec:SetExpanded(true) end
		end
	end
	self._sections = {}
	searchInput:GetPropertyChangedSignal("Text"):Connect(function()
		ApplySearch(searchInput.Text)
	end)

	-- ---------- WINDOW CONTROLS ----------
	local function SetBlur(on)
		if not Library._blur then return end
		if not Library.BlurEnabled then
			Tween(Library._blur, 0.3, { Size = 0 })
			return
		end
		Tween(Library._blur, 0.35, { Size = on and 14 or 0 })
	end

	local function OpenWindow()
		self.Open = true
		self.Main.Visible = true
		scale.Scale = 0.88
		self.Main.BackgroundTransparency = 1
		Tween(scale, 0.42, { Scale = 1 }, Enum.EasingStyle.Back)
		Tween(self.Main, 0.3, { BackgroundTransparency = 0.06 })
		Tween(mainStroke, 0.3, { Transparency = 0.2 })
		SetBlur(true)
	end

	local function CloseWindow()
		self.Open = false
		Tween(scale, 0.28, { Scale = 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Tween(self.Main, 0.25, { BackgroundTransparency = 1 })
		Tween(mainStroke, 0.25, { Transparency = 1 })
		SetBlur(false)
		task.delay(0.3, function()
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
		if isMin then
			self.Container.Visible = false
		else
			task.delay(0.2, function() self.Container.Visible = true end)
		end
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
				dragging = true
				dragStart = input.Position
				startPos = self.Main.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then dragging = false end
				end)
			end
		end)
		UIS.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - dragStart
				self.Main.Position = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + delta.X,
					startPos.Y.Scale, startPos.Y.Offset + delta.Y
				)
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
	-- ELEMENT FACTORY
	-- ============================================
	local function RegisterSearch(frame, name)
		table.insert(self._searchables, { frame = frame, name = name:lower() })
	end

	local function RegisterFlag(flag, default, setter)
		if not flag then return end
		Library.Flags[flag] = default
		Library.FlagSetters[flag] = setter
	end

	local function CreateElementMethods(target, parentFrame, updateCanvas)

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

			Create("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(215, 215, 225))
				}),
				Parent = bg
			})

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

			-- slider-style track + knob
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

			local api = {}
			function api:Set(val, silent)
				state = val
				updateView(state)
				if flag then Library.Flags[flag] = state end
				if not silent then task.spawn(callback, state) end
			end
			function api:Get() return state end
			api.SetValue = api.Set

			hit.MouseButton1Click:Connect(function() api:Set(not state) end)

			RegisterFlag(flag, state, function(v) api:Set(v) end)
			RegisterSearch(bg, text)

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
				if rounding == 0 then
					val = math.floor(val + 0.5)
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

			local api = {}
			function api:Set(v, silent) setValue(v, silent) end
			function api:Get() return current end
			api.SetValue = api.Set

			RegisterFlag(flag, default, function(v) setValue(v) end)
			RegisterSearch(bg, text)
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

			local titleLbl = Create("TextLabel", {
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

			local optButtons = {}

			local function refreshTitle()
				if multi then
					local n = 0
					for _ in pairs(selected) do n = n + 1 end
					if n == 0 then
						titleLbl.Text = text
					elseif n == 1 then
						for k in pairs(selected) do titleLbl.Text = text .. " : " .. k end
					else
						titleLbl.Text = text .. " : " .. n .. " selected"
					end
				end
			end

			local function refreshVisuals()
				for value, btn in pairs(optButtons) do
					local on
					if multi then on = selected[value] == true else on = (selected == value) end
					local box = btn:FindFirstChild("Box")
					local lbl = btn:FindFirstChild("Label")
					local check = box and box:FindFirstChild("Check")
					Tween(lbl, 0.15, { TextColor3 = on and Color3.fromRGB(250, 250, 255) or TXT_DIM })
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
					refreshTitle()
					refreshVisuals()
					task.spawn(callback, out)
				else
					selected = value
					titleLbl.Text = text .. " : " .. tostring(value)
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
					local h = 42 + #list * (rowH + 2) + 10
					Tween(bg, 0.25, { Size = UDim2.new(1, 0, 0, h) })
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
			function api:Refresh(newList, keepSelection)
				list = newList or {}
				if not keepSelection then
					selected = multi and {} or nil
					titleLbl.Text = text
				end
				buildOptions()
				refreshVisuals()
			end
			api.SetValue = api.Set

			RegisterFlag(flag, multi and {} or default, function(v) api:Set(v) end)
			RegisterSearch(bg, text)

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

			input.Focused:Connect(function()
				Tween(holder, 0.35, { Size = UDim2.fromOffset(210, 26), Position = UDim2.new(1, -224, 0.5, -13) })
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
				Size = UDim2.new(0.4, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 6, Parent = bg
			})

			local inputHolder = Create("Frame", {
				Size = UDim2.new(0.35, 0, 0, 26), Position = UDim2.new(0.42, 0, 0.5, -13),
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

			btn.MouseEnter:Connect(function() Tween(btn, 0.15, { BackgroundColor3 = Color3.fromRGB(220, 220, 230) }) end)
			btn.MouseLeave:Connect(function() Tween(btn, 0.15, { BackgroundColor3 = ACCENT }) end)
			btn.MouseButton1Click:Connect(function() task.spawn(callback, input.Text) end)

			AddHover(bg, stroke)
			RegisterSearch(bg, text)

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
					Vector2.new(lbl.AbsoluteSize.X, 10000))
				bg.Size = UDim2.new(1, 0, 0, s.Y + 16)
				lbl.Size = UDim2.new(1, -28, 0, s.Y)
			end
			lbl:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
			task.spawn(resize)

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
					Vector2.new(body.AbsoluteSize.X, 10000))
				bg.Size = UDim2.new(1, 0, 0, s.Y + 48)
				body.Size = UDim2.new(1, -28, 0, s.Y)
			end
			body:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
			task.spawn(resize)

			RegisterSearch(bg, title .. " " .. content)

			local api = {}
			function api:Set(t, c)
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
					Size = UDim2.new(1, -(w + 20), 0, 1),
					Position = UDim2.new(0, w + 14, 0.5, 0),
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
	-- SELECT TAB (with sliding indicator)
	-- ============================================
	local function SelectTab(tabBtn, tabDot, page, subFrame)
		for _, cat in pairs(self.TabHolder:GetChildren()) do
			if cat:IsA("Frame") then
				local sub = cat:FindFirstChild("SubTabHolder")
				if sub then
					for _, sf in pairs(sub:GetChildren()) do
						if sf:IsA("Frame") then
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
					end
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
			-- move indicator
			task.spawn(function()
				task.wait()
				local relY = subFrame.AbsolutePosition.Y - self.Sidebar.AbsolutePosition.Y
				self.Indicator.BackgroundTransparency = 0
				Tween(self.Indicator, 0.3, {
					Position = UDim2.fromOffset(2, relY + 6)
				}, Enum.EasingStyle.Back)
			end)
		end

		page.Visible = true
		self._activeTabBtn = tabBtn
		self._activeTabDot = tabDot

		-- stagger reveal of page contents
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
						elseif d:IsA("ImageLabel") then
							texts[d] = false
						end
					end

					task.delay(i * 0.035, function()
						if not child.Parent then return end
						Tween(child, 0.3, { BackgroundTransparency = baseTrans })
						for d, v in pairs(texts) do
							if d and d.Parent and v ~= false then
								Tween(d, 0.3, { TextTransparency = v })
							end
						end
					end)
				end
			end
		end)
	end

	-- ============================================
	-- SECTION
	-- ============================================
	local function CreateSection(Page, UpdateCanvas, cfg)
		local name    = cfg.Name or cfg.Title or "Section"
		local desc    = cfg.Description or cfg.Desc
		local icon    = cfg.Icon or DEFAULT_SECTION_ICON
		local open    = cfg.Default
		if open == nil then open = true end
		local expanded = open
		local Section = {}

		local SC = Create("Frame", {
			Name = "Section_" .. name, Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = Color3.fromRGB(18, 18, 25), BackgroundTransparency = 0.35,
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
			Tween(SC, 0.35, {
				Size = UDim2.new(1, 0, 0, expanded and (headerH + 2 + h) or headerH)
			})
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

		CreateElementMethods(Section, CH, UpdateCanvas)

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

		CH.MouseButton1Click:Connect(function()
			expanded = not expanded
			Tween(CAI, 0.35, { Rotation = expanded and 90 or 0 })
			Tween(CT, 0.2, { TextColor3 = expanded and Color3.fromRGB(228, 228, 240) or Color3.fromRGB(150, 150, 166) })
			Tween(CI, 0.2, { ImageColor3 = expanded and ACCENT or Color3.fromRGB(100, 100, 114) })
			UpdateCatSize()
		end)

		CH.MouseEnter:Connect(function()
			Tween(CT, 0.15, { TextColor3 = Color3.fromRGB(255, 255, 255) })
		end)
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
				BackgroundColor3 = ACCENT, BackgroundTransparency = 1,
				ZIndex = 6, Parent = STF
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

			TB.MouseButton1Click:Connect(function() SelectTab(TB, Dot, Page, STF) end)
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

			CreateElementMethods(Tab, Page, UCS)
			function Tab:Section(c) return CreateSection(Page, UCS, c) end
			function Tab:Select() SelectTab(TB, Dot, Page, STF) end

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

		function Category:SetExpanded(v)
			expanded = v
			Tween(CAI, 0.35, { Rotation = expanded and 90 or 0 })
			UpdateCatSize()
		end
		function Category:IsExpanded() return expanded end
		return Category
	end

	-- ============================================
	-- STANDALONE TAB (backward compatible)
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

		TabBtn.MouseButton1Click:Connect(function() SelectTab(TabBtn, Dot, Page, TabBg) end)

		CreateElementMethods(Tab, Page, UCS)
		function Tab:Section(c) return CreateSection(Page, UCS, c) end
		function Tab:Select() SelectTab(TabBtn, Dot, Page, TabBg) end
		return Tab
	end

	-- ============================================
	-- BOOT ANIMATION
	-- ============================================
	self.Main.Visible = true
	scale.Scale = 0.85
	self.Main.BackgroundTransparency = 1
	mainStroke.Transparency = 1
	titleLbl.TextTransparency = 1
	footerLbl.TextTransparency = 1
	searchBox.BackgroundTransparency = 1
	searchStroke.Transparency = 1

	task.spawn(function()
		Tween(scale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
		Tween(self.Main, 0.35, { BackgroundTransparency = 0.06 })
		Tween(mainStroke, 0.4, { Transparency = 0.2 })
		if Library.BlurEnabled and Library._blur then
			Tween(Library._blur, 0.5, { Size = 14 })
		end
		task.wait(0.12)
		Tween(titleLbl, 0.35, { TextTransparency = 0 })
		task.wait(0.05)
		Tween(footerLbl, 0.35, { TextTransparency = 0 })
		Tween(searchBox, 0.35, { BackgroundTransparency = 0.2 })
		Tween(searchStroke, 0.35, { Transparency = 0.3 })
	end)

	table.insert(Library._windows, self)
	return self
end

return Library

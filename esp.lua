--[[
	2t1 Studio - ESP Module
	Drawing API based, pooled per player, single render loop.

	Usage:
		local ESP = loadstring(game:HttpGet(".../esp.lua"))()
		ESP:Init()                 -- start the render loop
		ESP:BuildUI(tab)           -- optional: auto-generate all controls on a 2t1 tab
		ESP.Settings.Enabled = true

	Every value lives in ESP.Settings and can be changed at any time.
]]

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local Workspace   = game:GetService("Workspace")
local UIS         = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

local ESP = {}

-- ============================================
-- SETTINGS
-- ============================================
ESP.Settings = {
	Enabled          = false,
	TeamCheck        = false,   -- skip players on your team
	VisibilityCheck  = true,    -- recolour when the target is behind cover
	MaxDistance      = 2000,
	RefreshRate      = 0,       -- 0 = every frame, otherwise seconds between updates

	Colors = {
		Enemy    = Color3.fromRGB(255, 70, 80),
		Team     = Color3.fromRGB(80, 200, 255),
		Visible  = Color3.fromRGB(90, 240, 140),
		Occluded = Color3.fromRGB(150, 150, 165),
	},

	Box = {
		Enabled   = true,
		Style     = "corner",             -- "corner" | "full"
		Thickness = 1,
		Outline   = true,
		Filled    = false,
		FillAlpha = 0.82,
	},

	Name = {
		Enabled     = true,
		Size        = 13,
		Font        = 2,
		Outline     = true,
		UseDisplay  = true,
		ShowHealth  = false,               -- append "  87hp"
	},

	Distance = {
		Enabled = true,
		Size    = 12,
		Font    = 2,
		Outline = true,
	},

	Health = {
		Enabled   = true,
		Side      = "left",                -- "left" | "right"
		Width     = 3,
		Offset    = 5,
		Outline   = true,
		HighColor = Color3.fromRGB(80, 230, 120),
		LowColor  = Color3.fromRGB(240, 70, 70),
	},

	Tracer = {
		Enabled   = false,
		Origin    = "bottom",              -- "bottom" | "center" | "top" | "mouse"
		Thickness = 1,
		Outline   = true,
	},

	Skeleton = {
		Enabled   = false,
		Thickness = 1,
		Color     = Color3.fromRGB(235, 238, 246),
	},

	HeadDot = {
		Enabled   = false,
		Radius    = 4,
		Thickness = 1,
		Filled    = false,
		Sides     = 14,
	},

	Chams = {
		Enabled          = false,
		FillColor        = Color3.fromRGB(255, 70, 80),
		FillTransparency = 0.6,
		OutlineColor     = Color3.fromRGB(255, 255, 255),
		OutlineAlpha     = 0,
		AlwaysOnTop      = true,
	},

	OffScreen = {
		Enabled   = false,
		Radius    = 180,
		Size      = 13,
		Thickness = 2,
	},
}

local S = ESP.Settings

-- capability corrections are applied after the probe below

-- ============================================
-- INTERNAL
-- ============================================
local objects   = {}      -- player -> drawing pool
local running   = false
local conn      = nil
local accum     = 0

local hasDrawing = (typeof(Drawing) == "table" or typeof(Drawing) == "userdata") and true or false

-- ---------- executor capability probe ----------
-- Some executors ship a partial Drawing API. Anything missing degrades
-- silently instead of throwing and killing the calling script.
ESP.Supported = { Line = false, Text = false, Square = false, Circle = false, Triangle = false }
ESP.Missing   = {}

-- Some executors only accept numbers where the spec says boolean.
-- This proxy converts on the way in so the rest of the module stays clean.
local function boolProxy(obj)
	return setmetatable({}, {
		__index = function(_, k)
			if k == "Remove" or k == "Destroy" then
				return function() pcall(function() obj:Remove() end) end
			end
			local ok, v = pcall(function() return obj[k] end)
			if ok then return v end
			return nil
		end,
		__newindex = function(_, k, v)
			if type(v) == "boolean" then v = v and 1 or 0 end
			pcall(function() obj[k] = v end)
		end,
	})
end

-- true  = works with plain booleans
-- "num" = works, but booleans must be sent as 0/1
-- false = unusable
local function probe(kind)
	if not hasDrawing then return false end

	local ok, obj = pcall(function() return Drawing.new(kind) end)
	if not ok or not obj then return false end

	local plain = pcall(function()
		obj.Visible = false
		obj.Transparency = 1
		obj.Color = Color3.new(1, 1, 1)
	end)
	if plain then
		pcall(function() obj:Remove() end)
		return true
	end

	-- retry with numeric booleans
	local numeric = pcall(function()
		obj.Visible = 0
		obj.Transparency = 1
		obj.Color = Color3.new(1, 1, 1)
	end)
	pcall(function() obj:Remove() end)
	if numeric then return "num" end
	return false
end

ESP.Mode = {}   -- kind -> true | "num" | false

if hasDrawing then
	for kind in pairs(ESP.Supported) do
		local mode = probe(kind)
		ESP.Mode[kind] = mode
		ESP.Supported[kind] = (mode ~= false)
		if mode == false then
			table.insert(ESP.Missing, kind)
		elseif mode == "num" then
			warn("[2t1 ESP] " .. kind .. " needs numeric booleans in this executor, using a compatibility wrapper.")
		end
	end
	if #ESP.Missing > 0 then
		warn("[2t1 ESP] Unsupported Drawing types in this executor: " .. table.concat(ESP.Missing, ", "))
	end
	-- fall back to whatever the executor can actually draw
	if not ESP.Supported.Square then
		ESP.Settings.Box.Style  = "corner"
		ESP.Settings.Box.Filled = false
	end
	if not ESP.Supported.Circle   then ESP.Settings.HeadDot.Enabled   = false end
	if not ESP.Supported.Triangle then ESP.Settings.OffScreen.Enabled = false end
end

-- Prints exactly what this executor can and cannot do. Handy when a feature
-- silently does nothing and you want to know whether it is your settings or
-- the executor.
function ESP:Diagnose()
	print("=== 2t1 ESP capability report ===")
	print("Drawing API present :", hasDrawing)
	for kind, mode in pairs(ESP.Mode) do
		local label = (mode == true and "native")
			or (mode == "num" and "numeric-boolean wrapper")
			or "UNSUPPORTED"
		print(string.format("  %-9s %s", kind, label))
	end
	local okHl = pcall(function()
		local h = Instance.new("Highlight"); h:Destroy()
	end)
	print("Highlight (chams)   :", okHl and "available" or "UNSUPPORTED")
	print("=================================")
	return ESP.Mode
end

-- stand-in for an unsupported drawing type: swallows every read and write
local DUMMY_MT = {
	__index = function(_, k)
		if k == "Remove" or k == "Destroy" then return function() end end
		return nil
	end,
	__newindex = function() end,
}
local function makeDummy()
	return setmetatable({}, DUMMY_MT)
end

local function safeNew(kind)
	if not ESP.Supported[kind] then return makeDummy(), false end
	local ok, obj = pcall(function() return Drawing.new(kind) end)
	if not ok or not obj then
		ESP.Supported[kind] = false
		return makeDummy(), false
	end
	if ESP.Mode[kind] == "num" then
		return boolProxy(obj), true
	end
	return obj, true
end

-- creates a drawing and configures it; anything that throws during setup
-- retires that type instead of bubbling the error up to the caller
local function build(kind, setup)
	local obj, real = safeNew(kind)
	if not real then return obj end
	local ok = pcall(setup, obj)
	if ok then return obj end

	pcall(function() obj:Remove() end)
	ESP.Supported[kind] = false
	ESP.Mode[kind] = false
	local already = false
	for _, k in ipairs(ESP.Missing) do
		if k == kind then already = true break end
	end
	if not already then table.insert(ESP.Missing, kind) end
	warn("[2t1 ESP] " .. kind .. " could not be configured, disabling features that use it.")
	return makeDummy()
end

local R15_BONES = {
	{ "Head", "UpperTorso" },
	{ "UpperTorso", "LowerTorso" },
	{ "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
	{ "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
	{ "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
	{ "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}

local R6_BONES = {
	{ "Head", "Torso" },
	{ "Torso", "Left Arm" }, { "Torso", "Right Arm" },
	{ "Torso", "Left Leg" }, { "Torso", "Right Leg" },
}

local MAX_BONES = #R15_BONES

-- ---------- drawing helpers ----------
local function newLine()
	return build("Line", function(l)
		l.Visible = false; l.Thickness = 1; l.Transparency = 1
		l.Color = Color3.new(1, 1, 1)
	end)
end

local function newText()
	return build("Text", function(t)
		t.Visible = false; t.Center = true; t.Outline = true
		t.Size = 13; t.Font = 2; t.Transparency = 1
		t.Color = Color3.new(1, 1, 1)
	end)
end

local function newSquare()
	return build("Square", function(sq)
		sq.Visible = false; sq.Thickness = 1; sq.Filled = false
		sq.Transparency = 1; sq.Color = Color3.new(1, 1, 1)
	end)
end

local function newCircle()
	return build("Circle", function(c)
		c.Visible = false; c.Thickness = 1; c.Filled = false
		c.NumSides = 14; c.Radius = 4; c.Transparency = 1
		c.Color = Color3.new(1, 1, 1)
	end)
end

local function newTriangle()
	return build("Triangle", function(t)
		t.Visible = false; t.Thickness = 2; t.Filled = true
		t.Transparency = 1; t.Color = Color3.new(1, 1, 1)
	end)
end

-- ---------- pool ----------
local function createPool()
	local p = {
		boxOutline = newSquare(),
		box        = newSquare(),
		boxFill    = newSquare(),
		corners    = {},        -- 8 lines for corner style
		cornerOut  = {},
		name       = newText(),
		distance   = newText(),
		healthBg   = newLine(),
		healthBar  = newLine(),
		tracer     = newLine(),
		tracerOut  = newLine(),
		headDot    = newCircle(),
		bones      = {},
		arrow      = newTriangle(),
		highlight  = nil,
	}

	p.boxFill.Filled = true

	for i = 1, 8 do
		p.corners[i]   = newLine()
		p.cornerOut[i] = newLine()
	end
	for i = 1, MAX_BONES do
		p.bones[i] = newLine()
	end
	return p
end

local function hidePool(p)
	if not p then return end
	p.boxOutline.Visible = false
	p.box.Visible        = false
	p.boxFill.Visible    = false
	p.name.Visible       = false
	p.distance.Visible   = false
	p.healthBg.Visible   = false
	p.healthBar.Visible  = false
	p.tracer.Visible     = false
	p.tracerOut.Visible  = false
	p.headDot.Visible    = false
	p.arrow.Visible      = false
	for i = 1, 8 do
		p.corners[i].Visible   = false
		p.cornerOut[i].Visible = false
	end
	for i = 1, MAX_BONES do
		p.bones[i].Visible = false
	end
	if p.highlight then p.highlight.Enabled = false end
end

local function destroyPool(p)
	if not p then return end
	local function kill(o) if o and o.Remove then pcall(function() o:Remove() end) end end
	kill(p.boxOutline); kill(p.box); kill(p.boxFill)
	kill(p.name); kill(p.distance)
	kill(p.healthBg); kill(p.healthBar)
	kill(p.tracer); kill(p.tracerOut)
	kill(p.headDot); kill(p.arrow)
	for i = 1, 8 do kill(p.corners[i]); kill(p.cornerOut[i]) end
	for i = 1, MAX_BONES do kill(p.bones[i]) end
	if p.highlight then p.highlight:Destroy() end
end

-- ---------- geometry ----------
local function getCharacterParts(char)
	local hrp  = char:FindFirstChild("HumanoidRootPart")
	local head = char:FindFirstChild("Head")
	local hum  = char:FindFirstChildOfClass("Humanoid")
	return hrp, head, hum
end

-- screen-space box from head top to foot bottom
local function computeBox(hrp, head)
	local topWorld = (head.CFrame * CFrame.new(0, head.Size.Y * 0.9, 0)).Position
	local botWorld = (hrp.CFrame * CFrame.new(0, -3.3, 0)).Position

	local topPos, topVis = Camera:WorldToViewportPoint(topWorld)
	local botPos, botVis = Camera:WorldToViewportPoint(botWorld)
	if not (topVis or botVis) then return nil end
	if topPos.Z <= 0 and botPos.Z <= 0 then return nil end

	local height = math.abs(topPos.Y - botPos.Y)
	if height < 4 then return nil end
	local width  = height * 0.52

	local x = math.min(topPos.X, botPos.X) - width / 2
	local y = math.min(topPos.Y, botPos.Y)

	return Vector2.new(x, y), Vector2.new(width, height)
end

local raycastParams = RaycastParams.new()
do
	-- Blacklist was renamed to Exclude; support both
	local ok = pcall(function()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	end)
	if not ok then
		pcall(function()
			raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
		end)
	end
end

local function isVisible(char, targetPos)
	local myChar = LocalPlayer.Character
	if not myChar then return true end
	raycastParams.FilterDescendantsInstances = { myChar, char, Camera }
	local origin = Camera.CFrame.Position
	local dir = targetPos - origin
	local result = Workspace:Raycast(origin, dir, raycastParams)
	return result == nil
end

local function tracerOrigin()
	local vp = Camera.ViewportSize
	local o = S.Tracer.Origin
	if o == "center" then return Vector2.new(vp.X / 2, vp.Y / 2)
	elseif o == "top" then return Vector2.new(vp.X / 2, 0)
	elseif o == "mouse" then
		local m = UIS:GetMouseLocation()
		return Vector2.new(m.X, m.Y)
	end
	return Vector2.new(vp.X / 2, vp.Y)
end

-- ---------- chams ----------
local function ensureHighlight(p, char)
	if not S.Chams.Enabled then
		if p.highlight then p.highlight.Enabled = false end
		return
	end
	if not p.highlight or p.highlight.Parent ~= char then
		if p.highlight then p.highlight:Destroy() end
		local okHl, hl = pcall(function() return Instance.new("Highlight") end)
		if not okHl or not hl then return end
		hl.Name = "2t1_Chams"
		hl.Adornee = char
		hl.FillColor = S.Chams.FillColor
		hl.FillTransparency = S.Chams.FillTransparency
		hl.OutlineColor = S.Chams.OutlineColor
		hl.OutlineTransparency = S.Chams.OutlineAlpha
		hl.DepthMode = S.Chams.AlwaysOnTop
			and Enum.HighlightDepthMode.AlwaysOnTop
			or Enum.HighlightDepthMode.Occluded
		local ok = pcall(function() hl.Parent = char end)
		if not ok then hl.Parent = Workspace end
		p.highlight = hl
	end
	p.highlight.Enabled = true
	p.highlight.FillColor = S.Chams.FillColor
	p.highlight.FillTransparency = S.Chams.FillTransparency
	p.highlight.OutlineColor = S.Chams.OutlineColor
	p.highlight.OutlineTransparency = S.Chams.OutlineAlpha
	p.highlight.DepthMode = S.Chams.AlwaysOnTop
		and Enum.HighlightDepthMode.AlwaysOnTop
		or Enum.HighlightDepthMode.Occluded
end

-- ---------- corner box ----------
local function drawCornerBox(p, pos, size, color, thickness)
	local cut = math.min(size.X, size.Y) * 0.28
	local x, y, w, hgt = pos.X, pos.Y, size.X, size.Y

	local segs = {
		{ Vector2.new(x, y),               Vector2.new(x + cut, y) },
		{ Vector2.new(x, y),               Vector2.new(x, y + cut) },
		{ Vector2.new(x + w, y),           Vector2.new(x + w - cut, y) },
		{ Vector2.new(x + w, y),           Vector2.new(x + w, y + cut) },
		{ Vector2.new(x, y + hgt),         Vector2.new(x + cut, y + hgt) },
		{ Vector2.new(x, y + hgt),         Vector2.new(x, y + hgt - cut) },
		{ Vector2.new(x + w, y + hgt),     Vector2.new(x + w - cut, y + hgt) },
		{ Vector2.new(x + w, y + hgt),     Vector2.new(x + w, y + hgt - cut) },
	}

	for i = 1, 8 do
		local seg = segs[i]
		if S.Box.Outline then
			local o = p.cornerOut[i]
			o.From = seg[1]; o.To = seg[2]
			o.Thickness = thickness + 2
			o.Color = Color3.new(0, 0, 0)
			o.Transparency = 0.55
			o.Visible = true
		else
			p.cornerOut[i].Visible = false
		end

		local l = p.corners[i]
		l.From = seg[1]; l.To = seg[2]
		l.Thickness = thickness
		l.Color = color
		l.Visible = true
	end
end

-- ---------- off screen arrow ----------
local function drawArrow(p, worldPos, color)
	local vp = Camera.ViewportSize
	local center = Vector2.new(vp.X / 2, vp.Y / 2)

	local screenPos, onScreen = Camera:WorldToViewportPoint(worldPos)
	if onScreen and screenPos.Z > 0 then
		p.arrow.Visible = false
		return
	end

	local dir = Vector2.new(screenPos.X, screenPos.Y) - center
	if screenPos.Z <= 0 then dir = -dir end
	if dir.Magnitude < 0.001 then p.arrow.Visible = false; return end
	dir = dir.Unit

	local tip  = center + dir * S.OffScreen.Radius
	local perp = Vector2.new(-dir.Y, dir.X)
	local sz   = S.OffScreen.Size

	p.arrow.PointA = tip + dir * sz
	p.arrow.PointB = tip - dir * (sz * 0.4) + perp * (sz * 0.62)
	p.arrow.PointC = tip - dir * (sz * 0.4) - perp * (sz * 0.62)
	p.arrow.Color = color
	p.arrow.Thickness = S.OffScreen.Thickness
	p.arrow.Filled = true
	p.arrow.Visible = true
end

-- ============================================
-- MAIN RENDER
-- ============================================
local function renderPlayer(plr, p)
	local char = plr.Character
	if not char then hidePool(p); return end

	local hrp, head, hum = getCharacterParts(char)
	if not (hrp and head and hum) or hum.Health <= 0 then hidePool(p); return end

	-- team filter
	if S.TeamCheck and plr.Team and plr.Team == LocalPlayer.Team then
		hidePool(p); return
	end

	-- distance
	local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local dist = myRoot and (hrp.Position - myRoot.Position).Magnitude or 0
	if dist > S.MaxDistance then hidePool(p); return end

	-- colour
	local isTeam = plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team
	local color = isTeam and S.Colors.Team or S.Colors.Enemy
	if S.VisibilityCheck then
		color = isVisible(char, head.Position) and S.Colors.Visible or S.Colors.Occluded
	end

	ensureHighlight(p, char)

	-- off-screen arrow
	if S.OffScreen.Enabled then
		drawArrow(p, hrp.Position, color)
	else
		p.arrow.Visible = false
	end

	local pos, size = computeBox(hrp, head)
	if not pos then hidePool(p); if S.OffScreen.Enabled then drawArrow(p, hrp.Position, color) end return end

	-- ----- box -----
	if S.Box.Enabled then
		if S.Box.Style == "corner" then
			p.box.Visible = false
			p.boxOutline.Visible = false
			drawCornerBox(p, pos, size, color, S.Box.Thickness)
		else
			for i = 1, 8 do
				p.corners[i].Visible = false
				p.cornerOut[i].Visible = false
			end
			if S.Box.Outline then
				p.boxOutline.Position = pos - Vector2.new(1, 1)
				p.boxOutline.Size = size + Vector2.new(2, 2)
				p.boxOutline.Color = Color3.new(0, 0, 0)
				p.boxOutline.Thickness = S.Box.Thickness + 2
				p.boxOutline.Transparency = 0.55
				p.boxOutline.Visible = true
			else
				p.boxOutline.Visible = false
			end
			p.box.Position = pos
			p.box.Size = size
			p.box.Color = color
			p.box.Thickness = S.Box.Thickness
			p.box.Visible = true
		end

		if S.Box.Filled then
			p.boxFill.Position = pos
			p.boxFill.Size = size
			p.boxFill.Color = color
			p.boxFill.Transparency = 1 - S.Box.FillAlpha
			p.boxFill.Visible = true
		else
			p.boxFill.Visible = false
		end
	else
		p.box.Visible = false
		p.boxOutline.Visible = false
		p.boxFill.Visible = false
		for i = 1, 8 do
			p.corners[i].Visible = false
			p.cornerOut[i].Visible = false
		end
	end

	-- ----- name -----
	if S.Name.Enabled then
		local label = S.Name.UseDisplay and plr.DisplayName or plr.Name
		if S.Name.ShowHealth then
			label = label .. "   " .. math.floor(hum.Health) .. "hp"
		end
		p.name.Text = label
		p.name.Size = S.Name.Size
		p.name.Font = S.Name.Font
		p.name.Outline = S.Name.Outline
		p.name.Color = color
		p.name.Position = Vector2.new(pos.X + size.X / 2, pos.Y - S.Name.Size - 3)
		p.name.Visible = true
	else
		p.name.Visible = false
	end

	-- ----- distance -----
	if S.Distance.Enabled then
		p.distance.Text = math.floor(dist) .. "m"
		p.distance.Size = S.Distance.Size
		p.distance.Font = S.Distance.Font
		p.distance.Outline = S.Distance.Outline
		p.distance.Color = color
		p.distance.Position = Vector2.new(pos.X + size.X / 2, pos.Y + size.Y + 2)
		p.distance.Visible = true
	else
		p.distance.Visible = false
	end

	-- ----- health bar -----
	if S.Health.Enabled and hum.MaxHealth > 0 then
		local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
		local barX = (S.Health.Side == "right")
			and (pos.X + size.X + S.Health.Offset)
			or  (pos.X - S.Health.Offset)

		local top = Vector2.new(barX, pos.Y)
		local bot = Vector2.new(barX, pos.Y + size.Y)

		if S.Health.Outline then
			p.healthBg.From = top - Vector2.new(0, 1)
			p.healthBg.To   = bot + Vector2.new(0, 1)
			p.healthBg.Thickness = S.Health.Width + 2
			p.healthBg.Color = Color3.new(0, 0, 0)
			p.healthBg.Transparency = 0.6
			p.healthBg.Visible = true
		else
			p.healthBg.Visible = false
		end

		p.healthBar.From = Vector2.new(barX, pos.Y + size.Y * (1 - pct))
		p.healthBar.To   = bot
		p.healthBar.Thickness = S.Health.Width
		p.healthBar.Color = S.Health.LowColor:Lerp(S.Health.HighColor, pct)
		p.healthBar.Visible = true
	else
		p.healthBg.Visible = false
		p.healthBar.Visible = false
	end

	-- ----- tracer -----
	if S.Tracer.Enabled then
		local from = tracerOrigin()
		local to = Vector2.new(pos.X + size.X / 2, pos.Y + size.Y)
		if S.Tracer.Outline then
			p.tracerOut.From = from; p.tracerOut.To = to
			p.tracerOut.Thickness = S.Tracer.Thickness + 2
			p.tracerOut.Color = Color3.new(0, 0, 0)
			p.tracerOut.Transparency = 0.55
			p.tracerOut.Visible = true
		else
			p.tracerOut.Visible = false
		end
		p.tracer.From = from
		p.tracer.To = to
		p.tracer.Thickness = S.Tracer.Thickness
		p.tracer.Color = color
		p.tracer.Visible = true
	else
		p.tracer.Visible = false
		p.tracerOut.Visible = false
	end

	-- ----- head dot -----
	if S.HeadDot.Enabled then
		local hp, vis = Camera:WorldToViewportPoint(head.Position)
		if vis and hp.Z > 0 then
			local scale = math.clamp(1000 / (dist + 1), 0.35, 2.2)
			p.headDot.Position = Vector2.new(hp.X, hp.Y)
			p.headDot.Radius = S.HeadDot.Radius * scale
			p.headDot.NumSides = S.HeadDot.Sides
			p.headDot.Thickness = S.HeadDot.Thickness
			p.headDot.Filled = S.HeadDot.Filled
			p.headDot.Color = color
			p.headDot.Visible = true
		else
			p.headDot.Visible = false
		end
	else
		p.headDot.Visible = false
	end

	-- ----- skeleton -----
	if S.Skeleton.Enabled then
		local bones = char:FindFirstChild("UpperTorso") and R15_BONES or R6_BONES
		local idx = 0
		for _, pair in ipairs(bones) do
			local a = char:FindFirstChild(pair[1])
			local b = char:FindFirstChild(pair[2])
			idx = idx + 1
			local line = p.bones[idx]
			if a and b and line then
				local pa, va = Camera:WorldToViewportPoint(a.Position)
				local pb, vb = Camera:WorldToViewportPoint(b.Position)
				if pa.Z > 0 and pb.Z > 0 then
					line.From = Vector2.new(pa.X, pa.Y)
					line.To   = Vector2.new(pb.X, pb.Y)
					line.Thickness = S.Skeleton.Thickness
					line.Color = S.Skeleton.Color
					line.Visible = true
				else
					line.Visible = false
				end
			elseif line then
				line.Visible = false
			end
		end
		for i = idx + 1, MAX_BONES do
			p.bones[i].Visible = false
		end
	else
		for i = 1, MAX_BONES do p.bones[i].Visible = false end
	end
end

-- ============================================
-- LIFECYCLE
-- ============================================
local function addPlayer(plr)
	if plr == LocalPlayer then return end
	if objects[plr] then return end
	if not hasDrawing then return end
	local ok, pool = pcall(createPool)
	if ok and pool then
		objects[plr] = pool
	else
		warn("[2t1 ESP] Could not build drawings for " .. plr.Name .. ": " .. tostring(pool))
	end
end

local function removePlayer(plr)
	if objects[plr] then
		destroyPool(objects[plr])
		objects[plr] = nil
	end
end

function ESP:Init()
	if running then return true end
	if not hasDrawing then
		warn("[2t1 ESP] Drawing API not available in this executor. ESP is disabled.")
		return false, "no drawing api"
	end
	if not ESP.Supported.Line or not ESP.Supported.Text then
		warn("[2t1 ESP] This executor is missing core Drawing types. ESP is disabled.")
		return false, "missing core types"
	end
	running = true

	Camera = Workspace.CurrentCamera
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		Camera = Workspace.CurrentCamera
	end)

	for _, plr in ipairs(Players:GetPlayers()) do
		pcall(addPlayer, plr)
	end
	Players.PlayerAdded:Connect(function(plr) pcall(addPlayer, plr) end)
	Players.PlayerRemoving:Connect(function(plr) pcall(removePlayer, plr) end)

	conn = RunService.RenderStepped:Connect(function(dt)
		if not S.Enabled then
			for _, p in pairs(objects) do hidePool(p) end
			return
		end

		if S.RefreshRate > 0 then
			accum = accum + dt
			if accum < S.RefreshRate then return end
			accum = 0
		end

		for plr, p in pairs(objects) do
			local ok, err = pcall(renderPlayer, plr, p)
			if not ok then hidePool(p) end
		end
	end)

	return true
end

function ESP:Stop()
	running = false
	if conn then conn:Disconnect(); conn = nil end
	for _, p in pairs(objects) do hidePool(p) end
end

function ESP:Destroy()
	ESP:Stop()
	for plr, p in pairs(objects) do
		destroyPool(p)
		objects[plr] = nil
	end
end

function ESP:Refresh()
	for plr, p in pairs(objects) do
		destroyPool(p)
		objects[plr] = createPool()
	end
end

-- ============================================
-- UI BUILDER  (2t1 Studio tab)
-- ============================================
function ESP:BuildUI(tab)
	-- ---------- general ----------
	local main = tab:Section({ Name = "ESP", Icon = "scan", Default = true })

	local wrapped = {}
	for kind, mode in pairs(ESP.Mode) do
		if mode == "num" then table.insert(wrapped, kind) end
	end
	table.sort(wrapped)

	if #ESP.Missing > 0 then
		main:Paragraph({
			Title = "Limited support",
			Content = "Your executor does not provide these Drawing types: "
				.. table.concat(ESP.Missing, ", ")
				.. ". The features that rely on them are hidden. Everything else works normally."
		})
	elseif #wrapped > 0 then
		main:Paragraph({
			Title = "Compatibility mode",
			Content = "These Drawing types needed a small compatibility wrapper on your executor: "
				.. table.concat(wrapped, ", ")
				.. ". Everything still works, there is nothing you need to change."
		})
	end

	main:Toggle({
		Name = "Enabled", Icon = "eye", Flag = "esp_enabled", Default = false,
		Tooltip = "Master switch. Everything below only draws while this is on.",
		Callback = function(v) S.Enabled = v end
	})
	main:Toggle({
		Name = "Team Check", Icon = "users", Flag = "esp_teamcheck", Default = false,
		Tooltip = "Skip anyone on your own team entirely.",
		Callback = function(v) S.TeamCheck = v end
	})
	main:Toggle({
		Name = "Visibility Colours", Icon = "scan", Flag = "esp_vischeck", Default = true,
		Tooltip = "Recolour targets depending on whether you have line of sight.",
		Callback = function(v) S.VisibilityCheck = v end
	})
	main:Slider({
		Name = "Max Distance", Icon = "move", Flag = "esp_maxdist",
		Min = 100, Max = 5000, Default = 2000, Suffix = "m",
		Tooltip = "Anything past this range is not drawn.",
		Callback = function(v) S.MaxDistance = v end
	})
	main:Dropdown({
		Name = "Update Rate", Icon = "activity", Flag = "esp_rate",
		List = { "Every frame", "60 Hz", "30 Hz", "15 Hz" }, Default = "Every frame",
		Tooltip = "Lower rates cost less performance at the price of slight lag on the overlay.",
		Callback = function(v)
			S.RefreshRate = (v == "60 Hz" and 1/60) or (v == "30 Hz" and 1/30)
				or (v == "15 Hz" and 1/15) or 0
		end
	})

	-- ---------- colours ----------
	local col = tab:Section({ Name = "Colours", Icon = "palette", Default = false })

	col:ColorPicker({
		Name = "Enemy", Icon = "target", Flag = "esp_col_enemy",
		Default = S.Colors.Enemy,
		Callback = function(c) S.Colors.Enemy = c end
	})
	col:ColorPicker({
		Name = "Team", Icon = "shield", Flag = "esp_col_team",
		Default = S.Colors.Team,
		Callback = function(c) S.Colors.Team = c end
	})
	col:ColorPicker({
		Name = "Visible", Icon = "eye", Flag = "esp_col_visible",
		Default = S.Colors.Visible,
		Tooltip = "Used when Visibility Colours is on and you have line of sight.",
		Callback = function(c) S.Colors.Visible = c end
	})
	col:ColorPicker({
		Name = "Occluded", Icon = "eyeoff", Flag = "esp_col_occluded",
		Default = S.Colors.Occluded,
		Tooltip = "Used when the target is behind cover.",
		Callback = function(c) S.Colors.Occluded = c end
	})

	-- ---------- box ----------
	local box = tab:Section({ Name = "Box", Icon = "box", Default = false })

	box:Toggle({ Name = "Enabled", Icon = "box", Flag = "esp_box", Default = true,
		Callback = function(v) S.Box.Enabled = v end })
	box:Dropdown({
		Name = "Style", Icon = "layout", Flag = "esp_box_style",
		List = ESP.Supported.Square and { "corner", "full" } or { "corner" },
		Default = "corner",
		Tooltip = "Corner draws only the eight bracket segments. Full draws a complete rectangle.",
		Callback = function(v) S.Box.Style = v end
	})
	box:Slider({ Name = "Thickness", Icon = "sliders", Flag = "esp_box_thick",
		Min = 1, Max = 5, Default = 1,
		Callback = function(v) S.Box.Thickness = v end })
	box:Toggle({ Name = "Outline", Icon = "layers", Flag = "esp_box_outline", Default = true,
		Tooltip = "Adds a dark border so the box stays readable on bright maps.",
		Callback = function(v) S.Box.Outline = v end })
	if ESP.Supported.Square then
		box:Toggle({ Name = "Filled", Icon = "palette", Flag = "esp_box_filled", Default = false,
			Callback = function(v) S.Box.Filled = v end })
		box:Slider({ Name = "Fill Opacity", Icon = "sliders", Flag = "esp_box_alpha",
			Min = 0, Max = 1, Default = 0.18, Rounding = 2,
			Callback = function(v) S.Box.FillAlpha = 1 - v end })
	end

	-- ---------- text ----------
	local txt = tab:Section({ Name = "Text", Icon = "type", Default = false })

	txt:Toggle({ Name = "Name", Icon = "user", Flag = "esp_name", Default = true,
		Callback = function(v) S.Name.Enabled = v end })
	txt:Toggle({ Name = "Use Display Name", Icon = "user", Flag = "esp_name_display", Default = true,
		Tooltip = "Off shows the @username instead.",
		Callback = function(v) S.Name.UseDisplay = v end })
	txt:Toggle({ Name = "Append Health", Icon = "heart", Flag = "esp_name_hp", Default = false,
		Tooltip = "Adds the current health next to the name.",
		Callback = function(v) S.Name.ShowHealth = v end })
	txt:Slider({ Name = "Name Size", Icon = "type", Flag = "esp_name_size",
		Min = 8, Max = 22, Default = 13,
		Callback = function(v) S.Name.Size = v end })

	txt:Divider()

	txt:Toggle({ Name = "Distance", Icon = "move", Flag = "esp_dist", Default = true,
		Callback = function(v) S.Distance.Enabled = v end })
	txt:Slider({ Name = "Distance Size", Icon = "type", Flag = "esp_dist_size",
		Min = 8, Max = 22, Default = 12,
		Callback = function(v) S.Distance.Size = v end })

	-- ---------- health ----------
	local hp = tab:Section({ Name = "Health Bar", Icon = "heart", Default = false })

	hp:Toggle({ Name = "Enabled", Icon = "heart", Flag = "esp_hp", Default = true,
		Callback = function(v) S.Health.Enabled = v end })
	hp:Dropdown({ Name = "Side", Icon = "layout", Flag = "esp_hp_side",
		List = { "left", "right" }, Default = "left",
		Callback = function(v) S.Health.Side = v end })
	hp:Slider({ Name = "Width", Icon = "sliders", Flag = "esp_hp_width",
		Min = 1, Max = 8, Default = 3,
		Callback = function(v) S.Health.Width = v end })
	hp:ColorPicker({ Name = "Full Health", Icon = "heart", Flag = "esp_hp_high",
		Default = S.Health.HighColor,
		Callback = function(c) S.Health.HighColor = c end })
	hp:ColorPicker({ Name = "Low Health", Icon = "alert", Flag = "esp_hp_low",
		Default = S.Health.LowColor,
		Callback = function(c) S.Health.LowColor = c end })

	-- ---------- tracer ----------
	local tr = tab:Section({ Name = "Tracers", Icon = "radar", Default = false })

	tr:Toggle({ Name = "Enabled", Icon = "radar", Flag = "esp_tracer", Default = false,
		Callback = function(v) S.Tracer.Enabled = v end })
	tr:Dropdown({ Name = "Origin", Icon = "compass", Flag = "esp_tracer_origin",
		List = { "bottom", "center", "top", "mouse" }, Default = "bottom",
		Tooltip = "Where each line starts from on your screen.",
		Callback = function(v) S.Tracer.Origin = v end })
	tr:Slider({ Name = "Thickness", Icon = "sliders", Flag = "esp_tracer_thick",
		Min = 1, Max = 5, Default = 1,
		Callback = function(v) S.Tracer.Thickness = v end })
	tr:Toggle({ Name = "Outline", Icon = "layers", Flag = "esp_tracer_outline", Default = true,
		Callback = function(v) S.Tracer.Outline = v end })

	-- ---------- extras ----------
	local ex = tab:Section({ Name = "Extras", Icon = "sparkles", Default = false })

	ex:Toggle({ Name = "Skeleton", Icon = "activity", Flag = "esp_skeleton", Default = false,
		Tooltip = "Draws limb lines. Works with both R6 and R15 rigs.",
		Callback = function(v) S.Skeleton.Enabled = v end })
	ex:ColorPicker({ Name = "Skeleton Colour", Icon = "palette", Flag = "esp_skel_col",
		Default = S.Skeleton.Color,
		Callback = function(c) S.Skeleton.Color = c end })

	ex:Divider()

	if ESP.Supported.Circle then
		ex:Toggle({ Name = "Head Dot", Icon = "target", Flag = "esp_headdot", Default = false,
			Tooltip = "A circle over the head that scales with distance.",
			Callback = function(v) S.HeadDot.Enabled = v end })
		ex:Slider({ Name = "Dot Radius", Icon = "sliders", Flag = "esp_headdot_r",
			Min = 1, Max = 12, Default = 4,
			Callback = function(v) S.HeadDot.Radius = v end })
		ex:Toggle({ Name = "Dot Filled", Icon = "palette", Flag = "esp_headdot_fill", Default = false,
			Callback = function(v) S.HeadDot.Filled = v end })
		ex:Divider()
	end

	if ESP.Supported.Triangle then
		ex:Toggle({ Name = "Off-Screen Arrows", Icon = "compass", Flag = "esp_offscreen", Default = false,
			Tooltip = "Points toward targets that are outside your view.",
			Callback = function(v) S.OffScreen.Enabled = v end })
		ex:Slider({ Name = "Arrow Distance", Icon = "move", Flag = "esp_offscreen_r",
			Min = 60, Max = 400, Default = 180,
			Callback = function(v) S.OffScreen.Radius = v end })
		ex:Slider({ Name = "Arrow Size", Icon = "sliders", Flag = "esp_offscreen_s",
			Min = 6, Max = 30, Default = 13,
			Callback = function(v) S.OffScreen.Size = v end })
	end

	-- ---------- chams ----------
	local ch = tab:Section({ Name = "Chams", Icon = "layers", Default = false })

	ch:Toggle({ Name = "Enabled", Icon = "layers", Flag = "esp_chams", Default = false,
		Tooltip = "Fills the character model with colour, visible through walls.",
		Callback = function(v) S.Chams.Enabled = v end })
	ch:Toggle({ Name = "Always On Top", Icon = "eye", Flag = "esp_chams_top", Default = true,
		Tooltip = "Off means the fill only shows where the model is already visible.",
		Callback = function(v) S.Chams.AlwaysOnTop = v end })
	ch:ColorPicker({ Name = "Fill Colour", Icon = "palette", Flag = "esp_chams_fill",
		Default = S.Chams.FillColor,
		Callback = function(c) S.Chams.FillColor = c end })
	ch:Slider({ Name = "Fill Opacity", Icon = "sliders", Flag = "esp_chams_alpha",
		Min = 0, Max = 1, Default = 0.4, Rounding = 2,
		Callback = function(v) S.Chams.FillTransparency = 1 - v end })
	ch:ColorPicker({ Name = "Outline Colour", Icon = "palette", Flag = "esp_chams_out",
		Default = S.Chams.OutlineColor,
		Callback = function(c) S.Chams.OutlineColor = c end })
	ch:Slider({ Name = "Outline Opacity", Icon = "sliders", Flag = "esp_chams_outa",
		Min = 0, Max = 1, Default = 1, Rounding = 2,
		Callback = function(v) S.Chams.OutlineAlpha = 1 - v end })

	-- ---------- maintenance ----------
	local mt = tab:Section({ Name = "Maintenance", Icon = "wrench", Default = false })

	mt:Button({ Name = "Capability Report", Icon = "terminal",
		Tooltip = "Prints to the console which Drawing types your executor supports.",
		Callback = function() ESP:Diagnose() end })
	mt:Button({ Name = "Rebuild Drawings", Icon = "refresh",
		Tooltip = "Recreates every drawing object. Use if the overlay ever gets stuck.",
		Callback = function() ESP:Refresh() end })
	mt:Button({ Name = "Clear All", Icon = "trash",
		Tooltip = "Removes every drawing and stops the render loop.",
		Callback = function() ESP:Destroy() end })

	return {
		Main = main, Colours = col, Box = box, Text = txt,
		Health = hp, Tracers = tr, Extras = ex, Chams = ch
	}
end

return ESP

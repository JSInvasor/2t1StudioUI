--[[
	2t1 Studio - ESP Module  (v2, performance pass)

	Drawing API based, pooled per player, single render loop.

	What changed in v2
	  - every Drawing write is dirty-checked, so untouched properties
	    never cross into the executor
	  - visibility raycasts run on their own throttle instead of per frame
	  - Highlight properties only get written when they actually change
	  - hidden pools short-circuit instead of re-hiding 60 objects per frame
	  - camera and player state is resolved once per frame, not per target
	  - character part lookups are cached until the model is replaced
	  - optional cap on how many of the nearest players get drawn

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

	-- performance
	RefreshRate      = 0,       -- seconds between full updates, 0 = every frame
	VisRate          = 0.12,    -- seconds between visibility raycasts per target
	MaxTargets       = 0,       -- 0 = unlimited, otherwise only the N nearest

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
		Sides     = 12,
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
local objects     = {}    -- player -> drawing pool
local running     = false
local conn        = nil
local accum       = 0
local sortAccum   = 0
local renderOrder = {}    -- players allowed to draw this cycle when capped

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
			return obj[k]
		end,
		__newindex = function(_, k, v)
			if type(v) == "boolean" then v = v and 1 or 0 end
			obj[k] = v
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

-- ---------- cached drawing handle ----------
-- Every write to a Drawing crosses into the executor. Comparing against the
-- last written value in Lua first is far cheaper, and in normal play most
-- properties do not change between frames.
local Draw = {}
Draw.__index = Draw

function Draw.new(obj)
	return setmetatable({ o = obj, c = {} }, Draw)
end

function Draw:set(k, v)
	local c = self.c
	if c[k] ~= v then
		c[k] = v
		self.o[k] = v
	end
end

function Draw:show(v)
	local c = self.c
	if c.Visible ~= v then
		c.Visible = v
		self.o.Visible = v
	end
end

function Draw:remove()
	pcall(function() self.o:Remove() end)
end

-- ---------- drawing helpers ----------
local function newLine()
	return Draw.new(build("Line", function(l)
		l:show(false); l:set("Thickness", 1; l.Transparency = 1)
		l:set("Color", Color3.new(1, 1, 1))
	end))
end

local function newText()
	return Draw.new(build("Text", function(t)
		t.Visible = false; t.Center = true; t.Outline = true
		t.Size = 13; t.Font = 2; t.Transparency = 1
		t.Color = Color3.new(1, 1, 1)
	end))
end

local function newSquare()
	return Draw.new(build("Square", function(sq)
		sq.Visible = false; sq.Thickness = 1; sq.Filled = false
		sq.Transparency = 1; sq.Color = Color3.new(1, 1, 1)
	end))
end

local function newCircle()
	return Draw.new(build("Circle", function(c)
		c.Visible = false; c.Thickness = 1; c.Filled = false
		c.NumSides = 12; c.Radius = 4; c.Transparency = 1
		c.Color = Color3.new(1, 1, 1)
	end))
end

local function newTriangle()
	return Draw.new(build("Triangle", function(t)
		t.Visible = false; t.Thickness = 2; t.Filled = true
		t.Transparency = 1; t.Color = Color3.new(1, 1, 1)
	end))
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
		hlState    = {},     -- last written Highlight values
		hidden     = false,
		vis        = true,   -- cached line-of-sight result
		visT       = 0,      -- when it was last refreshed
		charCache  = nil,
		partCache  = nil,
	}

	p.boxFill:set("Filled", true)

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
	if p.hidden then return end      -- already down, skip ~60 property writes
	p.hidden = true
	p.boxOutline:show(false)
	p.box:show(false)
	p.boxFill:show(false)
	p.name:show(false)
	p.distance:show(false)
	p.healthBg:show(false)
	p.healthBar:show(false)
	p.tracer:show(false)
	p.tracerOut:show(false)
	p.headDot:show(false)
	p.arrow:show(false)
	for i = 1, 8 do
		p.corners[i]:show(false)
		p.cornerOut[i]:show(false)
	end
	for i = 1, MAX_BONES do
		p.bones[i]:show(false)
	end
	if p.highlight and p.hlState.Enabled ~= false then
		p.hlState.Enabled = false
		p.highlight.Enabled = false
	end
end

local function destroyPool(p)
	if not p then return end
	p.boxOutline:remove(); p.box:remove(); p.boxFill:remove()
	p.name:remove(); p.distance:remove()
	p.healthBg:remove(); p.healthBar:remove()
	p.tracer:remove(); p.tracerOut:remove()
	p.headDot:remove(); p.arrow:remove()
	for i = 1, 8 do p.corners[i]:remove(); p.cornerOut[i]:remove() end
	for i = 1, MAX_BONES do p.bones[i]:remove() end
	if p.highlight then p.highlight:Destroy() end
end

-- ---------- geometry ----------


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

local rayFilter = { nil, nil }

local function checkVisible(camPos, myChar, char, targetPos)
	rayFilter[1] = myChar
	rayFilter[2] = char
	raycastParams.FilterDescendantsInstances = rayFilter
	return Workspace:Raycast(camPos, targetPos - camPos, raycastParams) == nil
end



-- ---------- chams ----------
local function ensureHighlight(p, char)
	if not S.Chams.Enabled then
		if p.highlight and p.hlState.Enabled ~= false then
			p.hlState.Enabled = false
			p.highlight.Enabled = false
		end
		return
	end

	if not p.highlight or p.highlight.Parent ~= char then
		if p.highlight then p.highlight:Destroy() end
		local okHl, hl = pcall(function() return Instance.new("Highlight") end)
		if not okHl or not hl then return end
		hl.Name = "2t1_Chams"
		hl.Adornee = char
		local okP = pcall(function() hl.Parent = char end)
		if not okP then hl.Parent = Workspace end
		p.highlight = hl
		p.hlState = {}
	end

	-- only write what actually changed; Instance writes fire change signals
	local hl, st, c = p.highlight, p.hlState, S.Chams
	if st.Enabled ~= true then st.Enabled = true; hl.Enabled = true end
	if st.FillColor ~= c.FillColor then st.FillColor = c.FillColor; hl.FillColor = c.FillColor end
	if st.FillTransparency ~= c.FillTransparency then
		st.FillTransparency = c.FillTransparency; hl.FillTransparency = c.FillTransparency
	end
	if st.OutlineColor ~= c.OutlineColor then st.OutlineColor = c.OutlineColor; hl.OutlineColor = c.OutlineColor end
	if st.OutlineAlpha ~= c.OutlineAlpha then
		st.OutlineAlpha = c.OutlineAlpha; hl.OutlineTransparency = c.OutlineAlpha
	end
	local depth = c.AlwaysOnTop and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
	if st.Depth ~= depth then st.Depth = depth; hl.DepthMode = depth end
end

-- ---------- corner box ----------
local function drawCornerBox(p, x, y, w, hgt, color, thickness)
	local cut = (w < hgt and w or hgt) * 0.28

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
			o:set("From", seg[1]; o.To = seg[2])
			o:set("Thickness", thickness + 2)
			o:set("Color", Color3.new(0, 0, 0))
			o:set("Transparency", 0.55)
			o:show(true)
		else
			p.cornerOut[i]:show(false)
		end

		local l = p.corners[i]
		l:set("From", seg[1]; l.To = seg[2])
		l:set("Thickness", thickness)
		l:set("Color", color)
		l:show(true)
	end
end

-- ---------- off screen arrow ----------
local function drawArrow(p, worldPos, color, viewW, viewH)
	local sp, onScreen = Camera:WorldToViewportPoint(worldPos)
	if onScreen and sp.Z > 0 then
		p.arrow:show(false)
		return
	end

	local cx, cy = viewW * 0.5, viewH * 0.5
	local dx, dy = sp.X - cx, sp.Y - cy
	if sp.Z <= 0 then dx, dy = -dx, -dy end

	local mag = math.sqrt(dx * dx + dy * dy)
	if mag < 0.001 then p.arrow:show(false); return end
	dx, dy = dx / mag, dy / mag

	local r  = S.OffScreen.Radius
	local sz = S.OffScreen.Size
	local tipX, tipY = cx + dx * r, cy + dy * r
	local px, py = -dy, dx

	p.arrow:set("PointA", Vector2.new(tipX + dx * sz, tipY + dy * sz))
	p.arrow:set("PointB", Vector2.new(tipX - dx * sz * 0.4 + px * sz * 0.62,
	                                  tipY - dy * sz * 0.4 + py * sz * 0.62))
	p.arrow:set("PointC", Vector2.new(tipX - dx * sz * 0.4 - px * sz * 0.62,
	                                  tipY - dy * sz * 0.4 - py * sz * 0.62))
	p.arrow:set("Color", color)
	p.arrow:set("Thickness", S.OffScreen.Thickness)
	p.arrow:show(true)
end

-- ============================================
-- MAIN RENDER
-- ============================================
local function renderPlayer(plr, p, ctx)
	local char = plr.Character
	if not char then hidePool(p); return end

	-- part lookups are cached until the character model is replaced
	if p.charCache ~= char then
		p.charCache = char
		p.partCache = {
			hrp  = char:FindFirstChild("HumanoidRootPart"),
			head = char:FindFirstChild("Head"),
			hum  = char:FindFirstChildOfClass("Humanoid"),
			r15  = char:FindFirstChild("UpperTorso") ~= nil,
		}
	end

	local parts = p.partCache
	local hrp, head, hum = parts.hrp, parts.head, parts.hum
	if not hrp or not hrp.Parent then p.charCache = nil; hidePool(p); return end
	if not head or not hum or hum.Health <= 0 then hidePool(p); return end

	if S.TeamCheck and plr.Team and plr.Team == LocalPlayer.Team then
		hidePool(p); return
	end

	local hrpPos = hrp.Position
	local dist = ctx.myPos and (hrpPos - ctx.myPos).Magnitude or 0
	if dist > S.MaxDistance then hidePool(p); return end

	-- colour, with the raycast on its own throttle
	local color
	if S.VisibilityCheck then
		if ctx.now - p.visT >= S.VisRate then
			p.visT = ctx.now
			p.vis = checkVisible(ctx.camPos, ctx.myChar, char, head.Position)
		end
		color = p.vis and S.Colors.Visible or S.Colors.Occluded
	else
		color = (plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team)
			and S.Colors.Team or S.Colors.Enemy
	end

	ensureHighlight(p, char)

	-- project the body once
	local headCF = head.CFrame
	local topPos = Camera:WorldToViewportPoint((headCF + headCF.UpVector * (head.Size.Y * 0.9)).Position)
	local botPos = Camera:WorldToViewportPoint(hrpPos - Vector3.new(0, 3.3, 0))

	if topPos.Z <= 0 and botPos.Z <= 0 then
		hidePool(p)
		if S.OffScreen.Enabled then
			p.hidden = false
			drawArrow(p, hrpPos, color, ctx.viewW, ctx.viewH)
		end
		return
	end

	local height = topPos.Y - botPos.Y
	if height < 0 then height = -height end
	if height < 4 then hidePool(p); return end
	local width = height * 0.52

	local bx = (topPos.X < botPos.X and topPos.X or botPos.X) - width * 0.5
	local by = (topPos.Y < botPos.Y and topPos.Y or botPos.Y)

	p.hidden = false

	if S.OffScreen.Enabled then
		drawArrow(p, hrpPos, color, ctx.viewW, ctx.viewH)
	else
		p.arrow:show(false)
	end

	-- ----- box -----
	if S.Box.Enabled then
		if S.Box.Style == "corner" then
			p.box:show(false)
			p.boxOutline:show(false)
			drawCornerBox(p, bx, by, width, height, color, S.Box.Thickness)
		else
			for i = 1, 8 do
				p.corners[i]:show(false)
				p.cornerOut[i]:show(false)
			end
			if S.Box.Outline then
				p.boxOutline:set("Position", Vector2.new(bx - 1, by - 1))
				p.boxOutline:set("Size", Vector2.new(width + 2, height + 2))
				p.boxOutline:set("Color", Color3.new(0, 0, 0))
				p.boxOutline:set("Thickness", S.Box.Thickness + 2)
				p.boxOutline:set("Transparency", 0.55)
				p.boxOutline:show(true)
			else
				p.boxOutline:show(false)
			end
			p.box:set("Position", Vector2.new(bx, by))
			p.box:set("Size", Vector2.new(width, height))
			p.box:set("Color", color)
			p.box:set("Thickness", S.Box.Thickness)
			p.box:show(true)
		end

		if S.Box.Filled then
			p.boxFill:set("Position", Vector2.new(bx, by))
			p.boxFill:set("Size", Vector2.new(width, height))
			p.boxFill:set("Color", color)
			p.boxFill:set("Transparency", 1 - S.Box.FillAlpha)
			p.boxFill:show(true)
		else
			p.boxFill:show(false)
		end
	else
		p.box:show(false)
		p.boxOutline:show(false)
		p.boxFill:show(false)
		for i = 1, 8 do
			p.corners[i]:show(false)
			p.cornerOut[i]:show(false)
		end
	end

	-- ----- name -----
	if S.Name.Enabled then
		local label = S.Name.UseDisplay and plr.DisplayName or plr.Name
		if S.Name.ShowHealth then
			label = label .. "   " .. math.floor(hum.Health) .. "hp"
		end
		p.name:set("Text", label)
		p.name:set("Size", S.Name.Size)
		p.name:set("Font", S.Name.Font)
		p.name:set("Outline", S.Name.Outline)
		p.name:set("Color", color)
		p.name:set("Position", Vector2.new(bx + width * 0.5, by - S.Name.Size - 3))
		p.name:show(true)
	else
		p.name:show(false)
	end

	-- ----- distance -----
	if S.Distance.Enabled then
		p.distance:set("Text", math.floor(dist) .. "m")
		p.distance:set("Size", S.Distance.Size)
		p.distance:set("Font", S.Distance.Font)
		p.distance:set("Outline", S.Distance.Outline)
		p.distance:set("Color", color)
		p.distance:set("Position", Vector2.new(bx + width * 0.5, by + height + 2))
		p.distance:show(true)
	else
		p.distance:show(false)
	end

	-- ----- health bar -----
	if S.Health.Enabled and hum.MaxHealth > 0 then
		local pct = hum.Health / hum.MaxHealth
		if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
		local barX = (S.Health.Side == "right")
			and (bx + width + S.Health.Offset)
			or  (bx - S.Health.Offset)

		if S.Health.Outline then
			p.healthBg:set("From", Vector2.new(barX, by - 1))
			p.healthBg:set("To", Vector2.new(barX, by + height + 1))
			p.healthBg:set("Thickness", S.Health.Width + 2)
			p.healthBg:set("Color", Color3.new(0, 0, 0))
			p.healthBg:set("Transparency", 0.6)
			p.healthBg:show(true)
		else
			p.healthBg:show(false)
		end

		p.healthBar:set("From", Vector2.new(barX, by + height * (1 - pct)))
		p.healthBar:set("To", Vector2.new(barX, by + height))
		p.healthBar:set("Thickness", S.Health.Width)
		p.healthBar:set("Color", S.Health.LowColor:Lerp(S.Health.HighColor, pct))
		p.healthBar:show(true)
	else
		p.healthBg:show(false)
		p.healthBar:show(false)
	end

	-- ----- tracer -----
	if S.Tracer.Enabled then
		local to = Vector2.new(bx + width * 0.5, by + height)
		if S.Tracer.Outline then
			p.tracerOut:set("From", from; p.tracerOut.To = to)
			p.tracerOut:set("Thickness", S.Tracer.Thickness + 2)
			p.tracerOut:set("Color", Color3.new(0, 0, 0))
			p.tracerOut:set("Transparency", 0.55)
			p.tracerOut:show(true)
		else
			p.tracerOut:show(false)
		end
		p.tracer:set("From", ctx.tracerFrom)
		p.tracer:set("To", to)
		p.tracer:set("Thickness", S.Tracer.Thickness)
		p.tracer:set("Color", color)
		p.tracer:show(true)
	else
		p.tracer:show(false)
		p.tracerOut:show(false)
	end

	-- ----- head dot -----
	if S.HeadDot.Enabled then
		local hp = Camera:WorldToViewportPoint(head.Position)
		if hp.Z > 0 then
			local scale = 1000 / (dist + 1)
			if scale < 0.35 then scale = 0.35 elseif scale > 2.2 then scale = 2.2 end
			p.headDot:set("Position", Vector2.new(hp.X, hp.Y))
			p.headDot:set("Radius", S.HeadDot.Radius * scale)
			p.headDot:set("NumSides", S.HeadDot.Sides)
			p.headDot:set("Thickness", S.HeadDot.Thickness)
			p.headDot:set("Filled", S.HeadDot.Filled)
			p.headDot:set("Color", color)
			p.headDot:show(true)
		else
			p.headDot:show(false)
		end
	else
		p.headDot:show(false)
	end

	-- ----- skeleton -----
	if S.Skeleton.Enabled then
		local bones = parts.r15 and R15_BONES or R6_BONES
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
					line:set("From", Vector2.new(pa.X, pa.Y))
					line:set("To", Vector2.new(pb.X, pb.Y))
					line:set("Thickness", S.Skeleton.Thickness)
					line:set("Color", S.Skeleton.Color)
					line:show(true)
				else
					line:show(false)
				end
			elseif line then
				line:show(false)
			end
		end
		for i = idx + 1, MAX_BONES do
			p.bones[i]:show(false)
		end
	else
		for i = 1, MAX_BONES do p.bones[i]:show(false) end
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

	local ctx = {}

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

		-- resolve camera and player state once, not once per target
		local camCF = Camera.CFrame
		local vp = Camera.ViewportSize
		ctx.camPos = camCF.Position
		ctx.viewW  = vp.X
		ctx.viewH  = vp.Y
		ctx.now    = os.clock()

		local myChar = LocalPlayer.Character
		ctx.myChar = myChar
		local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
		ctx.myPos = myRoot and myRoot.Position or nil

		if S.Tracer.Enabled then
			local o = S.Tracer.Origin
			if o == "center" then
				ctx.tracerFrom = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
			elseif o == "top" then
				ctx.tracerFrom = Vector2.new(vp.X * 0.5, 0)
			elseif o == "mouse" then
				local m = UIS:GetMouseLocation()
				ctx.tracerFrom = Vector2.new(m.X, m.Y)
			else
				ctx.tracerFrom = Vector2.new(vp.X * 0.5, vp.Y)
			end
		end

		local limit = S.MaxTargets
		if limit and limit > 0 and ctx.myPos then
			-- recompute the nearest-N set a few times a second, not every frame
			sortAccum = sortAccum + dt
			if sortAccum >= 0.2 then
				sortAccum = 0
				local list = {}
				for plr in pairs(objects) do
					local c = plr.Character
					local r = c and c:FindFirstChild("HumanoidRootPart")
					if r then
						list[#list + 1] = { plr = plr, d = (r.Position - ctx.myPos).Magnitude }
					end
				end
				table.sort(list, function(a, b) return a.d < b.d end)
				renderOrder = {}
				for i = 1, math.min(limit, #list) do
					renderOrder[list[i].plr] = true
				end
			end

			for plr, p in pairs(objects) do
				if renderOrder[plr] then
					if not pcall(renderPlayer, plr, p, ctx) then hidePool(p) end
				else
					hidePool(p)
				end
			end
		else
			for plr, p in pairs(objects) do
				if not pcall(renderPlayer, plr, p, ctx) then hidePool(p) end
			end
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
		Tooltip = "Recolour targets based on line of sight. Costs one raycast per target per interval.",
		Callback = function(v) S.VisibilityCheck = v end
	})
	main:Slider({
		Name = "Max Distance", Icon = "move", Flag = "esp_maxdist",
		Min = 100, Max = 5000, Default = 2000, Suffix = "m",
		Tooltip = "Anything past this range is not drawn.",
		Callback = function(v) S.MaxDistance = v end
	})

	-- ---------- performance ----------
	local perf = tab:Section({ Name = "Performance", Icon = "activity", Default = false })

	perf:Paragraph({
		Title = "If your frame rate drops",
		Content = "Work through these in order: lower the Update Rate, raise the Visibility Interval, cap Max Targets, then turn off Skeleton and Chams. Those five account for nearly all of the cost."
	})

	perf:Dropdown({
		Name = "Update Rate", Icon = "activity", Flag = "esp_rate",
		List = { "Every frame", "60 Hz", "30 Hz", "20 Hz", "15 Hz", "10 Hz" },
		Default = "Every frame",
		Tooltip = "How often the whole overlay is recalculated. 30 Hz is hard to tell apart and roughly halves the cost.",
		Callback = function(v)
			S.RefreshRate = (v == "60 Hz" and 1/60) or (v == "30 Hz" and 1/30)
				or (v == "20 Hz" and 1/20) or (v == "15 Hz" and 1/15)
				or (v == "10 Hz" and 1/10) or 0
		end
	})
	perf:Slider({
		Name = "Visibility Interval", Icon = "scan", Flag = "esp_visrate",
		Min = 0, Max = 1, Default = 0.12, Rounding = 2, Suffix = "s",
		Tooltip = "Seconds between line-of-sight raycasts per target. Raycasting is the single most expensive part of ESP.",
		Callback = function(v) S.VisRate = v end
	})
	perf:Slider({
		Name = "Max Targets", Icon = "users", Flag = "esp_maxtargets",
		Min = 0, Max = 40, Default = 0,
		Tooltip = "0 draws everyone. Any other value draws only that many of the nearest players.",
		Callback = function(v) S.MaxTargets = v end
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
		Tooltip = "Draws limb lines for R6 and R15. Fourteen extra projections per target, the heaviest visual here.",
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
		ex:Slider({ Name = "Dot Sides", Icon = "sliders", Flag = "esp_headdot_sides",
			Min = 6, Max = 24, Default = 12,
			Tooltip = "Fewer sides render faster and look almost identical at small sizes.",
			Callback = function(v) S.HeadDot.Sides = v end })
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
		Main = main, Performance = perf, Colours = col, Box = box,
		Text = txt, Health = hp, Tracers = tr, Extras = ex, Chams = ch
	}
end

return ESP

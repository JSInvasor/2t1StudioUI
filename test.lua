--[[
	2t1 Studio - example hub

	Every block below is wrapped so a single failure cannot take the rest
	of the script down. If something breaks you still get every other tab,
	plus a visible note in the affected one and a line in the console.
]]

local BASE = "https://raw.githubusercontent.com/JSInvasor/2t1StudioUI/refs/heads/main/"
local function url(file) return BASE .. file .. "?v=" .. tick() end

-- ============================================================
-- LOAD THE LIBRARY
-- ============================================================
local Library
do
	local ok, res = pcall(function()
		return loadstring(game:HttpGet(url("first5.lua")))()
	end)
	if not ok or type(res) ~= "table" then
		warn("[2t1] Library failed to load: " .. tostring(res))
		return
	end
	Library = res
end

local Window = Library:New({
	Title  = "2t1 Studio",
	Footer = "Projects / Hypershot",
	Grid   = { Spacing = 18, Transparency = 0.55 },
	Tour   = true,
})

-- ============================================================
-- FAILURE ISOLATION
--   safe("label", tab, function() ... end)
--   runs the block, and on error logs it and drops a note in the tab
-- ============================================================
local failures = {}

local function safe(label, tab, fn)
	local ok, err = pcall(fn)
	if ok then return true end

	table.insert(failures, label .. ": " .. tostring(err))
	warn("[2t1] " .. label .. " failed -> " .. tostring(err))

	if tab then
		pcall(function()
			tab:Paragraph({
				Title = label .. " unavailable",
				Content = "This section could not be built. " .. tostring(err),
			})
		end)
	end
	return false
end

-- ============================================================
-- CATEGORIES AND TABS
-- ============================================================
local MainCat   = Window:NewCategory({ Name = "Main",   Icon = "sword",  Default = true })
local CombatTab = MainCat:NewTab("Combat")
local VisualTab = MainCat:NewTab("Visuals")

local PlayerCat = Window:NewCategory({ Name = "Player", Icon = "run",    Default = true })
local MoveTab   = PlayerCat:NewTab("Movement")

local MiscCat    = Window:NewCategory({ Name = "Config", Icon = "layers", Default = false })
local ConfigTab  = MiscCat:NewTab("Configs")
local SettingTab = MiscCat:NewTab("Settings")

-- ============================================================
-- COMBAT
-- ============================================================
safe("Silent Aim", CombatTab, function()
	local aim = CombatTab:Section({
		Name = "Silent Aim",
		Description = "Aim assist configuration",
		Icon = "crosshair",
		Default = true,
	})

	aim:Toggle({
		Name = "Enabled", Icon = "target", Flag = "silent_aim", Default = false,
		Tooltip = "Redirects your shots toward the selected target. May not work in games with server-side validation.",
		Callback = function(v)
			getgenv().SilentAimEnabled = v
			Library:Notify({
				Title = "Silent Aim",
				Content = v and "Silent aim is now active" or "Silent aim disabled",
				Type = v and "success" or "info", Time = 3,
			})
		end,
	})

	aim:Slider({
		Name = "FOV", Icon = "scan", Flag = "aim_fov",
		Min = 10, Max = 500, Default = 250,
		Tooltip = "Radius of the target search circle. Lower is more selective, higher is more aggressive.",
		Callback = function(v) getgenv().SilentFOV = v end,
	})

	aim:Slider({
		Name = "Smoothness", Icon = "activity", Flag = "aim_smooth",
		Min = 0, Max = 1, Default = 0.3, Rounding = 2,
		Tooltip = "0 snaps instantly. 1 is very smooth and looks far more natural.",
		Callback = function(v) getgenv().AimSmooth = v end,
	})

	aim:Dropdown({
		Name = "Target Part", Icon = "skull", Flag = "aim_part",
		List = { "Head", "Torso", "HumanoidRootPart", "Closest" }, Default = "Head",
		Tooltip = "Which body part to aim at.",
		Callback = function(v) getgenv().TargetPart = v end,
	})

	aim:Keybind({
		Name = "Aim Key", Icon = "keyboard", Flag = "aim_key",
		Default = Enum.KeyCode.E,
		Tooltip = "Hold this key to activate aim assist.",
		Callback = function() end,
	})
end)

safe("Target Filters", CombatTab, function()
	local filters = CombatTab:Section({ Name = "Target Filters", Icon = "filter", Default = false })

	filters:Dropdown({
		Name = "Ignore", Icon = "eyeoff", Flag = "aim_ignore", Multi = true,
		List = { "Teammates", "Friends", "Invisible", "Downed", "Behind Wall" },
		Tooltip = "Pick as many as you like. Anyone in a checked group will be skipped.",
		Callback = function(list) print("ignore:", table.concat(list, ", ")) end,
	})

	filters:Divider({ Text = "Advanced" })

	filters:Toggle({ Name = "Wall Check", Icon = "shield", Flag = "wall_check", Default = true,
		Tooltip = "Skip targets that are behind cover." })
	filters:Toggle({ Name = "Prediction", Icon = "compass", Flag = "prediction", Default = false,
		Tooltip = "Lead the shot based on where the target is heading." })
end)

-- ============================================================
-- VISUALS   (ESP module)
-- ============================================================
local ESP

safe("ESP module", VisualTab, function()
	local mod = loadstring(game:HttpGet(url("esp.lua")))()
	if type(mod) ~= "table" then error("esp.lua did not return a table", 0) end
	ESP = mod
end)

if ESP then
	safe("ESP init", VisualTab, function()
		ESP:Init()
	end)

	safe("ESP controls", VisualTab, function()
		ESP:BuildUI(VisualTab)
	end)
end

safe("World", VisualTab, function()
	local world = VisualTab:Section({ Name = "World", Icon = "globe", Default = false })

	world:Toggle({ Name = "Fullbright", Icon = "sun", Flag = "fullbright", Default = false,
		Tooltip = "Lights up dark areas of the map." })
	world:Slider({ Name = "Camera FOV", Icon = "eye", Flag = "cam_fov",
		Min = 70, Max = 120, Default = 70,
		Tooltip = "Field of view. Higher values show more but distort the edges." })
end)

-- ============================================================
-- MOVEMENT
-- ============================================================
safe("Speed", MoveTab, function()
	local move = MoveTab:Section({ Name = "Speed", Icon = "run", Default = true })

	move:Slider({
		Name = "WalkSpeed", Icon = "run", Flag = "walkspeed",
		Min = 16, Max = 300, Default = 16,
		Tooltip = "Default is 16. Very high values are likely to trip anti-cheat.",
		Callback = function(v)
			local c = game.Players.LocalPlayer.Character
			local h = c and c:FindFirstChildOfClass("Humanoid")
			if h then h.WalkSpeed = v end
		end,
	})

	move:Slider({
		Name = "JumpPower", Icon = "arrowupdown", Flag = "jumppower",
		Min = 50, Max = 300, Default = 50,
		Callback = function(v)
			local c = game.Players.LocalPlayer.Character
			local h = c and c:FindFirstChildOfClass("Humanoid")
			if h then h.JumpPower = v end
		end,
	})

	move:Divider()

	move:Toggle({ Name = "Infinite Jump", Icon = "chevronup", Flag = "inf_jump", Default = false })
	move:Toggle({ Name = "NoClip", Icon = "unlock", Flag = "noclip", Default = false,
		Tooltip = "Lets you walk through walls. Detected in some games." })
end)

safe("Teleport", MoveTab, function()
	local tp = MoveTab:Section({ Name = "Teleport", Icon = "compass", Default = false })

	tp:InputButton({
		Name = "Coordinates", Icon = "compass",
		Placeholder = "0, 50, 0", ButtonText = "TP",
		Tooltip = "Enter coordinates as X, Y, Z.",
		Callback = function(txt)
			local x, y, z = txt:match("(-?%d+%.?%d*),%s*(-?%d+%.?%d*),%s*(-?%d+%.?%d*)")
			if x then
				local c = game.Players.LocalPlayer.Character
				if c and c:FindFirstChild("HumanoidRootPart") then
					c.HumanoidRootPart.CFrame = CFrame.new(tonumber(x), tonumber(y), tonumber(z))
					Library:Notify({ Title = "Teleport", Content = "Moved to those coordinates",
						Type = "success", Time = 2 })
				end
			else
				Library:Notify({ Title = "Teleport",
					Content = "Could not read that. Use the format X, Y, Z",
					Type = "error", Time = 3 })
			end
		end,
	})
end)

-- ============================================================
-- CONFIG
-- ============================================================
local configName = ""
local configDropdown

safe("Local Configs", ConfigTab, function()
	local cfg = ConfigTab:Section({ Name = "Local Configs", Icon = "save", Default = true })

	cfg:Textbox({
		Name = "Config Name", Icon = "edit", Placeholder = "my_config",
		Tooltip = "Name of the file your settings will be written to.",
		Callback = function(txt) configName = txt end,
	})

	cfg:Button({
		Name = "Save", Icon = "save",
		Tooltip = "Write every current setting to disk.",
		Callback = function()
			local name = configName ~= "" and configName or "default"
			local ok = Library:SaveConfig(name)
			Library:Notify({
				Title = "Config", Type = ok and "success" or "error",
				Content = ok and ('Saved as "' .. name .. '"') or "Your executor has no file access",
				Time = 3,
			})
			if configDropdown then configDropdown:Refresh(Library:ListConfigs()) end
		end,
	})

	cfg:Button({
		Name = "Load", Icon = "upload",
		Tooltip = "Restore the settings from the selected file.",
		Callback = function()
			local name = configName ~= "" and configName or "default"
			local ok, n = Library:LoadConfig(name)
			Library:Notify({
				Title = "Config", Type = ok and "success" or "error",
				Content = ok and (tostring(n) .. " settings restored") or "That config does not exist",
				Time = 3,
			})
		end,
	})

	configDropdown = cfg:Dropdown({
		Name = "Saved", Icon = "list", List = Library:ListConfigs(),
		Tooltip = "Every config file currently saved on disk.",
		Callback = function(v) configName = v end,
	})

	cfg:Button({
		Name = "Delete Selected", Icon = "trash",
		Callback = function()
			if configName ~= "" then
				Library:DeleteConfig(configName)
				configDropdown:Refresh(Library:ListConfigs())
				Library:Notify({ Title = "Config", Content = "Config deleted",
					Type = "warning", Time = 2 })
			end
		end,
	})
end)

safe("Share", ConfigTab, function()
	local share = ConfigTab:Section({ Name = "Share", Icon = "link", Default = true })

	share:Paragraph({
		Title = "Sharing your setup",
		Content = "Export turns every setting into a single code and copies it to your clipboard. Anyone who pastes that code into Import ends up with the exact same configuration.",
	})

	share:Button({
		Name = "Export to Clipboard", Icon = "copy",
		Tooltip = "Encodes all of your settings into one code and copies it.",
		Callback = function()
			local s = Library:ExportConfig()
			Library:Notify({
				Title = "Export", Type = s and "success" or "error",
				Content = s and ("Copied to clipboard (" .. #s .. " characters)") or "Could not build the code",
				Time = 4,
			})
		end,
	})

	share:InputButton({
		Name = "Import", Icon = "download",
		Placeholder = "paste code here", ButtonText = "Apply",
		Tooltip = "Paste a config code you were given and press Apply.",
		Callback = function(txt)
			local ok, res = Library:ImportConfig(txt)
			Library:Notify({
				Title = "Import", Type = ok and "success" or "error",
				Content = ok and (tostring(res) .. " settings applied")
					or ("Import failed: " .. tostring(res)),
				Time = 4,
			})
		end,
	})
end)

-- ============================================================
-- SETTINGS
-- ============================================================
safe("Setting manager", SettingTab, function()
	Library.SettingManager():AddToTab(SettingTab)
end)

safe("Utilities", SettingTab, function()
	local util = SettingTab:Section({ Name = "Utilities", Icon = "wrench", Default = false })

	util:Button({
		Name = "Rejoin Server", Icon = "refresh",
		Callback = function()
			game:GetService("TeleportService"):Teleport(game.PlaceId, game.Players.LocalPlayer)
		end,
	})

	util:Button({
		Name = "Copy Game Link", Icon = "link",
		Callback = function()
			if setclipboard then
				setclipboard("https://www.roblox.com/games/" .. game.PlaceId)
				Library:Notify({ Title = "Copied", Content = "Game link copied to clipboard",
					Type = "success", Time = 2 })
			end
		end,
	})

	util:Divider({ Text = "Notification Test" })

	util:Button({ Name = "Info", Icon = "info", Callback = function()
		Library:Notify({ Title = "Info", Content = "This is what a neutral message looks like.",
			Type = "info", Time = 4 })
	end })
	util:Button({ Name = "Success", Icon = "check", Callback = function()
		Library:Notify({ Title = "Success", Content = "Everything went through without a problem.",
			Type = "success", Time = 4 })
	end })
	util:Button({ Name = "Warning", Icon = "alert", Callback = function()
		Library:Notify({ Title = "Warning", Content = "Something needs your attention before continuing.",
			Type = "warning", Time = 4 })
	end })
	util:Button({ Name = "Error", Icon = "x", Callback = function()
		Library:Notify({ Title = "Error", Content = "That action could not be completed.",
			Type = "error", Time = 4 })
	end })
end)

-- ============================================================
-- CUSTOM COMMANDS   (these show up inside Ctrl+K)
-- ============================================================
safe("Commands", nil, function()
	Library:RegisterCommand("Kill Velocity", "Drop all momentum on your character", function()
		local c = game.Players.LocalPlayer.Character
		if c and c:FindFirstChild("HumanoidRootPart") then
			c.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
			Library:Notify({ Title = "Velocity", Content = "Momentum cleared",
				Type = "success", Time = 2 })
		end
	end)

	Library:RegisterCommand("Reset Character", "Respawn your character", function()
		local c = game.Players.LocalPlayer.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if h then h.Health = 0 end
	end)
end)

-- ============================================================
-- ICON PACK   (optional)
--   Fill in icons.lua with ids from https://icons.rest and they load here.
--   Anything left blank keeps using the built-in drawn icon.
-- ============================================================
safe("Icon pack", nil, function()
	local Pack = loadstring(game:HttpGet(url("icons.lua")))()
	if type(Pack) ~= "table" then return end
	local _, count = Library:LoadIconPack(Pack)
	if count > 0 then
		Library:Notify({ Title = "Icons", Content = count .. " icons loaded from your pack",
			Type = "success", Time = 3 })
	end
end)

-- ============================================================
-- STARTUP
-- ============================================================
safe("Theme", nil, function()
	Library:SetTheme("Slate", true)
end)

safe("Select tab", nil, function()
	CombatTab:Select()
end)

task.delay(0.6, function()
	pcall(function()
		if Library:LoadConfig("autoload") then
			Library:Notify({ Title = "2t1 Studio", Content = "Your autoload config has been applied",
				Type = "success", Time = 3 })
		end
	end)
end)

if #failures > 0 then
	Library:Notify({
		Title = "Loaded with problems",
		Content = #failures .. " section(s) failed. Check the console for details.",
		Type = "warning", Time = 8,
	})
	warn("[2t1] ---- failure summary ----")
	for i, f in ipairs(failures) do warn("  " .. i .. ". " .. f) end
else
	Library:Notify({
		Title = "2t1 Studio",
		Content = "Ready to go. Right Ctrl opens the menu, Ctrl+K opens the command palette.",
		Type = "success", Time = 6,
	})
end

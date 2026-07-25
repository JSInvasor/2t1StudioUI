-- DcusUI Series
-- by iksuwu
-- Morten UI

-- Updated by JSInvasor
-- White theme + forced custom logo, no category hover bg, grid clipping fix

local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Player = game:GetService("Players").LocalPlayer

local DEFAULT_LOGO = "rbxassetid://122687530154939"

local function getGuiParent()
	local success, result = pcall(function()
		if gethui then return gethui() end
	end)
	if success and result then return result end
	local success2, result2 = pcall(function()
		if syn and syn.protect_gui then
			local gui = Player:WaitForChild("PlayerGui")
			syn.protect_gui(gui)
			return gui
		end
	end)
	if success2 and result2 then return result2 end
	local success3, result3 = pcall(function() return game:GetService("CoreGui") end)
	if success3 and result3 then return result3 end
	return Player:WaitForChild("PlayerGui")
end

local function Create(class, props, children)
	local obj = Instance.new(class)
	for k,v in pairs(props or {}) do obj[k] = v end
	for _,c in pairs(children or {}) do c.Parent = obj end
	return obj
end

local function CreateGridBackground(parent, config)
	config = config or {}
	local gridColor = config.GridColor or Color3.fromRGB(35, 35, 45)
	local lineThickness = config.LineThickness or 1
	local spacing = config.Spacing or 18
	local lineTransparency = config.LineTransparency or 0.5
	local margin = 12 -- corner radius kadar

	for i = 0, math.ceil(400 / spacing) + 1 do
		Create("Frame", {
			Name = "GridHLine",
			Size = UDim2.new(1, -margin*2, 0, lineThickness),
			Position = UDim2.new(0, margin, 0, i * spacing),
			BackgroundColor3 = gridColor, BackgroundTransparency = lineTransparency,
			BorderSizePixel = 0, ZIndex = 1, Parent = parent
		})
	end
	for i = 0, math.ceil(600 / spacing) + 1 do
		Create("Frame", {
			Name = "GridVLine",
			Size = UDim2.new(0, lineThickness, 1, -margin*2),
			Position = UDim2.new(0, i * spacing, 0, margin),
			BackgroundColor3 = gridColor, BackgroundTransparency = lineTransparency,
			BorderSizePixel = 0, ZIndex = 1, Parent = parent
		})
	end
end

-- ============================================
-- LUCIDE ICONS
-- ============================================
local ICONS = {
	Sword = "rbxassetid://10734953822",
	Shield = "rbxassetid://10734950498",
	Eye = "rbxassetid://10747384394",
	Crosshair = "rbxassetid://10709790948",
	Gear = "rbxassetid://10710000090",
	Wrench = "rbxassetid://10709821338",
	Zap = "rbxassetid://10709825498",
	Layers = "rbxassetid://10710110498",
	Home = "rbxassetid://10723407389",
	ArrowUpDown = "rbxassetid://10709768538",
	CornerRight = "rbxassetid://10709812485",
	Puzzle = "rbxassetid://10734944950",
	Box = "rbxassetid://10709780578",
}

local DEFAULT_SECTION_ICON = ICONS.Zap

local DEFAULT_CATEGORY_ICONS = {
	["Main"] = ICONS.Puzzle,
	["Combat"] = ICONS.Puzzle,
	["Player"] = ICONS.Puzzle,
	["Misc"] = ICONS.Puzzle,
	["Settings"] = ICONS.Puzzle,
	["Visuals"] = ICONS.Puzzle,
	["Config"] = ICONS.Puzzle,
}

-- ============================================
-- THEME (white accent everywhere)
-- ============================================
local ACCENT = Color3.fromRGB(255, 255, 255)
local ACCENT_SOFT = Color3.fromRGB(220, 220, 225)
local ACCENT_DIM = Color3.fromRGB(90, 90, 100)

local Library = {}
Library.__index = Library
Library.ToggleKey = Enum.KeyCode.RightControl

function Library.SettingManager()
	local Manager = {}
	function Manager:AddToTab(tab)
		tab:Paragraph({ Title = "UI Settings", Content = "Manage the interface settings and keybindings here." })
		tab:Keybind({ Name = "UI Toggle Key", Default = Library.ToggleKey, OnChange = function(New) Library.ToggleKey = New end })
		tab:Button({ Name = "Unload UI", Callback = function()
			local core = getGuiParent()
			local gui = core:FindFirstChild("DcusHub_v2.3 UI") or Player.PlayerGui:FindFirstChild("DcusHub_v2.3 UI")
			if gui then gui:Destroy() end
		end })
	end
	return Manager
end

function Library:New(config)
	local self = setmetatable({}, Library)

	self.Gui = Create("ScreenGui", {
		Name = "DcusHub_v2.3 UI", ResetOnSpawn = false, Parent = getGuiParent()
	})

	self.Main = Create("Frame", {
		Size = UDim2.fromOffset(550, 380),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(15, 15, 20),
		BorderSizePixel = 0, ClipsDescendants = true,
		Parent = self.Gui
	}, {
		Create("UICorner", {CornerRadius = UDim.new(0, 12)}),
		Create("UIStroke", {Color = Color3.fromRGB(60, 60, 70), Thickness = 1.5})
	})

	local gridConfig = config.Grid or {}
	CreateGridBackground(self.Main, {
		GridColor = gridConfig.Color or Color3.fromRGB(35, 35, 45),
		LineThickness = gridConfig.Thickness or 1,
		Spacing = gridConfig.Spacing or 18,
		LineTransparency = gridConfig.Transparency or 0.5
	})

	-- Top bar
	self.Top = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 55),
		BackgroundColor3 = Color3.fromRGB(20, 20, 28),
		BackgroundTransparency = 0.3,
		ZIndex = 2, Parent = self.Main
	}, {
		Create("UICorner", {CornerRadius = UDim.new(0, 12)}),
		Create("Frame", {
			Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1),
			BackgroundColor3 = Color3.fromRGB(80, 80, 90), BackgroundTransparency = 0.5, BorderSizePixel = 0,
		})
	})

	-- macOS buttons
	local buttonContainer = Create("Frame", {
		Size = UDim2.fromOffset(70, 20), Position = UDim2.new(1, -80, 0, 17),
		BackgroundTransparency = 1, ZIndex = 10, Parent = self.Top
	})

	local closeBtn = Create("TextButton", {
		Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(0, 3),
		BackgroundColor3 = Color3.fromRGB(255, 95, 87), Text = "", ZIndex = 11, Parent = buttonContainer
	}, { Create("UICorner", {CornerRadius = UDim.new(1, 0)}), Create("UIStroke", {Color = Color3.fromRGB(200, 70, 60), Thickness = 1}) })

	local minimizeBtn = Create("TextButton", {
		Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(22, 3),
		BackgroundColor3 = Color3.fromRGB(255, 189, 46), Text = "", ZIndex = 11, Parent = buttonContainer
	}, { Create("UICorner", {CornerRadius = UDim.new(1, 0)}), Create("UIStroke", {Color = Color3.fromRGB(200, 150, 30), Thickness = 1}) })

	local maximizeBtn = Create("TextButton", {
		Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(44, 3),
		BackgroundColor3 = Color3.fromRGB(40, 205, 65), Text = "", ZIndex = 11, Parent = buttonContainer
	}, { Create("UICorner", {CornerRadius = UDim.new(1, 0)}), Create("UIStroke", {Color = Color3.fromRGB(30, 160, 50), Thickness = 1}) })

	closeBtn.MouseButton1Click:Connect(function() self.Gui:Destroy() end)

	local IsMinimized = false
	minimizeBtn.MouseButton1Click:Connect(function()
		IsMinimized = not IsMinimized
		TweenService:Create(self.Main, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Size = IsMinimized and UDim2.fromOffset(550, 55) or UDim2.fromOffset(550, 380)
		}):Play()
		self.Container.Visible = not IsMinimized
	end)

	local IsMaximized = false
	maximizeBtn.MouseButton1Click:Connect(function()
		IsMaximized = not IsMaximized
		TweenService:Create(self.Main, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Size = IsMaximized and UDim2.fromScale(0.9, 0.9) or UDim2.fromOffset(550, 380),
			Position = UDim2.fromScale(0.5, 0.5)
		}):Play()
	end)

	-- Title + Logo (forced to DEFAULT_LOGO)
	local logoImage = DEFAULT_LOGO
	Create("ImageLabel", {
		Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(12, 11),
		BackgroundTransparency = 1, Image = logoImage, ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3, Parent = self.Top
	}, { Create("UICorner", {CornerRadius = UDim.new(0, 6)}) })
	local titleOffset = 52

	Create("TextLabel", {
		Text = config.Title or "Dcus Hub", Font = Enum.Font.GothamBold, TextSize = 18,
		TextColor3 = Color3.fromRGB(255, 255, 255), TextXAlignment = "Left", BackgroundTransparency = 1,
		Position = UDim2.fromOffset(titleOffset, 8), Size = UDim2.new(0, 200, 0, 30), ZIndex = 3, Parent = self.Top
	})

	Create("TextLabel", {
		Text = config.Footer or "Premium Interface • v2.3", Font = Enum.Font.GothamMedium, TextSize = 11,
		TextColor3 = Color3.fromRGB(140, 140, 150), TextXAlignment = "Left", BackgroundTransparency = 1,
		Size = UDim2.new(0, 200, 0, 20), Position = UDim2.fromOffset(titleOffset, 28), ZIndex = 3, Parent = self.Top
	})

	self.Container = Create("Frame", {
		Size = UDim2.new(1, 0, 1, -55), Position = UDim2.fromOffset(0, 55),
		BackgroundTransparency = 1, ClipsDescendants = true, Visible = true, ZIndex = 2, Parent = self.Main
	})

	-- ============================================
	-- SIDEBAR
	-- ============================================
	self.Sidebar = Create("Frame", {
		Size = UDim2.new(0, 150, 1, -16), Position = UDim2.fromOffset(10, 8),
		BackgroundTransparency = 1, ZIndex = 3, Parent = self.Container
	}, {
		Create("UICorner", {CornerRadius = UDim.new(0, 10)}),
		Create("UIStroke", {Color = Color3.fromRGB(55, 55, 65), Thickness = 1, Transparency = 0.5}),
	})

	self.SidebarScroll = Create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
		ScrollBarThickness = 0, CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 5, Parent = self.Sidebar
	})

	self.TabHolder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, ZIndex = 5, Parent = self.SidebarScroll
	}, {
		Create("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}),
		Create("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)})
	})

	local sidebarLayout = self.TabHolder:FindFirstChildOfClass("UIListLayout")
	local function UpdateSidebarCanvas()
		self.SidebarScroll.CanvasSize = UDim2.new(0, 0, 0, sidebarLayout.AbsoluteContentSize.Y + 16)
	end
	sidebarLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateSidebarCanvas)
	task.spawn(UpdateSidebarCanvas)

	self.Pages = Create("Frame", {
		Size = UDim2.new(1, -180, 1, -16), Position = UDim2.fromOffset(170, 8),
		BackgroundTransparency = 1, ZIndex = 3, Parent = self.Container
	})

	self._activeTabBtn = nil
	self._activeTabDot = nil

	-- Dragging
	do
		local dragging, dragStart, startPos
		self.Top.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startPos = self.Main.Position
				input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
			end
		end)
		UIS.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - dragStart
				self.Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			end
		end)
	end

	UIS.InputBegan:Connect(function(input, gpe)
		if not gpe and input.KeyCode == Library.ToggleKey then
			self.Open = not self.Open
			self.Main.Visible = self.Open
		end
	end)

	-- ============================================
	-- Notify
	-- ============================================
	function Library:Notify(config)
		local title = config.Title or "Notification"
		local content = config.Content or ""
		local duration = config.Time or 5
		local NotifGui = getGuiParent():FindFirstChild("DcusNotifications")
		if not NotifGui then
			NotifGui = Create("ScreenGui", {Name = "DcusNotifications", Parent = getGuiParent(), ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
		end
		local Holder = NotifGui:FindFirstChild("NotifHolder")
		if not Holder then
			Holder = Create("Frame", {
				Name = "NotifHolder", Parent = NotifGui,
				Size = UDim2.new(0, 260, 1, -20), Position = UDim2.new(1, -270, 0, 10),
				BackgroundTransparency = 1
			}, { Create("UIListLayout", {VerticalAlignment = "Top", HorizontalAlignment = "Right", Padding = UDim.new(0, 10)}) })
		end

		local Notif = Create("Frame", {
			Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = Color3.fromRGB(20, 20, 28),
			BackgroundTransparency = 1, Parent = Holder
		}, {
			Create("UICorner", {CornerRadius = UDim.new(0, 8)}),
			Create("UIStroke", {Color = ACCENT, Thickness = 1.2, Transparency = 1})
		})
		local TL = Create("TextLabel", {
			Text = title:upper(), Font = Enum.Font.GothamBold, TextSize = 12,
			TextColor3 = ACCENT, BackgroundTransparency = 1, TextTransparency = 1,
			Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 15), TextXAlignment = "Left", Parent = Notif
		})
		local Div = Create("Frame", {
			Size = UDim2.new(1, -24, 0, 1), Position = UDim2.fromOffset(12, 26),
			BackgroundColor3 = Color3.fromRGB(60, 60, 70), BorderSizePixel = 0, BackgroundTransparency = 1, Parent = Notif
		})
		local CL = Create("TextLabel", {
			Text = content, Font = Enum.Font.GothamMedium, TextSize = 12,
			TextColor3 = Color3.fromRGB(180, 180, 200), BackgroundTransparency = 1, TextTransparency = 1,
			Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -24, 0, 0),
			TextXAlignment = "Left", TextYAlignment = "Top", TextWrapped = true, Parent = Notif
		})
		local ts = game:GetService("TextService"):GetTextSize(content, 12, Enum.Font.GothamMedium, Vector2.new(236, 10000))
		local targetSizeY = ts.Y + 45
		Notif.Position = UDim2.new(1, 50, 0, 0)
		TweenService:Create(Notif, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundTransparency = 0, Size = UDim2.new(1, 0, 0, targetSizeY)}):Play()
		TweenService:Create(Notif.UIStroke, TweenInfo.new(0.5), {Transparency = 0.4}):Play()
		TweenService:Create(TL, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
		TweenService:Create(Div, TweenInfo.new(0.5), {BackgroundTransparency = 0}):Play()
		TweenService:Create(CL, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
		task.delay(duration, function()
			TweenService:Create(Notif, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0)}):Play()
			TweenService:Create(Notif.UIStroke, TweenInfo.new(0.5), {Transparency = 1}):Play()
			TweenService:Create(TL, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
			TweenService:Create(Div, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
			TweenService:Create(CL, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
			task.delay(0.6, function() Notif:Destroy() end)
		end)
	end

	-- ============================================
	-- Element Methods (shared between Tab and Section)
	-- ============================================
	local function CreateElementMethods(target, parentFrame, updateCanvasFunc)

		function target:Button(config)
			local text = config.Name or config.Text or "Button"
			local callback = config.Callback or function() end
			local BtnBg = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 45), BackgroundColor3 = Color3.fromRGB(22, 22, 30), ZIndex = 5, Parent = parentFrame
			}, { Create("UICorner", {CornerRadius = UDim.new(0, 8)}), Create("UIStroke", {Color = Color3.fromRGB(55, 55, 65), Thickness = 1}) })
			Create("TextLabel", {
				Text = text, Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = Color3.fromRGB(210, 210, 220),
				BackgroundTransparency = 1, Position = UDim2.fromOffset(15, 0), Size = UDim2.new(1, -100, 1, 0),
				TextXAlignment = "Left", ZIndex = 6, Parent = BtnBg
			})
			local RunBadge = Create("Frame", {
				Size = UDim2.fromOffset(45, 22), Position = UDim2.new(1, -55, 0.5, -11),
				BackgroundColor3 = Color3.fromRGB(45, 45, 55), ZIndex = 6, Parent = BtnBg
			}, { Create("UICorner", {CornerRadius = UDim.new(0, 6)}), Create("UIStroke", {Color = Color3.fromRGB(70, 70, 80), Thickness = 1}) })
			Create("TextLabel", {Text = "Run", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = RunBadge})
			local Hit = Create("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 10, Parent = BtnBg})
			Hit.MouseButton1Down:Connect(function()
				TweenService:Create(BtnBg, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 40, 45)}):Play()
				TweenService:Create(RunBadge, TweenInfo.new(0.2), {BackgroundColor3 = ACCENT}):Play()
			end)
			Hit.MouseButton1Up:Connect(function()
				TweenService:Create(BtnBg, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(22, 22, 30)}):Play()
				TweenService:Create(RunBadge, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(45, 45, 55)}):Play()
				callback()
			end)
		end

		function target:Toggle(config)
			local text = config.Name or "Toggle"
			local callback = config.Callback or function() end
			local state = config.Default or false
			local TglBg = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 45), BackgroundColor3 = Color3.fromRGB(22, 22, 30), ZIndex = 5, Parent = parentFrame
			}, { Create("UICorner", {CornerRadius = UDim.new(0, 8)}), Create("UIStroke", {Color = Color3.fromRGB(55, 55, 65), Thickness = 1}) })
			Create("TextLabel", {
				Text = text, Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = Color3.fromRGB(210, 210, 220),
				BackgroundTransparency = 1, Position = UDim2.fromOffset(15, 0), Size = UDim2.new(1, -70, 1, 0),
				TextXAlignment = "Left", ZIndex = 6, Parent = TglBg
			})
			local Switch = Create("Frame", {
				Size = UDim2.fromOffset(40, 20), Position = UDim2.new(1, -50, 0.5, -10),
				BackgroundColor3 = state and ACCENT or Color3.fromRGB(45, 45, 55), ZIndex = 6, Parent = TglBg
			}, { Create("UICorner", {CornerRadius = UDim.new(1, 0)}), Create("UIStroke", {Color = Color3.fromRGB(70, 70, 80), Thickness = 1}) })
			local Knob = Create("Frame", {
				Size = UDim2.fromOffset(16, 16), Position = state and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2),
				BackgroundColor3 = state and Color3.fromRGB(30, 30, 35) or Color3.fromRGB(255, 255, 255), ZIndex = 7, Parent = Switch
			}, { Create("UICorner", {CornerRadius = UDim.new(1, 0)}) })
			local function updateView(val)
				TweenService:Create(Switch, TweenInfo.new(0.2), {BackgroundColor3 = val and ACCENT or Color3.fromRGB(45, 45, 55)}):Play()
				TweenService:Create(Knob, TweenInfo.new(0.2), {
					Position = val and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2),
					BackgroundColor3 = val and Color3.fromRGB(30, 30, 35) or Color3.fromRGB(255, 255, 255)
				}):Play()
			end
			local Hit = Create("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 10, Parent = TglBg})
			Hit.MouseButton1Click:Connect(function() state = not state; updateView(state); callback(state) end)
			local T = {}; function T:SetValue(val) state = val; updateView(state); callback(state) end; return T
		end

		function target:Slider(config)
			local text = config.Name or "Slider"
			local min, max, default = config.Min or 0, config.Max or 100, config.Default or config.Min or 0
			local rounding = config.Rounding or 0
			local callback = config.Callback or function() end
			local SliderBg = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = Color3.fromRGB(22, 22, 30), ZIndex = 5, Parent = parentFrame
			}, { Create("UICorner", {CornerRadius = UDim.new(0, 8)}), Create("UIStroke", {Color = Color3.fromRGB(55, 55, 65), Thickness = 1}) })
			Create("TextLabel", {
				Text = text, Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = Color3.fromRGB(210, 210, 220),
				BackgroundTransparency = 1, Position = UDim2.fromOffset(15, 8), Size = UDim2.new(1, -100, 0, 20),
				TextXAlignment = "Left", ZIndex = 6, Parent = SliderBg
			})
			local ValueLabel = Create("TextLabel", {
				Text = tostring(default), Font = Enum.Font.GothamBold, TextSize = 13,
				TextColor3 = ACCENT, BackgroundTransparency = 1,
				Position = UDim2.new(1, -65, 0, 8), Size = UDim2.new(0, 50, 0, 20),
				TextXAlignment = "Right", ZIndex = 6, Parent = SliderBg
			})
			local Tray = Create("Frame", {
				Size = UDim2.new(1, -30, 0, 4), Position = UDim2.new(0, 15, 1, -12),
				BackgroundColor3 = Color3.fromRGB(45, 45, 55), ZIndex = 6, Parent = SliderBg
			}, { Create("UICorner", {CornerRadius = UDim.new(1, 0)}) })
			local Fill = Create("Frame", {
				Size = UDim2.fromScale((default - min) / (max - min), 1),
				BackgroundColor3 = ACCENT, ZIndex = 7, Parent = Tray
			}, { Create("UICorner", {CornerRadius = UDim.new(1, 0)}) })
			local SliderKnob = Create("Frame", {
				Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale((default - min) / (max - min), 0.5),
				BackgroundColor3 = Color3.fromRGB(22, 22, 30), ZIndex = 8, Parent = Tray
			}, { Create("UICorner", {CornerRadius = UDim.new(0, 4)}), Create("UIStroke", {Color = ACCENT, Thickness = 1.5}) })
			local function Update(input)
				local pos = math.clamp((input.Position.X - Tray.AbsolutePosition.X) / Tray.AbsoluteSize.X, 0, 1)
				local val = rounding == 1 and (math.floor((min + (max - min) * pos) * 10) / 10) or math.floor(min + (max - min) * pos)
				ValueLabel.Text = tostring(val)
				TweenService:Create(Fill, TweenInfo.new(0.1), {Size = UDim2.fromScale(pos, 1)}):Play()
				TweenService:Create(SliderKnob, TweenInfo.new(0.1), {Position = UDim2.fromScale(pos, 0.5)}):Play()
				callback(val)
			end
			local sd = false
			SliderBg.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then sd = true; Update(i) end end)
			UIS.InputChanged:Connect(function(i) if sd and i.UserInputType == Enum.UserInputType.MouseMovement then Update(i) end end)
			UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then sd = false end end)
		end

		function target:Dropdown(config)
			local text = config.Name or "Dropdown"
			local list = config.List or {}
			local default = config.Default
			local callback = config.Callback or function() end
			local expanded = false
			local DropdownBg = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 45), BackgroundColor3 = Color3.fromRGB(22, 22, 30),
				ClipsDescendants = true, ZIndex = 5, Parent = parentFrame
			}, { Create("UICorner", {CornerRadius = UDim.new(0, 8)}), Create("UIStroke", {Color = Color3.fromRGB(55, 55, 65), Thickness = 1}) })
			local Header = Create("TextButton", {Size = UDim2.new(1, 0, 0, 45), BackgroundTransparency = 1, Text = "", ZIndex = 6, Parent = DropdownBg})
			local TitleLabel = Create("TextLabel", {
				Text = text, Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = Color3.fromRGB(210, 210, 220),
				BackgroundTransparency = 1, Position = UDim2.fromOffset(15, 0), Size = UDim2.new(1, -50, 1, 0),
				TextXAlignment = "Left", ZIndex = 7, Parent = Header
			})
			local Arrow = Create("TextLabel", {
				Text = "▼", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.fromRGB(140, 140, 150),
				BackgroundTransparency = 1, Position = UDim2.new(1, -35, 0, 0), Size = UDim2.new(0, 25, 1, 0), ZIndex = 7, Parent = Header
			})
			local DDContent = Create("Frame", {
				Size = UDim2.new(1, -20, 0, #list * 32), Position = UDim2.fromOffset(10, 45),
				BackgroundTransparency = 1, ZIndex = 6, Parent = DropdownBg
			})
			local DropHL = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = ACCENT,
				BackgroundTransparency = 0.85, Visible = false, ZIndex = 7, Parent = DDContent
			}, { Create("UICorner", {CornerRadius = UDim.new(0, 6)}), Create("UIStroke", {Color = ACCENT, Thickness = 1, Transparency = 0.5}) })
			local OptHolder = Create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 8, Parent = DDContent})
			Create("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = OptHolder})
			local function Select(v, btn)
				DropHL.Visible = true
				local ty = btn.AbsolutePosition.Y - DDContent.AbsolutePosition.Y
				TweenService:Create(DropHL, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {Position = UDim2.fromOffset(0, ty)}):Play()
				for _, o in pairs(OptHolder:GetChildren()) do if o:IsA("TextButton") then TweenService:Create(o, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(160, 160, 170)}):Play() end end
				TweenService:Create(btn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
				TitleLabel.Text = text .. " : " .. v; callback(v)
			end
			for i, v in pairs(list) do
				local Opt = Create("TextButton", {
					Text = v, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Color3.fromRGB(160, 160, 170),
					Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 9, Parent = OptHolder
				})
				Opt.MouseButton1Click:Connect(function() Select(v, Opt) end)
				if default and v == default then task.spawn(function() repeat task.wait() until Opt.AbsolutePosition.Y > 0; Select(v, Opt) end) end
			end
			Header.MouseButton1Click:Connect(function()
				expanded = not expanded
				TweenService:Create(DropdownBg, TweenInfo.new(0.4, Enum.EasingStyle.Quart), {Size = UDim2.new(1, 0, 0, expanded and (45 + #list * 32 + 10) or 45)}):Play()
				TweenService:Create(Arrow, TweenInfo.new(0.4), {Rotation = expanded and 180 or 0}):Play()
			end)
		end

		function target:Label(config)
			local text = config.Text or "Label"
			local LBg = Create("Frame", {
				Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Color3.fromRGB(22, 22, 30),
				BackgroundTransparency = 0.5, ZIndex = 5, Parent = parentFrame
			}, { Create("UICorner", {CornerRadius = UDim.new(0, 8)}), Create("UIStroke", {Color = Color3.fromRGB(55, 55, 65), Thickness = 1, Transparency = 0.5}) })
			local T = Create("TextLabel", {
				Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Color3.fromRGB(190, 190, 200),
				BackgroundTransparency = 1, Position = UDim2.fromOffset(15, 8), Size = UDim2.new(1, -30, 0, 0),
				TextXAlignment = "Left", TextYAlignment = "Center", TextWrapped = true, ZIndex = 6, Parent = LBg
			})
			local function R() local s = game:GetService("TextService"):GetTextSize(T.Text, T.TextSize, T.Font, Vector2.new(T.AbsoluteSize.X, 10000)); LBg.Size = UDim2.new(1, 0, 0, s.Y + 16); T.Size = UDim2.new(1, -30, 0, s.Y) end
			T:GetPropertyChangedSignal("AbsoluteSize"):Connect(R); task.spawn(R)
		end

		function target:Paragraph(config)
			local title = config.Title or "Paragraph"
			local content = config.Content or ""
			local SBg = Create("Frame", {Size = UDim2.new(1, 0, 0, 65), BackgroundColor3 = Color3.fromRGB(22, 22, 30), ZIndex = 5, Parent = parentFrame}, {Create("UICorner", {CornerRadius = UDim.new(0, 8)}), Create("UIStroke", {Color = Color3.fromRGB(55, 55, 65), Thickness = 1})})
			Create("TextLabel", {Text = title:upper(), Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = ACCENT, BackgroundTransparency = 1, Position = UDim2.fromOffset(15, 8), Size = UDim2.new(1, -30, 0, 20), TextXAlignment = "Left", ZIndex = 6, Parent = SBg})
			Create("Frame", {Size = UDim2.new(1, -30, 0, 1), Position = UDim2.fromOffset(15, 30), BackgroundColor3 = Color3.fromRGB(60, 60, 70), BorderSizePixel = 0, ZIndex = 6, Parent = SBg})
			local D = Create("TextLabel", {Text = content, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Color3.fromRGB(160, 160, 170), BackgroundTransparency = 1, Position = UDim2.fromOffset(15, 38), Size = UDim2.new(1, -30, 0, 0), TextXAlignment = "Left", TextYAlignment = "Top", TextWrapped = true, ZIndex = 6, Parent = SBg})
			local function R() local s = game:GetService("TextService"):GetTextSize(D.Text, D.TextSize, D.Font, Vector2.new(D.AbsoluteSize.X, 10000)); SBg.Size = UDim2.new(1, 0, 0, s.Y + 50); D.Size = UDim2.new(1, -30, 0, s.Y) end
			D:GetPropertyChangedSignal("AbsoluteSize"):Connect(R); task.spawn(R)
		end

		function target:Keybind(config)
			local text = config.Name or "Keybind"
			local default = config.Default or Enum.KeyCode.E
			local callback = config.Callback or function() end
			local onChange = config.OnChange or function() end
			local listening = false
			local BBg = Create("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Color3.fromRGB(22, 22, 30), ZIndex = 5, Parent = parentFrame}, {Create("UICorner", {CornerRadius = UDim.new(0, 8)}), Create("UIStroke", {Color = Color3.fromRGB(55, 55, 65), Thickness = 1})})
			Create("TextLabel", {Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Color3.fromRGB(210, 210, 220), BackgroundTransparency = 1, Position = UDim2.fromOffset(15, 0), Size = UDim2.new(1, -85, 1, 0), TextXAlignment = "Left", ZIndex = 6, Parent = BBg})
			local BD = Create("Frame", {Size = UDim2.fromOffset(60, 24), Position = UDim2.new(1, -75, 0.5, -12), BackgroundColor3 = Color3.fromRGB(35, 35, 45), ZIndex = 6, Parent = BBg}, {Create("UICorner", {CornerRadius = UDim.new(0, 6)}), Create("UIStroke", {Color = Color3.fromRGB(70, 70, 80), Thickness = 1})})
			local BT = Create("TextLabel", {Text = default.Name, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = BD})
			local Hit = Create("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 10, Parent = BBg})
			Hit.MouseButton1Click:Connect(function() listening = true; BT.Text = "..."; TweenService:Create(BD:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.2), {Color = ACCENT}):Play() end)
			UIS.InputBegan:Connect(function(input, gpe)
				if gpe then return end
				if listening and input.UserInputType == Enum.UserInputType.Keyboard then
					listening = false; default = input.KeyCode; BT.Text = input.KeyCode.Name
					TweenService:Create(BD:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.2), {Color = Color3.fromRGB(70, 70, 80)}):Play()
					onChange(input.KeyCode)
				elseif not listening and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == default then
					local t = TweenService:Create(BD, TweenInfo.new(0.1), {BackgroundColor3 = ACCENT}); t:Play()
					t.Completed:Connect(function() TweenService:Create(BD, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(35, 35, 45)}):Play() end)
					callback()
				end
			end)
		end

		function target:Textbox(config)
			local text = config.Name or "Textbox"
			local placeholder = config.Placeholder or "Enter..."
			local callback = config.Callback or function() end
			local BxBg = Create("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Color3.fromRGB(22, 22, 30), ZIndex = 5, Parent = parentFrame}, {Create("UICorner", {CornerRadius = UDim.new(0, 8)}), Create("UIStroke", {Color = Color3.fromRGB(55, 55, 65), Thickness = 1})})
			Create("TextLabel", {Text = text, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Color3.fromRGB(210, 210, 220), BackgroundTransparency = 1, Position = UDim2.fromOffset(15, 0), Size = UDim2.new(1, -80, 1, 0), TextXAlignment = "Left", ZIndex = 6, Parent = BxBg})
			local IH = Create("Frame", {Size = UDim2.new(0, 60, 0, 26), Position = UDim2.new(1, -75, 0.5, -13), BackgroundColor3 = Color3.fromRGB(15, 15, 20), ClipsDescendants = true, ZIndex = 6, Parent = BxBg}, {Create("UICorner", {CornerRadius = UDim.new(0, 6)}), Create("UIStroke", {Color = Color3.fromRGB(50, 50, 70), Thickness = 1})})
			local Inp = Create("TextBox", {Text = "", PlaceholderText = placeholder, Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 1, Size = UDim2.new(1, -10, 1, 0), Position = UDim2.fromOffset(5, 0), TextXAlignment = "Center", ZIndex = 7, Parent = IH})
			local Lbl = BxBg:FindFirstChild("TextLabel")
			Inp.Focused:Connect(function()
				TweenService:Create(IH, TweenInfo.new(0.4, Enum.EasingStyle.Quart), {Size = UDim2.new(0, 180, 0, 26), Position = UDim2.new(1, -195, 0.5, -13)}):Play()
				TweenService:Create(IH:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.4), {Color = ACCENT}):Play()
				if Lbl then TweenService:Create(Lbl, TweenInfo.new(0.4), {TextTransparency = 0.5}):Play() end
			end)
			Inp.FocusLost:Connect(function(ep)
				TweenService:Create(IH, TweenInfo.new(0.4, Enum.EasingStyle.Quart), {Size = UDim2.new(0, 60, 0, 26), Position = UDim2.new(1, -75, 0.5, -13)}):Play()
				TweenService:Create(IH:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.4), {Color = Color3.fromRGB(50, 50, 70)}):Play()
				if Lbl then TweenService:Create(Lbl, TweenInfo.new(0.4), {TextTransparency = 0}):Play() end
				callback(Inp.Text, ep)
			end)
		end
	end

	-- ============================================
	-- SelectTab
	-- ============================================
	local function SelectTab(tabBtn, tabDot, page)
		for _, catFrame in pairs(self.TabHolder:GetChildren()) do
			if catFrame:IsA("Frame") then
				local subHolder = catFrame:FindFirstChild("SubTabHolder")
				if subHolder then
					for _, subFrame in pairs(subHolder:GetChildren()) do
						if subFrame:IsA("Frame") then
							local btn = subFrame:FindFirstChildOfClass("TextButton")
							local dot = subFrame:FindFirstChild("Dot")
							if btn then TweenService:Create(btn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(140, 140, 155)}):Play() end
							if dot then TweenService:Create(dot, TweenInfo.new(0.2), {ImageColor3 = Color3.fromRGB(60, 60, 70)}):Play() end
							local hl = subFrame:FindFirstChild("TabHighlightBg")
							if hl then
								TweenService:Create(hl, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
								local s = hl:FindFirstChildOfClass("UIStroke")
								if s then TweenService:Create(s, TweenInfo.new(0.2), {Transparency = 1}):Play() end
							end
						end
					end
				end
			end
		end
		for _, p in pairs(self.Pages:GetChildren()) do if p:IsA("ScrollingFrame") then p.Visible = false end end
		if tabBtn then TweenService:Create(tabBtn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play() end
		if tabDot then TweenService:Create(tabDot, TweenInfo.new(0.2), {ImageColor3 = ACCENT}):Play() end
		local subFrame = tabBtn and tabBtn.Parent
		if subFrame then
			local hl = subFrame:FindFirstChild("TabHighlightBg")
			if hl then
				TweenService:Create(hl, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {BackgroundTransparency = 0.88}):Play()
				local s = hl:FindFirstChildOfClass("UIStroke")
				if s then TweenService:Create(s, TweenInfo.new(0.25), {Transparency = 0.5}):Play() end
			end
		end
		page.Visible = true
		self._activeTabBtn = tabBtn
		self._activeTabDot = tabDot
	end

	-- ============================================
	-- Section builder
	-- ============================================
	local function CreateSection(Page, UpdateCanvasSize, config)
		local sectionName = config.Name or config.Title or "Section"
		local sectionDesc = config.Description or config.Desc or nil
		local icon = config.Icon or DEFAULT_SECTION_ICON
		local defaultOpen = config.Default
		if defaultOpen == nil then defaultOpen = true end
		local sExpanded = defaultOpen
		local Section = {}

		local SC = Create("Frame", {
			Name = "Section_" .. sectionName, Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 5, Parent = Page
		}, { Create("UICorner", {CornerRadius = UDim.new(0, 10)}), Create("UIStroke", {Color = Color3.fromRGB(55, 55, 65), Thickness = 1, Transparency = 0.5}) })

		local HB = Create("TextButton", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Text = "", ZIndex = 7, Parent = SC})

		local IL = Create("ImageLabel", {
			Image = icon, Size = UDim2.fromOffset(16, 16), Position = UDim2.new(0, 14, 0.5, -8),
			BackgroundTransparency = 1, ImageColor3 = Color3.fromRGB(255, 255, 255), ScaleType = Enum.ScaleType.Fit,
			ZIndex = 8, Parent = HB
		})

		local ST = Create("TextLabel", {
			Text = sectionName, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.fromRGB(235, 235, 245),
			BackgroundTransparency = 1, Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -80, 1, 0),
			TextXAlignment = "Left", ZIndex = 8, Parent = HB
		})

		local SA = Create("ImageLabel", {
			Image = ICONS.ArrowUpDown, Size = UDim2.fromOffset(14, 14), Position = UDim2.new(1, -28, 0.5, -7),
			BackgroundTransparency = 1, ImageColor3 = Color3.fromRGB(255, 255, 255), ScaleType = Enum.ScaleType.Fit,
			ZIndex = 8, Rotation = sExpanded and 90 or 0, Parent = HB
		})

		local headerHeight = 40
		if sectionDesc then
			Create("TextLabel", {Text = sectionDesc, Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Color3.fromRGB(120, 120, 130), BackgroundTransparency = 1, Position = UDim2.fromOffset(38, 25), Size = UDim2.new(1, -80, 0, 15), TextXAlignment = "Left", ZIndex = 8, Parent = HB})
			HB.Size = UDim2.new(1, 0, 0, 48); headerHeight = 48
		end

		local HD = Create("Frame", {
			Size = UDim2.new(1, -16, 0, 1), Position = UDim2.fromOffset(8, headerHeight),
			BackgroundColor3 = Color3.fromRGB(55, 55, 65), BackgroundTransparency = sExpanded and 0 or 1,
			BorderSizePixel = 0, ZIndex = 7, Parent = SC
		})

		local CH = Create("Frame", {
			Size = UDim2.new(1, -16, 0, 0), Position = UDim2.fromOffset(8, headerHeight + 4),
			BackgroundTransparency = 1, ZIndex = 6, Parent = SC
		}, {
			Create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}),
			Create("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2)})
		})

		local CL = CH:FindFirstChildOfClass("UIListLayout")
		local function USS()
			local ch = CL.AbsoluteContentSize.Y + 12
			TweenService:Create(SC, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0, sExpanded and (headerHeight + 4 + ch) or headerHeight)}):Play()
			TweenService:Create(HD, TweenInfo.new(0.2), {BackgroundTransparency = sExpanded and 0 or 1}):Play()
			task.delay(0.4, UpdateCanvasSize)
		end

		CL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() if sExpanded then USS() end end)

		HB.MouseButton1Click:Connect(function()
			sExpanded = not sExpanded
			TweenService:Create(SA, TweenInfo.new(0.35, Enum.EasingStyle.Quart), {Rotation = sExpanded and 90 or 0}):Play()
			TweenService:Create(IL, TweenInfo.new(0.2), {ImageColor3 = sExpanded and ACCENT or Color3.fromRGB(120, 120, 130)}):Play()
			TweenService:Create(ST, TweenInfo.new(0.2), {TextColor3 = sExpanded and Color3.fromRGB(235, 235, 245) or Color3.fromRGB(170, 170, 180)}):Play()
			USS()
		end)

		HB.MouseEnter:Connect(function() TweenService:Create(ST, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play() end)
		HB.MouseLeave:Connect(function() TweenService:Create(ST, TweenInfo.new(0.15), {TextColor3 = sExpanded and Color3.fromRGB(235, 235, 245) or Color3.fromRGB(170, 170, 180)}):Play() end)

		CreateElementMethods(Section, CH, UpdateCanvasSize)

		if sExpanded then task.spawn(function() task.wait(0.1); USS() end)
		else SC.Size = UDim2.new(1, 0, 0, headerHeight); IL.ImageColor3 = Color3.fromRGB(120, 120, 130); ST.TextColor3 = Color3.fromRGB(170, 170, 180); SA.Rotation = 0 end

		function Section:SetExpanded(val) sExpanded = val; TweenService:Create(SA, TweenInfo.new(0.35, Enum.EasingStyle.Quart), {Rotation = sExpanded and 90 or 0}):Play(); USS() end
		function Section:IsExpanded() return sExpanded end
		return Section
	end

	-- ============================================
	-- NewCategory
	-- ============================================
	local _categoryOrder = 0

	function self:NewCategory(config)
		local Window = self
		local catName = config.Name or "Category"
		local catIcon = config.Icon or DEFAULT_CATEGORY_ICONS[catName] or DEFAULT_SECTION_ICON
		local defaultOpen = config.Default
		if defaultOpen == nil then defaultOpen = true end
		_categoryOrder = _categoryOrder + 1
		local catExpanded = defaultOpen
		local Category = {}

		local CC = Create("Frame", {
			Name = "Cat_" .. catName, Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1,
			ClipsDescendants = true, LayoutOrder = _categoryOrder, ZIndex = 5, Parent = self.TabHolder
		})

		local CH = Create("TextButton", {
			Name = "CatHeader", Size = UDim2.new(1, 0, 0, 34),
			BackgroundTransparency = 1,
			Text = "", ZIndex = 7, Parent = CC
		}, { Create("UICorner", {CornerRadius = UDim.new(0, 8)}) })

		local CI = Create("ImageLabel", {
			Image = catIcon, Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(10, 10),
			BackgroundTransparency = 1, ImageColor3 = ACCENT,
			ScaleType = Enum.ScaleType.Fit, ZIndex = 8, Parent = CH
		})

		local CT = Create("TextLabel", {
			Text = catName, Font = Enum.Font.GothamBold, TextSize = 12,
			TextColor3 = Color3.fromRGB(225, 225, 235), BackgroundTransparency = 1,
			Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -52, 1, 0),
			TextXAlignment = "Center", ZIndex = 8, Parent = CH
		})

		local CAI = Create("ImageLabel", {
			Image = ICONS.ArrowUpDown, Size = UDim2.fromOffset(12, 12),
			Position = UDim2.new(1, -22, 0.5, -6), BackgroundTransparency = 1,
			ImageColor3 = Color3.fromRGB(190, 190, 200), ScaleType = Enum.ScaleType.Fit,
			ZIndex = 8, Rotation = catExpanded and 90 or 0, Parent = CH
		})

		local STH = Create("Frame", {
			Name = "SubTabHolder", Size = UDim2.new(1, 0, 0, 0), Position = UDim2.fromOffset(0, 36),
			BackgroundTransparency = 1, ZIndex = 5, Parent = CC
		}, {
			Create("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}),
			Create("UIPadding", {PaddingLeft = UDim.new(0, 6)})
		})

		local subLayout = STH:FindFirstChildOfClass("UIListLayout")
		local subTabOrder = 0

		local function UpdateCatSize()
			local ch = subLayout.AbsoluteContentSize.Y
			TweenService:Create(CC, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Size = UDim2.new(1, 0, 0, catExpanded and (36 + ch + 4) or 34)
			}):Play()
		end

		subLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() if catExpanded then UpdateCatSize() end end)

		CH.MouseButton1Click:Connect(function()
			catExpanded = not catExpanded
			TweenService:Create(CAI, TweenInfo.new(0.35, Enum.EasingStyle.Quart), {Rotation = catExpanded and 90 or 0}):Play()
			TweenService:Create(CT, TweenInfo.new(0.2), {TextColor3 = catExpanded and Color3.fromRGB(225, 225, 235) or Color3.fromRGB(150, 150, 165)}):Play()
			TweenService:Create(CI, TweenInfo.new(0.2), {ImageColor3 = catExpanded and ACCENT or Color3.fromRGB(100, 100, 110)}):Play()
			UpdateCatSize()
		end)

		CH.MouseEnter:Connect(function() TweenService:Create(CT, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play() end)
		CH.MouseLeave:Connect(function() TweenService:Create(CT, TweenInfo.new(0.15), {TextColor3 = catExpanded and Color3.fromRGB(225, 225, 235) or Color3.fromRGB(150, 150, 165)}):Play() end)

		function Category:NewTab(name)
			local Tab = {}
			subTabOrder = subTabOrder + 1

			local STF = Create("Frame", {
				Name = "SubTab_" .. name, Size = UDim2.new(1, -6, 0, 28),
				BackgroundTransparency = 1, LayoutOrder = subTabOrder, ZIndex = 6, Parent = STH
			})

			Create("Frame", {
				Name = "TabHighlightBg", Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = ACCENT, BackgroundTransparency = 1, ZIndex = 6, Parent = STF
			}, { Create("UICorner", {CornerRadius = UDim.new(0, 7)}), Create("UIStroke", {Color = ACCENT, Thickness = 1, Transparency = 1}) })

			local Dot = Create("ImageLabel", {
				Name = "Dot", Image = ICONS.CornerRight, Size = UDim2.fromOffset(12, 12),
				Position = UDim2.fromOffset(4, 8), BackgroundTransparency = 1,
				ImageColor3 = Color3.fromRGB(60, 60, 70), ScaleType = Enum.ScaleType.Fit, ZIndex = 8, Parent = STF
			})

			local TB = Create("TextButton", {
				Text = name, Font = Enum.Font.GothamMedium, TextSize = 12,
				TextColor3 = Color3.fromRGB(140, 140, 155), BackgroundTransparency = 1,
				Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -20, 1, 0),
				TextXAlignment = "Left", ZIndex = 9, Parent = STF
			})

			local Page = Create("ScrollingFrame", {
				Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false,
				ScrollBarThickness = 2, ScrollBarImageColor3 = ACCENT,
				CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 4, Parent = Window.Pages
			}, {
				Create("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}),
				Create("UIPadding", {PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 8)})
			})

			local PL = Page:FindFirstChildOfClass("UIListLayout")
			local function UCS() Page.CanvasSize = UDim2.new(0, 0, 0, PL.AbsoluteContentSize.Y + 15) end
			PL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UCS); task.spawn(UCS)

			TB.MouseButton1Click:Connect(function() SelectTab(TB, Dot, Page) end)
			TB.MouseEnter:Connect(function()
				if Window._activeTabBtn ~= TB then
					TweenService:Create(TB, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(210, 210, 220)}):Play()
					TweenService:Create(Dot, TweenInfo.new(0.15), {ImageColor3 = Color3.fromRGB(120, 120, 130)}):Play()
				end
			end)
			TB.MouseLeave:Connect(function()
				if Window._activeTabBtn ~= TB then
					TweenService:Create(TB, TweenInfo.new(0.15), {TextColor3 = Color3.fromRGB(140, 140, 155)}):Play()
					TweenService:Create(Dot, TweenInfo.new(0.15), {ImageColor3 = Color3.fromRGB(60, 60, 70)}):Play()
				end
			end)

			CreateElementMethods(Tab, Page, UCS)
			function Tab:Section(cfg) return CreateSection(Page, UCS, cfg) end

			task.spawn(function() task.wait(0.05); UpdateCatSize() end)
			return Tab
		end

		if catExpanded then task.spawn(function() task.wait(0.1); UpdateCatSize() end)
		else CC.Size = UDim2.new(1, 0, 0, 34); CAI.Rotation = 0; CT.TextColor3 = Color3.fromRGB(150, 150, 165); CI.ImageColor3 = Color3.fromRGB(100, 100, 110) end

		function Category:SetExpanded(val) catExpanded = val; TweenService:Create(CAI, TweenInfo.new(0.35, Enum.EasingStyle.Quart), {Rotation = catExpanded and 90 or 0}):Play(); UpdateCatSize() end
		function Category:IsExpanded() return catExpanded end
		return Category
	end

	-- ============================================
	-- NewTab (backward compatible)
	-- ============================================
	function self:NewTab(name)
		local Tab = {}
		_categoryOrder = _categoryOrder + 1
		local TabBg = Create("Frame", {
			Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Color3.fromRGB(30, 30, 38),
			LayoutOrder = _categoryOrder, ZIndex = 6, Parent = self.TabHolder
		}, { Create("UICorner", {CornerRadius = UDim.new(0, 8)}), Create("UIStroke", {Color = Color3.fromRGB(55, 55, 65), Thickness = 1}) })
		local Dot = Create("Frame", {
			Name = "Dot", Size = UDim2.fromOffset(4, 4), Position = UDim2.new(0, 10, 0.5, -2),
			BackgroundColor3 = Color3.fromRGB(160, 160, 170), ZIndex = 7, Parent = TabBg
		}, { Create("UICorner", {CornerRadius = UDim.new(1, 0)}) })
		local TabBtn = Create("TextButton", {
			Text = name, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Color3.fromRGB(160, 160, 170),
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 8, Parent = TabBg
		})
		local Page = Create("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false,
			ScrollBarThickness = 2, ScrollBarImageColor3 = ACCENT,
			CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 4, Parent = self.Pages
		}, {
			Create("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}),
			Create("UIPadding", {PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 8)})
		})
		local PL = Page:FindFirstChildOfClass("UIListLayout")
		local function UCS() Page.CanvasSize = UDim2.new(0, 0, 0, PL.AbsoluteContentSize.Y + 15) end
		PL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UCS); task.spawn(UCS)
		TabBtn.MouseButton1Click:Connect(function()
			for _, p in pairs(self.Pages:GetChildren()) do if p:IsA("ScrollingFrame") then p.Visible = false end end
			for _, bg in pairs(self.TabHolder:GetChildren()) do
				if bg:IsA("Frame") and bg:FindFirstChild("Frame") then
					local b = bg:FindFirstChildOfClass("TextButton"); local d = bg:FindFirstChild("Frame")
					if b then TweenService:Create(b, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(160, 160, 170)}):Play() end
					if d then TweenService:Create(d, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(160, 160, 170)}):Play() end
				end
			end
			Page.Visible = true
			TweenService:Create(TabBtn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
			TweenService:Create(Dot, TweenInfo.new(0.2), {ImageColor3 = ACCENT}):Play()
		end)
		CreateElementMethods(Tab, Page, UCS)
		function Tab:Section(cfg) return CreateSection(Page, UCS, cfg) end
		return Tab
	end

	return self
end

return Library

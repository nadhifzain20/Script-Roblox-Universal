--// MAMET UTILITY PRO (TABBED EDITION - V7.17.4 - SUPER OPTIMIZED + SMART ESP + SMART INSPECTOR)
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local StatsService = game:GetService("Stats")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalizationService = game:GetService("LocalizationService")

-- Fallback for VirtualUser (sometimes restricted)
local VirtualUser
pcall(function() VirtualUser = game:GetService("VirtualUser") end)
if not VirtualUser then
    VirtualUser = { Button2Down = function() end, Button2Up = function() end }
end

-- Safe Wait & Delay Functions (menggantikan task/wait/delay yang nil)
local function SafeWait(t)
    t = t or 0
    local start = os.clock()
    while os.clock() - start < t do
        RunService.Heartbeat:Wait()
    end
end

local function SafeDelay(t, func)
    coroutine.wrap(function()
        if t > 0 then SafeWait(t) end
        func()
    end)()
end

local LP = Players.LocalPlayer
local Waypoints = {}
local Connections = {} 

-- Global Locks & State
local ActiveSlider = nil 
local ActiveScroll = nil
local StatsConnection
local DescendantConnection
local SpeedConnection
local JumpConnection

-- Saving original lighting states safely
local OriginalFB = {Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, GlobalShadows = Lighting.GlobalShadows}
pcall(function() OriginalFB.ExposureCompensation = Lighting.ExposureCompensation end)
local OriginalFog = {FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart}

local WalkSpeed = 16
local JumpPower = 50
local FlySpeed = 50
local CurrentFOV = 70
local CurrentKeybind = Enum.KeyCode.RightControl
local Binding = false
local ToggleStates = {
    InfJump = false, Noclip = false, Fly = false,
    InstantPrompt = false, MaxZoom = false, AntiAFK = false, PotatoMode = false, ESP = false,
    SmartInspector = false, Fullbright = false, Nofog = false, PartESP = false, GotoPart = false
}

-- Config Folder Setup
local ConfigFolder = "MametConfigs"
pcall(function()
    if makefolder and (not isfolder or not isfolder(ConfigFolder)) then 
        makefolder(ConfigFolder) 
    end
end)

-- Cleanup Previous Instances
if game.CoreGui:FindFirstChild("MametUtility") then game.CoreGui.MametUtility:Destroy() end
if Lighting:FindFirstChild("MametUIBlur") then Lighting.MametUIBlur:Destroy() end

------------------------------------------------
-- ANTI-DETECTION SYSTEM
------------------------------------------------
local AntiDetectActive = false
pcall(function()
    local MirrorMT = getrawmetatable(game)
    local OldIndex = MirrorMT.__index
    local OldNewIndex = MirrorMT.__newindex
    setreadonly(MirrorMT, false)

    MirrorMT.__index = newcclosure(function(self, idx)
        if not checkcaller() and self:IsA("Humanoid") then
            if idx == "WalkSpeed" then return 16 end
            if idx == "JumpPower" then return 50 end
        end
        return OldIndex(self, idx)
    end)

    MirrorMT.__newindex = newcclosure(function(self, idx, val)
        if not checkcaller() and self:IsA("Humanoid") then
            if idx == "WalkSpeed" or idx == "JumpPower" then return end
        end
        OldNewIndex(self, idx, val)
    end)

    setreadonly(MirrorMT, true)
    AntiDetectActive = true
end)

------------------------------------------------
-- THEME & LANGUAGE SYSTEM
------------------------------------------------
local Themes = {
    Light = { Background = Color3.fromHex("#9B5DE5"), BackgroundTop = Color3.fromHex("#7B45B7"), BackgroundTab = Color3.fromHex("#8948D4"), ButtonDefault = Color3.fromHex("#00BBF9"), ButtonOn = Color3.fromHex("#F15BB5"), ButtonOff = Color3.fromHex("#00BBF9"), Text = Color3.fromHex("#FEE440") },
    Dark = { Background = Color3.fromHex("#18181B"), BackgroundTop = Color3.fromHex("#09090B"), BackgroundTab = Color3.fromHex("#27272A"), ButtonDefault = Color3.fromHex("#3F3F46"), ButtonOn = Color3.fromHex("#3730A3"), ButtonOff = Color3.fromHex("#3F3F46"), Text = Color3.fromHex("#38BDF8") }
}

local Theme = Themes.Dark
local IsDarkMode = true
local CurrentLanguage = "ID"
local DynamicLabels = {}

local function RegisterDynamicLang(obj, textID, textEN) table.insert(DynamicLabels, {Obj = obj, ID = textID, EN = textEN}); obj.Text = CurrentLanguage == "ID" and textID or textEN end
local UIBlur = Instance.new("BlurEffect", Lighting); UIBlur.Name = "MametUIBlur"; UIBlur.Size = 0 
local Gui = Instance.new("ScreenGui", game.CoreGui); Gui.Name = "MametUtility"

local function Humanoid() local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function HRP() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function Corner(obj, r) local c = Instance.new("UICorner", obj); c.CornerRadius = UDim.new(0, r or 10) end

local function CustomDrag(hitPart, targetGui)
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
    local conn1 = hitPart.InputBegan:Connect(function(input)
        if ActiveSlider or ActiveScroll then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; dragStart = input.Position; startPos = targetGui.Position; input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end) end
    end)
    local conn2 = hitPart.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end end)
    local conn3 = UIS.InputChanged:Connect(function(input)
        if input == dragInput and dragging and not ActiveSlider and not ActiveScroll then
            local delta = input.Position - dragStart; targetGui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    table.insert(Connections, conn1); table.insert(Connections, conn2); table.insert(Connections, conn3)
end

-- Notification System
local ActiveNotifications = {}
local function Notify(title, message, duration)
    duration = duration or 5
    for _, notif in ipairs(ActiveNotifications) do
        if notif and notif.Parent then TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(1, -220, 1, notif.Position.Y.Offset - 65)}):Play() end
    end
    local Notif = Instance.new("Frame", Gui); Notif.Size = UDim2.new(0, 200, 0, 60); Notif.Position = UDim2.new(1, 20, 1, -80); Notif.BackgroundColor3 = Theme.BackgroundTop; Notif.BorderSizePixel = 0; Corner(Notif, 8)
    local TxtTitle = Instance.new("TextLabel", Notif); TxtTitle.Size = UDim2.new(1, -10, 0, 20); TxtTitle.Position = UDim2.new(0, 10, 0, 5); TxtTitle.Text = title; TxtTitle.TextColor3 = Theme.Text; TxtTitle.Font = Enum.Font.GothamBold; TxtTitle.TextSize = 12; TxtTitle.BackgroundTransparency = 1; TxtTitle.TextXAlignment = Enum.TextXAlignment.Left
    local TxtMsg = Instance.new("TextLabel", Notif); TxtMsg.Size = UDim2.new(1, -10, 0, 30); TxtMsg.Position = UDim2.new(0, 10, 0, 22); TxtMsg.Text = message; TxtMsg.TextColor3 = Color3.new(1,1,1); TxtMsg.Font = Enum.Font.Gotham; TxtMsg.TextSize = 10; TxtMsg.BackgroundTransparency = 1; TxtMsg.TextXAlignment = Enum.TextXAlignment.Left; TxtMsg.TextWrapped = true
    table.insert(ActiveNotifications, Notif)
    TweenService:Create(Notif, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(1, -220, 1, -80)}):Play()
    SafeDelay(duration, function()
        local out = TweenService:Create(Notif, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(1, 20, 1, Notif.Position.Y.Offset)})
        out:Play(); out.Completed:Wait()
        for i, v in ipairs(ActiveNotifications) do if v == Notif then table.remove(ActiveNotifications, i) break end end
        Notif:Destroy()
    end)
end

-- Tooltip System
local TooltipUI = Instance.new("Frame", Gui); TooltipUI.BackgroundColor3 = Theme.BackgroundTop; TooltipUI.Size = UDim2.new(0, 200, 0, 30); TooltipUI.Visible = false; TooltipUI.ZIndex = 100; Corner(TooltipUI, 6)
local TooltipText = Instance.new("TextLabel", TooltipUI); TooltipText.Size = UDim2.new(1, -10, 1, -10); TooltipText.Position = UDim2.new(0, 5, 0, 5); TooltipText.BackgroundTransparency = 1; TooltipText.TextColor3 = Theme.Text; TooltipText.Font = Enum.Font.GothamBold; TooltipText.TextSize = 11; TooltipText.TextWrapped = true; TooltipText.TextXAlignment = Enum.TextXAlignment.Center

local lastTooltipUpdate = 0
UIS.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and TooltipUI.Visible then
        local now = os.clock()
        if now - lastTooltipUpdate > 0.05 then
            lastTooltipUpdate = now
            local targetX = input.Position.X + 15; local targetY = input.Position.Y + 15
            local cam = workspace.CurrentCamera
            if cam and cam.ViewportSize then
                targetX = math.clamp(targetX, 0, cam.ViewportSize.X - TooltipUI.AbsoluteSize.X - 10)
                targetY = math.clamp(targetY, 0, cam.ViewportSize.Y - TooltipUI.AbsoluteSize.Y - 10)
            end
            TooltipUI.Position = UDim2.new(0, targetX, 0, targetY)
        end
    end
end)

------------------------------------------------
-- MAIN UI & HEADER BUTTONS
------------------------------------------------
local Open = Instance.new("TextButton", Gui); Open.Size = UDim2.new(0, 26, 0, 26); Open.Position = UDim2.new(0, 15, 0.5, -13); Open.BackgroundTransparency = 1; Open.Text = "❤️"; Open.TextColor3 = Theme.Text; Open.TextSize = 20; Open.Selectable = false; CustomDrag(Open, Open)

local Frame = Instance.new("Frame", Gui); Frame.AnchorPoint = Vector2.new(0.5, 0.5); Frame.Position = UDim2.new(0.5, 0, 0.5, -50); Frame.Size = UDim2.new(0, 360, 0, 0); Frame.BackgroundColor3 = Theme.Background; Frame.Visible = false; Frame.ClipsDescendants = true; Corner(Frame, 12)
local Top = Instance.new("TextButton", Frame); Top.Text = ""; Top.AutoButtonColor = false; Top.Selectable = false; Top.Size = UDim2.new(1, 0, 0, 36); Top.BackgroundColor3 = Theme.BackgroundTop; CustomDrag(Top, Frame); Corner(Top, 12)
local TopBlocker = Instance.new("Frame", Top); TopBlocker.Size = UDim2.new(1, 0, 0, 10); TopBlocker.Position = UDim2.new(0, 0, 1, -10); TopBlocker.BackgroundColor3 = Theme.BackgroundTop; TopBlocker.BorderSizePixel = 0

local HeaderText = Instance.new("TextLabel", Top); HeaderText.Size = UDim2.new(1, -110, 1, 0); HeaderText.Position = UDim2.new(0, 10, 0, 0); HeaderText.BackgroundTransparency = 1; HeaderText.TextColor3 = Theme.Text; HeaderText.Font = Enum.Font.GothamBold; HeaderText.TextSize = 10; HeaderText.TextXAlignment = Enum.TextXAlignment.Left; HeaderText.RichText = true

local fps, startTime, frames, lastPingHex, lastPingValue = 0, os.clock(), 0, "#2ECC71", 0
StatsConnection = RunService.RenderStepped:Connect(function()
    frames = frames + 1; local now = os.clock()
    if now - startTime >= 1 then 
        fps = frames; frames = 0; startTime = now 
        pcall(function() lastPingValue = tonumber(StatsService.Network.ServerStatsItem["Data Ping"]:GetValueString():match("%d+")) or 0 end)
        lastPingHex = (lastPingValue >= 250) and "#E74C3C" or ((lastPingValue >= 150) and "#E67E22" or ((lastPingValue >= 80) and "#F1C40F" or "#2ECC71"))
    end
    HeaderText.Text = "MAMET PRO │ " .. os.date("%H:%M") .. " │ " .. fps .. " FPS │ <font color='" .. lastPingHex .. "'>" .. lastPingValue .. " ms</font>"
end)

-- Tab Panel Setup
local TabPanel = Instance.new("Frame", Frame); TabPanel.Size = UDim2.new(0, 100, 1, -36); TabPanel.Position = UDim2.new(0, 0, 0, 36); TabPanel.BackgroundColor3 = Theme.BackgroundTab; TabPanel.BorderSizePixel = 0; Corner(TabPanel, 12)
local TabPanelTopFixer = Instance.new("Frame", TabPanel); TabPanelTopFixer.Size = UDim2.new(1, 0, 0, 12); TabPanelTopFixer.BackgroundColor3 = Theme.BackgroundTab; TabPanelTopFixer.BorderSizePixel = 0
local TabListLayout = Instance.new("UIListLayout", TabPanel); TabListLayout.SortOrder = Enum.SortOrder.LayoutOrder; TabListLayout.Padding = UDim.new(0, 5); TabListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
local PageContainer = Instance.new("Frame", Frame); PageContainer.Size = UDim2.new(1, -100, 1, -36); PageContainer.Position = UDim2.new(0, 100, 0, 36); PageContainer.BackgroundTransparency = 1

local Tabs, CurrentTab = {}, nil
local function CreateTab(name, icon, layoutOrder)
    local TabBtn = Instance.new("TextButton", TabPanel); TabBtn.Size = UDim2.new(0, 90, 0, 28); TabBtn.BackgroundColor3 = Theme.BackgroundTop; TabBtn.Text = icon .. " │ " .. name; TabBtn.AutoButtonColor = false; TabBtn.Selectable = false; TabBtn.TextColor3 = Color3.new(1,1,1); TabBtn.Font = Enum.Font.GothamBold; TabBtn.TextSize = 10; TabBtn.LayoutOrder = layoutOrder; TabBtn.TextXAlignment = Enum.TextXAlignment.Left; Corner(TabBtn, 6)
    local UIPad = Instance.new("UIPadding", TabBtn); UIPad.PaddingLeft = UDim.new(0, 8)
    local Indicator = Instance.new("Frame", TabBtn); Indicator.Size = UDim2.new(0, 3, 0, 0); Indicator.Position = UDim2.new(0, -8, 0.5, 0); Indicator.AnchorPoint = Vector2.new(0, 0.5); Indicator.BackgroundColor3 = Theme.Text; Indicator.BorderSizePixel = 0; Corner(Indicator, 2)
    local PageWrapper = Instance.new("Frame", PageContainer); PageWrapper.Size = UDim2.new(1, 0, 1, 0); PageWrapper.BackgroundTransparency = 1; PageWrapper.Visible = false
    local Page = Instance.new("ScrollingFrame", PageWrapper); Page.Size = UDim2.new(1, 0, 1, 0); Page.BackgroundTransparency = 1; Page.BorderSizePixel = 0; Page.ScrollBarThickness = 3; Page.ScrollBarImageColor3 = Theme.ButtonDefault
    local UIList = Instance.new("UIListLayout", Page); UIList.SortOrder = Enum.SortOrder.LayoutOrder; UIList.Padding = UDim.new(0, 8); UIList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    local PageSpacer = Instance.new("Frame", Page); PageSpacer.Size = UDim2.new(1, 0, 0, 2); PageSpacer.BackgroundTransparency = 1; PageSpacer.LayoutOrder = 0
    UIList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() Page.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y + 15) end)

    TabBtn.Activated:Connect(function()
        if CurrentTab == name then return end
        for _, v in pairs(Tabs) do v.Wrapper.Visible = false; v.Btn.BackgroundColor3 = Theme.BackgroundTop; v.Btn.TextColor3 = Color3.new(1,1,1); TweenService:Create(v.Ind, TweenInfo.new(0.3), {Size = UDim2.new(0, 3, 0, 0)}):Play() end
        PageWrapper.Visible = true; TabBtn.BackgroundColor3 = Theme.ButtonDefault; TabBtn.TextColor3 = Theme.Text; CurrentTab = name
        TweenService:Create(Indicator, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0, 3, 0.6, 0)}):Play()
    end)
    table.insert(Tabs, {Name = name, Btn = TabBtn, Wrapper = PageWrapper, Page = Page, Ind = Indicator})
    return Page, TabBtn, PageWrapper, Indicator
end

local UI_Open = false
local function ToggleUI()
    UI_Open = not UI_Open; if UI_Open then Frame.Visible = true end
    TweenService:Create(Frame, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UI_Open and UDim2.new(0, 360, 0, 260) or UDim2.new(0, 360, 0, 0)}):Play()
    TweenService:Create(UIBlur, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UI_Open and 20 or 0}):Play()
    if not UI_Open then SafeDelay(0.4, function() if not UI_Open then Frame.Visible = false end end) end
end

-- Header Buttons
local Close = Instance.new("TextButton", Top); Close.Size = UDim2.new(0, 26, 0, 26); Close.Position = UDim2.new(1, -34, 0.5, -13); Close.Text = "X"; Close.Font = Enum.Font.GothamBold; Close.TextSize = 14; Close.AutoButtonColor = false; Close.BackgroundColor3 = Color3.fromRGB(220, 50, 50); Close.TextColor3 = Color3.new(1,1,1); Corner(Close, 6); Close.Activated:Connect(ToggleUI); Open.Activated:Connect(ToggleUI)

local ThemeToggle = Instance.new("TextButton", Top); ThemeToggle.Size = UDim2.new(0, 26, 0, 26); ThemeToggle.Position = UDim2.new(1, -66, 0.5, -13); ThemeToggle.Text = "☀️"; ThemeToggle.TextSize = 16; ThemeToggle.Font = Enum.Font.GothamBold; ThemeToggle.AutoButtonColor = false; ThemeToggle.BackgroundTransparency = 1; ThemeToggle.TextColor3 = Color3.new(1,1,1)
ThemeToggle.Activated:Connect(function()
    IsDarkMode = not IsDarkMode; ThemeToggle.Text = IsDarkMode and "☀️" or "🌙"
    local from = IsDarkMode and Themes.Light or Themes.Dark; local to = IsDarkMode and Themes.Dark or Themes.Light; Theme = to
    local colorMap = {[from.Background:ToHex()] = to.Background, [from.BackgroundTop:ToHex()] = to.BackgroundTop, [from.BackgroundTab:ToHex()] = to.BackgroundTab, [from.ButtonDefault:ToHex()] = to.ButtonDefault, [from.ButtonOn:ToHex()] = to.ButtonOn, [from.ButtonOff:ToHex()] = to.ButtonOff, [from.Text:ToHex()] = to.Text}
    for _, obj in pairs(Gui:GetDescendants()) do
        pcall(function()
            if obj:IsA("GuiObject") and colorMap[obj.BackgroundColor3:ToHex()] and obj ~= ThemeToggle and obj ~= LangToggle then TweenService:Create(obj, TweenInfo.new(0.3), {BackgroundColor3 = colorMap[obj.BackgroundColor3:ToHex()]}):Play() end
            if (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) and colorMap[obj.TextColor3:ToHex()] then TweenService:Create(obj, TweenInfo.new(0.3), {TextColor3 = colorMap[obj.TextColor3:ToHex()]}):Play() end
            if obj:IsA("ScrollingFrame") and colorMap[obj.ScrollBarImageColor3:ToHex()] then obj.ScrollBarImageColor3 = colorMap[obj.ScrollBarImageColor3:ToHex()] end
        end)
    end
    for _, v in pairs(Tabs) do
        if CurrentTab == v.Name then TweenService:Create(v.Btn, TweenInfo.new(0.3), {BackgroundColor3 = Theme.ButtonDefault, TextColor3 = Theme.Text}):Play() else TweenService:Create(v.Btn, TweenInfo.new(0.3), {BackgroundColor3 = Theme.BackgroundTop, TextColor3 = Color3.new(1,1,1)}):Play() end
        TweenService:Create(v.Ind, TweenInfo.new(0.3), {BackgroundColor3 = Theme.Text}):Play()
    end
end)

local LangToggle = Instance.new("TextButton", Top); LangToggle.Size = UDim2.new(0, 26, 0, 26); LangToggle.Position = UDim2.new(1, -98, 0.5, -13); LangToggle.Text = "友"; LangToggle.TextSize = 16; LangToggle.Font = Enum.Font.GothamBold; LangToggle.AutoButtonColor = false; LangToggle.BackgroundTransparency = 1; LangToggle.TextColor3 = Color3.new(1,1,1)
LangToggle.Activated:Connect(function()
    CurrentLanguage = CurrentLanguage == "ID" and "EN" or "ID"
    Notify("LANGUAGE", CurrentLanguage == "ID" and "Bahasa diubah ke Indonesia" or "Language changed to English", 3)
    for _, data in ipairs(DynamicLabels) do if data.Obj then data.Obj.Text = CurrentLanguage == "ID" and data.ID or data.EN end end
end)

------------------------------------------------
-- UI COMPONENTS
------------------------------------------------
local function GetInfoString(info) return (type(info) == "table") and (info[CurrentLanguage] or info.ID) or info end

local function CreateButton(parent, text, color, layoutOrder, infoText)
    local MainBtn = Instance.new("TextButton", parent); MainBtn.Size = UDim2.new(0, 220, 0, 28); MainBtn.BackgroundColor3 = color; MainBtn.Text = text; MainBtn.TextColor3 = Theme.Text; MainBtn.TextSize = 11; MainBtn.Font = Enum.Font.GothamBold; MainBtn.AutoButtonColor = false; MainBtn.LayoutOrder = layoutOrder; Corner(MainBtn, 8)
    if infoText then
        local InfoBtn = Instance.new("TextButton", MainBtn); InfoBtn.Size = UDim2.new(0, 30, 1, 0); InfoBtn.Position = UDim2.new(1, -30, 0, 0); InfoBtn.BackgroundTransparency = 1; InfoBtn.Text = "ⓘ"; InfoBtn.TextColor3 = Color3.new(1, 1, 1); InfoBtn.TextSize = 14; InfoBtn.Font = Enum.Font.GothamBold; InfoBtn.AutoButtonColor = false; InfoBtn.ZIndex = 2
        InfoBtn.MouseEnter:Connect(function()
            if UIS:GetLastInputType() == Enum.UserInputType.Touch then return end
            InfoBtn.TextColor3 = Theme.Text; TooltipText.Text = GetInfoString(infoText); TooltipText.Size = UDim2.new(1, -10, 0, 1000)
            TooltipUI.Size = UDim2.new(0, math.clamp(TooltipText.TextBounds.X + 20, 150, 250), 0, TooltipText.TextBounds.Y + 10)
            TooltipText.Size = UDim2.new(1, -10, 1, -10); TooltipUI.Visible = true
        end)
        InfoBtn.MouseLeave:Connect(function() InfoBtn.TextColor3 = Color3.new(1, 1, 1); TooltipUI.Visible = false end)
        InfoBtn.Activated:Connect(function() TooltipUI.Visible = false; Notify("INFO", GetInfoString(infoText), 6) end)
    end
    return MainBtn
end

local function CreateSlider(parent, name, min, max, default, color, layoutOrder, callback)
    local Holder = Instance.new("Frame", parent); Holder.Size = UDim2.new(0, 220, 0, 42); Holder.BackgroundTransparency = 1; Holder.LayoutOrder = layoutOrder
    local Label = Instance.new("TextLabel", Holder); Label.Size = UDim2.new(1, 0, 0, 15); Label.TextColor3 = Theme.Text; Label.TextSize = 11; Label.Text = name .. " : " .. default; Label.Font = Enum.Font.GothamBold; Label.BackgroundTransparency = 1
    local Bar = Instance.new("TextButton", Holder); Bar.Text = ""; Bar.AutoButtonColor = false; Bar.Position = UDim2.new(0, 0, 0, 20); Bar.Size = UDim2.new(1, 0, 0, 12); Bar.BackgroundTransparency = 1
    local VBar = Instance.new("Frame", Bar); VBar.Size = UDim2.new(1, 0, 0, 4); VBar.Position = UDim2.new(0, 0, 0.5, -2); VBar.BackgroundColor3 = Color3.fromHex("#6237A0"); Corner(VBar, 999)
    local Fill = Instance.new("Frame", VBar); Fill.BackgroundColor3 = color; Corner(Fill, 999)
    local Handle = Instance.new("Frame", VBar); Handle.Size = UDim2.new(0, 18, 0, 18); Handle.AnchorPoint = Vector2.new(0.5, 0.5); Handle.Position = UDim2.new(0, 0, 0.5, 0); Handle.BackgroundColor3 = Theme.Text; Corner(Handle, 999)

    local function Update(x)
        local p = math.clamp((x - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1); local val = math.floor(min + ((max - min) * p) + 0.5)
        Fill.Size = UDim2.new(p, 0, 1, 0); Handle.Position = UDim2.new(p, 0, 0.5, 0); Label.Text = name .. " : " .. val; callback(val)
    end
    Handle.InputBegan:Connect(function(input) if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and ActiveSlider == nil then ActiveSlider = Handle; parent.ScrollingEnabled = false end end)
    UIS.InputChanged:Connect(function(input) if ActiveSlider == Handle and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then Update(input.Position.X) end end)
    UIS.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then if ActiveSlider == Handle then ActiveSlider = nil; parent.ScrollingEnabled = true end end end)

    local startX
    Bar.InputBegan:Connect(function(input) if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and ActiveSlider == nil then startX = input.Position.X end end)
    Bar.InputEnded:Connect(function(input) if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and startX then if math.abs(input.Position.X - startX) < 5 and ActiveSlider == nil then Update(input.Position.X) end; startX = nil end end)
    local function SetVisual(val) local p = math.clamp((val - min) / (max - min), 0, 1); Fill.Size = UDim2.new(p, 0, 1, 0); Handle.Position = UDim2.new(p, 0, 0.5, 0); Label.Text = name .. " : " .. val end
    SetVisual(default); return SetVisual
end

local function CreateAccordion(parent, title, color, layoutOrder, infoText, maxHeight)
    maxHeight = maxHeight or 140
    local Holder = Instance.new("Frame", parent); Holder.Size = UDim2.new(0, 220, 0, 28); Holder.BackgroundTransparency = 1; Holder.ClipsDescendants = true; Holder.LayoutOrder = layoutOrder
    local ToggleBtn = CreateButton(Holder, title .. " ▼", color, 1, infoText)
    local Menu = Instance.new("Frame", Holder); Menu.Size = UDim2.new(1, 0, 1, -32); Menu.Position = UDim2.new(0, 0, 0, 32); Menu.BackgroundTransparency = 1
    local Scroll = Instance.new("ScrollingFrame", Menu); Scroll.Size = UDim2.new(1, 0, 1, 0); Scroll.BackgroundTransparency = 1; Scroll.BorderSizePixel = 0; Scroll.ScrollBarThickness = 2; Scroll.ScrollBarImageColor3 = Theme.ButtonDefault
    local ListUI = Instance.new("UIListLayout", Scroll); ListUI.Padding = UDim.new(0, 4); ListUI.SortOrder = Enum.SortOrder.LayoutOrder
    local State = {IsOpen = false, ExtraHeight = 0}

    Scroll.InputBegan:Connect(function(input) if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and ActiveScroll == nil then ActiveScroll = Scroll; if parent:IsA("ScrollingFrame") then parent.ScrollingEnabled = false end end end)
    UIS.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then if ActiveScroll == Scroll then ActiveScroll = nil; if parent:IsA("ScrollingFrame") then parent.ScrollingEnabled = true end end end end)

    local function UpdateSize() TweenService:Create(Holder, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0, 220, 0, State.IsOpen and (32 + math.clamp(ListUI.AbsoluteContentSize.Y + State.ExtraHeight, 0, maxHeight)) or 28)}):Play() end
    ToggleBtn.Activated:Connect(function() State.IsOpen = not State.IsOpen; ToggleBtn.Text = State.IsOpen and (title .. " ▲") or (title .. " ▼"); UpdateSize() end)
    return Holder, Menu, Scroll, ListUI, UpdateSize, ToggleBtn, State
end

------------------------------------------------
-- TABS & FUNCTIONALITIES
------------------------------------------------
local TabProfile, BtnProfile, WrapProf, IndProf = CreateTab("Profile", "👤", 1)
local TabMovement, BtnMovement, WrapMov, IndMov = CreateTab("Movement", "🧑‍🦽", 2)
local TabVisual, BtnVisual, WrapVis, IndVis     = CreateTab("Visual", "👁️", 3)
local TabUtility, BtnUtility, WrapUtl, IndUtl   = CreateTab("Utility", "⚙️", 4)
local TabTeleport, BtnTeleport, WrapTel, IndTel = CreateTab("Teleport", "🌍", 5)
local TabConfig, BtnConfig, WrapCfg, IndCfg     = CreateTab("Settings", "💾", 6)

BtnProfile.BackgroundColor3 = Theme.ButtonDefault; BtnProfile.TextColor3 = Theme.Text; IndProf.Size = UDim2.new(0, 3, 0.6, 0); WrapProf.Visible = true; CurrentTab = "Profile"

-- // CHARACTER HANDLER
local function ApplyProperties(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        hum.WalkSpeed = WalkSpeed; hum.JumpPower = JumpPower; hum.UseJumpPower = true
        if SpeedConnection then SpeedConnection:Disconnect() end; if JumpConnection then JumpConnection:Disconnect() end
        SpeedConnection = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function() if hum.WalkSpeed ~= WalkSpeed then hum.WalkSpeed = WalkSpeed end end)
        JumpConnection = hum:GetPropertyChangedSignal("JumpPower"):Connect(function() if hum.JumpPower ~= JumpPower then hum.JumpPower = JumpPower end end)
    end
end
if LP.Character then ApplyProperties(LP.Character) end
Connections.CharAdded = LP.CharacterAdded:Connect(ApplyProperties)

-- // 1. PROFILE TAB
local ProfileListUI = Instance.new("UIListLayout", TabProfile); ProfileListUI.SortOrder = Enum.SortOrder.LayoutOrder; ProfileListUI.Padding = UDim.new(0, 10); ProfileListUI.HorizontalAlignment = Enum.HorizontalAlignment.Center
ProfileListUI:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() TabProfile.CanvasSize = UDim2.new(0, 0, 0, ProfileListUI.AbsoluteContentSize.Y + 20) end)

local function CreateRow(parent, labelText)
    local Row = Instance.new("Frame", parent); Row.BackgroundTransparency = 1; Row.Size = UDim2.new(1, 0, 0, 18)
    local Lbl = Instance.new("TextLabel", Row); Lbl.BackgroundTransparency = 1; Lbl.Size = UDim2.new(0.45, 0, 1, 0); Lbl.Position = UDim2.new(0, 10, 0, 0); Lbl.Font = Enum.Font.Gotham; Lbl.Text = labelText; Lbl.TextColor3 = Theme.Text; Lbl.TextSize = 10; Lbl.TextXAlignment = Enum.TextXAlignment.Left
    local Val = Instance.new("TextLabel", Row); Val.BackgroundTransparency = 1; Val.Size = UDim2.new(0.5, 0, 1, 0); Val.Position = UDim2.new(0.45, 0, 0, 0); Val.Font = Enum.Font.GothamBold; Val.Text = "Loading..."; Val.TextColor3 = Color3.new(1, 1, 1); Val.TextSize = 10; Val.TextXAlignment = Enum.TextXAlignment.Right; Val.TextTruncate = Enum.TextTruncate.AtEnd
    return Val
end

local function CreateProfileAccordion(title, layoutOrder, maxHeight)
    local _, _, Scroll, ListUI, UpdateSize, _, State = CreateAccordion(TabProfile, title, Theme.BackgroundTop, layoutOrder, nil, maxHeight)
    ListUI:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() Scroll.CanvasSize = UDim2.new(0, 0, 0, ListUI.AbsoluteContentSize.Y); if State.IsOpen then UpdateSize() end end)
    return Scroll
end

local AvatarFrame = Instance.new("Frame", TabProfile); AvatarFrame.Size = UDim2.new(0, 64, 0, 64); AvatarFrame.BackgroundColor3 = Theme.BackgroundTop; AvatarFrame.LayoutOrder = 1; Corner(AvatarFrame, 32)
local AvatarImg = Instance.new("ImageLabel", AvatarFrame); AvatarImg.Size = UDim2.new(1, 0, 1, 0); AvatarImg.BackgroundTransparency = 1; Corner(AvatarImg, 32)
coroutine.wrap(function() local s, img = pcall(function() return Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420) end); if s then AvatarImg.Image = img end end)()

local SecAcc = CreateProfileAccordion("Account Information", 2, 200)
CreateRow(SecAcc, "Display Name").Text = LP.DisplayName
CreateRow(SecAcc, "Username").Text = "@" .. LP.Name
CreateRow(SecAcc, "User ID").Text = tostring(LP.UserId)
CreateRow(SecAcc, "Account Age").Text = LP.AccountAge .. " Days"
CreateRow(SecAcc, "Join Date").Text = os.date("%Y-%m-%d", os.time() - (LP.AccountAge * 86400))
local ValPremium = CreateRow(SecAcc, "Premium"); ValPremium.Text = LP.MembershipType == Enum.MembershipType.Premium and "Yes" or "No"; ValPremium.TextColor3 = LP.MembershipType == Enum.MembershipType.Premium and Color3.fromHex("#F1C40F") or Color3.new(1, 1, 1)

local ValBio, ValFriends, ValActiveFriends = CreateRow(SecAcc, "Bio"), CreateRow(SecAcc, "Friends"), CreateRow(SecAcc, "Active Friends")
local function GetAPI(url) local req = request or http_request or (syn and syn.request); if req then local s, r = pcall(function() return req({Url = url, Method = "GET"}) end); if s and r and r.Body then local s2, res = pcall(function() return HttpService:JSONDecode(r.Body) end); if s2 then return res end end end; local s, r = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end); return (s and r) and r or nil end

coroutine.wrap(function() local api = GetAPI("https://users.roproxy.com/v1/users/" .. LP.UserId); ValBio.Text = api and (api.description ~= "" and api.description or "No Bio") or "API Blocked" end)()
coroutine.wrap(function() local api = GetAPI("https://friends.roproxy.com/v1/users/" .. LP.UserId .. "/friends/count"); ValFriends.Text = api and tostring(api.count or 0) or "Error" end)()
coroutine.wrap(function() local s, online = pcall(function() return LP:GetFriendsOnline(200) end); ValActiveFriends.Text = s and tostring(#online) or "Error" end)()

local SecServer = CreateProfileAccordion("Server Information", 3, 150)
local ValGame = CreateRow(SecServer, "Game Name"); CreateRow(SecServer, "Place ID").Text = tostring(game.PlaceId); CreateRow(SecServer, "Universe ID").Text = tostring(game.GameId)
CreateRow(SecServer, "Job ID").Text = game.JobId ~= "" and game.JobId or "Private / Studio"
local ValPlayers = CreateRow(SecServer, "Players")
local function UpdatePlayerCount() ValPlayers.Text = tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers) end
UpdatePlayerCount(); Players.PlayerAdded:Connect(UpdatePlayerCount); Players.PlayerRemoving:Connect(UpdatePlayerCount)
coroutine.wrap(function() local s, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end); ValGame.Text = s and info.Name or "Unknown Game" end)()

local SecExtra = CreateProfileAccordion("Extra Information", 4, 120)
CreateRow(SecExtra, "Device").Text = (UIS.TouchEnabled and not UIS.KeyboardEnabled) and "Mobile" or (UIS.GamepadEnabled and "Console" or "PC")
CreateRow(SecExtra, "Locale").Text = LocalizationService.SystemLocaleId
CreateRow(SecExtra, "Roblox Version").Text = version()
local ValStatus = CreateRow(SecExtra, "Status"); ValStatus.Text = "Connected"; ValStatus.TextColor3 = Color3.fromHex("#2ECC71")

-- // 2. MOVEMENT TAB
local SetSpeedVisual = CreateSlider(TabMovement, "Walk Speed", 16, 120, 16, Theme.Text, 1, function(v) WalkSpeed = v; local h = Humanoid(); if h then h.WalkSpeed = v end end)
local SetJumpVisual = CreateSlider(TabMovement, "Jump Power", 50, 250, 50, Theme.Text, 2, function(v) JumpPower = v; local h = Humanoid(); if h then h.JumpPower = v end end)

local InfBtn = CreateButton(TabMovement, "Inf Jump : OFF", Theme.ButtonOff, 3, {ID="Melompat terus-menerus di udara.", EN="Jump continuously in the air."})
local function SetInfJump(state) ToggleStates.InfJump = state; InfBtn.Text = state and "Inf Jump : ON" or "Inf Jump : OFF"; InfBtn.BackgroundColor3 = state and Theme.ButtonOn or Theme.ButtonOff end
InfBtn.Activated:Connect(function() SetInfJump(not ToggleStates.InfJump) end); Connections.Jump = UIS.JumpRequest:Connect(function() if ToggleStates.InfJump and Humanoid() then Humanoid():ChangeState(Enum.HumanoidStateType.Jumping) end end)

local NoclipBtn = CreateButton(TabMovement, "Noclip : OFF", Theme.ButtonOff, 4, {ID="Menembus dinding.", EN="Walk through walls."})
local function SetNoclip(state) 
    ToggleStates.Noclip = state; NoclipBtn.Text = state and "Noclip : ON" or "Noclip : OFF"; NoclipBtn.BackgroundColor3 = state and Theme.ButtonOn or Theme.ButtonOff 
    if state then
        if not Connections.Noclip then
            Connections.Noclip = RunService.Stepped:Connect(function()
                if LP.Character then
                    if LP.Character ~= Connections.LastCharNoclip then Connections.LastCharNoclip = LP.Character; Connections.CharPartsCache = {}; for _, v in ipairs(LP.Character:GetDescendants()) do if v:IsA("BasePart") then table.insert(Connections.CharPartsCache, v) end end end
                    for i = 1, #Connections.CharPartsCache do local part = Connections.CharPartsCache[i]; if part and part.CanCollide then part.CanCollide = false end end
                end
            end)
        end
    else if Connections.Noclip then Connections.Noclip:Disconnect(); Connections.Noclip, Connections.LastCharNoclip, Connections.CharPartsCache = nil, nil, nil end end
end
NoclipBtn.Activated:Connect(function() SetNoclip(not ToggleStates.Noclip) end)

local FlyBody, FlyGyro
local function SetFly(state)
    ToggleStates.Fly = state; local h, hum = HRP(), Humanoid(); if not h or not hum then ToggleStates.Fly = false return end
    if state then
        hum.PlatformStand = true; FlyBody = Instance.new("BodyVelocity", h); FlyBody.MaxForce = Vector3.new(9e9, 9e9, 9e9); FlyBody.Velocity = Vector3.zero
        FlyGyro = Instance.new("BodyGyro", h); FlyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9); FlyGyro.P = 9e4; FlyGyro.CFrame = h.CFrame
        Connections.FlyLoop = RunService.RenderStepped:Connect(function()
            if not ToggleStates.Fly or not HRP() or not Humanoid() then return end
            local cam = workspace.CurrentCamera
            local moveDir = Humanoid().MoveDirection
            local vel = Vector3.zero
            
            if moveDir.Magnitude > 0 then 
                local camSpaceMove = cam.CFrame:VectorToObjectSpace(moveDir)
                vel = (cam.CFrame.LookVector * -camSpaceMove.Z + cam.CFrame.RightVector * camSpaceMove.X) * FlySpeed 
            end
            
            if UIS:IsKeyDown(Enum.KeyCode.Space) then vel = vel + Vector3.new(0, FlySpeed, 0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then vel = vel - Vector3.new(0, FlySpeed, 0) end
            
            FlyBody.Velocity = vel; FlyGyro.CFrame = cam.CFrame
        end)
    else hum.PlatformStand = false; if FlyBody then FlyBody:Destroy() end; if FlyGyro then FlyGyro:Destroy() end; if Connections.FlyLoop then Connections.FlyLoop:Disconnect() end end
end
local FlyBtn = CreateButton(TabMovement, "Fly : OFF", Theme.ButtonOff, 5, {ID="Terbang bebas di udara.", EN="Fly freely."})
FlyBtn.Activated:Connect(function() SetFly(not ToggleStates.Fly); FlyBtn.Text = ToggleStates.Fly and "Fly : ON" or "Fly : OFF"; FlyBtn.BackgroundColor3 = ToggleStates.Fly and Theme.ButtonOn or Theme.ButtonOff end)
local SetFlySpeedVisual = CreateSlider(TabMovement, "Fly Speed", 1, 300, 50, Theme.Text, 6, function(v) FlySpeed = v end)

local EmoteBtn = CreateButton(TabMovement, "Emotes / Animations", Theme.ButtonDefault, 7, {ID="Load script Emotes.", EN="Load Emotes script."})
EmoteBtn.Activated:Connect(function() Notify("SYSTEM", CurrentLanguage == "ID" and "Memuat script..." or "Loading script...", 3)
    local s = pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/7yd7/Hub/refs/heads/Branch/GUIS/Emotes.lua"))() end)
    if not s then Notify("ERROR", CurrentLanguage == "ID" and "Gagal memuat Emotes!" or "Failed to load Emotes!", 3) end
end)

-- // 3. VISUAL TAB
local SetFOVVisual = CreateSlider(TabVisual, "Field Of View", 70, 120, 70, Theme.Text, 1, function(v) CurrentFOV = v; if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView = v end end)
local MaxZoomBtn = CreateButton(TabVisual, "Max Zoom : OFF", Theme.ButtonOff, 2, {ID="Zoom out kamera tak terbatas.", EN="Infinite camera zoom out."})
local function SetMaxZoom(state) ToggleStates.MaxZoom = state; MaxZoomBtn.Text = state and "Max Zoom : ON" or "Max Zoom : OFF"; MaxZoomBtn.BackgroundColor3 = state and Theme.ButtonOn or Theme.ButtonOff; LP.CameraMaxZoomDistance = state and 100000 or 400 end
MaxZoomBtn.Activated:Connect(function() SetMaxZoom(not ToggleStates.MaxZoom) end)

local FPSBtn = CreateButton(TabVisual, "FPS Booster : OFF", Theme.ButtonOff, 3, {ID="Menurunkan grafik secara ekstrem.", EN="Lowers graphics extremely."})
local OriginalGraphics, OriginalLighting = {}, {GlobalShadows = Lighting.GlobalShadows, FogEnd = Lighting.FogEnd, ShadowSoftness = Lighting.ShadowSoftness}
setmetatable(OriginalGraphics, {__mode = "k"})

local function SetPotatoMode(state)
    ToggleStates.PotatoMode = state
    if state then
        FPSBtn.Text = "FPS Booster : ON"; FPSBtn.BackgroundColor3 = Theme.ButtonOn; Notify("SYSTEM", "Optimizing game...", 3)
        Lighting.GlobalShadows = false; Lighting.FogEnd = 9e9; Lighting.ShadowSoftness = 0
        local function ApplyPotato(v)
            if not OriginalGraphics[v] then OriginalGraphics[v] = {} end
            if v:IsA("BasePart") and not v:IsA("MeshPart") then if not OriginalGraphics[v].Material then OriginalGraphics[v].Material = v.Material; OriginalGraphics[v].Reflectance = v.Reflectance end; v.Material = Enum.Material.SmoothPlastic; v.Reflectance = 0
            elseif v:IsA("Decal") or v:IsA("Texture") then if not OriginalGraphics[v].Transparency then OriginalGraphics[v].Transparency = v.Transparency end; v.Transparency = 1
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then if not OriginalGraphics[v].Lifetime then OriginalGraphics[v].Lifetime = v.Lifetime end; v.Lifetime = NumberRange.new(0) end
        end
        coroutine.wrap(function() local des = workspace:GetDescendants(); for i = 1, #des do ApplyPotato(des[i]); if i % 500 == 0 then RunService.Heartbeat:Wait() end end end)()
        if not DescendantConnection then DescendantConnection = workspace.DescendantAdded:Connect(function(v) if ToggleStates.PotatoMode then ApplyPotato(v) end end) end
    else
        FPSBtn.Text = "FPS Booster : OFF"; FPSBtn.BackgroundColor3 = Theme.ButtonOff; Notify("SYSTEM", "Restoring graphics...", 3)
        if DescendantConnection then DescendantConnection:Disconnect(); DescendantConnection = nil end
        Lighting.GlobalShadows = OriginalLighting.GlobalShadows; Lighting.FogEnd = OriginalLighting.FogEnd; Lighting.ShadowSoftness = OriginalLighting.ShadowSoftness
        for v, data in pairs(OriginalGraphics) do if v and v.Parent then if data.Material then v.Material = data.Material; v.Reflectance = data.Reflectance end; if data.Transparency then v.Transparency = data.Transparency end; if data.Lifetime then v.Lifetime = data.Lifetime end end end
    end
end
FPSBtn.Activated:Connect(function() SetPotatoMode(not ToggleStates.PotatoMode) end)

local ESPInstances = {}
local function RemoveESP(player)
    if ESPInstances[player] then
        if ESPInstances[player].Connection then ESPInstances[player].Connection:Disconnect() end
        if ESPInstances[player].Highlight then ESPInstances[player].Highlight:Destroy() end
        if ESPInstances[player].Billboard then ESPInstances[player].Billboard:Destroy() end
        ESPInstances[player] = nil
    end
end

local function CreateESP(player)
    if player == LP then return end
    RemoveESP(player)

    local highlight = Instance.new("Highlight")
    highlight.FillColor = Color3.fromHex("#E74C3C")
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.FillTransparency = 0.6
    highlight.OutlineTransparency = 0.1
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3.5, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 5000

    local textLabel = Instance.new("TextLabel", billboard)
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.TextStrokeTransparency = 0
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextSize = 10

    ESPInstances[player] = {Highlight = highlight, Billboard = billboard, Text = textLabel}

    ESPInstances[player].Connection = RunService.RenderStepped:Connect(function()
        if ToggleStates.ESP and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            highlight.Parent = player.Character
            billboard.Parent = player.Character.HumanoidRootPart

            local myHRP = HRP()
            if myHRP then
                local dist = math.floor((myHRP.Position - player.Character.HumanoidRootPart.Position).Magnitude)
                local hp = math.floor(player.Character.Humanoid.Health)
                local maxHp = math.floor(player.Character.Humanoid.MaxHealth)
                
                local hpColor = hp > (maxHp * 0.6) and "#2ECC71" or (hp > (maxHp * 0.3) and "#F1C40F" or "#E74C3C")
                textLabel.Text = player.DisplayName .. " | " .. dist .. "m\n<font color='" .. hpColor .. "'>HP: " .. hp .. "/" .. maxHp .. "</font>"
                textLabel.RichText = true
            end
        else
            highlight.Parent = nil
            billboard.Parent = nil
        end
    end)
end

local ESPBtn = CreateButton(TabVisual, "Smart ESP : OFF", Theme.ButtonOff, 4, {ID="Melihat pemain beserta HP & jarak menembus dinding.", EN="See players, HP & distance through walls."})

local function SetESP(state)
    ToggleStates.ESP = state
    ESPBtn.Text = state and "Smart ESP : ON" or "Smart ESP : OFF"
    ESPBtn.BackgroundColor3 = state and Theme.ButtonOn or Theme.ButtonOff

    if state then
        for _, p in pairs(Players:GetPlayers()) do CreateESP(p) end
        Connections.ESPPlayerAdded = Players.PlayerAdded:Connect(CreateESP)
        Connections.ESPPlayerRemoving = Players.PlayerRemoving:Connect(RemoveESP)
    else
        if Connections.ESPPlayerAdded then Connections.ESPPlayerAdded:Disconnect() end
        if Connections.ESPPlayerRemoving then Connections.ESPPlayerRemoving:Disconnect() end
        for p, _ in pairs(ESPInstances) do RemoveESP(p) end
    end
end
ESPBtn.Activated:Connect(function() SetESP(not ToggleStates.ESP) end)

-- Fitur Fullbright
local FullbrightBtn = CreateButton(TabVisual, "Fullbright : OFF", Theme.ButtonOff, 5, {ID="Membuat game menjadi sangat terang.", EN="Makes the game extremely bright."})
local function SetFullbright(state)
    ToggleStates.Fullbright = state
    FullbrightBtn.Text = state and "Fullbright : ON" or "Fullbright : OFF"
    FullbrightBtn.BackgroundColor3 = state and Theme.ButtonOn or Theme.ButtonOff
    if state then
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        pcall(function() Lighting.ExposureCompensation = 0.75 end)
    else
        Lighting.Brightness = OriginalFB.Brightness
        Lighting.ClockTime = OriginalFB.ClockTime
        Lighting.GlobalShadows = OriginalFB.GlobalShadows
        pcall(function() Lighting.ExposureCompensation = OriginalFB.ExposureCompensation end)
    end
end
FullbrightBtn.Activated:Connect(function() SetFullbright(not ToggleStates.Fullbright) end)

-- Fitur No Fog
local NofogBtn = CreateButton(TabVisual, "No Fog : OFF", Theme.ButtonOff, 6, {ID="Menghilangkan kabut di sekitar map.", EN="Removes fog from the map."})
local function SetNofog(state)
    ToggleStates.Nofog = state
    NofogBtn.Text = state and "No Fog : ON" or "No Fog : OFF"
    NofogBtn.BackgroundColor3 = state and Theme.ButtonOn or Theme.ButtonOff
    if state then
        Lighting.FogEnd = 9e9
        pcall(function() Lighting.FogStart = 9e9 end)
    else
        Lighting.FogEnd = OriginalFog.FogEnd
        pcall(function() Lighting.FogStart = OriginalFog.FogStart end)
    end
end
NofogBtn.Activated:Connect(function() SetNofog(not ToggleStates.Nofog) end)


-- // 4. UTILITY TAB
local InstantBtn = CreateButton(TabUtility, "Instant Prompt : OFF", Theme.ButtonOff, 1, {ID="Bypass hold E.", EN="Bypass prompt hold time."})
local function SetInstantPrompt(state) ToggleStates.InstantPrompt = state; InstantBtn.Text = state and "Instant Prompt : ON" or "Instant Prompt : OFF"; InstantBtn.BackgroundColor3 = state and Theme.ButtonOn or Theme.ButtonOff end
InstantBtn.Activated:Connect(function() SetInstantPrompt(not ToggleStates.InstantPrompt) end)
Connections.Prompt = ProximityPromptService.PromptButtonHoldBegan:Connect(function(p) if ToggleStates.InstantPrompt then p.HoldDuration = 0; if fireproximityprompt then fireproximityprompt(p) end end end)

local AntiAFKBtn = CreateButton(TabUtility, "Anti AFK : OFF", Theme.ButtonOff, 2, {ID="Mencegah auto kick afk.", EN="Prevents idle kick."})
local function SetAntiAFK(state) ToggleStates.AntiAFK = state; AntiAFKBtn.Text = state and "Anti AFK : ON" or "Anti AFK : OFF"; AntiAFKBtn.BackgroundColor3 = state and Theme.ButtonOn or Theme.ButtonOff end
AntiAFKBtn.Activated:Connect(function() SetAntiAFK(not ToggleStates.AntiAFK) end)
Connections.Idled = LP.Idled:Connect(function() if ToggleStates.AntiAFK then local cam = workspace.CurrentCamera; VirtualUser:Button2Down(Vector2.new(0,0), cam.CFrame); SafeWait(1); VirtualUser:Button2Up(Vector2.new(0,0), cam.CFrame) end end)

local KeybindBtn = CreateButton(TabUtility, "Keybind : RightControl", Theme.ButtonDefault, 3, {ID="Ubah tombol GUI.", EN="Change GUI bind."})
KeybindBtn.Activated:Connect(function() Binding = true; KeybindBtn.Text = "Press any key..."; KeybindBtn.BackgroundColor3 = Color3.fromHex("#E74C3C") end)
Connections.Input = UIS.InputBegan:Connect(function(input, gpe)
    if Binding and input.UserInputType == Enum.UserInputType.Keyboard then CurrentKeybind = input.KeyCode; Binding = false; KeybindBtn.Text = "Keybind : " .. input.KeyCode.Name; KeybindBtn.BackgroundColor3 = Theme.ButtonDefault; Notify("SYSTEM", "Keybind changed", 3)
    elseif not gpe and input.KeyCode == CurrentKeybind then ToggleUI() end
end)

-- ==========================================
-- SMART INSPECTOR & PART TOOLS INTEGRATION
-- ==========================================
local ToolMouseConn, ToolTouchConn
local CurrentSelectionBox = nil
local CurrentBillboard = nil
local PartESPHighlights = {}

local function ClearInspector()
    if CurrentSelectionBox then CurrentSelectionBox:Destroy(); CurrentSelectionBox = nil end
    if CurrentBillboard then CurrentBillboard:Destroy(); CurrentBillboard = nil end
end

local function ClearPartESP()
    for _, hl in pairs(PartESPHighlights) do
        if hl then hl:Destroy() end
    end
    PartESPHighlights = {}
end

local function GetSmartTarget(hitPart)
    local parentModel = hitPart:FindFirstAncestorOfClass("Model")
    if parentModel and parentModel.Name ~= "Workspace" then return parentModel, hitPart end
    return hitPart, hitPart
end

local function HighlightSmart(hitPart)
    ClearInspector()
    if not hitPart or not hitPart:IsA("BasePart") then return end
    
    local mainTarget, basePart = GetSmartTarget(hitPart)
    local targetSize = Vector3.zero
    
    if mainTarget:IsA("Model") then
        local orientation, size = mainTarget:GetBoundingBox()
        targetSize = size
    else
        targetSize = mainTarget.Size
    end
    
    CurrentSelectionBox = Instance.new("SelectionBox")
    CurrentSelectionBox.Adornee = mainTarget
    CurrentSelectionBox.LineThickness = 0.05
    CurrentSelectionBox.Color3 = Color3.fromHex("#10B981")
    CurrentSelectionBox.Parent = Gui
    
    CurrentBillboard = Instance.new("BillboardGui")
    CurrentBillboard.Adornee = basePart
    CurrentBillboard.Size = UDim2.new(0, 150, 0, 30)
    CurrentBillboard.StudsOffset = Vector3.new(0, (basePart.Size.Y / 2) + 1.5, 0)
    CurrentBillboard.AlwaysOnTop = true
    CurrentBillboard.Parent = Gui
    
    local TextLabel = Instance.new("TextLabel")
    TextLabel.Size = UDim2.new(1, 0, 1, 0)
    TextLabel.BackgroundColor3 = Color3.fromHex("#09090B")
    TextLabel.BackgroundTransparency = 0.2
    TextLabel.TextColor3 = Color3.fromHex("#10B981")
    TextLabel.TextScaled = true
    TextLabel.Text = mainTarget.Name .. "\n(" .. tostring(math.floor(targetSize.X)) .. ", " .. tostring(math.floor(targetSize.Y)) .. ", " .. tostring(math.floor(targetSize.Z)) .. ")"
    TextLabel.Font = Enum.Font.GothamBold
    TextLabel.Parent = CurrentBillboard
    Corner(TextLabel, 6)
end

local function HandlePartESPClick(target)
    if target and (not LP.Character or not target:IsDescendantOf(LP.Character)) then
        local hasESP = false
        for _, hl in pairs(PartESPHighlights) do
            if hl.Adornee == target then hasESP = true; break end
        end
        if not hasESP then
            local hl = Instance.new("Highlight")
            hl.FillColor = Color3.fromHex("#F15BB5")
            hl.OutlineColor = Color3.new(1, 1, 1)
            hl.FillTransparency = 0.5
            hl.Parent = target
            table.insert(PartESPHighlights, hl)
        end
    end
end

local function HandleGotoPartClick(target)
    if target and (not LP.Character or not target:IsDescendantOf(LP.Character)) then
        local h = HRP()
        if h then
            h.CFrame = target.CFrame * CFrame.new(0, 3, 0)
            Notify("TELEPORT", "Teleported to " .. target.Name, 3)
        end
    end
end

local function SetupToolConnections()
    if ToolMouseConn then ToolMouseConn:Disconnect(); ToolMouseConn = nil end
    if ToolTouchConn then ToolTouchConn:Disconnect(); ToolTouchConn = nil end
    
    if ToggleStates.SmartInspector or ToggleStates.PartESP or ToggleStates.GotoPart then
        ToolTouchConn = UIS.TouchTapInWorld:Connect(function(position, processedByUI)
            if not processedByUI then
                local cam = workspace.CurrentCamera
                local ray = cam:ViewportPointToRay(position.X, position.Y)
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances = {LP.Character, Gui}
                
                local result = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
                if result and result.Instance then
                    if ToggleStates.SmartInspector then HighlightSmart(result.Instance)
                    elseif ToggleStates.PartESP then HandlePartESPClick(result.Instance)
                    elseif ToggleStates.GotoPart then HandleGotoPartClick(result.Instance) end
                else
                    if ToggleStates.SmartInspector then ClearInspector() end
                end
            end
        end)
        
        ToolMouseConn = UIS.InputBegan:Connect(function(input, gpe)
            if input.UserInputType == Enum.UserInputType.MouseButton1 and not gpe then
                if not UIS:GetFocusedTextBox() then
                    local mouseLoc = UIS:GetMouseLocation()
                    local cam = workspace.CurrentCamera
                    local ray = cam:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)
                    local params = RaycastParams.new()
                    params.FilterType = Enum.RaycastFilterType.Exclude
                    params.FilterDescendantsInstances = {LP.Character, Gui}
                    
                    local result = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
                    if result and result.Instance then
                        if ToggleStates.SmartInspector then HighlightSmart(result.Instance)
                        elseif ToggleStates.PartESP then HandlePartESPClick(result.Instance)
                        elseif ToggleStates.GotoPart then HandleGotoPartClick(result.Instance) end
                    else
                        if ToggleStates.SmartInspector then ClearInspector() end
                    end
                end
            end
        end)
    end
end

local _, _, SmartScroll, SmartListUI, UpdateSmartSize, SmartToggleBtn, SmartState = CreateAccordion(TabUtility, "Smart Inspector Menu", Theme.ButtonDefault, 4, {ID="Menu inspeksi & teleport pintar.", EN="Smart inspect & teleport menu."}, 140)

local SmartInspectorBtn = CreateButton(SmartScroll, "Smart Inspector : OFF", Theme.ButtonOff, 1, {ID="Inspeksi ukuran & model part pintar.", EN="Smart inspect parts & models size."})
SmartInspectorBtn.Size = UDim2.new(1, -6, 0, 28)

local PartESPBtn = CreateButton(SmartScroll, "ESP Part : OFF", Theme.ButtonOff, 2, {ID="Klik part untuk memberikan ESP permanen.", EN="Click a part to give it permanent ESP."})
PartESPBtn.Size = UDim2.new(1, -6, 0, 28)

local GotoPartBtn = CreateButton(SmartScroll, "Goto Part : OFF", Theme.ButtonOff, 3, {ID="Klik part untuk teleport ke posisinya.", EN="Click a part to teleport to its position."})
GotoPartBtn.Size = UDim2.new(1, -6, 0, 28)

SmartListUI:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() 
    SmartScroll.CanvasSize = UDim2.new(0, 0, 0, SmartListUI.AbsoluteContentSize.Y) 
    if SmartState.IsOpen then UpdateSmartSize() end 
end)

local SetSmartInspector, SetPartESP, SetGotoPart

SetSmartInspector = function(state)
    if state then SetPartESP(false); SetGotoPart(false) end
    ToggleStates.SmartInspector = state
    SmartInspectorBtn.Text = state and "Smart Inspector : ON" or "Smart Inspector : OFF"
    SmartInspectorBtn.BackgroundColor3 = state and Theme.ButtonOn or Theme.ButtonOff
    SetupToolConnections()
end

SetPartESP = function(state)
    if state then SetSmartInspector(false); SetGotoPart(false) end
    ToggleStates.PartESP = state
    PartESPBtn.Text = state and "ESP Part : ON" or "ESP Part : OFF"
    PartESPBtn.BackgroundColor3 = state and Theme.ButtonOn or Theme.ButtonOff
    if not state then ClearPartESP() end
    SetupToolConnections()
end

SetGotoPart = function(state)
    if state then SetSmartInspector(false); SetPartESP(false) end
    ToggleStates.GotoPart = state
    GotoPartBtn.Text = state and "Goto Part : ON" or "Goto Part : OFF"
    GotoPartBtn.BackgroundColor3 = state and Theme.ButtonOn or Theme.ButtonOff
    SetupToolConnections()
end

SmartInspectorBtn.Activated:Connect(function() SetSmartInspector(not ToggleStates.SmartInspector) end)
PartESPBtn.Activated:Connect(function() SetPartESP(not ToggleStates.PartESP) end)
GotoPartBtn.Activated:Connect(function() SetGotoPart(not ToggleStates.GotoPart) end)


-- // 5. TELEPORT TAB
local _, _, PlayerScroll, PlayerListUI, _, TogglePlayerBtn, PlayerState = CreateAccordion(TabTeleport, "Teleport to Player", Theme.ButtonDefault, 1, {ID="Teleport ke pemain lain.", EN="Teleport to other players."}, 140)
local function RefreshPlayers()
    for _, v in pairs(PlayerScroll:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP then
            local btn = Instance.new("TextButton", PlayerScroll); btn.Size = UDim2.new(1, -6, 0, 26); btn.BackgroundColor3 = Theme.BackgroundTop; btn.TextColor3 = Theme.Text; btn.Font = Enum.Font.GothamBold; btn.TextSize = 11; btn.Text = p.DisplayName .. " (@" .. p.Name .. ")"; Corner(btn, 6)
            btn.Activated:Connect(function() local my, tH = HRP(), p.Character and p.Character:FindFirstChild("HumanoidRootPart"); if my and tH then my.CFrame = tH.CFrame; Notify("TELEPORT", "Teleported to " .. p.DisplayName, 3) end end)
        end
    end
    PlayerScroll.CanvasSize = UDim2.new(0, 0, 0, PlayerListUI.AbsoluteContentSize.Y)
end
TogglePlayerBtn.Activated:Connect(function() if PlayerState.IsOpen then RefreshPlayers() end end)

local _, WPMenu, WPScroll, WPListUI, UpdateWPSize, _, WPState = CreateAccordion(TabTeleport, "Waypoints Menu", Theme.ButtonDefault, 2, {ID="Simpan posisi teleport.", EN="Save teleport positions."}, 140)
WPScroll.Size = UDim2.new(1, 0, 1, -32); WPScroll.Position = UDim2.new(0, 0, 0, 32); WPState.ExtraHeight = 32
local AddWPBtn = CreateButton(WPMenu, "+ Add Current Pos", Theme.ButtonOn, 1); AddWPBtn.Size = UDim2.new(1, 0, 0, 28); AddWPBtn.Position = UDim2.new(0, 0, 0, 0)
local WPContainer = Instance.new("Frame", Gui); WPContainer.Size = UDim2.new(0, 60, 0, 200); WPContainer.Position = UDim2.new(0, 10, 0, 10); WPContainer.BackgroundTransparency = 1

local function RefreshFloatingWPs()
    for _, child in pairs(WPContainer:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    local idx = 1
    for id, cf in pairs(Waypoints) do
        local btn = Instance.new("TextButton", WPContainer); btn.Size = UDim2.new(0, 50, 0, 30); btn.Position = UDim2.new(0, 0, 0, (idx-1)*35); btn.Text = "WP "..id; btn.BackgroundColor3 = Theme.ButtonDefault; btn.TextColor3 = Theme.Text; btn.Font = Enum.Font.GothamBold; btn.TextSize = 11; Corner(btn, 8)
        btn.Activated:Connect(function() local h = HRP(); if h then h.CFrame = cf end end); CustomDrag(btn, WPContainer); idx = idx + 1
    end
end

local function CreateDynamicWP(id, cfToSave)
    Waypoints[id] = cfToSave
    local Item = Instance.new("Frame", WPScroll); Item.Size = UDim2.new(1, 0, 0, 30); Item.BackgroundColor3 = Theme.BackgroundTop; Corner(Item, 8)
    local NameLbl = Instance.new("TextLabel", Item); NameLbl.Size = UDim2.new(0, 70, 1, 0); NameLbl.Position = UDim2.new(0, 10, 0, 0); NameLbl.BackgroundTransparency = 1; NameLbl.Text = "WP " .. id; NameLbl.TextColor3 = Theme.Text; NameLbl.Font = Enum.Font.GothamBold; NameLbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local TpBtn = Instance.new("TextButton", Item); TpBtn.Size = UDim2.new(0, 35, 0, 22); TpBtn.Position = UDim2.new(1, -110, 0.5, -11); TpBtn.Text = "Go"; TpBtn.BackgroundColor3 = Theme.ButtonDefault; TpBtn.TextColor3 = Theme.Text; TpBtn.Font = Enum.Font.GothamBold; Corner(TpBtn, 6)
    local EditBtn = Instance.new("TextButton", Item); EditBtn.Size = UDim2.new(0, 35, 0, 22); EditBtn.Position = UDim2.new(1, -70, 0.5, -11); EditBtn.Text = "Set"; EditBtn.BackgroundColor3 = Color3.fromHex("#F39C12"); EditBtn.TextColor3 = Color3.new(1, 1, 1); EditBtn.Font = Enum.Font.GothamBold; Corner(EditBtn, 6)
    local DelBtn = Instance.new("TextButton", Item); DelBtn.Size = UDim2.new(0, 25, 0, 22); DelBtn.Position = UDim2.new(1, -30, 0.5, -11); DelBtn.Text = "X"; DelBtn.Font = Enum.Font.GothamBold; DelBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50); DelBtn.TextColor3 = Color3.new(1,1,1); Corner(DelBtn, 6)
    
    TpBtn.Activated:Connect(function() local h = HRP(); if h and Waypoints[id] then h.CFrame = Waypoints[id] end end)
    EditBtn.Activated:Connect(function() 
        local h = HRP()
        if h then 
            Waypoints[id] = h.CFrame
            Notify("TELEPORT", "WP " .. id .. " ditimpa dengan posisi sekarang!", 3)
            RefreshFloatingWPs()
        end
    end)
    
    DelBtn.Activated:Connect(function() Waypoints[id] = nil; Item:Destroy(); WPScroll.CanvasSize = UDim2.new(0, 0, 0, WPListUI.AbsoluteContentSize.Y); UpdateWPSize(); RefreshFloatingWPs() end)
    WPScroll.CanvasSize = UDim2.new(0, 0, 0, WPListUI.AbsoluteContentSize.Y); UpdateWPSize(); RefreshFloatingWPs()
end

local function GetNextWPId()
    local id = 1
    while Waypoints[id] ~= nil do id = id + 1 end
    return id
end
AddWPBtn.Activated:Connect(function() local h = HRP(); if h then CreateDynamicWP(GetNextWPId(), h.CFrame) end end)

local _, _, HopScroll = CreateAccordion(TabTeleport, "Server Hop", Color3.fromHex("#6D28D9"), 3, {ID="Pindah ke server publik lain.", EN="Hop to another server."}, 100)
local function PerformServerHop(isCrowded)
    Notify("SERVER", CurrentLanguage == "ID" and "Nyari server..." or "Searching server...", 4)
    coroutine.wrap(function()
        local Api = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=" .. (isCrowded and "Desc" or "Asc") .. "&limit=100"
        local s, res = pcall(function() return HttpService:JSONDecode(game:HttpGet(Api)) end)
        if s and res and res.data then
            for _, srv in pairs(res.data) do
                if srv.playing and srv.playing < srv.maxPlayers and srv.id ~= game.JobId then
                    Notify("SERVER", CurrentLanguage == "ID" and "OTW pindah..." or "Teleporting...", 3); TeleportService:TeleportToPlaceInstance(game.PlaceId, srv.id, LP); return
                end
            end
            Notify("SERVER", "No server found, try again.", 3)
        else Notify("ERROR", "Failed to fetch servers.", 3) end
    end)()
end

local HopBtnContainer = Instance.new("Frame", HopScroll); HopBtnContainer.Size = UDim2.new(1, -6, 0, 28); HopBtnContainer.BackgroundTransparency = 1; HopBtnContainer.LayoutOrder = 1
local HopEmptyBtn = CreateButton(HopBtnContainer, "Hop (Sepi)", Color3.fromHex("#1D4ED8"), 1); HopEmptyBtn.Size = UDim2.new(0.5, -2, 1, 0); HopEmptyBtn.TextColor3 = Color3.new(1, 1, 1); HopEmptyBtn.Activated:Connect(function() PerformServerHop(false) end); RegisterDynamicLang(HopEmptyBtn, "Hop (Sepi)", "Hop (Empty)")
local HopCrowdedBtn = CreateButton(HopBtnContainer, "Hop (Rame)", Color3.fromHex("#BE185D"), 2); HopCrowdedBtn.Size = UDim2.new(0.5, -2, 1, 0); HopCrowdedBtn.AnchorPoint = Vector2.new(1, 0); HopCrowdedBtn.Position = UDim2.new(1, 0, 0, 0); HopCrowdedBtn.TextColor3 = Color3.new(1, 1, 1); HopCrowdedBtn.Activated:Connect(function() PerformServerHop(true) end); RegisterDynamicLang(HopCrowdedBtn, "Hop (Rame)", "Hop (Crowded)")
HopScroll.CanvasSize = UDim2.new(0, 0, 0, 30)

local RejoinBtn = CreateButton(TabTeleport, "Rejoin", Color3.fromHex("#E74C3C"), 4, {ID="Masuk ulang server sama.", EN="Rejoin same server."}); RejoinBtn.TextColor3 = Color3.new(1, 1, 1)
RejoinBtn.Activated:Connect(function() 
    Notify("SERVER", "Rejoining...", 3)
    if game.JobId == "" then TeleportService:Teleport(game.PlaceId, LP) else TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end
end)

-- // 6. CONFIG TAB
local ConfigInput = Instance.new("TextBox", TabConfig); ConfigInput.Size = UDim2.new(0, 220, 0, 28); ConfigInput.BackgroundColor3 = Theme.BackgroundTop; ConfigInput.TextColor3 = Theme.Text; ConfigInput.Font = Enum.Font.GothamBold; ConfigInput.TextSize = 11; ConfigInput.PlaceholderText = "(nama config)"; ConfigInput.Text = ""; ConfigInput.LayoutOrder = 1; Corner(ConfigInput, 8)
local SaveBtn = CreateButton(TabConfig, "Save Config", Color3.fromHex("#0F766E"), 2, {ID="Simpan setingan.", EN="Save settings."}); SaveBtn.TextColor3 = Color3.new(1, 1, 1)
local _, _, LoadScroll, LoadListUI, _, ToggleLoadBtn, LoadState = CreateAccordion(TabConfig, "Load Config", Color3.fromHex("#4338CA"), 3, {ID="Muat setingan.", EN="Load settings."}, 120)

local function GetConfigPath(name) return ConfigFolder .. "/" .. string.gsub(name=="" and "ConfigUtama" or name, "[^%w_]", "") .. ".json" end

local function LoadConfigData(path)
    if readfile and isfile and isfile(path) then
        local s, res = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
        if s and res then
            WalkSpeed = res.WalkSpeed or 16; JumpPower = res.JumpPower or 50; CurrentFOV = res.FOV or 70; FlySpeed = res.FlySpeed or 50; CurrentKeybind = Enum.KeyCode[res.Keybind or "RightControl"]; KeybindBtn.Text = "Keybind : " .. CurrentKeybind.Name
            SetSpeedVisual(WalkSpeed); SetJumpVisual(JumpPower); SetFOVVisual(CurrentFOV); SetFlySpeedVisual(FlySpeed)
            if res.InfJump ~= ToggleStates.InfJump then SetInfJump(res.InfJump) end; if res.Noclip ~= ToggleStates.Noclip then SetNoclip(res.Noclip) end
            if res.InstantPrompt ~= ToggleStates.InstantPrompt then SetInstantPrompt(res.InstantPrompt) end; if res.MaxZoom ~= ToggleStates.MaxZoom then SetMaxZoom(res.MaxZoom) end
            if res.AntiAFK ~= ToggleStates.AntiAFK then SetAntiAFK(res.AntiAFK) end; if res.PotatoMode ~= ToggleStates.PotatoMode then SetPotatoMode(res.PotatoMode) end
            if res.ESP ~= ToggleStates.ESP then SetESP(res.ESP) end
            if res.Fullbright ~= ToggleStates.Fullbright then SetFullbright(res.Fullbright) end
            if res.Nofog ~= ToggleStates.Nofog then SetNofog(res.Nofog) end
            if res.SmartInspector ~= ToggleStates.SmartInspector then SetSmartInspector(res.SmartInspector) end
            if res.PartESP ~= ToggleStates.PartESP then SetPartESP(res.PartESP) end
            if res.GotoPart ~= ToggleStates.GotoPart then SetGotoPart(res.GotoPart) end
            if res.Waypoints then for id, cData in pairs(res.Waypoints) do CreateDynamicWP(tonumber(id) or id, CFrame.new(unpack(cData))) end end
            Notify("CONFIG", "Loaded from " .. path, 3)
        else Notify("ERROR", "Data config corrupt!", 3) end
    else Notify("ERROR", "File config tidak ditemukan!", 3) end
end

local function RefreshConfigList()
    for _, v in pairs(LoadScroll:GetChildren()) do if v:IsA("Frame") or v:IsA("TextButton") then v:Destroy() end end
    if listfiles then
        for _, file in pairs(listfiles(ConfigFolder)) do
            if string.match(file, "%.json$") then
                local filename = string.match(file, "[\\/]([^\\/]+)%.json$") or string.match(file, "([^\\/]+)%.json$")
                
                local ItemFrame = Instance.new("Frame", LoadScroll); ItemFrame.Size = UDim2.new(1, -6, 0, 26); ItemFrame.BackgroundTransparency = 1
                local LoadBtn = Instance.new("TextButton", ItemFrame); LoadBtn.Size = UDim2.new(1, -30, 1, 0); LoadBtn.BackgroundColor3 = Theme.BackgroundTop; LoadBtn.TextColor3 = Theme.Text; LoadBtn.Font = Enum.Font.GothamBold; LoadBtn.TextSize = 11; LoadBtn.Text = filename; Corner(LoadBtn, 6)
                local DelBtn = Instance.new("TextButton", ItemFrame); DelBtn.Size = UDim2.new(0, 26, 1, 0); DelBtn.Position = UDim2.new(1, -26, 0, 0); DelBtn.Text = "X"; DelBtn.Font = Enum.Font.GothamBold; DelBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50); DelBtn.TextColor3 = Color3.new(1,1,1); Corner(DelBtn, 6)
                
                LoadBtn.Activated:Connect(function() LoadConfigData(file) end)
                DelBtn.Activated:Connect(function()
                    if delfile then
                        local success = pcall(function() delfile(file) end)
                        if success then Notify("CONFIG", filename .. " berhasil dihapus!", 3); RefreshConfigList() end
                    else Notify("ERROR", "Executor tidak support delfile!", 3) end
                end)
            end
        end
        LoadScroll.CanvasSize = UDim2.new(0, 0, 0, LoadListUI.AbsoluteContentSize.Y)
    end
end

ToggleLoadBtn.Activated:Connect(function() if LoadState.IsOpen then RefreshConfigList() end end)
SaveBtn.Activated:Connect(function()
    if writefile then
        local data = { WalkSpeed = WalkSpeed, JumpPower = JumpPower, FOV = CurrentFOV, FlySpeed = FlySpeed, Keybind = CurrentKeybind.Name, InfJump = ToggleStates.InfJump, Noclip = ToggleStates.Noclip, InstantPrompt = ToggleStates.InstantPrompt, MaxZoom = ToggleStates.MaxZoom, AntiAFK = ToggleStates.AntiAFK, PotatoMode = ToggleStates.PotatoMode, ESP = ToggleStates.ESP, Fullbright = ToggleStates.Fullbright, Nofog = ToggleStates.Nofog, SmartInspector = ToggleStates.SmartInspector, PartESP = ToggleStates.PartESP, GotoPart = ToggleStates.GotoPart, Waypoints = {} }
        for id, cf in pairs(Waypoints) do data.Waypoints[tostring(id)] = {cf:GetComponents()} end
        local s = pcall(function() writefile(GetConfigPath(ConfigInput.Text), HttpService:JSONEncode(data)) end)
        if s then Notify("CONFIG", "Saved to " .. GetConfigPath(ConfigInput.Text), 3); if LoadState.IsOpen then RefreshConfigList() end else Notify("ERROR", "Gagal menyimpan config!", 3) end
    else Notify("ERROR", "Executor tidak support WriteFile!", 3) end
end)

local UnloadBtn = CreateButton(TabConfig, "Unload Script", Color3.fromHex("#C0392B"), 4, {ID="Hapus script dari layar.", EN="Remove script."}); UnloadBtn.TextColor3 = Color3.new(1, 1, 1)
UnloadBtn.Activated:Connect(function()
    if StatsConnection then StatsConnection:Disconnect() end; if DescendantConnection then DescendantConnection:Disconnect() end
    if SpeedConnection then SpeedConnection:Disconnect() end; if JumpConnection then JumpConnection:Disconnect() end
    if ToolMouseConn then ToolMouseConn:Disconnect() end; if ToolTouchConn then ToolTouchConn:Disconnect() end
    for _, conn in pairs(Connections) do if conn and conn.Disconnect then conn:Disconnect() end end
    ClearInspector(); ClearPartESP()
    SetNoclip(false); SetFly(false); SetPotatoMode(false); SetInfJump(false); SetInstantPrompt(false); SetMaxZoom(false); SetAntiAFK(false); SetESP(false); SetSmartInspector(false); SetPartESP(false); SetGotoPart(false); SetFullbright(false); SetNofog(false)
    UIBlur:Destroy(); Gui:Destroy()
end)

for _, data in ipairs(DynamicLabels) do if data.Obj then data.Obj.Text = CurrentLanguage == "ID" and data.ID or data.EN end end

coroutine.wrap(function()
    ToggleUI(); local sound = Instance.new("Sound", workspace); sound.SoundId = "rbxassetid://6042053626"; sound.Volume = 0.5; sound:Play()
    Notify("SYSTEM", "Mamet Utility Pro V7.17.4 Loaded", 5)
    if AntiDetectActive then Notify("SECURITY", "Anti-Cheat Bypass Active", 5) end
    SafeDelay(5, function() sound:Destroy() end)
end)()

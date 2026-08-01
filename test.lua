--// MAMET UTILITY PRO (Google Pixel UI / Material Design 3 Visuals)
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local StatsService = game:GetService("Stats")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalizationService = game:GetService("LocalizationService")

local LP = Players.LocalPlayer

-- Shared States & Variables
local Waypoints = {}
local Connections = {} 
local ActiveSlider = nil 
local ActiveScroll = nil
local ToggleStates = {
    InfJump = false, Noclip = false, Fly = false,
    InstantPrompt = false, MaxZoom = false, AntiAFK = false, PotatoMode = false, ESP = false,
    Inspector = false, PartESP = false, Fullbright = false, Nofog = false
}

local WalkSpeed = 16
local JumpPower = 50
local FlySpeed = 50
local CurrentFOV = 70
local CurrentKeybind = Enum.KeyCode.RightControl
local Binding = false
local PrevNoclipState = false

local OriginalFB, OriginalFog = {}, {}
local ConfigFolder = "MametConfigs"
local AntiDetectActive = false

local Themes, Theme, IsDarkMode, CurrentLanguage, DynamicLabels, UIBlur, Gui = {}, nil, true, "ID", {}, nil, nil

-- Shared Functions Declaration
local Notify, ToggleUI, CreateButton, CreateSlider, CreateAccordion, SetBtnColor
local SetSpeedVisual, SetJumpVisual, SetInfJump, SetNoclip, SetFly, SetFlySpeedVisual
local SetFOVVisual, SetMaxZoom, SetPotatoMode, SetESP, SetFullbright, SetNofog
local SetInstantPrompt, SetAntiAFK, SetInspector, SetPartESP
local CreateDynamicWP, GetConfigPath, LoadConfigData, RefreshConfigList

-- ================= BLOK 1: INIT & ANTI-DETECT =================
do
    OriginalFB = {Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, GlobalShadows = Lighting.GlobalShadows}
    pcall(function() OriginalFB.ExposureCompensation = Lighting.ExposureCompensation end)
    OriginalFog = {FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart}

    pcall(function()
        if makefolder and (not isfolder or not isfolder(ConfigFolder)) then makefolder(ConfigFolder) end
    end)

    if game.CoreGui:FindFirstChild("MametUtility") then game.CoreGui.MametUtility:Destroy() end
    if Lighting:FindFirstChild("MametUIBlur") then Lighting.MametUIBlur:Destroy() end

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
end

-- ================= BLOK 2: HELPERS & UI BASE (MATERIAL 3) =================
do
    -- Palet Warna "Google Pixel UI / Material 3"
    Themes = {
        Light = { 
            Background = Color3.fromHex("#F8F9FA"), BackgroundTop = Color3.fromHex("#FFFFFF"), 
            BackgroundTab = Color3.fromHex("#F1F3F4"), ButtonDefault = Color3.fromHex("#1A73E8"), 
            ButtonOn = Color3.fromHex("#34A853"), ButtonOff = Color3.fromHex("#E8EAED"), 
            Text = Color3.fromHex("#202124"), Danger = Color3.fromHex("#EA4335")
        },
        Dark = { 
            Background = Color3.fromHex("#121212"), BackgroundTop = Color3.fromHex("#1E1E1E"), 
            BackgroundTab = Color3.fromHex("#272727"), ButtonDefault = Color3.fromHex("#8AB4F8"), 
            ButtonOn = Color3.fromHex("#81C995"), ButtonOff = Color3.fromHex("#3C4043"), 
            Text = Color3.fromHex("#E8EAED"), Danger = Color3.fromHex("#F28B82")
        }
    }
    Theme = Themes.Dark

    UIBlur = Instance.new("BlurEffect", Lighting)
    UIBlur.Name = "MametUIBlur"
    UIBlur.Size = 0 

    Gui = Instance.new("ScreenGui", game.CoreGui)
    Gui.Name = "MametUtility"

    local function Humanoid()
        local char = LP.Character
        return char and char:FindFirstChildOfClass("Humanoid") or nil
    end

    local function HRP()
        local char = LP.Character
        return char and char:FindFirstChild("HumanoidRootPart") or nil
    end

    local function Corner(obj, r)
        local c = Instance.new("UICorner", obj)
        c.CornerRadius = UDim.new(0, r or 16) -- Pixel cenderung memakai radius 16-24
    end

    -- Animasi Material (Smooth & Snappy)
    function SetBtnColor(btn, color)
        btn:SetAttribute("BaseColor", color)
        TweenService:Create(btn, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundColor3 = color}):Play()
    end

    local function AddHoverEffect(btn)
        btn.MouseEnter:Connect(function()
            local base = btn:GetAttribute("BaseColor") or btn.BackgroundColor3
            -- Material State Layer (Lerp ke putih/hitam 10%)
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = base:Lerp(IsDarkMode and Color3.new(0,0,0) or Color3.new(1,1,1), 0.1)}):Play()
        end)
        btn.MouseLeave:Connect(function()
            local base = btn:GetAttribute("BaseColor") or btn.BackgroundColor3
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = base}):Play()
        end)
    end

    local function CustomDrag(hitPart, targetGui)
        local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
        local conn1 = hitPart.InputBegan:Connect(function(input)
            if ActiveSlider or ActiveScroll then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then 
                dragging = true; dragStart = input.Position; startPos = targetGui.Position 
                input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end) 
            end
        end)
        local conn2 = hitPart.InputChanged:Connect(function(input) 
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end 
        end)
        local conn3 = UIS.InputChanged:Connect(function(input)
            if input == dragInput and dragging and not ActiveSlider and not ActiveScroll then
                local delta = input.Position - dragStart
                targetGui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
        table.insert(Connections, conn1); table.insert(Connections, conn2); table.insert(Connections, conn3)
    end

    local ActiveNotifications = {}
    function Notify(title, message, duration)
        duration = duration or 5
        for _, notif in ipairs(ActiveNotifications) do
            if notif and notif.Parent then 
                TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 1, notif.Position.Y.Offset - 65)}):Play() 
            end
        end
        local Notif = Instance.new("Frame", Gui)
        Notif.Size = UDim2.new(0, 260, 0, 60)
        Notif.AnchorPoint = Vector2.new(0.5, 0)
        Notif.Position = UDim2.new(0.5, 0, 1, 80)
        Notif.BackgroundColor3 = Theme.BackgroundTop; Notif.BorderSizePixel = 0; Corner(Notif, 24) -- Pill Shape Snackbar
        Notif:SetAttribute("BaseColor", Theme.BackgroundTop)
        
        local stroke = Instance.new("UIStroke", Notif)
        stroke.Color = Color3.new(0,0,0); stroke.Transparency = 0.8; stroke.Thickness = 1
        
        local TxtTitle = Instance.new("TextLabel", Notif)
        TxtTitle.Size = UDim2.new(1, -20, 0, 20); TxtTitle.Position = UDim2.new(0, 15, 0, 8); TxtTitle.Text = title
        TxtTitle.TextColor3 = Theme.ButtonDefault; TxtTitle.Font = Enum.Font.RobotoMedium; TxtTitle.TextSize = 13
        TxtTitle.BackgroundTransparency = 1; TxtTitle.TextXAlignment = Enum.TextXAlignment.Left
        
        local TxtMsg = Instance.new("TextLabel", Notif)
        TxtMsg.Size = UDim2.new(1, -20, 0, 20); TxtMsg.Position = UDim2.new(0, 15, 0, 28); TxtMsg.Text = message
        TxtMsg.TextColor3 = Theme.Text; TxtMsg.Font = Enum.Font.Roboto; TxtMsg.TextSize = 11
        TxtMsg.BackgroundTransparency = 1; TxtMsg.TextXAlignment = Enum.TextXAlignment.Left; TxtMsg.TextWrapped = true
        
        table.insert(ActiveNotifications, Notif)
        TweenService:Create(Notif, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 1, -20)}):Play()
        
        delay(duration, function()
            local out = TweenService:Create(Notif, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0.5, 0, 1, 80)})
            out:Play(); out.Completed:Wait()
            for i, v in ipairs(ActiveNotifications) do if v == Notif then table.remove(ActiveNotifications, i) break end end
            Notif:Destroy()
        end)
    end

    local function RegisterDynamicLang(obj, textID, textEN)
        table.insert(DynamicLabels, {Obj = obj, ID = textID, EN = textEN})
        obj.Text = CurrentLanguage == "ID" and textID or textEN 
    end

    _MametHelpers = { Humanoid = Humanoid, HRP = HRP, Corner = Corner, AddHoverEffect = AddHoverEffect, CustomDrag = CustomDrag, RegisterDynamicLang = RegisterDynamicLang }
end

local Humanoid, HRP, Corner, AddHoverEffect, CustomDrag = _MametHelpers.Humanoid, _MametHelpers.HRP, _MametHelpers.Corner, _MametHelpers.AddHoverEffect, _MametHelpers.CustomDrag
local RegisterDynamicLang = _MametHelpers.RegisterDynamicLang

-- ================= BLOK 3: MAIN UI & TABS (PIXEL LAYOUT) =================
do
    local Open = Instance.new("TextButton", Gui)
    Open.Size = UDim2.new(0, 40, 0, 40); Open.Position = UDim2.new(0, 15, 0.5, -20)
    Open.BackgroundColor3 = Theme.ButtonDefault
    Open.Text = "⚡"; Open.TextColor3 = Color3.new(1,1,1)
    Open.Font = Enum.Font.RobotoBold; Open.TextSize = 18
    Corner(Open, 999) -- Circle
    AddHoverEffect(Open); SetBtnColor(Open, Theme.ButtonDefault); CustomDrag(Open, Open)

    local Frame = Instance.new("Frame", Gui)
    Frame.AnchorPoint = Vector2.new(0.5, 0.5); Frame.Position = UDim2.new(0.5, 0, 0.5, -50)
    Frame.Size = UDim2.new(0, 400, 0, 0); Frame.BackgroundColor3 = Theme.Background
    Frame.Visible = false; Frame.ClipsDescendants = true; Corner(Frame, 24)
    
    local FrameStroke = Instance.new("UIStroke", Frame)
    FrameStroke.Color = Color3.new(0,0,0); FrameStroke.Transparency = 0.8; FrameStroke.Thickness = 1

    local Top = Instance.new("TextButton", Frame)
    Top.Text = ""; Top.AutoButtonColor = false; Top.Selectable = false
    Top.Size = UDim2.new(1, 0, 0, 48); Top.BackgroundColor3 = Theme.BackgroundTop
    CustomDrag(Top, Frame); Corner(Top, 24)

    local TopBlocker = Instance.new("Frame", Top)
    TopBlocker.Size = UDim2.new(1, 0, 0, 15); TopBlocker.Position = UDim2.new(0, 0, 1, -15)
    TopBlocker.BackgroundColor3 = Theme.BackgroundTop; TopBlocker.BorderSizePixel = 0

    local HeaderText = Instance.new("TextLabel", Top)
    HeaderText.Size = UDim2.new(1, -150, 1, 0); HeaderText.Position = UDim2.new(0, 15, 0, 0)
    HeaderText.BackgroundTransparency = 1; HeaderText.TextColor3 = Theme.Text
    HeaderText.Font = Enum.Font.RobotoMedium; HeaderText.TextSize = 13
    HeaderText.TextXAlignment = Enum.TextXAlignment.Left; HeaderText.RichText = true

    local fps, startTime, frames, lastPingHex, lastPingValue = 0, os.clock(), 0, "#8AB4F8", 0
    local StatsConnection = RunService.RenderStepped:Connect(function()
        frames = frames + 1
        local now = os.clock()
        if now - startTime >= 1 then 
            fps = frames; frames = 0; startTime = now 
            pcall(function() lastPingValue = tonumber(StatsService.Network.ServerStatsItem["Data Ping"]:GetValueString():match("%d+")) or 0 end)
            lastPingHex = (lastPingValue >= 250) and "#F28B82" or ((lastPingValue >= 150) and "#FDD663" or ((lastPingValue >= 80) and "#81C995" or "#8AB4F8"))
        end
        HeaderText.Text = "MAMET PRO │ " .. os.date("%H:%M") .. " │ " .. fps .. " FPS │ <font color='" .. lastPingHex .. "'>" .. lastPingValue .. " ms</font>"
    end)
    table.insert(Connections, StatsConnection)

    local TabPanel = Instance.new("Frame", Frame)
    TabPanel.Size = UDim2.new(0, 110, 1, -48); TabPanel.Position = UDim2.new(0, 0, 0, 48)
    TabPanel.BackgroundColor3 = Theme.BackgroundTab; TabPanel.BorderSizePixel = 0; Corner(TabPanel, 24)

    local TabPanelTopFixer = Instance.new("Frame", TabPanel)
    TabPanelTopFixer.Size = UDim2.new(1, 0, 0, 15); TabPanelTopFixer.BackgroundColor3 = Theme.BackgroundTab; TabPanelTopFixer.BorderSizePixel = 0

    local TabListLayout = Instance.new("UIListLayout", TabPanel)
    TabListLayout.SortOrder = Enum.SortOrder.LayoutOrder; TabListLayout.Padding = UDim.new(0, 6); TabListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    local PageContainer = Instance.new("Frame", Frame)
    PageContainer.Size = UDim2.new(1, -110, 1, -48); PageContainer.Position = UDim2.new(0, 110, 0, 48)
    PageContainer.BackgroundTransparency = 1

    local Tabs, CurrentTab = {}, nil

    function CreateTab(name, icon, layoutOrder)
        local TabBtn = Instance.new("TextButton", TabPanel)
        TabBtn.Size = UDim2.new(0, 98, 0, 34); TabBtn.BackgroundColor3 = Theme.BackgroundTop
        TabBtn.Text = "  " .. icon .. "  " .. name; TabBtn.AutoButtonColor = false; TabBtn.Selectable = false
        TabBtn.TextColor3 = Theme.Text; TabBtn.Font = Enum.Font.RobotoMedium; TabBtn.TextSize = 11
        TabBtn.LayoutOrder = layoutOrder; TabBtn.TextXAlignment = Enum.TextXAlignment.Left
        Corner(TabBtn, 999); AddHoverEffect(TabBtn) -- Pill shape
        SetBtnColor(TabBtn, Theme.BackgroundTop)
        
        local UIPad = Instance.new("UIPadding", TabBtn); UIPad.PaddingLeft = UDim.new(0, 10)
        
        local PageWrapper = Instance.new("Frame", PageContainer)
        PageWrapper.Size = UDim2.new(1, 0, 1, 0); PageWrapper.BackgroundTransparency = 1; PageWrapper.Visible = false
        
        local SearchBox = Instance.new("TextBox", PageWrapper)
        SearchBox.Size = UDim2.new(1, -20, 0, 36); SearchBox.Position = UDim2.new(0, 10, 0, 8)
        SearchBox.BackgroundColor3 = Theme.BackgroundTop; SearchBox.TextColor3 = Theme.Text
        SearchBox.Font = Enum.Font.Roboto; SearchBox.TextSize = 12
        SearchBox.PlaceholderText = "Cari fitur..."; SearchBox.Text = ""; SearchBox.ClearTextOnFocus = false
        SearchBox.Visible = false; Corner(SearchBox, 999) -- Pill
        SearchBox:SetAttribute("BaseColor", Theme.BackgroundTop)
        
        local SearchPad = Instance.new("UIPadding", SearchBox)
        SearchPad.PaddingLeft = UDim.new(0, 15)
        
        local Page = Instance.new("ScrollingFrame", PageWrapper)
        Page.Size = UDim2.new(1, 0, 1, 0); Page.Position = UDim2.new(0, 0, 0, 0)
        Page.BackgroundTransparency = 1; Page.BorderSizePixel = 0; Page.ScrollBarThickness = 3; Page.ScrollBarImageColor3 = Theme.ButtonDefault
        
        local UIList = Instance.new("UIListLayout", Page)
        UIList.SortOrder = Enum.SortOrder.LayoutOrder; UIList.Padding = UDim.new(0, 8); UIList.HorizontalAlignment = Enum.HorizontalAlignment.Center
        
        local PageSpacer = Instance.new("Frame", Page)
        PageSpacer.Size = UDim2.new(1, 0, 0, 8); PageSpacer.BackgroundTransparency = 1; PageSpacer.LayoutOrder = 0
        
        UIList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() Page.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y + 15) end)

        SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
            local txt = string.lower(string.trim(SearchBox.Text))
            for _, child in pairs(Page:GetChildren()) do
                if child:IsA("GuiObject") and child ~= PageSpacer then
                    local match = false
                    if txt == "" then match = true else
                        local key = child:GetAttribute("SearchKey")
                        if key and string.find(key, txt, 1, true) then match = true end
                    end
                    child.Visible = match
                end
            end
        end)

        TabBtn.Activated:Connect(function()
            if CurrentTab == name then return end
            for _, v in pairs(Tabs) do 
                v.Wrapper.Visible = false
                SetBtnColor(v.Btn, Theme.BackgroundTop)
                v.Btn.TextColor3 = Theme.Text
            end
            PageWrapper.Visible = true
            SetBtnColor(TabBtn, Theme.ButtonDefault)
            TabBtn.TextColor3 = Color3.new(1,1,1); CurrentTab = name
        end)
        
        table.insert(Tabs, {Name = name, Btn = TabBtn, Wrapper = PageWrapper, Page = Page, Search = SearchBox})
        return Page, TabBtn, PageWrapper
    end

    local UI_Open = false
    function ToggleUI()
        UI_Open = not UI_Open
        if UI_Open then 
            Frame.Visible = true; Frame.Size = UDim2.new(0, 400, 0, 0)
            TweenService:Create(Frame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 400, 0, 320)}):Play()
            TweenService:Create(UIBlur, TweenInfo.new(0.4), {Size = 24}):Play()
        else
            local tw = TweenService:Create(Frame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Size = UDim2.new(0, 400, 0, 0)})
            tw:Play(); TweenService:Create(UIBlur, TweenInfo.new(0.3), {Size = 0}):Play()
            tw.Completed:Connect(function() if not UI_Open then Frame.Visible = false end end)
        end
    end

    local Close = Instance.new("TextButton", Top)
    Close.Size = UDim2.new(0, 30, 0, 30); Close.Position = UDim2.new(1, -40, 0.5, -15); Close.Text = "✕"
    Close.Font = Enum.Font.RobotoBold; Close.TextSize = 14; Close.AutoButtonColor = false
    Close.TextColor3 = Color3.new(1,1,1)
    Corner(Close, 999); AddHoverEffect(Close); SetBtnColor(Close, Theme.Danger)
    Close.Activated:Connect(ToggleUI); Open.Activated:Connect(ToggleUI)

    local ThemeToggle = Instance.new("TextButton", Top)
    ThemeToggle.Size = UDim2.new(0, 30, 0, 30); ThemeToggle.Position = UDim2.new(1, -78, 0.5, -15)
    ThemeToggle.Text = "☀️"; ThemeToggle.TextSize = 14; ThemeToggle.Font = Enum.Font.RobotoMedium
    ThemeToggle.AutoButtonColor = false; ThemeToggle.BackgroundTransparency = 1; ThemeToggle.TextColor3 = Theme.Text
    ThemeToggle.Activated:Connect(function()
        IsDarkMode = not IsDarkMode; ThemeToggle.Text = IsDarkMode and "☀️" or "🌙"
        local from = Theme
        local to = IsDarkMode and Themes.Dark or Themes.Light
        Theme = to
        
        local colorMap = {}
        for k, v in pairs(from) do colorMap[v:ToHex()] = to[k] end

        for _, obj in pairs(Gui:GetDescendants()) do
            pcall(function()
                local baseCol = obj:GetAttribute("BaseColor")
                if baseCol and colorMap[baseCol:ToHex()] then
                    SetBtnColor(obj, colorMap[baseCol:ToHex()])
                elseif obj:IsA("GuiObject") and colorMap[obj.BackgroundColor3:ToHex()] and obj ~= ThemeToggle and obj ~= LangToggle and obj ~= SearchToggle then
                    SetBtnColor(obj, colorMap[obj.BackgroundColor3:ToHex()])
                end
                if (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) and colorMap[obj.TextColor3:ToHex()] then 
                    TweenService:Create(obj, TweenInfo.new(0.3), {TextColor3 = colorMap[obj.TextColor3:ToHex()]}):Play() 
                end
                if obj:IsA("ScrollingFrame") and colorMap[obj.ScrollBarImageColor3:ToHex()] then 
                    obj.ScrollBarImageColor3 = colorMap[obj.ScrollBarImageColor3:ToHex()] 
                end
            end)
        end
        for _, v in pairs(Tabs) do
            if CurrentTab == v.Name then SetBtnColor(v.Btn, Theme.ButtonDefault); v.Btn.TextColor3 = Color3.new(1,1,1) else SetBtnColor(v.Btn, Theme.BackgroundTop); v.Btn.TextColor3 = Theme.Text end
        end
    end)

    local LangToggle = Instance.new("TextButton", Top)
    LangToggle.Size = UDim2.new(0, 30, 0, 30); LangToggle.Position = UDim2.new(1, -116, 0.5, -15)
    LangToggle.Text = "🌐"; LangToggle.TextSize = 14; LangToggle.Font = Enum.Font.RobotoMedium
    LangToggle.AutoButtonColor = false; LangToggle.BackgroundTransparency = 1; LangToggle.TextColor3 = Theme.Text
    LangToggle.Activated:Connect(function()
        CurrentLanguage = CurrentLanguage == "ID" and "EN" or "ID"
        Notify("LANGUAGE", CurrentLanguage == "ID" and "Bahasa diubah ke Indonesia" or "Language changed to English", 3)
        for _, data in ipairs(DynamicLabels) do if data.Obj then data.Obj.Text = CurrentLanguage == "ID" and data.ID or data.EN end end
    end)

    local SearchToggle = Instance.new("TextButton", Top)
    SearchToggle.Size = UDim2.new(0, 30, 0, 30); SearchToggle.Position = UDim2.new(1, -154, 0.5, -15)
    SearchToggle.Text = "🔍"; SearchToggle.TextSize = 14; SearchToggle.Font = Enum.Font.RobotoMedium
    SearchToggle.AutoButtonColor = false; SearchToggle.BackgroundTransparency = 1; SearchToggle.TextColor3 = Theme.Text
    SearchToggle.Activated:Connect(function()
        for _, v in pairs(Tabs) do
            if v.Name == CurrentTab then
                v.Search.Visible = not v.Search.Visible
                if v.Search.Visible then
                    v.Page.Size = UDim2.new(1, 0, 1, -52)
                    v.Page.Position = UDim2.new(0, 0, 0, 52)
                else
                    v.Page.Size = UDim2.new(1, 0, 1, 0)
                    v.Page.Position = UDim2.new(0, 0, 0, 0)
                end
            end
        end
    end)
end

-- ================= BLOK 4: UI COMPONENTS (MATERIAL WIDGETS) =================
do
    local function GetInfoString(info) return (type(info) == "table") and (info[CurrentLanguage] or info.ID) or info end

    function CreateButton(parent, text, color, layoutOrder, infoText)
        local MainBtn = Instance.new("TextButton", parent)
        MainBtn.Size = UDim2.new(0, 240, 0, 36); MainBtn.Text = text
        MainBtn.TextColor3 = Color3.new(1,1,1); MainBtn.TextSize = 12; MainBtn.Font = Enum.Font.RobotoMedium
        MainBtn.AutoButtonColor = false; MainBtn.LayoutOrder = layoutOrder; Corner(MainBtn, 999) -- Pill Shape
        SetBtnColor(MainBtn, color); AddHoverEffect(MainBtn)
        
        local keyStr = string.lower(text)
        if infoText then keyStr = keyStr .. " " .. string.lower(GetInfoString(infoText)) end
        MainBtn:SetAttribute("SearchKey", keyStr)
        
        if infoText then
            local InfoBtn = Instance.new("TextButton", MainBtn)
            InfoBtn.Size = UDim2.new(0, 36, 1, 0); InfoBtn.Position = UDim2.new(1, -36, 0, 0)
            InfoBtn.BackgroundTransparency = 1; InfoBtn.Text = "ⓘ"; InfoBtn.TextColor3 = Color3.new(1,1,1)
            InfoBtn.TextSize = 14; InfoBtn.Font = Enum.Font.RobotoMedium; InfoBtn.AutoButtonColor = false; InfoBtn.ZIndex = 2
            
            local TooltipUI = Instance.new("Frame", Gui)
            TooltipUI.BackgroundColor3 = Theme.BackgroundTop; TooltipUI.Size = UDim2.new(0, 200, 0, 30)
            TooltipUI.Visible = false; TooltipUI.ZIndex = 100; Corner(TooltipUI, 12) -- Material Card
            TooltipUI:SetAttribute("BaseColor", Theme.BackgroundTop)
            local TooltipText = Instance.new("TextLabel", TooltipUI)
            TooltipText.Size = UDim2.new(1, -10, 1, -10); TooltipText.Position = UDim2.new(0, 5, 0,5)
            TooltipText.BackgroundTransparency = 1; TooltipText.TextColor3 = Theme.Text
            TooltipText.Font = Enum.Font.Roboto; TooltipText.TextSize = 11
            TooltipText.TextWrapped = true; TooltipText.TextXAlignment = Enum.TextXAlignment.Center

            local lastTooltipUpdate = 0
            UIS.InputChanged:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseMovement and TooltipUI.Visible then
                    local now = os.clock()
                    if now - lastTooltipUpdate > 0.05 then
                        lastTooltipUpdate = now; local targetX = input.Position.X + 15; local targetY = input.Position.Y + 15
                        local cam = workspace.CurrentCamera
                        if cam and cam.ViewportSize then
                            targetX = math.clamp(targetX, 0, cam.ViewportSize.X - TooltipUI.AbsoluteSize.X - 10)
                            targetY = math.clamp(targetY, 0, cam.ViewportSize.Y - TooltipUI.AbsoluteSize.Y - 10)
                        end
                        TooltipUI.Position = UDim2.new(0, targetX, 0, targetY)
                    end
                end
            end)

            InfoBtn.MouseEnter:Connect(function()
                if UIS:GetLastInputType() == Enum.UserInputType.Touch then return end
                InfoBtn.TextColor3 = Theme.ButtonOn; TooltipText.Text = GetInfoString(infoText); TooltipText.Size = UDim2.new(1, -10, 0, 1000)
                TooltipUI.Size = UDim2.new(0, math.clamp(TooltipText.TextBounds.X + 20, 150, 250), 0, TooltipText.TextBounds.Y + 10)
                TooltipText.Size = UDim2.new(1, -10, 1, -10); TooltipUI.Visible = true
            end)
            InfoBtn.MouseLeave:Connect(function() InfoBtn.TextColor3 = Color3.new(1,1,1); TooltipUI.Visible = false end)
            InfoBtn.Activated:Connect(function() TooltipUI.Visible = false; Notify("INFO", GetInfoString(infoText), 6) end)
        end
        return MainBtn
    end

    function CreateSlider(parent, name, min, max, default, color, layoutOrder, callback)
        local Holder = Instance.new("Frame", parent)
        Holder.Size = UDim2.new(0, 240, 0, 50); Holder.BackgroundTransparency = 1; Holder.LayoutOrder = layoutOrder
        Holder:SetAttribute("SearchKey", string.lower(name))
        
        local Label = Instance.new("TextLabel", Holder)
        Label.Size = UDim2.new(1, 0, 0, 18); Label.TextColor3 = Theme.Text; Label.TextSize = 12
        Label.Text = name .. " : " .. default; Label.Font = Enum.Font.RobotoMedium; Label.BackgroundTransparency = 1
        Label.TextXAlignment = Enum.TextXAlignment.Left
        
        local Bar = Instance.new("TextButton", Holder)
        Bar.Text = ""; Bar.AutoButtonColor = false; Bar.Position = UDim2.new(0, 0, 0, 24)
        Bar.Size = UDim2.new(1, 0, 0, 24); Bar.BackgroundTransparency = 1
        
        local VBar = Instance.new("Frame", Bar)
        VBar.Size = UDim2.new(1, 0, 0, 6); VBar.Position = UDim2.new(0, 0, 0.5, -3)
        VBar.BackgroundColor3 = Theme.BackgroundTab; Corner(VBar, 999)
        VBar:SetAttribute("BaseColor", Theme.BackgroundTab)
        
        local Fill = Instance.new("Frame", VBar); Fill.BackgroundColor3 = color; Corner(Fill, 999)
        Fill:SetAttribute("BaseColor", color)
        local Handle = Instance.new("Frame", VBar)
        Handle.Size = UDim2.new(0, 20, 0, 20); Handle.AnchorPoint = Vector2.new(0.5, 0.5)
        Handle.Position = UDim2.new(0, 0, 0.5, 0); Handle.BackgroundColor3 = Color3.new(1,1,1); Corner(Handle, 999)
        Handle:SetAttribute("BaseColor", Color3.new(1,1,1))
        local HandleStroke = Instance.new("UIStroke", Handle); HandleStroke.Color = color; HandleStroke.Thickness = 2

        local function Update(x)
            local p = math.clamp((x - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
            local val = math.floor(min + ((max - min) * p) + 0.5)
            Fill.Size = UDim2.new(p, 0, 1, 0); Handle.Position = UDim2.new(p, 0, 0.5, 0)
            Label.Text = name .. " : " .. val; callback(val)
        end
        
        Handle.InputBegan:Connect(function(input) 
            if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and ActiveSlider == nil then 
                ActiveSlider = Handle; parent.ScrollingEnabled = false 
            end 
        end)
        UIS.InputChanged:Connect(function(input) 
            if ActiveSlider == Handle and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then Update(input.Position.X) end 
        end)
        UIS.InputEnded:Connect(function(input) 
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then 
                if ActiveSlider == Handle then ActiveSlider = nil; parent.ScrollingEnabled = true end 
            end 
        end)

        local startX
        Bar.InputBegan:Connect(function(input) 
            if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and ActiveSlider == nil then startX = input.Position.X end 
        end)
        Bar.InputEnded:Connect(function(input) 
            if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and startX then 
                if math.abs(input.Position.X - startX) < 5 and ActiveSlider == nil then Update(input.Position.X) end; startX = nil 
            end 
        end)
        
        local function SetVisual(val)
            local p = math.clamp((val - min) / (max - min), 0, 1)
            Fill.Size = UDim2.new(p, 0, 1, 0); Handle.Position = UDim2.new(p, 0, 0.5, 0)
            Label.Text = name .. " : " .. val 
        end
        SetVisual(default); return SetVisual
    end

    function CreateAccordion(parent, title, color, layoutOrder, infoText, maxHeight)
        maxHeight = maxHeight or 140
        local Holder = Instance.new("Frame", parent)
        Holder.Size = UDim2.new(0, 240, 0, 36); Holder.BackgroundTransparency = 1
        Holder.ClipsDescendants = true; Holder.LayoutOrder = layoutOrder
        
        local keyStr = string.lower(title)
        if infoText then keyStr = keyStr .. " " .. string.lower(GetInfoString(infoText)) end
        Holder:SetAttribute("SearchKey", keyStr)
        
        local ToggleBtn = CreateButton(Holder, title .. " ▼", color, 1, infoText)
        local Menu = Instance.new("Frame", Holder)
        Menu.Size = UDim2.new(1, 0, 1, -40); Menu.Position = UDim2.new(0, 0, 0, 40); Menu.BackgroundTransparency = 1
        
        local Scroll = Instance.new("ScrollingFrame", Menu)
        Scroll.Size = UDim2.new(1, 0, 1, 0); Scroll.BackgroundTransparency = 1
        Scroll.BorderSizePixel = 0; Scroll.ScrollBarThickness = 3; Scroll.ScrollBarImageColor3 = Theme.ButtonDefault
        
        local ListUI = Instance.new("UIListLayout", Scroll)
        ListUI.Padding = UDim.new(0, 6); ListUI.SortOrder = Enum.SortOrder.LayoutOrder
        local State = {IsOpen = false, ExtraHeight = 0}

        Scroll.InputBegan:Connect(function(input) 
            if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and ActiveScroll == nil then 
                ActiveScroll = Scroll; if parent:IsA("ScrollingFrame") then parent.ScrollingEnabled = false end 
            end 
        end)
        UIS.InputEnded:Connect(function(input) 
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then 
                if ActiveScroll == Scroll then ActiveScroll = nil; if parent:IsA("ScrollingFrame") then parent.ScrollingEnabled = true end end 
            end 
        end)

        local function UpdateSize() TweenService:Create(Holder, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0, 240, 0, State.IsOpen and (40 + math.clamp(ListUI.AbsoluteContentSize.Y + State.ExtraHeight, 0, maxHeight)) or 36)}):Play() end
        ToggleBtn.Activated:Connect(function() State.IsOpen = not State.IsOpen; ToggleBtn.Text = State.IsOpen and (title .. " ▲") or (title .. " ▼"); UpdateSize() end)
        return Holder, Menu, Scroll, ListUI, UpdateSize, ToggleBtn, State
    end
end

-- ================= BLOK 5: CHARACTER HANDLER & TABS =================
do
    local TabProfile, BtnProfile, WrapProf = CreateTab("Profile", "👤", 1)
    local TabMovement, BtnMovement, WrapMov = CreateTab("Movement", "🏃", 2)
    local TabVisual, BtnVisual, WrapVis = CreateTab("Visual", "👁️", 3)
    local TabUtility, BtnUtility, WrapUtl = CreateTab("Utility", "⚙️", 4)
    local TabTeleport, BtnTeleport, WrapTel = CreateTab("Teleport", "🌍", 5)
    local TabConfig, BtnConfig, WrapCfg = CreateTab("Settings", "💾", 6)

    SetBtnColor(BtnProfile, Theme.ButtonDefault); BtnProfile.TextColor3 = Color3.new(1,1,1)
    WrapProf.Visible = true; CurrentTab = "Profile"

    local SpeedConnection, JumpConnection
    local function ApplyProperties(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if hum then
            hum.WalkSpeed = WalkSpeed; hum.JumpPower = JumpPower; hum.UseJumpPower = true
            if SpeedConnection then SpeedConnection:Disconnect() end
            if JumpConnection then JumpConnection:Disconnect() end
            SpeedConnection = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function() if hum.WalkSpeed ~= WalkSpeed then hum.WalkSpeed = WalkSpeed end end)
            JumpConnection = hum:GetPropertyChangedSignal("JumpPower"):Connect(function() if hum.JumpPower ~= JumpPower then hum.JumpPower = JumpPower end end)
        end
    end
    if LP.Character then ApplyProperties(LP.Character) end
    Connections.CharAdded = LP.CharacterAdded:Connect(ApplyProperties)
    
    _MametTabs = { TabProfile=TabProfile, TabMovement=TabMovement, TabVisual=TabVisual, TabUtility=TabUtility, TabTeleport=TabTeleport, TabConfig=TabConfig }
end

local TabProfile = _MametTabs.TabProfile
local TabMovement = _MametTabs.TabMovement
local TabVisual = _MametTabs.TabVisual
local TabUtility = _MametTabs.TabUtility
local TabTeleport = _MametTabs.TabTeleport
local TabConfig = _MametTabs.TabConfig

-- ================= BLOK 6: PROFILE TAB =================
do
    local ProfileListUI = Instance.new("UIListLayout", TabProfile)
    ProfileListUI.SortOrder = Enum.SortOrder.LayoutOrder; ProfileListUI.Padding = UDim.new(0, 10); ProfileListUI.HorizontalAlignment = Enum.HorizontalAlignment.Center
    ProfileListUI:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() TabProfile.CanvasSize = UDim2.new(0, 0, 0, ProfileListUI.AbsoluteContentSize.Y + 20) end)

    local function CreateRow(parent, labelText)
        local Row = Instance.new("Frame", parent); Row.BackgroundTransparency = 1; Row.Size = UDim2.new(1, -20, 0, 20)
        local Lbl = Instance.new("TextLabel", Row)
        Lbl.BackgroundTransparency = 1; Lbl.Size = UDim2.new(0.45, 0, 1, 0); Lbl.Position = UDim2.new(0, 10, 0, 0)
        Lbl.Font = Enum.Font.Roboto; Lbl.Text = labelText; Lbl.TextColor3 = Theme.Text; Lbl.TextSize = 11; Lbl.TextXAlignment = Enum.TextXAlignment.Left
        local Val = Instance.new("TextLabel", Row)
        Val.BackgroundTransparency = 1; Val.Size = UDim2.new(0.5, 0, 1, 0); Val.Position = UDim2.new(0.45, 0, 0, 0)
        Val.Font = Enum.Font.RobotoMedium; Val.Text = "Loading..."; Val.TextColor3 = Theme.Text; Val.TextSize = 11; Val.TextXAlignment = Enum.TextXAlignment.Right; Val.TextTruncate = Enum.TextTruncate.AtEnd
        return Val
    end

    local function CreateProfileAccordion(title, layoutOrder, maxHeight)
        local _, _, Scroll, ListUI, UpdateSize, _, State = CreateAccordion(TabProfile, title, Theme.BackgroundTop, layoutOrder, nil, maxHeight)
        ListUI:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() Scroll.CanvasSize = UDim2.new(0, 0, 0, ListUI.AbsoluteContentSize.Y); if State.IsOpen then UpdateSize() end end)
        return Scroll
    end

    local AvatarFrame = Instance.new("Frame", TabProfile)
    AvatarFrame.Size = UDim2.new(0, 72, 0, 72); AvatarFrame.BackgroundColor3 = Theme.BackgroundTop; AvatarFrame.LayoutOrder = 1; Corner(AvatarFrame, 999) -- Circular
    AvatarFrame:SetAttribute("BaseColor", Theme.BackgroundTop)
    local AvatarImg = Instance.new("ImageLabel", AvatarFrame); AvatarImg.Size = UDim2.new(1, 0, 1, 0); AvatarImg.BackgroundTransparency = 1; Corner(AvatarImg, 999)
    coroutine.wrap(function() local s, img = pcall(function() return Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420) end); if s then AvatarImg.Image = img end end)()

    local SecAcc = CreateProfileAccordion("Account Information", 2, 200)
    CreateRow(SecAcc, "Display Name").Text = LP.DisplayName
    CreateRow(SecAcc, "Username").Text = "@" .. LP.Name
    CreateRow(SecAcc, "User ID").Text = tostring(LP.UserId)
    CreateRow(SecAcc, "Account Age").Text = LP.AccountAge .. " Days"
    CreateRow(SecAcc, "Join Date").Text = os.date("%Y-%m-%d", os.time() - (LP.AccountAge * 86400))
    local ValPremium = CreateRow(SecAcc, "Premium"); ValPremium.Text = LP.MembershipType == Enum.MembershipType.Premium and "Yes" or "No"
    ValPremium.TextColor3 = LP.MembershipType == Enum.MembershipType.Premium and Theme.ButtonOn or Theme.Text

    local ValBio, ValFriends, ValActiveFriends = CreateRow(SecAcc, "Bio"), CreateRow(SecAcc, "Friends"), CreateRow(SecAcc, "Active Friends")
    local function GetAPI(url)
        local req = request or http_request or (syn and syn.request)
        if req then 
            local s, r = pcall(function() return req({Url = url, Method = "GET"}) end)
            if s and r and r.Body then local s2, res = pcall(function() return HttpService:JSONDecode(r.Body) end); if s2 then return res end end 
        end
        local s, r = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end); return (s and r) and r or nil 
    end

    coroutine.wrap(function() local api = GetAPI("https://users.roproxy.com/v1/users/" .. LP.UserId); ValBio.Text = api and (api.description ~= "" and api.description or "No Bio") or "API Blocked" end)()
    coroutine.wrap(function() local api = GetAPI("https://friends.roproxy.com/v1/users/" .. LP.UserId .. "/friends/count"); ValFriends.Text = api and tostring(api.count or 0) or "Error" end)()
    coroutine.wrap(function() local s, online = pcall(function() return LP:GetFriendsOnline(200) end); ValActiveFriends.Text = s and tostring(#online) or "Error" end)()

    local SecServer = CreateProfileAccordion("Server Information", 3, 150)
    local ValGame = CreateRow(SecServer, "Game Name")
    CreateRow(SecServer, "Place ID").Text = tostring(game.PlaceId)
    CreateRow(SecServer, "Universe ID").Text = tostring(game.GameId)
    
    local ValJobID = CreateRow(SecServer, "Job ID")
    ValJobID.Text = game.JobId ~= "" and (game.JobId .. " 📋") or "Private / Studio"
    ValJobID.Active = true
    ValJobID.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if game.JobId ~= "" and setclipboard then
                pcall(function() setclipboard(game.JobId) end)
                Notify("SYSTEM", "Job ID disalin ke clipboard!", 3)
            elseif game.JobId == "" then
                Notify("ERROR", "Server tidak memiliki Job ID.", 3)
            else
                Notify("ERROR", "Executor tidak support setclipboard", 3)
            end
        end
    end)

    local ValPlayers = CreateRow(SecServer, "Players")
    local function UpdatePlayerCount() ValPlayers.Text = tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers) end
    UpdatePlayerCount(); Players.PlayerAdded:Connect(UpdatePlayerCount); Players.PlayerRemoving:Connect(UpdatePlayerCount)
    coroutine.wrap(function() local s, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end); ValGame.Text = s and info.Name or "Unknown Game" end)()

    local SecExtra = CreateProfileAccordion("Extra Information", 4, 120)
    CreateRow(SecExtra, "Device").Text = (UIS.TouchEnabled and not UIS.KeyboardEnabled) and "Mobile" or (UIS.GamepadEnabled and "Console" or "PC")
    CreateRow(SecExtra, "Locale").Text = LocalizationService.SystemLocaleId
    CreateRow(SecExtra, "Roblox Version").Text = version()
    local ValStatus = CreateRow(SecExtra, "Status"); ValStatus.Text = "Connected"; ValStatus.TextColor3 = Theme.ButtonOn
end

-- ================= BLOK 7: MOVEMENT TAB =================
do
    SetSpeedVisual = CreateSlider(TabMovement, "Walk Speed", 16, 120, 16, Theme.ButtonDefault, 1, function(v) WalkSpeed = v; local h = Humanoid(); if h then h.WalkSpeed = v end end)
    SetJumpVisual = CreateSlider(TabMovement, "Jump Power", 50, 250, 50, Theme.ButtonDefault, 2, function(v) JumpPower = v; local h = Humanoid(); if h then h.JumpPower = v end end)

    local InfBtn = CreateButton(TabMovement, "Inf Jump : OFF", Theme.ButtonOff, 3, {ID="Melompat terus-menerus di udara.", EN="Jump continuously in the air."})
    InfBtn.TextColor3 = Theme.Text
    function SetInfJump(state) ToggleStates.InfJump = state; InfBtn.Text = state and "Inf Jump : ON" or "Inf Jump : OFF"; SetBtnColor(InfBtn, state and Theme.ButtonOn or Theme.ButtonOff); InfBtn.TextColor3 = state and Color3.new(1,1,1) or Theme.Text end
    InfBtn.Activated:Connect(function() SetInfJump(not ToggleStates.InfJump) end)
    Connections.Jump = UIS.JumpRequest:Connect(function() if ToggleStates.InfJump and Humanoid() then Humanoid():ChangeState(Enum.HumanoidStateType.Jumping) end end)

    local NoclipBtn = CreateButton(TabMovement, "Noclip : OFF", Theme.ButtonOff, 4, {ID="Menembus dinding.", EN="Walk through walls."})
    NoclipBtn.TextColor3 = Theme.Text
    function SetNoclip(state) 
        ToggleStates.Noclip = state; NoclipBtn.Text = state and "Noclip : ON" or "Noclip : OFF"; SetBtnColor(NoclipBtn, state and Theme.ButtonOn or Theme.ButtonOff); NoclipBtn.TextColor3 = state and Color3.new(1,1,1) or Theme.Text
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
    function SetFly(state)
        ToggleStates.Fly = state; local h, hum = HRP(), Humanoid(); if not h or not hum then ToggleStates.Fly = false return end
        if state then
            PrevNoclipState = ToggleStates.Noclip; if not ToggleStates.Noclip then SetNoclip(true) end
            hum.PlatformStand = true; FlyBody = Instance.new("BodyVelocity", h); FlyBody.MaxForce = Vector3.new(9e9, 9e9, 9e9); FlyBody.Velocity = Vector3.zero
            FlyGyro = Instance.new("BodyGyro", h); FlyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9); FlyGyro.P = 9e4; FlyGyro.CFrame = h.CFrame
            Connections.FlyLoop = RunService.RenderStepped:Connect(function()
                if not ToggleStates.Fly or not HRP() or not Humanoid() then return end
                local cam = workspace.CurrentCamera; local moveDir = Humanoid().MoveDirection; local vel = Vector3.zero
                if moveDir.Magnitude > 0 then local camSpaceMove = cam.CFrame:VectorToObjectSpace(moveDir); vel = (cam.CFrame.LookVector * -camSpaceMove.Z + cam.CFrame.RightVector * camSpaceMove.X) * FlySpeed end
                if UIS:IsKeyDown(Enum.KeyCode.Space) then vel = vel + Vector3.new(0, FlySpeed, 0) end
                if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then vel = vel - Vector3.new(0, FlySpeed, 0) end
                FlyBody.Velocity = vel; FlyGyro.CFrame = cam.CFrame
            end)
        else
            hum.PlatformStand = false; if FlyBody then FlyBody:Destroy() end; if FlyGyro then FlyGyro:Destroy() end; if Connections.FlyLoop then Connections.FlyLoop:Disconnect() end
            if not PrevNoclipState and ToggleStates.Noclip then SetNoclip(false) end
        end
    end
    local FlyBtn = CreateButton(TabMovement, "Fly : OFF", Theme.ButtonOff, 5, {ID="Terbang bebas di udara.", EN="Fly freely."})
    FlyBtn.TextColor3 = Theme.Text
    FlyBtn.Activated:Connect(function() SetFly(not ToggleStates.Fly); FlyBtn.Text = ToggleStates.Fly and "Fly : ON" or "Fly : OFF"; SetBtnColor(FlyBtn, ToggleStates.Fly and Theme.ButtonOn or Theme.ButtonOff); FlyBtn.TextColor3 = ToggleStates.Fly and Color3.new(1,1,1) or Theme.Text end)
    SetFlySpeedVisual = CreateSlider(TabMovement, "Fly Speed", 1, 300, 50, Theme.ButtonDefault, 6, function(v) FlySpeed = v end)

    local EmoteBtn = CreateButton(TabMovement, "Emotes / Animations", Theme.ButtonDefault, 7, {ID="Load script Emotes.", EN="Load Emotes script."})
    EmoteBtn.Activated:Connect(function() Notify("SYSTEM", CurrentLanguage == "ID" and "Memuat script..." or "Loading script...", 3); local s = pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/7yd7/Hub/refs/heads/Branch/GUIS/Emotes.lua"))() end); if not s then Notify("ERROR", CurrentLanguage == "ID" and "Gagal memuat Emotes!" or "Failed to load Emotes!", 3) end end)
end

-- ================= BLOK 8: VISUAL TAB =================
do
    SetFOVVisual = CreateSlider(TabVisual, "Field Of View", 70, 120, 70, Theme.ButtonDefault, 1, function(v) CurrentFOV = v; if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView = v end end)

    local MaxZoomBtn = CreateButton(TabVisual, "Max Zoom : OFF", Theme.ButtonOff, 2, {ID="Zoom out kamera tak terbatas.", EN="Infinite camera zoom out."})
    MaxZoomBtn.TextColor3 = Theme.Text
    function SetMaxZoom(state) ToggleStates.MaxZoom = state; MaxZoomBtn.Text = state and "Max Zoom : ON" or "Max Zoom : OFF"; SetBtnColor(MaxZoomBtn, state and Theme.ButtonOn or Theme.ButtonOff); MaxZoomBtn.TextColor3 = state and Color3.new(1,1,1) or Theme.Text; LP.CameraMaxZoomDistance = state and 100000 or 400 end
    MaxZoomBtn.Activated:Connect(function() SetMaxZoom(not ToggleStates.MaxZoom) end)

    local FPSBtn = CreateButton(TabVisual, "FPS Booster : OFF", Theme.ButtonOff, 3, {ID="Menurunkan grafik secara ekstrem.", EN="Lowers graphics extremely."})
    FPSBtn.TextColor3 = Theme.Text
    local OriginalGraphics, OriginalLighting = {}, {GlobalShadows = Lighting.GlobalShadows, FogEnd = Lighting.FogEnd, ShadowSoftness = Lighting.ShadowSoftness}
    setmetatable(OriginalGraphics, {__mode = "k"})

    function SetPotatoMode(state)
        ToggleStates.PotatoMode = state
        if state then
            FPSBtn.Text = "FPS Booster : ON"; SetBtnColor(FPSBtn, Theme.ButtonOn); FPSBtn.TextColor3 = Color3.new(1,1,1); Notify("SYSTEM", "Optimizing game...", 3)
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
            FPSBtn.Text = "FPS Booster : OFF"; SetBtnColor(FPSBtn, Theme.ButtonOff); FPSBtn.TextColor3 = Theme.Text; Notify("SYSTEM", "Restoring graphics...", 3)
            if DescendantConnection then DescendantConnection:Disconnect(); DescendantConnection = nil end
            Lighting.GlobalShadows = OriginalLighting.GlobalShadows; Lighting.FogEnd = OriginalLighting.FogEnd; Lighting.ShadowSoftness = OriginalLighting.ShadowSoftness
            for v, data in pairs(OriginalGraphics) do if v and v.Parent then if data.Material then v.Material = data.Material; v.Reflectance = data.Reflectance end; if data.Transparency then v.Transparency = data.Transparency end; if data.Lifetime then v.Lifetime = data.Lifetime end end end
        end
    end
    FPSBtn.Activated:Connect(function() SetPotatoMode(not ToggleStates.PotatoMode) end)

    local ESPInstances = {}
    local ESPConnection = nil
    local function RemoveESP(player)
        if ESPInstances[player] then
            if ESPInstances[player].Highlight then ESPInstances[player].Highlight:Destroy() end
            if ESPInstances[player].Billboard then ESPInstances[player].Billboard:Destroy() end
            ESPInstances[player] = nil
        end
    end
    local function CreateESPInstance(player)
        if player == LP then return end; RemoveESP(player)
        local highlight = Instance.new("Highlight"); highlight.FillColor = Theme.ButtonOn; highlight.OutlineColor = Color3.new(1, 1, 1); highlight.FillTransparency = 0.6; highlight.OutlineTransparency = 0.1; highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        local billboard = Instance.new("BillboardGui"); billboard.Size = UDim2.new(0, 200, 0, 50); billboard.StudsOffset = Vector3.new(0, 3.5, 0); billboard.AlwaysOnTop = true; billboard.MaxDistance = 5000
        local textLabel = Instance.new("TextLabel", billboard); textLabel.Size = UDim2.new(1, 0, 1, 0); textLabel.BackgroundTransparency = 1; textLabel.TextColor3 = Color3.new(1, 1, 1); textLabel.TextStrokeTransparency = 0; textLabel.Font = Enum.Font.RobotoMedium; textLabel.TextSize = 11
        ESPInstances[player] = {Highlight = highlight, Billboard = billboard, Text = textLabel}
    end

    local ESPBtn = CreateButton(TabVisual, "ESP : OFF", Theme.ButtonOff, 4, {ID="Melihat pemain beserta HP & jarak menembus dinding.", EN="See players, HP & distance through walls."})
    ESPBtn.TextColor3 = Theme.Text
    function SetESP(state)
        ToggleStates.ESP = state; ESPBtn.Text = state and "ESP : ON" or "ESP : OFF"; SetBtnColor(ESPBtn, state and Theme.ButtonOn or Theme.ButtonOff); ESPBtn.TextColor3 = state and Color3.new(1,1,1) or Theme.Text
        if state then
            for _, p in pairs(Players:GetPlayers()) do CreateESPInstance(p) end
            Connections.ESPPlayerAdded = Players.PlayerAdded:Connect(CreateESPInstance)
            Connections.ESPPlayerRemoving = Players.PlayerRemoving:Connect(RemoveESP)
            ESPConnection = RunService.RenderStepped:Connect(function()
                for player, espData in pairs(ESPInstances) do
                    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
                        espData.Highlight.Parent = player.Character; espData.Billboard.Parent = player.Character.HumanoidRootPart
                        local myHRP = HRP()
                        if myHRP then
                            local dist = math.floor((myHRP.Position - player.Character.HumanoidRootPart.Position).Magnitude)
                            local hp = math.floor(player.Character.Humanoid.Health); local maxHp = math.floor(player.Character.Humanoid.MaxHealth)
                            local hpColor = hp > (maxHp * 0.6) and "#81C995" or (hp > (maxHp * 0.3) and "#FDD663" or "#F28B82")
                            espData.Text.Text = player.DisplayName .. " | " .. dist .. "m\n<font color='" .. hpColor .. "'>HP: " .. hp .. "/" .. maxHp .. "</font>"; espData.Text.RichText = true
                        end
                    else espData.Highlight.Parent = nil; espData.Billboard.Parent = nil end
                end
            end)
        else
            if ESPConnection then ESPConnection:Disconnect(); ESPConnection = nil end
            if Connections.ESPPlayerAdded then Connections.ESPPlayerAdded:Disconnect() end
            if Connections.ESPPlayerRemoving then Connections.ESPPlayerRemoving:Disconnect() end
            for p, _ in pairs(ESPInstances) do RemoveESP(p) end
        end
    end
    ESPBtn.Activated:Connect(function() SetESP(not ToggleStates.ESP) end)

    local FullbrightBtn = CreateButton(TabVisual, "Fullbright : OFF", Theme.ButtonOff, 5, {ID="Membuat game menjadi sangat terang.", EN="Makes the game extremely bright."})
    FullbrightBtn.TextColor3 = Theme.Text
    function SetFullbright(state)
        ToggleStates.Fullbright = state; FullbrightBtn.Text = state and "Fullbright : ON" or "Fullbright : OFF"; SetBtnColor(FullbrightBtn, state and Theme.ButtonOn or Theme.ButtonOff); FullbrightBtn.TextColor3 = state and Color3.new(1,1,1) or Theme.Text
        if state then Lighting.Brightness = 3; Lighting.ClockTime = 14; Lighting.GlobalShadows = false; pcall(function() Lighting.ExposureCompensation = 0.75 end)
        else Lighting.Brightness = OriginalFB.Brightness; Lighting.ClockTime = OriginalFB.ClockTime; Lighting.GlobalShadows = OriginalFB.GlobalShadows; pcall(function() Lighting.ExposureCompensation = OriginalFB.ExposureCompensation end) end
    end
    FullbrightBtn.Activated:Connect(function() SetFullbright(not ToggleStates.Fullbright) end)

    local NofogBtn = CreateButton(TabVisual, "No Fog : OFF", Theme.ButtonOff, 6, {ID="Menghilangkan kabut di sekitar map.", EN="Removes fog from the map."})
    NofogBtn.TextColor3 = Theme.Text
    function SetNofog(state)
        ToggleStates.Nofog = state; NofogBtn.Text = state and "No Fog : ON" or "No Fog : OFF"; SetBtnColor(NofogBtn, state and Theme.ButtonOn or Theme.ButtonOff); NofogBtn.TextColor3 = state and Color3.new(1,1,1) or Theme.Text
        if state then Lighting.FogEnd = 9e9; pcall(function() Lighting.FogStart = 9e9 end)
        else Lighting.FogEnd = OriginalFog.FogEnd; pcall(function() Lighting.FogStart = OriginalFog.FogStart end) end
    end
    NofogBtn.Activated:Connect(function() SetNofog(not ToggleStates.Nofog) end)
end

-- ================= BLOK 9: UTILITY TAB =================
do
    local InstantBtn = CreateButton(TabUtility, "Instant Prompt : OFF", Theme.ButtonOff, 1, {ID="Bypass hold E.", EN="Bypass prompt hold time."})
    InstantBtn.TextColor3 = Theme.Text
    function SetInstantPrompt(state) ToggleStates.InstantPrompt = state; InstantBtn.Text = state and "Instant Prompt : ON" or "Instant Prompt : OFF"; SetBtnColor(InstantBtn, state and Theme.ButtonOn or Theme.ButtonOff); InstantBtn.TextColor3 = state and Color3.new(1,1,1) or Theme.Text end
    InstantBtn.Activated:Connect(function() SetInstantPrompt(not ToggleStates.InstantPrompt) end)
    Connections.Prompt = ProximityPromptService.PromptButtonHoldBegan:Connect(function(p) if ToggleStates.InstantPrompt then p.HoldDuration = 0; if fireproximityprompt then fireproximityprompt(p) end end end)

    local AntiAFKBtn = CreateButton(TabUtility, "Anti AFK : OFF", Theme.ButtonOff, 2, {ID="Mencegah auto kick afk.", EN="Prevents idle kick."})
    AntiAFKBtn.TextColor3 = Theme.Text
    function SetAntiAFK(state) ToggleStates.AntiAFK = state; AntiAFKBtn.Text = state and "Anti AFK : ON" or "Anti AFK : OFF"; SetBtnColor(AntiAFKBtn, state and Theme.ButtonOn or Theme.ButtonOff); AntiAFKBtn.TextColor3 = state and Color3.new(1,1,1) or Theme.Text end
    AntiAFKBtn.Activated:Connect(function() SetAntiAFK(not ToggleStates.AntiAFK) end)
    Connections.Idled = LP.Idled:Connect(function() if ToggleStates.AntiAFK then local cam = workspace.CurrentCamera; VirtualUser:CaptureController(); VirtualUser:ClickCenter(Vector2.new(0, 0), cam.CFrame) end end)

    local KeybindBtn = CreateButton(TabUtility, "Keybind : RightControl", Theme.ButtonDefault, 3, {ID="Ubah tombol GUI.", EN="Change GUI bind."})
    KeybindBtn.Activated:Connect(function() Binding = true; KeybindBtn.Text = "Press any key..."; SetBtnColor(KeybindBtn, Theme.Danger) end)
    Connections.Input = UIS.InputBegan:Connect(function(input, gpe)
        if Binding and input.UserInputType == Enum.UserInputType.Keyboard then CurrentKeybind = input.KeyCode; Binding = false; KeybindBtn.Text = "Keybind : " .. input.KeyCode.Name; SetBtnColor(KeybindBtn, Theme.ButtonDefault); Notify("SYSTEM", "Keybind changed", 3)
        elseif not gpe and input.KeyCode == CurrentKeybind then ToggleUI() end
    end)

    local _, _, InspScroll, InspList, UpdateInspSize = CreateAccordion(TabUtility, "Inspector & Part ESP", Theme.BackgroundTop, 4, {ID="Inspeksi ukuran, ESP, dan teleport ke part.", EN="Inspect size, ESP, and teleport to parts."}, 220)
    
    local InspectorBtn = CreateButton(InspScroll, "Inspector : OFF", Theme.ButtonOff, 1, {ID="Inspeksi ukuran & model part pintar.", EN="Inspect parts & models size."})
    InspectorBtn.TextColor3 = Theme.Text
    local PartInput = Instance.new("TextBox", InspScroll)
    PartInput.Size = UDim2.new(0, 240, 0, 36); PartInput.BackgroundColor3 = Theme.BackgroundTop; PartInput.TextColor3 = Theme.Text
    PartInput.Font = Enum.Font.Roboto; PartInput.TextSize = 12; PartInput.PlaceholderText = "Masukkan nama part..."
    PartInput.Text = ""; PartInput.LayoutOrder = 2; PartInput.ClearTextOnFocus = false; Corner(PartInput, 999)
    PartInput:SetAttribute("BaseColor", Theme.BackgroundTop)
    local PartInputPad = Instance.new("UIPadding", PartInput); PartInputPad.PaddingLeft = UDim.new(0, 15)
    PartInput:SetAttribute("SearchKey", "part input esp goto")
    
    local ESPPartBtn = CreateButton(InspScroll, "Part ESP : OFF", Theme.ButtonOff, 3, {ID="Tampilkan ESP pada part dengan nama tersebut.", EN="Show ESP on parts with that name."})
    ESPPartBtn.TextColor3 = Theme.Text
    local GotoBtn = CreateButton(InspScroll, "Goto Part", Theme.ButtonDefault, 4, {ID="Teleport ke part terdekat dengan nama tersebut.", EN="Teleport to nearest part with that name."})
    
    InspList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() 
        InspScroll.CanvasSize = UDim2.new(0, 0, 0, InspList.AbsoluteContentSize.Y) 
        UpdateInspSize()
    end)

    local CurrentSelectionBox, CurrentBillboard = nil, nil
    local function ClearInspector()
        if CurrentSelectionBox then CurrentSelectionBox:Destroy(); CurrentSelectionBox = nil end
        if CurrentBillboard then CurrentBillboard:Destroy(); CurrentBillboard = nil end
    end

    local function GetTarget(obj)
        local highestModel = nil
        local current = obj
        while current and current ~= workspace do
            if current:IsA("Model") then highestModel = current end
            current = current.Parent
        end
        local mainTarget = highestModel or obj
        local basePart = obj
        if not basePart:IsA("BasePart") then
            basePart = mainTarget:FindFirstChildWhichIsA("BasePart", true) or mainTarget
        end
        return mainTarget, basePart
    end

    local function HighlightTarget(hitPart)
        ClearInspector()
        if not hitPart or not hitPart:IsA("BasePart") then return end
        local mainTarget, basePart = GetTarget(hitPart)
        local targetSize = mainTarget:IsA("Model") and select(2, mainTarget:GetBoundingBox()) or mainTarget.Size
        
        CurrentSelectionBox = Instance.new("SelectionBox")
        CurrentSelectionBox.Adornee = mainTarget; CurrentSelectionBox.LineThickness = 0.05
        CurrentSelectionBox.Color3 = Theme.ButtonOn; CurrentSelectionBox.Parent = Gui
        
        CurrentBillboard = Instance.new("BillboardGui")
        CurrentBillboard.Adornee = basePart; CurrentBillboard.Size = UDim2.new(0, 150, 0, 30)
        CurrentBillboard.StudsOffset = Vector3.new(0, (basePart:IsA("BasePart") and (basePart.Size.Y / 2) + 1.5 or 3), 0)
        CurrentBillboard.AlwaysOnTop = true; CurrentBillboard.Parent = Gui
        
        local TextLabel = Instance.new("TextLabel", CurrentBillboard)
        TextLabel.Size = UDim2.new(1, 0, 1, 0); TextLabel.BackgroundColor3 = Theme.BackgroundTop
        TextLabel.BackgroundTransparency = 0.2; TextLabel.TextColor3 = Theme.ButtonOn
        TextLabel.TextScaled = true; TextLabel.Text = mainTarget.Name .. "\n(" .. math.floor(targetSize.X) .. ", " .. math.floor(targetSize.Y) .. ", " .. math.floor(targetSize.Z) .. ")"
        TextLabel.Font = Enum.Font.RobotoMedium; Corner(TextLabel, 8)
    end

    local ActivePartESPs = {}
    local PartESPConnection
    local function ClearPartESP()
        for _, esp in pairs(ActivePartESPs) do
            if esp.Box then esp.Box:Destroy() end
            if esp.Billboard then esp.Billboard:Destroy() end
        end
        ActivePartESPs = {}
        if PartESPConnection then PartESPConnection:Disconnect(); PartESPConnection = nil end
    end

    local function RefreshPartESP(query)
        ClearPartESP()
        if query == "" then return end
        query = string.lower(query)
        
        for _, v in pairs(workspace:GetDescendants()) do
            if LP.Character and v:IsDescendantOf(LP.Character) then continue end
            if (v:IsA("BasePart") or v:IsA("Model")) and string.find(string.lower(v.Name), query) then
                local mainTarget, basePart = GetTarget(v)
                if not ActivePartESPs[mainTarget] then
                    local box = Instance.new("SelectionBox")
                    box.Adornee = mainTarget; box.LineThickness = 0.05; box.Color3 = Theme.ButtonOn; box.Parent = Gui
                    
                    local bb = Instance.new("BillboardGui")
                    bb.Adornee = basePart; bb.Size = UDim2.new(0, 150, 0, 30); bb.AlwaysOnTop = true; bb.Parent = Gui
                    
                    local txt = Instance.new("TextLabel", bb)
                    txt.Size = UDim2.new(1, 0, 1, 0); txt.BackgroundTransparency = 1
                    txt.TextColor3 = Theme.ButtonOn; txt.TextStrokeTransparency = 0.5
                    txt.Font = Enum.Font.RobotoMedium; txt.TextSize = 12
                    
                    ActivePartESPs[mainTarget] = {Box = box, Billboard = bb, Text = txt, BasePart = basePart}
                end
            end
        end
        PartESPConnection = RunService.RenderStepped:Connect(function()
            local hrp = HRP()
            if not hrp then return end
            for target, esp in pairs(ActivePartESPs) do
                if esp.BasePart and esp.BasePart.Parent then
                    local dist = math.floor((hrp.Position - esp.BasePart.Position).Magnitude)
                    esp.Text.Text = target.Name .. "\n[" .. dist .. "m]"
                else
                    if esp.Box then esp.Box:Destroy() end
                    if esp.Billboard then esp.Billboard:Destroy() end
                    ActivePartESPs[target] = nil
                end
            end
        end)
    end

    function SetInspector(state)
        ToggleStates.Inspector = state
        InspectorBtn.Text = state and "Inspector : ON" or "Inspector : OFF"
        SetBtnColor(InspectorBtn, state and Theme.ButtonOn or Theme.ButtonOff)
        InspectorBtn.TextColor3 = state and Color3.new(1,1,1) or Theme.Text
        if state then
            Connections.InspectorTouch = UIS.TouchTapInWorld:Connect(function(position, processedByUI)
                if not processedByUI then
                    local cam = workspace.CurrentCamera; local ray = cam:ViewportPointToRay(position.X, position.Y)
                    local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances = {LP.Character, Gui}
                    local result = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
                    if result and result.Instance then HighlightTarget(result.Instance) else ClearInspector() end
                end
            end)
            local Mouse = LP:GetMouse()
            Connections.InspectorMouse = Mouse.Button1Down:Connect(function()
                if not UIS:GetFocusedTextBox() then
                    local target = Mouse.Target
                    if target and (not LP.Character or not target:IsDescendantOf(LP.Character)) then HighlightTarget(target) else ClearInspector() end
                end
            end)
        else
            if Connections.InspectorTouch then Connections.InspectorTouch:Disconnect(); Connections.InspectorTouch = nil end
            if Connections.InspectorMouse then Connections.InspectorMouse:Disconnect(); Connections.InspectorMouse = nil end
            ClearInspector()
        end
    end
    InspectorBtn.Activated:Connect(function() SetInspector(not ToggleStates.Inspector) end)

    function SetPartESP(state)
        ToggleStates.PartESP = state
        ESPPartBtn.Text = state and "Part ESP : ON" or "Part ESP : OFF"
        SetBtnColor(ESPPartBtn, state and Theme.ButtonOn or Theme.ButtonOff)
        ESPPartBtn.TextColor3 = state and Color3.new(1,1,1) or Theme.Text
        if state then RefreshPartESP(PartInput.Text) else ClearPartESP() end
    end
    ESPPartBtn.Activated:Connect(function() SetPartESP(not ToggleStates.PartESP) end)

    PartInput.FocusLost:Connect(function()
        if ToggleStates.PartESP then RefreshPartESP(PartInput.Text) end
    end)

    GotoBtn.Activated:Connect(function()
        local query = string.lower(PartInput.Text)
        if query == "" then Notify("ERROR", "Isi nama part dulu!", 3) return end
        local hrp = HRP()
        if not hrp then return end

        local closestDistance = math.huge
        local bestCFrame = nil
        local foundName = ""
        local processedTargets = {}
        
        for _, v in pairs(workspace:GetDescendants()) do
            if LP.Character and v:IsDescendantOf(LP.Character) then continue end
            if (v:IsA("BasePart") or v:IsA("Model")) and string.find(string.lower(v.Name), query) then
                local mainTarget, basePart = GetTarget(v)
                if not processedTargets[mainTarget] then
                    processedTargets[mainTarget] = true
                    local targetCF = nil
                    if mainTarget:IsA("Model") and mainTarget.PrimaryPart then
                        targetCF = mainTarget.PrimaryPart.CFrame
                    elseif basePart and basePart:IsA("BasePart") then
                        targetCF = basePart.CFrame
                    elseif mainTarget:IsA("Model") then
                        targetCF = mainTarget:GetBoundingBox()
                    end

                    if targetCF then
                        local dist = (hrp.Position - targetCF.Position).Magnitude
                        if dist < closestDistance then
                            closestDistance = dist; bestCFrame = targetCF; foundName = mainTarget.Name
                        end
                    end
                end
            end
        end

        if bestCFrame then
            hrp.CFrame = bestCFrame
            Notify("TELEPORT", "Menuju: " .. foundName .. " (" .. math.floor(closestDistance) .. "m)", 5)
        else
            Notify("ERROR", "Part tidak ditemukan di Map!", 3)
        end
    end)
end

-- ================= BLOK 10: TELEPORT TAB =================
do
    local _, _, PlayerScroll, PlayerListUI, _, TogglePlayerBtn, PlayerState = CreateAccordion(TabTeleport, "Teleport to Player", Theme.ButtonDefault, 1, {ID="Teleport ke pemain lain.", EN="Teleport to other players."}, 160)
    local function RefreshPlayers()
        for _, v in pairs(PlayerScroll:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LP then
                local btn = CreateButton(PlayerScroll, p.DisplayName .. " (@" .. p.Name .. ")", Theme.BackgroundTop, 1)
                btn.Size = UDim2.new(1, -6, 0, 32); btn.TextColor3 = Theme.Text; btn.Font = Enum.Font.Roboto; btn.TextSize = 11
                btn.Activated:Connect(function() local my, tH = HRP(), p.Character and p.Character:FindFirstChild("HumanoidRootPart"); if my and tH then my.CFrame = tH.CFrame; Notify("TELEPORT", "Teleported to " .. p.DisplayName, 3) end end)
            end
        end
        PlayerScroll.CanvasSize = UDim2.new(0, 0, 0, PlayerListUI.AbsoluteContentSize.Y)
    end
    TogglePlayerBtn.Activated:Connect(function() if PlayerState.IsOpen then RefreshPlayers() end end)

    local _, WPMenu, WPScroll, WPListUI, UpdateWPSize, _, WPState = CreateAccordion(TabTeleport, "Waypoints Menu", Theme.ButtonDefault, 2, {ID="Simpan posisi teleport.", EN="Save teleport positions."}, 160)
    WPScroll.Size = UDim2.new(1, 0, 1, -40); WPScroll.Position = UDim2.new(0, 0, 0, 40); WPState.ExtraHeight = 40
    local AddWPBtn = CreateButton(WPMenu, "+ Add Current Pos", Theme.ButtonOn, 1); AddWPBtn.Size = UDim2.new(1, 0, 0, 36); AddWPBtn.Position = UDim2.new(0, 0, 0, 0)
    local WPContainer = Instance.new("Frame", Gui); WPContainer.Size = UDim2.new(0, 60, 0, 200); WPContainer.Position = UDim2.new(0, 10, 0, 10); WPContainer.BackgroundTransparency = 1

    local function RefreshFloatingWPs()
        for _, child in pairs(WPContainer:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
        local idx = 1
        for id, cf in pairs(Waypoints) do
            local btn = CreateButton(WPContainer, "WP "..id, Theme.ButtonDefault, idx)
            btn.Size = UDim2.new(0, 50, 0, 32); btn.Position = UDim2.new(0, 0, 0, (idx-1)*36)
            btn.Activated:Connect(function() local h = HRP(); if h then h.CFrame = cf end end); CustomDrag(btn, WPContainer); idx = idx + 1
        end
    end

    function CreateDynamicWP(id, cfToSave)
        Waypoints[id] = cfToSave
        local Item = Instance.new("Frame", WPScroll); Item.Size = UDim2.new(1, 0, 0, 36); Item.BackgroundColor3 = Theme.BackgroundTop; Corner(Item, 12)
        Item:SetAttribute("BaseColor", Theme.BackgroundTop)
        local NameLbl = Instance.new("TextLabel", Item); NameLbl.Size = UDim2.new(0, 70, 1, 0); NameLbl.Position = UDim2.new(0, 10, 0, 0); NameLbl.BackgroundTransparency = 1; NameLbl.Text = "WP " .. id; NameLbl.TextColor3 = Theme.Text; NameLbl.Font = Enum.Font.RobotoMedium; NameLbl.TextSize = 11; NameLbl.TextXAlignment = Enum.TextXAlignment.Left
        local TpBtn = CreateButton(Item, "Go", Theme.ButtonDefault, 1); TpBtn.Size = UDim2.new(0, 40, 0, 28); TpBtn.Position = UDim2.new(1, -130, 0.5, -14); TpBtn.TextColor3 = Color3.new(1,1,1)
        local EditBtn = CreateButton(Item, "Set", Theme.ButtonOff, 2); EditBtn.Size = UDim2.new(0, 40, 0, 28); EditBtn.Position = UDim2.new(1, -85, 0.5, -14); EditBtn.TextColor3 = Theme.Text
        local DelBtn = CreateButton(Item, "X", Theme.Danger, 3); DelBtn.Size = UDim2.new(0, 28, 0, 28); DelBtn.Position = UDim2.new(1, -35, 0.5, -14); DelBtn.TextColor3 = Color3.new(1,1,1)
        
        TpBtn.Activated:Connect(function() local h = HRP(); if h and Waypoints[id] then h.CFrame = Waypoints[id] end end)
        EditBtn.Activated:Connect(function() local h = HRP(); if h then Waypoints[id] = h.CFrame; Notify("TELEPORT", "WP " .. id .. " ditimpa dengan posisi sekarang!", 3); RefreshFloatingWPs() end end)
        DelBtn.Activated:Connect(function() Waypoints[id] = nil; Item:Destroy(); WPScroll.CanvasSize = UDim2.new(0, 0, 0, WPListUI.AbsoluteContentSize.Y); UpdateWPSize(); RefreshFloatingWPs() end)
        WPScroll.CanvasSize = UDim2.new(0, 0, 0, WPListUI.AbsoluteContentSize.Y); UpdateWPSize(); RefreshFloatingWPs()
    end

    local function GetNextWPId() local id = 1; while Waypoints[id] ~= nil do id = id + 1 end; return id end
    AddWPBtn.Activated:Connect(function() local h = HRP(); if h then CreateDynamicWP(GetNextWPId(), h.CFrame) end end)

    local _, _, HopScroll = CreateAccordion(TabTeleport, "Server Hop", Theme.ButtonDefault, 3, {ID="Pindah ke server publik lain.", EN="Hop to another server."}, 120)
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

    local HopBtnContainer = Instance.new("Frame", HopScroll); HopBtnContainer.Size = UDim2.new(1, -6, 0, 36); HopBtnContainer.BackgroundTransparency = 1; HopBtnContainer.LayoutOrder = 1
    local HopEmptyBtn = CreateButton(HopBtnContainer, "Hop (Sepi)", Theme.ButtonOff, 1); HopEmptyBtn.Size = UDim2.new(0.5, -3, 1, 0); HopEmptyBtn.TextColor3 = Theme.Text; HopEmptyBtn.Activated:Connect(function() PerformServerHop(false) end); RegisterDynamicLang(HopEmptyBtn, "Hop (Sepi)", "Hop (Empty)")
    local HopCrowdedBtn = CreateButton(HopBtnContainer, "Hop (Rame)", Theme.ButtonOn, 2); HopCrowdedBtn.Size = UDim2.new(0.5, -3, 1, 0); HopCrowdedBtn.AnchorPoint = Vector2.new(1, 0); HopCrowdedBtn.Position = UDim2.new(1, 0, 0, 0); HopCrowdedBtn.TextColor3 = Color3.new(1,1,1); HopCrowdedBtn.Activated:Connect(function() PerformServerHop(true) end); RegisterDynamicLang(HopCrowdedBtn, "Hop (Rame)", "Hop (Crowded)")
    HopScroll.CanvasSize = UDim2.new(0, 0, 0, 40)

    local RejoinBtn = CreateButton(TabTeleport, "Rejoin", Theme.Danger, 4, {ID="Masuk ulang server sama.", EN="Rejoin same server."})
    RejoinBtn.Activated:Connect(function() Notify("SERVER", "Rejoining...", 3); if game.JobId == "" then TeleportService:Teleport(game.PlaceId, LP) else TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end end)
end

-- ================= BLOK 11: CONFIG TAB =================
do
    local ConfigInput = Instance.new("TextBox", TabConfig); ConfigInput.Size = UDim2.new(0, 240, 0, 36); ConfigInput.BackgroundColor3 = Theme.BackgroundTop; ConfigInput.TextColor3 = Theme.Text; ConfigInput.Font = Enum.Font.Roboto; ConfigInput.TextSize = 12; ConfigInput.PlaceholderText = "(nama config)"; ConfigInput.Text = ""; ConfigInput.LayoutOrder = 1; Corner(ConfigInput, 999)
    local ConfigPad = Instance.new("UIPadding", ConfigInput); ConfigPad.PaddingLeft = UDim.new(0, 15)
    ConfigInput:SetAttribute("BaseColor", Theme.BackgroundTop)
    local SaveBtn = CreateButton(TabConfig, "Save Config", Theme.ButtonOn, 2, {ID="Simpan setingan.", EN="Save settings."})
    local _, _, LoadScroll, LoadListUI, _, ToggleLoadBtn, LoadState = CreateAccordion(TabConfig, "Load Config", Theme.ButtonDefault, 3, {ID="Muat setingan.", EN="Load settings."}, 140)

    function GetConfigPath(name) return ConfigFolder .. "/" .. string.gsub(name=="" and "ConfigUtama" or name, "[^%w_]", "") .. ".json" end

    function LoadConfigData(path)
        if readfile and isfile and isfile(path) then
            local s, res = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
            if s and res then
                WalkSpeed = res.WalkSpeed or 16; JumpPower = res.JumpPower or 50; CurrentFOV = res.FOV or 70; FlySpeed = res.FlySpeed or 50; CurrentKeybind = Enum.KeyCode[res.Keybind or "RightControl"]
                SetSpeedVisual(WalkSpeed); SetJumpVisual(JumpPower); SetFOVVisual(CurrentFOV); SetFlySpeedVisual(FlySpeed)
                if res.InfJump ~= ToggleStates.InfJump then SetInfJump(res.InfJump) end; if res.Noclip ~= ToggleStates.Noclip then SetNoclip(res.Noclip) end
                if res.InstantPrompt ~= ToggleStates.InstantPrompt then SetInstantPrompt(res.InstantPrompt) end; if res.MaxZoom ~= ToggleStates.MaxZoom then SetMaxZoom(res.MaxZoom) end
                if res.AntiAFK ~= ToggleStates.AntiAFK then SetAntiAFK(res.AntiAFK) end; if res.PotatoMode ~= ToggleStates.PotatoMode then SetPotatoMode(res.PotatoMode) end
                if res.ESP ~= ToggleStates.ESP then SetESP(res.ESP) end; if res.Fullbright ~= ToggleStates.Fullbright then SetFullbright(res.Fullbright) end; if res.Nofog ~= ToggleStates.Nofog then SetNofog(res.Nofog) end
                if res.Waypoints then for id, cData in pairs(res.Waypoints) do CreateDynamicWP(tonumber(id) or id, CFrame.new(unpack(cData))) end end
                Notify("CONFIG", "Loaded from " .. path, 3)
            else Notify("ERROR", "Data config corrupt!", 3) end
        else Notify("ERROR", "File config tidak ditemukan!", 3) end
    end

    function RefreshConfigList()
        for _, v in pairs(LoadScroll:GetChildren()) do if v:IsA("Frame") or v:IsA("TextButton") then v:Destroy() end end
        if listfiles then
            for _, file in pairs(listfiles(ConfigFolder)) do
                if string.match(file, "%.json$") then
                    local filename = string.match(file, "[\\/]([^\\/]+)%.json$") or string.match(file, "([^\\/]+)%.json$")
                    local ItemFrame = Instance.new("Frame", LoadScroll); ItemFrame.Size = UDim2.new(1, -6, 0, 32); ItemFrame.BackgroundTransparency = 1
                    local LoadBtn = CreateButton(ItemFrame, filename, Theme.BackgroundTop, 1); LoadBtn.Size = UDim2.new(1, -38, 1, 0); LoadBtn.TextColor3 = Theme.Text; LoadBtn.Font = Enum.Font.Roboto; LoadBtn.TextSize = 11
                    local DelBtn = CreateButton(ItemFrame, "X", Theme.Danger, 2); DelBtn.Size = UDim2.new(0, 32, 1, 0); DelBtn.Position = UDim2.new(1, -32, 0, 0)
                    LoadBtn.Activated:Connect(function() LoadConfigData(file) end)
                    DelBtn.Activated:Connect(function() if delfile then local success = pcall(function() delfile(file) end); if success then Notify("CONFIG", filename .. " berhasil dihapus!", 3); RefreshConfigList() end else Notify("ERROR", "Executor tidak support delfile!", 3) end end)
                end
            end
            LoadScroll.CanvasSize = UDim2.new(0, 0, 0, LoadListUI.AbsoluteContentSize.Y)
        end
    end

    ToggleLoadBtn.Activated:Connect(function() if LoadState.IsOpen then RefreshConfigList() end end)
    SaveBtn.Activated:Connect(function()
        if writefile then
            local data = { WalkSpeed = WalkSpeed, JumpPower = JumpPower, FOV = CurrentFOV, FlySpeed = FlySpeed, Keybind = CurrentKeybind.Name, InfJump = ToggleStates.InfJump, Noclip = ToggleStates.Noclip, InstantPrompt = ToggleStates.InstantPrompt, MaxZoom = ToggleStates.MaxZoom, AntiAFK = ToggleStates.AntiAFK, PotatoMode = ToggleStates.PotatoMode, ESP = ToggleStates.ESP, Fullbright = ToggleStates.Fullbright, Nofog = ToggleStates.Nofog, Waypoints = {} }
            for id, cf in pairs(Waypoints) do data.Waypoints[tostring(id)] = {cf:GetComponents()} end
            local s = pcall(function() writefile(GetConfigPath(ConfigInput.Text), HttpService:JSONEncode(data)) end)
            if s then Notify("CONFIG", "Saved to " .. GetConfigPath(ConfigInput.Text), 3); if LoadState.IsOpen then RefreshConfigList() end else Notify("ERROR", "Gagal menyimpan config!", 3) end
        else Notify("ERROR", "Executor tidak support WriteFile!", 3) end
    end)

    local UnloadBtn = CreateButton(TabConfig, "Unload Script", Theme.Danger, 4, {ID="Hapus script dari layar.", EN="Remove script."})
    UnloadBtn.Activated:Connect(function()
        if Connections.Stats then Connections.Stats:Disconnect() end; if Connections.Descendant then Connections.Descendant:Disconnect() end; if Connections.Speed then Connections.Speed:Disconnect() end; if Connections.Jump then Connections.Jump:Disconnect() end
        for _, conn in pairs(Connections) do if conn and conn.Disconnect then conn:Disconnect() end end
        SetNoclip(false); SetFly(false); SetPotatoMode(false); SetInfJump(false); SetInstantPrompt(false); SetMaxZoom(false); SetAntiAFK(false); SetESP(false); SetInspector(false); SetPartESP(false); SetFullbright(false); SetNofog(false)
        UIBlur:Destroy(); Gui:Destroy()
    end)
end

-- ================= BLOK 12: FINAL EXECUTION =================
do
    for _, data in ipairs(DynamicLabels) do if data.Obj then data.Obj.Text = CurrentLanguage == "ID" and data.ID or data.EN end end

    coroutine.wrap(function()
        ToggleUI()
        local sound = Instance.new("Sound", workspace); sound.SoundId = "rbxassetid://6042053626"; sound.Volume = 0.5; sound:Play()
        Notify("SYSTEM", "Mamet Utility Pro V9.0 (Pixel UI) Loaded", 5)
        if AntiDetectActive then Notify("SECURITY", "Anti-Cheat Bypass Active", 5) end
        delay(5, function() sound:Destroy() end)
    end)()
end

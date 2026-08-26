--[=[
    MiningUI.client.lua
    UBICACIÓN: StarterPlayer > StarterPlayerScripts

    HUD tecnológico del juego:
    - Barra superior interactiva con avatar y modo excavación/construcción.
    - Panel de progreso de profundidad y progresión del pico.
    - Tiempo jugado, récord personal y bloques excavados.
    - Ranking físico 3D en el mundo con foto de perfil de cada jugador.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotesFolder = ReplicatedStorage:WaitForChild("MiningRemotes")
local statsUpdateEvent = remotesFolder:WaitForChild("StatsUpdate")
local notifyEvent = remotesFolder:WaitForChild("Notify")
local leaderboardUpdateEvent = remotesFolder:WaitForChild("LeaderboardUpdate")

local signalsFolder = ReplicatedStorage:FindFirstChild("MiningLocalSignals")
if not signalsFolder then
    signalsFolder = Instance.new("Folder")
    signalsFolder.Name = "MiningLocalSignals"
    signalsFolder.Parent = ReplicatedStorage
end
local toggleBuildSignal = signalsFolder:FindFirstChild("ToggleBuildMode")
if not toggleBuildSignal then
    toggleBuildSignal = Instance.new("BindableEvent")
    toggleBuildSignal.Name = "ToggleBuildMode"
    toggleBuildSignal.Parent = signalsFolder
end

-- ======= PALETA =======
local C = {
    Navy = Color3.fromRGB(8, 18, 32),
    Panel = Color3.fromRGB(12, 28, 45),
    PanelLight = Color3.fromRGB(18, 43, 63),
    Cyan = Color3.fromRGB(78, 224, 255),
    CyanSoft = Color3.fromRGB(129, 244, 255),
    Mint = Color3.fromRGB(87, 232, 190),
    Gold = Color3.fromRGB(255, 205, 78),
    Orange = Color3.fromRGB(255, 160, 71),
    Red = Color3.fromRGB(255, 107, 116),
    White = Color3.fromRGB(240, 247, 255),
    Muted = Color3.fromRGB(151, 178, 201),
    Dark = Color3.fromRGB(22, 44, 62),
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MiningUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Enabled = false
screenGui.Parent = playerGui

local function corner(parent, radius)
    local item = Instance.new("UICorner")
    item.CornerRadius = UDim.new(0, radius or 10)
    item.Parent = parent
    return item
end

local function stroke(parent, color, transparency, thickness)
    local item = Instance.new("UIStroke")
    item.Color = color or C.Cyan
    item.Transparency = transparency or 0.35
    item.Thickness = thickness or 1
    item.Parent = parent
    return item
end

local function gradient(parent, colorA, colorB, rotation)
    local item = Instance.new("UIGradient")
    item.Color = ColorSequence.new(colorA, colorB)
    item.Rotation = rotation or 0
    item.Parent = parent
    return item
end

local function label(parent, name, text, position, size, font, textSize, color)
    local item = Instance.new("TextLabel")
    item.Name = name
    item.BackgroundTransparency = 1
    item.Position = position
    item.Size = size
    item.Font = font or Enum.Font.Gotham
    item.Text = text
    item.TextColor3 = color or C.White
    item.TextSize = textSize or 14
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.TextYAlignment = Enum.TextYAlignment.Center
    item.Parent = parent
    return item
end

local function panel(parent, name, position, size)
    local item = Instance.new("Frame")
    item.Name = name
    item.Position = position
    item.Size = size
    item.BackgroundColor3 = C.Panel
    item.BackgroundTransparency = 0.12
    item.BorderSizePixel = 0
    item.Parent = parent
    corner(item, 12)
    stroke(item, Color3.fromRGB(62, 132, 163), 0.35, 1)
    gradient(item, Color3.fromRGB(19, 45, 66), C.Panel, 135)
    return item
end

local function addSectionHeader(parent, text, subtitle)
    local title = label(parent, "Header", text, UDim2.new(0, 16, 0, 8), UDim2.new(1, -32, 0, 24), Enum.Font.GothamBlack, 16, C.White)
    local sub = label(parent, "Subheader", subtitle, UDim2.new(0, 16, 0, 32), UDim2.new(1, -32, 0, 15), Enum.Font.GothamMedium, 10, C.Cyan)
    sub.TextTransparency = 0.1
    return title, sub
end

-- ======= BARRA SUPERIOR =======
local topBar = panel(screenGui, "TechTopBar", UDim2.new(0.5, -300, 0, 16), UDim2.new(0, 600, 0, 62))
local accent = Instance.new("Frame")
accent.Name = "Accent"
accent.BorderSizePixel = 0
accent.BackgroundColor3 = C.Cyan
accent.Position = UDim2.new(0, 0, 0, 0)
accent.Size = UDim2.new(0, 4, 1, 0)
accent.Parent = topBar
corner(accent, 4)

local avatar = Instance.new("ImageLabel")
avatar.Name = "ProfileAvatar"
avatar.BackgroundColor3 = C.Dark
avatar.BorderSizePixel = 0
avatar.Position = UDim2.new(0, 14, 0, 11)
avatar.Size = UDim2.new(0, 40, 0, 40)
avatar.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(player.UserId)
avatar.Parent = topBar
corner(avatar, 10)
stroke(avatar, C.Cyan, 0.18, 1)

local profileName = label(topBar, "ProfileName", player.DisplayName:upper(), UDim2.new(0, 64, 0, 10), UDim2.new(0, 150, 0, 18), Enum.Font.GothamBlack, 13, C.White)
local profileTag = label(topBar, "ProfileTag", "EXCAVADOR // EN LÍNEA", UDim2.new(0, 64, 0, 30), UDim2.new(0, 170, 0, 14), Enum.Font.GothamMedium, 9, C.Mint)

local topProgressBg = Instance.new("Frame")
topProgressBg.Name = "DepthProgressBg"
topProgressBg.BackgroundColor3 = C.Dark
topProgressBg.BorderSizePixel = 0
topProgressBg.Position = UDim2.new(0, 235, 0, 14)
topProgressBg.Size = UDim2.new(0, 175, 0, 10)
topProgressBg.Parent = topBar
corner(topProgressBg, 6)
local topProgressFill = Instance.new("Frame")
topProgressFill.Name = "Fill"
topProgressFill.BackgroundColor3 = C.Cyan
topProgressFill.BorderSizePixel = 0
topProgressFill.Size = UDim2.new(0, 0, 1, 0)
topProgressFill.Parent = topProgressBg
corner(topProgressFill, 6)
gradient(topProgressFill, C.Cyan, C.Mint, 0)
local topDepthText = label(topBar, "DepthText", "PROFUNDIDAD  0 / 110m", UDim2.new(0, 235, 0, 27), UDim2.new(0, 175, 0, 18), Enum.Font.GothamBold, 10, C.CyanSoft)
local topStatus = label(topBar, "Status", "● LIVE", UDim2.new(0, 235, 0, 45), UDim2.new(0, 90, 0, 12), Enum.Font.GothamBold, 9, C.Mint)

local buildButton = Instance.new("TextButton")
buildButton.Name = "BuildModeButton"
buildButton.AutoButtonColor = false
buildButton.BackgroundColor3 = Color3.fromRGB(31, 76, 92)
buildButton.BorderSizePixel = 0
buildButton.Position = UDim2.new(1, -168, 0, 12)
buildButton.Size = UDim2.new(0, 151, 0, 38)
buildButton.Font = Enum.Font.GothamBlack
buildButton.Text = "⛏  EXCAVAR   [B]"
buildButton.TextColor3 = C.CyanSoft
buildButton.TextSize = 12
buildButton.Parent = topBar
corner(buildButton, 9)
stroke(buildButton, C.Cyan, 0.22, 1)

local function setBuildMode(enabled)
    buildButton.Text = enabled and "▣  CONSTRUIR   [B]" or "⛏  EXCAVAR   [B]"
    buildButton.BackgroundColor3 = enabled and Color3.fromRGB(107, 68, 32) or Color3.fromRGB(31, 76, 92)
    buildButton.TextColor3 = enabled and Color3.fromRGB(255, 222, 124) or C.CyanSoft
    local outline = buildButton:FindFirstChildOfClass("UIStroke")
    if outline then outline.Color = enabled and C.Orange or C.Cyan end
    toggleBuildSignal:Fire(enabled)
end

buildButton.Activated:Connect(function()
    local enabled = buildButton.Text:find("CONSTRUIR") ~= nil
    setBuildMode(not enabled)
end)

-- ======= PANEL DE PROGRESO DEL JUGADOR =======
local statsPanel = panel(screenGui, "StatsPanel", UDim2.new(0, 18, 0, 94), UDim2.new(0, 300, 0, 252))
statsPanel.Visible = false
addSectionHeader(statsPanel, "CENTRO DE CONTROL", "ESTADO DE EXCAVACIÓN // PERSONAL")

local pointsIcon = label(statsPanel, "PointsIcon", "◆", UDim2.new(0, 17, 0, 62), UDim2.new(0, 22, 0, 26), Enum.Font.GothamBlack, 20, C.Gold)
local pointsLabel = label(statsPanel, "Points", "0", UDim2.new(0, 46, 0, 58), UDim2.new(0, 120, 0, 25), Enum.Font.GothamBlack, 22, C.Gold)
local pointsCaption = label(statsPanel, "PointsCaption", "PUNTOS DE RECURSOS", UDim2.new(0, 47, 0, 81), UDim2.new(0, 165, 0, 13), Enum.Font.GothamBold, 9, C.Muted)

local pickaxeLabel = label(statsPanel, "Pickaxe", "PICO DE MADERA", UDim2.new(0, 16, 0, 108), UDim2.new(1, -32, 0, 18), Enum.Font.GothamBold, 13, C.White)
local pickaxePower = label(statsPanel, "PickaxePower", "POTENCIA 1", UDim2.new(0, 16, 0, 126), UDim2.new(1, -32, 0, 14), Enum.Font.GothamMedium, 9, C.Cyan)

local pickaxeBg = Instance.new("Frame")
pickaxeBg.Name = "PickaxeProgressBg"
pickaxeBg.BackgroundColor3 = C.Dark
pickaxeBg.BorderSizePixel = 0
pickaxeBg.Position = UDim2.new(0, 16, 0, 150)
pickaxeBg.Size = UDim2.new(1, -32, 0, 11)
pickaxeBg.Parent = statsPanel
corner(pickaxeBg, 6)
local pickaxeFill = Instance.new("Frame")
pickaxeFill.Name = "Fill"
pickaxeFill.BackgroundColor3 = C.Gold
pickaxeFill.BorderSizePixel = 0
pickaxeFill.Size = UDim2.new(0, 0, 1, 0)
pickaxeFill.Parent = pickaxeBg
corner(pickaxeFill, 6)
gradient(pickaxeFill, C.Gold, C.Orange, 0)
local pickaxeProgressText = label(statsPanel, "PickaxeProgressText", "PREPARANDO SIGUIENTE PICO", UDim2.new(0, 16, 0, 165), UDim2.new(1, -32, 0, 14), Enum.Font.GothamMedium, 9, C.Muted)

local blocksLabel = label(statsPanel, "Blocks", "BLOQUES  0", UDim2.new(0, 16, 0, 193), UDim2.new(0.48, -16, 0, 22), Enum.Font.GothamBold, 11, C.Mint)
local timeLabel = label(statsPanel, "Time", "TIEMPO  00:00", UDim2.new(0.5, 0, 193, 0), UDim2.new(0.5, -16, 0, 22), Enum.Font.GothamBold, 11, C.CyanSoft)
local bestLabel = label(statsPanel, "Best", "RÉCORD  --", UDim2.new(0, 16, 0, 218), UDim2.new(1, -32, 0, 18), Enum.Font.GothamMedium, 10, C.Muted)

-- ======= PANEL DE PROFUNDIDAD =======
local depthPanel = panel(screenGui, "DepthPanel", UDim2.new(1, -318, 0, 94), UDim2.new(0, 300, 0, 212))
depthPanel.Visible = false
addSectionHeader(depthPanel, "LECTURA DE MINA", "RUTA VERTICAL // ZONA ACTUAL")
local depthBig = label(depthPanel, "DepthBig", "0m", UDim2.new(0, 16, 0, 61), UDim2.new(0, 130, 0, 42), Enum.Font.GothamBlack, 34, C.Cyan)
local depthZone = label(depthPanel, "DepthZone", "SUPERFICIE SEGURA", UDim2.new(0, 148, 0, 69), UDim2.new(0, 130, 0, 21), Enum.Font.GothamBold, 10, C.Mint)

local depthBarBg = Instance.new("Frame")
depthBarBg.Name = "DepthBarBg"
depthBarBg.BackgroundColor3 = C.Dark
depthBarBg.BorderSizePixel = 0
depthBarBg.Position = UDim2.new(0, 16, 0, 116)
depthBarBg.Size = UDim2.new(1, -32, 0, 12)
depthBarBg.Parent = depthPanel
corner(depthBarBg, 6)
local depthFill = Instance.new("Frame")
depthFill.Name = "Fill"
depthFill.BackgroundColor3 = C.Mint
depthFill.BorderSizePixel = 0
depthFill.Size = UDim2.new(0, 0, 1, 0)
depthFill.Parent = depthBarBg
corner(depthFill, 6)
gradient(depthFill, C.Cyan, C.Mint, 0)
local depthMaxText = label(depthPanel, "DepthMax", "MÁXIMO PERSONAL  0m", UDim2.new(0, 16, 0, 137), UDim2.new(1, -32, 0, 17), Enum.Font.GothamBold, 10, C.White)
local depthHint = label(depthPanel, "DepthHint", "Excava hasta encontrar diamante.", UDim2.new(0, 16, 0, 168), UDim2.new(1, -32, 0, 18), Enum.Font.GothamMedium, 10, C.Muted)

local function formatTime(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local remaining = seconds % 60
    if hours > 0 then
        return ("%02d:%02d:%02d"):format(hours, minutes, remaining)
    end
    return ("%02d:%02d"):format(minutes, remaining)
end

local function getDepthZone(depth)
    if depth <= 8 then return "TIERRA // INICIO", C.Mint end
    if depth <= 22 then return "PIEDRA // TÚNEL", C.White end
    if depth <= 48 then return "METALES // EXTRACCIÓN", C.Orange end
    if depth <= 72 then return "ORO // RIESGO MEDIO", C.Gold end
    if depth <= 98 then return "GEMAS // PROFUNDO", C.CyanSoft end
    return "OBSDIANA // ABISMO", Color3.fromRGB(198, 150, 255)
end

local function updateStats(stats)
    if not stats then return end
    local points = stats.Points or 0
    local currentDepth = stats.CurrentDepth or 0
    local maxDepth = stats.MaxDepth or 0
    local totalDepth = stats.MineTotalDepth or 110

    pointsLabel.Text = tostring(points)
    pickaxeLabel.Text = tostring(stats.PickaxeName or "PICO"):upper()
    pickaxePower.Text = ("POTENCIA  %d"):format(stats.PickaxePower or 1)
    blocksLabel.Text = ("BLOQUES  %d"):format(stats.BlocksMined or 0)
    timeLabel.Text = ("TIEMPO  %s"):format(formatTime(stats.PlayTime))
    bestLabel.Text = stats.BestDepthTime and stats.BestDepthTime > 0 and ("RÉCORD  " .. formatTime(stats.BestDepthTime)) or "RÉCORD  AÚN SIN REGISTRO"

    depthBig.Text = ("%dm"):format(currentDepth)
    depthMaxText.Text = ("MÁXIMO PERSONAL  %dm"):format(maxDepth)
    local zone, zoneColor = getDepthZone(currentDepth)
    depthZone.Text = zone
    depthZone.TextColor3 = zoneColor
    depthHint.Text = currentDepth >= totalDepth and "Límite alcanzado // piso de seguridad activo." or "La mina continúa hacia abajo // mantén el ritmo."

    local depthProgress = math.clamp(currentDepth / math.max(1, totalDepth), 0, 1)
    TweenService:Create(topProgressFill, TweenInfo.new(0.35), { Size = UDim2.new(depthProgress, 0, 1, 0) }):Play()
    TweenService:Create(depthFill, TweenInfo.new(0.35), { Size = UDim2.new(depthProgress, 0, 1, 0) }):Play()
    topDepthText.Text = ("PROFUNDIDAD  %d / %dm"):format(currentDepth, totalDepth)

    local currentLevel = stats.CurrentLevelPoints or 0
    local nextLevel = stats.NextLevelPoints
    if nextLevel then
        local progress = math.clamp((points - currentLevel) / math.max(1, nextLevel - currentLevel), 0, 1)
        TweenService:Create(pickaxeFill, TweenInfo.new(0.35), { Size = UDim2.new(progress, 0, 1, 0) }):Play()
        pickaxeProgressText.Text = ("%d / %d  //  SIGUIENTE: %s"):format(points, nextLevel, tostring(stats.NextLevelName or "PICO"):upper())
    else
        pickaxeFill.Size = UDim2.new(1, 0, 1, 0)
        pickaxeProgressText.Text = "NIVEL MÁXIMO // PICO LEGENDARIO"
    end
end

-- ======= NOTIFICACIONES =======
local notifContainer = Instance.new("Frame")
notifContainer.Name = "Notifications"
notifContainer.BackgroundTransparency = 1
notifContainer.AnchorPoint = Vector2.new(0.5, 0)
notifContainer.Position = UDim2.new(0.5, 0, 0, 92)
notifContainer.Size = UDim2.new(0, 500, 0, 220)
notifContainer.Visible = false
notifContainer.Parent = screenGui
local notifLayout = Instance.new("UIListLayout")
notifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifLayout.Padding = UDim.new(0, 7)
notifLayout.Parent = notifContainer

local function showNotification(text)
    local notif = Instance.new("Frame")
    notif.Name = "Toast"
    notif.Size = UDim2.new(0, 420, 0, 42)
    notif.BackgroundColor3 = C.PanelLight
    notif.BackgroundTransparency = 1
    notif.BorderSizePixel = 0
    notif.Parent = notifContainer
    corner(notif, 9)
    stroke(notif, C.Gold, 0.35, 1)

    local bar = Instance.new("Frame")
    bar.BackgroundColor3 = C.Gold
    bar.BorderSizePixel = 0
    bar.Size = UDim2.new(0, 4, 1, 0)
    bar.Parent = notif
    corner(bar, 4)

    local toastLabel = label(notif, "Text", tostring(text), UDim2.new(0, 14, 0, 0), UDim2.new(1, -24, 1, 0), Enum.Font.GothamBlack, 13, C.Gold)
    toastLabel.TextTransparency = 1
    TweenService:Create(notif, TweenInfo.new(0.22), { BackgroundTransparency = 0.08 }):Play()
    TweenService:Create(toastLabel, TweenInfo.new(0.22), { TextTransparency = 0 }):Play()

    task.delay(3.2, function()
        if not notif.Parent then return end
        local fade = TweenService:Create(notif, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
        TweenService:Create(toastLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
        fade:Play()
        fade.Completed:Connect(function()
            notif:Destroy()
        end)
    end)
end

-- ======= TABLERO 3D =======
local boardGui
local boardColumns = {}
local boardRows = {}
local boardBoardReady = false
local boardServerStatus
local latestLeaderboardPayload

local function boardLabel(parent, name, text, position, size, font, textSize, color)
    local item = Instance.new("TextLabel")
    item.Name = name
    item.BackgroundTransparency = 1
    item.Position = position
    item.Size = size
    item.Font = font
    item.Text = text
    item.TextColor3 = color or C.White
    item.TextSize = textSize
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.TextYAlignment = Enum.TextYAlignment.Center
    item.Parent = parent
    return item
end

local function createBoardColumn(parent, name, title, x, accentColor)
    local column = Instance.new("Frame")
    column.Name = name
    column.BackgroundColor3 = Color3.fromRGB(8, 22, 36)
    column.BackgroundTransparency = 0.1
    column.BorderSizePixel = 0
    column.Position = UDim2.new(0, x, 0, 66)
    column.Size = UDim2.new(0, 330, 0, 435)
    column.Parent = parent
    corner(column, 8)
    stroke(column, accentColor, 0.48, 1)
    boardLabel(column, "Title", title, UDim2.new(0, 13, 0, 6), UDim2.new(1, -26, 0, 25), Enum.Font.GothamBlack, 13, accentColor)
    boardLabel(column, "Rule", "────────────────────────", UDim2.new(0, 13, 0, 27), UDim2.new(1, -26, 0, 12), Enum.Font.Gotham, 10, accentColor)
    local rows = {}
    for index = 1, 6 do
        local row = Instance.new("Frame")
        row.Name = "Row" .. index
        row.BackgroundColor3 = index % 2 == 0 and Color3.fromRGB(18, 39, 55) or Color3.fromRGB(12, 31, 47)
        row.BackgroundTransparency = 0.12
        row.BorderSizePixel = 0
        row.Position = UDim2.new(0, 8, 0, 45 + (index - 1) * 62)
        row.Size = UDim2.new(1, -16, 0, 55)
        row.Parent = column
        corner(row, 6)

        boardLabel(row, "Rank", tostring(index), UDim2.new(0, 7, 0, 0), UDim2.new(0, 22, 1, 0), Enum.Font.GothamBlack, 13, index == 1 and C.Gold or C.Muted)
        local image = Instance.new("ImageLabel")
        image.Name = "Avatar"
        image.BackgroundColor3 = C.Dark
        image.BorderSizePixel = 0
        image.Position = UDim2.new(0, 32, 0, 9)
        image.Size = UDim2.new(0, 36, 0, 36)
        image.Image = ""
        image.Parent = row
        corner(image, 8)
        local nameLabel = boardLabel(row, "Name", "Esperando minero...", UDim2.new(0, 78, 0, 4), UDim2.new(1, -154, 0, 22), Enum.Font.GothamBold, 11, C.White)
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        local detailLabel = boardLabel(row, "Detail", "--", UDim2.new(0, 78, 0, 27), UDim2.new(1, -154, 0, 17), Enum.Font.GothamMedium, 9, C.Muted)
        local valueLabel = boardLabel(row, "Value", "--", UDim2.new(1, -72, 0, 0), UDim2.new(0, 64, 1, 0), Enum.Font.GothamBlack, 11, accentColor)
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        rows[index] = { Frame = row, Avatar = image, Name = nameLabel, Detail = detailLabel, Value = valueLabel }
    end
    boardColumns[name] = { Frame = column, Rows = rows, Accent = accentColor }
end

local function setupBoard()
    local board = workspace:WaitForChild("LeaderboardDisplay", 20)
    if not board then return end
    boardGui = Instance.new("SurfaceGui")
    boardGui.Name = "LeaderboardSurface"
    boardGui.Adornee = board
    boardGui.Face = Enum.NormalId.Back
    boardGui.CanvasSize = Vector2.new(1040, 560)
    boardGui.LightInfluence = 0
    boardGui.Brightness = 1.5
    boardGui.AlwaysOnTop = false
    boardGui.Parent = board

    local background = Instance.new("Frame")
    background.Name = "BoardBackground"
    background.Size = UDim2.new(1, 0, 1, 0)
    background.BackgroundColor3 = C.Navy
    background.BorderSizePixel = 0
    background.Parent = boardGui
    gradient(background, Color3.fromRGB(17, 44, 65), Color3.fromRGB(7, 18, 32), 135)

    boardLabel(background, "BoardTitle", "RANKING DEL SERVIDOR  //  MINA PROFUNDA", UDim2.new(0, 28, 0, 14), UDim2.new(0, 700, 0, 31), Enum.Font.GothamBlack, 22, C.CyanSoft)
    boardLabel(background, "BoardSubtitle", "LOS MEJORES EXCAVADORES EN TIEMPO REAL", UDim2.new(0, 30, 0, 42), UDim2.new(0, 600, 0, 17), Enum.Font.GothamBold, 10, C.Mint)
    boardServerStatus = boardLabel(background, "ServerStatus", "● ESCÁNER ONLINE", UDim2.new(1, -310, 0, 24), UDim2.new(0, 280, 0, 24), Enum.Font.GothamBlack, 11, C.Mint)
    boardServerStatus.TextXAlignment = Enum.TextXAlignment.Right

    createBoardColumn(background, "Depth", "▾  MÁS PROFUNDO", 20, C.Cyan)
    createBoardColumn(background, "Speed", "◷  MÁS RÁPIDO", 355, C.Orange)
    createBoardColumn(background, "Points", "◆  MÁS PUNTOS", 690, C.Gold)

    boardBoardReady = true
end

local function updateBoardColumn(name, entries, valueFormat, detailFormat)
    local column = boardColumns[name]
    if not column then return end
    entries = entries or {}
    for index = 1, 6 do
        local row = column.Rows[index]
        local entry = entries[index]
        if entry then
            row.Avatar.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=100&h=100"):format(entry.UserId or 0)
            row.Name.Text = (entry.Name or entry.Username or "MINERO"):upper()
            row.Detail.Text = detailFormat(entry)
            row.Value.Text = valueFormat(entry)
            row.Frame.BackgroundColor3 = index == 1 and Color3.fromRGB(53, 56, 50) or (index % 2 == 0 and Color3.fromRGB(18, 39, 55) or Color3.fromRGB(12, 31, 47))
        else
            row.Avatar.Image = ""
            row.Name.Text = "ESPERANDO MINERO..."
            row.Detail.Text = "ÚNETE A LA EXCAVACIÓN"
            row.Value.Text = "--"
            row.Frame.BackgroundColor3 = Color3.fromRGB(12, 31, 47)
        end
    end
end

local function updateBoard(payload)
    if not boardBoardReady or not payload then return end
    updateBoardColumn("Depth", payload.Depth, function(entry)
        return (" %dm"):format(entry.MaxDepth or 0)
    end, function(entry)
        return ("%d bloques  //  %s jugado"):format(entry.BlocksMined or 0, formatTime(entry.PlayTime))
    end)
    updateBoardColumn("Speed", payload.Speed, function(entry)
        return entry.BestDepthTime and entry.BestDepthTime > 0 and formatTime(entry.BestDepthTime) or "--"
    end, function(entry)
        return ("hasta %dm  //  %s jugado"):format(entry.MaxDepth or 0, formatTime(entry.PlayTime))
    end)
    updateBoardColumn("Points", payload.Points, function(entry)
        return ("%d"):format(entry.Points or 0)
    end, function(entry)
        return ("%dm  //  %s jugado"):format(entry.MaxDepth or 0, formatTime(entry.PlayTime))
    end)
    if boardServerStatus then
        boardServerStatus.Text = ("● ESCÁNER ONLINE  //  %d MINEROS"):format(payload.ServerSize or 0)
    end
end

statsUpdateEvent.OnClientEvent:Connect(updateStats)
notifyEvent.OnClientEvent:Connect(showNotification)
leaderboardUpdateEvent.OnClientEvent:Connect(function(payload)
    latestLeaderboardPayload = payload
    updateBoard(payload)
end)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.B then
        local enabled = buildButton.Text:find("CONSTRUIR") ~= nil
        setBuildMode(not enabled)
    end
end)

-- El tablero es físico dentro del mundo; el HUD normal sigue oculto para mantener la pantalla limpia.
task.spawn(function()
    setupBoard()
    if latestLeaderboardPayload then
        updateBoard(latestLeaderboardPayload)
    end
end)
setBuildMode(false)
print("[MiningUI] HUD tecnológico, perfil, progreso y monitor 3D listos.")

--[=[
    MiningUI.client.lua
    UBICACIÓN: StarterPlayer > StarterPlayerScripts

    HUD compacto de Crónicas de Lumenfall. Las estaciones y el registro principal
    continúan siendo objetos físicos dentro del mundo.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LumenRemotes")
local statsUpdate = remotes:WaitForChild("StatsUpdate")
local notify = remotes:WaitForChild("Notify")

local gui = Instance.new("ScreenGui")
gui.Name = "LumenfallHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent, radius)
    local item = Instance.new("UICorner")
    item.CornerRadius = UDim.new(0, radius)
    item.Parent = parent
end

local function text(parent, value, position, size, font, textSize, color)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = position
    label.Size = size
    label.Font = font
    label.Text = value
    label.TextSize = textSize
    label.TextColor3 = color
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent
    return label
end

local panel = Instance.new("Frame")
panel.Name = "LumenStatus"
panel.Position = UDim2.new(0, 14, 0, 14)
panel.Size = UDim2.new(0, 244, 0, 126)
panel.BackgroundColor3 = Color3.fromRGB(8, 20, 33)
panel.BackgroundTransparency = 0.17
panel.BorderSizePixel = 0
panel.Parent = gui
corner(panel, 10)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(88, 178, 205)
stroke.Transparency = 0.3
stroke.Parent = panel

text(panel, "CRÓNICAS DE LUMENFALL", UDim2.new(0, 13, 0, 10), UDim2.new(1, -26, 0, 17), Enum.Font.GothamBlack, 12, Color3.fromRGB(137, 236, 255))
local energyLabel = text(panel, "ENERGÍA 100 / 100", UDim2.new(0, 13, 0, 35), UDim2.new(1, -26, 0, 16), Enum.Font.GothamBold, 11, Color3.fromRGB(184, 255, 216))

local energyBack = Instance.new("Frame")
energyBack.Position = UDim2.new(0, 13, 0, 55)
energyBack.Size = UDim2.new(1, -26, 0, 9)
energyBack.BackgroundColor3 = Color3.fromRGB(28, 49, 63)
energyBack.BorderSizePixel = 0
energyBack.Parent = panel
corner(energyBack, 5)

local energyFill = Instance.new("Frame")
energyFill.Size = UDim2.new(1, 0, 1, 0)
energyFill.BackgroundColor3 = Color3.fromRGB(99, 236, 181)
energyFill.BorderSizePixel = 0
energyFill.Parent = energyBack
corner(energyFill, 5)

local resourcesLabel = text(panel, "MADERA 0   PIEDRA 0\nCRISTAL 0   LUMEN 0", UDim2.new(0, 13, 0, 75), UDim2.new(1, -26, 0, 38), Enum.Font.GothamBold, 10, Color3.fromRGB(229, 240, 250))

local controls = text(gui, "CLICK/TOQUE: RECOLECTAR   ·   B: CONSTRUIR   ·   1-4: MATERIAL", UDim2.new(0.5, -210, 1, -34), UDim2.new(0, 420, 0, 20), Enum.Font.GothamBold, 10, Color3.fromRGB(220, 239, 250))
controls.TextXAlignment = Enum.TextXAlignment.Center

local toast = Instance.new("TextLabel")
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 18)
toast.Size = UDim2.new(0, 460, 0, 34)
toast.BackgroundColor3 = Color3.fromRGB(13, 35, 52)
toast.BackgroundTransparency = 1
toast.BorderSizePixel = 0
toast.Font = Enum.Font.GothamBlack
toast.TextSize = 12
toast.TextColor3 = Color3.fromRGB(255, 224, 128)
toast.TextTransparency = 1
toast.Text = ""
toast.Parent = gui
corner(toast, 8)

local activeToast = 0
local function showToast(message)
    activeToast = activeToast + 1
    local id = activeToast
    toast.Text = tostring(message)
    TweenService:Create(toast, TweenInfo.new(0.2), { BackgroundTransparency = 0.12, TextTransparency = 0 }):Play()
    task.delay(2.7, function()
        if id ~= activeToast then return end
        TweenService:Create(toast, TweenInfo.new(0.3), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
    end)
end

statsUpdate.OnClientEvent:Connect(function(stats)
    local resources = stats.Resources or {}
    local energy = math.clamp(tonumber(stats.Energy) or 0, 0, tonumber(stats.MaxEnergy) or 100)
    local maximum = math.max(1, tonumber(stats.MaxEnergy) or 100)
    energyLabel.Text = ("ENERGÍA %d / %d  //  BALIZAS %d"):format(energy, maximum, tonumber(stats.Beacons) or 0)
    resourcesLabel.Text = ("MADERA %d   PIEDRA %d\nCRISTAL %d   LUMEN %d"):format(resources.Madera or 0, resources.Piedra or 0, resources.Cristal or 0, resources.Lumen or 0)
    local color = energy > 35 and Color3.fromRGB(99, 236, 181) or Color3.fromRGB(255, 142, 102)
    energyFill.BackgroundColor3 = color
    TweenService:Create(energyFill, TweenInfo.new(0.35), { Size = UDim2.new(energy / maximum, 0, 1, 0) }):Play()
end)

notify.OnClientEvent:Connect(showToast)
print("[LumenfallHUD] Interfaz compacta lista.")

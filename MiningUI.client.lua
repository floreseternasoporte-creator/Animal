--[[
	MiningUI.client.lua
	UBICACIÓN: StarterPlayer > StarterPlayerScripts

	Crea toda la interfaz gráfica (ScreenGui) por código:
	- Panel con puntos, profundidad máxima alcanzada y pico actual
	- Barra de progreso hacia el siguiente nivel de pico
	- Notificaciones tipo "toast" cuando subes de nivel

	Solo lee datos que el servidor manda por RemoteEvent. No calcula nada por sí solo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("MiningRemotes")
local statsUpdateEvent = remotesFolder:WaitForChild("StatsUpdate")
local notifyEvent = remotesFolder:WaitForChild("Notify")

-- ======= CONSTRUCCIÓN DE LA UI =======

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MiningUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- --- Panel principal (esquina superior izquierda) ---
local panel = Instance.new("Frame")
panel.Name = "StatsPanel"
panel.Size = UDim2.new(0, 260, 0, 130)
panel.Position = UDim2.new(0, 20, 0, 20)
panel.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

local panelPadding = Instance.new("UIPadding")
panelPadding.PaddingTop = UDim.new(0, 10)
panelPadding.PaddingLeft = UDim.new(0, 14)
panelPadding.PaddingRight = UDim.new(0, 14)
panelPadding.Parent = panel

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.BackgroundTransparency = 1
titleLabel.Size = UDim2.new(1, 0, 0, 22)
titleLabel.Font = Enum.Font.FredokaOne
titleLabel.Text = "⛏️ Minero"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextSize = 20
titleLabel.Parent = panel

local pointsLabel = Instance.new("TextLabel")
pointsLabel.Name = "Points"
pointsLabel.BackgroundTransparency = 1
pointsLabel.Position = UDim2.new(0, 0, 0, 26)
pointsLabel.Size = UDim2.new(1, 0, 0, 20)
pointsLabel.Font = Enum.Font.GothamBold
pointsLabel.Text = "Puntos: 0"
pointsLabel.TextColor3 = Color3.fromRGB(255, 230, 80)
pointsLabel.TextXAlignment = Enum.TextXAlignment.Left
pointsLabel.TextSize = 16
pointsLabel.Parent = panel

local depthLabel = Instance.new("TextLabel")
depthLabel.Name = "Depth"
depthLabel.BackgroundTransparency = 1
depthLabel.Position = UDim2.new(0, 0, 0, 46)
depthLabel.Size = UDim2.new(1, 0, 0, 20)
depthLabel.Font = Enum.Font.Gotham
depthLabel.Text = "Profundidad máxima: 0m"
depthLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
depthLabel.TextXAlignment = Enum.TextXAlignment.Left
depthLabel.TextSize = 14
depthLabel.Parent = panel

local pickaxeLabel = Instance.new("TextLabel")
pickaxeLabel.Name = "Pickaxe"
pickaxeLabel.BackgroundTransparency = 1
pickaxeLabel.Position = UDim2.new(0, 0, 0, 66)
pickaxeLabel.Size = UDim2.new(1, 0, 0, 20)
pickaxeLabel.Font = Enum.Font.Gotham
pickaxeLabel.Text = "Pico: Pico de Madera"
pickaxeLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
pickaxeLabel.TextXAlignment = Enum.TextXAlignment.Left
pickaxeLabel.TextSize = 14
pickaxeLabel.Parent = panel

-- Barra de progreso hacia el siguiente nivel
local progressBg = Instance.new("Frame")
progressBg.Name = "ProgressBarBg"
progressBg.Position = UDim2.new(0, 0, 0, 92)
progressBg.Size = UDim2.new(1, 0, 0, 16)
progressBg.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
progressBg.BorderSizePixel = 0
progressBg.Parent = panel

local progressBgCorner = Instance.new("UICorner")
progressBgCorner.CornerRadius = UDim.new(1, 0)
progressBgCorner.Parent = progressBg

local progressFill = Instance.new("Frame")
progressFill.Name = "Fill"
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = Color3.fromRGB(90, 200, 255)
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBg

local progressFillCorner = Instance.new("UICorner")
progressFillCorner.CornerRadius = UDim.new(1, 0)
progressFillCorner.Parent = progressFill

local progressText = Instance.new("TextLabel")
progressText.BackgroundTransparency = 1
progressText.Size = UDim2.new(1, 0, 1, 0)
progressText.Font = Enum.Font.GothamBold
progressText.Text = ""
progressText.TextColor3 = Color3.fromRGB(255, 255, 255)
progressText.TextSize = 11
progressText.TextStrokeTransparency = 0.5
progressText.Parent = progressBg

-- --- Contenedor de notificaciones (centro-arriba) ---
local notifContainer = Instance.new("Frame")
notifContainer.Name = "Notifications"
notifContainer.BackgroundTransparency = 1
notifContainer.Size = UDim2.new(0, 400, 0, 200)
notifContainer.Position = UDim2.new(0.5, -200, 0, 20)
notifContainer.Parent = screenGui

local notifLayout = Instance.new("UIListLayout")
notifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifLayout.Padding = UDim.new(0, 6)
notifLayout.Parent = notifContainer

-- ======= FUNCIONES DE ACTUALIZACIÓN =======

local function updateStats(stats)
	pointsLabel.Text = "Puntos: " .. tostring(stats.Points)
	depthLabel.Text = "Profundidad máxima: " .. tostring(stats.MaxDepth) .. " capas"
	pickaxeLabel.Text = "Pico: " .. stats.PickaxeName

	if stats.NextLevelPoints then
		local currentLevelStart = 0
		-- Buscamos el punto de inicio del nivel actual de forma aproximada
		-- usando la diferencia hacia el siguiente nivel para la barra
		local progress = math.clamp(stats.Points / stats.NextLevelPoints, 0, 1)

		TweenService:Create(progressFill, TweenInfo.new(0.3), {
			Size = UDim2.new(progress, 0, 1, 0),
		}):Play()

		progressText.Text = tostring(stats.Points) .. " / " .. tostring(stats.NextLevelPoints) .. " → " .. stats.NextLevelName
	else
		progressFill.Size = UDim2.new(1, 0, 1, 0)
		progressText.Text = "¡Nivel máximo alcanzado!"
	end
end

local function showNotification(text)
	local notif = Instance.new("Frame")
	notif.Size = UDim2.new(0, 320, 0, 40)
	notif.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	notif.BackgroundTransparency = 0.1
	notif.BorderSizePixel = 0
	notif.Parent = notifContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = notif

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -10, 1, 0)
	label.Position = UDim2.new(0, 5, 0, 0)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 230, 80)
	label.TextScaled = true
	label.Parent = notif

	notif.BackgroundTransparency = 1
	label.TextTransparency = 1
	TweenService:Create(notif, TweenInfo.new(0.25), { BackgroundTransparency = 0.1 }):Play()
	TweenService:Create(label, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()

	task.delay(3, function()
		local fadeOut = TweenService:Create(notif, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		fadeOut:Play()
		fadeOut.Completed:Connect(function()
			notif:Destroy()
		end)
	end)
end

-- ======= CONEXIONES A EVENTOS DEL SERVIDOR =======

statsUpdateEvent.OnClientEvent:Connect(updateStats)
notifyEvent.OnClientEvent:Connect(showNotification)

print("[MiningUI] Interfaz lista.")

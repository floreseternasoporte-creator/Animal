--[[
	MiningController.client.lua
	UBICACIÓN: StarterPlayer > StarterPlayerScripts

	Este script SOLO se encarga de:
	- Detectar cuándo el jugador hace click/tap sobre un bloque minable
	- Pedirle al servidor que lo mine (el servidor decide si es válido)
	- Reproducir efectos visuales y sonoros cuando el servidor confirma golpes/roturas

	IMPORTANTE: este script NO otorga puntos ni decide nada del juego.
	Toda la lógica real vive en el servidor (MiningHandler.server.lua).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Esperar a que el servidor cree los RemoteEvents
local remotesFolder = ReplicatedStorage:WaitForChild("MiningRemotes")
local mineBlockEvent = remotesFolder:WaitForChild("MineBlockRequest")
local blockHitEvent = remotesFolder:WaitForChild("BlockHit")
local blockBrokenEvent = remotesFolder:WaitForChild("BlockBroken")

-- Rango máximo desde el que el cliente permite intentar minar (coincide con el del servidor)
local CLICK_MAX_DISTANCE = 15

-- Cooldown local para no spamear el RemoteEvent mientras se mantiene el click
local MINE_INTERVAL = 0.15
local lastMineAttempt = 0
local isMouseDown = false
local currentTarget = nil

-- ======= EFECTOS VISUALES =======

-- Crea un pequeño efecto de partículas cuando se golpea un bloque
local function playHitEffect(block)
	if not block or not block.Parent then return end

	local attachment = Instance.new("Attachment")
	attachment.Parent = block

	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Color = ColorSequence.new(block.Color)
	particles.Lifetime = NumberRange.new(0.2, 0.4)
	particles.Rate = 0
	particles.Speed = NumberRange.new(4, 8)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Size = NumberSequence.new(0.3)
	particles.Parent = attachment

	particles:Emit(12)
	Debris:AddItem(attachment, 1)

	-- Pequeño "shake" de escala para dar sensación de impacto
	local originalSize = block.Size
	local tweenDown = TweenService:Create(block, TweenInfo.new(0.05), { Size = originalSize * 0.95 })
	tweenDown:Play()
	tweenDown.Completed:Connect(function()
		if block.Parent then
			TweenService:Create(block, TweenInfo.new(0.08), { Size = originalSize }):Play()
		end
	end)
end

-- Crea un efecto más grande de "explosión" cuando el bloque se rompe
local function playBreakEffect(block, layerName, points)
	if not block then return end

	local position = block.Position
	local color = block.Color

	-- Partículas de rotura
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.Position = position
	part.Parent = workspace

	local attachment = Instance.new("Attachment")
	attachment.Parent = part

	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Color = ColorSequence.new(color)
	particles.Lifetime = NumberRange.new(0.4, 0.8)
	particles.Rate = 0
	particles.Speed = NumberRange.new(8, 16)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Size = NumberSequence.new(0.5, 0)
	particles.Parent = attachment

	particles:Emit(25)
	Debris:AddItem(part, 1.5)

	-- Texto flotante mostrando los puntos ganados
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(4, 0, 1.5, 0)
	billboard.StudsOffset = Vector3.new(0, 1, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Font = Enum.Font.FredokaOne
	label.Text = "+" .. tostring(points)
	label.TextColor3 = Color3.fromRGB(255, 230, 80)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Parent = billboard

	local tween = TweenService:Create(part, TweenInfo.new(0.9, Enum.EasingStyle.Quad), {
		Position = position + Vector3.new(0, 4, 0),
	})
	tween:Play()

	TweenService:Create(label, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end

-- ======= DETECCIÓN DE INPUT =======

-- Revisa qué bloque está bajo el mouse y, si es válido, intenta minarlo
local function tryMine()
	local target = mouse.Target
	if not target then return end
	if not target:GetAttribute("IsMineable") then return end

	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local distance = (hrp.Position - target.Position).Magnitude
	if distance > CLICK_MAX_DISTANCE then return end

	local now = os.clock()
	if now - lastMineAttempt < MINE_INTERVAL then return end
	lastMineAttempt = now

	-- Reproducir un pequeño efecto de golpe inmediato (feedback rápido, aunque el servidor
	-- es quien decide si realmente se rompe o no)
	playHitEffect(target)

	mineBlockEvent:FireServer(target)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isMouseDown = true
		tryMine()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isMouseDown = false
	end
end)

-- Mientras el jugador mantiene presionado el botón, seguir intentando minar (picar sostenido)
RunService.RenderStepped:Connect(function()
	if isMouseDown then
		tryMine()
	end
end)

-- ======= RESPUESTA A EVENTOS DEL SERVIDOR =======

blockHitEvent.OnClientEvent:Connect(function(block, hitsLeft, maxHits)
	playHitEffect(block)
end)

blockBrokenEvent.OnClientEvent:Connect(function(block, layerName, points)
	playBreakEffect(block, layerName, points)
end)

print("[MiningController] Cliente de minería listo.")

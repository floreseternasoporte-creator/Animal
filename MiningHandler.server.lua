--[[
	MiningHandler.server.lua
	UBICACIÓN: ServerScriptService

	Este script es el "cerebro" del juego:
	- Crea los RemoteEvents que usa el cliente para pedir romper un bloque
	- VALIDA en el servidor que el jugador realmente pueda romper ese bloque
	  (distancia, que exista, cooldown) para evitar exploits/cheats
	- Otorga puntos y actualiza el nivel de picador del jugador
	- Guarda el progreso con DataStore para que no se pierda al salir
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local DataStoreService = game:GetService("DataStoreService")

local mineDataStore = DataStoreService:GetDataStore("MiningGame_PlayerData_v1")

-- ======= REMOTE EVENTS =======
-- Carpeta de RemoteEvents dentro de ReplicatedStorage para comunicación cliente-servidor
local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "MiningRemotes"
remotesFolder.Parent = ReplicatedStorage

local mineBlockEvent = Instance.new("RemoteEvent")
mineBlockEvent.Name = "MineBlockRequest"       -- Cliente -> Servidor: "quiero minar este bloque"
mineBlockEvent.Parent = remotesFolder

local blockHitEvent = Instance.new("RemoteEvent")
blockHitEvent.Name = "BlockHit"                -- Servidor -> Cliente: "el bloque recibió un golpe" (para efectos)
blockHitEvent.Parent = remotesFolder

local blockBrokenEvent = Instance.new("RemoteEvent")
blockBrokenEvent.Name = "BlockBroken"          -- Servidor -> Cliente: "el bloque se rompió" (para efectos + sonido)
blockBrokenEvent.Parent = remotesFolder

local statsUpdateEvent = Instance.new("RemoteEvent")
statsUpdateEvent.Name = "StatsUpdate"          -- Servidor -> Cliente: actualiza la UI (puntos, nivel, profundidad)
statsUpdateEvent.Parent = remotesFolder

local notifyEvent = Instance.new("RemoteEvent")
notifyEvent.Name = "Notify"                    -- Servidor -> Cliente: notificaciones tipo "¡Subiste de nivel!"
notifyEvent.Parent = remotesFolder

-- ======= NIVELES DE PICADOR =======
-- Mientras más puntos totales tenga el jugador, mejor es su pico
-- (rompe bloques más rápido: menos golpes necesarios).
local PICKAXE_LEVELS = {
	{ Name = "Pico de Madera",   MinPoints = 0,    Power = 1 },
	{ Name = "Pico de Piedra",   MinPoints = 50,   Power = 2 },
	{ Name = "Pico de Hierro",   MinPoints = 150,  Power = 3 },
	{ Name = "Pico de Oro",      MinPoints = 400,  Power = 4 },
	{ Name = "Pico de Diamante", MinPoints = 800,  Power = 6 },
	{ Name = "Pico de Esmeralda",MinPoints = 1500, Power = 8 },
	{ Name = "Pico Legendario",  MinPoints = 3000, Power = 12 },
}

-- Distancia máxima permitida entre jugador y bloque para poder minarlo (anti-cheat)
local MAX_MINE_DISTANCE = 15

-- Cooldown mínimo entre golpes (en segundos) para evitar spam de RemoteEvent
local HIT_COOLDOWN = 0.15

-- Tablas en memoria con el estado de cada jugador
local playerData = {}     -- [Player] = { Points = 0, MaxDepth = 0, LastHitTime = 0 }

-- ======= FUNCIONES AUXILIARES =======

local function getPickaxeLevel(points)
	local current = PICKAXE_LEVELS[1]
	for _, level in ipairs(PICKAXE_LEVELS) do
		if points >= level.MinPoints then
			current = level
		end
	end
	return current
end

local function getNextPickaxeLevel(points)
	for _, level in ipairs(PICKAXE_LEVELS) do
		if points < level.MinPoints then
			return level
		end
	end
	return nil -- ya está en el nivel máximo
end

-- Envía al cliente el estado actual (puntos, nivel, profundidad máxima)
local function sendStatsUpdate(player)
	local data = playerData[player]
	if not data then return end

	local currentLevel = getPickaxeLevel(data.Points)
	local nextLevel = getNextPickaxeLevel(data.Points)

	statsUpdateEvent:FireClient(player, {
		Points = data.Points,
		MaxDepth = data.MaxDepth,
		PickaxeName = currentLevel.Name,
		PickaxePower = currentLevel.Power,
		NextLevelPoints = nextLevel and nextLevel.MinPoints or nil,
		NextLevelName = nextLevel and nextLevel.Name or nil,
	})
end

-- Carga los datos guardados del jugador (o crea datos nuevos)
local function loadPlayerData(player)
	local success, savedData = pcall(function()
		return mineDataStore:GetAsync("Player_" .. player.UserId)
	end)

	if success and savedData then
		playerData[player] = {
			Points = savedData.Points or 0,
			MaxDepth = savedData.MaxDepth or 0,
			LastHitTime = 0,
		}
	else
		playerData[player] = {
			Points = 0,
			MaxDepth = 0,
			LastHitTime = 0,
		}
	end

	sendStatsUpdate(player)
end

-- Guarda los datos del jugador en el DataStore
local function savePlayerData(player)
	local data = playerData[player]
	if not data then return end

	local success, err = pcall(function()
		mineDataStore:SetAsync("Player_" .. player.UserId, {
			Points = data.Points,
			MaxDepth = data.MaxDepth,
		})
	end)

	if not success then
		warn("[MiningHandler] Error guardando datos de", player.Name, ":", err)
	end
end

-- ======= LÓGICA PRINCIPAL: MINAR UN BLOQUE =======

local function onMineBlockRequest(player, block)
	-- Validaciones de seguridad (todo esto pasa en servidor, nunca confiar en el cliente)
	if not block or not block:IsA("BasePart") then return end
	if not block:GetAttribute("IsMineable") then return end
	if not block.Parent then return end -- ya fue removido

	local data = playerData[player]
	if not data then return end

	-- Cooldown anti-spam
	local now = os.clock()
	if now - data.LastHitTime < HIT_COOLDOWN then return end
	data.LastHitTime = now

	-- Validar distancia (anti-cheat: que el jugador esté cerca del bloque)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local distance = (hrp.Position - block.Position).Magnitude
	if distance > MAX_MINE_DISTANCE then return end

	-- Calcular poder de minado según el nivel de pico del jugador
	local pickaxeLevel = getPickaxeLevel(data.Points)
	local power = pickaxeLevel.Power

	local hitsLeft = block:GetAttribute("HitsLeft") - power
	block:SetAttribute("HitsLeft", math.max(hitsLeft, 0))

	if hitsLeft > 0 then
		-- El bloque aguantó el golpe, avisar al cliente para efectos visuales (partículas, cámara shake, etc.)
		blockHitEvent:FireClient(player, block, hitsLeft, block:GetAttribute("MaxHits"))
	else
		-- ¡Bloque destruido!
		local points = block:GetAttribute("Points")
		local depth = block:GetAttribute("Depth")
		local layerName = block:GetAttribute("LayerName")

		local previousLevel = getPickaxeLevel(data.Points)

		data.Points += points
		if depth > data.MaxDepth then
			data.MaxDepth = depth
		end

		local newLevel = getPickaxeLevel(data.Points)

		-- Avisar a todos los clientes cercanos que el bloque se rompió (para efectos)
		blockBrokenEvent:FireClient(player, block, layerName, points)

		block:SetAttribute("IsMineable", false)
		block:Destroy()

		-- Si subió de nivel de pico, notificar
		if newLevel.Name ~= previousLevel.Name then
			notifyEvent:FireClient(player, ("¡Subiste de nivel! Ahora tienes: %s"):format(newLevel.Name))
		end

		sendStatsUpdate(player)
	end
end

mineBlockEvent.OnServerEvent:Connect(onMineBlockRequest)

-- ======= EVENTOS DE JUGADORES =======

Players.PlayerAdded:Connect(function(player)
	loadPlayerData(player)

	player.CharacterAdded:Connect(function(character)
		-- Pequeño delay para que el HumanoidRootPart exista
		task.wait(0.5)
		sendStatsUpdate(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayerData(player)
	playerData[player] = nil
end)

-- Autoguardado cada 2 minutos por si el servidor se cae
task.spawn(function()
	while true do
		task.wait(120)
		for _, player in ipairs(Players:GetPlayers()) do
			savePlayerData(player)
		end
	end
end)

-- Guardar también si el servidor se está cerrando
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayerData(player)
	end
end)

print("[MiningHandler] Sistema de minería listo.")

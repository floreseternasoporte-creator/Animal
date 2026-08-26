--[=[
    MiningHandler.server.lua
    UBICACIÓN: ServerScriptService

    Cerebro seguro de la mina:
    - Valida cada golpe y cada bloque en el servidor.
    - Guarda puntos, profundidad, bloques rotos, tiempo jugado y récord de velocidad.
    - Publica rankings vivos del servidor para el monitor 3D.
    - Permite construir bloques de vuelta en modo construcción.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local DataStoreService = game:GetService("DataStoreService")

local mineDataStore = DataStoreService:GetDataStore("MiningGame_PlayerData_v2")
local blocksFolder = Workspace:WaitForChild("MineBlocks")

local CONFIG = {
    MaxMineDistance = 18,
    HitCooldown = 0.13,
    BuildCooldown = 0.25,
    AutoSaveSeconds = 120,
    LeaderboardLimit = 6,
    BlockSize = Workspace:GetAttribute("MineBlockSize") or 6,
    StartY = Workspace:GetAttribute("MineStartY") or 64,
    GridSize = Workspace:GetAttribute("MineGridSize") or 18,
    TotalDepth = Workspace:GetAttribute("MineTotalDepth") or 110,
}

local MINE_WIDTH = CONFIG.GridSize * CONFIG.BlockSize
local HALF_GRID = math.floor(CONFIG.GridSize / 2)
local MIN_GRID_COORD = -HALF_GRID * CONFIG.BlockSize
local MAX_GRID_COORD = (HALF_GRID - 1) * CONFIG.BlockSize

-- ======= REMOTES =======
local remotesFolder = ReplicatedStorage:FindFirstChild("MiningRemotes")
if not remotesFolder then
    remotesFolder = Instance.new("Folder")
    remotesFolder.Name = "MiningRemotes"
    remotesFolder.Parent = ReplicatedStorage
end

local function getOrCreateRemote(name, className)
    local remote = remotesFolder:FindFirstChild(name)
    if not remote then
        remote = Instance.new(className or "RemoteEvent")
        remote.Name = name
        remote.Parent = remotesFolder
    end
    return remote
end

local mineBlockEvent = getOrCreateRemote("MineBlockRequest")
local blockHitEvent = getOrCreateRemote("BlockHit")
local blockBrokenEvent = getOrCreateRemote("BlockBroken")
local specialDiscoveryEvent = getOrCreateRemote("SpecialDiscovery")
local statsUpdateEvent = getOrCreateRemote("StatsUpdate")
local notifyEvent = getOrCreateRemote("Notify")
local leaderboardUpdateEvent = getOrCreateRemote("LeaderboardUpdate")
local placeBlockEvent = getOrCreateRemote("PlaceBlockRequest")
local blockPlacedEvent = getOrCreateRemote("BlockPlaced")

-- ======= PROGRESIÓN DEL PICO =======
local PICKAXE_LEVELS = {
    { Name = "Pico de Madera",    MinPoints = 0,    Power = 1 },
    { Name = "Pico de Piedra",    MinPoints = 50,   Power = 2 },
    { Name = "Pico de Hierro",    MinPoints = 150,  Power = 3 },
    { Name = "Pico de Oro",       MinPoints = 400,  Power = 4 },
    { Name = "Pico de Diamante",  MinPoints = 800,  Power = 6 },
    { Name = "Pico de Esmeralda", MinPoints = 1500, Power = 8 },
    { Name = "Pico de Zafiro",    MinPoints = 2800, Power = 10 },
    { Name = "Pico de Cristal",   MinPoints = 4800, Power = 13 },
    { Name = "Pico de Magma",     MinPoints = 7600, Power = 17 },
    { Name = "Pico de Obsidiana", MinPoints = 11000, Power = 22 },
    { Name = "Pico Estelar",      MinPoints = 16000, Power = 30 },
}

local playerData = {}

local function getPickaxeLevel(points)
    points = tonumber(points) or 0
    local current = PICKAXE_LEVELS[1]
    for _, level in ipairs(PICKAXE_LEVELS) do
        local minimum = tonumber(level.MinPoints) or 0
        if points >= minimum then
            current = level
        end
    end
    return current
end

local function getNextPickaxeLevel(points)
    points = tonumber(points) or 0
    for _, level in ipairs(PICKAXE_LEVELS) do
        local minimum = tonumber(level.MinPoints) or math.huge
        if points < minimum then
            return level
        end
    end
    return nil
end

local function getPlayTime(data)
    return math.max(0, (data.PlayTime or 0) + math.floor(time() - (data.SessionStartedAt or time())))
end

local function getCurrentDepth(player)
    local character = player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0 end
    return math.clamp(math.max(0, math.floor((CONFIG.StartY - hrp.Position.Y) / CONFIG.BlockSize)), 0, CONFIG.TotalDepth)
end

local function ensureLeaderstats(player)
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then
        leaderstats = Instance.new("Folder")
        leaderstats.Name = "leaderstats"
        leaderstats.Parent = player
    end

    local function value(name, className)
        local item = leaderstats:FindFirstChild(name)
        if not item then
            item = Instance.new(className or "IntValue")
            item.Name = name
            item.Parent = leaderstats
        end
        return item
    end

    return {
        Points = value("Puntos"),
        Depth = value("Profundidad"),
        Blocks = value("Bloques"),
        Time = value("TiempoMin", "IntValue"),
    }
end

local function updateLeaderstats(player, currentDepth)
    local data = playerData[player]
    if not data then return end
    local stats = ensureLeaderstats(player)
    stats.Points.Value = data.Points
    stats.Depth.Value = data.MaxDepth
    stats.Blocks.Value = data.BlocksMined
    stats.Time.Value = math.floor(getPlayTime(data) / 60)
end

local function makeEntry(player)
    local data = playerData[player]
    if not data then return nil end
    return {
        Name = player.DisplayName,
        Username = player.Name,
        UserId = player.UserId,
        Points = data.Points,
        MaxDepth = data.MaxDepth,
        BlocksMined = data.BlocksMined,
        PlayTime = getPlayTime(data),
        BestDepthTime = data.BestDepthTime or 0,
    }
end

local function sortedCopy(entries, comparator)
    local copy = table.clone(entries)
    table.sort(copy, comparator)
    return copy
end

local function buildLeaderboardPayload()
    local entries = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local entry = makeEntry(player)
        if entry then table.insert(entries, entry) end
    end

    local depth = sortedCopy(entries, function(a, b)
        if a.MaxDepth == b.MaxDepth then return a.Points > b.Points end
        return a.MaxDepth > b.MaxDepth
    end)
    local speed = sortedCopy(entries, function(a, b)
        local aTime = a.BestDepthTime > 0 and a.BestDepthTime or math.huge
        local bTime = b.BestDepthTime > 0 and b.BestDepthTime or math.huge
        if aTime == bTime then return a.MaxDepth > b.MaxDepth end
        return aTime < bTime
    end)
    local points = sortedCopy(entries, function(a, b)
        if a.Points == b.Points then return a.MaxDepth > b.MaxDepth end
        return a.Points > b.Points
    end)

    local function limit(list)
        local result = {}
        for index = 1, math.min(CONFIG.LeaderboardLimit, #list) do
            result[index] = list[index]
        end
        return result
    end

    return {
        Depth = limit(depth),
        Speed = limit(speed),
        Points = limit(points),
        ServerSize = #entries,
        UpdatedAt = os.time(),
    }
end

local function broadcastLeaderboards()
    leaderboardUpdateEvent:FireAllClients(buildLeaderboardPayload())
end

local function sendStatsUpdate(player)
    local data = playerData[player]
    if not data then return end

    local currentLevel = getPickaxeLevel(data.Points)
    local nextLevel = getNextPickaxeLevel(data.Points)
    local currentDepth = getCurrentDepth(player)
    updateLeaderstats(player, currentDepth)

    statsUpdateEvent:FireClient(player, {
        Points = data.Points,
        MaxDepth = data.MaxDepth,
        CurrentDepth = currentDepth,
        BlocksMined = data.BlocksMined,
        PlayTime = getPlayTime(data),
        BestDepthTime = data.BestDepthTime or 0,
        PickaxeName = currentLevel.Name,
        PickaxePower = currentLevel.Power,
        CurrentLevelPoints = currentLevel.MinPoints,
        NextLevelPoints = nextLevel and nextLevel.MinPoints or nil,
        NextLevelName = nextLevel and nextLevel.Name or nil,
        MineTotalDepth = CONFIG.TotalDepth,
    })
end

-- ======= DATOS =======
local function newPlayerData()
    return {
        Points = 0,
        MaxDepth = 0,
        BlocksMined = 0,
        PlayTime = 0,
        BestDepthTime = 0,
        LastHitTime = 0,
        LastBuildTime = 0,
        SessionStartedAt = time(),
    }
end

local function loadPlayerData(player)
    local data = newPlayerData()
    local success, savedData = pcall(function()
        return mineDataStore:GetAsync("Player_" .. player.UserId)
    end)

    if success and type(savedData) == "table" then
        data.Points = tonumber(savedData.Points) or 0
        data.MaxDepth = tonumber(savedData.MaxDepth) or 0
        data.BlocksMined = tonumber(savedData.BlocksMined) or 0
        data.PlayTime = tonumber(savedData.PlayTime) or 0
        data.BestDepthTime = tonumber(savedData.BestDepthTime) or 0
    elseif not success then
        warn("[MiningHandler] No se pudieron cargar los datos de", player.Name)
    end

    playerData[player] = data
    ensureLeaderstats(player)
    sendStatsUpdate(player)
    broadcastLeaderboards()
end

local function savePlayerData(player)
    local data = playerData[player]
    if not data then return end

    local payload = {
        Points = data.Points,
        MaxDepth = data.MaxDepth,
        BlocksMined = data.BlocksMined,
        PlayTime = getPlayTime(data),
        BestDepthTime = data.BestDepthTime,
    }

    local success, err = pcall(function()
        mineDataStore:SetAsync("Player_" .. player.UserId, payload)
    end)
    if not success then
        warn("[MiningHandler] Error guardando datos de", player.Name, ":", err)
    end
end

-- ======= VALIDACIONES COMUNES =======
local function isMineBlock(block)
    return block and block:IsA("BasePart") and block.Parent and blocksFolder and block:IsDescendantOf(blocksFolder) and block:GetAttribute("IsMineable") == true
end

local function getCharacterRoot(player)
    local character = player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    return hrp
end

local function withinMineRange(player, position)
    local hrp = getCharacterRoot(player)
    return hrp and (hrp.Position - position).Magnitude <= CONFIG.MaxMineDistance
end

local function recordDepthProgress(player)
    local data = playerData[player]
    if not data then return false end

    local currentDepth = getCurrentDepth(player)
    if currentDepth <= data.MaxDepth then
        return false
    end

    data.MaxDepth = currentDepth
    local runTime = getPlayTime(data)
    if data.BestDepthTime == 0 or runTime < data.BestDepthTime then
        data.BestDepthTime = runTime
    end
    return true
end

-- ======= MINERÍA =======
local function onMineBlockRequest(player, block)
    if not isMineBlock(block) then return end

    local data = playerData[player]
    if not data then return end

    local now = time()
    if now - data.LastHitTime < CONFIG.HitCooldown then return end
    data.LastHitTime = now

    if not withinMineRange(player, block.Position) then return end

    local hitsLeft = tonumber(block:GetAttribute("HitsLeft")) or 1
    local maxHits = tonumber(block:GetAttribute("MaxHits")) or hitsLeft
    local power = getPickaxeLevel(data.Points).Power
    hitsLeft = hitsLeft - power
    block:SetAttribute("HitsLeft", math.max(hitsLeft, 0))

    if hitsLeft > 0 then
        blockHitEvent:FireClient(player, block, hitsLeft, maxHits)
        return
    end

    local points = tonumber(block:GetAttribute("Points")) or 0
    local depth = tonumber(block:GetAttribute("Depth")) or 0
    local layerName = tostring(block:GetAttribute("LayerName") or "Bloque")
    local rarity = tostring(block:GetAttribute("Rarity") or "COMÚN")
    local previousLevel = getPickaxeLevel(data.Points)

    data.Points = data.Points + points
    data.BlocksMined = data.BlocksMined + 1
    if depth > data.MaxDepth then
        data.MaxDepth = depth
        local runTime = getPlayTime(data)
        if data.BestDepthTime == 0 or runTime < data.BestDepthTime then
            data.BestDepthTime = runTime
        end
    end

    local newLevel = getPickaxeLevel(data.Points)
    blockBrokenEvent:FireClient(player, block, layerName, points, data.Points, data.MaxDepth, rarity)
    if rarity ~= "COMÚN" or points >= 100 then
        specialDiscoveryEvent:FireClient(player, layerName, rarity, points, depth)
    end
    block:SetAttribute("IsMineable", false)
    block:Destroy()

    if newLevel.Name ~= previousLevel.Name then
        notifyEvent:FireClient(player, ("NUEVO PICO DESBLOQUEADO  //  %s"):format(newLevel.Name))
    end

    sendStatsUpdate(player)
    broadcastLeaderboards()
end

mineBlockEvent.OnServerEvent:Connect(onMineBlockRequest)

-- ======= CONSTRUCCIÓN =======
local normalVectors = {
    [Enum.NormalId.Top] = Vector3.new(0, 1, 0),
    [Enum.NormalId.Bottom] = Vector3.new(0, -1, 0),
    [Enum.NormalId.Front] = Vector3.new(0, 0, -1),
    [Enum.NormalId.Back] = Vector3.new(0, 0, 1),
    [Enum.NormalId.Left] = Vector3.new(-1, 0, 0),
    [Enum.NormalId.Right] = Vector3.new(1, 0, 0),
}

local function isPositionInsideMine(position)
    return position.X >= MIN_GRID_COORD and position.X <= MAX_GRID_COORD
        and position.Z >= MIN_GRID_COORD and position.Z <= MAX_GRID_COORD
        and position.Y <= CONFIG.StartY + CONFIG.BlockSize / 2
        and position.Y >= (Workspace:GetAttribute("MineFloorY") or -700) + CONFIG.BlockSize / 2
end

local function hasOccupant(position, ignorePart)
    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.FilterDescendantsInstances = { ignorePart }
    local parts = Workspace:GetPartBoundsInBox(CFrame.new(position), Vector3.new(CONFIG.BlockSize - 0.2, CONFIG.BlockSize - 0.2, CONFIG.BlockSize - 0.2), overlapParams)
    for _, part in ipairs(parts) do
        if part:IsDescendantOf(blocksFolder) then
            return true
        end
    end
    return false
end

local function onPlaceBlockRequest(player, target, normalId)
    if not isMineBlock(target) then return end
    local direction = normalVectors[normalId]
    if not direction then return end

    local data = playerData[player]
    if not data then return end
    local now = time()
    if now - data.LastBuildTime < CONFIG.BuildCooldown then return end

    local targetPosition = target.Position
    local candidate = targetPosition + direction * CONFIG.BlockSize
    candidate = Vector3.new(
        math.round(candidate.X / CONFIG.BlockSize) * CONFIG.BlockSize,
        math.round(candidate.Y / CONFIG.BlockSize) * CONFIG.BlockSize,
        math.round(candidate.Z / CONFIG.BlockSize) * CONFIG.BlockSize
    )

    if not isPositionInsideMine(candidate) then return end
    if not withinMineRange(player, candidate) then return end
    if hasOccupant(candidate, target) then return end

    data.LastBuildTime = now
    local block = Instance.new("Part")
    block.Name = "Construido"
    block.Anchored = true
    block.Size = Vector3.new(CONFIG.BlockSize, CONFIG.BlockSize, CONFIG.BlockSize)
    block.Position = candidate
    block.Color = Color3.fromRGB(63, 174, 201)
    block.Material = Enum.Material.SmoothPlastic
    block.TopSurface = Enum.SurfaceType.Smooth
    block.BottomSurface = Enum.SurfaceType.Smooth
    block:SetAttribute("LayerName", "Construido")
    block:SetAttribute("MaxHits", 3)
    block:SetAttribute("HitsLeft", 3)
    block:SetAttribute("Points", 0)
    block:SetAttribute("Depth", math.max(1, math.floor((CONFIG.StartY - candidate.Y) / CONFIG.BlockSize)))
    block:SetAttribute("IsMineable", true)
    block:SetAttribute("IsPlaced", true)
    block.Parent = blocksFolder

    blockPlacedEvent:FireAllClients(block, player.DisplayName)
    notifyEvent:FireClient(player, "BLOQUE COLOCADO  //  MODO CONSTRUCCIÓN")
end

placeBlockEvent.OnServerEvent:Connect(onPlaceBlockRequest)

-- ======= EVENTOS DE JUGADORES Y ACTUALIZACIÓN VIVA =======
Players.PlayerAdded:Connect(function(player)
    loadPlayerData(player)
    task.delay(3, function()
        if player.Parent then
            broadcastLeaderboards()
        end
    end)
    player.CharacterAdded:Connect(function()
        task.wait(0.6)
        sendStatsUpdate(player)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    savePlayerData(player)
    playerData[player] = nil
    broadcastLeaderboards()
end)

task.spawn(function()
    while true do
        task.wait(1)
        for _, player in ipairs(Players:GetPlayers()) do
            local data = playerData[player]
            if data then
                local progressed = recordDepthProgress(player)
                sendStatsUpdate(player)
                if progressed then
                    notifyEvent:FireClient(player, ("NUEVO RÉCORD DE PROFUNDIDAD  //  %dm"):format(data.MaxDepth))
                    broadcastLeaderboards()
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(CONFIG.AutoSaveSeconds)
        for _, player in ipairs(Players:GetPlayers()) do
            savePlayerData(player)
        end
        broadcastLeaderboards()
    end
end)

game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        savePlayerData(player)
    end
end)

broadcastLeaderboards()
print("[MiningHandler] Sistema seguro de minería, construcción y rankings listo.")

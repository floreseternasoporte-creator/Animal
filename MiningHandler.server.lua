--[=[
    MiningHandler.server.lua
    UBICACIÓN: ServerScriptService

    Núcleo servidor de Crónicas de Lumenfall.
    Mantiene el nombre de archivo para facilitar el reemplazo en Studio.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local DataStoreService = game:GetService("DataStoreService")

Workspace:WaitForChild("LumenfallWorld")
while not Workspace:GetAttribute("LumenfallReady") do
    task.wait(0.1)
end

local world = Workspace:WaitForChild("LumenfallWorld")
local terrainFolder = world:WaitForChild("LumenTerrain")
local harvestFolder = world:WaitForChild("LumenHarvestables")
local buildFolder = world:WaitForChild("LumenPlayerBuilds")
local structuresFolder = world:WaitForChild("LumenStructures")

local BLOCK_SIZE = Workspace:GetAttribute("LumenBlockSize") or 4
local MAP_RADIUS = Workspace:GetAttribute("LumenMapRadius") or 20
local dataStore = DataStoreService:GetDataStore("Lumenfall_PlayerData_v1")

local oldMiningRemotes = ReplicatedStorage:FindFirstChild("MiningRemotes")
if oldMiningRemotes then oldMiningRemotes:Destroy() end

local remotes = ReplicatedStorage:FindFirstChild("LumenRemotes")
if not remotes then
    remotes = Instance.new("Folder")
    remotes.Name = "LumenRemotes"
    remotes.Parent = ReplicatedStorage
end

local function remote(name)
    local item = remotes:FindFirstChild(name)
    if not item then
        item = Instance.new("RemoteEvent")
        item.Name = name
        item.Parent = remotes
    end
    return item
end

local gatherRequest = remote("GatherRequest")
local placeRequest = remote("PlaceRequest")
local statsUpdate = remote("StatsUpdate")
local notify = remote("Notify")
local harvestFX = remote("HarvestFX")
local boardUpdate = remote("BoardUpdate")

local CONFIG = {
    GatherDistance = 16,
    GatherCooldown = 0.22,
    PlaceCooldown = 0.18,
    MaxEnergy = 100,
    EnergyDrainInterval = 12,
    BeaconCost = 6,
    AutoSaveInterval = 120,
}

local BUILD_TYPES = {
    Madera = { Cost = "Madera", Color = Color3.fromRGB(116, 79, 51), Material = Enum.Material.Wood },
    Piedra = { Cost = "Piedra", Color = Color3.fromRGB(118, 128, 142), Material = Enum.Material.Slate },
    Cristal = { Cost = "Cristal", Color = Color3.fromRGB(106, 229, 255), Material = Enum.Material.Glass },
    Lumen = { Cost = "Lumen", Color = Color3.fromRGB(213, 149, 255), Material = Enum.Material.Neon },
}

local playerData = {}

local function newData()
    return {
        Resources = { Madera = 8, Piedra = 5, Cristal = 0, Lumen = 0 },
        Energy = CONFIG.MaxEnergy,
        Beacons = { Aurora = false, Rift = false, Ash = false },
        ResourcesGathered = 0,
        BlocksBuilt = 0,
        LastGather = 0,
        LastPlace = 0,
    }
end

local function safeResourceTable(resources)
    resources = type(resources) == "table" and resources or {}
    return {
        Madera = math.max(0, tonumber(resources.Madera) or 0),
        Piedra = math.max(0, tonumber(resources.Piedra) or 0),
        Cristal = math.max(0, tonumber(resources.Cristal) or 0),
        Lumen = math.max(0, tonumber(resources.Lumen) or 0),
    }
end

local function beaconCount(data)
    local total = 0
    for _, restored in pairs(data.Beacons or {}) do
        if restored then total = total + 1 end
    end
    return total
end

local function getRoot(player)
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function updateLeaderstats(player)
    local data = playerData[player]
    if not data then return end
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then
        leaderstats = Instance.new("Folder")
        leaderstats.Name = "leaderstats"
        leaderstats.Parent = player
    end

    local function getValue(name)
        local value = leaderstats:FindFirstChild(name)
        if not value then
            value = Instance.new("IntValue")
            value.Name = name
            value.Parent = leaderstats
        end
        return value
    end

    getValue("Balizas").Value = beaconCount(data)
    getValue("Recursos").Value = data.ResourcesGathered
    getValue("Construido").Value = data.BlocksBuilt
end

local function sendStats(player)
    local data = playerData[player]
    if not data then return end
    updateLeaderstats(player)
    statsUpdate:FireClient(player, {
        Resources = safeResourceTable(data.Resources),
        Energy = data.Energy,
        MaxEnergy = CONFIG.MaxEnergy,
        Beacons = beaconCount(data),
        BeaconState = data.Beacons,
        ResourcesGathered = data.ResourcesGathered,
        BlocksBuilt = data.BlocksBuilt,
    })
end

local function playerEntry(player)
    local data = playerData[player]
    if not data then return nil end
    return {
        Name = player.DisplayName,
        UserId = player.UserId,
        Beacons = beaconCount(data),
        Resources = data.ResourcesGathered,
        Built = data.BlocksBuilt,
    }
end

local function updatePhysicalBoard()
    local board = structuresFolder:FindFirstChild("ExplorerBoard")
    local panel = board and board:FindFirstChild("WorldPanel")
    local subtitle = panel and panel:FindFirstChild("Subtitle")
    if not subtitle then return end

    local entries = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local entry = playerEntry(player)
        if entry then table.insert(entries, entry) end
    end
    table.sort(entries, function(a, b)
        if a.Beacons == b.Beacons then return a.Resources > b.Resources end
        return a.Beacons > b.Beacons
    end)

    local lines = {}
    for index = 1, math.min(#entries, 5) do
        local entry = entries[index]
        table.insert(lines, ("%d. %s  //  %d BALIZAS  //  %d RECURSOS"):format(index, string.upper(entry.Name), entry.Beacons, entry.Resources))
    end
    subtitle.Text = #lines > 0 and table.concat(lines, "\n") or "AÚN NO HAY VIAJEROS REGISTRADOS"
    boardUpdate:FireAllClients(entries)
end

local function savePlayer(player)
    local data = playerData[player]
    if not data then return end
    local payload = {
        Resources = safeResourceTable(data.Resources),
        Energy = data.Energy,
        Beacons = data.Beacons,
        ResourcesGathered = data.ResourcesGathered,
        BlocksBuilt = data.BlocksBuilt,
    }
    local ok, err = pcall(function()
        dataStore:UpdateAsync("Lumen_" .. player.UserId, function()
            return payload
        end)
    end)
    if not ok then warn("[Lumenfall] No se pudo guardar", player.Name, err) end
end

local function loadPlayer(player)
    local data = newData()
    local ok, saved = pcall(function()
        return dataStore:GetAsync("Lumen_" .. player.UserId)
    end)
    if ok and type(saved) == "table" then
        data.Resources = safeResourceTable(saved.Resources)
        data.Energy = math.clamp(tonumber(saved.Energy) or CONFIG.MaxEnergy, 1, CONFIG.MaxEnergy)
        data.Beacons = type(saved.Beacons) == "table" and {
            Aurora = saved.Beacons.Aurora == true,
            Rift = saved.Beacons.Rift == true,
            Ash = saved.Beacons.Ash == true,
        } or data.Beacons
        data.ResourcesGathered = math.max(0, tonumber(saved.ResourcesGathered) or 0)
        data.BlocksBuilt = math.max(0, tonumber(saved.BlocksBuilt) or 0)
    end
    playerData[player] = data
    sendStats(player)
    updatePhysicalBoard()
end

local function findHarvestNode(instance)
    local current = instance
    while current and current ~= Workspace do
        if current:IsA("Model") and current:GetAttribute("HarvestNode") then
            return current
        end
        current = current.Parent
    end
    return nil
end

local function nodeCore(node)
    return node and node:FindFirstChild("HarvestCore", true)
end

local function scheduleNodeRespawn(node)
    local template = node:Clone()
    template.Parent = nil
    local delaySeconds = math.max(25, tonumber(node:GetAttribute("RespawnSeconds")) or 60)
    local attemptRespawn
    attemptRespawn = function()
        if not harvestFolder.Parent then return end
        local core = nodeCore(template)
        if not core then return end
        for _, player in ipairs(Players:GetPlayers()) do
            local root = getRoot(player)
            if root and (root.Position - core.Position).Magnitude < BLOCK_SIZE * 2 then
                task.delay(15, attemptRespawn)
                return
            end
        end
        if template.Parent == nil then template.Parent = harvestFolder end
    end
    task.delay(delaySeconds, attemptRespawn)
end

local function scheduleTerrainRespawn(voxel)
    local template = voxel:Clone()
    template.Parent = nil
    local function restore()
        if not terrainFolder.Parent then return end
        for _, player in ipairs(Players:GetPlayers()) do
            local root = getRoot(player)
            if root and (root.Position - template.Position).Magnitude < BLOCK_SIZE * 1.5 then
                task.delay(20, restore)
                return
            end
        end
        if template.Parent == nil then template.Parent = terrainFolder end
    end
    task.delay(120, restore)
end

local function harvest(player, target)
    local data = playerData[player]
    if not data or not target or not target:IsA("BasePart") then return end
    local root = getRoot(player)
    if not root or (root.Position - target.Position).Magnitude > CONFIG.GatherDistance then return end
    local now = time()
    if now - data.LastGather < CONFIG.GatherCooldown then return end
    data.LastGather = now

    local node = findHarvestNode(target)
    local core = nodeCore(node)
    if node and core and node.Parent then
        local health = math.max(0, (tonumber(node:GetAttribute("Health")) or 1) - 1)
        node:SetAttribute("Health", health)
        harvestFX:FireClient(player, core.Position, node:GetAttribute("ResourceColor"), health > 0)
        if health > 0 then return end

        local drop = tostring(node:GetAttribute("DropType") or "Piedra")
        local amount = math.max(1, tonumber(node:GetAttribute("DropAmount")) or 1)
        data.Resources[drop] = (data.Resources[drop] or 0) + amount
        data.ResourcesGathered = data.ResourcesGathered + amount
        notify:FireClient(player, ("RECOLECTASTE %d %s"):format(amount, string.upper(drop)))
        scheduleNodeRespawn(node)
        node:Destroy()
    elseif target:IsDescendantOf(terrainFolder) and target:GetAttribute("Voxel") then
        data.Resources.Piedra = (data.Resources.Piedra or 0) + 1
        data.ResourcesGathered = data.ResourcesGathered + 1
        harvestFX:FireClient(player, target.Position, Color3.fromRGB(177, 167, 150), false)
        scheduleTerrainRespawn(target)
        target:Destroy()
    else
        return
    end

    sendStats(player)
    updatePhysicalBoard()
end

local NORMALS = {
    [Enum.NormalId.Top] = Vector3.new(0, 1, 0),
    [Enum.NormalId.Bottom] = Vector3.new(0, -1, 0),
    [Enum.NormalId.Front] = Vector3.new(0, 0, -1),
    [Enum.NormalId.Back] = Vector3.new(0, 0, 1),
    [Enum.NormalId.Left] = Vector3.new(-1, 0, 0),
    [Enum.NormalId.Right] = Vector3.new(1, 0, 0),
}

local function isBuildAnchor(target)
    return target and target:IsA("BasePart") and (target:IsDescendantOf(terrainFolder) or target:IsDescendantOf(buildFolder))
end

local function candidatePosition(target, normalId)
    local direction = NORMALS[normalId]
    if not direction then return nil end
    local raw = target.Position + direction * BLOCK_SIZE
    return Vector3.new(
        math.round(raw.X / BLOCK_SIZE) * BLOCK_SIZE,
        math.round(raw.Y / BLOCK_SIZE) * BLOCK_SIZE,
        math.round(raw.Z / BLOCK_SIZE) * BLOCK_SIZE
    )
end

local function isOpenCell(position)
    if math.abs(position.X / BLOCK_SIZE) > MAP_RADIUS + 2 or math.abs(position.Z / BLOCK_SIZE) > MAP_RADIUS + 2 then
        return false
    end
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { terrainFolder, buildFolder, harvestFolder, structuresFolder }
    local parts = Workspace:GetPartBoundsInBox(CFrame.new(position), Vector3.new(BLOCK_SIZE - 0.16, BLOCK_SIZE - 0.16, BLOCK_SIZE - 0.16), params)
    if #parts > 0 then return false end
    for _, player in ipairs(Players:GetPlayers()) do
        local root = getRoot(player)
        if root and (root.Position - position).Magnitude < BLOCK_SIZE then
            return false
        end
    end
    return true
end

local function placeBlock(player, target, normalId, buildType)
    local data = playerData[player]
    buildType = tostring(buildType or "Madera")
    local config = BUILD_TYPES[buildType]
    if not data or not config or not isBuildAnchor(target) then return end

    local root = getRoot(player)
    local position = candidatePosition(target, normalId)
    if not root or not position or (root.Position - position).Magnitude > CONFIG.GatherDistance then return end
    if not isOpenCell(position) then return end
    local now = time()
    if now - data.LastPlace < CONFIG.PlaceCooldown then return end
    if (data.Resources[config.Cost] or 0) < 1 then
        notify:FireClient(player, ("FALTA %s PARA CONSTRUIR"):format(string.upper(config.Cost)))
        return
    end

    data.LastPlace = now
    data.Resources[config.Cost] = data.Resources[config.Cost] - 1
    data.BlocksBuilt = data.BlocksBuilt + 1
    local block = Instance.new("Part")
    block.Name = "Bloque " .. buildType
    block.Anchored = true
    block.Size = Vector3.new(BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE)
    block.Position = position
    block.Color = config.Color
    block.Material = config.Material
    block.TopSurface = Enum.SurfaceType.Smooth
    block.BottomSurface = Enum.SurfaceType.Smooth
    block:SetAttribute("PlayerBuild", true)
    block:SetAttribute("BuildType", buildType)
    block.Parent = buildFolder
    harvestFX:FireAllClients(position, config.Color, false, true)
    sendStats(player)
    updatePhysicalBoard()
end

local function requireResources(data, requirements)
    for resource, amount in pairs(requirements) do
        if (data.Resources[resource] or 0) < amount then return false end
    end
    for resource, amount in pairs(requirements) do
        data.Resources[resource] = data.Resources[resource] - amount
    end
    return true
end

local function activateStations()
    local workshop = structuresFolder:WaitForChild("LumenWorkshop")
    local shrine = structuresFolder:WaitForChild("RestShrine")
    local beaconPrompts = {
        { Object = structuresFolder:WaitForChild("AuroraBeacon"), Key = "Aurora", Name = "BALIZA DE AURORA" },
        { Object = structuresFolder:WaitForChild("CrystalBeacon"), Key = "Rift", Name = "BALIZA DE LA GRIETA" },
        { Object = structuresFolder:WaitForChild("AshBeacon"), Key = "Ash", Name = "BALIZA DE CENIZA" },
    }

    workshop:WaitForChild("WorkshopPrompt").Triggered:Connect(function(player)
        local data = playerData[player]
        if not data then return end
        if requireResources(data, { Madera = 4, Piedra = 2 }) then
            data.Resources.Lumen = (data.Resources.Lumen or 0) + 3
            notify:FireClient(player, "KIT FABRICADO  //  +3 BLOQUES LUMEN")
            sendStats(player)
        else
            notify:FireClient(player, "RECETA: 4 MADERA + 2 PIEDRA")
        end
    end)

    shrine:WaitForChild("RestPrompt").Triggered:Connect(function(player)
        local data = playerData[player]
        if not data then return end
        data.Energy = CONFIG.MaxEnergy
        notify:FireClient(player, "ENERGÍA RESTAURADA  //  VIAJE GUARDADO")
        sendStats(player)
        savePlayer(player)
    end)

    for _, beacon in ipairs(beaconPrompts) do
        beacon.Object:WaitForChild(beacon.Key == "Aurora" and "BeaconPrompt" or (beacon.Key == "Rift" and "RiftPrompt" or "AshPrompt")).Triggered:Connect(function(player)
            local data = playerData[player]
            if not data then return end
            if data.Beacons[beacon.Key] then
                notify:FireClient(player, beacon.Name .. " YA ESTÁ RESTAURADA")
                return
            end
            if requireResources(data, { Cristal = CONFIG.BeaconCost }) then
                data.Beacons[beacon.Key] = true
                data.Energy = CONFIG.MaxEnergy
                notify:FireClient(player, beacon.Name .. " RESTAURADA  //  NUEVA RUTA")
                sendStats(player)
                updatePhysicalBoard()
            else
                notify:FireClient(player, ("NECESITAS %d CRISTALES LUMEN"):format(CONFIG.BeaconCost))
            end
        end)
    end
end

gatherRequest.OnServerEvent:Connect(harvest)
placeRequest.OnServerEvent:Connect(placeBlock)

task.spawn(activateStations)

Players.PlayerAdded:Connect(function(player)
    loadPlayer(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        sendStats(player)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    savePlayer(player)
    playerData[player] = nil
    updatePhysicalBoard()
end)

task.spawn(function()
    while true do
        task.wait(CONFIG.EnergyDrainInterval)
        for _, player in ipairs(Players:GetPlayers()) do
            local data = playerData[player]
            if data then
                data.Energy = math.max(0, data.Energy - 1)
                if data.Energy == 0 then
                    local character = player.Character
                    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                    if humanoid then humanoid:TakeDamage(5) end
                end
                sendStats(player)
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(CONFIG.AutoSaveInterval)
        for _, player in ipairs(Players:GetPlayers()) do
            savePlayer(player)
        end
        updatePhysicalBoard()
    end
end)

game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        savePlayer(player)
    end
end)

updatePhysicalBoard()
print("[Lumenfall] Servidor de supervivencia voxel listo.")

--[=[
    WorldGenerator.server.lua
    UBICACIÓN: ServerScriptService

    Crónicas de Lumenfall: mundo voxel original de exploración y supervivencia.
    No replica mapas, nombres, recetas ni apariencia de ningún juego existente.
]=]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local CONFIG = {
    Seed = 48152,
    BlockSize = 4,
    MapRadius = 20,
    WorldFloorY = -22,
}

local function clearWorld()
    for _, name in ipairs({
        "LumenfallWorld", "LumenTerrain", "LumenHarvestables", "LumenStructures", "LumenPlayerBuilds",
        "MineBlocks", "MineWorld", "MineBoundaries", "LeaderboardDisplay", "Surface", "MainSpawn", "MineFloor",
    }) do
        local old = Workspace:FindFirstChild(name)
        if old then old:Destroy() end
    end
end

clearWorld()
Workspace:SetAttribute("LumenfallReady", false)
Workspace:SetAttribute("LumenBlockSize", CONFIG.BlockSize)
Workspace:SetAttribute("LumenMapRadius", CONFIG.MapRadius)
Workspace.FallenPartsDestroyHeight = CONFIG.WorldFloorY - 60

local world = Instance.new("Folder")
world.Name = "LumenfallWorld"
world.Parent = Workspace

local terrainFolder = Instance.new("Folder")
terrainFolder.Name = "LumenTerrain"
terrainFolder.Parent = world

local harvestFolder = Instance.new("Folder")
harvestFolder.Name = "LumenHarvestables"
harvestFolder.Parent = world

local structuresFolder = Instance.new("Folder")
structuresFolder.Name = "LumenStructures"
structuresFolder.Parent = world

local buildFolder = Instance.new("Folder")
buildFolder.Name = "LumenPlayerBuilds"
buildFolder.Parent = world

local function part(parent, name, size, position, color, material, canCollide, transparency)
    local instance = Instance.new("Part")
    instance.Name = name
    instance.Anchored = true
    instance.Size = size
    instance.Position = position
    instance.Color = color
    instance.Material = material or Enum.Material.SmoothPlastic
    instance.CanCollide = canCollide ~= false
    instance.CanTouch = false
    instance.CanQuery = true
    instance.Transparency = tonumber(transparency) or 0
    instance.TopSurface = Enum.SurfaceType.Smooth
    instance.BottomSurface = Enum.SurfaceType.Smooth
    instance.Parent = parent
    return instance
end

local function neon(parent, name, size, position, color)
    local strip = part(parent, name, size, position, color, Enum.Material.Neon, false)
    strip.CanQuery = false
    return strip
end

local function heightAt(gridX, gridZ)
    local broad = math.noise((gridX + CONFIG.Seed) / 15, (gridZ - CONFIG.Seed) / 15) * 2.1
    local detail = math.noise((gridX + CONFIG.Seed * 2) / 5, (gridZ + CONFIG.Seed) / 5) * 0.8
    return math.clamp(math.floor(broad + detail), -2, 4)
end

local function biomeAt(gridX, gridZ)
    if gridZ < -8 then
        return "Grieta de Cristal", Color3.fromRGB(89, 129, 167), Color3.fromRGB(105, 224, 255)
    elseif gridX > 7 then
        return "Llanuras de Ceniza", Color3.fromRGB(114, 101, 92), Color3.fromRGB(255, 138, 74)
    elseif gridX < -10 then
        return "Bosque de Aurora", Color3.fromRGB(59, 121, 89), Color3.fromRGB(96, 238, 187)
    end
    return "Praderas de Lumen", Color3.fromRGB(91, 157, 96), Color3.fromRGB(95, 214, 255)
end

local function makeVoxel(parent, name, gridX, y, gridZ, color, material)
    local size = CONFIG.BlockSize
    local voxel = part(parent, name, Vector3.new(size, size, size), Vector3.new(gridX * size, y * size, gridZ * size), color, material, true)
    voxel:SetAttribute("Voxel", true)
    voxel:SetAttribute("GridX", gridX)
    voxel:SetAttribute("GridY", y)
    voxel:SetAttribute("GridZ", gridZ)
    return voxel
end

local function createTerrain()
    local floor = part(terrainFolder, "WorldFoundation", Vector3.new((CONFIG.MapRadius * 2 + 9) * CONFIG.BlockSize, 4, (CONFIG.MapRadius * 2 + 9) * CONFIG.BlockSize), Vector3.new(0, CONFIG.WorldFloorY, 0), Color3.fromRGB(31, 41, 52), Enum.Material.Slate, true)
    floor.CanQuery = false

    for x = -CONFIG.MapRadius, CONFIG.MapRadius do
        for z = -CONFIG.MapRadius, CONFIG.MapRadius do
            local height = heightAt(x, z)
            local _, topColor = biomeAt(x, z)
            for depth = height - 3, height - 1 do
                local lower = depth <= height - 2
                makeVoxel(terrainFolder, lower and "StoneLayer" or "SoilLayer", x, depth, z, lower and Color3.fromRGB(89, 94, 105) or Color3.fromRGB(91, 71, 53), lower and Enum.Material.Slate or Enum.Material.Ground)
            end
            makeVoxel(terrainFolder, "Surface", x, height, z, topColor, Enum.Material.Grass)
        end
        if x % 2 == 0 then task.wait() end
    end
end

local function createTree(gridX, gridZ)
    local height = heightAt(gridX, gridZ)
    local baseY = height + 1
    local model = Instance.new("Model")
    model.Name = "AuroraTree"
    model:SetAttribute("HarvestNode", true)
    model:SetAttribute("NodeType", "Árbol de Aurora")
    model:SetAttribute("DropType", "Madera")
    model:SetAttribute("DropAmount", 4)
    model:SetAttribute("MaxHealth", 4)
    model:SetAttribute("Health", 4)
    model:SetAttribute("RespawnSeconds", 75)
    model:SetAttribute("ResourceColor", Color3.fromRGB(109, 223, 163))
    model.Parent = harvestFolder

    local trunk = makeVoxel(model, "Core", gridX, baseY, gridZ, Color3.fromRGB(105, 72, 47), Enum.Material.Wood)
    trunk.Name = "HarvestCore"
    makeVoxel(model, "TrunkUpper", gridX, baseY + 1, gridZ, Color3.fromRGB(105, 72, 47), Enum.Material.Wood).CanQuery = false
    for _, offset in ipairs({ Vector3.new(0, 2, 0), Vector3.new(1, 2, 0), Vector3.new(-1, 2, 0), Vector3.new(0, 2, 1), Vector3.new(0, 2, -1), Vector3.new(0, 3, 0) }) do
        local leaf = part(model, "AuroraLeaf", Vector3.new(CONFIG.BlockSize, CONFIG.BlockSize, CONFIG.BlockSize), trunk.Position + offset * CONFIG.BlockSize, Color3.fromRGB(76, 193, 133), Enum.Material.Grass, true)
        leaf.CanQuery = false
    end
end

local function createRock(gridX, gridZ, kind)
    local height = heightAt(gridX, gridZ)
    local config = kind == "Crystal" and {
        name = "Cristal Lumen", drop = "Cristal", amount = 2, health = 5, color = Color3.fromRGB(114, 224, 255), material = Enum.Material.Neon, respawn = 150,
    } or {
        name = "Roca de Ceniza", drop = "Piedra", amount = 3, health = 3, color = Color3.fromRGB(111, 119, 131), material = Enum.Material.Slate, respawn = 90,
    }

    local model = Instance.new("Model")
    model.Name = config.name
    model:SetAttribute("HarvestNode", true)
    model:SetAttribute("NodeType", config.name)
    model:SetAttribute("DropType", config.drop)
    model:SetAttribute("DropAmount", config.amount)
    model:SetAttribute("MaxHealth", config.health)
    model:SetAttribute("Health", config.health)
    model:SetAttribute("RespawnSeconds", config.respawn)
    model:SetAttribute("ResourceColor", config.color)
    model.Parent = harvestFolder

    local core = makeVoxel(model, "HarvestCore", gridX, height + 1, gridZ, config.color, config.material)
    core.Size = Vector3.new(CONFIG.BlockSize * 1.15, CONFIG.BlockSize * 1.15, CONFIG.BlockSize * 1.15)
    if kind == "Crystal" then
        local glow = Instance.new("PointLight")
        glow.Color = config.color
        glow.Brightness = 1.5
        glow.Range = 13
        glow.Parent = core
    end
end

local function createHarvestables()
    for x = -18, -10, 2 do
        for z = -7, 13, 4 do
            if math.noise(x / 4, z / 4, CONFIG.Seed) > -0.2 then createTree(x, z) end
        end
    end
    for x = 8, 18, 3 do
        for z = -4, 15, 5 do
            if math.noise(x / 3, z / 3, CONFIG.Seed) > -0.35 then createRock(x, z, "Rock") end
        end
    end
    for x = -12, 12, 4 do
        for z = -18, -10, 3 do
            if math.noise(x / 3, z / 3, CONFIG.Seed) > -0.15 then createRock(x, z, "Crystal") end
        end
    end
end

local function physicalPanel(parent, face, title, subtitle, accent)
    local gui = Instance.new("SurfaceGui")
    gui.Name = "WorldPanel"
    gui.Adornee = parent
    gui.Face = face
    gui.CanvasSize = Vector2.new(620, 360)
    gui.LightInfluence = 0
    gui.Brightness = 1.4
    gui.Parent = parent

    local titleLabel = Instance.new("TextLabel")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.new(0, 22, 0, 48)
    titleLabel.Size = UDim2.new(1, -44, 0, 80)
    titleLabel.Font = Enum.Font.GothamBlack
    titleLabel.Text = title
    titleLabel.TextColor3 = accent
    titleLabel.TextScaled = true
    titleLabel.Parent = gui

    local subLabel = Instance.new("TextLabel")
    subLabel.Name = "Subtitle"
    subLabel.BackgroundTransparency = 1
    subLabel.Position = UDim2.new(0, 28, 0, 145)
    subLabel.Size = UDim2.new(1, -56, 0, 104)
    subLabel.Font = Enum.Font.GothamBold
    subLabel.Text = subtitle
    subLabel.TextColor3 = Color3.fromRGB(230, 241, 255)
    subLabel.TextWrapped = true
    subLabel.TextScaled = true
    subLabel.Parent = gui
    return gui
end

local function station(name, gridX, gridZ, accent, title, subtitle, promptName, action)
    local height = heightAt(gridX, gridZ)
    local groundY = height * CONFIG.BlockSize + CONFIG.BlockSize / 2
    local base = part(structuresFolder, name .. "Base", Vector3.new(12, 1, 10), Vector3.new(gridX * CONFIG.BlockSize, groundY + 0.5, gridZ * CONFIG.BlockSize), Color3.fromRGB(20, 37, 50), Enum.Material.Metal, true)
    base.CanQuery = false
    local console = part(structuresFolder, name, Vector3.new(7, 7, 1), base.Position + Vector3.new(0, 4.1, 12), Color3.fromRGB(9, 23, 37), Enum.Material.Metal, true)
    console.CanQuery = false
    neon(structuresFolder, name .. "Light", Vector3.new(5.8, 0.16, 0.14), console.Position + Vector3.new(0, 2.3, -0.58), accent)
    physicalPanel(console, Enum.NormalId.Front, title, subtitle, accent)

    if promptName then
        local prompt = Instance.new("ProximityPrompt")
        prompt.Name = promptName
        prompt.ActionText = action
        prompt.ObjectText = title
        prompt.HoldDuration = 0.25
        prompt.MaxActivationDistance = 10
        prompt.RequiresLineOfSight = false
        prompt.KeyboardKeyCode = Enum.KeyCode.E
        prompt.Parent = console
    end
    return console
end

local function createStructures()
    local workshop = station("LumenWorkshop", -4, 4, Color3.fromRGB(255, 185, 80), "TALLER LUMEN", "CONVIERTE MADERA Y PIEDRA EN BLOQUES LUMEN", "WorkshopPrompt", "FABRICAR KIT")
    local shrine = station("RestShrine", 5, 4, Color3.fromRGB(103, 241, 190), "SANTUARIO VIVO", "RECUPERA ENERGÍA Y GUARDA EL VIAJE", "RestPrompt", "DESCANSAR")
    local beacon = station("AuroraBeacon", -15, -12, Color3.fromRGB(116, 226, 255), "BALIZA DE AURORA", "RESTAURA LA LUZ CON CRISTALES LUMEN", "BeaconPrompt", "RESTAURAR")
    local rift = station("CrystalBeacon", 0, -16, Color3.fromRGB(199, 130, 255), "BALIZA DE LA GRIETA", "UN FARO PARA LAS CAVERNAS PRISMÁTICAS", "RiftPrompt", "RESTAURAR")
    local ash = station("AshBeacon", 15, 4, Color3.fromRGB(255, 137, 74), "BALIZA DE CENIZA", "ENCIENDE LA RUTA A LAS LLANURAS", "AshPrompt", "RESTAURAR")

    local boardGround = heightAt(-15, 17) * CONFIG.BlockSize + CONFIG.BlockSize / 2
    local board = part(structuresFolder, "ExplorerBoard", Vector3.new(22, 11, 1), Vector3.new(-60, boardGround + 6, 68), Color3.fromRGB(9, 24, 39), Enum.Material.Metal, true)
    board.CanQuery = false
    physicalPanel(board, Enum.NormalId.Front, "REGISTRO DE EXPLORADORES", "AÚN NO HAY VIAJEROS REGISTRADOS", Color3.fromRGB(95, 218, 255))
    neon(structuresFolder, "BoardLight", Vector3.new(18, 0.18, 0.15), board.Position + Vector3.new(0, 4.5, -0.58), Color3.fromRGB(95, 218, 255))

    for _, console in ipairs({ workshop, shrine, beacon, rift, ash }) do
        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(120, 221, 255)
        light.Brightness = 1.2
        light.Range = 16
        light.Parent = console
    end
end

local function createSpawn()
    local height = heightAt(0, 0)
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "LumenfallSpawn"
    spawn.Anchored = true
    spawn.Neutral = true
    spawn.Size = Vector3.new(8, 1, 8)
    spawn.Position = Vector3.new(0, height * CONFIG.BlockSize + CONFIG.BlockSize / 2 + 0.5, 0)
    spawn.Color = Color3.fromRGB(100, 228, 255)
    spawn.Material = Enum.Material.Neon
    spawn.Transparency = 0.12
    spawn.Parent = structuresFolder
end

local function setAtmosphere()
    Lighting.ClockTime = 15.2
    Lighting.Brightness = 2.1
    Lighting.Ambient = Color3.fromRGB(93, 118, 145)
    Lighting.OutdoorAmbient = Color3.fromRGB(73, 93, 118)
    Lighting.FogColor = Color3.fromRGB(103, 149, 171)
    Lighting.FogEnd = 280

    local old = Lighting:FindFirstChild("LumenfallAtmosphere")
    if old then old:Destroy() end
    local atmosphere = Instance.new("Atmosphere")
    atmosphere.Name = "LumenfallAtmosphere"
    atmosphere.Color = Color3.fromRGB(172, 215, 229)
    atmosphere.Decay = Color3.fromRGB(94, 126, 159)
    atmosphere.Density = 0.27
    atmosphere.Glare = 0.12
    atmosphere.Haze = 1.5
    atmosphere.Parent = Lighting
end

setAtmosphere()
createTerrain()
createHarvestables()
createStructures()
createSpawn()

Workspace:SetAttribute("LumenfallReady", true)
print("[LumenfallWorld] Archipiélago voxel generado correctamente.")

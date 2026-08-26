--[=[
    WorldGenerator.server.lua
    UBICACIÓN: ServerScriptService

    Mundo de excavación y construcción:
    - La superficie es un anillo/campamento: el centro queda abierto y sí se puede excavar.
    - La mina es profunda y ancha para que los jugadores puedan entrar literalmente.
    - Un piso, muros invisibles y una zona de retorno evitan que el jugador caiga al vacío.
    - Se crea un monitor 3D para que el cliente pinte rankings y progreso.
]=]

local Workspace = game:GetService("Workspace")

-- ======= CONFIGURACIÓN DEL MUNDO =======
local LAYERS = {
    { Name = "Tierra",       Color = Color3.fromRGB(126, 82, 52),   Material = Enum.Material.Ground,   Hits = 1,  Points = 1,    Rarity = "COMÚN",     MinDepth = 1,   MaxDepth = 6 },
    { Name = "Piedra",       Color = Color3.fromRGB(112, 121, 132), Material = Enum.Material.Slate,    Hits = 2,  Points = 3,    Rarity = "COMÚN",     MinDepth = 7,   MaxDepth = 14 },
    { Name = "Granito",      Color = Color3.fromRGB(155, 137, 132), Material = Enum.Material.Rock,     Hits = 3,  Points = 6,    Rarity = "COMÚN",     MinDepth = 15,  MaxDepth = 22 },
    { Name = "Carbón",       Color = Color3.fromRGB(35, 42, 52),    Material = Enum.Material.Basalt,   Hits = 3,  Points = 10,   Rarity = "POCO COMÚN", MinDepth = 23,  MaxDepth = 30 },
    { Name = "Cobre",        Color = Color3.fromRGB(184, 104, 72),  Material = Enum.Material.Metal,    Hits = 4,  Points = 16,   Rarity = "POCO COMÚN", MinDepth = 31,  MaxDepth = 38 },
    { Name = "Hierro",       Color = Color3.fromRGB(168, 148, 132), Material = Enum.Material.Metal,    Hits = 4,  Points = 23,   Rarity = "POCO COMÚN", MinDepth = 39,  MaxDepth = 46 },
    { Name = "Plata",        Color = Color3.fromRGB(210, 224, 235), Material = Enum.Material.Metal,    Hits = 5,  Points = 33,   Rarity = "RARA",       MinDepth = 47,  MaxDepth = 54 },
    { Name = "Oro",          Color = Color3.fromRGB(239, 192, 54),  Material = Enum.Material.Metal,    Hits = 6,  Points = 48,   Rarity = "RARA",       MinDepth = 55,  MaxDepth = 62 },
    { Name = "Zafiro",       Color = Color3.fromRGB(45, 115, 255),  Material = Enum.Material.Ice,      Hits = 7,  Points = 68,   Rarity = "ÉPICA",      MinDepth = 63,  MaxDepth = 70 },
    { Name = "Diamante",     Color = Color3.fromRGB(92, 218, 255),  Material = Enum.Material.Ice,      Hits = 8,  Points = 95,   Rarity = "ÉPICA",      MinDepth = 71,  MaxDepth = 78 },
    { Name = "Esmeralda",    Color = Color3.fromRGB(47, 211, 138),  Material = Enum.Material.Glass,    Hits = 10, Points = 135,  Rarity = "MÍTICA",     MinDepth = 79,  MaxDepth = 86 },
    { Name = "Cristal Lunar",Color = Color3.fromRGB(196, 142, 255), Material = Enum.Material.Glass,    Hits = 12, Points = 190,  Rarity = "MÍTICA",     MinDepth = 87,  MaxDepth = 94 },
    { Name = "Magma",        Color = Color3.fromRGB(255, 86, 38),  Material = Enum.Material.Neon,     Hits = 14, Points = 270,  Rarity = "LEGENDARIA", MinDepth = 95,  MaxDepth = 101 },
    { Name = "Obsidiana",    Color = Color3.fromRGB(30, 23, 48),    Material = Enum.Material.Basalt,   Hits = 16, Points = 390,  Rarity = "LEGENDARIA", MinDepth = 102, MaxDepth = 107 },
    { Name = "Núcleo Estelar",Color = Color3.fromRGB(255, 235, 132),Material = Enum.Material.Neon,     Hits = 20, Points = 650,  Rarity = "ANCIANA",    MinDepth = 108, MaxDepth = 999 },
}

local GRID_SIZE = 14             -- 14 x 14 bloques por capa: grande, pero estable en Studio
local BLOCK_SIZE = 6              -- tamaño de cada bloque en studs
local TOTAL_DEPTH = 110           -- 110 capas; el pozo ya no se siente corto
local START_Y = 64                -- altura de la primera capa
local MINE_WIDTH = GRID_SIZE * BLOCK_SIZE
local OUTER_WIDTH = MINE_WIDTH + 28
local HALF_GRID = math.floor(GRID_SIZE / 2)
local FLOOR_Y = START_Y - (TOTAL_DEPTH * BLOCK_SIZE) - (BLOCK_SIZE / 2) - 2
local WALL_HEIGHT = START_Y - FLOOR_Y + 22
local WALL_CENTER_Y = (START_Y + FLOOR_Y) / 2

-- Limpiar restos si el script se vuelve a ejecutar en Studio.
for _, name in ipairs({ "MineBlocks", "MineWorld", "MineBoundaries", "LeaderboardDisplay", "Surface", "MainSpawn", "MineFloor" }) do
    local old = Workspace:FindFirstChild(name)
    if old then
        old:Destroy()
    end
end

local worldFolder = Instance.new("Folder")
worldFolder.Name = "MineWorld"
worldFolder.Parent = Workspace

local blocksFolder = Instance.new("Folder")
blocksFolder.Name = "MineBlocks"
blocksFolder.Parent = Workspace

local boundariesFolder = Instance.new("Folder")
boundariesFolder.Name = "MineBoundaries"
boundariesFolder.Parent = Workspace

local function makePart(parent, name, size, position, color, material, transparency, canCollide)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.Size = size
    part.Position = position
    part.Color = color or Color3.fromRGB(255, 255, 255)
    part.Material = material or Enum.Material.SmoothPlastic
    local safeTransparency = tonumber(transparency) or 0
    part.Transparency = safeTransparency
    part.CanCollide = canCollide ~= false
    part.CanTouch = canCollide ~= false
    part.CanQuery = safeTransparency < 1
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = parent
    return part
end

local function makeNeonStrip(parent, name, size, position, color)
    local strip = makePart(parent, name, size, position, color, Enum.Material.Neon, 0, false)
    strip.CanTouch = false
    strip.CanQuery = false
    return strip
end

local function createStation(name, position, accent, title, subtitle, promptName, actionText)
    local base = makePart(worldFolder, name .. "Base", Vector3.new(13, 1.2, 9), position, Color3.fromRGB(22, 39, 52), Enum.Material.Metal, 0, true)
    base.CanQuery = false

    local console = makePart(worldFolder, name, Vector3.new(8, 8, 1.2), position + Vector3.new(0, 4.6, 2.9), Color3.fromRGB(10, 24, 37), Enum.Material.Metal, 0, true)
    console.CanQuery = false
    makeNeonStrip(worldFolder, name .. "Accent", Vector3.new(6.8, 0.16, 0.16), console.Position + Vector3.new(0, 2.8, -0.72), accent)

    local panel = Instance.new("SurfaceGui")
    panel.Name = name .. "Panel"
    panel.Adornee = console
    panel.Face = Enum.NormalId.Front
    panel.CanvasSize = Vector2.new(600, 380)
    panel.LightInfluence = 0
    panel.Brightness = 1.4
    panel.AlwaysOnTop = false
    panel.Parent = console

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.new(0, 25, 0, 55)
    titleLabel.Size = UDim2.new(1, -50, 0, 75)
    titleLabel.Font = Enum.Font.GothamBlack
    titleLabel.Text = title
    titleLabel.TextColor3 = accent
    titleLabel.TextScaled = true
    titleLabel.Parent = panel

    local subLabel = Instance.new("TextLabel")
    subLabel.Name = "Subtitle"
    subLabel.BackgroundTransparency = 1
    subLabel.Position = UDim2.new(0, 30, 0, 150)
    subLabel.Size = UDim2.new(1, -60, 0, 84)
    subLabel.Font = Enum.Font.GothamBold
    subLabel.Text = subtitle
    subLabel.TextColor3 = Color3.fromRGB(220, 234, 245)
    subLabel.TextWrapped = true
    subLabel.TextScaled = true
    subLabel.Parent = panel

    if promptName then
        local prompt = Instance.new("ProximityPrompt")
        prompt.Name = promptName
        prompt.ActionText = actionText
        prompt.ObjectText = title
        prompt.HoldDuration = 0.35
        prompt.MaxActivationDistance = 12
        prompt.RequiresLineOfSight = false
        prompt.KeyboardKeyCode = Enum.KeyCode.E
        prompt.Parent = console
    end

    return console, panel
end

local function getLayerForDepth(depth)
    for _, layer in ipairs(LAYERS) do
        if depth >= layer.MinDepth and depth <= layer.MaxDepth then
            return layer
        end
    end
    return LAYERS[#LAYERS]
end

-- ======= SUPERFICIE ABIERTA =======
-- Antes había una plataforma de Grass encima de todo el pozo. Ahora sólo hay un anillo
-- alrededor de la mina, por lo que la primera capa queda expuesta y es minable.
local function generateSurface()
    local surfaceY = START_Y + 2
    local ringThickness = 14
    local sideLength = OUTER_WIDTH
    local innerLength = MINE_WIDTH

    makePart(worldFolder, "SurfaceNorth", Vector3.new(sideLength, 4, ringThickness), Vector3.new(0, surfaceY, (innerLength / 2) + (ringThickness / 2)), Color3.fromRGB(47, 116, 88), Enum.Material.Grass)
    makePart(worldFolder, "SurfaceSouth", Vector3.new(sideLength, 4, ringThickness), Vector3.new(0, surfaceY, -(innerLength / 2) - (ringThickness / 2)), Color3.fromRGB(47, 116, 88), Enum.Material.Grass)
    makePart(worldFolder, "SurfaceEast", Vector3.new(ringThickness, 4, innerLength), Vector3.new((innerLength / 2) + (ringThickness / 2), surfaceY, 0), Color3.fromRGB(47, 116, 88), Enum.Material.Grass)
    makePart(worldFolder, "SurfaceWest", Vector3.new(ringThickness, 4, innerLength), Vector3.new(-(innerLength / 2) - (ringThickness / 2), surfaceY, 0), Color3.fromRGB(47, 116, 88), Enum.Material.Grass)

    -- Borde industrial alrededor de la boca de la mina.
    local edgeY = START_Y + 0.1
    local edgeColor = Color3.fromRGB(34, 53, 71)
    makePart(worldFolder, "MineRimNorth", Vector3.new(innerLength, 1.2, 1.2), Vector3.new(0, edgeY, innerLength / 2), edgeColor, Enum.Material.Metal)
    makePart(worldFolder, "MineRimSouth", Vector3.new(innerLength, 1.2, 1.2), Vector3.new(0, edgeY, -innerLength / 2), edgeColor, Enum.Material.Metal)
    makePart(worldFolder, "MineRimEast", Vector3.new(1.2, 1.2, innerLength), Vector3.new(innerLength / 2, edgeY, 0), edgeColor, Enum.Material.Metal)
    makePart(worldFolder, "MineRimWest", Vector3.new(1.2, 1.2, innerLength), Vector3.new(-innerLength / 2, edgeY, 0), edgeColor, Enum.Material.Metal)

    for i = -4, 4 do
        makeNeonStrip(worldFolder, "RimLightN" .. i, Vector3.new(4, 0.18, 0.18), Vector3.new(i * 12, START_Y + 0.75, innerLength / 2 + 0.75), Color3.fromRGB(62, 220, 255))
        makeNeonStrip(worldFolder, "RimLightS" .. i, Vector3.new(4, 0.18, 0.18), Vector3.new(i * 12, START_Y + 0.75, -innerLength / 2 - 0.75), Color3.fromRGB(62, 220, 255))
    end

    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "MainSpawn"
    spawn.Anchored = true
    spawn.CanCollide = true
    spawn.Neutral = true
    spawn.Size = Vector3.new(8, 1, 8)
    spawn.Position = Vector3.new(-OUTER_WIDTH / 2 + 9, START_Y + 4.5, OUTER_WIDTH / 2 - 7)
    spawn.Transparency = 0.15
    spawn.Color = Color3.fromRGB(71, 221, 191)
    spawn.Material = Enum.Material.Neon
    spawn.Parent = worldFolder

    local spawnPad = makePart(worldFolder, "SpawnPad", Vector3.new(26, 1, 22), Vector3.new(-OUTER_WIDTH / 2 + 9, START_Y + 1, OUTER_WIDTH / 2 - 7), Color3.fromRGB(25, 48, 65), Enum.Material.Metal)
    spawnPad.CanQuery = false

    -- Estaciones físicas: el jugador encuentra las mejoras y contratos en el campamento, no en un menú invasivo.
    local stationZ = OUTER_WIDTH / 2 - 7
    createStation("ForgeStation", Vector3.new(-12, START_Y + 1, stationZ), Color3.fromRGB(255, 174, 67), "FORJA DE PROFUNDIDAD", "MEJORA LA POTENCIA BASE DEL PICO", "ForgePrompt", "FORJAR MEJORA")
    createStation("ScannerStation", Vector3.new(10, START_Y + 1, stationZ), Color3.fromRGB(77, 225, 255), "ESCÁNER GEOLOGICO", "ACTIVA UNA VENTANA DE HALLAZGOS MEJORADOS", "ScannerPrompt", "ACTIVAR ESCÁNER")
    createStation("ContractStation", Vector3.new(32, START_Y + 1, stationZ), Color3.fromRGB(95, 232, 190), "CONTRATOS DE MINERÍA", "ROMPE BLOQUES, DESCIENDE Y DESCUBRE MINERALES RAROS", "ContractPrompt", "RECLAMAR CONTRATO")
    local eventBeacon, eventPanel = createStation("EventBeacon", Vector3.new(48, START_Y + 1, stationZ), Color3.fromRGB(196, 142, 255), "BALIZA DE EVENTOS", "SIN EVENTO ACTIVO // LA MINA ESTÁ ESTABLE", nil, nil)

    -- Faros del campamento.
    for _, x in ipairs({ -OUTER_WIDTH / 2 + 3, -OUTER_WIDTH / 2 + 15 }) do
        local pole = makePart(worldFolder, "CampLightPole", Vector3.new(0.7, 9, 0.7), Vector3.new(x, START_Y + 6.5, OUTER_WIDTH / 2 - 3), Color3.fromRGB(50, 67, 82), Enum.Material.Metal)
        local lamp = makePart(worldFolder, "CampLight", Vector3.new(2.4, 0.5, 2.4), pole.Position + Vector3.new(0, 4.8, 0), Color3.fromRGB(255, 224, 130), Enum.Material.Neon, 0, false)
        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(100, 220, 255)
        light.Brightness = 1.8
        light.Range = 24
        light.Parent = lamp
    end

end

local function createBlock(x, y, z, depth)
    local layer = getLayerForDepth(depth)
    local block = Instance.new("Part")
    block.Name = layer.Name
    block.Anchored = true
    block.Size = Vector3.new(BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE)
    block.Position = Vector3.new(x, y, z)
    block.Color = layer.Color
    block.Material = layer.Material
    block.TopSurface = Enum.SurfaceType.Smooth
    block.BottomSurface = Enum.SurfaceType.Smooth
    block.CastShadow = true
    block:SetAttribute("LayerName", layer.Name)
    block:SetAttribute("Rarity", layer.Rarity or "COMÚN")
    block:SetAttribute("MaxHits", layer.Hits)
    block:SetAttribute("HitsLeft", layer.Hits)
    block:SetAttribute("Points", layer.Points)
    block:SetAttribute("Depth", depth)
    block:SetAttribute("IsMineable", true)
    block:SetAttribute("IsPlaced", false)
    block.Parent = blocksFolder
    return block
end

local function createDepthLandmark(depth, title, accent)
    local markerY = START_Y - (depth * BLOCK_SIZE) + 1
    local marker = makePart(worldFolder, "ZoneMarker_" .. depth, Vector3.new(30, 4.5, 0.7), Vector3.new(0, markerY, -(MINE_WIDTH / 2 + 4)), Color3.fromRGB(12, 27, 42), Enum.Material.Metal, 0, true)
    marker.CanQuery = false
    makeNeonStrip(worldFolder, "ZoneMarkerLight_" .. depth, Vector3.new(26, 0.16, 0.14), marker.Position + Vector3.new(0, 1.6, 0.48), accent)

    local panel = Instance.new("SurfaceGui")
    panel.Name = "ZonePanel"
    panel.Adornee = marker
    panel.Face = Enum.NormalId.Back
    panel.CanvasSize = Vector2.new(720, 180)
    panel.LightInfluence = 0
    panel.Brightness = 1.25
    panel.Parent = marker

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Size = UDim2.new(1, 0, 1, 0)
    text.Font = Enum.Font.GothamBlack
    text.Text = title
    text.TextColor3 = accent
    text.TextStrokeColor3 = Color3.fromRGB(5, 13, 24)
    text.TextStrokeTransparency = 0.15
    text.TextScaled = true
    text.Parent = panel
end

local function generateMine()
    generateSurface()

    -- Indices exactos de -9 a 8: 18 x 18, sin huecos laterales.
    for depth = 1, TOTAL_DEPTH do
        local y = START_Y - (depth * BLOCK_SIZE)
        for xi = -HALF_GRID, HALF_GRID - 1 do
            for zi = -HALF_GRID, HALF_GRID - 1 do
                createBlock(xi * BLOCK_SIZE, y, zi * BLOCK_SIZE, depth)
            end
        end
        -- Ceder un frame evita que la generación masiva congele Studio y permite que la mina aparezca progresivamente.
        if depth % 2 == 0 then
            task.wait()
        end
    end

    createDepthLandmark(8, "CAPA DE GRANITO // TÚNELES ANTIGUOS", Color3.fromRGB(177, 167, 160))
    createDepthLandmark(31, "VETA DE COBRE // GALERÍA INDUSTRIAL", Color3.fromRGB(244, 140, 91))
    createDepthLandmark(55, "BÓVEDA DORADA // ZONA DE RIESGO", Color3.fromRGB(255, 206, 78))
    createDepthLandmark(79, "CAVERNAS PRISMÁTICAS // GEMAS", Color3.fromRGB(100, 232, 255))
    createDepthLandmark(102, "FRACTURA DE OBSIDIANA // ABISMO", Color3.fromRGB(201, 141, 255))

    -- Piso real de seguridad: si se rompe todo, el jugador nunca cae al vacío.
    local floor = makePart(boundariesFolder, "MineFloor", Vector3.new(OUTER_WIDTH + 40, 4, OUTER_WIDTH + 40), Vector3.new(0, FLOOR_Y, 0), Color3.fromRGB(19, 26, 38), Enum.Material.Basalt)
    floor:SetAttribute("IsMineable", false)

    -- Muros invisibles en los cuatro lados: protegen la zona incluso si se excava hasta el borde.
    local wallThickness = 2
    makePart(boundariesFolder, "BoundaryNorth", Vector3.new(OUTER_WIDTH + 40, WALL_HEIGHT, wallThickness), Vector3.new(0, WALL_CENTER_Y, OUTER_WIDTH / 2 + 18), Color3.fromRGB(255, 255, 255), Enum.Material.ForceField, 1, true)
    makePart(boundariesFolder, "BoundarySouth", Vector3.new(OUTER_WIDTH + 40, WALL_HEIGHT, wallThickness), Vector3.new(0, WALL_CENTER_Y, -OUTER_WIDTH / 2 - 18), Color3.fromRGB(255, 255, 255), Enum.Material.ForceField, 1, true)
    makePart(boundariesFolder, "BoundaryEast", Vector3.new(wallThickness, WALL_HEIGHT, OUTER_WIDTH + 40), Vector3.new(OUTER_WIDTH / 2 + 18, WALL_CENTER_Y, 0), Color3.fromRGB(255, 255, 255), Enum.Material.ForceField, 1, true)
    makePart(boundariesFolder, "BoundaryWest", Vector3.new(wallThickness, WALL_HEIGHT, OUTER_WIDTH + 40), Vector3.new(-OUTER_WIDTH / 2 - 18, WALL_CENTER_Y, 0), Color3.fromRGB(255, 255, 255), Enum.Material.ForceField, 1, true)

    -- Monitor físico de clasificación: está en el mundo, no en el HUD del jugador.
    -- Se coloca al sur de la entrada y mira hacia el interior de la mina.
    local boardPosition = Vector3.new(0, START_Y + 13, -(OUTER_WIDTH / 2 + 10))
    local display = makePart(Workspace, "LeaderboardDisplay", Vector3.new(46, 23, 1), boardPosition, Color3.fromRGB(8, 19, 32), Enum.Material.Metal, 0, true)
    display.CanQuery = false
    display:SetAttribute("DisplayType", "MiningLeaderboard")

    local displayFrame = makePart(worldFolder, "LeaderboardFrame", Vector3.new(49, 26, 1.6), boardPosition - Vector3.new(0, 0, 0.25), Color3.fromRGB(29, 60, 82), Enum.Material.Metal, 0, true)
    displayFrame.CanQuery = false
    local displayFace = makePart(worldFolder, "LeaderboardFace", Vector3.new(44, 21, 0.25), boardPosition - Vector3.new(0, 0, 1.1), Color3.fromRGB(6, 15, 27), Enum.Material.SmoothPlastic, 0, false)
    displayFace.CanQuery = false
    makeNeonStrip(worldFolder, "LeaderboardTopLight", Vector3.new(41, 0.18, 0.18), boardPosition + Vector3.new(0, 10.7, 1.1), Color3.fromRGB(78, 224, 255))

    for _, xOffset in ipairs({ -17, 17 }) do
        local post = makePart(worldFolder, "LeaderboardPost", Vector3.new(1.4, 14, 1.4), boardPosition + Vector3.new(xOffset, -17, 0), Color3.fromRGB(28, 48, 63), Enum.Material.Metal, 0, true)
        post.CanQuery = false
        local foot = makePart(worldFolder, "LeaderboardFoot", Vector3.new(7, 1.2, 6), post.Position - Vector3.new(0, 7.5, 0), Color3.fromRGB(22, 39, 52), Enum.Material.Metal, 0, true)
        foot.CanQuery = false
    end

    Workspace:SetAttribute("MineGridSize", GRID_SIZE)
    Workspace:SetAttribute("MineBlockSize", BLOCK_SIZE)
    Workspace:SetAttribute("MineTotalDepth", TOTAL_DEPTH)
    Workspace:SetAttribute("MineStartY", START_Y)
    Workspace:SetAttribute("MineFloorY", FLOOR_Y)
    Workspace.FallenPartsDestroyHeight = FLOOR_Y - 30

    print("[WorldGenerator] Mina generada:", GRID_SIZE, "x", GRID_SIZE, "x", TOTAL_DEPTH, "con superficie abierta y límites de seguridad.")
end

generateMine()

_G.MINE_LAYERS = LAYERS
_G.MINE_CONFIG = {
    GRID_SIZE = GRID_SIZE,
    BLOCK_SIZE = BLOCK_SIZE,
    TOTAL_DEPTH = TOTAL_DEPTH,
    START_Y = START_Y,
    FLOOR_Y = FLOOR_Y,
}

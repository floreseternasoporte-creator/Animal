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
    { Name = "Tierra",     Color = Color3.fromRGB(126, 82, 52),   Material = Enum.Material.Ground,   Hits = 1,  Points = 1,   MinDepth = 1,  MaxDepth = 8 },
    { Name = "Piedra",     Color = Color3.fromRGB(112, 121, 132), Material = Enum.Material.Slate,    Hits = 2,  Points = 3,   MinDepth = 9,  MaxDepth = 22 },
    { Name = "Carbón",     Color = Color3.fromRGB(35, 42, 52),    Material = Enum.Material.Basalt,   Hits = 3,  Points = 8,   MinDepth = 23, MaxDepth = 36 },
    { Name = "Cobre",      Color = Color3.fromRGB(184, 104, 72),  Material = Enum.Material.Metal,    Hits = 3,  Points = 12,  MinDepth = 37, MaxDepth = 48 },
    { Name = "Hierro",     Color = Color3.fromRGB(168, 148, 132), Material = Enum.Material.Metal,    Hits = 4,  Points = 18,  MinDepth = 49, MaxDepth = 60 },
    { Name = "Oro",        Color = Color3.fromRGB(239, 192, 54),  Material = Enum.Material.Metal,    Hits = 5,  Points = 34,  MinDepth = 61, MaxDepth = 72 },
    { Name = "Diamante",   Color = Color3.fromRGB(92, 218, 255),  Material = Enum.Material.Ice,      Hits = 7,  Points = 68,  MinDepth = 73, MaxDepth = 86 },
    { Name = "Esmeralda",  Color = Color3.fromRGB(47, 211, 138),  Material = Enum.Material.Glass,    Hits = 9,  Points = 115, MinDepth = 87, MaxDepth = 98 },
    { Name = "Obsidiana",  Color = Color3.fromRGB(30, 23, 48),    Material = Enum.Material.Basalt,   Hits = 12, Points = 230, MinDepth = 99, MaxDepth = 999 },
}

local GRID_SIZE = 18             -- 18 x 18 bloques por capa
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
    part.Transparency = transparency or 0
    part.CanCollide = canCollide ~= false
    part.CanTouch = canCollide ~= false
    part.CanQuery = transparency < 1
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

    local signAnchor = makePart(worldFolder, "MineSignAnchor", Vector3.new(1, 1, 1), Vector3.new(0, START_Y + 13, OUTER_WIDTH / 2 + 4), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, 1, false)
    local sign = Instance.new("BillboardGui")
    sign.Name = "MineTitle"
    sign.Adornee = signAnchor
    sign.Size = UDim2.new(0, 520, 0, 120)
    sign.StudsOffset = Vector3.new(0, 0, 0)
    sign.AlwaysOnTop = true
    sign.Parent = worldFolder

    local signLabel = Instance.new("TextLabel")
    signLabel.BackgroundTransparency = 1
    signLabel.Size = UDim2.new(1, 0, 1, 0)
    signLabel.Font = Enum.Font.GothamBlack
    signLabel.Text = ("MINA PROFUNDA  //  %d CAPAS"):format(TOTAL_DEPTH)
    signLabel.TextColor3 = Color3.fromRGB(95, 227, 255)
    signLabel.TextStrokeColor3 = Color3.fromRGB(15, 31, 52)
    signLabel.TextStrokeTransparency = 0.15
    signLabel.TextScaled = true
    signLabel.Parent = sign
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
    block:SetAttribute("MaxHits", layer.Hits)
    block:SetAttribute("HitsLeft", layer.Hits)
    block:SetAttribute("Points", layer.Points)
    block:SetAttribute("Depth", depth)
    block:SetAttribute("IsMineable", true)
    block:SetAttribute("IsPlaced", false)
    block.Parent = blocksFolder
    return block
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
    end

    -- Piso real de seguridad: si se rompe todo, el jugador nunca cae al vacío.
    local floor = makePart(boundariesFolder, "MineFloor", Vector3.new(OUTER_WIDTH + 40, 4, OUTER_WIDTH + 40), Vector3.new(0, FLOOR_Y, 0), Color3.fromRGB(19, 26, 38), Enum.Material.Basalt)
    floor:SetAttribute("IsMineable", false)

    -- Muros invisibles en los cuatro lados: protegen la zona incluso si se excava hasta el borde.
    local wallThickness = 2
    makePart(boundariesFolder, "BoundaryNorth", Vector3.new(OUTER_WIDTH + 40, WALL_HEIGHT, wallThickness), Vector3.new(0, WALL_CENTER_Y, OUTER_WIDTH / 2 + 18), Color3.fromRGB(255, 255, 255), Enum.Material.ForceField, 1, true)
    makePart(boundariesFolder, "BoundarySouth", Vector3.new(OUTER_WIDTH + 40, WALL_HEIGHT, wallThickness), Vector3.new(0, WALL_CENTER_Y, -OUTER_WIDTH / 2 - 18), Color3.fromRGB(255, 255, 255), Enum.Material.ForceField, 1, true)
    makePart(boundariesFolder, "BoundaryEast", Vector3.new(wallThickness, WALL_HEIGHT, OUTER_WIDTH + 40), Vector3.new(OUTER_WIDTH / 2 + 18, WALL_CENTER_Y, 0), Color3.fromRGB(255, 255, 255), Enum.Material.ForceField, 1, true)
    makePart(boundariesFolder, "BoundaryWest", Vector3.new(wallThickness, WALL_HEIGHT, OUTER_WIDTH + 40), Vector3.new(-OUTER_WIDTH / 2 - 18, WALL_CENTER_Y, 0), Color3.fromRGB(255, 255, 255), Enum.Material.ForceField, 1, true)

    -- Pantalla 3D física. El cliente crea el SurfaceGui sobre esta pieza.
    local display = makePart(Workspace, "LeaderboardDisplay", Vector3.new(46, 23, 1), Vector3.new(0, START_Y + 13, -(OUTER_WIDTH / 2 + 10)), Color3.fromRGB(10, 20, 34), Enum.Material.Metal, 0, true)
    display:SetAttribute("DisplayType", "MiningLeaderboard")
    local displayGlow = makePart(worldFolder, "LeaderboardGlow", Vector3.new(43, 20, 0.2), display.Position + Vector3.new(0, 0, 0.58), Color3.fromRGB(33, 112, 150), Enum.Material.Neon, 0.72, false)
    displayGlow.CanQuery = false

    -- Atril superior para que se identifique como panel de clasificación.
    local boardHeader = makePart(worldFolder, "LeaderboardHeader", Vector3.new(42, 2.2, 1.5), display.Position + Vector3.new(0, 12.5, 0), Color3.fromRGB(38, 83, 111), Enum.Material.Metal)
    boardHeader.CanQuery = false
    makeNeonStrip(worldFolder, "BoardHeaderLine", Vector3.new(37, 0.12, 0.12), boardHeader.Position + Vector3.new(0, -0.75, -0.8), Color3.fromRGB(82, 226, 255))

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

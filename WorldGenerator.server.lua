--[[
	WorldGenerator.server.lua
	UBICACIÓN: ServerScriptService

	Genera el "pozo" de minería en capas verticales.
	Cada capa tiene un material, color, dureza (cuántos golpes para romperse)
	y puntos que otorga al jugador cuando se rompe.

	Mientras más profundo, más difícil y más puntos vale.
]]

local Workspace = game:GetService("Workspace")

-- ======= CONFIGURACIÓN DE CAPAS =======
-- Cada capa define: nombre, color, cuántos "golpes" para romper el bloque,
-- puntos que otorga, y el rango de profundidad (en número de capa) donde aparece.
local LAYERS = {
	{ Name = "Tierra",     Color = Color3.fromRGB(117, 79, 53),   Hits = 1,  Points = 1,   MinDepth = 1,  MaxDepth = 5 },
	{ Name = "Piedra",     Color = Color3.fromRGB(120, 120, 120), Hits = 2,  Points = 3,   MinDepth = 6,  MaxDepth = 15 },
	{ Name = "Carbón",     Color = Color3.fromRGB(40, 40, 40),    Hits = 3,  Points = 8,   MinDepth = 16, MaxDepth = 25 },
	{ Name = "Hierro",     Color = Color3.fromRGB(186, 148, 108), Hits = 4,  Points = 15,  MinDepth = 26, MaxDepth = 35 },
	{ Name = "Oro",        Color = Color3.fromRGB(212, 175, 55),  Hits = 5,  Points = 30,  MinDepth = 36, MaxDepth = 45 },
	{ Name = "Diamante",   Color = Color3.fromRGB(120, 220, 255), Hits = 7,  Points = 60,  MinDepth = 46, MaxDepth = 55 },
	{ Name = "Esmeralda",  Color = Color3.fromRGB(40, 200, 120),  Hits = 9,  Points = 100, MinDepth = 56, MaxDepth = 65 },
	{ Name = "Obsidiana",  Color = Color3.fromRGB(20, 15, 30),    Hits = 12, Points = 200, MinDepth = 66, MaxDepth = 999 },
}

-- Tamaño del pozo
local GRID_SIZE = 10        -- 10x10 bloques por capa
local BLOCK_SIZE = 6        -- tamaño en studs de cada bloque
local TOTAL_DEPTH = 80       -- número total de capas a generar
local START_Y = 50           -- altura Y donde empieza la superficie

-- Carpeta donde viven todos los bloques
local blocksFolder = Instance.new("Folder")
blocksFolder.Name = "MineBlocks"
blocksFolder.Parent = Workspace

-- Función para elegir qué capa corresponde a cierta profundidad
local function getLayerForDepth(depth)
	for _, layer in ipairs(LAYERS) do
		if depth >= layer.MinDepth and depth <= layer.MaxDepth then
			return layer
		end
	end
	-- Si se pasa del rango definido, usa la última capa (la más difícil)
	return LAYERS[#LAYERS]
end

-- Genera una plataforma de inicio (superficie) donde el jugador spawnea
local function generateSurface()
	local platform = Instance.new("Part")
	platform.Name = "Surface"
	platform.Anchored = true
	platform.Size = Vector3.new(GRID_SIZE * BLOCK_SIZE + 10, 4, GRID_SIZE * BLOCK_SIZE + 10)
	platform.Position = Vector3.new(0, START_Y + 2, 0)
	platform.Color = Color3.fromRGB(90, 170, 90)
	platform.Material = Enum.Material.Grass
	platform.Parent = Workspace

	-- SpawnLocation encima de la plataforma
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MainSpawn"
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(0, START_Y + 4.5, 0)
	spawn.Transparency = 0.5
	spawn.BrickColor = BrickColor.new("Bright green")
	spawn.Parent = Workspace
end

-- Genera un bloque individual y le pone los atributos necesarios
local function createBlock(x, y, z, depth)
	local layer = getLayerForDepth(depth)

	local block = Instance.new("Part")
	block.Name = layer.Name
	block.Anchored = true
	block.Size = Vector3.new(BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE)
	block.Position = Vector3.new(x, y, z)
	block.Color = layer.Color
	block.Material = Enum.Material.Slate
	block.TopSurface = Enum.SurfaceType.Smooth
	block.BottomSurface = Enum.SurfaceType.Smooth

	-- Atributos que el script de minería va a leer
	block:SetAttribute("LayerName", layer.Name)
	block:SetAttribute("MaxHits", layer.Hits)
	block:SetAttribute("HitsLeft", layer.Hits)
	block:SetAttribute("Points", layer.Points)
	block:SetAttribute("Depth", depth)
	block:SetAttribute("IsMineable", true)

	block.Parent = blocksFolder

	return block
end

-- Genera todo el pozo capa por capa
local function generateMine()
	generateSurface()

	local half = math.floor(GRID_SIZE / 2)

	for depth = 1, TOTAL_DEPTH do
		local y = START_Y - (depth * BLOCK_SIZE)

		for xi = -half, half do
			for zi = -half, half do
				local x = xi * BLOCK_SIZE
				local z = zi * BLOCK_SIZE
				createBlock(x, y, z, depth)
			end
		end
	end

	-- Piso final indestructible en el fondo del pozo (por si alguien llega hasta el fondo)
	local floor = Instance.new("Part")
	floor.Name = "MineFloor"
	floor.Anchored = true
	floor.Size = Vector3.new(GRID_SIZE * BLOCK_SIZE + 10, 4, GRID_SIZE * BLOCK_SIZE + 10)
	floor.Position = Vector3.new(0, START_Y - (TOTAL_DEPTH * BLOCK_SIZE) - 2, 0)
	floor.Color = Color3.fromRGB(10, 10, 10)
	floor.Material = Enum.Material.Basalt
	floor.Parent = Workspace

	print("[WorldGenerator] Mina generada con éxito. Profundidad total:", TOTAL_DEPTH, "capas.")
end

generateMine()

-- Exponemos las capas como un ModuleScript-like a través de un value,
-- pero más simple: guardamos la config en un Folder de atributos por si
-- otros scripts la necesitan (opcional). Aquí lo dejamos disponible
-- globalmente vía _G para que MiningHandler lo use fácilmente.
_G.MINE_LAYERS = LAYERS
_G.MINE_CONFIG = {
	GRID_SIZE = GRID_SIZE,
	BLOCK_SIZE = BLOCK_SIZE,
	TOTAL_DEPTH = TOTAL_DEPTH,
	START_Y = START_Y,
}

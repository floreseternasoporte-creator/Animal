--[=[
    MiningAudio.client.lua
    UBICACIÓN: StarterPlayer > StarterPlayerScripts

    Sistema de audio de la mina. Los IDs están centralizados para poder sustituirlos
    desde Studio si un asset cambia de permisos o disponibilidad.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("MiningRemotes")
local blockHitEvent = remotes:WaitForChild("BlockHit")
local blockBrokenEvent = remotes:WaitForChild("BlockBroken")
local blockPlacedEvent = remotes:WaitForChild("BlockPlaced")
local specialDiscoveryEvent = remotes:WaitForChild("SpecialDiscovery")
local notifyEvent = remotes:WaitForChild("Notify")
local statsUpdateEvent = remotes:WaitForChild("StatsUpdate")

-- IDs consultados en Creator Store. Si Studio indica falta de permisos, reemplaza
-- el valor por un audio encontrado con Toolbox > Creator Store > Audio.
local AUDIO = {
    CaveAmbience = "rbxassetid://273398061",
    LevelUp = "rbxassetid://2686079706",
    RockBreak = "rbxassetid://9125931990",
    RockFragments = "rbxassetid://9125929705",
    -- Música de respaldo: el ambiente de cueva funciona como base musical atmosférica.
    MineTheme = "rbxassetid://273398061",
}

local SOUND_GROUP_NAME = "MiningAudio"
local soundGroup = SoundService:FindFirstChild(SOUND_GROUP_NAME)
if not soundGroup then
    soundGroup = Instance.new("SoundGroup")
    soundGroup.Name = SOUND_GROUP_NAME
    soundGroup.Volume = 0.9
    soundGroup.Parent = SoundService
end

local function newSound(name, soundId, volume, looped)
    local sound = Instance.new("Sound")
    sound.Name = name
    sound.SoundId = soundId
    sound.Volume = volume or 0.5
    sound.Looped = looped == true
    sound.RollOffMode = Enum.RollOffMode.InverseTapered
    sound.SoundGroup = soundGroup
    return sound
end

local function play2D(name, soundId, volume, playbackSpeed)
    local sound = newSound(name, soundId, volume, false)
    sound.PlaybackSpeed = playbackSpeed or 1
    sound.Parent = SoundService
    sound:Play()
    sound.Ended:Connect(function()
        sound:Destroy()
    end)
    Debris:AddItem(sound, 12)
    return sound
end

local function play3D(name, soundId, position, volume, playbackSpeed, maxDistance)
    if not position then return end
    local anchor = Instance.new("Part")
    anchor.Name = "MiningAudioEmitter"
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.CanTouch = false
    anchor.CanQuery = false
    anchor.Transparency = 1
    anchor.Size = Vector3.new(0.3, 0.3, 0.3)
    anchor.Position = position
    anchor.Parent = workspace

    local sound = newSound(name, soundId, volume, false)
    sound.PlaybackSpeed = playbackSpeed or 1
    sound.RollOffMaxDistance = maxDistance or 55
    sound.RollOffMinDistance = 8
    sound.Parent = anchor
    sound:Play()
    sound.Ended:Connect(function()
        anchor:Destroy()
    end)
    Debris:AddItem(anchor, 8)
    return sound
end

-- Música/ambiente persistente. Se separan en dos canales para poder bajarlos
-- individualmente cuando el jugador entra a capas profundas.
local theme = newSound("MineTheme", AUDIO.MineTheme, 0.12, true)
theme.PlaybackSpeed = 0.78
theme.Parent = SoundService

theme:Play()

local ambience = newSound("CaveAmbience", AUDIO.CaveAmbience, 0.08, true)
ambience.PlaybackSpeed = 0.96
ambience.Parent = SoundService
local reverb = Instance.new("ReverbSoundEffect")
reverb.Name = "DeepCaveReverb"
reverb.DecayTime = 2.8
reverb.Density = 0.72
reverb.Diffusion = 0.82
reverb.WetLevel = -8
reverb.DryLevel = -2
reverb.Parent = ambience
ambience:Play()

local lastDepth = 0
local function updateAtmosphere(stats)
    local depth = stats and (stats.CurrentDepth or 0) or 0
    local total = stats and (stats.MineTotalDepth or 110) or 110
    if math.abs(depth - lastDepth) < 2 then return end
    lastDepth = depth

    local ratio = math.clamp(depth / math.max(1, total), 0, 1)
    local targetTheme = 0.12 - (ratio * 0.035)
    local targetAmbience = 0.08 + (ratio * 0.08)
    local targetDecay = 2.8 + (ratio * 2.5)
    TweenService:Create(theme, TweenInfo.new(1.2), { Volume = targetTheme, PlaybackSpeed = 0.78 - (ratio * 0.08) }):Play()
    TweenService:Create(ambience, TweenInfo.new(1.2), { Volume = targetAmbience }):Play()
    TweenService:Create(reverb, TweenInfo.new(1.2), { DecayTime = targetDecay }):Play()
end

local function blockPosition(block)
    return block and block.Position or nil
end

local function getBlockDepth(block)
    return block and tonumber(block:GetAttribute("Depth")) or 0
end

blockHitEvent.OnClientEvent:Connect(function(block)
    local speed = 0.91 + (math.random() * 0.18)
    play3D("PickaxeHit", AUDIO.RockFragments, blockPosition(block), 0.34, speed, 42)
end)

blockBrokenEvent.OnClientEvent:Connect(function(block, layerName, points, _, _, rarity)
    local depth = getBlockDepth(block)
    local speed = 0.86 + (math.random() * 0.22)
    local volume = rarity and rarity ~= "COMÚN" and 0.78 or 0.55
    play3D("BlockBreak_" .. tostring(layerName), AUDIO.RockBreak, blockPosition(block), volume, speed, 62)

    if depth >= 95 or (rarity and rarity ~= "COMÚN") then
        play3D("RareOrePulse", AUDIO.RockFragments, blockPosition(block), 0.72, 0.68, 72)
    end
end)

blockPlacedEvent.OnClientEvent:Connect(function(block)
    play3D("BuildPlace", AUDIO.RockFragments, blockPosition(block), 0.42, 1.12 + (math.random() * 0.12), 48)
end)

specialDiscoveryEvent.OnClientEvent:Connect(function(layerName, rarity, points, depth)
    play2D("RareDiscovery", AUDIO.LevelUp, 0.64, 1.12)
    task.delay(0.16, function()
        play2D("DiscoveryEcho", AUDIO.LevelUp, 0.34, 0.76)
    end)
end)

notifyEvent.OnClientEvent:Connect(function(text)
    local message = tostring(text)
    if message:find("NUEVO PICO") or message:find("NUEVO RÉCORD") or message:find("CONTRATO COMPLETADO") then
        play2D("Achievement", AUDIO.LevelUp, 0.86, message:find("PICO") and 1.0 or 1.16)
    elseif message:find("FORJA MEJORADA") or message:find("EVENTO ACTIVO") or message:find("ESCÁNER ACTIVADO") then
        play2D("UpgradeOrEvent", AUDIO.LevelUp, 0.68, 0.88)
    elseif message:find("COLOCADO") then
        play2D("BuildConfirm", AUDIO.RockFragments, 0.28, 1.28)
    end
end)

statsUpdateEvent.OnClientEvent:Connect(updateAtmosphere)

player.CharacterRemoving:Connect(function()
    -- Los sonidos 2D continúan suavemente entre respawns; los emisores 3D son efímeros.
end)

print("[MiningAudio] Música, ambiente, golpes, roturas, construcción y descubrimientos listos.")

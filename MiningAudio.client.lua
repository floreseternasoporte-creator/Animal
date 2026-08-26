--[=[
    MiningAudio.client.lua
    UBICACIÓN: StarterPlayer > StarterPlayerScripts

    Audio de Crónicas de Lumenfall. Los IDs permanecen centralizados para poder
    sustituirlos en Studio si cambian permisos de Creator Store.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local remotes = ReplicatedStorage:WaitForChild("LumenRemotes")
local harvestFX = remotes:WaitForChild("HarvestFX")
local notify = remotes:WaitForChild("Notify")

local AUDIO = {
    Ambience = "rbxassetid://273398061",
    Chime = "rbxassetid://2686079706",
    Break = "rbxassetid://9125931990",
    Fragments = "rbxassetid://9125929705",
}

local group = SoundService:FindFirstChild("LumenfallAudio")
if not group then
    group = Instance.new("SoundGroup")
    group.Name = "LumenfallAudio"
    group.Volume = 0.85
    group.Parent = SoundService
end

local function play(soundId, volume, speed, parent)
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = volume
    sound.PlaybackSpeed = speed or 1
    sound.RollOffMaxDistance = 58
    sound.RollOffMinDistance = 7
    sound.SoundGroup = group
    sound.Parent = parent or SoundService
    sound:Play()
    sound.Ended:Connect(function() sound:Destroy() end)
    Debris:AddItem(sound, 10)
    return sound
end

local ambience = Instance.new("Sound")
ambience.Name = "LumenfallAmbience"
ambience.SoundId = AUDIO.Ambience
ambience.Volume = 0.08
ambience.PlaybackSpeed = 0.82
ambience.Looped = true
ambience.SoundGroup = group
ambience.Parent = SoundService
ambience:Play()

harvestFX.OnClientEvent:Connect(function(position, color, hitOnly, placed)
    local anchor = Instance.new("Part")
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.CanTouch = false
    anchor.CanQuery = false
    anchor.Transparency = 1
    anchor.Size = Vector3.new(0.1, 0.1, 0.1)
    anchor.Position = position
    anchor.Parent = workspace
    play(placed and AUDIO.Fragments or (hitOnly and AUDIO.Fragments or AUDIO.Break), placed and 0.3 or 0.48, placed and 1.18 or (0.9 + math.random() * 0.16), anchor)
    Debris:AddItem(anchor, 8)
end)

notify.OnClientEvent:Connect(function(message)
    message = tostring(message)
    if message:find("BALIZA") or message:find("KIT FABRICADO") or message:find("ENERGÍA RESTAURADA") then
        play(AUDIO.Chime, 0.7, 1.04)
    elseif message:find("RECOLECTASTE") then
        play(AUDIO.Fragments, 0.24, 1.2)
    end
end)

print("[LumenfallAudio] Ambiente y efectos listos.")

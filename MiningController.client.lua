--[=[
    MiningController.client.lua
    UBICACIÓN: StarterPlayer > StarterPlayerScripts

    Control local de Crónicas de Lumenfall.
    Click/tap recolecta. B cambia a construcción. Las teclas 1-4 eligen material.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local remotes = ReplicatedStorage:WaitForChild("LumenRemotes")
local gatherRequest = remotes:WaitForChild("GatherRequest")
local placeRequest = remotes:WaitForChild("PlaceRequest")
local harvestFX = remotes:WaitForChild("HarvestFX")

local MAX_DISTANCE = 17
local ACTION_INTERVAL = 0.2
local lastAction = 0
local buildMode = false
local buildTypes = { "Madera", "Piedra", "Cristal", "Lumen" }
local selectedIndex = 1
local currentHighlight
local keyToBuildIndex = {
    [Enum.KeyCode.One] = 1,
    [Enum.KeyCode.Two] = 2,
    [Enum.KeyCode.Three] = 3,
    [Enum.KeyCode.Four] = 4,
}

local function characterRoot()
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function validTarget(target)
    local root = characterRoot()
    if not target or not root or not target:IsA("BasePart") then return nil end
    if (root.Position - target.Position).Magnitude > MAX_DISTANCE then return nil end
    return target
end

local function targetIsHarvestable(target)
    local current = target
    while current and current ~= workspace do
        if current:IsA("Model") and current:GetAttribute("HarvestNode") then
            return true
        end
        current = current.Parent
    end
    local world = workspace:FindFirstChild("LumenfallWorld")
    local terrain = world and world:FindFirstChild("LumenTerrain")
    return terrain and target:IsDescendantOf(terrain) and target:GetAttribute("Voxel") == true
end

local function targetIsBuildable(target)
    local world = workspace:FindFirstChild("LumenfallWorld")
    if not world or not target then return false end
    local terrain = world:FindFirstChild("LumenTerrain")
    local builds = world:FindFirstChild("LumenPlayerBuilds")
    return (terrain and target:IsDescendantOf(terrain)) or (builds and target:IsDescendantOf(builds))
end

local function updateHighlight()
    local target = validTarget(mouse.Target)
    local allowed = target and (buildMode and targetIsBuildable(target) or (not buildMode and targetIsHarvestable(target)))
    if currentHighlight then
        currentHighlight:Destroy()
        currentHighlight = nil
    end
    if not allowed then return end

    local highlight = Instance.new("Highlight")
    highlight.Adornee = target
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = 0.8
    highlight.OutlineTransparency = 0.08
    highlight.FillColor = buildMode and Color3.fromRGB(255, 187, 81) or Color3.fromRGB(102, 236, 190)
    highlight.OutlineColor = buildMode and Color3.fromRGB(255, 231, 153) or Color3.fromRGB(143, 255, 218)
    highlight.Parent = workspace
    currentHighlight = highlight
end

local function action()
    local target = validTarget(mouse.Target)
    if not target then return end
    local now = time()
    if now - lastAction < ACTION_INTERVAL then return end
    lastAction = now

    if buildMode then
        if targetIsBuildable(target) then
            placeRequest:FireServer(target, mouse.TargetSurface, buildTypes[selectedIndex])
        end
    elseif targetIsHarvestable(target) then
        gatherRequest:FireServer(target)
    end
end

local function effect(position, color, hitOnly, placed)
    if not position then return end
    local anchor = Instance.new("Part")
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.CanTouch = false
    anchor.CanQuery = false
    anchor.Transparency = 1
    anchor.Size = Vector3.new(0.2, 0.2, 0.2)
    anchor.Position = position
    anchor.Parent = workspace

    local attachment = Instance.new("Attachment")
    attachment.Parent = anchor
    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    emitter.Color = ColorSequence.new(color or Color3.fromRGB(255, 255, 255))
    emitter.Lifetime = NumberRange.new(0.25, 0.6)
    emitter.Speed = NumberRange.new(4, placed and 9 or 13)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Rate = 0
    emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, placed and 0.35 or 0.55), NumberSequenceKeypoint.new(1, 0) })
    emitter.Parent = attachment
    emitter:Emit(hitOnly and 10 or 28)
    Debris:AddItem(anchor, 1)
end

harvestFX.OnClientEvent:Connect(effect)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.B then
        buildMode = not buildMode
        return
    end
    if keyToBuildIndex[input.KeyCode] then
        selectedIndex = keyToBuildIndex[input.KeyCode]
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        action()
    end
end)

RunService.RenderStepped:Connect(updateHighlight)

player.CharacterRemoving:Connect(function()
    if currentHighlight then currentHighlight:Destroy() end
end)

print("[LumenfallController] Recolección y construcción listas.")

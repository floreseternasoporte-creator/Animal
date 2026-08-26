--[=[
    MiningController.client.lua
    UBICACIÓN: StarterPlayer > StarterPlayerScripts

    Control local de excavación y construcción.
    El cliente sólo pide acciones: el servidor valida todo antes de aplicar cambios.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local remotesFolder = ReplicatedStorage:WaitForChild("MiningRemotes")
local mineBlockEvent = remotesFolder:WaitForChild("MineBlockRequest")
local blockHitEvent = remotesFolder:WaitForChild("BlockHit")
local blockBrokenEvent = remotesFolder:WaitForChild("BlockBroken")
local placeBlockEvent = remotesFolder:WaitForChild("PlaceBlockRequest")
local blockPlacedEvent = remotesFolder:WaitForChild("BlockPlaced")

local signalsFolder = ReplicatedStorage:WaitForChild("MiningLocalSignals")
local toggleBuildSignal = signalsFolder:WaitForChild("ToggleBuildMode")

local CLICK_MAX_DISTANCE = 18
local MINE_INTERVAL = 0.13
local lastMineAttempt = 0
local isMouseDown = false
local buildMode = false
local currentTarget = nil
local currentSurface = nil
local currentHighlight = nil
local camera = workspace.CurrentCamera
local toolMotor = nil
local toolHead = nil
local toolSwinging = false
local baseCameraCFrame = nil

local function getCharacter()
    return player.Character or player.CharacterAdded:Wait()
end

-- ======= HERRAMIENTA Y ANIMACIÓN PROCEDURAL =======
local function ensureToolVisual()
    local character = player.Character
    if not character then return end
    local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
    if not hand then return end

    local old = character:FindFirstChild("MiningToolVisual")
    if old and old:FindFirstChild("ToolMotor") and old:FindFirstChild("ToolHead") then
        toolMotor = old.ToolMotor
        toolHead = old.ToolHead
        return
    end
    if old then old:Destroy() end

    local model = Instance.new("Model")
    model.Name = "MiningToolVisual"
    model.Parent = character

    local handle = Instance.new("Part")
    handle.Name = "ToolHandle"
    handle.Size = Vector3.new(0.32, 2.8, 0.32)
    handle.Color = Color3.fromRGB(35, 45, 58)
    handle.Material = Enum.Material.Metal
    handle.CanCollide = false
    handle.CanTouch = false
    handle.CanQuery = false
    handle.Massless = true
    handle.Parent = model

    local head = Instance.new("Part")
    head.Name = "ToolHead"
    head.Size = Vector3.new(2.2, 0.32, 0.38)
    head.Color = Color3.fromRGB(93, 220, 255)
    head.Material = Enum.Material.Neon
    head.CanCollide = false
    head.CanTouch = false
    head.CanQuery = false
    head.Massless = true
    head.Parent = model

    local headWeld = Instance.new("WeldConstraint")
    headWeld.Part0 = handle
    headWeld.Part1 = head
    head.CFrame = handle.CFrame * CFrame.new(0, 1.2, 0)
    headWeld.Parent = handle

    local motor = Instance.new("Motor6D")
    motor.Name = "ToolMotor"
    motor.Part0 = hand
    motor.Part1 = handle
    motor.C0 = CFrame.new(0, -0.8, -0.5) * CFrame.Angles(math.rad(-66), math.rad(-15), math.rad(8))
    motor.Parent = model

    toolMotor = motor
    toolHead = head
end

local function playToolSwing()
    ensureToolVisual()
    if not toolMotor or toolSwinging then return end
    toolSwinging = true
    local resting = CFrame.new(0, -0.8, -0.5) * CFrame.Angles(math.rad(-66), math.rad(-15), math.rad(8))
    local strike = CFrame.new(0, -0.65, -0.65) * CFrame.Angles(math.rad(-125), math.rad(-28), math.rad(38))
    local out = TweenService:Create(toolMotor, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = strike })
    local back = TweenService:Create(toolMotor, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { C0 = resting })
    out:Play()
    out.Completed:Connect(function()
        back:Play()
        back.Completed:Connect(function()
            toolSwinging = false
        end)
    end)
end

local function setBuildVisual(enabled)
    ensureToolVisual()
    buildMode = enabled
    if toolHead then
        toolHead.Color = enabled and Color3.fromRGB(255, 190, 67) or Color3.fromRGB(93, 220, 255)
    end
    if currentHighlight then
        currentHighlight.FillColor = enabled and Color3.fromRGB(255, 190, 67) or Color3.fromRGB(73, 210, 255)
        currentHighlight.OutlineColor = enabled and Color3.fromRGB(255, 226, 126) or Color3.fromRGB(117, 242, 255)
    end
end

toggleBuildSignal.Event:Connect(function(enabled)
    setBuildVisual(enabled == true)
end)

-- ======= FEEDBACK VISUAL =======
local function cameraShake(amount)
    if not camera then return end
    local original = camera.CFrame
    local offset = CFrame.Angles(math.rad(math.random(-amount, amount) / 3), math.rad(math.random(-amount, amount) / 3), 0)
    camera.CFrame = original * offset
    task.delay(0.045, function()
        if camera then
            camera.CFrame = original
        end
    end)
end

local function playHitEffect(block)
    if not block then return end
    local position = block.Position
    local color = block.Color

    local anchor = Instance.new("Part")
    anchor.Name = "MiningHitFX"
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
    local particles = Instance.new("ParticleEmitter")
    particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    particles.Color = ColorSequence.new(color, Color3.fromRGB(255, 244, 193))
    particles.Lifetime = NumberRange.new(0.16, 0.36)
    particles.Rate = 0
    particles.Speed = NumberRange.new(5, 12)
    particles.SpreadAngle = Vector2.new(160, 160)
    particles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
    particles.Parent = attachment
    particles:Emit(14)
    Debris:AddItem(anchor, 0.9)

    if block.Parent then
        local originalSize = block.Size
        local originalCFrame = block.CFrame
        local squash = TweenService:Create(block, TweenInfo.new(0.045, Enum.EasingStyle.Quad), {
            Size = originalSize * 0.94,
            CFrame = originalCFrame * CFrame.Angles(0, 0, math.rad(2)),
        })
        squash:Play()
        squash.Completed:Connect(function()
            if block.Parent then
                TweenService:Create(block, TweenInfo.new(0.09, Enum.EasingStyle.Back), { Size = originalSize, CFrame = originalCFrame }):Play()
            end
        end)
    end
    cameraShake(3)
    playToolSwing()
end

local function playBreakEffect(block, layerName, points, rarity)
    if not block then return end
    local position = block.Position
    local color = block.Color
    local rarityName = tostring(rarity or "COMÚN")
    local rarityColors = {
        ["POCO COMÚN"] = Color3.fromRGB(97, 224, 150),
        ["RARA"] = Color3.fromRGB(102, 174, 255),
        ["ÉPICA"] = Color3.fromRGB(185, 115, 255),
        ["MÍTICA"] = Color3.fromRGB(255, 110, 220),
        ["LEGENDARIA"] = Color3.fromRGB(255, 119, 50),
        ["ANCIANA"] = Color3.fromRGB(255, 235, 132),
    }
    local rarityColor = rarityColors[rarityName] or color

    local part = Instance.new("Part")
    part.Name = "MiningBreakFX"
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Transparency = 1
    part.Size = Vector3.new(1, 1, 1)
    part.Position = position
    part.Parent = workspace

    local attachment = Instance.new("Attachment")
    attachment.Parent = part
    local particles = Instance.new("ParticleEmitter")
    particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    particles.Color = ColorSequence.new(color, Color3.fromRGB(255, 251, 210))
    particles.Lifetime = NumberRange.new(0.35, 0.85)
    particles.Rate = 0
    particles.Speed = NumberRange.new(10, 20)
    particles.SpreadAngle = Vector2.new(180, 180)
    particles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.65), NumberSequenceKeypoint.new(1, 0) })
    particles.Parent = attachment
    particles:Emit(rarityName == "COMÚN" and 32 or 54)

    if rarityName ~= "COMÚN" then
        local light = Instance.new("PointLight")
        light.Color = rarityColor
        light.Brightness = rarityName == "ANCIANA" and 7 or 3.5
        light.Range = rarityName == "ANCIANA" and 28 or 18
        light.Parent = part

        local ring = Instance.new("Part")
        ring.Name = "RareDiscoveryRing"
        ring.Shape = Enum.PartType.Cylinder
        ring.Anchored = true
        ring.CanCollide = false
        ring.CanTouch = false
        ring.CanQuery = false
        ring.Material = Enum.Material.Neon
        ring.Color = rarityColor
        ring.Transparency = 0.15
        ring.Size = Vector3.new(0.18, 1.2, 1.2)
        ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
        ring.Parent = workspace
        TweenService:Create(ring, TweenInfo.new(0.75, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = Vector3.new(0.18, rarityName == "ANCIANA" and 14 or 8, rarityName == "ANCIANA" and 14 or 8),
            Transparency = 1,
        }):Play()
        Debris:AddItem(ring, 0.9)
    end

    Debris:AddItem(part, 1.6)

    -- Sin texto flotante: el resultado se comunica únicamente por sonido y HUD compacto.
    TweenService:Create(part, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = position + Vector3.new(0, 3, 0) }):Play()
    cameraShake(5)
    playToolSwing()
end

-- ======= SELECCIÓN Y TARGET =======
local function getValidTarget()
    local target = mouse.Target
    if not target or not target:GetAttribute("IsMineable") then
        return nil
    end

    local character = player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    if (hrp.Position - target.Position).Magnitude > CLICK_MAX_DISTANCE then
        return nil
    end
    return target
end

local function updateHighlight(target)
    if target == currentTarget and currentHighlight then return end
    if currentHighlight then
        currentHighlight:Destroy()
        currentHighlight = nil
    end
    currentTarget = target
    currentSurface = target and mouse.TargetSurface or nil
    if not target then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "MiningSelection"
    highlight.Adornee = target
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = buildMode and Color3.fromRGB(255, 190, 67) or Color3.fromRGB(73, 210, 255)
    highlight.FillTransparency = 0.78
    highlight.OutlineColor = buildMode and Color3.fromRGB(255, 226, 126) or Color3.fromRGB(117, 242, 255)
    highlight.OutlineTransparency = 0.05
    highlight.Parent = workspace
    currentHighlight = highlight
end

local function tryAction()
    local target = getValidTarget()
    if not target then return end

    local now = time()
    if buildMode then
        if now - lastMineAttempt < 0.22 then return end
        lastMineAttempt = now
        placeBlockEvent:FireServer(target, mouse.TargetSurface)
        return
    end

    if now - lastMineAttempt < MINE_INTERVAL then return end
    lastMineAttempt = now
    playHitEffect(target)
    mineBlockEvent:FireServer(target)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isMouseDown = true
        tryAction()
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isMouseDown = false
    end
end)

RunService.RenderStepped:Connect(function()
    local target = getValidTarget()
    updateHighlight(target)
    if isMouseDown then
        tryAction()
    end
end)

player.CharacterAdded:Connect(function()
    task.wait(0.5)
    ensureToolVisual()
end)

blockHitEvent.OnClientEvent:Connect(function(block)
    playHitEffect(block)
end)

blockBrokenEvent.OnClientEvent:Connect(function(block, layerName, points, _, _, rarity)
    playBreakEffect(block, layerName, points, rarity)
end)

blockPlacedEvent.OnClientEvent:Connect(function(block)
    if not block then return end
    local original = block.Color
    block.Color = Color3.fromRGB(151, 244, 255)
    local pulse = TweenService:Create(block, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Color = original })
    pulse:Play()
end)

ensureToolVisual()
print("[MiningController] Excavación, construcción, selección y animaciones listas.")

--!strict
local Players = game:GetService('Players')
local Debris = game:GetService('Debris')
local TweenService = game:GetService('TweenService')

local Controller = {}

local function makeLeaf(parent: Instance, position: Vector3, direction: Vector3, distance: number)
    local leaf = Instance.new('Part')
    leaf.Name = 'GuidingWindLeaf'
    leaf.Size = Vector3.new(0.28,0.08,0.48)
    leaf.Material = Enum.Material.SmoothPlastic
    leaf.Color = Color3.fromRGB(144, 208, 123)
    leaf.CanCollide = false
    leaf.CanTouch = false
    leaf.CanQuery = false
    leaf.Anchored = true
    leaf.Transparency = 0.12
    leaf.CFrame = CFrame.lookAt(position, position + direction) * CFrame.Angles(0,0,math.rad(math.random(-40,40)))
    leaf.Parent = parent
    local target = position + direction * distance + Vector3.new(0, math.random(2,5), 0)
    local tween = TweenService:Create(leaf, TweenInfo.new(0.75 + math.random()*0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = target,
        Transparency = 1,
        Orientation = Vector3.new(math.random(-120,120), math.random(-180,180), math.random(-120,120)),
    })
    tween:Play()
    Debris:AddItem(leaf, 1.5)
end

function Controller:Play(payload)
    if type(payload) ~= 'table' then return end
    local direction = payload.Direction
    if typeof(direction) ~= 'Vector3' or direction.Magnitude < 0.05 then return end
    direction = direction.Unit
    local player = Players.LocalPlayer
    local char = player.Character
    local root = char and char:FindFirstChild('HumanoidRootPart')
    if not root or not root:IsA('BasePart') then return end

    local holder = workspace:FindFirstChild('NewLifeClientVFX') or Instance.new('Folder')
    holder.Name = 'NewLifeClientVFX'
    holder.Parent = workspace

    local duration = math.clamp(tonumber(payload.Duration) or 3, 1, 5)
    local strength = math.clamp(tonumber(payload.Strength) or 24, 8, 48)
    local count = math.clamp(math.floor(strength / 3), 8, 18)
    for i = 1, count do
        task.delay((i-1) * (duration / count) * 0.55, function()
            if not root.Parent then return end
            local side = root.CFrame.RightVector * math.random(-8,8)
            local forward = direction * math.random(2,9)
            local origin = root.Position + Vector3.new(0, math.random(1,4), 0) + side + forward
            makeLeaf(holder, origin, direction, math.random(10,18))
        end)
    end

    local attachment = Instance.new('Attachment')
    attachment.Name = 'GuidingWindBurst'
    attachment.Parent = root
    local emitter = Instance.new('ParticleEmitter')
    emitter.Name = 'WindMotes'
    emitter.Texture = 'rbxasset://textures/particles/sparkles_main.dds'
    emitter.Color = ColorSequence.new(Color3.fromRGB(196,235,184), Color3.fromRGB(228,246,220))
    emitter.LightEmission = 0.35
    emitter.Lifetime = NumberRange.new(0.5,1.0)
    emitter.Speed = NumberRange.new(5,10)
    emitter.Rate = 0
    emitter.SpreadAngle = Vector2.new(18,18)
    emitter.Drag = 2
    emitter.Acceleration = direction * 14 + Vector3.new(0,2,0)
    emitter.Parent = attachment
    emitter:Emit(math.clamp(count*2, 16, 34))
    Debris:AddItem(attachment, 1.5)
end

return Controller

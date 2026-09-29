--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GameConfig = require(ReplicatedStorage.NewLife.Shared.Config.GameConfig)
local player = Players.LocalPlayer

local LockOnController = { _started=false, _target=nil, _highlight=nil }

local function validTarget(model: Instance?): boolean
    if not model or not model:IsA("Model") or not model:IsDescendantOf(workspace) then return false end
    local hum=model:FindFirstChildOfClass("Humanoid")
    local root=model:FindFirstChild("HumanoidRootPart")
    return hum ~= nil and hum.Health>0 and root ~= nil and root:IsA("BasePart")
end

function LockOnController:_clearVisual()
    if self._highlight then self._highlight:Destroy(); self._highlight=nil end
end
function LockOnController:Clear()
    self:_clearVisual(); self._target=nil; player:SetAttribute("LockOnTargetName","")
end
function LockOnController:GetTarget(): Model?
    if validTarget(self._target) then return self._target end
    self:Clear(); return nil
end
function LockOnController:_nearest(): Model?
    local character=player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then return nil end
    local best: Model?=nil
    local bestDistance=GameConfig.Network.LockOnDistance
    for _,item in CollectionService:GetTagged("NL_Enemy") do
        if validTarget(item) then
            local targetRoot=item:FindFirstChild("HumanoidRootPart") :: BasePart
            local d=(targetRoot.Position-root.Position).Magnitude
            if d<bestDistance then best=item; bestDistance=d end
        end
    end
    return best
end
function LockOnController:Toggle(): Model?
    if self:GetTarget() then self:Clear(); return nil end
    local target=self:_nearest()
    if not target then self:Clear(); return nil end
    self._target=target
    local h=Instance.new("Highlight"); h.Name="NewLifeLockOn"; h.FillTransparency=0.82; h.OutlineTransparency=0; h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; h.Parent=target
    self._highlight=h
    player:SetAttribute("LockOnTargetName",target.Name)
    return target
end
function LockOnController:Start()
    if self._started then return end
    self._started=true; player:SetAttribute("LockOnTargetName","")
    RunService.RenderStepped:Connect(function()
        local target=self._target
        if not target then return end
        local character=player.Character
        local root=character and character:FindFirstChild("HumanoidRootPart")
        local targetRoot=target:FindFirstChild("HumanoidRootPart")
        if not root or not targetRoot or not root:IsA("BasePart") or not targetRoot:IsA("BasePart") or (targetRoot.Position-root.Position).Magnitude>GameConfig.Network.LockOnDistance or not validTarget(target) then self:Clear() end
    end)
end
return LockOnController

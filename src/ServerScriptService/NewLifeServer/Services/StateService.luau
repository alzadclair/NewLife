--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateDefinitions = require(ReplicatedStorage.NewLife.Shared.Modules.StateDefinitions)

local StateService = {}

function StateService:SetState(instance: Instance, stateName: string, enabled: boolean): boolean
    if StateDefinitions.Allowed[stateName] ~= true then
        return false
    end
    local attributeName = StateDefinitions.AttributeName(stateName)
    local tagName = StateDefinitions.TagName(stateName)
    instance:SetAttribute(attributeName, enabled)
    if enabled then
        if not CollectionService:HasTag(instance, tagName) then
            CollectionService:AddTag(instance, tagName)
        end
    elseif CollectionService:HasTag(instance, tagName) then
        CollectionService:RemoveTag(instance, tagName)
    end
    return true
end

function StateService:IsInState(instance: Instance?, stateName: string): boolean
    if not instance or StateDefinitions.Allowed[stateName] ~= true then
        return false
    end
    return instance:GetAttribute(StateDefinitions.AttributeName(stateName)) == true
end

function StateService:ClearTransient(instance: Instance)
    for stateName in StateDefinitions.Transient do
        self:SetState(instance, stateName, false)
    end
end

return StateService

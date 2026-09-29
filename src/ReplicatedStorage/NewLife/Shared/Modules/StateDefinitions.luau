--!strict
local StateDefinitions = {
    TagPrefix = "NL_State_",
    Allowed = {
        Alive = true,
        Attacking = true,
        Blocking = true,
        Sprinting = true,
        Stunned = true,
        Dead = true,
        Dodging = true,
        Dashing = true,
        Parrying = true,
    },
    Transient = {
        Attacking = true,
        Blocking = true,
        Sprinting = true,
        Stunned = true,
        Dodging = true,
        Dashing = true,
        Parrying = true,
    },
}
function StateDefinitions.AttributeName(stateName: string): string
    return "State_" .. stateName
end
function StateDefinitions.TagName(stateName: string): string
    return StateDefinitions.TagPrefix .. stateName
end
return table.freeze(StateDefinitions)

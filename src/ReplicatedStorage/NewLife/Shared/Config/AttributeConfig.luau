--!strict

local AttributeConfig = {
    Defaults = {
        Health = 100,
        Mana = 100,
        Stamina = 100,
        Strength = 10,
        Defense = 5,
        Power = 10,
    },

    Limits = {
        Health = { Min = 1, Max = 100000 },
        Mana = { Min = 0, Max = 100000 },
        Stamina = { Min = 0, Max = 100000 },
        Strength = { Min = 0, Max = 100000 },
        Defense = { Min = 0, Max = 100000 },
        Power = { Min = 0, Max = 100000 },
    },

    Persistent = {
        "Health",
        "Mana",
        "Stamina",
        "Strength",
        "Defense",
        "Power",
    },
}

for _, value in AttributeConfig.Limits do
    table.freeze(value)
end

table.freeze(AttributeConfig.Defaults)
table.freeze(AttributeConfig.Limits)
table.freeze(AttributeConfig.Persistent)
table.freeze(AttributeConfig)

return AttributeConfig

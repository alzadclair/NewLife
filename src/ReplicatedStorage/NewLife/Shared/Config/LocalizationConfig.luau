--!strict

local LocalizationConfig = {
    DefaultLocale = "pt-br",
    FallbackLocale = "en-us",

    Strings = {
        ["pt-br"] = {
            ["hud.title"] = "NEW LIFE  •  FUNDAÇÃO",
            ["hud.foundationOnline"] = "Fundação online",
            ["race.human"] = "Humano",
            ["class.adventurer"] = "Aventureiro",
            ["system.ready"] = "Sistema pronto",
        },
        ["en-us"] = {
            ["hud.title"] = "NEW LIFE  •  FOUNDATION",
            ["hud.foundationOnline"] = "Foundation online",
            ["race.human"] = "Human",
            ["class.adventurer"] = "Adventurer",
            ["system.ready"] = "System ready",
        },
    },
}

function LocalizationConfig.Translate(localeId: string?, key: string): string
    local locale = string.lower(localeId or LocalizationConfig.DefaultLocale)
    local bucket = LocalizationConfig.Strings[locale]
        or LocalizationConfig.Strings[LocalizationConfig.FallbackLocale]
    return bucket[key]
        or LocalizationConfig.Strings[LocalizationConfig.FallbackLocale][key]
        or key
end

return LocalizationConfig

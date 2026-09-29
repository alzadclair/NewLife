--!strict
local services = script.Parent:WaitForChild("Services")
local StateService = require(services:WaitForChild("StateService"))
local PlayerDataService = require(services:WaitForChild("PlayerDataService"))
local CharacterService = require(services:WaitForChild("CharacterService"))
local CombatService = require(services:WaitForChild("CombatService"))
local NetworkService = require(services:WaitForChild("NetworkService"))
local EnemyService = require(services:WaitForChild("EnemyService"))
PlayerDataService:Start()
CharacterService:Start(PlayerDataService, StateService)
CombatService:Start(StateService, CharacterService)
NetworkService:Start(PlayerDataService, StateService, CharacterService, CombatService)
EnemyService:Start(StateService, CombatService)
print("[NewLife] FASE 1 server core gameplay online")

return true
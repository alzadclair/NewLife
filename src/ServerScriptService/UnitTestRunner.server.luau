--!strict
-- UnitTestRunner: Disabled by default. Enable to auto-run Phase 10 unit tests on server start.
local RunService = game:GetService('RunService')

if not RunService:IsStudio() then return end

-- This script is disabled by default. Enable it to auto-run tests.
-- Otherwise, tests are run via execute_luau in play mode.
if not script.Enabled then return end

task.wait(3) -- Wait for services to initialize

local ok, err = pcall(function()
    local RunUnitTest = require(game.ServerStorage.UnitTest.RunUnitTest)
    RunUnitTest.Run(nil, 30)
end)

if not ok then
    warn('[UnitTestRunner] Error: ' .. tostring(err))
end
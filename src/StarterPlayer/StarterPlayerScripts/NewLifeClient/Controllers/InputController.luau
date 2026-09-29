--!strict
local ContextActionService=game:GetService('ContextActionService')
local Players=game:GetService('Players')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local NetProtocol=require(ReplicatedStorage.NewLife.Shared.Modules.NetProtocol)
local GameConfig=require(ReplicatedStorage.NewLife.Shared.Config.GameConfig)
local InputController={_started=false,_mouse=nil,_lockOn=nil}
local function mouseTarget(self) if self._lockOn then local l=self._lockOn:GetTarget(); if l then return l end end local t=self._mouse and self._mouse.Target; if not t then return nil end local m=t:FindFirstAncestorOfClass('Model'); if m and m:FindFirstChildOfClass('Humanoid') then return m end return nil end
local function moveDirection(player) local c=player.Character; if not c then return Vector3.zero end local h=c:FindFirstChildOfClass('Humanoid'); local r=c:FindFirstChild('HumanoidRootPart'); if h and h.MoveDirection.Magnitude>0.05 then return h.MoveDirection end; if r and r:IsA('BasePart') then return r.CFrame.LookVector end; return Vector3.zero end
function InputController:Start(lockOn)
 if self._started then return end; self._started=true; self._lockOn=lockOn
 local player=Players.LocalPlayer; if not player then self._started=false; return end; self._mouse=player:GetMouse()
 local remote=ReplicatedStorage.NewLife.Remotes:WaitForChild(NetProtocol.Remotes.ActionRequest)
 local function attack(a) remote:FireServer(a,{Target=mouseTarget(self)}) end
 ContextActionService:BindAction('NewLife_LightAttack',function(_,s) if s==Enum.UserInputState.Begin then attack(NetProtocol.Actions.LightAttack) end return Enum.ContextActionResult.Pass end,false,Enum.UserInputType.MouseButton1,Enum.KeyCode.ButtonR2)
 ContextActionService:BindAction('NewLife_HeavyAttack',function(_,s) if s==Enum.UserInputState.Begin then attack(NetProtocol.Actions.HeavyAttack) end return Enum.ContextActionResult.Pass end,false,Enum.UserInputType.MouseButton2,Enum.KeyCode.ButtonR1)
 ContextActionService:BindAction('NewLife_Dodge',function(_,s) if s==Enum.UserInputState.Begin then remote:FireServer(NetProtocol.Actions.Dodge,{Direction=moveDirection(player)}) end return Enum.ContextActionResult.Pass end,false,Enum.KeyCode.Q,Enum.KeyCode.ButtonB)
 ContextActionService:BindAction('NewLife_Dash',function(_,s) if s==Enum.UserInputState.Begin then remote:FireServer(NetProtocol.Actions.Dash,{Direction=moveDirection(player)}) end return Enum.ContextActionResult.Pass end,false,Enum.KeyCode.E,Enum.KeyCode.ButtonX)
 ContextActionService:BindAction('NewLife_Block',function(_,s) if s==Enum.UserInputState.Begin then remote:FireServer(NetProtocol.Actions.Block,true) elseif s==Enum.UserInputState.End or s==Enum.UserInputState.Cancel then remote:FireServer(NetProtocol.Actions.Block,false) end return Enum.ContextActionResult.Pass end,false,Enum.KeyCode.F,Enum.KeyCode.ButtonL2)
 ContextActionService:BindAction('NewLife_Parry',function(_,s) if s==Enum.UserInputState.Begin then remote:FireServer(NetProtocol.Actions.Parry,{}) end return Enum.ContextActionResult.Pass end,false,Enum.KeyCode.R,Enum.KeyCode.ButtonL1)
 ContextActionService:BindAction('NewLife_Sprint',function(_,s) if s==Enum.UserInputState.Begin then remote:FireServer(NetProtocol.Actions.Sprint,true) elseif s==Enum.UserInputState.End or s==Enum.UserInputState.Cancel then remote:FireServer(NetProtocol.Actions.Sprint,false) end return Enum.ContextActionResult.Pass end,false,Enum.KeyCode.LeftShift,Enum.KeyCode.ButtonL3)
 ContextActionService:BindAction('NewLife_LockOn',function(_,s) if s==Enum.UserInputState.Begin and self._lockOn then self._lockOn:Toggle() end return Enum.ContextActionResult.Pass end,false,Enum.KeyCode.T,Enum.KeyCode.ButtonY)
 ContextActionService:BindAction('NewLife_Interact',function(_,s) if s==Enum.UserInputState.Begin then remote:FireServer(NetProtocol.Actions.Interact,{}) end return Enum.ContextActionResult.Pass end,false,Enum.KeyCode.G)
 ContextActionService:BindAction('NewLife_RacialSkill',function(_,st) if st==Enum.UserInputState.Begin then remote:FireServer(NetProtocol.Actions.UseSkill,{SkillId='Evolution',Target=mouseTarget(self)}) end return Enum.ContextActionResult.Pass end,false,Enum.KeyCode.H)
 ContextActionService:BindAction('NewLife_ClassSkill',function(_,st) if st==Enum.UserInputState.Begin then remote:FireServer(NetProtocol.Actions.UseSkill,{SkillId='AdventurerStrike',Target=mouseTarget(self)}) end return Enum.ContextActionResult.Pass end,false,Enum.KeyCode.Z)
 ContextActionService:BindAction('NewLife_Magic1',function(_,st) if st==Enum.UserInputState.Begin then remote:FireServer(NetProtocol.Actions.CastMagic,{MagicId='ArcBolt',Target=mouseTarget(self)}) end return Enum.ContextActionResult.Pass end,false,Enum.KeyCode.X)
 ContextActionService:BindAction('NewLife_Magic2',function(_,st) if st==Enum.UserInputState.Begin then remote:FireServer(NetProtocol.Actions.CastMagic,{MagicId='EmberBurst',Target=mouseTarget(self)}) end return Enum.ContextActionResult.Pass end,false,Enum.KeyCode.C)
 local windKey=Enum.KeyCode[GameConfig.World.GuidingWindInputKey] or Enum.KeyCode.V
 ContextActionService:BindAction('NewLife_GuidingWind',function(_,st) if st==Enum.UserInputState.Begin then remote:FireServer(NetProtocol.Actions.GuidingWind,{}) end return Enum.ContextActionResult.Sink end,false,windKey,Enum.KeyCode.DPadUp)
end
return InputController
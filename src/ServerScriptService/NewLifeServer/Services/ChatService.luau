--!strict
local Players=game:GetService('Players')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local TextService=game:GetService('TextService')
local RunService=game:GetService('RunService')
local GameConfig=require(ReplicatedStorage.NewLife.Shared.Config.GameConfig)
local NetProtocol=require(ReplicatedStorage.NewLife.Shared.Modules.NetProtocol)

local Service={_started=false,_data=nil,_party=nil,_guild=nil}

local function trim(s:string):string return string.gsub(s,'^%s*(.-)%s*$','%1') end

function Service:_remote():RemoteEvent?
 local r=ReplicatedStorage.NewLife.Remotes:FindFirstChild(NetProtocol.Remotes.ChatMessage)
 return r and r:IsA('RemoteEvent') and r or nil
end

function Service:_filter(player:Player,text:string):string?
 if RunService:IsStudio() then return text end
 local ok,result=pcall(function()
  local filtered=TextService:FilterStringAsync(text,player.UserId,Enum.TextFilterContext.PublicChat)
  return filtered:GetNonChatStringForBroadcastAsync()
 end)
 if ok and type(result)=='string' then return result end
 return nil
end

function Service:_recipients(player:Player,channel:string):{Player}
 if channel=='Party' and self._party then return self._party:GetPartyMembers(player) end
 if channel=='Guild' and self._guild then return self._guild:GetOnlineGuildMembers(player) end
 local out={}
 if channel=='Local' then
  local root=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
  if not root or not root:IsA('BasePart') then return out end
  for _,p in Players:GetPlayers() do
   local pr=p.Character and p.Character:FindFirstChild('HumanoidRootPart')
   if pr and pr:IsA('BasePart') and (pr.Position-root.Position).Magnitude<=GameConfig.Chat.LocalRange then table.insert(out,p) end
  end
  return out
 end
 return Players:GetPlayers()
end

function Service:Send(player:Player,payload:any):(boolean,string)
 if type(payload)~='table' or type(payload.Text)~='string' then return false,'InvalidMessage' end
 local channel=type(payload.Channel)=='string' and payload.Channel or 'Local'
 if channel~='Local' and channel~='Party' and channel~='Guild' and channel~='Global' then return false,'InvalidChannel' end
 local text=trim(string.sub(payload.Text,1,GameConfig.Chat.MaxLength))
 if text=='' then return false,'EmptyMessage' end
 if channel=='Party' and (not self._party or not self._party:GetPartyForPlayer(player)) then return false,'NotInParty' end
 if channel=='Guild' and (not self._guild or not self._guild:GetGuildForPlayer(player)) then return false,'NotInGuild' end
 local filtered=self:_filter(player,text)
 if not filtered then return false,'FilterFailed' end
 local remote=self:_remote(); if not remote then return false,'RemoteMissing' end
 local packet={Channel=channel,FromUserId=player.UserId,FromName=player.Name,Text=filtered,Timestamp=os.time()}
 for _,recipient in self:_recipients(player,channel) do
  if recipient==player or (not self._data:IsBlocked(recipient,player.UserId) and not self._data:IsMuted(recipient,player.UserId)) then remote:FireClient(recipient,packet) end
 end
 return true,'OK'
end

function Service:Start(dataService,partyService,guildService)
 if self._started then return end
 self._started=true; self._data=dataService; self._party=partyService; self._guild=guildService
end
return Service

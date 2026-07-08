--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local NetworkConfig=require(ReplicatedStorage.VTR.Shared.NetworkConfig)
local base=require(script.Parent.ServiceClient).create("UIState")
local UISoundService=require(script.Parent.UISoundService)
local remote=ReplicatedStorage.VTR:WaitForChild(NetworkConfig.FolderName):WaitForChild(NetworkConfig.UIStateEvent)::RemoteEvent
local Service={}
function Service:Get() return base:Get() end
function Service:Observe(callback:(any)->()) return base:Observe(callback) end
function Service:SetLastPage(page:string) remote:FireServer({Type="LastPage",Page=page}) end
function Service:SetTab(mode:string,tab:string) remote:FireServer({Type="Tab",Mode=mode,Tab=tab}) end
function Service:SetSetting(key:string,value:any)
	if string.find(string.lower(tostring(key)), "color") or string.find(string.lower(tostring(key)), "kit") then
		UISoundService.PlayColor()
	end
	remote:FireServer({Type="Setting",Key=key,Value=value})
end
function Service:SetTutorialProgress(step:number,device:string,complete:boolean)
	remote:FireServer({Type="TutorialProgress",Step=step,Device=device,Complete=complete})
end
function Service:SetSquad(slot:string,card:string?) remote:FireServer({Type="Squad",Slot=slot,Card=card}) end
function Service:SetCosmetic(slot:string,item:string) UISoundService.PlayColor();remote:FireServer({Type="Cosmetic",Slot=slot,Item=item}) end
function Service:ClearCosmetic(slot:string) UISoundService.PlayColor();remote:FireServer({Type="CosmeticClear",Slot=slot}) end
function Service:SetCustomGoalMusic(soundId:string,startSecond:number) UISoundService.PlayColor();remote:FireServer({Type="CustomGoalMusic",SoundId=soundId,StartSecond=startSecond}) end
function Service:SelectCareerSave(slot:number) remote:FireServer({Type="CareerSave",Slot=slot}) end
return Service

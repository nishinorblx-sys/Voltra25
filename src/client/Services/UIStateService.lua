--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local NetworkConfig=require(ReplicatedStorage.VTR.Shared.NetworkConfig)
local base=require(script.Parent.ServiceClient).create("UIState")
local remote=ReplicatedStorage.VTR:WaitForChild(NetworkConfig.FolderName):WaitForChild(NetworkConfig.UIStateEvent)::RemoteEvent
local Service={}
function Service:Get() return base:Get() end
function Service:Observe(callback:(any)->()) return base:Observe(callback) end
function Service:SetLastPage(page:string) remote:FireServer({Type="LastPage",Page=page}) end
function Service:SetTab(mode:string,tab:string) remote:FireServer({Type="Tab",Mode=mode,Tab=tab}) end
function Service:SetSetting(key:string,value:any) remote:FireServer({Type="Setting",Key=key,Value=value}) end
function Service:SetSquad(slot:string,card:string?) remote:FireServer({Type="Squad",Slot=slot,Card=card}) end
function Service:SetCosmetic(slot:string,item:string) remote:FireServer({Type="Cosmetic",Slot=slot,Item=item}) end
function Service:SelectCareerSave(slot:number) remote:FireServer({Type="CareerSave",Slot=slot}) end
return Service

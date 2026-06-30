--!strict
local Generator=require(script.Parent.AvatarPortraitGenerator)
local Service={}
function Service.new(parent:Instance,playerData:any,size:UDim2?,circular:boolean?):ViewportFrame return Generator.new(parent,playerData,size,circular)end
return Service

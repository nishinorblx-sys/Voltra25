--!strict
local PlayerPortraitService=require(script.Parent.Parent.Services.PlayerPortraitService)
local Component={}
function Component.new(props:any):ViewportFrame return PlayerPortraitService.new(props.Parent,props.Player,props.Size,props.Circular)end
return Component

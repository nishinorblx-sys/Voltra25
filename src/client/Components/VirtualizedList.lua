--!strict
local RunService=game:GetService("RunService")
local VirtualizedList={}

function VirtualizedList.new(parent:Instance,props:any):ScrollingFrame
	local rowHeight=props.RowHeight or 120
	local gap=props.Gap or 9
	local stride=rowHeight+gap
	local buffer=props.Buffer or 9
	local items=props.Items or{}
	local canvasHeight=math.max(0,#items*stride-gap)
	local scroll=Instance.new("ScrollingFrame")
	scroll.Name="VirtualizedList"
	scroll.BackgroundTransparency=1
	scroll.BorderSizePixel=0
	scroll.ClipsDescendants=true
	scroll.Position=props.Position or UDim2.new()
	scroll.Size=props.Size or UDim2.fromScale(1,1)
	scroll.AutomaticCanvasSize=Enum.AutomaticSize.None
	scroll.CanvasSize=UDim2.fromOffset(0,canvasHeight)
	scroll.ScrollBarThickness=3
	scroll.ScrollBarImageColor3=Color3.fromHex("FFFFFF")
	scroll.ScrollingDirection=Enum.ScrollingDirection.Y
	scroll.Parent=parent

	local rendered:{[number]:GuiObject}={}
	local queued=false
	local lastTop=-1
	local lastHeight=-1

	local function update()
		queued=false
		if not scroll.Parent then return end
		local top=math.max(0,scroll.CanvasPosition.Y)
		local height=math.max(1,scroll.AbsoluteWindowSize.Y>1 and scroll.AbsoluteWindowSize.Y or scroll.AbsoluteSize.Y)
		if math.abs(top-lastTop)<.5 and math.abs(height-lastHeight)<.5 then return end
		lastTop=top
		lastHeight=height
		local first=math.max(1,math.floor(top/stride)+1-buffer)
		local last=math.min(#items,math.ceil((top+height)/stride)+buffer)
		for index,node in rendered do
			if index<first or index>last then
				node:Destroy()
				rendered[index]=nil
			end
		end
		for index=first,last do
			if not rendered[index] then
				local node=props.RenderItem(scroll,items[index],index)
				node.AnchorPoint=Vector2.zero
				node.Position=UDim2.fromOffset(0,(index-1)*stride)
				node.Size=UDim2.new(1,-8,0,rowHeight)
				node.LayoutOrder=index
				rendered[index]=node
			end
		end
	end

	local function request()
		if queued then return end
		queued=true
		task.defer(update)
	end

	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(request)
	scroll:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(request)
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(request)
	scroll.AncestryChanged:Connect(function(_,parentNow)
		if not parentNow then
			for _,node in rendered do node:Destroy()end
			table.clear(rendered)
		end
	end)
	local heartbeatConnection
	heartbeatConnection=RunService.Heartbeat:Connect(function()
		if not scroll.Parent then heartbeatConnection:Disconnect();return end
		if scroll.Visible then request()end
	end)
	request()
	return scroll
end

return VirtualizedList

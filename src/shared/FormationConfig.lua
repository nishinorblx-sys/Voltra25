--!strict

local function slot(x:number,y:number,label:string,expected:string):any return {X=x,Y=y,Label=label,Expected=expected} end

return {
	Order={"GK","LB","CB1","CB2","RB","CDM","CM1","CM2","LW","ST","RW"},
	Default="4-3-3",
	Formations={
		["4-3-3"]={GK=slot(.50,.88,"GK","GK"),LB=slot(.18,.70,"LB","LB"),CB1=slot(.38,.70,"CB","CB"),CB2=slot(.62,.70,"CB","CB"),RB=slot(.82,.70,"RB","RB"),CM1=slot(.32,.48,"CM","CM"),CDM=slot(.50,.56,"CDM","CDM"),CM2=slot(.68,.48,"CM","CM"),LW=slot(.18,.25,"LW","LW"),ST=slot(.50,.18,"ST","ST"),RW=slot(.82,.25,"RW","RW")},
		["4-4-2"]={GK=slot(.50,.88,"GK","GK"),LB=slot(.18,.70,"LB","LB"),CB1=slot(.38,.70,"CB","CB"),CB2=slot(.62,.70,"CB","CB"),RB=slot(.82,.70,"RB","RB"),CM1=slot(.38,.49,"CM","CM"),CDM=slot(.62,.49,"CM","CM"),CM2=slot(.62,.24,"ST","ST"),LW=slot(.16,.46,"LM","LW"),ST=slot(.38,.24,"ST","ST"),RW=slot(.84,.46,"RM","RW")},
		["4-2-3-1"]={GK=slot(.50,.88,"GK","GK"),LB=slot(.18,.70,"LB","LB"),CB1=slot(.38,.70,"CB","CB"),CB2=slot(.62,.70,"CB","CB"),RB=slot(.82,.70,"RB","RB"),CM1=slot(.38,.54,"CDM","CDM"),CM2=slot(.62,.54,"CDM","CDM"),CDM=slot(.50,.38,"CAM","CAM"),LW=slot(.20,.35,"LAM","LW"),ST=slot(.50,.18,"ST","ST"),RW=slot(.80,.35,"RAM","RW")},
		["3-5-2"]={GK=slot(.50,.88,"GK","GK"),LB=slot(.28,.70,"CB","CB"),CB1=slot(.50,.73,"CB","CB"),CB2=slot(.72,.70,"CB","CB"),RB=slot(.86,.48,"RM","RW"),CM1=slot(.37,.50,"CM","CM"),CDM=slot(.50,.58,"CDM","CDM"),CM2=slot(.63,.50,"CM","CM"),LW=slot(.14,.48,"LM","LW"),ST=slot(.39,.22,"ST","ST"),RW=slot(.61,.22,"ST","ST")},
		["5-3-2"]={GK=slot(.50,.88,"GK","GK"),LB=slot(.12,.62,"LWB","LB"),CB1=slot(.34,.70,"CB","CB"),CDM=slot(.50,.74,"CB","CB"),CB2=slot(.66,.70,"CB","CB"),RB=slot(.88,.62,"RWB","RB"),CM1=slot(.35,.45,"CM","CM"),CM2=slot(.65,.45,"CM","CM"),LW=slot(.50,.50,"CAM","CAM"),ST=slot(.39,.22,"ST","ST"),RW=slot(.61,.22,"ST","ST")},
	}
}

--!strict

return table.freeze({
	Pages = table.freeze({ Home=true, UltimateTeam=true, Inventory=true, Play=true, Ranked=true, Clubs=true, Career=true, Store=true, Settings=true }),
	Tabs = table.freeze({
		UltimateTeam={Squad=true,Cards=true,Packs=true,Objectives=true,StorePacks=true,Club=true,Chemistry=true},
		Inventory={Packs=true,Players=true,Cosmetics=true,Kits=true,Stadiums=true,Consumables=true,History=true},
		Play={Quick=true,Private=true,Training=true,MatchSettings=true,TeamSelect=true,StadiumSelect=true,KitSelect=true,Ready=true},
		Ranked={Division=true,Rewards=true,History=true,Leaders=true,Season=true,Queue=true},
		Clubs={Start=true,Dashboard=true,Members=true,Roles=true,Fixtures=true,League=true,Trophies=true,Settings=true},
		Career={Choose=true,CreatePlayer=true,CreateManager=true,Dashboard=true,Calendar=true,Training=true,Contracts=true,Transfers=true,Stats=true,Saves=true},
		Store={Featured=true,Packs=true,Cosmetics=true,Stadium=true,Kits=true,Currency=true},
		Settings={Controls=true,Audio=true,Graphics=true,Camera=true,Accessibility=true,Account=true},
	}),
	Settings = table.freeze({ TimedFinishing="boolean",MenuMusic="boolean",MotionEffects="boolean",PerformanceMode="boolean",InvertY="boolean",HighContrast="boolean",ReducedMotion="boolean",Crossplay="boolean",ControlPreset="string",MasterVolume="string",Commentary="string",Graphics="string",CameraPreset="string",CameraShake="string",CameraZoomMode="string",BroadcastHeight="string",BroadcastZoom="string",CameraSpeed="string",CameraSide="string",PlayerNames="string",Trainer="string",PassReceiverAutoSwitch="string",ReceiverAssist="string",Minimap="string",MinimapOrientation="string",TextScale="string" }),
	SquadSlots = table.freeze({ GK=true,LB=true,CB1=true,CB2=true,RB=true,CDM=true,CM1=true,CM2=true,LW=true,ST=true,RW=true }),
	CosmeticSlots = table.freeze({ ActiveKit=true,Walkout=true,ClubKit=true,StadiumTheme=true,ProfileFrame=true,Crest=true }),
})

--!strict

return table.freeze({
	Pages = table.freeze({ Home=true, UltimateTeam=true, AILab=true, WorldCup=true, Inventory=true, Campaign=true, Play=true, Ranked=true, Clubs=true, Career=true, Store=true, Settings=true }),
	Tabs = table.freeze({
		UltimateTeam={Squad=true,Cards=true,Packs=true,Objectives=true,StorePacks=true,Club=true,Customize=true,Chemistry=true},
		AILab={Playstyles=true},
		Inventory={Packs=true,Players=true,Cosmetics=true,Kits=true,Stadiums=true,Consumables=true,History=true},
		Play={Quick=true,Private=true,Training=true,MatchSettings=true,TeamSelect=true,StadiumSelect=true,KitSelect=true,Ready=true},
		Ranked={Division=true,Rewards=true,History=true,Leaders=true,Season=true,Queue=true},
		Clubs={Start=true,Dashboard=true,Members=true,Roles=true,Fixtures=true,League=true,Trophies=true,Settings=true},
		Career={Choose=true,CreatePlayer=true,CreateManager=true,Dashboard=true,Calendar=true,Training=true,Contracts=true,Transfers=true,Stats=true,Saves=true},
		Store={Passes=true,Coins=true,VoltraPoints=true,Boosts=true,Packs=true,Kits=true,Boots=true,GoalEffects=true,Celebrations=true,Club=true},
		Settings={Controls=true,Audio=true,Camera=true,Accessibility=true,Account=true},
	}),
	Settings = table.freeze({ TimedFinishing="boolean",MenuMusic="boolean",MotionEffects="boolean",PerformanceMode="boolean",InvertY="boolean",HighContrast="boolean",ReducedMotion="boolean",Crossplay="boolean",ControlPreset="string",MasterVolume="number",Graphics="string",MatchFormat="string",CameraPreset="string",CameraShake="string",CameraZoomMode="string",BroadcastHeight="string",BroadcastZoom="string",CameraSpeed="string",CameraSide="string",PlayerNames="string",Trainer="string",ReceiverAssistMode="string",PassReceiverAutoSwitch="string",ManualPassAutoSwitch="string",MobileSprintMode="string",MobileControlHandedness="string",ImmersivePresentation="boolean",Minimap="string",MinimapOrientation="string",TextScale="string",PauseKey="string",SkipKey="string",TutorialComplete="boolean",TutorialStep="number",TutorialDevice="string" }),
	SquadSlots = table.freeze({ GK=true,LB=true,CB1=true,CB2=true,RB=true,CDM=true,CM1=true,CM2=true,LW=true,ST=true,RW=true }),
	CosmeticSlots = table.freeze({ ActiveKit=true,Walkout=true,Celebration=true,ClubKit=true,StadiumTheme=true,ProfileFrame=true,Crest=true,BootStyle=true,GoalEffect=true,GoalMusic=true,ClubBanner=true,Nameplate=true }),
})

--!strict
local Factory = require(script.Parent.MockModeService)

return Factory.new({
	Id="UltimateTeam", Kicker="VTR SQUAD HUB", Title="SQUAD HUB", Subtitle="Build, tune and express your elite squad.",
	Tabs={
		{Id="Squad",Label="SQUAD",Description="Starting XI • 4-2-1-3",Cards={
			{Title="VOLTAGE XI",Subtitle="OVERALL 89",Meta="CHEMISTRY 32 / 33",Accent=true,Action={Label="MANAGE SQUAD",Operation="Toast",Message="Squad management active."}},
			{Title="EMPTY CB SLOT",Subtitle="ADD A PLAYER",Meta="Chemistry link available",Empty=true,Action={Label="FIND PLAYER",TargetTab="Cards"}},
			{Title="EMPTY BENCH SLOT",Subtitle="7 / 9 SELECTED",Meta="Two substitutes required",Empty=true,Action={Label="ADD SUBSTITUTE",TargetTab="Cards"}},
		}},
		{Id="Cards",Label="PLAYER CARDS",Description="24 owned players",Cards={
			{Id="Volt92",Title="M. VOLT",Subtitle="92 ST • VTR ELITE",Meta="96 PAC  •  93 SHO",Accent=true,Detail="Elite striker with explosive acceleration and clinical finishing.",Action={Label="VIEW / EQUIP",Operation="EquipToggle",Item="M. VOLT",Slot="ST",Confirm=true}},
			{Id="Nova89",Title="NOVA",Subtitle="89 LW • VOLTRA FC",Meta="94 PAC  •  91 DRI",Detail="Direct winger built for isolated one-versus-one situations.",Action={Label="VIEW / EQUIP",Operation="EquipToggle",Item="NOVA",Slot="LW",Confirm=true}},
			{Id="Kade88",Title="KADE",Subtitle="88 CB • ZERO XI",Meta="91 DEF  •  89 PHY",Detail="Front-foot centre-back with elite recovery pace.",Action={Label="VIEW / EQUIP",Operation="EquipToggle",Item="KADE",Slot="CB",Confirm=true}},
		}},
		{Id="Packs",Label="PACKS",Description="Unopened inventory",Cards={{Title="ELITE ELECTRUM PACK",Subtitle="12 ITEMS • 6 RARE",Meta="1 pack available",Accent=true,Action={Label="OPEN PACK",Operation="ComingSoon",Message="Pack opening animation queued. Player reveals connect here later.",Loading=true}},{Title="NO MORE PACKS",Subtitle="YOUR INVENTORY IS CLEAR",Meta="Earn packs through objectives",Empty=true,Action={Label="VIEW OBJECTIVES",TargetTab="Objectives"}}}},
		{Id="Objectives",Label="OBJECTIVES",Description="Season progression",Cards={{Title="SQUAD ARCHITECT",Subtitle="BUILD 3 CHEMISTRY LINKS",Meta="2 / 3 • +750 XP",Action={Label="TRACK OBJECTIVE",Operation="Toast",Message="Objective pinned to Home."}},{Title="RIVALS READY",Subtitle="REACH 88 TEAM OVERALL",Meta="COMPLETE • PLAYER PICK",Accent=true,Action={Label="CLAIM REWARD",Operation="Claim",Item="88+ Player Pick",Confirm=true}}}},
		{Id="StorePacks",Label="STORE PACKS",Description="Curated pack offers",Cards={{Title="VOLTAGE PRIME",Subtitle="24 GOLD ITEMS",Meta="◈ 25,000",Accent=true,Action={Label="PREVIEW PACK",Operation="ComingSoon",Message="Pack purchase preview opened."}},{Title="DAILY SILVER",Subtitle="6 ITEMS",Meta="FREE IN 04:12:33",Action={Label="VIEW CONTENTS",Operation="Toast",Message="Pack contains six silver player items."}}}},
		{Id="Club",Label="CLUB CUSTOM",Description="Identity and presentation",Cards={{Title="HOME KIT",Subtitle="VOLTAGE BLACK",Meta="EQUIPPED",Action={Label="CHANGE KIT",Operation="Select",Key="ClubKit",Item="Voltage Black"}},{Title="CREST",Subtitle="ELECTRIC V",Meta="LEVEL 4",Action={Label="CUSTOMIZE",Operation="ComingSoon",Message="Crest editor placeholder opened."}},{Title="STADIUM THEME",Subtitle="AFTERDARK",Meta="OWNED",Action={Label="EQUIP THEME",Operation="Select",Key="StadiumTheme",Item="Afterdark"}}}},
		{Id="Chemistry",Label="CHEMISTRY",Description="Squad links and rating",Cards={{Title="32 / 33",Subtitle="SQUAD CHEMISTRY",Meta="+1 needed for maximum boost",Accent=true,Action={Label="VIEW LINKS",Operation="Toast",Message="Strong links: ST–CAM, LW–LB, CB–GK."}},{Title="89",Subtitle="TEAM OVERALL",Meta="ATT 91 • MID 88 • DEF 87",Action={Label="RATING BREAKDOWN",Operation="Toast",Message="Overall is calculated from the active starting XI."}}}},
	}
})

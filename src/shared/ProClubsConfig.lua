--!strict
return table.freeze({
	MaximumLevel=100,StartingOverall=60,MaximumOverall=99,StartingAttributePoints=20,AttributePointsPerLevel=2,PerkEveryLevels=5,
	Categories=table.freeze({
		Pace={"Acceleration","SprintSpeed","Agility","Balance"},Shooting={"Finishing","ShotPower","LongShots","Volleys","Penalties","Curve"},Passing={"Vision","ShortPassing","LongPassing","Crossing","FreeKickAccuracy"},Dribbling={"BallControl","Dribbling","FirstTouch","Composure","Reactions"},Defending={"DefensiveAwareness","StandingTackle","SlidingTackle","Interceptions","Marking"},Physical={"Strength","Stamina","Jumping","Aggression","HeadingAccuracy"},Goalkeeping={"Diving","Handling","Reflexes","Positioning","Kicking"},
	}),
	Milestones=table.freeze({[20]="BUILD_PATH",[35]="PLAYSTYLE_SLOT_1",[50]="PLAYSTYLE_SLOT_2",[75]="SIGNATURE_ABILITY",[100]="PRESTIGE"}),
	BuildPaths=table.freeze({"Poacher","Target Man","Pressing Forward","False 9","Inside Forward","Traditional Winger","Creative Winger","Deep Playmaker","Box To Box","Advanced Playmaker","Ball Winning Midfielder","Stopper","Sweeper","Ball Playing Defender","Attacking Fullback","Defensive Fullback","Inverted Fullback","Shot Stopper","Sweeper Keeper","Commanding Keeper"}),
	Perks=table.freeze({"Engine","Deadeye","Playmaker","Interceptor","Bruiser","Rapid","Whipped Pass","Aerial Threat","Long Throw","Captain"}),
	Playstyles=table.freeze({"Power Shot","Technical Dribbler","Rapid","Long Ball Pass","Whipped Pass","Pinged Pass","Anticipate","Intercept","Relentless","Quick Step","Acrobatic","Trivela","Finesse Shot","First Touch","Press Proven"}),
})

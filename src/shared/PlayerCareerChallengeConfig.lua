--!strict

local Config = {}

Config.Categories = table.freeze({"Technical","Tactical","Defensive","Creative","Physical","Goalkeeping","Leadership","Discipline","Comeback","Game Management"})
Config.Challenges = table.freeze({
	progressive_passes={Name="Progressive Rhythm",Category="Creative",Positions={"CDM","CM","CAM","LM","RM","LW","RW"},Target=3},
	defensive_duels={Name="Middle-Third Duel Work",Category="Defensive",Positions={"CB","LB","RB","LWB","RWB","CDM","CM"},Target=2},
	recovery_runs={Name="Recovery Runs",Category="Physical",Positions={"LB","RB","LWB","RWB","CM","LM","RM","LW","RW"},Target=2},
	box_entry_run={Name="Arrive In The Box",Category="Tactical",Positions={"CAM","LW","RW","CF","ST","LM","RM"},Target=1},
	keeper_distribution={Name="Clean Distribution",Category="Goalkeeping",Positions={"GK"},Target=3},
	protect_lead={Name="Protect The Phase",Category="Game Management",Positions={"GK","CB","LB","RB","CDM","CM","CAM","LW","RW","ST","CF","LM","RM","LWB","RWB"},Target=1},
})

return table.freeze(Config)

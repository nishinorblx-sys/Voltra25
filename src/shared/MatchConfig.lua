--!strict
return table.freeze({
	MatchLengths=table.freeze({3,4,6,8,10}),Difficulties=table.freeze({"Amateur","Semi Pro","Professional","World Class","Legendary"}),MatchTypes=table.freeze({"Quick Match","Friendly","Training Match","Objective Match"}),Weather=table.freeze({"Clear","Cloudy","Rain","Night"}),Times=table.freeze({"Day","Evening","Night"}),KitTypes=table.freeze({"Home","Away","Third"}),
	Stadiums=table.freeze({
		{Id="voltra_arena",Name="Voltra Arena",Capacity=68000,Surface="Hybrid Grass",WeatherSupport={"Clear","Cloudy","Rain","Night"}},
		{Id="neon_park",Name="Neon Park",Capacity=32000,Surface="Natural Grass",WeatherSupport={"Clear","Cloudy","Night"}},
		{Id="storm_grounds",Name="Storm Grounds",Capacity=47000,Surface="Hybrid Grass",WeatherSupport={"Clear","Cloudy","Rain","Night"}},
		{Id="apex_field",Name="Apex Field",Capacity=41000,Surface="Natural Grass",WeatherSupport={"Clear","Cloudy","Rain"}},
		{Id="metro_stadium",Name="Metro Stadium",Capacity=59000,Surface="Hybrid Grass",WeatherSupport={"Clear","Cloudy","Rain","Night"}},
		{Id="champions_dome",Name="Champions Dome",Capacity=82000,Surface="Retractable Hybrid",WeatherSupport={"Clear","Cloudy","Night"}},
	}),
})

--!strict
return table.freeze({
	MinimumSpacing = 8,
	ThrowIn = table.freeze({NearbyAttackers = 2, NearbyDefenders = 2, Radius = 25, MaxInside = 5}),
	GoalKick = table.freeze({Pressers = 3, Radius = 35, MaxInside = 6}),
	Corner = table.freeze({AttackersInBox = 5, DefendersInBox = 6, EdgePlayers = 2}),
})

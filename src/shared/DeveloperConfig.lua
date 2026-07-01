--!strict
return table.freeze({
	-- Temporary launch-testing switch. Set this to false before release.
	AllowEveryone=true,
	-- Testing economy switch. Keep false for normal starter/match-earned coins.
	InfiniteCoinsEveryone=false,
	-- User-owned experiences authorize game.CreatorId automatically.
	-- For group-owned experiences, add your Roblox user ID here.
	UserIds=table.freeze({
		-- 123456789,
	}),
	CoinGrantAmount=10000000,
})

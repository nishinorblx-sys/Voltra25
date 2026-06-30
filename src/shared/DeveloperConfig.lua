--!strict
return table.freeze({
	-- Temporary launch-testing switch. Set this to false before release.
	AllowEveryone=true,
	-- Testing economy: every player is kept at MaximumCoins and coin purchases are free.
	-- Turn this off before release.
	InfiniteCoinsEveryone=true,
	-- User-owned experiences authorize game.CreatorId automatically.
	-- For group-owned experiences, add your Roblox user ID here.
	UserIds=table.freeze({
		-- 123456789,
	}),
	CoinGrantAmount=10000000,
})

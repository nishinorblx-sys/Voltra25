local SevenWinLoginRewardConfig = {}

SevenWinLoginRewardConfig.MinimumWins = 7
SevenWinLoginRewardConfig.BaseChance = 1
SevenWinLoginRewardConfig.ChancePerWin = 0
SevenWinLoginRewardConfig.MaxChance = 1
SevenWinLoginRewardConfig.ClaimKey = "SevenWinLoginReward_v2"
SevenWinLoginRewardConfig.RemoteFolderName = "SevenWinLoginRewardRemotes"
SevenWinLoginRewardConfig.PendingRemoteName = "PendingSevenWinLoginReward"
SevenWinLoginRewardConfig.ConfirmRemoteName = "ConfirmSevenWinLoginReward"
SevenWinLoginRewardConfig.FallbackPacks = {
	"BronzePack",
	"SilverPack",
	"GoldPack",
}

return SevenWinLoginRewardConfig

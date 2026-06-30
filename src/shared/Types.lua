--!strict

export type NavigationItem = {
	Id: string,
	Label: string,
	Icon: string,
	Order: number,
}

export type Currency = {
	Icon: string,
	Value: string,
	Color: Color3?,
}

export type Fixture = {
	Home: string,
	Away: string,
	Time: string,
	Competition: string,
}

export type Stat = {
	Label: string,
	Value: string,
	Accent: boolean?,
}

export type PageContext = {
	Theme: any,
	Config: any,
	Navigate: (string) -> (),
}

export type PlayerProfileData = { Username: string, DisplayName: string, Level: number, XP: number, SelectedClub: string, ClubIdentity: any?, Avatar: { UserId: number, HeadshotType: string, OutfitId: number } }
export type CurrencyData = { Coins: number, Bolts: number }
export type SeasonData = { Name: string, Level: number, XP: number, RequiredXP: number }
export type RankedData = { Division: string, Rank: string, Wins: number, Draws: number, Losses: number, RP: number, RequiredRP: number, WinStreak: number }
export type ObjectiveData = {
	objectiveId: string, groupId: string, title: string, description: string,
	progress: number, target: number, reward: { Type: string, Amount: number },
	status: "locked" | "active" | "completed" | "claimable" | "claimed",
	nextObjectiveId: string?, sortOrder: number,
}
export type FixtureData = { Id: string, HomeTeam: string, AwayTeam: string, Competition: string, StartsAt: number, DisplayTime: string }

return {}

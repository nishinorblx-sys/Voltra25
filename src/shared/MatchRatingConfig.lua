--!strict
local Universal={
	Assist=.8,KeyPass=.25,BigChanceCreated=.35,ShotOnTarget=.15,SuccessfulDribble=.12,
	SuccessfulPass=.02,ProgressivePass=.08,SuccessfulCross=.15,PossessionWon=.12,
	Interception=.18,TackleWon=.18,Block=.2,Clearance=.1,AerialDuelWon=.12,FoulWon=.1,
	OwnGoal=-2,RedCard=-3,YellowCard=-.3,FoulCommitted=-.12,PenaltyConceded=-1.5,
	ErrorLeadingToShot=-.6,ErrorLeadingToGoal=-1.5,PossessionLost=-.08,BadPass=-.05,
	FailedDribble=-.1,BigChanceMissed=-.55,ShotOffTarget=-.08,TackleFailed=-.08,DribbledPast=-.18,
}
local ByRole={
	GK={Goal=2,Assist=1,Save=.35,DifficultSave=.55,PenaltySave=1.5,ClaimedCross=.18,SuccessfulPass=.04,LongDistributionCompleted=.12,BadPass=-.12,ErrorLeadingToGoal=-1.8,GoalConceded=-.45},
	CB={Goal=1.5,Assist=1,Interception=.22,TackleWon=.2,Block=.25,Clearance=.15,AerialDuelWon=.15,LastManTackle=.45,DribbledPast=-.22,LostAerialDuel=-.12,GoalConceded=-.3,PenaltyConceded=-1.5},
	FB={Goal=1,Assist=1,TackleWon=.18,Interception=.18,SuccessfulCross=.22,KeyPass=.25,ProgressiveCarry=.1,DribbledPast=-.2,FailedCross=-.06,GoalConceded=-.25},
	CDM={Goal=1.5,Assist=.8,Interception=.24,TackleWon=.22,BallRecovery=.16,ProgressivePass=.1,PassUnderPressure=.08,Block=.18,LostDefensiveThird=-.25,DribbledPast=-.18,BadPassOwnHalf=-.12,FoulNearBox=-.25,GoalConceded=-.15},
	CM={Goal=1,Assist=.85,SuccessfulPass=.025,ProgressivePass=.1,KeyPass=.3,ChanceCreated=.3,SuccessfulDribble=.12,BallRecovery=.12,BadPass=-.06,BigChanceMissed=-.45,LostBallCenter=-.12},
	CAM={Goal=1.1,Assist=.9,KeyPass=.35,BigChanceCreated=.45,SuccessfulDribble=.15,PossessionLost=-.08,BadPass=-.06,BigChanceMissed=-.45,LostBallCenter=-.12},
	W={Goal=1.2,Assist=.8,SuccessfulDribble=.18,SuccessfulCross=.22,KeyPass=.28,ShotOnTarget=.15,ProgressiveCarry=.12,FailedDribble=-.12,FailedCross=-.06,BigChanceMissed=-.5,PossessionLost=-.08},
	ST={Goal=1.25,Assist=.75,ShotOnTarget=.18,BigChanceCreated=.3,AerialDuelWon=.12,BigChanceMissed=-.65,ShotOffTarget=-.1,PossessionLost=-.07,Offside=-.08},
}
return table.freeze({Base=6,Minimum=3,Maximum=10,Universal=table.freeze(Universal),ByRole=table.freeze(ByRole)})

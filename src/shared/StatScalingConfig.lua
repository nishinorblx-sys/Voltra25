--!strict
local Scaling={}
function Scaling.Speed(pac:number):number return 12+math.clamp(pac,1,99)/99*10 end
function Scaling.Acceleration(pac:number):number return 7+math.clamp(pac,1,99)/99*8 end
function Scaling.PassSpeed(pas:number):number return 42+math.clamp(pas,1,99)/99*26 end
function Scaling.ShotSpeed(sho:number,charge:number):number return (58+math.clamp(sho,1,99)/99*50)*(0.55+math.clamp(charge,0,1)*.45) end
function Scaling.TouchDistance(dri:number,sprinting:boolean):number return (sprinting and 4.4 or 3.1)+(100-math.clamp(dri,1,99))/100*(sprinting and 1.8 or .8) end
function Scaling.TackleChance(def:number,phy:number):number return math.clamp(.2+def/160+phy/300,.2,.92) end
function Scaling.DuelStrength(phy:number):number return .5+math.clamp(phy,1,99)/99 end
function Scaling.Goalkeeper(gk:number):number return math.clamp(.2+gk/125,.2,.95) end
return table.freeze(Scaling)

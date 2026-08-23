#include "script/common.lua"
#include "hrafnscripts/bodyscripts.lua"
#include "hrafnscripts/aiscripts.lua"
#include "hrafnscripts/flightscripts.lua"
#include "hrafnscripts/weaponscripts1.lua"
#include "hrafnscripts/utilities.lua"
#include "hrafnscripts/swfaction.lua"
SW_FACTION = "rebel"		-- Star Wars faction: empire | rebel

--gfx
--customGlare = LoadSprite("gfx/glare.png")
cGRadius = 10
cGMaxDist = 75
cGMidPoint = 0
--no weapons yet I'm just testing squad/swarm ai
--flyerfp is my standardized tag for various utilities
function init()
	getAllChoppers() --base game heli bodies, for rejection
	
	--autoCannonSettings = FindLocations("autocannonsettings")	
	
	--settings locations
	aiSettings = FindLocation("aisettings")
	attackSettings = FindLocation("attacksettings") --to spare space in ai settings
	squadSettings = FindLocation("squadsettings")
	healthSettings = FindLocation("healthsettings")

	--sounds
	thrusterHumLoop = LoadLoop("MOD/snd/jet.ogg", 40.0)
	heardSound = LoadSound("robot/alert.ogg")
	heardSound = LoadSound("snd/alertclicking.ogg")
	shieldBreakSound = LoadSound("alarm3-loop.ogg")
	shieldBreakSound2 = LoadSound("alarm1.ogg")
	shieldPop = LoadSound("light/spark2.ogg")
	dieSound = LoadSound("robot/disable0.ogg")
	--weaponChargeSound = LoadSound("MOD/snd/plasma.ogg", 20.0)

	--load body and searchlight
	initBodies()
	factionInitAir()
	--shields 
	core = FindShape("core") --the weakspot, breakable after shields down
	corebody = GetShapeBody(core)
	
	shieldsEnabled = HasTag(healthSettings,"shields") or false --enable entire shielding routine in lua
	if shieldsEnabled then initShields(); SetTag(core,"unbreakable") end
	
	--searchlight colors
	initSearchLightColors()
	
	--ai flight params
	targetPos= GetPlayerPos() --where thing is targeting
	lookPos = GetPlayerPos()
	hoverPos = GetPlayerPos() --where to hover at relative to targetpos
	hrafnVel = Vec() --for actual velocity
	hrafnSpeed = 15
	height = math.random(5,7)	--height above ground, i originally wanted 6, TODO: editor-set height
	toHeight = 0 --after accounting for ground
	averageSurroundingHeight = 0 
	
	--ai awareness parameters
	timeSinceLastSeen = 0
	timeSinceChoosePatrol = 0
	maxPatrolTime = tonumber(GetTagValue(aiSettings, "patroltime")) or 10
	minPatrolRadius = tonumber(GetTagValue(aiSettings, "minpatroldist")) or 7
	maxPatrolRadius = tonumber(GetTagValue(aiSettings, "maxpatroldist")) or 45
	
	timeSinceDistraction = 0
	distractionThreshold = tonumber(GetTagValue(aiSettings, "distracttime")) or 3
	timeToReposition = 0 --how long to spend moving to a hoverPos before switching
	repositionTime = tonumber(GetTagValue(aiSettings, "repotime")) or 2.8
	minHoverDist = tonumber(GetTagValue(aisettings,"minhoverdist")) or 20
	maxHoverDist = tonumber(GetTagValue(aisettings,"maxhoverdist")) or 26
	
	playerSeen = false --player sighted
	playerTracked = false --preparations for attack
	playerSeeMeter = 0 --from 0 to 1
	maxHearDist = tonumber(GetTagValue(aiSettings, "maxhear")) or 50 --maximum hearing distance
	
	--ai attack parameters
	closeInStyle = HasTag(attackSettings,"closein") or false --whether to continue circling around or to get in close on playertracking
	closeInMaxDist = tonumber(GetTagValue(attackSettings,"closemax")) or 40
	closeInMinDist = tonumber(GetTagValue(attackSettings,"closemin")) or 20
	blindFireable = HasTag(attackSettings,"blindfire") or false --blindfire enabled? most apparent in squad context
	weaponActive = false
	activeWeaponCount = 0
	attackCount = 0 --how many attacks so far
	
	--weapons
	
	--autocannon
	initAutoCannon()
	initLaser() --laser
	initRockets()
	
	--ai squad parameters and registries
	--IMPORTANT: a squad masterscript (such as flyerfpsquad) is required to make a registry for the squad, this script WILL break
	--if you force squadup to true without a squad registered
	squad = GetTagValue(squadSettings,"squad") or "nil" --get squad name from the ai settings or nah, don't use nil in the squad script
	squadreg = "level.flyerfp.squad."..squad
	squadup = HasKey(squadreg) --if there is a squad then yes
	noSwarm = HasTag(squadSettings, "noswarm") --disable swarm ai and resume normal flight activity but with shared target data
	--DebugPrint(squadup)
	squadSightLink = HasTag(squadSettings,"sightlink") --if true then it receives sighting information from other units
	regTargetChange = squadreg..".targetchange" --squad alternative to choosePatrolTarget
	regHeard = squadreg..".detect" --report sightings or sounds to this bool
	regSighted = squadreg..".sighted" --report sightings to this bool
	regSightLink = squadreg..".sightlink" --for communication with squad script
	regDetectPos = squadreg..".detectpos" --report the location of the sighting or sound to this string registry
	regDetectLink = squadreg..".detectlink" --respond to sounds others heard
	regAttackCount = squadreg..".attackcount"
	
	active = true
end

function tick(dt)
	if not active then return end
	local selflist = FindBodies("flyerfp")
	--ai sight
	playerSeen = false
	playerTracked = false
	lightR,lightG,lightB = idleLightR,idleLightG,idleLightB
	SetLightColor(lightSpot,lightR,lightG,lightB)
	
	sightMeter(dt)
	isPlayerSeen()
	
	playerTracking()
	if squadup then squadSight() end
	
	--ai hearing
	hearSound()
	
	--navigation
	newPatrolPoint()
	
	--DebugLine(targetPos,VecAdd(targetPos,Vec(0,1,0)))
	
	--movement
	hoverMovement(dt)
	
	--aBOIDance (crude)
	rejectSelf()
	local hit, p, n, s = QueryClosestPoint(hrafnTargetPos,4)
	local p2 = hrafnTargetPos[2] - p[2]
	if HasTag(GetShapeBody(s),"flyerfp") then --yay for my trademarked tag
		if hit and p2 < 1 and p2 > -1 then
			local dir = VecSub(hrafnTransform.pos,p)
			--DebugLine(hrafnTransform.pos,p)
			--dir[2] = 0
			dir = VecNormalize(dir)
			hrafnTargetPos = VecAdd(hrafnTargetPos,VecScale(dir,7))
		end
	end
	
	--closeInStyle movement
	if closeInStyle then
		closeInMovement(dt)
	end
	--timers
	timeSince(dt)
	
	--repositioning hoverPos
	hoverReposition()
	
	--height control
	computeSurroundingHeight(7)
	computeSurroundingHeight(7,height)
	computeSurroundingHeight(13,0,hrafnTransform.pos)
	computeSurroundingHeight(13,0,hrafnTransform.pos)
	computeSurroundingHeight(3.8,height)
	computeSurroundingHeight(3.8,height,hrafnTransform.pos)
	
	heightControl()
	
	--rotate body
	hrafnTargetRot = QuatLookAt(hrafnTransform.pos,lookPos)
	local coreEulerX, coreEulerY, coreEulerZ = GetQuatEuler(hrafnTargetRot) --break quat into euler
	coreEulerX = clamp(coreEulerX,-15,5) --limit pitch
	hrafnTargetRot = QuatEuler(coreEulerX,coreEulerY,coreEulerZ) --rebuild quat with modified pitch
	
	--searchlight control 
	local aimPos = VecCopy(lookPos)
	local radius = clamp(timeSinceLastSeen,0,7)
	if not lookaimAngle then lookaimAngle = 0; lookaimAngleY= 0 end --sorry for needing two aimangles cause i don't want leaks later
	lookaimAngle = lookaimAngle%360 + dt
	lookaimAngleY = lookaimAngleY%360 + dt*1.7 --one day I can make the look pattern more easily modifiable element
	local x = math.cos(lookaimAngle) * radius
	local z = math.sin(lookaimAngleY) * radius
	aimPos = VecAdd(aimPos, Vec(x, 0, z))
	--DebugCross(aimPos)
	
	local lightTransform = TransformToParentTransform(hrafnTransform,searchLightLocalTransform)
	searchLightTargetRot = QuatLookAt(lightTransform.pos,aimPos)
	lightTransform.rot = searchLightRot
	
	--set transforms
	SetBodyTransform(hrafn,hrafnTransform)
	SetBodyTransform(searchLight,lightTransform)
	
	forceStatic()
	
	--render custom glare
	rejectSelf()
	local glareTrans = Transform(GetBodyTransform(searchLight).pos,GetCameraTransform().rot)
	local glaredir = VecSub(GetCameraTransform().pos,GetBodyTransform(searchLight).pos)
	local glaredist = VecLength(glaredir)
	glaredir = VecNormalize(glaredir)
	local glareBlocked = QueryRaycast(GetBodyTransform(searchLight).pos,glaredir,math.min(glaredist,cGMaxDist))
	if not glareBlocked and glaredist < cGMaxDist then
		local radi = 1-clamp(glaredist-cGMidPoint,0,cGMaxDist-cGMidPoint)/(cGMaxDist-cGMidPoint)
		radi = radi*cGRadius
		DrawSprite(customGlare,glareTrans,radi,radi,lightR,lightG,lightB,1,false,true)
		DrawSprite(customGlare,glareTrans,radi,radi,1,1,1,0.25,false,true)
	end
	
	--weapon system tick
	activeWeaponCount = 0
	if not weaponActive and not playerDead() then --which weapons to use for the attack unless you died
		local shouldFire = false
		if squadup then
			if squadSightLink and GetBool(regSightLink) then
				if blindFireable or not blindFireable and canSeePlayer() then
					shouldFire = true
				end
			end
		end
		if playerTracked then shouldFire = true end
		if shouldFire and getDistanceToPlayer() < 41 then
			local activated = false
			if hasAutoCannon and math.random() < .5 then
				autoCannonReady = true
				autoCannonFireDelay = 1 +(math.random()-0.5)*0.5
				autoCannonShotCount = math.random(autoCannonShotCounter[1],autoCannonShotCounter[2])
				--PlaySound(weaponChargeSound,hrafnTransform.pos,3,false)
				activated = true
			end
			if hasLaser and math.random() <0.5 then
				laserTimer = laserTime 
				laserDelay = 1 +(math.random()-0.5)*0.5
				laserReady = true
				--PlaySound(weaponChargeSound,hrafnTransform.pos,2,false)
				activated = true
			end
			if activated then attackCount = attackCount + 1 end
			if squadup and activated then
				SetFloat(regAttackCount, GetFloat(regAttackCount)+1)
				attackCount = GetFloat(regAttackCount)
			end
		end
	end
	if hasAutoCannon then tickAutoCannon(dt) end
	if hasLaser then tickLaser(dt) end
	if activeWeaponCount > 0 then weaponActive = true else weaponActive = false end
	if hasRocket then
		if playerTracked or squadup and squadSightLink and GetBool(regSightLink) then considerRocket() end
		if not playerTracked or squadup and squadSightLink and not GetBool(regSightLink) then
			if rocketTimer > 0 then
				rocketTimer = math.max(0,rocketTimer - dt)
				if rocketTimer <= 0 then
					rocketLaunch()
					considerRocketReload()
				end
			end
		end
	end

	--shield status
	if shieldsEnabled then--run shield routine here if has shields
		tickShields(dt)
	end
	
	if IsShapeBroken(core) or GetShapeBody(core) ~= corebody then --ded
		active = false
		factionAirDeath()
		local self = selflist --thanks convenient tag i made
		for s, p in ipairs(self) do
			--remove unbreakability from all shapes
			local shapes = GetBodyShapes(p)
			for s, shp in ipairs(shapes) do
				RemoveTag(shp,"unbreakable")
			end
		
			SetBodyDynamic(p, true)
			RemoveTag(p,"flyerfp") --cause its dead n all
			SetBodyVelocity(p,hrafnVel)
		end
		--PlaySound(dieSound, hrafnTransform.pos, 13,false)
		MakeHole(GetBodyTransform(searchLight).pos,0.1,0.1,0.1)
	end

	for key, shell in ipairs(autoCannonShellHandler.shells) do --operation of autocannon shots in tickspace
		if shell.active then 
			autoCannonShellOperation(shell)
		end
	end
	for key, rocket in ipairs(rocketHandler.rockets) do --operation of autocannon shots in tickspace
		if rocket.active then 
			rocketOperation(rocket)
		end
	end	
	
end

function rnd(mi, ma)
        return math.random(0, 100)/100*(ma-mi)+mi
end

function update(dt)
	if not active then return end

    tipPos = TransformToParentPoint(GetBodyTransform(corebody), Vec(6.3, -0.3, -1.2))
    tipPos2 = TransformToParentPoint(GetBodyTransform(corebody), Vec(-6.3, -0.3, -1.2))	

	--smooth movement
	local acc = VecSub(hrafnTargetPos,hrafnTransform.pos)
	hrafnVel = VecAdd(hrafnVel,VecScale(acc,dt*1.5))
	hrafnVel = VecScale(hrafnVel,0.98) --drag factor, 0 for immobilize, 1 for NO DRAG
	hrafnTransform.pos = VecAdd(hrafnTransform.pos,VecScale(hrafnVel,dt))
	--smooth rotation
	hrafnTransform.rot = QuatSlerp(hrafnTransform.rot,hrafnTargetRot,0.07)
	
	--searchlight control
	searchLightRot = QuatSlerp(searchLightRot, searchLightTargetRot, 0.13)
	
end
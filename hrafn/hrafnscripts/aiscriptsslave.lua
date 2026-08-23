--shields 
function initShields()
	shieldLights = FindShapes("shieldlight") --shield, for convenience i make them glow
	for s, shap in ipairs(shieldLights) do
		shieldLights[s] = {shape = shap}
		shieldLights[s].body = GetShapeBody(shap)
	end
	shieldBreakTime = 0
	if #shieldLights > 0 then shielded = true; shieldBreakTime = 0.44 end
end

function initSearchLightColors()
	idleLightR,idleLightG,idleLightB = 0, 0, 0
	susLightR, susLightG, susLightB = 0, 0.0, 0.0
	alertLightR,alertLightG,alertLightB = 0, 0, 0
	lightR,lightG,lightB = 0,0,0 --the actual rgb to use
end

function repositionPoint() --change hoverpos around targetpos
	local dir = VecNormalize(Vec(rndFloat(-1,1), 0, rndFloat(-1,1)))
	local r = math.random(minHoverDist,maxHoverDist)
	hoverPos = VecAdd(targetPos, VecScale(dir, r))
end

function chooseLookPoint()
	local dir = VecNormalize(Vec(rndFloat(-1,1), 0, rndFloat(-1,1)))
	local r = math.random(2,7)
	lookPos = VecAdd(hoverPos, VecScale(dir, r))
end

function choosePatrolTarget() --change targetPos
	local dir = VecNormalize(Vec(rndFloat(-1,1), 0, rndFloat(-1,1)))
	local r = math.random(minPatrolRadius,maxPatrolRadius)
	targetPos = VecAdd(GetPlayerPos(), VecScale(dir, r))
end

function computeSurroundingHeight(radius, exheight,controlpoint) --control radius, extra height to give, and where to base probe from
	radius = radius or 10
	exheight = exheight or 0
	controlpoint = controlpoint or hrafnTargetPos
	
	rejectAll()
	rejectChoppers()
	local probe = VecCopy(controlpoint)
	probe[1] = probe[1] + math.random(-radius, radius)
	probe[2] = 100
	probe[3] = probe[3] + math.random(-radius, radius) --random bb radius around point
	local hit, dist = QueryRaycast(probe, Vec(0,-1,0), 100)
	local hitHeight = 0
	if hit then
		hitHeight = 100 - dist
	end
	averageSurroundingHeight = math.max(hitHeight+exheight, averageSurroundingHeight - GetTimeStep()*2.4)
end

function canSeePlayer()
	local playerPos = GetPlayerCameraTransform().pos
	--direction to player
	local lightPos = GetBodyTransform(searchLight).pos
	local dir = VecSub (playerPos, lightPos)
	local dist = VecLength(dir)
	dir = VecNormalize(dir)
	
	rejectSelf()
	QueryRejectVehicle(GetPlayerVehicle())
	return not QueryRaycast(lightPos, dir, dist, 0, true)

end

function playerDead()
	if GetPlayerHealth() <= 0 then
		return true
	end
	return false
end

--tickspace
function sightMeter(dt) --playerSeeMeter
	if canSeePlayer() and IsPointAffectedByLight(lightSpot,GetPlayerCameraTransform().pos) then --you are spotted by the spotlight
		playerSeen = true
		playerSeeMeter = math.min(2,playerSeeMeter+dt*2) --getting seen increases seen meter
	else
		playerSeeMeter = math.max(0,playerSeeMeter - dt) --decrease seen meter
	end
	if playerSeeMeter >= 1 then --fully alert
		lightR,lightG,lightB = alertLightR,alertLightG,alertLightB
		SetLightColor(lightSpot,lightR,lightG,lightB)
		playerTracked = true
	elseif playerSeeMeter > 0.05 then
		lightR,lightG,lightB= susLightR,susLightG,susLightB
		SetLightColor(lightSpot,lightR,lightG,lightB)
	end
end

function isPlayerSeen()
	if playerSeen then
		timeSinceLastSeen = 0
		lookPos = GetPlayerPos()
	elseif not playerSeen and timeSinceLastSeen < 1 then--emulate motion estimation
		lookPos = GetPlayerPos()
		if playerTracked then 
			targetPos = GetPlayerPos() 
			if squadup then 
				SetString(regDetectPos,string.format("%f,%f,%f",targetPos[1],targetPos[2],targetPos[3])) --write targetpos to registry
			end
		end
	end	
end

function getDistanceToPlayer()
	local playerPos = GetPlayerPos()
	return VecDist(playerPos, hrafnTransform.pos)
end

function playerTracking()
	if playerTracked then --full alert
		timeSinceChoosePatrol = 0
		timeSinceDistraction =0
		if closeInStyle then timeToReposition = 0 end --force reposition timer to 0 if tracking player in closein mode
		if playerSeen then targetPos = GetPlayerPos() end
		
		if squadup then
			SetBool(regSighted,true)
			if playerSeen then 
				SetString(regDetectPos,string.format("%f,%f,%f",targetPos[1],targetPos[2],targetPos[3])) --report player target pos to reg
			end
		end
	end
end
function timeSince(dt) --last seen, patrol change, reposition, etc
	if not playerSeen then
		timeSinceLastSeen = math.min(timeSinceLastSeen + dt,1000) --math.min to prevent overflow
	end
	if not playerTracked then
		if not squadup then --standard
			timeSinceChoosePatrol = timeSinceChoosePatrol + dt --use the squad script's patrol target and time instead if in squad and swarm
			timeSinceDistraction = timeSinceDistraction + dt
		else --in squad
			if squadSightLink then
				timeSinceDistraction = GetFloat(squadreg..".distractiontime") --collective hearing from the squad masterscript
			else
				timeSinceDistraction = timeSinceDistraction + dt --without synced vision, have separate hearing
			end
			timeSinceChoosePatrol = timeSinceChoosePatrol + dt --resume normal timeSinceChoosePatrol ticker
		end
	end
	timeToReposition = timeToReposition + dt
end

function squadSight() --synchronized sighting with other squad members
	if squadup and GetBool(regSightLink) and squadSightLink then --if in squad and other unit is tracking player but not this one
		--only if sightlink enabled
		lookPos = VecCopy(targetPos) --shared sight
	end
end

function hearSound()
	if timeSinceDistraction > distractionThreshold then
		local volume, pos = GetLastSound();
		if volume > 0.5 then
	 		local v = getSoundVolume(pos) * volume
			if v > 0.5 then
				targetPos = pos
				lookPos = VecCopy(targetPos)
				repositionPoint()
				if squadup then 
					SetBool(regHeard, true) 
					SetString(regDetectPos,string.format("%f,%f,%f",pos[1],pos[2],pos[3]))
				end
				timeSinceChoosePatrol = 0
				timeSinceDistraction = 0
				timeToReposition = 0
				--PlaySound(heardSound,hrafnTransform.pos,8,false)
			end
		end
	end
	if squadup and GetBool(regDetectLink) and squadSightLink then 
	--if sight is linked so is hearing, if other squad member hears then receive here
		targetPos = tagToVec(GetString("level.flyerfp.squad."..squad..".targetpos"))
		lookPos = VecCopy(targetPos)
		repositionPoint()
		timeSinceChoosePatrol = 0
		timeSinceDistraction = 0
		timeToReposition = 0
	end
end

--navigation tickspace
function newPatrolPoint()
	local exceedtime = timeSinceChoosePatrol > maxPatrolTime
	if exceedtime and not squadup or exceedtime and squadup and noSwarm then --this statement if no squad or swarm flying is disabled
		choosePatrolTarget()
		repositionPoint()
		lookPos = VecCopy(targetPos)
		timeSinceChoosePatrol = 0
		timeToReposition = 0
	elseif squadup and not noSwarm then
		targetPos = tagToVec(GetString("level.flyerfp.squad."..squad..".targetpos")) --constantly fed the squad handler's targetPos
		if GetBool(regTargetChange) then
			--DebugPrint("connected")
			repositionPoint()
			lookPos = VecCopy(targetPos)
			timeSinceChoosePatrol = 0
			timeToReposition = 0
		end
	end
	--spaghetti for syncing targetpos with squad when target sighted but not in swarm
	if squadup and noSwarm and GetBool(regSightLink) and squadSightLink then
		targetPos = tagToVec(GetString("level.flyerfp.squad."..squad..".targetpos"))
		timeSinceChoosePatrol = 0 --ghetto way to disable patroltarget code above
	end
end

	--movement tickspace
function hoverMovement(dt)	
	local toHover = VecSub(hoverPos,hrafnTargetPos)
	toHover[2] = 0
	local l = VecLength(toHover)
	local minDist = 1
	
	PlayLoop(thrusterHumLoop,hrafnTransform.pos,0.5,false)
	PlayLoop(thrusterHumLoop2,hrafnTransform.pos,30,false)
	
	local speed = math.min(hrafnSpeed,l*1.4)
	toHover = VecNormalize(toHover)
	hrafnTargetPos = VecAdd(hrafnTargetPos,VecScale(toHover,speed*dt))
end

function closeInMovement(dt) --if playertracked and closeInStyle
	if playerTracked or squadup and squadSightLink and GetBool(regSightLink) then
		local toTarget = VecSub(lookPos,hrafnTargetPos)
		toTarget[2] = 0
		local dir2tgt = VecNormalize(toTarget)
		local moveDir = Vec()
		if VecLength(toTarget) > closeInMaxDist then
			moveDir = VecScale(dir2tgt,1)
		elseif VecLength(toTarget) < closeInMinDist then
			moveDir = VecScale(dir2tgt,-1)
		end		
		local sideways = Transform(Vec(),QuatLookAt(Vec(),dir2tgt))
		sideways = TransformToParentVec(sideways,Vec(rndFloat(-1,1),0,0))
		moveDir = VecNormalize(VecAdd(moveDir,sideways))
		
		hoverPos = VecAdd(hoverPos,VecScale(moveDir,hrafnSpeed*dt))
		timeToReposition = 0 --force reposition time to 0
	end
end

function hoverReposition()
	if timeToReposition > repositionTime then
		repositionPoint()
		targetPos[2] = GetPlayerPos()[2]
		
		--choosing look point, dependant on squad or not
		if not weaponActive then
			if not squadup then
				if playerSeeMeter < 0.1  or timeSinceLastSeen > 1 then chooseLookPoint() end
			else --in squad
				if playerSeeMeter < 0.1 or timeSinceLastSeen > 1 then --use shared look point if sightlink enabled 
					if squadSightLink and not GetBool(regSightLink) then
						chooseLookPoint()
					elseif not squadSightLink then
						chooseLookPoint()
					end
				end 
				--if in squad, it will chooseLookPoint if squad hasn't seen player
			end
		end
		timeToReposition = 0
	end
end

--shield tick
function tickShields(dt)
	for s,shield in ipairs(shieldLights) do
		if IsShapeBroken(shield.shape) or not IsHandleValid(shield.shape) or GetShapeBody(shield.shape) ~= shield.body then 
			table.remove(shieldLights,s)
		end
	end
	
	if #shieldLights == 0 and shielded then
		shielded = false
		RemoveTag(core,"unbreakable")
		--PlaySound(shieldBreakSound,hrafnTransform.pos,35,false)
		--PlaySound(shieldBreakSound2,hrafnTransform.pos,26,false)
		--PlaySound(shieldPop,hrafnTransform.pos,15,false)
		
		--shield break particles
		ParticleReset()
		ParticleColor(1,0.37,0.1)
		ParticleTile(14)
		ParticleRadius(0.5,7)
		ParticleAlpha(1,0)
		ParticleGravity(0)
		ParticleEmissive(6,1)
		--ParticleRotation(20)
		ParticleSticky(0)
		ParticleCollide(0)
		SpawnParticle(hrafnTransform.pos,Vec(),0.2)
	end
	if not shielded then 
		--PointLight(hrafnTransform.pos,1,0.66,0.1,(shieldBreakTime/0.44)*52) --AUGH SHIELDS ARE DOWN
		shieldBreakTime = math.max(shieldBreakTime-dt,0)--how long the shield break light lasts
	end
end
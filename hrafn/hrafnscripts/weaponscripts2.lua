autoCannonShellHandler = {
	shellNum = 1,
	shells = {},
	defaultShell = {active = false}
} --for secondary autocannon

rocketHandler = {
	rocketNum = 1,
	rockets = {},
	defaultRocket = {active = false}
} --for rockets

function initAutoCannon()
	autoCannonSettings = FindLocation("autocannonsettings")
	autoCannonSound = LoadSound("MOD/snd/tieshoot.ogg", 25.0)
    autoCannonSound2 = LoadSound("MOD/snd/l0.ogg", 10.0)
	hasAutoCannon = autoCannonSettings ~= 0
	autoCannonRecoil = 1
	autoCannonDmg = 2.4
	autoCannonFR = 170/660 --fire rate
	autoCannonShotCounter = {3,6}
	autoCannonShotCount = 0 --dont mix up the -er, this is the actual meter
	autoCannonFireDelay = 0 --the timer
	autoCannonVel = 150
	for i=1,75 do
		autoCannonShellHandler.shells[i] = {active = false}
	end
	autoCannonLocalMuzzle = GetLocationTransform(autoCannonSettings) --doubles as muzzle
	autoCannonLocalMuzzle = TransformToLocalTransform(hrafnTransform,autoCannonLocalMuzzle)
	autoCannonMode = "off" --or "charge" or "shoot"
	autoCannonReady = false
end

function initRockets()
	rocketSettings = FindLocation("rocketsettings")
	rocketSound= LoadSound("tools/launcher0.ogg")
	hasRocket = rocketSettings ~= 0 
	rocketVel = 100
	for i=1,35 do
		rocketHandler.rockets[i] = {active = false}
	end
	rocketLaunchLocalPoint = TransformToLocalTransform(hrafnTransform,GetLocationTransform(rocketSettings))
	rocketTimer = 0
	rocketDelay = 4
end

function initLaser()
	--gfx
	laserSprite = LoadSprite("gfx/laser.png")
	--sounds
	laserHitPlayer= LoadSound("light/spark0.ogg")
	laserLoop = LoadLoop("snd/laser-loop.ogg")
	laserHitLoop = LoadLoop("snd/laser-hit-loop.ogg")

	laserSettings = FindLocation("lasersettings")
	hasLaser = laserSettings ~= 0
	laserMode = "off"
	laserTime = 1
	laserTimer = 0
	laserDelay = 0 --for tickLaser
	laserDmg = 0.5
	laserPoint = GetLocationTransform(laserSettings)
	laserPoint = TransformToLocalTransform(hrafnTransform,laserPoint)
	laserRot = Quat()
	laserTargetRot = Quat()
	laserReady = false
end

--autocannon
function autoCannonFire()
	local origin = TransformToParentTransform(hrafnTransform,autoCannonLocalMuzzle) --should be the unmoving muzzle of the drone
	origin.rot = QuatLookAt(origin.pos,lookPos)
	--local lookat = VecAdd(lookPos,TransformToParentVec(origin,Vec(0,0.41,0)))
	--origin.rot = QuatLookAt(origin.pos,lookat)
	--origin.rot = QuatRotateQuat(origin.rot,QuatEuler(rndFloat(-5,5),rndFloat(-5,5),0))
	
	local dir = TransformToParentVec(origin,Vec(0,0,-100))
	local spread = 4
	dir[1] = dir[1]+(math.random()-0.5)*spread
	dir[2] = dir[2]+(math.random()-0.5)*spread
	dir[3] = dir[3]+(math.random()-0.5)*spread
	local targetDist = VecDist(lookPos,origin.pos)
	dir=VecNormalize(dir)
	
	--loads shell
	autoCannonShellHandler.shells[autoCannonShellHandler.shellNum] = {active = false} 
	loadedShell = autoCannonShellHandler.shells[autoCannonShellHandler.shellNum]
	loadedShell.active = true
	loadedShell.pos = origin.pos --set shell start point to the muzzle
	loadedShell.dmg = autoCannonDmg
	loadedShell.vel = VecScale(dir,autoCannonVel)
	loadedShell.travelDist = 0
	loadedShell.killDist = targetDist*2 --to save computing
	autoCannonShellHandler.shellNum = (autoCannonShellHandler.shellNum%#autoCannonShellHandler.shells)+1
	
	--PointLight(origin.pos, 0.1, 0.9, 0.1, 90)
	PlaySound(autoCannonSound,origin.pos,0.8,false)
	hrafnVel = VecAdd(hrafnVel,VecScale(dir,-autoCannonRecoil))--recoil
end

function autoCannonShellOperation(shell)
	local ahead = VecAdd(shell.pos,VecScale(shell.vel,GetTimeStep()))
	local dir = VecNormalize(shell.vel)
	local particlet = Transform(shell.pos,QuatLookAt(Vec(),dir))
	local shellLen = VecDist(ahead,shell.pos)
	local shellVec = VecSub(ahead,shell.pos)
	local dmg = shell.dmg
	
	--check player for damage
	local hitPlayer = false --will it hit you?
	local ppos = GetPlayerTransform().pos
	ppos[2] = ppos[2]-0.5
	local pdist,phit = getDistanceToLineSegment(ppos,shell.pos,ahead)
	if pdist < 0.6 then
		hitPlayer = true
	end
	ppos = GetPlayerCameraTransform().pos
	ppos[2] = ppos[2] - 0.7 --now 1.2 m height
	local pdist,phit = getDistanceToLineSegment(ppos,shell.pos,ahead)
	if pdist < 0.6 then
		hitPlayer = true
	end
	if hitPlayer then
		local health = GetPlayerHealth()
		health = health - 0.1
		--health = math.max(0.1,health - 0.1)
		SetPlayerHealth(health)
	end
	
	if squadup then rejectAll() else rejectSelf() end --disable friendly fire
	QueryRequire("physical")
	local dist = VecDist(ahead,shell.pos)
	local hit, dist = QueryRaycast(shell.pos, dir, shellLen) --raycast for determining impact with voxel
	if hit then
		local hitPos = VecAdd(shell.pos, VecScale(VecNormalize(VecSub(ahead, shell.pos)), dist))
		shell.active = false
		for a = 0,VecLength(VecSub(hitPos,shell.pos)), 0.05 do
			SpawnParticle("smoke",TransformToParentPoint(particlet,Vec(0,0,-a)),Vec(0,0,0),0.06,0.03+GetTimeStep()*0.1*a)
		end
		MakeHole(hitPos,dmg,dmg*0.9,dmg*0.1)
		PointLight(hitPos, 1, 0.9, 0.7, 50)
		PlaySound(autoCannonSound2,hitPos,0.5,false)
		
		ParticleReset()
        ParticleRadius(0.2, 1.2, "smooth")
        ParticleColor(1, 1, 1, 0.5, 0.5, 0.5)
        ParticleGravity(-1.5)
		ParticleAlpha(0.9, 0)
		ParticleStretch(5.0)
		ParticleCollide(0, 1)
		ParticleRotation(rnd(8, 10), 0.0, "easeout")
		ParticleDrag(0, 0.05)

        for i=1,15 do
            SpawnParticle(hitPos, Vec(rnd(-1,1), rnd(0,3.5), rnd(-1,1)), rnd(1,3))
        end	

		ParticleReset()
        ParticleRadius(0.1, 1.2, "smooth")
        ParticleColor(0.8, 0.8, 0.8, 0.2, 0.2, 0.2)
        ParticleGravity(-1.5)
		ParticleAlpha(0.7, 0)
		ParticleStretch(5.0)
		ParticleCollide(0, 1)
		ParticleRotation(rnd(-8, -10), 0.0, "easeout")
		ParticleDrag(0, 0.05)

        for i=1,17 do
            SpawnParticle(hitPos, Vec(rnd(-1,1), rnd(0,3.5), rnd(-1,1)), rnd(1,3))
        end		

		ParticleReset()
		ParticleTile(5)
        ParticleRadius(0.2, 0.4, "smooth")
        ParticleColor(1, 0.6, 0.4, 1, 0.4, 0.2)
        ParticleGravity(0, rnd(-6, 1))
		ParticleAlpha(1, 0)
		ParticleStretch(5.0)
		ParticleCollide(0, 1)
		ParticleRotation(rnd(12, 16), 1, "easeout")
		ParticleEmissive(rnd(2, 3), 0, "easeout")
		ParticleDrag(0, 0.07)

        for i=1,32 do
            SpawnParticle(hitPos, Vec(rnd(-0.5,0.5), rnd(0,2), rnd(-0.5,0.5)), rnd(1,2))
        end	

		ParticleReset()
		ParticleTile(5)
        ParticleRadius(0.2, 0.4, "smooth")
        ParticleColor(1, 0.7, 0.5, 1, 0.7, 0.4)
        ParticleGravity(0, rnd(-6, 1))
		ParticleAlpha(1, 0)
		ParticleStretch(5.0)
		ParticleCollide(0, 1)
		ParticleRotation(rnd(-12, -16), -1, "easeout")
		ParticleEmissive(rnd(2, 3), 0, "easeout")
		ParticleDrag(0, 0.07)

        for i=1,32 do
            SpawnParticle(hitPos, Vec(rnd(-0.5,0.5), rnd(0,2), rnd(-0.5,0.5)), rnd(1,2))
        end			
		
		ParticleReset()
		ParticleEmissive(1.5, 0, "easein")
		ParticleGravity(-5, rnd(-1, -9))
		ParticleRadius(0.02, 0.0, "smooth")
		ParticleColor(1,0.8,0.6, 1,0,0)
		ParticleTile(4)
        ParticleCollide(0, 1)
		ParticleStretch(1.5)
		ParticleSticky(0, 0.05)
		
		for i=1,110 do
            SpawnParticle(hitPos, Vec(rnd(-1,1.5), rnd(1,6), rnd(-1,1.5)), rnd(1,12))
        end	
		
		ParticleReset()
		ParticleGravity(-8)
		ParticleRadius(0.05, 0.0, "smooth")
		ParticleColor(0.5, 0.5, 0.5)
		ParticleTile(6)
        ParticleCollide(1, 1, "constant", 0.05)
		ParticleAlpha(1)
		ParticleRotation(rnd(10, 15), 0.0, "easeout")
		ParticleSticky(0, 0.2)
		
		for i=1,30 do
            SpawnParticle(hitPos, Vec(rnd(-1,2), rnd(0,5), rnd(-1,2)), rnd(1,6))
        end			
		
		
		--bodies in holing distance
		QueryRequire("physical") --dynamic optional
		local mi = VecAdd(hitPos,Vec(-dmg,-dmg,-dmg))
		local ma = VecAdd(hitPos,Vec(dmg,dmg,dmg))
		local bodies = QueryAabbBodies(mi, ma)	
		for i,body in ipairs(bodies) do
			--compute body center and dist
			local bmi,bma = GetBodyBounds(body)
			local bc = VecLerp(bmi,bma,0.5) --get center
			local dir = VecSub(bc, hitPos)
			local dist = VecLength(dir)
			dir = VecScale(dir,1/dist)
			local mass = GetBodyMass(body)--get mass
			
			--dir forward
			dir = VecLerp(dir,shell.vel,0.75)
			dir = VecNormalize(dir)
			
			local distScale = 1 - math.min(dist/dmg*1.2,1)
			--local dF = math.min(dist/1*1.2,1)
			--local distScale = 1 - dF*(2-dF)
			local force = math.min(8899/2.2522,14*mass)*distScale
			--local force = (13*mass*massScale*distScale)
			local add = VecScale(dir,force)
			
			ApplyBodyImpulse(body,hitPos,add)
		end
	else
		for a = 0,VecLength(VecSub(ahead,shell.pos)), 0.04 do
			SpawnParticle("smoke",TransformToParentPoint(particlet,Vec(0,0,-a)),Vec(0,0,0),0.08,0.04+GetTimeStep()*0.1*a)
		end
		PointLight(ahead, 0.1, 0.9, 0.1, 20)
		DrawLine(shell.pos,ahead)
	end
	shell.travelDist = shell.travelDist + shellLen
	shell.pos = ahead
	if shell.travelDist > shell.killDist then
		shell.active = false
	end
end
function tickAutoCannon(dt)
	if autoCannonReady then activeWeaponCount = activeWeaponCount+1 end --weapon is operating
	if playerDead() then
		-- autoCannonShotCount = 0
		-- autoCannonReady = false --force disabled
		-- return 
	end
	if autoCannonReady then
		if autoCannonFireDelay > 0 then
			autoCannonFireDelay = math.max(0,autoCannonFireDelay - dt) --stop function here if delayed
			return
		end
		if autoCannonShotCount > 0 then
			autoCannonFire()
			autoCannonFireDelay = autoCannonFR+ math.random()*0.1
			autoCannonShotCount = autoCannonShotCount - 1
		else
			autoCannonReady = false
		end
	end
end

--laser 
function laser()
	local origin = TransformToParentTransform(hrafnTransform,laserPoint) --should be the unmoving muzzle of the drone
	origin.rot = laserRot
	local dir = TransformToParentVec(origin,Vec(0,0,-1))
	
	if squadup then rejectAll() else rejectSelf() end
	local hitPos = TransformToParentPoint(origin,Vec(0,0,-50))
	local hit,dist = QueryRaycast(origin.pos,dir,50)
	if hit then
		hitPos = TransformToParentPoint(origin,Vec(0,0,-dist))
		MakeHole(hitPos,laserDmg,laserDmg,laserDmg*0.1,true)
	end
	--DrawLine(origin.pos,hitPos,1)
	laserParticle()--set up particles
	for i=0,VecDist(hitPos,origin.pos),0.05 do
		ParticleRadius(0.06,0.06)
		ParticleColor(1,1,1)
		ParticleEmissive(6)
		SpawnParticle(TransformToParentPoint(origin,Vec(0,0,-i)),Vec(),GetTimeStep()*1.3)
		ParticleRadius(0.1,0.1)
		ParticleEmissive(3)
		ParticleAlpha(0.5)
		ParticleColor(1,0,0)
		SpawnParticle(TransformToParentPoint(origin,Vec(0,0,-i)),Vec(),GetTimeStep()*1.3)
	end
	PlayLoop(laserLoop,origin.pos,4,false)
	PlayLoop(laserHitLoop,hitPos,6,false)
	--check player for damage
	local hitPlayer = false --will it hit you?
	local ppos = GetPlayerTransform().pos
	ppos[2] = ppos[2]-0.5
	local pdist,phit = getDistanceToLineSegment(ppos,origin.pos,hitPos)
	PlayLoop(laserLoop,phit,4,false)
	if pdist < 0.7 then
		hitPlayer = true
	end
	ppos = GetPlayerCameraTransform().pos
	ppos[2] = ppos[2] - 0.7 --now 1.2 m height
	local pdist,phit = getDistanceToLineSegment(ppos,origin.pos,hitPos)
	if pdist < 0.7 then
		hitPlayer = true
	end
	if hitPlayer then
		PlaySound(laserHitPlayer,GetPlayerPos(),0.6,false)
		local health = GetPlayerHealth()
		health = health - 0.005
		--health = math.max(0.1,health - 0.1)
		SetPlayerHealth(health)
	end
end
function laserParticle()
	ParticleReset()
	ParticleTile(3)
	ParticleAlpha(1)
	ParticleGravity(0)
	ParticleCollide(0)
	ParticleSticky(0)
end
function tickLaser(dt)
	laserTargetRot = QuatLookAt(TransformToParentPoint(hrafnTransform,laserPoint.pos),lookPos)
	laserRot = QuatSlerp(laserRot,laserTargetRot,0.33)

	if laserReady then activeWeaponCount = activeWeaponCount+1 end --weapon is operating
	if playerDead() then
		-- laserTimer = 0
		-- laserReady = false --force disabled
		-- return 
	end
	if laserReady then
		if laserDelay > 0 then
			laserDelay = math.max(0,laserDelay - dt) --stop function here if delayed
			return
		end
		if laserTimer > 0 then
			laser()
			laserTimer = math.max(0,laserTimer - dt)
		else
			laserReady = false
		end
	end
end

function considerRocket()
	if math.random() < 0.42 and attackCount > 3 then
		rocketTimer = rocketDelay+ math.random()*2
	else
		rocketTimer = 0
	end
end
function considerRocketReload()
	if math.random() < 0.78 then
		rocketTimer = 0.1 + math.random()*0.1
	else
		rocketTimer = 0
	end
end
function rocketLaunch()
	local origin = TransformToParentTransform(hrafnTransform,rocketLaunchLocalPoint)
	origin.rot = QuatLookAt(origin.pos,targetPos)
	local dir = TransformToParentVec(origin,Vec(0,0,-1))
	
	rocketHandler.rockets[rocketHandler.rocketNum] = {active = false} 
	rocket = rocketHandler.rockets[rocketHandler.rocketNum]
	rocket.active = true
	rocket.pos = origin.pos
	rocket.vel = TransformToParentVec(origin,Vec(0,0,-rocketVel))
	rocket.dmg = 0.9
	rocket.travelDist = 0
	rocket.killDist = 200
	rocketHandler.rocketNum = (rocketHandler.rocketNum%#rocketHandler.rockets)+1
	
	PlaySound(rocketSound, origin.pos, 5, false)
end
function rocketOperation(rocket)
	local ahead = VecAdd(rocket.pos,VecScale(rocket.vel,GetTimeStep()))
	local dir = VecNormalize(rocket.vel)
	local particlet = Transform(rocket.pos,QuatLookAt(Vec(),dir))
	local rocketLen = VecDist(ahead,rocket.pos)
	local rocketVec = VecSub(ahead,rocket.pos)
	local dmg = rocket.dmg
	
	ParticleReset()
	ParticleRadius(0.5,0.1)
	ParticleEmissive(0)
	ParticleDrag(0.4,1)
	ParticleGravity(0,1)
	
	if squadup then rejectAll() else rejectSelf() end --disable friendly fire
	QueryRequire("physical")
	local dist = VecDist(ahead,rocket.pos)
	local hitPos = ahead
	local hit, dist = QueryRaycast(rocket.pos, dir, rocketLen) --raycast for determining impact with voxel
	if hit then
		hitPos = VecAdd(rocket.pos,VecScale(dir,dist))
		DrawLine(rocket.pos,hitPos)
		rocket.active=false
		Explosion(hitPos,dmg)
	end
	DrawLine(rocket.pos,ahead)
	for m=0,rocketLen,0.2 do
		SpawnParticle(TransformToParentPoint(particlet,Vec(0,0,-m)),Vec(),0.4+GetTimeStep()*m*0.2)
	end
	PointLight(ahead,1,0.66,.45,12)
	rocket.pos = ahead
	rocket.travelDist = rocket.travelDist + rocketLen
	if rocket.travelDist > rocket.killDist then
		rocket.active = false
		Explosion(rocket.pos,dmg)
	end
end
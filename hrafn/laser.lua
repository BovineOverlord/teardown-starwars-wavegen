MAX_DIST = 1000
DONE_TIMER = 2.0
BURN_TIME = 25
PLAYER_HIT_RADIUS = 0.4

function rnd(mi, ma)
	return math.random(1000)/1000*(ma-mi) + mi
end

function rndVec(t)
	return Vec(rnd(-t, t), rnd(-t, t), rnd(-t, t))
end 

function init()
	buttonShape = FindShape("button")
	emitterShape = FindShape("emitter")
	emitterLocation = FindLocation("emitter")
	vaultDoors = FindBodies("vaultdoor", true)
	
	laserLoop = LoadLoop("laser-loop.ogg")
	laserHitLoop = LoadLoop("laser-hit-loop.ogg")
	laserHitSound = LoadSound("light/spark0.ogg")
	laserDist = 0
	laserHitScale = 0
	
	laserSprite = LoadSprite("gfx/laser.png")

	disableTimer = 0
	setEnabled(false)
end


function setEnabled(e)
	enabled = e
	if enabled then
		SetShapeEmissiveScale(emitterShape, 1)
		SetTag(buttonShape, "interact", "Turn off")
	else
		SetShapeEmissiveScale(emitterShape, 0)
		SetTag(buttonShape, "interact", "Turn on")
	end
end


function emitSmoke(pos, amount)
	ParticleReset()
	ParticleType("smoke")
	ParticleColor(0.8, 0.8, 0.8)
	ParticleRadius(0.2, 0.4)
	ParticleAlpha(0.5, 0)
	ParticleDrag(0.5)
	ParticleGravity(rnd(0.0, 2.0))
	SpawnParticle(VecAdd(pos, rndVec(0.01)), rndVec(0.1), rnd(1.0, 3.0))

	ParticleReset()
	ParticleEmissive(5, 0, "easeout")
	ParticleGravity(-10)
	ParticleRadius(0.01, 0.0, "easein")
	ParticleColor(1, 0.4, 0.3)
	ParticleTile(4)
	local vel = VecAdd(Vec(0, 1, 0), rndVec(2.0))
	SpawnParticle(pos, vel, rnd(1.0, 2.0))
end


function getDistanceToLineSegment(point, p0, p1)
    local line_vec = VecSub(p1, p0)
    local pnt_vec = VecSub(point, p0)
    local line_len = VecLength(line_vec)
    local line_unitvec = VecNormalize(line_vec)
    local pnt_vec_scaled = VecScale(pnt_vec, 1.0/line_len)
    local t = VecDot(line_unitvec, pnt_vec_scaled)    
    if t < 0.0 then
        t = 0.0
    elseif t > 1.0 then
        t = 1.0
	end
    local nearest = VecScale(line_vec, t)
    local dist = VecLength(VecSub(nearest, pnt_vec))
    local nearest = VecAdd(nearest, p0)
    return dist, nearest
end


function shootLaser(body, shape, origin, dir, currentLength)
	--Raycast
	QueryRequire("physical")
	if shape ~= 0 then
		QueryRejectShape(shape)
	end
	if body ~= 0 then
		QueryRejectBody(body)
	end
	local hit, hitDist, hitNormal, hitShape = QueryRaycast(origin, dir, MAX_DIST, 0.0, true)
	local length = MAX_DIST
	if hit then
		length = hitDist
	end
	local hitPoint = VecAdd(origin, VecScale(dir, length))
	
	local t = Transform(VecLerp(origin, hitPoint, 0.5))
	local xAxis = VecNormalize(VecSub(hitPoint, origin))
	local zAxis = VecNormalize(VecSub(origin, GetCameraTransform().pos))
	t.rot = QuatAlignXZ(xAxis, zAxis)
	DrawSprite(laserSprite, t, length, 0.05+math.random()*0.01, 8, 4, 4, 1, true, true)
	DrawSprite(laserSprite, t, length, 0.5, 1.0, 0.3, 0.3, 1, true, true)

	--Check if player if hit by laser
	local ppos = GetPlayerCameraTransform().pos
	ppos[2] = ppos[2] - PLAYER_HIT_RADIUS*0.5
	local pdist, phit = getDistanceToLineSegment(ppos, origin, hitPoint)
	if pdist < PLAYER_HIT_RADIUS then
		--Decrease health but don't kill
		local health = GetPlayerHealth()
		health = math.max(0.1, health - 0.3)
		SetPlayerHealth(health)
		ReleasePlayerGrab()
		
		--Disance to player, without vertical component
		local pdir = VecSub(ppos, phit)
		pdir[2] = 0
		pdir = VecNormalize(pdir)

		--Move player and give a nudge
		local pt = GetPlayerTransform(true)
		pt.pos = VecAdd(pt.pos, VecScale(pdir, PLAYER_HIT_RADIUS-pdist+0.1))
		SetPlayerTransform(pt, true)
		SetPlayerVelocity(VecScale(pdir, 10))

		--Play hit sound
		PlaySound(laserHitSound, ppos)
	end

	--Check if reflected
	local hitBody = GetShapeBody(hitShape)
	if HasTag(hitBody, "mirror") and currentLength < MAX_DIST then
		local refDir = VecSub(dir, VecScale(hitNormal, VecDot(hitNormal, dir)*2))
		return shootLaser(hitBody, hitShape, hitPoint, refDir, currentLength + length)
	end
	return currentLength + length, hitPoint, hitBody, hitShape
end

function tick(dt)
	if GetPlayerInteractShape() == buttonShape and InputPressed("interact") then
		setEnabled(not enabled)
	end
	
	if enabled then
		local emitTransform = GetLocationTransform(emitterLocation)
		local origin = emitTransform.pos
		PlayLoop(laserLoop, origin, 0.5)
		local dir = TransformToParentVec(emitTransform, Vec(0, 0, -1))
		local length, hitPoint, hitBody, hitShape = shootLaser(0, emitterShape, origin, dir, 0)
		if length ~= laserDist then
			laserHitScale = 1
			laserDist = length
		end
		laserHitScale = math.max(0.0, laserHitScale - dt)
		if laserHitScale > 0 then
			PlayLoop(laserHitLoop, endPoint, laserHitScale)
			PointLight(hitPoint, 1, 0.2, 0.2, rnd(2.0, 4.0)*laserHitScale)
		end
		PointLight(hitPoint, 1, 0.2, 0.2, rnd(0.5, 1.0))

		for i = 1, #vaultDoors do
			if hitBody == vaultDoors[i] then
				RemoveTag(vaultDoors[i], "unbreakable")
			end
		end
	
		emitSmoke(hitPoint, 1.0)
		MakeHole(hitPoint, 0.5, 0.3, 0, true)
	end
	
	SetBool("level.laser", enabled)

	if GetBool("level.vaultbroken") then
		disableTimer = disableTimer + dt
		if disableTimer > 3 then
			setEnabled(false)
			SetBool("level.vaultbroken", false)
		end
	end
end

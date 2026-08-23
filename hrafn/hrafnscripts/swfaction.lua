------------------------------------------------------------------------------------
-- STAR WARS AI PACK - Aircraft faction & targeting overrides (added by mod update)
------------------------------------------------------------------------------------
-- Included LAST in each aircraft main script so these definitions override the
-- stock ones in aiscripts*.lua. Requires the global SW_FACTION ("empire"|"rebel")
-- to be set before init().
--
-- The whole flyer AI funnels its target through GetPlayerPos() / canSeePlayer().
-- By redirecting those to the nearest hostile (enemy-faction unit or the player)
-- the craft will hunt and fire on the opposing faction. Its cannon/laser deal
-- damage physically (MakeHole / raycast), so enemy units and craft take hits.
------------------------------------------------------------------------------------

function swEnemyFaction()
	if SW_FACTION == "empire" then return "rebel" end
	return "empire"
end

function swSelfPos()
	if hrafnTransform then return hrafnTransform.pos end
	return GetPlayerCameraTransform().pos
end

-- Tag the craft so it can be found and identified by the faction system.
function factionInitAir()
	swTargetIsPlayer = false
	swNoTarget = true
	swTargetPos = swSelfPos()
	swPosTime = -1
	swTarget = 0
	local bodies = FindBodies("flyerfp")
	for i = 1, #bodies do
		SetTag(bodies[i], "sw_faction", SW_FACTION)
	end
	if hrafn and hrafn ~= 0 then
		SetTag(hrafn, "sw_" .. SW_FACTION)
	end
end

-- Called from the craft's death block so nobody keeps hunting the wreck.
function factionAirDeath()
	if hrafn and hrafn ~= 0 then
		RemoveTag(hrafn, "sw_" .. SW_FACTION)
		SetTag(hrafn, "sw_dead")
	end
end

function swNearestEnemy()
	local best, bestD = 0, 1e9
	local from = swSelfPos()
	local list = FindBodies("sw_" .. swEnemyFaction(), true)
	for i = 1, #list do
		local b = list[i]
		if b ~= 0 and IsHandleValid(b) and not HasTag(b, "sw_dead") then
			local d = VecLength(VecSub(GetBodyTransform(b).pos, from))
			if d < bestD then bestD = d; best = b end
		end
	end
	return best, bestD
end

function swComputeTargetPos()
	-- Fight only the enemy faction; the player is a spectator and is never targeted.
	local e = swNearestEnemy()
	swTarget = e
	swTargetIsPlayer = false
	if e ~= 0 then
		swNoTarget = false
		return VecAdd(GetBodyTransform(e).pos, Vec(0, 1, 0))
	end
	-- No enemy: loiter in place. canSeePlayer() returns false so nothing is fired.
	swNoTarget = true
	return swSelfPos()
end

-- Override: nearest hostile, cached at ~5 Hz (called many times per tick).
function GetPlayerPos()
	local now = GetTime()
	if not swPosTime or now - swPosTime > 0.2 then
		swPosTime = now
		swTargetPos = swComputeTargetPos()
	end
	return swTargetPos
end

-- Override: line of sight to the current target (enemy body counts as visible).
function canSeePlayer()
	if swNoTarget then return false end   -- no enemy to fight: hold fire
	local tp = GetPlayerPos()
	local lightPos = GetBodyTransform(searchLight).pos
	local dir = VecSub(tp, lightPos)
	local dist = VecLength(dir)
	dir = VecNormalize(dir)
	rejectSelf()
	QueryRejectVehicle(GetPlayerVehicle())
	local hit, hd, hn, hs = QueryRaycast(lightPos, dir, dist, 0, true)
	if not hit then return true end
	if not swTargetIsPlayer then
		local b = GetShapeBody(hs)
		if b ~= 0 and HasTag(b, "sw_faction") and GetTagValue(b, "sw_faction") == swEnemyFaction() then
			return true
		end
	end
	return false
end

-- Override: run the see-meter against the current target rather than the player.
function sightMeter(dt)
	local tp = GetPlayerPos()
	if canSeePlayer() and IsPointAffectedByLight(lightSpot, tp) then
		playerSeen = true
		playerSeeMeter = math.min(2, playerSeeMeter + dt * 2)
	else
		playerSeeMeter = math.max(0, playerSeeMeter - dt)
	end
	if playerSeeMeter >= 1 then
		lightR, lightG, lightB = alertLightR, alertLightG, alertLightB
		SetLightColor(lightSpot, lightR, lightG, lightB)
		playerTracked = true
	elseif playerSeeMeter > 0.05 then
		lightR, lightG, lightB = susLightR, susLightG, susLightB
		SetLightColor(lightSpot, lightR, lightG, lightB)
	end
end

-- Override: only the human player can be "dead"; keep fighting enemy units.
function playerDead()
	if swTargetIsPlayer then
		return GetPlayerHealth() <= 0
	end
	return false
end

------------------------------------------------------------------------------------
-- STAR WARS AI PACK - Faction & targeting module (added by mod update)
------------------------------------------------------------------------------------
-- Included by every ground-unit AI script right after common.lua.
-- Requires the global FACTION to be set to "empire" or "rebel" before init().
--
-- The stock robot AI is hard-wired to hunt the human player. This module makes
-- every unit instead lock on to the NEAREST hostile, where "hostile" means any
-- unit of the opposing faction AND the player. The chosen hostile is fed into
-- the stock AI through robot.playerPos / robot.distToPlayer / robot.dirToPlayer,
-- so the whole existing state machine (hunt, aim, shoot) keeps working unchanged.
------------------------------------------------------------------------------------

function factionEnemyName()
	if FACTION == "empire" then return "rebel" end
	return "empire"
end

function factionInit()
	faction = {}
	faction.name = FACTION or "empire"
	faction.enemy = factionEnemyName()
	faction.target = 0				-- enemy-unit main body handle (0 = none / targeting player)
	faction.targetIsPlayer = true
	faction.targetPos = GetPlayerCameraTransform().pos
	faction.reacquireTimer = 0
	faction.dead = false

	-- Tag every body so line-of-sight checks can recognise enemy units,
	-- and tag the main body as a locatable beacon for the enemy faction to find.
	for i = 1, #robot.allBodies do
		SetTag(robot.allBodies[i], "sw_faction", faction.name)
	end
	SetTag(robot.body, "sw_" .. faction.name)
	-- How much this unit counts toward faction strength / the entity budget
	-- (heavy units such as the AT-ST set UNIT_WEIGHT before init).
	SetTag(robot.body, "sw_weight", tostring(UNIT_WEIGHT or 1))
	-- Heroes are limited to one alive per side by the Wave Generator.
	if UNIT_HERO then SetTag(robot.body, "sw_hero") end

	-- Units spawned by the Wave Generator are flagged aggressive so they advance
	-- across the map toward the enemy even before they have line of sight.
	-- config.aggressive itself is toggled per-frame in factionUpdateTargeting so a
	-- unit stands down (and never hunts the player) once its enemies are gone.
	faction.aggro = HasTag(robot.body, "sw_aggro") or GetBool("level.sw.aggressive")
	if faction.aggro then
		config.canSeePlayer = true
		config.canHearPlayer = true
		config.huntPlayer = true
	end
end

-- Drop our beacon when we die so nobody keeps hunting a corpse.
-- Also react to a "sw_kill" tag placed on us by an enemy melee/force attack.
function factionSelfCheck()
	if not faction then return end
	if robot.enabled and HasTag(robot.body, "sw_kill") then
		robot.enabled = false
		if feetCollideLegs then feetCollideLegs(true) end
	end
	if not faction.dead and not robot.enabled then
		faction.dead = true
		RemoveTag(robot.body, "sw_" .. faction.name)
		SetTag(robot.body, "sw_dead")
	end
end

function factionNearestEnemyUnit()
	local best, bestDist = 0, 1e9
	local from = robot.bodyCenter
	local enemies = FindBodies("sw_" .. faction.enemy, true)
	for i = 1, #enemies do
		local b = enemies[i]
		if b ~= 0 and IsHandleValid(b) and not HasTag(b, "sw_dead") then
			local d = VecLength(VecSub(GetBodyTransform(b).pos, from))
			if d < bestDist then
				bestDist = d
				best = b
			end
		end
	end
	return best, bestDist
end

-- Lock on to the nearest enemy-faction unit (never the player) and feed it to the
-- stock AI. Returns the target position (raised to torso height for units).
function factionUpdateTargeting(dt)
	if not faction then
		return VecAdd(GetPlayerTransform().pos, Vec(0, 1, 0))
	end
	if faction.dead then
		return faction.targetPos
	end

	-- Hunt-the-player mode: both factions ignore each other and chase the player.
	if GetBool("level.sw.huntplayer") then
		faction.targetIsPlayer = true
		config.aggressive = true
		faction.targetPos = GetPlayerCameraTransform().pos
		robot.playerPos = faction.targetPos
		return faction.targetPos
	end

	-- Validate current unit target
	if faction.target ~= 0 and (not IsHandleValid(faction.target) or HasTag(faction.target, "sw_dead")) then
		faction.target = 0
	end

	-- Periodically (or when we have no unit target) look for the nearest enemy unit
	faction.reacquireTimer = faction.reacquireTimer - dt
	if faction.target == 0 or faction.reacquireTimer <= 0 then
		faction.reacquireTimer = 0.35
		faction.target = factionNearestEnemyUnit()
	end

	-- Fight only the enemy faction; the player is a spectator and is never targeted.
	faction.targetIsPlayer = false
	if faction.target ~= 0 and IsHandleValid(faction.target) then
		config.aggressive = faction.aggro
		faction.targetPos = VecAdd(GetBodyTransform(faction.target).pos, Vec(0, 1, 0))
	else
		-- No enemy left to fight: stand down (roam) rather than chase the player.
		config.aggressive = false
		faction.targetPos = Vec(robot.bodyCenter[1], -1000, robot.bodyCenter[3])
	end

	robot.playerPos = faction.targetPos
	return faction.targetPos
end

-- Line-of-sight test that treats hitting the enemy unit (or any enemy body) as
-- "visible", and rejects our own bodies. Used only when targeting an enemy unit.
function factionLosClear(fromPos, dir, dist)
	rejectAllBodies(robot.allBodies)
	QueryRejectVehicle(GetPlayerVehicle())
	local hit, hd, hn, hshape = QueryRaycast(fromPos, dir, dist, 0, true)
	if not hit then return true end
	local b = GetShapeBody(hshape)
	if b ~= 0 and HasTag(b, "sw_faction") and GetTagValue(b, "sw_faction") == faction.enemy then
		return true
	end
	return false
end

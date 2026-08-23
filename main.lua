------------------------------------------------------------------------------------
-- STAR WARS AI PACK - WAVE GENERATOR  (runs on every sandbox level when enabled)
------------------------------------------------------------------------------------
-- Empire and Rebel forces spawn on opposing sides of the battlefield and advance
-- toward the centre, fighting each other (and you). Each wave is larger than the
-- last and unlocks heavier units: troops -> walkers -> aircraft -> heroes.
--
--   HOTKEYS
--     O  - toggle Wave Generator on / off
--     P  - clear every spawned unit
--     U  - force the next wave to spawn immediately
------------------------------------------------------------------------------------

--------------------------------- tuning -------------------------------------------
WAVE_INTERVAL   = 25.0      -- seconds between waves
FIRST_WAVE_WAIT = 3.0       -- delay before the very first wave
SPAWN_DIST      = 40.0      -- how far each faction spawns from the battle centre
                            -- (keep < 50 so the ~100m pathfinder can route them together)
LATERAL_STEP    = 4.0       -- spacing between units along a spawn line
-- These are high safety nets only; the ~30 FPS gate below is the real limiter, so
-- waves keep coming as long as the frame rate holds up.
MAX_ALIVE       = 400       -- weighted safety cap on living units (AT-ST counts as 5)
MAX_BODIES      = 2000      -- hard safety cap on total unit bodies
AIR_HEIGHT      = 12.0      -- spawn height for aircraft above the ground
MAX_AIR_PER_SIDE = 3        -- cap on aircraft spawned per faction per wave
PERF_MAX_FRAME_DT = 0.0333  -- hold waves while avg frame time is worse than this (~30 FPS)
REBALANCE_MAX   = 10        -- most reinforcements the losing side can get per wave

WAVE_VEHICLES = 3           -- wave that unlocks walkers
WAVE_AIRCRAFT = 5           -- wave that unlocks starfighters
WAVE_HEROES   = 7           -- wave that unlocks heroes & villains

-- Prefab paths (relative to the mod)
P_TROOPER  = "MOD/trooper.xml"
P_REBEL    = "MOD/rebel.xml"
P_ATST     = "MOD/atst.xml"
P_TIE      = "MOD/hrafn/tie.xml"
P_SLAVE    = "MOD/hrafn/hrafn.xml"
P_AIR      = "MOD/hrafn/air.xml"
P_VADER    = "MOD/vader.xml"
P_EMPEROR  = "MOD/emperor.xml"
P_LUKE     = "MOD/luke.xml"
P_KENOBI   = "MOD/kenobi.xml"
------------------------------------------------------------------------------------

function init()
	wave = {
		active = false,
		number = 0,
		timer = 0,
		center = Vec(0, 0, 0),
		axis = Vec(1, 0, 0),      -- battle axis: empire on +axis, rebels on -axis
		side = Vec(0, 0, 1),      -- perpendicular, units spread along this
		flash = 0,                -- HUD flash timer when a wave lands
		eCount = 0,               -- cached faction strengths for the HUD
		rCount = 0,
		countTimer = 0,
		holding = false,          -- next wave delayed for perf / saturation
		paused = false,           -- user-paused (hotkey): stop spawning new waves
		forceNext = false,        -- "wave now" request: spawn immediately, ignore gates
		bodyCount = 0,            -- cached total unit bodies (real FPS driver)
		avgFrameDt = 1 / 60,      -- smoothed real frame time (FPS proxy)
	}
end

------------------------------------------------------------------------------------
-- helpers
------------------------------------------------------------------------------------
-- Raycast down to the ground at (x,z). Returns the surface point, or nil if
-- there is nothing solid below.
function groundHit(x, z)
	local hit, dist = QueryRaycast(Vec(x, 400, z), Vec(0, -1, 0), 800)
	if hit then
		return Vec(x, 400 - dist + 0.4, z)
	end
	return nil
end

-- Find a dry patch of ground near (x,z). Searches outward in rings so units are
-- never dropped into water (where the stock AI instantly disables them).
-- Returns a ground point, or nil if only water/void is nearby.
function findDryGround(x, z)
	local base = groundHit(x, z)
	if base and not IsPointInWater(base) then return base end
	-- First search along the line toward the battle centre, so units relocated out
	-- of water land on the centre-facing shore (reachable) rather than a far one.
	local toC = VecSub(wave.center, Vec(x, wave.center[2], z))
	toC[2] = 0
	local len = VecLength(toC)
	if len > 0.001 then
		local dir = VecScale(toC, 1 / len)
		for d = 4, math.min(len, 60), 4 do
			local p = groundHit(x + dir[1] * d, z + dir[3] * d)
			if p and not IsPointInWater(p) then return p end
		end
	end
	-- Fall back to an outward ring search.
	for r = 4, 40, 4 do
		for a = 0, 315, 45 do
			local rad = math.rad(a)
			local p = groundHit(x + math.cos(rad) * r, z + math.sin(rad) * r)
			if p and not IsPointInWater(p) then return p end
		end
	end
	return nil
end

-- Face a spawned unit toward the battle centre (yaw only).
function faceCenter(pos)
	local look = Vec(wave.center[1], pos[2], wave.center[3])
	if VecLength(VecSub(look, pos)) < 0.01 then return QuatEuler(0, 0, 0) end
	return QuatLookAt(pos, look)
end

function factionStrength(tag)
	local total = 0
	local bodies = FindBodies(tag, true)
	for i = 1, #bodies do
		total = total + (tonumber(GetTagValue(bodies[i], "sw_weight")) or 1)
	end
	return total
end

-- Returns total, empire, rebel strength. AT-STs count as 5, everything else 1.
function countAlive()
	local e = factionStrength("sw_empire")
	local r = factionStrength("sw_rebel")
	return e + r, e, r
end

-- Count heavy units (walkers, weight >= 5) alive for a faction beacon tag.
function countHeavies(tag)
	local c = 0
	local bodies = FindBodies(tag, true)
	for i = 1, #bodies do
		if (tonumber(GetTagValue(bodies[i], "sw_weight")) or 1) >= 5 then c = c + 1 end
	end
	return c
end

-- Count heroes currently alive for a faction beacon tag.
function countHeroes(tag)
	local c = 0
	local bodies = FindBodies(tag, true)
	for i = 1, #bodies do
		if HasTag(bodies[i], "sw_hero") then c = c + 1 end
	end
	return c
end

-- Hold the next wave until the battlefield thins out and the frame rate recovers.
function canSpawnNextWave()
	if wave.bodyCount >= MAX_BODIES then return false end           -- entity load (FPS)
	if (wave.eCount + wave.rCount) >= MAX_ALIVE then return false end -- weighted strength
	if wave.avgFrameDt > PERF_MAX_FRAME_DT then return false end     -- measured frame time
	return true
end

-- Spawn a prefab, snap it to the ground (or air height) and make ground units
-- advance aggressively across the map toward the nearest enemy.
function spawnUnit(prefab, x, z, air)
	local pos
	if air then
		-- Aircraft fly, so water underneath is fine; prefer dry land but don't require it.
		local g = findDryGround(x, z) or groundHit(x, z) or Vec(x, 6, z)
		pos = VecAdd(g, Vec(0, AIR_HEIGHT, 0))
	else
		-- Ground units must not spawn in water, or they die instantly.
		local g = findDryGround(x, z)
		if not g then return end   -- no dry land nearby; skip this unit
		pos = g
	end
	local t = Transform(pos, faceCenter(pos))
	local entities = Spawn(prefab, t)
	if entities then
		for i = 1, #entities do
			-- 'sw_aggro' makes the ground AI aggressive (read in factionInit) so
			-- units march toward the enemy even before they have line of sight.
			SetTag(entities[i], "sw_aggro")
		end
	end
	return entities
end

-- Spawn a line of units for one faction along the spawn edge.
function spawnLine(prefab, sign, count, air)
	local edge = VecAdd(wave.center, VecScale(wave.axis, SPAWN_DIST * sign))
	local half = (count - 1) * 0.5
	for i = 1, count do
		local off = (i - 1 - half) * LATERAL_STEP
		local p = VecAdd(edge, VecScale(wave.side, off))
		spawnUnit(prefab, p[1], p[3], air)
	end
end

------------------------------------------------------------------------------------
-- wave logic
------------------------------------------------------------------------------------
function startWaveMode()
	wave.active = true
	wave.number = 0
	wave.timer = WAVE_INTERVAL - FIRST_WAVE_WAIT
	-- Put the battlefield in front of the player: the two armies spawn to the left
	-- and right and clash downrange, so the player can watch from behind the lines.
	local pt = GetPlayerTransform()
	local fwd = TransformToParentVec(pt, Vec(0, 0, -1))
	fwd[2] = 0
	if VecLength(fwd) < 0.01 then fwd = Vec(1, 0, 0) end
	fwd = VecNormalize(fwd)
	local right = VecNormalize(VecCross(fwd, Vec(0, 1, 0)))
	wave.center = VecAdd(pt.pos, VecScale(fwd, 35))   -- clash point, 35m downrange
	wave.axis = right                                 -- empire right, rebels left
	wave.side = fwd                                   -- spread units along depth
	-- Anchor the clash point on dry, solid ground so both armies converge on land.
	local c = findDryGround(wave.center[1], wave.center[3])
	if c then wave.center = c end
	-- Units read this in factionInit to become aggressive (advance across the map).
	SetBool("level.sw.aggressive", true)
	SetString("hud.notification", "Wave Generator ARMED - first wave incoming")
end

function stopWaveMode()
	wave.active = false
	SetBool("level.sw.aggressive", false)
end

function clearUnits()
	local bodies = FindBodies("sw_faction", true)
	for i = 1, #bodies do
		if IsHandleValid(bodies[i]) then Delete(bodies[i]) end
	end
end

function spawnWave()
	wave.number = wave.number + 1
	wave.flash = 1.5
	local n = wave.number

	local _, e, r = countAlive()
	local base = math.min(2 + n, 8)

	-- Rebalance by STRENGTH budget: reinforce the LOSING side by the size of the gap
	-- and scale the WINNING side back so a lead can't snowball. Each side then spends
	-- its budget on units, where an AT-ST costs 5 (its strength), so walkers replace
	-- troopers rather than adding on top of them.
	local catchUp = math.min(math.floor(math.abs(e - r)), REBALANCE_MAX)
	local empBudget, rebBudget = base, base
	if e > r then
		empBudget = math.max(0, base - catchUp)
		rebBudget = base + catchUp
	elseif r > e then
		rebBudget = math.max(0, base - catchUp)
		empBudget = base + catchUp
	end

	-- Empire spends its budget on AT-STs first (5 each), then troopers - but no new
	-- walkers once the Empire is already well ahead.
	local empAT = 0
	if n >= WAVE_VEHICLES and e <= r + 10 then
		empAT = math.min(math.max(1, math.floor(n / 4)), math.floor(empBudget / 5))
	end
	local empTroops = math.max(0, empBudget - empAT * 5)

	-- Rebels have no ground walker, so spend their whole budget on infantry plus a
	-- small standing bonus.
	local rebTroops = rebBudget
	if n >= WAVE_VEHICLES then rebTroops = rebTroops + 2 end

	spawnLine(P_ATST, 1, empAT, false)          -- Empire walkers (0 = none)
	spawnLine(P_TROOPER, 1, empTroops, false)   -- Empire infantry on +axis
	spawnLine(P_REBEL, -1, rebTroops, false)    -- Rebels on -axis

	-- Starfighters (capped per side). Rebels get the air advantage since aircraft
	-- are their main way to destroy AT-STs. Slave I is not used in waves.
	if n >= WAVE_AIRCRAFT then
		spawnLine(P_TIE, 1, math.min(1, MAX_AIR_PER_SIDE), true)   -- Empire: 1 TIE
		spawnLine(P_AIR, -1, math.min(3, MAX_AIR_PER_SIDE), true)  -- Rebels: 3 airspeeders
	end

	-- Heroes & villains: at most ONE alive per side at a time. Send the losing side's
	-- champion; only send the winning side's if it isn't already dominant.
	if n >= WAVE_HEROES then
		if e <= r + 10 and countHeroes("sw_empire") == 0 then
			spawnLine((math.random() < 0.5) and P_VADER or P_EMPEROR, 1, 1, false)
		end
		if r <= e + 10 and countHeroes("sw_rebel") == 0 then
			spawnLine((math.random() < 0.5) and P_LUKE or P_KENOBI, -1, 1, false)
		end
	end
end

------------------------------------------------------------------------------------
-- main callbacks
------------------------------------------------------------------------------------
function tick(dt)
	-- hotkeys
	if InputPressed("o") then
		if wave.active then
			stopWaveMode()
			SetString("hud.notification", "Wave Generator: OFF")
		else
			startWaveMode()
			SetString("hud.notification", "Wave Generator: ON - first wave incoming")
		end
	end
	if InputPressed("p") then
		clearUnits()
		SetString("hud.notification", "Wave Generator: cleared all units")
	end

	if not wave.active then return end

	if InputPressed("k") then
		wave.paused = not wave.paused
		SetString("hud.notification", wave.paused and "Wave Generator: PAUSED" or "Wave Generator: resumed")
	end

	if InputPressed("u") then
		wave.forceNext = true
		SetString("hud.notification", "Wave Generator: spawning next wave")
	end

	-- Refresh cached counts a few times a second (HUD + spawn-gate checks).
	wave.countTimer = wave.countTimer - dt
	if wave.countTimer <= 0 then
		wave.countTimer = 0.3
		local _, e, r = countAlive()
		wave.eCount = e
		wave.rCount = r
		wave.bodyCount = #FindBodies("sw_faction", true)
	end

	if wave.forceNext then
		-- "Wave now" is an explicit user command: spawn immediately, ignoring the
		-- pause, the performance hold and the entity caps.
		wave.forceNext = false
		wave.timer = 0
		wave.holding = false
		spawnWave()
	elseif not wave.paused then
		wave.timer = wave.timer + dt
		if wave.timer >= WAVE_INTERVAL then
			if canSpawnNextWave() then
				wave.timer = 0
				wave.holding = false
				spawnWave()
			else
				-- Battlefield too full or FPS low: hold the wave and keep re-checking
				-- so it fires the instant conditions recover.
				wave.timer = WAVE_INTERVAL
				wave.holding = true
			end
		end
	end

	if wave.flash > 0 then wave.flash = math.max(0, wave.flash - dt) end
end

function draw()
	if not wave.active then
		-- Clearly visible so its presence confirms main.lua is running on this map.
		UiPush()
			UiAlign("center top")
			UiTranslate(UiCenter(), 14)
			UiFont("regular.ttf", 24)
			UiColor(1, 0.85, 0.1, 1)
			UiText("STAR WARS WAVE GENERATOR ready - press [O] to start")
		UiPop()
		return
	end

	UiPush()
		UiAlign("center top")
		UiTranslate(UiCenter(), 18)

		UiFont("regular.ttf", 30)
		UiColor(1, 0.85, 0.1, 1)
		UiText("STAR WARS - WAVE " .. wave.number)

		UiTranslate(0, 32)
		UiFont("regular.ttf", 22)
		local status, col
		if wave.paused then
			status = "PAUSED"
			col = {1, 0.8, 0.2}
		elseif wave.holding then
			status = "HOLDING (thinning out / FPS " .. math.floor(1 / math.max(wave.avgFrameDt, 0.0001)) .. ")"
			col = {1, 0.5, 0.2}
		else
			status = "next wave: " .. math.max(0, math.ceil(WAVE_INTERVAL - wave.timer)) .. "s"
			col = {0.5, 0.7, 1}
		end
		UiColor(col[1], col[2], col[3], 1)
		UiText("Empire " .. wave.eCount .. "   vs   Rebels " .. wave.rCount .. "        " .. status)

		UiTranslate(0, 26)
		UiColor(0.7, 0.7, 0.7, 1)
		UiFont("regular.ttf", 18)
		UiText("[O] toggle   [K] pause   [P] clear   [U] wave now")

		if wave.flash > 0 then
			UiTranslate(0, 34)
			UiColor(1, 0.3, 0.2, wave.flash / 1.5)
			UiFont("regular.ttf", 26)
			UiText("WAVE " .. wave.number .. " INCOMING")
		end
	UiPop()
end

function update(dt)
	-- update() runs once per rendered frame, so its dt tracks real frame time and
	-- lets the wave gate pause spawning when performance drops.
	if dt and dt > 0 and dt < 1 then
		wave.avgFrameDt = wave.avgFrameDt * 0.9 + dt * 0.1
	end
end

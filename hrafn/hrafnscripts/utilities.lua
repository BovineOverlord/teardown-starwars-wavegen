function rndFloat(mi, ma)
	return mi + (ma-mi)*(math.random(0, 1000000)/1000000.0)
end

function VecDist(a,b) --tuxedo labs pls
	return VecLength(VecSub(b,a))
end

function tagToVec(tag) --or QuatEulers, it's just a table of three values
	tag = commasplit(tag) --tag must be able to turn into a table of three
	for key, value in ipairs(tag) do
		value = tonumber(value)
	end
	return tag
end 
function commasplit(inputstr) --splits a "x,x,x..." string into a table
	local t = {}
	for str in string.gmatch(inputstr,"([^,]+)") do
		table.insert(t,str)
	end
	return t
end

function getAllChoppers() --gets base game choppers
	choppers = FindBodies("chopper",true)
	tailrotors = FindBodies("tailrotor",true)
	mainrotors = FindBodies("mainrotor",true)
	chopperlights = FindBodies("light",true)
end

function rejectChoppers() --for use alongside base game choppers
	for c, body in ipairs(choppers) do
		QueryRejectBody(body)
	end
	for c, body in ipairs(tailrotors) do
		QueryRejectBody(body)
	end
	for c, body in ipairs(mainrotors) do
		QueryRejectBody(body)
	end
	for c, body in ipairs(chopperlights) do
		QueryRejectBody(body)
	end
end

function rejectSelf() --reject own body
	local rejects = FindBodies("flyerfp") --my own trademarked tag for these entities
	for r, reject in ipairs(rejects) do
		QueryRejectBody(reject)
	end
end

function rejectAll() --rejects all "flyerfp" tagged
	local rejects = FindBodies("flyerfp", true)
	for r, reject in ipairs(rejects) do
		QueryRejectBody(reject)
	end
end

function getSoundVolume(pos)
	local d = VecDist(pos, hrafnTransform.pos)
	local dir = VecNormalize(VecSub(pos, hrafnTransform.pos))
	local distanceLower = 10
	local distanceUpper = maxHearDist
	local distanceFactor = 1.0 - clamp(d-distanceLower, 0, distanceUpper-distanceLower)/(distanceUpper-distanceLower)
		
	local origin = hrafnTransform.pos
	local dist = d - 2
	local blockedFactor = 1.0
	QueryRejectBody(chopper)
	if QueryRaycast(origin, dir, dist) then
		blockedFactor = 0.5
	end

	return blockedFactor * distanceFactor
end

function forceStatic() --i hate physics
	local bodies = FindBodies("flyerfp")
	for f, p in ipairs(bodies) do
		SetBodyDynamic(p, false)
	end
end

function getDistanceToLineSegment(point, p0, p1) --idk how this works but 
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

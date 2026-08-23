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

function heightControl()
	toHeight = height
	rejectAll()
	rejectChoppers()
	local heightprobe = VecCopy(hrafnTargetPos)
	heightprobe[2] = 100
	local hit, dist = QueryRaycast(heightprobe, Vec(0,-1,0), 100, 0)
	if hit then
		toHeight = toHeight + 100-dist
	end
	toHeight = math.max(toHeight, averageSurroundingHeight)
	toHeight = math.max(toHeight, targetPos[2]-7) --to avoid being too far below the target
	hrafnTargetPos[2] = toHeight
end


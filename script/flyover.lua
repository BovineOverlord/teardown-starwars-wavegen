function init()	
	local l0 = FindLocation("start")
	local l1 = FindLocation("end")
	
	t0 = GetLocationTransform(l0)
	t1 = GetLocationTransform(l1)
	
	t = 0

end


function tick(dt)
	t = t + dt
	if t > 20 then
	          StartLevel("main2","MOD/main2.xml","")
	end
	
	if InputPressed("space") or InputPressed("lmb") then
		StartLevel("main2","MOD/main2.xml","")
	end

	--Linear interpolation between t0 and t1
	local q = t / 20
	local pos = VecLerp(t0.pos, t1.pos, q)
	local rot = QuatSlerp(t0.rot, t1.rot, q)
	
	--Set camera transform, this will override the default camera for this frame
	SetCameraTransform(Transform(pos, rot))
	SetCameraFov(110)

end


function draw()
          
	UiImage("MOD/logo.png")

end


function init()	
	--Find handles to the light door13 and and lamp
	door13 = FindShape("door13")
	doorconsole = FindShape("doorconsole")
	motor = FindJoint("motor")
	door13trigger = FindTrigger("door13trigger")
	door13On = false
	Ondoor13 = GetFloatParam("Ondoor13", 4.5)
    Offdoor13 = GetFloatParam("Offdoor13", 0)
    OnSpeed = GetFloatParam("OnSpeed", 2.5)
    OffSpeed =  GetFloatParam("OffSpeed", 2.5)
	motorOn = false
	--Load sounds from the game asset folder (data/snd)
	motorSound = LoadSound("MOD/main/snd/door2.ogg", 9)
	timer=1
	
end


function tick(dt)
	
		broken1 = IsJointBroken(motor)
		broken2 = IsShapeBroken(doorconsole)
		broken3 = IsShapeBroken(door13)
		if not broken1 or broken2 then
		
		if GetPlayerInteractShape() == doorconsole and InputPressed("interact") then
			pos = GetShapeWorldTransform(door13).pos	
			door13On = true
			motorOn = true
			PlaySound(motorSound, pos)
			SetJointMotorTarget(motor, Ondoor13, OnSpeed)
			
		end
	end
	
	
	if timer == 0 then
		pos = GetShapeWorldTransform(door13).pos
        door13On = false
		motorOn = false
		PlaySound(motorSound, pos)
		SetTag(doorconsole, "interact", "Open")
		SetJointMotorTarget(motor, Offdoor13, OffSpeed)
    end	
	if IsShapeInTrigger(door13trigger, door13) then
		RemoveTag(doorconsole, "interact", "Open")
		timer = (timer + dt)
		if timer > 5 then
        timer = 0
		end
		else
		SetTag(doorconsole, "interact", "Open")
	end
	if broken1 or broken2 or broken3 then
		RemoveTag(doorconsole, "interact", "Open")
	end
	
end


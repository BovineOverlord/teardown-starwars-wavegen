isJPEG = GetBoolParam("isJPEG",false)

function init()

	if isJPEG == true then
		topImage = LoadSprite("SkyboxTop.jpeg")
		bottomImage = LoadSprite("SkyboxBottom.jpeg")
		frontImage = LoadSprite("SkyboxFront.jpeg")
		backImage = LoadSprite("SkyboxBack.jpeg")
		leftImage = LoadSprite("SkyboxLeft.jpeg")
		rightImage = LoadSprite("SkyboxRight.jpeg")
	else
		topImage = LoadSprite("SkyboxTop.png")
		bottomImage = LoadSprite("SkyboxBottom.png")
		frontImage = LoadSprite("SkyboxFront.png")
		backImage = LoadSprite("SkyboxBack.png")
		leftImage = LoadSprite("SkyboxLeft.png")
		rightImage = LoadSprite("SkyboxRight.png")
	end
	topQuat = QuatEuler(90,0,0)
	bottomQuat = QuatEuler(-90,0,0)
	frontQuat = QuatEuler(10,0,0)
	backQuat = QuatEuler(0,180,0)
	leftQuat = QuatEuler(0,90,0)
	rightQuat = QuatEuler(0,-90,0)
end

function tick()
	local ct = GetCameraTransform()
	--DrawSprite(topImage,Transform(VecAdd(ct.pos, Vec(0,250,0)), topQuat),500,500,1,1,1,1,true,false)
	--DrawSprite(bottomImage,Transform(VecAdd(ct.pos, Vec(0,-250,0)), bottomQuat),500,500,1,1,1,1,true,false)
	DrawSprite(frontImage,Transform(VecAdd(ct.pos, Vec(-20,30,-300)), frontQuat),900,900,1,1,1,1,true,false)
	--DrawSprite(backImage,Transform(VecAdd(ct.pos, Vec(0,0,250)), backQuat),500,500,1,1,1,1,true,false)
	--DrawSprite(leftImage,Transform(VecAdd(ct.pos, Vec(-250,0,0)), leftQuat),500,500,1,1,1,1,true,false)
	--DrawSprite(rightImage,Transform(VecAdd(ct.pos, Vec(250,0,0)), rightQuat),500,500,1,1,1,1,true,false)
end

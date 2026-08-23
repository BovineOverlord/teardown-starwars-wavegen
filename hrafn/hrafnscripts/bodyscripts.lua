function initBodies()
	hrafn = FindBody("hrafn")
	hrafnTransform = GetBodyTransform(hrafn)
	hrafnTargetPos = Vec()
	hrafnTargetRot = QuatEuler()	
	
	--searchlight
	lightSpot = FindLight("searchlightspot") --the actual light
	
	searchLight = FindBody("searchlight")
	searchLightTransform = GetBodyTransform(searchLight)
	searchLightLocalTransform = TransformToLocalTransform(hrafnTransform,searchLightTransform)
	searchLightRot = QuatEuler()
	searchLightTargetRot = QuatEuler()
end
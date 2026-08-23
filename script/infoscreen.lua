pName = GetStringParam("name","img")
pAmountOfImages = GetIntParam("amount",1)
function init()	
	current = 0
	count = -1
	t = 0
end

function tick()	
	screen = UiGetScreen()
    pName = GetTagValue(screen, "name")
    pAmountOfImages = GetTagValue(screen, "amount")
	count = tonumber(pAmountOfImages)
end

function draw()
	if screen == 0 then
		return
	end
	if count == -1 then
		return
	end	

	UiTranslate(UiCenter(), UiMiddle())
	UiAlign("center middle")
	if count == 1 then
		UiImage("../infoscreens/"..pName.."1.jpg")
		return
	end
	
	local a = current
	local b = math.mod(current+1, count)
	t = t + GetTimeStep()
	UiImage("../infoscreens/"..pName..(a+1)..".jpg")
	if t > 4 then
		UiScale(t-4)
		UiImage("../infoscreens/"..pName..(b+1)..".jpg")
	end
	if t > 5 then
		t = 0
		current = b
	end	
end

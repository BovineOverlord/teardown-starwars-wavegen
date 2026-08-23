------------------------------------------------------------------------------------
-- STAR WARS AI PACK - mod options screen (shown from the Mods list)
------------------------------------------------------------------------------------

function init()
end

function draw()
	UiPush()
		UiTranslate(UiCenter(), 0)
		UiAlign("center middle")

		UiTranslate(0, UiHeight() * 0.18)
		UiFont("regular.ttf", 34)
		UiColor(1, 0.85, 0.1, 1)
		UiText("STAR WARS AI PACK")

		UiTranslate(0, 46)
		UiFont("regular.ttf", 22)
		UiColor(1, 1, 1, 1)
		UiText("Enable this mod, then load any sandbox map.")
		UiTranslate(0, 30)
		UiText("Empire and Rebel units fight each other; you are a spectator.")

		UiTranslate(0, 50)
		UiColor(0.6, 0.8, 1, 1)
		UiFont("regular.ttf", 26)
		UiText("Wave Generator hotkeys (in-game)")

		UiTranslate(0, 34)
		UiColor(1, 1, 1, 1)
		UiFont("regular.ttf", 22)
		UiText("O  -  start / stop the waves")
		UiTranslate(0, 28)
		UiText("K  -  pause / resume spawning")
		UiTranslate(0, 28)
		UiText("P  -  clear all spawned units")
		UiTranslate(0, 28)
		UiText("U  -  force the next wave now")

		UiTranslate(0, 26)
		UiColor(0.7, 0.7, 0.7, 1)
		UiFont("regular.ttf", 18)
		UiText("Waves grow over time: troops, then walkers, starfighters and heroes.")

		UiTranslate(0, 50)
		UiFont("regular.ttf", 26)
		if UiTextButton("Close", 200, 45) then
			Menu()
		end
	UiPop()
end

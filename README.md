# Star Wars AI Pack — Faction Wars & Wave Generator

A gameplay fork of the **STAR WARS AI PACK** mod for [Teardown](https://teardowngame.com),
adding **faction-vs-faction combat** and an endless **Wave Generator** battle mode.

> ⚠️ **This is a fan modification and a derivative work — see [Credits & Licensing](#credits--licensing).**
> It is not affiliated with, endorsed by, or sponsored by Lucasfilm, Disney, or Tuxedo Labs.

---

## What this fork adds

The original mod let you spawn individual Star Wars units that all hunted the player.
This version turns it into a battle sandbox:

- **Two hostile factions.** Empire (Stormtroopers, AT-ST, TIE Fighter, Darth Vader, Emperor
  Palpatine) and Rebels (Rebel troopers, T-47 Airspeeders, Luke, Obi-Wan) now fight *each other*.
  You are a **spectator** — units target only the opposing faction, not you (though you can still
  be caught in the crossfire).
- **Wave Generator mode.** Press a key and endless, escalating waves spawn on opposing sides of
  the battlefield and march toward the centre to clash:
  1. Infantry
  2. **Walkers** (AT-STs) from wave 3
  3. **Starfighters** from wave 5
  4. **Heroes & villains** from wave 7 (max one per side alive at a time)
- **Automatic balancing.** The losing side is reinforced and the winning side scaled back so
  battles stay competitive. AT-STs count as 5 units toward strength/budget. Rebels get an air
  advantage (3 airspeeders vs 1 TIE) since aircraft are their main way to destroy walkers.
- **Performance-aware.** Waves automatically pause when the frame rate drops below ~30 FPS and
  resume once it recovers.

## Controls (Wave Generator)

| Key | Action |
|-----|--------|
| `O` | Start / stop the waves |
| `K` | Pause / resume spawning |
| `P` | Clear all spawned units |
| `U` | Force the next wave now (overrides the performance pause) |

A status banner at the top of the screen shows the wave number, faction strengths, and the
next-wave timer.

## Installation

1. Own and install **Teardown**.
2. Copy this folder into your Teardown mods directory:
   `Documents/Teardown/mods/`
3. Launch Teardown, open **Play → Mods**, and **enable** this mod.
4. Load any sandbox map. You'll see the *"STAR WARS WAVE GENERATOR ready — press [O] to start"*
   banner. Press `O` to begin.

You can also spawn individual units from the pause-menu **Spawn** list, as in the original mod.

## Tuning

The wave behaviour is configured by constants at the top of [`main.lua`](main.lua) — wave interval,
spawn distance, entity/FPS caps, escalation thresholds, air counts and rebalancing strength. Edit
them to taste.

## Credits & Licensing

This is a **derivative work**. Please respect the original creators:

- **Original "STAR WARS AI PACK" mod** — by **tislericsm**
  ([Steam Workshop item 2823645128](https://steamcommunity.com/sharedfiles/filedetails/?id=2823645128)).
  All of the original models (`.vox`), sounds (`.ogg`), textures (`.dds`/`.png`/`.jpg`) and the
  base unit AI belong to their author.
- **Teardown & the base robot AI** — © **Tuxedo Labs**.
- **Star Wars** — characters, names, sounds and likenesses are © **Lucasfilm Ltd. / The Walt
  Disney Company**. Used here non-commercially by fans.

The faction-combat and Wave Generator additions in `main.lua`, `options.lua`, `script/faction.lua`
and `hrafn/hrafnscripts/swfaction.lua` (plus targeting edits to the unit scripts) are the
contribution of this fork.

Because this repository redistributes third-party assets and IP, **no open-source license is
granted over the mod as a whole.** If you are the original author (tislericsm) or a rights holder
and would like changes or removal, please open an issue.

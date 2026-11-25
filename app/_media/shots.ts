// The landing page's screens in each of the app's eight moons, keyed by `MoonTheme`'s raw value. All
// eighty are from one shoot of the 1.6 cut on the iPhone 17 Pro Max simulator, one run per moon
// (`POCKET_SHOOT_MOON` in pocket-ios `scripts/shoot-manual.sh`), so a screen says the same thing in
// every moon and only its colours change. Static imports, so a missing image fails the build.
import type { MoonShots } from '../_components/MoonPhone'
import homeBlood from './shots/blood/home.png'
import homeBlue from './shots/blue/home.png'
import homeJade from './shots/jade/home.png'
import homeCorn from './shots/corn/home.png'
import homeSilver from './shots/silver/home.png'
import homePink from './shots/pink/home.png'
import homeHarvest from './shots/harvest/home.png'
import homeCold from './shots/cold/home.png'
import songPlayerBlood from './shots/blood/song-player.png'
import songPlayerBlue from './shots/blue/song-player.png'
import songPlayerJade from './shots/jade/song-player.png'
import songPlayerCorn from './shots/corn/song-player.png'
import songPlayerSilver from './shots/silver/song-player.png'
import songPlayerPink from './shots/pink/song-player.png'
import songPlayerHarvest from './shots/harvest/song-player.png'
import songPlayerCold from './shots/cold/song-player.png'
import drillBlood from './shots/blood/drill.png'
import drillBlue from './shots/blue/drill.png'
import drillJade from './shots/jade/drill.png'
import drillCorn from './shots/corn/drill.png'
import drillSilver from './shots/silver/drill.png'
import drillPink from './shots/pink/drill.png'
import drillHarvest from './shots/harvest/drill.png'
import drillCold from './shots/cold/drill.png'
import routineBlood from './shots/blood/routine.png'
import routineBlue from './shots/blue/routine.png'
import routineJade from './shots/jade/routine.png'
import routineCorn from './shots/corn/routine.png'
import routineSilver from './shots/silver/routine.png'
import routinePink from './shots/pink/routine.png'
import routineHarvest from './shots/harvest/routine.png'
import routineCold from './shots/cold/routine.png'
import journalBlood from './shots/blood/journal.png'
import journalBlue from './shots/blue/journal.png'
import journalJade from './shots/jade/journal.png'
import journalCorn from './shots/corn/journal.png'
import journalSilver from './shots/silver/journal.png'
import journalPink from './shots/pink/journal.png'
import journalHarvest from './shots/harvest/journal.png'
import journalCold from './shots/cold/journal.png'
import todayBlood from './shots/blood/today.png'
import todayBlue from './shots/blue/today.png'
import todayJade from './shots/jade/today.png'
import todayCorn from './shots/corn/today.png'
import todaySilver from './shots/silver/today.png'
import todayPink from './shots/pink/today.png'
import todayHarvest from './shots/harvest/today.png'
import todayCold from './shots/cold/today.png'
import takeBlood from './shots/blood/take.png'
import takeBlue from './shots/blue/take.png'
import takeJade from './shots/jade/take.png'
import takeCorn from './shots/corn/take.png'
import takeSilver from './shots/silver/take.png'
import takePink from './shots/pink/take.png'
import takeHarvest from './shots/harvest/take.png'
import takeCold from './shots/cold/take.png'
import byEarBlood from './shots/blood/by-ear.png'
import byEarBlue from './shots/blue/by-ear.png'
import byEarJade from './shots/jade/by-ear.png'
import byEarCorn from './shots/corn/by-ear.png'
import byEarSilver from './shots/silver/by-ear.png'
import byEarPink from './shots/pink/by-ear.png'
import byEarHarvest from './shots/harvest/by-ear.png'
import byEarCold from './shots/cold/by-ear.png'
import sourcesBlood from './shots/blood/sources.png'
import sourcesBlue from './shots/blue/sources.png'
import sourcesJade from './shots/jade/sources.png'
import sourcesCorn from './shots/corn/sources.png'
import sourcesSilver from './shots/silver/sources.png'
import sourcesPink from './shots/pink/sources.png'
import sourcesHarvest from './shots/harvest/sources.png'
import sourcesCold from './shots/cold/sources.png'
import logBlood from './shots/blood/log.png'
import logBlue from './shots/blue/log.png'
import logJade from './shots/jade/log.png'
import logCorn from './shots/corn/log.png'
import logSilver from './shots/silver/log.png'
import logPink from './shots/pink/log.png'
import logHarvest from './shots/harvest/log.png'
import logCold from './shots/cold/log.png'

export const SHOTS = {
  home: {
    blood: homeBlood, blue: homeBlue, jade: homeJade, corn: homeCorn,
    silver: homeSilver, pink: homePink, harvest: homeHarvest, cold: homeCold,
  },
  'song-player': {
    blood: songPlayerBlood, blue: songPlayerBlue, jade: songPlayerJade, corn: songPlayerCorn,
    silver: songPlayerSilver, pink: songPlayerPink, harvest: songPlayerHarvest, cold: songPlayerCold,
  },
  drill: {
    blood: drillBlood, blue: drillBlue, jade: drillJade, corn: drillCorn,
    silver: drillSilver, pink: drillPink, harvest: drillHarvest, cold: drillCold,
  },
  routine: {
    blood: routineBlood, blue: routineBlue, jade: routineJade, corn: routineCorn,
    silver: routineSilver, pink: routinePink, harvest: routineHarvest, cold: routineCold,
  },
  journal: {
    blood: journalBlood, blue: journalBlue, jade: journalJade, corn: journalCorn,
    silver: journalSilver, pink: journalPink, harvest: journalHarvest, cold: journalCold,
  },
  today: {
    blood: todayBlood, blue: todayBlue, jade: todayJade, corn: todayCorn,
    silver: todaySilver, pink: todayPink, harvest: todayHarvest, cold: todayCold,
  },
  take: {
    blood: takeBlood, blue: takeBlue, jade: takeJade, corn: takeCorn,
    silver: takeSilver, pink: takePink, harvest: takeHarvest, cold: takeCold,
  },
  'by-ear': {
    blood: byEarBlood, blue: byEarBlue, jade: byEarJade, corn: byEarCorn,
    silver: byEarSilver, pink: byEarPink, harvest: byEarHarvest, cold: byEarCold,
  },
  sources: {
    blood: sourcesBlood, blue: sourcesBlue, jade: sourcesJade, corn: sourcesCorn,
    silver: sourcesSilver, pink: sourcesPink, harvest: sourcesHarvest, cold: sourcesCold,
  },
  log: {
    blood: logBlood, blue: logBlue, jade: logJade, corn: logCorn,
    silver: logSilver, pink: logPink, harvest: logHarvest, cold: logCold,
  },
} satisfies Record<string, MoonShots>

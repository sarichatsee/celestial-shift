/* game.js: LNS.Engine, the rules of Lunar Night Shift.
 *
 * No DOM access at all. Deterministic: no Math.random. The reference
 * implementation is tools/balance_sim.py; the turn order in takeTurn() follows
 * HANDOVER.md section 4.7 step by step and tests/run.js checks it against the
 * simulator's results.
 *
 * NO PEEKING: whether a storm really followed a flare (`followed`) is read in
 * exactly one place before a turn is played: resolveStorm(), which runs inside
 * takeTurn(). alertForTurn() and getState() never return it or anything
 * computed from it. getDebrief() shows it only for turns already played.
 */
(function (root) {
  "use strict";

  var LNS = root.LNS = root.LNS || {};

  // English fallbacks, used when text.js is not loaded (tests, console play).
  var FALLBACK_MESSAGES = {
    negative: "No negative power",
    lsMax: "Life support can't go above 5",
    noChargeNight: "No sunlight: you can't charge at night",
    noScienceShelter: "No science while sheltering",
    noAlert: "No storm alert this turn",
    shieldFull: "The shield is already full",
    noGreenhouse: "No greenhouse on this level",
    notEnoughPower: "Not enough power",
    levelOver: "This level is over"
  };
  var FALLBACK_TIPS = {
    lostAir: "Life support needs power every turn, even at night. Charge the battery in daylight.",
    lostDose: "Radiation never goes away. Build shielding, or shelter when a big flare is spotted.",
    lostFood: "Grow food while the sun shines: the greenhouse costs 1 power by day but 4 at night.",
    lostWater: "Keep life support at 3 or more so the water recycler keeps running.",
    highDose: "You made it, but your radiation is high. The next levels have more storms.",
    "default": "Great work. Could you earn more stars without losing safety?"
  };
  var HIGH_DOSE_TIP = 60; // the "your radiation is high" tip shows above this (section 7)
  var EPS = 1e-9;         // the battery is a float (charging adds 0.8 per power)

  var s = null;           // the whole game state
  var lastResult = null;  // the result that ended the current level, if it has ended

  // ---------------------------------------------------------------- helpers
  function P() { return LNS.NUMBERS; }

  function text(group, key, fallbacks) {
    var t = LNS.TEXT && LNS.TEXT[group];
    return (t && typeof t[key] === "string") ? t[key] : fallbacks[key];
  }
  function message(key) { return text("messages", key, FALLBACK_MESSAGES); }

  function ensure() { if (s === null) startGame(); }

  function levelDef(n) { return LNS.LEVELS[n - 1]; }

  function hasFood() { return !!levelDef(s.level).hasFood; }

  /** The saved real stretch of 2024 for level n, or null (Levels 1 and 2). */
  function stormWindow(n) {
    var def = levelDef(n);
    var all = LNS.STORMS && LNS.STORMS.windows;
    if (!def.window || !all || !all[def.window] || !all[def.window].length) return null;
    return all[def.window][0];
  }

  /** The saved record for the current turn, or null. Engine-internal: it holds `followed`. */
  function stormThisTurn() {
    var w = stormWindow(s.level);
    if (!w) return null;
    for (var i = 0; i < w.turns.length; i++) {
      if (w.turns[i].turn === s.turn) return w.turns[i];
    }
    return null;
  }

  function addDays(isoDate, days) {
    var p = isoDate.split("-");
    var d = new Date(Date.UTC(+p[0], +p[1] - 1, +p[2] + days));
    return d.toISOString().slice(0, 10);
  }

  // ---------------------------------------------------------------- levels
  function startGame() {
    s = { level: 1, dose: 0, shield: 0, shieldProgress: 0, stars: 0 };
    startLevel(1);
  }

  function startLevel(n) {
    var p = P();
    var food = !!levelDef(n).hasFood;
    s.level = n;
    s.turn = 1;
    s.battery = p.START_BATTERY;
    s.air = p.START_AIR;
    s.food = food ? p.FOOD_START : null;    // food and water reset each level,
    s.water = food ? p.WATER_START : null;  // like the battery and the air
    s.history = [];
    s.stormLog = [];
    s.phase = "playing";
    s.levelStart = { dose: s.dose, shield: s.shield, shieldProgress: s.shieldProgress, stars: s.stars };
    lastResult = null;
  }

  /** Same level again, with the dose, shield and stars it started with. */
  function retryLevel() {
    ensure();
    var keep = s.levelStart;
    s.dose = keep.dose;
    s.shield = keep.shield;
    s.shieldProgress = keep.shieldProgress;
    s.stars = keep.stars;
    startLevel(s.level);
  }

  /** Dose, shield, shield progress and stars carry over. Only after a level is won. */
  function nextLevel() {
    ensure();
    if (s.phase !== "level_won" || s.level >= LNS.LEVELS.length) return;
    startLevel(s.level + 1);
  }

  // ---------------------------------------------------------------- questions
  function getState() {
    ensure();
    return {
      level: s.level,
      levelCount: LNS.LEVELS.length,
      turn: s.turn,
      turnsPerLevel: P().TURNS_PER_LEVEL,
      isDay: isDay(),
      battery: s.battery,
      air: s.air,
      water: s.water,
      food: s.food,
      dose: s.dose,
      shield: s.shield,
      shieldProgress: s.shieldProgress,
      stars: s.stars
    };
  }

  function getLevelInfo() {
    ensure();
    var index = s.level - 1;
    var def = levelDef(s.level);
    var w = stormWindow(s.level);
    var start = w ? w.start : null;
    var named = LNS.TEXT && LNS.TEXT.levels && LNS.TEXT.levels[index];
    return {
      index: index,
      name: (named && named.name) || def.name,
      hasFood: !!def.hasFood,
      hasStorms: !!w,
      windowStart: start,
      /** The real dates a turn covers: {from, to}, both days included. */
      turnDates: function (turn) {
        if (!start) return null;
        return { from: addDays(start, 2 * (turn - 1)), to: addDays(start, 2 * turn - 1) };
      }
    };
  }

  function isDay() {
    ensure();
    return s.turn <= P().DAY_TURNS;
  }

  function powerAvailable() {
    ensure();
    return isDay() ? P().SOLAR_POWER : s.battery;
  }

  function totalSpend(plan) {
    var p = P();
    var spend = plan.lifeSupport + plan.shield + plan.science + plan.charge;
    if (plan.shelter) spend += p.SHELTER_COST;
    if (plan.greenhouse) spend += isDay() ? p.GREENHOUSE_DAY : p.GREENHOUSE_NIGHT;
    return spend;
  }

  /** "ok", or the first rule that fails (HANDOVER.md section 4.8). Changes nothing. */
  function checkPlan(plan) {
    ensure();
    var p = P();
    var amounts = [plan.lifeSupport, plan.shield, plan.science, plan.charge];
    for (var i = 0; i < amounts.length; i++) {
      if (typeof amounts[i] !== "number" || !(amounts[i] >= 0) || !isFinite(amounts[i])) {
        return message("negative");
      }
    }
    if (plan.lifeSupport > p.LS_MAX) return message("lsMax");
    if (!isDay() && plan.charge > 0) return message("noChargeNight");
    if (plan.shelter && plan.science > 0) return message("noScienceShelter");
    if (plan.shelter && stormThisTurn() === null) return message("noAlert");
    if (s.shield >= p.MAX_SHIELD && plan.shield > 0) return message("shieldFull");
    if (plan.greenhouse && !hasFood()) return message("noGreenhouse");
    if (totalSpend(plan) > powerAvailable() + EPS) return message("notEnoughPower");
    return "ok";
  }

  /** What the screen is ALLOWED to know about this turn's flare. Never `followed`. */
  function alertForTurn() {
    ensure();
    var storm = stormThisTurn();
    if (storm === null) return null;
    var chance = LNS.STORMS.chance[storm.shown.cls];
    return {
      cls: storm.shown.cls,
      fullClass: storm.shown.fullClass,
      date: storm.shown.peak.slice(0, 10),
      dots: chance.dots   // from the flare class alone (archive rate), same for every flare of that class
    };
  }

  // ---------------------------------------------------------------- one turn
  function addToShield(power) {
    var p = P();
    s.shieldProgress += power;
    while (s.shieldProgress >= p.SHIELD_COST && s.shield < p.MAX_SHIELD) {
      s.shield += 1;
      s.shieldProgress -= p.SHIELD_COST;
    }
  }

  /** What REALLY happened, from the saved record. The only reader of `followed`. */
  function resolveStorm(sheltered) {
    var storm = stormThisTurn();
    if (storm === null) return;
    var dose = 0;
    if (storm.followed) {
      dose = sheltered ? P().SHELTER_DOSE : P().DOSE_BY_SHIELD[s.shield];
    }
    s.dose += dose;
    s.stormLog.push({ turn: s.turn, sheltered: !!sheltered, dose: dose, record: storm });
  }

  function end(result) {
    s.phase = result.status;
    lastResult = result;
    return result;
  }

  function takeTurn(plan) {
    ensure();
    var p = P();
    // 1. check first, change second
    if (s.phase !== "playing") return { status: "invalid", message: message("levelOver") };
    var problem = checkPlan(plan);
    if (problem !== "ok") return { status: "invalid", message: problem };

    var day = isDay();
    var food = hasFood();
    // 2. at night the battery pays; by day the sun does
    if (!day) s.battery -= totalSpend(plan);
    // 3. air
    s.air = Math.max(0, Math.min(p.AIR_MAX, s.air + (plan.lifeSupport - p.LS_NEEDED) * p.AIR_PER_POWER));
    // 4. shield
    addToShield(plan.shield);
    // 5. science
    if (!plan.shelter) s.stars += plan.science;
    // 6. charging
    if (day) s.battery = Math.min(p.BATTERY_MAX, s.battery + plan.charge * p.CHARGE_EFFICIENCY);
    // 7. food and water
    if (food) {
      if (plan.greenhouse) {
        s.food += p.FOOD_PER_GREENHOUSE;
        s.water -= p.GREENHOUSE_WATER;
      }
      s.food -= p.FOOD_EATEN;
      s.water -= (plan.lifeSupport >= p.LS_NEEDED) ? p.WATER_USED : p.WATER_USED_NO_RECYCLER;
    }
    // 8. the real record decides
    resolveStorm(plan.shelter);
    // 9. history
    s.history.push({
      turn: s.turn, battery: s.battery, air: s.air, water: s.water, food: s.food, dose: s.dose,
      plan: {
        lifeSupport: plan.lifeSupport, shield: plan.shield, science: plan.science, charge: plan.charge,
        shelter: !!plan.shelter, greenhouse: !!plan.greenhouse
      }
    });
    // 10. lose checks, in this order
    if (s.air <= 0) return end({ status: "lost", reason: "air" });
    if (s.dose >= p.DOSE_LIMIT) return end({ status: "lost", reason: "dose" });
    if (food && s.food < 0) return end({ status: "lost", reason: "food" });
    if (food && s.water < 0) return end({ status: "lost", reason: "water" });
    // 11. the level ends after the last turn
    if (s.turn === p.TURNS_PER_LEVEL) {
      return end({ status: s.level === LNS.LEVELS.length ? "game_won" : "level_won" });
    }
    // 12. next turn
    s.turn += 1;
    return { status: "continue" };
  }

  // ---------------------------------------------------------------- debrief
  function getDebrief(result) {
    ensure();
    result = result || lastResult || { status: "continue" };
    var p = P();
    var food = hasFood();
    var w = stormWindow(s.level);
    var played = s.history.length;

    var history = s.history.map(function (h) {
      return { turn: h.turn, battery: h.battery, air: h.air, water: h.water, food: h.food, dose: h.dose };
    });

    // Only turns already played are in the log, so `followed` may be shown here.
    var storms = s.stormLog.map(function (entry) {
      var rec = entry.record;
      return {
        turn: entry.turn,
        fullClass: rec.shown.fullClass,
        date: rec.shown.peak.slice(0, 10),
        link: rec.shown.link,
        followed: rec.followed,
        sheltered: entry.sheltered,
        dose: entry.dose,
        causes: rec.flares.filter(function (f) { return f.followed; }).map(function (f) {
          return { fullClass: f.fullClass, date: f.peak.slice(0, 10), link: f.link };
        })
      };
    });

    // Measured radiation at the Moon, for the chart. Turns not yet played stay
    // hidden (null) so a lost level's debrief can't show storms still to come.
    var moonDose = null;
    if (w && w.moonDose) {
      moonDose = w.moonDose.map(function (v, i) { return i < played ? v : null; });
    }

    var recyclerSaved = null;
    if (food) {
      var turnsOn = s.history.filter(function (h) { return h.plan.lifeSupport >= p.LS_NEEDED; }).length;
      recyclerSaved = turnsOn * (p.WATER_USED_NO_RECYCLER - p.WATER_USED);
    }

    var tipKey = "default";
    if (result.status === "lost") {
      tipKey = { air: "lostAir", dose: "lostDose", food: "lostFood", water: "lostWater" }[result.reason] || "default";
    } else if (s.dose > HIGH_DOSE_TIP) {
      tipKey = "highDose";
    }

    return {
      result: result,
      levelIndex: s.level - 1,
      history: history,
      storms: storms,
      moonDose: moonDose,
      stormTurns: storms.filter(function (st) { return st.followed; }).map(function (st) { return st.turn; }),
      recyclerSaved: recyclerSaved,
      tipKey: tipKey,
      tip: text("tips", tipKey, FALLBACK_TIPS)
    };
  }

  LNS.Engine = {
    startGame: startGame,
    getState: getState,
    getLevelInfo: getLevelInfo,
    isDay: isDay,
    powerAvailable: powerAvailable,
    totalSpend: function (plan) { ensure(); return totalSpend(plan); },
    checkPlan: checkPlan,
    alertForTurn: alertForTurn,
    takeTurn: takeTurn,
    getDebrief: getDebrief,
    nextLevel: nextLevel,
    retryLevel: retryLevel
  };
})(globalThis);

#!/usr/bin/env node
/* Tests for Lunar Night Shift. Node built-ins only: `node tests/run.js`.
 *
 * The game files are classic scripts that attach to globalThis.LNS, so each
 * test loads them into a fresh `vm` context, exactly as a browser would load
 * them into a fresh page.
 */
"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");
const assert = require("assert");

const ROOT = path.join(__dirname, "..");
const GAME = path.join(ROOT, "game");
const ENGINE_FILES = ["data.js", "storms.js", "game.js"];

// ---------------------------------------------------------------- tiny harness
const results = { passed: 0, failed: [] };
let currentGroup = "";

function group(name) { currentGroup = name; }

function test(name, fn) {
  try {
    fn();
    results.passed += 1;
  } catch (err) {
    results.failed.push({ name: currentGroup + " > " + name, err: err });
  }
}

/** Load game scripts into a fresh context. Options:
 *  files    which scripts, in order (default: the engine and its data)
 *  numbers  test-only overrides of LNS.NUMBERS (never used for parity)
 *  storms   function(STORMS) that edits the loaded storm data (test-only) */
function loadGame(opts) {
  opts = opts || {};
  const ctx = vm.createContext({});
  for (const file of opts.files || ENGINE_FILES) {
    vm.runInContext(fs.readFileSync(path.join(GAME, file), "utf8"), ctx, { filename: "game/" + file });
    if (file === "data.js" && opts.numbers) Object.assign(ctx.LNS.NUMBERS, opts.numbers);
    if (file === "storms.js" && opts.storms) opts.storms(ctx.LNS.STORMS);
  }
  return ctx.LNS;
}

function newEngine(opts) {
  const LNS = loadGame(opts);
  LNS.Engine.startGame();
  return LNS.Engine;
}

function plan(over) {
  return Object.assign({ lifeSupport: 0, shield: 0, science: 0, charge: 0, shelter: false, greenhouse: false }, over || {});
}

/** Objects from another vm context have other prototypes, so compare as JSON. */
function same(actual, expected, msg) {
  assert.strictEqual(JSON.stringify(actual), JSON.stringify(expected), msg || "not the same");
}

function near(actual, expected, msg) {
  msg = msg || "";
  assert.ok(Math.abs(actual - expected) < 1e-9, (msg || "") + " expected " + expected + ", got " + actual);
}

/** Play `count` turns with the same plan (or a function of the state). Returns the last result. */
function playTurns(E, count, planOrFn) {
  let result = null;
  for (let i = 0; i < count; i++) {
    const pl = typeof planOrFn === "function" ? planOrFn(E.getState()) : planOrFn;
    result = E.takeTurn(pl);
    assert.notStrictEqual(result.status, "invalid", "turn " + E.getState().turn + ": " + result.message);
  }
  return result;
}

/** A careful, legal way through one level: enough charge for the night. */
function carefulPlan(st) {
  if (st.isDay) {
    return plan({ lifeSupport: 3, charge: 4, greenhouse: st.food !== null, science: st.food !== null ? 2 : 3 });
  }
  return plan({ lifeSupport: 3 });
}

function winLevel(E) {
  return playTurns(E, 14, carefulPlan);
}

/** Skip the day: 7 turns of holding Air steady and charging a little. */
function toNight(E, charge) {
  playTurns(E, 7, plan({ lifeSupport: 3, charge: charge === undefined ? 4 : charge }));
  assert.strictEqual(E.isDay(), false);
}

// ---------------------------------------------------------------- checkPlan (section 4.8)
group("checkPlan");

test("a sensible plan is ok", () => {
  const E = newEngine();
  assert.strictEqual(E.checkPlan(plan({ lifeSupport: 3, science: 3, charge: 4 })), "ok");
});

test("rule 1: no negative power", () => {
  const E = newEngine();
  for (const key of ["lifeSupport", "shield", "science", "charge"]) {
    assert.strictEqual(E.checkPlan(plan({ [key]: -1 })), "No negative power", key);
  }
});

test("rule 2: life support can't go above 5", () => {
  const E = newEngine();
  assert.strictEqual(E.checkPlan(plan({ lifeSupport: 6 })), "Life support can't go above 5");
  assert.strictEqual(E.checkPlan(plan({ lifeSupport: 5 })), "ok");
});

test("rule 3: no charging at night", () => {
  const E = newEngine();
  assert.strictEqual(E.checkPlan(plan({ lifeSupport: 3, charge: 1 })), "ok");
  toNight(E);
  assert.strictEqual(E.checkPlan(plan({ lifeSupport: 3, charge: 1 })), "No sunlight: you can't charge at night");
});

test("rule 4: no science while sheltering (checked before rule 5)", () => {
  const E = newEngine();
  assert.strictEqual(E.checkPlan(plan({ shelter: true, science: 1 })), "No science while sheltering");
});

test("rule 5: no shelter without an alert", () => {
  const E = newEngine();
  assert.strictEqual(E.alertForTurn(), null);
  assert.strictEqual(E.checkPlan(plan({ lifeSupport: 3, shelter: true })), "No storm alert this turn");
});

test("rule 6: the shield is already full", () => {
  const E = newEngine();
  playTurns(E, 4, plan({ lifeSupport: 3, shield: 6 }));   // 24 power = 3 levels
  assert.strictEqual(E.getState().shield, 3);
  assert.strictEqual(E.checkPlan(plan({ lifeSupport: 3, shield: 1 })), "The shield is already full");
});

test("rule 7: no greenhouse on Level 1", () => {
  const E = newEngine();
  assert.strictEqual(E.checkPlan(plan({ lifeSupport: 3, greenhouse: true })), "No greenhouse on this level");
});

test("rule 8: not enough power, by day and at night", () => {
  const E = newEngine();
  assert.strictEqual(E.checkPlan(plan({ lifeSupport: 5, science: 5 })), "ok");
  assert.strictEqual(E.checkPlan(plan({ lifeSupport: 5, science: 6 })), "Not enough power");
  toNight(E, 0);                                           // battery still 10
  assert.strictEqual(E.checkPlan(plan({ lifeSupport: 5, science: 5 })), "ok");
  assert.strictEqual(E.checkPlan(plan({ lifeSupport: 5, science: 6 })), "Not enough power");
});

test("an invalid plan changes nothing", () => {
  const E = newEngine();
  playTurns(E, 2, plan({ lifeSupport: 3, shield: 3, charge: 2, science: 2 }));
  const before = JSON.stringify([E.getState(), E.getDebrief()]);
  const bad = [
    plan({ lifeSupport: -1 }), plan({ lifeSupport: 6 }), plan({ shelter: true, science: 2 }),
    plan({ lifeSupport: 3, shelter: true }), plan({ lifeSupport: 3, greenhouse: true }),
    plan({ lifeSupport: 5, science: 9 })
  ];
  for (const pl of bad) {
    const result = E.takeTurn(pl);
    assert.strictEqual(result.status, "invalid");
    assert.strictEqual(typeof result.message, "string");
    assert.strictEqual(JSON.stringify([E.getState(), E.getDebrief()]), before);
  }
});

// ---------------------------------------------------------------- the controls (section 4.4)
group("controls");

test("life support 3 holds Air steady", () => {
  const E = newEngine();
  playTurns(E, 3, plan({ lifeSupport: 3 }));
  assert.strictEqual(E.getState().air, 60);
});

test("life support below 3 drains Air 8 per missing point", () => {
  const E = newEngine();
  E.takeTurn(plan({ lifeSupport: 2 }));
  assert.strictEqual(E.getState().air, 52);
  E.takeTurn(plan({ lifeSupport: 0 }));
  assert.strictEqual(E.getState().air, 28);
});

test("life support above 3 adds 8 Air per point, never above 60", () => {
  const E = newEngine();
  playTurns(E, 2, plan({ lifeSupport: 1 }));               // 60 -> 28
  E.takeTurn(plan({ lifeSupport: 4 }));
  assert.strictEqual(E.getState().air, 36);
  E.takeTurn(plan({ lifeSupport: 5 }));
  assert.strictEqual(E.getState().air, 52);
  E.takeTurn(plan({ lifeSupport: 5 }));
  assert.strictEqual(E.getState().air, 60);
});

test("Air at 0 ends the level (lost/air)", () => {
  const E = newEngine();
  const result = playTurns(E, 3, plan({ lifeSupport: 0 }));  // 60 -> 36 -> 12 -> 0
  same(result, { status: "lost", reason: "air" });
  assert.strictEqual(E.getState().air, 0);
});

test("shield: 8 power per level, can be spread over turns, max 3", () => {
  const E = newEngine();
  E.takeTurn(plan({ lifeSupport: 3, shield: 5 }));
  same([E.getState().shield, E.getState().shieldProgress], [0, 5]);
  E.takeTurn(plan({ lifeSupport: 3, shield: 5 }));
  same([E.getState().shield, E.getState().shieldProgress], [1, 2]);
  playTurns(E, 2, plan({ lifeSupport: 3, shield: 7 }));
  same([E.getState().shield, E.getState().shieldProgress], [3, 0]);
});

test("science: 1 power is 1 star", () => {
  const E = newEngine();
  E.takeTurn(plan({ lifeSupport: 3, science: 7 }));
  assert.strictEqual(E.getState().stars, 7);
});

test("charge: 1 power puts 0.8 in the battery, capped at 40", () => {
  const E = newEngine();
  E.takeTurn(plan({ lifeSupport: 3, charge: 5 }));
  near(E.getState().battery, 14);
  playTurns(E, 6, plan({ lifeSupport: 3, charge: 7 }));    // would reach 47.6
  assert.strictEqual(E.getState().battery, 40);
});

test("day power you don't spend is lost", () => {
  const E = newEngine();
  E.takeTurn(plan({ lifeSupport: 3 }));                    // 7 of 10 unspent
  assert.strictEqual(E.getState().battery, 10);
  assert.strictEqual(E.powerAvailable(), 10);
});

test("by day the sun pays; at night the battery pays", () => {
  const E = newEngine();
  assert.strictEqual(E.isDay(), true);
  assert.strictEqual(E.powerAvailable(), 10);
  toNight(E, 5);                                           // 10 + 7 * 4 = 38
  near(E.getState().battery, 38);
  near(E.powerAvailable(), 38);
  E.takeTurn(plan({ lifeSupport: 3, science: 2, shield: 1 }));
  near(E.getState().battery, 32);
  assert.strictEqual(E.getState().stars, 2);
});

test("turns 1 to 7 are day, 8 to 14 are night", () => {
  const E = newEngine();
  const days = [];
  for (let turn = 1; turn <= 14; turn++) {
    assert.strictEqual(E.getState().turn, turn);
    days.push(E.getState().isDay);
    E.takeTurn(carefulPlan(E.getState()));
  }
  same(days, [true, true, true, true, true, true, true, false, false, false, false, false, false, false]);
});

test("totalSpend adds everything up (greenhouse 1 by day, 4 at night)", () => {
  const E = newEngine();
  playTurns(E, 14, carefulPlan);
  E.nextLevel();
  const pl = plan({ lifeSupport: 3, shield: 2, science: 1, charge: 1, greenhouse: true });
  assert.strictEqual(E.totalSpend(pl), 8);
  toNight(E);
  assert.strictEqual(E.totalSpend(plan({ lifeSupport: 3, greenhouse: true })), 7);
});

// ---------------------------------------------------------------- food and water (section 4.6)
group("food and water");

function levelTwo(opts) {
  const E = newEngine(opts);
  same(winLevel(E), { status: "level_won" });
  E.nextLevel();
  assert.strictEqual(E.getState().level, 2);
  return E;
}

test("Level 1 has no food or water", () => {
  const E = newEngine();
  same([E.getState().food, E.getState().water], [null, null]);
  same([E.getLevelInfo().hasFood, E.getLevelInfo().hasStorms], [false, false]);
});

test("Level 2 starts with 16 food and 30 water", () => {
  const E = levelTwo();
  same([E.getState().food, E.getState().water], [16, 30]);
  assert.strictEqual(E.getLevelInfo().hasFood, true);
});

test("the crew eats 2 food per turn; the recycler keeps water at 1 per turn", () => {
  const E = levelTwo();
  E.takeTurn(plan({ lifeSupport: 3 }));
  same([E.getState().food, E.getState().water], [14, 29]);
});

test("recycler off (life support below 3): 2 water per turn", () => {
  const E = levelTwo();
  E.takeTurn(plan({ lifeSupport: 2 }));
  same([E.getState().food, E.getState().water], [14, 28]);
});

test("greenhouse: +3 food, plants drink 1 more water, 1 power by day", () => {
  const E = levelTwo();
  assert.strictEqual(E.checkPlan(plan({ lifeSupport: 5, science: 4, greenhouse: true })), "ok");
  assert.strictEqual(E.checkPlan(plan({ lifeSupport: 5, science: 5, greenhouse: true })), "Not enough power");
  E.takeTurn(plan({ lifeSupport: 3, greenhouse: true }));
  same([E.getState().food, E.getState().water], [17, 28]);
});

test("greenhouse at night costs 4 from the battery", () => {
  const E = levelTwo();
  toNight(E, 5);                                           // battery 38
  E.takeTurn(plan({ lifeSupport: 3, greenhouse: true }));
  near(E.getState().battery, 31);
});

test("no greenhouse: food runs out on turn 9 (lost/food)", () => {
  const E = levelTwo();
  let result = playTurns(E, 8, (st) => plan({ lifeSupport: 3, charge: st.isDay ? 4 : 0 }));
  same(result, { status: "continue" });
  assert.strictEqual(E.getState().food, 0);
  result = E.takeTurn(plan({ lifeSupport: 3 }));
  same(result, { status: "lost", reason: "food" });
});

test("water below 0 ends the level (lost/water)", () => {
  // Water is a calm meter: with the real numbers careful play never runs out,
  // so this test uses a smaller tank (test-only override) to reach the check.
  const E = levelTwo({ numbers: { WATER_START: 3 } });
  let result = playTurns(E, 3, plan({ lifeSupport: 3 }));
  same(result, { status: "continue" });
  assert.strictEqual(E.getState().water, 0);
  result = E.takeTurn(plan({ lifeSupport: 3 }));
  same(result, { status: "lost", reason: "water" });
});

test("lose checks run in order: air before food", () => {
  const E = levelTwo({ numbers: { FOOD_START: 4, START_AIR: 24 } });
  const result = playTurns(E, 3, plan({ lifeSupport: 2 }));  // air 0 and food -2 on the same turn
  same(result, { status: "lost", reason: "air" });
});

test("the debrief counts the water the recycler saved", () => {
  const E = levelTwo();
  playTurns(E, 2, plan({ lifeSupport: 3 }));
  E.takeTurn(plan({ lifeSupport: 2 }));
  E.takeTurn(plan({ lifeSupport: 4 }));
  assert.strictEqual(E.getDebrief().recyclerSaved, 3);
});

// ---------------------------------------------------------------- levels (sections 4.3, 4.9)
group("levels");

test("a level is won after turn 14", () => {
  const E = newEngine();
  const result = playTurns(E, 13, carefulPlan);
  same(result, { status: "continue" });
  same(E.takeTurn(carefulPlan(E.getState())), { status: "level_won" });
});

test("no more turns after a level ends", () => {
  const E = newEngine();
  winLevel(E);
  const before = JSON.stringify(E.getState());
  assert.strictEqual(E.takeTurn(plan({ lifeSupport: 3 })).status, "invalid");
  assert.strictEqual(JSON.stringify(E.getState()), before);
});

test("next level: shield, shield progress and stars carry over; battery, Air, food and water reset", () => {
  const E = newEngine();
  playTurns(E, 14, (st) => st.isDay
    ? plan({ lifeSupport: 2, charge: 4, shield: 2, science: 2 })   // 14 shield power, Air drains by day
    : plan({ lifeSupport: 3 }));
  const end = E.getState();
  same([end.shield, end.shieldProgress, end.stars, end.air], [1, 6, 14, 4]);
  E.nextLevel();
  const st = E.getState();
  same([st.level, st.turn, st.isDay], [2, 1, true]);
  same([st.shield, st.shieldProgress, st.stars, st.dose], [1, 6, 14, 0]);
  same([st.battery, st.air, st.food, st.water], [10, 60, 16, 30]);
});

test("nextLevel does nothing unless the level was won", () => {
  const E = newEngine();
  E.takeTurn(plan({ lifeSupport: 3 }));
  E.nextLevel();
  same([E.getState().level, E.getState().turn], [1, 2]);
});

test("retry restores the values the level started with", () => {
  const E = levelTwo();
  const start = E.getState();
  playTurns(E, 3, plan({ lifeSupport: 0, shield: 5, science: 5 }));   // loses on Air
  assert.notStrictEqual(E.getState().stars, start.stars);
  E.retryLevel();
  same(E.getState(), start);
  same(E.getDebrief().history, []);
  assert.strictEqual(E.takeTurn(plan({ lifeSupport: 3 })).status, "continue");
});

test("startGame starts over at Level 1", () => {
  const E = levelTwo();
  E.startGame();
  const st = E.getState();
  same([st.level, st.turn, st.stars, st.shield, st.shieldProgress, st.dose], [1, 1, 0, 0, 0, 0]);
});

test("getState returns a copy", () => {
  const E = newEngine();
  const st = E.getState();
  st.air = 1; st.stars = 999; st.turn = 14;
  same([E.getState().air, E.getState().stars, E.getState().turn], [60, 0, 1]);
});

test("getState has exactly the documented keys", () => {
  const E = newEngine();
  same(Object.keys(E.getState()), ["level", "levelCount", "turn", "turnsPerLevel", "isDay", "battery", "air",
    "water", "food", "dose", "shield", "shieldProgress", "stars"]);
  same([E.getState().levelCount, E.getState().turnsPerLevel], [4, 14]);
});

test("debrief: history and tips", () => {
  const E = newEngine();
  playTurns(E, 2, plan({ lifeSupport: 3, charge: 5 }));
  let d = E.getDebrief();
  same(d.history.map((h) => h.turn), [1, 2]);
  same(Object.keys(d.history[0]), ["turn", "battery", "air", "water", "food", "dose"]);
  same([d.levelIndex, d.recyclerSaved, d.moonDose, d.tipKey], [0, null, null, "default"]);
  const result = playTurns(E, 3, plan({ lifeSupport: 0 }));
  d = E.getDebrief(result);
  same([d.result.status, d.tipKey], ["lost", "lostAir"]);
  assert.ok(d.tip.indexOf("Life support needs power every turn") === 0);
});

// ---------------------------------------------------------------- storms.js (section 5.4)
group("storms data");

const WINDOW_TABLES = {
  // turn, shown flare, peak (UTC), storm followed, alerts in turn
  spaceWeather: { start: "2024-01-13", rows: [
    [6, "M5.1", "2024-01-23T03:31Z", false, 1],
    [9, "M6.8", "2024-01-29T04:38Z", true, 1],
    [13, "M5.1", "2024-02-07T03:31Z", false, 1],
    [14, "X3.3", "2024-02-09T13:14Z", true, 1]
  ] },
  bigOne: { start: "2024-05-05", rows: [
    [1, "X4.5", "2024-05-06T06:35Z", false, 5],
    [2, "X1.0", "2024-05-08T01:41Z", true, 9],
    [3, "X3.9", "2024-05-10T06:54Z", true, 4],
    [4, "X5.8", "2024-05-11T01:23Z", true, 4],
    [5, "X8.7", "2024-05-14T16:51Z", true, 4],
    [6, "X3.4", "2024-05-15T08:37Z", false, 2],
    [7, "M7.2", "2024-05-17T21:08Z", false, 1],
    [12, "X2.8", "2024-05-27T07:08Z", false, 1],
    [13, "X1.4", "2024-05-29T14:37Z", false, 2],
    [14, "X1.4", "2024-06-01T08:48Z", false, 4]
  ] }
};

for (const key of Object.keys(WINDOW_TABLES)) {
  test("default " + key + " window matches the handover table", () => {
    const w = loadGame().STORMS.windows[key][0];
    assert.strictEqual(w.start, WINDOW_TABLES[key].start);
    same(w.turns.map((t) => [t.turn, t.shown.fullClass, t.shown.peak, t.followed, t.flares.length]),
      WINDOW_TABLES[key].rows);
  });
}

test("every saved turn is well formed and comes with a DONKI link", () => {
  const STORMS = loadGame().STORMS;
  for (const key of Object.keys(STORMS.windows)) {
    for (const w of STORMS.windows[key]) {
      assert.ok(/^\d{4}-\d{2}-\d{2}$/.test(w.start));
      assert.ok(w.moonDose === null || w.moonDose.length === 14);
      for (const t of w.turns) {
        assert.ok(t.turn >= 1 && t.turn <= 14);
        assert.strictEqual(t.shown.cls, t.shown.fullClass[0]);
        assert.strictEqual(t.followed, t.flares.some((f) => f.followed));
        for (const f of t.flares.concat([t.shown])) {
          assert.ok(/^[XM]\d+(\.\d+)?$/.test(f.fullClass), f.fullClass);
          assert.ok(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}Z$/.test(f.peak), f.peak);
          assert.ok(f.link.indexOf("https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/") === 0, f.link);
          // the flare's peak is inside the turn's two real days
          const days = (Date.parse(f.peak) - Date.parse(w.start + "T00:00Z")) / 86400000;
          assert.strictEqual(Math.floor(days / 2) + 1, t.turn);
        }
        // the shown flare is the strongest in the turn (X beats M, then magnitude)
        const power = (c) => (c[0] === "X" ? 1000 : 0) + parseFloat(c.slice(1));
        assert.ok(t.flares.every((f) => power(f.fullClass) <= power(t.shown.fullClass)));
      }
    }
  }
});

test("storm chance: 14 of 54 X flares (3 dots), 9 of 82 M5+ flares (1 dot)", () => {
  same(loadGame().STORMS.chance, { X: { followed: 14, total: 54, dots: 3 }, M: { followed: 9, total: 82, dots: 1 } });
});

test("Moon dose and Sun snapshot are real saved numbers or null (offline build)", () => {
  const STORMS = loadGame().STORMS;
  assert.ok(/^\d{4}-\d{2}-\d{2}$/.test(STORMS.savedOn));
  const doses = [];
  for (const key of Object.keys(STORMS.windows)) {
    for (const w of STORMS.windows[key]) if (w.moonDose) doses.push(w.moonDose);
  }
  for (const dose of doses) assert.ok(dose.every((v) => v === null || (typeof v === "number" && v > 0)));
  assert.strictEqual(STORMS.moonQuiet === null, doses.length === 0);
  const snap = STORMS.liveSnapshot;
  if (snap !== null) {
    same(Object.keys(snap), ["savedOn", "windowDays", "bigFlares", "latest", "particleStorms"]);
    assert.ok(/^\d{4}-\d{2}-\d{2}$/.test(snap.savedOn) && snap.windowDays === 30);
    assert.ok(Number.isInteger(snap.bigFlares) && Number.isInteger(snap.particleStorms));
  }
});

test("The Big One has at least 3 storm turns", () => {
  for (const w of loadGame().STORMS.windows.bigOne) {
    assert.ok(w.turns.filter((t) => t.followed).length >= 3, w.start);
  }
});

// ---------------------------------------------------------------- storms in the engine (section 4.5)
group("storms");

/** A fresh game at the start of the given level (never sheltering on the way, to keep it simple). */
function atLevel(n, opts) {
  const E = newEngine(opts);
  while (E.getState().level < n) {
    same(playTurns(E, 14, (st) => {
      const pl = carefulPlan(st);
      if (E.alertForTurn()) { pl.shelter = true; pl.science = 0; }
      return pl;
    }), { status: "level_won" });
    E.nextLevel();
  }
  return E;
}

/** Play careful turns (staying in the main base) until the given turn is the current one. */
function untilTurn(E, turn) {
  while (E.getState().turn < turn) playTurns(E, 1, carefulPlan);
}

test("Levels 1 and 2 have no alerts; Levels 3 and 4 have the real ones", () => {
  const E = newEngine();
  const seen = {};
  for (let level = 1; level <= 4; level++) {
    seen[level] = [];
    for (let turn = 1; turn <= 14; turn++) {
      const alert = E.alertForTurn();
      if (alert) seen[level].push(turn);
      const pl = carefulPlan(E.getState());
      if (alert) { pl.shelter = true; pl.science = 0; }
      E.takeTurn(pl);
    }
    E.nextLevel();
  }
  same(seen, { 1: [], 2: [], 3: [6, 9, 13, 14], 4: [1, 2, 3, 4, 5, 6, 7, 12, 13, 14] });
});

test("the alert shows the class, the real date and dots, and nothing else", () => {
  const E = atLevel(3);
  untilTurn(E, 6);
  same(E.alertForTurn(), { cls: "M", fullClass: "M5.1", date: "2024-01-23", dots: 1 });
  const E4 = atLevel(4);
  same(E4.alertForTurn(), { cls: "X", fullClass: "X4.5", date: "2024-05-06", dots: 3 });
});

test("level info: real window and turn dates", () => {
  const E = atLevel(3);
  const info = E.getLevelInfo();
  same([info.index, info.name, info.hasFood, info.hasStorms, info.windowStart], [2, "Space Weather", true, true, "2024-01-13"]);
  same(info.turnDates(1), { from: "2024-01-13", to: "2024-01-14" });
  same(info.turnDates(6), { from: "2024-01-23", to: "2024-01-24" });
  same(info.turnDates(14), { from: "2024-02-08", to: "2024-02-09" });
  same(atLevel(4).getLevelInfo().turnDates(14), { from: "2024-05-31", to: "2024-06-01" });
  assert.strictEqual(newEngine().getLevelInfo().turnDates(3), null);
});

test("stay + a real storm: radiation by shield level (20 with no shield)", () => {
  const E = atLevel(3);
  untilTurn(E, 9);
  assert.strictEqual(E.getState().dose, 0);
  E.takeTurn(plan({ lifeSupport: 3 }));
  assert.strictEqual(E.getState().dose, 20);
});

test("shelter + a real storm: radiation 1.5, costs 1 power", () => {
  const E = atLevel(3);
  untilTurn(E, 9);
  const battery = E.getState().battery;
  assert.strictEqual(E.totalSpend(plan({ lifeSupport: 3, shelter: true })), 4);
  E.takeTurn(plan({ lifeSupport: 3, shelter: true }));
  assert.strictEqual(E.getState().dose, 1.5);
  near(E.getState().battery, battery - 4);
});

test("shelter: no science that turn", () => {
  const E = atLevel(3);
  untilTurn(E, 6);
  assert.strictEqual(E.checkPlan(plan({ lifeSupport: 3, shelter: true, science: 1 })), "No science while sheltering");
  assert.strictEqual(E.checkPlan(plan({ lifeSupport: 3, shelter: true, charge: 6 })), "ok");
  assert.strictEqual(E.checkPlan(plan({ lifeSupport: 3, shelter: true, charge: 7 })), "Not enough power");
});

test("false alarm: no radiation, sheltered or not", () => {
  for (const shelter of [true, false]) {
    const E = atLevel(3);
    untilTurn(E, 6);
    E.takeTurn(plan({ lifeSupport: 3, shelter: shelter }));
    assert.strictEqual(E.getState().dose, 0);
    same(E.getDebrief().storms.map((st) => [st.turn, st.followed, st.sheltered, st.dose]), [[6, false, shelter, 0]]);
  }
});

test("the shield counts after this turn's building: 13 / 9 / 5", () => {
  const expected = [20, 13, 9, 5];
  for (let levels = 0; levels <= 3; levels++) {
    // build the shield in the daylight of Level 1, then carry it to Level 4
    const E = newEngine();
    let left = levels * 8;
    playTurns(E, 14, (st) => {
      if (!st.isDay) return plan({ lifeSupport: 3 });
      const shield = Math.min(4, left);
      left -= shield;
      return plan({ lifeSupport: 3, charge: 3, shield: shield });
    });
    E.nextLevel();
    for (let level = 2; level <= 3; level++) {
      playTurns(E, 14, (st) => Object.assign(carefulPlan(st), E.alertForTurn() ? { shelter: true, science: 0 } : {}));
      E.nextLevel();
    }
    same([E.getState().level, E.getState().shield], [4, levels]);
    E.takeTurn(plan({ lifeSupport: 3 }));                  // turn 1: a false alarm
    const before = E.getState().dose;
    E.takeTurn(plan({ lifeSupport: 3 }));                  // turn 2: a real storm, staying in the main base
    assert.strictEqual(E.getState().dose - before, expected[levels]);
  }
  const E = atLevel(4);
  const before = E.getState().dose;
  E.takeTurn(plan({ lifeSupport: 3 }));
  assert.strictEqual(E.takeTurn(plan({ lifeSupport: 2, shield: 8 })).status, "continue");  // built on the storm turn itself
  same([E.getState().shield, E.getState().dose - before], [1, 13]);
});

test("radiation carries over to the next level and never goes down", () => {
  const E = atLevel(3);
  let last = 0;
  for (let turn = 1; turn <= 14; turn++) {
    E.takeTurn(carefulPlan(E.getState()));
    assert.ok(E.getState().dose >= last);
    last = E.getState().dose;
  }
  assert.strictEqual(last, 40);
  E.nextLevel();
  same([E.getState().level, E.getState().dose], [4, 40]);
});

test("radiation at 100 ends the level (lost/dose); retry restores the level's starting dose", () => {
  const E = atLevel(3);
  playTurns(E, 14, carefulPlan);                           // 40
  E.nextLevel();
  const result = playTurns(E, 4, carefulPlan);             // 60, 80, 100 on turns 2, 3, 4
  same(result, { status: "lost", reason: "dose" });
  const d = E.getDebrief(result);
  same([d.tipKey, d.stormTurns], ["lostDose", [2, 3, 4]]);
  E.retryLevel();
  same([E.getState().level, E.getState().turn, E.getState().dose], [4, 1, 40]);
});

test("a win with radiation above 60 gets the high-radiation tip", () => {
  const E = atLevel(4);                                    // sheltered through Level 3: 3.0
  playTurns(E, 4, carefulPlan);                            // + 20 on turns 2, 3 and 4
  assert.strictEqual(E.getState().dose, 63);
  assert.strictEqual(E.getDebrief({ status: "level_won" }).tipKey, "highDose");
  const calm = atLevel(4);
  playTurns(calm, 3, carefulPlan);                         // 43
  assert.strictEqual(calm.getDebrief({ status: "level_won" }).tipKey, "default");
});

test("debrief storm cards: real date, class, link, and which flare caused the storm", () => {
  const E = atLevel(4);
  playTurns(E, 4, (st) => plan({ lifeSupport: 3, shelter: true, charge: 6 }));
  E.takeTurn(plan({ lifeSupport: 3, charge: 4 }));         // turn 5: stay
  const d = E.getDebrief();
  same(d.storms.map((st) => st.turn), [1, 2, 3, 4, 5]);
  const card = d.storms[4];
  same(Object.keys(card), ["turn", "fullClass", "date", "link", "followed", "sheltered", "dose", "causes"]);
  same([card.fullClass, card.date, card.followed, card.sheltered, card.dose], ["X8.7", "2024-05-14", true, false, 20]);
  assert.ok(card.link.indexOf("https://ccmc.gsfc.nasa.gov/DONKI/view/FLR/") === 0);
  // In this turn the X8.7 shown did not bring the storm: another flare did.
  assert.ok(card.causes.length >= 1);
  assert.ok(card.causes.every((c) => c.fullClass !== "X8.7"));
  same(Object.keys(card.causes[0]), ["fullClass", "date", "link"]);
  same(d.storms[0].causes, []);                            // turn 1 was a false alarm
  same(d.stormTurns, [2, 3, 4, 5]);
});

// ---------------------------------------------------------------- no peeking (sections 4.5, 9.1)
group("no peeking");

function deepKeys(value, out) {
  out = out || [];
  if (value && typeof value === "object") {
    for (const key of Object.keys(value)) { out.push(key); deepKeys(value[key], out); }
  }
  return out;
}

/** Everything the screen may ask before a turn, on every turn of every level. */
function visibleBeforeEachTurn(opts) {
  const E = newEngine(opts);
  const seen = [];
  for (let level = 1; level <= 4; level++) {
    for (let turn = 1; turn <= 14; turn++) {
      const st = E.getState();
      const alert = E.alertForTurn();
      const info = E.getLevelInfo();
      const pl = carefulPlan(st);
      pl.charge = st.isDay ? 5 : 0; pl.science = 0;          // enough battery to shelter all night
      if (alert) pl.shelter = true;
      seen.push({ state: st, alert: alert, info: info, dates: info.turnDates(turn), check: E.checkPlan(pl),
        power: E.powerAvailable(), spend: E.totalSpend(pl) });
      const result = E.takeTurn(pl);
      assert.ok(result.status === "continue" || result.status === "level_won" || result.status === "game_won",
        "L" + level + " t" + turn + ": " + JSON.stringify(result));
    }
    E.nextLevel();
  }
  return seen;
}

test("alertForTurn() and getState() never contain `followed`, on any turn", () => {
  const seen = visibleBeforeEachTurn();
  assert.strictEqual(seen.length, 56);
  let alerts = 0;
  for (const view of seen) {
    assert.ok(deepKeys(view).indexOf("followed") === -1);
    assert.ok(JSON.stringify(view).indexOf("followed") === -1);
    if (view.alert) {
      alerts += 1;
      same(Object.keys(view.alert), ["cls", "fullClass", "date", "dots"]);
      // no true/false anywhere in the alert: nothing that could be the answer
      assert.ok(Object.keys(view.alert).every((k) => typeof view.alert[k] !== "boolean"));
    }
    same(Object.keys(view.state).filter((k) => typeof view.state[k] === "boolean"), ["isDay"]);
  }
  assert.strictEqual(alerts, 14);
});

test("the dots depend on the flare class only", () => {
  for (const view of visibleBeforeEachTurn()) {
    if (view.alert) assert.strictEqual(view.alert.dots, view.alert.cls === "X" ? 3 : 1);
  }
});

test("flipping every saved `followed` changes nothing the alert or the level info shows", () => {
  const flip = (STORMS) => {
    for (const key of Object.keys(STORMS.windows)) {
      for (const w of STORMS.windows[key]) {
        for (const t of w.turns) {
          t.followed = !t.followed;
          for (const f of t.flares) f.followed = !f.followed;
        }
      }
    }
  };
  const pick = (views) => views.map((v) => [v.alert, v.info, v.dates, v.check, v.power, v.spend, v.state.turn, v.state.level]);
  const real = visibleBeforeEachTurn();
  const flipped = visibleBeforeEachTurn({ storms: flip });
  same(pick(flipped), pick(real));
  // ...while what happens after the turn does change (the flip is really wired in)
  assert.notStrictEqual(JSON.stringify(flipped.map((v) => v.state.dose)), JSON.stringify(real.map((v) => v.state.dose)));
});

test("the debrief only shows storms from turns already played", () => {
  const dose = [];
  for (let i = 1; i <= 14; i++) dose.push(i);
  const E = atLevel(4, { storms: (STORMS) => { STORMS.windows.bigOne[0].moonDose = dose.slice(); } });
  same(E.getDebrief().storms, []);
  same(E.getDebrief().stormTurns, []);
  same(E.getDebrief().moonDose, [null, null, null, null, null, null, null, null, null, null, null, null, null, null]);
  playTurns(E, 3, (st) => plan({ lifeSupport: 3, shelter: true }));
  const d = E.getDebrief();
  same(d.storms.map((st) => st.turn), [1, 2, 3]);
  same(d.stormTurns, [2, 3]);
  same(d.moonDose, [1, 2, 3, null, null, null, null, null, null, null, null, null, null, null]);
});

// ---------------------------------------------------------------- parity with tools/balance_sim.py (section 9.2)
group("parity");

/* A port of `Policy` and `strategies(p, food=True)` from tools/balance_sim.py.
 * Strategies only ever see the alert (its class), never whether a storm followed. */
function policy(name, over) {
  return Object.assign({ name: name, dayLs: 3, chargeTo: 0, shieldTo: 0, shelter: "never", nightLs: 3, grow: "day" }, over || {});
}

function wantsShelter(pol, alert) {
  return alert !== null && (pol.shelter === "always" || (pol.shelter === "X" && alert.cls === "X"));
}

function shieldNeeded(pol, s, p) {
  if (s.shield >= Math.min(pol.shieldTo, p.MAX_SHIELD)) return 0;
  return p.SHIELD_COST * (pol.shieldTo - s.shield) - s.shieldProgress;
}

function foodShort(s, p) {
  const turnsLeft = p.TURNS_PER_LEVEL - s.turn + 1;
  return s.food < p.FOOD_EATEN * turnsLeft;
}

function wantsGreenhouse(pol, s, p, isDay) {
  if (s.food === null || pol.grow === "never") return false;
  if (pol.grow === "always") return true;
  if (pol.grow === "night" && isDay) return false;
  return foodShort(s, p);
}

function policyPlan(pol, s, p, isDay, alert) {
  const pl = plan();
  if (isDay) {
    let budget = p.SOLAR_POWER;
    if (wantsShelter(pol, alert)) {
      pl.shelter = true;
      budget -= p.SHELTER_COST;
    }
    let ls = pol.dayLs;
    if (ls === "bank") ls = s.air < p.AIR_MAX ? p.LS_MAX : p.LS_NEEDED;
    pl.lifeSupport = Math.min(ls, budget, p.LS_MAX);
    budget -= pl.lifeSupport;
    if (wantsGreenhouse(pol, s, p, true) && budget >= p.GREENHOUSE_DAY) {
      pl.greenhouse = true;
      budget -= p.GREENHOUSE_DAY;
    }
    const need = Math.max(0, pol.chargeTo - s.battery) / p.CHARGE_EFFICIENCY;
    pl.charge = Math.min(budget, Math.ceil(need - 1e-9));
    budget -= pl.charge;
    pl.shield = Math.min(budget, shieldNeeded(pol, s, p));
    budget -= pl.shield;
    if (pl.shelter) pl.charge += budget;   // no science while sheltering: bank the rest
    else pl.science = budget;
    return pl;
  }
  // night: only the battery
  let b = s.battery;
  if (wantsShelter(pol, alert) && b >= p.SHELTER_COST) {
    pl.shelter = true;
    b -= p.SHELTER_COST;
  }
  pl.lifeSupport = Math.min(pol.nightLs, Math.trunc(b + 1e-9));
  b -= pl.lifeSupport;
  if (wantsGreenhouse(pol, s, p, false) && b >= p.GREENHOUSE_NIGHT) {
    pl.greenhouse = true;
    b -= p.GREENHOUSE_NIGHT;
  }
  if ((pol.grow === "night" || pol.grow === "always") && s.food !== null) return pl;
  const nightsAfter = p.TURNS_PER_LEVEL - s.turn;
  const spare = Math.trunc(b - nightsAfter * pol.nightLs + 1e-9);
  if (spare > 0) {
    pl.shield = Math.min(spare, shieldNeeded(pol, s, p));
    if (!pl.shelter) pl.science = spare - pl.shield;
  }
  return pl;
}

function strategies(p) {
  const night = p.LS_NEEDED * (p.TURNS_PER_LEVEL - p.DAY_TURNS);   // battery the night needs
  const smart = { shieldTo: 1, shelter: "X" };
  return [
    policy("all science, never charge"),
    policy("bank Air by day, never charge", { dayLs: "bank" }),
    policy("never shelter, no shield", { chargeTo: night }),
    policy("always shelter, no shield", { chargeTo: night + 6, shelter: "always" }),
    policy("full shield early, never shelter", { chargeTo: night, shieldTo: 3 }),
    policy("shelter on X, 1 shield", { chargeTo: night + 4, shieldTo: 1, shelter: "X" }),
    policy("shelter on X, 2 shields", { chargeTo: night + 4, shieldTo: 2, shelter: "X" }),
    policy("never use the greenhouse", Object.assign({ chargeTo: night + 4, grow: "never" }, smart)),
    policy("greenhouse only at night", Object.assign({ chargeTo: p.BATTERY_MAX, grow: "night" }, smart)),
    policy("greenhouse always on", Object.assign({ chargeTo: p.BATTERY_MAX, grow: "always" }, smart))
  ];
}

/** Play the whole game with one policy, no retries (like `play()` in the simulator). */
function playPolicy(pol) {
  const LNS = loadGame();
  const E = LNS.Engine;
  const p = LNS.NUMBERS;
  E.startGame();
  for (let guard = 0; guard < 1000; guard++) {
    const result = E.takeTurn(policyPlan(pol, E.getState(), p, E.isDay(), E.alertForTurn()));
    assert.notStrictEqual(result.status, "invalid", pol.name + ": " + result.message);
    if (result.status === "continue") continue;
    const st = E.getState();
    if (result.status === "lost") {
      return { result: "lost L" + st.level + " (" + result.reason + ")", stars: st.stars, dose: st.dose, shield: null };
    }
    if (result.status === "game_won") return { result: "won", stars: st.stars, dose: st.dose, shield: st.shield };
    E.nextLevel();
  }
  throw new Error("the game never ended");
}

// From `python3 tools/balance_sim.py --preset tuned_food --food` (HANDOVER.md section 9.2).
// NEVER change a number here to make a test pass: find the engine bug instead.
const PARITY = [
  // strategy, result, stars, dose, shield
  ["all science, never charge", "lost L1 (air)", 49, 0, null],
  ["bank Air by day, never charge", "lost L1 (air)", 49, 0, null],
  ["never shelter, no shield", "lost L4 (dose)", 107, 100.0, null],
  ["always shelter, no shield", "won", 108, 9.0, 0],
  ["full shield early, never shelter", "won", 104, 30.0, 3],
  ["shelter on X, 1 shield", "won", 107, 20.5, 1],
  ["shelter on X, 2 shields", "won", 99, 16.5, 2],
  ["never use the greenhouse", "lost L2 (food)", 60, 0, null],
  ["greenhouse only at night", "won", 49, 20.5, 1],
  ["greenhouse always on", "won", 30, 20.5, 1]
];

test("the strategy list is the simulator's, in order", () => {
  same(strategies(loadGame().NUMBERS).map((pol) => pol.name), PARITY.map((row) => row[0]));
});

for (const row of PARITY) {
  test(row[0] + " -> " + row[1], () => {
    const pol = strategies(loadGame().NUMBERS).filter((x) => x.name === row[0])[0];
    const got = playPolicy(pol);
    same([got.result, got.stars, got.dose.toFixed(1), got.shield], [row[1], row[2], row[3].toFixed(1), row[4]]);
  });
}

// ---------------------------------------------------------------- report
if (results.failed.length) {
  for (const f of results.failed) {
    console.error("FAIL  " + f.name + "\n      " + String(f.err && f.err.message).split("\n").join("\n      "));
  }
}
console.log(results.passed + " passed, " + results.failed.length + " failed");
process.exit(results.failed.length ? 1 : 0);

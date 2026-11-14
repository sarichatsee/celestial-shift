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
const ENGINE_FILES = ["data.js", "game.js"];

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
  assert.strictEqual(JSON.stringify(actual), JSON.stringify(expected), msg);
}

function near(actual, expected, msg) {
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

// ---------------------------------------------------------------- report
if (results.failed.length) {
  for (const f of results.failed) {
    console.error("FAIL  " + f.name + "\n      " + String(f.err && f.err.message).split("\n").join("\n      "));
  }
}
console.log(results.passed + " passed, " + results.failed.length + " failed");
process.exit(results.failed.length ? 1 : 0);

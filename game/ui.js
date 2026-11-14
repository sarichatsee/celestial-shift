/* ui.js: draws the state, reads clicks, calls the engine.
 *
 * It never changes a game number: it only asks LNS.Engine questions and sends
 * it the player's plan. All words come from LNS.TEXT (text.js).
 *
 * NO PEEKING: before a turn is played this file only knows what
 * Engine.alertForTurn() returns (flare class, date, dots). Whether a storm
 * followed is read from Engine.getDebrief(), which holds played turns only.
 */
(function (root) {
  "use strict";

  var LNS = root.LNS;
  var doc = root.document;
  if (!doc || !LNS || !LNS.Engine) return;

  var E = LNS.Engine;
  var T = LNS.TEXT;
  var N = LNS.NUMBERS;

  // Display-only settings (they never change a rule).
  var AIR_LOW_PCT = 30;        // Air bar turns amber under this
  var DOSE_HIGH = 60;          // same line as the "radiation is high" tip
  var ICONS = {
    battery: "🔋", air: "💨", water: "💧", food: "🥕", radiation: "☢️", shield: "🛡️", stars: "⭐",
    lifeSupport: "💨", science: "🔬", charge: "🔋", greenhouse: "🌱"
  };

  var plan = null;             // the player's plan for the current turn (not sent yet)
  var hint = "";               // a one-off friendly message (night falls, new meters)
  var report = null;           // what happened on the turn just played
  var newMetersSeen = false;   // the "New!" hint shows once
  var nodes = {};              // elements built once and updated on every render

  // ---------------------------------------------------------------- small helpers
  function $(id) { return doc.getElementById(id); }

  /** fmt("Turn {turn} of {total}", {turn: 3, total: 14}) */
  function fmt(str, vars) {
    return String(str).replace(/\{(\w+)\}/g, function (whole, key) {
      return vars && vars[key] !== undefined ? vars[key] : whole;
    });
  }

  function el(tag, attrs, children) {
    var node = doc.createElement(tag);
    Object.keys(attrs || {}).forEach(function (key) {
      if (key === "text") node.textContent = attrs[key];
      else node.setAttribute(key, attrs[key]);
    });
    (children || []).forEach(function (child) { if (child) node.appendChild(child); });
    return node;
  }

  function icon(key) { return el("span", { "class": "meter-icon", "aria-hidden": "true", text: ICONS[key] }); }

  /** Numbers on screen: at most one decimal, and no "10.0". */
  function show(n) { return String(Math.round(n * 10) / 10); }

  function pct(value, max) { return Math.max(0, Math.min(100, (value / max) * 100)); }

  /** "2024-05-11" -> "11 May 2024" (or "11 May"). */
  function fmtDate(iso, opts) {
    var p = iso.split("-");
    var months = opts && opts.long ? T.dates.monthsLong : T.dates.monthsShort;
    return (+p[2]) + " " + months[+p[1] - 1] + (opts && opts.noYear ? "" : " " + p[0]);
  }

  /** {from: "2024-01-23", to: "2024-01-24"} -> "23–24 Jan 2024" */
  function fmtDateRange(range, opts) {
    var a = range.from.split("-");
    var b = range.to.split("-");
    if (a[0] === b[0] && a[1] === b[1]) return (+a[2]) + "–" + fmtDate(range.to, opts);
    var first = fmtDate(range.from, { long: opts && opts.long, noYear: a[0] === b[0] });
    return first + " – " + fmtDate(range.to, opts);
  }

  function showScreen(name, focusId) {
    ["game", "debrief"].forEach(function (s) {
      var node = $("screen-" + s);
      if (node) node.hidden = s !== name;
    });
    root.scrollTo(0, 0);
    var target = focusId && $(focusId);
    if (target) target.focus();
  }

  /** Fill every element that names its words: <p data-t="title.disclaimer">. */
  function fillStaticText() {
    var marked = doc.querySelectorAll("[data-t]");
    for (var i = 0; i < marked.length; i++) {
      var value = marked[i].getAttribute("data-t").split(".").reduce(function (o, k) { return o && o[k]; }, T);
      if (typeof value === "string") marked[i].textContent = value;
    }
    doc.title = T.title.name;
  }

  // ---------------------------------------------------------------- the plan
  function freshPlan() {
    return { lifeSupport: N.LS_NEEDED, shield: 0, science: 0, charge: 0, shelter: false, greenhouse: false };
  }

  /** Power still needed to finish the shield (so the player can't pour power into a full one). */
  function shieldRoom(st) {
    return Math.max(0, N.SHIELD_COST * (N.MAX_SHIELD - st.shield) - st.shieldProgress);
  }

  /** The most a stepper may show. The engine still has the last word (checkPlan). */
  function maxFor(key, st) {
    var power = Math.floor(E.powerAvailable() + 1e-9);
    if (key === "lifeSupport") return N.LS_MAX;
    if (key === "shield") return Math.min(shieldRoom(st), Math.max(power, 0));
    if (key === "charge") return st.isDay ? power : 0;
    if (key === "science") return plan.shelter ? 0 : Math.max(power, 0);
    return 0;
  }

  /** A new turn starts from the last plan. If it no longer fits, cut science,
   *  then shield, then the greenhouse. Never life support: that is the player's call. */
  function carryPlanToNewTurn() {
    var st = E.getState();
    plan.shelter = false;
    if (!st.isDay) plan.charge = 0;
    plan.shield = Math.min(plan.shield, shieldRoom(st));
    if (!E.getLevelInfo().hasFood) plan.greenhouse = false;
    var guard = 0;
    while (E.totalSpend(plan) > E.powerAvailable() + 1e-9 && guard++ < 200) {
      if (plan.science > 0) plan.science -= 1;
      else if (plan.shield > 0) plan.shield -= 1;
      else if (plan.greenhouse) plan.greenhouse = false;
      else break;
    }
  }

  function step(key, delta) {
    var st = E.getState();
    var next = Math.max(0, Math.min(maxFor(key, st), plan[key] + delta));
    if (next === plan[key]) return;
    plan[key] = next;
    hint = "";
    renderGame();
  }

  function toggleGreenhouse() {
    plan.greenhouse = !plan.greenhouse;
    hint = "";
    renderGame();
  }

  // ---------------------------------------------------------------- building the game screen (once)
  function buildMeters() {
    var box = $("meters");
    var list = [
      { key: "battery", max: N.BATTERY_MAX },
      { key: "air", max: N.AIR_MAX },
      { key: "water", max: N.WATER_START, note: true },
      { key: "food", max: N.FOOD_EATEN * N.TURNS_PER_LEVEL },   // a full bar feeds the whole level
      { key: "radiation", max: N.DOSE_LIMIT }
    ];
    nodes.meters = {};
    list.forEach(function (m) {
      var bar = el("div", { "class": "bar", role: "meter", "aria-label": T.meters[m.key], "aria-valuemin": "0",
        "aria-valuemax": String(m.max) }, [el("div", { "class": "bar-fill" })]);
      var value = el("span", { "class": "meter-value" });
      var note = m.note ? el("span", { "class": "meter-note" }) : null;
      var row = el("div", { "class": "meter " + m.key }, [
        icon(m.key), el("span", { "class": "meter-name", text: T.meters[m.key] }), bar, value, note
      ]);
      box.appendChild(row);
      nodes.meters[m.key] = { row: row, bar: bar, fill: bar.firstChild, value: value, note: note, max: m.max };
    });

    nodes.pips = el("span", { "class": "shield-pips" });
    nodes.shieldNote = el("small");
    nodes.stars = el("span");
    box.appendChild(el("div", { "class": "meter-row" }, [
      el("span", { "class": "stat" }, [icon("shield"), el("span", { text: T.meters.shield + " " }), nodes.pips,
        el("span", { text: " " }), nodes.shieldNote]),
      el("span", { "class": "stat" }, [icon("stars"), el("span", { text: T.meters.stars + " " }), nodes.stars])
    ]));
  }

  function buildControls() {
    var grid = $("control-grid");
    nodes.controls = {};
    ["lifeSupport", "shield", "science", "charge"].forEach(function (key) {
      var label = T.controls[key];
      var minus = el("button", { "class": "btn", type: "button", "aria-label": fmt(T.controls.less, { name: label }), text: "−" });
      var plus = el("button", { "class": "btn", type: "button", "aria-label": fmt(T.controls.more, { name: label }), text: "+" });
      var out = el("output", { "aria-label": label });
      var hintNode = el("p", { "class": "control-hint", text: T.controls.hints[key] });
      minus.addEventListener("click", function () { step(key, -1); });
      plus.addEventListener("click", function () { step(key, +1); });
      var box = el("div", { "class": "control", role: "group", "aria-label": label }, [
        el("div", { "class": "control-name" }, [icon(key), el("span", { text: label })]),
        el("div", { "class": "stepper" }, [minus, out, plus]),
        hintNode
      ]);
      grid.appendChild(box);
      nodes.controls[key] = { box: box, minus: minus, plus: plus, out: out, hint: hintNode };
    });

    var sw = el("button", { "class": "btn switch", type: "button", "aria-pressed": "false" });
    sw.addEventListener("click", toggleGreenhouse);
    var ghHint = el("p", { "class": "control-hint", text: T.controls.hints.greenhouse + " " + T.controls.greenhouseCost + "." });
    var gh = el("div", { "class": "control", role: "group", "aria-label": T.controls.greenhouse }, [
      el("div", { "class": "control-name" }, [icon("greenhouse"), el("span", { text: T.controls.greenhouse })]),
      sw, ghHint
    ]);
    grid.appendChild(gh);
    nodes.greenhouse = { box: gh, button: sw, hint: ghHint };

    $("end-turn").addEventListener("click", endTurn);
  }

  // ---------------------------------------------------------------- drawing the game screen (every change)
  function setMeter(key, value, low, valueText) {
    var m = nodes.meters[key];
    m.fill.style.width = pct(value, m.max) + "%";
    m.value.textContent = show(value);
    m.bar.setAttribute("aria-valuenow", String(Math.max(0, Math.min(m.max, value))));
    m.bar.setAttribute("aria-valuetext", valueText || fmt(T.meters.of, { value: show(value), max: m.max }));
    m.row.classList.toggle("low", !!low);
  }

  function renderGame() {
    var st = E.getState();
    var info = E.getLevelInfo();
    var available = E.powerAvailable();
    var spend = E.totalSpend(plan);
    var check = E.checkPlan(plan);
    var nightsLeft = st.turnsPerLevel - Math.max(st.turn, N.DAY_TURNS + 1) + 1;

    // top bar
    $("hdr-level").textContent = fmt(T.header.level, { n: st.level, name: info.name });
    $("hdr-turn").textContent = fmt(T.meters.turn, { turn: st.turn, total: st.turnsPerLevel });
    var phase = $("hdr-phase");
    phase.textContent = (st.isDay ? "☀️ " : "🌙 ") + (st.isDay ? T.meters.day : T.meters.night);
    phase.className = "chip phase " + (st.isDay ? "day" : "night");
    var dates = info.turnDates(st.turn);
    $("hdr-dates").hidden = !dates;
    if (dates) $("hdr-dates").textContent = fmtDateRange(dates);

    // meters
    setMeter("battery", st.battery, !st.isDay && st.battery + 1e-9 < N.LS_NEEDED * nightsLeft);
    setMeter("air", st.air, pct(st.air, N.AIR_MAX) < AIR_LOW_PCT);
    setMeter("radiation", st.dose, st.dose > DOSE_HIGH);
    ["water", "food"].forEach(function (key) {
      var m = nodes.meters[key];
      m.row.hidden = !info.hasFood;
      m.row.classList.toggle("new", info.hasFood && hint === T.messages.newMeters);
      if (info.hasFood) setMeter(key, st[key], st[key] < 2 * (key === "food" ? N.FOOD_EATEN : N.WATER_USED_NO_RECYCLER));
    });
    var recyclerOn = plan.lifeSupport >= N.LS_NEEDED;
    var note = nodes.meters.water.note;
    note.textContent = recyclerOn ? T.meters.recyclerOn : T.meters.recyclerOff;
    note.className = "meter-note " + (recyclerOn ? "on" : "off");

    nodes.pips.textContent = "";
    for (var i = 0; i < N.MAX_SHIELD; i++) {
      nodes.pips.appendChild(el("span", { "class": "pip" + (i < st.shield ? " full" : "") }));
    }
    nodes.pips.setAttribute("role", "img");
    nodes.pips.setAttribute("aria-label", fmt(T.meters.of, { value: st.shield, max: N.MAX_SHIELD }));
    nodes.shieldNote.textContent = st.shield >= N.MAX_SHIELD ? T.meters.shieldFull
      : fmt(T.meters.shieldProgress, { done: st.shieldProgress, cost: N.SHIELD_COST });
    nodes.stars.textContent = String(st.stars);

    // controls
    ["lifeSupport", "shield", "science", "charge"].forEach(function (key) {
      var c = nodes.controls[key];
      var max = maxFor(key, st);
      c.out.textContent = String(plan[key]);
      c.minus.disabled = plan[key] <= 0;
      c.plus.disabled = plan[key] >= max;
      c.box.classList.toggle("disabled", max <= 0 && plan[key] <= 0);
    });
    nodes.controls.charge.hint.textContent = st.isDay ? T.controls.hints.charge
      : T.controls.chargeDayOnly + ". " + T.messages.noChargeNight + ".";
    nodes.controls.shield.hint.textContent = st.shield >= N.MAX_SHIELD ? T.messages.shieldFull + "."
      : T.controls.hints.shield;
    nodes.controls.science.hint.textContent = plan.shelter ? T.controls.hints.noScienceShelter : T.controls.hints.science;

    nodes.greenhouse.box.hidden = !info.hasFood;
    nodes.greenhouse.button.setAttribute("aria-pressed", plan.greenhouse ? "true" : "false");
    nodes.greenhouse.button.textContent = plan.greenhouse ? T.controls.on : T.controls.off;
    nodes.greenhouse.button.setAttribute("aria-label", T.controls.greenhouse + ": " +
      (plan.greenhouse ? T.controls.on : T.controls.off));
    nodes.greenhouse.box.classList.toggle("new", info.hasFood && hint === T.messages.newMeters);

    // power, message, end turn
    var left = available - spend;
    var power = $("power-left");
    power.textContent = "⚡ " + fmt(T.controls.powerLeft, { n: show(left) }) + " ";
    power.appendChild(el("small", { text: "(" + show(available) + " " +
      (st.isDay ? T.controls.powerFromSun : T.controls.powerFromBattery) + ")" }));
    power.classList.toggle("over", left < -1e-9);

    var message = $("message");
    var problem = check !== "ok" ? check : "";
    message.textContent = problem || hint;
    message.className = "message" + (problem ? " problem" : hint ? " hint" : "");
    $("end-turn").disabled = !!problem;

    renderReport();

    if (LNS.Base) {
      LNS.Base.update({
        isDay: st.isDay,
        turn: st.turn,
        airPct: pct(st.air, N.AIR_MAX),
        batteryPct: pct(st.battery, N.BATTERY_MAX),
        dosePct: pct(st.dose, N.DOSE_LIMIT),
        waterPct: info.hasFood ? pct(st.water, nodes.meters.water.max) : null,
        foodPct: info.hasFood ? pct(st.food, nodes.meters.food.max) : null,
        shield: st.shield,
        lifeSupportOk: recyclerOn,
        sciencePowered: plan.science > 0 && !plan.shelter,
        greenhouse: info.hasFood ? (plan.greenhouse ? "on" : "off") : null,
        sheltering: !!plan.shelter,
        alert: null,
        ended: null
      });
    }
  }

  function renderReport() {
    var box = $("report");
    box.hidden = !report;
    if (!report) return;
    box.textContent = "";
    box.appendChild(el("strong", { text: T.report.heading + ":" }));
    box.appendChild(el("span", { text: report.text }));
    box.classList.toggle("hit", !!report.hit);
  }

  // ---------------------------------------------------------------- playing
  function beginLevel() {
    plan = freshPlan();
    report = null;
    hint = "";
    if (E.getLevelInfo().hasFood && !newMetersSeen) {
      hint = T.messages.newMeters;
      newMetersSeen = true;
    }
    showScreen("game", "hdr-level");
    renderGame();
  }

  function endTurn() {
    var sent = { lifeSupport: plan.lifeSupport, shield: plan.shield, science: plan.science, charge: plan.charge,
      shelter: plan.shelter, greenhouse: plan.greenhouse };
    var result = E.takeTurn(sent);
    if (result.status === "invalid") { renderGame(); return; }
    report = null;
    hint = "";
    if (result.status === "continue") {
      carryPlanToNewTurn();
      if (E.getState().turn === N.DAY_TURNS + 1) hint = T.messages.nightHint;
      renderGame();
      $("end-turn").focus();
    } else {
      showDebrief(result);
    }
  }

  // ---------------------------------------------------------------- debrief
  function showDebrief(result) {
    var d = E.getDebrief(result);
    var st = E.getState();
    var lost = result.status === "lost";
    var headline = lost ? T.debrief.lost : (result.status === "game_won" ? T.debrief.gameWon : T.debrief.won);
    $("debrief-headline").textContent = (lost ? "🚀 " : "🌅 ") + headline;
    $("debrief-why").textContent = lost ? T.debrief.why[result.reason] : T.debrief.why.won;
    $("debrief-score").textContent = fmt(T.debrief.score, { stars: st.stars, dose: show(st.dose), limit: N.DOSE_LIMIT,
      shield: st.shield, max: N.MAX_SHIELD });
    var tip = $("debrief-tip");
    tip.textContent = "";
    tip.appendChild(el("strong", { text: "💡 " + T.debrief.tipHeading + ":" }));
    tip.appendChild(el("span", { text: d.tip }));

    var buttons = $("debrief-buttons");
    buttons.textContent = "";
    function add(label, primary, action) {
      var b = el("button", { "class": "btn big" + (primary ? " primary" : ""), type: "button", text: label });
      b.addEventListener("click", action);
      buttons.appendChild(b);
    }
    if (result.status === "level_won") add(T.debrief.next, true, function () { E.nextLevel(); beginLevel(); });
    add(T.debrief.retry, lost, function () { E.retryLevel(); beginLevel(); });
    add(T.debrief.again, result.status === "game_won", function () { E.startGame(); beginLevel(); });

    showScreen("debrief", "debrief-headline");
  }

  // ---------------------------------------------------------------- start
  function init() {
    fillStaticText();
    buildMeters();
    buildControls();
    var picture = $("base-picture");
    picture.setAttribute("aria-label", T.meters.basePicture);
    if (LNS.Base) LNS.Base.mount(picture);
    E.startGame();
    beginLevel();
  }

  // For the dev pages and the browser console; the game itself does not use this.
  LNS.UI = { fmt: fmt, fmtDate: fmtDate, fmtDateRange: fmtDateRange, beginLevel: beginLevel, showDebrief: showDebrief };

  if (doc.readyState === "loading") doc.addEventListener("DOMContentLoaded", init);
  else init();
})(globalThis);

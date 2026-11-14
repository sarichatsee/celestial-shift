#!/usr/bin/env python3
"""Balance simulator for Lunar Night Shift (rules from the simple build plan).

Plays fixed strategies through every level on REAL 2024 DONKI storm alerts
(tools/donki_alerts_2024.json) and prints who wins, who loses, and the score.
The engine below follows the plan's pseudocode (sections 5.1 to 5.5) line by line.
--food adds the proposed Food and Water rules and a "Green Thumb" level before the storms.

  python3 tools/balance_sim.py                        # compare the presets
  python3 tools/balance_sim.py --preset tuned --food   # with food and water
  python3 tools/balance_sim.py --set SHIELD_COST=8 START_AIR=60
  python3 tools/balance_sim.py --l2 2024-08-22 --l3 2024-09-29
  python3 tools/balance_sim.py --windows               # every stormy 2024 window as the last level

Strategies only ever see the alert (class + risk), never whether a storm followed.
"""
import argparse
import copy
import datetime as dt
import json
import math
import os
import random

# ---------------------------------------------------------------- numbers (data.js)
PRESETS = {
    # Section 5.1 / 8.1 of the simple build plan, unchanged.
    "plan": dict(
        TURNS_PER_LEVEL=14, DAY_TURNS=7, SOLAR_POWER=10,
        START_BATTERY=10, BATTERY_MAX=40, CHARGE_EFFICIENCY=0.8,
        START_AIR=80, AIR_MAX=100, LS_NEEDED=3, LS_MAX=5, AIR_PER_POWER=5,
        SHIELD_COST=6, MAX_SHIELD=3, SHELTER_COST=2,
        DOSE_LIMIT=100, SHELTER_DOSE=1.5, DOSE_BY_SHIELD=[15, 10, 7, 4],
    ),
}
# Suggested fix: Air is a small buffer that cannot be overfilled.
PRESETS["fix"] = dict(PRESETS["plan"], START_AIR=60, AIR_MAX=60, AIR_PER_POWER=10)
# Best of a grid search against the plan's targets (section 8.2): the Air fix,
# plus storms that hurt more, a dearer shield and a cheaper shelter.
PRESETS["tuned"] = dict(PRESETS["fix"], DOSE_BY_SHIELD=[20, 13, 9, 5], SHIELD_COST=8, SHELTER_COST=1)

# Proposed Food and Water rules (only used with --food). [TUNE]
FOOD_WATER = dict(
    FOOD_START=16,              # days of food the supply lander brings each level
    FOOD_EATEN=2,               # the crew eats 2 days of food per turn (1 turn = 2 Earth days)
    FOOD_PER_GREENHOUSE=3,      # food grown in a turn with the greenhouse on
    GREENHOUSE_DAY=1,           # power by day: pumps and heat (sunlight is free)
    GREENHOUSE_NIGHT=4,         # power at night: pumps, heat AND grow lights
    # Water is a CALM meter on purpose (team decision, 2026-11-14): with life support
    # running it only drifts down (about 30 -> 11 in a level). It shows recycling working
    # and should rarely end a game; only an always-on greenhouse brings it near empty.
    WATER_START=30,             # water in the tank at the start of a level
    WATER_USED=1,               # water lost per turn while the recycler runs (life support >= LS_NEEDED)
    WATER_USED_NO_RECYCLER=2,   # water lost per turn INSTEAD of WATER_USED when life support is short (recycler off)
    GREENHOUSE_WATER=1,         # extra water the plants drink in a greenhouse turn
)
for _p in PRESETS.values():
    _p.update(FOOD_WATER)
# With food and water (use with --food): food adds work, so Air can drain a little slower.
PRESETS["tuned_food"] = dict(PRESETS["tuned"], AIR_PER_POWER=8)

RISK_BY_CLASS = {"C": "low", "M": "medium", "X": "high"}  # shown to the player [D6]

# ---------------------------------------------------------------- real storms (storms.js)
HERE = os.path.dirname(os.path.abspath(__file__))
ALERTS = json.load(open(os.path.join(HERE, "donki_alerts_2024.json")))["alerts"]


def _strength(cls):
    return (2 if cls[0] == "X" else 1, float(cls[1:] or 1))


def storms_for_window(start, p):
    """A real 28-day window -> one level. 1 turn = 2 days; keep the strongest
    alert in each turn; the turn's storm 'followed' if any alert in it did."""
    t0 = dt.datetime.fromisoformat(start)
    turns = {}
    for a in ALERTS:
        peak = dt.datetime.strptime(a["peak"], "%Y-%m-%dT%H:%MZ")
        i = (peak - t0).days // 2
        if 0 <= i < p["TURNS_PER_LEVEL"]:
            turns.setdefault(i + 1, []).append(a)
    storms = []
    for turn, alerts in sorted(turns.items()):
        top = max(alerts, key=lambda a: _strength(a["class"]))
        storms.append({"turn": turn, "class": top["class"][0], "date": top["peak"][:10],
                       "followed": any(a["followed"] for a in alerts)})
    return storms


def build_levels(p, weather, big, food):
    """The level list. With food: First Night, Green Thumb, Space Weather, The Big One."""
    levels = [{"name": "First Night", "storms": [], "food": False}]
    if food:
        levels.append({"name": "Green Thumb", "storms": [], "food": True})
    levels.append({"name": "Space Weather", "storms": storms_for_window(weather, p), "food": food, "window": weather})
    levels.append({"name": "The Big One", "storms": storms_for_window(big, p), "food": food, "window": big})
    return levels


# ---------------------------------------------------------------- the rules (game.js)
class Game:
    def __init__(self, p, levels):
        self.p, self.levels, self.s = p, levels, {}

    def start_game(self):
        s = self.s
        s.update(level=1, dose=0.0, shield=0, shield_progress=0, stars=0)
        self.start_level(1)

    def start_level(self, n):
        s, p = self.s, self.p
        s.update(level=n, turn=1, battery=float(p["START_BATTERY"]), air=p["START_AIR"],
                 history=[], storm_log=[], min_air=p["START_AIR"])
        food = self.levels[n - 1]["food"]  # food and water reset each level, like battery and air
        s.update(food=p["FOOD_START"] if food else None, water=p["WATER_START"] if food else None,
                 min_food=p["FOOD_START"] if food else None, min_water=p["WATER_START"] if food else None)
        s["level_start"] = {k: s[k] for k in ("dose", "shield", "shield_progress", "stars")}

    def get_state(self):
        return {k: v for k, v in self.s.items() if k not in ("history", "storm_log", "level_start")}

    def has_food(self):
        return self.levels[self.s["level"] - 1]["food"]

    def is_day(self):
        return self.s["turn"] <= self.p["DAY_TURNS"]

    def power_available(self):
        return self.p["SOLAR_POWER"] if self.is_day() else self.s["battery"]

    def total_spend(self, plan):
        p = self.p
        spend = plan["life_support"] + plan["shield"] + plan["science"] + plan["charge"]
        if plan["shelter"]:
            spend += p["SHELTER_COST"]
        if plan["greenhouse"]:
            spend += p["GREENHOUSE_DAY"] if self.is_day() else p["GREENHOUSE_NIGHT"]
        return spend

    def check_plan(self, plan):
        p, s = self.p, self.s
        if min(plan["life_support"], plan["shield"], plan["science"], plan["charge"]) < 0:
            return "No negative power"
        if plan["life_support"] > p["LS_MAX"]:
            return "Life support can't go above %d" % p["LS_MAX"]
        if not self.is_day() and plan["charge"] > 0:
            return "No sunlight: you can't charge at night"
        if plan["shelter"] and plan["science"] > 0:
            return "No science while sheltering"
        if s["shield"] >= p["MAX_SHIELD"] and plan["shield"] > 0:
            return "The shield is already full"
        if plan["greenhouse"] and not self.has_food():
            return "No greenhouse on this level"
        if self.total_spend(plan) > self.power_available() + 1e-9:
            return "Not enough power"
        return "ok"

    def storm_this_turn(self):
        for storm in self.levels[self.s["level"] - 1]["storms"]:
            if storm["turn"] == self.s["turn"]:
                return storm
        return None

    def alert_for_turn(self):  # what the screen is ALLOWED to know
        storm = self.storm_this_turn()
        if storm is None:
            return None
        return {"class": storm["class"], "risk": RISK_BY_CLASS[storm["class"]]}

    def add_to_shield(self, power):
        s, p = self.s, self.p
        s["shield_progress"] += power
        while s["shield_progress"] >= p["SHIELD_COST"] and s["shield"] < p["MAX_SHIELD"]:
            s["shield"] += 1
            s["shield_progress"] -= p["SHIELD_COST"]

    def resolve_storm(self, sheltered):  # what REALLY happens, from the saved record
        storm = self.storm_this_turn()
        if storm is None:
            return
        dose = 0.0
        if storm["followed"]:
            dose = self.p["SHELTER_DOSE"] if sheltered else self.p["DOSE_BY_SHIELD"][self.s["shield"]]
        self.s["dose"] += dose
        self.s["storm_log"].append(dict(storm, sheltered=sheltered, dose=dose))

    def feed_crew(self, plan):  # food and water, only on levels that have them
        s, p = self.s, self.p
        if plan["greenhouse"]:
            s["food"] += p["FOOD_PER_GREENHOUSE"]
            s["water"] -= p["GREENHOUSE_WATER"]
        s["food"] -= p["FOOD_EATEN"]
        recycler_on = plan["life_support"] >= p["LS_NEEDED"]
        s["water"] -= p["WATER_USED"] if recycler_on else p["WATER_USED_NO_RECYCLER"]
        s["min_food"] = min(s["min_food"], s["food"])
        s["min_water"] = min(s["min_water"], s["water"])

    def take_turn(self, plan):
        problem = self.check_plan(plan)
        if problem != "ok":
            raise ValueError("invalid plan on level %d turn %d: %s %s"
                             % (self.s["level"], self.s["turn"], problem, plan))
        s, p = self.s, self.p
        if not self.is_day():
            s["battery"] -= self.total_spend(plan)
        s["air"] = max(0, min(p["AIR_MAX"], s["air"] + (plan["life_support"] - p["LS_NEEDED"]) * p["AIR_PER_POWER"]))
        s["min_air"] = min(s["min_air"], s["air"])
        self.add_to_shield(plan["shield"])
        if not plan["shelter"]:
            s["stars"] += plan["science"]
        if self.is_day():
            s["battery"] = min(p["BATTERY_MAX"], s["battery"] + plan["charge"] * p["CHARGE_EFFICIENCY"])
        if self.has_food():
            self.feed_crew(plan)
        self.resolve_storm(plan["shelter"])
        s["history"].append({"turn": s["turn"], "battery": s["battery"], "air": s["air"], "dose": s["dose"]})
        if s["air"] <= 0:
            return {"status": "lost", "reason": "air"}
        if s["dose"] >= p["DOSE_LIMIT"]:
            return {"status": "lost", "reason": "dose"}
        if self.has_food() and s["food"] < 0:
            return {"status": "lost", "reason": "food"}
        if self.has_food() and s["water"] < 0:
            return {"status": "lost", "reason": "water"}
        if s["turn"] == p["TURNS_PER_LEVEL"]:
            return {"status": "game_won" if s["level"] == len(self.levels) else "level_won"}
        s["turn"] += 1
        return {"status": "continue"}

    def retry_level(self):
        keep = self.s["level_start"]
        self.s.update(keep)
        self.start_level(self.s["level"])

    def next_level(self):
        self.start_level(self.s["level"] + 1)


# ---------------------------------------------------------------- strategies
def new_plan():
    return {"life_support": 0, "shield": 0, "science": 0, "charge": 0, "shelter": False, "greenhouse": False}


class Policy:
    """A fixed way of playing.
    day_ls      life support by day (or 'bank': 5 until Air is full, then 3)
    charge_to   battery level wanted by sunset
    shield_to   shield level to build (0-3), as early as possible
    shelter     'never' | 'always' | 'X' (only on X-class alerts)
    grow        greenhouse: 'day' (by day while food is short; at night only in an emergency)
                | 'night' (only at night) | 'always' | 'never'
    """

    def __init__(self, name, target, day_ls=3, charge_to=0, shield_to=0, shelter="never", night_ls=3, grow="day"):
        self.name, self.target = name, target
        self.day_ls, self.charge_to, self.shield_to = day_ls, charge_to, shield_to
        self.shelter, self.night_ls, self.grow = shelter, night_ls, grow

    def wants_shelter(self, alert):
        return alert is not None and (self.shelter == "always" or (self.shelter == "X" and alert["class"] == "X"))

    def shield_needed(self, s, p):
        if s["shield"] >= min(self.shield_to, p["MAX_SHIELD"]):
            return 0
        return p["SHIELD_COST"] * (self.shield_to - s["shield"]) - s["shield_progress"]

    def food_short(self, s, p):
        """True if the food in store won't last to the end of the level."""
        turns_left = p["TURNS_PER_LEVEL"] - s["turn"] + 1
        return s["food"] < p["FOOD_EATEN"] * turns_left

    def wants_greenhouse(self, s, p, is_day):
        if s["food"] is None or self.grow == "never":
            return False
        if self.grow == "always":
            return True
        if self.grow == "night" and is_day:
            return False
        return self.food_short(s, p)  # 'day' growers only use it at night in an emergency

    def plan(self, s, p, is_day, alert):
        plan = new_plan()
        if is_day:
            budget = p["SOLAR_POWER"]
            if self.wants_shelter(alert):
                plan["shelter"] = True
                budget -= p["SHELTER_COST"]
            ls = self.day_ls
            if ls == "bank":
                ls = p["LS_MAX"] if s["air"] < p["AIR_MAX"] else p["LS_NEEDED"]
            plan["life_support"] = min(ls, budget, p["LS_MAX"])
            budget -= plan["life_support"]
            if self.wants_greenhouse(s, p, True) and budget >= p["GREENHOUSE_DAY"]:
                plan["greenhouse"] = True
                budget -= p["GREENHOUSE_DAY"]
            need = max(0.0, self.charge_to - s["battery"]) / p["CHARGE_EFFICIENCY"]
            plan["charge"] = min(budget, math.ceil(need - 1e-9))
            budget -= plan["charge"]
            plan["shield"] = min(budget, self.shield_needed(s, p))
            budget -= plan["shield"]
            if plan["shelter"]:
                plan["charge"] += budget  # no science while sheltering: bank the rest
            else:
                plan["science"] = budget
            return plan
        # night: only the battery
        b = s["battery"]
        if self.wants_shelter(alert) and b >= p["SHELTER_COST"]:
            plan["shelter"] = True
            b -= p["SHELTER_COST"]
        plan["life_support"] = min(self.night_ls, int(b + 1e-9))
        b -= plan["life_support"]
        if self.wants_greenhouse(s, p, False) and b >= p["GREENHOUSE_NIGHT"]:
            plan["greenhouse"] = True
            b -= p["GREENHOUSE_NIGHT"]
        if self.grow in ("night", "always") and s["food"] is not None:
            return plan  # night growers keep the rest of the battery for the greenhouse
        nights_after = p["TURNS_PER_LEVEL"] - s["turn"]
        spare = int(b - nights_after * self.night_ls + 1e-9)
        if spare > 0:
            plan["shield"] = min(spare, self.shield_needed(s, p))
            if not plan["shelter"]:
                plan["science"] = spare - plan["shield"]
        return plan


class FirstTimer(Policy):
    """A rough model of a new player: sensible-ish but random choices."""

    def __init__(self, rng):
        super().__init__("first-timer (random)", "Usually survives L1; loses at least once later")
        self.rng = rng

    def plan(self, s, p, is_day, alert):
        r, plan = self.rng, new_plan()
        if alert is not None and r.random() < (0.7 if alert["class"] == "X" else 0.4):
            plan["shelter"] = True
        budget = p["SOLAR_POWER"] if is_day else int(s["battery"] + 1e-9)
        if plan["shelter"]:
            if budget < p["SHELTER_COST"]:
                plan["shelter"] = False
            else:
                budget -= p["SHELTER_COST"]
        plan["life_support"] = min(r.choice([2, 3, 3, 3, 4]), budget)
        budget -= plan["life_support"]
        if s["food"] is not None:
            cost = p["GREENHOUSE_DAY"] if is_day else p["GREENHOUSE_NIGHT"]
            if budget >= cost and r.random() < (0.6 if is_day else 0.25):
                plan["greenhouse"] = True
                budget -= cost
        if is_day:
            plan["charge"] = r.randint(0, budget)
            budget -= plan["charge"]
        if s["shield"] < p["MAX_SHIELD"] and budget > 0 and r.random() < 0.4:
            plan["shield"] = r.randint(0, budget if is_day else min(2, budget))
            budget -= plan["shield"]
        if not plan["shelter"]:
            # by day the rest goes to science; at night a new player dabbles a little
            plan["science"] = budget if is_day else r.randint(0, min(2, budget))
        return plan


def strategies(p, food=False):
    night = p["LS_NEEDED"] * (p["TURNS_PER_LEVEL"] - p["DAY_TURNS"])  # battery the night needs
    pols = [
        Policy("all science, never charge", "Loses in Level 1 (Air runs out at night)"),
        Policy("bank Air by day, never charge", "(exploit check) should lose", day_ls="bank"),
        Policy("never shelter, no shield", "Loses in the last level from radiation", charge_to=night),
        Policy("always shelter, no shield", "Survives with a low score", charge_to=night + 6, shelter="always"),
        Policy("full shield early, never shelter", "Survives, decent score, must not beat everything",
               charge_to=night, shield_to=3),
        Policy("shelter on X, 1 shield", "Survives with a good score", charge_to=night + 4, shield_to=1, shelter="X"),
        Policy("shelter on X, 2 shields", "Survives with a good score", charge_to=night + 4, shield_to=2, shelter="X"),
    ]
    if food:  # same storm play as "shelter on X, 1 shield", different greenhouse habits
        smart = dict(shield_to=1, shelter="X")
        pols += [
            Policy("never use the greenhouse", "Runs out of food in Green Thumb", charge_to=night + 4, grow="never", **smart),
            Policy("greenhouse only at night", "Loses or scores low (grow lights eat the battery)",
                   charge_to=p["BATTERY_MAX"], grow="night", **smart),
            Policy("greenhouse always on", "Scores low; water runs low but needn't run out (calm meter)",
                   charge_to=p["BATTERY_MAX"], grow="always", **smart),
        ]
    return pols


# ---------------------------------------------------------------- running games
def play(p, levels, policy, retries=0):
    """Play the whole game. Returns a summary dict. Deterministic policies get no retries."""
    g = Game(p, levels)
    g.start_game()
    per_level, losses = [], []
    while True:
        stars_before = g.s["level_start"]["stars"]
        alert = g.alert_for_turn()
        result = g.take_turn(policy.plan(g.get_state(), p, g.is_day(), alert))
        if result["status"] == "continue":
            continue
        lvl = g.s["level"]
        if result["status"] == "lost":
            losses.append((lvl, result["reason"]))
            if len([l for l in losses if l[0] == lvl]) > retries:
                return dict(won=False, lost_at=lvl, reason=result["reason"], levels=per_level,
                            stars=g.s["stars"], dose=g.s["dose"], shield=g.s["shield"], losses=losses)
            g.retry_level()
            continue
        per_level.append(dict(stars=g.s["stars"] - stars_before, min_air=g.s["min_air"],
                              min_food=g.s["min_food"], min_water=g.s["min_water"],
                              end_battery=g.s["battery"], dose=g.s["dose"]))
        if result["status"] == "game_won":
            return dict(won=True, levels=per_level, stars=g.s["stars"], dose=g.s["dose"],
                        shield=g.s["shield"], losses=losses)
        g.next_level()


def describe(res):
    if not res["won"]:
        return "LOST at L%d (%s)  stars so far %d  dose %.1f" % (
            res["lost_at"], res["reason"], res["stars"], res["dose"])
    text = "WON  stars %3d  dose %5.1f  shield %d  min Air %s" % (
        res["stars"], res["dose"], res["shield"], "/".join("%d" % l["min_air"] for l in res["levels"]))
    fed = [l for l in res["levels"] if l["min_food"] is not None]
    if fed:
        text += "  min Food %d  min Water %d" % (min(l["min_food"] for l in fed), min(l["min_water"] for l in fed))
    return text


def first_timer_stats(p, levels, runs=2000, seed=1):
    rng = random.Random(seed)
    l1_first_try = fail_later = won = 0
    stars, reasons = [], {}
    for _ in range(runs):
        res = play(p, levels, FirstTimer(rng), retries=4)
        lost_levels = [l for l, _ in res["losses"]]
        for _, why in res["losses"]:
            reasons[why] = reasons.get(why, 0) + 1
        l1_first_try += 1 not in lost_levels
        fail_later += any(l > 1 for l in lost_levels)
        won += res["won"]
        if res["won"]:
            stars.append(res["stars"])
    pct = lambda n: "%d%%" % round(100 * n / runs)
    why = ", ".join("%s %d" % kv for kv in sorted(reasons.items(), key=lambda kv: -kv[1]))
    return ("passes L1 first try %s, fails a later level at least once %s, finishes within 5 tries %s,"
            " avg stars %d\n%38s losses by cause: %s"
            % (pct(l1_first_try), pct(fail_later), pct(won), sum(stars) / max(1, len(stars)), "", why or "none"))


def report(name, p, weather, big, food):
    levels = build_levels(p, weather, big, food)
    print("\n=== numbers: %s%s ===" % (name, " + food and water" if food else ""))
    changed = {k: v for k, v in p.items() if PRESETS["plan"].get(k) != v}
    print("changes from the plan: %s" % (changed or "none"))
    for i, lv in enumerate(levels, start=1):
        storms = "  ".join("t%d %s%s" % (s["turn"], s["class"], "*" if s["followed"] else "") for s in lv["storms"])
        print("L%d %-14s %s%s" % (i, lv["name"], "food+water  " if lv["food"] else "",
                                  ("storms from %s: %s" % (lv["window"], storms)) if lv["storms"] else "no storms"))
    print("   (* = a real particle storm followed)")
    for pol in strategies(p, food):
        print("  %-34s %-80s target: %s" % (pol.name, describe(play(p, levels, pol)), pol.target))
    print("  %-34s %s" % ("first-timer (random, 2000 games)", first_timer_stats(p, levels)))


def window_sweep(name, p, weather, food):
    """Every 2024 start date with at least 5 alert turns as the last level: how robust is each strategy?"""
    starts = []
    d = dt.date(2024, 1, 1)
    while d <= dt.date(2024, 12, 3):
        if len(storms_for_window(d.isoformat(), p)) >= 5:
            starts.append(d.isoformat())
        d += dt.timedelta(days=1)
    print("\n=== numbers: %s | last level swept over %d stormy 2024 windows ===" % (name, len(starts)))
    for pol in strategies(p, food):
        results = [play(p, build_levels(p, weather, s, food), pol) for s in starts]
        wins = [r for r in results if r["won"]]
        print("  %-34s wins %3d%%  avg stars when won %5.1f  avg dose %5.1f" % (
            pol.name, round(100 * len(wins) / len(results)),
            sum(r["stars"] for r in wins) / max(1, len(wins)), sum(r["dose"] for r in results) / len(results)))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--preset", choices=sorted(PRESETS), help="run one preset only")
    ap.add_argument("--set", nargs="*", default=[], metavar="NAME=VALUE", help="override numbers")
    ap.add_argument("--l2", default="2024-01-13", help="start date of the real window for Space Weather")
    ap.add_argument("--l3", default="2024-05-05", help="start date of the real window for The Big One")
    ap.add_argument("--food", action="store_true", help="add food and water and a Green Thumb level")
    ap.add_argument("--windows", action="store_true", help="sweep the last level over every stormy 2024 window")
    a = ap.parse_args()
    names = [a.preset] if a.preset else (["plan"] if a.set else ["plan", "fix", "tuned"])
    for name in names:
        p = copy.deepcopy(PRESETS[name])
        for kv in a.set:
            k, v = kv.split("=", 1)
            p[k] = json.loads(v)
        label = name + (" + " + " ".join(a.set) if a.set else "")
        report(label, p, a.l2, a.l3, a.food)
        if a.windows:
            window_sweep(label, p, a.l2, a.food)


if __name__ == "__main__":
    main()

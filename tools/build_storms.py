#!/usr/bin/env python3
"""Builds storms_data.gd (the Godot game's saved storm data) from real NASA records.

  python3 tools/build_storms.py --offline        # from tools/donki_alerts_2024.json, no internet
  python3 tools/build_storms.py --years 2024     # from the live DONKI and RadLab APIs

Python 3, standard library only. See HANDOVER.md sections 5.1 to 5.7.

What it does
  1. Gets the flare alerts: class X or M5+ flares that came with a real alert
     (a non-empty sentNotifications) from NASA's Moon to Mars Space Weather
     Analysis Office. An alert "followed" if a particle storm (SEP) is linked to
     the flare in either direction.
  2. Counts how often each flare class was followed by a storm (the dots out of 10).
  3. Cuts each real 28-day window into 14 two-day turns.
  4. Online only: adds the radiation measured at the Moon by LRO/CRaTER (per-turn
     mean, from NASA OSDR RadLab) and a snapshot of the last 30 days of the Sun.

Nothing here is invented: every date, class and link is copied from DONKI, and
every dose value is a mean of RadLab rows. If the network fails, the existing
storms_data.gd is left as it is.
"""
import argparse
import csv
import datetime as dt
import io
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OFFLINE_JSON = os.path.join(HERE, "donki_alerts_2024.json")
CACHE_DIR = os.path.join(HERE, "cache")
OUT_GD = os.path.join(ROOT, "storms_data.gd")

DONKI = "https://ccmc.gsfc.nasa.gov/DONKI/WS/get/"   # moved here on 2026-09-30; no API key
RADLAB = "https://visualization.osdr.nasa.gov/radlab/api/"
MAX_DAYS = 60                # DONKI refuses longer date ranges
CHUNK_DAYS = 55              # stay well inside the limit
SLEEP_SECONDS = 1            # be polite between calls
TIMEOUT_SECONDS = 60
TRIES = 3                    # per request, with a pause between tries

# Must match game_numbers.gd.
TURNS_PER_LEVEL = 14
DAYS_PER_TURN = 2

# The real stretches of 2024 used as levels, default first (HANDOVER.md section 5.4).
WINDOWS = {
    "space_weather": ["2024-01-13", "2024-08-22"],
    "big_one": ["2024-05-05", "2024-09-29"],
}
BIG_ONE_MIN_STORM_TURNS = 3  # with fewer, ignoring storms becomes a safe strategy
MOON_INSTRUMENT = "CRaTER-D1D2"
LIVE_WINDOW_DAYS = 30


# ---------------------------------------------------------------- network
def fetch(url, cache_name=None, refresh=False):
    """GET a URL as text. Raw responses are cached in tools/cache/ when cache_name is given."""
    path = os.path.join(CACHE_DIR, cache_name) if cache_name else None
    if path and not refresh and os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            return f.read()
    for attempt in range(1, TRIES + 1):
        try:
            with urllib.request.urlopen(url, timeout=TIMEOUT_SECONDS) as resp:
                text = resp.read().decode("utf-8")
            break
        except (urllib.error.URLError, OSError) as err:   # e.g. a passing "502 Proxy Error"
            if attempt == TRIES:
                raise
            print("  retrying after: %s" % err, file=sys.stderr)
            time.sleep(5 * attempt)
    time.sleep(SLEEP_SECONDS)
    if path:
        os.makedirs(CACHE_DIR, exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
    return text


def chunks(first, last):
    """Split [first, last] (dates, both included) into ranges DONKI accepts."""
    start = first
    while start <= last:
        end = min(last, start + dt.timedelta(days=CHUNK_DAYS))
        yield start, end
        start = end + dt.timedelta(days=1)


def donki(kind, first, last, refresh=False, cache=True):
    """All DONKI records of one kind ("FLR" or "SEP") between two dates, without duplicates."""
    id_key = {"FLR": "flrID", "SEP": "sepID"}[kind]
    seen, out = set(), []
    for start, end in chunks(first, last):
        assert (end - start).days <= MAX_DAYS
        url = "%s%s?startDate=%s&endDate=%s" % (DONKI, kind, start.isoformat(), end.isoformat())
        name = "donki_%s_%s_%s.json" % (kind, start.isoformat(), end.isoformat()) if cache else None
        text = fetch(url, name, refresh)
        try:
            records = json.loads(text) if text.strip() else []
        except ValueError:
            if name and os.path.exists(os.path.join(CACHE_DIR, name)):
                os.remove(os.path.join(CACHE_DIR, name))   # don't keep an error page in the cache
            raise RuntimeError("DONKI did not send JSON for %s: %s" % (url, text[:120]))
        for rec in records:
            if rec.get(id_key) not in seen:
                seen.add(rec.get(id_key))
                out.append(rec)
    return out


# ---------------------------------------------------------------- alerts
def strength(full_class):
    """X beats M, then the higher magnitude."""
    return (2 if full_class[0] == "X" else 1, float(full_class[1:] or 1))


def is_alert(flare):
    cls = flare.get("classType") or ""
    if not cls or not flare.get("peakTime") or not flare.get("sentNotifications"):
        return False
    try:
        magnitude = float(cls[1:] or 1)
    except ValueError:
        return False
    return cls[0] == "X" or (cls[0] == "M" and magnitude >= 5)


def linked_ids(record):
    return [e.get("activityID", "") for e in (record.get("linkedEvents") or [])]


def alerts_from_donki(flares, seps):
    """Alerts in the same shape as tools/donki_alerts_2024.json: peak, class, followed, link."""
    flares_named_by_seps = set()
    for sep in seps:
        flares_named_by_seps.update(i for i in linked_ids(sep) if "-FLR-" in i)
    alerts = []
    for f in flares:
        if not is_alert(f):
            continue
        # The links are not symmetric, so check both directions.
        followed = any("-SEP-" in i for i in linked_ids(f)) or f["flrID"] in flares_named_by_seps
        alerts.append({"peak": f["peakTime"], "class": f["classType"], "followed": followed, "link": f["link"]})
    alerts.sort(key=lambda a: a["peak"])
    return alerts


def chance_table(alerts):
    """How many alerts of each class were followed by a storm, and the dots out of 10."""
    table = {}
    for cls in ("X", "M"):
        mine = [a for a in alerts if a["class"][0] == cls]
        followed = sum(1 for a in mine if a["followed"])
        dots = int(10.0 * followed / len(mine) + 0.5) if mine else 0
        table[cls] = {"followed": followed, "total": len(mine), "dots": dots}
    return table


def window_turns(start, alerts):
    """A real 28-day window -> the turns that have alerts (1 turn = 2 days, UTC)."""
    t0 = dt.datetime.fromisoformat(start)
    by_turn = {}
    for a in alerts:
        peak = dt.datetime.strptime(a["peak"], "%Y-%m-%dT%H:%MZ")
        i = (peak - t0).days // DAYS_PER_TURN
        if 0 <= i < TURNS_PER_LEVEL:
            by_turn.setdefault(i + 1, []).append(a)
    turns = []
    for turn in sorted(by_turn):
        flares = sorted(by_turn[turn], key=lambda a: a["peak"])
        top = max(flares, key=lambda a: strength(a["class"]))   # the first of equals: the earliest
        turns.append({
            "turn": turn,
            "shown": {"cls": top["class"][0], "full_class": top["class"], "peak": top["peak"], "link": top["link"]},
            "followed": any(a["followed"] for a in flares),
            "flares": [{"full_class": a["class"], "peak": a["peak"], "link": a["link"], "followed": a["followed"]}
                       for a in flares],
        })
    return turns


# ---------------------------------------------------------------- radiation at the Moon
class NoMoonData(Exception):
    """RadLab answered, but has no rows for this window."""


def moon_dose(start, refresh=False):
    """Per-turn mean absorbed dose rate (µGy/h) measured by LRO/CRaTER, from OSDR RadLab.
    Returns (list of 14 numbers or None for a turn with no data, quietest daily mean)."""
    t0 = dt.datetime.fromisoformat(start)
    end = t0 + dt.timedelta(days=TURNS_PER_LEVEL * DAYS_PER_TURN)
    # The filters are "timestamp>" = START and "timestamp<END": the "=" must stay a literal "=".
    url = ("%s?celestial_body=Moon&instrument_id&timestamp%%3E=%s&timestamp%%3C%s&absorbed_dose_rate&format=csv"
           % (RADLAB, t0.date().isoformat(), end.date().isoformat()))
    name = "radlab_moon_%s.csv" % start
    text = fetch(url, name, refresh)
    if not text.startswith("timestamp,"):
        os.remove(os.path.join(CACHE_DIR, name))   # don't keep an error reply in the cache
        raise RuntimeError("RadLab did not send the expected CSV: %s" % text[:120].strip())
    rows = list(csv.DictReader(io.StringIO(text)))
    per_turn = [[] for _ in range(TURNS_PER_LEVEL)]
    per_day = {}
    for row in rows:
        if row["instrument_id"] != MOON_INSTRUMENT or not row["absorbed_dose_rate"]:
            continue
        stamp = dt.datetime.fromisoformat(row["timestamp"][:19])
        i = (stamp - t0).days // DAYS_PER_TURN
        if 0 <= i < TURNS_PER_LEVEL:
            value = float(row["absorbed_dose_rate"])
            per_turn[i].append(value)
            per_day.setdefault(stamp.date(), []).append(value)
    if not any(per_turn):
        # Not an error: RadLab's CRaTER record stops on 2024-06-18 (checked 2026-11-14).
        raise NoMoonData("RadLab has no %s rows for the window starting %s" % (MOON_INSTRUMENT, start))
    means = [round(sum(v) / len(v), 2) if v else None for v in per_turn]
    quiet = round(min(sum(v) / len(v) for v in per_day.values()), 2)
    return means, quiet


# ---------------------------------------------------------------- the last 30 days
def live_snapshot(today):
    """The numbers the title screen shows when the live fetch fails (section 5.8)."""
    first = today - dt.timedelta(days=LIVE_WINDOW_DAYS)
    flares = donki("FLR", first, today, cache=False)
    seps = donki("SEP", first, today, cache=False)
    big = [f for f in flares if (f.get("classType") or "")[:1] in ("M", "X") and f.get("peakTime")]
    big.sort(key=lambda f: f["peakTime"])
    latest = {"full_class": big[-1]["classType"], "date": big[-1]["peakTime"][:10]} if big else None
    return {"saved_on": today.isoformat(), "window_days": LIVE_WINDOW_DAYS, "big_flares": len(big),
            "latest": latest, "particle_storms": len(seps)}


# ---------------------------------------------------------------- output
HEADER = """# storms_data.gd: the saved storm data. GENERATED by tools/build_storms.py -- do not edit by hand.
#
# Real solar flare alerts from NASA's DONKI database, cut into two-day turns.
# %s
#
# `followed` says whether a particle storm really followed a flare. Only the
# rules (game_state.gd) may read it, and only after the turn is played: no peeking.
extends RefCounted

const DATA := %s
"""


def write_gd(data, note):
    # JSON is also a valid GDScript literal (true, false, null, strings, numbers, [], {}).
    with open(OUT_GD, "w", encoding="utf-8") as f:
        f.write(HEADER % (note, json.dumps(data, indent="\t", ensure_ascii=True)))


def describe(data):
    for key, windows in data["windows"].items():
        for w in windows:
            marks = "  ".join("t%d %s%s" % (t["turn"], t["shown"]["full_class"], "*" if t["followed"] else "")
                              for t in w["turns"])
            print("  %-12s %s  %s" % (key, w["start"], marks))
    print("  (* = a real particle storm followed)")
    print("  chance: %s" % json.dumps(data["chance"]))
    print("  live_snapshot: %s" % json.dumps(data["live_snapshot"]))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--offline", action="store_true", help="build from tools/donki_alerts_2024.json, no internet")
    ap.add_argument("--years", nargs="*", type=int, default=[2024], help="years of DONKI alerts to fetch (online)")
    ap.add_argument("--refresh", action="store_true", help="ignore tools/cache/ and fetch again")
    a = ap.parse_args()
    today = dt.datetime.now(dt.timezone.utc).date()

    with open(OFFLINE_JSON, encoding="utf-8") as f:
        extract = json.load(f)

    if a.offline:
        alerts = sorted(extract["alerts"], key=lambda x: x["peak"])
        found = re.search(r"downloaded (\d{4}-\d{2}-\d{2})", extract.get("source", ""))
        saved_on = found.group(1) if found else dt.date.fromtimestamp(os.path.getmtime(OFFLINE_JSON)).isoformat()
        source = "NASA DONKI (ccmc.gsfc.nasa.gov/DONKI)"
        note = "Built OFFLINE from tools/donki_alerts_2024.json (saved %s). No Moon dose, no Sun snapshot." % saved_on
        snapshot = None
    else:
        try:
            flares, seps = [], []
            for year in sorted(a.years):
                first = dt.date(year, 1, 1)
                last = min(dt.date(year, 12, 31), today)
                flares += donki("FLR", first, last, a.refresh)
                # a storm can follow a late-December flare into January
                seps += donki("SEP", first, min(last + dt.timedelta(days=14), today), a.refresh)
            alerts = alerts_from_donki(flares, seps)
            snapshot = live_snapshot(today)
        except (urllib.error.URLError, OSError, RuntimeError) as err:
            print("DONKI fetch failed: %s" % err, file=sys.stderr)
            print("storms_data.gd was NOT changed. Use --offline to rebuild from the saved extract.", file=sys.stderr)
            return 1
        saved_on = today.isoformat()
        source = "NASA DONKI (ccmc.gsfc.nasa.gov/DONKI)"
        note = "Built ONLINE on %s from DONKI FLR and SEP records for %s." % (
            saved_on, ", ".join(str(y) for y in sorted(a.years)))
        if 2024 in a.years:
            key = lambda x: (x["peak"], x["class"], x["followed"], x["link"])
            diff = set(map(key, alerts)) ^ set(map(key, extract["alerts"]))
            print("online alerts for 2024 vs the saved extract: %s" % (
                "identical (%d alerts)" % len(alerts) if not diff else "%d differences: %s" % (len(diff), sorted(diff))))

    data = {
        "saved_on": saved_on,
        "source": source,
        "chance": chance_table(alerts),
        "windows": {},
        "moon_quiet": None,
        "live_snapshot": snapshot,
    }
    moon_ok, quiet_days = not a.offline, []
    for key, starts in WINDOWS.items():
        data["windows"][key] = []
        for start in starts:
            w = {"start": start, "turns": window_turns(start, alerts), "moon_dose": None}
            if moon_ok:
                try:
                    w["moon_dose"], quiet = moon_dose(start, a.refresh)
                    quiet_days.append(quiet)
                except NoMoonData as err:
                    print("note: %s: its moon_dose is null." % err, file=sys.stderr)
                except (urllib.error.URLError, OSError, RuntimeError, ValueError) as err:
                    print("RadLab fetch failed (%s): moon_dose is null for every window." % err, file=sys.stderr)
                    moon_ok = False
            data["windows"][key].append(w)
            storm_turns = sum(1 for t in w["turns"] if t["followed"])
            if key == "big_one" and storm_turns < BIG_ONE_MIN_STORM_TURNS:
                print("WARNING: big_one window %s has only %d storm turns" % (start, storm_turns), file=sys.stderr)
    if moon_ok and quiet_days:
        # "A quiet day" for the debrief chart: the quietest daily mean in any saved window.
        data["moon_quiet"] = min(quiet_days)
        data["source"] += ", NASA OSDR RadLab (LRO/CRaTER)"
        note += " Moon dose: RadLab %s per-turn means, in µGy/h." % MOON_INSTRUMENT
    else:
        for windows in data["windows"].values():
            for w in windows:
                w["moon_dose"] = None

    write_gd(data, note)
    print("wrote %s (%d alerts)" % (os.path.relpath(OUT_GD, ROOT), len(alerts)))
    describe(data)
    return 0


if __name__ == "__main__":
    sys.exit(main())

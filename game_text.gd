extends RefCounted
## Every word a player reads. No logic.
##
## Change wording here without touching the rules. Placeholders like {name} are
## filled with String.format(). The strings in `messages` and `tips` are also
## returned by the rules (game_state.gd) and must not contain placeholders.
##
## FACTS: a science sentence marked TODO(verify) has NOT been checked by a human
## yet. Do not remove a mark, or set "verified": true, without checking the
## source (HANDOVER.md section 12).
##
## Plain characters only: the default Godot font has no emoji.

const TEXT := {
	"title": {
		"name": "Lunar Night Shift",
		"tagline": "Keep a Moon base running through the long night.",
		"how_to": [
			"The sun gives you 10 power each turn. Share it out.",
			"Night is coming. Charge the battery while it's light.",
			"Real solar flares set off alerts. Shelter, or stay and do science?",
		],
		"start": "Start the mission",
		"science": "Science Behind It",
		"back": "Back",
		"disclaimer": "Not made or endorsed by NASA. Uses public NASA data.",
	},
	"levels": [
		{
			"name": "First Night",
			"intro": "Welcome to the Moon base! The sun gives 10 power each turn, but only for 7 turns. Then comes night: 7 turns on battery power alone. Air needs power every turn.",
		},
		{
			"name": "Green Thumb",
			"intro": "A supply lander brought 16 days of food, and the crew eats 2 each turn. Grow more in the greenhouse. It is cheap in sunlight and costly at night.",
		},
		{
			"name": "Space Weather",
			"intro": "Mission Control is watching the Sun. Every alert on this level is a real flare. Sheltering costs power and science. Radiation never goes away.",
		},
		{
			# TODO(verify): how the May 2024 storm is described. This wording only says what the saved DONKI alerts show.
			"name": "The Big One",
			"intro": "May 2024: big flares came almost every turn. Is it better to build a shield, or to shelter each time? Power is short. Choose with care.",
		},
	],
	"intro": {
		"level": "LEVEL {n} OF {total}",
		"real_dates": "This month really happened: {from} to {to}.",
		"go": "Start the level",
	},
	"dates": {
		"months_short": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
		"months_long": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"],
	},
	"rooms": {
		"base": "1  Base",
		"greenhouse": "2  Greenhouse",
		"base_placeholder": "MOON BASE",
		"greenhouse_placeholder": "GREENHOUSE / STATE {state}",
		"base_quiet": "No flare alert this turn",
		"base_alert": "Flare alert: {full_class}",
		# the small signs under each building in the Moon base picture
		"labels": {
			"solar": "Solar panels",
			"battery": "Battery",
			"science": "Science lab",
			"base": "Main base",
			"shelter": "Shelter",
			"greenhouse": "Greenhouse",
			"water": "Water",
		},
		"shield_status": "Shield {shield} of {max}",
		"shield_progress": "next layer {done} of {cost} power",
		"shield_full": "shield full",
		"sheltering": "Crew in the shelter",
		"in_base": "Crew in the main base",
		"greenhouse_on": "Greenhouse ON: growing {food} food this turn",
		"greenhouse_off": "Greenhouse OFF",
		"greenhouse_none": "The greenhouse opens on Level 2",
		"greenhouse_cost": "costs {cost} power now",
		"food_left": "Food for {turns} more turns",
	},
	"hud": {
		"line": "LEVEL {level}  {name}    TURN {turn} / {total}    {phase}    STARS {stars}",
		"line_dates": "LEVEL {level}  {name}    TURN {turn} / {total}    {phase}    {dates}    STARS {stars}",
		"radiation": "RADIATION {dose}/{limit}",
	},
	"meters": {
		"battery": "Battery",
		"air": "Air",
		"water": "Water",
		"food": "Food",
		"radiation": "Radiation",
		"shield": "Shield",
		"stars": "Stars",
		"recycler_on": "Recycler on",
		"recycler_off": "Recycler OFF",
		"day": "DAY",
		"night": "NIGHT",
		"turn": "Turn {turn} of {total}",
		"low": "LOW",
		"new": "NEW",
	},
	"controls": {
		"life_support": "Life support",
		"shield": "Shield",
		"science": "Science",
		"charge": "Charge battery",
		"charge_day_only": "Day only",
		"greenhouse": "Greenhouse",
		"greenhouse_cost": "1 power by day, 4 at night",
		"end_turn": "End turn",
		"power_left": "POWER LEFT {n}",
		"power_from_sun": "{n} from the sun",
		"power_from_battery": "{n} from the battery",
		"mute": "Sound",
		"sound_on": "Sound: on",
		"sound_off": "Sound: off",
		"on": "ON",
		"off": "OFF",
		"title": "Quit to title",
		"hints": {
			"life_support": "3 keeps Air steady. Less: Air drops.",
			"shield": "8 power builds 1 layer. It lasts forever.",
			"science": "1 power = 1 star.",
			"charge": "1 power puts 0.8 in the battery.",
			"greenhouse": "Grows 3 food. Uses 1 water.",
			"no_science_shelter": "No science in the shelter.",
		},
	},
	"alert": {
		"heading": "STORM ALERT",
		"title": "Mission Control spotted an {full_class} flare!",
		"chance": "About {dots} in 10 flares like this sent a radiation storm.",
		"shelter": "Shelter ({cost} power, no science)",
		"stay": "Stay in the main base",
		"chosen": "> {text} <",
		"choose": "Storm alert! Choose: shelter or stay.",
		"when": "Flare seen on {date}",
	},
	# What happened on the turn just played (shown only after the turn).
	"report": {
		"heading": "Last turn",
		"storm": "The {full_class} flare sent a radiation storm.",
		"storm_other": "A radiation storm came.",
		"false_alarm": "False alarm: no storm followed the {full_class} flare.",
		"sheltered": "You sheltered: Radiation +{dose}.",
		"stayed": "You stayed in the base: Radiation +{dose}.",
		"sheltered_nothing": "You sheltered, just in case.",
		"stayed_nothing": "You stayed and kept working.",
	},
	# Returned by the rules (game_state.gd): no placeholders here.
	"messages": {
		"negative": "No negative power",
		"ls_max": "Life support can't go above 5",
		"no_charge_night": "No sunlight: you can't charge at night",
		"no_science_shelter": "No science while sheltering",
		"no_alert": "No storm alert this turn",
		"shield_full": "The shield is already full",
		"no_greenhouse": "No greenhouse on this level",
		"not_enough_power": "Not enough power",
		"level_over": "This level is over",
		"night_hint": "Night! Only battery power now.",
		"new_meters": "New! Food and Water. Grow food in the greenhouse.",
	},
	# Returned by the rules (game_state.gd): no placeholders here.
	"tips": {
		"lost_air": "Life support needs power every turn, even at night. Charge the battery in daylight.",
		"lost_dose": "Radiation never goes away. Build shielding, or shelter when a big flare is spotted.",
		"lost_food": "Grow food while the sun shines: the greenhouse costs 1 power by day but 4 at night.",
		"lost_water": "Keep life support at 3 or more so the water recycler keeps running.",
		"high_dose": "You made it, but your radiation is high. The next levels have more storms.",
		"default": "Great work. Could you earn more stars without losing safety?",
	},
	"debrief": {
		"won": "Level complete!",
		"game_won": "Mission complete! The crew is safe.",
		"lost": "Mission Control brings the crew home.",
		"why": {
			"air": "The Air ran out.",
			"dose": "The crew took in too much radiation.",
			"food": "The food ran out.",
			"water": "The water ran out.",
			"won": "You kept the base running for all 14 turns.",
		},
		"tip_heading": "TIP",
		"score": "Stars {stars}    Radiation {dose} of {limit}    Shield {shield} of {max}",
		"storms_heading": "The real flares on this level",
		"no_storms_played": "No alerts came before the level ended.",
		"storm_turn": "Turn {turn} · {full_class}",
		"storm_card": "This flare really happened on {date}, recorded in NASA's DONKI database.",
		"storm_link": "See the {full_class} flare in DONKI",
		"followed_yes": "A radiation storm followed.",
		"followed_no": "False alarm: no storm followed.",
		"sheltered": "You sheltered.",
		"stayed": "You stayed in the main base.",
		"dose_gain": "Radiation +{dose}",
		"caused_by": "The storm came from the {full_class} flare on {date}.",
		"caused_by_many": "Storms followed these flares in the same two days:",
		"storm_link_short": "{full_class} flare, {date}",
		"recycler_saved": "Your recycler saved {n} water this level.",
		"battery_chart": "Your battery, turn by turn",
		"battery_chart_note": "Turns 1 to 7 are day. Turns 8 to 14 are night.",
		"moon_chart": "Radiation measured at the Moon",
		# The numbers are per-turn means from NASA OSDR RadLab (LRO/CRaTER), checked against the API on 2026-11-14.
		"moon_chart_note": "Real measurements from the CRaTER instrument on NASA's Lunar Reconnaissance Orbiter. Each bar shows how many times stronger the radiation was than on a quiet day. The game's storms follow DONKI's records, so the bars and the storm marks do not always match. Saved on {date}.",
		"moon_times": "{n}×",
		"moon_storm": "storm",
		"reflection": "What would you do differently next time?",
		"next": "Next level",
		"retry": "Try this level again",
		"again": "Play again from Level 1",
	},
	"live": {
		"heading": "THE SUN RIGHT NOW",
		"loading": "Checking the Sun…",
		"live_label": "LIVE · checked {time} UTC",
		"saved_label": "Saved on {date}",
		"big_flares": "Big flares in the last 30 days: {n}",
		"latest": "Latest big flare: {full_class} on {date}",
		"no_latest": "No big flares in the last 30 days.",
		"particle_storms": "Particle storms: {n}",
		"quiet": "Quiet",
		"busy": "Busy",
		"very_busy": "Very busy",
		"unavailable": "No Sun data right now. The game still works.",
		"source": "Data: NASA DONKI",
	},
	"science": {
		"heading": "Science Behind It",
		"intro": "This is a game, so some things are simpler than real life. Here is what is real and what is simplified.",
		"game_column": "IN THE GAME",
		"real_column": "IN REAL LIFE",
		"unverified": "(We are still checking this fact.)",
		"rows": [
			{
				"game": "Every storm alert is a real solar flare.",
				"real": "The flares, their dates and whether a particle storm followed come from NASA's DONKI database for 2024.",
				"verified": true,  # checked against the DONKI API on 2026-11-14 (HANDOVER.md section 12)
			},
			{
				"game": "The storm chance is shown as dots out of 10.",
				"real": "In 2024, 14 of 54 X-class alerts and 9 of 82 strong M-class alerts were followed by a particle storm. The game uses only the flare class. Real forecasters use much more, and still get false alarms.",
				"verified": true,  # the counts were checked against the DONKI API on 2026-11-14
			},
			{
				# TODO(verify): lunar day and night are each about 14 Earth days.
				"game": "One turn is 2 days. A level has 7 day turns and 7 night turns.",
				"real": "A real day on the Moon lasts about 14 Earth days. So does a real night.",
				"verified": false,
			},
			{
				# TODO(verify): wording about real battery losses.
				"game": "Charging loses 20% of the power.",
				"real": "Real batteries lose some energy too. The 20% is a game number.",
				"verified": false,
			},
			{
				# TODO(verify): against NASA-STD-3001 radiation limits.
				"game": "The Radiation bar goes from 0 to 100.",
				"real": "This is a simple stand-in. Real radiation dose is measured in millisieverts, and space agencies set career limits for astronauts.",
				"verified": false,
			},
			{
				# TODO(verify): what real storm shelters are made of.
				"game": "The shelter and the shield cut storm radiation.",
				"real": "Real shelters use thick walls of water, supplies or Moon dirt.",
				"verified": false,
			},
			{
				# TODO(verify): storm particles reach the Moon's night side.
				"game": "Storms can hit at night.",
				"real": "Storm particles can reach the Moon's night side too.",
				"verified": false,
			},
			{
				# TODO(verify): cosmic rays as a steady background dose.
				"game": "Radiation only comes from storms.",
				"real": "There are also cosmic rays, all the time. The game leaves them out.",
				"verified": false,
			},
			{
				# TODO(verify): crop growth times (NASA Veggie).
				"game": "The greenhouse grows food in one turn.",
				"real": "Real crops take weeks to grow.",
				"verified": false,
			},
			{
				# TODO(verify): ISS water recovery is about 98% (NASA, 2023).
				"game": "The recycler halves the water you lose.",
				"real": "The International Space Station recycles about 98% of its water.",
				"verified": false,
			},
		],
		"datasets_heading": "The NASA data in this game",
		"datasets": [
			{
				"name": "DONKI: Space Weather Database Of Notifications, Knowledge, Information",
				"url": "https://ccmc.gsfc.nasa.gov/DONKI/",
				"why": "Run by NASA's Community Coordinated Modeling Center with the Moon to Mars Space Weather Analysis Office. It gives every flare alert in the game, and tells us whether a particle storm followed.",
			},
			{
				"name": "OSDR RadLab: radiation measured by LRO's CRaTER instrument",
				"url": "https://visualization.osdr.nasa.gov/radlab/",
				"why": "It gives the radiation really measured at the Moon during each storm level. You see it in the chart after the level. It never changes the game.",
			},
		],
		"credits_heading": "Credits",
		"credits": [
			"Flare and particle storm records: NASA DONKI (CCMC and the Moon to Mars Space Weather Analysis Office).",
			"Moon radiation measurements: NASA OSDR RadLab, from the CRaTER instrument on the Lunar Reconnaissance Orbiter.",
			"For real space weather forecasts, the official United States source is NOAA's Space Weather Prediction Center.",
		],
		"saved_note": "The storm data in this game was saved on {date}.",
		"disclaimer": "Not made or endorsed by NASA. Uses public NASA data.",
	},
}

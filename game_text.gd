extends RefCounted
## Every word a player reads. No logic.
##
## Change wording here without touching the rules. Placeholders like {name} are
## filled with String.format(). The strings in `messages` and `tips` are also
## returned by the rules (game_state.gd) and must not contain placeholders.
##
## FACTS: a science sentence marked TODO(verify) has NOT been checked by a human
## yet. Do not remove a mark, or set "verified": true, without checking the
## source (HANDOVER.md section 12). Unchecked facts stay on the Science page
## with a "still checking" mark and are never shown in play.
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
		"start_short": "Short game",
		"start_full": "Full game",
		"short_note": "{levels} levels of {turns} turns. A good first game.",
		"full_note": "{levels} levels of {turns} turns, with food and water.",
		"science": "Science Behind It",
		"back": "Back",
		"disclaimer": "Not made or endorsed by NASA. Uses public NASA data.",
	},
	"levels": [
		{
			"name": "First Night",
			"intro": "Welcome to the Moon base! The sun gives 10 power each turn, but only for 7 turns. Then comes night: 7 turns on battery power alone. Air needs power every turn.",
			"question": "How much battery did the night need? Did you save too much, or too little?",
		},
		{
			"name": "Green Thumb",
			"intro": "A supply lander brought 16 days of food, and the crew eats 2 each turn. Grow more in the greenhouse. It is cheap in sunlight and costly at night.",
			"question": "When was the best time to run the greenhouse? Why?",
		},
		{
			"name": "Space Weather",
			"intro": "Mission Control is watching the Sun. Every alert on this level is a real flare. An X storm hits harder than an M storm. Sheltering costs power and science. Radiation never goes away.",
			"question": "Would you shelter again on a 1 in 10 alert? What would you give up?",
		},
		{
			# Checked by the team, 2026-11-15. The wording only says what the saved DONKI alerts show.
			"name": "The Big One",
			"intro": "May 2024: big flares came almost every turn. Is it better to build a shield, or to shelter each time? Power is short. Choose with care.",
			"question": "Which kept the crew safer: the shield, or the shelter? Why?",
		},
	],
	# The short game: the same base and the same real flares, in fewer turns.
	"levels_short": [
		{
			"name": "First Night",
			"intro": "Welcome to the Moon base! The sun gives 10 power each turn, but only for 4 turns. Then comes night: 4 turns on battery power alone. Air needs power every turn.",
			"question": "How much battery did the night need? Did you save too much, or too little?",
		},
		{
			"name": "Space Weather",
			"intro": "Mission Control is watching the Sun. Every alert on this level is a real flare. An X storm hits harder than an M storm. Shelter, or stay and do science?",
			"question": "Would you shelter again on a 1 in 10 alert? What would you give up?",
		},
		{
			# Checked by the team, 2026-11-15. The wording only says what the saved DONKI alerts show.
			"name": "The Big One",
			"intro": "May 2024: big flares came turn after turn. Build a shield, or shelter each time? Choose with care.",
			"question": "Which kept the crew safer: the shield, or the shelter? Why?",
		},
	],
	# The three stars of a level, and the missions. Both are made up for the game.
	"stars": {
		"heading": "EARN 3 STARS",
		"safe": "Keep the crew safe to the end",
		"science": "Earn {goal} science",
		"science_now": "Earn {goal} science (you have {now})",
		"missions_one": "Finish 1 mission",
		"missions_many": "Finish {goal} missions",
		"missions_now": "{text} ({now} done)",
		"total": "Whole game: {earned} of {possible} stars",
		"level_stars": "{n} of 3 stars",
		"none": "No stars this time. Stars are for levels you finish.",
	},
	"missions": {
		"line": "MISSION  {name}: {ask}  (+{reward} science)",
		"ready": "MISSION READY  {name}: your plan does it!  (+{reward} science)",
		"next": "Next mission: {name}, on turn {turn}.",
		"none_left": "No more missions on this level.",
		"done": "Mission done: {name}. Science +{reward}.",
		"missed": "Mission missed: {name}.",
		"debrief_heading": "Missions",
		"debrief_done": "Turn {turn}: {name}, done (+{reward} science)",
		"debrief_missed": "Turn {turn}: {name}, missed",
		"names": {
			"sample_run": "Sample run",
			"big_experiment": "Big experiment",
			"night_survey": "Night survey",
			"charge_up": "Charge up",
			"deep_clean": "Fresh air",
			"dig_crew": "Dig crew",
			"night_harvest": "Night harvest",
		},
		# {n} is the mission's amount, from game_numbers.gd
		"asks": {
			"sample_run": "put {n} or more power into Science",
			"big_experiment": "put {n} or more power into Science",
			"night_survey": "put {n} or more power into Science tonight",
			"charge_up": "put {n} or more power into the battery",
			"deep_clean": "set Life support to {n} or more",
			"dig_crew": "put {n} or more power into the Shield",
			"night_harvest": "run the greenhouse tonight",
		},
	},
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
		"back": "<  Back to the base",
		"click_hint": "Click a building to open it",
		"look_inside": "Look inside",
		"close": "X",
		"no_alert": "No storm alert this turn.",
		"science_so_far": "Science on this level: {science} of {goal}",
		# the first line of each building's card: what the building is for in the game
		"about": {
			"solar": "By day the sun gives {solar} power every turn. At night the panels make nothing.",
			"battery": "Saves power for the night. It holds up to {max}.",
			"science": "The crew does experiments here.",
			"base": "The crew lives here. Life support keeps the air good.",
			"shelter": "A small room with thick walls, for storm alerts. Sheltering costs {cost} power and stops science.",
			"greenhouse": "Fresh food for the crew.",
			"water": "The crew uses {used} water a turn, or {more} with the recycler off. Life support at {needed} or more runs the recycler.",
		},
		"base_placeholder": "MOON BASE",
		"greenhouse_placeholder": "GREENHOUSE / STATE {state}",
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
		"shield_progress": "next layer {done} of {cost} power",
		"shield_full": "shield full",
		"greenhouse_on": "Greenhouse ON: growing {food} food this turn",
		"greenhouse_off": "Greenhouse OFF",
		"greenhouse_none": "The greenhouse opens on Level 2",
		"greenhouse_cost": "costs {cost} power now",
		"food_left": "Food for {turns} more turns",
	},
	"hud": {
		"line": "LEVEL {level}  {name}    TURN {turn} / {total}    {phase}    STARS {earned} / {possible}",
		"line_dates": "LEVEL {level}  {name}    TURN {turn} / {total}    {phase}    {dates}    STARS {earned} / {possible}",
		"radiation": "RADIATION {dose}/{limit}",
	},
	"meters": {
		"battery": "Battery",
		"air": "Air",
		"water": "Water",
		"food": "Food",
		"radiation": "Radiation",
		"shield": "Shield",
		"science": "Science",
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
		# the three groups of controls
		"groups": {
			"running": "KEEP THE BASE RUNNING",
			"protection": "PROTECT THE CREW",
			"science": "DO SCIENCE",
		},
		"hints": {
			"life_support": "3 keeps Air steady. Less: Air drops.",
			"shield": "8 power builds 1 layer. It lasts forever.",
			"science": "1 power = 1 science.",
			"charge": "1 power puts 0.8 in the battery.",
			"greenhouse": "Grows 3 food. Uses 1 water.",
			"no_science_shelter": "No science in the shelter.",
		},
	},
	"alert": {
		"heading": "STORM ALERT",
		"title": "{full_class} flare spotted!",
		"chance": "About {dots} in 10 like this sent a storm.",
		# what is at stake (numbers only, never the outcome)
		"stakes": "If a storm comes:",
		"shelter": "Shelter:  Radiation +{dose}",
		"stay": "Stay:  Radiation +{dose}",
		"chosen": "> {text} <",
		"choose": "Storm alert! Choose: shelter or stay.",
		"when": "Seen on {date}",
		# what sheltering costs, in one short line
		"cost": "Shelter costs {cost} power. No science there.",
		"cost_science": "Shelter costs {cost} power and {science} science.",
		"cost_paid": "In the shelter. No science this turn.",
	},
	# What happened on the turn just played (shown only after the turn).
	"report": {
		"heading": "Last turn",
		"storm": "The {full_class} flare sent a radiation storm.",
		"storm_other": "A radiation storm came.",
		"false_alarm": "No radiation storm was recorded after the {full_class} flare.",
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
		"high_dose": "You made it, but your radiation is high. The shelter or a shield keeps it lower.",
		"default": "Great work. Could you earn more science without losing safety?",
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
			"won": "You kept the base running for all {turns} turns.",
		},
		"tip_heading": "TIP",
		"score": "Science {science}    Radiation {dose} of {limit}    Shield {shield} of {max}",
		"storms_heading": "The real flares on this level",
		"no_storms_played": "No alerts came before the level ended.",
		"storm_turn": "Turn {turn} · {full_class}",
		"storm_card": "This flare really happened on {date}, recorded in NASA's DONKI database.",
		"storm_link": "See the {full_class} flare in DONKI",
		"followed_yes": "A radiation storm followed.",
		"followed_no": "No radiation storm was recorded.",
		"sheltered": "You sheltered.",
		"stayed": "You stayed in the main base.",
		"dose_gain": "Radiation +{dose}",
		"caused_by": "The storm came from the {full_class} flare on {date}.",
		"caused_by_many": "Storms followed these flares in the same two days:",
		"storm_link_short": "{full_class} flare, {date}",
		"recycler_saved": "Your recycler saved {n} water this level.",
		"battery_chart": "Your battery, turn by turn",
		"battery_chart_note": "Turns 1 to {day_end} are day. Turns {night_start} to {last} are night.",
		"moon_chart": "Radiation measured at the Moon",
		# The numbers are per-turn means from NASA OSDR RadLab (LRO/CRaTER), checked against the API on 2026-11-14.
		"moon_chart_note": "Real measurements from the CRaTER instrument on NASA's Lunar Reconnaissance Orbiter. Each bar shows how many times stronger the radiation was than on a quiet day. The game's storms follow DONKI's records, so the bars and the storm marks do not always match. Saved on {date}.",
		"moon_times": "{n}×",
		"moon_storm": "storm",
		"reflection": "What would you do differently next time?",
		"question_heading": "TALK ABOUT IT",
		# "What really happened": the player's own choices next to the real record.
		# Counts only, from the turns that were played.
		"recap_heading": "What really happened",
		"recap_alerts_one": "Mission Control sent 1 alert.",
		"recap_alerts_many": "Mission Control sent {n} alerts.",
		"recap_storms_none": "No radiation storm followed.",
		"recap_storms_one": "A radiation storm followed 1 time.",
		"recap_storms_many": "A radiation storm followed {n} times.",
		"recap_sheltered_none": "You never sheltered.",
		"recap_sheltered_one": "You sheltered 1 time.",
		"recap_sheltered_many": "You sheltered {n} times.",
		"recap_extra": "Sheltering when no storm comes is not a mistake. The dots only show a chance.",
		"recap_hits": "Staying kept the science going, but it added {dose} Radiation.",
		"recap_match": "Every choice matched what happened. With only a chance to go on, that took some luck!",
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
		# One list of facts for the whole game. Each row has:
		#   id        a short name; `in_play` below points at it
		#   game      what the game does
		#   real      what is true in real life (the Science page shows both)
		#   note      one short sentence for play: Mission Control notes and building cards.
		#             It may only say what `real` says. A row without one stays on the Science page.
		#   verified  true once a human has checked the fact. Unchecked facts are never shown in play.
		#   source    where the fact comes from, when it is a web page (shown as a link)
		"rows": [
			{
				"id": "real_flares",
				"game": "Every storm alert is a real solar flare.",
				"real": "The flares, their dates and whether a particle storm followed come from NASA's DONKI database for 2024.",
				"note": "Every alert in this game is a real flare from 2024, saved from NASA's DONKI database.",
				"verified": true,  # checked against the DONKI API on 2026-11-14 (HANDOVER.md section 12)
			},
			{
				"id": "odds",
				"game": "The storm chance is shown as dots out of 10.",
				"real": "In 2024, 14 of 54 X-class alerts and 9 of 82 strong M-class alerts were followed by a particle storm. The game uses only the flare class. Real forecasters use much more, and still get false alarms.",
				"note": "Real forecasters get false alarms too. In 2024, most strong flares were not followed by a particle storm.",
				"verified": true,  # the counts were checked against the DONKI API on 2026-11-14
			},
			{
				# How tools/build_storms.py works: "followed" means DONKI links a
				# particle storm (SEP) record to the flare. The rest is a caution, not a claim.
				"id": "record",
				"game": "After an alert, the game tells you a radiation storm came, or that none was recorded.",
				"real": "The game follows the links in DONKI between flares and particle storms. No link means no storm was recorded for that flare. It is not proof that nothing happened.",
				"verified": true,
			},
			{
				# Researched by the coding agent on 2026-11-15; marked as checked by the team the same day.
				# Source says: "Our planet has two layers of protection that the Moon lacks - an
				# atmosphere and a global magnetic field" and "With no magnetosphere, and almost no
				# atmosphere, most of the lunar surface is directly exposed to solar wind and other
				# space radiation."
				"id": "why_moon",
				"game": "A radiation storm is a danger at the Moon base.",
				"real": "Earth has two shields that the Moon lacks: its air and a magnetic field all around the planet. On the Moon, most of the ground is open to radiation from space.",
				"note": "Earth has two shields that the Moon lacks: its air and its magnetic field.",
				"verified": true,
				"source_name": "NASA Science: Solar Wind on the Moon",
				"source": "https://science.nasa.gov/moon/solar-wind/",
			},
			{
				# Researched by the coding agent on 2026-11-15; marked as checked by the team the same day.
				# Source says: "each higher class is a 10-fold increase in energy. So an X flare is
				# 10 times stronger than an M flare" and classes A to M "are divided further using
				# numbers 1 through 9".
				"id": "flare_classes",
				"game": "An alert shows the flare's class, such as M5.1 or X3.9.",
				"real": "Flares are sorted into classes A, B, C, M and X, from weakest to strongest. Each class is 10 times stronger than the one before, so an X flare is 10 times stronger than an M flare. The number after the letter sorts flares inside a class.",
				"note": "Flares go A, B, C, M, X. Each letter is 10 times stronger than the one before.",
				"verified": true,
				"source_name": "NASA Science: Solar Storms and Flares",
				"source": "https://science.nasa.gov/sun/solar-storms-and-flares/",
			},
			{
				# Researched by the coding agent on 2026-11-15; marked as checked by the team the same day.
				# Source says: a solar flare is "an intense burst of radiation, or light", its
				# energy "reaches Earth about 8 minutes after a flare happens", and in a radiation
				# storm "the fastest particles ... zip across roughly 93 million miles from the Sun
				# to Earth in about 30 minutes or less".
				"id": "flare_vs_storm",
				"game": "The alert comes first. A radiation storm may follow, or not.",
				"real": "A flare is a burst of light. Its light reaches Earth about 8 minutes after the flare happens. A radiation storm is made of fast particles, and the fastest can cross from the Sun to Earth in about 30 minutes or less.",
				"note": "A flare is a burst of light. A radiation storm is fast particles, which come later.",
				"verified": true,
				"source_name": "NASA Science: Solar Storms and Flares",
				"source": "https://science.nasa.gov/sun/solar-storms-and-flares/",
			},
			{
				# Written by the coding agent on 2026-11-15; marked as checked by the team the same day.
				# The second sentence is from this game's saved data (storms_data.gd, the
				# Space Weather window): the per-turn means of CRaTER's dose rate are 365.25
				# for turn 9 (M6.8, a storm followed) and 363.36 for turn 14 (X3.3, a storm
				# followed). A test checks the two numbers are still that close.
				"id": "storm_strength",
				"game": "An X-class storm adds more Radiation than an M-class storm: 25 against 10 with no shield.",
				"real": "A bigger flare does not always mean a bigger radiation storm. In this game's saved Moon measurements, the two days with the M6.8 storm were as strong as the two days with the X3.3 storm.",
				"verified": true,
			},
			{
				# checked by the team, 2026-11-15
				"id": "lunar_night",
				"game": "One turn is 2 days. A full-game level has 7 day turns and 7 night turns.",
				"real": "A real day on the Moon lasts about 14 Earth days. So does a real night.",
				"note": "A real night on the Moon lasts about 14 Earth days. So does a real day.",
				"verified": true,
			},
			{
				# checked by the team, 2026-11-15
				"id": "battery_loss",
				"game": "Charging loses 20% of the power.",
				"real": "Real batteries lose some energy too. The 20% is a game number.",
				"note": "Real batteries lose some energy too. The 20% is a game number.",
				"verified": true,
			},
			{
				# checked by the team, 2026-11-15
				"id": "dose_bar",
				"game": "The Radiation bar goes from 0 to 100.",
				"real": "This is a simple stand-in. Real radiation dose is measured in millisieverts, and space agencies set career limits for astronauts.",
				"note": "Real radiation dose is measured in millisieverts. Space agencies set career limits for astronauts.",
				"verified": true,
			},
			{
				# checked by the team, 2026-11-15
				"id": "shelter",
				"game": "The shelter and the shield cut storm radiation.",
				"real": "Real shelters use thick walls of water, supplies or Moon dirt.",
				"note": "Real shelters use thick walls of water, supplies or Moon dirt.",
				"verified": true,
			},
			{
				# checked by the team, 2026-11-15
				"id": "night_storms",
				"game": "Storms can hit at night.",
				"real": "Storm particles can reach the Moon's night side too.",
				"note": "Storm particles can reach the Moon's night side too.",
				"verified": true,
			},
			{
				# checked by the team, 2026-11-15
				"id": "cosmic_rays",
				"game": "Radiation only comes from storms.",
				"real": "There are also cosmic rays, all the time. The game leaves them out.",
				"note": "In real life there are also cosmic rays, all the time. The game leaves them out.",
				"verified": true,
			},
			{
				# checked by the team, 2026-11-15
				"id": "crops",
				"game": "The greenhouse grows food in one turn.",
				"real": "Real crops take weeks to grow.",
				"note": "Real crops take weeks to grow. The game speeds them up.",
				"verified": true,
			},
			{
				# checked by the team, 2026-11-15
				"id": "recycler",
				"game": "The recycler halves the water you lose.",
				"real": "The International Space Station recycles about 98% of its water.",
				"note": "The International Space Station recycles about 98% of its water.",
				"verified": true,
			},
			{
				# The same statement as the RadLab entry under `datasets`, checked against the API on 2026-11-14.
				"id": "crater",
				"game": "After a storm level, a chart shows the radiation at the Moon.",
				"real": "The numbers were measured by the CRaTER instrument on NASA's Lunar Reconnaissance Orbiter.",
				"note": "The CRaTER instrument on NASA's Lunar Reconnaissance Orbiter measures radiation at the Moon.",
				"verified": true,
			},
		],
		# Where the facts show up in play. Every id is a row above; a row that is not
		# verified, or has no `note`, is skipped.
		"in_play": {
			# What just happened -> the facts to tell, one each time it happens, in this order.
			"events": {
				"storm": ["why_moon"],  # the first storm that hits: why it matters on the Moon
				"storm_night": ["night_storms"],
				"storm_more": ["shelter", "dose_bar"],
				"false_alarm": ["odds", "cosmic_rays"],
				"alert": ["flare_classes", "flare_vs_storm", "real_flares"],
				"night": ["lunar_night"],
				"shield": ["shelter"],
				"recycler_off": ["recycler"],
				"greenhouse": ["crops"],
				"charge": ["battery_loss"],
			},
			# Building -> the facts for its card (the first usable one is shown).
			"buildings": {
				"solar": ["lunar_night"],
				"battery": ["battery_loss"],
				"science": ["crater"],
				"base": ["why_moon", "dose_bar"],
				"shelter": ["shelter"],
				"greenhouse": ["crops"],
				"water": ["recycler"],
			},
		},
		"in_real_life": "IN REAL LIFE",
		"source_link": "Source: {name}",
		"notes_heading": "Made up for the game",
		# These say what is NOT real, so they need no source.
		"notes": [
			"The missions and the stars are made up for the game.",
			"The short game plays 16 of the 28 real days of each storm level, without a break: 21 January to 5 February 2024, and 9 to 24 May 2024.",
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

class_name TutorialInteractions
extends RefCounted
## Player-facing interaction reference for the "Come si gioca" screen.
## Mirrors docs/GDD.md §8 (plus the two core fish behaviours). Effects are short
## so they fit on a chip and stay true if balance numbers change.

const ROWS: Array[Dictionary] = [
	{
		"id": &"fish_nest", "group": "Pesce", "agent": "Pesce adulto",
		"agent_id": &"fish", "target": "Nido", "target_id": &"nest",
		"short": "feconda il nido", "color": Color(0.55, 0.8, 1.0),
	},
	{
		"id": &"fish_algae", "group": "Pesce", "agent": "Pesce",
		"agent_id": &"fish", "target": "Alga", "target_id": &"algae",
		"short": "mangia l'alga", "color": Color(0.55, 0.8, 1.0),
	},
	{
		"id": &"algae_coral", "group": "Alga", "agent": "Alga",
		"agent_id": &"algae", "target": "Corallo", "target_id": &"coral",
		"short": "−ossigeno", "color": Color(0.4, 0.9, 0.45),
	},
	{
		"id": &"co2_coral", "group": "CO₂", "agent": "CO₂",
		"agent_id": &"co2", "target": "Corallo", "target_id": &"coral",
		"short": "−ossigeno, via", "color": Color(0.75, 0.78, 0.82),
	},
	{
		"id": &"co2_algae", "group": "CO₂", "agent": "CO₂",
		"agent_id": &"co2", "target": "Alga", "target_id": &"algae",
		"short": "assorbita, cresce", "color": Color(0.75, 0.78, 0.82),
	},
	{
		"id": &"co2_nest", "group": "CO₂", "agent": "CO₂",
		"agent_id": &"co2", "target": "Nido con uova", "target_id": &"nest_eggs",
		"short": "uova muoiono", "color": Color(0.75, 0.78, 0.82),
	},
	{
		"id": &"bag_fish", "group": "Busta", "agent": "Busta",
		"agent_id": &"bag", "target": "Pesce", "target_id": &"fish",
		"short": "pesce muore", "color": Color(0.9, 0.9, 0.95),
	},
	{
		"id": &"bag_coral", "group": "Busta", "agent": "Busta",
		"agent_id": &"bag", "target": "Corallo", "target_id": &"coral",
		"short": "−ossigeno, via", "color": Color(0.9, 0.9, 0.95),
	},
	{
		"id": &"cyclone_fish_algae", "group": "Ciclone", "agent": "Ciclone",
		"agent_id": &"cyclone", "target": "Pesce o alga", "target_id": &"fish",
		"short": "distrutti", "color": Color(0.45, 0.85, 0.95),
	},
	{
		"id": &"cyclone_nest", "group": "Ciclone", "agent": "Ciclone",
		"agent_id": &"cyclone", "target": "Nido", "target_id": &"nest",
		"short": "nido distrutto", "color": Color(0.45, 0.85, 0.95),
	},
	{
		"id": &"cyclone_threat", "group": "Ciclone", "agent": "Ciclone",
		"agent_id": &"cyclone", "target": "CO₂ o busta", "target_id": &"co2",
		"short": "minaccia via", "color": Color(0.45, 0.85, 0.95),
	},
	{
		"id": &"cyclone_predator", "group": "Ciclone", "agent": "Ciclone",
		"agent_id": &"cyclone", "target": "Predatore", "target_id": &"predator",
		"short": "predatore via", "color": Color(0.45, 0.85, 0.95),
	},
	{
		"id": &"cyclone_coral", "group": "Ciclone", "agent": "Ciclone",
		"agent_id": &"cyclone", "target": "Corallo", "target_id": &"coral",
		"short": "corallo muore", "color": Color(0.45, 0.85, 0.95),
	},
	{
		"id": &"predator_fish", "group": "Predatore", "agent": "Predatore",
		"agent_id": &"predator", "target": "Pesce", "target_id": &"fish",
		"short": "mangiato", "color": Color(1.0, 0.55, 0.25),
	},
	{
		"id": &"predator_eggs", "group": "Predatore", "agent": "Predatore",
		"agent_id": &"predator", "target": "Nido con uova", "target_id": &"nest_eggs",
		"short": "uova mangiate", "color": Color(1.0, 0.55, 0.25),
	},
	{
		"id": &"turtle_predator", "group": "Tartaruga", "agent": "Tartaruga",
		"agent_id": &"turtle", "target": "Predatore", "target_id": &"predator",
		"short": "lo allontana", "color": Color(0.4, 1.0, 0.6),
	},
	{
		"id": &"turtle_bag", "group": "Tartaruga", "agent": "Tartaruga",
		"agent_id": &"turtle", "target": "Busta", "target_id": &"bag",
		"short": "busta via", "color": Color(0.4, 1.0, 0.6),
	},
	{
		"id": &"turtle_algae", "group": "Tartaruga", "agent": "Tartaruga",
		"agent_id": &"turtle", "target": "Alga", "target_id": &"algae",
		"short": "mangia l'alga", "color": Color(0.4, 1.0, 0.6),
	},
]

class_name TutorialInteractions
extends RefCounted
## Complete player-facing interaction reference for the "Come si gioca" screen.
## Mirrors docs/GDD.md §8 (plus the two core fish behaviours), but describes the
## effects qualitatively so balance-number changes do not make the tutorial stale.

const ROWS: Array[Dictionary] = [
	{
		"agent": "Pesce adulto", "target": "Nido",
		"effect": "Lo feconda: dopo l'incubazione nascono i piccoli.",
		"color": Color(0.55, 0.8, 1.0),
	},
	{
		"agent": "Pesce", "target": "Alga",
		"effect": "Il pesce affamato mangia l'alga.",
		"color": Color(0.55, 0.8, 1.0),
	},
	{
		"agent": "Alga", "target": "Corallo",
		"effect": "L'alga che cresce sul corallo gli toglie ossigeno.",
		"color": Color(0.4, 0.9, 0.45),
	},
	{
		"agent": "CO2", "target": "Corallo",
		"effect": "Danneggia il corallo e svanisce.",
		"color": Color(0.75, 0.78, 0.82),
	},
	{
		"agent": "CO2", "target": "Alga",
		"effect": "Viene assorbita e l'alga si espande subito.",
		"color": Color(0.75, 0.78, 0.82),
	},
	{
		"agent": "CO2", "target": "Nido con uova",
		"effect": "Le uova muoiono; il nido torna vuoto.",
		"color": Color(0.75, 0.78, 0.82),
	},
	{
		"agent": "Busta", "target": "Pesce",
		"effect": "Il pesce muore; la busta resta.",
		"color": Color(0.9, 0.9, 0.95),
	},
	{
		"agent": "Busta", "target": "Corallo",
		"effect": "Danneggia il corallo e svanisce.",
		"color": Color(0.9, 0.9, 0.95),
	},
	{
		"agent": "Ciclone", "target": "Pesce o alga",
		"effect": "Pesci e alghe vengono distrutti.",
		"color": Color(0.45, 0.85, 0.95),
	},
	{
		"agent": "Ciclone", "target": "Nido",
		"effect": "Il nido viene distrutto.",
		"color": Color(0.45, 0.85, 0.95),
	},
	{
		"agent": "Ciclone", "target": "CO2 o busta",
		"effect": "Le minacce vengono rimosse.",
		"color": Color(0.45, 0.85, 0.95),
	},
	{
		"agent": "Ciclone", "target": "Predatore",
		"effect": "Il predatore viene rimosso.",
		"color": Color(0.45, 0.85, 0.95),
	},
	{
		"agent": "Ciclone", "target": "Corallo",
		"effect": "Il corallo muore; il ciclone svanisce.",
		"color": Color(0.45, 0.85, 0.95),
	},
	{
		"agent": "Predatore", "target": "Pesce",
		"effect": "Il predatore mangia il pesce.",
		"color": Color(1.0, 0.55, 0.25),
	},
	{
		"agent": "Predatore", "target": "Nido con uova",
		"effect": "Mangia le uova; il nido torna vuoto.",
		"color": Color(1.0, 0.55, 0.25),
	},
	{
		"agent": "Tartaruga", "target": "Predatore",
		"effect": "Lo allontana: smette di cacciare e se ne va.",
		"color": Color(0.4, 1.0, 0.6),
	},
	{
		"agent": "Tartaruga", "target": "Busta",
		"effect": "Rimuove la busta, poi se ne va.",
		"color": Color(0.4, 1.0, 0.6),
	},
	{
		"agent": "Tartaruga", "target": "Alga",
		"effect": "La mangia, più in fretta di un pesce.",
		"color": Color(0.4, 1.0, 0.6),
	},
]

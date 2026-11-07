class_name TutorialSequence
extends RefCounted
## Tutorial steps and captions, in order.
## Kept free of nodes so the sequence can be tested headlessly: TutorialStage
## renders each step and TutorialScreen advances through them.

const CAPTIONS: Array[String] = [
	"Il pesce adulto feconda il nido: dalle uova nascono due piccoli.",
	"La CO2 tocca l'alga, viene assorbita, e l'alga si espande.",
	"L'alga che cresce sul corallo gli toglie ossigeno.",
]

var index := 0


func count() -> int:
	return CAPTIONS.size()


func caption() -> String:
	return CAPTIONS[index]


func advance() -> void:
	index = (index + 1) % CAPTIONS.size()


func reset() -> void:
	index = 0

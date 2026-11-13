class_name SelectionColors
extends RefCounted
## Colours of "the selected fish can use this", shared by the fish's outline and
## activity badge (entities/fish/fish_visual.gd) and the ring around the algae
## or nest under the pointer (core/order_highlight.gd). One palette keeps the
## meaning identical everywhere: green = eat, gold = lay eggs.

const FOOD := Color(0.45, 1.0, 0.5)
const EGGS := Color(1.0, 0.85, 0.35)

class_name DamageDummy
extends Node3D

## Alvo de teste no grupo 'player' que só conta o dano recebido.

var damage_taken: float = 0.0


func _ready() -> void:
	add_to_group("player")


func take_damage(amount: float) -> void:
	damage_taken += amount

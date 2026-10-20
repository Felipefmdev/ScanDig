class_name Rumble
extends RefCounted

## Vibração do comando (#148): o único lugar que chama Input.start_joy_vibration. Quem joga
## (player, detector, chefes) só avisa o evento; daqui sai a força já escalada pela opção
## "Vibração" (gameplay/pad_vibration, 0 = desligada).
## Só vibra com o comando em uso (InputDevice) e para o jogador local: os eventos chegam das
## funções que só rodam no dono (take_damage, apply_knockback) ou checam isso aqui (detector).
## O tremor de tela da Acessibilidade NÃO mexe aqui; o "reduzir flashes" corta a explosão
## (A11y.flash_scale), que é o evento que vem com clarão.
## Uma vibração mais forte em andamento não é cortada por uma mais fraca.

## Dano: fração da vida perdida -> força (10 % da vida ~ 0.4; 40 % ou mais = cheia).
const DAMAGE_BASE: float = 0.2
const DAMAGE_GAIN: float = 2.0
## Explosão: até esta distância (m, a mesma do tremor de tela); longe, sobra o mínimo.
const EXPLOSION_RANGE: float = 14.0
const EXPLOSION_MIN: float = 0.15
## Detector: só com sinal forte (perto do alvo), pulso fraco e no máximo um por intervalo.
const DETECTOR_MIN_SIGNAL: float = 0.6
const DETECTOR_INTERVAL_MS: int = 800
const DETECTOR_WEAK: Vector2 = Vector2(0.08, 0.25)
const DETECTOR_SECONDS: float = 0.06
## Golpe forte (empurrão de chefe, #57): o tremor de tela dele vai até ~0.3.
const HEAVY_SHAKE_FULL: float = 0.3
## Prévia do controle deslizante: no máximo uma por intervalo.
const PREVIEW_INTERVAL_MS: int = 250

## Testes trocam a chamada de verdade: func(device: int, weak: float, strong: float, seconds: float).
static var backend: Callable = Callable()
static var _active_until_ms: int = 0
static var _active_strength: float = 0.0
static var _detector_last_ms: int = -100000
static var _preview_last_ms: int = -100000


# --- Valores ---------------------------------------------------------------------

## Opção "Vibração" (0 a 1). Sem o SettingsManager, o padrão.
static func setting() -> float:
	var sm: SettingsManager = SettingsManager.instance
	var value: Variant = sm.get_value(SettingsManager.GAMEPLAY, "pad_vibration") if sm != null \
		else (SettingsManager.DEFAULTS[SettingsManager.GAMEPLAY] as Dictionary)["pad_vibration"]
	return clampf(float(value), 0.0, 1.0)


static func enabled() -> bool:
	return setting() > 0.0 and InputDevice.using_gamepad() and InputDevice.pad_device() >= 0


## Esquece vibração em andamento e limites (troca de cena, testes).
static func reset() -> void:
	_active_until_ms = 0
	_active_strength = 0.0
	_detector_last_ms = -100000
	_preview_last_ms = -100000


# --- Eventos ---------------------------------------------------------------------

## Dano no jogador local, proporcional à fração da vida.
static func on_damage(amount: float, max_health: float, now_ms: int = -1) -> bool:
	if amount <= 0.0:
		return false
	var f: float = clampf(DAMAGE_BASE + amount / maxf(max_health, 1.0) * DAMAGE_GAIN, DAMAGE_BASE, 1.0)
	return pulse(f * 0.6, f, 0.15 + 0.25 * f, now_ms)


## Explosão a `distance` m do jogador local: forte perto, some no fim do alcance.
static func on_explosion(distance: float, now_ms: int = -1) -> bool:
	if distance >= EXPLOSION_RANGE:
		return false
	var f: float = lerpf(1.0, EXPLOSION_MIN, clampf(distance / EXPLOSION_RANGE, 0.0, 1.0)) * A11y.flash_scale()
	return pulse(f, f, 0.45, now_ms)


## A pá revelou um item (raro vibra mais).
static func on_dig_found(rare: bool = false, now_ms: int = -1) -> bool:
	if rare:
		return pulse(0.8, 0.6, 0.3, now_ms)
	return pulse(0.5, 0.25, 0.18, now_ms)


## Ping do detector com sinal `signal_strength` (0 a 1). `source` (o detector) precisa ser do
## jogador local.
static func on_detector_ping(signal_strength: float, source: Node = null, now_ms: int = -1) -> bool:
	if signal_strength < DETECTOR_MIN_SIGNAL or not is_local_node(source):
		return false
	var now: int = Time.get_ticks_msec() if now_ms < 0 else now_ms
	if now - _detector_last_ms < DETECTOR_INTERVAL_MS:
		return false
	var t: float = clampf((signal_strength - DETECTOR_MIN_SIGNAL) / (1.0 - DETECTOR_MIN_SIGNAL), 0.0, 1.0)
	if not pulse(lerpf(DETECTOR_WEAK.x, DETECTOR_WEAK.y, t), 0.0, DETECTOR_SECONDS, now):
		return false
	_detector_last_ms = now
	return true


## Um chefe entrou na cena.
static func on_boss_entry(now_ms: int = -1) -> bool:
	return pulse(0.6, 0.8, 0.6, now_ms)


## Golpe forte (empurrão com tremor de tela `shake`, #57).
static func on_heavy_hit(shake: float, now_ms: int = -1) -> bool:
	if shake <= 0.0:
		return false
	var f: float = clampf(shake / HEAVY_SHAKE_FULL, 0.4, 1.0)
	return pulse(f * 0.7, f, 0.25 + 0.2 * f, now_ms)


## Prévia ao mexer no controle deslizante (`value` ainda não aplicado, 0 a 1).
static func preview(value: float, now_ms: int = -1) -> bool:
	var now: int = Time.get_ticks_msec() if now_ms < 0 else now_ms
	if value <= 0.0 or not InputDevice.using_gamepad() or now - _preview_last_ms < PREVIEW_INTERVAL_MS:
		return false
	var device: int = InputDevice.pad_device()
	if device < 0:
		return false
	_preview_last_ms = now
	_vibrate(device, 0.5 * value, 0.5 * value, 0.2)
	return true


# --- Base ------------------------------------------------------------------------

## Vibra com a força crua (0 a 1) vezes a opção. Falso se não vibrou (desligada, sem comando,
## ou uma mais forte ainda em andamento).
static func pulse(weak: float, strong: float, seconds: float, now_ms: int = -1) -> bool:
	if not enabled():
		return false
	var gain: float = setting()
	weak = clampf(weak * gain, 0.0, 1.0)
	strong = clampf(strong * gain, 0.0, 1.0)
	var strength: float = maxf(weak, strong)
	if strength <= 0.0:
		return false
	var now: int = Time.get_ticks_msec() if now_ms < 0 else now_ms
	if now < _active_until_ms and strength < _active_strength:
		return false
	_active_until_ms = now + int(seconds * 1000.0)
	_active_strength = strength
	_vibrate(InputDevice.pad_device(), weak, strong, seconds)
	return true


static func _vibrate(device: int, weak: float, strong: float, seconds: float) -> void:
	if backend.is_valid():
		backend.call(device, weak, strong, seconds)
	else:
		Input.start_joy_vibration(device, weak, strong, seconds)


## O nó é do jogador local? Dentro de um Player, só o do grupo local; fora de um (sandbox,
## testes), sim.
static func is_local_node(node: Node) -> bool:
	var n: Node = node
	while n != null:
		if n is Player:
			return n.is_in_group(Player.LOCAL_GROUP)
		n = n.get_parent()
	return true

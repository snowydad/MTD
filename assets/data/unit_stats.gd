class_name UnitStats
extends Resource

## Data-driven статистика юнитов.
## Позже можно заменить на .tres или JSON.

enum UnitType { ARCHER, MAGE, CANNON }

@export var type: UnitType
@export var level: int = 1

@export var damage: float = 10.0
@export var attack_speed: float = 1.0   # атак в секунду
@export var range: float = 300.0
@export var splash_radius: float = 0.0  # 0 = single target

# Коэффициенты при мерже (уровень N → N+1)
const MERGE_DAMAGE_MULT := 2.0
const MERGE_RANGE_MULT := 2.0


static func get_base(type: UnitType) -> Dictionary:
	match type:
		UnitType.ARCHER:
			return {
				"damage": 12.0,
				"attack_speed": 0.5,
				"range": 700.0,
				"splash_radius": 0.0,
			}
		UnitType.MAGE:
			return {
				"damage": 18.0,
				"attack_speed": 1.1,
				"range": 320.0,
				"splash_radius": 0.0,
			}
		UnitType.CANNON:
			return {
				"damage": 25.0,
				"attack_speed": 0.6,
				"range": 280.0,
				"splash_radius": 80.0,
			}
	return {}

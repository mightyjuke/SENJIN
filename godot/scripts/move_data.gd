extends RefCounted
## Native data derived from src/hero/moves.js at d41b48d.
## Copyright (c) 2026 BubuAi. MIT; see res://legal/NOTICE.txt.
## The browser implementation is retained as a reference, not a mobile dependency.

const AIR_CHAIN_MAX: int = 10
const SURGE_COST: float = 25.0
const SURGE_CONTACT: int = 132
const SURGE_FINISHER: int = 176
const SURGE_END: int = 200

static func hit(first: int, last: int, shape: String, reach: float, damage: float,
		angle: float = 180.0, force: float = 3.0, lift: float = 0.0,
		every: int = 0, heavy: bool = false, width: float = 2.0,
		direction: float = 0.0, height: float = 3.0, stop: int = 3) -> Dictionary:
	return {"first": first, "last": last, "shape": shape, "range": reach,
		"damage": damage, "angle": angle, "force": force, "lift": lift,
		"every": every, "heavy": heavy, "width": width, "direction": direction,
		"height": height, "hitstop": stop}

static func build() -> Dictionary:
	return {
		"n1": {"frames":35,"cancel":23,"branch":11,"dodge":11,"next":"n2","charge":"c2","lunge":[[2,9,0.3]],
			"hits":[hit(7,10,"arc",2.5,12,110,3,0,0,false,2,-20)]},
		"n2": {"frames":35,"cancel":25,"branch":13,"dodge":13,"next":"n3","charge":"c3","lunge":[[0,9,0.8]],
			"hits":[hit(9,12,"arc",2.4,12,130,3,0,0,false,2,10)]},
		"n3": {"frames":30,"cancel":20,"branch":14,"dodge":14,"next":"n4","charge":"c4","lunge":[[7,12,0.4]],
			"hits":[hit(10,13,"arc",2.4,14,170,6,0,0,false,2,20)]},
		"n4": {"frames":38,"cancel":28,"branch":24,"dodge":17,"next":"n5","charge":"c5","lunge":[[0,14,1.3]],
			"hits":[hit(14,23,"arc",2.6,14,160,4,0,0,false,2,25)]},
		"n5": {"frames":50,"cancel":32,"branch":22,"dodge":22,"next":"n6","charge":"c6","lunge":[[8,12,0.15],[16,20,0.2]],
			"hits":[hit(12,14,"line",2.3,10,180,3,0,0,false,1.2,0,3,2),hit(19,21,"arc",2.2,12,120,5,0,0,false,2,-20)]},
		"n6": {"frames":48,"cancel":38,"dodge":19,"next":"n1","charge":"c1","armor":true,"lunge":[[3,14,1.4]],
			"hits":[hit(15,18,"circle",2.4,26,360,12,6,0,true,2,0,3,7)]},
		"c1": {"frames":56,"cancel":50,"dodge":29,"armor":true,"lunge":[[22,28,0.8]],
			"hits":[hit(25,29,"arc",3.8,18,170,2,10,0,true,2,0,3,6)]},
		"c2": {"frames":112,"cancel":104,"dodge":84,"armor":true,"leap":[26,13],"land":84,"lunge":[[4,16,0.8],[26,80,2.4]],
			"hits":[hit(16,19,"line",4.4,18,180,3,11,0,true,2.4,0,3,5),hit(46,58,"circle",3.6,10,360,3,5,6,false,2,0,5.5,2)]},
		"c3": {"frames":114,"cancel":104,"dodge":77,"armor":true,"lunge":[[11,43,1.4],[49,53,1.0]],
			"hits":[hit(13,43,"line",4.2,6,180,1.5,0,6,false,2.4,0,3,1),hit(52,55,"arc",3.6,16,200,3,0,0,true,2,0,3,6),hit(74,77,"circle",3.8,26,360,3,10,0,true,2,0,3,8)]},
		"c4": {"frames":76,"cancel":66,"dodge":52,"armor":true,"lunge":[[22,38,0.8]],
			"hits":[hit(24,52,"circle",4.2,11,360,6,3,10,false)]},
		"c5": {"frames":80,"cancel":72,"dodge":54,"armor":true,"lunge":[[14,40,2.4]],
			"hits":[hit(24,27,"circle",3.2,8,360,2,0,0,false,2,0,3,2),hit(50,54,"circle",4.6,26,360,5,9,0,true,2,0,3,8)]},
		"c6": {"frames":130,"cancel":120,"dodge":95,"armor":true,"leap":[72,11],"plunge":[80,-26],"land":82,"lunge":[[10,66,1.8],[72,82,0.8]],
			"hits":[hit(10,62,"circle",3.6,5,360,0.8,0,10,false,2,0,4,1),hit(82,85,"circle",4.2,18,360,3,8,0,true,2,0,4,6),hit(92,95,"circle",5.2,30,360,15,7,0,true,2,0,4.5,8)]},
		"dash": {"frames":88,"cancel":80,"dodge":40,"lunge":[[0,43,6.1],[43,56,2.2]],
			"hits":[hit(5,8,"circle",3.2,10,360,4,0,0,false,2,0,3,2),hit(20,23,"circle",3.2,10,360,4,0,0,false,2,0,3,2),hit(35,38,"circle",3.2,12,360,6,0,0,false,2,0,3,2),hit(47,52,"line",4.2,20,180,11,4,0,true,2.2,0,3,5)]},
		"jatk": {"frames":22,"cancel":12,"branch":12,"dodge":99,"next":"jatk","charge":"jc","air":true,
			"hits":[hit(5,9,"arc",3.6,12,220,3,0,0,false,2,0,4.5,2)]},
		"jc": {"frames":56,"cancel":50,"dodge":39,"air":true,"armor":true,"hang":[6,32],"plunge":[32,-80],"land":36,
			"hits":[hit(36,39,"circle",4.4,22,360,5,8,0,true,2,0,4,7)]}
	}

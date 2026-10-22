
extends RefCounted
# Static game data: cities, outfits, upgrades, missions.

const CITY_LENGTH := 1200.0

static func cities() -> Array:
	# A full day across Iraq: afternoon -> noon -> late afternoon -> sunset -> night -> sunrise.
	return [
		{"name": "سالمورا", "en": "Salmora", "sky_top": Color("2f78c4"), "sky_hor": Color("f6cf98"), "fog": Color("ecd2a6"),
		 "sun": Color("fff1d0"), "sun_pitch": -42.0, "sun_energy": 1.25, "amb": 0.9, "night": 0.0,
		 "ground": Color("8d7b5e"), "walk": Color("c9b79a"), "bld": [Color("d9b98a"), Color("c9a070"), Color("e7d3a8"), Color("b98f62")],
		 "hmin": 8.0, "hmax": 22.0, "trees": "palm", "tree_n": 3, "lm": "mosque", "bunting": true,
		 "shops": ["مطعم النخيل", "صيدلية", "مخبز الصباح", "عطور", "ملحمة", "مكتبة"]},
		{"name": "هيلانور", "en": "Helanor", "sky_top": Color("3a8fd6"), "sky_hor": Color("bfe3ee"), "fog": Color("cfe6ea"),
		 "sun": Color("fffbe8"), "sun_pitch": -68.0, "sun_energy": 1.4, "amb": 1.0, "night": 0.0,
		 "ground": Color("6e8a6a"), "walk": Color("d8d2bf"), "bld": [Color("e9e2d0"), Color("9ec3d6"), Color("d8c9a6"), Color("c7d9c4")],
		 "hmin": 7.0, "hmax": 18.0, "trees": "palm", "tree_n": 4, "lm": "crane", "water": true,
		 "shops": ["سمك مشوي", "كورنيش", "ميناء", "قهوة", "ثلج", "تمور"]},
		{"name": "كوربند", "en": "Korband", "sky_top": Color("2a62b8"), "sky_hor": Color("f4dcb4"), "fog": Color("eadbc0"),
		 "sun": Color("ffe9c4"), "sun_pitch": -34.0, "sun_energy": 1.3, "amb": 0.85, "night": 0.0,
		 "ground": Color("9a8a63"), "walk": Color("cfc3a6"), "bld": [Color("e2cfa6"), Color("a9c6e0"), Color("8fb4d4"), Color("ece0c0")],
		 "hmin": 8.0, "hmax": 30.0, "trees": "pine", "tree_n": 2, "lm": "citadel", "flags": true,
		 "shops": ["كباب", "مول", "حلويات", "برج الساعة", "مقهى", "صيدلية"]},
		{"name": "نافيرا", "en": "Navira", "sky_top": Color("3b5a9a"), "sky_hor": Color("ff9a5a"), "fog": Color("f0b890"),
		 "sun": Color("ffa868"), "sun_pitch": -9.0, "sun_energy": 1.15, "amb": 0.62, "night": 0.3,
		 "ground": Color("a8946a"), "walk": Color("d6c8a4"), "bld": [Color("efe3c4"), Color("e0cfa2"), Color("f4ecd6"), Color("d4be90")],
		 "hmin": 7.0, "hmax": 16.0, "trees": "palm", "tree_n": 2, "lm": "mosque_gold", "bunting": true,
		 "shops": ["مكتبة", "عطور", "حلويات", "هدايا", "تمور", "ملابس"]},
		{"name": "ديمارا", "en": "Demara", "sky_top": Color("0b1230"), "sky_hor": Color("4a4a78"), "fog": Color("3a3a5c"),
		 "sun": Color("9fb0ff"), "sun_pitch": -35.0, "sun_energy": 0.45, "amb": 0.5, "night": 1.0,
		 "ground": Color("5a5040"), "walk": Color("8a8576"), "bld": [Color("cdbb97"), Color("b9a57e"), Color("d6c7a4"), Color("a69270")],
		 "hmin": 6.0, "hmax": 15.0, "trees": "pine", "tree_n": 1, "lm": "hadba",
		 "shops": ["صابون", "مخبز", "مطعم", "مقهى", "حلويات", "صيدلية"]},
		{"name": "ياسلون", "en": "Yaslun", "sky_top": Color("4a86d0"), "sky_hor": Color("ffd0a0"), "fog": Color("f2d6bc"),
		 "sun": Color("ffd2a0"), "sun_pitch": -16.0, "sun_energy": 1.3, "amb": 0.8, "night": 0.0,
		 "ground": Color("5f8a4e"), "walk": Color("c4cbb8"), "bld": [Color("e8d9bd"), Color("d3a583"), Color("cfd6c0"), Color("b8a389")],
		 "hmin": 6.0, "hmax": 16.0, "trees": "pine", "tree_n": 4, "lm": "mountain", "flags": true,
		 "shops": ["شاي", "كتب", "مقهى", "سينما", "حلويات", "فن"]},
	]

static func city_at(distance: float) -> int:
	return int(distance / CITY_LENGTH) % 6

static func outfits() -> Array:
	return [
		{"id": "national", "name": "القميص الأخضر", "price": 0, "shirt": Color("1c9a4d"), "acc": Color("ffffff"), "pants": Color("f4f4f4"), "shoes": Color("202020"), "head": "none", "headc": Color("ffffff"), "long": false, "shorts": true, "sleeve": "short"},
		{"id": "sport", "name": "بدلة رياضية", "price": 1000, "shirt": Color("1f4fa8"), "acc": Color("ffd23f"), "pants": Color("14213d"), "shoes": Color("f2f2f2"), "head": "cap", "headc": Color("1f4fa8"), "long": false, "shorts": false, "sleeve": "long"},
		{"id": "ghutra", "name": "الغترة الحمراء", "price": 1500, "shirt": Color("f1efe8"), "acc": Color("c8372d"), "pants": Color("34343c"), "shoes": Color("4a3524"), "head": "ghutra", "headc": Color("c8372d"), "long": false, "shorts": false, "sleeve": "long"},
		{"id": "classic", "name": "الثوب الكلاسيكي", "price": 2000, "shirt": Color("d9c9a2"), "acc": Color("8a6d3b"), "pants": Color("d9c9a2"), "shoes": Color("3a2a1a"), "head": "sidara", "headc": Color("8d7a58"), "long": true, "shorts": false, "sleeve": "long"},
		{"id": "black_robe", "name": "الثوب الأسود", "price": 2500, "shirt": Color("2b2b30"), "acc": Color("d8d8d8"), "pants": Color("2b2b30"), "shoes": Color("1a1a1a"), "head": "ghutra", "headc": Color("303030"), "long": true, "shorts": false, "sleeve": "long"},
		{"id": "explorer", "name": "المستكشف", "price": 3000, "shirt": Color("b9a46a"), "acc": Color("5a4a2a"), "pants": Color("6b5a3a"), "shoes": Color("3a2a1a"), "head": "hat", "headc": Color("8a7442"), "long": false, "shorts": false, "sleeve": "long"},
		{"id": "boxer", "name": "الملاكم", "price": 3500, "shirt": Color("c0392b"), "acc": Color("ffffff"), "pants": Color("c0392b"), "shoes": Color("ffffff"), "head": "headband", "headc": Color("ffffff"), "long": false, "shorts": true, "sleeve": "short"},
		{"id": "chef", "name": "الطباخ", "price": 4000, "shirt": Color("f7f7f7"), "acc": Color("c0392b"), "pants": Color("3a3f45"), "shoes": Color("f2f2f2"), "head": "cap", "headc": Color("f7f7f7"), "long": false, "shorts": false, "sleeve": "long"},
		{"id": "sailor", "name": "البحّار", "price": 4500, "shirt": Color("f4f4f4"), "acc": Color("1f4fa8"), "pants": Color("1f3a6e"), "shoes": Color("f2f2f2"), "head": "cap", "headc": Color("f4f4f4"), "long": false, "shorts": false, "sleeve": "long"},
		{"id": "business", "name": "رجل الأعمال", "price": 5000, "shirt": Color("1d2733"), "acc": Color("c0392b"), "pants": Color("1d2733"), "shoes": Color("111111"), "head": "none", "headc": Color("111111"), "long": false, "shorts": false, "sleeve": "long"},
		{"id": "winter", "name": "الشتوي", "price": 5500, "shirt": Color("2e6fb7"), "acc": Color("f4f4f4"), "pants": Color("2a3340"), "shoes": Color("5b4a3a"), "head": "beanie", "headc": Color("c0392b"), "long": false, "shorts": false, "sleeve": "long"},
		{"id": "astro", "name": "رائد الفضاء", "price": 6500, "shirt": Color("d8dde2"), "acc": Color("ff8a2a"), "pants": Color("d8dde2"), "shoes": Color("8d949c"), "head": "helmet", "headc": Color("c9d0d6"), "long": false, "shorts": false, "sleeve": "long"},
		{"id": "golden", "name": "الزي الذهبي", "price": 7000, "shirt": Color("e0a81c"), "acc": Color("fff1b0"), "pants": Color("7a1f1f"), "shoes": Color("e0a81c"), "head": "cap", "headc": Color("e0a81c"), "long": false, "shorts": false, "sleeve": "long"},
		{"id": "shepherd", "name": "الراعي", "price": 7500, "shirt": Color("8a6a3e"), "acc": Color("e8d9b0"), "pants": Color("8a6a3e"), "shoes": Color("3a2a1a"), "head": "ghutra", "headc": Color("e8d9b0"), "long": true, "shorts": false, "sleeve": "long"},
		{"id": "knight", "name": "الفارس", "price": 8500, "shirt": Color("3b4a5a"), "acc": Color("c9d0d6"), "pants": Color("2a323c"), "shoes": Color("1a1a1a"), "head": "helmet", "headc": Color("8d949c"), "long": false, "shorts": false, "sleeve": "long"},
		{"id": "fire", "name": "ثوب اللهب", "price": 10000, "shirt": Color("e8452c"), "acc": Color("ffd23f"), "pants": Color("3a1a14"), "shoes": Color("ffd23f"), "head": "headband", "headc": Color("ffd23f"), "long": false, "shorts": false, "sleeve": "long"},
		{"id": "ice", "name": "ثوب الجليد", "price": 11000, "shirt": Color("bfe6ff"), "acc": Color("ffffff"), "pants": Color("5a8fc0"), "shoes": Color("f4f4f4"), "head": "beanie", "headc": Color("ffffff"), "long": false, "shorts": false, "sleeve": "long"},
		{"id": "royal", "name": "الزي الملكي", "price": 14000, "shirt": Color("5b2a8c"), "acc": Color("f2c14e"), "pants": Color("3a1a5c"), "shoes": Color("f2c14e"), "head": "crown", "headc": Color("f2c14e"), "long": true, "shorts": false, "sleeve": "long"},
		{"id": "neon", "name": "النيون", "price": 16000, "shirt": Color("1a1a24"), "acc": Color("39ff88"), "pants": Color("1a1a24"), "shoes": Color("39ff88"), "head": "cap", "headc": Color("1a1a24"), "long": false, "shorts": false, "sleeve": "long"},
		{"id": "legend", "name": "الأسطورة", "price": 20000, "shirt": Color("ffd23f"), "acc": Color("c0392b"), "pants": Color("1c9a4d"), "shoes": Color("ffffff"), "head": "crown", "headc": Color("ffd23f"), "long": false, "shorts": false, "sleeve": "short"},
	]

static func upgrades() -> Array:
	return [
		{"id": "magnet", "name": "المغناطيس", "desc": "يجذب العملات القريبة", "base": 6.0, "step": 1.5, "color": Color("e5484d")},
		{"id": "jet", "name": "الحقيبة الصاروخية", "desc": "تحلّق فوق كل العوائق", "base": 5.0, "step": 1.0, "color": Color("ff8a2a")},
		{"id": "mult", "name": "مضاعف العملات ×2", "desc": "كل عملة تُحتسب بضعفها", "base": 8.0, "step": 2.0, "color": Color("f2c94c")},
		{"id": "boots", "name": "حذاء القفز", "desc": "قفزة أعلى وأطول", "base": 8.0, "step": 2.0, "color": Color("3ecf6e")},
		{"id": "shield", "name": "الدرع", "desc": "يحميك من اصطدام واحد", "base": 8.0, "step": 2.0, "color": Color("39b8f0")},
	]

const MAX_LEVEL := 6

static func duration(id: String, level: int) -> float:
	for u in upgrades():
		if u["id"] == id:
			return float(u["base"]) + float(u["step"]) * level
	return 6.0

static func upgrade_cost(level: int) -> int:
	return 400 * (level + 1)

static func mission_templates() -> Dictionary:
	return {
		"coins": {"text": "اجمع %d عملة", "targets": [60, 100, 150, 220, 300], "reward": 0.8},
		"distance": {"text": "اركض %d متراً", "targets": [800, 1500, 2500, 4000, 6000], "reward": 0.12},
		"jumps": {"text": "اقفز %d مرة", "targets": [15, 30, 50, 80, 120], "reward": 8.0},
		"rolls": {"text": "انزلق %d مرة", "targets": [10, 20, 35, 55, 80], "reward": 10.0},
		"powerups": {"text": "التقط %d قدرة خارقة", "targets": [3, 6, 10, 15, 22], "reward": 55.0},
		"runs": {"text": "العب %d جولات", "targets": [2, 4, 6, 9, 12], "reward": 90.0},
	}

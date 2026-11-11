class_name RedeEnergiaPlex
extends RefCounted

var planta: PlantaPlex
var geradores: Array[Dictionary] = []
var lampadas: Array[Dictionary] = []
var revisao := -1
var potencia := 0.0
var demanda := 0.0
var fator := 0.0
var extra := 0.0

func _init(p: PlantaPlex) -> void:
	planta = p

func conectado(gerador: Dictionary) -> bool:
	return planta.objetos.has(gerador.id) and TerrenoPlex.cabe(planta,gerador.tipo,gerador.celula,gerador.rotacao) and gerador.get("ligada",true) and not gerador.get("reinicio_pendente",false) and float(gerador.get("combustivel",0))>0.0

func atualizar(delta: float = 0.0) -> void:
	if revisao != planta.revisao:
		revisao = planta.revisao
		geradores.clear()
		lampadas.clear()
		for item in planta.objetos.values():
			if MobiliaPlex.dados(item).get("gerador",false):
				if not item.has("combustivel"): item.combustivel = 100.0
				geradores.append(item)
			if item.tipo.begins_with("luz_"): lampadas.append(item)
	potencia = 0.0
	demanda = 0.0
	for luz in lampadas:
		if luz.get("ligada",true): demanda += maxf(0.0,float(luz.get("energia",1.2)))
	for gerador in geradores:
		if planta.objetos.has(gerador.id) and conectado(gerador): potencia += float(MobiliaPlex.dados(gerador).potencia)
	if potencia>0.0 and delta>0.0:
		var carga := clampf(demanda/potencia,.15,1.0)*(1.0+extra)
		for gerador in geradores:
			if planta.objetos.has(gerador.id) and conectado(gerador):
				gerador.combustivel = maxf(0.0,float(gerador.combustivel)-delta*float(MobiliaPlex.dados(gerador).consumo_hora)*carga/60.0)
				if float(gerador.combustivel)<=0:gerador.ligada=false;gerador.reinicio_pendente=true
		potencia = 0.0
		for gerador in geradores:
			if planta.objetos.has(gerador.id) and conectado(gerador): potencia += float(MobiliaPlex.dados(gerador).potencia)
	fator = clampf(potencia/maxf(.001,demanda),0.0,1.0) if potencia>0.0 else 0.0

func abastecer(id: int) -> bool:
	var item: Dictionary = planta.objetos.get(id,{})
	if not MobiliaPlex.dados(item).get("gerador",false): return false
	item.combustivel = 100.0
	atualizar()
	return true

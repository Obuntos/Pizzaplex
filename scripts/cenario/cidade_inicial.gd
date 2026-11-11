class_name CidadeInicialPlex
extends RefCounted

const RESTAURANTE := Rect2i(33,25,12,12)
static var dados: Dictionary = {}

static func montar(planta: PlantaPlex) -> Array[String]:
	planta.area_construcao = RESTAURANTE
	if dados.is_empty(): dados=JSON.parse_string(FileAccess.get_file_as_string("res://dados/cidade_inicial.json"))
	var erros: Array[String]=[]
	for piso in dados.pisos:
		var c:=Vector2i(piso[0],piso[1])
		if not RESTAURANTE.has_point(c): planta.pisos[c]=str(piso[2])
	for registro in dados.objetos:
		var id:=planta.colocar(str(registro[0]),Vector2i(registro[1],registro[2]),int(registro[3]))
		if id<0: erros.append(str(registro))
		else:
			planta.objetos[id].cidade=true
			if registro[0]==CaminhosCidadePlex.CASA: planta.objetos[id].casa_administrador=true
	return erros

static func presente(planta: PlantaPlex) -> bool:
	return planta.objetos.values().any(func(o): return o.get("cidade",false))

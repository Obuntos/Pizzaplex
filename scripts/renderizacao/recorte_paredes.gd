class_name RecorteParedesPlex
extends RefCounted

const ESTRUTURA = ["parede", "porta", "porta_dupla"]
var niveis: Dictionary = {}

func estrutura(planta: PlantaPlex, celula: Vector2i) -> bool:
	return planta.em(celula).get("tipo", "") in ESTRUTURA

func tem_atras(planta: PlantaPlex, celula: Vector2i, direcao: Vector2i, id: int) -> bool:
	var orientada := Vector2i(GradePlex.girar(Vector2(direcao), -GradePlex.visao))
	var ponto := celula - orientada
	while GradePlex.dentro(ponto):
		var outro := planta.em(ponto)
		if outro.get("tipo", "") in ESTRUTURA and outro.id != id:
			return true
		ponto -= orientada
	return false

func calcular(planta: PlantaPlex, nivel: int, automatico: bool) -> void:
	niveis.clear()
	if not automatico or nivel == 1:
		return
	for item in planta.objetos.values():
		if item.tipo not in ESTRUTURA:
			continue
		var fundo := false
		var ocupadas := planta.celulas(item.tipo, item.celula, item.rotacao)
		for celula in ocupadas:
			var eixo_x := estrutura(planta, celula + Vector2i(1, 0)) or estrutura(planta, celula - Vector2i(1, 0))
			var eixo_y := estrutura(planta, celula + Vector2i(0, 1)) or estrutura(planta, celula - Vector2i(0, 1))
			if item.tipo in ["porta", "porta_dupla"]:
				eixo_x = item.rotacao % 2 == 0
				eixo_y = not eixo_x
			if GradePlex.visao % 2 == 1:
				var anterior := eixo_x
				eixo_x = eixo_y
				eixo_y = anterior
			if eixo_x and not tem_atras(planta, celula, Vector2i(0, 1), item.id):
				fundo = true
			if eixo_y and not tem_atras(planta, celula, Vector2i(1, 0), item.id):
				fundo = true
			if not eixo_x and not eixo_y:
				fundo = not tem_atras(planta, celula, Vector2i(1, 0), item.id) and not tem_atras(planta, celula, Vector2i(0, 1), item.id)
		niveis[item.id] = nivel if fundo else 1

func nivel_para(item: Dictionary, padrao: int) -> int:
	return int(niveis.get(item.id, padrao))

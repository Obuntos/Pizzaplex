class_name EscadasPlex
extends RefCounted

static func tipo(objeto: Dictionary) -> String:
	var nome := str(objeto.get("tipo",""))
	return "palco" if CatalogoPlex.objetos.get(nome,{}).get("novo_palco",false) else MobiliaPlex.logico(nome)

static func eh(objeto: Dictionary) -> bool:
	return tipo(objeto)=="escada"

static func palco(objeto: Dictionary) -> bool:
	return tipo(objeto)=="palco"

static func faixa(celula: Vector2i, planta: PlantaPlex) -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	var objeto := planta.em(celula)
	if not eh(objeto):
		return resultado
	var frente := GradePlex.frente(objeto.rotacao)
	var lado := Vector2i(frente.y, -frente.x)
	var fila: Array[Vector2i] = [celula]
	while not fila.is_empty():
		var local: Vector2i = fila.pop_front()
		if resultado.has(local):
			continue
		resultado.append(local)
		for deslocamento in [lado, -lado]:
			var vizinho: Vector2i = local + deslocamento
			var outro := planta.em(vizinho)
			if eh(outro) and outro.rotacao == objeto.rotacao and not resultado.has(vizinho):
				fila.append(vizinho)
	return resultado

static func acessivel(celula: Vector2i, planta: PlantaPlex) -> bool:
	var entrada: bool = false
	var saida: bool = false
	var objeto := planta.em(celula)
	if not eh(objeto):
		return false
	var frente := GradePlex.frente(objeto.rotacao)
	for local in faixa(celula, planta):
		var antes: Vector2i = local + frente
		var depois: Vector2i = local - frente
		entrada = entrada or (planta.transitavel(antes) and is_zero_approx(planta.altura(antes)))
		saida = saida or palco(planta.em(depois))
	return entrada and saida


static func altura(local: Vector2, planta: PlantaPlex) -> float:
	var celula := Vector2i(local.round())
	var objeto := planta.em(celula)
	if not eh(objeto):
		return planta.altura(celula)
	var frente := Vector2(GradePlex.frente(objeto.rotacao))
	var t := clampf(0.5 - (local - Vector2(celula)).dot(frente), 0.0, 1.0)
	return clampf((floorf(t * 3.0) + 1.0) * 6.0, 6.0, 18.0)

static func degrau(local: Vector2, planta: PlantaPlex) -> int:
	var celula := Vector2i(local.round())
	var objeto := planta.em(celula)
	if not eh(objeto):
		return 0
	var frente := Vector2(GradePlex.frente(objeto.rotacao))
	return clampi(int(ceil((0.5 - (local - Vector2(celula)).dot(frente)) * 3.0)), 1, 3)



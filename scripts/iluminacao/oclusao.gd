class_name OclusaoPlex
extends RefCounted

static func mapa_portas(planta: PlantaPlex) -> Image:
	var imagem := Image.create_empty(GradePlex.TAMANHO.x, GradePlex.TAMANHO.y, false, Image.FORMAT_RGBAF)
	for objeto in planta.objetos.values():
		if objeto.tipo not in CatalogoPlex.PORTAS: continue
		var dimensao := CatalogoPlex.dimensoes(objeto.tipo, objeto.rotacao)
		var centro := Vector2(objeto.celula) + Vector2(dimensao - Vector2i.ONE) * .5
		var largura := (2.0 if CatalogoPlex.base(objeto.tipo) == "porta_dupla" else 1.0) * (-1.0 if objeto.aberta else 1.0)
		for celula in planta.celulas(objeto.tipo, objeto.celula, objeto.rotacao):
			imagem.set_pixel(celula.x, celula.y, Color(centro.x, centro.y, objeto.rotacao, largura))
	return imagem

static func altura(planta: PlantaPlex, celula: Vector2i) -> float:
	if not GradePlex.dentro(celula): return 0.0
	var item := planta.em(celula)
	if item.get("tipo", "") == "palco": return 18.0
	if item.get("tipo", "") in SalasPlex.ESTRUTURA and not item.get("aberta", false): return 160.0
	return 0.0

static func grade(ponto: Vector3) -> Vector2:
	return GradePlex.inverter(Vector2(ponto.x, ponto.y * .5)) + Vector2(.5, .5)

static func raio_caixa(a: Vector3, b: Vector3, minimo: Vector3, maximo: Vector3, entrada: float, saida: float) -> bool:
	var delta := b - a
	for eixo in 3:
		if absf(delta[eixo]) < .000001:
			if a[eixo] < minimo[eixo] or a[eixo] > maximo[eixo]: return false
		else:
			var t1: float = (minimo[eixo] - a[eixo]) / delta[eixo]
			var t2: float = (maximo[eixo] - a[eixo]) / delta[eixo]
			entrada = maxf(entrada, minf(t1, t2))
			saida = minf(saida, maxf(t1, t2))
			if saida < entrada + .000001: return false
	return saida >= entrada + .000001

static func local_porta(ponto: Vector3, objeto: Dictionary) -> Vector3:
	var dimensao := CatalogoPlex.dimensoes(objeto.tipo, objeto.rotacao)
	var centro := Vector2(objeto.celula) + Vector2(dimensao - Vector2i.ONE) * .5
	var local := grade(ponto) - Vector2(.5, .5) - centro
	var frente := Vector2(GradePlex.frente(objeto.rotacao))
	return Vector3(local.dot(Vector2(frente.y, -frente.x)), local.dot(frente), ponto.z)

static func trecho_bloqueado(planta: PlantaPlex, celula: Vector2i, ponto: Vector3, luz: Vector3, entrada: float, saida: float) -> bool:
	var objeto := planta.em(celula)
	if objeto.get("tipo", "") not in CatalogoPlex.PORTAS:
		var z := minf(lerpf(ponto.z, luz.z, entrada), lerpf(ponto.z, luz.z, saida))
		return altura(planta, celula) > z + 1.0
	var a := local_porta(ponto, objeto)
	var b := local_porta(luz, objeto)
	var meio := 1.0 if CatalogoPlex.base(objeto.tipo) == "porta_dupla" else .5
	var passagem := meio - (.14 if CatalogoPlex.base(objeto.tipo) == "porta_dupla" else .12)
	if raio_caixa(a, b, Vector3(-meio + .005, -.495, 0), Vector3(-meio + .115, .495, 160), entrada, saida): return true
	if raio_caixa(a, b, Vector3(meio - .115, -.495, 0), Vector3(meio - .005, .495, 160), entrada, saida): return true
	if raio_caixa(a, b, Vector3(-meio, -.495, 98), Vector3(meio, .495, 160), entrada, saida): return true
	if not objeto.aberta:
		return raio_caixa(a, b, Vector3(-passagem, -.0325, 0), Vector3(passagem, .0325, 98), entrada, saida)
	var folha := passagem if CatalogoPlex.base(objeto.tipo) == "porta_dupla" else passagem * 2.0
	if raio_caixa(a, b, Vector3(-passagem - .0325, -folha, 1), Vector3(-passagem + .0325, 0, 97), entrada, saida): return true
	return CatalogoPlex.base(objeto.tipo) == "porta_dupla" and raio_caixa(a, b, Vector3(passagem - .0325, -folha, 1), Vector3(passagem + .0325, 0, 97), entrada, saida)

static func visibilidade(planta: PlantaPlex, ponto: Vector3, luz: Vector3) -> float:
	var a := grade(ponto)
	var delta := grade(luz) - a
	var celula := Vector2i(a.floor())
	var passo := Vector2i(int(signf(delta.x)), int(signf(delta.y)))
	var incremento := Vector2(1e20 if absf(delta.x) < .000001 else absf(1.0 / delta.x), 1e20 if absf(delta.y) < .000001 else absf(1.0 / delta.y))
	var limite := Vector2(celula) + Vector2(1 if delta.x >= 0 else 0, 1 if delta.y >= 0 else 0)
	var proximos := Vector2(absf(limite.x - a.x) * incremento.x, absf(limite.y - a.y) * incremento.y)
	if passo.x == 0: proximos.x = 1e20
	if passo.y == 0: proximos.y = 1e20
	var entrada := 0.0
	for i in GradePlex.TAMANHO.x + GradePlex.TAMANHO.y + 4:
		var saida := minf(1.0, minf(proximos.x, proximos.y))
		if trecho_bloqueado(planta, celula, ponto, luz, entrada, saida): return 0.0
		if saida >= 1.0: return 1.0
		if absf(proximos.x - proximos.y) < .000001:
			if trecho_bloqueado(planta, celula + Vector2i(passo.x, 0), ponto, luz, maxf(0, saida - .00001), minf(1, saida + .00001)) or trecho_bloqueado(planta, celula + Vector2i(0, passo.y), ponto, luz, maxf(0, saida - .00001), minf(1, saida + .00001)): return 0.0
			celula += passo
			proximos += incremento
		elif proximos.x < proximos.y:
			celula.x += passo.x
			proximos.x += incremento.x
		else:
			celula.y += passo.y
			proximos.y += incremento.y
		entrada = saida
	return 0.0


class_name RotasPlex
extends RefCounted

var planta: PlantaPlex
var grafo := AStar2D.new()

func _init(valor: PlantaPlex) -> void:
	planta = valor
	planta.alterada.connect(reconstruir)
	reconstruir()

func indice(celula: Vector2i) -> int:
	return celula.y * GradePlex.TAMANHO.x + celula.x

func celula(id: int) -> Vector2i:
	return Vector2i(id % GradePlex.TAMANHO.x, id / GradePlex.TAMANHO.x)

func escada_ligada(a: Vector2i, b: Vector2i) -> bool:
	var escada := planta.em(a)
	if escada.get("tipo", "") != "escada":
		return false
	var frente := GradePlex.frente(escada.rotacao)
	var entrada: Vector2i = a + frente
	var saida: Vector2i = a - frente
	if not EscadasPlex.acessivel(a, planta):
		return false
	var vizinho := planta.em(b)
	if vizinho.get("tipo", "") == "escada":
		return vizinho.rotacao == escada.rotacao and Vector2(b - a).dot(Vector2(frente)) == 0.0
	if b == entrada:
		return planta.transitavel(b) and is_zero_approx(planta.altura(b))
	return b == saida and vizinho.get("tipo", "") == "palco"

func conectavel(a: Vector2i, b: Vector2i) -> bool:
	if not CabinesPlex.permite(planta, a, b): return false
	var primeiro := planta.em(a)
	var segundo := planta.em(b)
	if primeiro.get("tipo", "") == "escada":
		return escada_ligada(a, b)
	if segundo.get("tipo", "") == "escada":
		return escada_ligada(b, a)
	for item in [primeiro, segundo]:
		if item.get("tipo", "") in ["porta", "porta_dupla"]:
			var normal := GradePlex.frente(item.rotacao)
			if a - b != normal and b - a != normal:
				return false
	return is_equal_approx(planta.altura(a), planta.altura(b))

func reconstruir() -> void:
	grafo.clear()
	for y in GradePlex.TAMANHO.y:
		for x in GradePlex.TAMANHO.x:
			var local := Vector2i(x, y)
			if planta.transitavel(local):
				grafo.add_point(indice(local), Vector2(local))
	for id in grafo.get_point_ids():
		var a := celula(id)
		for deslocamento in GradePlex.VIZINHOS:
			var b: Vector2i = a + deslocamento
			if GradePlex.dentro(b) and grafo.has_point(indice(b)) and conectavel(a, b):
				grafo.connect_points(id, indice(b))

func caminho(origem: Vector2i, destino: Vector2i, bloqueados: Array[Vector2i] = []) -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	if not GradePlex.dentro(origem) or not GradePlex.dentro(destino):
		return resultado
	if not grafo.has_point(indice(origem)) or not grafo.has_point(indice(destino)):
		return resultado
	var desativados: Array[int] = []
	for local in bloqueados:
		if local != origem and GradePlex.dentro(local) and grafo.has_point(indice(local)):
			grafo.set_point_disabled(indice(local), true)
			desativados.append(indice(local))
	for id in grafo.get_id_path(indice(origem), indice(destino)):
		resultado.append(celula(id))
	for id in desativados:
		grafo.set_point_disabled(id, false)
	return resultado

func aproximar(origem: Vector2i, objeto: int) -> Array[Vector2i]:
	var melhor: Array[Vector2i] = []
	for destino in planta.interacoes(objeto):
		var rota := caminho(origem, destino)
		if not rota.is_empty() and (melhor.is_empty() or rota.size() < melhor.size()):
			melhor = rota
	return melhor

func sair_suporte(suporte: int, destino: Vector2i) -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	for entrada in planta.interacoes(suporte):
		var rota := caminho(entrada, destino)
		if not rota.is_empty():
			resultado.append(planta.objetos[suporte].celula)
			resultado.append_array(rota)
			return resultado
	return resultado

func aproximar_montagem(origem: Vector2i, suporte: int) -> Array[Vector2i]:
	var opcoes := planta.interacoes(suporte)
	var centro: Vector2i = planta.objetos[suporte].celula
	var frente := GradePlex.frente(planta.objetos[suporte].rotacao)
	opcoes.sort_custom(func(a, b):
		var nota_a: float = GradePlex.projetar_local(Vector2(a - centro)).y + (2.0 if a - centro == frente else 0.0)
		var nota_b: float = GradePlex.projetar_local(Vector2(b - centro)).y + (2.0 if b - centro == frente else 0.0)
		return nota_a > nota_b)
	for destino in opcoes:
		var rota := caminho(origem, destino)
		if not rota.is_empty():
			return rota
	return []

class_name RotasPlex
extends RefCounted

var planta: PlantaPlex
var grafo := AStar2D.new()
var assinatura: int = -1
var revisao := 0
var cache: Dictionary = {}
var consultas := 0
var calculadas := 0
var reconstrucoes := 0
var bloqueios_ativos: Dictionary = {}
var assinatura_bloqueios := -1

func _init(valor: PlantaPlex) -> void:
	planta = valor
	planta.alterada.connect(reconstruir)
	reconstruir()

func indice(celula_local: Vector2i) -> int:
	return celula_local.y * GradePlex.TAMANHO.x + celula_local.x

func celula(id: int) -> Vector2i:
	return Vector2i(id % GradePlex.TAMANHO.x, floori(float(id) / GradePlex.TAMANHO.x))

func escada_ligada(a: Vector2i, b: Vector2i) -> bool:
	var escada := planta.em(a)
	if not EscadasPlex.eh(escada):
		return false
	var frente := GradePlex.frente(escada.rotacao)
	var entrada: Vector2i = a + frente
	var saida: Vector2i = a - frente
	var conectada := EscadasPlex.faixa(a,planta).any(func(c): return EscadasPlex.palco(planta.em(c-frente)))
	if not conectada: return false
	var vizinho := planta.em(b)
	if EscadasPlex.eh(vizinho):
		return vizinho.rotacao == escada.rotacao and Vector2(b - a).dot(Vector2(frente)) == 0.0
	if b == entrada:
		return GradePlex.dentro(b) and is_zero_approx(planta.altura(b))
	return b == saida and EscadasPlex.palco(vizinho)

func conectavel(a: Vector2i, b: Vector2i) -> bool:
	if not CabinesPlex.permite(planta, a, b): return false
	var primeiro := planta.em(a)
	var segundo := planta.em(b)
	if EscadasPlex.eh(primeiro):
		return escada_ligada(a, b)
	if EscadasPlex.eh(segundo):
		return escada_ligada(b, a)
	for item in [primeiro, segundo]:
		if item.get("tipo", "") in CatalogoPlex.PORTAS:
			var normal := GradePlex.frente(item.rotacao)
			if a - b != normal and b - a != normal:
				return false
	return is_equal_approx(planta.altura(a), planta.altura(b))

func reconstruir() -> void:
	var estrutura: Array = []
	for item in planta.objetos.values():
		if item.tipo in (CatalogoPlex.PORTAS + ["divisoria_porta"]) or EscadasPlex.tipo(item) in ["palco","escada"]: estrutura.append([item.tipo,item.celula,item.rotacao])
	var atual := hash(estrutura)
	if assinatura != atual:
		assinatura = atual
		reconstrucoes += 1
		grafo.clear()
		bloqueios_ativos.clear()
		assinatura_bloqueios = -1
		for y in GradePlex.TAMANHO.y:
			for x in GradePlex.TAMANHO.x:
				var local := Vector2i(x,y)
				grafo.add_point(indice(local),Vector2(local))
		for id in grafo.get_point_ids():
			var a := celula(id)
			for d in [Vector2i(1,0),Vector2i(0,1)]:
				var b: Vector2i = a+d
				if GradePlex.dentro(b) and conectavel(a,b): grafo.connect_points(id,indice(b))
	atualizar_bloqueios()

func atualizar_bloqueios() -> void:
	var novos: Dictionary = {}
	for c in planta.ocupacao:
		var item := planta.em(c)
		if item.get("tipo","") not in CatalogoPlex.PORTAS and EscadasPlex.tipo(item) not in ["palco","escada"]: novos[c]=true
	for c in planta.reservas_abertura: novos[c]=true
	var atual := hash(novos)
	if atual == assinatura_bloqueios: return
	assinatura_bloqueios = atual
	for c in bloqueios_ativos:
		if not novos.has(c) and grafo.has_point(indice(c)): grafo.set_point_disabled(indice(c),false)
	for c in novos:
		if not bloqueios_ativos.has(c) and grafo.has_point(indice(c)): grafo.set_point_disabled(indice(c),true)
	bloqueios_ativos = novos
	revisao += 1
	cache.clear()

func caminho(origem: Vector2i, destino: Vector2i, bloqueados: Array[Vector2i] = []) -> Array[Vector2i]:
	consultas += 1
	var chave := Vector4i(origem.x,origem.y,destino.x,destino.y)
	if bloqueados.is_empty() and cache.has(chave):
		var salva: Array[Vector2i] = []
		salva.assign(cache[chave])
		return salva
	var resultado: Array[Vector2i] = []
	if not GradePlex.dentro(origem) or not GradePlex.dentro(destino):
		return resultado
	if not grafo.has_point(indice(origem)) or not grafo.has_point(indice(destino)):
		return resultado
	if grafo.is_point_disabled(indice(destino)) and destino != origem: return resultado
	var origem_bloqueada := grafo.is_point_disabled(indice(origem))
	if origem_bloqueada: grafo.set_point_disabled(indice(origem),false)
	var desativados: Array[int] = []
	for local in bloqueados:
		if local != origem and GradePlex.dentro(local) and grafo.has_point(indice(local)) and not grafo.is_point_disabled(indice(local)):
			grafo.set_point_disabled(indice(local), true)
			desativados.append(indice(local))
	calculadas += 1
	for id in grafo.get_id_path(indice(origem), indice(destino)):
		resultado.append(celula(id))
	for id in desativados:
		grafo.set_point_disabled(id, false)
	if origem_bloqueada: grafo.set_point_disabled(indice(origem),true)
	if bloqueados.is_empty():
		if cache.size()>=4096: cache.clear()
		cache[chave] = resultado.duplicate()
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


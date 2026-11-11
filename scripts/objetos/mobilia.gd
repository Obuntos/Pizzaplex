class_name MobiliaPlex
extends RefCounted

static func visual(item: Dictionary) -> String:
	return str(item.get("variante", item.tipo))

static func dados(item: Dictionary) -> Dictionary:
	return CatalogoPlex.objetos.get(visual(item), {})

static func logico(tipo: String) -> String:
	return str(CatalogoPlex.objetos.get(tipo, {}).get("logico", tipo))

static func preparar(item: Dictionary, tipo: String) -> void:
	var destino := logico(tipo)
	if destino == tipo: return
	item.variante = tipo
	item.tipo = destino
	item.estado = CatalogoPlex.objetos[destino].get("estado_padrao", "")

static func estado(item: Dictionary) -> String:
	var info := dados(item)
	var estados: Array = info.get("estados", [])
	if item.tipo in CatalogoPlex.PORTAS: return "aberta" if item.get("aberta", false) else "fechada"
	var atual := str(item.get("estado", ""))
	if estados.has(atual): return atual
	return str(item.get("estado_visual", info.get("estado_padrao", "")))

static func preco(tipo: String) -> int:
	return maxi(0, int(CatalogoPlex.objetos.get(tipo, {}).get("preco", 0)))

static func modulos(tipo: String, celula: Vector2i, rotacao: int) -> Array[Vector2i]:
	var pacote: Array = CatalogoPlex.objetos.get(tipo, {}).get("pacote", [1,1])
	var tamanho := Vector2i(pacote[0], pacote[1])
	if rotacao % 2 == 1: tamanho = Vector2i(tamanho.y,tamanho.x)
	var resultado: Array[Vector2i] = []
	for x in tamanho.x:
		for y in tamanho.y: resultado.append(celula + Vector2i(x,y))
	return resultado

static func nota(item: Dictionary) -> int:
	var valor := int(dados(item).get("conforto", 0))
	if valor<=0: return 0
	if estado(item) in ["lascada","danificada","partido","rasgado","sem-porta","buraco","topo-partido"]: valor -= 1
	return clampi(valor,1,10)

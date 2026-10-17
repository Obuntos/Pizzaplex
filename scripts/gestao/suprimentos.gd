class_name SuprimentosPlex
extends RefCounted

const COMPONENTES = ["massa","molho","queijo"]

static func preparar(geladeira: Dictionary) -> void:
	if not geladeira.has("estoque"):
		geladeira.estoque = {}
		for c in COMPONENTES: geladeira.estoque[c] = int(geladeira.get("ingredientes",0))
	geladeira.ingredientes = COMPONENTES.map(func(c): return int(geladeira.estoque.get(c,0))).min()

static func cabe(geladeira: Dictionary, caixa: Dictionary) -> bool:
	preparar(geladeira)
	var c: String = caixa.get("componente", "")
	return int(geladeira.estoque.get(c,12)) < 12 if COMPONENTES.has(c) else int(geladeira.ingredientes) < 8 and COMPONENTES.all(func(nome): return int(geladeira.estoque.get(nome,0))<12)

static func abastecer(geladeira: Dictionary, caixa: Dictionary) -> int:
	preparar(geladeira)
	var c: String = caixa.get("componente", "")
	var maior: int = COMPONENTES.map(func(nome): return int(geladeira.estoque.get(nome,0))).max()
	var qtd := mini(int(caixa.quantidade),12-int(geladeira.estoque[c] if COMPONENTES.has(c) else maior))
	if qtd <= 0: return 0
	for nome in COMPONENTES:
		if c.is_empty() or nome == c: geladeira.estoque[nome] = int(geladeira.estoque.get(nome,0))+qtd
	caixa.quantidade -= qtd
	preparar(geladeira)
	return qtd

static func retirar(geladeira: Dictionary) -> bool:
	preparar(geladeira)
	if int(geladeira.ingredientes) < 1: return false
	for c in COMPONENTES: geladeira.estoque[c] -= 1
	preparar(geladeira)
	return true

static func devolver(geladeira: Dictionary) -> void:
	preparar(geladeira)
	for c in COMPONENTES: geladeira.estoque[c] += 1
	preparar(geladeira)

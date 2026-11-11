class_name SuprimentosPlex
extends RefCounted

const COMPONENTES = ["pizza", "guarana"]
const CAPACIDADE = 24

static func preparar(geladeira: Dictionary) -> void:
	if not geladeira.has("estoque"): geladeira.estoque = {"pizza":int(geladeira.get("ingredientes", 0)), "guarana":0}
	var estoque: Dictionary = geladeira.estoque
	if not estoque.has("pizza"):
		estoque.pizza = mini(int(estoque.get("massa", 0)), mini(int(estoque.get("molho", 0)), int(estoque.get("queijo", 0))))
	if not estoque.has("guarana"): estoque.guarana = 0
	for legado in ["massa", "molho", "queijo"]: estoque.erase(legado)
	geladeira.ingredientes = int(estoque.pizza)

static func componente(caixa: Dictionary) -> String:
	return "guarana" if caixa.get("componente", "") == "guarana" or caixa.get("tipo", "") == "caixa_guarana" else "pizza"

static func cabe(geladeira: Dictionary, caixa: Dictionary) -> bool:
	preparar(geladeira)
	return int(geladeira.estoque[componente(caixa)]) < CAPACIDADE

static func abastecer(geladeira: Dictionary, caixa: Dictionary) -> int:
	preparar(geladeira)
	var c := componente(caixa)
	var qtd := mini(int(caixa.quantidade), CAPACIDADE - int(geladeira.estoque[c]))
	if qtd <= 0: return 0
	geladeira.estoque[c] += qtd
	caixa.quantidade -= qtd
	preparar(geladeira)
	return qtd

static func retirar(geladeira: Dictionary, c: String = "pizza") -> bool:
	preparar(geladeira)
	if int(geladeira.estoque.get(c, 0)) < 1: return false
	geladeira.estoque[c] -= 1
	preparar(geladeira)
	return true

static func devolver(geladeira: Dictionary, c: String = "pizza") -> void:
	preparar(geladeira)
	geladeira.estoque[c] = mini(CAPACIDADE, int(geladeira.estoque.get(c, 0)) + 1)
	preparar(geladeira)

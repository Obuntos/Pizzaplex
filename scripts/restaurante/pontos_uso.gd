class_name PontosUsoPlex
extends RefCounted

static var definicoes: Dictionary = {}

static func carregar() -> void:
	if definicoes.is_empty(): definicoes = JSON.parse_string(FileAccess.get_file_as_string("res://dados/pontos_uso.json"))

static func tem(tipo: String) -> bool:
	carregar()
	return definicoes.has(tipo)

static func ponto(objeto: Dictionary, nome: String) -> Vector3:
	carregar()
	var dimensao := CatalogoPlex.dimensoes(objeto.tipo, objeto.rotacao)
	var centro := Vector2(objeto.celula) + Vector2(dimensao - Vector2i.ONE) * .5
	var frente := Vector2(GradePlex.frente(objeto.rotacao))
	var lado := Vector2(frente.y, -frente.x)
	var dados: Array = definicoes.get(objeto.tipo, {}).get(nome, [0, 1, 0])
	var local := centro + lado * float(dados[0]) + frente * float(dados[1])
	return Vector3(local.x, local.y, float(dados[2]))

static func parada(objeto: Dictionary) -> Vector2:
	var p := ponto(objeto, "parada")
	return Vector2(p.x, p.y)

static func caixa(objeto: Dictionary) -> Vector3:
	return ponto(objeto, "caixa")

static func alvos(objeto: Dictionary) -> Array[Vector2i]:
	carregar()
	var resultado: Array[Vector2i] = []
	var dados: Array = definicoes.get(objeto.tipo, {}).get("acessos", [])
	if dados.is_empty(): return [Vector2i(parada(objeto).round())]
	var centro := Vector2(objeto.celula) + Vector2(CatalogoPlex.dimensoes(objeto.tipo,objeto.rotacao)-Vector2i.ONE)*.5
	var frente := Vector2(GradePlex.frente(objeto.rotacao))
	var lado := Vector2(frente.y,-frente.x)
	for local in dados: resultado.append(Vector2i((centro+lado*float(local[0])+frente*float(local[1])).round()))
	return resultado

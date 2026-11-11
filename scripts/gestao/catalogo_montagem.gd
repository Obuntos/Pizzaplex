class_name CatalogoMontagemPlex
extends RefCounted
const LEGADOS=["endo","endo_01","raposa","dragao","endo_08","galo","endo_04","ave","endo_03","macaco","endo_02","guaxinim","coelho","ovelha","endo_07","gato","endo_05","dragao_variante","coelho_quebrado","coelho_travado","ovelha_quebrada","ovelha_travada","raposa_quebrada","raposa_travada","cervo_quebrado","hipopotamo_quebrado","sol_fantoche"]

static var dados: Dictionary = {}

static func carregar() -> void:
	if dados.is_empty(): dados = JSON.parse_string(FileAccess.get_file_as_string("res://dados/montagem_modelos.json"))

static func modelo(id: String) -> Dictionary:
	carregar()
	return dados.modelos.get(id,{})

static func robotico(id: String) -> bool:
	carregar()
	return id in LEGADOS or AtracoesCatalogoPlex.permitido(id) or dados.modelos.has(id)

static func quebrado(id: String) -> bool:
	return bool(modelo(id).get("quebrado",false))

static func carcaca(id: String) -> bool:
	return bool(modelo(id).get("carcaca",not quebrado(id)))

static func config(id: String) -> Dictionary:
	var m := modelo(id)
	if m.is_empty(): return {}
	var tipo: String = m.estrutura
	return {"cabeca":tipo,"corpo":tipo,"bracos":tipo,"pernas":tipo,"modelo_estrutura":m.endo}

static func nome(id: String) -> String:
	return str(AtracoesCatalogoPlex.registro(id).get("nome",modelo(id).get("nome",id.capitalize())))


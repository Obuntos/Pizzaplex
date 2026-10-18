class_name CatalogoMontagemPlex
extends RefCounted

static var dados: Dictionary = {}

static func carregar() -> void:
	if dados.is_empty(): dados = JSON.parse_string(FileAccess.get_file_as_string("res://dados/montagem_modelos.json"))

static func modelo(id: String) -> Dictionary:
	carregar()
	return dados.modelos.get(id,{})

static func robotico(id: String) -> bool:
	ClipesPlex.carregar()
	return id=="endo" or ClipesPlex.modelos.has(id)

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
	return str(modelo(id).get("nome",id.capitalize()))

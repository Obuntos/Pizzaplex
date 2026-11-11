class_name VariedadeAparenciaPlex
extends RefCounted

static var dados: Dictionary = {}

static func carregar() -> void:
	if dados.is_empty(): dados=JSON.parse_string(FileAccess.get_file_as_string("res://dados/variedade_aparencia.json"))

static func feminino(ator: PersonagemPlex) -> bool:
	return str(ator.identidade.get("sexo",""))=="feminino" or ator.modelo in ["humana","adolescente_feminina"]

static func cabelos(ator: PersonagemPlex) -> Array:
	carregar()
	AparenciaPlex.carregar()
	var lista: Array=dados.infantis if ator.modelo=="crianca" else dados.femininos if feminino(ator) else dados.masculinos
	return AparenciaPlex.dados.cabelos.filter(func(c): return lista.has(str(c.id)))

static func escolher_cabelo(ator: PersonagemPlex, reservado: String) -> String:
	var lista:=cabelos(ator).filter(func(c): return str(c.id)!=reservado)
	if lista.is_empty(): return "nenhum"
	var salvo:=str(ator.visita.get("estilo_cabelo",""))
	if not lista.any(func(c): return str(c.id)==salvo):
		var indice:=posmod(hash(str(ator.identificador)+str(ator.identidade.get("nome",""))+":estilo"),lista.size())
		salvo=str(lista[indice].id)
		ator.visita.estilo_cabelo=salvo
	return salvo

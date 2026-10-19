class_name RoupasVisitantesPlex
extends RefCounted

static var dados: Dictionary = {}
static var arquivos: Dictionary = {}

static func carregar() -> void:
	if dados.is_empty(): dados=JSON.parse_string(FileAccess.get_file_as_string("res://dados/roupas_visitantes.json"))

static func pasta(ator: PersonagemPlex) -> String:
	if ator.cargo!="cliente" or ator.modelo not in ["humano","humana"]: return ""
	carregar()
	var id:=str(ator.visita.get("roupa",""))
	if not dados.has(id) or dados[id].modelo!=ator.modelo:
		var opcoes: Array=dados.keys().filter(func(chave): return dados[chave].modelo==ator.modelo)
		if opcoes.is_empty(): return ""
		id=opcoes[posmod(hash(IdentidadesPlex.completo(ator)),opcoes.size())]
		ator.visita.roupa=id
	return str(dados[id].pasta)

static func arquivo(ator: PersonagemPlex, original: String) -> String:
	var destino:=pasta(ator)
	if destino.is_empty(): return original
	var prefixo: String="res://assets/personagens/"+ator.modelo+"/"
	if not original.begins_with(prefixo): return original
	var novo:=destino+"/"+original.trim_prefix(prefixo)
	if not arquivos.has(novo): arquivos[novo]=novo if ResourceLoader.exists(novo) else original
	return str(arquivos[novo])

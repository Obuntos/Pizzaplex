class_name RoupasVisitantesPlex
extends RefCounted

static var dados: Dictionary = {}
static var arquivos: Dictionary = {}

static func carregar() -> void:
	if dados.is_empty(): dados=JSON.parse_string(FileAccess.get_file_as_string("res://dados/roupas_visitantes.json"))

static func visitante(ator: PersonagemPlex) -> bool:
	return (ator.cargo in ["cliente","morador","adolescente","crianca"] or ator.visita.get("turno_civil",false)) and not ator.robo

static func compativel(item: Dictionary, ator: PersonagemPlex) -> bool:
	var modelo_base: String="humana" if VariedadeAparenciaPlex.feminino(ator) else "humano"
	if str(item.modelo)!=modelo_base: return false
	return item.get("pastas",{str(item.modelo):str(item.pasta)}).has(ator.modelo)

static func pasta(ator: PersonagemPlex) -> String:
	if not visitante(ator): return ""
	carregar()
	var id:=str(ator.visita.get("roupa",""))
	if not dados.has(id) or not compativel(dados[id],ator):
		var opcoes: Array=dados.keys().filter(func(chave): return compativel(dados[chave],ator))
		if opcoes.is_empty(): return ""
		id=str(opcoes[posmod(hash(IdentidadesPlex.completo(ator)+str(ator.identificador)+":roupa"),opcoes.size())])
		ator.visita.roupa=id
	return str(dados[id].get("pastas",{}).get(ator.modelo,dados[id].pasta))

static func arquivo(ator: PersonagemPlex, original: String) -> String:
	var destino:=pasta(ator)
	if destino.is_empty(): return original
	var prefixo: String="res://assets/personagens/"+ator.modelo+"/"
	if not original.begins_with(prefixo): return original
	var novo:=destino+"/"+original.trim_prefix(prefixo)
	if not arquivos.has(novo): arquivos[novo]=novo if ResourceLoader.exists(novo) else original
	return str(arquivos[novo])

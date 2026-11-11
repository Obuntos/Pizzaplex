class_name CoresCabeloPlex
extends RefCounted

static var opcoes: Array = []
static var cache: Dictionary = {}

static func carregar() -> void:
	if opcoes.is_empty(): opcoes=JSON.parse_string(FileAccess.get_file_as_string("res://dados/cores_cabelo.json"))

static func validar(id: String) -> String:
	carregar()
	return id if opcoes.any(func(c): return str(c.id)==id) else "marrom_escuro"

static func cor(ator: PersonagemPlex) -> String:
	carregar()
	if not ator.visita.has("cor_cabelo"):
		var indice:=posmod(hash(str(ator.identificador)+str(ator.identidade.get("nome",""))+":cabelo"),opcoes.size())
		ator.visita.cor_cabelo=str(opcoes[indice].id)
	ator.visita.cor_cabelo=validar(str(ator.visita.cor_cabelo))
	return str(ator.visita.cor_cabelo)

static func textura(arquivo: String, id: String, modelo: String = "") -> CanvasTexture:
	var relativo:=arquivo.trim_prefix("res://assets/aparencias/cabelos/")
	var estilo:=relativo.get_slice("/",0)
	var ajustado := EncaixeCabeloPlex.ajustado(modelo,estilo)
	var base := "res://assets/aparencias/cabelos_ajustados/"+modelo+"/"+relativo if ajustado else arquivo
	var original:=CatalogoPlex.textura_iluminada(base) as CanvasTexture
	if id.is_empty(): return original
	var chave:=base+":"+validar(id)
	if cache.has(chave): return cache[chave]
	var pasta := "res://assets/aparencias/cabelos_cores_ajustados/"+modelo+"/" if ajustado else "res://assets/aparencias/cabelos_cores/"
	var caminho:=pasta+estilo+"/"+validar(id)+"/"+relativo.get_file()
	if not ResourceLoader.exists(caminho): return original
	var resultado:=CanvasTexture.new()
	resultado.diffuse_texture=load(caminho)
	resultado.normal_texture=original.normal_texture
	resultado.specular_texture=original.specular_texture
	resultado.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	if cache.size()>=96: cache.erase(cache.keys()[0])
	cache[chave]=resultado
	return resultado

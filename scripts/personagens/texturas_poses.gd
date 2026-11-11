class_name TexturasPosesPlex
extends RefCounted

static var texturas: Dictionary = {}
static var carregador: RefCounted
static var pendentes: Dictionary={}
static var falhas: Dictionary={}
static var ordem: Array[String] = []
static var bytes_texturas := 0
static var criados := 0
const LIMITE := 96 * 1024 * 1024

static func mapa(caminho: String, material: bool = false) -> String:
	var relativo := caminho.trim_prefix("res://assets/poses_humanas/")
	var uniforme := relativo.get_slice("/",0)
	var referencia := caminho
	if not (uniforme == "nenhum" and caminho.ends_with("/parado_corpo.png")):
		referencia = caminho.replace("res://assets/poses_humanas/"+uniforme+"/","res://assets/poses_humanas/funcionario/")
	return referencia.replace(".png","_material.png" if material else "_normal.png")

static func recurso_pronto(caminho: String) -> bool:
	if CatalogoPlex.texturas.has(caminho) or ResourceLoader.has_cached(caminho): return true
	if falhas.has(caminho): return false
	if is_instance_valid(carregador):
		if carregador.recursos.has(caminho): return true
		if carregador.falhas.has(caminho): falhas[caminho]=true;return false
		carregador.adicionar(caminho)
		return false
	if not ResourceLoader.exists(caminho): falhas[caminho]=true;return false
	if not pendentes.has(caminho):
		var erro:=ResourceLoader.load_threaded_request(caminho)
		if erro!=OK: falhas[caminho]=true;return false
		pendentes[caminho]=true
	var estado:=ResourceLoader.load_threaded_get_status(caminho)
	if estado==ResourceLoader.THREAD_LOAD_LOADED:
		CatalogoPlex.texturas[caminho]=ResourceLoader.load_threaded_get(caminho)
		pendentes.erase(caminho)
		return true
	if estado==ResourceLoader.THREAD_LOAD_FAILED or estado==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		falhas[caminho]=true;pendentes.erase(caminho)
	return false

static func obter_recurso(caminho: String) -> Texture2D:
	if is_instance_valid(carregador) and carregador.recursos.has(caminho): return carregador.recursos[caminho]
	if CatalogoPlex.texturas.has(caminho): return CatalogoPlex.texturas[caminho]
	return load(caminho) as Texture2D if ResourceLoader.has_cached(caminho) else null

static func pronta(caminho: String) -> bool:
	if texturas.has(caminho): return true
	var pronta_base:=true
	for arquivo in [caminho,mapa(caminho),mapa(caminho,true)]:
		if arquivo!=caminho and not ResourceLoader.exists(arquivo): continue
		if not recurso_pronto(arquivo): pronta_base=false
	return pronta_base

static func atlas_completo(caminho: String) -> CanvasTexture:
	if texturas.has(caminho):
		ordem.erase(caminho)
		ordem.append(caminho)
		return texturas[caminho]
	if not pronta(caminho): return null
	var canvas := CanvasTexture.new()
	canvas.diffuse_texture=obter_recurso(caminho)
	canvas.normal_texture=obter_recurso(mapa(caminho))
	canvas.specular_texture=obter_recurso(mapa(caminho,true))
	canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var tamanho := int(canvas.get_width()*canvas.get_height())*12
	while not ordem.is_empty() and bytes_texturas+tamanho>LIMITE:
		var antiga: String=ordem.pop_front()
		var anterior: CanvasTexture=texturas[antiga]
		bytes_texturas-=int(anterior.get_width()*anterior.get_height())*12
		texturas.erase(antiga)
	ordem.append(caminho)
	texturas[caminho]=canvas
	bytes_texturas+=tamanho
	criados+=1
	return canvas

static func aplicar(atlas: AtlasTexture, caminho: String, regiao: Rect2) -> void:
	if atlas.get_meta("fonte_poses","")!=caminho or atlas.atlas==null or atlas.atlas.get_instance_id()!=int(atlas.get_meta("textura_poses",0)):
		var completa:=atlas_completo(caminho)
		if completa==null: return
		atlas.atlas=completa
		atlas.set_meta("fonte_poses",caminho)
		atlas.set_meta("textura_poses",atlas.atlas.get_instance_id())
	if atlas.region!=regiao: atlas.region=regiao


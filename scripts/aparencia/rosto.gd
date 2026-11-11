class_name RostoPlex
extends RefCounted

const OLHOS=["padrao","cansados","fox","doe"]
const ITENS=["bochechas","nariz","sardas","pintas"]
const ESTADOS=["neutro","feliz","muito_feliz","chateado","triste","depressivo","ansioso","medo","pavor","incomodado","raivoso","confuso","surpreso","shocked"]
static var cache:Dictionary={}
static func itens(valor:Variant) -> Array:
	var r:Array=[]
	if valor is Array:
		for item in valor:
			if item in ITENS and not r.has(item) and r.size()<2:r.append(item)
	return r
static func olhos(valor:String) -> String: return valor if valor in OLHOS else "padrao"
static func estado(valor:String) -> String:
	return {"cansado":"depressivo","assustado":"medo","irritado":"incomodado"}.get(valor,valor) if valor not in [""] and (valor in ESTADOS or valor in ["cansado","assustado","irritado"]) else "neutro"
static func textura(tipo:String,expressao:String,item:String="") -> Texture2D:
	var arquivo:="res://assets/aparencias/rostos/"+olhos(tipo)+"_"+estado(expressao)+("_"+item if not item.is_empty() else "")+".png"
	if not cache.has(arquivo):
		if cache.size()>=48:cache.erase(cache.keys()[0])
		cache[arquivo]=load(arquivo)
	return cache[arquivo]
static func aplicar(a:PersonagemPlex) -> void:
	if a.visita.get("morto",false) or a.modelo not in ["humano","humana"] or not a.animacao.camadas.has("olhos"):
		for i in 2:
			var extra:Sprite2D=a.personalizacao.camadas.get("rosto_"+str(i))
			if is_instance_valid(extra):extra.hide()
		return
	var e:=estado(a.animacao.expressao)
	var tipo:=olhos(str(a.visita.get("olhos","padrao")))
	var quadro:=posmod(floori(a.relogio*6.0),24)
	var direcao:=GradePlex.direcao_visual(a.direcao)
	var olho:Sprite2D=a.animacao.camadas.olhos
	var cabeca:Sprite2D=a.animacao.camadas.cabeca
	var atlas:AtlasTexture=a.animacao.atlases.olhos
	atlas.atlas=textura(tipo,e);atlas.region=Rect2(quadro*48,direcao*40,48,40)
	olho.position=cabeca.position;olho.scale=cabeca.scale;olho.show();a.animacao.camadas.boca.hide()
	var escolhidos:=itens(a.visita.get("itens_faciais",[]))
	for i in 2:
		var sprite:Sprite2D=a.personalizacao.camadas.get("rosto_"+str(i))
		if sprite==null:
			if i>=escolhidos.size():continue
			sprite=Sprite2D.new();sprite.centered=false;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;sprite.use_parent_material=true;sprite.texture=CatalogoPlex.atlas_vazio()
			a.visual.add_child(sprite);a.personalizacao.camadas["rosto_"+str(i)]=sprite
		sprite.visible=i<escolhidos.size()
		if not sprite.visible:continue
		var imagem:AtlasTexture=sprite.texture
		imagem.atlas=textura(tipo,e,str(escolhidos[i]));imagem.region=atlas.region
		sprite.position=a.animacao.position+cabeca.position*a.animacao.scale;sprite.scale=cabeca.scale*a.animacao.scale

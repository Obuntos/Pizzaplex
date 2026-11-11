class_name CabeloProfissaoPlex
extends RefCounted
static var cache:Dictionary={}
static func textura(original:Texture2D,modelo:String) -> Texture2D:
	var chave:=str(original.get_instance_id())+modelo
	if cache.has(chave):return cache[chave]
	var fonte:=SilhuetasPlex.imagem(original)
	if fonte==null or fonte.get_width()<48 or fonte.get_height()<480:return null
	var cabelo:=CatalogoPlex.imagem("res://assets/aparencias/cabelos/curto/parado_frente.png")
	var tras:=CatalogoPlex.imagem("res://assets/aparencias/cabelos/curto/parado_tras.png")
	var imagem:=Image.create_empty(fonte.get_width(),fonte.get_height(),false,Image.FORMAT_RGBA8)
	for d in 8:
		for f in floori(float(fonte.get_width())/48.0):
			for y in range(6,29):
				for x in range(7,41):
					var n:=fonte.get_pixel(f*48+x,d*60+y)
					if n.a>.5 and y<17 and not (n.r>n.g*1.12 and n.g>n.b*1.10 and n.r>.4):continue
					var p:=Vector2i((f%12)*48+x,d*68+y+8)
					var c:=cabelo.get_pixelv(p)
					if d in [3,4,5]:c=tras.get_pixelv(p).blend(c)
					if c.a>.1:imagem.set_pixel(f*48+x,d*60+y,c)
	var t:=ImageTexture.create_from_image(imagem);SilhuetasPlex.registrar(t,imagem)
	if cache.size()>=16:cache.erase(cache.keys()[0])
	cache[chave]=t;return t
static func aplicar(a:AnimacaoPlex) -> void:
	if not ProfissoesBairroPlex.eh(a.modelo) or a.modelo=="profissao_jornalista":return
	var base:AtlasTexture=a.atlases.modelo
	if base.atlas==null:return
	if not a.camadas.has("cabelo_profissional"):
		var s:=Sprite2D.new();s.centered=false;s.use_parent_material=true;s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;s.texture=CatalogoPlex.atlas_vazio();a.add_child(s);a.camadas.cabelo_profissional=s
	var cabelo:Sprite2D=a.camadas.cabelo_profissional;var atlas:AtlasTexture=cabelo.texture
	var textura_cabelo:=textura(base.atlas,a.modelo)
	cabelo.visible=textura_cabelo!=null
	if textura_cabelo==null:return
	atlas.atlas=textura_cabelo;atlas.region=base.region;cabelo.position=a.camadas.modelo.position
static func aplicar_guarda(ator:PersonagemPlex) -> void:
	if not ProfissoesBairroPlex.eh(ator.modelo) and ator.animacao.camadas.has("cabelo_profissional"):ator.animacao.camadas.cabelo_profissional.hide()

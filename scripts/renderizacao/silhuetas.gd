class_name SilhuetasPlex
extends RefCounted

static var imagens: Dictionary = {}
static var ordem_imagens: Array[int] = []
static var quadros: Dictionary = {}
static var ordem: Array[String] = []
static var compostos := 0
static var bytes_imagens := 0
const LIMITE_IMAGENS := 64 * 1024 * 1024

static func registrar(textura: Texture2D, fonte: Image) -> void:
	if not valida(textura) or fonte==null or fonte.is_empty(): return
	var id := textura.get_instance_id()
	if imagens.has(id): return
	var tamanho := fonte.get_width()*fonte.get_height()*4
	while not ordem_imagens.is_empty() and (bytes_imagens+tamanho>LIMITE_IMAGENS or ordem_imagens.size()>=192):
		var antiga: int=ordem_imagens.pop_front()
		var anterior: Image=imagens[antiga]
		bytes_imagens-=anterior.get_width()*anterior.get_height()*4
		imagens.erase(antiga)
	ordem_imagens.append(id)
	imagens[id]=fonte
	bytes_imagens+=tamanho

static func valida(textura: Texture2D) -> bool:
	if textura==null or not is_instance_valid(textura): return false
	if textura is AtlasTexture: return valida(textura.atlas)
	if textura is CanvasTexture: return valida(textura.diffuse_texture)
	return textura.get_width()>0 and textura.get_height()>0

static func imagem(textura: Texture2D) -> Image:
	if not valida(textura): return null
	if textura is AtlasTexture:
		var base:=imagem(textura.atlas)
		return (base.get_region(Rect2i(textura.region)) if textura.region.has_area() else base) if base!=null else null
	if textura is CanvasTexture: return imagem(textura.diffuse_texture)
	var id := textura.get_instance_id()
	if not imagens.has(id):
		var caminho:=textura.resource_path
		var fonte:=Image.new()
		if not caminho.begins_with("res://") or not caminho.ends_with(".png") or not FileAccess.file_exists(caminho) or fonte.load_png_from_buffer(FileAccess.get_file_as_bytes(caminho))!=OK: fonte=textura.get_image()
		if fonte==null or fonte.is_empty(): return null
		registrar(textura,fonte)
	else:
		ordem_imagens.erase(id)
		ordem_imagens.append(id)
	return imagens[id]

static func obter(fontes: Array, tamanho: Vector2i) -> Texture2D:
	if tamanho.x<=0 or tamanho.y<=0: return null
	var partes: Array = [tamanho]
	var validas: Array=[]
	for f in fontes:
		if not valida(f.get("textura")) or Rect2i(f.regiao).size.x<=0 or Rect2i(f.regiao).size.y<=0: continue
		validas.append(f)
		partes.append([f.textura.get_instance_id(),f.regiao,Vector2i(f.posicao.round())])
	if validas.is_empty(): return null
	var chave := str(partes)
	if quadros.has(chave): return quadros[chave]
	var resultado := Image.create_empty(tamanho.x,tamanho.y,false,Image.FORMAT_RGBA8)
	for f in validas:
		var fonte:=imagem(f.textura)
		if fonte==null: return null
		if fonte.is_compressed(): fonte=fonte.duplicate();fonte.decompress()
		if fonte.get_format()!=Image.FORMAT_RGBA8: fonte=fonte.duplicate();fonte.convert(Image.FORMAT_RGBA8)
		resultado.blend_rect(fonte,Rect2i(f.regiao),Vector2i(f.posicao.round()))
	if resultado.get_used_rect().size==Vector2i.ZERO: return null
	var textura := ImageTexture.create_from_image(resultado)
	if ordem.size()>=1024: quadros.erase(ordem.pop_front())
	ordem.append(chave)
	quadros[chave] = textura
	compostos += 1
	return textura

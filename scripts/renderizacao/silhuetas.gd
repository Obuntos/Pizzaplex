class_name SilhuetasPlex
extends RefCounted

static var imagens: Dictionary = {}
static var ordem_imagens: Array[int] = []
static var quadros: Dictionary = {}
static var ordem: Array[String] = []
static var compostos := 0

static func imagem(textura: Texture2D) -> Image:
	if textura is CanvasTexture: textura = textura.diffuse_texture
	var id := textura.get_instance_id()
	if not imagens.has(id):
		if ordem_imagens.size()>=96: imagens.erase(ordem_imagens.pop_front())
		ordem_imagens.append(id)
		imagens[id]=textura.get_image()
	return imagens[id]

static func obter(fontes: Array, tamanho: Vector2i) -> Texture2D:
	var partes: Array = [tamanho]
	for f in fontes: partes.append([f.textura.get_instance_id(),f.regiao,Vector2i(f.posicao.round())])
	var chave := str(partes)
	if quadros.has(chave): return quadros[chave]
	var resultado := Image.create_empty(tamanho.x,tamanho.y,false,Image.FORMAT_RGBA8)
	for f in fontes: resultado.blend_rect(imagem(f.textura),Rect2i(f.regiao),Vector2i(f.posicao.round()))
	var textura := ImageTexture.create_from_image(resultado)
	if ordem.size()>=1024: quadros.erase(ordem.pop_front())
	ordem.append(chave)
	quadros[chave] = textura
	compostos += 1
	return textura

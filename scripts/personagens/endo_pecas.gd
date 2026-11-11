class_name EndoPecasPlex
extends RefCounted

const ESTILOS = {"base":"Clássico", "dragao":"Reforçado", "ave":"Aviano", "barril":"Barril"}
const PARTES = {"cabeca":"Cabeça", "corpo":"Tronco", "bracos":"Braços", "pernas":"Pernas"}
static var cache: Dictionary = {}

static func valida(configuracao: Dictionary) -> bool:
	return PARTES.keys().all(func(p): return ESTILOS.has(configuracao.get(p,"")))

static func chave(configuracao: Dictionary, instaladas: Array, direcao: int) -> String:
	return str(configuracao.get("modelo_estrutura",""))+str(PARTES.keys().map(func(p): return configuracao.get(p,"base") if instaladas.has(p) else "-"))+":"+str(posmod(direcao,8))

static func textura(configuracao: Dictionary, instaladas: Array, direcao: int) -> CanvasTexture:
	var id := chave(configuracao,instaladas,direcao)
	if cache.has(id): return cache[id]
	if configuracao.has("modelo_estrutura"):
		return familia(configuracao.modelo_estrutura,instaladas,direcao,id)
	var cor := Image.create_empty(64,100,false,Image.FORMAT_RGBA8)
	var normal := Image.create_empty(64,100,false,Image.FORMAT_RGBA8)
	var material := Image.create_empty(64,100,false,Image.FORMAT_RGBA8)
	for camada in ["pernas","bracos_tras","corpo","bracos_frente","cabeca"]:
		var parte: String = "bracos" if camada.begins_with("bracos") else camada
		if not instaladas.has(parte): continue
		var caminho: String = "res://assets/endos/componentes/"+str(configuracao.corpo)+"/"+camada+"_"+str(configuracao[parte])+".png"
		var regiao := Rect2i(0,posmod(direcao,8)*100,64,100)
		cor.blend_rect(CatalogoPlex.imagem(caminho),regiao,Vector2i.ZERO)
		var mapa: String = caminho.replace("res://assets/endos/","res://assets/iluminacao/endos/")
		normal.blend_rect(CatalogoPlex.imagem(mapa),regiao,Vector2i.ZERO)
		material.blend_rect(CatalogoPlex.imagem(mapa.replace(".png","_material.png")),regiao,Vector2i.ZERO)
	var resultado := CanvasTexture.new()
	resultado.diffuse_texture = ImageTexture.create_from_image(cor)
	resultado.normal_texture = ImageTexture.create_from_image(normal)
	resultado.specular_texture = ImageTexture.create_from_image(material)
	resultado.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cache[id] = resultado
	return resultado

static func familia(modelo: String, instaladas: Array, direcao: int, id: String) -> CanvasTexture:
	var d: Dictionary = CatalogoPlex.personagens[modelo]
	var mascara := 0
	for parte in PARTES:
		if instaladas.has(parte): mascara |= {"cabeca":1,"corpo":2,"bracos":4,"pernas":8}[parte]
	var caminho := "res://assets/endos/montagem/"+modelo+".png"
	var regiao := Rect2(mascara*int(d.width),posmod(direcao,8)*int(d.height),int(d.width),int(d.height))
	var resultado := CanvasTexture.new()
	for tipo in ["diffuse_texture","normal_texture","specular_texture"]:
		var arquivo := caminho
		if tipo!="diffuse_texture": arquivo = arquivo.replace("res://assets/endos/","res://assets/iluminacao/endos/")
		if tipo=="specular_texture": arquivo = arquivo.replace(".png","_material.png")
		var imagem := CatalogoPlex.imagem(arquivo).get_region(Rect2i(regiao))
		resultado.set(tipo,ImageTexture.create_from_image(imagem))
	resultado.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cache[id] = resultado
	return resultado

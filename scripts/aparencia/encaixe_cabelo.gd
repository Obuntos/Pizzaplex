class_name EncaixeCabeloPlex
extends RefCounted

static var dados: Dictionary = {}
static var centros: Dictionary = {}
static var ajustes: Dictionary = {}

static func carregar() -> void:
	if dados.is_empty(): dados=JSON.parse_string(FileAccess.get_file_as_string("res://dados/encaixe_cabelos.json"))

static func ajustado(modelo: String, estilo: String) -> bool:
	var chave := modelo+":"+estilo
	if not ajustes.has(chave):
		ajustes[chave] = ResourceLoader.exists("res://assets/aparencias/cabelos_ajustados/"+modelo+"/"+estilo+"/parado_frente.png")
	return bool(ajustes[chave])

static func centro(ator: PersonagemPlex, padrao: Array) -> Vector2:
	var atlas:=ator.animacao.atlases.cabeca as AtlasTexture
	if atlas==null or atlas.atlas==null: return Vector2(padrao[0],padrao[1])
	var fonte: Texture2D=atlas.atlas.diffuse_texture if atlas.atlas is CanvasTexture else atlas.atlas
	var chave:=str(fonte.get_instance_id())+":"+str(atlas.region)
	if not centros.has(chave):
		var imagem:=fonte.get_image()
		var regiao:=Rect2i(atlas.region).intersection(Rect2i(Vector2i.ZERO,imagem.get_size()))
		if not regiao.has_area(): return Vector2(padrao[0],padrao[1])
		var corpo:=imagem.get_region(regiao).get_used_rect()
		centros[chave]=Vector2(corpo.position)+Vector2(corpo.size)*.5 if corpo.has_area() else Vector2(padrao[0],padrao[1])
	return centros[chave]

static func aplicar(sprite: Sprite2D, ator: PersonagemPlex, estilo: String, andando: bool, quadro: int, direcao: int) -> void:
	carregar()
	var modelo: String=ator.modelo
	if not dados.modelos.has(modelo): return
	var alvo: Array=dados.modelos[modelo].parado[direcao][0]
	var cabeca: Sprite2D=ator.animacao.camadas.cabeca
	if ajustado(modelo,estilo):
		var referencia: Array=dados.modelos[modelo].andar[direcao][quadro] if andando else alvo
		sprite.scale=ator.animacao.scale
		sprite.position=(cabeca.position+centro(ator,alvo)-Vector2(float(referencia[0]),float(referencia[1])+8.0))*sprite.scale
		return
	var adulto: String="humana" if VariedadeAparenciaPlex.feminino(ator) else "humano"
	var sexo: String="feminino" if VariedadeAparenciaPlex.feminino(ator) else "masculino"
	var referencias: Dictionary=dados.fontes[sexo] if dados.novos.has(estilo) else dados.modelos[adulto]
	var origem: Array=referencias.parado[direcao][0]
	var fonte: Array=referencias.andar[direcao][quadro] if andando else origem
	var proporcao:=Vector2(float(alvo[2])/maxf(1,float(origem[2])),float(alvo[3])/maxf(1,float(origem[3])))
	proporcao=proporcao.clamp(Vector2(.7,.7),Vector2(1.15,1.15))
	sprite.scale=ator.animacao.scale*proporcao
	var ponto: Vector2=(cabeca.position+centro(ator,alvo))*ator.animacao.scale
	sprite.position=ponto-Vector2(float(fonte[0]),float(fonte[1])+8.0)*sprite.scale

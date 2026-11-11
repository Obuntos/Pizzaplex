class_name VassouraPosePlex
extends RefCounted

const TAMANHO=Vector2i(96,112)
const ORIGEM=Vector2i(-48,-96)
const LIMITE=96
static var cache: Dictionary={}
static var ordem: Array[String]=[]
static var fontes: Dictionary={}

static func usa(acao: String) -> bool:
	return acao in ["varrer","segurar_vassoura","levar_vassoura"]

static func fonte(rotacao: int, varrendo: bool) -> Dictionary:
	var chave:=str([rotacao,varrendo])
	if fontes.has(chave): return fontes[chave]
	var volume:=GeometriaPlex.obter("vassoura",rotacao)
	var limites:=Rect2(Vector2(volume.pontos[0].x,volume.pontos[0].y),Vector2.ZERO)
	var indice: Dictionary={}
	for i in volume.pontos.size():
		var p: Vector3=volume.pontos[i]
		limites=limites.expand(Vector2(p.x,p.y))
		indice[Vector2i(roundi(p.x),roundi(p.y))]=i
	var alvo:=Vector2(limites.get_center().x,limites.position.y+limites.size.y*(.58 if varrendo else .64))
	var melhor:=Vector3.ZERO
	var distancia:=INF
	for p in volume.pontos:
		var d:=Vector2(p.x,p.y).distance_squared_to(alvo)
		if d<distancia:
			distancia=d;melhor=Vector3(p.x,p.y,(p.z-2.0*p.y)/3.0)
	fontes[chave]={"volume":volume,"indice":indice,"apoio":melhor}
	return fontes[chave]

static func construir(a: PersonagemPlex) -> Dictionary:
	var pose: PosesHumanasPlex=a.poses_humanas
	var d:=GradePlex.direcao_visual(a.direcao)
	var rotacao:=posmod(roundi(float(d)/2.0),4)
	var dados:=fonte(rotacao,pose.acao=="varrer")
	var volume: Dictionary=dados.volume
	var apoio: Vector3=dados.apoio
	var destino: Vector3=a.postura_manual.punhos[1]
	var angulo:=0.0
	if pose.acao=="varrer":
		var p0: Vector3=a.postura_manual.punhos[0]
		var p1: Vector3=a.postura_manual.punhos[1]
		destino=p0 if p0.z<p1.z else p1
		var superior: Vector3=p1 if p0.z<p1.z else p0
		var eixo:=Vector2(superior.x-destino.x,superior.y-destino.y)
		if eixo.length()>.5: angulo=clampf(eixo.angle()+PI*.5,-.65,.65)
	else: angulo=sin(float(d)*PI/4.0)*.10
	var indice: Dictionary=dados.indice
	var imagem:=Image.create_empty(TAMANHO.x,TAMANHO.y,false,Image.FORMAT_RGBA8)
	var normais:=Image.create_empty(TAMANHO.x,TAMANHO.y,false,Image.FORMAT_RGBA8)
	var profundidades:=PackedFloat32Array();profundidades.resize(TAMANHO.x*TAMANHO.y);profundidades.fill(-10000.0)
	for y in TAMANHO.y:
		for x in TAMANHO.x:
			var local:=Vector2(x+ORIGEM.x,y+ORIGEM.y)
			var amostra_fonte: Vector2=(local-Vector2(destino.x,destino.y)).rotated(-angulo)+Vector2(apoio.x,apoio.y)
			var i: int=indice.get(Vector2i(amostra_fonte.round()),-1)
			if i<0: continue
			var q: Vector3=volume.pontos[i]
			var altura: float=maxf(0.0,destino.z-(local.y-destino.y)+(q.z+q.y)/3.0-(apoio.z+apoio.y))
			imagem.set_pixel(x,y,volume.cores[i])
			normais.set_pixel(x,y,volume.superficies[i])
			profundidades[y*TAMANHO.x+x]=2.0*local.y+3.0*altura
	return {"textura":ImageTexture.create_from_image(imagem),"normais":ImageTexture.create_from_image(normais),"profundidade":ImageTexture.create_from_image(Image.create_from_data(TAMANHO.x,TAMANHO.y,false,Image.FORMAT_RF,profundidades.to_byte_array()))}

static func aplicar(a: PersonagemPlex) -> void:
	var pose: PosesHumanasPlex=a.poses_humanas
	var d:=GradePlex.direcao_visual(a.direcao)
	var chave:=str([a.modelo,pose.acao,d,pose.quadro,a.animacao.scale])
	if not cache.has(chave):
		if ordem.size()>=LIMITE: cache.erase(ordem.pop_front())
		cache[chave]=construir(a)
	else: ordem.erase(chave)
	ordem.append(chave)
	var imagem: Dictionary=cache[chave]
	a.manuseio.objeto.texture=imagem.textura
	a.manuseio.objeto.position=Vector2(ORIGEM)
	a.manuseio.objeto.scale=Vector2.ONE
	a.manuseio.uniforme.set_shader_parameter("profundidade_item",imagem.profundidade)
	a.manuseio.uniforme.set_shader_parameter("superficies_item",imagem.normais)
	a.manuseio.uniforme.set_shader_parameter("base",GradePlex.profundidade(a.local,a.altura))
	a.manuseio.carga_na_frente=d not in [3,4,5]
	pose.ordem_frente=-1 if d in [3,4,5] else 2
	pose.ordem_maos=-1 if d in [3,4,5] else 5


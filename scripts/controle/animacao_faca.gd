class_name AnimacaoFacaPlex
extends RefCounted

static var cache: Dictionary = {}

static func paleta(imagem: Image) -> Array[Color]:
	var contagem: Dictionary={}
	for y in imagem.get_height():
		for x in imagem.get_width():
			var cor:=imagem.get_pixel(x,y)
			if cor.a>.9 and cor.get_luminance()>.18: contagem[cor]=int(contagem.get(cor,0))+1
	var cores: Array=contagem.keys()
	cores.sort_custom(func(a,b): return contagem[a]>contagem[b])
	var base: Color=cores[0] if not cores.is_empty() else Color("cda14e")
	var sombra:=base
	for cor in cores:
		if cor.get_luminance()<sombra.get_luminance() and cor.get_luminance()>base.get_luminance()*.56: sombra=cor
	return [base,sombra]

static func ossos(d: int, fase: float, andando: bool, pivo: float, ataque: float) -> Array:
	var bracos: Array=[]
	var passo:=sin(fase*TAU) if andando else 0.0
	var gesto:=sin(clampf(ataque,0,1)*PI)
	for lado in [-1.0,1.0]:
		var livre: bool=lado<0
		var y: float=passo*2.7 if livre else 2.4+passo*.75+gesto*5.0
		var z: float=12.3+absf(passo)*.35 if livre else 14.0+gesto*10.0
		var ombro:=PosturasManuaisPlex.osso(lado*5.7,0.0,25.0,d,pivo)
		var cotovelo:=PosturasManuaisPlex.osso(lado*6.5,y*.45,18.6+gesto*2.0*(0.0 if livre else 1.0),d,pivo)
		var pulso:=PosturasManuaisPlex.osso(lado*6.5,y,z,d,pivo)
		bracos.append([ombro,cotovelo,pulso])
	return bracos

static func desenhar(braco: Array, cores: Array[Color], pele: Array[Color], destino: Image, dedos: Image, fantasia: bool, distante: bool) -> void:
	for trecho in 2:
		var a:=Vector2(braco[trecho].x,braco[trecho].y)
		var b:=Vector2(braco[trecho+1].x,braco[trecho+1].y)
		var eixo:=b-a
		var limites:=Rect2(a,Vector2.ZERO).expand(b).grow(2)
		for y in range(maxi(0,floori(limites.position.y)),mini(destino.get_height(),ceili(limites.end.y))):
			for x in range(maxi(0,floori(limites.position.x)),mini(destino.get_width(),ceili(limites.end.x))):
				var p:=Vector2(x+.5,y+.5)
				var t:=clampf((p-a).dot(eixo)/maxf(.001,eixo.length_squared()),0,1)
				var centro:=a+eixo*t
				if p.distance_squared_to(centro)>2.15: continue
				var cor: Color=cores[1] if distante or p.x<centro.x-.5 else cores[0]
				destino.set_pixel(x,y,cor)
	var pulso:=Vector2(braco[2].x,braco[2].y)
	for y in range(floori(pulso.y)-1,floori(pulso.y)+2):
		for x in range(floori(pulso.x)-1,floori(pulso.x)+2):
			if not Rect2i(Vector2i.ZERO,destino.get_size()).has_point(Vector2i(x,y)): continue
			var cor: Color=(cores[1] if distante else cores[0]) if fantasia else (pele[1] if distante or x<pulso.x-.5 else pele[0])
			destino.set_pixel(x,y,cor)
			dedos.set_pixel(x,y,cor)

static func aplicar(pose: PosturasManuaisPlex, a: PersonagemPlex, andando: bool) -> void:
	var fantasia:=a.modelo.begins_with("fantasia_")
	var d:=GradePlex.direcao_visual(a.direcao)
	var quadro:=posmod(floori(a.fase*12),12) if andando else 0
	var fase:=float(quadro)/12.0
	var pivo:=float(a.animacao.definicao.pivot[1])
	var ataque:=a.progresso_acao if a.trabalho=="montar" else 0.0
	var etapa:=roundi(clampf(ataque,0,1)*8)
	var bracos:=ossos(d,fase,andando,pivo,float(etapa)/8.0)
	pose.punhos.clear()
	for braco in bracos:
		var p: Vector3=braco[2]
		pose.punhos.append(Vector3((p.x-24)*a.animacao.scale.x,(p.y-pivo)*a.animacao.scale.y,p.z*a.animacao.scale.y))
	pose.ponto_carga=(pose.punhos[0]+pose.punhos[1])*.5
	pose.arma_atras=d in [2,3,4,5]
	pose.angulo_faca=.10+sin(float(d)*PI/4.0)*.12+(sin(fase*TAU)*.07 if andando else 0.0)
	var acao:="andar" if andando else "parado"
	var arquivo:="res://assets/personagens/"+a.modelo+"/"+acao+(".png" if fantasia else "_corpo.png")
	if not fantasia: arquivo=AparenciaPlex.vestir(a,arquivo)
	var nome:="modelo" if fantasia else "corpo"
	var regiao: Rect2=a.animacao.atlases[nome].region
	var escada:=str(a.animacao.arquivos.get(nome,"")) if a.em_degraus else ""
	var chave:=str([arquivo,d,quadro,etapa,escada,regiao if a.em_degraus else Rect2()])
	if not cache.has(chave):
		var h:=80 if fantasia else 60
		var area:=Rect2i(quadro*48,d*h,48,h)
		var original:=CatalogoPlex.imagem(arquivo).get_region(area)
		var corpo:=original.duplicate() as Image
		if not fantasia:
			var torso:=AparenciaPlex.vestir(a,"res://assets/personagens/"+a.modelo+"/servico/segurar_prato_corpo.png")
			corpo.blit_rect(CatalogoPlex.imagem(torso),Rect2i(0,d*60,48,40),Vector2i.ZERO)
		if not escada.is_empty():
			var pernas:=CatalogoPlex.imagem(escada).get_region(Rect2i(regiao))
			corpo.blit_rect(pernas,Rect2i(0,64 if fantasia else 40,48,16 if fantasia else 20),Vector2i(0,64 if fantasia else 40))
		var largura:=5.0-absf(sin(float(d)*PI/4.0))*1.7
		for y in range(48 if fantasia else 27,65 if fantasia else 44):
			for x in 48:
				if absf(float(x)-23.5)>largura: corpo.set_pixel(x,y,Color.TRANSPARENT)
		var longe:=Image.create_empty(48,h,false,Image.FORMAT_RGBA8)
		var perto:=Image.create_empty(48,h,false,Image.FORMAT_RGBA8)
		var maos:=Image.create_empty(48,h,false,Image.FORMAT_RGBA8)
		var maos_longe:=Image.create_empty(48,h,false,Image.FORMAT_RGBA8)
		var fonte: Image
		if fantasia: fonte=CatalogoPlex.imagem("res://assets/personagens/"+a.modelo+"/parado.png").get_region(Rect2i(14,d*80+50,20,14))
		else: fonte=CatalogoPlex.imagem(AparenciaPlex.vestir(a,"res://assets/personagens/"+a.modelo+"/servico/segurar_prato_maos.png")).get_region(Rect2i(0,0,48,60))
		var cores:=paleta(fonte)
		var pele:=paleta(CatalogoPlex.imagem("res://assets/personagens/humano/servico/segurar_prato_maos.png").get_region(Rect2i(0,0,48,60)))
		for i in 2:
			var atras:=d in [3,4,5] or (d==2 and i==1) or (d==6 and i==0)
			desenhar(bracos[i],cores,pele,longe if atras else perto,maos_longe if atras else maos,fantasia,atras)
		if cache.size()>384: cache.clear()
		cache[chave]={"corpo":PosturasManuaisPlex.textura_corpo(corpo,arquivo,area),"tras":ImageTexture.create_from_image(longe),"frente":ImageTexture.create_from_image(perto),"maos":ImageTexture.create_from_image(maos)}
	var dados: Dictionary=cache[chave]
	var atlas: AtlasTexture=a.animacao.atlases[nome]
	atlas.atlas=dados.corpo
	atlas.region=Rect2(0,0,48,80 if fantasia else 60)
	for par in [[pose.tras,"tras"],[pose.frente,"frente"],[pose.dedos,"maos"]]:
		par[0].texture=dados[par[1]]
		par[0].scale=a.animacao.scale
		par[0].position=-Vector2(24,pivo)*a.animacao.scale
	pose.quadro_atual=quadro

class_name PosturasManuaisPlex
extends Node2D

static var cache: Dictionary = {}
var ativo := false
var modo_atual := ""
var tras := Sprite2D.new()
var frente := Sprite2D.new()
var dedos := Sprite2D.new()
var punhos: Array[Vector3] = []
var ponto_carga := Vector3.ZERO
var quadro_atual := -1
var arma_atras := false
var angulo_faca := 0.0

func _init() -> void:
	use_parent_material=true
	for s in [tras,frente,dedos]:
		s.centered=false
		s.use_parent_material=true
		s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(s)
	hide()

static func projetar(p: Vector3, direcao: int, pivo: float) -> Vector3:
	var a:=float(direcao)*PI/4.0
	var x:=cos(a)*p.x+sin(a)*p.y
	var y:=(-sin(a)*p.x+cos(a)*p.y)*.5-p.z
	return Vector3(24+x,pivo+y,p.z)

static func osso(x: float, y: float, z: float, d: int, pivo: float) -> Vector3:
	return projetar(Vector3(x,y,z),d,pivo)

static func esqueleto(modo: String, d: int, fase: float, andando: bool, ataque: float, pivo: float) -> Array:
	var bracos: Array=[]
	var onda:=sin(fase*TAU) if andando else 0.0
	for lado in [-1.0,1.0]:
		var ombro:=osso(lado*6.1,0,25,d,pivo)
		var cotovelo: Vector3
		var pulso: Vector3
		if modo=="corpo":
			cotovelo=osso(lado*7.4,3.5,17.0+onda*.24,d,pivo)
			pulso=osso(lado*5.7,8.0,18.5+onda*.24,d,pivo)
		elif lado>0:
			var levantar:=sin(clampf(ataque,0,1)*PI)
			cotovelo=osso(7.4,1.7+levantar*4.0,18.4+levantar*3.0,d,pivo)
			pulso=osso(6.7,4.5+levantar*6.5,15.1+levantar*12.0+onda*.25,d,pivo)
		else:
			cotovelo=osso(-7.0,onda*1.3,18.0,d,pivo)
			pulso=osso(-6.8,onda*2.4,11.8,d,pivo)
		bracos.append([ombro,cotovelo,pulso])
	return bracos

static func distancia(p: Vector2, a: Vector2, b: Vector2) -> float:
	var vetor:=b-a
	var t:=clampf((p-a).dot(vetor)/maxf(.001,vetor.length_squared()),0,1)
	return p.distance_squared_to(a+vetor*t)

static func deformar(fonte: Image, origem: Array, destino: Array, desenho: Image, palma: Image) -> void:
	for trecho in 2:
		var a:=Vector2(destino[trecho].x,destino[trecho].y)
		var b:=Vector2(destino[trecho+1].x,destino[trecho+1].y)
		var c:=Vector2(origem[trecho][0],origem[trecho][1])
		var e:=Vector2(origem[trecho+1][0],origem[trecho+1][1])
		var eixo: Vector2=b-a
		var normal: Vector2=Vector2(-eixo.y,eixo.x).normalized()
		var eixo_fonte:=e-c
		var normal_fonte:=Vector2(-eixo_fonte.y,eixo_fonte.x).normalized()
		var limites:=Rect2(a,Vector2.ZERO).expand(b).grow(3.0)
		for y in range(maxi(0,floori(limites.position.y)),mini(desenho.get_height(),ceili(limites.end.y))):
			for x in range(maxi(0,floori(limites.position.x)),mini(desenho.get_width(),ceili(limites.end.x))):
				var p:=Vector2(x+.5,y+.5)
				var t: float=(p-a).dot(eixo)/maxf(.001,eixo.length_squared())
				if t<-.18 or t>1.18 or distancia(p,a,b)>8.4: continue
				var q:=Vector2i((c+eixo_fonte*t+normal_fonte*(p-a).dot(normal)).floor())
				if not Rect2i(Vector2i.ZERO,fonte.get_size()).has_point(q): continue
				var cor:=fonte.get_pixelv(q)
				if cor.a<.1: continue
				desenho.set_pixel(x,y,cor)
				if trecho==1 and p.distance_squared_to(b)<5.6: palma.set_pixel(x,y,cor)

static func paleta(im: Image) -> Array[Color]:
	var contagem: Dictionary={}
	for y in range(50,60):
		for x in range(17,31):
			var c:=im.get_pixel(x,y)
			if c.a>.9: contagem[c]=int(contagem.get(c,0))+1
	var cores: Array=contagem.keys()
	cores.sort_custom(func(a,b): return contagem[a]>contagem[b])
	var principal: Color=cores[0] if not cores.is_empty() else Color("cda14e")
	var sombra:=principal
	var luz:=principal
	for c in cores:
		var brilho: float=c.r+c.g+c.b
		if brilho<(sombra.r+sombra.g+sombra.b) and brilho>(principal.r+principal.g+principal.b)*.65: sombra=c
		if brilho>(luz.r+luz.g+luz.b): luz=c
	return [principal,sombra,luz]

static func manga_fantasia(destino: Array, cores: Array, desenho: Image, palma: Image) -> void:
	for trecho in 2:
		var a:=Vector2(destino[trecho].x,destino[trecho].y)
		var b:=Vector2(destino[trecho+1].x,destino[trecho+1].y)
		var limites:=Rect2(a,Vector2.ZERO).expand(b).grow(3)
		for y in range(maxi(0,floori(limites.position.y)),mini(desenho.get_height(),ceili(limites.end.y))):
			for x in range(maxi(0,floori(limites.position.x)),mini(desenho.get_width(),ceili(limites.end.x))):
				var p:=Vector2(x+.5,y+.5)
				var d:=distancia(p,a,b)
				if d>3.4: continue
				var c: Color=cores[1] if d>1.8 or p.x<a.x-.5 else cores[0]
				if trecho==1 and p.distance_squared_to(b)<3.8:
					c=cores[2]
					palma.set_pixel(x,y,c)
				desenho.set_pixel(x,y,c)

static func textura_corpo(imagem: Image, arquivo: String, regiao: Rect2i) -> Texture2D:
	var fonte:=CatalogoPlex.textura_iluminada(arquivo) as CanvasTexture
	var textura:=CanvasTexture.new()
	textura.diffuse_texture=ImageTexture.create_from_image(imagem)
	if fonte!=null:
		for par in [[fonte.normal_texture,"normal_texture"],[fonte.specular_texture,"specular_texture"]]:
			var mapa: Texture2D=par[0]
			if mapa!=null and Rect2i(Vector2i.ZERO,Vector2i(mapa.get_size())).encloses(regiao):
				var imagem_mapa:=SilhuetasPlex.imagem(mapa)
				if imagem_mapa!=null: textura.set(par[1],ImageTexture.create_from_image(imagem_mapa.get_region(regiao)))
	textura.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	return textura

func atualizar(a: PersonagemPlex, andando: bool) -> void:
	if a.modelo=="fantasia_coelho":
		hide();tras.hide();frente.hide();dedos.hide();ativo=false
		modo_atual="corpo" if int(a.visita.get("corpo_carregado",-1))>0 else "faca" if a.visita.get("controle_manual",false) and a.visita.get("faca_equipada",false) else ""
		punhos.clear()
		var movimento_nativo:=UsoFantasiaUrsoPlex.acao(a,andando)
		for i in 2: punhos.append(UsoFantasiaUrsoPlex.ponto(a,movimento_nativo,i))
		ponto_carga=(punhos[0]+punhos[1])*.5
		if modo_atual=="corpo" and a.animacao.atlases.has("modelo"):
			var arquivo_nativo:=str(a.animacao.arquivos.get("modelo",""))
			var mascara:=arquivo_nativo.replace(".png","_dedos.png")
			if FileAccess.file_exists(mascara):
				var regiao_nativa:=Rect2i(a.animacao.atlases.modelo.region)
				var chave_dedos:="dedos:"+str([arquivo_nativo,regiao_nativa])
				if not cache.has(chave_dedos):
					if cache.size()>=512: cache.clear()
					cache[chave_dedos]=textura_corpo(CatalogoPlex.imagem(mascara).get_region(regiao_nativa),arquivo_nativo,regiao_nativa)
				dedos.texture=cache[chave_dedos]
				dedos.scale=a.animacao.scale
				dedos.position=-Vector2(a.animacao.definicao.pivot[0],a.animacao.definicao.pivot[1])*a.animacao.scale
				show();dedos.show()
		return
	if a.poses_humanas.ativa:
		hide()
		return
	var modo:="corpo" if int(a.visita.get("corpo_carregado",-1))>0 else "faca" if a.visita.get("controle_manual",false) and a.visita.get("faca_equipada",false) else ""
	var estava:=ativo
	ativo=not modo.is_empty() and not a.visita.get("morto",false)
	modo_atual=modo if ativo else ""
	visible=ativo
	if not ativo:
		if estava:
			var camada_original:="corpo" if a.animacao.definicao.layered else "modelo"
			var original:=str(a.animacao.arquivos.get(camada_original,""))
			if original.begins_with("res://"): a.animacao.atlases[camada_original].atlas=CatalogoPlex.textura_iluminada(original)
		return
	var fantasia:=a.modelo.begins_with("fantasia_")
	if not fantasia and a.modelo not in ["humano","humana"]: hide(); ativo=false; return
	if modo=="faca":
		AnimacaoFacaPlex.aplicar(self,a,andando)
		return
	var d:=GradePlex.direcao_visual(a.direcao)
	var quadro:=posmod(floori(a.fase*12.0),12) if andando else 0
	var fase:=float(quadro)/12.0
	var ataque:=a.progresso_acao if a.trabalho=="montar" and modo=="faca" else 0.0
	var etapa_ataque:=roundi(ataque*8.0)
	var pivo:=float(a.animacao.definicao.pivot[1])
	var ossos:=esqueleto(modo,d,fase,andando,float(etapa_ataque)/8.0,pivo)
	punhos.clear()
	for braco in ossos:
		var p: Vector3=braco[2]
		punhos.append(Vector3((p.x-24)*a.animacao.scale.x,(p.y-pivo)*a.animacao.scale.y,p.z*a.animacao.scale.y))
	ponto_carga=(punhos[0]+punhos[1])*.5
	var movimento:="levar_prato" if andando else "segurar_prato"
	var arquivo:="res://assets/personagens/"+a.modelo+"/"+("andar" if andando else "parado")+".png" if fantasia else AparenciaPlex.vestir(a,"res://assets/personagens/"+a.modelo+"/servico/"+movimento+"_corpo.png")
	var nome:="modelo" if fantasia else "corpo"
	var regiao: Rect2=a.animacao.atlases[nome].region
	var arquivo_escada:=str(a.animacao.arquivos.get(nome,"")) if a.em_degraus else ""
	var chave:=str([arquivo,d,quadro,modo,etapa_ataque,arquivo_escada,regiao if a.em_degraus else Rect2()])
	if not cache.has(chave):
		var h:=80 if fantasia else 60
		var corpo:=CatalogoPlex.imagem(arquivo).get_region(Rect2i(quadro*48,d*h,48,h))
		if not arquivo_escada.is_empty():
			var pernas:=CatalogoPlex.imagem(arquivo_escada).get_region(Rect2i(regiao))
			if fantasia: corpo=pernas
			else: corpo.blit_rect(pernas,Rect2i(0,40,48,20),Vector2i(0,40))
		var longe:=Image.create_empty(48,h,false,Image.FORMAT_RGBA8)
		var perto:=Image.create_empty(48,h,false,Image.FORMAT_RGBA8)
		var maos:=Image.create_empty(48,h,false,Image.FORMAT_RGBA8)
		if fantasia:
			var cores:=paleta(CatalogoPlex.imagem("res://assets/personagens/"+a.modelo+"/parado.png").get_region(Rect2i(0,d*80,48,80)))
			var largura:=5.3-absf(sin(float(d)*PI/4.0))*2.3
			for y in range(50,64):
				for x in 48:
					if absf(float(x)-23.5)>largura and y<61: corpo.set_pixel(x,y,Color.TRANSPARENT)
					elif y>=60 and y<=64:
						var cor:=corpo.get_pixel(x,y)
						if cor.a>.5 and cor.r+cor.g+cor.b>2.2: corpo.set_pixel(x,y,cores[0])
			for i in 2:
				var atras:=d in [3,4,5] or (d==2 and i==1) or (d==6 and i==0)
				manga_fantasia(ossos[i],cores,longe if atras else perto,maos)
		else:
			var caminho:=AparenciaPlex.vestir(a,"res://assets/personagens/"+a.modelo+"/servico/segurar_prato_maos.png")
			var fonte:=CatalogoPlex.imagem(caminho).get_region(Rect2i(0,d*60,48,60))
			var direcao_fonte:=d
			if not fonte.get_used_rect().has_area():
				direcao_fonte=0
				fonte=CatalogoPlex.imagem(caminho).get_region(Rect2i(0,0,48,60))
			var segmentos: Array=ManuseioPlex.definicoes[a.modelo].segurar_prato.segmentos[direcao_fonte][0]
			for i in 2:
				var atras:=d in [3,4,5] or (d==2 and i==1) or (d==6 and i==0)
				deformar(fonte,segmentos[i],ossos[i],longe if atras else perto,maos)
		if cache.size()>512: cache.clear()
		cache[chave]={"corpo":textura_corpo(corpo,arquivo_escada if fantasia and not arquivo_escada.is_empty() else arquivo,Rect2i(regiao) if fantasia and not arquivo_escada.is_empty() else Rect2i(quadro*48,d*h,48,h)),"tras":ImageTexture.create_from_image(longe),"frente":ImageTexture.create_from_image(perto),"maos":ImageTexture.create_from_image(maos)}
	var dados: Dictionary=cache[chave]
	var atlas: AtlasTexture=a.animacao.atlases["modelo" if fantasia else "corpo"]
	atlas.atlas=dados.corpo
	atlas.region=Rect2(0,0,48,80 if fantasia else 60)
	for par in [[tras,"tras"],[frente,"frente"],[dedos,"maos"]]:
		par[0].texture=dados[par[1]]
		par[0].scale=a.animacao.scale
		par[0].position=-Vector2(24,pivo)*a.animacao.scale
	if not fantasia:
		var offset: Array=ManuseioPlex.definicoes[a.modelo][movimento].offsets[d][quadro]
		for camada in ["cabeca","olhos","boca"]: a.animacao.camadas[camada].position+=Vector2(offset[0],offset[1])
	quadro_atual=quadro


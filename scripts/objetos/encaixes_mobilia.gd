class_name EncaixesMobiliaPlex
extends RefCounted

static var interiores:Dictionary={}
static var versao:int=-1
static func interior(planta:PlantaPlex,c:Vector2i) -> bool:
	var atual:=hash([planta.get_instance_id(),planta.revisao,planta.ocupacao])
	if versao!=atual:interiores.clear();versao=atual
	if interiores.has(c):return interiores[c]
	var fila:Array[Vector2i]=[c];var vistos:Dictionary={c:true};var indice:=0;var fechado:=true
	while indice<fila.size():
		var p:Vector2i=fila[indice];indice+=1
		if not GradePlex.dentro(p) or not TerrenoPlex.contem(planta,p):fechado=false;continue
		for d in GradePlex.VIZINHOS:
			var q:Vector2i=p+d
			if vistos.has(q):continue
			if SubstituicaoParedesPlex.estrutural(planta.em(q)):continue
			vistos[q]=true;fila.append(q)
	for p in vistos:interiores[p]=fechado
	return fechado
static var faixas:Dictionary={}
static var espessuras:Dictionary={}
static func faixa(tipo:String,_r:int=0) -> Vector2:
	if faixas.has(tipo):return faixas[tipo]
	var resultado:=Vector2(0.0,float(CatalogoPlex.objetos.get(tipo,{}).get("altura",0.0)))
	if LuminariasPlex.eh(tipo):
		faixas[tipo]=Vector2(resultado.y*.6,resultado.y);espessuras[tipo]=.3
		return faixas[tipo]
	var dados_volume:Dictionary=GeometriaPlex.obter(tipo,0)
	var pontos:PackedVector3Array=dados_volume.get("pontos",PackedVector3Array())
	var menor:=INF;var maior:=-INF
	var u_min:=INF;var u_max:=-INF;var v_min:=INF;var v_max:=-INF
	for ponto in pontos:
		if ponto.z<-9000.0:continue
		var z:=(ponto.z-ponto.y*2.0)/3.0
		var soma:=(ponto.z+ponto.y)/48.0
		var dif:=ponto.x/32.0
		var u:=(soma+dif)*.5;var v:=(soma-dif)*.5
		menor=minf(menor,z);maior=maxf(maior,z)
		u_min=minf(u_min,u);u_max=maxf(u_max,u);v_min=minf(v_min,v);v_max=maxf(v_max,v)
	if menor<=maior:resultado=Vector2(menor,maior)
	faixas[tipo]=resultado
	espessuras[tipo]=minf(u_max-u_min,v_max-v_min) if u_min<=u_max else 0.0
	return resultado
static func plano(tipo:String) -> bool:
	faixa(tipo)
	return float(espessuras.get(tipo,0.0))<.2
static func topo(planta:PlantaPlex,c:Vector2i,ignorar:int=-1) -> float:
	var maior:=0.0
	var base:=planta.em(c)
	if not base.is_empty() and int(base.id)!=ignorar:maior=float(CatalogoPlex.objetos.get(str(base.tipo),{}).get("altura",0.0))
	for o in planta.sobre(c):
		if int(o.id)==ignorar or int(o.get("sobre",-1))<0:continue
		maior=maxf(maior,ApoiosPlex.posicao(planta,o).z+float(CatalogoPlex.objetos.get(str(o.tipo),{}).get("altura",0.0)))
	return maior
static func de_parede(o:Dictionary) -> bool:
	return bool(MobiliaPlex.dados(o).get("parede_requerida",false)) and not LuminariasPlex.eh(str(o.tipo))
static func parede_permitida(planta:PlantaPlex,tipo:String,c:Vector2i,r:int,ignorar:int=-1) -> bool:
	var altura:=faixa(tipo,r)
	for p in planta.celulas(tipo,c,r):
		if CatalogoPlex.base(str(planta.em(p).get("tipo","")))!="parede":return false
		var uso:Vector2i=p+GradePlex.frente(r)
		var base:=planta.em(uso)
		var banheiro:bool=tipo in ["amb_espelho_banheiro","amb_dispensador_papel"] and CatalogoPlex.base(str(base.get("tipo",""))) in ["pia","pia_banheiro","vaso_sanitario"]
		if not interior(planta,uso):return false
		if not planta.transitavel(uso) and not banheiro and (base.is_empty() or str(base.tipo) in SalasPlex.ESTRUTURA or SubstituicaoParedesPlex.estrutural(base) or (not plano(tipo) and topo(planta,uso,ignorar)>altura.x+1.0)):return false
		for outro in planta.sobre(p):
			if int(outro.id)==ignorar or str(outro.tipo)==tipo or not de_parede(outro) or posmod(int(outro.rotacao),4)!=posmod(r,4):continue
			var f:=faixa(str(outro.tipo),int(outro.rotacao))
			if minf(f.y,altura.y)-maxf(f.x,altura.x)>2.0:return false
	return true
static func corta_parede(planta:PlantaPlex,tipo:String,c:Vector2i,r:int) -> bool:
	var info:Dictionary=CatalogoPlex.objetos.get(tipo,{})
	if planta.sobreposto(tipo) or info.get("piso",false) or info.get("estrutura",false) or tipo in SalasPlex.ESTRUTURA:return false
	var altura:=float(info.get("altura",0.0))
	for celula in planta.celulas(tipo,c,r):
		for d in GradePlex.VIZINHOS:
			for o in planta.sobre(celula+d):
				if not de_parede(o) or plano(str(o.tipo)) or celula+d+GradePlex.frente(int(o.rotacao))!=celula:continue
				if faixa(str(o.tipo),int(o.rotacao)).x+1.0<altura:return true
	return false
static func area_camera(o:Dictionary) -> Array[Vector2i]:
	var resultado:Array[Vector2i]=[]
	for quadro in 13:
		var amostra:=o.duplicate();amostra.camera_quadro=quadro
		var lente:=CamerasVigilanciaPlex.lente(amostra)
		for x in [-.16,0.0,.16]:
			for y in [-.16,0.0,.16]:
				var c:=Vector2i((lente+Vector2(x,y)).round())
				if not resultado.has(c):resultado.append(c)
	return resultado
static func camera_livre(planta:PlantaPlex,o:Dictionary) -> bool:
	var tipo_camera:=str(o.get("tipo",planta.objetos.get(int(o.get("id",-1)),{}).get("tipo","sistema_camera_parede")))
	var baixo:=faixa(tipo_camera).x
	for c in area_camera(o):
		if not GradePlex.dentro(c):return false
		var base:=planta.em(c)
		if not base.is_empty() and (str(base.tipo) in SalasPlex.ESTRUTURA or SubstituicaoParedesPlex.estrutural(base) or topo(planta,c,int(o.get("id",-2)))>baixo+1.0):return false
		for outra in planta.objetos.values():
			if int(outra.get("id",-1))==int(o.get("id",-2)):continue
			if MobiliaPlex.dados(outra).get("camera",false) and area_camera(outra).has(c):return false
	return true
static func bloqueia_camera(planta:PlantaPlex,tipo:String,c:Vector2i,r:int) -> bool:
	var info:Dictionary=CatalogoPlex.objetos.get(tipo,{})
	if planta.sobreposto(tipo) or ApoiosPlex.superficie(tipo) or ApoiosPlex.decoracao_mesa(tipo):return false
	if info.get("piso",false):return false
	var ocupadas:=planta.celulas(tipo,c,r)
	var altura:=float(info.get("altura",0.0))
	for o in planta.objetos.values():
		if not MobiliaPlex.dados(o).get("camera",false):continue
		if altura<=faixa(str(o.tipo),int(o.rotacao)).x+1.0:continue
		if area_camera(o).any(func(p):return ocupadas.has(p)):return true
	return false
static func ancora_luz(planta:PlantaPlex,o:Dictionary) -> Vector2:
	var base:=planta.em(o.celula)
	if LuminariasPlex.tipo(str(o.tipo)) in ["luz_chao","luz_teto"] and base.get("tipo","")=="sistema_palco_picadeiro":
		return Vector2(base.celula)+Vector2(CatalogoPlex.dimensoes(base.tipo,base.rotacao)-Vector2i.ONE)*.5
	return Vector2(o.celula)
static func volume(base:Dictionary,tipo:String,r:int) -> Dictionary:
	if base.pontos.is_empty():return base
	var info:Dictionary=CatalogoPlex.objetos.get(tipo,{})
	if info.get("gerador",false):return gerador(base,tipo,r)
	var centralizar:bool=info.get("gerador",false) or tipo in ["sistema_palco_picadeiro","amb_maquina_premios"]
	var parede:bool=info.get("parede_requerida",false) and AmbientesAssetsPlex.eh(tipo)
	if not centralizar and not parede:return base
	var minimo:=Vector2(INF,INF);var maximo:=-minimo
	var frente:=Vector2(GradePlex.frente(r));var encosto:=INF
	for p in base.pontos:
		var h:float=(p.z-p.y*2.0)/3.0
		var local:=GradePlex.inverter_local(Vector2(p.x,p.y+h))
		minimo=minimo.min(local);maximo=maximo.max(local);encosto=minf(encosto,local.dot(frente))
	var centro:=(minimo+maximo)*.5 if centralizar else Vector2.ZERO
	var escala:=Vector2.ONE
	if info.get("gerador",false) or tipo=="amb_maquina_premios":
		var tamanho:=Vector2(CatalogoPlex.dimensoes(tipo,r))-Vector2(.08,.08)
		var atual:=maximo-minimo
		escala=Vector2(minf(1,tamanho.x/maxf(.01,atual.x)),minf(1,tamanho.y/maxf(.01,atual.y)))
	var deslocamento:=frente*maxf(0,.54-encosto) if parede else Vector2.ZERO
	var pixels:Dictionary={};var canto:=Vector2i(10000,10000);var fim:=-canto
	for i in base.pontos.size():
		var p:Vector3=base.pontos[i];var h:float=(p.z-p.y*2.0)/3.0
		var local:=(GradePlex.inverter_local(Vector2(p.x,p.y+h))-centro)*escala+deslocamento
		var tela:=GradePlex.projetar_local(local,h);var pixel:=Vector2i(tela.round());var z:=GradePlex.projetar_local(local).y*2.0+h+2.0*(pixel.y-tela.y)
		if pixels.has(pixel) and float(pixels[pixel].z)>z:continue
		pixels[pixel]={"z":z,"cor":base.cores[i],"normal":base.superficies[i]};canto=canto.min(pixel);fim=fim.max(pixel)
	var im:=Image.create_empty(fim.x-canto.x+1,fim.y-canto.y+1,false,Image.FORMAT_RGBA8)
	var pontos:=PackedVector3Array();var cores:=PackedColorArray();var normais:=PackedColorArray()
	for pixel in pixels:
		var dados:Dictionary=pixels[pixel];im.set_pixelv(pixel-canto,dados.cor);pontos.append(Vector3(pixel.x,pixel.y,dados.z));cores.append(dados.cor);normais.append(dados.normal)
	var resultado:=base.duplicate();resultado.origin=[canto.x,canto.y];resultado.pontos=pontos;resultado.cores=cores;resultado.superficies=normais;resultado.textura=ImageTexture.create_from_image(im)
	return resultado
static func gerador(base:Dictionary,tipo:String,r:int) -> Dictionary:
	var fonte:=CatalogoPlex.imagem(str(base.image));var tamanho:=Vector2(CatalogoPlex.dimensoes(tipo,r))
	var minimo:=Vector2i(10000,10000);var maximo:=-minimo
	for y in fonte.get_height():
		for x in fonte.get_width():
			var cor:=fonte.get_pixel(x,y)
			if cor.a<=0 or y>fonte.get_height()*.6 and cor.g>.65 and cor.r<.4 and cor.b<.4:continue
			minimo=minimo.min(Vector2i(x,y));maximo=maximo.max(Vector2i(x,y))
	var origem:=Vector2i(-roundi(float(minimo.x+maximo.x)*.5),roundi((tamanho.x+tamanho.y-.16)*8.0)-maximo.y)
	var limite:=(tamanho-Vector2(.08,.08))*.5;var altura:=float(CatalogoPlex.objetos[tipo].altura)
	var pontos:=PackedVector3Array();var cores:=PackedColorArray();var normais:=PackedColorArray()
	var im:=Image.create_empty(fonte.get_width(),fonte.get_height(),false,Image.FORMAT_RGBA8)
	var normal:Image=CatalogoPlex.imagem(str(base.normal)) if base.has("normal") else null
	var originais:Dictionary={}
	var antiga:=Vector2i(int(base.origin[0]),int(base.origin[1]))
	for ponto in base.get("pontos",PackedVector3Array()):originais[Vector2i(roundi(ponto.x),roundi(ponto.y))-antiga]=ponto.z
	var deslocamento:=float(origem.y-antiga.y)*2.0
	for y in fonte.get_height():
		for x in fonte.get_width():
			var cor:=fonte.get_pixel(x,y)
			if cor.a<=0:continue
			var pixel:=Vector2(x+origem.x,y+origem.y);var chao:=GradePlex.inverter_local(pixel)
			var h:=minf(altura,minf((limite.x-chao.x)*32.0,(limite.y-chao.y)*32.0))
			var entrada:=maxf(0,maxf((-limite.x-chao.x)*32.0,(-limite.y-chao.y)*32.0))
			if h<entrada-.9 or h<-.9 or h<5 and cor.g>.65 and cor.r<.4 and cor.b<.4:continue
			h=maxf(0,h);pontos.append(Vector3(pixel.x,pixel.y,float(originais[Vector2i(x,y)])+deslocamento if originais.has(Vector2i(x,y)) else pixel.y*2.0+h*3.0));cores.append(cor);normais.append(normal.get_pixel(x,y) if normal!=null and normal.get_size()==fonte.get_size() else Color(.8,.8,.5,.2));im.set_pixel(x,y,cor)
	var resultado:=base.duplicate();resultado.origin=[origem.x,origem.y];resultado.pontos=pontos;resultado.cores=cores;resultado.superficies=normais;resultado.textura=ImageTexture.create_from_image(im);return resultado

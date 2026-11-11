class_name AncorasFantasiaPlex
extends RefCounted

static func limites(volume: Dictionary) -> Rect2:
	var limites_pontos:=Rect2()
	for i in volume.pontos.size():
		var p: Vector3=volume.pontos[i]
		if i==0: limites_pontos=Rect2(Vector2(p.x,p.y),Vector2.ONE)
		else: limites_pontos=limites_pontos.expand(Vector2(p.x+1,p.y+1))
	return limites_pontos

static func compor(componentes: Array, ancora: Array, escala: Vector2, direcao: int, tipo_item: String="") -> Dictionary:
	if str(ancora[4])=="box": return caixa(ancora,escala,direcao,tipo_item)
	var fonte:=ItensPlex.compor(componentes)
	if componentes.is_empty(): return fonte
	var tipo:=str(ancora[4])
	var extras: Dictionary=ancora[5] if ancora.size()>5 else {}
	var raiz: Dictionary=componentes[0].volume
	var limites_raiz:=limites(raiz)
	var tamanho:=limites_raiz.size
	var alvo:=tamanho
	if tipo=="plate": alvo=Vector2(10.4,3.6)*escala
	elif tipo=="soda": alvo=Vector2(4.4,7.2)*escala
	elif tipo=="box":
		var medida: Dictionary=extras.get("size",{"r":18.0,"f":12.0,"z":11.0})
		var angulo:=float(direcao)*PI/4.0
		alvo=Vector2(absf(cos(angulo))*medida.r+absf(sin(angulo))*medida.f,(absf(sin(angulo))*medida.r+absf(cos(angulo))*medida.f)*.5+medida.z)*escala
	var fator:=alvo/tamanho.max(Vector2.ONE)
	var centro:=limites_raiz.get_center()
	var minimo_z:=INF
	var maximo_z:=-INF
	for p in raiz.pontos:
		var z: float=(p.z-p.y*2.0)/3.0
		minimo_z=minf(minimo_z,z);maximo_z=maxf(maximo_z,z)
	var centro_z: float=(minimo_z+maximo_z)*.5
	var fator_z:=fator.y
	if tipo=="plate": fator_z=fator.x
	elif tipo=="box": fator_z=float(extras.get("size",{}).get("z",11.0))*escala.y/maxf(.01,maximo_z-minimo_z)
	var matriz:=Transform2D(Vector2(fator.x,0),Vector2(0,fator.y),-centro*fator)
	if tipo=="broom":
		var angulo:=float(direcao)*PI/4.0
		var ponto: Dictionary=extras.point
		var topo: Dictionary=extras.top
		var ponta: Dictionary=extras.tip
		var projetar:=func(v: Dictionary) -> Vector2: return Vector2(cos(angulo)*(float(v.r)-float(ponto.r))+sin(angulo)*(float(v.f)-float(ponto.f)),(-sin(angulo)*(float(v.r)-float(ponto.r))+cos(angulo)*(float(v.f)-float(ponto.f)))*.5-(float(v.z)-float(ponto.z)))*escala
		var a: Vector2=projetar.call(ponta)
		var b: Vector2=projetar.call(topo)
		var baixo:=Vector2.ZERO
		var alto:=Vector2.ZERO
		var n_baixo:=0
		var n_alto:=0
		for p in raiz.pontos:
			var z: float=(p.z-p.y*2.0)/3.0
			if z>=maximo_z-1: alto+=Vector2(p.x,p.y);n_alto+=1
			if z<=minimo_z+1: baixo+=Vector2(p.x,p.y);n_baixo+=1
		alto/=maxi(1,n_alto);baixo/=maxi(1,n_baixo)
		var eixo: Vector2=(alto-baixo).normalized()
		var transversal:=Vector2(-eixo.y,eixo.x)
		var destino: Vector2=(b-a)/maxf(1.0,alto.distance_to(baixo))
		var largura: Vector2=Vector2(-destino.y,destino.x).normalized()*9.2*escala.x/maxf(1.0,limites_raiz.size.x)
		matriz=Transform2D(destino*eixo.x+largura*transversal.x,destino*eixo.y+largura*transversal.y,Vector2.ZERO)
		matriz.origin=a-matriz*baixo
		centro_z=minimo_z-(float(ponta.z)-float(ponto.z))*maxf(.01,maximo_z-minimo_z)/(float(topo.z)-float(ponta.z))
		fator_z=(float(topo.z)-float(ponta.z))*escala.y/maxf(.01,maximo_z-minimo_z)
	var cores_raiz: Dictionary={}
	var cor_borda:=Color.WHITE
	if tipo=="plate":
		for i in raiz.pontos.size():
			var p: Vector3=raiz.pontos[i]
			var cor: Color=raiz.cores[i]
			cores_raiz[Vector2i(roundi(p.x)+96,roundi(p.y)+144)]=cor
			if cor.get_luminance()<cor_borda.get_luminance(): cor_borda=cor
	if tipo=="plate": cor_borda=cor_borda.darkened(.22)
	var inversa:=matriz.affine_inverse()
	var imagem: Image=fonte.textura.get_image()
	var normais: Image=fonte.normais.get_image()
	var profundidade: Image=fonte.profundidade.get_image()
	var resultado:=Image.create_empty(192,192,false,Image.FORMAT_RGBA8)
	var faces:=Image.create_empty(192,192,false,Image.FORMAT_RGBA8)
	var distancias:=Image.create_empty(192,192,false,Image.FORMAT_RF)
	distancias.fill(Color(-10000,0,0))
	var uso:=imagem.get_used_rect()
	var transformada:=Rect2()
	for p in [Vector2(uso.position),Vector2(uso.end.x,uso.position.y),Vector2(uso.end),Vector2(uso.position.x,uso.end.y)]:
		var v: Vector2=matriz*(p-Vector2(96,144))+Vector2(96,144)
		if transformada.size==Vector2.ZERO: transformada=Rect2(v,Vector2(.01,.01))
		else: transformada=transformada.expand(v)
	var area:=Rect2i(Vector2i(transformada.position.floor()),Vector2i(transformada.size.ceil()+Vector2.ONE)).intersection(Rect2i(0,0,192,192))
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			var local:=Vector2(x-96,y-144)
			var origem:=Vector2i(inversa*(local+Vector2(.5,.5))+Vector2(96,144))
			if origem.x<0 or origem.y<0 or origem.x>=192 or origem.y>=192: continue
			var cor:=imagem.get_pixelv(origem)
			if cor.a<=0.0: continue
			var z: float=((profundidade.get_pixelv(origem).r-2.0*(origem.y-144))/3.0-centro_z)*fator_z
			if tipo=="plate" and local.y>=0 and cores_raiz.has(origem) and cores_raiz[origem].is_equal_approx(cor):
				var abaixo:=Vector2i(inversa*(local+Vector2(.5,1.5))+Vector2(96,144))
				if not cores_raiz.has(abaixo): cor=Color(cor_borda,cor.a)
			resultado.set_pixel(x,y,cor)
			faces.set_pixel(x,y,normais.get_pixelv(origem))
			distancias.set_pixel(x,y,Color(local.y*2.0+z*3.0,0,0))
	return {"textura":ImageTexture.create_from_image(resultado),"normais":ImageTexture.create_from_image(faces),"profundidade":ImageTexture.create_from_image(distancias)}

static func caixa(ancora: Array, escala: Vector2, direcao: int, tipo_item: String="") -> Dictionary:
	var dimensoes: Dictionary=ancora[5].get("size",{"r":18.0,"f":12.0,"z":11.0})
	var largura:=float(dimensoes.r)
	var fundo:=float(dimensoes.f)
	var altura:=float(dimensoes.z)
	var marca:=Color("71847b") if tipo_item.contains("ingrediente") else Color("ad5555") if tipo_item.contains("pecas") or tipo_item.contains("fur") else Color("737d91") if tipo_item.contains("utensilio") else Color("a98a60")
	var angulo:=float(direcao)*PI/4.0
	var imagem:=Image.create_empty(192,192,false,Image.FORMAT_RGBA8)
	var normais:=Image.create_empty(192,192,false,Image.FORMAT_RGBA8)
	var mapa:=Image.create_empty(192,192,false,Image.FORMAT_RF)
	mapa.fill(Color(-10000,0,0))
	for face in 6:
		var horizontal: float=fundo if face in [2,4] else largura
		var vertical: float=fundo if face in [0,5] else altura
		var nu:=ceili(horizontal*escala.x*3.0)
		var nv:=ceili(vertical*escala.y*3.0)
		for i in range(nu+1):
			for j in range(nv+1):
				var u:=float(i)/nu;var v:=float(j)/nv
				var ponto:=Vector3((u-.5)*largura,(v-.5)*fundo,altura*.5)
				var normal:=Vector3(0,0,1)
				var cor:=Color("cfa369")
				if face==1: ponto=Vector3((u-.5)*largura,fundo*.5,(v-.5)*altura);normal=Vector3(0,1,0);cor=Color("936343")
				elif face in [2,4]: ponto=Vector3(largura*(.5 if face==2 else -.5),(u-.5)*fundo,(v-.5)*altura);normal=Vector3(1 if face==2 else -1,0,0);cor=Color("b37c4e")
				elif face==3: ponto=Vector3((u-.5)*largura,-fundo*.5,(v-.5)*altura);normal=Vector3(0,-1,0);cor=Color("936343")
				elif face==5: ponto.z=-altura*.5;normal=Vector3(0,0,-1);cor=Color("936343")
				if i==0 or i==nu or j==0 or j==nv: cor=Color("493c36")
				elif face==0 and absf(u-.5)<.085: cor=Color("eed094")
				elif face not in [0,5] and v<.2: cor=marca
				elif face!=0 and u>.64 and u<.88 and v>.35 and v<.62: cor=Color("d7cbb0")
				var x: float=(cos(angulo)*ponto.x+sin(angulo)*ponto.y)*escala.x
				var f: float=(-sin(angulo)*ponto.x+cos(angulo)*ponto.y)*escala.y
				var z: float=ponto.z*escala.y
				var pixel:=Vector2i(roundi(x)+96,roundi(f*.5-z)+144)
				var d: float=float(pixel.y-144)*2.0+z*3.0
				if not Rect2i(0,0,192,192).has_point(pixel) or d<mapa.get_pixelv(pixel).r: continue
				imagem.set_pixelv(pixel,cor);mapa.set_pixelv(pixel,Color(d,0,0))
				var n:=Vector3(cos(angulo)*normal.x+sin(angulo)*normal.y,-sin(angulo)*normal.x+cos(angulo)*normal.y,normal.z)
				normais.set_pixelv(pixel,Color(n.x*.5+.5,n.y*.5+.5,n.z*.5+.5,.2))
	return {"textura":ImageTexture.create_from_image(imagem),"normais":ImageTexture.create_from_image(normais),"profundidade":ImageTexture.create_from_image(mapa)}

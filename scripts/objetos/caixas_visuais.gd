class_name CaixasVisuaisPlex
extends RefCounted

static var cache: Dictionary={}

static func eh(tipo: String) -> bool:
	return tipo=="caixa" or tipo.begins_with("caixa_") or tipo.begins_with("embalagem_")

static func obter(tipo: String, rotacao: int, estado: String="") -> Dictionary:
	var chave:=str([tipo,rotacao,estado])
	if cache.has(chave): return cache[chave]
	var info: Dictionary=CatalogoPlex.objetos.get(tipo,{})
	var movel:=tipo.begins_with("embalagem_")
	var tamanho:=Vector2(float(info.get("largura",1)),float(info.get("profundidade",1))) if movel else Vector2(.48,.48)
	tamanho*=.78 if movel else 1.0
	var altura:=float(info.get("altura",20)) if movel else 11.0
	var pixels: Dictionary={}
	var ordem:=PackedVector3Array()
	var cores:=PackedColorArray()
	var normais:=PackedColorArray()
	var imagem:=Image.create_empty(192,192,false,Image.FORMAT_RGBA8)
	var marca:=Color("71847b") if tipo.contains("ingrediente") else Color("ad5555") if tipo.contains("pecas") or tipo.contains("fur") else Color("737d91") if tipo.contains("utensilio") else Color("a98a60")
	for face in 5:
		var nu:=maxi(1,roundi((tamanho.y if face in [2,4] else tamanho.x)*64))
		var nv:=maxi(1,roundi((tamanho.y if face==0 else altura/32.0)*64))
		for i in range(nu+1):
			for j in range(nv+1):
				var a:=float(i)/nu;var b:=float(j)/nv
				var local:=Vector3((a-.5)*tamanho.x,(b-.5)*tamanho.y,altura)
				var normal:=Vector3(0,0,1)
				var cor:=Color("cfa369")
				if face==1: local=Vector3((a-.5)*tamanho.x,tamanho.y*.5,b*altura);normal=Vector3(0,1,0);cor=Color("936343")
				elif face in [2,4]: local=Vector3(tamanho.x*(.5 if face==2 else -.5),(a-.5)*tamanho.y,b*altura);normal=Vector3(1 if face==2 else -1,0,0);cor=Color("b37c4e")
				elif face==3: local=Vector3((a-.5)*tamanho.x,-tamanho.y*.5,b*altura);normal=Vector3(0,-1,0);cor=Color("936343")
				var borda:=i==0 or i==nu or j==0 or j==nv
				if borda: cor=Color("493c36")
				elif face==0:
					if estado=="aberta":
						cor=Color("574437") if minf(minf(a,1.0-a),minf(b,1.0-b))>.12 else Color("c7a16e")
					elif absf(a-.5)<.085: cor=Color("eed094") if absf(a-.5)>.025 else Color("b58a53")
					elif absf(b-.5)<.016: cor=Color("9e7049")
				elif a>.66 and a<.86 and b>.30 and b<.51: cor=Color("d7cbb0")
				elif b<.21: cor=marca.darkened(.12 if face==1 else 0.0)
				var uv:=GradePlex.girar(Vector2(local.x,local.y),rotacao)
				var tela:=GradePlex.projetar_local(uv,local.z).round()
				var profundidade:=tela.y*2.0+local.z*3.0
				var n:=GradePlex.girar(Vector2(normal.x,normal.y),rotacao)
				var ponto:=Vector2i(tela)
				if not pixels.has(ponto) or profundidade>=pixels[ponto].z:
					pixels[ponto]={"z":profundidade,"cor":cor,"normal":Color(n.x*.5+.5,n.y*.5+.5,normal.z*.5+.5,.2)}
	for xy in pixels:
		if xy.x+96<0 or xy.x+96>=192 or xy.y+144<0 or xy.y+144>=192: continue
		var pixel: Dictionary=pixels[xy]
		ordem.append(Vector3(xy.x,xy.y,pixel.z));cores.append(pixel.cor);normais.append(pixel.normal)
		imagem.set_pixel(xy.x+96,xy.y+144,pixel.cor)
	var volume: Dictionary={"image":"caixa:"+chave,"origin":[-96,-144],"textura":ImageTexture.create_from_image(imagem),"pontos":ordem,"cores":cores,"superficies":normais}
	cache[chave]=volume
	return volume

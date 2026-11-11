class_name ParedesContinuasPlex
extends RefCounted

static var cache: Dictionary={}

static func obter(original: Dictionary, nivel: int, ligacoes: int) -> Dictionary:
	var chave:=str([original.image,nivel,ligacoes])
	if cache.has(chave): return cache[chave]
	var base:=molde(original,nivel,ligacoes).duplicate()
	var fonte:=Image.create_empty(192,192,false,Image.FORMAT_RGBA8)
	var topo:=Color("a7a393")
	var alto:=-INF
	for i in original.pontos.size():
		var p: Vector3=original.pontos[i]
		var c:=Vector2i(roundi(p.x)+96,roundi(p.y)+144)
		if Rect2i(0,0,192,192).has_point(c): fonte.set_pixelv(c,original.cores[i])
		var altura: float=(p.z-p.y*2.0)/3.0
		if altura>alto:
			alto=altura
			topo=original.cores[i]
	var imagem:=Image.create_empty(192,192,false,Image.FORMAT_RGBA8)
	var cores:=PackedColorArray()
	var altura_corte: float=[6,22,52,104][clampi(nivel-1,0,3)]
	for i in base.pontos.size():
		var p: Vector3=base.pontos[i]
		var c:=Vector2i(roundi(p.x)+96,roundi(p.y)+144)
		var amostra:=c
		if nivel<4:
			var altura: float=(p.z-p.y*2.0)/3.0
			amostra.y-=roundi(altura*(104.0/altura_corte-1.0))
		var cor:=fonte.get_pixelv(amostra) if Rect2i(Vector2i.ZERO,fonte.get_size()).has_point(amostra) else Color.TRANSPARENT
		if base.superficies[i].b>.8: cor=topo
		elif cor.a<.9:
			for distancia in range(1,24):
				var achou:=false
				for deslocamento in [Vector2i(0,distancia),Vector2i(0,-distancia),Vector2i(distancia,0),Vector2i(-distancia,0)]:
					var alvo: Vector2i=amostra+deslocamento
					if Rect2i(0,0,192,192).has_point(alvo) and fonte.get_pixelv(alvo).a>.9:
						cor=fonte.get_pixelv(alvo)
						achou=true
						break
				if achou: break
		if cor.a<.9: cor=topo
		cores.append(Color(cor,1.0))
		imagem.set_pixelv(c,Color(cor,1.0))
	base.cores=cores
	base.textura=ImageTexture.create_from_image(imagem)
	base.origin=[-96,-144]
	cache[chave]=base
	return base

static func molde(original: Dictionary, nivel: int, ligacoes: int) -> Dictionary:
	var chave: String="molde:"+str([original.image,nivel,ligacoes])
	if cache.has(chave): return cache[chave]
	var fonte:=original
	var corte: float=[6.0,22.0,52.0,104.0][clampi(nivel-1,0,3)]
	var pontos: Dictionary={}
	for i in fonte.pontos.size():
		var p: Vector3=fonte.pontos[i]
		var altura: float=(p.z-2.0*p.y)/3.0
		var h:=minf(altura,corte)
		var tela:=Vector2i(roundi(p.x),roundi(p.y+altura-h))
		var profundidade:=float(tela.y)*2.0+h*3.0
		var topo:=altura>corte-.1
		var normal: Color=Color(.5,.5,1,.5) if topo else fonte.superficies[i]
		var cor: Color=Color("818783") if topo else fonte.cores[i]
		if pontos.has(tela) and float(pontos[tela].p.z)>profundidade+.01: continue
		pontos[tela]={"p":Vector3(tela.x,tela.y,profundidade),"normal":normal,"cor":cor}
	var volume: Dictionary={"image":chave,"origin":[-96,-144],"pontos":PackedVector3Array(),"cores":PackedColorArray(),"superficies":PackedColorArray()}
	var imagem:=Image.create_empty(192,192,false,Image.FORMAT_RGBA8)
	for pixel in pontos:
		var v: Dictionary=pontos[pixel]
		volume.pontos.append(v.p);volume.cores.append(v.cor);volume.superficies.append(v.normal)
		imagem.set_pixelv(pixel+Vector2i(96,144),v.cor)
	volume.textura=ImageTexture.create_from_image(imagem)
	cache[chave]=volume
	return volume

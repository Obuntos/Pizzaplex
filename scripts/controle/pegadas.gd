class_name PegadasPlex
extends RefCounted

static var cache: Dictionary = {}

static func textura(direcao: int, seco: bool) -> Texture2D:
	var chave:=Vector3i(direcao,int(seco),GradePlex.visao)
	if cache.has(chave): return cache[chave]
	var im:=Image.create_empty(48,32,false,Image.FORMAT_RGBA8)
	var angulo:=float(GradePlex.direcao_visual(direcao))*PI/4.0
	var cor:=Color("54252a") if seco else Color("8d2933")
	for y in 32:
		for x in 48:
			var plano:=Vector2(float(x)-23.5,(float(y)-15.5)*2.0)
			var p:=Vector2(cos(angulo)*plano.x-sin(angulo)*plano.y,sin(angulo)*plano.x+cos(angulo)*plano.y)
			for lado in [-1,1]:
				var q:=p-Vector2(float(lado)*3.3,float(lado)*6.4)
				var sola:=q.x*q.x/3.8+(q.y-.7)*(q.y-.7)/7.3
				var calcanhar:=absf(q.x)<1.1 and q.y>=-4.0 and q.y<=-1.0
				if sola>1.0 and not calcanhar: continue
				var c:=cor.darkened(.22) if sola>.60 else cor
				if posmod(x*17+y*13,11)==0: c=c.lightened(.10)
				im.set_pixel(x,y,c)
	var tex:=ImageTexture.create_from_image(im)
	cache[chave]=tex
	return tex

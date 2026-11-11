class_name AcabamentoEsquadriasPlex
extends RefCounted

static var cache: Dictionary = {}
const CORES = [Color("a09d8f"),Color("c8c3ae"),Color("818783"),Color("626d6c"),Color("4b5759")]

static func eh(item: Dictionary) -> bool:
	return item.get("tipo","") in CatalogoPlex.PORTAS or str(item.get("tipo","")).begins_with("janela")

static func paredes(planta: PlantaPlex, item: Dictionary) -> Array:
	if not eh(item): return []
	var frente:=GradePlex.frente(item.rotacao)
	var lado:=Vector2i(frente.y,-frente.x)
	var dimensao:=CatalogoPlex.dimensoes(item.tipo,item.rotacao)
	var centro:=Vector2(item.celula)+Vector2(dimensao-Vector2i.ONE)*.5
	var resultado: Array=[]
	for sinal in [-1,1]:
		for distancia in range(1,10):
			var c:=Vector2i((centro+Vector2(lado)*float(sinal)*(float(maxi(dimensao.x,dimensao.y))*.5+float(distancia)-.5)).round())
			var outro:=planta.em(c)
			if outro.is_empty(): break
			if CatalogoPlex.base(outro.tipo)=="parede" and not eh(outro): resultado.append(outro); break
			if not eh(outro): break
	return resultado

static func chave(planta: PlantaPlex, item: Dictionary) -> Array:
	return paredes(planta,item).map(func(p): return [p.tipo,MobiliaPlex.visual(p),MobiliaPlex.estado(p),p.rotacao])

static func aplicar(base: Dictionary, planta: PlantaPlex, item: Dictionary, nivel: int) -> Dictionary:
	var vizinhas:=paredes(planta,item)
	if vizinhas.is_empty(): return base
	var chave_cache:=str([base.image,item.tipo,item.rotacao,nivel,GradePlex.visao,chave(planta,item)])
	if cache.has(chave_cache): return cache[chave_cache]
	var fontes: Array=[]
	for parede in vizinhas:
		var v:=GeometriaPlex.obter(MobiliaPlex.visual(parede),GradePlex.rotacao_visual(parede.rotacao),4,0,false,MobiliaPlex.estado(parede))
		var im:=Image.create_empty(192,192,false,Image.FORMAT_RGBA8)
		for i in v.pontos.size():
			var p: Vector3=v.pontos[i]
			var q:=Vector2i(roundi(p.x)+96,roundi(p.y)+144)
			if Rect2i(0,0,192,192).has_point(q): im.set_pixelv(q,v.cores[i])
		fontes.append(im)
	var resultado:=base.duplicate()
	var cores: PackedColorArray=base.cores.duplicate()
	var previa:=Image.create_empty(base.textura.get_width(),base.textura.get_height(),false,Image.FORMAT_RGBA8)
	for i in base.pontos.size():
		var ponto: Vector3=base.pontos[i]
		var z: float=(ponto.z-ponto.y*2.0)/3.0
		var cor: Color=cores[i]
		var topo: bool=z>103.2 or (nivel<4 and absf(z-float([6,22,52][nivel-1]))<.8)
		var pintura: bool=CORES.slice(0,2 if z>8.5 else 5).any(func(c): return Vector3(c.r,c.g,c.b).distance_to(Vector3(cor.r,cor.g,cor.b))<.018)
		if topo or pintura:
			var fonte: Image=fontes[0 if ponto.x<0 or fontes.size()==1 else 1]
			var x:=clampi(roundi(ponto.x),-28,28)
			if abs(x)<3: x=-3 if ponto.x<0 else 3
			var y:=roundi(16.0-absf(float(x))*.5-z)
			var amostra:=fonte.get_pixel(clampi(x+96,0,191),clampi(y+144,0,191))
			if topo: amostra=fonte.get_pixel(96,34)
			if amostra.a>.5: cores[i]=Color(amostra.r,amostra.g,amostra.b,cor.a)
		var pixel:=Vector2i(roundi(ponto.x)-int(base.origin[0]),roundi(ponto.y)-int(base.origin[1]))
		if Rect2i(Vector2i.ZERO,previa.get_size()).has_point(pixel): previa.set_pixelv(pixel,cores[i])
	resultado.cores=cores
	resultado.textura=ImageTexture.create_from_image(previa)
	if cache.size()>512: cache.clear()
	cache[chave_cache]=resultado
	return resultado

static func cor_topo(planta: PlantaPlex, item: Dictionary) -> Color:
	var adjacentes:=paredes(planta,item)
	if adjacentes.is_empty(): return Color("818783")
	var parede: Dictionary=adjacentes[0]
	var v:=GeometriaPlex.obter(MobiliaPlex.visual(parede),GradePlex.rotacao_visual(parede.rotacao),4,0,false,MobiliaPlex.estado(parede))
	for i in v.pontos.size():
		var p: Vector3=v.pontos[i]
		if absf(p.x)<1 and absf(p.y+110)<1: return v.cores[i]
	return Color("818783")

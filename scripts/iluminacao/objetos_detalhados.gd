class_name SombrasObjetosPlex
extends RefCounted

static var armarios: Dictionary={}

static func caixa(gerente: SombrasEstruturasPlex, item: Dictionary, centro: Vector2, u: float, v: float, w: float, d: float, z: float, h: float, elipse: bool=false) -> void:
	var local:=centro+GradePlex.girar(Vector2(u,v),int(item.rotacao))
	var tamanho:=Vector2(w,d) if int(item.rotacao)%2==0 else Vector2(d,w)
	gerente.caixa(Rect2(local-tamanho*.5,tamanho),z,z+h,elipse)

static func cidade(gerente: SombrasEstruturasPlex, item: Dictionary, area: Rect2) -> bool:
	var tipo:=str(item.tipo)
	var c:=area.get_center()
	if tipo.contains("barraca"):
		caixa(gerente,item,c,0,0,.94,.90,51,9)
		caixa(gerente,item,c,0,.12,.80,.53,22,8)
		for lado in [-1,1]: caixa(gerente,item,c,lado*.35,-.30,.06,.06,0,53)
		return true
	if tipo.contains("bicicleta") or tipo.contains("bicicletario"):
		for lado in [-1,1]: caixa(gerente,item,c,lado*.29,0,.30,.07,0,15,true)
		caixa(gerente,item,c,0,0,.55,.055,9,6)
		caixa(gerente,item,c,.22,0,.05,.14,15,11)
		return true
	if tipo.contains("canteiro") or tipo.contains("jardineira") or tipo.contains("floreira"):
		caixa(gerente,item,c,0,0,.88,.36,0,8)
		for lado in [-1,0,1]: caixa(gerente,item,c,lado*.24,0,.28,.28,6,9,true)
		return true
	return false

static func armario(gerente: SombrasEstruturasPlex, item: Dictionary, apoio: Vector3) -> bool:
	var visual:=MobiliaPlex.visual(item)
	if not visual.contains("armario") and MobiliaPlex.dados(item).get("familia","")!="lixeira" and not visual.begins_with("lixeira"): return false
	var chave:=str([visual,MobiliaPlex.estado(item),GradePlex.visao,item.rotacao])
	if not armarios.has(chave):
		var volume:=GeometriaPlex.objeto(item,gerente.planta,4)
		var baixo:=Vector3(INF,INF,INF);var alto:=-baixo
		for ponto in volume.pontos:
			var altura: float=(ponto.z-2*ponto.y)/3.0
			var local:=GradePlex.inverter_vetor(Vector2(ponto.x,ponto.y+altura))
			var q:=Vector3(local.x,local.y,maxf(0,altura));baixo=baixo.min(q);alto=alto.max(q)
		if not baixo.is_finite() or not alto.is_finite(): return false
		baixo.z=0;armarios[chave]=[baixo,alto]
	var limites: Array=armarios[chave]
	gerente.adicionar(limites[0]+apoio,limites[1]+apoio)
	return true

static func carga(gerente: SombrasEstruturasPlex, item: Dictionary, apoio: Vector3) -> bool:
	if not CaixasVisuaisPlex.eh(item.tipo) and item.tipo!="saco_lixo": return false
	var volume:=GeometriaPlex.objeto(item,gerente.planta,4)
	var baixo:=Vector3(INF,INF,INF)
	var alto:=-baixo
	for p in volume.pontos:
		var altura: float=(p.z-2.0*p.y)/3.0
		var local:=GradePlex.inverter_vetor(Vector2(p.x,p.y+altura))
		var v:=Vector3(local.x,local.y,altura)
		baixo=baixo.min(v);alto=alto.max(v)
	if baixo.is_finite() and alto.is_finite():
		gerente.adicionar(baixo+apoio,alto+apoio,item.tipo=="saco_lixo")
	return true


static func bancada_montagem(gerente:SombrasEstruturasPlex,item:Dictionary,apoio:Vector3) -> bool:
	if not MontagemAtracoesPlex.bancada(item):return false
	var c:=Vector2(apoio.x,apoio.y);var z:=apoio.z
	caixa(gerente,item,c,0,0,2.8,.86,z+29,2.1)
	for u in [-1.27,1.27]:
		for v in [-.33,.33]:caixa(gerente,item,c,u,v,.08,.08,z,29)
	caixa(gerente,item,c,-1.06,0,.45,.74,z+16,11.7)
	caixa(gerente,item,c,0,-.31,2.6,.055,z+9,2.4)
	for u in [-1.27,1.27]:caixa(gerente,item,c,u,0,.065,.74,z+9,2.4)
	return true

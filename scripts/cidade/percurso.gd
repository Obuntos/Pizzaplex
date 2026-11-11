class_name PercursoMoradoresPlex
extends RefCounted

static func preparar(s: Dictionary, planta: PlantaPlex) -> void:
	var rota: Array=s.get("rota",[])
	var chave:=hash(rota)
	if s.get("chave_percurso",-1)==chave: return
	s.chave_percurso=chave
	var pontos: Array=[]
	var distancias: Array=[0.0]
	var faixa:=float(posmod(hash(str(s.get("id",""))),4))*.16-.24
	for i in rota.size():
		var centro:=Vector2(rota[i][0],rota[i][1])
		var anterior:=Vector2(rota[maxi(0,i-1)][0],rota[maxi(0,i-1)][1])
		var proximo:=Vector2(rota[mini(rota.size()-1,i+1)][0],rota[mini(rota.size()-1,i+1)][1])
		var tangente:=(proximo-anterior).normalized()
		var lateral:=Vector2(-tangente.y,tangente.x)
		var cruzamento:=str(planta.pisos.get(Vector2i(centro.round()),"")).begins_with("cidade_faixa")
		var peso:=0.0 if i==0 or i==rota.size()-1 or cruzamento else 1.0
		var ponto:=centro+lateral*faixa*peso
		pontos.append([ponto.x,ponto.y])
		if i>0:
			var ultimo: Array=pontos[i-1]
			distancias.append(float(distancias[-1])+ponto.distance_to(Vector2(ultimo[0],ultimo[1])))
	s.pontos_percurso=pontos;s.distancias_percurso=distancias
	s.comprimento_percurso=float(distancias[-1]) if not pontos.is_empty() else 0.0

static func posicao(s: Dictionary, tempo: float, planta: PlantaPlex) -> Vector2:
	preparar(s,planta)
	if s.get("ritmo_real",0)!=2:
		var progresso:=clampf((tempo-float(s.inicio))/maxf(.001,float(s.duracao)),0,1)
		var variacao:=.92+float(posmod(hash(str(s.get("id",""))),9))*.025
		var nova:=maxf(.01,float(s.comprimento_percurso)/(CaminhosCidadePlex.PASSO_EXTERNO*variacao)*CalendarioPlex.MINUTOS_POR_SEGUNDO)
		s.inicio=tempo-progresso*nova;s.duracao=nova;s.ritmo_real=2
	var pontos: Array=s.pontos_percurso
	if pontos.is_empty(): return Vector2(s.posicao[0],s.posicao[1])
	var distancia:=clampf((tempo-float(s.inicio))/maxf(.001,float(s.duracao)),0,1)*float(s.comprimento_percurso)
	var ds: Array=s.distancias_percurso
	var indice:=0
	while indice+1<ds.size() and float(ds[indice+1])<distancia: indice+=1
	var proximo:=mini(indice+1,pontos.size()-1)
	var t:=clampf((distancia-float(ds[indice]))/maxf(.001,float(ds[proximo])-float(ds[indice])),0,1)
	return Vector2(pontos[indice][0],pontos[indice][1]).lerp(Vector2(pontos[proximo][0],pontos[proximo][1]),t)

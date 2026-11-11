class_name RondasPlex
extends RefCounted

var jogo: Node
var espera:=0.0
var assinatura: int=-1
var pontos: Array[Vector2i]=[]
var percursos: Dictionary={}

func _init(cena: Node) -> void:
	jogo=cena

func noite() -> bool:
	return not jogo.operacao.aberto and jogo.calendario.periodo()=="noite"

func valido(c: Vector2i) -> bool:
	return GradePlex.dentro(c) and jogo.planta.transitavel(c) and is_zero_approx(jogo.planta.altura(c)) and jogo.ambientes.em(c).get("fechada",false) and jogo.planta.em(c).get("tipo","") not in CatalogoPlex.PORTAS

func atualizar_pontos() -> void:
	jogo.ambientes.atualizar()
	var atual:=hash([jogo.ambientes.assinatura_estrutura,jogo.rotas.assinatura])
	if assinatura==atual: return
	assinatura=atual
	pontos.clear()
	percursos.clear()
	for sala in jogo.ambientes.ambientes:
		if not sala.fechada: continue
		var livres: Array[Vector2i]=[]
		var centro:=Vector2.ZERO
		for c in sala.celulas:
			if not valido(c): continue
			livres.append(c)
			centro+=Vector2(c)
		if livres.is_empty(): continue
		centro/=livres.size()
		for eixo in [Vector2(1,1),Vector2(1,-1),Vector2(-1,1),Vector2(-1,-1)]:
			var melhor: Vector2i=livres[0]
			for c in livres:
				if Vector2(c).dot(eixo)>Vector2(melhor).dot(eixo): melhor=c
			if not pontos.has(melhor): pontos.append(melhor)
		livres.sort_custom(func(a,b): return Vector2(a).distance_squared_to(centro)<Vector2(b).distance_squared_to(centro))
		if not pontos.has(livres[0]): pontos.append(livres[0])

func destino(a:PersonagemPlex,ciclo:int) -> Dictionary:
	atualizar_pontos()
	var opcoes:Array=[]
	for item in jogo.planta.objetos.values():
		if LugaresPlex.mesa(str(item.tipo)) or FornoPlex.eh(item) or item.tipo=="geladeira" or EscadasPlex.eh(item) or item.tipo in CatalogoPlex.PORTAS:
			for c in jogo.planta.interacoes(int(item.id)):
				if valido(c):opcoes.append({"celula":c,"olhar":item.celula,"acao":"inspecionar"})
	for c in pontos:opcoes.append({"celula":c,"olhar":c+GradePlex.frente(a.direcao),"acao":"ronda"})
	if opcoes.is_empty():return {}
	for i in opcoes.size():
		var ponto:Dictionary=opcoes[posmod(ciclo+i,opcoes.size())]
		if a.local.distance_to(Vector2(ponto.celula))<1.0:continue
		if not jogo.rotas.caminho(a.origem_rota(),ponto.celula).is_empty():return ponto
	return {}

func ronda_noturna(a: PersonagemPlex, tempo: float) -> void:
	atualizar_pontos()
	if not percursos.has(a.identificador): percursos[a.identificador]={"vistos":{},"espera":0.0,"alvo":Vector2i(-1,-1),"direcao":a.direcao}
	var percurso: Dictionary=percursos[a.identificador]
	if a.ocupado(): return
	if percurso.alvo==a.celula and not percurso.vistos.has(a.celula):
		percurso.vistos[a.celula]=true
		percurso.espera=2.4
		percurso.direcao=a.direcao
	if float(percurso.espera)>0.0:
		percurso.espera=maxf(0.0,float(percurso.espera)-tempo)
		a.direcao=posmod(int(percurso.direcao)+[0,1,-1][mini(2,floori((2.4-float(percurso.espera))/.8))],8)
		a.trabalho="inspecionar_noite"
		return
	var opcoes:=pontos.filter(func(c): return not percurso.vistos.has(c) and valido(c))
	if opcoes.is_empty():
		percurso.vistos.clear()
		percurso.espera=2.0
		return
	opcoes.sort_custom(func(x,y): return a.celula.distance_squared_to(x)<a.celula.distance_squared_to(y))
	for c in opcoes:
		var rota: Array[Vector2i]=jogo.rotas.caminho(a.origem_rota(),c)
		if rota.is_empty():
			percurso.vistos[c]=true
			continue
		percurso.alvo=c
		a.trabalho="ronda_noturna"
		if a.has_meta("limites_rota"): a.remove_meta("limites_rota")
		a.andar(rota)
		return
	percurso.espera=2.0

func atualizar(delta: float) -> void:
	jogo.sistemas.guarda.atualizar(delta)

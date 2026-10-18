class_name RondasPlex
extends RefCounted
var jogo: Node
var espera:=0.0
func _init(cena: Node) -> void:
	jogo=cena
func destino(a: PersonagemPlex, ciclo: int) -> Dictionary:
	var candidatos: Array=[]
	if ciclo%3==0:
		for marca in jogo.planta.objetos.values():
			if marca.tipo!="pose": continue
			var frente:=GradePlex.frente(marca.rotacao)
			for dist in [4,5,3]: candidatos.append({"celula":marca.celula+frente*dist,"olhar":marca.celula,"acao":"vigiar_palco"})
	elif ciclo%3==1:
		for pc in jogo.planta.objetos.values():
			if pc.tipo!="terminal_ibm": continue
			for c in jogo.planta.interacoes(pc.id): candidatos.append({"celula":c,"olhar":pc.celula,"acao":"vigiar_ibm"})
	else:
		for dist in [4,6,2]:
			for lado in GradePlex.VIZINHOS:
				var c: Vector2i=a.celula+lado*dist
				candidatos.append({"celula":c,"olhar":c+lado,"acao":"ronda"})
	for p in candidatos:
		if jogo.clientes.chao(p.celula) and not jogo.clientes.caminho(a.origem_rota(),p.celula).is_empty(): return p
	return {}
func atualizar(delta: float) -> void:
	espera+=delta
	if espera<.5: return
	var tempo:=espera
	espera=0.0
	for a in jogo.personagens:
		if a.robo or a.cargo!="funcionario" or a.funcao!="seguranca" or not a.automatico: continue
		if jogo.servicos.trabalhos.has(a.identificador): jogo.servicos.cancelar(a)
		if jogo.tarefas.trabalhos.has(a.identificador): jogo.tarefas.liberar(a)
		if a.carga_item>=0: jogo.servicos.inventario.devolver(a)
		a.carregando=false
		a.assento=-1
		if a.ocupado(): continue
		if a.visita.has("ronda_olhar"):
			var olhar: Array=a.visita.ronda_olhar
			jogo.tarefas.orientar(a,Vector2(olhar[0],olhar[1]))
		a.visita.ronda_espera=maxf(0,float(a.visita.get("ronda_espera",0.0))-tempo)
		if a.visita.ronda_espera>0: continue
		var ciclo:=int(a.visita.get("ronda_ciclo",0))
		var p:=destino(a,ciclo)
		a.visita.ronda_ciclo=ciclo+1
		a.visita.ronda_espera=6.0+float(posmod(a.identificador+ciclo,5))
		if p.is_empty(): continue
		a.visita.ronda_olhar=[p.olhar.x,p.olhar.y]
		a.trabalho=p.acao
		a.andar(jogo.clientes.caminho(a.origem_rota(),p.celula))

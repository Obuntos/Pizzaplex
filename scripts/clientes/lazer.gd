class_name LazerPlex
extends RefCounted

var jogo: Node
var espera := 0.0

func _init(cena: Node) -> void:
	jogo = cena

func vincular(a: PersonagemPlex, responsavel: int) -> void:
	if jogo.clientes.grupos.has(a.familia): return
	var adulto: PersonagemPlex=jogo.clientes.ator(responsavel)
	if not is_instance_valid(adulto) or not jogo.clientes.grupos.has(adulto.familia): return
	var grupo: Dictionary=jogo.clientes.grupos[adulto.familia]
	a.familia=adulto.familia
	a.responsavel=adulto.identificador
	a.visita.solo=false
	IdentidadesPlex.familiar(a,adulto)
	if not grupo.has("adolescentes"): grupo.adolescentes=[]
	if not grupo.adolescentes.has(a.identificador): grupo.adolescentes.append(a.identificador)

func criar(local: Vector2i, feminino: bool = false, responsavel: int = -1) -> bool:
	if not jogo.clientes.chao(local): return false
	var vagas: Array[Vector2i]=jogo.clientes.vagas(local,1,1)
	if vagas.is_empty(): return false
	var destino: Vector2i=jogo.clientes.saida(vagas[0])
	if destino.x<0: return false
	var a: PersonagemPlex=jogo.spawn("adolescente_feminina" if feminino else "adolescente",vagas[0],"adolescente")
	a.cabelo="camadas" if feminino else "curto"
	a.uniforme="nenhum"
	a.visita={"etapa":"arcade","partidas":0,"espera_jogo":0.0,"comeu":false,"solo":responsavel<0,"limite_partidas":2+randi()%3,"sem_maquina":0.0,"saida":[destino.x,destino.y]}
	if responsavel>=0: vincular(a,responsavel)
	return true

static func lugares_maquina(servico: ServicosPlex, ator: PersonagemPlex, id: int) -> Dictionary:
	var pontos:=servico.planta.interacoes(id)
	for posto in pontos:
		if servico.personagens.any(func(p): return p!=ator and (p.local.distance_to(Vector2(posto))<.8 or (p.movimento.atravessando and p.movimento.destino==posto))): continue
		if servico.rotas.caminho(ator.origem_rota(),posto).is_empty(): continue
		var opcoes: Array[Vector2i]=[]
		for raio in [1,2,3]:
			for d in GradePlex.VIZINHOS:
				var c: Vector2i=posto+d*raio
				if not servico.planta.transitavel(c) or not is_zero_approx(servico.planta.altura(c)): continue
				if servico.personagens.any(func(p): return p!=ator and (p.celula==c or p.movimento.destino==c and p.movimento.atravessando)): continue
				var frente_de_maquina:=false
				for outra in servico.planta.objetos.values():
					if outra.tipo=="maquina_fliperama" and servico.planta.interacoes(outra.id).has(c):
						frente_de_maquina=true
						break
				if frente_de_maquina: continue
				var rota:=servico.rotas.caminho(posto,c)
				if not rota.is_empty() and rota.size()<=5: opcoes.append(c)
		if opcoes.is_empty(): continue
		opcoes.sort_custom(func(a,b): return posto.distance_squared_to(a)<posto.distance_squared_to(b))
		return {"posto":[posto.x,posto.y],"saida":[opcoes[0].x,opcoes[0].y]}
	return {}

func refeicao(a: PersonagemPlex, grupo: Dictionary) -> void:
	var mesa: Dictionary=jogo.planta.objetos.get(int(grupo.get("mesa",-1)),{})
	if mesa.is_empty():
		a.trabalho="aguardar_familia"
		return
	var lugar:=AcompanhamentoVisitantesPlex.lugar(jogo.clientes,a,grupo)
	if lugar.is_empty() or not jogo.clientes.sentar(a,lugar): return
	var pedido:=int(a.visita.get("pedido",-1))
	if pedido<0:
		if jogo.servicos.criar_pedido(mesa.id,a.identificador,grupo.id,int(lugar.slot)): a.visita.pedido=jogo.servicos.proximo_pedido-1
		return
	var dados: Dictionary=jogo.servicos.pedido_por_id(pedido)
	if dados.get("estado","")=="consumido" and dados.get("bebida_estado","consumida")=="consumida":
		a.visita.comeu=true
		a.visita.etapa="show"
		a.visita.tempo_show=0.0
		a.assento=-1
		a.visita.erase("cadeira")
		a.trabalho="visitar"

func show(a: PersonagemPlex, delta: float) -> void:
	if not a.visita.has("show"):
		var ponto: Dictionary=jogo.clientes.ponto_show(a)
		if ponto.is_empty():
			a.visita.tempo_sem_show=float(a.visita.get("tempo_sem_show",0.0))+delta
			if a.visita.tempo_sem_show>=8.0: a.visita.etapa="arcade" if a.visita.get("comeu",false) else "refeicao"
			return
		a.visita.show=ponto.celula
		a.visita.pose=ponto.pose
	var alvo: Array=a.visita.show
	if not jogo.poses.valida(int(a.visita.pose)):
		a.visita.erase("show")
		return
	if not jogo.clientes.ir(a,Vector2i(alvo[0],alvo[1])): return
	for robo in jogo.personagens:
		if not robo.robo or robo.pose!=int(a.visita.pose): continue
		a.trabalho="assistir"
		jogo.tarefas.orientar(a,robo.local)
		if robo.robotica.get("estado","")=="ligado": a.visita.tempo_show=float(a.visita.get("tempo_show",0.0))+delta
		if float(a.visita.get("tempo_show",0.0))>=16.0:
			a.visita.assistiu=true
			a.visita.etapa="arcade" if a.visita.get("comeu",false) else "refeicao"
			a.visita.espera_jogo=3.0
			a.visita.erase("show")
		break

func jogar(a: PersonagemPlex) -> bool:
	var maquinas: Array=jogo.servicos.encontrar("maquina_fliperama",["jogos"])
	maquinas.sort_custom(func(x,y): return a.local.distance_squared_to(Vector2(jogo.planta.objetos[x].celula))<a.local.distance_squared_to(Vector2(jogo.planta.objetos[y].celula)))
	for id in maquinas:
		if RotinasPlex.iniciar(jogo.servicos,a,id):
			a.assento=-1
			a.visita.erase("cadeira")
			return true
	a.trabalho="aguardar_arcade"
	a.visita.espera_jogo=1.5
	return false

func sozinho(a: PersonagemPlex, delta: float) -> void:
	if a.visita.get("etapa","")=="sair":
		var alvo: Array=a.visita.get("saida",[-1,-1])
		var destino:=Vector2i(alvo[0],alvo[1])
		if not GradePlex.dentro(destino) or jogo.clientes.caminho(a.origem_rota(),destino).is_empty():
			destino=jogo.clientes.saida(a.origem_rota())
			if destino.x<0: return
			a.visita.saida=[destino.x,destino.y]
		if a.celula.distance_to(destino)<1.5:
			jogo.despawn(a)
			return
		jogo.clientes.ir(a,destino)
		a.trabalho="sair_visita"
		return
	a.visita.espera_jogo=maxf(0,float(a.visita.get("espera_jogo",0))-delta)
	if a.visita.espera_jogo>0: return
	if jogar(a): a.visita.sem_maquina=0.0
	else:
		a.visita.sem_maquina=float(a.visita.get("sem_maquina",0))+delta+1.0
		if a.visita.sem_maquina>=120.0:
			a.visita.etapa="sair"
			a.visita.irritado=true

func atualizar(delta: float) -> void:
	espera+=delta
	if espera<.5: return
	var tempo:=espera
	espera=0.0
	for a in jogo.personagens.duplicate():
		if not is_instance_valid(a) or a.cargo!="adolescente" or a.ocupado() or jogo.servicos.trabalhos.has(a.identificador): continue
		if a.familia<0:
			a.visita.solo=true
			sozinho(a,tempo)
			continue
		var grupo: Dictionary=jogo.clientes.grupos.get(a.familia,{})
		if grupo.is_empty() or grupo.estado in ["saindo","pago"] or not grupo.get("acesso",false): continue
		var etapa:=str(a.visita.get("etapa","arcade"))
		if etapa=="refeicao":
			refeicao(a,grupo)
			continue
		if etapa=="show":
			show(a,tempo)
			continue
		if grupo.estado!="visita" or grupo.get("irritado",false): continue
		a.visita.espera_jogo=maxf(0,float(a.visita.get("espera_jogo",0))-tempo)
		if a.visita.espera_jogo<=0: jogar(a)

static func brincar(jogo_atual: Node, a: PersonagemPlex, grupo: Dictionary, delta: float) -> bool:
	if not a.visita.get("brincou", false):
		a.visita.brincou = true
		a.visita.etapa = "correr"
		a.visita.corrida_restante = 12.0
		a.visita.depois_corrida = "jogar"
	elif a.visita.get("assistiu", false) and float(a.visita.get("tempo_show", 0)) >= 16 and not a.visita.get("correu_apos_show", false):
		a.visita.correu_apos_show = true
		a.visita.etapa = "correr"
		a.visita.corrida_restante = 12.0
		a.visita.depois_corrida = "show"
		a.visita.erase("show")
	if a.visita.get("etapa", "") != "correr":
		a.visita.correndo = false
		return false
	var ambiente: Dictionary = jogo_atual.ambientes.em(a.celula)
	var no_salao: bool = "salao" in ambiente.get("funcoes", [])
	if no_salao: a.visita.corrida_restante = maxf(0, float(a.visita.get("corrida_restante", 12)) - delta)
	if float(a.visita.corrida_restante) <= 0:
		a.visita.correndo = false
		a.visita.etapa = str(a.visita.get("depois_corrida", "jogar"))
		return false
	if a.ocupado(): return true
	var outros: Array = jogo_atual.personagens.filter(func(o): return o != a and o.cargo == "crianca" and o.familia == grupo.id)
	var centro: Vector2i = a.celula
	if not outros.is_empty(): centro = outros[0].celula
	var candidatos: Array[Vector2i] = []
	for d in [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]:
		var c: Vector2i = centro + d * (1 + int(a.identificador % 2))
		var sala: Dictionary = jogo_atual.ambientes.em(c)
		if "salao" in sala.get("funcoes", []) and jogo_atual.clientes.chao(c) and c != a.celula: candidatos.append(c)
	if candidatos.is_empty():
		for id in jogo_atual.ambientes.equipamentos("mesa", ["salao"]):
			var acessos: Array[Vector2i] = jogo_atual.planta.interacoes(id)
			candidatos.append_array(acessos)
	candidatos.sort_custom(func(x, y): return x.distance_squared_to(a.celula) < y.distance_squared_to(a.celula))
	for c in candidatos:
		var rota: Array[Vector2i] = jogo_atual.clientes.caminho(a.origem_rota(), c)
		if rota.is_empty() or (no_salao and rota.size() > 14): continue
		a.trabalho = "brincar"
		a.visita.correndo = no_salao
		a.andar(rota)
		return true
	return true

class_name DiversaoFamiliaPlex
extends RefCounted

const DURACAO_SHOW_REAL=180.0
const PACIENCIA_MASCOTE=10.0
static func esperar(jogo:Node,a:PersonagemPlex,delta:float) -> bool:
	a.visita.espera_mascote=float(a.visita.get("espera_mascote",0))+delta*CalendarioPlex.MINUTOS_POR_SEGUNDO
	if float(a.visita.espera_mascote)<PACIENCIA_MASCOTE:return false
	CirculacaoVisitantesPlex.encerrar_espera(jogo,a)
	return true

static func contar_show(jogo: Node, a: PersonagemPlex, delta: float) -> void:
	a.visita.tempo_show=float(a.visita.get("tempo_show",0.0))+delta/maxf(.001,float(jogo.velocidade_tempo))

static func prontos(jogo: Node, grupo: Dictionary) -> bool:
	for id in grupo.get("criancas",[])+grupo.get("adolescentes",[]):
		var a: PersonagemPlex=jogo.clientes.ator(int(id))
		if is_instance_valid(a) and not a.visita.get("diversao_concluida",false): return false
	return true

static func concluir(jogo: Node, a: PersonagemPlex) -> void:
	if a.visita.get("diversao_concluida",false): return
	a.visita.diversao_concluida=true;a.visita.assistiu=true;a.visita.etapa="aguardar";a.trabalho="aguardar_familia"
	jogo.livro.divertir(a)

static func ponto_perto(jogo: Node, a: PersonagemPlex, centro: Vector2i) -> Vector2i:
	var lista: Array[Vector2i]=[]
	for raio in [1,2,3]:
		for d in GradePlex.VIZINHOS:
			var p: Vector2i=centro+d*raio
			if not jogo.planta.transitavel(p) or not TerrenoPlex.contem(jogo.planta,p): continue
			if jogo.personagens.any(func(o): return o!=a and (o.celula==p or o.ocupado() and o.origem_rota()==p)): continue
			lista.append(p)
	lista.sort_custom(func(x,y): return a.local.distance_squared_to(Vector2(x))<a.local.distance_squared_to(Vector2(y)))
	for p in lista:
		if not CirculacaoVisitantesPlex.rota(jogo,a.origem_rota(),p).is_empty(): return p
	return Vector2i(-1,-1)

static func atualizar(jogo: Node, a: PersonagemPlex, grupo: Dictionary, delta: float) -> bool:
	if not a.visita.get("comeu",false) or grupo.get("estado","") in ["saindo","pago"]: return false
	if a.visita.get("voltar_responsavel",false):return true
	if a.visita.get("solitario",false) and jogo.servicos.tempo_servico<float(a.visita.get("isolamento_ate",0)):a.trabalho="isolada";return true
	if a.visita.get("diversao_concluida",false):
		if not a.ocupado(): a.trabalho="aguardar_familia"
		return true
	if jogo.servicos.trabalhos.has(a.identificador): return true
	var robo: PersonagemPlex=null
	for r in jogo.personagens:
		if r.robo and r.pose>=0 and r.trabalho=="apresentar" and not r.visita.get("montando_atracao",false) and not AnimatronicosPlex.pausado(r): robo=r;break
	if is_instance_valid(robo):
		if not a.visita.has("show"):
			if a.relogio<float(a.visita.get("buscar_show_apos",0)):esperar(jogo,a,delta);return true
			a.visita.buscar_show_apos=a.relogio+1.0
			var ponto: Dictionary=jogo.clientes.ponto_show(a)
			if not ponto.is_empty(): a.visita.show=ponto.celula;a.visita.pose=ponto.pose
		if not a.visita.has("show"):esperar(jogo,a,delta);return true
		var alvo: Array=a.visita.show
		if jogo.clientes.ir(a,Vector2i(alvo[0],alvo[1])):
			a.trabalho="assistir"
			for r in jogo.personagens:
				if r.pose==int(a.visita.get("pose",-1)):
					jogo.tarefas.orientar(a,r.local)
					if r.robotica.get("estado","")=="ligado": contar_show(jogo,a,delta)
			if float(a.visita.get("tempo_show",0))>=DURACAO_SHOW_REAL: concluir(jogo,a)
		else:esperar(jogo,a,delta)
		return true
	var adm: PersonagemPlex=jogo.fantasias.administrador()
	if not is_instance_valid(adm) or not adm.modelo.begins_with("fantasia_") or not CirculacaoVisitantesPlex.permitida(jogo,adm.celula):a.trabalho="aguardar_mascote";esperar(jogo,a,delta);return true
	if a.local.distance_to(adm.local)>2.4:
		if esperar(jogo,a,delta):return true
		if not a.ocupado():
			var perto:=ponto_perto(jogo,a,adm.origem_rota())
			if perto.x>=0: a.assento=-1;a.andar(CirculacaoVisitantesPlex.rota(jogo,a.origem_rota(),perto));a.trabalho="seguir_mascote"
		return true
	if a.ocupado() or adm.ocupado() or jogo.servicos.trabalhos.has(adm.identificador):esperar(jogo,a,delta);return true
	adm.visita.conversando_ate=adm.relogio+1.0;adm.trabalho="animar_visitantes";a.trabalho="assistir_mascote"
	jogo.tarefas.orientar(a,adm.local);jogo.tarefas.orientar(adm,a.local)
	a.visita.tempo_mascote=float(a.visita.get("tempo_mascote",0))+delta
	if float(a.visita.tempo_mascote)>=7: concluir(jogo,a)
	return true

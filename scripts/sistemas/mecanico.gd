class_name MecanicoNoturnoPlex
extends RefCounted

const INICIO:=1410.0
const LIMITE:=240.0
const TEMPO_CLIPE:=6.0
const TEMPO_FANTASIA:=8.0
const FALHA_BASE:=.15
const REDUCAO:=.6
var jogo:Node
var feita:=-1
var espera:=0.0

func _init(cena:Node) -> void:jogo=cena
func noite_atual() -> int:return int(jogo.calendario.dias) if float(jogo.calendario.minutos)>=1380.0 else int(jogo.calendario.dias)-1
func horario() -> bool:return float(jogo.calendario.minutos)>=INICIO or float(jogo.calendario.minutos)<LIMITE
func ativo() -> PersonagemPlex:
	for a in jogo.personagens:
		if a.visita.has("mec"):return a
	return null
func possuido(r:PersonagemPlex) -> bool:return r.robotica.get("assombrado",false) or r.visita.get("debug_possuido",false)

func mecanico() -> PersonagemPlex:
	for a in jogo.personagens:
		if a.cargo=="funcionario" and not a.robo and a.funcao=="manutencao" and not a.visita.get("morto",false) and not a.visita.get("demitido",false):return a
	return null

func robo_alvo() -> PersonagemPlex:
	var melhor:PersonagemPlex=null
	for r in jogo.personagens:
		if not r.robo or r.modelo not in ControleAnimatronicoPlex.MODELOS or ArmazemRobosPlex.INTEIRO.has(r.modelo) or r.robotica.get("armazenado",false) or r.visita.get("montando_atracao",false):continue
		if r.visita.has("oficina_robo") or r.visita.has("controle_largado"):continue
		if melhor==null or float(r.robotica.get("desgaste",0.0))>float(melhor.robotica.get("desgaste",0.0)):melhor=r
	return melhor

func destino(r:PersonagemPlex) -> Vector2i:
	for tipo in ["area_montagem_atracao","amb_painel_diagnostico","amb_carregador_oficina"]:
		for o in jogo.planta.objetos.values():
			if o.tipo!=tipo:continue
			var lista:Array=[o.celula] if tipo=="area_montagem_atracao" else jogo.planta.interacoes(int(o.id))
			for c in lista:
				var alvo:Vector2i=c
				if jogo.planta.transitavel(alvo) and not jogo.personagens.any(func(p):return p!=r and p.celula==alvo) and (r.celula==alvo or not jogo.rotas.caminho(r.origem_rota(),alvo).is_empty()):return alvo
	return Vector2i(-1,-1)

func ir_ate(a:PersonagemPlex,alvo:Vector2i) -> bool:
	for d in GradePlex.VIZINHOS:
		var c:Vector2i=alvo+d
		if a.celula==c:return true
		if not jogo.planta.transitavel(c) or jogo.personagens.any(func(p):return p!=a and p.celula==c):continue
		var rota:Array[Vector2i]=jogo.rotas.caminho(a.origem_rota(),c)
		if not rota.is_empty():a.andar(rota);return true
	return false

func iniciar() -> void:
	var m:=mecanico();var r:=robo_alvo()
	feita=noite_atual()
	if m==null or r==null:return
	var trazido:=false
	if m.visita.get("fora_turno",false) or m.visita.get("saindo_fechamento",false):jogo.turnos.chegada(m,.5);trazido=true
	m.visita.mec={"robo":r.identificador,"etapa":"chegar","t":0.0,"passo":0,"trazido":trazido}
	jogo.painel.mensagem("O mecânico vai fazer a manutenção noturna de "+IdentidadesPlex.completo(r)+".")
	jogo.sistemas.avisos.marcar(r.local,"Manutenção noturna: "+IdentidadesPlex.completo(r))

func atualizar(delta:float) -> void:
	espera+=delta
	if espera<.5:return
	var passo:=espera;espera=0.0
	var m:=ativo()
	if m==null:
		if horario() and feita!=noite_atual():iniciar()
		return
	var d:Dictionary=m.visita.mec
	var r:PersonagemPlex=jogo.clientes.ator(int(d.robo))
	if m.visita.get("morto",false):encerrar(m,r,false);return
	if not is_instance_valid(r):encerrar(m,null,false);return
	d.t=float(d.t)+passo
	match str(d.etapa):
		"chegar":
			if TurnosEquipePlex.ocupado(m) or m.visita.get("fora_turno",false):
				if float(d.t)>240.0:encerrar(m,r,false)
				return
			if ir_ate(m,r.celula):d.etapa="buscar";d.t=0.0
			else:encerrar(m,r,false)
		"buscar":
			if m.ocupado():return
			if m.local.distance_to(r.local)>1.8:
				if float(d.t)>60.0 or not ir_ate(m,r.celula):encerrar(m,r,false)
				return
			pegar(m,r,d)
		"levar":
			if r.ocupado() or m.ocupado():return
			d.etapa="testar";d.t=0.0;d.passo=0;jogo.tarefas.orientar(m,r.local)
			jogo.sistemas.baloes.exibir(m,"Vamos testar as animações.",3)
		"testar":
			testar(m,r,d)
		"fantasia":
			m.trabalho="montar";jogo.tarefas.orientar(m,r.local)
			if ClipesPlex.possui(r.modelo,"plastico"):r.visita.diagnostico_animacao="plastico";r.visita.diagnostico_tempo=float(d.t)
			if float(d.t)>=TEMPO_FANTASIA:
				r.visita.erase("diagnostico_animacao")
				jogo.sistemas.baloes.exibir(m,"Plástico em ordem. Fantasia de volta no lugar.",3)
				r.robotica.desgaste=maxf(0.0,float(r.robotica.get("desgaste",0.0))-REDUCAO)
				if float(r.robotica.desgaste)<2.0:r.robotica.avariado=false
				encerrar(m,r,true)

func pegar(m:PersonagemPlex,r:PersonagemPlex,d:Dictionary) -> void:
	if jogo.controle_robo.controlado(r):jogo.controle_robo.soltar(false,"O mecânico pegou o animatrônico para a manutenção. Controle outro.")
	r.visita.erase("controle_largado");r.visita.bloqueio_noite=true;r.visita.mec_noturno=m.identificador
	r.movimento.cancelar();r.trabalho="manutencao_noturna"
	var alvo:=destino(r)
	if alvo.x<0:jogo.painel.mensagem("O mecânico precisa de uma sala de serviço com base de montagem, diagnóstico ou carregador livre.");encerrar(m,r,false);return
	if r.celula!=alvo:r.andar(jogo.rotas.caminho(r.origem_rota(),alvo))
	ir_ate(m,alvo)
	d.etapa="levar";d.t=0.0
	jogo.sistemas.baloes.exibir(m,"Vem comigo, vamos para a sala de serviço.",3)

func clipes(r:PersonagemPlex) -> Array:
	var lista:Array=[]
	for nome in ["cantar","pose_apresentar","pose_tocando","pose_tchau","pose_crooner","pose_cintura"]:
		if ClipesPlex.possui(r.modelo,nome):lista.append(nome)
	return lista

func testar(m:PersonagemPlex,r:PersonagemPlex,d:Dictionary) -> void:
	var lista:=clipes(r)
	m.trabalho="montar";jogo.tarefas.orientar(m,r.local)
	if int(d.passo)>=lista.size():
		r.visita.erase("diagnostico_animacao");d.etapa="fantasia";d.t=0.0
		jogo.sistemas.baloes.exibir(m,"Tirando a fantasia para inspecionar o plástico...",4)
		return
	if not r.visita.has("diagnostico_animacao") or str(r.visita.diagnostico_animacao)!=str(lista[d.passo]):
		r.visita.diagnostico_animacao=str(lista[d.passo]);r.visita.diagnostico_tempo=0.0
		if possuido(r) and randf()<FALHA_BASE/maxf(.5,HabilidadesEquipePlex.fator(m,"manutencao")):ataque(m,r);return
	r.visita.diagnostico_tempo=float(d.t)
	if float(d.t)>=TEMPO_CLIPE:d.passo=int(d.passo)+1;d.t=0.0

func ataque(m:PersonagemPlex,r:PersonagemPlex) -> void:
	r.visita.erase("diagnostico_animacao")
	jogo.tarefas.orientar(r,m.local)
	var caca:CacaAnimatronicosPlex=jogo.sistemas.caca
	var guarda:GuardaAutonomoPlex=jogo.sistemas.guarda
	for g in jogo.personagens:
		if not caca.guarda(g):continue
		if VisaoNPCPlex.ve(jogo,g,m,8.0) or guarda.monitorando(g) and guarda.camera_atual_ve(g,m.local):caca.somar_medo(g,1.5);jogo.sistemas.baloes.exibir(g,"O ANIMATRÔNICO ATACOU O MECÂNICO!",4)
	jogo.sistemas.investigacao.registrar_incidente(m)
	GorePlex.espalhar(jogo,m.celula,3,posmod(roundi(float(r.direcao)/2.0),4))
	jogo.painel.mensagem("O animatrônico ativou durante a manutenção e atacou o mecânico. Limpe tudo antes que alguém veja.")
	jogo.sistemas.avisos.marcar(m.local,"O mecânico foi atacado")
	jogo.sistemas.jornal.noticiar("Funcionário da pizzaria desaparece durante o turno da noite.")
	r.visita.erase("bloqueio_noite");r.visita.erase("mec_noturno");r.trabalho=""
	m.visita.erase("mec")
	jogo.despawn(m)

func encerrar(m:PersonagemPlex,r:PersonagemPlex,ok:bool) -> void:
	if is_instance_valid(r):
		r.visita.erase("diagnostico_animacao");r.visita.erase("mec_noturno");r.trabalho=""
	if not is_instance_valid(m):return
	var d:Dictionary=m.visita.get("mec",{})
	m.visita.erase("mec");m.trabalho=""
	if ok:
		for q in jogo.planta.objetos.values():
			if q.tipo=="amb_quadro_energia" and float(q.get("desgaste",0.0))>=50.0 and jogo.sistemas.tempestade.pedir(q,m):return
	if d.get("trazido",false):jogo.turnos.sair(m)

func gravar() -> Dictionary:return {"feita":feita}
func restaurar(dados:Dictionary) -> void:feita=int(dados.get("feita",-1))

class_name TurnosEquipePlex
extends RefCounted

var jogo:Node
var espera:=0.0
var filas:Dictionary={}
var ordem_fila:=0
func _init(cena:Node) -> void:jogo=cena
static func funcionario(a:PersonagemPlex) -> bool:return not a.visita.get("debug_servico",false) and a.cargo=="funcionario" and not a.robo and not AdministradorPlex.eh(a) and not a.visita.get("morto",false) and not a.visita.get("demitido",false)
static func trabalhador(a:PersonagemPlex) -> bool:return not a.visita.get("debug_servico",false) and a.cargo=="funcionario" and not a.robo and not a.visita.get("morto",false)
static func ocupado(a:PersonagemPlex) -> bool:return not str(a.visita.get("turno_etapa","")).is_empty()
static func eh_armario(item:Dictionary) -> bool:return item.get("tipo","")=="armario_funcionarios"

func armario(a:PersonagemPlex=null) -> int:
	if is_instance_valid(a):
		var atual:=int(a.visita.get("turno_fila_armario",-1))
		if jogo.planta.objetos.has(atual) and not ArmariosPlex.acessos_vestiario(jogo.planta,jogo.planta.objetos[atual]).is_empty():return atual
	var lista:Array=jogo.planta.objetos.values().filter(func(item):return eh_armario(item) and jogo.ambientes.do_objeto(item.id).get("fechada",false) and not ArmariosPlex.acessos_vestiario(jogo.planta,item).is_empty())
	if is_instance_valid(a):lista.sort_custom(func(x,y):return a.local.distance_squared_to(Vector2(x.celula))<a.local.distance_squared_to(Vector2(y.celula)))
	for item in lista:
		if not is_instance_valid(a) or not jogo.rotas.aproximar(a.origem_rota(),int(item.id)).is_empty():return int(item.id)
	return -1

func cadeiras() -> Array:
	var lista:Array=[]
	for item in jogo.planta.objetos.values():
		if CatalogoPlex.base(item.tipo)!="cadeira" and item.tipo not in ["oficina_cadeira_escritorio_baixa","oficina_cadeira_escritorio_alta"]:continue
		var sala:Dictionary=jogo.ambientes.do_objeto(item.id)
		if not sala.get("fechada",false):continue
		if not FuncoesSalaPlex.aceita(sala,["descanso","escritorio","seguranca"]) and not sala.get("objetos",[]).any(func(id):return eh_armario(jogo.planta.objetos.get(id,{}))):continue
		lista.append(item)
	return lista

func destino_trabalho(a:PersonagemPlex) -> Vector2i:
	jogo.ambientes.atualizar()
	var entradas:Array=ChegadasEquipePlex.entradas(jogo)
	var candidatos:Array[Vector2i]=[]
	var v:=armario(a)
	if v>=0:candidatos.append_array(jogo.planta.interacoes(v))
	for sala in jogo.ambientes.ambientes:
		if not sala.fechada or not FuncoesSalaPlex.aceita(sala,["salao","recepcao","cozinha","oficina","escritorio"]):continue
		for p in sala.celulas:
			if jogo.planta.transitavel(p):candidatos.append(p)
	for candidato in candidatos:
		if entradas.is_empty():return candidato
		if entradas.any(func(e):return not jogo.rotas.caminho(e.fora,candidato).is_empty()):return candidato
	for e in entradas:
		if jogo.planta.transitavel(e.dentro) and not jogo.rotas.caminho(e.fora,e.dentro).is_empty():return e.dentro
	return Vector2i(-1,-1)

func chegada(a:PersonagemPlex,atraso:float=0.0) -> void:
	if not funcionario(a):return
	if a.visita.get("fora_turno",false):recuperar_descanso(a)
	liberar_cadeira(a)
	jogo.controle.interromper(a)
	a.visita.erase("estudando")
	a.visita.turno_iniciado=true;a.visita.turno_etapa="aguardar_chegada";a.visita.turno_espera=atraso
	a.visita.turno_uniforme=str(a.visita.get("turno_uniforme",a.uniforme));a.visita.turno_automatico=bool(a.visita.get("turno_automatico",true))
	a.visita.fora_turno=true;a.visita.erase("saindo_fechamento");a.visita.erase("saida_fechamento")
	a.necessidades.turno=false;a.automatico=false;a.hide()
	var destino:=destino_trabalho(a)
	if destino.x<0:
		var entradas:Array=ChegadasEquipePlex.entradas(jogo)
		if not entradas.is_empty():
			var fora:Vector2i=entradas[0].fora;a.celula=fora;a.local=Vector2(fora);a.position=GradePlex.projetar(a.local);a.visita.erase("fora_turno");a.visita.turno_etapa="aguardar_acesso";a.visita.turno_revisao=jogo.planta.revisao;a.trabalho="aguardar_acesso";a.show()
		jogo.painel.mensagem("Funcionário chamado. Libere a entrada e o caminho até a área de trabalho.");return
	var ponto:=ChegadasEquipePlex.origem(jogo,a,destino)
	a.visita.turno_origem_pendente=ponto.x<0
	if ponto.x>=0:a.celula=ponto;a.local=Vector2(ponto);a.position=GradePlex.projetar(a.local)
	a.uniforme="nenhum"
	a.visita.turno_civil=true;a.visita.troca_uniforme_pendente=true
	a.visita.turno_destino=[destino.x,destino.y]
	if a.has_meta("limites_rota"):a.remove_meta("limites_rota")
	jogo.preparacao.personagem(a)

func abrir() -> void:
	var atraso:=.5
	for a in jogo.personagens:
		if funcionario(a):
			if a.visita.get("contrato_noturno",false) and not jogo.sistemas.guarda.escala.ativo(a,jogo.calendario.dias,jogo.calendario.minutos):continue
			if a.funcao=="seguranca" and a.visita.get("turno_noturno",false) and not a.visita.get("fora_turno",false):continue
			chegada(a,atraso);atraso+=1.5

func fechar() -> void:
	for a in jogo.personagens:
		if not funcionario(a):continue
		if a.funcao=="seguranca" and jogo.sistemas.guarda.escala.ativo(a,jogo.calendario.dias,jogo.calendario.minutos):continue
		if a.visita.get("fora_turno",false):a.visita.erase("turno_etapa");a.hide();continue
		liberar_cadeira(a);a.visita.turno_etapa="ir_trocar_saida";a.visita.turno_tempo=0.0;a.automatico=false

func liberar_cadeira(a:PersonagemPlex) -> void:
	var id:=int(a.visita.get("descanso_cadeira",-1))
	if jogo.planta.objetos.has(id) and int(jogo.planta.objetos[id].get("reserva",0))==a.identificador:jogo.planta.objetos[id].reserva=0
	a.visita.erase("descanso_cadeira");a.assento=-1

func descansar(a:PersonagemPlex,manual:bool=true) -> bool:
	if not trabalhador(a) or a.visita.get("fora_turno",false) or a.visita.get("saindo_fechamento",false):return false
	if manual and a.funcao=="seguranca":return false
	if not manual and a.visita.get("estudo_forcado",false):return false
	if ocupado(a):return false
	for cadeira in cadeiras():
		if int(cadeira.get("reserva",0))!=0:continue
		var rota:Array[Vector2i]=jogo.rotas.aproximar(a.origem_rota(),cadeira.id)
		if rota.is_empty():continue
		if AdministradorPlex.eh(a):
			jogo.controle.cancelar_acao();a.visita.controle_manual=false
			if "rotina_adm" in jogo:jogo.rotina_adm.cancelar(a)
		jogo.controle.interromper(a);cadeira.reserva=a.identificador
		a.visita.erase("estudando")
		a.visita.turno_automatico=a.automatico;a.automatico=false;a.visita.descanso_cadeira=cadeira.id;a.visita.turno_etapa="ir_descansar"
		a.andar(rota);a.trabalho="ir_descansar"
		return true
	if manual:jogo.painel.mensagem("Coloque uma cadeira em uma sala fechada com armários de funcionários e deixe acesso livre.")
	return false

func voltar(a:PersonagemPlex) -> void:
	var armario_id:=int(a.visita.get("turno_armario",-1))
	liberar_vestiario(a)
	liberar_cadeira(a);a.visita.erase("turno_etapa");a.visita.erase("turno_tempo");a.trabalho="";a.automatico=bool(a.visita.get("turno_automatico",true));a.necessidades.turno=true
	if armario_id>=0:afastar_armario(a,armario_id)

func ir(a:PersonagemPlex,destino:Vector2i,titulo:String) -> bool:
	if a.ocupado():return false
	if a.celula==destino:return true
	var rota:Array[Vector2i]=jogo.rotas.caminho(a.origem_rota(),destino)
	if not rota.is_empty():a.andar(rota);a.trabalho=titulo
	return false

func atualizar(delta:float) -> void:
	espera+=delta
	if espera<.3:return
	var tempo:=espera;espera=0.0
	for a in jogo.personagens:
		if not trabalhador(a):continue
		if funcionario(a) and not a.visita.get("turno_iniciado",false):
			if (jogo.sistemas.guarda.em_turno(a) if a.funcao=="seguranca" else jogo.operacao.aberto):chegada(a,1.0)
			else:a.visita.fora_turno=true;a.hide()
		var fase:=str(a.visita.get("turno_etapa",""))
		if fase.is_empty() and a.visita.get("troca_uniforme_pendente",false) and not a.visita.get("fora_turno",false) and not ControleAdministradorPlex.ocupado(a) and not jogo.servicos.trabalhos.has(a.identificador) and not jogo.tarefas.trabalhos.has(a.identificador):
			var id:=armario(a)
			if id>=0 and not jogo.rotas.aproximar(a.origem_rota(),id).is_empty():
				var destino:Vector2i=ArmariosPlex.acessos_vestiario(jogo.planta,jogo.planta.objetos[id])[0]
				a.visita.turno_destino=[destino.x,destino.y];a.visita.turno_automatico=a.automatico;a.automatico=false;a.visita.turno_etapa="chegando";fase="chegando"
		if fase.is_empty() and a.visita.get("fora_turno",false):a.energia=minf(100,a.energia+tempo*.18)
		if fase=="aguardar_chegada":
			a.visita.turno_espera=float(a.visita.get("turno_espera",0.0))-tempo
			if float(a.visita.turno_espera)<=0:
				if a.visita.get("turno_origem_pendente",false):
					var destino:=destino_trabalho(a);var origem:=ChegadasEquipePlex.origem(jogo,a,destino)
					if origem.x<0:a.visita.turno_espera=3.0;continue
					a.celula=origem;a.local=Vector2(origem);a.position=GradePlex.projetar(a.local);a.visita.turno_origem_pendente=false;a.visita.turno_destino=[destino.x,destino.y]
				a.visita.erase("fora_turno");a.visita.turno_etapa="chegando";a.show()
		elif fase=="aguardar_acesso":
			if int(a.visita.get("turno_revisao",-1))!=jogo.planta.revisao:chegada(a,0)
		elif fase=="chegando":
			var id_armario:=armario(a)
			if id_armario>=0 and not obter_vez(a,id_armario):continue
			var p:Array=a.visita.turno_destino
			if id_armario>=0:
				var frente:Vector2i=ArmariosPlex.acessos_vestiario(jogo.planta,jogo.planta.objetos[id_armario])[0]
				p=[frente.x,frente.y]
			if ir(a,Vector2i(p[0],p[1]),"chegar_trabalho"):
				if id_armario<0 or not jogo.planta.interacoes(id_armario).has(a.celula):voltar(a)
				else:a.visita.turno_etapa="trocar_entrada";a.visita.turno_tempo=0.0
		elif fase in ["trocar_entrada","trocar_saida"]:
			var id:=int(a.visita.get("turno_armario",-1))
			if not ArmariosPlex.em_vestiario(jogo.planta,a,id):
				a.visita.turno_etapa="chegando" if fase=="trocar_entrada" else "ir_trocar_saida";a.visita.turno_tempo=0.0;continue
			jogo.tarefas.orientar(a,Vector2(jogo.planta.objetos[id].celula))
			a.visita.turno_tempo=float(a.visita.get("turno_tempo",0.0))+tempo;a.trabalho="usar_armario"
			if float(a.visita.turno_tempo)>=2.5:
				a.uniforme=str(a.visita.get("turno_uniforme","automatico")) if fase=="trocar_entrada" else "nenhum"
				if fase=="trocar_entrada":a.visita.turno_civil=false;a.visita.troca_uniforme_pendente=false;voltar(a);jogo.preparacao.personagem(a);jogo.equipamentos.ponto.iniciar(a,true)
				else:liberar_vestiario(a);a.visita.turno_civil=true;a.visita.erase("turno_etapa");a.trabalho="sair_fechamento";jogo.preparacao.personagem(a)
		elif fase=="ir_trocar_saida":
			var id:=armario(a)
			if id<0:a.visita.erase("turno_etapa");a.trabalho="sair_fechamento";continue
			if not obter_vez(a,id):continue
			var rota:Array[Vector2i]=jogo.rotas.aproximar(a.origem_rota(),id)
			if not a.ocupado() and not rota.is_empty():
				if rota.size()<=1:a.visita.turno_etapa="trocar_saida";a.visita.turno_tempo=0.0
				else:a.andar(rota);a.trabalho="ir_vestiario_saida"
		elif fase=="ir_descansar":
			var cadeira:Dictionary=jogo.planta.objetos.get(int(a.visita.get("descanso_cadeira",-1)),{})
			if cadeira.is_empty():voltar(a);continue
			if not a.ocupado():
				var rota:Array[Vector2i]=jogo.rotas.aproximar(a.origem_rota(),cadeira.id)
				if rota.is_empty():voltar(a)
				elif rota.size()>1:a.andar(rota)
				else:a.assento=cadeira.id;a.direcao=GradePlex.direcao_suporte(cadeira.rotacao);a.trabalho="descansar";a.visita.turno_etapa="descansando"
		elif fase=="descansando":
			var id:=int(a.visita.get("descanso_cadeira",-1))
			if not jogo.planta.objetos.has(id):voltar(a);continue
			a.assento=id;jogo.planta.objetos[id].reserva=a.identificador
			a.trabalho="descansar";a.energia=minf(100.0,a.energia+tempo*1.4)
			if a.energia>=95.0:voltar(a)
		elif fase.is_empty() and (jogo.operacao.aberto or a.visita.get("turno_noturno",false)) and not a.visita.get("fora_turno",false) and not a.visita.get("saindo_fechamento",false):
			if trabalhando(a):a.energia=maxf(0,a.energia-tempo*(.03 if a.visita.has("caixa_cadeira") else .07))
			if a.energia<25.0 and not a.ocupado() and (not ControleAdministradorPlex.ocupado(a) or a.visita.get("estudando",false)) and not jogo.servicos.trabalhos.has(a.identificador):descansar(a,false)

func sair(a:PersonagemPlex) -> void:
	liberar_cadeira(a);jogo.controle.interromper(a);a.visita.saindo_fechamento=true;a.visita.turno_etapa="ir_trocar_saida";a.visita.turno_tempo=0.0;a.automatico=false
	jogo.equipamentos.ponto.iniciar(a,false)

func comecar_turno(a:PersonagemPlex) -> bool:
	if not funcionario(a):return false
	if a.visita.get("contrato_noturno",false) and not jogo.sistemas.guarda.escala.ativo(a,jogo.calendario.dias,jogo.calendario.minutos):
		jogo.painel.mensagem("O segurança comparece no horário contratado.");return false
	if ocupado(a) and not a.visita.get("fora_turno",false):voltar(a)
	if not a.visita.get("fora_turno",false) and a.visita.get("turno_iniciado",false) and TerrenoPlex.contem(jogo.planta,a.celula):a.show();return true
	a.visita.turno_manual=true;chegada(a,0);return true
func acabar_turno(a:PersonagemPlex) -> void:
	if funcionario(a) and not a.visita.get("fora_turno",false):a.visita.turno_manual=false;sair(a)

func liberar_vestiario(a:PersonagemPlex) -> void:
	var fila_id:=int(a.visita.get("turno_fila_armario",-1))
	if filas.has(fila_id):filas[fila_id].erase(a.identificador)
	a.visita.erase("turno_fila_armario");a.visita.erase("vestiario_ordem");liberar_espera(a)
	var id:=int(a.visita.get("turno_armario",-1))
	var item:Dictionary=jogo.planta.objetos.get(id,{})
	if not item.is_empty() and int(item.get("reserva",0))==a.identificador:item.reserva=0
	a.visita.erase("turno_armario")
func obter_vez(a:PersonagemPlex,id:int) -> bool:
	var item:Dictionary=jogo.planta.objetos.get(id,{})
	if item.is_empty():liberar_vestiario(a);return false
	var fila:Array=filas.get(id,[]).filter(func(n):return is_instance_valid(jogo.clientes.ator(int(n))) and int(jogo.clientes.ator(int(n)).visita.get("turno_fila_armario",-1))==id and not jogo.clientes.ator(int(n)).visita.get("fora_turno",false) and not jogo.clientes.ator(int(n)).visita.get("morto",false))
	if not fila.has(a.identificador):
		ordem_fila+=1;a.visita.turno_fila_armario=id;a.visita.vestiario_ordem=ordem_fila;fila.append(a.identificador)
	filas[id]=fila
	var reserva:=int(item.get("reserva",0));var dono:PersonagemPlex=jogo.clientes.ator(reserva)
	if reserva!=0 and (not is_instance_valid(dono) or dono.visita.get("fora_turno",false) or dono.visita.get("morto",false) or dono.visita.get("demitido",false)):
		item.reserva=0;reserva=0
	if reserva==a.identificador or (reserva==0 or not is_instance_valid(dono)) and int(fila[0])==a.identificador:
		item.reserva=a.identificador;a.visita.turno_armario=id;liberar_espera(a);return true
	esperar_vestiario(a,item)
	return false

func liberar_espera(a:PersonagemPlex) -> void:
	var id:=int(a.visita.get("vestiario_cadeira",-1))
	if jogo.planta.objetos.has(id) and int(jogo.planta.objetos[id].get("reserva",0))==a.identificador:jogo.planta.objetos[id].reserva=0
	if a.visita.get("fila_aguardando",false):a.movimento.cancelar();a.assento=-1
	for campo in ["vestiario_cadeira","vestiario_destino","fila_aguardando"]:a.visita.erase(campo)

func esperar_vestiario(a:PersonagemPlex,item:Dictionary) -> void:
	if not a.visita.get("fila_aguardando",false):a.movimento.cancelar();a.visita.fila_aguardando=true
	a.trabalho="aguardar_vestiario"
	if a.ocupado():return
	if a.visita.has("vestiario_destino"):
		var dados:Array=a.visita.vestiario_destino;var c:=Vector2i(dados[0],dados[1]);var cadeira:=int(a.visita.get("vestiario_cadeira",-1))
		if cadeira>=0 and not jogo.planta.objetos.has(cadeira):liberar_espera(a);return
		if not jogo.planta.transitavel(c):liberar_espera(a);return
		if a.celula==c:
			if cadeira>=0:a.assento=cadeira;a.direcao=GradePlex.direcao_suporte(int(jogo.planta.objetos[cadeira].rotacao))
			return
		var rota:Array[Vector2i]=jogo.rotas.caminho(a.origem_rota(),c)
		if not rota.is_empty():a.andar(rota)
		return
	var sala:Dictionary=jogo.ambientes.do_objeto(int(item.id))
	var frente:=PontosUsoPlex.frente(item)
	for cadeira in cadeiras():
		if int(cadeira.get("reserva",0))!=0 or jogo.ambientes.do_objeto(int(cadeira.id)).get("id",-1)!=sala.get("id",-2):continue
		var rota:Array[Vector2i]=jogo.rotas.aproximar(a.origem_rota(),int(cadeira.id))
		if rota.is_empty() or rota[-1]==frente:continue
		if sala.get("celulas",{}).has(a.celula) and rota.any(func(c):return not sala.celulas.has(c)):continue
		cadeira.reserva=a.identificador;a.visita.vestiario_cadeira=cadeira.id;a.visita.vestiario_destino=[rota[-1].x,rota[-1].y];a.andar(rota);return
	var candidatos:Array[Vector2i]=[]
	for c in sala.get("celulas",{}):
		if Vector2(c).distance_to(Vector2(item.celula))>4.5 or c==frente or not jogo.planta.transitavel(c):continue
		if jogo.personagens.any(func(p):return p!=a and (p.celula==c or p.visita.get("vestiario_destino",[])==[c.x,c.y])):continue
		candidatos.append(c)
	candidatos.sort_custom(func(x,y):return x.distance_squared_to(a.celula)<y.distance_squared_to(a.celula))
	for c in candidatos:
		var rota:Array[Vector2i]=jogo.rotas.caminho(a.origem_rota(),c)
		if rota.is_empty() or sala.get("celulas",{}).has(a.celula) and rota.any(func(tile):return not sala.celulas.has(tile)):continue
		a.visita.vestiario_destino=[c.x,c.y];a.andar(rota);return

func trabalhando(a:PersonagemPlex) -> bool:
	return jogo.servicos.trabalhos.has(a.identificador) or jogo.tarefas.trabalhos.has(a.identificador) or a.trabalho in ["estudar","montar","reparar","preparar","lavar","varrer","esfregar","usar_caixa","vigiar_ibm","ronda","ronda_noturna","abordar_invasor","usar_gerador","ir_ligar_gerador","animar_visitantes"]

static func recuperar_descanso(a:PersonagemPlex) -> void:
	a.energia=100.0
	for necessidade in ["banheiro","higiene","lazer"]:a.necessidades[necessidade]=100.0

func afastar_armario(a:PersonagemPlex,id:int) -> void:
	if a.visita.get("controle_manual",false) or a.ocupado():return
	var item:Dictionary=jogo.planta.objetos.get(id,{})
	if item.is_empty():return
	var sala:Dictionary=jogo.ambientes.do_objeto(id)
	var opcoes:Array[Vector2i]=[]
	var alternativas:Array[Vector2i]=[]
	for y in range(item.celula.y-6,item.celula.y+7):
		for x in range(item.celula.x-6,item.celula.x+7):
			var c:=Vector2i(x,y)
			if Vector2(c).distance_to(Vector2(item.celula))<2 or Vector2(c).distance_to(Vector2(item.celula))>6 or not TerrenoPlex.contem(jogo.planta,c) or not jogo.planta.transitavel(c):continue
			if jogo.planta.em(c).get("tipo","") in CatalogoPlex.PORTAS or jogo.personagens.any(func(p):return p!=a and (p.origem_rota()==c or p.visita.get("vestiario_destino",[])==[c.x,c.y])):continue
			if sala.get("celulas",{}).has(c):opcoes.append(c)
			elif jogo.ambientes.em(c).get("tipo","livre") in ["livre","circulacao","salao","recepcao","descanso","vestiario"]:alternativas.append(c)
	opcoes.shuffle();alternativas.shuffle();opcoes.append_array(alternativas)
	for c in opcoes:
		var rota:Array[Vector2i]=jogo.rotas.caminho(a.origem_rota(),c)
		if rota.is_empty():continue
		a.andar(rota);a.trabalho="sair_vestiario";return

class_name EquipamentosAmbientesPlex
extends RefCounted

var jogo:Node
var ponto:PontoEquipePlex
var espera:=0.0
var tempo:=0.0
var ultimo_dia_chuva:=-100
var diagnostico_ui:DiagnosticoRobosPlex
func _init(cena:Node) -> void:jogo=cena;ponto=PontoEquipePlex.new(cena)
func sala_lado(p:Dictionary,atras:bool=false) -> Dictionary:
	var frente:=GradePlex.frente(int(p.rotacao))*(-1 if atras else 1)
	return jogo.ambientes.em(p.celula+frente)
func livro_perto() -> bool:
	for p in jogo.planta.objetos.values():
		if p.tipo!="amb_livro_reservas" or ApoiosPlex.portador(jogo.planta,int(p.id))>0:continue
		var pos:=ApoiosPlex.posicao(jogo.planta,p)
		for balcao in jogo.planta.objetos.values():
			if CatalogoPlex.base(str(balcao.tipo))!="balcao":continue
			var b:=ApoiosPlex.posicao(jogo.planta,balcao)
			if Vector2(pos.x,pos.y).distance_to(Vector2(b.x,b.y))<=3 and VisaoNPCPlex.linha(jogo.planta,Vector2(pos.x,pos.y),Vector2(b.x,b.y)):return true
	return false
func pedidos_festa() -> int:return jogo.servicos.aniversarios.filter(func(p):return p.get("estado","") in ["solicitado","reservado","comprado"]).size()
func gerador_do_quadro(quadro:Dictionary) -> Dictionary:
	var sala:=sala_lado(quadro)
	var lista:Array=jogo.planta.objetos.values().filter(func(p):return MobiliaPlex.dados(p).get("gerador",false))
	lista.sort_custom(func(a,b):return Vector2(a.celula).distance_squared_to(Vector2(quadro.celula))<Vector2(b.celula).distance_squared_to(Vector2(quadro.celula)))
	for p in lista:
		var mesma:bool=sala.get("fechada",false) and jogo.ambientes.do_objeto(int(p.id)).get("id",-1)==sala.get("id",-2)
		if mesma or Vector2(p.celula).distance_to(Vector2(quadro.celula))<=3 and VisaoNPCPlex.linha(jogo.planta,Vector2(quadro.celula)+Vector2(GradePlex.frente(int(quadro.rotacao)))*.6,Vector2(p.celula)):return p
	return {}
func solicitar_energia(gerador:int=-1,quadro:int=-1,manual:bool=true) -> bool:
	for q in jogo.planta.objetos.values():
		if q.tipo!="amb_quadro_energia" or quadro>=0 and int(q.id)!=quadro:continue
		var g:=gerador_do_quadro(q)
		if g.is_empty() or gerador>=0 and int(g.id)!=gerador or float(g.get("combustivel",0))<=0:continue
		q.religar_pendente=true
		return true
	if manual:jogo.painel.mensagem("Coloque uma caixa de energia acessível perto do gerador ou na mesma sala. O gerador precisa ter combustível.")
	return false
func liberar_energia(a:PersonagemPlex,q:Dictionary={}) -> void:
	if int(q.get("reserva",0))==a.identificador:q.reserva=0
	for chave in ["reativar_gerador","energia_alvo","energia_tempo"]:a.visita.erase(chave)
	a.trabalho=""
func atualizar_energia(dt:float) -> void:
	for pessoa in jogo.personagens:
		if pessoa.visita.get("reativar_gerador",false) and jogo.planta.objetos.get(int(pessoa.visita.get("energia_alvo",-1)),{}).get("tipo","")!="amb_quadro_energia":liberar_energia(pessoa)
	for q in jogo.planta.objetos.values():
		if q.tipo!="amb_quadro_energia":continue
		var g:=gerador_do_quadro(q)
		if g.is_empty():q.erase("religar_pendente");continue
		var precisa:bool=not g.get("ligada",true) or g.get("reinicio_pendente",false)
		if not precisa or float(g.get("combustivel",0))<=0:
			var antigo:PersonagemPlex=jogo.clientes.ator(int(q.get("reserva",0)))
			if is_instance_valid(antigo) and antigo.visita.get("reativar_gerador",false):liberar_energia(antigo,q)
			q.religar_pendente=false;continue
		q.religar_pendente=true
		var a:PersonagemPlex=jogo.clientes.ator(int(q.get("reserva",0)))
		if is_instance_valid(a) and (a.visita.get("fora_turno",false) or a.visita.get("morto",false) or a.visita.get("controle_manual",false) or TurnosEquipePlex.ocupado(a)):liberar_energia(a,q);a=null
		if not is_instance_valid(a):
			var candidatos:Array=jogo.personagens.filter(func(p):return p.cargo=="funcionario" and not p.robo and (not p.ocupado() or p.funcao=="seguranca") and not p.visita.get("paralisado",false) and not p.visita.get("fora_turno",false) and not p.visita.get("saindo_fechamento",false) and not p.visita.get("morto",false) and not p.visita.get("obra_atracao",false) and not ControleAdministradorPlex.ocupado(p) and not jogo.servicos.trabalhos.has(p.identificador) and not jogo.tarefas.trabalhos.has(p.identificador))
			candidatos.sort_custom(func(x,y):return (0 if x.funcao=="seguranca" else 1 if AdministradorPlex.eh(x) else 2)<(0 if y.funcao=="seguranca" else 1 if AdministradorPlex.eh(y) else 2))
			for p in candidatos:
				var rota:Array[Vector2i]=jogo.rotas.aproximar(p.origem_rota(),int(q.id))
				if rota.is_empty():continue
				if p.funcao=="seguranca":jogo.sistemas.guarda.forcar_energia(p)
				a=p;q.reserva=a.identificador;a.visita.reativar_gerador=true;a.visita.energia_alvo=q.id;a.visita.energia_tempo=0.0;a.andar(rota);a.trabalho="ir_ligar_quadro";break
		if not is_instance_valid(a) or a.ocupado() or a.visita.get("paralisado",false):continue
		if not jogo.planta.interacoes(int(q.id)).has(a.celula):
			var rota:Array[Vector2i]=jogo.rotas.aproximar(a.origem_rota(),int(q.id))
			if not rota.is_empty():a.andar(rota);a.trabalho="ir_ligar_quadro"
			else:liberar_energia(a,q)
			continue
		q.estado="aberta";a.trabalho="usar_gerador";jogo.tarefas.orientar(a,Vector2(q.celula));a.visita.energia_tempo=float(a.visita.get("energia_tempo",0))+dt
		if float(a.visita.energia_tempo)>=2.5:
			g.reinicio_pendente=false;g.ligada=true;q.religar_pendente=false;q.estado="grande";liberar_energia(a,q);jogo.iluminacao.rede.atualizar();jogo.planta.alterada.emit()
func abrir_diagnostico(id:int) -> void:
	if not is_instance_valid(diagnostico_ui):diagnostico_ui=DiagnosticoRobosPlex.new();jogo.add_child(diagnostico_ui);diagnostico_ui.configurar(jogo)
	diagnostico_ui.abrir(id)
func opcoes(menu:CanvasLayer,p:Dictionary) -> void:
	match str(p.tipo):
		"sistema_triturador_residuos":jogo.sistemas.vhs.opcoes(menu,p)
		"amb_painel_diagnostico":menu.adicionar("Testar robô e percursos",func():abrir_diagnostico(int(p.id)))
		"amb_livro_reservas":menu.adicionar("Pedidos de festa · %d"%pedidos_festa(),func():jogo.festas.abrir_referencia("aniversarios"))
		"amb_quadro_energia":
			menu.adicionar("Religar energia",func():solicitar_energia(-1,int(p.id)))
			jogo.sistemas.tempestade.opcoes(menu,p)
		"amb_relogio_ponto":
			menu.adicionar("Horas e pagamentos",abrir_ponto)
			var admin:PersonagemPlex=jogo.controle.administrador()
			if is_instance_valid(admin):menu.adicionar("Bater saída" if admin.visita.get("ponto_ativo",false) else "Bater entrada",func():ponto.iniciar(admin,not admin.visita.get("ponto_ativo",false)))
		"amb_telefone_disco":menu.adicionar("Atender reservas",func():p.estado="fora";jogo.festas.abrir_referencia("aniversarios"))
		"amb_interruptor_antigo":menu.adicionar("Desligar luzes da sala" if p.estado=="ligado" else "Ligar luzes da sala",func():alternar_luzes(p))
		"amb_maquina_fichas":
			menu.adicionar("Reabastecer fichas · $10",func():
				if jogo.editor.cobrar(10):p.fichas=int(p.get("fichas",0))+50)
			FichasPremiosPlex.opcoes(jogo,menu,p)
		"dec_piscina_bolinhas":jogo.sistemas.piscina.opcoes(menu,p)
		"amb_balcao_tickets":menu.adicionar("Abrir troca de tickets" if p.estado=="fechado" else "Fechar troca de tickets",func():p.estado="aberto" if p.estado=="fechado" else "fechado")
	jogo.sistemas.cartazes.opcoes(menu,p)
	LembrancasPlex.opcoes(jogo,menu,p)
func abrir_ponto() -> void:
	var linhas:=PackedStringArray()
	for a in jogo.personagens:
		if not TurnosEquipePlex.funcionario(a):continue
		var minutos:=float(a.visita.get("minutos_folha",0));var valor:=HabilidadesEquipePlex.salario(a)*minutos/FolhaPagamentoPlex.MINUTOS_SEMANA
		var credito:=float(a.visita.get("credito_salario",a.visita.get("contrato_pago",0) if a.visita.get("contrato_noturno",false) else 0))
		linhas.append("%s · %.1f h · $%.2f a receber · %s"%[IdentidadesPlex.completo(a),minutos/60,maxf(0,valor-credito),"Trabalhando" if a.visita.get("ponto_ativo",false) else "Fora do ponto"])
	AvisoPlex.mostrar(jogo,"Ponto da equipe","\n".join(linhas) if not linhas.is_empty() else "Nenhum funcionário contratado.","Fechar","",640)
func alternar_luzes(p:Dictionary) -> void:
	jogo.ambientes.atualizar()
	var sala:=sala_lado(p)
	if not sala.get("fechada",false):return
	var luzes:Array=[]
	for luz in jogo.planta.objetos.values():
		if not LuminariasPlex.eh(str(luz.tipo)):continue
		var local:Dictionary=sala_lado(luz) if LuminariasPlex.tipo(str(luz.tipo))=="luz_parede" else jogo.ambientes.em(luz.celula)
		if local.get("id",-1)==sala.id:luzes.append(luz)
	var ligar:bool=not luzes.any(func(l):return l.get("ligada",true))
	p.estado="ligado" if ligar else "desligado"
	for luz in luzes:LuminariasPlex.definir(jogo.planta,int(luz.id),ligar)
func marca(tipo:String,c:Vector2i,estado:String="pequena",r:int=0,extras:Dictionary={}) -> int:
	if not GradePlex.dentro(c) or not TerrenoPlex.contem(jogo.planta,c):return -1
	if jogo.planta.objetos.values().any(func(p):return p.tipo==tipo and p.celula==c):return -1
	var dados:Dictionary={"estado":estado,"solto":true,"limpeza_apos":jogo.servicos.tempo_servico+15.0};dados.merge(extras,true)
	return jogo.planta.inserir(tipo,c,r,{},dados)
func chao_livre(p:Dictionary) -> Vector2i:
	for c in jogo.planta.interacoes(int(p.id)):
		if jogo.planta.em(c).is_empty() and not jogo.planta.sobre(c).any(func(o):return MobiliaPlex.dados(o).get("entulho",false)):return c
	return Vector2i(-1,-1)
func em_uso(p:Dictionary) -> bool:
	if int(p.get("reserva",0))>0 or int(p.get("familia_cliente",-1))>=0 or p.get("mesa_cozinha",false) and not ApoiosPlex.filhos(jogo.planta,int(p.id)).is_empty():return true
	if FornoPlex.eh(p):return float(p.get("tempo_assar",0))>0 or str(p.get("estado","")) in ["funcionando","aceso"]
	return jogo.personagens.any(func(a):return a.assento==int(p.id) or a.trabalho in ["lavar","preparar","usar_armario","jogar","montar"] and a.local.distance_to(Vector2(p.celula))<1.8)
func desgaste(p:Dictionary,dt:float) -> void:
	var info:=MobiliaPlex.dados(p)
	if info.get("entulho",false) or info.get("bairro",false) or info.get("parede_requerida",false) or p.tipo in SalasPlex.ESTRUTURA or int(p.get("sobre",-1))>=0 or int(p.get("carregada_por",0))>0:return
	if CatalogoPlex.base(str(p.tipo)) not in ["mesa","cadeira","balcao","estante","armario_funcionarios"] and not info.get("ambiente_novo",false):return
	var usado:=em_uso(p);var minutos:=dt*CalendarioPlex.MINUTOS_POR_SEGUNDO
	p.tempo_colocado=float(p.get("tempo_colocado",0))+minutos;p.tempo_sem_uso=0.0 if usado else float(p.get("tempo_sem_uso",0))+minutos
	if usado:p.tempo_usado=float(p.get("tempo_usado",0))+minutos
	var celula:Array=[p.celula.x,p.celula.y];var anterior:Array=p.get("ultima_celula_uso",celula)
	if anterior!=celula and float(p.tempo_colocado)>=7*1440:
		marca("amb_marcas_moveis",Vector2i(anterior[0],anterior[1]),"cadeira" if CatalogoPlex.base(str(p.tipo))=="cadeira" else "mesa" if LugaresPlex.mesa(str(p.tipo)) else "armario",int(p.rotacao))
	p.ultima_celula_uso=celula
	var estados:Array=info.get("estados",[])
	if float(p.tempo_sem_uso)>=21*1440 and estados.has("abandonado"):p.estado="abandonado"
	elif float(p.get("tempo_usado",0))>=480 or float(p.tempo_sem_uso)>=3*1440:
		if estados.has("usado") and not FornoPlex.eh(p):p.estado="usado"
		elif estados.has("gasta"):p.estado="gasta"
	if float(p.tempo_sem_uso)>=3*1440 and not p.get("poeira_criada",false):
		var c:=chao_livre(p)
		if c.x>=0 and marca("amb_poeira_piso",c,"pequena")>=0:p.poeira_criada=true
func sujeira_cozinha(dt:float) -> void:
	jogo.ambientes.atualizar()
	for sala in jogo.ambientes.ambientes:
		if not sala.get("fechada",false) or not FuncoesSalaPlex.aceita(sala,["cozinha"]):continue
		var pias:=FuncoesSalaPlex.contar(jogo.planta,sala,"pia")
		var externa:=false
		for o in jogo.planta.objetos.values():
			if o.tipo!="oficina_duto_grade":continue
			var dentro:=false;var fora:=false
			for d in GradePlex.VIZINHOS:
				var vizinha:Dictionary=jogo.ambientes.em(o.celula+d)
				if vizinha.get("id",-1)==sala.id:dentro=true
				if not vizinha.get("fechada",false):fora=true
			if dentro and fora:externa=true
		if pias<2 and not (externa and ultimo_dia_chuva>=jogo.calendario.dias-1):continue
		for c in sala.celulas:
			var achou:=false
			for dir in GradePlex.VIZINHOS:
				var parede:Dictionary=jogo.planta.em(c+dir)
				if CatalogoPlex.base(str(parede.get("tipo","")))!="parede":continue
				parede.umidade_minutos=float(parede.get("umidade_minutos",0))+dt*CalendarioPlex.MINUTOS_POR_SEGUNDO*(pias if pias>=2 else 1)
				if float(parede.umidade_minutos)>=360:
					var rotacao:=0
					for r in 4:
						if GradePlex.frente(r)==-dir:rotacao=r;break
					marca("amb_umidade_parede",parede.celula,"pequena",rotacao)
				achou=true;break
			if achou:break
	for forno in jogo.planta.objetos.values():
		if not FornoPlex.eh(forno):continue
		if float(forno.get("tempo_assar",0))>0:forno.tempo_cozinha=float(forno.get("tempo_cozinha",0))+dt*CalendarioPlex.MINUTOS_POR_SEGUNDO
		if int(forno.get("pizzas_feitas",0))-int(forno.get("gordura_pizzas",0))<4 or float(forno.get("tempo_cozinha",0))<2:continue
		var c:=chao_livre(forno)
		if c.x>=0 and marca("amb_gordura_piso",c,"pequena",int(forno.rotacao),{"forno_fonte":forno.id})>=0:forno.gordura_pizzas=int(forno.pizzas_feitas)
func pegadas() -> void:
	for a in jogo.personagens:
		if a.robo or a.cargo not in ["cliente","crianca","adolescente"] or a.visita.get("morto",false):continue
		var dentro:bool=jogo.ambientes.em(a.celula).get("fechada",false)
		if dentro and not a.visita.get("chuva_dentro",dentro) and ultimo_dia_chuva>=jogo.calendario.dias-1:a.visita.passos_molhados=6
		a.visita.chuva_dentro=dentro
		var anterior:Array=a.visita.get("chuva_celula",[a.celula.x,a.celula.y])
		if dentro and int(a.visita.get("passos_molhados",0))>0 and anterior!=[a.celula.x,a.celula.y]:
			marca("amb_pegadas_piso",a.celula,"par",posmod(floori(float(a.direcao)/2),4),{"chuva_cliente":a.identificador});a.visita.passos_molhados=int(a.visita.passos_molhados)-1
		a.visita.chuva_celula=[a.celula.x,a.celula.y]
func atualizar(delta:float) -> void:
	ponto.atualizar(delta);tempo+=delta;espera+=delta
	if espera<1.0:return
	var dt:=espera;espera=0.0
	if jogo.calendario.previsao()=="Chuva":ultimo_dia_chuva=int(jogo.calendario.dias)
	jogo.ambientes.atualizar();atualizar_energia(dt);pegadas();sujeira_cozinha(dt)
	for p in jogo.planta.objetos.values():
		if p.tipo=="maquina_fliperama" and not MobiliaPlex.visual(p).begins_with("amb_"):
			p.variante="amb_fliperama_estrelar";p.avariada=MobiliaPlex.estado(p) in ["avariado","quebrado","quebrada"];p.estado="avariado" if p.avariada else "desligado"
		if p.tipo=="amb_livro_reservas":p.estado="aberto" if pedidos_festa()>0 else "fechado"
		elif p.tipo=="amb_painel_diagnostico":p.estado="desligado" if jogo.iluminacao.rede.fator<=.05 else "alerta" if jogo.personagens.any(func(a):return a.robo and a.robotica.get("avariado",false) and a.local.distance_to(Vector2(p.celula))<6) else "ligado"
		elif p.tipo=="amb_placas_salas":
			var sala:=sala_lado(p,true);var nome:=str(sala.get("tipo","entrada")).to_upper()
			if nome in ["SALAO_FESTAS","APRESENTACOES"]:nome="SALAO"
			if not sala.get("fechada",false):nome="ENTRADA"
			p.nome_sala=str(sala.get("nome",nome.capitalize()));p.estado=nome if CatalogoPlex.objetos[p.tipo].estados.has(nome) else "ENTRADA"
		elif MobiliaPlex.visual(p).begins_with("amb_fliperama_") or MobiliaPlex.visual(p)=="amb_maquina_premios" or p.tipo=="amb_maquina_fichas":
			p.energia_disponivel=jogo.iluminacao.rede.fator>.05
			if p.get("avariada",false):p.estado="avariado"
			elif p.energia_disponivel and jogo.personagens.any(func(a):return a.trabalho=="jogar" and a.local.distance_to(Vector2(p.celula))<1.8 and jogo.servicos.trabalhos.get(a.identificador,{}).get("reservas",[]).has(p.id)):p.estado="ligado_"+str(posmod(floori(tempo*2),8))
			else:p.estado="desligado"
		if TerrenoPlex.contem(jogo.planta,p.celula):desgaste(p,dt)
func gravar() -> Dictionary:return {"ultimo_dia_chuva":ultimo_dia_chuva}
func restaurar(d:Dictionary) -> void:
	ultimo_dia_chuva=int(d.get("ultimo_dia_chuva",-100));espera=0.0
	if is_instance_valid(diagnostico_ui):diagnostico_ui.fechar()

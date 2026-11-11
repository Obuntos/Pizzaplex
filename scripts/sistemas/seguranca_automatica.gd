class_name GuardaAutonomoPlex
extends RefCounted

var jogo:Node
var escala:=EscalaNoturnaPlex.new()
var espera:=0.0
var terminais:Dictionary={}
var recuperando:=-1
var espera_energia:=0.0
var alerta:="Nenhuma ocorrência."
var inicio_apagao:=-1.0
var trancamentos:=0
const ESPERA_APAGAO=5.0
func agora() -> float:return float(jogo.calendario.dias)*1440.0+jogo.calendario.minutos
func observar_energia() -> void:
	if jogo.iluminacao.rede.fator>.05:
		inicio_apagao=-1.0
		for a in jogo.personagens:
			if a.visita.get("medo_apagao",false):a.visita.erase("medo_apagao");a.emocao.forcada_ate=a.emocao.tempo
			if a.funcao=="seguranca":a.visita.lanterna_equipada=false;a.visita.erase("apagao_verificado");a.visita.erase("apagao_salas")
		return
	if inicio_apagao<0:inicio_apagao=agora()
	for a in jogo.personagens:
		if a.cargo!="funcionario" or a.funcao!="seguranca" or a.visita.get("morto",false) or a.visita.get("fora_turno",false) or a.visita.get("saindo_fechamento",false):continue
		a.visita.lanterna_equipada=true
		if not a.visita.get("medo_apagao",false):
			a.visita.medo_apagao=true;a.emocao.exibir("assustado")
func aguardando_apagao() -> bool:return inicio_apagao>=0 and agora()-inicio_apagao<ESPERA_APAGAO
func _init(cena:Node) -> void:jogo=cena
func em_turno(a:PersonagemPlex) -> bool:
	if a.visita.get("debug_servico",false):return true
	var noturno:=escala.ativo(a,jogo.calendario.dias,jogo.calendario.minutos)
	return noturno if a.visita.get("contrato_noturno",false) else jogo.operacao.aberto or noturno
static func preco_noites(candidato:Dictionary,noites:int) -> int:return ceili(float(candidato.get("salario",90))/7.0)*noites
func contratar_noturno(candidato_id:String,noites:int) -> PersonagemPlex:
	if noites<1 or noites>8 or escala.vigente(jogo.calendario.dias,jogo.calendario.minutos):return null
	var candidato:=RecrutamentoPlex.buscar(jogo,"seguranca",candidato_id)
	if candidato.is_empty():return null
	var custo:=preco_noites(candidato,noites)
	if jogo.servicos.saldo<custo:return null
	var a:PersonagemPlex=jogo.criar_personagem(str(candidato.modelo),Vector2i.ZERO,"funcionario",true,{})
	if not is_instance_valid(a):return null
	a.funcao="seguranca";a.uniforme="seguranca";a.cabelo="curto";a.automatico=false
	a.identidade={"nome":str(candidato.nome),"sobrenome":str(candidato.sobrenome),"apelido":"","idade":30,"sexo":"feminino" if a.modelo=="humana" else "masculino"}
	a.visita.habilidades=candidato.habilidades.duplicate(true);a.visita.contrato_noturno=true;a.visita.contrato_pago=custo
	a.visita.credito_salario=float(custo)
	a.visita.turno_iniciado=true;a.visita.fora_turno=true;a.visita.turno_uniforme="seguranca";a.necessidades.turno=false;a.hide()
	jogo.servicos.saldo=snappedf(jogo.servicos.saldo-custo,.01);RecrutamentoPlex.remover(jogo,"seguranca",candidato_id)
	return a
func disponivel(a:PersonagemPlex) -> bool:
	return a.cargo=="funcionario" and a.funcao=="seguranca" and not a.robo and not a.visita.get("morto",false) and not a.visita.get("fora_turno",false) and not a.visita.get("saindo_fechamento",false) and not TurnosEquipePlex.ocupado(a) and not a.visita.get("controle_manual",false) and em_turno(a)
func terminal_ligado(o:Dictionary) -> bool:return o.get("tipo","")=="terminal_ibm" and o.get("estado","") in ["ligado","uso"] and jogo.iluminacao.rede.fator>.05
func monitorando(a:PersonagemPlex) -> bool:
	var pc:Dictionary=jogo.planta.objetos.get(int(a.visita.get("guarda_terminal",-1)),{})
	return disponivel(a) and a.trabalho=="vigiar_ibm" and not a.ocupado() and terminal_ligado(pc) and em_posto(a,pc)
func escuro(_a:PersonagemPlex) -> bool:
	return jogo.iluminacao.rede.fator<=.05
func fora_do_horario() -> bool:return jogo.calendario.minutos>=1380 or jogo.calendario.minutos<360
func invasor(a:PersonagemPlex) -> bool:
	return (a.visita.get("investigador_invasao",false) or a.funcao=="investigador" and fora_do_horario()) and not a.visita.get("morto",false) and not a.visita.get("expulso",false)
func ouvir(guarda:PersonagemPlex,alvo:PersonagemPlex) -> bool:
	if not invasor(alvo):return false
	var buscando:bool=alvo.visita.get("buscando_registros",false)
	if not alvo.ocupado() and not buscando:return false
	var distancia:float=guarda.local.distance_to(alvo.local)
	if distancia>9:return false
	var forca:=.85 if buscando else .48
	var sinal:float=forca*jogo.sistemas.ambiencia.transmissao(alvo.local,guarda.local,"mexer" if buscando else "passos")/(1.0+distancia*.22)
	return sinal>.12+jogo.sistemas.ambiencia.nivel(guarda.local)*.65
func detectar(a:PersonagemPlex) -> PersonagemPlex:
	for alvo in jogo.personagens:
		if not invasor(alvo):continue
		var visual:bool=VisaoNPCPlex.ve(jogo,a,alvo,7.0)
		if visual or ouvir(a,alvo) or monitorando(a) and camera_atual_ve(a,alvo.local):return alvo
	return null
func liberar_terminal(a:PersonagemPlex) -> void:
	var pc:=int(a.visita.get("guarda_terminal",-1))
	if int(terminais.get(pc,-1))==a.identificador:terminais.erase(pc)
	a.visita.erase("guarda_terminal")
	var cadeira:=int(a.visita.get("guarda_cadeira",-1))
	if jogo.planta.objetos.has(cadeira) and int(jogo.planta.objetos[cadeira].get("reserva",0))==a.identificador:jogo.planta.objetos[cadeira].reserva=0
	a.visita.erase("guarda_cadeira");a.visita.erase("guarda_camera");a.assento=-1
func abordar(a:PersonagemPlex,alvo:PersonagemPlex,tempo:float) -> void:
	liberar_terminal(a);a.visita.guarda_alvo=alvo.identificador;a.visita.guarda_vigiando=true
	if alvo.visita.get("expulso",false):a.visita.erase("guarda_alvo");a.visita.guarda_pausa=0.0;return
	if a.local.distance_to(alvo.local)<1.8 and jogo.controle.incidentes.linha_livre(a.local,alvo.local):
		a.movimento.cancelar();alvo.movimento.cancelar();a.trabalho="abordar_invasor";alvo.trabalho="abordado"
		a.visita.guarda_abordagem=float(a.visita.get("guarda_abordagem",0))+tempo
		if float(a.visita.guarda_abordagem)<2.4:return
		alvo.visita.expulso=true;alvo.visita.erase("buscando_registros");alvo.visita.erase("investigador_invasao")
		var evento:Dictionary=jogo.seguranca.eventos.filter(func(e):return int(e.get("agente",-1))==alvo.identificador).front() if jogo.seguranca.eventos.any(func(e):return int(e.get("agente",-1))==alvo.identificador) else {}
		if not evento.is_empty():evento.fase="saindo";evento.furto_impedido=true
		jogo.sistemas.baloes.exibir(a,"Área restrita. Acompanhe-me até a saída.",5)
		jogo.sistemas.baloes.exibir(alvo,"Estou saindo.",4)
		alerta="Investigador abordado; retirada de registros impedida."
		if fora_do_horario():jogo.sistemas.investigacao.pista("barrado:"+str(alvo.identificador),"Investigador barrado por um segurança durante a madrugada",5)
		jogo.painel.mensagem(alerta);a.visita.erase("guarda_alvo");a.visita.erase("guarda_abordagem");a.visita.guarda_pausa=0.0
	elif not a.ocupado():
		var rota:Array[Vector2i]=jogo.rotas.caminho(a.origem_rota(),alvo.celula)
		if not rota.is_empty():a.andar(rota);a.trabalho="averiguar_ruido"
func cameras() -> Array:
	var lista:Array=jogo.planta.listar("cameras").filter(func(o):return CamerasVigilanciaPlex.instalacao_permitida(jogo,o))
	lista.sort_custom(func(x,y):return int(x.id)<int(y.id))
	return lista
func trocar_camera(a:PersonagemPlex) -> void:
	var lista:=cameras()
	if lista.is_empty():a.visita.erase("guarda_camera");return
	var atual:=int(a.visita.get("guarda_camera",-1))
	if jogo.planta.objetos.has(atual):
		var r:PersonagemPlex=jogo.controle_robo.ator()
		var vendo:bool=is_instance_valid(r) and camera_atual_ve(a,r.local)
		if vendo and agora()-float(a.visita.get("guarda_camera_inicio",agora()))<10.0:return
		if agora()<float(a.visita.get("guarda_camera_ate",0)):return
	var indice:=0
	for i in lista.size():
		if int(lista[i].id)==atual:indice=i+1
	var o:Dictionary=lista[indice%lista.size()]
	var porta:Dictionary=porta_sem_camera(a)
	var portas:=portas_sala(sala_guarda(a))
	if porta.is_empty() and not portas.is_empty():porta=portas[0]
	if not porta.is_empty() and randf()<.35:
		var perto:=lista.duplicate()
		perto.sort_custom(func(x,y):return Vector2(x.celula).distance_to(Vector2(porta.celula))<Vector2(y.celula).distance_to(Vector2(porta.celula)))
		if int(perto[0].id)!=atual:o=perto[0]
	if atual!=int(o.id):a.visita.cameras_vistas=int(a.visita.get("cameras_vistas",0))+1
	a.visita.guarda_camera=int(o.id);a.visita.guarda_camera_inicio=agora();a.visita.guarda_camera_ate=agora()+2.0+randf()*8.0
	if atual!=int(o.id):jogo.sistemas.baloes.exibir(a,"Câmera: "+str(o.get("camera_nome",CamerasVigilanciaPlex.nome(jogo,o))),3)
func camera_vigiada(id:int) -> bool:
	return jogo.personagens.any(func(p):return int(p.visita.get("guarda_camera",-1))==id and monitorando(p))
func camera_atual_ve(a:PersonagemPlex,p:Vector2) -> bool:
	var o:Dictionary=jogo.planta.objetos.get(int(a.visita.get("guarda_camera",-1)),{})
	return not o.is_empty() and jogo.sistemas.investigacao.camera_ve(o,p)
func posto(a:PersonagemPlex) -> bool:
	var id:=int(a.visita.get("guarda_terminal",-1));var pc:Dictionary=jogo.planta.objetos.get(id,{})
	if not pc.is_empty() and terminal_ligado(pc):
		if a.ocupado():return true
		if em_posto(a,pc):
			var cadeira:=cadeira_terminal(pc,a)
			if cadeira>=0:a.assento=cadeira;a.visita.guarda_cadeira=cadeira;jogo.planta.objetos[cadeira].reserva=a.identificador
			a.trabalho="vigiar_ibm";a.visita.guarda_vigiando=true;jogo.tarefas.orientar(a,Vector2(pc.celula));trocar_camera(a)
			return true
		liberar_terminal(a);return false
	liberar_terminal(a)
	for o in jogo.planta.listar("terminais"):
		if not terminal_ligado(o) or terminais.has(o.id):continue
		var cadeira:=cadeira_terminal(o,a,false)
		var rota:Array[Vector2i]=jogo.rotas.aproximar(a.origem_rota(),cadeira if cadeira>=0 else int(o.id))
		if rota.is_empty():continue
		terminais[o.id]=a.identificador;a.visita.guarda_terminal=o.id;a.visita.guarda_pausa=6.0;a.visita.guarda_vigiando=true;a.trabalho="ir_vigiar_ibm";a.andar(rota);return true
	return false
func atualizar(delta:float) -> void:
	espera+=delta
	if espera<.3:return
	var tempo:=espera;espera=0.0
	observar_energia()
	for a in jogo.personagens:
		if a.cargo!="funcionario" or a.funcao!="seguranca" or a.visita.get("morto",false) or a.visita.get("reativar_gerador",false):continue
		var noturno:=escala.ativo(a,jogo.calendario.dias,jogo.calendario.minutos)
		if noturno and not a.visita.get("turno_noturno",false):
			a.visita.turno_noturno=true
			if a.visita.get("fora_turno",false) or a.visita.get("saindo_fechamento",false):jogo.turnos.chegada(a,.5)
		elif not noturno and a.visita.get("turno_noturno",false):
			a.visita.erase("turno_noturno")
			a.visita.erase("noite_trabalhada")
			encerrar_noite(a)
			jogo.turnos.sair(a)
			continue
		var madrugada:bool=jogo.calendario.minutos>=1380.0 or jogo.calendario.minutos<360.0
		if madrugada and disponivel(a):a.visita.noite_trabalhada=true
		elif not madrugada and not noturno and a.visita.get("noite_trabalhada",false):
			a.visita.erase("noite_trabalhada");encerrar_noite(a);jogo.turnos.sair(a);continue
		if not disponivel(a):
			soltar_porta(a);liberar_terminal(a);a.visita.erase("guarda_vigiando")
			a.visita.lanterna_equipada=escuro(a) and not a.visita.get("fora_turno",false) and not a.visita.get("saindo_fechamento",false)
			continue
		a.visita.lanterna_equipada=escuro(a) or agora()<float(a.visita.get("lanterna_ate",0.0))
		if jogo.sistemas.caca.paralisado(a):soltar_porta(a);liberar_terminal(a);a.movimento.cancelar();a.trabalho="paralisado";continue
		if esconderijo(a):continue
		if escuro(a) and aguardando_apagao():
			liberar_terminal(a)
			if a.trabalho!="aguardar_energia":a.movimento.cancelar()
			a.trabalho="aguardar_energia";continue
		var indice:=escala.noite_atual(jogo.calendario.dias,jogo.calendario.minutos)
		if noturno:escala.presencas[str(indice)]=true
		var alvo:PersonagemPlex=jogo.clientes.ator(int(a.visita.get("guarda_alvo",-1)))
		if not is_instance_valid(alvo) or not invasor(alvo):alvo=detectar(a)
		if is_instance_valid(alvo):abordar(a,alvo,tempo);continue
		if reagir_robo(a):continue
		if trancando(a):continue
		if segurando(a):continue
		if checar_robo(a):continue
		if a.trabalho=="descansar":continue
		if a.ocupado():continue
		if escuro(a) and verificar_apagao(a):continue
		if not escuro(a) and ouvir_porta(a):continue
		if not escuro(a) and posto(a):continue
		liberar_terminal(a)
		a.visita.guarda_vigiando=true;a.visita.guarda_pausa=maxf(0,float(a.visita.get("guarda_pausa",0))-tempo)
		if float(a.visita.guarda_pausa)>0:
			var olhar:Array=a.visita.get("guarda_olhar",[a.celula.x,a.celula.y])
			jogo.tarefas.orientar(a,Vector2(olhar[0],olhar[1]));continue
		a.visita.guarda_ciclo=int(a.visita.get("guarda_ciclo",0))+1
		var ponto:Dictionary=jogo.rondas.destino(a,int(a.visita.guarda_ciclo))
		if ponto.is_empty():jogo.rondas.ronda_noturna(a,tempo)
		else:
			a.visita.guarda_olhar=[ponto.olhar.x,ponto.olhar.y];a.andar(jogo.rotas.caminho(a.origem_rota(),ponto.celula));a.trabalho="ronda_noturna" if noturno else "ronda";a.visita.guarda_pausa=6.0
			if noturno:escala.rondas[str(indice)]=int(escala.rondas.get(str(indice),0))+1
func restaurar(d:Dictionary) -> void:
	escala.restaurar(d);terminais.clear();inicio_apagao=float(d.get("inicio_apagao",-1.0))
	for a in jogo.personagens:
		liberar_terminal(a);a.visita.erase("guarda_alvo");a.visita.erase("guarda_vigiando")

func cadeira_terminal(pc:Dictionary,a:PersonagemPlex,exigir_acesso:bool=true) -> int:
	for o in jogo.planta.objetos.values():
		if CatalogoPlex.base(o.tipo)!="cadeira" or not MobiliaPlex.visual(o).begins_with("oficina_cadeira_escritorio_"):continue
		if int(o.get("reserva",0)) not in [0,a.identificador]:continue
		if Vector2(o.celula).distance_to(Vector2(pc.celula))<=2.1 and (not exigir_acesso or jogo.planta.interacoes(o.id).has(a.celula)):return int(o.id)
	return -1

func em_posto(a:PersonagemPlex,pc:Dictionary) -> bool:
	return jogo.planta.interacoes(int(pc.id)).has(a.celula) or cadeira_terminal(pc,a)>=0

func atualizar_energia(_delta:float) -> void:
	observar_energia()

func robo_suspeito(a:PersonagemPlex) -> PersonagemPlex:
	var r:PersonagemPlex=jogo.controle_robo.ator()
	if not is_instance_valid(r):return null
	if r.ocupado() and (VisaoNPCPlex.ve(jogo,a,r,7.0) or monitorando(a) and camera_atual_ve(a,r.local)):return r
	if jogo.controle_robo.tocando(r) and a.local.distance_to(r.local)<=12.0:
		var sinal:float=jogo.sistemas.ambiencia.transmissao(r.local,a.local,"musica")/(1.0+a.local.distance_to(r.local)*.22)
		if sinal>.12+jogo.sistemas.ambiencia.nivel(a.local)*.65:return r
	return null
func checar_robo(a:PersonagemPlex) -> bool:
	var r:PersonagemPlex=jogo.clientes.ator(int(a.visita.get("guarda_robo",-1)))
	if not is_instance_valid(r) or not jogo.controle_robo.controlado(r):
		a.visita.erase("guarda_robo");r=robo_suspeito(a)
		if not is_instance_valid(r):return false
		a.visita.guarda_robo=r.identificador;a.emocao.exibir("assustado")
		jogo.sistemas.baloes.exibir(a,"De novo... esse animatrônico está possuído!" if a.visita.get("viu_robo_mover",false) else "Esse animatrônico... se mexeu?",4)
		a.visita.viu_robo_mover=true
	if not jogo.ambientes.em(a.celula).get("celulas",{}).has(r.celula):return false
	liberar_terminal(a)
	if a.local.distance_to(r.local)<=5.0 and VisaoNPCPlex.ve(jogo,a,r,6.0):
		a.movimento.cancelar();jogo.tarefas.orientar(a,r.local)
		if agora()<float(a.visita.get("lanterna_falhou_ate",0.0)):return true
		if randf()<jogo.sistemas.caca.chance_falha(a):
			a.visita.lanterna_falhou_ate=agora()+2.0;a.trabalho="mirar_lanterna"
			jogo.sistemas.baloes.exibir(a,"*a lanterna pisca e apaga*",3);jogo.sistemas.caca.somar_medo(a,.5);return true
		a.visita.lanterna_ate=agora()+.7;a.visita.lanterna_equipada=true;a.trabalho="mirar_lanterna";jogo.tarefas.orientar(a,r.local)
		jogo.sistemas.baloes.exibir(a,"*aponta a lanterna*",3);a.visita.erase("guarda_robo");jogo.controle_robo.lanterna(r)
		return true
	if not a.ocupado():
		var rota:Array[Vector2i]=jogo.rotas.caminho(a.origem_rota(),r.celula)
		if not rota.is_empty():a.andar(rota);a.trabalho="averiguar_animatronico"
	return true
func pontos_apagao(a:PersonagemPlex) -> Array:
	var centros:Array=[]
	for sala in jogo.ambientes.ambientes:
		if not sala.get("fechada",false):continue
		var livres:Array=sala.celulas.keys().filter(func(c):return jogo.rondas.valido(c))
		if livres.is_empty():continue
		var media:=Vector2.ZERO
		for c in livres:media+=Vector2(c)
		media/=float(livres.size())
		livres.sort_custom(func(x,y):return Vector2(x).distance_squared_to(media)<Vector2(y).distance_squared_to(media))
		centros.append(livres[0])
	var ordem:Array=[];var atual:Vector2i=a.celula
	while not centros.is_empty():
		centros.sort_custom(func(x,y):return atual.distance_squared_to(x)<atual.distance_squared_to(y))
		atual=centros.pop_front();ordem.append([atual.x,atual.y])
	return ordem
func forcar_energia(a:PersonagemPlex) -> void:
	if a.visita.has("escondido"):jogo.sistemas.caca.revelar(a)
	soltar_porta(a)
	for chave in ["escondendo","trancando","ouvindo_porta","ouvindo_ate","guarda_robo","apagao_salas"]:a.visita.erase(chave)
	liberar_terminal(a);a.movimento.cancelar()
	jogo.sistemas.baloes.exibir(a,"A energia caiu... preciso religar, custe o que custar.",4)
func encerrar_noite(a:PersonagemPlex) -> void:
	soltar_porta(a)
	if a.visita.has("escondido"):jogo.sistemas.caca.revelar(a)
	jogo.sistemas.caca.soltar_paralisia(a)
	for chave in ["escondendo","trancando","ouvindo_porta","ouvindo_ate","guarda_robo","apagao_salas","apagao_verificado","cameras_vistas"]:a.visita.erase(chave)
	liberar_terminal(a);a.movimento.cancelar();a.trabalho=""
	jogo.sistemas.baloes.exibir(a,"Fim do turno. Vou para casa.",3)
func religar_pendente() -> bool:
	return jogo.planta.objetos.values().any(func(q):return q.tipo=="amb_quadro_energia" and q.get("religar_pendente",false))
func verificar_apagao(a:PersonagemPlex) -> bool:
	if a.visita.get("apagao_verificado",false):
		if not religar_pendente():return false
		a.trabalho="aguardar_energia";return true
	if not a.visita.has("apagao_salas"):
		a.visita.apagao_salas=pontos_apagao(a);jogo.sistemas.baloes.exibir(a,"Faltou luz. Vou verificar as salas antes do gerador.",4)
	var pendentes:Array=a.visita.apagao_salas
	while not pendentes.is_empty():
		var p:Array=pendentes.pop_front()
		var rota:Array[Vector2i]=jogo.rotas.caminho(a.origem_rota(),Vector2i(int(p[0]),int(p[1])))
		if rota.is_empty():continue
		a.andar(rota);a.trabalho="verificar_apagao";return true
	a.visita.erase("apagao_salas");a.visita.apagao_verificado=true
	jogo.sistemas.baloes.exibir(a,"Tudo verificado. Vou religar o gerador.",4)
	return true
func gravar() -> Dictionary:
	var dados:=escala.gravar();dados.inicio_apagao=inicio_apagao;return dados

func sala_posto(a:PersonagemPlex) -> Dictionary:
	var pc:Dictionary=jogo.planta.objetos.get(int(a.visita.get("guarda_terminal",-1)),{})
	return jogo.ambientes.em(pc.celula+GradePlex.frente(int(pc.rotacao))) if not pc.is_empty() else jogo.ambientes.em(a.celula)
func portas_sala(sala:Dictionary) -> Array:
	var celulas:Dictionary=sala.get("total",sala.get("celulas",{}))
	var lista:Array=[]
	for o in jogo.planta.listar("portas"):
		var frente:=GradePlex.frente(int(o.rotacao))
		for c in jogo.planta.celulas(o.tipo,o.celula,o.rotacao):
			if celulas.has(c+frente) or celulas.has(c-frente):lista.append(o);break
	return lista
func sala_guarda(a:PersonagemPlex) -> Dictionary:
	var sala:Dictionary=jogo.ambientes.em(a.celula)
	return sala if sala.get("fechada",false) else sala_posto(a)
func porta_alvo(sala:Dictionary,porta:Dictionary) -> Vector2i:
	var tiles:Array[Vector2i]=jogo.planta.celulas(porta.tipo,porta.celula,porta.rotacao)
	var meio:Vector2i=tiles[floori(float(tiles.size())*.5)] if not tiles.is_empty() else porta.celula
	var melhor:=Vector2i(-1,-1)
	for d in GradePlex.VIZINHOS:
		var c:Vector2i=meio+d
		if tiles.has(c) or not sala.get("total",sala.get("celulas",{})).has(c) or not jogo.planta.transitavel(c):continue
		if melhor.x<0 or Vector2(c).distance_to(Vector2(meio))<Vector2(melhor).distance_to(Vector2(meio)):melhor=c
	return melhor
func trancar(o:Dictionary) -> bool:
	if o.get("trancada",false) or o.get("arrombada",false):return false
	var tiles:Array[Vector2i]=jogo.planta.celulas(o.tipo,o.celula,o.rotacao)
	if jogo.personagens.any(func(p):return tiles.has(p.celula) or p.movimento.atravessando and tiles.has(p.movimento.destino)):return false
	o.trancada=true;o.aberta=false;trancamentos+=1
	for p in jogo.personagens:
		if p.movimento.rota.any(func(c):return tiles.has(c)):p.movimento.cancelar()
	jogo.planta.alterada.emit()
	return true
func ir_trancar(a:PersonagemPlex,fala:String,perto:Vector2) -> bool:
	if a.visita.has("trancando"):return true
	var sala:=sala_guarda(a);var melhor:Dictionary={}
	for o in portas_sala(sala):
		if o.get("trancada",false) or o.get("arrombada",false):continue
		if melhor.is_empty() or Vector2(o.celula).distance_to(perto)<Vector2(melhor.celula).distance_to(perto):melhor=o
	if melhor.is_empty():return false
	var alvo:=porta_alvo(sala,melhor)
	if alvo.x<0:return false
	var rota:Array[Vector2i]=[]
	if a.celula!=alvo:
		rota=jogo.rotas.caminho(a.origem_rota(),alvo)
		if rota.is_empty():return false
	liberar_terminal(a);a.visita.erase("ouvindo_ate");a.visita.erase("ouvindo_porta")
	a.visita.trancando=int(melhor.id);a.trabalho="trancar_porta"
	if not rota.is_empty():a.andar(rota)
	jogo.sistemas.baloes.exibir(a,fala,4)
	return true
func segurar(a:PersonagemPlex,o:Dictionary) -> void:
	a.visita.segurando_porta=int(o.id);a.visita.segurando_ate=agora()+5.0;a.trabalho="segurar_porta";jogo.tarefas.orientar(a,Vector2(o.celula))
func soltar_porta(a:PersonagemPlex) -> void:
	if not a.visita.has("segurando_porta"):return
	var o:Dictionary=jogo.planta.objetos.get(int(a.visita.segurando_porta),{})
	a.visita.erase("segurando_porta");a.visita.erase("segurando_ate")
	if not o.is_empty() and o.get("trancada",false):o.trancada=false;jogo.planta.alterada.emit()
	if a.trabalho=="segurar_porta":a.trabalho=""
func segurando(a:PersonagemPlex) -> bool:
	if not a.visita.has("segurando_porta"):return false
	if agora()>=float(a.visita.segurando_ate):
		soltar_porta(a);jogo.sistemas.baloes.exibir(a,"Acho que passou... volto para o computador.",3);return false
	var o:Dictionary=jogo.planta.objetos.get(int(a.visita.segurando_porta),{})
	if not o.is_empty():jogo.tarefas.orientar(a,Vector2(o.celula))
	a.trabalho="segurar_porta";return true
func trancando(a:PersonagemPlex) -> bool:
	if not a.visita.has("trancando"):return false
	if a.ocupado():return true
	var o:Dictionary=jogo.planta.objetos.get(int(a.visita.trancando),{})
	a.visita.erase("trancando");a.trabalho=""
	if o.is_empty():return false
	jogo.tarefas.orientar(a,Vector2(o.celula))
	if trancar(o):jogo.sistemas.baloes.exibir(a,"*tranca e segura a porta*",3);segurar(a,o)
	return true
func seguranca_maxima(a:PersonagemPlex) -> void:
	if a.visita.get("seguranca_maxima",false):return
	a.visita.seguranca_maxima=true
	if not ir_trancar(a,"Segurança máxima! Vou trancar a porta.",a.local):jogo.sistemas.baloes.exibir(a,"Aquela carcaça antiga... se mexeu. Segurança máxima!",4)
	alerta="Segurança máxima: o guarda viu a carcaça antiga se mover."
func perto_porta_posto(a:PersonagemPlex,p:Vector2) -> bool:
	for o in portas_sala(sala_guarda(a)):
		if Vector2(o.celula).distance_to(p)<=5.0:return true
	return false
func porta_sem_camera(a:PersonagemPlex) -> Dictionary:
	for o in portas_sala(sala_guarda(a)):
		var coberta:=false
		for cam in cameras():
			if jogo.sistemas.investigacao.camera_ve(cam,Vector2(o.celula)):coberta=true;break
		if not coberta:return o
	return {}
func ouvir_porta(a:PersonagemPlex) -> bool:
	if a.visita.has("ouvindo_porta"):
		var escutando:Dictionary=jogo.planta.objetos.get(int(a.visita.ouvindo_porta),{})
		if escutando.is_empty():a.visita.erase("ouvindo_porta");a.visita.erase("ouvindo_ate");return false
		if a.ocupado():return true
		a.trabalho="ouvir_porta";jogo.tarefas.orientar(a,Vector2(escutando.celula))
		if not a.visita.has("ouvindo_ate"):a.visita.ouvindo_ate=agora()+3.0+float(randi()%4);jogo.sistemas.baloes.exibir(a,"*encosta a orelha na porta*",3)
		if agora()<float(a.visita.ouvindo_ate):return true
		a.visita.erase("ouvindo_ate");a.visita.erase("ouvindo_porta");a.trabalho=""
		jogo.sistemas.baloes.exibir(a,"Nada... volto para o computador.",3)
		return false
	if not monitorando(a) or int(a.visita.get("cameras_vistas",0))<maxi(1,cameras().size()):return false
	a.visita.cameras_vistas=0
	if agora()>float(a.visita.get("alerta_robo_ate",-999.0))+30.0 and randf()>.25:return false
	var sala:=sala_guarda(a)
	var portas:=portas_sala(sala)
	var porta:=porta_sem_camera(a)
	if porta.is_empty() and not portas.is_empty():porta=portas[randi()%portas.size()]
	if porta.is_empty():return false
	var alvo:=porta_alvo(sala,porta)
	if alvo.x<0:return false
	var rota:Array[Vector2i]=[]
	if a.celula!=alvo:
		rota=jogo.rotas.caminho(a.origem_rota(),alvo)
		if rota.is_empty():return false
	liberar_terminal(a);a.trabalho="ouvir_porta";a.visita.ouvindo_porta=int(porta.id)
	if not rota.is_empty():a.andar(rota)
	jogo.sistemas.baloes.exibir(a,"Já olhei todas as câmeras. Vou escutar na porta.",4)
	return true
func esconderijo(a:PersonagemPlex) -> bool:
	var r:PersonagemPlex=jogo.controle_robo.ator()
	if a.visita.has("escondido"):
		var perto:bool=is_instance_valid(r) and r.local.distance_to(a.local)<=8.0
		if perto:a.visita.escondido_calmo=0.0;return true
		a.visita.escondido_calmo=float(a.visita.get("escondido_calmo",0.0))+.3
		if float(a.visita.escondido_calmo)<6.0:return true
		jogo.sistemas.caca.revelar(a);a.trabalho=""
		jogo.sistemas.baloes.exibir(a,"Acho que ele foi embora...",3)
		return false
	if not a.visita.has("escondendo"):return false
	if jogo.sistemas.caca.medo(a)>=CacaAnimatronicosPlex.MEDO_MAX:a.visita.erase("escondendo");a.movimento.cancelar();a.trabalho="";return false
	var o:Dictionary=jogo.planta.objetos.get(int(a.visita.escondendo),{})
	if o.is_empty():a.visita.erase("escondendo");return false
	if a.ocupado():return true
	a.visita.erase("escondendo")
	a.visita.escondido={"objeto":int(o.id),"celula":[a.celula.x,a.celula.y]};a.trabalho="escondido"
	if str(o.tipo).contains("armario"):a.visita.escondido_armario=true;a.visible=false
	else:a.local=Vector2(o.celula);a.celula=o.celula;a.modulate.a=.45
	return true
func esconder(a:PersonagemPlex) -> bool:
	if jogo.sistemas.caca.medo(a)>=CacaAnimatronicosPlex.MEDO_MAX:return false
	soltar_porta(a)
	var melhor:Dictionary={};var rota_melhor:Array[Vector2i]=[]
	for o in jogo.planta.objetos.values():
		if not (str(o.tipo).contains("armario") or CatalogoPlex.base(str(o.tipo))=="mesa") or Vector2(o.celula).distance_to(a.local)>7.0:continue
		if jogo.personagens.any(func(p):return int(p.visita.get("escondido",{}).get("objeto",-1))==int(o.id) or int(p.visita.get("escondendo",-1))==int(o.id)):continue
		var rota:Array[Vector2i]=jogo.rotas.aproximar(a.origem_rota(),int(o.id))
		if rota.is_empty():continue
		if melhor.is_empty() or rota.size()<rota_melhor.size():melhor=o;rota_melhor=rota
	if melhor.is_empty():return false
	liberar_terminal(a);a.visita.escondendo=int(melhor.id);a.andar(rota_melhor);a.trabalho="esconder"
	jogo.sistemas.baloes.exibir(a,"Preciso me esconder!",3)
	return true
func reagir_robo(a:PersonagemPlex) -> bool:
	var r:PersonagemPlex=jogo.controle_robo.ator()
	if not is_instance_valid(r):return false
	var caca:CacaAnimatronicosPlex=jogo.sistemas.caca
	var travado:=caca.medo(a)>=CacaAnimatronicosPlex.MEDO_MAX
	var sala:Dictionary=jogo.ambientes.em(a.celula)
	if sala.get("fechada",false) and sala.get("celulas",{}).has(r.celula) and a.local.distance_to(r.local)<=10.0:
		if a.visita.has("escondendo") or caca.escondido(a):return true
		if not travado and agora()<float(a.visita.get("alerta_robo_ate",0.0)) and esconder(a):
			jogo.sistemas.baloes.exibir(a,"Ele entrou! Preciso me esconder!",3);return true
		caca.paralisar(a);return true
	if a.visita.has("escondendo") or a.visita.has("segurando_porta"):return a.visita.has("escondendo")
	var d:=a.local.distance_to(r.local)
	var na_porta:=a.visita.has("ouvindo_ate")
	var na_camera:bool=monitorando(a) and camera_atual_ve(a,r.local)
	var ve:bool=VisaoNPCPlex.ve(jogo,a,r,7.0) and d<=6.0
	var ouviu:=false
	if r.ocupado() and d<=(10.0 if na_porta else 8.0):
		var sinal:float=.6*jogo.sistemas.ambiencia.transmissao(r.local,a.local,"passos")/(1.0+d*.22)
		var limite:float=.12+jogo.sistemas.ambiencia.nivel(a.local)*.65
		ouviu=sinal>(limite*.5 if na_porta else limite)
	if not (na_camera or ouviu or ve):return false
	a.visita.alerta_robo_ate=agora()+20.0
	if travado:return false
	if na_porta and ouviu:
		var porta:Dictionary=jogo.planta.objetos.get(int(a.visita.get("ouvindo_porta",-1)),{})
		a.visita.erase("ouvindo_ate");a.visita.erase("ouvindo_porta");a.trabalho=""
		if not porta.is_empty() and trancar(porta):jogo.sistemas.baloes.exibir(a,"Passos lá fora! *tranca e segura a porta*",4);segurar(a,porta);return true
	if (na_camera or ouviu) and perto_porta_posto(a,r.local) and ir_trancar(a,"Ele está vindo para cá! Vou trancar a porta.",r.local):return true
	if ouviu and not ve and agora()>=float(a.visita.get("reacao_robo_ate",0.0)):a.visita.reacao_robo_ate=agora()+10.0;caca.somar_medo(a,.3)
	return false

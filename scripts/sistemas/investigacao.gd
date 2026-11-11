class_name InvestigacaoProgressivaPlex
extends RefCounted

var jogo:Node
var desaparecidos:Dictionary={}
var pistas:Dictionary={}
var vestigios:Dictionary={}
var historico:Array=[]
var gravacoes:Array=[]
var suspensoes:Array=[]
var suspeita:=0.0
var espera:=0.0
var ultima_sala:Dictionary={}
var rastros_forjados:=0
var quadro_ponto:Array=[]
var tempo_camera:=0.0
var espera_camera:=0.0
func _init(cena:Node) -> void:jogo=cena
func agora() -> float:return jogo.calendario.dias*1440.0+jogo.calendario.minutos
func ativo() -> bool:return desaparecidos.size()>=2
func nivel() -> int:
	if jogo.seguranca.eventos.any(func(x):return x.tipo=="policial" and x.get("mandado",false) and x.fase!="concluido"):return 4
	if not ativo():return 1 if not desaparecidos.is_empty() else 0
	return 3 if suspeita>=40 else 2
func sala_final(pessoa:String) -> String:
	for i in range(historico.size()-1,-1,-1):
		if str(historico[i].pessoa)==pessoa:return str(historico[i].sala)
	return ""
func avaliar_resposta(e:Dictionary,pergunta:int,valor:String) -> void:
	var chave:="resposta:"+str(e.id)+":"+str(pergunta)
	if pergunta==0 and valor.begins_with("Não me lembro"):pista(chave,"O administrador não soube dizer quando viu "+str(e.nome),4)
	elif pergunta==1:
		var ultima:=sala_final(str(e.vitima))
		if valor.begins_with("No salão") and ultima!="" and ultima not in ["salao","salao_festas"]:pista(chave,"Depoimento contradiz os registros: "+str(e.nome)+" foi visto por último em "+ultima,8)
		elif valor.begins_with("Não sei"):pista(chave,"O administrador não soube dizer onde a pessoa estava",3)
	elif pergunta==2:
		if valor.begins_with("Não percebi") and pistas.keys().any(func(k):return str(k).begins_with("marca:") or str(k).begins_with("odor:")):pista(chave,"O administrador negou sinais já encontrados na inspeção",6)
		elif valor.begins_with("Posso procurar"):suspeita=maxf(0,suspeita-3)
func relatar(id:String,nome:String) -> void:
	if desaparecidos.has(id):return
	desaparecidos[id]={"nome":nome,"quando":agora()}
	if desaparecidos.size()==2:jogo.painel.mensagem("Segundo desaparecimento relatado. A investigação passou a observar registros, funcionários e condições do restaurante.")
func pista(chave:String,descricao:String,peso:float) -> void:
	if not ativo() or pistas.has(chave):return
	pistas[chave]={"descricao":descricao,"peso":peso,"quando":agora()};suspeita=clampf(suspeita+peso,0,100)
func nome_sala(c:Vector2i) -> String:
	var s:Dictionary=jogo.ambientes.em(c)
	return str(s.get("tipo","rua")) if s.get("fechada",false) else "rua"
func camera_ve(o:Dictionary,c:Vector2) -> bool:
	if not CamerasVigilanciaPlex.ligada(o,jogo.iluminacao.rede.fator) or not CamerasVigilanciaPlex.instalacao_permitida(jogo,o) or nome_sala(Vector2i(c.round()))=="banheiro":return false
	return CamerasVigilanciaPlex.area(jogo,o).has(Vector2i(c.round()))
func filmado(c:Vector2) -> bool:
	return jogo.planta.listar("cameras").any(func(o):return camera_ve(o,c))
func registrar_incidente(a:PersonagemPlex) -> void:
	var captado:=false
	for ouvinte in jogo.personagens:
		if ouvinte==a or ouvinte.robo or AdministradorPlex.eh(ouvinte) or ouvinte.visita.get("morto",false) or ouvinte.local.distance_to(a.local)>12:continue
		var sinal:float=jogo.sistemas.ambiencia.transmissao(a.local,ouvinte.local,"grito")/(1.0+a.local.distance_to(ouvinte.local)*.18)
		if sinal>float(jogo.sistemas.ambiencia.nivel(ouvinte.local))+.12:captado=true
	historico.append({"pessoa":SegurancaBairroPlex.chave(a),"nome":IdentidadesPlex.completo(a),"sala":nome_sala(a.celula),"quando":agora(),"incidente":true,"som_captado":captado,"camera":filmado(a.local)})
	vestigios[SegurancaBairroPlex.chave(a)]={"celula":[a.celula.x,a.celula.y],"quando":agora(),"sala":nome_sala(a.celula)}
	while vestigios.size()>100:vestigios.erase(vestigios.keys()[0])
	limitar()
	jogo.sistemas.vhs.incidente(a)
func limitar() -> void:
	while historico.size()>600:historico.pop_front()
	while gravacoes.size()>240:gravacoes.pop_front()
	while quadro_ponto.size()>100:quadro_ponto.pop_front()
func alterar_ponto() -> void:
	if not ativo():jogo.painel.mensagem("Não há registros sob investigação.");return
	if quadro_ponto.is_empty():jogo.painel.mensagem("Nenhum registro de turno disponível.");return
	var registro:Dictionary=quadro_ponto[-1];registro.original=registro.get("original",registro.quando);registro.quando=float(registro.quando)+45;registro.alterado=true
	jogo.painel.mensagem("Registro de turno ajustado no terminal. Outras fontes podem divergir deste horário.")
func falso_rastro() -> void:
	if not ativo():return
	rastros_forjados+=1
	quadro_ponto.append({"pessoa":"registro_manual","sala":"depósito","quando":agora()-60,"alterado":true,"falso":true})
	jogo.painel.mensagem("Um registro manual foi incluído. Ele ainda pode ser confrontado com as câmeras.")
func examinar(e:Dictionary,a:PersonagemPlex) -> void:
	var caso:=str(e.id);var sala:Dictionary=jogo.ambientes.em(a.celula)
	for o in jogo.planta.objetos.values():
		if not VisaoNPCPlex.ve_ponto(jogo,a,Vector2(o.celula),5):continue
		var visual:=MobiliaPlex.visual(o)
		if visual.contains("poca") or visual.contains("sangue"):pista("marca:"+str(o.id),"Marcas observadas na "+nome_sala(o.celula),18)
		if MobiliaPlex.dados(o).get("camera",false):
			jogo.sistemas.vhs.assistir(self)
			for g in gravacoes:
				if desaparecidos.has(str(g.pessoa)):pista("video:"+str(g.pessoa)+":"+str(g.sala),"Gravação: "+str(g.nome)+" entrou em "+str(g.sala),12)
		if LimpezaAmbientesPlex.eh(o):pista("higiene:"+caso,"Condições de limpeza registradas na inspeção",3)
	for r in jogo.personagens:
		if r.robo and r.local.distance_to(a.local)<6 and float(r.robotica.get("cheiro",0))>25:pista("odor:"+str(r.identificador),"Odor e desgaste anormais em um animatrônico",22)
	for id in vestigios:
		var v:Dictionary=vestigios[id];var c:=Vector2(v.celula[0],v.celula[1])
		if a.local.distance_to(c)<4 and agora()-float(v.quando)<8640:pista("desgaste:"+str(id),"Marcas de desgaste incomuns na "+str(v.sala),8)
	for h in historico:
		if not desaparecidos.has(str(h.pessoa)):continue
		if str(h.sala) in ["oficina","banheiro","deposito"]:
			var saida:bool=historico.any(func(x):return x.pessoa==h.pessoa and float(x.quando)>float(h.quando) and str(x.sala) not in ["oficina","banheiro","deposito"] and not x.get("incidente",false))
			if not saida:pista("trajeto:"+str(h.pessoa),"Último trajeto sem saída confirmada: "+str(h.nome),14)
		if h.get("incidente",false) and h.get("som_captado",false):pista("audio:"+str(h.pessoa),"Ruído suspeito no horário de um desaparecimento",10)
	for f in jogo.personagens:
		if f.cargo!="funcionario" or f.robo or AdministradorPlex.eh(f) or f.visita.get("morto",false) or f.local.distance_to(a.local)>4:continue
		f.emocao.exibir("exclamacao")
		if float(f.visita.get("desconfianca",0))>0:
			pista("relato:"+str(f.identificador),"Funcionário relatou marcas incomuns durante o trabalho",15);jogo.sistemas.baloes.exibir(f,"Encontrei marcas estranhas durante a limpeza.",6)
		else:jogo.sistemas.baloes.exibir(f,"Não notei nada fora do normal.",4)
	for registro in quadro_ponto:
		if registro.get("alterado",false) and not gravacoes.is_empty():pista("horario:"+str(registro.get("pessoa","")),"Horários de ponto divergem de outros registros",10)
	if rastros_forjados>0:
		if gravacoes.is_empty():suspeita=maxf(0,suspeita-3);rastros_forjados=0
		else:pista("falso","Registro manual contradiz gravações existentes",12)
	e.inspecoes=int(e.get("inspecoes",0))+1
func apurar(e:Dictionary,a:PersonagemPlex) -> bool:
	if not ativo() or e.tipo!="investigador" or e.get("apurado",false):return false
	if not e.has("roteiro"):
		var pontos:Array=[]
		for o in jogo.planta.objetos.values():
			if not TerrenoPlex.contem(jogo.planta,o.celula):continue
			if o.tipo in ["terminal_ibm","bancada_montagem_coelho","registradora"] or MobiliaPlex.dados(o).get("camera",false):pontos.append(o.id)
		e.roteiro=pontos.slice(0,5);e.parada=0;e.observar=0.0;e.inicio_apuracao=agora()
	if a.visita.get("expulso",false):e.fase="saindo";return true
	if a.visita.get("buscando_registros",false):
		e.tempo_busca=float(e.get("tempo_busca",0))+.5
		if float(e.tempo_busca)<10:return true
		a.visita.erase("buscando_registros")
		if not e.get("furto_impedido",false):e.copia_registros=true
	if not e.get("tentou_registros",false):
		for o in jogo.planta.objetos.values():
			if o.tipo!="terminal_ibm" or not jogo.planta.interacoes(o.id).has(a.celula) or a.ocupado():continue
			e.tentou_registros=true
			if posmod(int(e.id),3)==0:
				a.visita.investigador_invasao=true;a.visita.buscando_registros=true;a.trabalho="procurar_registros";e.tempo_busca=0.0
				jogo.sistemas.baloes.exibir(a,"Vou conferir estes registros...",5);return true
	if int(e.parada)>=e.roteiro.size() or agora()-float(e.inicio_apuracao)>90:
		e.apurado=true;examinar(e,a);return false
	var id:=int(e.roteiro[int(e.parada)])
	if not jogo.planta.objetos.has(id):e.parada=int(e.parada)+1;return true
	if jogo.planta.interacoes(id).has(a.celula) and not a.ocupado():
		a.trabalho="investigar"
		if float(e.observar)==0:
			jogo.sistemas.baloes.exibir(a,"Estou verificando as condições do local.",4)
		e.observar=float(e.observar)+.5
		if float(e.observar)>=4:examinar(e,a);e.parada=int(e.parada)+1;e.observar=0.0
	elif not a.ocupado():
		var rota:Array[Vector2i]=jogo.rotas.aproximar(a.origem_rota(),id)
		if rota.is_empty():pista("obstrucao:"+str(e.id),"Área fechada impediu parte da inspeção",4);e.parada=int(e.parada)+1
		else:
			a.andar(rota);a.trabalho="visita_autoridade"
			if nome_sala(jogo.planta.objetos[id].celula) in ["oficina","deposito","estoque"]:a.visita.investigador_invasao=true
	return true
func concluir(e:Dictionary) -> void:
	if not ativo() or suspeita<75 or not e.get("apurado",false):return
	if jogo.seguranca.eventos.any(func(x):return x.tipo=="policial" and x.fase!="concluido"):return
	var quando:=float(jogo.calendario.dias+1)*1440+540
	jogo.seguranca.eventos.append({"id":jogo.seguranca.proximo,"vitima":e.vitima,"nome":e.nome,"cargo":e.cargo,"tipo":"policial","quando":quando,"fase":"aguardando","agente":-1,"pergunta":0,"respostas":[],"ultima_rota":-1.0,"mandado":true})
	jogo.seguranca.proximo+=1;jogo.painel.mensagem("A investigação reuniu indícios para um mandado. A polícia voltará no próximo dia.")
func observar_trabalhos() -> void:
	if not ativo():return
	for a in jogo.personagens:
		if a.cargo!="funcionario" or a.robo or AdministradorPlex.eh(a) or a.visita.get("morto",false):continue
		if a.trabalho not in ["lavar","esfregar","varrer","montar","reparar"]:continue
		for o in jogo.planta.sobre(a.celula):
			if MobiliaPlex.visual(o).contains("poca"):a.visita.desconfianca=maxf(1,float(a.visita.get("desconfianca",0)))
		for v in vestigios.values():
			if a.local.distance_to(Vector2(v.celula[0],v.celula[1]))<3 and agora()-float(v.quando)>=60:a.visita.desconfianca=maxf(1,float(a.visita.get("desconfianca",0)))
		for r in jogo.personagens:
			if r.robo and r.local.distance_to(a.local)<3 and float(r.robotica.get("cheiro",0))>20:a.visita.desconfianca=maxf(1,float(a.visita.get("desconfianca",0)))
func atualizar(delta:float) -> void:
	atualizar_recolhimento();atualizar_cameras(delta)
	for r in jogo.personagens:
		if not r.robo or int(r.visita.get("corpo_oculto",-1))<0 or r.visita.get("montando_atracao",false):continue
		r.robotica.contaminacao=float(r.robotica.get("contaminacao",0))+delta*CalendarioPlex.MINUTOS_POR_SEGUNDO/1440
		r.robotica.cheiro=minf(100,float(r.robotica.contaminacao)*35)
		if float(r.robotica.cheiro)>65:r.robotica.desgaste=minf(2,float(r.robotica.get("desgaste",0))+delta*.001)
	espera+=delta
	if espera<3:return
	espera=0
	for a in jogo.personagens:
		if a.robo or a.visita.get("morto",false) or not TerrenoPlex.contem(jogo.planta,a.celula):continue
		var id:=SegurancaBairroPlex.chave(a);var sala:=nome_sala(a.celula)
		if ultima_sala.get(id,"")==sala:continue
		ultima_sala[id]=sala
		var r:Dictionary={"pessoa":id,"nome":IdentidadesPlex.completo(a),"sala":sala,"quando":agora()}
		historico.append(r)
		if filmado(a.local):gravacoes.append(r.duplicate())
		if a.cargo=="funcionario":quadro_ponto.append(r.duplicate())
	limitar();observar_trabalhos()
func gravar() -> Dictionary:return {"tempo_camera":tempo_camera,"desaparecidos":desaparecidos,"pistas":pistas,"vestigios":vestigios,"historico":historico,"gravacoes":gravacoes,"suspensoes":suspensoes,"suspeita":suspeita,"rastros_forjados":rastros_forjados,"quadro_ponto":quadro_ponto}
func restaurar(d:Dictionary) -> void:
	tempo_camera=float(d.get("tempo_camera",0));espera_camera=0.0
	vestigios=d.get("vestigios",{}).duplicate(true);desaparecidos=d.get("desaparecidos",{}).duplicate(true);pistas=d.get("pistas",{}).duplicate(true);historico=d.get("historico",[]).duplicate(true);gravacoes=d.get("gravacoes",[]).duplicate(true);suspensoes=d.get("suspensoes",[]).duplicate(true);suspeita=clampf(float(d.get("suspeita",0)),0,100);rastros_forjados=int(d.get("rastros_forjados",0));quadro_ponto=d.get("quadro_ponto",[]).duplicate(true);ultima_sala.clear();limitar()

func guarda_interrompeu(e:Dictionary,a:PersonagemPlex) -> bool:
	if not a.visita.get("expulso",false):return false
	e.fase="saindo";e.furto_impedido=true;return true
func recolher_deposito(r:PersonagemPlex) -> bool:
	return jogo.oficina.recolher(r)
func atualizar_recolhimento() -> void:pass

func atualizar_cameras(delta:float) -> void:
	tempo_camera+=delta;espera_camera+=delta/maxf(.1,jogo.velocidade_tempo)
	if espera_camera<.14:return
	espera_camera=0.0
	for o in jogo.planta.objetos.values():
		if not MobiliaPlex.dados(o).get("camera",false):continue
		var assinatura_nome:=hash([jogo.ambientes.assinatura_estrutura,jogo.animatronicos.palcos.assinatura,o.celula,o.rotacao,jogo.iluminacao.rede.fator>.05])
		if int(o.get("camera_nome_revisao",-1))!=assinatura_nome:o.camera_nome=CamerasVigilanciaPlex.nome(jogo,o);o.camera_nome_revisao=assinatura_nome
		o.camera_ligada=CamerasVigilanciaPlex.ligada(o,jogo.iluminacao.rede.fator)
		if o.camera_ligada:o.camera_quadro=roundi(pingpong(tempo_camera/CamerasVigilanciaPlex.GIRO+float(posmod(int(o.id),7))/7.0,1.0)*12.0)

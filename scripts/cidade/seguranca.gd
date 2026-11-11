class_name SegurancaBairroPlex
extends RefCounted

var jogo:Node
var eventos:Array=[]
var observados:Dictionary={}
var registrados:Dictionary={}
var proximo:=1
var preso:=false
var dialogo:DialogoAutoridadePlex
var espera:=0.0
func _init(cena:Node) -> void:jogo=cena
func agora() -> float:return float(jogo.calendario.dias)*1440.0+float(jogo.calendario.minutos)
static func chave(a:PersonagemPlex) -> String:return str(a.visita.get("morador_id",a.identidade.get("morador_id","pessoa:"+str(a.identificador))))
func aberto() -> bool:return is_instance_valid(dialogo) and not dialogo.is_queued_for_deletion()
func registrar(vitima:PersonagemPlex,testemunhas:Array) -> void:
	var id:=chave(vitima)
	if registrados.has(id):return
	registrados[id]=true;observados.erase(id)
	var e:Dictionary={"id":proximo,"vitima":id,"nome":IdentidadesPlex.completo(vitima),"cargo":vitima.cargo,"tipo":"policial" if not testemunhas.is_empty() else "investigador","quando":agora()+(2.0 if not testemunhas.is_empty() else 60.0),"fase":"aguardando","agente":-1,"pergunta":0,"respostas":[],"ultima_rota":-1.0}
	proximo+=1
	if testemunhas.is_empty():
		registrados.erase(id)
		observados[id]={"chave":id,"nome":IdentidadesPlex.completo(vitima),"cargo":vitima.cargo,"familia":vitima.familia,"ultima":agora(),"ausencia":true,"familiar":true}
	else:eventos.push_front(e);jogo.painel.mensagem("Uma testemunha avisou a polícia. Um policial está a caminho do restaurante.")

func desaparecimento(registro:Dictionary) -> void:
	var id:=str(registro.chave)
	if registrados.has(id):return
	registrados[id]=true
	jogo.sistemas.investigacao.relatar(id,str(registro.nome))
	if not jogo.sistemas.investigacao.ativo():return
	eventos.append({"id":proximo,"vitima":id,"nome":str(registro.nome),"cargo":str(registro.cargo),"tipo":"investigador","quando":agora(),"fase":"aguardando","agente":-1,"pergunta":0,"respostas":[],"ultima_rota":-1.0})
	proximo+=1
	jogo.painel.mensagem("Uma pessoa foi dada como desaparecida. Um investigador virá conversar.")
func saida_normal(a:PersonagemPlex) -> void:
	if not a.visita.get("morto",false):observados.erase(chave(a))
func acompanhar() -> void:
	var presentes:Dictionary={}
	for a in jogo.personagens:
		if a.cargo not in ["cliente","crianca","adolescente","funcionario"] or a.visita.get("morto",false):continue
		var id:=chave(a)
		if registrados.has(id):continue
		presentes[id]=true
		var r:Dictionary=observados.get(id,{"chave":id,"nome":IdentidadesPlex.completo(a),"cargo":a.cargo,"familia":a.familia,"ultima":agora()})
		var familia_original:=int(r.get("familia",a.familia))
		var separado:bool=int(a.visita.get("seguindo_adm",-1))>0 and familia_original>=0 and not jogo.clientes.grupos.has(familia_original)
		if not separado:r.ultima=agora()
		elif agora()-float(r.ultima)>=60.0:desaparecimento(r)
		observados[id]=r
	for id in observados.keys():
		if not presentes.has(id) and agora()-float(observados[id].ultima)>=60.0:desaparecimento(observados[id]);observados.erase(id)
func origem() -> Vector2i:
	if "populacao" in jogo and jogo.populacao!=null:
		var p:Vector2i=jogo.populacao.locais.ponto("delegacia")
		if p.x>=0:return p
	var admin:PersonagemPlex=jogo.controle.administrador()
	if is_instance_valid(admin):return jogo.clientes.saida(admin.origem_rota())
	return Vector2i(-1,-1)
func ator(id:int) -> PersonagemPlex:return jogo.clientes.ator(id)
func chegada(e:Dictionary) -> bool:
	var local:=origem()
	if local.x<0:return false
	var disfarce:bool=e.tipo=="investigador" and not e.get("mandado",false)
	var a:PersonagemPlex=jogo.spawn("humano" if disfarce else "profissao_"+str(e.tipo),local,"autoridade",true)
	if not is_instance_valid(a):return false
	a.funcao=str(e.tipo);a.automatico=false;a.visita.servico_publico=true
	if disfarce:a.uniforme="nenhum";a.cabelo="curto";a.visita.investigador_disfarce=true;a.visita.turno_civil=true
	a.identidade={"nome":"Policial" if e.tipo=="policial" else "Investigador","sobrenome":"","apelido":"","idade":40,"sexo":"masculino"}
	if disfarce:a.identidade.nome="Visitante"
	e.agente=a.identificador;e.fase="chegando"
	jogo.painel.mensagem("Um "+str(e.tipo)+" chegou para apurar o ocorrido.")
	return true
func aproximar(a:PersonagemPlex,admin:PersonagemPlex,e:Dictionary) -> bool:
	if a.local.distance_to(admin.local)<=1.8 and jogo.controle.incidentes.linha_livre(a.local,admin.local):
		a.movimento.cancelar();a.trabalho="investigar" if e.tipo=="investigador" else "servico";jogo.tarefas.orientar(a,admin.local);return true
	if a.ocupado() or agora()-float(e.ultima_rota)<.5:return false
	e.ultima_rota=agora()
	var melhor:Array[Vector2i]=[]
	for d in GradePlex.VIZINHOS:
		var c:Vector2i=admin.origem_rota()+d
		if not jogo.planta.transitavel(c):continue
		var rota:Array[Vector2i]=jogo.rotas.caminho(a.origem_rota(),c)
		if not rota.is_empty() and (melhor.is_empty() or rota.size()<melhor.size()):melhor=rota
	if not melhor.is_empty():a.andar(melhor);a.trabalho="visita_autoridade"
	elif e.tipo=="policial":jogo.sistemas.arrombar(a,e)
	return false
func prender(e:Dictionary) -> void:
	if preso:return
	var admin:PersonagemPlex=jogo.controle.administrador()
	if not is_instance_valid(admin):return
	jogo.controle.cancelar_acao();jogo.controle.seguidores.dispensar_todos();jogo.controle.interromper(admin)
	admin.visita.controle_manual=false;admin.visita.preso=true;admin.visita.faca_equipada=false;admin.automatico=false;admin.trabalho="preso"
	preso=true;e.fase="concluido";jogo.velocidade_tempo=0.0
	mostrar(e,true)
func mostrar(e:Dictionary,prisao:bool=false) -> void:
	if aberto():dialogo.queue_free()
	if "terminal_ui" in jogo:jogo.terminal_ui.fechar()
	if "menu_controle" in jogo:jogo.menu_controle.fechar()
	if "hud" in jogo.painel and jogo.painel.hud!=null:jogo.painel.hud.agenda.hide()
	dialogo=DialogoAutoridadePlex.new();jogo.add_child(dialogo);dialogo.configurar(self,int(e.id),prisao)
func responder(id:int,valor:String) -> void:
	var lista:Array=eventos.filter(func(registro):return int(registro.id)==id)
	if lista.is_empty():return
	var e:Dictionary=lista[0]
	if e.fase!="perguntas":return
	jogo.sistemas.investigacao.avaliar_resposta(e,int(e.pergunta),valor)
	e.respostas.append(valor);e.pergunta=int(e.pergunta)+1
	if int(e.pergunta)>=3:
		e.fase="saindo"
		jogo.sistemas.investigacao.concluir(e)
		if aberto():dialogo.queue_free()
		jogo.painel.mensagem("O investigador terminou as três perguntas e está deixando o restaurante.")
	else:mostrar(e)
func atualizar(delta:float) -> void:
	if preso:return
	espera+=delta
	if espera<.5:return
	espera=0.0;acompanhar()
	var admin:PersonagemPlex=jogo.controle.administrador()
	if not is_instance_valid(admin):return
	for e in eventos:
		if e.fase=="concluido":continue
		if e.fase=="aguardando":
			if e.tipo=="investigador" and not jogo.sistemas.investigacao.ativo():e.fase="concluido";continue
			if e.tipo=="investigador" and (jogo.calendario.minutos<480 or jogo.calendario.minutos>=1080):return
			if agora()>=float(e.quando):chegada(e)
			return
		var a:=ator(int(e.agente))
		if not is_instance_valid(a) or a.visita.get("morto",false):e.fase="aguardando";e.agente=-1;e.quando=agora()+5.0;return
		if e.fase=="chegando" and jogo.sistemas.investigacao.apurar(e,a):return
		if e.fase=="chegando" and jogo.sistemas.investigacao.guarda_interrompeu(e,a):return
		if e.fase=="chegando" and aproximar(a,admin,e):
			if e.tipo=="policial":prender(e)
			else:e.fase="perguntas";mostrar(e)
		elif e.fase=="perguntas" and not aberto():mostrar(e)
		elif e.fase=="saindo":
			var fora:=origem()
			if fora.x<0:return
			if a.celula==fora and not a.ocupado():e.fase="concluido";jogo.despawn(a)
			elif not a.ocupado():
				var rota:Array[Vector2i]=jogo.rotas.caminho(a.origem_rota(),fora)
				if not rota.is_empty():a.andar(rota);a.trabalho="sair_autoridade"
		return
func gravar() -> Dictionary:return {"eventos":eventos,"observados":observados,"registrados":registrados,"proximo":proximo,"preso":preso}
func restaurar(dados:Dictionary) -> void:
	if aberto():dialogo.queue_free()
	eventos=dados.get("eventos",[]).duplicate(true);observados=dados.get("observados",{}).duplicate(true);registrados=dados.get("registrados",{}).duplicate(true);proximo=int(dados.get("proximo",1));preso=bool(dados.get("preso",false))
	if preso and not eventos.is_empty():jogo.velocidade_tempo=0.0;mostrar.call_deferred(eventos[0],true)

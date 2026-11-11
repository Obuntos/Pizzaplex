class_name ControleAdministradorPlex
extends RefCounted

var jogo: Node
var seguidores: SeguidoresAdministradorPlex
var incidentes: IncidentesPlex
var corpos: CorposPlex
var acao: Dictionary={}
var espera:=0.0

func _init(cena: Node) -> void:
	jogo=cena
	seguidores=SeguidoresAdministradorPlex.new(self)
	incidentes=IncidentesPlex.new(self)
	corpos=CorposPlex.new(self)

static func ocupado(a: PersonagemPlex) -> bool:
	return a.visita.get("tutorial_guia",false) or a.visita.get("reativar_gerador",false) or a.visita.get("brincando",false) or int(a.visita.get("show_forcado",-1))>=0 or TurnosEquipePlex.ocupado(a) or a.visita.get("preso",false) or a.visita.get("servico_publico",false) or a.visita.get("estudando",false) or int(a.visita.get("recepcao_grupo",-1))>=0 or a.visita.get("socializando",false) or not str(a.visita.get("rotina_casa_etapa","")).is_empty() or a.visita.get("saindo_fechamento",false) or a.visita.get("fora_turno",false) or a.visita.get("controle_manual",false) or a.visita.get("morto",false) or a.visita.get("fugindo",false) or int(a.visita.get("seguindo_adm",-1))>0

func administrador() -> PersonagemPlex:
	return ator(jogo.operacao.administrador)

func ator(id: int) -> PersonagemPlex:
	return jogo.clientes.ator(id)

func manual() -> bool:
	var a:=administrador()
	return is_instance_valid(a) and bool(a.visita.get("controle_manual",false))

func aviso(texto: String) -> void:
	jogo.painel.mensagem(texto)

func interromper(a: PersonagemPlex) -> void:
	jogo.atracoes.pausar_ator(a)
	jogo.clientes.recepcao.interromper(a)
	if jogo.servicos.trabalhos.has(a.identificador): jogo.servicos.cancelar(a)
	if jogo.tarefas.trabalhos.has(a.identificador): jogo.tarefas.liberar(a)
	if a.carga_item>=0: jogo.servicos.inventario.devolver(a)
	jogo.fantasias.liberar_armario(a)
	for item in jogo.planta.objetos.values():
		if int(item.get("reserva",0))==a.identificador: item.reserva=0
	a.visita.erase("manual_limpeza")
	a.visita.erase("show")
	a.visita.erase("comando_manual_ate")
	a.movimento.cancelar()
	a.assento=-1
	a.carregando=false
	a.progresso_acao=0.0
	a.trabalho=""
	if a.has_meta("limites_rota"): a.remove_meta("limites_rota")

func alternar() -> void:
	var a:=administrador()
	if not is_instance_valid(a): return
	if a.visita.get("preso",false):aviso("O administrador está preso.");return
	if a.visita.get("manual_limpeza",false): interromper(a)
	cancelar_acao()
	if manual():
		corpos.soltar()
		seguidores.dispensar_todos()
		a.visita.controle_manual=false
		a.visita.faca_equipada=false
		a.automatico=bool(a.visita.get("manual_automatico",true))
		a.visita.erase("manual_automatico")
		a.movimento.cancelar()
		a.trabalho=""
		if a.modelo.begins_with("fantasia_"):
			a.visita.fantasia_etapa="passear"
			a.visita.fantasia_tempo=2.0
		aviso("Controle automático restaurado.")
	else:
		jogo.rotina_adm.cancelar(a)
		a.visita.manual_automatico=a.automatico
		interromper(a)
		a.visita.controle_manual=true
		a.automatico=false
		a.trabalho="manual"
		jogo.escolher_ferramenta("selecionar")
		jogo.selecionar(a)
		aviso("Controle manual · Clique no chão para andar. Botão direito abre as interações. Para sair, use novamente Controle manual no administrador.")

func mover(celula: Vector2i) -> bool:
	if not manual(): return false
	cancelar_acao()
	var a:=administrador()
	if a.visita.get("manual_limpeza",false): jogo.servicos.cancelar(a); a.visita.erase("manual_limpeza")
	jogo.rotas.atualizar_atores(jogo.personagens)
	if jogo.rotas.solidos.has(celula) or not jogo.planta.transitavel(celula): return false
	var rota: Array[Vector2i]=jogo.rotas.caminho(a.origem_rota(),celula)
	if rota.is_empty(): aviso("Sem caminho até esse tile."); return false
	a.trabalho="manual"
	a.assento=-1
	a.visita.erase("banco_slot")
	a.andar(rota)
	return true

func cancelar_acao() -> void:
	if acao.get("tipo","")=="montar_atracao":
		var admin:=administrador()
		if is_instance_valid(admin):jogo.atracoes.pausar_ator(admin)
	if acao.get("tipo","")=="limpar_robo":
		var admin:=administrador()
		if is_instance_valid(admin): admin.automatico=bool(acao.get("automatico",true));admin.trabalho="manual" if manual() else ""
	if acao.get("tipo","")=="desembalar":
		var item: Dictionary=jogo.planta.objetos.get(int(acao.get("objeto",-1)),{})
		var a:=administrador()
		if is_instance_valid(a) and item.get("reserva",0)==a.identificador: item.reserva=0
	acao.clear()

func solicitar(tipo: String, alvo: int = -1, objeto: int = -1) -> bool:
	if tipo in ["apresentar","conversar","elogiar","brincar","provocar"]: return jogo.social.iniciar(ator(alvo),tipo)
	if tipo=="seguir": return seguidores.adicionar(ator(alvo))
	if tipo=="dispensar": seguidores.dispensar(ator(alvo));return true
	if tipo=="limpar_robo": return solicitar_limpeza_robo(alvo)
	if tipo=="limpar": return limpar_alvo(objeto)
	if not manual(): return false
	if administrador().visita.get("manual_limpeza",false): interromper(administrador())
	if tipo=="dispensar_todos": seguidores.dispensar_todos(); return true
	if tipo=="soltar_corpo": return corpos.soltar()
	if tipo=="soltar_faca": return largar_faca()
	if tipo=="parar": cancelar_acao(); administrador().movimento.cancelar(); return true
	if tipo=="equipar_faca":
		var a:=administrador()
		if a.visita.has("faca_tipo") and int(a.visita.get("corpo_carregado",-1))<0:
			a.visita.faca_equipada=not a.visita.get("faca_equipada",false)
			return true
		return false
	var pessoa:=ator(alvo)
	if tipo=="dispensar" and is_instance_valid(pessoa): seguidores.dispensar(pessoa); return true
	if tipo=="seguir" and seguidores.lista().size()>=4: aviso("Máximo de quatro acompanhantes."); return false
	if tipo=="desembalar":
		var item: Dictionary=jogo.planta.objetos.get(objeto,{})
		if not EmbalagensMoveisPlex.eh(item) or int(item.get("reserva",0)) not in [0,administrador().identificador]: return false
	cancelar_acao()
	if tipo=="desembalar": jogo.planta.objetos[objeto].reserva=administrador().identificador
	acao={"tipo":tipo,"alvo":alvo,"objeto":objeto,"tempo":0.0,"duracao":3.0 if tipo=="desembalar" else (5.4 if administrador().modelo=="fantasia_coelho" else 1.65) if tipo=="atacar" else 0.5}
	administrador().movimento.cancelar()
	administrador().trabalho="manual"
	return true

func aproximar_pessoa(a: PersonagemPlex, alvo: PersonagemPlex) -> bool:
	if a.local.distance_to(alvo.local)<=1.6 and absf(a.altura-alvo.altura)<10.0 and incidentes.linha_livre(a.local,alvo.local): return not a.ocupado()
	if a.ocupado(): return false
	var melhor: Array[Vector2i]=[]
	for d in GradePlex.VIZINHOS:
		var c: Vector2i=alvo.origem_rota()+d
		if not jogo.planta.transitavel(c): continue
		var rota: Array[Vector2i]=jogo.rotas.caminho(a.origem_rota(),c)
		if not rota.is_empty() and (melhor.is_empty() or rota.size()<melhor.size()): melhor=rota
	if not melhor.is_empty(): a.andar(melhor)
	else: aviso("Não há acesso ao personagem."); cancelar_acao()
	return false

func aproximar_objeto(a: PersonagemPlex, id: int) -> bool:
	if not jogo.planta.objetos.has(id): cancelar_acao(); return false
	if jogo.planta.interacoes(id).has(a.celula) and not a.ocupado(): return true
	if a.ocupado(): return false
	var rota: Array[Vector2i]=jogo.rotas.aproximar(a.origem_rota(),id)
	if not rota.is_empty(): a.andar(rota)
	else: aviso("Libere um acesso ao objeto."); cancelar_acao()
	return false

func concluir(tipo: String, pessoa: PersonagemPlex, id: int) -> void:
	var a:=administrador()
	match tipo:
		"limpar_robo":
			if is_instance_valid(pessoa): PossessaoPlex.limpar(pessoa)
		"desembalar": EmbalagensMoveisPlex.abrir(jogo.planta,id)
		"sentar_banco":
			if not BancosCidadePlex.sentar(a,jogo.planta,id,jogo.personagens): aviso("Os três lugares do banco estão ocupados.")
		"conversar":
			if is_instance_valid(pessoa): aviso(IdentidadesPlex.completo(pessoa)+": “Olá! Estou conhecendo o restaurante.”")
		"seguir": seguidores.adicionar(pessoa)
		"atacar": incidentes.atacar(pessoa)
		"carregar": corpos.pegar(pessoa)
		"ocultar":
			if not corpos.ocultar(pessoa): aviso("Este animatrônico não está disponível ou já contém um corpo.")
		"pegar_faca":
			var item: Dictionary=jogo.planta.objetos.get(id,{})
			if item.get("tipo","")!="cenario_faca_cozinha": return
			if int(a.visita.get("corpo_carregado",-1))>0: aviso("Solte o corpo antes de pegar a faca."); return
			if a.visita.has("faca_tipo"): aviso("Largue a faca que está carregando antes de pegar outra."); return
			a.visita.faca_tipo=item.tipo
			a.visita.faca_equipada=true
			jogo.planta.remover(id)
			a.atualizar_visual(a.ocupado())
			aviso("Faca equipada.")
		"vestir","retirar_fantasia":
			a.visita.fantasia_armario=id
			ArmariosPlex.estado(jogo.planta,id,true)
			if tipo=="retirar_fantasia": jogo.fantasias.retirar(a)
			else: jogo.vestiario_ui.abrir()

func atualizar_acao(delta: float) -> void:
	if acao.get("tipo","")=="montar_atracao":return
	if acao.is_empty() or not manual() and acao.get("tipo","")!="limpar_robo": return
	var a:=administrador()
	var tipo:=str(acao.tipo)
	var pessoa:=ator(int(acao.alvo))
	var objeto:=int(acao.objeto)
	if objeto<0 and not is_instance_valid(pessoa): cancelar_acao(); return
	var chegou:=aproximar_objeto(a,objeto) if objeto>=0 else aproximar_pessoa(a,pessoa)
	if not chegou or acao.is_empty(): return
	if is_instance_valid(pessoa): jogo.tarefas.orientar(a,pessoa.local)
	else: jogo.tarefas.orientar(a,Vector2(jogo.planta.objetos[objeto].celula))
	acao.tempo=float(acao.tempo)+delta
	a.visita.gesto_manual=tipo
	a.trabalho="lavar" if tipo=="limpar_robo" else "montar" if tipo in ["atacar","carregar","ocultar","pegar_faca","desembalar"] else "manual"
	a.progresso_acao=clampf(float(acao.tempo)/float(acao.duracao),0.0,1.0)
	if float(acao.tempo)<float(acao.duracao): return
	cancelar_acao()
	concluir(tipo,pessoa,objeto)
	a.visita.erase("gesto_manual")
	if a.trabalho!="sentar_banco": a.trabalho="manual" if manual() else ""
	a.progresso_acao=0.0

func atualizar(delta: float) -> void:
	var a:=administrador()
	if is_instance_valid(a) and acao.is_empty(): a.visita.erase("gesto_manual")
	if is_instance_valid(a) and a.visita.get("manual_limpeza",false):
		if jogo.servicos.trabalhos.has(a.identificador): jogo.servicos.atualizar_trabalho(a,jogo.servicos.trabalhos[a.identificador],delta)
		else: a.visita.erase("manual_limpeza"); a.trabalho="manual"
	atualizar_acao(delta)
	seguidores.atualizar(delta)
	incidentes.atualizar(delta)

func removendo(a: PersonagemPlex) -> void:
	if int(a.visita.get("corpo_carregado",-1))>0: corpos.soltar()
	var corpo:=ator(int(a.visita.get("corpo_oculto",-1)))
	if is_instance_valid(corpo):
		corpo.visita.erase("oculto_em")
		corpo.local=a.local
		corpo.celula=a.celula
		corpo.altura=a.altura
	if AdministradorPlex.eh(a): seguidores.dispensar_todos()

func limpar() -> void:
	cancelar_acao()
	corpos.limpar()

func largar_faca() -> bool:
	var a:=administrador()
	if not manual() or not a.visita.has("faca_tipo"): return false
	var tipo:=str(a.visita.faca_tipo)
	var locais: Array[Vector2i]=[a.celula]
	for lado in GradePlex.VIZINHOS: locais.append(a.celula+lado)
	for c in locais:
		if not jogo.planta.pode_colocar(tipo,c,0): continue
		jogo.planta.colocar(tipo,c,0)
		a.visita.erase("faca_tipo")
		a.visita.erase("faca_equipada")
		a.atualizar_visual(a.ocupado())
		aviso("Faca colocada no restaurante.")
		return true
	aviso("Não há espaço para largar a faca neste local.")
	return false

func limpar_alvo(id: int) -> bool:
	var a:=administrador()
	if not is_instance_valid(a) or a.visita.get("morto",false) or int(a.visita.get("corpo_carregado",-1))>0: return false
	var era_manual:=manual()
	jogo.rotina_adm.cancelar(a)
	interromper(a)
	cancelar_acao()
	if not era_manual and a.modelo.begins_with("fantasia_"): jogo.fantasias.retirar(a)
	a.visita.controle_manual=false
	var iniciou: bool=jogo.servicos.limpar_alvo(a,id)
	a.visita.controle_manual=era_manual
	if iniciou:
		if era_manual: a.visita.manual_limpeza=true
		else: a.automatico=true
		a.visita.faca_equipada=false
	else: aviso("É preciso ter a ferramenta livre e passagem até a sujeira. Verifique também o acesso ao armário.")
	return iniciou


func solicitar_limpeza_robo(id: int) -> bool:
	var a:=administrador()
	var robo:=ator(id)
	if not is_instance_valid(a) or not is_instance_valid(robo) or not robo.robo or not robo.robotica.get("sangrando",false) or a.visita.get("morto",false) or int(a.visita.get("corpo_carregado",-1))>0: return false
	cancelar_acao()
	jogo.rotina_adm.cancelar(a)
	interromper(a)
	acao={"tipo":"limpar_robo","alvo":id,"objeto":-1,"tempo":0.0,"duracao":5.0,"automatico":a.automatico}
	a.automatico=false
	a.visita.faca_equipada=false
	return true

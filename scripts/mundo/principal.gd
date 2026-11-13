extends Node2D

const TIPOS_REMOVIDOS=["amb_riscos_arrasto","dec_bolinhas_espalhadas","oficina_duto_cruz","oficina_duto_curva","oficina_duto_linha","oficina_duto_quina","oficina_duto_reto","oficina_duto_t","oficina_duto_vertical","oficina_fita_perigo_1","oficina_fita_perigo_3","oficina_papeis_formularios","oficina_placa_voltagem_haste","oficina_placa_voltagem_horizontal","antigo_armario_duplo"]
var ctrl_consumido:=false
var apagando:=false
var apagada_ultima:=Vector2i(-1,-1)
var remocoes_traco:Dictionary={}
var folha_pagamento:=FolhaPagamentoPlex.new()

const CENA_PERSONAGEM = preload("res://cenas/personagens/personagem.tscn")
const VISUAIS_DIRETOS = ["luz_teto","luz_parede","luz_chao","luz_teto_economica","luz_parede_economica","luz_chao_economica","pose","pose_quebrado","pose_montagem"]
const CENA_OBJETO = preload("res://cenas/objetos/objeto.tscn")
var planta := PlantaPlex.new()
var rotas: RotasPlex
var editor: EditorPlex
var tarefas: TarefasPlex
var portas := PortasPlex.new()
var personagens: Array = []
var visuais: Dictionary = {}
var chao := ChaoPlex.new()
var limites_terreno := LimitesTerrenoPlex.new()
var composicao := CenaPlex.new()
var mundo := Node2D.new()
var sombras_itens:=SombrasItensPlex.new()
var sombras_luzes := Node2D.new()
var camera := Camera2D.new()
var cursor := CursorPlex.new()
var painel := PainelPlex.new()
var selecionado: PersonagemPlex
var nivel_paredes: int = 4
var proximo_personagem: int = 1
var arrastando: bool = false
var espera_palco: float = 0.0
var poses: PosesPlex
var iluminacao: IluminacaoPlex
var luz_selecionada: int = -1
var cortar_frente: bool = true
var traco_parede := TracoParedePlex.new()
var saida_montagem: SaidaMontagemPlex
var ambientes: AmbientesPlex
var servicos: ServicosPlex
var atendimento: CaixaPlex
var rondas: RondasPlex
var animatronicos: AnimatronicosPlex
var lazer: LazerPlex
var cortinas: CortinasPalcoPlex
var festas: FestasRestaurantePlex
var clientes: ClientesPlex
var compras: ComprasPlex
var quebrados: DestinosQuebradosPlex
var terminal_ui := TerminalUIPlex.new()
var janelas_moveis:=JanelasMoveisPlex.new()
var livro:=LivroAtracoesPlex.new(self)
var atracoes:=MontagemAtracoesPlex.new(self)
var oficina:=OficinaRobosPlex.new(self)
var equipamentos:=EquipamentosAmbientesPlex.new(self)
var estudos:=EstudosPlex.new(self)
var estudos_ui:=UIEstudosPlex.new()
var carteira := CarteiraPlex.new()
var clique_personagem: PersonagemPlex
var clique_terminal := -1
var inicio_direito := Vector2.ZERO
var interface_gestao := InterfaceGestaoPlex.new()
var desenho_salas := DesenhoSalasPlex.new()
var visor := VisorPlex.new()
var velocidade_base := 1.0
var pausas_ativas:Dictionary={}
var velocidade_tempo:float:
	get:
		return 0.0 if not pausas_ativas.is_empty() else velocidade_base
	set(valor):
		velocidade_base=valor

func pausar(motivo:String) -> void:
	pausas_ativas[motivo]=true

func retomar(motivo:String) -> void:
	pausas_ativas.erase(motivo)

var calendario := CalendarioPlex.new()
var conforto: ConfortoPlex
var campanha := false
var compras_construcao := 0
var ultimo_minuto := -1
var ultimo_sol_ms := 0
var revisao_vista := -1
var revisao_ms := 0
var desempenho:=DesempenhoPlex.new()
var espera_ocupacao:=0.0
var operacao: OperacaoRestaurantePlex
var mapa_conforto: MapaConfortoPlex
var fantasias: FantasiasRestaurantePlex
var vestiario_ui:=UIVestiarioPlex.new()
var energia_ui := UIEnergiaPlex.new()
var vizinhanca := VizinhancaPlex.new()
var bairro := BairroCidadePlex.new()
var clima := ClimaCidadePlex.new()
var clique_gerador := -1
var clique_objeto := -1
var manchas := ManchasPlex.new()
var rotina_adm: RotinaAdministradorPlex
var encerramento: EncerramentoPlex
var ratos:RatosPlex
var seguranca:SegurancaBairroPlex
var turnos:TurnosEquipePlex
var venda_baloes:VendaBaloesPlex
var tempo_quadros_personagens:=0.0
var clique_rato:=-1
var controle: ControleAdministradorPlex
var controle_robo: ControleAnimatronicoPlex
var menu_controle:=MenuControlePlex.new()
var visuais_contexto := -1
var atividade_janela := AtividadeJanelaPlex.new()
var preparacao := PreparacaoRecursosPlex.new()
var atualizacoes := AtualizacoesMundoPlex.new()
var visibilidade := VisibilidadeMundoPlex.new()
var assinatura_sincronizacao := -1
var populacao: PopulacaoBairroPlex
var social: SocialBairroPlex
var sistemas:=NovosSistemasPlex.new(self)

func _ready() -> void:
	AudioServer.set_bus_mute(0,false)
	get_window().content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	CatalogoPlex.carregar()
	EscalaPlex.carregar()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rotas = RotasPlex.new(planta)
	editor = EditorPlex.new(planta)
	editor.personagens = personagens
	editor.jogo = self
	poses = PosesPlex.new(planta, rotas, personagens)
	saida_montagem = SaidaMontagemPlex.new(planta, rotas, poses, personagens)
	iluminacao = IluminacaoPlex.new(planta)
	iluminacao.atualizar_sol(calendario)
	tarefas = TarefasPlex.new(planta, rotas)
	tarefas.personagens = personagens
	ambientes = AmbientesPlex.new(planta, rotas)
	servicos = ServicosPlex.new(planta, rotas, ambientes, tarefas, personagens)
	servicos.jogo=self
	conforto = ConfortoPlex.new(self)
	clientes = ClientesPlex.new(self)
	festas = FestasRestaurantePlex.new(self)
	servicos.recepcao=clientes.recepcao
	atendimento = CaixaPlex.new(self)
	rondas = RondasPlex.new(self)
	animatronicos = AnimatronicosPlex.new(self)
	cortinas = CortinasPalcoPlex.new(self)
	lazer = LazerPlex.new(self)
	compras = ComprasPlex.new(self)
	operacao = OperacaoRestaurantePlex.new(self)
	fantasias = FantasiasRestaurantePlex.new(self)
	quebrados = DestinosQuebradosPlex.new(self)
	controle = ControleAdministradorPlex.new(self)
	controle_robo = ControleAnimatronicoPlex.new(self)
	ratos=RatosPlex.new(self)
	seguranca=SegurancaBairroPlex.new(self)
	turnos=TurnosEquipePlex.new(self)
	venda_baloes=VendaBaloesPlex.new(self)
	encerramento = EncerramentoPlex.new(self)
	rotina_adm = RotinaAdministradorPlex.new(self)
	populacao = PopulacaoBairroPlex.new(self)
	social = SocialBairroPlex.new(self)
	manchas.jogo=self
	manchas.z_index=-1
	add_child(manchas)
	mapa_conforto = MapaConfortoPlex.new()
	mapa_conforto.jogo = self
	mapa_conforto.z_index = 120
	add_child(mapa_conforto)
	desenho_salas.salas = ambientes
	desenho_salas.z_index = -2
	chao.planta = planta
	planta.piso_alterado.connect(chao.queue_redraw)
	chao.z_index = -2
	add_child(chao)
	limites_terreno.editor = editor
	limites_terreno.z_index = -2
	add_child(limites_terreno)
	add_child(desenho_salas)
	add_child(composicao)
	iluminacao.configurar(chao, composicao)
	vizinhanca.planta = planta
	vizinhanca.luz = iluminacao
	vizinhanca.composicao = composicao
	vizinhanca.bairro = bairro
	mundo.add_child(vizinhanca)
	add_child(energia_ui)
	energia_ui.configurar(self)
	sombras_luzes.z_index = -1
	add_child(sombras_luzes)
	add_child(sombras_itens);sombras_itens.configurar(self)
	mundo.name = "ObjetosEPersonagens"
	mundo.y_sort_enabled = true
	add_child(mundo)
	mundo.add_child(bairro)
	bairro.configurar(self)
	add_child(clima)
	clima.configurar(self)
	add_child(camera)
	camera.position = GradePlex.projetar(GradePlex.CENTRO)
	camera.zoom = Vector2(1.4, 1.4)
	cursor.editor = editor
	cursor.z_index = 0
	add_child(cursor)
	move_child(cursor,mundo.get_index())
	add_child(painel)
	painel.configurar_hud(self)
	add_child(menu_controle)
	menu_controle.configurar(self)
	vestiario_ui.configurar(self)
	add_child(vestiario_ui)
	interface_gestao.configurar(self)
	visor.configurar(self)
	add_child(estudos_ui)
	estudos_ui.configurar(self)
	terminal_ui.configurar(self)
	add_child(terminal_ui)
	add_child(carteira)
	carteira.configurar(self)
	compras.aviso.connect(painel.mensagem)
	servicos.aviso.connect(painel.mensagem)
	painel.ferramenta_escolhida.connect(escolher_ferramenta)
	painel.luz_ajustada.connect(ajustar_luz)
	painel.recorte_escolhido.connect(definir_corte)
	painel.recorte.set_pressed_no_signal(cortar_frente)
	editor.aviso.connect(painel.mensagem)
	editor.spawn_solicitado.connect(spawn)
	editor.destino_quebrado_escolhido.connect(quebrados.mover)
	planta.alterada.connect(sincronizar)
	sincronizar()
	add_child(atividade_janela)
	atividade_janela.configurar(self)
	add_child(janelas_moveis)
	janelas_moveis.registrar(energia_ui.janela,energia_ui.fechar)
	janelas_moveis.registrar(estudos_ui.janela,estudos_ui.fechar,64)
	janelas_moveis.registrar(terminal_ui.janela,terminal_ui.fechar,92)
	janelas_moveis.registrar(carteira.folha,carteira.fechar,72)
	janelas_moveis.registrar(painel.hud.livro_ui.janela,painel.hud.livro_ui.fechar,76)
	janelas_moveis.registrar(vestiario_ui.janela,vestiario_ui.adiar,64)
	janelas_moveis.registrar(painel.hud.agenda.janela,painel.hud.agenda.hide,72)
	janelas_moveis.registrar(painel.hud.arquivos.janela,painel.hud.arquivos.fechar,72)
	janelas_moveis.registrar(painel.hud.catalogo.painel,func(): painel.hud.catalogo.painel.hide();escolher_ferramenta("selecionar"),44)


func escolher_ferramenta(valor: String) -> void:
	if valor!=editor.ferramenta: editor.item_movendo=-1
	if valor!="pose": editor.alvo_pose_atracao=-1
	if valor!="pose_quebrado" and sistemas!=null: sistemas.armazem.lugar=-1
	traco_parede.encerrar()
	if editor.ferramenta!=valor: editor.estado_visual=str(CatalogoPlex.objetos.get(valor,{}).get("estado_padrao",""))
	editor.ferramenta = valor
	if valor != "editar_luz":
		luz_selecionada = -1
	var texto: String = CatalogoPlex.objetos[valor].nome if CatalogoPlex.objetos.has(valor) else valor.replace("spawn:", "Colocar ").replace("_", " ").capitalize()
	painel.ferramenta.text = texto + " · direção " + str(editor.rotacao + 1)
	limites_terreno.atualizar()

func spawn(modelo: String, celula: Vector2i, cargo: String = "funcionario", silencioso: bool = false) -> PersonagemPlex:
	return criar_personagem(modelo,celula,cargo,silencioso,{})

func spawn_morador(perfil: Dictionary, celula: Vector2i, cargo: String = "morador") -> PersonagemPlex:
	return criar_personagem(str(perfil.modelo),celula,cargo,true,perfil)

func criar_personagem(modelo: String, celula: Vector2i, cargo: String, silencioso: bool, perfil: Dictionary) -> PersonagemPlex:
	var oficio := modelo if modelo in ["faxineiro","entregador","caixista","seguranca"] else ""
	if not oficio.is_empty(): modelo="humano"
	var robo: bool = CatalogoMontagemPlex.robotico(modelo)
	if robo and not AtracoesCatalogoPlex.permitido(modelo):return null
	var ator: PersonagemPlex = CENA_PERSONAGEM.instantiate()
	ator.equipe = personagens
	ator.set_meta("cabelo_reservado",str(operacao.criacao.get("cabelo","nenhum")))
	ator.cargo = cargo
	if not perfil.is_empty(): AparenciasFamiliaPlex.aplicar(ator,perfil)
	ator.configurar(proximo_personagem, modelo, celula, robo)
	if not oficio.is_empty():
		ator.funcao={"faxineiro":"limpeza","entregador":"estoque","caixista":"caixa","seguranca":"seguranca"}[oficio]
		ator.uniforme=oficio
		ator.cabelo="curto"
	proximo_personagem += 1
	personagens.append(ator)
	mundo.add_child(ator)
	composicao.vincular(ator)
	iluminacao.vincular(ator.material)
	ator.manuseio.configurar(composicao,iluminacao)
	var sombra := SombraLuminariaPlex.new()
	sombra.configurar(ator, iluminacao, composicao)
	sombras_luzes.add_child(sombra)
	ator.planta_visual=planta
	ator.atualizar_visual(false)
	composicao.atualizar_personagem(ator)
	preparar_personagem.call_deferred(ator)
	if not silencioso:
		selecionar(ator)
		painel.mensagem("Personagem colocado. Ele procura tarefas compatíveis e acessíveis.")
	return ator

func preparar_personagem(ator: PersonagemPlex) -> void:
	if is_instance_valid(ator): preparacao.personagem(ator)

func despawn(ator: PersonagemPlex) -> void:
	if ator.robo:oficina.remover(ator)
	if seguranca!=null:seguranca.saida_normal(ator)
	if ator.visita.get("socializando",false): social.cancelar()
	controle.removendo(ator)
	if carteira.ator==ator: carteira.fechar()
	if servicos.trabalhos.has(ator.identificador): servicos.cancelar(ator)
	if tarefas.trabalhos.has(ator.identificador): tarefas.liberar(ator)
	if selecionado == ator:
		selecionado = null
		painel.selecao.text = "Nenhum personagem selecionado"
		painel.retrato.hide()
	for sombra in sombras_luzes.get_children():
		if sombra.ator == ator: sombra.queue_free()
	personagens.erase(ator)
	if populacao!=null and populacao.atores.recolher(ator): return
	ator.queue_free()

func selecionar(ator: PersonagemPlex) -> void:
	if is_instance_valid(selecionado):
		selecionado.selecionado = false
	selecionado = ator
	selecionado.selecionado = true
	painel.selecao.text = social.nome(ator)
	painel.autonomia.set_pressed_no_signal(ator.automatico)
	painel.mostrar_aparencia(ator)

func sincronizar() -> void:
	atualizacoes.agendar("visuais",sincronizar_agora)

func sincronizar_agora() -> void:
	desenho_salas.queue_redraw()
	if PortasPlex.normalizar(planta):
		rotas.reconstruir()
	chao.queue_redraw()
	limites_terreno.atualizar()
	for id in visuais.keys():
		if not planta.objetos.has(id) or planta.objetos[id].tipo not in VISUAIS_DIRETOS:
			visuais[id].queue_free()
			visuais.erase(id)
	for id in planta.objetos:
		if planta.objetos[id].tipo not in VISUAIS_DIRETOS: continue
		if not visuais.has(id):
			var visual: ObjetoVisualPlex = CENA_OBJETO.instantiate()
			mundo.add_child(visual)
			visual.visible = planta.sobreposto(planta.objetos[id].tipo)
			if visual.visible:
				visual.configurar_profundidade(composicao)
			visuais[id] = visual
		visuais[id].visible = planta.sobreposto(planta.objetos[id].tipo)
		visuais[id].energia_disponivel=iluminacao.fator_lampada(id)>.06
		visuais[id].atualizar(planta.objetos[id], planta, nivel_paredes, composicao.recorte.niveis, iluminacao.salas)
	for ator in personagens.duplicate():
		if ator.suporte >= 0:
			if not planta.objetos.has(ator.suporte):
				personagens.erase(ator)
				ator.queue_free()
			else:
				var registro: Dictionary = planta.objetos[ator.suporte]
				ator.pecas = registro.pecas if ator.modelo=="endo" or not ator.animacao.endo_config.is_empty() else -1
				if ator.modelo.begins_with("endo") and not registro.get("montado",false) and registro.has("componentes_endo"):
					ator.animacao.endo_config = registro.componentes_endo.duplicate(true)
					ator.animacao.endo_partes = registro.get("instaladas_endo",[]).duplicate()
				if not ator.ocupado():
					ator.direcao = GradePlex.direcao_suporte(planta.objetos[ator.suporte].rotacao)

func levar_ao_palco(ator: PersonagemPlex) -> bool:
	return poses.encaminhar(ator)

func ajustar_luz(valor: Dictionary) -> void:
	editor.luz_padrao = valor.duplicate()
	if planta.objetos.has(luz_selecionada) and TerrenoPlex.contem(planta,planta.objetos[luz_selecionada].celula):
		planta.objetos[luz_selecionada].merge(valor, true)
		planta.alterada.emit()

func girar_visao() -> void:
	traco_parede.encerrar()
	var foco := GradePlex.inverter(camera.position)
	GradePlex.visao = posmod(GradePlex.visao + 1, 4)
	camera.position = GradePlex.projetar(foco)
	camera.force_update_scroll()
	iluminacao.invalidar()
	composicao.atualizar(planta, nivel_paredes, cortar_frente)
	iluminacao.atualizar()
	sincronizar()
	for ator in personagens:
		ator.planta_visual = planta
		ator.atualizar_visual(ator.ocupado())
		composicao.atualizar_personagem(ator)
	for sombra in sombras_luzes.get_children(): sombra.atualizar()
	painel.mensagem("Visão " + str(GradePlex.visao + 1) + " / 4 · Shift gira 90° · Ctrl alterna as paredes.")

func definir_corte(valor: bool) -> void:
	cortar_frente=valor
	painel.recorte.set_pressed_no_signal(valor)
	sincronizar()

func trocar_paredes() -> void:
	nivel_paredes = nivel_paredes % 4 + 1
	painel.paredes.text = "Paredes: " + str(nivel_paredes) + " / 4 · Ctrl"
	sincronizar()

func apontada() -> Vector2i:
	var mouse:=get_global_mouse_position();var centro:=GradePlex.selecionar(mouse)
	for y in range(-1,2):
		for x in range(-1,2):
			var c:=centro+Vector2i(x,y)
			if EscadasPlex.palco(planta.em(c)) and Geometry2D.is_point_in_polygon(mouse,GradePlex.poligono(GradePlex.projetar(Vector2(c),18.0))):return c
	return centro

func _process(delta: float) -> void:
	var inicio:=Time.get_ticks_usec()
	_atualizar_quadro(delta)
	desempenho.processo(inicio)

func _atualizar_quadro(delta: float) -> void:
	desempenho.quadro(delta)
	var inicio_quadro:=Time.get_ticks_usec()
	if not atividade_janela.permite_simular(): return
	delta=minf(delta,.05)
	if not atividade_janela.iniciar_quadro(delta): return
	preparacao.atualizar(true)
	var minigame_aberto:bool=atracoes.minigame_aberto() or is_instance_valid(sistemas.tutorial) and sistemas.tutorial.bloqueia()
	if minigame_aberto:apagando=false;arrastando=false;traco_parede.encerrar()
	var comando_camera := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if not minigame_aberto and not sistemas.escala_aberta() and not seguranca.aberto() and not festas.aberto() and not menu_controle.aberto() and not energia_ui.aberto() and not carteira.aberto() and not terminal_ui.aberto() and not estudos_ui.aberto() and not painel.hud.menu_aberto() and not (get_viewport().gui_get_focus_owner() is LineEdit) and atividade_janela.em_foco and not comando_camera.is_zero_approx():
		visor.automatico = false
		camera.position += comando_camera.normalized() * 400.0 * minf(delta, 0.05) / camera.zoom.x
		camera.force_update_scroll()
	if arrastando and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		arrastando = false
	if not minigame_aberto and traco_parede.ativo and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not painel.bloqueia_mouse(get_viewport().get_mouse_position()):
		traco_parede.estender(apontada(),editor)
	traco_parede.atualizar(delta,editor)
	if traco_parede.ativo and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		traco_parede.encerrar()

	sombras_itens.atualizar(delta)
	var inicio_cena:=Time.get_ticks_usec()
	processar_atualizacoes()
	if not minigame_aberto and editor.ferramenta=="remover" and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not painel.bloqueia_mouse(get_viewport().get_mouse_position()):
		var destino_apagar:=apontada()
		if not apagando:apagada_ultima=destino_apagar
		var distancia_apagar:=maxi(absi(destino_apagar.x-apagada_ultima.x),absi(destino_apagar.y-apagada_ultima.y))
		for i in range(distancia_apagar+1):
			var ponto_apagar:=Vector2i(Vector2(apagada_ultima).lerp(Vector2(destino_apagar),float(i)/maxi(1,distancia_apagar)).round())
			if not remocoes_traco.has(ponto_apagar):
				preparar_remocao(ponto_apagar)
				editor.remover_uma_vez(ponto_apagar,remocoes_traco)
		apagando=true;apagada_ultima=destino_apagar
	desempenho.medir("Cenário e luzes",inicio_cena)
	bairro.atualizar(delta*velocidade_tempo)
	clima.atualizar(delta*velocidade_tempo)
	for a in personagens:
		if a.visita.get("fora_turno",false): a.hide()
	controle.corpos.atualizar()
	manchas.atualizar(delta*velocidade_tempo)
	var contexto_visual := hash([planta.revisao,GradePlex.visao,nivel_paredes,cortar_frente,iluminacao.rede.fator>0.0])
	var contexto_mudou:=visuais_contexto!=contexto_visual
	if contexto_mudou:
		visuais_contexto = contexto_visual
		for id in visuais:
			if visuais[id].visible and planta.objetos.has(id):
				if LuminariasPlex.eh(planta.objetos[id].tipo): visuais[id].aplicar_energia(iluminacao.fator_lampada(id),iluminacao.ambiente_diurno)
				visuais[id].modulate.a=1.0
				visuais[id].atualizar(planta.objetos[id],planta,nivel_paredes,composicao.recorte.niveis,iluminacao.salas)
	for id in (visuais if not contexto_mudou else {}):
		if visuais[id].visible and planta.objetos.has(id) and LuminariasPlex.eh(planta.objetos[id].tipo):
			visuais[id].aplicar_energia(iluminacao.fator_lampada(id),iluminacao.ambiente_diurno)
	ambientes.atualizar()
	interface_gestao.atualizar(delta)
	painel.hud.atualizar(delta)

	var local := apontada()
	if editor.ferramenta=="remover":preparar_remocao(local)
	cursor.celula = local
	cursor.altura = planta.altura(local)
	cursor.valido = GradePlex.dentro(local)
	if CatalogoPlex.objetos.has(editor.ferramenta) and editor.ferramenta != "chao":
		cursor.valido = (planta.pode_colocar(editor.ferramenta, local, editor.rotacao) or SubstituicaoParedesPlex.permite(planta,editor.ferramenta,local,editor.rotacao)) and (planta.sobreposto(editor.ferramenta) or editor.livre(local))
	if CatalogoPlex.objetos.get(editor.ferramenta,{}).get("piso",false): cursor.valido=GradePlex.dentro(local)
	if CatalogoPlex.objetos.get(editor.ferramenta,{}).has("pacote"):
		for c in MobiliaPlex.modulos(editor.ferramenta,local,editor.rotacao):
			if (not planta.pode_colocar(editor.ferramenta,c,editor.rotacao) and not SubstituicaoParedesPlex.permite(planta,editor.ferramenta,c,editor.rotacao)) or not editor.livre(c): cursor.valido=false
	if editor.ferramenta in ["pose_quebrado","pose_montagem"]: cursor.valido=quebrados.livre(local,editor.marca_quebrado)
	if CatalogoPlex.objetos.has(editor.ferramenta): cursor.valido=cursor.valido and editor.acessos.avaliar(editor,local).permitido
	cursor.valido = editor.permitido(local) if editor.item_movendo>=0 else cursor.valido and editor.permitido(local)
	limites_terreno.atualizar()
	cursor.visible = not minigame_aberto and not seguranca.aberto() and not menu_controle.aberto() and not energia_ui.aberto() and not carteira.aberto() and not terminal_ui.aberto() and not estudos_ui.aberto() and not painel.bloqueia_mouse(get_viewport().get_mouse_position())
	cursor.niveis = composicao.recorte.niveis
	cursor.salas = iluminacao.salas
	cursor.queue_redraw()
	var removendo:=editor.alvo_remocao(local) if cursor.visible and editor.ferramenta=="remover" else {}
	for id in visuais:
		if LuminariasPlex.eh(str(visuais[id].registro.get("tipo",""))):visuais[id].destacar_exclusao(int(removendo.get("id",-1))==int(id))
	desempenho.medir("Quadro visual",inicio_quadro)

func _physics_process(delta: float) -> void:
	var inicio:=Time.get_ticks_usec()
	_simular(delta)
	desempenho.fisica(inicio)

func _simular(delta: float) -> void:
	if not atividade_janela.permite_simular(): return
	if is_instance_valid(sistemas.tutorial) and sistemas.tutorial.bloqueia():sistemas.tutorial.simular(minf(delta,.05));return
	delta = minf(delta,.05)*velocidade_tempo
	if delta <= 0: return
	portas.atualizar(delta,planta,personagens)
	CabinesPlex.atualizar(planta,personagens)
	iluminacao.rede.atualizar(delta*CalendarioPlex.MINUTOS_POR_SEGUNDO)
	operacao.atualizar(delta)
	calendario.atualizar(delta)
	folha_pagamento.atualizar(self)
	estudos.atualizar(delta)
	DecoracaoEstudoPlex.atualizar(planta,calendario.minutos)
	populacao.atualizar(delta)
	rotina_adm.atualizar(delta)
	conforto.atualizar(delta)
	if ultimo_minuto != calendario.minuto_do_dia() and Time.get_ticks_msec()-ultimo_sol_ms>=2500:
		ultimo_minuto = calendario.minuto_do_dia()
		ultimo_sol_ms = Time.get_ticks_msec()
		iluminacao.atualizar_sol(calendario)
	espera_ocupacao+=delta
	if espera_ocupacao>=.1:espera_ocupacao=0;rotas.atualizar_atores(personagens)
	turnos.atualizar(delta)
	equipamentos.atualizar(delta)
	oficina.atualizar(delta)
	encerramento.atualizar(delta)
	controle.atualizar(delta)
	controle_robo.atualizar(delta)
	var inicio_ambiencia:=Time.get_ticks_usec()
	sistemas.atualizar(delta)
	desempenho.medir("Ar, som e eventos",inicio_ambiencia)
	seguranca.atualizar(delta)
	ratos.atualizar(delta)
	social.atualizar(delta)
	compras.atualizar(delta)

	atracoes.atualizar(delta)
	atendimento.atualizar(delta)
	rondas.atualizar(delta)
	fantasias.atualizar(delta)
	var inicio_servicos:=Time.get_ticks_usec()
	servicos.atualizar(delta)
	desempenho.medir("Trabalho da equipe",inicio_servicos)
	var inicio_clientes:=Time.get_ticks_usec()
	clientes.atualizar(delta)
	desempenho.medir("Clientes e caminhos",inicio_clientes)
	festas.atualizar(delta)
	venda_baloes.atualizar(delta)
	lazer.atualizar(delta)

	cortinas.atualizar(delta)
	visibilidade.atualizar(camera,get_viewport())
	tempo_quadros_personagens+=delta/maxf(.001,velocidade_tempo)
	var desenhar:=atividade_janela.permite_desenhar() and tempo_quadros_personagens>=1.0/30.0
	if desenhar:tempo_quadros_personagens=fmod(tempo_quadros_personagens,1.0/30.0)
	for ator in personagens:
		if ator.visita.get("morto",false) or ator.visita.get("fora_turno",false): continue
		if ator.cargo=="morador" and not ControleAdministradorPlex.ocupado(ator): continue
		ator.set_meta("tarefa_ativa", ControleAdministradorPlex.ocupado(ator) or  servicos.trabalhos.has(ator.identificador) or tarefas.trabalhos.has(ator.identificador) or FantasiasRestaurantePlex.ocupando(ator) or ator.pose >= 0 or ator.trabalho in ["liberar_saida","caixa","caixa_sentado","ir_caixa","usar_caixa","estudar","ir_estudar"] or ator.cargo in ["cliente", "crianca"] or ator.funcao in ["caixa","seguranca"])
		var mostrar:=visibilidade.personagem(ator)
		ator.visible=mostrar
		ator.atualizar(delta, planta, rotas, personagens,mostrar and desenhar)
		if mostrar and desenhar: composicao.atualizar_personagem(ator)
	if desenhar:
		vizinhanca.atualizar_postes(personagens)
		iluminacao.atualizar_moveis(personagens,delta)
		for sombra in sombras_luzes.get_children(): sombra.atualizar(delta/maxf(.001,velocidade_tempo))
	espera_palco += delta
	if espera_palco >= 1.0:
		espera_palco = 0.0
		for ator in personagens:
			if ator.robo and not AtracoesCatalogoPlex.permitido(ator.modelo) and not ator.modelo.begins_with("novo_") and ator.automatico and not EquipePlex.em_comando(ator) and not AnimatronicosPlex.pausado(ator) and not ator.ocupado() and ator.pronto_para_destino() and ator.pose < 0:
				levar_ao_palco(ator)

func processar_atualizacoes() -> void:
	var contexto:=hash([planta.revisao,nivel_paredes,cortar_frente,GradePlex.visao])
	if composicao.precisa_atualizar(planta,nivel_paredes,cortar_frente):
		atualizacoes.agendar("cena",func():
			composicao.atualizar(planta,nivel_paredes,cortar_frente)
			visuais_contexto=-1)
	if planta.revisao!=revisao_vista:
		revisao_vista=planta.revisao
		revisao_ms=Time.get_ticks_msec()
	if iluminacao.precisa_atualizar() and (iluminacao.revisao_portas==planta.revisao or Time.get_ticks_msec()-revisao_ms>=150): atualizacoes.agendar("iluminacao",iluminacao.atualizar)
	if contexto!=assinatura_sincronizacao or vizinhanca.horario!=iluminacao.cidade.versao_horario or vizinhanca.clima_versao!=CatalogoCidadePlex.versao:
		assinatura_sincronizacao=contexto
		atualizacoes.agendar("bairro",func():
			vizinhanca.desativada=false
			vizinhanca.definir_recorte(nivel_paredes,cortar_frente)
			vizinhanca.atualizar())
	atualizacoes.processar(3000,2,desempenho)
	if not vizinhanca.fila.is_empty(): atualizacoes.agendar("bairro_visuais",vizinhanca.processar)

func terminal_apontado() -> int:
	var mouse := get_global_mouse_position()
	for objeto in planta.listar("terminais"):
		var p := ApoiosPlex.posicao(planta,objeto)
		var centro := GradePlex.projetar(Vector2(p.x,p.y),p.z)
		var volume := GeometriaPlex.objeto(objeto,planta,4)
		var local := Vector2i((mouse-centro-Vector2(volume.origin[0],volume.origin[1])).floor())
		var imagem: Image = volume.textura.get_image()
		if Rect2i(Vector2i.ZERO,imagem.get_size()).has_point(local) and imagem.get_pixelv(local).a > .1: return objeto.id
	return -1

func personagem_apontado() -> PersonagemPlex:
	var mouse := get_global_mouse_position()
	if controle.manual():
		var corpo:=controle.corpos.apontado(mouse)
		if is_instance_valid(corpo): return corpo
	var lista := personagens.duplicate()
	lista.sort_custom(func(a,b): return a.position.y>b.position.y)
	for pessoa in lista:
		if not pessoa.visible or pessoa.visita.get("morto",false): continue
		for camada in pessoa.pintura.fontes:
			var fonte: Sprite2D = camada.sprite
			if not is_instance_valid(fonte) or not fonte.visible or fonte.texture==null: continue
			var imagem: Image = SilhuetasPlex.imagem(fonte.texture)
			var ponto := Vector2i(fonte.to_local(mouse).floor())
			if imagem!=null and Rect2i(Vector2i.ZERO,imagem.get_size()).has_point(ponto) and imagem.get_pixelv(ponto).a>.1: return pessoa
	return null

func _input(evento: InputEvent) -> void:
	tratar_entrada(evento)

func tratar_entrada(evento: InputEvent) -> void:
	if is_instance_valid(sistemas.tutorial) and sistemas.tutorial.entrada_evento(evento):get_viewport().set_input_as_handled();return
	if is_instance_valid(equipamentos.diagnostico_ui) and equipamentos.diagnostico_ui.aberto():return
	if atracoes!=null and atracoes.minigame_aberto():return
	if evento is InputEventKey:
		if evento.pressed and evento.keycode!=KEY_CTRL and evento.ctrl_pressed:ctrl_consumido=true
		if evento.keycode==KEY_CTRL:
			if evento.pressed and not evento.echo:ctrl_consumido=false
			elif not evento.pressed and not ctrl_consumido and not terminal_ui.aberto() and not carteira.aberto() and not painel.hud.menu_aberto():trocar_paredes()
	if evento is InputEventMouseButton and evento.button_index==MOUSE_BUTTON_LEFT and not evento.pressed:apagando=false
	if sistemas!=null and sistemas.escala_aberta():return
	if seguranca!=null and seguranca.aberto():return
	if festas!=null and festas.aberto():
		if evento is InputEventKey and evento.pressed and evento.keycode==KEY_ESCAPE:festas.referencia_ui.queue_free();get_viewport().set_input_as_handled()
		return
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.ctrl_pressed and evento.keycode==KEY_Z and not (get_viewport().gui_get_focus_owner() is LineEdit) and not (get_viewport().gui_get_focus_owner() is TextEdit):
		editor.desfazer();get_viewport().set_input_as_handled();return
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.keycode==KEY_SPACE and not get_viewport().gui_get_focus_owner() is LineEdit and not get_viewport().gui_get_focus_owner() is TextEdit:
		if painel.hud!=null and not painel.hud.menu.visible:
			painel.hud.alternar_pausa();get_viewport().set_input_as_handled();return
	if evento is InputEventKey and evento.pressed and evento.keycode==KEY_ESCAPE and painel.hud.ar_ui.mapa.ativo and not carteira.aberto() and not terminal_ui.aberto() and not menu_controle.aberto() and not estudos_ui.aberto() and not energia_ui.aberto() and not painel.hud.menu_aberto():
		painel.hud.ar_ui.fechar();get_viewport().set_input_as_handled();return
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.keycode==KEY_ESCAPE and mapa_conforto.ativo and not painel.hud.menu_aberto() and not menu_controle.aberto() and not energia_ui.aberto() and not carteira.aberto() and not terminal_ui.aberto() and not estudos_ui.aberto():
		painel.hud.conforto_ui.fechar()
		get_viewport().set_input_as_handled()
		return
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.keycode==KEY_ESCAPE and editor.item_movendo>=0:
		editor.item_movendo=-1
		escolher_ferramenta("selecionar")
		arrastando=false
		get_viewport().set_input_as_handled()
		return
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.keycode==KEY_ESCAPE and janelas_moveis.fechar_topo():
		get_viewport().set_input_as_handled()
		return
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.keycode==KEY_ESCAPE and painel.hud!=null:
		if menu_controle.aberto(): menu_controle.fechar()
		elif energia_ui.aberto(): energia_ui.fechar()
		elif painel.hud.arquivos.visible: painel.hud.arquivos.fechar()
		elif vestiario_ui.aberto(): vestiario_ui.adiar()
		elif carteira.aberto(): carteira.fechar()
		elif terminal_ui.aberto(): terminal_ui.fechar()
		elif painel.hud.agenda.visible: painel.hud.agenda.hide()
		elif painel.hud.pendencias.aberto(): painel.hud.pendencias.fechar()
		elif painel.hud.menu.visible: painel.hud.alternar_menu()
		elif painel.hud.mostrar_tempo: painel.hud.mostrar_tempo=false;painel.hud.atualizar(1)
		elif painel.hud.catalogo.painel.visible:
			painel.hud.catalogo.painel.hide()
			escolher_ferramenta("selecionar")
			traco_parede.encerrar()
			arrastando=false
		else:
			escolher_ferramenta("selecionar")
			traco_parede.encerrar()
			arrastando=false
			painel.hud.alternar_menu()
		get_viewport().set_input_as_handled()
		return
	if painel.hud != null and painel.hud.menu_aberto():
		if evento is InputEventKey and evento.pressed and evento.keycode==KEY_ESCAPE:
			if painel.hud.agenda.visible: painel.hud.agenda.hide()
			else: painel.hud.alternar_menu()
			get_viewport().set_input_as_handled()
		return
	if menu_controle.aberto() or energia_ui.aberto() or vestiario_ui.aberto(): return
	if carteira.aberto():
		if evento is InputEventKey and evento.pressed and evento.keycode==KEY_ESCAPE:
			carteira.fechar()
			get_viewport().set_input_as_handled()
		return
	if evento is InputEventMouseButton and not evento.pressed and evento.button_index == MOUSE_BUTTON_RIGHT:
		if evento.position.distance_to(inicio_direito)<=6 and sistemas.armazem.cancelar():
			get_viewport().set_input_as_handled()
			return
		if editor.item_movendo>=0 and evento.position.distance_to(inicio_direito)<=6:
			escolher_ferramenta("selecionar")
			get_viewport().set_input_as_handled()
			return
		if clique_rato>=0 and evento.position.distance_to(inicio_direito)<=6:
			menu_controle.abrir_rato(clique_rato,evento.position);get_viewport().set_input_as_handled()
		elif is_instance_valid(clique_personagem) and personagens.has(clique_personagem) and evento.position.distance_to(inicio_direito)<=6:
			if not menu_controle.abrir(clique_personagem,-1,evento.position): carteira.abrir(clique_personagem)
			get_viewport().set_input_as_handled()
		elif (controle.manual() or clique_objeto>=0) and evento.position.distance_to(inicio_direito)<=6:
			menu_controle.abrir(null,clique_objeto,evento.position)
			get_viewport().set_input_as_handled()
		elif clique_gerador>=0 and evento.position.distance_to(inicio_direito)<=6:
			menu_controle.abrir(null,clique_gerador,evento.position)
			get_viewport().set_input_as_handled()
		elif clique_terminal >= 0 and evento.position.distance_to(inicio_direito) <= 6 and not terminal_ui.aberto() and not estudos_ui.aberto():
			terminal_ui.abrir(clique_terminal)
			get_viewport().set_input_as_handled()
		elif evento.position.distance_to(inicio_direito)<=6 and editor.ferramenta=="selecionar":
			menu_controle.abrir(null,-1,evento.position)
		elif evento.position.distance_to(inicio_direito)<=6 and editor.ferramenta!="selecionar":
			escolher_ferramenta("selecionar")
			painel.hud.catalogo.preencher()
		clique_rato=-1
		clique_terminal = -1
		clique_gerador = -1
		clique_objeto = -1
		clique_personagem = null
	if evento is InputEventMouseButton and not evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		traco_parede.encerrar()
	if evento is InputEventMouseButton and not evento.pressed and evento.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		arrastando = false

func _unhandled_input(evento: InputEvent) -> void:
	tratar_entrada_livre(evento)

func tratar_entrada_livre(evento: InputEvent) -> void:
	if is_instance_valid(sistemas.tutorial) and sistemas.tutorial.bloqueia():return
	if is_instance_valid(equipamentos.diagnostico_ui) and equipamentos.diagnostico_ui.aberto():return
	if atracoes.minigame_aberto():return
	if menu_controle.aberto() or energia_ui.aberto() or vestiario_ui.aberto() or carteira.aberto() or terminal_ui.aberto() or estudos_ui.aberto() or painel.hud.menu_aberto(): return
	if evento is InputEventMouse and painel.bloqueia_mouse(evento.position):
		return
	if evento is InputEventKey and evento.pressed and not evento.echo:
		if evento.keycode == KEY_CTRL:
			pass
		elif evento.keycode == KEY_SHIFT:
			girar_visao()
		elif evento.keycode == KEY_HOME:
			enquadrar()
		elif evento.keycode == KEY_F11:
			alternar_tela_cheia()
		elif evento.keycode == KEY_R:
			traco_parede.encerrar()
			editor.rotacao = (editor.rotacao + 1) % 4
			escolher_ferramenta(editor.ferramenta)
		elif evento.keycode == KEY_ESCAPE:
			escolher_ferramenta("selecionar")
			traco_parede.encerrar()
			arrastando=false
			painel.hud.alternar_menu()
			get_viewport().set_input_as_handled()
	if evento is InputEventMouseButton:
		if evento.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			arrastando = evento.pressed
			if evento.button_index == MOUSE_BUTTON_RIGHT and evento.pressed:
				inicio_direito = evento.position
				clique_rato=ratos.apontado(get_global_mouse_position())
				clique_personagem = personagem_apontado() if clique_rato<0 else null
				clique_terminal = terminal_apontado() if clique_personagem==null else -1
				clique_gerador = gerador_apontado() if clique_personagem==null and clique_terminal<0 else -1
				clique_objeto = objeto_manual_apontado()
				if planta.objetos.get(clique_objeto,{}).get("tipo","")=="amb_interruptor_antigo":clique_rato=-1;clique_personagem=null;clique_terminal=-1;clique_gerador=-1
				if clique_rato>=0 or clique_objeto>=0 or clique_gerador>=0 or clique_terminal >= 0 or is_instance_valid(clique_personagem): arrastando = false
		elif evento.pressed and evento.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var fator: float = 1.1 if evento.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1
			visor.automatico = false
			camera.zoom = Vector2.ONE * clampf(camera.zoom.x * fator, 0.30, 3.5)
		elif evento.button_index == MOUSE_BUTTON_LEFT and evento.pressed:
			if editor.ferramenta.begins_with("visita:"):
				if editor.ferramenta.begins_with("visita:adolescente"): lazer.criar(apontada(),editor.ferramenta == "visita:adolescente_feminina")
				elif editor.ferramenta == "visita:crianca": clientes.adicionar_crianca(apontada())
				elif editor.ferramenta.begins_with("visita:grupo:"): clientes.criar_preset(apontada(),editor.ferramenta.trim_prefix("visita:grupo:"))
				else: clientes.criar(apontada(),1 if editor.ferramenta.begins_with("visita:familia1") else 2,"humana" if editor.ferramenta.ends_with("_humana") else "humano" if editor.ferramenta.ends_with("_humano") else "")
			elif editor.ferramenta.begins_with("sala:"):
				if editor.permitido(apontada()):
					ambientes.definir(apontada(), editor.ferramenta.trim_prefix("sala:"))
					interface_gestao.inspecionar(apontada())
			elif editor.ferramenta == "inspecionar":
				interface_gestao.inspecionar(apontada())
			elif editor.ferramenta == "editar_luz":
				if not editor.permitido(apontada()): return
				var adicionais: Array = planta.sobre(apontada()).filter(func(item): return item.tipo.begins_with("luz_"))
				if not adicionais.is_empty():
					var indice := 0
					for i in adicionais.size():
						if adicionais[i].id == luz_selecionada:
							indice = (i + 1) % adicionais.size()
							break
					luz_selecionada = adicionais[indice].id
					painel.mostrar_luz(adicionais[indice])
			elif editor.ferramenta == "selecionar":
				clicar_mundo(apontada())
			elif editor.ferramenta=="remover":
				remocoes_traco.clear();apagando=true;apagada_ultima=apontada()
				preparar_remocao(apagada_ultima);editor.remover_uma_vez(apagada_ultima,remocoes_traco)
			elif TracoParedePlex.aceita(editor):
				traco_parede.iniciar(apontada(), editor)
			else:
				editor.aplicar(apontada())
	if evento is InputEventMouseMotion and (clique_rato>=0 or clique_objeto>=0 or clique_gerador>=0 or clique_terminal>=0 or is_instance_valid(clique_personagem)) and evento.position.distance_to(inicio_direito) > 6:
		clique_rato=-1
		clique_terminal = -1
		clique_gerador = -1
		clique_objeto = -1
		clique_personagem = null
		clique_gerador = -1
		clique_objeto = -1
		arrastando = true
	if evento is InputEventMouseMotion and arrastando:
		visor.automatico = false
		camera.position -= evento.relative / camera.zoom
		camera.force_update_scroll()
	elif evento is InputEventMouseMotion and traco_parede.ativo:
		traco_parede.estender(apontada(), editor)

func clicar_mundo(celula: Vector2i) -> void:
	var rato:=ratos.apontado(get_global_mouse_position())
	if rato>=0:menu_controle.abrir_rato(rato,get_viewport().get_mouse_position());return
	var luminaria:=luz_apontada()
	if luminaria>=0:
		menu_controle.abrir(null,luminaria,get_viewport().get_mouse_position())
		return
	if sistemas.armazem.clicar(celula):return
	if controle_robo.ativo():
		controle_robo.mover(celula)
		return
	if controle.manual():
		controle.mover(celula)
		return
	var ator := personagem_apontado()
	if is_instance_valid(ator):
		selecionar(ator)
		return
	interface_gestao.inspecionar(celula)

func salvar(slot:int=0) -> void:
	if slot==0:painel.hud.arquivos.abrir_salvar();return
	var sucesso := ArquivoPlex.salvar(planta, personagens, servicos.gravar(), clientes.gravar(), compras.gravar(), {"cidade":"bairro_jardim_1958" if planta.bairro_ativo else "","ativa":campanha,"calendario":calendario.gravar(),"gastos_construcao":compras_construcao,"visao":GradePlex.visao,"paredes":nivel_paredes,"cortar_frente":cortar_frente,"operacao":operacao.gravar(),"populacao":populacao.gravar(),"social":social.gravar(),"estudos":estudos.gravar(),"ratos":ratos.gravar(),"seguranca":seguranca.gravar(),"sistemas":sistemas.gravar()},slot)
	painel.hud.carregar_botao.disabled=not ArquivoPlex.tem_saves()
	painel.mensagem("Partida salva no slot "+str(slot)+"." if sucesso else "Não foi possível salvar a partida.")

func carregar(caminho: String = "") -> bool:
	var sucesso:=_carregar_partida(caminho)
	return sucesso

func _carregar_partida(caminho: String) -> bool:
	var dados := ArquivoPlex.ler(caminho)
	if dados.is_empty():
		painel.mensagem("Selecione uma partida válida na janela Carregar.")
		return false
	terminal_ui.fechar()
	if festas.aberto():festas.referencia_ui.queue_free()
	carteira.fechar()
	menu_controle.fechar()
	social.cancelar()
	controle.limpar()
	turnos.filas.clear();turnos.ordem_fila=0
	editor.historico.clear()
	traco_parede.encerrar()
	saida_montagem.limpar()
	cortinas.assinatura = 0
	cortinas.fases.clear()
	cortinas.palcos_ativos.clear()
	iluminacao.circuito.palcos_ativos.clear()
	populacao.visitas.cancelar()
	populacao.atores.limpar()
	populacao.iniciado=false
	for ator in personagens:
		ator.queue_free()
	personagens.clear()
	selecionado = null
	luz_selecionada = -1
	tarefas.trabalhos.clear()
	planta.objetos.clear()
	planta.ocupacao.clear()
	planta.cores.clear()
	planta.pisos.clear()
	planta.terrenos_adquiridos.clear()
	planta.area_construcao=Rect2i()
	planta.rotacoes_pisos.clear()
	planta.uso_pisos.clear()
	planta.funcoes_salas.clear()
	servicos.trabalhos.clear()
	planta.proximo_id = 1
	for registro in dados.objetos:
		if registro.has("parte_endo") or str(registro.get("tipo","")).begins_with("caixa_pecas_") or registro.get("tipo","") in ["pecas_manutencao","pose_quebrado","pose_montagem"]: continue
		if str(registro.get("tipo","")) in TIPOS_REMOVIDOS: continue
		var objeto: Dictionary = registro.duplicate()
		if objeto.tipo=="maquina_fliperama" and not str(objeto.get("variante","")).begins_with("amb_"):
			objeto.variante="amb_fliperama_estrelar";objeto.estado="desligado"
		if objeto.tipo=="suporte":
			for chave in objeto.keys():
				if chave not in ["id","tipo","celula","rotacao","estado","sobre","slot","valor_pago","atracao_livro"]: objeto.erase(chave)
		objeto.celula = Vector2i(registro.celula[0], registro.celula[1])
		objeto.reserva = 0
		var id: int = objeto.id
		planta.objetos[id] = objeto
		planta.proximo_id = maxi(planta.proximo_id, id + 1)
		if planta.ocupa(objeto):
			for local in planta.celulas(objeto.tipo, objeto.celula, objeto.rotacao):
				planta.ocupacao[local] = id
	planta.reindexar()
	for marca in dados.get("salas", []):
		planta.funcoes_salas[Vector2i(marca[0], marca[1])] = str(marca[2])
	for cor in dados.cores:
		planta.cores[Vector2i(cor[0], cor[1])] = int(cor[2])
	for piso in dados.get("pisos",[]):
		planta.pisos[Vector2i(piso[0],piso[1])] = str(piso[2])
		planta.rotacoes_pisos[Vector2i(piso[0],piso[1])]=posmod(int(piso[3]),4) if piso.size()>3 else 0
	DesgastePisosPlex.restaurar(planta,dados.get("uso_pisos",[]))
	var progresso: Dictionary = dados.get("campanha",{})
	campanha = bool(progresso.get("ativa",false))
	operacao.restaurar(progresso.get("operacao",{}))
	TerrenoPlex.restaurar_lotes(planta,dados.get("terrenos_adquiridos",{}))
	bairro.ativar(str(progresso.get("cidade",""))=="bairro_jardim_1958",true)
	TerrenoPlex.restaurar(planta,dados.get("terreno",[]))
	LayoutsImoveisPlex.atualizar_antigos(planta)
	LayoutsImoveisPlex.corrigir_farmacia(planta)
	compras_construcao = int(progresso.get("gastos_construcao",0))
	calendario.restaurar(progresso.get("calendario",{}))
	folha_pagamento.ultimo_dia=-1
	estudos.restaurar(progresso.get("estudos",{}))
	ultimo_minuto=-1
	iluminacao.atualizar_sol(calendario)
	GradePlex.visao = posmod(int(progresso.get("visao",GradePlex.visao)),4)
	nivel_paredes = clampi(int(progresso.get("paredes",nivel_paredes)),1,4)
	cortar_frente = bool(progresso.get("cortar_frente",cortar_frente))
	painel.recorte.set_pressed_no_signal(cortar_frente)
	iluminacao.invalidar()
	var suportes_antigos: Array = []
	for item in planta.objetos.values():
		if item.tipo=="suporte" and item.get("endo",false) and not item.get("montado",false) and not item.has("componentes_endo"):
			suportes_antigos.append(item.id)
			item.endo = false
			item.pecas = 0
			item.caixa = false
	for registro in dados.personagens:
		if registro.modelo=="endo" and suportes_antigos.has(int(registro.get("suporte",-1))): continue
		if bool(registro.get("robo",CatalogoMontagemPlex.robotico(str(registro.modelo)))) and not AtracoesCatalogoPlex.permitido(str(registro.modelo)):continue
		var ator := spawn(registro.modelo, Vector2i(registro.celula[0], registro.celula[1]),str(registro.get("cargo","funcionario")),true)
		if not is_instance_valid(ator):continue
		ator.identificador = int(registro.id)
		ator.relogio = float(registro.get("relogio",0.0))
		proximo_personagem = maxi(proximo_personagem, ator.identificador + 1)
		ator.cargo = str(registro.get("cargo", "funcionario"))
		ator.identidade = registro.get("identidade",{}).duplicate(true)
		IdentidadesPlex.garantir(ator)
		ator.funcao = str(registro.get("funcao","geral"))
		ator.funcoes_secundarias = registro.get("funcoes_secundarias",[]).duplicate()
		ator.caixa_tipo = str(registro.get("caixa_tipo","caixa"))
		ator.caixa_qualidade = str(registro.get("caixa_qualidade","boa"))
		ator.caixa_durabilidade = int(registro.get("caixa_durabilidade",100))
		ator.cabelo = str(registro.get("cabelo","automatico"))
		ator.uniforme = str(registro.get("uniforme","automatico"))
		ator.familia = int(registro.get("familia", -1))
		ator.responsavel = int(registro.get("responsavel", -1))
		ator.visita = registro.get("visita", {}).duplicate(true)
		ator.visita.erase("estudando")
		ator.visita.erase("socializando")
		ator.visita.erase("autonomia_social")
		ator.robotica = registro.get("robotica",{}).duplicate(true)
		ator.direcao = int(registro.direcao)
		ator.automatico = registro.get("automatico", true)
		ator.carga_item = int(registro.get("carga_item", -1))
		ator.carga_extra.assign(registro.get("carga_extra",[]).map(func(id): return int(id)))
		ator.energia = float(registro.get("energia", 100.0))
		ator.necessidades.merge(registro.get("necessidades", {}), true)
		ator.carregando = registro.carregando
		ator.suporte = int(registro.suporte)
		ator.pose = int(registro.get("pose", -1))
		ator.pecas = int(registro.pecas)
		ator.animacao.expressao = registro.expressao
		if registro.get("apresentando", false):
			ator.trabalho = "apresentar"
	servicos.restaurar(dados.get("servicos", {}))
	planta.reindexar()
	KitLimpezaPlex.restaurar(planta)
	RecebimentosPlex.corrigir(planta)
	clientes.restaurar(dados.get("clientes", {}))
	compras.restaurar(dados.get("compras",{}))
	populacao.restaurar(progresso.get("populacao",{}))
	social.restaurar(progresso.get("social",{}))
	ratos.restaurar(progresso.get("ratos",{}))
	seguranca.restaurar(progresso.get("seguranca",{}))
	sistemas.restaurar(progresso.get("sistemas",{}))
	AdministradorPlex.reservar_cabelo(self)
	ApoiosPlex.corrigir_decoracoes(planta)
	FachadaPlex.corrigir_decoracao(planta)
	planta.alterada.emit()
	painel.hud.atualizar(1.0)
	operacao.aplicar_credito()
	if operacao.bloqueado_por_seguranca() and operacao.aberto:operacao.mudar_abertura(false)
	painel.mensagem("Partida carregada.")
	return true

func enquadrar() -> void:
	visor.enquadrar()

func alternar_tela_cheia() -> void:
	visor.alternar_tela_cheia()


func preco_construcao(tipo: String) -> int:
	return MobiliaPlex.preco(tipo)

func gerador_apontado() -> int:
	var mouse := get_global_mouse_position()
	for item in iluminacao.rede.geradores:
		var p := ApoiosPlex.posicao(planta,item)
		var centro := GradePlex.projetar(Vector2(p.x,p.y),p.z)
		var volume := GeometriaPlex.objeto(item,planta,4)
		var local := Vector2i((mouse-centro-Vector2(volume.origin[0],volume.origin[1])).floor())
		var imagem: Image = volume.textura.get_image()
		if Rect2i(Vector2i.ZERO,imagem.get_size()).has_point(local) and imagem.get_pixelv(local).a>.1: return item.id
	return -1

func interruptor_apontado(mouse:Vector2) -> int:
	var melhor:=-1;var distancia:=INF
	for o in planta.objetos.values():
		if o.tipo!="amb_interruptor_antigo" or int(o.get("carregada_por",0))>0 or not TerrenoPlex.contem(planta,o.celula):continue
		var p:=ApoiosPlex.posicao(planta,o);var v:=GeometriaPlex.objeto(o,planta,composicao.recorte.nivel_para(o,nivel_paredes),composicao.recorte.niveis)
		var retangulo:=Rect2(GradePlex.projetar(Vector2(p.x,p.y),p.z)+Vector2(v.origin[0],v.origin[1]),v.textura.get_size())
		var margem:=6.0/maxf(.25,camera.zoom.x)
		if not retangulo.grow(margem).has_point(mouse):continue
		var d:=mouse.distance_squared_to(retangulo.get_center())
		if d<distancia:distancia=d;melhor=int(o.id)
	return melhor
func objeto_manual_apontado() -> int:
	var mancha:=manchas.apontada(get_global_mouse_position())
	if mancha>=0: return mancha
	var mouse:=get_global_mouse_position()
	var interruptor:=interruptor_apontado(mouse)
	if interruptor>=0:return interruptor
	var luz:=luz_apontada()
	if luz>=0: return luz
	var celula_palco:=GradePlex.selecionar(mouse+Vector2(0,GradePlex.ALTURA_PALCO))
	var palco:=planta.em(celula_palco)
	if EscadasPlex.palco(palco):return int(palco.id)
	var objetos:=planta.objetos.values().filter(func(o): return TerrenoPlex.contem(planta,o.celula) and int(o.get("carregada_por",0))==0 and (not planta.sobreposto(o.tipo) or LuminariasPlex.eh(o.tipo) or AssetsSistemasPlex.eh(str(o.tipo)) or CortinasPalcoPlex.eh(str(o.tipo)) or MobiliaPlex.dados(o).get("parede_requerida",false)))
	objetos.sort_custom(func(a,b):
		var ya:=GradePlex.projetar(Vector2(a.celula)).y
		var yb:=GradePlex.projetar(Vector2(b.celula)).y
		if not is_equal_approx(ya,yb): return ya>yb
		return ApoiosPlex.posicao(planta,a).z>ApoiosPlex.posicao(planta,b).z)
	for item in objetos:
		var p:=ApoiosPlex.posicao(planta,item)
		if LuminariasPlex.eh(item.tipo): continue
		var volume:=GeometriaPlex.objeto(item,planta,composicao.recorte.nivel_para(item,nivel_paredes),composicao.recorte.niveis)
		var local:=Vector2i((mouse-GradePlex.projetar(Vector2(p.x,p.y),p.z)-Vector2(volume.origin[0],volume.origin[1])).floor())
		var im: Image=volume.textura.get_image()
		if Rect2i(Vector2i.ZERO,im.get_size()).has_point(local) and im.get_pixelv(local).a>.1: return item.id
	var adicionais:=planta.sobre(apontada())
	if not adicionais.is_empty(): return adicionais[-1].id
	return int(planta.em(apontada()).get("id",-1))

func _exit_tree() -> void:
	if populacao!=null: populacao.finalizar()


func luz_apontada() -> int:
	var mouse:=get_global_mouse_position()
	for id in visuais:
		if visuais[id].visible and TerrenoPlex.contem(planta,planta.objetos.get(id,{}).get("celula",Vector2i(-1,-1))) and DesenhoLuzPlex.apontada(visuais[id],mouse): return int(id)
	return -1

func preparar_remocao(c:Vector2i) -> void:
	editor.remocao_celula=c
	editor.remocao_direta=luz_apontada()
	if editor.remocao_direta<0:
		var mouse:=get_global_mouse_position()
		for item in planta.objetos.values():
			if not CortinasPalcoPlex.eh(str(item.tipo)):continue
			var p:=ApoiosPlex.posicao(planta,item);var v:=GeometriaPlex.objeto(item,planta,nivel_paredes)
			var pixel:=Vector2i((mouse-GradePlex.projetar(Vector2(p.x,p.y),p.z)-Vector2(v.origin[0],v.origin[1])).floor())
			var im:Image=v.textura.get_image()
			if Rect2i(Vector2i.ZERO,im.get_size()).has_point(pixel) and im.get_pixelv(pixel).a>.1:editor.remocao_direta=item.id;break

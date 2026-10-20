extends Node2D

const CENA_PERSONAGEM = preload("res://cenas/personagens/personagem.tscn")
const VISUAIS_DIRETOS = ["luz_teto","luz_parede","luz_chao","pose","pose_quebrado"]
const CENA_OBJETO = preload("res://cenas/objetos/objeto.tscn")
var planta := PlantaPlex.new()
var rotas: RotasPlex
var editor: EditorPlex
var tarefas: TarefasPlex
var portas := PortasPlex.new()
var personagens: Array = []
var visuais: Dictionary = {}
var chao := ChaoPlex.new()
var composicao := CenaPlex.new()
var mundo := Node2D.new()
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
var clientes: ClientesPlex
var compras: ComprasPlex
var projetos_endo: ProjetosEndoPlex
var quebrados: DestinosQuebradosPlex
var terminal_ui := TerminalUIPlex.new()
var catalogo_modelos := UIModelosPlex.new()
var carteira := CarteiraPlex.new()
var clique_personagem: PersonagemPlex
var clique_terminal := -1
var inicio_direito := Vector2.ZERO
var interface_gestao := InterfaceGestaoPlex.new()
var desenho_salas := DesenhoSalasPlex.new()
var visor := VisorPlex.new()
var velocidade_tempo := 1.0
var calendario := CalendarioPlex.new()
var conforto: ConfortoPlex
var campanha := false
var compras_construcao := 0
var ultimo_minuto := -1
var operacao: OperacaoRestaurantePlex
var mapa_conforto: MapaConfortoPlex
var fantasias: FantasiasRestaurantePlex
var vestiario_ui:=UIVestiarioPlex.new()

func _ready() -> void:
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
	conforto = ConfortoPlex.new(self)
	clientes = ClientesPlex.new(self)
	atendimento = CaixaPlex.new(self)
	rondas = RondasPlex.new(self)
	animatronicos = AnimatronicosPlex.new(self)
	cortinas = CortinasPalcoPlex.new(self)
	lazer = LazerPlex.new(self)
	compras = ComprasPlex.new(self)
	operacao = OperacaoRestaurantePlex.new(self)
	fantasias = FantasiasRestaurantePlex.new(self)
	quebrados = DestinosQuebradosPlex.new(self)
	projetos_endo = ProjetosEndoPlex.new(self)
	projetos_endo.aviso.connect(painel.mensagem)
	mapa_conforto = MapaConfortoPlex.new()
	mapa_conforto.jogo = self
	mapa_conforto.z_index = 120
	add_child(mapa_conforto)
	desenho_salas.salas = ambientes
	desenho_salas.z_index = -2
	chao.planta = planta
	chao.z_index = -2
	add_child(chao)
	add_child(desenho_salas)
	add_child(composicao)
	iluminacao.configurar(chao, composicao)
	sombras_luzes.z_index = -1
	add_child(sombras_luzes)
	mundo.name = "ObjetosEPersonagens"
	mundo.y_sort_enabled = true
	add_child(mundo)
	add_child(camera)
	camera.position = GradePlex.projetar(GradePlex.CENTRO)
	camera.zoom = Vector2(1.4, 1.4)
	cursor.editor = editor
	cursor.z_index = 100
	add_child(cursor)
	add_child(painel)
	painel.configurar_hud(self)
	vestiario_ui.configurar(self)
	add_child(vestiario_ui)
	interface_gestao.configurar(self)
	visor.configurar(self)
	terminal_ui.configurar(self)
	add_child(terminal_ui)
	add_child(carteira)
	carteira.configurar(self)
	add_child(catalogo_modelos)
	catalogo_modelos.configurar(self)
	painel.catalogo_solicitado.connect(catalogo_modelos.abrir)
	painel.cabelo_escolhido.connect(func(valor):
		if is_instance_valid(selecionado) and AparenciaPlex.permitida(selecionado): selecionado.cabelo = valor)
	painel.uniforme_escolhido.connect(func(valor):
		if is_instance_valid(selecionado) and AparenciaPlex.permitida(selecionado): selecionado.uniforme = valor)
	compras.aviso.connect(painel.mensagem)
	servicos.aviso.connect(painel.mensagem)
	painel.ferramenta_escolhida.connect(escolher_ferramenta)
	painel.luz_ajustada.connect(ajustar_luz)
	painel.cor_escolhida.connect(func(valor): editor.cor = valor)
	painel.expressao_escolhida.connect(func(valor):
		if is_instance_valid(selecionado):
			selecionado.animacao.expressao = valor)
	painel.autonomia_escolhida.connect(func(valor):
		if is_instance_valid(selecionado):
			selecionado.automatico = valor)
	painel.salvar_solicitado.connect(salvar)
	painel.carregar_solicitado.connect(painel.hud.abrir_saves)
	painel.paredes_solicitadas.connect(trocar_paredes)
	painel.recorte_escolhido.connect(func(valor):
		cortar_frente = valor
		sincronizar())
	editor.aviso.connect(painel.mensagem)
	editor.spawn_solicitado.connect(spawn)
	editor.destino_quebrado_escolhido.connect(quebrados.mover)
	tarefas.aviso.connect(painel.mensagem)
	tarefas.montado.connect(finalizar_montagem)
	planta.alterada.connect(sincronizar)
	sincronizar()

func escolher_ferramenta(valor: String) -> void:
	traco_parede.encerrar()
	if editor.ferramenta!=valor: editor.estado_visual=str(CatalogoPlex.objetos.get(valor,{}).get("estado_padrao",""))
	editor.ferramenta = valor
	if valor != "editar_luz":
		luz_selecionada = -1
	var texto: String = CatalogoPlex.objetos[valor].nome if CatalogoPlex.objetos.has(valor) else valor.replace("spawn:", "Colocar ").replace("_", " ").capitalize()
	painel.ferramenta.text = texto + " · direção " + str(editor.rotacao + 1)

func spawn(modelo: String, celula: Vector2i, cargo: String = "funcionario") -> PersonagemPlex:
	var oficio := modelo if modelo in ["faxineiro","entregador","caixista","seguranca"] else ""
	if not oficio.is_empty(): modelo="humano"
	var ator: PersonagemPlex = CENA_PERSONAGEM.instantiate()
	var robo: bool = CatalogoMontagemPlex.robotico(modelo)
	ator.equipe = personagens
	ator.set_meta("cabelo_reservado",str(operacao.criacao.get("cabelo","nenhum")))
	ator.cargo = cargo
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
	selecionar(ator)
	painel.mensagem("Personagem colocado. Ele procura tarefas compatíveis e acessíveis.")
	return ator

func despawn(ator: PersonagemPlex) -> void:
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
	ator.queue_free()

func spawn_endo(suporte: int) -> void:
	var registro: Dictionary = planta.objetos[suporte]
	if registro.get("instaladas_endo",[]).is_empty(): return
	var anterior := selecionado
	var ator := spawn(registro.componentes_endo.get("modelo_estrutura","endo"), registro.celula)
	ator.animacao.endo_config = registro.componentes_endo.duplicate(true)
	ator.animacao.endo_partes = registro.instaladas_endo.duplicate()
	if is_instance_valid(anterior): selecionar(anterior)
	ator.suporte = suporte
	ator.direcao = GradePlex.direcao_suporte(registro.rotacao)
	ator.pecas = registro.pecas
	ator.altura = EscadasPlex.altura(ator.local,planta)+ApoioMontagemPlex.elevacao(ator)
	ator.atualizar_visual(false)
	composicao.atualizar_personagem(ator)
	painel.mensagem("Componente instalado no suporte. A manutenção continua a montagem.")

func selecionar(ator: PersonagemPlex) -> void:
	if is_instance_valid(selecionado):
		selecionado.selecionado = false
	selecionado = ator
	selecionado.selecionado = true
	painel.selecao.text = IdentidadesPlex.completo(ator)
	painel.autonomia.set_pressed_no_signal(ator.automatico)
	painel.mostrar_aparencia(ator)

func sincronizar() -> void:
	if PortasPlex.normalizar(planta):
		rotas.reconstruir()
	chao.queue_redraw()
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
		visuais[id].atualizar(planta.objetos[id], planta, nivel_paredes, composicao.recorte.niveis, iluminacao.salas)
	for registro in planta.objetos.values():
		if registro.tipo=="suporte" and registro.get("endo",false) and registro.has("componentes_endo") and not registro.get("robo_saiu",false) and not personagens.any(func(a): return a.suporte==registro.id): spawn_endo(registro.id)
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

func finalizar_montagem(suporte: int) -> void:
	for ator in personagens:
		if ator.suporte == suporte:
			ator.mudar_modelo(planta.objetos[suporte].get("modelo_alvo",planta.objetos[suporte].get("fur_modelo","coelho")))
			ator.caixa_qualidade = str(planta.objetos[suporte].get("qualidade_pecas",planta.objetos[suporte].get("qualidade",ator.caixa_qualidade)))
			ator.robotica.clear()
			var marca: int = planta.objetos[suporte].get("destino_quebrado",-1)
			if planta.objetos.has(marca): planta.objetos[marca].dono = ator.identificador
			ator.direcao = GradePlex.direcao_suporte(planta.objetos[suporte].rotacao)
			saida_montagem.iniciar(ator, suporte)

func levar_ao_palco(ator: PersonagemPlex) -> bool:
	return poses.encaminhar(ator)

func ajustar_luz(valor: Dictionary) -> void:
	editor.luz_padrao = valor.duplicate()
	if planta.objetos.has(luz_selecionada):
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

func trocar_paredes() -> void:
	nivel_paredes = nivel_paredes % 4 + 1
	painel.paredes.text = "Paredes: " + str(nivel_paredes) + " / 4 · Ctrl"
	sincronizar()

func apontada() -> Vector2i:
	var mouse := get_global_mouse_position()
	for item in planta.objetos.values():
		if item.tipo == "palco":
			if Geometry2D.is_point_in_polygon(mouse,GradePlex.poligono(GradePlex.projetar(Vector2(item.celula),18.0))): return item.celula
	return GradePlex.selecionar(mouse)

func _process(delta: float) -> void:
	var comando_camera := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if not carteira.aberto() and not terminal_ui.aberto() and not catalogo_modelos.aberto() and not painel.hud.menu_aberto() and not (get_viewport().gui_get_focus_owner() is LineEdit) and not comando_camera.is_zero_approx():
		visor.automatico = false
		camera.position += comando_camera.normalized() * 400.0 * minf(delta, 0.05) / camera.zoom.x
		camera.force_update_scroll()
	if arrastando and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		arrastando = false
	if traco_parede.ativo and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		traco_parede.encerrar()
	portas.atualizar(delta*velocidade_tempo, planta, personagens)
	CabinesPlex.atualizar(planta, personagens)
	composicao.atualizar(planta, nivel_paredes, cortar_frente)
	iluminacao.atualizar()
	for id in visuais:
		if visuais[id].visible and planta.objetos.has(id):
			visuais[id].atualizar(planta.objetos[id], planta, nivel_paredes, composicao.recorte.niveis, iluminacao.salas)
	ambientes.atualizar()
	interface_gestao.atualizar(delta)
	painel.hud.atualizar(delta)
	desenho_salas.queue_redraw()
	var local := apontada()
	cursor.celula = local
	cursor.altura = planta.altura(local)
	cursor.valido = GradePlex.dentro(local)
	if CatalogoPlex.objetos.has(editor.ferramenta) and editor.ferramenta != "chao":
		cursor.valido = planta.pode_colocar(editor.ferramenta, local, editor.rotacao) and (planta.sobreposto(editor.ferramenta) or editor.livre(local))
	if CatalogoPlex.objetos.get(editor.ferramenta,{}).get("piso",false): cursor.valido=GradePlex.dentro(local)
	if CatalogoPlex.objetos.get(editor.ferramenta,{}).has("pacote"):
		for c in MobiliaPlex.modulos(editor.ferramenta,local,editor.rotacao):
			if not planta.pode_colocar(editor.ferramenta,c,editor.rotacao) or not editor.livre(c): cursor.valido=false
	if editor.ferramenta=="pose_quebrado": cursor.valido=quebrados.livre(local,editor.marca_quebrado)
	cursor.visible = not carteira.aberto() and not catalogo_modelos.aberto() and not terminal_ui.aberto() and not painel.bloqueia_mouse(get_viewport().get_mouse_position())
	cursor.niveis = composicao.recorte.niveis
	cursor.salas = iluminacao.salas
	cursor.queue_redraw()

func _physics_process(delta: float) -> void:
	delta *= velocidade_tempo
	if delta <= 0: return
	operacao.atualizar(delta)
	calendario.atualizar(delta)
	conforto.atualizar(delta)
	if ultimo_minuto != calendario.minuto_do_dia():
		ultimo_minuto = calendario.minuto_do_dia()
		iluminacao.atualizar_sol(calendario)
	compras.atualizar(delta)
	projetos_endo.atualizar(delta)
	atendimento.atualizar(delta)
	rondas.atualizar(delta)
	fantasias.atualizar(delta)
	servicos.atualizar(delta)
	clientes.atualizar(delta)
	lazer.atualizar(delta)
	tarefas.atualizar(delta)
	saida_montagem.atualizar()
	poses.atualizar()
	animatronicos.atualizar(delta)
	cortinas.atualizar(delta)
	for ator in personagens:
		ator.set_meta("tarefa_ativa", servicos.trabalhos.has(ator.identificador) or tarefas.trabalhos.has(ator.identificador) or FantasiasRestaurantePlex.ocupando(ator) or ator.pose >= 0 or ator.trabalho in ["liberar_saida","caixa","ir_caixa","usar_caixa"] or ator.cargo in ["cliente", "crianca"] or ator.funcao in ["caixa","seguranca"])
		ator.atualizar(delta, planta, rotas, personagens)
		composicao.atualizar_personagem(ator)
	for sombra in sombras_luzes.get_children():
		sombra.atualizar(delta)
	espera_palco += delta
	if espera_palco >= 1.0:
		espera_palco = 0.0
		for ator in personagens:
			if ator.robo and ator.automatico and not EquipePlex.em_comando(ator) and not AnimatronicosPlex.pausado(ator) and not ator.ocupado() and ator.pronto_para_destino() and ator.pose < 0:
				levar_ao_palco(ator)

func terminal_apontado() -> int:
	var mouse := get_global_mouse_position()
	for objeto in planta.objetos.values():
		if objeto.tipo != "terminal_ibm": continue
		var p := ApoiosPlex.posicao(planta,objeto)
		var centro := GradePlex.projetar(Vector2(p.x,p.y),p.z)
		var volume := GeometriaPlex.objeto(objeto,planta,4)
		var local := Vector2i((mouse-centro-Vector2(volume.origin[0],volume.origin[1])).floor())
		var imagem: Image = volume.textura.get_image()
		if Rect2i(Vector2i.ZERO,imagem.get_size()).has_point(local) and imagem.get_pixelv(local).a > .1: return objeto.id
	return -1

func personagem_apontado() -> PersonagemPlex:
	var mouse := get_global_mouse_position()
	var lista := personagens.duplicate()
	lista.sort_custom(func(a,b): return a.position.y>b.position.y)
	for pessoa in lista:
		for camada in pessoa.pintura.fontes:
			var fonte: Sprite2D = camada.sprite
			if not is_instance_valid(fonte) or not fonte.visible or fonte.texture==null: continue
			var imagem: Image = fonte.texture.get_image()
			var ponto := Vector2i(fonte.to_local(mouse).floor())
			if Rect2i(Vector2i.ZERO,imagem.get_size()).has_point(ponto) and imagem.get_pixelv(ponto).a>.1: return pessoa
	return null

func _input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.keycode==KEY_ESCAPE and painel.hud!=null:
		if painel.hud.arquivos.visible: painel.hud.arquivos.fechar()
		elif vestiario_ui.aberto(): vestiario_ui.adiar()
		elif carteira.aberto(): carteira.fechar()
		elif terminal_ui.aberto(): terminal_ui.fechar()
		elif catalogo_modelos.aberto(): catalogo_modelos.fechar()
		elif painel.hud.agenda.visible: painel.hud.agenda.hide()
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
	if vestiario_ui.aberto(): return
	if carteira.aberto():
		if evento is InputEventKey and evento.pressed and evento.keycode==KEY_ESCAPE:
			carteira.fechar()
			get_viewport().set_input_as_handled()
		return
	if catalogo_modelos.aberto():
		if evento is InputEventKey and evento.pressed and evento.keycode == KEY_ESCAPE:
			catalogo_modelos.fechar()
			get_viewport().set_input_as_handled()
		return
	if evento is InputEventMouseButton and not evento.pressed and evento.button_index == MOUSE_BUTTON_RIGHT:
		if is_instance_valid(clique_personagem) and personagens.has(clique_personagem) and evento.position.distance_to(inicio_direito)<=6:
			carteira.abrir(clique_personagem)
			get_viewport().set_input_as_handled()
		elif clique_terminal >= 0 and evento.position.distance_to(inicio_direito) <= 6 and not terminal_ui.aberto():
			terminal_ui.abrir(clique_terminal)
			get_viewport().set_input_as_handled()
		elif evento.position.distance_to(inicio_direito)<=6 and editor.ferramenta!="selecionar":
			escolher_ferramenta("selecionar")
			painel.hud.catalogo.preencher()
		clique_terminal = -1
		clique_personagem = null
	if evento is InputEventMouseButton and not evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		traco_parede.encerrar()
	if evento is InputEventMouseButton and not evento.pressed and evento.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		arrastando = false

func _unhandled_input(evento: InputEvent) -> void:
	if vestiario_ui.aberto() or carteira.aberto() or catalogo_modelos.aberto() or terminal_ui.aberto() or painel.hud.menu_aberto(): return
	if evento is InputEventMouse and painel.bloqueia_mouse(evento.position):
		return
	if evento is InputEventKey and evento.pressed and not evento.echo:
		if evento.keycode == KEY_CTRL:
			trocar_paredes()
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
				clique_personagem = personagem_apontado()
				clique_terminal = terminal_apontado() if clique_personagem==null else -1
				if clique_terminal >= 0 or is_instance_valid(clique_personagem): arrastando = false
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
				ambientes.definir(apontada(), editor.ferramenta.trim_prefix("sala:"))
				interface_gestao.inspecionar(apontada())
			elif editor.ferramenta == "inspecionar":
				interface_gestao.inspecionar(apontada())
			elif editor.ferramenta == "editar_luz":
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
			elif CatalogoPlex.base(editor.ferramenta) == "parede" and not editor.ferramenta.begins_with("janela"):
				traco_parede.iniciar(apontada(), editor)
			else:
				editor.aplicar(apontada())
	if evento is InputEventMouseMotion and (clique_terminal>=0 or is_instance_valid(clique_personagem)) and evento.position.distance_to(inicio_direito) > 6:
		clique_terminal = -1
		clique_personagem = null
		arrastando = true
	if evento is InputEventMouseMotion and arrastando:
		visor.automatico = false
		camera.position -= evento.relative / camera.zoom
		camera.force_update_scroll()
	elif evento is InputEventMouseMotion and traco_parede.ativo:
		traco_parede.estender(apontada(), editor)

func clicar_mundo(celula: Vector2i) -> void:
	var ator := personagem_apontado()
	if is_instance_valid(ator):
		if ator==selecionado and celula!=ator.celula and planta.transitavel(celula):
			comandar(celula)
			return
		if ator.robo and ator.suporte>=0 and is_instance_valid(selecionado) and not selecionado.robo:
			tarefas.solicitar(selecionado,ator.suporte)
			return
		selecionar(ator)
		return
	if is_instance_valid(selecionado): comandar(celula)
	else: interface_gestao.inspecionar(celula)

func comandar(celula: Vector2i) -> void:
	if not is_instance_valid(selecionado):
		painel.mensagem("Selecione um personagem para mover.")
		return
	if selecionado.cargo in ["cliente", "crianca", "adolescente"]:
		painel.mensagem("Clientes seguem a visita automaticamente. Use a aba Clientes para adicionar famílias.")
		return
	if selecionado.robo and selecionado.modelo != "endo" and EscadasPlex.palco(planta.em(celula)):
		var marcas := planta.sobre(celula, "pose")
		if marcas.is_empty() or not poses.encaminhar(selecionado, marcas[0].id):
			painel.mensagem("O destino no palco precisa de uma Pose livre e acessível.")
		else: selecionado.visita.comando_manual_ate=selecionado.relogio+15.0
		return
	if servicos.trabalhos.has(selecionado.identificador): servicos.cancelar(selecionado)
	if planta.objetos.has(selecionado.pose) and int(planta.objetos[selecionado.pose].get("reserva",0))==selecionado.identificador:
		planta.objetos[selecionado.pose].reserva=0
	selecionado.pose = -1
	var caminho: Array[Vector2i]
	var objeto := planta.em(celula)
	if not selecionado.robo and objeto.get("tipo", "") in ["caixa", "suporte"]:
		if tarefas.solicitar(selecionado, objeto.id):
			return
	var origem := selecionado.origem_rota()
	if selecionado.suporte >= 0:
		if selecionado.modelo == "endo":
			painel.mensagem("O endo aguarda a montagem no suporte.")
			return
		caminho = rotas.sair_suporte(selecionado.suporte, celula)
	elif objeto.is_empty() or planta.transitavel(celula):
		caminho = rotas.caminho(origem, celula)
	else:
		caminho = rotas.aproximar(origem, objeto.id)
	if caminho.is_empty():
		painel.mensagem("Sem caminho. Palcos precisam de uma escada alinhada.")
		return
	tarefas.liberar(selecionado)
	selecionado.trabalho = ""
	if selecionado.suporte >= 0:
		selecionado.suporte = -1
	selecionado.andar(caminho)
	if selecionado.has_meta("limites_rota"): selecionado.remove_meta("limites_rota")
	selecionado.visita.comando_manual_ate=selecionado.relogio+15.0
	painel.mensagem("Destino atualizado. As tarefas automáticas continuam ativas.")

func salvar() -> void:
	var sucesso := ArquivoPlex.salvar(planta, personagens, servicos.gravar(), clientes.gravar(), compras.gravar(), {"ativa":campanha,"calendario":calendario.gravar(),"gastos_construcao":compras_construcao,"visao":GradePlex.visao,"paredes":nivel_paredes,"cortar_frente":cortar_frente,"operacao":operacao.gravar()})
	painel.mensagem("Partida salva. Ela está disponível na janela Carregar." if sucesso else "Não foi possível salvar a partida.")

func carregar(caminho: String = ArquivoPlex.CAMINHO) -> void:
	var dados := ArquivoPlex.ler(caminho)
	if dados.is_empty():
		painel.mensagem("Ainda não há uma construção salva.")
		return
	terminal_ui.fechar()
	carteira.fechar()
	traco_parede.encerrar()
	saida_montagem.limpar()
	cortinas.assinatura = 0
	cortinas.fases.clear()
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
	planta.funcoes_salas.clear()
	servicos.trabalhos.clear()
	planta.proximo_id = 1
	for registro in dados.objetos:
		var objeto: Dictionary = registro.duplicate()
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
	var progresso: Dictionary = dados.get("campanha",{})
	campanha = bool(progresso.get("ativa",false))
	operacao.restaurar(progresso.get("operacao",{}))
	compras_construcao = int(progresso.get("gastos_construcao",0))
	calendario.restaurar(progresso.get("calendario",{}))
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
		var ator := spawn(registro.modelo, Vector2i(registro.celula[0], registro.celula[1]))
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
	clientes.restaurar(dados.get("clientes", {}))
	compras.restaurar(dados.get("compras",{}))
	AdministradorPlex.reservar_cabelo(self)
	FachadaPlex.corrigir_decoracao(planta)
	planta.alterada.emit()
	painel.hud.atualizar(1.0)
	painel.mensagem("Construção carregada. As tarefas são recalculadas pelos objetos disponíveis.")

func enquadrar() -> void:
	visor.enquadrar()

func alternar_tela_cheia() -> void:
	visor.alternar_tela_cheia()


func preco_construcao(tipo: String) -> int:
	return 0 if operacao.debug else MobiliaPlex.preco(tipo)

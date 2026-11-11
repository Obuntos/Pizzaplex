class_name CarteiraPlex
extends CanvasLayer

const T = preload("res://scripts/gestao/tema.gd")
var jogo: Node
var ator: PersonagemPlex
var raiz := Control.new()
var folha := PanelContainer.new()
var conteudo := VBoxContainer.new()
var atividade: Label
var condicao: Label
var botao_energia: Button
var espera := 0.0
var documento:DocumentoPessoaPlex

func configurar(mundo: Node) -> void:
	jogo = mundo
	layer = 90
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.theme = T.criar()
	add_child(raiz)
	var fundo := ColorRect.new()
	fundo.color = Color(0.035,0.05,0.04,.76)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed: fechar())
	raiz.add_child(fundo)
	raiz.add_child(folha)
	var rolagem := ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	folha.add_child(rolagem)
	conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conteudo.add_theme_constant_override("separation",18)
	rolagem.add_child(conteudo)
	get_viewport().size_changed.connect(redimensionar)
	fechar()

func aberto() -> bool:
	return raiz.visible

func redimensionar() -> void:
	var tela := get_viewport().get_visible_rect().size
	if is_instance_valid(documento) and documento.visible:documento.ajustar(tela);return
	var visitante: bool=is_instance_valid(ator) and ator.cargo in ["morador","cliente","crianca","adolescente"] and not ator.robo
	folha.size = Vector2(minf(650,tela.x-32),minf(400 if visitante else 760 if is_instance_valid(ator) and ator.robo else 540,tela.y-32))
	JanelasMoveisPlex.centralizar(folha,tela)

func fechar() -> void:
	raiz.hide()
	if is_instance_valid(documento):documento.hide()
	ator = null

func abrir(entrada: PersonagemPlex) -> void:
	jogo.terminal_ui.fechar()
	ator = entrada
	IdentidadesPlex.garantir(ator)
	for filho in conteudo.get_children():
		conteudo.remove_child(filho)
		filho.queue_free()
	if is_instance_valid(documento):documento.queue_free();documento=null
	if ator.robo:fechar();return
	if not ator.robo:
		folha.hide();documento=DocumentoPessoaPlex.new();raiz.add_child(documento);documento.construir(self);condicao=null;botao_energia=null;raiz.show();redimensionar();atualizar_atividade();return
	folha.show()
	var visitante := ator.cargo in ["cliente","crianca","adolescente","morador"]
	var destaque := Color("a74b3b") if visitante else T.VERDE
	if ator.robo:
		destaque = Color("3d5966")
		if ator.robotica.get("sangrando",false):
			var id_robo:=ator.identificador
			T.botao(conteudo,"Limpar animatrônico",func(): fechar();jogo.controle.solicitar("limpar_robo",id_robo))
	folha.add_theme_stylebox_override("panel",T.caixa(T.PAPEL,destaque,10,24))
	var topo := HBoxContainer.new()
	conteudo.add_child(topo)
	var marca := T.texto(topo,"PIZZAPLEX  /  VISITANTES" if visitante else "PIZZAPLEX  /  EQUIPE",12,destaque,true)
	if ator.robo: marca.text = "PIZZAPLEX  /  REGISTRO TÉCNICO"
	marca.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	T.botao(topo,"Fechar ×",fechar)
	T.texto(conteudo,"Registro de morador" if ator.cargo=="morador" else "Passe de visita" if visitante else ("Ficha técnica" if ator.robo else "Carteira de funcionário"),25,destaque)
	conteudo.add_child(HSeparator.new())
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation",22)
	conteudo.add_child(linha)
	var moldura := PanelContainer.new()
	moldura.add_theme_stylebox_override("panel",T.caixa(Color("d9dacb"),T.LINHA,4,8))
	linha.add_child(moldura)
	var retrato := TextureRect.new()
	retrato.texture = RetratoEquipePlex.criar(ator)
	retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	retrato.custom_minimum_size = Vector2(100,112)
	moldura.add_child(retrato)
	var dados := VBoxContainer.new()
	dados.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(dados)
	T.texto(dados,"NOME / IDENTIFICAÇÃO",10,T.SUAVE,true)
	var nome := T.texto(dados,IdentidadesPlex.completo(ator),23)
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not str(ator.identidade.get("apelido","")).is_empty(): T.texto(dados,"Conhecido como “"+str(ator.identidade.apelido)+"”",14,destaque)
	if not ator.robo: T.texto(dados,str(ator.identidade.idade)+" anos · "+("Criança acompanhada" if ator.cargo=="crianca" else "Visitante" if visitante else "Funcionário"),13,T.SUAVE)
	T.texto(dados,("PASSE " if visitante else "REGISTRO ")+str(ator.identidade.get("morador_id",str(ator.identificador).pad_zeros(4))),12,destaque,true)
	conteudo.add_child(HSeparator.new())
	if ator.cargo=="morador":
		var perfil: Dictionary=jogo.populacao.perfis.get(str(ator.identidade.get("morador_id","")),{})
		var familia: Dictionary=jogo.populacao.familias.get(str(perfil.get("familia","")),{})
		T.texto(conteudo,str(perfil.get("ocupacao","Morador")),16).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		T.texto(conteudo,str(familia.get("endereco","")),14,T.SUAVE)
		T.texto(conteudo,"FAMÍLIA",10,destaque,true)
		for id in familia.get("membros",[]):
			var parente: Dictionary=jogo.populacao.perfis[id]
			T.texto(conteudo,str(parente.nome)+" · "+str(int(parente.idade))+" anos",13,T.SUAVE)
	elif visitante:
		T.texto(conteudo,"Conforto: %.1f / 10 · Satisfação: %d%%" % [float(ator.visita.get("conforto",5.0)),roundi(float(ator.visita.get("satisfacao",70.0)))],13,T.SUAVE)
		T.texto(conteudo,"ACOMPANHAMENTO",10,destaque,true)
		var acompanhantes: Array = jogo.personagens.filter(func(pessoa): return pessoa!=ator and pessoa.cargo in ["cliente","crianca","adolescente"] and ator.familia>=0 and pessoa.familia==ator.familia)
		var adultos := acompanhantes.filter(func(pessoa): return pessoa.cargo=="cliente").size()
		var criancas := acompanhantes.filter(func(pessoa): return pessoa.cargo=="crianca").size()
		var adolescentes := acompanhantes.filter(func(pessoa): return pessoa.cargo=="adolescente").size()
		T.texto(conteudo,"Visitante em família · "+str(adultos)+" adulto(s) e "+str(criancas)+" criança(s) e "+str(adolescentes)+" adolescente(s) acompanhando" if not acompanhantes.is_empty() else "Visitante sem acompanhantes",14).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		for pessoa in acompanhantes:
			var papel := "Responsável" if pessoa.identificador==ator.responsavel else "Adulto" if pessoa.cargo=="cliente" else "Adolescente" if pessoa.cargo=="adolescente" else "Criança"
			T.texto(conteudo,papel+" · "+IdentidadesPlex.completo(pessoa)+" · "+str(pessoa.identidade.idade)+" anos",13,T.SUAVE).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif ator.robo:fechar();return
	if not ator.robo:
		T.texto(conteudo,"FUNÇÃO PRINCIPAL",10,destaque,true)
		T.texto(conteudo,EquipePlex.NOMES.get(ator.funcao,"Geral"),19)
		var apoios := PackedStringArray()
		for funcao in ator.funcoes_secundarias: apoios.append(EquipePlex.NOMES.get(funcao,funcao))
		if not apoios.is_empty(): T.texto(conteudo,"Apoio: "+", ".join(apoios),13,T.SUAVE).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		T.texto(conteudo,"Conforto do animatrônico: "+str(ConfortoPlex.robo(ator))+" / 10",13,T.SUAVE)
		T.texto(conteudo,"MODELO",10,destaque,true)
		T.texto(conteudo,ator.modelo.replace("_"," ").capitalize(),18)
		var linha_nome := HBoxContainer.new()
		conteudo.add_child(linha_nome)
		var campo := LineEdit.new()
		campo.text = str(ator.identidade.get("nome_robotico",""))
		campo.placeholder_text = "Nome do animatrônico"
		campo.max_length = 40
		campo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha_nome.add_child(campo)
		var salvar := func():
			var valor := campo.text.strip_edges().replace("\n"," ").replace("\r"," ").replace("\t"," ")
			ator.identidade.nome_robotico = valor
			nome.text = IdentidadesPlex.completo(ator)
			jogo.selecionar(ator)
		T.botao(linha_nome,"Salvar nome",salvar)
		campo.text_submitted.connect(func(_valor): salvar.call())
	if ator.robo:
		AnimatronicosPlex.garantir(ator)
		T.botao(conteudo,"Redefinir lugar",func(): jogo.atracoes.redefinir_lugar(ator.identificador)).disabled=bool(ator.visita.get("montando_atracao",false))
		T.texto(conteudo,"TIPO DE APRESENTAÇÃO",11,destaque,true)
		var apresentacao := OptionButton.new()
		apresentacao.custom_minimum_size.y=40
		for tipo in [["cantar","Cantar"],["falar","Falar"],["dancar","Dançar"]]:
			apresentacao.add_item(tipo[1])
			apresentacao.set_item_metadata(apresentacao.item_count-1,tipo[0])
			if ator.robotica.apresentacao==tipo[0]: apresentacao.select(apresentacao.item_count-1)
		apresentacao.item_selected.connect(func(i): ator.robotica.apresentacao=str(apresentacao.get_item_metadata(i)); ator.relogio=0.0)
		conteudo.add_child(apresentacao)
		botao_energia=T.botao(conteudo,"",func():
			AnimatronicosPlex.comandar_energia(ator,bool(ator.robotica.get("desligado_manual",false)))
			atualizar_atividade())
		var energia:=CheckButton.new()
		energia.text="Manter sempre ligado"
		energia.button_pressed=ator.robotica.modo=="sempre"
		energia.toggled.connect(func(ligado):
			ator.robotica.modo="sempre" if ligado else "automatico"
			if ligado: AnimatronicosPlex.comandar_energia(ator,true)
			atualizar_atividade())
		conteudo.add_child(energia)
		if ReparosPlex.reparavel(ator):
			var pausa:=CheckButton.new()
			pausa.text="Pausar para manutenção"
			pausa.button_pressed=bool(ator.robotica.get("manutencao_solicitada",false))
			pausa.toggled.connect(func(v): ator.robotica.manutencao_solicitada=v)
			conteudo.add_child(pausa)
		T.texto(conteudo,"Automático: liga com a plateia do palco. Desligar mantém este robô parado e permite o reparo com peças da Oficina. Ligar retoma o modo escolhido.",12,T.SUAVE).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		condicao=T.texto(conteudo,"",13,destaque)
		condicao.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	else:
		condicao=null
		botao_energia=null
	if TurnosEquipePlex.trabalhador(ator) and ator.funcao!="seguranca":T.botao(conteudo,"Descansar",func():jogo.turnos.descansar(ator))
	atividade = T.texto(conteudo,"",13,T.SUAVE)
	atividade.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	T.texto(conteudo,"ENTRADA EM FAMÍLIA  ·  RESTAURANTE & SHOWS" if visitante else "IDENTIFICAÇÃO INTERNA  ·  PESSOAL AUTORIZADO",10,destaque,true).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	raiz.show()
	redimensionar()
	atualizar_atividade()

func atualizar_atividade() -> void:
	if is_instance_valid(documento) and documento.visible:documento.atualizar()
	if TurnosEquipePlex.trabalhador(ator):
		atividade.text="ENERGIA: %d / 100 · %s"%[roundi(ator.energia),"Descansando" if ator.trabalho=="descansar" else "Chegando ao trabalho" if str(ator.visita.get("turno_etapa","")).begins_with("cheg") else "Fora do turno" if ator.visita.get("fora_turno",false) else ator.trabalho.replace("_"," ").capitalize()]
		return
	if not ator.robo and ator.cargo in ["morador","cliente","crianca","adolescente"]:
		atividade.text="Conversa em andamento" if ator.visita.get("socializando",false) else "Na cidade" if ator.cargo=="morador" else "Visitando a pizzaria"
		return
	if ator.cargo=="morador":
		atividade.text="Agora: "+jogo.populacao.atividade(str(ator.identidade.get("morador_id","")))
		return
	var nomes := {"manual":"Controle manual","seguir_administrador":"Acompanhando o administrador","fugir":"Saindo em pânico","morto":"Sem atividade","reparar":"Reparando animatrônico","circular_salao":"Circulando pelo salão","reservado_pecas":"Reservado para reutilização de peças","ir_pose":"Indo para o posto","liberar_saida":"Saindo da oficina","caixa":"No posto da registradora","caixa_sentado":"Sentado na registradora","piscina":"Brincando na piscina de bolinhas","recolher_bolinhas":"Recolhendo bolinhas","usar_caixa":"Recebendo pagamento","ir_caixa":"Indo ao caixa","fila_caixa":"Aguardando na fila","pagar":"Pagando a refeição","aguardar_familia":"Aguardando acompanhantes","vigiar_palco":"Vigiando o palco","vigiar_ibm":"Verificando o IBM","ronda":"Em ronda","aguardar_caixa":"Aguardando registradora","varrer":"Varrendo o chão","esfregar":"Limpando o piso","montar":"Montando animatrônico","lavar":"Lavando pratos","preparar":"Preparando comida","jogar":"Jogando","assistir":"Assistindo ao show","sentar_mesa":"À mesa","apresentar":"Apresentando show","visitar":"Visitando o restaurante","seguir_familia":"Entrando com a família","procurar_salao":"Procurando acesso ao salão","aguardar_acesso":"Aguardando acesso ao restaurante","sair_visita":"Saindo da visita"}
	if ator.robo and is_instance_valid(condicao):
		AnimatronicosPlex.garantir(ator)
		var desligado_manual:=bool(ator.robotica.get("desligado_manual",false))
		botao_energia.text="Ligar" if desligado_manual else "Desligar"
		botao_energia.disabled=int(ator.robotica.get("reparo_por",0))>0 or (desligado_manual and bool(ator.robotica.get("avariado",false)))
		botao_energia.tooltip_text=""
		for controle in conteudo.get_children():
			if not controle is CheckButton: continue
			if controle.text=="Pausar para manutenção": controle.set_pressed_no_signal(bool(ator.robotica.get("manutencao_solicitada",false)))
			elif controle.text=="Manter sempre ligado": controle.set_pressed_no_signal(ator.robotica.modo=="sempre")
		var qualidade:String={"media":"Médias","boa":"Boas","otima":"Perfeitas"}.get(str(ator.robotica.qualidade),"Médias")
		condicao.text=AnimatronicosPlex.titulo(ator)+" · Peças: "+qualidade+"\nDesgaste: "+str(roundi(float(ator.robotica.desgaste)*50))+"% · Uso: "+str(ator.robotica.minutos_uso)+" min"
	if ator.robo:
		if int(ator.robotica.get("reparo_por",0))>0:
			atividade.text="Agora: Recebendo reparos"
			return
		if bool(ator.robotica.get("desligado_manual",false)) and not ator.ocupado():
			atividade.text="Agora: Desligado manualmente"+(" · aguardando reparo" if ReparosPlex.danificado(ator) else "")
			return
	if ator.robo and ator.trabalho=="apresentar":
		atividade.text="Agora: "+str({"desligado":"Aguardando plateia","ativando":"Iniciando apresentação","ligado":"Apresentando show","desligando":"Desligando","avariado":"Aguardando manutenção"}.get(str(ator.robotica.get("estado","desligado")),"Aguardando plateia"))
		return
	atividade.text = "Agora: "+str(nomes.get(ator.trabalho, "A caminho" if ator.ocupado() else "Disponível" if ator.cargo=="funcionario" else "Em visita"))

func _process(delta: float) -> void:
	if not aberto(): return
	if not is_instance_valid(ator) or not jogo.personagens.has(ator):
		fechar()
		return
	espera += delta
	if espera>=.25:
		espera = 0
		atualizar_atividade()



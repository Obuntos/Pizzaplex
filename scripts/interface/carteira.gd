class_name CarteiraPlex
extends CanvasLayer

const T = preload("res://scripts/gestao/tema.gd")
var jogo: Node
var ator: PersonagemPlex
var raiz := Control.new()
var folha := PanelContainer.new()
var conteudo := VBoxContainer.new()
var atividade: Label
var espera := 0.0

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
	folha.size = Vector2(minf(650,tela.x-32),minf(540,tela.y-32))
	folha.position = (tela-folha.size)*.5

func fechar() -> void:
	raiz.hide()
	ator = null

func abrir(pessoa: PersonagemPlex) -> void:
	jogo.terminal_ui.fechar()
	jogo.catalogo_modelos.fechar()
	ator = pessoa
	IdentidadesPlex.garantir(ator)
	for filho in conteudo.get_children():
		conteudo.remove_child(filho)
		filho.queue_free()
	var visitante := ator.cargo in ["cliente","crianca"]
	var destaque := Color("a74b3b") if visitante else T.VERDE
	if ator.robo: destaque = Color("3d5966")
	folha.add_theme_stylebox_override("panel",T.caixa(T.PAPEL,destaque,10,24))
	var topo := HBoxContainer.new()
	conteudo.add_child(topo)
	var marca := T.texto(topo,"PIZZAPLEX  /  VISITANTES" if visitante else "PIZZAPLEX  /  EQUIPE",12,destaque,true)
	if ator.robo: marca.text = "PIZZAPLEX  /  REGISTRO TÉCNICO"
	marca.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	T.botao(topo,"Fechar ×",fechar)
	T.texto(conteudo,"Passe de visita" if visitante else ("Ficha técnica" if ator.robo else "Carteira de funcionário"),25,destaque)
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
	T.texto(dados,("PASSE " if visitante else "REGISTRO ")+str(ator.identificador).pad_zeros(4),12,destaque,true)
	conteudo.add_child(HSeparator.new())
	if visitante:
		T.texto(conteudo,"ACOMPANHAMENTO",10,destaque,true)
		var familia := "Visita em família"
		if ator.cargo=="crianca":
			for pessoa_grupo in jogo.personagens:
				if pessoa_grupo.identificador==ator.responsavel: familia = "Responsável: "+IdentidadesPlex.completo(pessoa_grupo)
		else:
			var nomes := PackedStringArray()
			for pessoa_grupo in jogo.personagens:
				if pessoa_grupo.responsavel==ator.identificador: nomes.append(IdentidadesPlex.curto(pessoa_grupo))
			familia = "Acompanhantes: "+", ".join(nomes) if not nomes.is_empty() else "Visita sem acompanhantes"
		T.texto(conteudo,familia,14).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif not ator.robo:
		T.texto(conteudo,"FUNÇÃO PRINCIPAL",10,destaque,true)
		T.texto(conteudo,EquipePlex.NOMES.get(ator.funcao,"Geral"),19)
		var apoios := PackedStringArray()
		for funcao in ator.funcoes_secundarias: apoios.append(EquipePlex.NOMES.get(funcao,funcao))
		if not apoios.is_empty(): T.texto(conteudo,"Apoio: "+", ".join(apoios),13,T.SUAVE).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		T.texto(conteudo,"MODELO",10,destaque,true)
		T.texto(conteudo,ator.modelo.replace("_"," ").capitalize(),18)
	atividade = T.texto(conteudo,"",13,T.SUAVE)
	atividade.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	T.texto(conteudo,"ENTRADA EM FAMÍLIA  ·  RESTAURANTE & SHOWS" if visitante else "IDENTIFICAÇÃO INTERNA  ·  PESSOAL AUTORIZADO",10,destaque,true).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	raiz.show()
	redimensionar()
	atualizar_atividade()

func atualizar_atividade() -> void:
	var nomes := {"varrer":"Varrendo o chão","esfregar":"Limpando o piso","montar":"Montando animatrônico","lavar":"Lavando pratos","preparar":"Preparando comida","jogar":"Jogando","assistir":"Assistindo ao show","sentar_mesa":"À mesa","apresentar":"Apresentando show","visitar":"Visitando o restaurante"}
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

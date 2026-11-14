class_name UILivroPlex
extends CanvasLayer
## Montagem de animatrônicos. À esquerda, o elenco: quem já foi estudado
## aparece em cores e pode ser escolhido; os demais ficam em silhueta. No
## meio, o escolhido num palco com lâmpadas de letreiro. À direita, a ficha
## com a descrição e o botão que inicia a montagem.

const TEXTO=Color("8a5a38")
var jogo: Node
var raiz:=Control.new()
var janela:PanelContainer
var id_atual:=""
var voltar:Callable
var palco:FichasEstudoPlex.Palco
var luzes:LuzesShowPlex
var retrato:TextureRect
var nome:Label
var subtitulo:Label
var texto:Label
var acao:Button
var situacao:Label
var botao_voltar:Button
var elenco:=VBoxContainer.new()
var miniaturas:Dictionary={}
var assinatura:=-1

func configurar(cena: Node) -> void:
	jogo=cena;layer=80
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raiz.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(raiz)
	raiz.theme=TemaHudPlex.criar();raiz.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var escuro:=ColorRect.new();escuro.color=Color(.05,.025,.015,.7);escuro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raiz.add_child(escuro)
	var show:=JanelaShowPlex.criar(raiz,"Montagem",fechar)
	janela=show
	var corpo:=HBoxContainer.new();corpo.add_theme_constant_override("separation",14);show.corpo.add_child(corpo)
	# --- Elenco: escolher quem montar.
	var coluna_elenco:=VBoxContainer.new();coluna_elenco.add_theme_constant_override("separation",6);corpo.add_child(coluna_elenco)
	var rotulo:=KitPlex.texto(coluna_elenco,"ELENCO",12,ShowPlex.AMBAR,"forte");rotulo.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	elenco.add_theme_constant_override("separation",8);coluna_elenco.add_child(elenco)
	for id in EstudosPlex.ORDEM:criar_miniatura(id)
	# --- Palco com o escolhido.
	palco=FichasEstudoPlex.Palco.new();palco.custom_minimum_size=Vector2(256,430);corpo.add_child(palco)
	retrato=TextureRect.new();palco.add_child(retrato)
	luzes=LuzesShowPlex.em_volta(palco,22,5)
	# --- Ficha.
	var folha:=PanelContainer.new();folha.add_theme_stylebox_override("panel",ShowPlex.estilo("placa",26,ShowPlex.MADEIRA,{"volutas":true}));corpo.add_child(folha)
	var coluna:=VBoxContainer.new();coluna.add_theme_constant_override("separation",8);folha.add_child(coluna)
	nome=KitPlex.texto(coluna,"",34,ShowPlex.NANQUIM,"titulo");nome.uppercase=true;nome.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	nome.add_theme_color_override("font_outline_color",ShowPlex.NANQUIM);nome.add_theme_constant_override("outline_size",6)
	subtitulo=KitPlex.texto(coluna,"",12,TEXTO,"forte");subtitulo.uppercase=true;subtitulo.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var fio:=ColorRect.new();fio.color=Color("cfa676");fio.custom_minimum_size=Vector2(0,2);fio.mouse_filter=Control.MOUSE_FILTER_IGNORE;coluna.add_child(fio)
	texto=KitPlex.texto(coluna,"",15,TEXTO,"forte");texto.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;texto.custom_minimum_size.x=400;texto.size_flags_vertical=Control.SIZE_EXPAND_FILL
	texto.add_theme_constant_override("line_spacing",3)
	situacao=KitPlex.texto(coluna,"",13,ShowPlex.VINHO,"forte");situacao.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var rodape:=HBoxContainer.new();rodape.add_theme_constant_override("separation",10);coluna.add_child(rodape)
	botao_voltar=KitPlex.botao(rodape,"Voltar",func():
		var destino:=voltar
		fechar()
		if destino.is_valid():destino.call(),"noite",15)
	botao_voltar.icon=VintagePlex.icone("seta_esquerda");botao_voltar.custom_minimum_size.y=50
	botao_voltar.tooltip_text="Voltar ao cartaz de estudo"
	acao=KitPlex.botao(rodape,"CONSTRUIR",construir,"ouro",18);acao.custom_minimum_size.y=50;acao.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	jogo.livro.alterado.connect(recarregar);get_viewport().size_changed.connect(centralizar);raiz.hide()

## Miniatura do elenco: plaquinha com o boneco em tamanho natural.
func criar_miniatura(id:String) -> void:
	var b:=Button.new();b.focus_mode=Control.FOCUS_NONE;b.custom_minimum_size=Vector2(84,124)
	b.pressed.connect(func():escolher(id))
	b.mouse_entered.connect(func():
		if not b.disabled:ShowPlex.pular(b,4.0))
	elenco.add_child(b)
	var figura:=FichasEstudoPlex.retrato(b,id,1,true)
	figura.position=((b.custom_minimum_size-figura.custom_minimum_size)*.5).round()
	b.resized.connect(func():figura.position=((b.size-figura.custom_minimum_size)*.5).round())
	miniaturas[id]={"botao":b,"figura":figura}

func vestir_miniaturas() -> void:
	for id in miniaturas:
		var b:Button=miniaturas[id].botao
		var pronto:bool=jogo.atracoes.pesquisado(id)
		var atual:bool=id==id_atual
		b.disabled=not pronto
		b.tooltip_text=str(FichasEstudoPlex.ficha(id).nome) if pronto else "Ainda não estudado"
		(miniaturas[id].figura as TextureRect).self_modulate=Color.WHITE if pronto else Color("1d0e08")
		var moldura:=Color("e8a237") if atual else ShowPlex.MADEIRA_ESCURA
		b.add_theme_stylebox_override("normal",ShowPlex.estilo("placa",0,moldura))
		b.add_theme_stylebox_override("hover",ShowPlex.estilo("placa",0,moldura.lightened(.2),{"folha":Color("fff0cc")}))
		b.add_theme_stylebox_override("pressed",ShowPlex.estilo("placa",0,moldura.darkened(.15)))
		b.add_theme_stylebox_override("disabled",ShowPlex.estilo("placa",0,Color("4a3a30"),{"folha":Color("cdb891")}))
		b.add_theme_stylebox_override("focus",StyleBoxEmpty.new())

func aberto() -> bool: return raiz.visible and is_inside_tree()
func fechar() -> void: raiz.hide();voltar=Callable()

## Abre a montagem num animatrônico estudado. Sem id, usa o primeiro estudado.
func abrir(id:String="", ao_voltar:Callable=Callable()) -> void:
	if id.is_empty():
		for candidato in EstudosPlex.ORDEM:
			if jogo.atracoes.pesquisado(candidato):id=candidato;break
	if id.is_empty() or not jogo.atracoes.pesquisado(id):return
	voltar=ao_voltar
	botao_voltar.visible=voltar.is_valid()
	raiz.show()
	mostrar(id)
	centralizar.call_deferred()
	ShowPlex.entrar.call_deferred(janela)

func escolher(id:String) -> void:
	if id==id_atual or not jogo.atracoes.pesquisado(id):return
	mostrar(id)
	ConfetePlex.sobre(palco,18)

func mostrar(id:String) -> void:
	id_atual=id
	var f:=FichasEstudoPlex.ficha(id)
	var cor:=FichasEstudoPlex.cor(id)
	palco.borda=cor;palco.queue_redraw()
	retrato.queue_free()
	retrato=FichasEstudoPlex.retrato(palco,id,4,false)
	palco.move_child(retrato,0)
	nome.text=str(f.nome);nome.add_theme_color_override("font_color",cor)
	subtitulo.text=str(f.get("subtitulo",""));subtitulo.visible=not subtitulo.text.is_empty()
	texto.text=str(f.get("longa",""))
	vestir_miniaturas()
	assinatura=-1;atualizar()

func centralizar() -> void:
	janela.reset_size();JanelasMoveisPlex.centralizar(janela,get_viewport().get_visible_rect().size)

func atualizar() -> void:
	if id_atual.is_empty():return
	var chave:=hash([id_atual,jogo.atracoes.fila,jogo.personagens.size()])
	if chave==assinatura:return
	assinatura=chave
	var em_obra:bool=jogo.atracoes.ocupado(id_atual)
	var seta:bool=jogo.atracoes.fila.any(func(o): return o.modelo==id_atual and o.fase=="seta")
	acao.text="POSICIONAR SETA" if seta else "EM MONTAGEM" if em_obra else "CONSTRUIR"
	acao.disabled=em_obra and not seta
	situacao.text="Escolha onde ele vai ficar." if seta else "A equipe já está montando." if em_obra else "Leve as peças à bancada de montagem da oficina."
	# As lâmpadas do palco correm enquanto ele pode ser montado.
	luzes.modo=LuzesShowPlex.Modo.PISCAR if em_obra and not seta else LuzesShowPlex.Modo.CORRER

func construir() -> void:
	ConfetePlex.sobre(acao,36)
	reservar(id_atual)

func reservar(id: String) -> void:
	if not AtracoesCatalogoPlex.permitido(id) or not jogo.livro.possui(id): return
	if jogo.atracoes.retomar(id): fechar();return
	if jogo.atracoes.iniciar_disponivel(id):fechar()

func recarregar() -> void:
	assinatura=-1
	if aberto(): vestir_miniaturas();atualizar()

func _process(_delta:float) -> void:
	if aberto():atualizar()

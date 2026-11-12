class_name UILivroPlex
extends CanvasLayer
## Ficha de um animatrônico já estudado, como uma página impressa do
## restaurante: faixas quadriculadas, o retrato num palco com cortina e,
## ao lado, o nome e a descrição completa. A montagem começa daqui.

const TINTA=Color("2a1408")
const SEPIA=Color("8a5a38")
const TEXTO=Color("9a5f3c")
var jogo: Node
var raiz:=Control.new()
var janela:=PanelContainer.new()
var id_atual:=""
var voltar:Callable
var palco:FichasEstudoPlex.Palco
var retrato:TextureRect
var nome:Label
var subtitulo:Label
var texto:Label
var acao:Button
var situacao:Label
var botao_voltar:Button
var assinatura:=-1

func configurar(cena: Node) -> void:
	jogo=cena;layer=80
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raiz.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(raiz)
	raiz.theme=TemaHudPlex.criar();raiz.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var escuro:=ColorRect.new();escuro.color=Color(.05,.025,.015,.7);escuro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raiz.add_child(escuro)
	raiz.add_child(janela);janela.add_theme_stylebox_override("panel",KitPlex.quadro([Color("2a1408"),Color("b8955e")],Color("f1dcaa"),1,0))
	var pagina:=VBoxContainer.new();pagina.add_theme_constant_override("separation",0);janela.add_child(pagina)
	# Cabeçalho: faixa quadriculada com o título no meio.
	var cabeca:=Control.new();cabeca.custom_minimum_size=Vector2(860,64);pagina.add_child(cabeca)
	var xadrez:=FichasEstudoPlex.Xadrez.new();xadrez.custom_minimum_size.y=40;xadrez.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);xadrez.offset_top=12;xadrez.offset_bottom=52;cabeca.add_child(xadrez)
	var placa:=PanelContainer.new();placa.add_theme_stylebox_override("panel",KitPlex.quadro([Color("2a1408"),Color("b8955e")],Color("f1dcaa"),1,10));cabeca.add_child(placa)
	placa.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);placa.grow_horizontal=Control.GROW_DIRECTION_BOTH;placa.offset_top=4
	var titulo:=KitPlex.texto(placa,"Ficha de animatrônico",24,SEPIA,"titulo");titulo.uppercase=true
	var fechar_botao:=KitPlex.fechar(cabeca,fechar);fechar_botao.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);fechar_botao.offset_left=-52;fechar_botao.offset_top=12;fechar_botao.offset_right=-12;fechar_botao.offset_bottom=52
	var arquivo:=KitPlex.texto(cabeca,"Arquivo Pizzaplex · 1958",11,SEPIA,"forte");arquivo.position=Vector2(18,56)
	# Corpo: palco com o retrato e a coluna de texto.
	var margem:=MarginContainer.new()
	for lado in ["left","right"]:margem.add_theme_constant_override("margin_"+lado,28)
	margem.add_theme_constant_override("margin_top",18);margem.add_theme_constant_override("margin_bottom",18)
	pagina.add_child(margem)
	var corpo:=HBoxContainer.new();corpo.add_theme_constant_override("separation",28);margem.add_child(corpo)
	palco=FichasEstudoPlex.Palco.new();palco.custom_minimum_size=Vector2(280,452);corpo.add_child(palco)
	retrato=TextureRect.new();palco.add_child(retrato)
	var coluna:=VBoxContainer.new();coluna.add_theme_constant_override("separation",10);coluna.size_flags_horizontal=Control.SIZE_EXPAND_FILL;corpo.add_child(coluna)
	nome=KitPlex.texto(coluna,"",36,TINTA,"titulo");nome.uppercase=true
	nome.add_theme_color_override("font_outline_color",Color("2a1408"));nome.add_theme_constant_override("outline_size",6)
	subtitulo=KitPlex.texto(coluna,"",13,SEPIA,"forte");subtitulo.uppercase=true
	var fio:=ColorRect.new();fio.color=Color("cfa676");fio.custom_minimum_size=Vector2(0,2);fio.mouse_filter=Control.MOUSE_FILTER_IGNORE;coluna.add_child(fio)
	texto=KitPlex.texto(coluna,"",17,TEXTO,"forte");texto.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;texto.custom_minimum_size.x=480;texto.size_flags_vertical=Control.SIZE_EXPAND_FILL
	texto.add_theme_constant_override("line_spacing",4)
	# Montagem: a ação que antes ficava na blueprint.
	var montagem:=KitPlex.painel(coluna,"campo",10)
	var linha:=HBoxContainer.new();linha.add_theme_constant_override("separation",10);montagem.add_child(linha)
	var info:=VBoxContainer.new();info.add_theme_constant_override("separation",0);info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;info.alignment=BoxContainer.ALIGNMENT_CENTER;linha.add_child(info)
	KitPlex.texto(info,"MONTAGEM",12,KitPlex.AMBAR,"forte")
	situacao=KitPlex.texto(info,"",13,KitPlex.AREIA);situacao.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;situacao.custom_minimum_size.x=220
	acao=KitPlex.botao(linha,"CONSTRUIR",func():reservar(id_atual),"ouro",17);acao.custom_minimum_size=Vector2(190,46);acao.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	var rodape:=HBoxContainer.new();coluna.add_child(rodape)
	botao_voltar=KitPlex.botao(rodape,"Voltar ao cartaz",func():
		var destino:=voltar
		fechar()
		if destino.is_valid():destino.call(),"noite",15)
	botao_voltar.icon=VintagePlex.icone("seta_esquerda")
	pagina.add_child(FichasEstudoPlex.Xadrez.new())
	jogo.livro.alterado.connect(recarregar);get_viewport().size_changed.connect(centralizar);raiz.hide()

func aberto() -> bool: return raiz.visible and is_inside_tree()
func fechar() -> void: raiz.hide();voltar=Callable()

## Abre a ficha de um animatrônico estudado. Sem id, usa o primeiro estudado.
func abrir(id:String="", ao_voltar:Callable=Callable()) -> void:
	if id.is_empty():
		for candidato in EstudosPlex.ORDEM:
			if jogo.atracoes.pesquisado(candidato):id=candidato;break
	if id.is_empty() or not jogo.atracoes.pesquisado(id):return
	id_atual=id;voltar=ao_voltar
	var f:=FichasEstudoPlex.ficha(id)
	var cor:=FichasEstudoPlex.cor(id)
	palco.borda=cor;palco.queue_redraw()
	retrato.queue_free()
	retrato=FichasEstudoPlex.retrato(palco,id,4,false)
	nome.text=str(f.nome);nome.add_theme_color_override("font_color",cor)
	subtitulo.text=str(f.get("subtitulo",""));subtitulo.visible=not subtitulo.text.is_empty()
	texto.text=str(f.get("longa",""))
	botao_voltar.visible=voltar.is_valid()
	assinatura=-1;raiz.show();atualizar();centralizar.call_deferred()
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

func reservar(id: String) -> void:
	if not AtracoesCatalogoPlex.permitido(id) or not jogo.livro.possui(id): return
	if jogo.atracoes.retomar(id): fechar();return
	if jogo.atracoes.iniciar_disponivel(id):fechar()

func recarregar() -> void:
	assinatura=-1
	if aberto(): atualizar()

func _process(_delta:float) -> void:
	if aberto():atualizar()

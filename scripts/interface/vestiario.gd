class_name UIVestiarioPlex
extends CanvasLayer

const T = preload("res://scripts/interface/tema_hud.gd")
var jogo: Node
var raiz:=Control.new()
var janela:=PanelContainer.new()
var anterior:=1.0

func configurar(cena: Node) -> void:
	jogo=cena
	layer=120
	add_child(raiz)
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.theme=T.criar()
	var fundo:=ColorRect.new()
	fundo.color=Color(.05,.025,.015,.72)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(fundo)
	raiz.add_child(janela)
	janela.add_theme_stylebox_override("panel",KitPlex.moldura("janela",20))
	var coluna:=VBoxContainer.new()
	coluna.add_theme_constant_override("separation",14)
	janela.add_child(coluna)
	KitPlex.placa(coluna,"Vestiário",22)
	var texto:=T.texto(coluna,"Escolha um mascote para receber e entreter as crianças e os adolescentes no salão.",15,T.PAPEL)
	texto.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	texto.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	texto.custom_minimum_size.x=480
	var opcoes:=HBoxContainer.new()
	opcoes.alignment=BoxContainer.ALIGNMENT_CENTER
	coluna.add_child(opcoes)
	for spec in [["fantasia_coelho","Coelho"]]:
		var modelo: String=spec[0]
		var card:=Button.new()
		card.custom_minimum_size=Vector2(200,276)
		# Cartão de papel: o friso fica dourado ao passar o mouse.
		card.add_theme_stylebox_override("normal",KitPlex.moldura("papel",12))
		for estado in ["hover","pressed","hover_pressed"]:card.add_theme_stylebox_override(estado,KitPlex.moldura("papel_ativo",12))
		card.add_theme_stylebox_override("focus",KitPlex.moldura("contorno_ouro"))
		opcoes.add_child(card)
		var conteudo:=VBoxContainer.new()
		conteudo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		conteudo.offset_left=14
		conteudo.offset_right=-14
		conteudo.offset_top=14
		conteudo.offset_bottom=-14
		conteudo.mouse_filter=Control.MOUSE_FILTER_IGNORE
		card.add_child(conteudo)
		var imagem:=TextureRect.new()
		var atlas:=CatalogoPlex.atlas_vazio()
		atlas.atlas=load("res://assets/personagens/"+modelo+("/ancoras_3/" if modelo=="fantasia_coelho" else "/")+"parado.png")
		atlas.region=Rect2(0,0,128,100) if modelo=="fantasia_coelho" else Rect2(0,0,64,100)
		imagem.texture=atlas
		imagem.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		imagem.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		imagem.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		imagem.custom_minimum_size.y=208
		imagem.mouse_filter=Control.MOUSE_FILTER_IGNORE
		conteudo.add_child(imagem)
		KitPlex.texto(conteudo,spec[1],20,Color("2a1408"),"titulo").horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		card.pressed.connect(func(): fechar(); jogo.fantasias.vestir(modelo))
	var rodape:=HBoxContainer.new();rodape.alignment=BoxContainer.ALIGNMENT_CENTER;coluna.add_child(rodape)
	KitPlex.botao(rodape,"Agora não",adiar,"noite").custom_minimum_size.x=200
	jogo.get_viewport().size_changed.connect(redimensionar)
	raiz.hide()

func redimensionar() -> void:
	var tela: Vector2=jogo.get_viewport_rect().size
	janela.size=Vector2(560,0)
	JanelasMoveisPlex.centralizar(janela,tela)

func aberto() -> bool:
	return raiz.visible

func abrir() -> void:
	if aberto(): return
	jogo.pausar("vestiario")
	raiz.show()
	redimensionar()

func fechar() -> void:
	if not aberto(): return
	raiz.hide()
	jogo.retomar("vestiario")

func adiar() -> void:
	fechar()
	jogo.fantasias.adiar()


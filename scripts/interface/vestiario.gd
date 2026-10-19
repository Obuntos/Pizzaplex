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
	fundo.color=Color(0.025,.04,.06,.8)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(fundo)
	raiz.add_child(janela)
	janela.add_theme_stylebox_override("panel",T.caixa(Color("243039"),T.AMBAR,24))
	var coluna:=VBoxContainer.new()
	coluna.add_theme_constant_override("separation",18)
	janela.add_child(coluna)
	T.texto(coluna,"VESTIÁRIO / FANTASIAS",25,T.AMBAR)
	var texto:=T.texto(coluna,"Escolha um mascote para receber e entreter as crianças e os adolescentes no salão.",17,T.PAPEL)
	texto.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	texto.custom_minimum_size.x=640
	var opcoes:=HBoxContainer.new()
	opcoes.alignment=BoxContainer.ALIGNMENT_CENTER
	coluna.add_child(opcoes)
	for spec in [["fantasia_ovelha","Ovelha"],["fantasia_coelho","Coelho"],["fantasia_raposa","Raposa"]]:
		var modelo: String=spec[0]
		var card:=Button.new()
		card.custom_minimum_size=Vector2(200,276)
		card.add_theme_stylebox_override("normal",T.caixa(Color("334049"),T.LINHA,12))
		card.add_theme_stylebox_override("hover",T.caixa(Color("46514b"),T.AMBAR,12))
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
		var atlas:=AtlasTexture.new()
		atlas.atlas=load("res://assets/personagens/"+modelo+"/parado.png")
		atlas.region=Rect2(0,0,48,80)
		imagem.texture=atlas
		imagem.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		imagem.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		imagem.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		imagem.custom_minimum_size.y=208
		imagem.mouse_filter=Control.MOUSE_FILTER_IGNORE
		conteudo.add_child(imagem)
		T.texto(conteudo,spec[1],20).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		card.pressed.connect(func(): fechar(); jogo.fantasias.vestir(modelo))
	T.botao(coluna,"Agora não",adiar)
	jogo.get_viewport().size_changed.connect(redimensionar)
	raiz.hide()

func redimensionar() -> void:
	var tela: Vector2=jogo.get_viewport_rect().size
	janela.size=Vector2(720,440)
	janela.position=((tela-janela.size)*.5).round()

func aberto() -> bool:
	return raiz.visible

func abrir() -> void:
	if aberto(): return
	anterior=jogo.velocidade_tempo
	jogo.velocidade_tempo=0
	raiz.show()
	redimensionar()

func fechar() -> void:
	if not aberto(): return
	raiz.hide()
	jogo.velocidade_tempo=anterior

func adiar() -> void:
	fechar()
	jogo.fantasias.adiar()

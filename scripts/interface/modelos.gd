class_name UIModelosPlex
extends CanvasLayer

var jogo: Node2D
var raiz := Control.new()
var janela := PanelContainer.new()
var imagem := TextureRect.new()
var atlas := AtlasTexture.new()
var titulo := Label.new()
var detalhe := Label.new()
var animacoes := OptionButton.new()
var direcoes := OptionButton.new()
var relogio := 0.0
var modelo := ""
var acao := "parado"
var pausado := false
var arquivo := ""
var catalogo: Array = []

func aberto() -> bool:
	return raiz.visible and is_inside_tree()

func configurar(cena: Node2D) -> void:
	jogo = cena
	layer = 80
	raiz.theme = TemaTerminalPlex.criar()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(raiz)
	var fundo := ColorRect.new()
	fundo.color = Color(0.04,0.07,0.08,.84)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(fundo)
	raiz.add_child(janela)
	janela.add_theme_stylebox_override("panel",TemaTerminalPlex.caixa(Color("e8e9de"),Color("51675f"),8,22))
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation",14)
	janela.add_child(coluna)
	var topo := HBoxContainer.new()
	coluna.add_child(topo)
	TemaTerminalPlex.texto(topo,"REPERTÓRIO  /  MODELOS",20,Color("263b34"),true).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	TemaTerminalPlex.botao(topo,"Fechar",fechar)
	var corpo := HBoxContainer.new()
	corpo.add_theme_constant_override("separation",20)
	corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(corpo)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 230
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_force_pass_scroll_events = false
	corpo.add_child(scroll)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation",8)
	scroll.add_child(lista)
	catalogo = JSON.parse_string(FileAccess.get_file_as_string("res://dados/modelos_futuros.json"))
	var grupos := ["Animatrônicos","Variantes","Endoesqueletos","Estruturas especiais"]
	catalogo.sort_custom(func(a,b): return a.nome.naturalnocasecmp_to(b.nome)<0 if a.grupo == b.grupo else grupos.find(a.grupo)<grupos.find(b.grupo))
	var grupo := ""
	for item in catalogo:
		if grupo != item.grupo:
			grupo = item.grupo
			TemaTerminalPlex.texto(lista,grupo.to_upper(),11,Color("51675f"),true)
		var id: String = item.id
		var botao := TemaTerminalPlex.botao(lista,item.nome,func(): escolher(id))
		botao.clip_text = true
		botao.tooltip_text = item.nome
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var preview := VBoxContainer.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corpo.add_child(preview)
	preview.add_child(titulo)
	titulo.add_theme_color_override("font_color",Color("263b34"))
	titulo.add_theme_font_size_override("font_size",22)
	var quadro := PanelContainer.new()
	quadro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	quadro.add_theme_stylebox_override("panel",TemaTerminalPlex.caixa(Color("27373c"),Color("51675f"),6,22))
	preview.add_child(quadro)
	imagem.texture = atlas
	imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	quadro.add_child(imagem)
	preview.add_child(detalhe)
	detalhe.add_theme_color_override("font_color",Color("51675f"))
	detalhe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var controles := HBoxContainer.new()
	preview.add_child(controles)
	controles.add_child(animacoes)
	for nome in ["Frente","Frente / direita","Direita","Costas / direita","Costas","Costas / esquerda","Esquerda","Frente / esquerda"]: direcoes.add_item(nome)
	controles.add_child(direcoes)
	TemaTerminalPlex.botao(controles,"Pausar / tocar",func(): pausado = not pausado)
	animacoes.item_selected.connect(func(i): acao = animacoes.get_item_metadata(i); relogio = 0.0)
	var nota := TemaTerminalPlex.texto(coluna,"As famílias e os quebrados estão disponíveis na aba Endo da central de gestão.",12,Color("51675f"))
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	get_viewport().size_changed.connect(redimensionar)
	raiz.hide()

func redimensionar() -> void:
	var tamanho := get_viewport().get_visible_rect().size
	janela.size = Vector2(minf(1100,tamanho.x-32),minf(730,tamanho.y-32))
	janela.position = (tamanho-janela.size)*.5

func abrir() -> void:
	jogo.terminal_ui.fechar()
	raiz.show()
	redimensionar()
	if modelo.is_empty() and not catalogo.is_empty(): escolher(catalogo[0].id)

func fechar() -> void:
	raiz.hide()

func escolher(id: String) -> void:
	ClipesPlex.carregar()
	modelo = id
	relogio = 0.0
	acao = "parado"
	var d: Dictionary = ClipesPlex.modelos[id]
	titulo.text = d.nome
	detalhe.text = d.grupo+"  ·  8 direções  ·  Ciclos completos"
	animacoes.clear()
	for nome in d.clipes:
		animacoes.add_item(nome.capitalize())
		animacoes.set_item_metadata(animacoes.item_count-1,nome)
	animacoes.select(0)
	arquivo = ""
	atualizar_imagem()

func atualizar_imagem() -> void:
	if modelo.is_empty(): return
	var q := ClipesPlex.quadro(modelo,acao,direcoes.selected,relogio*1.2,relogio)
	if arquivo != q.arquivo:
		arquivo = q.arquivo
		atlas.atlas = CatalogoPlex.textura(arquivo)
	atlas.region = q.regiao

func _process(delta: float) -> void:
	if not aberto(): return
	if not pausado: relogio += delta
	atualizar_imagem()

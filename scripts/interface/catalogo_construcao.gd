class_name CatalogoConstrucaoPlex
extends RefCounted

const T = preload("res://scripts/interface/tema_hud.gd")
const CATEGORIAS = ["Paredes","Pisos","Portas e janelas","Móveis","Cozinha","Palcos","Luzes","Decoração","Limpeza"]
var jogo: Node
var painel := PanelContainer.new()
var itens := HBoxContainer.new()
var busca := LineEdit.new()
var estilos := OptionButton.new()
var titulo: Label
var categoria := "Móveis"
var botoes: Dictionary = {}
var selecionado := ""
var demolir: Button

func grupo(tipo: String) -> String:
	var d: Dictionary = CatalogoPlex.objetos[tipo]
	if d.has("categoria"): return str(d.categoria)
	var base := CatalogoPlex.base(tipo)
	if tipo in CatalogoPlex.PORTAS or tipo.begins_with("janela"): return "Portas e janelas"
	if base=="parede": return "Paredes"
	if d.get("piso",false) or tipo=="chao" or tipo.begins_with("externo_"): return "Pisos"
	if tipo.begins_with("luz_"): return "Luzes"
	if tipo in ["palco","escada","pose"] or tipo.begins_with("cortina_"): return "Palcos"
	if tipo in ["forno","geladeira","pia","bancada_preparo","armario_utensilios"]: return "Cozinha"
	if tipo in ["lixeira","lixeira_salao","vassoura","balde","armario_limpeza"]: return "Limpeza"
	if tipo in ["cadeira","mesa","mesa_longa","mesa_longa_arredondada","balcao","bancada","suporte","terminal_ibm","registradora","banco_espera","estante","armario_funcionarios","armario_ferramentas","maquina_fliperama","divisoria_porta","pia_banheiro","vaso_sanitario","ponto_recebimento"]: return "Móveis"
	return "Decoração"

func permitido(tipo: String) -> bool:
	var d: Dictionary = CatalogoPlex.objetos[tipo]
	return tipo not in ["caixa","pose_quebrado","dinheiro","pizza","fatia_pizza","prato","bandeja","copo_bebida","mancha_chao","bebida_derramada","restos_mesa","pecas_manutencao","caixa_ferramentas","parede_fachada"] and not tipo.begins_with("caixa_") and not tipo.begins_with("guarana_") and not d.has("recurso") and not d.get("entulho",false) and not d.get("compravel",false)

func configurar(cena: Node, raiz: Control) -> void:
	jogo = cena
	painel.theme = T.criar()
	painel.mouse_force_pass_scroll_events = false
	painel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	painel.offset_left = 16
	painel.offset_right = -16
	painel.offset_top = -296
	painel.offset_bottom = -108
	painel.add_theme_stylebox_override("panel",T.caixa(T.FUNDO,Color("9f8054"),8))
	raiz.add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation",4)
	painel.add_child(coluna)
	var cabecalho := HBoxContainer.new()
	coluna.add_child(cabecalho)
	titulo = T.texto(cabecalho,"CONSTRUÇÃO / MOBILIÁRIO",16,T.AMBAR)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	estilos.custom_minimum_size.x = 150
	estilos.item_selected.connect(func(i): jogo.editor.estado_visual=str(estilos.get_item_metadata(i)))
	cabecalho.add_child(estilos)
	busca.placeholder_text = "Pesquisar item"
	busca.custom_minimum_size = Vector2(180,24)
	busca.text_changed.connect(func(_v): preencher())
	cabecalho.add_child(busca)
	demolir=T.botao(cabecalho,"",func(): selecionado=""; jogo.escolher_ferramenta("remover"); preencher(),T.MARROM)
	demolir.custom_minimum_size=Vector2(46,36)
	demolir.toggle_mode=true
	demolir.tooltip_text="Demolir · Clique nos objetos para remover. Botão direito cancela."
	var martelo:=IconeHudPlex.new("demolir")
	martelo.scale=Vector2.ONE*.65
	martelo.position=Vector2(6,1)
	demolir.add_child(martelo)
	T.botao(cabecalho,"×",func(): jogo.escolher_ferramenta("selecionar"); painel.hide()).tooltip_text="Fechar construção"
	var scroll := ScrollContainer.new()
	scroll.mouse_force_pass_scroll_events = false
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(scroll)
	scroll.add_child(itens)
	var abas := ScrollContainer.new()
	abas.mouse_force_pass_scroll_events = false
	abas.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	coluna.add_child(abas)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation",3)
	abas.add_child(linha)
	for nome in CATEGORIAS:
		var b := T.botao(linha,nome,func(): categoria=nome; preencher(),T.MARROM)
		b.custom_minimum_size.y = 27
		b.add_theme_font_size_override("font_size",14)
		botoes[nome] = b
	preencher()

func icone(tipo: String) -> Texture2D:
	if tipo in ["pose","luz_teto","luz_parede","luz_chao"]: return null
	var textura := CatalogoPlex.sprite(tipo,0)
	var atlas := AtlasTexture.new()
	atlas.atlas = textura
	atlas.region = Rect2(textura.get_image().get_used_rect())
	return atlas

func preencher() -> void:
	for filho in itens.get_children():
		itens.remove_child(filho)
		filho.queue_free()
	if demolir!=null: demolir.set_pressed_no_signal(jogo.editor.ferramenta=="remover")
	estilos.clear()
	var estados: Array = CatalogoPlex.objetos.get(selecionado,{}).get("estados",[])
	estilos.visible = estados.size()>1
	for estado in estados:
		estilos.add_item(str(estado).replace("_"," ").capitalize())
		estilos.set_item_metadata(estilos.item_count-1,estado)
		if estado==jogo.editor.estado_visual: estilos.select(estilos.item_count-1)
	titulo.text = "CONSTRUÇÃO / "+categoria.to_upper()+"   ·   R GIRA"
	for nome in botoes: botoes[nome].modulate = Color.WHITE if nome==categoria else Color("929d98")
	var tipos: Array = CatalogoPlex.objetos.keys().filter(func(tipo): return permitido(tipo) and grupo(tipo)==categoria and (busca.text.is_empty() or str(CatalogoPlex.objetos[tipo].nome).to_lower().contains(busca.text.to_lower())))
	tipos.sort_custom(func(a,b): return MobiliaPlex.preco(a)<MobiliaPlex.preco(b))
	for tipo in tipos:
		var info: Dictionary = CatalogoPlex.objetos[tipo]
		var card := Button.new()
		card.custom_minimum_size = Vector2(136,104)
		card.mouse_force_pass_scroll_events = false
		card.clip_contents = true
		card.add_theme_stylebox_override("normal",T.caixa(Color("2a3638"),T.AMBAR if selecionado==tipo else Color("435354"),4))
		var pacote: Array = info.get("pacote",[1,1])
		var preco: int = jogo.preco_construcao(tipo)*int(pacote[0])*int(pacote[1])
		card.tooltip_text = str(info.nome)+"\nConforto: "+str(info.conforto)+" / 10 · "+ConfortoPlex.titulo(info.conforto)+"\nCusto: $ "+str(preco)+("\nMódulos de 18 px, acesso por escada." if info.get("logico",tipo)=="palco" else "")
		card.pressed.connect(func(): selecionado=tipo; jogo.escolher_ferramenta(tipo); preencher())
		itens.add_child(card)
		var coluna := VBoxContainer.new()
		coluna.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		coluna.offset_left = 6
		coluna.offset_right = -6
		coluna.offset_top = 4
		coluna.offset_bottom = -4
		coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coluna.add_theme_constant_override("separation",0)
		card.add_child(coluna)
		var imagem := TextureRect.new()
		imagem.texture = icone(tipo)
		imagem.custom_minimum_size = Vector2(124,56)
		imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		imagem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		imagem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coluna.add_child(imagem)
		if imagem.texture==null:
			var simbolo := IconeHudPlex.new("paredes" if tipo=="pose" else "sol")
			imagem.add_child(simbolo)
			simbolo.position = Vector2(38,3)
		var nome := T.texto(coluna,str(info.nome),14)
		nome.clip_text = true
		nome.custom_minimum_size.x = 124
		nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var custo := T.texto(coluna,"$%d · %d/10" % [preco,info.conforto],14,T.AMBAR)
		custo.clip_text = true
		custo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func alternar() -> void:
	painel.visible = not painel.visible
	jogo.visor.enquadrar_se_automatico()

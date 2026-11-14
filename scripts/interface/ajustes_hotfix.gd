extends Node

const ICONES={
	"ibm":"res://assets/interface/ajustes/ibm.png",
	"ar":"res://assets/interface/ajustes/vento.png",
	"piso":"res://assets/interface/ajustes/tiles.png",
	"paredes":"res://assets/interface/ajustes/paredes.png",
	"construir":"res://assets/interface/ajustes/martelo.png",
	"demolir":"res://assets/interface/ajustes/lixeira.png"
}

var jogo:Node
var relogio_atualizacao:=0.0
var instalado:=false

func _ready() -> void:
	jogo=get_parent()
	call_deferred("instalar")

func instalar() -> void:
	if instalado:return
	if jogo==null or not is_instance_valid(jogo.painel) or not is_instance_valid(jogo.painel.hud):return
	var hud:HudPlex=jogo.painel.hud
	if hud.expandir.get_parent()==hud.controles_horario:
		hud.controles_horario.move_child(hud.expandir,0)
		hud.expandir.custom_minimum_size=Vector2(100,52)
		hud.controles_horario.add_theme_constant_override("separation",5)
		hud.linha_tempo.add_theme_constant_override("separation",2)
		for valor in hud.velocidades:
			hud.velocidades[valor].custom_minimum_size=Vector2(32,32)
	for nome in ["amb_interruptor_antigo","antigo_barril_escuro"]:
		if CatalogoPlex.objetos.has(nome):
			var dados:Dictionary=CatalogoPlex.objetos[nome]
			dados["nome"]="Energia" if nome=="amb_interruptor_antigo" else "Lixeira"
	jogo.get_viewport().size_changed.connect(organizar_catalogo)
	organizar_catalogo()
	atualizar_icones(hud)
	instalado=true
	atualizar_bloqueios()

func _process(delta:float) -> void:
	if not instalado:
		instalar()
		return
	relogio_atualizacao+=delta
	if relogio_atualizacao<0.15:return
	relogio_atualizacao=0.0
	if jogo==null or not is_instance_valid(jogo.painel) or not is_instance_valid(jogo.painel.hud):return
	var hud:HudPlex=jogo.painel.hud
	atualizar_bloqueios()
	var catalogo:CatalogoConstrucaoPlex=hud.catalogo
	if not catalogo.painel.visible:return
	organizar_catalogo()
	corrigir_nomes(catalogo)
	adicionar_energia(catalogo)
	ajustar_cards(catalogo)
	ordenar_cards(catalogo)
	atualizar_icones(catalogo.painel)

func tutorial_ativo() -> bool:
	if jogo==null or jogo.sistemas==null or not is_instance_valid(jogo.sistemas.tutorial):return false
	return not jogo.sistemas.tutorial.intro_concluida

func atualizar_bloqueios() -> void:
	if jogo==null or not is_instance_valid(jogo.painel) or not is_instance_valid(jogo.painel.hud):return
	var hud:HudPlex=jogo.painel.hud
	var bloqueado:=tutorial_ativo()
	var etapa:=""
	if bloqueado:etapa=str(jogo.sistemas.tutorial.etapa)
	var terminal_necessario:=bloqueado and etapa in ["ibm_abrir","pizza_confirmar"]
	definir_bloqueio(hud.conforto_ui.botao,bloqueado)
	definir_bloqueio(hud.ar_ui.botao,bloqueado)
	definir_bloqueio(hud.corte,bloqueado)
	var acoes:Node=hud.catalogo_botao.get_parent()
	if hud.catalogo_botao.get_index()+1<acoes.get_child_count():
		var agenda_botao:Button=acoes.get_child(hud.catalogo_botao.get_index()+1) as Button
		definir_bloqueio(agenda_botao,bloqueado)
	definir_bloqueio(hud.terminal_atalho,bloqueado and not terminal_necessario)
	if bloqueado:
		if jogo.mapa_conforto.ativo:hud.conforto_ui.fechar()
		if hud.ar_ui.mapa.ativo:hud.ar_ui.fechar()

func definir_bloqueio(botao:Button,bloquear:bool) -> void:
	if not is_instance_valid(botao):return
	var escudo:Control=botao.get_node_or_null("TravaTutorial") as Control
	if escudo==null:
		escudo=ColorRect.new()
		escudo.name="TravaTutorial"
		(escudo as ColorRect).color=Color(.25,.27,.29,.79)
		escudo.mouse_filter=Control.MOUSE_FILTER_IGNORE
		botao.add_child(escudo)
		escudo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var cadeado:=IconeHudPlex.new("cadeado")
		cadeado.escala_pixel=1.0
		cadeado.custom_minimum_size=Vector2(24,24)
		escudo.add_child(cadeado)
		cadeado.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		cadeado.offset_left=-12
		cadeado.offset_top=-12
		cadeado.offset_right=12
		cadeado.offset_bottom=12
	botao.disabled=bloquear
	escudo.visible=bloquear
	escudo.mouse_filter=Control.MOUSE_FILTER_STOP if bloquear else Control.MOUSE_FILTER_IGNORE

func atualizar_icones(no:Node) -> void:
	if no is IconeHudPlex:
		var icone:IconeHudPlex=no as IconeHudPlex
		if ICONES.has(icone.tipo) and not icone.has_meta("imagem_substituta"):
			var textura:Texture2D=load(str(ICONES[icone.tipo])) as Texture2D
			if textura!=null:
				var imagem:=TextureRect.new()
				icone.add_child(imagem)
				imagem.texture=textura
				imagem.mouse_filter=Control.MOUSE_FILTER_IGNORE
				imagem.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
				imagem.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
				imagem.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				imagem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				if icone.tipo=="ar":
					var pixels:Image=textura.get_image()
					if pixels!=null:
						var regiao:Rect2i=pixels.get_used_rect()
						if regiao.has_area():
							var recortada:=AtlasTexture.new()
							recortada.atlas=textura
							recortada.region=Rect2(regiao)
							imagem.texture=recortada
					imagem.offset_left=2
					imagem.offset_top=2
					imagem.offset_right=-2
					imagem.offset_bottom=-2
				icone.self_modulate=Color.TRANSPARENT
				icone.set_meta("imagem_substituta",true)
	for filho in no.get_children():
		atualizar_icones(filho)

func organizar_catalogo() -> void:
	if jogo==null or not is_instance_valid(jogo.painel) or not is_instance_valid(jogo.painel.hud):return
	var catalogo:CatalogoConstrucaoPlex=jogo.painel.hud.catalogo
	var largura:float=jogo.get_viewport().get_visible_rect().size.x
	var altura:float=jogo.get_viewport().get_visible_rect().size.y
	var colunas:int=clampi(int((largura-24.0)/142.0),3,8)
	catalogo.abas.columns=colunas
	var linhas:int=ceili(float(CatalogoConstrucaoPlex.CATEGORIAS.size())/float(colunas))
	var margem_inferior:float=76.0
	var tamanho:float=minf(maxf(156.0,altura*0.53),236.0+38.0*linhas)
	tamanho=minf(tamanho,maxf(120.0,altura-margem_inferior-16.0))
	catalogo.painel.offset_left=8
	catalogo.painel.offset_right=-8
	catalogo.painel.offset_top=-margem_inferior-tamanho
	catalogo.painel.offset_bottom=-margem_inferior
	catalogo.painel.z_index=100

func corrigir_nomes(catalogo:CatalogoConstrucaoPlex) -> void:
	for tipo in ["amb_interruptor_antigo","antigo_barril_escuro"]:
		if not catalogo.cards.has(tipo):continue
		var card:Button=catalogo.cards[tipo]
		if not is_instance_valid(card):continue
		var nome:String="Energia" if tipo=="amb_interruptor_antigo" else "Lixeira"
		card.tooltip_text=nome
		for filho in card.get_children():
			if filho is VBoxContainer:
				for label in filho.get_children():
					if label is Label and not str(label.text).begins_with("$"):
						label.text=nome
	if catalogo.categoria=="Escritório" and catalogo.cards.has("amb_interruptor_antigo"):
		var interruptor:Button=catalogo.cards["amb_interruptor_antigo"]
		interruptor.hide()

func adicionar_energia(catalogo:CatalogoConstrucaoPlex) -> void:
	if catalogo.categoria!="Energia" or catalogo.cards.has("amb_interruptor_antigo"):return
	if not CatalogoPlex.objetos.has("amb_interruptor_antigo"):return
	if not catalogo.busca.text.is_empty() and not ("energia interruptor".contains(catalogo.busca.text.to_lower())):return
	var tipo:="amb_interruptor_antigo"
	var card:=Button.new()
	card.name=tipo
	card.custom_minimum_size=Vector2(138,130)
	card.clip_contents=true
	card.set_meta("tipo",tipo)
	card.tooltip_text="Energia"
	card.pressed.connect(func():
		catalogo.selecionado=tipo
		jogo.escolher_ferramenta(tipo)
		catalogo.preencher()
	)
	catalogo.itens.add_child(card)
	for estado in ["normal","hover","pressed","hover_pressed"]:card.add_theme_stylebox_override(estado,KitPlex.quadro([KitPlex.TINTA,Color("a5784c") if estado=="hover" else Color("6b4a36")],Color("4a3a2e") if estado=="hover" else Color("3b2a25"),1,7))
	catalogo.cards[tipo]=card
	var coluna:=VBoxContainer.new()
	card.add_child(coluna)
	coluna.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	coluna.offset_left=5
	coluna.offset_right=-5
	coluna.offset_top=4
	coluna.offset_bottom=-4
	coluna.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var imagem:=TextureRect.new()
	imagem.texture=catalogo.icone(tipo)
	imagem.custom_minimum_size=Vector2(120,68)
	imagem.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	imagem.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagem.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	imagem.mouse_filter=Control.MOUSE_FILTER_IGNORE
	coluna.add_child(imagem)
	var nome:=Label.new()
	nome.text="Energia"
	nome.add_theme_font_size_override("font_size",14)
	coluna.add_child(nome)
	var preco:=Label.new()
	preco.text="$ %d"%jogo.preco_construcao(tipo)
	preco.add_theme_font_size_override("font_size",13)
	coluna.add_child(preco)

func ajustar_cards(catalogo:CatalogoConstrucaoPlex) -> void:
	for card in catalogo.itens.get_children():
		if card is Button:
			card.custom_minimum_size=Vector2(138,130)
			for filho in card.get_children():
				if filho is VBoxContainer:
					for componente in filho.get_children():
						if componente is TextureRect:componente.custom_minimum_size.y=66

func chave_ordem(tipo:String,categoria:String) -> String:
	var preco:int=jogo.preco_construcao(tipo) if CatalogoPlex.objetos.has(tipo) else 999999
	if categoria=="Palcos":
		var palco:bool=(tipo.contains("palco") or PalcosMadeiraPlex.eh(tipo)) and not tipo.contains("cortina")
		return "%02d:%08d:%s"%[0 if palco else 1,preco,tipo]
	if categoria=="Armazenamento":
		var estante:bool=tipo.contains("estante") or CatalogoPlex.base(tipo)=="estante"
		return "%02d:%08d:%s"%[0 if estante else 1,preco,tipo]
	return tipo

func ordenar_cards(catalogo:CatalogoConstrucaoPlex) -> void:
	if catalogo.categoria not in ["Palcos","Armazenamento"]:return
	var cards:Array=catalogo.itens.get_children()
	cards.sort_custom(func(a,b):return chave_ordem(str(a.name),catalogo.categoria).naturalnocasecmp_to(chave_ordem(str(b.name),catalogo.categoria))<0)
	for i in cards.size():
		if cards[i].get_index()!=i:catalogo.itens.move_child(cards[i],i)

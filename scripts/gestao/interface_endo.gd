class_name UIEndoPlex
extends RefCounted

const T = preload("res://scripts/gestao/tema.gd")
var ui: TerminalUIPlex
var suporte := -1
var modelo := "coelho"
var direcao := 7
var estado: Label
var resumo: Label
var comprar: Button
var preview: TextureRect
var destino: Button
var catalogo: GridContainer

func _init(interface: TerminalUIPlex) -> void:
	ui = interface

func disponiveis() -> Array[String]:
	CatalogoMontagemPlex.carregar()
	var lista: Array[String] = []
	for id in CatalogoMontagemPlex.dados.modelos:
		if not AnimatronicosPlex.base(id).is_empty() and id != AnimatronicosPlex.base(id): continue
		lista.append(id)
	return lista

func construir() -> void:
	CatalogoMontagemPlex.carregar()
	ui.titulo.text = "Escolha o próximo animatrônico"
	ui.subtitulo.text = "Cada personagem já tem sua estrutura e carcaça. Compre peças de reposição na Oficina para cuidar dos que você já tem."
	var jogo := ui.jogo
	var suportes: Array = jogo.planta.objetos.values().filter(func(o): return o.tipo == "suporte")
	if not suportes.any(func(s): return s.id == suporte): suporte = suportes[0].id if not suportes.is_empty() else -1
	var estacao: Dictionary = jogo.planta.objetos.get(suporte,{})
	var livre: bool = jogo.projetos_endo.suporte_livre(suporte)
	if not livre and estacao.has("modelo_alvo"): modelo = estacao.modelo_alvo
	elif not AnimatronicosPlex.base(modelo).is_empty(): modelo = AnimatronicosPlex.base(modelo)
	var painel := PanelContainer.new()
	painel.add_theme_stylebox_override("panel",T.caixa(T.PAPEL,T.LINHA,5,16))
	ui.catalogo_area.add_child(painel)
	var corpo := VBoxContainer.new()
	corpo.add_theme_constant_override("separation",12)
	painel.add_child(corpo)
	T.texto(corpo,"LOCAL DE MONTAGEM",11,T.VERDE,true)
	var escolha := OptionButton.new()
	escolha.custom_minimum_size.y = 38
	for item in suportes:
		escolha.add_item("Suporte #"+str(item.id)+" · "+str(item.celula.x)+", "+str(item.celula.y))
		escolha.set_item_metadata(escolha.item_count-1,item.id)
		if item.id == suporte: escolha.select(escolha.item_count-1)
	escolha.disabled = suportes.is_empty()
	escolha.item_selected.connect(func(i): suporte = int(escolha.get_item_metadata(i)); ui.montar_pagina())
	corpo.add_child(escolha)
	if livre:
		T.texto(corpo,"ANIMATRÔNICOS",11,T.VERDE,true)
		catalogo = GridContainer.new()
		catalogo.columns = 3
		catalogo.add_theme_constant_override("h_separation",8)
		catalogo.add_theme_constant_override("v_separation",8)
		corpo.add_child(catalogo)
		for id in disponiveis(): cartao(id)
	else:
		catalogo = null
		T.texto(corpo,CatalogoMontagemPlex.nome(modelo),22,T.VERDE)
	estado = T.texto(corpo,"",13,T.SUAVE)
	estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	destino = T.botao(corpo,"Ajustar destino vermelho",func():
		var id: int = jogo.planta.objetos.get(suporte,{}).get("destino_quebrado",-1)
		if not jogo.planta.objetos.has(id): return
		jogo.editor.marca_quebrado = id
		jogo.editor.rotacao = jogo.planta.objetos[id].rotacao
		ui.fechar()
		jogo.escolher_ferramenta("pose_quebrado"))
	var quadro := PanelContainer.new()
	quadro.add_theme_stylebox_override("panel",T.caixa(Color("d7dfc8"),Color("a5b296"),5,16))
	ui.detalhe_area.add_child(quadro)
	var lateral := VBoxContainer.new()
	lateral.add_theme_constant_override("separation",12)
	quadro.add_child(lateral)
	T.texto(lateral,"SEU ANIMATRÔNICO",10,T.VERDE,true)
	T.texto(lateral,CatalogoMontagemPlex.nome(modelo),23)
	preview = TextureRect.new()
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size.y = 160
	preview.texture = RetratoEquipePlex.modelo(modelo,direcao)
	lateral.add_child(preview)
	var giro := HBoxContainer.new()
	lateral.add_child(giro)
	for par in [["↶",-1],["↷",1]]:
		var passo: int = par[1]
		var b := T.botao(giro,par[0],func(): direcao = posmod(direcao+passo,8); atualizar_preview())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	T.texto(lateral,"Estrutura e carcaça incluídas, com peças boas. O mecânico recebe as caixas e faz a montagem.",12,T.SUAVE).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	T.botao(lateral,"Peças e reparos →",func(): ui.mudar_aba("oficina"))
	resumo = T.texto(ui.catalogo_area,"",12,T.SUAVE)
	resumo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var checkout := VBoxContainer.new()
	ui.conclusao.add_child(checkout)
	T.texto(checkout,"R$ 0",26,T.VERDE,true)
	comprar = T.botao(checkout,"Encomendar "+CatalogoMontagemPlex.nome(modelo),func():
		if jogo.projetos_endo.encomendar(ui.terminal,suporte,modelo): ui.montar_pagina(),true)
	atualizar()

func cartao(id: String) -> void:
	var caixa := PanelContainer.new()
	caixa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caixa.add_theme_stylebox_override("panel",T.caixa(T.PAPEL,T.VERDE if id == modelo else T.LINHA,4,8))
	catalogo.add_child(caixa)
	var c := VBoxContainer.new()
	caixa.add_child(c)
	var img := TextureRect.new()
	img.texture = RetratoEquipePlex.modelo(id,0)
	img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size = Vector2(80,65)
	c.add_child(img)
	var nome := T.texto(c,CatalogoMontagemPlex.nome(id),13)
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	T.botao(c,"Escolhido" if id == modelo else "Escolher",func(): modelo = id; ui.montar_pagina(),id == modelo)

func atualizar_preview() -> void:
	if is_instance_valid(preview): preview.texture = RetratoEquipePlex.modelo(modelo,direcao)

func atualizar() -> void:
	if not is_instance_valid(estado): return
	var jogo := ui.jogo
	var s: Dictionary = jogo.planta.objetos.get(suporte,{})
	var livre: bool = jogo.projetos_endo.suporte_livre(suporte)
	var erro: String = jogo.projetos_endo.motivo(ui.terminal,suporte,modelo)
	comprar.disabled = not erro.is_empty()
	comprar.visible = livre or s.is_empty()
	comprar.tooltip_text = erro
	var fase: String = s.get("fase_montagem","") if not livre else ""
	estado.text = {"endo":"Montagem em andamento · "+str(s.get("instaladas_endo",[]).size())+" / 4 etapas","fur":"Finalizando a carcaça","concluido":"Montagem concluída. Para manutenção, compre peças na Oficina."}.get(fase,erro if not erro.is_empty() else "Estação disponível para receber a encomenda.")
	destino.visible = s.get("destino_quebrado",-1) >= 0 and jogo.planta.objetos.has(s.get("destino_quebrado",-1))
	var linhas: Array[String] = []
	for p in jogo.projetos_endo.pedidos.slice(maxi(0,jogo.projetos_endo.pedidos.size()-4)):
		linhas.append("#E"+str(p.id).pad_zeros(3)+" · "+CatalogoMontagemPlex.nome(p.get("modelo",modelo))+" · "+str(p.estado))
	resumo.text = "\n".join(linhas) if not linhas.is_empty() else "O personagem vem definido. Não é necessário escolher modelos de cabeça, corpo, braços ou pernas."

func redimensionar() -> void:
	if is_instance_valid(preview): preview.custom_minimum_size.y = 100 if ui.get_viewport().get_visible_rect().size.y < 740 else 160
	if is_instance_valid(catalogo): catalogo.columns = 3 if ui.janela.size.x >= 1080 else 2

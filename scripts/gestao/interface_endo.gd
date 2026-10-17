class_name UIEndoPlex
extends RefCounted

const T = preload("res://scripts/gestao/tema.gd")
var ui: TerminalUIPlex
var suporte := -1
var familia := "base"
var modelo := "coelho"
var direcao := 7
var estado: Label
var resumo: Label
var comprar: Button
var preview: TextureRect
var preview_endo: TextureRect
var legenda_preview: Label
var destino: Button
var modelos: OptionButton

func _init(interface: TerminalUIPlex) -> void:
	ui=interface

func imagem(id: String) -> Texture2D:
	return RetratoEquipePlex.modelo(id,direcao)

func construir() -> void:
	CatalogoMontagemPlex.carregar()
	ui.titulo.text="Escolha quem vai ganhar vida"
	ui.subtitulo.text="O personagem define o endo compatível. Uma compra inclui os componentes e, quando houver, a carcaça."
	var jogo:=ui.jogo
	var suportes: Array=jogo.planta.objetos.values().filter(func(o):return o.tipo=="suporte")
	if not suportes.any(func(s):return s.id==suporte):suporte=suportes[0].id if not suportes.is_empty() else -1
	var estacao:Dictionary=jogo.planta.objetos.get(suporte,{})
	var livre:bool=jogo.projetos_endo.suporte_livre(suporte)
	if not livre and estacao.has("modelo_alvo"):
		modelo=estacao.modelo_alvo
		familia=CatalogoMontagemPlex.modelo(modelo).get("familia","base")
	var painel:=PanelContainer.new()
	painel.add_theme_stylebox_override("panel",T.caixa(T.PAPEL,T.LINHA,5,18))
	ui.catalogo_area.add_child(painel)
	var corpo:=VBoxContainer.new()
	painel.add_child(corpo)
	T.texto(corpo,"01  OFICINA",11,T.VERDE,true)
	var escolha_suporte:=OptionButton.new()
	escolha_suporte.custom_minimum_size.y=38
	for item in suportes:
		escolha_suporte.add_item("Suporte #"+str(item.id)+" · "+str(item.celula.x)+", "+str(item.celula.y))
		escolha_suporte.set_item_metadata(escolha_suporte.item_count-1,item.id)
		if item.id==suporte:escolha_suporte.select(escolha_suporte.item_count-1)
	escolha_suporte.disabled=suportes.is_empty()
	escolha_suporte.item_selected.connect(func(i):suporte=int(escolha_suporte.get_item_metadata(i));ui.montar_pagina())
	corpo.add_child(escolha_suporte)
	T.texto(corpo,"02  FAMÍLIA DO ENDO",11,T.VERDE,true)
	var familias:=OptionButton.new()
	familias.custom_minimum_size.y=38
	for id in CatalogoMontagemPlex.dados.familias:
		familias.add_item(CatalogoMontagemPlex.dados.familias[id].nome)
		familias.set_item_metadata(familias.item_count-1,id)
		if id==familia:familias.select(familias.item_count-1)
	familias.disabled=not livre
	familias.item_selected.connect(func(i):familia=str(familias.get_item_metadata(i));modelo=CatalogoMontagemPlex.dados.familias[familia].modelos[0];ui.montar_pagina())
	corpo.add_child(familias)
	T.texto(corpo,"03  MODELO",11,T.VERDE,true)
	modelos=OptionButton.new()
	modelos.custom_minimum_size.y=38
	for id in CatalogoMontagemPlex.dados.familias[familia].modelos:
		modelos.add_item(CatalogoMontagemPlex.nome(id))
		modelos.set_item_metadata(modelos.item_count-1,id)
		if id==modelo:modelos.select(modelos.item_count-1)
	modelos.disabled=not livre
	modelos.item_selected.connect(func(i):modelo=str(modelos.get_item_metadata(i));ui.montar_pagina())
	corpo.add_child(modelos)
	var definicao:=CatalogoMontagemPlex.modelo(modelo)
	var nota:=T.texto(corpo,"",13,T.SUAVE)
	nota.text="Sem show por enquanto. Após a montagem, este modelo fica no destino vermelho para futura reutilização de peças." if definicao.quebrado else "Endo compatível: "+CatalogoMontagemPlex.dados.familias[familia].nome+". A carcaça deste modelo será instalada automaticamente após montar o endo."
	nota.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	T.texto(corpo,"MONTAGEM",11,T.VERDE,true)
	estado=T.texto(corpo,"",12,T.VERDE)
	estado.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	destino=T.botao(corpo,"Ajustar seta vermelha no chão",func():
		var id:int=jogo.planta.objetos.get(suporte,{}).get("destino_quebrado",-1)
		if jogo.planta.objetos.has(id):
			jogo.editor.marca_quebrado=id
			jogo.editor.rotacao=jogo.planta.objetos[id].rotacao
			ui.fechar()
			jogo.escolher_ferramenta("pose_quebrado")
			jogo.painel.mensagem("Clique em um tile livre. R gira a seta vermelha; Esc cancela."))
	var quadro:=PanelContainer.new()
	quadro.add_theme_stylebox_override("panel",T.caixa(Color("d7dfc8"),Color("a5b296"),5,8))
	ui.detalhe_area.add_child(quadro)
	var lateral:=VBoxContainer.new()
	lateral.add_theme_constant_override("separation",6)
	quadro.add_child(lateral)
	legenda_preview=T.texto(lateral,"MODELO / ENDO",10,T.VERDE,true)
	var imagens:=HBoxContainer.new()
	lateral.add_child(imagens)
	for id in [modelo,definicao.endo]:
		var img:=TextureRect.new()
		img.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		img.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size=Vector2(85,160)
		img.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		img.texture=imagem(id)
		imagens.add_child(img)
		if preview==null or imagens.get_child_count()==1:preview=img
		else:preview_endo=img
	var giro:=HBoxContainer.new()
	lateral.add_child(giro)
	for par in [["↶",-1],["↷",1]]:
		var passo:int=par[1]
		var botao:=T.botao(giro,par[0],func():direcao=posmod(direcao+passo,8);atualizar_preview())
		botao.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		botao.custom_minimum_size.y=28
	resumo=T.texto(ui.catalogo_area,"",12,T.SUAVE)
	resumo.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var checkout:=VBoxContainer.new()
	ui.conclusao.add_child(checkout)
	T.texto(checkout,"R$ 0",26,T.VERDE,true)
	comprar=T.botao(checkout,"Comprar "+CatalogoMontagemPlex.nome(modelo),func():
		if jogo.projetos_endo.encomendar(ui.terminal,suporte,modelo):ui.montar_pagina(),true)
	atualizar()

func atualizar_preview() -> void:
	if not is_instance_valid(preview):return
	preview.texture=imagem(modelo)
	preview_endo.texture=imagem(CatalogoMontagemPlex.modelo(modelo).endo)

func atualizar() -> void:
	if not is_instance_valid(estado):return
	var jogo:=ui.jogo
	var s:Dictionary=jogo.planta.objetos.get(suporte,{})
	var livre:bool=jogo.projetos_endo.suporte_livre(suporte)
	var erro:String=jogo.projetos_endo.motivo(ui.terminal,suporte,modelo)
	comprar.disabled=not erro.is_empty()
	comprar.visible=livre or s.is_empty()
	comprar.tooltip_text=erro
	var partes:Array=[] if livre else s.get("instaladas_endo",[])
	var linhas:Array[String]=[]
	for p in EndoPecasPlex.PARTES:
		linhas.append(("✓ " if partes.has(p) else "○ ")+("Base de sustentação" if p=="pernas" and familia=="barril" else EndoPecasPlex.PARTES[p]))
	var fase:String=s.get("fase_montagem","") if not livre else ""
	var situacao:String={"endo":"Montando o endo","fur":"Instalando a carcaça escolhida","concluido":"Reservado para reutilização" if CatalogoMontagemPlex.quebrado(modelo) else "Pronto para o palco"}.get(fase,erro if not erro.is_empty() else "Suporte vazio · pronto para encomendar")
	estado.text="\n".join(linhas)+"\n\n"+situacao
	destino.visible=s.get("destino_quebrado",-1)>=0 and jogo.planta.objetos.has(s.get("destino_quebrado",-1))
	if destino.visible:
		var marca:Dictionary=jogo.planta.objetos[s.destino_quebrado]
		estado.text+="\nDestino vermelho: "+str(marca.celula.x)+", "+str(marca.celula.y)+" · direção "+str(marca.rotacao+1)
	var pedidos:Array[String]=[]
	for p in jogo.projetos_endo.pedidos.slice(maxi(0,jogo.projetos_endo.pedidos.size()-5)):
		pedidos.append("#E"+str(p.id).pad_zeros(3)+" · "+CatalogoMontagemPlex.nome(p.get("modelo",modelo))+" · "+str(p.estado))
	resumo.text="ENCOMENDAS\n"+"\n".join(pedidos) if not pedidos.is_empty() else "Peças entregues em caixas físicas. A manutenção monta o endo compatível e instala a carcaça do modelo encomendado."

func redimensionar() -> void:
	if not is_instance_valid(preview):return
	var compacto:=ui.get_viewport().get_visible_rect().size.y<740
	preview.custom_minimum_size.y=100 if compacto else 160
	preview_endo.custom_minimum_size.y=100 if compacto else 160
	legenda_preview.visible=not compacto

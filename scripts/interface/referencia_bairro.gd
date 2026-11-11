class_name ReferenciaBairroPlex
extends CanvasLayer

const T=preload("res://scripts/interface/tema_hud.gd")
var jogo: Node
var predio:=""
var raiz:=Control.new()
var folha:=PanelContainer.new()
var conteudo:=VBoxContainer.new()
var tempo:=0.0
var assinatura:=-1
var scroll:=ScrollContainer.new()

func configurar(cena: Node, tipo: String) -> void:
	jogo=cena;predio=tipo;layer=116
	add_child(raiz);raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raiz.theme=T.criar()
	var sombra:=ColorRect.new();sombra.color=Color(0,0,0,.65);sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raiz.add_child(sombra)
	raiz.add_child(folha)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;folha.add_child(scroll)
	scroll.add_child(conteudo);conteudo.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	get_viewport().size_changed.connect(posicionar)
	posicionar();preencher()

func posicionar() -> void:
	var tela:=get_viewport().get_visible_rect().size
	folha.size=Vector2(minf(720,tela.x-24),minf(620,tela.y-24))
	folha.position=((tela-folha.size)*.5).round()

func preencher() -> void:
	var anterior:=scroll.scroll_vertical
	assinatura=estado_atual()
	for n in conteudo.get_children():conteudo.remove_child(n);n.queue_free()
	var topo:=HBoxContainer.new();conteudo.add_child(topo)
	T.texto(topo,"REFERÊNCIA DO BAIRRO",20).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	T.botao(topo,"×",queue_free)
	T.texto(conteudo,str(CatalogoPlex.objetos.get(predio,{}).get("nome","Restaurante")),18)
	var geral:=ReputacaoClientesPlex.nota(jogo.servicos)
	rotulo("Satisfação com a pizzaria: %.0f / 100"%geral)
	rotulo("Famílias satisfeitas podem pedir aniversários, trazendo os filhos e crianças convidadas. Reserve lugares para todos e compre o bolo para iniciar o preparo.")
	var locais: Array=[]
	for nome in jogo.populacao.dados.get("locais",{}):
		if jogo.populacao.dados.locais[nome]==predio:locais.append(nome)
	var total:=0
	for familia in jogo.populacao.familias.values():
		if not locais.has(str(familia.get("moradia",""))):continue
		total+=1
		rotulo("Família %s · satisfação %.0f / 100"%[familia.nome,ReputacaoClientesPlex.nota(jogo.servicos,str(familia.id))])
	if total==0:rotulo("Este prédio não possui famílias residentes cadastradas.")
	T.texto(conteudo,"PEDIDOS DE ANIVERSÁRIO",18)
	var pendentes:=0
	for pedido in jogo.servicos.aniversarios:
		var grupo: Dictionary=jogo.clientes.grupos.get(int(pedido.grupo),{})
		if grupo.is_empty() or grupo.get("estado","")=="saindo" or pedido.estado in ["recusado","encerrado"]:continue
		pendentes+=1
		var card:=PanelContainer.new();conteudo.add_child(card)
		var coluna:=VBoxContainer.new();card.add_child(coluna)
		var nome:=str(pedido.get("nome","Família"))
		var filhos: Array=grupo.get("criancas",[])
		T.texto(coluna,nome+" · "+str(FamiliasVisitantesPlex.membros(grupo).size())+" pessoas",17)
		var l:=T.texto(coluna,str(filhos.size())+" crianças · "+str(pedido.get("convidados",0))+" convidada(s) · "+("lugares suficientes" if ReputacaoClientesPlex.lugares(jogo,grupo) else "faltam cadeiras ou mesas"),14);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var id:=int(grupo.id)
		if pedido.estado=="solicitado":
			T.botao(coluna,"Reservar aniversário",func(): jogo.festas.reservar(id);preencher.call_deferred())
			T.botao(coluna,"Recusar pedido",func(): jogo.festas.recusar(id);preencher.call_deferred())
		elif pedido.estado=="reservado":
			T.botao(coluna,"Comprar bolo de aniversário · $ 12",func(): jogo.festas.pedir(id,true);preencher.call_deferred())
		else:T.texto(coluna,"Bolo: "+str(grupo.get("festa_estado","pedido")).replace("_"," "),14)
	if pendentes==0:rotulo("Nenhum aniversário solicitado no momento.")
	scroll.set_deferred("scroll_vertical",anterior)

func rotulo(valor: String) -> void:
	var l:=T.texto(conteudo,valor,15);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func _process(delta: float) -> void:
	tempo+=delta
	if tempo>=2.0:
		tempo=0.0
		if assinatura!=estado_atual():preencher()

func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and evento.keycode==KEY_ESCAPE:
		get_viewport().set_input_as_handled();queue_free()

func estado_atual() -> int:
	return hash([jogo.servicos.reputacao,jogo.servicos.aniversarios,jogo.clientes.grupos.values().map(func(g): return [g.id,g.get("estado",""),g.get("festa_estado",""),ReputacaoClientesPlex.lugares(jogo,g)]),jogo.servicos.saldo])

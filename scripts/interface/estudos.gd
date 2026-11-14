class_name UIEstudosPlex
extends CanvasLayer
## Cartaz de estudo da mesa de projetos. À esquerda, os animatrônicos que
## podem ser estudados, cada um numa moldura de arco com uma descrição curta:
## sem estudo aparecem só como silhueta; estudados, em cores, e abrem a ficha
## completa. À direita, a folha de controle: quem estuda, quantas horas,
## o progresso e as ações.

const TINTA=Color("2a1408")
const SEPIA=Color("8a5a38")
var jogo:Node
var raiz:=Control.new()
var janela:=PanelContainer.new()
var cartoes:=HBoxContainer.new()
var visuais:Dictionary={}
var escolhido:=""
var pessoas:Array[Dictionary]=[]
var pessoa_indice:=0
var pessoa_nome:Label
var pessoa_anterior:Button
var pessoa_seguinte:Button
var horas:=8
var horas_texto:Label
var horas_menos:Button
var horas_mais:Button
var progresso:=MedidorDocumentoPlex.new()
var percentual:=NumeroPixelPlex.new("0%",3,TINTA)
var andamento:Label
var descricao:Label
var projeto:Label
var carimbo:PanelContainer
var carimbo_texto:Label
var mesa:=-1
var estudar_botao:Button
var pausar_botao:Button
var forcar_botao:Button
var forcar_texto:Label
var aviso:=""
var aviso_ate:=0
var estado_anterior:=""

func configurar(cena:Node) -> void:
	jogo=cena;layer=75;add_child(raiz);raiz.theme=TemaHudPlex.criar();raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var sombra:=ColorRect.new();sombra.color=Color(.05,.025,.015,.65);sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raiz.add_child(sombra)
	raiz.add_child(janela);janela.add_theme_stylebox_override("panel",KitPlex.moldura("janela",16))
	var coluna:=VBoxContainer.new();coluna.add_theme_constant_override("separation",12);janela.add_child(coluna)
	# Letreiro: estrela, placa e estrela, como um cartaz de atrações.
	var topo:=HBoxContainer.new();topo.add_theme_constant_override("separation",10);coluna.add_child(topo)
	var e1:=FichasEstudoPlex.Estrela.new();e1.size_flags_vertical=Control.SIZE_SHRINK_CENTER;topo.add_child(e1)
	KitPlex.placa(topo,"Atrações em estudo",20)
	var e2:=FichasEstudoPlex.Estrela.new();e2.size_flags_vertical=Control.SIZE_SHRINK_CENTER;topo.add_child(e2)
	KitPlex.fechar(topo,fechar)
	var corpo:=HBoxContainer.new();corpo.add_theme_constant_override("separation",14);coluna.add_child(corpo)
	# --- Cartaz
	var cartaz:=KitPlex.painel(corpo,"campo",14)
	cartoes.add_theme_constant_override("separation",16);cartoes.alignment=BoxContainer.ALIGNMENT_CENTER;cartoes.size_flags_vertical=Control.SIZE_SHRINK_CENTER;cartaz.add_child(cartoes)
	for id in EstudosPlex.ORDEM:criar_cartao(id)
	# --- Folha de controle
	var lado:=VBoxContainer.new();lado.add_theme_constant_override("separation",10);lado.custom_minimum_size.x=330;corpo.add_child(lado)
	var folha:=KitPlex.painel(lado,"papel",14);folha.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var papel:=VBoxContainer.new();papel.add_theme_constant_override("separation",8);folha.add_child(papel)
	KitPlex.texto(papel,"PROJETO ESCOLHIDO",12,SEPIA,"forte")
	var linha_nome:=HBoxContainer.new();linha_nome.add_theme_constant_override("separation",10);papel.add_child(linha_nome)
	projeto=KitPlex.texto(linha_nome,"",24,TINTA,"titulo");projeto.size_flags_horizontal=Control.SIZE_EXPAND_FILL;projeto.clip_text=true
	carimbo=KitPlex.painel(linha_nome,"etiqueta",5);carimbo.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	carimbo_texto=KitPlex.texto(carimbo,"",12,KitPlex.PAPEL,"forte")
	KitPlex.secao(papel,"1 · Quem estuda e por quanto tempo",SEPIA,Color("b8955e"))
	KitPlex.texto(papel,"Pesquisador",14,TINTA,"forte")
	var s:=KitPlex.seletor(papel,func():mudar_pessoa(-1),func():mudar_pessoa(1))
	pessoa_anterior=s.menos;pessoa_seguinte=s.mais;pessoa_nome=s.valor
	pessoa_anterior.tooltip_text="";pessoa_seguinte.tooltip_text=""
	KitPlex.texto(papel,"Horas por dia",14,TINTA,"forte")
	var h:=KitPlex.seletor(papel,func():mudar_horas(-1),func():mudar_horas(1),true)
	horas_menos=h.menos;horas_mais=h.mais;horas_texto=h.valor
	horas_menos.tooltip_text="";horas_mais.tooltip_text=""
	KitPlex.secao(papel,"2 · Progresso",SEPIA,Color("b8955e"))
	var linha_progresso:=HBoxContainer.new();linha_progresso.add_theme_constant_override("separation",12);papel.add_child(linha_progresso)
	percentual.custom_minimum_size.x=72;percentual.alinhamento=HORIZONTAL_ALIGNMENT_LEFT;percentual.size_flags_vertical=Control.SIZE_SHRINK_CENTER;linha_progresso.add_child(percentual)
	var medida:=VBoxContainer.new();medida.add_theme_constant_override("separation",4);medida.size_flags_horizontal=Control.SIZE_EXPAND_FILL;linha_progresso.add_child(medida)
	var trilho:=KitPlex.painel(medida,"visor",6);trilho.custom_minimum_size.y=28
	progresso.cor=KitPlex.OURO;progresso.custom_minimum_size.y=14;trilho.add_child(progresso)
	andamento=KitPlex.texto(medida,"",13,TINTA,"forte")
	descricao=KitPlex.texto(papel,"",13,SEPIA);descricao.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;descricao.custom_minimum_size=Vector2(290,34)
	# Ações: Estudar é a principal; Pausar é secundária.
	var botoes:=HBoxContainer.new();botoes.add_theme_constant_override("separation",8);lado.add_child(botoes)
	estudar_botao=KitPlex.botao(botoes,"ESTUDAR",iniciar,"ouro",18);estudar_botao.size_flags_horizontal=Control.SIZE_EXPAND_FILL;estudar_botao.size_flags_stretch_ratio=2.0;estudar_botao.custom_minimum_size.y=48
	pausar_botao=KitPlex.botao(botoes,"PAUSAR",func(): jogo.estudos.pausar();atualizar(),"madeira",16);pausar_botao.size_flags_horizontal=Control.SIZE_EXPAND_FILL;pausar_botao.custom_minimum_size.y=48
	# Forçar estudo é um modo à parte: caixa própria com explicação.
	var forcar:=KitPlex.painel(lado,"campo",10)
	var linha_forcar:=HBoxContainer.new();linha_forcar.add_theme_constant_override("separation",10);forcar.add_child(linha_forcar)
	var textos:=VBoxContainer.new();textos.add_theme_constant_override("separation",0);textos.size_flags_horizontal=Control.SIZE_EXPAND_FILL;textos.alignment=BoxContainer.ALIGNMENT_CENTER;linha_forcar.add_child(textos)
	KitPlex.texto(textos,"ESTUDO CONTÍNUO",12,KitPlex.AMBAR,"forte")
	forcar_texto=KitPlex.texto(textos,"",12,KitPlex.AREIA);forcar_texto.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;forcar_texto.custom_minimum_size.x=160
	forcar_botao=KitPlex.botao(linha_forcar,"Forçar estudo",alternar_forcado,"verde",15);forcar_botao.custom_minimum_size=Vector2(132,44);forcar_botao.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	raiz.hide()
	if is_inside_tree():conectar_viewport()
	elif not ready.is_connected(conectar_viewport):ready.connect(conectar_viewport,CONNECT_ONE_SHOT)

## Um cartão do cartaz: moldura em arco com o retrato e, abaixo, a placa
## com nome, situação e descrição curta. O cartão inteiro é clicável.
func criar_cartao(id:String) -> void:
	var b:=Button.new();b.focus_mode=Control.FOCUS_NONE;b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for estado in ["normal","hover","pressed","hover_pressed","disabled","focus"]:b.add_theme_stylebox_override(estado,StyleBoxEmpty.new())
	cartoes.add_child(b)
	var coluna:=VBoxContainer.new();coluna.mouse_filter=Control.MOUSE_FILTER_IGNORE;coluna.add_theme_constant_override("separation",6);b.add_child(coluna)
	var arco:=FichasEstudoPlex.Arco.new();arco.custom_minimum_size=Vector2(204,232);coluna.add_child(arco)
	var retrato:=FichasEstudoPlex.retrato(arco,id,2,true)
	var legenda:=KitPlex.painel(coluna,"hud",10);legenda.mouse_filter=Control.MOUSE_FILTER_IGNORE;legenda.custom_minimum_size=Vector2(204,136)
	var textos:=VBoxContainer.new();textos.mouse_filter=Control.MOUSE_FILTER_IGNORE;textos.add_theme_constant_override("separation",4);legenda.add_child(textos)
	var nome:=KitPlex.texto(textos,str(FichasEstudoPlex.ficha(id).nome),18,KitPlex.AMBAR,"titulo");nome.uppercase=true;nome.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var estado:=KitPlex.texto(textos,"",11,KitPlex.AREIA,"forte");estado.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var curta:=KitPlex.texto(textos,str(FichasEstudoPlex.ficha(id).curta),13,KitPlex.PAPEL)
	curta.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;curta.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;curta.custom_minimum_size.x=184
	coluna.position=Vector2.ZERO
	b.custom_minimum_size=Vector2(204,232+6+136)
	b.resized.connect(func():coluna.size=b.size)
	b.pressed.connect(func():clicar(id))
	b.mouse_entered.connect(func():visuais[id].sobre=true;pintar_cartao(id))
	b.mouse_exited.connect(func():visuais[id].sobre=false;pintar_cartao(id))
	visuais[id]={"botao":b,"arco":arco,"retrato":retrato,"nome":nome,"estado":estado,"legenda":legenda,"sobre":false,"chave":""}

func situacao(id:String) -> String:
	var e:EstudosPlex=jogo.estudos
	if e.concluidos.has(id):return "estudado"
	if e.projeto==id and e.progresso>0.0:return "estudando" if e.pesquisador>=0 else "pausado"
	if id==escolhido:return "escolhido"
	return "livre" if e.pode_escolher(id) else "travado"

func pintar_cartao(id:String) -> void:
	var v:Dictionary=visuais[id]
	var s:=situacao(id)
	var cor:=FichasEstudoPlex.cor(id)
	var destaque:bool=s in ["escolhido","estudando","pausado"]
	var arco:FichasEstudoPlex.Arco=v.arco
	arco.borda=Color("f0c060") if destaque else cor if s=="estudado" else Color("c98a4b") if v.sobre else Color("8a5a38")
	arco.fundo=Color("f6e3b8") if s=="estudado" or destaque else Color("e6cf9c")
	arco.queue_redraw()
	(v.retrato as TextureRect).self_modulate=Color.WHITE if s=="estudado" else Color("1d0e08")
	(v.legenda as PanelContainer).add_theme_stylebox_override("panel",KitPlex.moldura("hud_ativo" if destaque or v.sobre else "hud",10))
	var textos:={"estudado":"ESTUDADO · VER FICHA","estudando":"EM ESTUDO","pausado":"ESTUDO PAUSADO","escolhido":"ESCOLHIDO","livre":"CLIQUE PARA ESCOLHER","travado":"AGUARDANDO"}
	(v.estado as Label).text=textos[s]
	(v.estado as Label).add_theme_color_override("font_color",KitPlex.VERDE_LUZ if s=="estudado" else KitPlex.AMBAR if destaque else KitPlex.AREIA)
	(v.nome as Label).add_theme_color_override("font_color",cor.lightened(.15) if s=="estudado" else KitPlex.AMBAR)
	var chave:=s
	if v.chave!=chave and not v.chave.is_empty() and s!="travado":KitPlex.piscar(v.arco)
	v.chave=chave

func clicar(id:String) -> void:
	var e:EstudosPlex=jogo.estudos
	if e.concluidos.has(id):
		fechar()
		jogo.painel.hud.livro_ui.abrir(id,func():abrir(mesa))
		return
	if not e.pode_escolher(id):
		avisar("Termine o estudo de %s antes de trocar de projeto."%str(FichasEstudoPlex.ficha(e.projeto).nome))
		return
	escolhido=id;aviso="";atualizar()

func conectar_viewport() -> void:
	var viewport:=get_viewport()
	if viewport==null:return
	if not viewport.size_changed.is_connected(centralizar):viewport.size_changed.connect(centralizar)
	if aberto():centralizar()
func aberto() -> bool:return raiz.visible
func fechar() -> void:raiz.hide()
func centralizar() -> void:
	if not is_inside_tree() or get_viewport()==null:return
	janela.reset_size();JanelasMoveisPlex.centralizar(janela,get_viewport().get_visible_rect().size)
func abrir(id:int) -> void:
	mesa=id;pessoas.clear();pessoa_indice=0;aviso=""
	var e:EstudosPlex=jogo.estudos
	escolhido=e.projeto if not e.projeto.is_empty() else e.proximo()
	for a in jogo.personagens:
		if EstudosPlex.elegivel(a):
			pessoas.append({"nome":IdentidadesPlex.completo(a),"id":a.identificador})
			if a.identificador==e.pesquisador:pessoa_indice=pessoas.size()-1
	mudar_pessoa(0)
	horas=e.horas;mudar_horas(0);estado_anterior="";raiz.show();atualizar();centralizar.call_deferred()
func mudar_pessoa(passo:int) -> void:
	pessoa_anterior.disabled=pessoas.size()<2;pessoa_seguinte.disabled=pessoas.size()<2
	if pessoas.is_empty():pessoa_nome.text="Nenhum disponível";return
	pessoa_indice=posmod(pessoa_indice+passo,pessoas.size());pessoa_nome.text=str(pessoas[pessoa_indice].nome)
	if passo!=0:KitPlex.piscar(pessoa_nome)
func pesquisador_id() -> int:return -1 if pessoas.is_empty() else int(pessoas[pessoa_indice].id)
func mudar_horas(delta:int) -> void:
	horas=clampi(horas+delta,1,12);horas_texto.text=str(horas)+" h"
	horas_menos.disabled=horas<=1;horas_mais.disabled=horas>=12
	if delta!=0:KitPlex.piscar(horas_texto)
func avisar(texto:String) -> void:
	aviso=texto;aviso_ate=Time.get_ticks_msec()+4000;atualizar()
func iniciar() -> void:
	if jogo.estudos.configurar(mesa,pesquisador_id(),horas,false,escolhido):aviso="";atualizar()
	else:avisar("Libere o pesquisador e um acesso à mesa.")
func alternar_forcado() -> void:
	if jogo.estudos.forcado:jogo.estudos.pausar()
	elif not jogo.estudos.configurar(mesa,pesquisador_id(),horas,true,escolhido):
		avisar("Libere o acesso à mesa e escolha um pesquisador presente no restaurante.")
	atualizar()
func atualizar() -> void:
	var e:EstudosPlex=jogo.estudos
	if escolhido.is_empty() or e.concluidos.has(escolhido) or not e.pode_escolher(escolhido):
		escolhido=e.projeto if not e.projeto.is_empty() else e.proximo()
	for id in visuais:pintar_cartao(id)
	var concluido:=escolhido.is_empty()
	var atual:=not concluido and e.projeto==escolhido
	var estado:="concluido" if concluido else "continuo" if atual and e.forcado else "andamento" if atual and e.pesquisador>=0 else "pausado" if atual and e.progresso>0 else "novo"
	if estado+escolhido!=estado_anterior:
		estado_anterior=estado+escolhido
		var rotulos:={"concluido":["CONCLUÍDO",Color("4f6a3f")],"continuo":["CONTÍNUO",Color("8b2026")],"andamento":["EM ANDAMENTO",Color("4f6a3f")],"pausado":["PAUSADO",Color("9a6a1c")],"novo":["NÃO INICIADO",Color("6b4a36")]}
		carimbo_texto.text=rotulos[estado][0]
		carimbo.add_theme_stylebox_override("panel",KitPlex.quadro([Color("2a1408")],rotulos[estado][1],1,5))
		KitPlex.piscar(carimbo)
	projeto.text=str(FichasEstudoPlex.ficha(escolhido).nome) if not concluido else "Tudo estudado"
	var fracao:=e.progresso/EstudosPlex.MINUTOS_PROJETO if atual else 0.0
	progresso.value=fracao*100.0
	percentual.texto="%d%%"%floori(fracao*100.0)
	andamento.text="%.1f de 16 horas"%(fracao*16.0) if not concluido else "Todos os projetos estudados"
	forcar_botao.text="Parar estudo" if e.forcado else "Forçar estudo"
	KitPlex.preparar_botao(forcar_botao,KitPlex.VARIANTES.vinho.face if e.forcado else KitPlex.VARIANTES.verde.face)
	forcar_botao.disabled=not e.forcado and (pessoas.is_empty() or concluido)
	forcar_texto.text="Ligado: só para ao concluir." if e.forcado else "Ignora o limite de horas."
	estudar_botao.disabled=pessoas.is_empty() or concluido
	estudar_botao.text="ATUALIZAR ESTUDO" if estado=="andamento" else "ESTUDAR"
	pausar_botao.disabled=e.pesquisador<0
	if not aviso.is_empty() and Time.get_ticks_msec()<aviso_ate:
		descricao.text=aviso;descricao.add_theme_color_override("font_color",Color("8b2026"))
		return
	descricao.add_theme_color_override("font_color",SEPIA)
	match estado:
		"concluido":descricao.text="Clique em um animatrônico estudado para ver a ficha e montá-lo."
		"continuo":descricao.text="Estudo contínuo até concluir ou escolher Parar estudo."
		"andamento":descricao.text="%d horas por dia, das 8h às 20h."%e.horas
		"pausado":descricao.text="Estudo parado. Escolha Estudar para retomar de onde parou."
		_:descricao.text="Escolha no cartaz quem estudar, depois o pesquisador e as horas."
func _process(_delta:float) -> void:
	if aberto():atualizar()

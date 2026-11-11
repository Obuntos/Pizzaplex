class_name TerminalUIPlex
extends CanvasLayer

const I=preload("res://scripts/interface/tema_ibm.gd")
var jogo: Node
var raiz:=Control.new()
var janela:=Control.new()
var tela:=Control.new()
var corpo:=Control.new()
var catalogo_area:=VBoxContainer.new()
var detalhe_area:=VBoxContainer.new()
var conclusao:=VBoxContainer.new()
var lateral:=VBoxContainer.new()
var rolagem:=ScrollContainer.new()
var rolagem_detalhe:=ScrollContainer.new()
var conteudo:=Control.new()
var titulo:=Label.new()
var subtitulo:=Label.new()
var saldo_label:Label
var aviso_label:Label
var entregas_label:=Label.new()
var total_label:Label
var depois_label:Label
var quantidade_label:Label
var comprar_botao:Button
var grade:GridContainer
var reparos_label:Label
var abas:Dictionary={}
var estoques:Dictionary={}
var terminal:=-1
var aba:="mercado"
var produto:="pizza"
var quantidade:=1
var funcionario:=-1
var recrutando:=false
var acompanhando:=false
var linhas_equipe:Dictionary={}
var oficio_candidatos:=""
var pagina_rolagem:=""
var rolagens:Dictionary={}
var revisao_pagina:=0
var contratando:=false
var notificacao:=""
var tempo_notificacao:=0.0
var terrenos_assinatura:=-1
var pagina_registros:=false
var seguranca_status:Label
var botao_escala:Button
var espera:=0.0
var ultimo_tamanho:=Vector2.ZERO
var altura_corpo:=464.0
var crt:ColorRect
var moldura:SuperficieModelosPlex
var respiro:SuperficieModelosPlex
var marca:Label
var led:ColorRect
var rodape:Control
var saldo_anterior:=-1.0
var cursor_terminal:=ColorRect.new()
var tempo_cursor:=0.0
var linha_rodape:ColorRect

func configurar(cena:Node) -> void:
	jogo=cena;layer=40;add_child(raiz);raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raiz.theme=I.criar()
	var reserva:=Control.new();reserva.hide();raiz.add_child(reserva)
	for n in [conclusao,lateral,conteudo,titulo,subtitulo,entregas_label]:reserva.add_child(n)
	var sombra:=ColorRect.new();sombra.color=Color(0,0,0,.7);sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raiz.add_child(sombra)
	raiz.add_child(janela)
	
	moldura=SuperficieModelosPlex.new("carcaca");janela.add_child(moldura);moldura.position=Vector2(50,50)
	janela.add_child(tela);tela.position=Vector2(84,80)
	var painel:=Panel.new();painel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);painel.add_theme_stylebox_override("panel",I.caixa(I.FUNDO,Color("1b1a14"),0));painel.mouse_filter=Control.MOUSE_FILTER_IGNORE;tela.add_child(painel)
	var borda:=Panel.new();borda.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);borda.offset_left=-8;borda.offset_right=8;borda.offset_top=-8;borda.offset_bottom=8;borda.add_theme_stylebox_override("panel",I.caixa(Color.TRANSPARENT,Color("8b836a"),0));borda.mouse_filter=Control.MOUSE_FILTER_IGNORE;tela.add_child(borda)
	var h:=HBoxContainer.new();tela.add_child(h);h.position=Vector2(24,22);h.size=Vector2(764,74);h.add_theme_constant_override("separation",16)
	var nome:=VBoxContainer.new();nome.size_flags_horizontal=Control.SIZE_EXPAND_FILL;nome.add_theme_constant_override("separation",6);h.add_child(nome)
	I.texto(nome,"PIZZAPLEX / ADMINISTRAÇÃO",38).add_theme_font_override("font",I.fonte(2))
	I.texto(nome,"LIVRO DE GESTÃO · IBM",24,I.SUAVE)
	var dinheiro:=PanelContainer.new();dinheiro.add_theme_stylebox_override("panel",I.caixa(Color.TRANSPARENT,I.VERDE,6));h.add_child(dinheiro)
	var dinheiro_c:=VBoxContainer.new();dinheiro_c.add_theme_constant_override("separation",0);dinheiro.add_child(dinheiro_c)
	I.texto(dinheiro_c,"DISPONÍVEL NO CAIXA",20,I.SUAVE).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	saldo_label=I.texto(dinheiro_c,"$ 0.00",36);saldo_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	linha(tela,Vector2(24,110),764)
	var nav:=HBoxContainer.new();nav.position=Vector2(24,126);nav.add_theme_constant_override("separation",12);tela.add_child(nav)
	for item in [["funcionarios","F1 FUNCIONÁRIOS"],["mercado","F2 MERCADO"],["terrenos","F3 TERRENOS"],["seguranca","F4 SEGURANÇA"]]:
		var id:String=item[0];var b:=I.botao(nav,item[1],func():mudar_aba(id));b.custom_minimum_size.y=42;b.add_theme_font_size_override("font_size",22);abas[id]=b
	linha(tela,Vector2(24,182),764)
	tela.add_child(corpo);corpo.position=Vector2(24,202)
	corpo.add_child(rolagem);rolagem.add_child(catalogo_area);catalogo_area.size_flags_horizontal=Control.SIZE_EXPAND_FILL;catalogo_area.add_theme_constant_override("separation",12)
	corpo.add_child(rolagem_detalhe);rolagem_detalhe.add_child(detalhe_area);detalhe_area.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detalhe_area.add_theme_constant_override("separation",14)
	for s in [rolagem,rolagem_detalhe]:s.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;s.mouse_force_pass_scroll_events=false
	rodape=Control.new();tela.add_child(rodape)
	aviso_label=I.texto(rodape,"> AGUARDANDO COMANDO",24,I.SUAVE);aviso_label.size=Vector2(600,44);aviso_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;aviso_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;aviso_label.add_theme_font_size_override("font_size",22)
	var fechar_b:=I.botao(rodape,"F10 FECHAR",fechar);fechar_b.position=Vector2(618,0);fechar_b.size=Vector2(146,44)
	cursor_terminal.color=I.VERDE;cursor_terminal.size=Vector2(12,20);cursor_terminal.mouse_filter=Control.MOUSE_FILTER_IGNORE;rodape.add_child(cursor_terminal)
	crt=ColorRect.new();crt.mouse_filter=Control.MOUSE_FILTER_IGNORE;crt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);crt.material=ShaderMaterial.new();crt.material.shader=preload("res://shaders/monitor_crt.gdshader");crt.z_index=10;tela.add_child(crt)
	marca=Label.new();marca.text="IBM";var fonte_marca:=FontVariation.new();fonte_marca.base_font=VintagePlex.fonte("botao");fonte_marca.spacing_glyph=3;marca.add_theme_font_override("font",fonte_marca);marca.add_theme_font_size_override("font_size",13);marca.add_theme_color_override("font_color",Color("6b6450"));janela.add_child(marca)
	respiro=SuperficieModelosPlex.new("ventilacao");respiro.size=Vector2(90,24);janela.add_child(respiro)
	led=ColorRect.new();led.color=I.VERDE;led.size=Vector2(10,10);janela.add_child(led)
	jogo.compras.alterada.connect(atualizar_valores);jogo.compras.aviso.connect(mensagem)
	if is_inside_tree():get_viewport().size_changed.connect(redimensionar)
	else:ready.connect(func():get_viewport().size_changed.connect(redimensionar),CONNECT_ONE_SHOT)
	linha_rodape=linha(tela,Vector2.ZERO,764)
	raiz.hide()

func aberto() -> bool:return raiz.visible
func abrir(id:int) -> void:
	if not jogo.compras.terminal_valido(id):jogo.painel.mensagem("Ligue o terminal e coloque-o sobre uma mesa ou balcão.");return
	terminal=id;jogo.planta.objetos[id].estado="uso";jogo.planta.alterada.emit();jogo.arrastando=false;jogo.traco_parede.encerrar();raiz.show();montar_pagina();atualizar_valores()
func fechar() -> void:
	if jogo!=null and jogo.planta.objetos.has(terminal):jogo.planta.objetos[terminal].estado="ligado";jogo.planta.alterada.emit()
	terminal=-1;raiz.hide()
func limpar(pai:Node) -> void:
	for n in pai.get_children():pai.remove_child(n);n.queue_free()
func linha(pai:Node,pos:Vector2,largura:float) -> ColorRect:
	var l:=ColorRect.new();l.color=I.SUAVE;l.position=pos;l.size=Vector2(largura,2);l.mouse_filter=Control.MOUSE_FILTER_IGNORE;pai.add_child(l);return l
func regra(pai:Node) -> void:
	var l:=ColorRect.new();l.color=I.SUAVE;l.custom_minimum_size.y=2;l.mouse_filter=Control.MOUSE_FILTER_IGNORE;pai.add_child(l)
func texto(pai:Node,valor:String,tamanho:int=24,cor:Color=I.VERDE) -> Label:
	var l:=I.texto(pai,valor,tamanho,cor);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;return l
func card(pai:Node,selecionada:bool=false,pontilhado:bool=false) -> VBoxContainer:
	var p:PanelContainer
	if pontilhado:p=PainelIBMPlex.new()
	else:p=PanelContainer.new()
	p.add_theme_stylebox_override("panel",I.caixa(Color(I.VERDE,.07) if selecionada else Color.TRANSPARENT,Color.TRANSPARENT if pontilhado else I.VERDE if selecionada else I.SUAVE,12));pai.add_child(p)
	var c:=VBoxContainer.new();c.add_theme_constant_override("separation",10);p.add_child(c);return c
func mudar_aba(valor:String) -> void:
	if valor not in ["funcionarios","mercado","terrenos","seguranca"]:return
	aba=valor;recrutando=false;montar_pagina();atualizar_valores()
func montar_pagina() -> void:
	if not pagina_rolagem.is_empty():rolagens[pagina_rolagem]=Vector2i(rolagem.scroll_vertical,rolagem_detalhe.scroll_vertical)
	var chave_pagina:=aba+(":candidatos:"+oficio_candidatos if recrutando else ":acompanhamento" if acompanhando else ":principal")
	var posicoes:Vector2i=rolagens.get(chave_pagina,Vector2i.ZERO)
	pagina_rolagem=chave_pagina;revisao_pagina+=1
	pagina_registros=false
	limpar(catalogo_area);limpar(detalhe_area);estoques.clear();total_label=null;comprar_botao=null
	for id in abas:
		var b:Button=abas[id]
		for e in ["normal","hover","pressed"]:b.add_theme_stylebox_override(e,I.caixa(I.VERDE if id==aba else Color(I.VERDE,.07) if e=="hover" else Color.TRANSPARENT,I.VERDE if id==aba else I.SUAVE,10))
		for n in ["font_color","font_hover_color","font_pressed_color"]:b.add_theme_color_override(n,I.FUNDO if id==aba else I.VERDE)
	var esquerda:=410.0 if aba=="funcionarios" else 430.0 if aba=="mercado" else 468.0
	altura_corpo=464.0
	rolagem.position=Vector2.ZERO;rolagem.size=Vector2(esquerda,altura_corpo)
	rolagem_detalhe.position=Vector2(esquerda+(24 if aba=="terrenos" else 28),0);rolagem_detalhe.size=Vector2(764-rolagem_detalhe.position.x,altura_corpo)
	if aba=="funcionarios":
		if acompanhando:montar_acompanhamento()
		elif recrutando:montar_candidatos()
		else:montar_equipe()
	elif aba=="terrenos":montar_terrenos()
	elif aba=="seguranca":montar_seguranca()
	else:
		texto(catalogo_area,"> MERCADO",28)
		for id in jogo.compras.catalogo:
			var p:Dictionary=jogo.compras.catalogo[id]
			if p.grupo=="mercado":montar_produto(id,p)
		montar_detalhe()
	redimensionar()
	restaurar_rolagem(posicoes,revisao_pagina)
func restaurar_rolagem(posicoes:Vector2i,revisao_atual:int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if revisao_atual!=revisao_pagina:return
	for par in [[rolagem,catalogo_area,posicoes.x],[rolagem_detalhe,detalhe_area,posicoes.y]]:
		var scroll:ScrollContainer=par[0];var lista:VBoxContainer=par[1];var barra:=scroll.get_v_scroll_bar()
		barra.max_value=maxf(scroll.size.y,lista.get_combined_minimum_size().y);barra.page=scroll.size.y
		scroll.scroll_vertical=int(par[2])
func redimensionar() -> void:
	if not is_inside_tree():return
	var sh:=202+altura_corpo+32+44+18
	tela.size=Vector2(812,sh);moldura.size=Vector2(880,sh+104)
	janela.size=Vector2(980,sh+204);corpo.size=Vector2(764,altura_corpo)
	rodape.position=Vector2(24,202+altura_corpo+32);rodape.size=Vector2(764,44)
	linha_rodape.position=Vector2(24,202+altura_corpo+18)
	marca.position=Vector2(90,80+sh+26);respiro.position=Vector2(764,80+sh+22);led.position=Vector2(878,80+sh+28)
	crt.material.set_shader_parameter("dimensao",tela.size)
	ultimo_tamanho=get_viewport().get_visible_rect().size
	var escala:=minf(1.0,minf((ultimo_tamanho.x-24)/janela.size.x,(ultimo_tamanho.y-24)/janela.size.y))
	janela.scale=Vector2.ONE*escala;janela.position=((ultimo_tamanho-janela.size*escala)*.5).round()
func montar_produto(id:String,p:Dictionary) -> void:
	var caixa:=card(catalogo_area,id==produto);var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);caixa.add_child(row)
	texto(row,"▶" if id==produto else " ",24).custom_minimum_size.x=18
	var ic_frame:=PanelContainer.new();ic_frame.add_theme_stylebox_override("panel",I.caixa(Color.TRANSPARENT,I.SUAVE,5));ic_frame.custom_minimum_size=Vector2(44,44);ic_frame.size_flags_vertical=Control.SIZE_SHRINK_CENTER;row.add_child(ic_frame)
	var ic:=IconeHudPlex.new("pratos" if p.has("material_prato") else "pizza" if id=="pizza" else "compras");ic.escala_pixel=1.25;ic.custom_minimum_size=Vector2(30,30);ic.size_flags_vertical=Control.SIZE_SHRINK_CENTER;ic_frame.add_child(ic)
	var dados:=VBoxContainer.new();dados.size_flags_horizontal=Control.SIZE_EXPAND_FILL;dados.add_theme_constant_override("separation",2);row.add_child(dados)
	var nome_linha:=HBoxContainer.new();dados.add_child(nome_linha)
	var nome_valor:String="PRATOS DE PAPEL · 10 UN" if id=="pratos_papel" else "PRATO" if id=="pratos_ceramica" else str(p.nome).to_upper()
	var nome:=texto(nome_linha,nome_valor,28);nome.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var preco_label:=I.texto(nome_linha,"$ "+str(int(p.preco)),28);preco_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	estoques[id]=texto(dados,("UTENSÍLIOS" if p.has("material_prato") else "INGREDIENTES")+" · %d UN/CX · %d EM ESTOQUE"%[p.unidades,jogo.compras.estoque(id)],22,I.SUAVE)
	var b:=Button.new();b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);b.flat=true;b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for e in ["normal","hover","pressed","focus"]:b.add_theme_stylebox_override(e,StyleBoxEmpty.new())
	caixa.get_parent().add_child(b);b.pressed.connect(func():produto=id;montar_pagina();atualizar_valores())
func montar_detalhe() -> void:
	if not jogo.compras.catalogo.has(produto):produto="pizza"
	var p:Dictionary=jogo.compras.catalogo[produto]
	texto(detalhe_area,"> SEU PEDIDO",28)
	var c:=card(detalhe_area,false,true);texto(c,str(p.nome).to_upper(),32);texto(c,str(p.descricao).to_upper(),24,I.SUAVE)
	texto(detalhe_area,"QUANTIDADE DE CAIXAS:",24,I.SUAVE)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",8);detalhe_area.add_child(row)
	I.botao(row,"−",func():ajustar_quantidade(-1)).custom_minimum_size.x=48
	var n:=PanelContainer.new();n.add_theme_stylebox_override("panel",I.caixa(Color.TRANSPARENT,I.SUAVE,0));n.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(n)
	quantidade_label=I.texto(n,str(quantidade),30);quantidade_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	I.botao(row,"+",func():ajustar_quantidade(1)).custom_minimum_size.x=48
	regra(detalhe_area)
	var totais:=HBoxContainer.new();detalhe_area.add_child(totais);texto(totais,"TOTAL").size_flags_horizontal=Control.SIZE_EXPAND_FILL;total_label=I.texto(totais,"$ 0",36);total_label.custom_minimum_size.x=72;total_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	depois_label=texto(detalhe_area,"",24,I.SUAVE)
	comprar_botao=I.botao(detalhe_area,"CONFIRMAR COMPRA →",confirmar,true);comprar_botao.custom_minimum_size.y=50
func ajustar_quantidade(delta:int) -> void:quantidade=clampi(quantidade+delta,1,8);atualizar_valores()
func confirmar() -> void:
	if jogo.compras.comprar(terminal,produto,quantidade):
		mensagem("PEDIDO #"+str(jogo.compras.proximo_id-1).pad_zeros(3)+" CONFIRMADO")
		if is_instance_valid(jogo.sistemas.tutorial) and jogo.sistemas.tutorial.etapa=="pizza_confirmar":fechar();return
	atualizar_valores()
func seletor(pai:Node,atual:String,acao:Callable,adm:bool=false) -> MenuButton:
	var s:=MenuButton.new();s.custom_minimum_size.y=44;s.size_flags_horizontal=Control.SIZE_EXPAND_FILL;s.text=str(EquipePlex.NOMES.get(atual,"ESCOLHA A FUNÇÃO")).to_upper()+" ▾";pai.add_child(s)
	var popup:=s.get_popup()
	for f in EquipePlex.NOMES:
		if f=="administrador" or f=="seguranca" or f=="geral" and not adm:continue
		popup.add_item(str(EquipePlex.NOMES[f]).to_upper());popup.set_item_metadata(popup.item_count-1,f)
	popup.id_pressed.connect(func(i):
		var f:=str(popup.get_item_metadata(popup.get_item_index(i)));s.text=str(EquipePlex.NOMES[f]).to_upper()+" ▾";acao.call(f))
	return s

func montar_equipe() -> void:
	I.botao(catalogo_area,"ACOMPANHAMENTO",func():acompanhando=true;montar_pagina())
	texto(catalogo_area,"> FUNCIONÁRIOS",28)
	var c:=card(catalogo_area,false,true);texto(c,"CONTRATAR NOVA FUNÇÃO:",24,I.SUAVE)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",10);c.add_child(row)
	seletor(row,oficio_candidatos,func(f):oficio_candidatos=f;montar_pagina.call_deferred())
	var contratar_b:=I.botao(row,"CONTRATAR",func():abrir_candidatos(oficio_candidatos),true);contratar_b.disabled=oficio_candidatos.is_empty()
	texto(c,"Escolha a função para ver o salário." if oficio_candidatos.is_empty() else "POSSUI %02d · SALÁRIO: US$ %d/SEMANA"%[jogo.personagens.filter(func(contratado_item):return contratado_item.funcao==oficio_candidatos and not contratado_item.visita.get("demitido",false)).size(),FolhaPagamentoPlex.salario(oficio_candidatos)],24,I.SUAVE)
	var lista:Array=jogo.personagens.filter(func(membro):return membro.cargo=="funcionario" and not membro.robo and membro.funcao!="seguranca" and not membro.visita.get("demitido",false))
	if not lista.any(func(membro):return membro.identificador==funcionario):funcionario=lista[0].identificador if not lista.is_empty() else -1
	for membro in lista:
		var id:int=membro.identificador;var v:=card(catalogo_area,id==funcionario);var r:=HBoxContainer.new();r.add_theme_constant_override("separation",14);v.add_child(r)
		texto(r,"▶" if id==funcionario else " ").custom_minimum_size.x=22
		var d:=VBoxContainer.new();d.size_flags_horizontal=Control.SIZE_EXPAND_FILL;r.add_child(d)
		texto(d,IdentidadesPlex.completo(membro).to_upper(),28);texto(d,str(EquipePlex.NOMES.get(membro.funcao,"Geral")).to_upper()+" · "+("AUTOMÁTICO" if membro.automatico else "PAUSADO"),24,I.SUAVE)
		var gerenciar:=I.botao(r,"GERENCIAR",func():funcionario=id;montar_pagina.call_deferred(),id==funcionario);gerenciar.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	if lista.is_empty():texto(detalhe_area,"> NENHUM FUNCIONÁRIO",28);return
	var a:PersonagemPlex=lista.filter(func(p):return p.identificador==funcionario)[0]
	texto(detalhe_area,"> FICHA: "+IdentidadesPlex.completo(a).to_upper(),28)
	var energia:=ProgressBar.new();energia.name="EnergiaFuncionario";energia.custom_minimum_size.y=16;energia.show_percentage=false;energia.value=a.energia;energia.add_theme_stylebox_override("background",I.caixa(Color.TRANSPARENT,I.SUAVE,2));energia.add_theme_stylebox_override("fill",I.caixa(I.VERDE,I.VERDE,0));detalhe_area.add_child(energia)
	texto(detalhe_area,"ENERGIA · %d / 100"%roundi(a.energia),22,I.SUAVE).name="TextoEnergiaFuncionario"
	if not AdministradorPlex.eh(a):
		I.botao(detalhe_area,"AUTOMÁTICO: "+("SIM" if a.automatico else "NÃO"),func():jogo.controle.interromper(a);a.automatico=not a.automatico;montar_pagina.call_deferred())
		I.botao(detalhe_area,"COMEÇAR TURNO",func():jogo.turnos.comecar_turno(a))
		I.botao(detalhe_area,"HORA DO ALMOÇO",func():jogo.turnos.descansar(a))
		I.botao(detalhe_area,"ACABAR TURNO",func():jogo.turnos.acabar_turno(a))
		I.botao(detalhe_area,"DEMITIR",func():AdministradorPlex.demitir(jogo,a);funcionario=-1;montar_pagina.call_deferred())
	var skills:=GridContainer.new();skills.columns=2;skills.add_theme_constant_override("h_separation",8);skills.add_theme_constant_override("v_separation",8);detalhe_area.add_child(skills)
	for f in [a.funcao]:
		var r:=HBoxContainer.new();r.add_theme_constant_override("separation",4);skills.add_child(r)
		I.texto(r,str(EquipePlex.NOMES[f]).to_upper(),20).custom_minimum_size.x=72
		pips(r,HabilidadesEquipePlex.estrelas(a,f),10)
	regra(detalhe_area)
	if AdministradorPlex.eh(a):texto(detalhe_area,"ADMINISTRADOR · APOIO AUTOMÁTICO À EQUIPE",24,I.SUAVE);return
	texto(detalhe_area,"FUNÇÃO PRINCIPAL:",24,I.SUAVE)
	seletor(detalhe_area,a.funcao,func(f):EquipePlex.definir(a,f,a.funcoes_secundarias);montar_pagina.call_deferred(),true)
	texto(detalhe_area,"APOIO AUTORIZADO:",24,I.SUAVE)
	var apoios:=GridContainer.new();apoios.columns=2;apoios.add_theme_constant_override("h_separation",8);apoios.add_theme_constant_override("v_separation",8);detalhe_area.add_child(apoios)
	for f in EquipePlex.FUNCOES:
		var chave:String=f;var check:=Button.new();check.toggle_mode=true;check.text=str(EquipePlex.NOMES[f]).to_upper();check.custom_minimum_size.y=40;check.add_theme_font_size_override("font_size",20)
		check.button_pressed=a.funcao=="geral" or a.funcao==f or a.funcoes_secundarias.has(f);check.disabled=a.funcao=="geral" or a.funcao==f;apoios.add_child(check)
		check.toggled.connect(func(v):
			if v and not a.funcoes_secundarias.has(chave):a.funcoes_secundarias.append(chave)
			elif not v:a.funcoes_secundarias.erase(chave))
func pips(pai:Node,n:int,tamanho:int=14) -> void:
	var r:=HBoxContainer.new();r.add_theme_constant_override("separation",4 if tamanho>=14 else 2);pai.add_child(r)
	for i in 5:
		var p:=Panel.new();p.custom_minimum_size=Vector2(tamanho,tamanho);p.size_flags_vertical=Control.SIZE_SHRINK_CENTER;p.add_theme_stylebox_override("panel",I.caixa(I.VERDE if i<n else Color.TRANSPARENT,I.VERDE if i<n else I.SUAVE,0));r.add_child(p)
func abrir_candidatos(funcao:String) -> void:
	if funcao.is_empty():mensagem("Escolha a função antes de contratar.");return
	if funcao=="seguranca":jogo.sistemas.abrir_escala();return
	oficio_candidatos=funcao;recrutando=true;montar_pagina.call_deferred()
func montar_candidatos() -> void:
	texto(catalogo_area,"> CONTRATAR · "+str(EquipePlex.NOMES[oficio_candidatos]).to_upper(),28)
	I.botao(catalogo_area,"‹ FUNCIONÁRIOS",func():recrutando=false;montar_pagina.call_deferred())
	texto(catalogo_area,"POSSUI %02d"%jogo.personagens.filter(func(contratado_item):return contratado_item.funcao==oficio_candidatos and not contratado_item.visita.get("demitido",false)).size(),24,I.SUAVE)
	for candidato in RecrutamentoPlex.listar(jogo,oficio_candidatos):
		var c:=card(catalogo_area);var id:String=candidato.id
		texto(c,(str(candidato.nome)+" "+str(candidato.sobrenome)).to_upper(),28)
		for f in [oficio_candidatos]:
			var r:=HBoxContainer.new();c.add_child(r);texto(r,str(EquipePlex.NOMES[f]).to_upper(),22).size_flags_horizontal=Control.SIZE_EXPAND_FILL;pips(r,int(candidato.habilidades.get(f,1)),10)
		texto(c,"CONTRATAÇÃO: $ %d · SALÁRIO: $ %d/SEMANA"%[candidato.custo,candidato.salario],22,I.SUAVE)
		var b:=I.botao(c,"CONTRATAR",func():contratar_candidato.call_deferred(id),true);b.set_meta("candidato_id",id);b.disabled=contratando or jogo.servicos.saldo<float(candidato.custo)
	texto(detalhe_area,"> CANDIDATOS",28);texto(detalhe_area,"Compare as habilidades. Funcionários mais experientes cobram mais e trabalham mais rápido.",24,I.SUAVE)
func contratar_candidato(id:String) -> void:
	if contratando:return
	var candidato:=RecrutamentoPlex.buscar(jogo,oficio_candidatos,id)
	if candidato.is_empty():return
	contratando=true;var a:=AdministradorPlex.contratar(jogo,oficio_candidatos,candidato)
	if is_instance_valid(a):
		funcionario=a.identificador;mensagem("CONTRATADO · "+IdentidadesPlex.completo(a))
		for botao_contrato in catalogo_area.find_children("*","Button",true,false):
			if botao_contrato.has_meta("candidato_id"):
				botao_contrato.disabled=true
				if str(botao_contrato.get_meta("candidato_id"))==id:botao_contrato.text="CONTRATADO"
		await get_tree().create_timer(.85).timeout
		recrutando=false
	else:mensagem("SALDO OU ESPAÇO INSUFICIENTE")
	contratando=false
	montar_pagina.call_deferred()
func montar_terrenos() -> void:
	if CompraTerrenosPlex.LOTES.keys().all(func(id):return jogo.planta.terrenos_adquiridos.get(id,false)):
		montar_satisfacao();return
	texto(catalogo_area,"> PLANTA DO QUARTEIRÃO",28)
	var mapa:=SuperficieModelosPlex.new("planta");mapa.custom_minimum_size=Vector2(468,285);mapa.adquiridos=jogo.planta.terrenos_adquiridos.duplicate();catalogo_area.add_child(mapa)
	for i in 3:
		var l:=I.texto(mapa,["ESQUERDA","CENTRO","DIREITA"][i],20,I.SUAVE);l.position=Vector2(34+i*140,62);l.size=Vector2(120,24);l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var p:=PanelContainer.new();p.position=Vector2(34+i*140,150);p.size=Vector2(120,32);p.add_theme_stylebox_override("panel",I.caixa(I.FUNDO,I.FUNDO,0));mapa.add_child(p)
		I.texto(p,["PADARIA","PIZZAPLEX","FARMÁCIA"][i],26).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	for i in 2:
		var q:=I.texto(mapa,["FLORICULTURA","POSTO"][i],14,I.SUAVE);q.position=Vector2(174+i*140,60);q.size=Vector2(120,24);q.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	I.texto(mapa,"N ↑",20,I.SUAVE).position=Vector2(420,38)
	I.botao(catalogo_area,"AMBIENTE / REGISTROS",mostrar_sistemas)
	texto(catalogo_area,"PIZZAPLEX · SEU TERRENO",22,I.VERDE)
	texto(catalogo_area,"LOTES VIZINHOS: PADARIA, FARMÁCIA, FLORICULTURA E POSTO",20,I.SUAVE)
	var satisfacao:=ReputacaoClientesPlex.nota(jogo.servicos)
	texto(catalogo_area,"SATISFAÇÃO · %.0f / 100"%satisfacao,24,I.SUAVE)
	var satisfacao_barra:=ProgressBar.new();satisfacao_barra.name="Satisfacao";satisfacao_barra.custom_minimum_size.y=16;satisfacao_barra.show_percentage=false;satisfacao_barra.value=satisfacao
	satisfacao_barra.add_theme_stylebox_override("background",I.caixa(Color.TRANSPARENT,I.SUAVE,2));satisfacao_barra.add_theme_stylebox_override("fill",I.caixa(I.VERDE,I.VERDE,0));catalogo_area.add_child(satisfacao_barra)
	texto(detalhe_area,"> LOTES À VENDA",28)
	for id in CompraTerrenosPlex.LOTES:
		if jogo.planta.terrenos_adquiridos.get(id,false):continue
		var chave:String=id;var l:Dictionary=CompraTerrenosPlex.LOTES[id];var c:=card(detalhe_area)
		texto(c,str(l.nome).to_upper(),30);texto(c,str(l.lado).to_upper()+" · %d TILES"%(int(l.area[2])*int(l.area[3])),24,I.SUAVE)
		var preco:=CompraTerrenosPlex.preco(jogo,id);var saldo:float=jogo.compras.saldo();var own:bool=jogo.planta.terrenos_adquiridos.get(id,false)
		texto(c,"CAIXA / PREÇO   $ %.0f / $ %d"%[saldo,preco],22,I.SUAVE)
		var bar:=ProgressBar.new();bar.custom_minimum_size.y=16;bar.show_percentage=false;bar.value=clampf(saldo/float(maxi(1,preco))*100,0,100);bar.add_theme_stylebox_override("background",I.caixa(Color.TRANSPARENT,I.SUAVE,2));bar.add_theme_stylebox_override("fill",I.caixa(I.VERDE,I.VERDE,0));c.add_child(bar)
		var erro:=CompraTerrenosPlex.motivo(jogo,id)
		var b:=I.botao(c,"ADQUIRIDO" if own else "COMPRAR · $ "+str(preco),func():CompraTerrenosPlex.comprar(jogo,chave);montar_pagina.call_deferred());b.disabled=not erro.is_empty()
		if not own and not erro.is_empty():texto(c,"! SALDO INSUFICIENTE — FALTAM $ %.0f"%maxf(0,preco-saldo) if saldo<preco else "! "+erro.to_upper(),24)
	terrenos_assinatura=hash([jogo.servicos.saldo,jogo.planta.terrenos_adquiridos,jogo.servicos.reputacao,roundi(ReputacaoClientesPlex.ambiente(jogo.servicos))])
func mensagem(valor:String) -> void:notificacao=valor.to_upper();tempo_notificacao=6.0;if is_instance_valid(aviso_label):aviso_label.text="> "+notificacao
func atualizar_valores() -> void:
	if aba=="funcionarios" and aberto() and not recrutando:
		var bar:=detalhe_area.get_node_or_null("EnergiaFuncionario") as ProgressBar
		for membro in jogo.personagens:
			if membro.identificador==funcionario and bar!=null:
				bar.value=membro.energia
				var rotulo:=detalhe_area.get_node_or_null("TextoEnergiaFuncionario") as Label
				if rotulo!=null:rotulo.text="ENERGIA · %d / 100"%roundi(membro.energia)
				break
	if jogo==null or not aberto():return
	saldo_label.text="$ %.2f"%jogo.compras.saldo()
	if aba=="seguranca" and is_instance_valid(seguranca_status):atualizar_seguranca()
	if aba=="funcionarios" and acompanhando:atualizar_acompanhamento()
	if aba=="mercado" and is_instance_valid(total_label):
		var preco:=int(jogo.compras.catalogo[produto].preco)*quantidade;total_label.text="$ "+str(preco);quantidade_label.text=str(quantidade);depois_label.text="SALDO APÓS A COMPRA   $ %.2f"%(jogo.compras.saldo()-preco)
		var erro:String=jogo.compras.motivo(terminal,produto,quantidade);comprar_botao.disabled=not erro.is_empty()
		aviso_label.text="> "+(notificacao if tempo_notificacao>0 else erro.to_upper() if not erro.is_empty() else "AGUARDANDO COMANDO")
	elif tempo_notificacao<=0:aviso_label.text="> AGUARDANDO COMANDO"
	if aba=="terrenos" and not pagina_registros and terrenos_assinatura!=hash([jogo.servicos.saldo,jogo.planta.terrenos_adquiridos,jogo.servicos.reputacao,roundi(ReputacaoClientesPlex.ambiente(jogo.servicos))]):montar_pagina.call_deferred()
	if aba=="mercado":
		for id in estoques:
			var p:Dictionary=jogo.compras.catalogo[id];estoques[id].text=("UTENSÍLIOS" if p.has("material_prato") else "INGREDIENTES")+" · %d UN/CX · %d EM ESTOQUE"%[p.unidades,jogo.compras.estoque(id)]
	if saldo_anterior!=jogo.compras.saldo():
		saldo_anterior=jogo.compras.saldo()
		if aba=="funcionarios" and recrutando:montar_pagina.call_deferred()
func _process(delta:float) -> void:
	if not aberto():return
	tempo_cursor+=delta
	cursor_terminal.visible=fmod(tempo_cursor,1.05)<.6
	cursor_terminal.position=Vector2(minf(594,aviso_label.get_theme_font("font").get_string_size(aviso_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x+6),12)
	if not jogo.compras.terminal_valido(terminal):fechar();return
	tempo_notificacao=maxf(0,tempo_notificacao-delta);espera+=delta
	if espera>=.5:espera=0;atualizar_valores()
func _input(e:InputEvent) -> void:
	if not aberto():return
	if e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		if jogo.sistemas.escala_aberta():return
		for scroll in [rolagem,rolagem_detalhe]:
			if scroll.get_global_rect().has_point(e.position):
				scroll.scroll_vertical+=(-70 if e.button_index==MOUSE_BUTTON_WHEEL_UP else 70);get_viewport().set_input_as_handled();return
	if not e is InputEventKey or not e.pressed or e.echo:return
	match e.keycode:
		KEY_F1:mudar_aba("funcionarios")
		KEY_F2:mudar_aba("mercado")
		KEY_F3:mudar_aba("terrenos")
		KEY_F4:mudar_aba("seguranca")
		KEY_ESCAPE,KEY_F10:fechar()
		_:return
	get_viewport().set_input_as_handled()

func mostrar_sistemas() -> void:
	pagina_registros=true
	limpar(catalogo_area);limpar(detalhe_area)
	texto(catalogo_area,"> AMBIENTE E VENTILAÇÃO",28)
	for sala in jogo.ambientes.ambientes:
		if sala.get("fechada",false):texto(catalogo_area,str(sala.tipo).to_upper()+" · AR %d / 100"%int(jogo.sistemas.ambiencia.ar.get(sala.id,60)),24)
	var caso:InvestigacaoProgressivaPlex=jogo.sistemas.investigacao
	texto(detalhe_area,"> REGISTROS",28)
	texto(detalhe_area,"DESAPARECIMENTOS: "+str(caso.desaparecidos.size()),24)
	texto(detalhe_area,"APURAÇÃO AMPLIADA: "+("ATIVA" if caso.ativo() else "AGUARDA O SEGUNDO CASO"),22)
	texto(detalhe_area,"HISTÓRICO: %d · GRAVAÇÕES: %d"%[caso.historico.size(),caso.gravacoes.size()],22)
	for p in caso.pistas.values():texto(detalhe_area,"> "+str(p.descricao),22)
	I.botao(detalhe_area,"AJUSTAR PONTO",func():caso.alterar_ponto();mostrar_sistemas())
	I.botao(detalhe_area,"REGISTRO MANUAL",func():caso.falso_rastro();mostrar_sistemas())
	I.botao(detalhe_area,"VOLTAR",montar_pagina)

func montar_seguranca() -> void:
	texto(catalogo_area,"> PLANTA DE SEGURANÇA",26)
	var mapa:=MapaSegurancaPlex.new();mapa.jogo=jogo;catalogo_area.add_child(mapa)
	texto(catalogo_area,"■ COELHO · ● CLIENTES · ◆ GUARDAS\nPISCA QUANDO A CÂMERA VÊ",19,I.SUAVE)
	botao_escala=I.botao(catalogo_area,"FORMULÁRIO · TURNO DA NOITE",func():jogo.sistemas.abrir_escala())
	texto(detalhe_area,"> POSTO CENTRAL",26)
	seguranca_status=texto(detalhe_area,"",21,I.SUAVE)
	atualizar_seguranca()
func atualizar_seguranca() -> void:
	if is_instance_valid(botao_escala):
		botao_escala.disabled=jogo.sistemas.guarda.escala.vigente(jogo.calendario.dias,jogo.calendario.minutos)
		botao_escala.text="CONTRATO NOTURNO EM ANDAMENTO" if botao_escala.disabled else "FORMULÁRIO · TURNO DA NOITE"
	var ativos:Array=jogo.personagens.filter(func(a):return jogo.sistemas.guarda.monitorando(a))
	var linhas:=PackedStringArray(["NO MONITOR: "+str(ativos.size())])
	for a in jogo.personagens:
		if a.cargo=="funcionario" and a.funcao=="seguranca":linhas.append(IdentidadesPlex.completo(a).to_upper()+" · "+("AGUARDA O HORÁRIO" if a.visita.get("fora_turno",false) else a.trabalho.replace("_"," ").to_upper()))
	linhas.append("\n"+jogo.sistemas.guarda.alerta.to_upper());seguranca_status.text="\n".join(linhas)

func montar_acompanhamento() -> void:
	linhas_equipe.clear();texto(catalogo_area,"> ACOMPANHAMENTO DA EQUIPE",26)
	I.botao(catalogo_area,"‹ FUNCIONÁRIOS",func():acompanhando=false;montar_pagina())
	for a in jogo.personagens:
		if a.cargo!="funcionario" or a.robo:continue
		var c:=card(catalogo_area);texto(c,IdentidadesPlex.completo(a).to_upper(),24);linhas_equipe[a.identificador]=texto(c,"",21,I.SUAVE)
	texto(detalhe_area,"> SITUAÇÃO DO RESTAURANTE",26)
	texto(detalhe_area,"Os estados abaixo acompanham trabalho, deslocamento, descanso e obstáculos. Atualização automática.",21,I.SUAVE)
	texto(detalhe_area,"Desempenho",24)
	var d:=texto(detalhe_area,"",20,I.SUAVE);d.name="DiagnosticoDesempenho"
	texto(detalhe_area,"> PEDIDOS EM ESPERA",24)
	for p in jogo.servicos.pedidos:
		if p.get("estado","") in ["cancelado","consumido","entregue"]:continue
		var mesa:=int(p.get("mesa",-1));var linha_pedido:=HBoxContainer.new();detalhe_area.add_child(linha_pedido)
		I.botao(linha_pedido,"PRIORIZAR #"+str(p.id),func():PrioridadesServicoPlex.solicitar(jogo,mesa,"atender");mensagem("Atendimento priorizado."))
		I.botao(linha_pedido,"VER",func():
			if jogo.planta.objetos.has(mesa):
				jogo.camera.position=GradePlex.projetar(Vector2(jogo.planta.objetos[mesa].celula));jogo.camera.force_update_scroll();fechar())
	atualizar_acompanhamento()
func atualizar_acompanhamento() -> void:
	for a in jogo.personagens:
		if linhas_equipe.has(a.identificador) and is_instance_valid(linhas_equipe[a.identificador]):linhas_equipe[a.identificador].text=AcompanhamentoEquipePlex.estado(jogo,a)+"\nEnergia: %d%%"%roundi(a.energia)
	var d:=detalhe_area.get_node_or_null("DiagnosticoDesempenho")
	if d!=null:d.text=jogo.desempenho.resumo() if "desempenho" in jogo else "Diagnóstico disponível durante a partida."

func montar_satisfacao() -> void:
	texto(catalogo_area,"> SATISFAÇÃO DOS CLIENTES",28)
	texto(catalogo_area,"NOTA DO RESTAURANTE · %d / 100"%roundi(ReputacaoClientesPlex.nota(jogo.servicos)),26)
	texto(detalhe_area,"> COMENTÁRIOS E RECLAMAÇÕES",26)
	var total:=0
	for a in jogo.personagens:
		if a.cargo not in ["cliente","morador","crianca","adolescente"] or not a.visible:continue
		var c:=card(detalhe_area);texto(c,IdentidadesPlex.completo(a).to_upper(),24)
		var nota:=float(a.visita.get("satisfacao",60));var relato:="Satisfeito com a visita." if nota>=70 else str(a.visita.get("motivo_insatisfacao","Aguardando o pedido."))
		if a.visita.get("solitario",false):relato="Sentiu-se sozinho durante a visita."
		elif a.trabalho in ["aguardar","esperar_pedido"]:relato="Aguardando atendimento."
		texto(c,relato+" · %d / 100"%roundi(nota),21,I.SUAVE);total+=1
	if total==0:texto(detalhe_area,"Nenhum comentário de visitante presente.",22,I.SUAVE)
	terrenos_assinatura=hash([jogo.servicos.saldo,jogo.planta.terrenos_adquiridos,jogo.servicos.reputacao,roundi(ReputacaoClientesPlex.ambiente(jogo.servicos))])

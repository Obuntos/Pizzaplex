class_name QuadroInvestigacaoPlex
extends CanvasLayer

const T=preload("res://scripts/interface/tema_hud.gd")
const ETAPAS=[["RELATO","Uma pessoa sumiu. No segundo desaparecimento a investigação é aberta."],["ABERTA","O investigador visita, inspeciona o local e faz três perguntas. Cada pista aumenta a suspeita."],["SUSPEITA ALTA","Com 75 de suspeita e a inspeção concluída, a polícia pede um mandado."],["MANDADO","A polícia está vindo prender o administrador."]]
const ATIVIDADES={"visita_autoridade":"indo ao próximo ponto","investigar":"inspecionando","procurar_registros":"vasculhando os registros","abordado":"sendo abordado por um segurança","sair_autoridade":"deixando o restaurante","servico":"conversando com o administrador"}
var jogo:Node
var raiz:=Control.new()
var emblema:=Button.new()
var emblema_titulo:Label
var emblema_barra:=ProgressBar.new()
var janela:=PanelContainer.new()
var etapas:=HBoxContainer.new()
var proximo:Label
var barra:=ProgressBar.new()
var suspeita_texto:Label
var agora_texto:Label
var desaparecidos_texto:Label
var pistas_lista:=VBoxContainer.new()
var espera:=0.0
var total_pistas:=-1
var assinatura:=-1

func configurar(cena:Node) -> void:
	jogo=cena;layer=118;add_child(raiz);raiz.theme=T.criar();raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raiz.mouse_filter=Control.MOUSE_FILTER_IGNORE
	raiz.add_child(emblema);emblema.position=Vector2(16,80);emblema.custom_minimum_size=Vector2(216,46);emblema.pressed.connect(alternar)
	for estado in ["normal","hover","pressed","focus"]:emblema.add_theme_stylebox_override(estado,T.caixa(Color("3a2420") if estado!="hover" else Color("4a2e27"),T.AMBAR,6))
	var linha:=HBoxContainer.new();linha.mouse_filter=Control.MOUSE_FILTER_IGNORE;emblema.add_child(linha);linha.position=Vector2(6,4)
	var icone:=IconeHudPlex.new("fichario");icone.escala_pixel=1.5;icone.custom_minimum_size=Vector2(36,36);linha.add_child(icone)
	var coluna:=VBoxContainer.new();coluna.mouse_filter=Control.MOUSE_FILTER_IGNORE;coluna.add_theme_constant_override("separation",2);linha.add_child(coluna)
	emblema_titulo=T.texto(coluna,"INVESTIGAÇÃO",13,T.AMBAR)
	coluna.add_child(emblema_barra);preparar_barra(emblema_barra,Vector2(160,8))
	emblema.hide()
	raiz.add_child(janela);janela.add_theme_stylebox_override("panel",T.caixa(T.FUNDO,T.AMBAR,18))
	var col:=VBoxContainer.new();col.custom_minimum_size.x=560;col.add_theme_constant_override("separation",10);janela.add_child(col)
	var topo:=T.cabecalho(col,"QUADRO DA INVESTIGAÇÃO","fichario");T.botao(topo,"×",fechar)
	col.add_child(etapas);etapas.add_theme_constant_override("separation",6)
	proximo=T.texto(col,"",14,T.PAPEL);proximo.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;proximo.custom_minimum_size.x=550
	var linha_barra:=HBoxContainer.new();col.add_child(linha_barra)
	suspeita_texto=T.texto(linha_barra,"",14,T.AMBAR);suspeita_texto.custom_minimum_size.x=170
	linha_barra.add_child(barra);preparar_barra(barra,Vector2(370,14));barra.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	T.texto(col,"AGORA",13,T.SUAVE)
	agora_texto=T.texto(col,"",14,T.PAPEL);agora_texto.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;agora_texto.custom_minimum_size.x=550
	desaparecidos_texto=T.texto(col,"",13,T.SUAVE);desaparecidos_texto.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;desaparecidos_texto.custom_minimum_size.x=550
	T.texto(col,"PISTAS",13,T.SUAVE)
	var rolagem:=ScrollContainer.new();rolagem.custom_minimum_size=Vector2(550,170);rolagem.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;col.add_child(rolagem)
	rolagem.add_child(pistas_lista);pistas_lista.size_flags_horizontal=Control.SIZE_EXPAND_FILL;pistas_lista.add_theme_constant_override("separation",4)
	jogo.janelas_moveis.registrar(janela,fechar,56);janela.hide()
func preparar_barra(b:ProgressBar,tamanho:Vector2) -> void:
	b.min_value=0;b.max_value=100;b.show_percentage=false;b.custom_minimum_size=tamanho;b.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var fundo:=StyleBoxFlat.new();fundo.bg_color=Color("1e1512");fundo.border_color=T.LINHA;fundo.set_border_width_all(1)
	var cheio:=StyleBoxFlat.new();cheio.bg_color=Color("c4553f")
	b.add_theme_stylebox_override("background",fundo);b.add_theme_stylebox_override("fill",cheio)

func aberto() -> bool:return janela.visible
func alternar() -> void:
	if aberto():fechar()
	else:abrir()
func abrir() -> void:
	janela.show();assinatura=-1;atualizar_quadro();janela.reset_size();JanelasMoveisPlex.centralizar(janela,get_viewport().get_visible_rect().size)
func fechar() -> void:janela.hide()
func horario(minutos:float) -> String:
	var m:=int(minutos);return "Dia %d · %02d:%02d"%[floori(m/1440.0)+1,floori(posmod(m,1440)/60.0),posmod(m,60)]

func evento_atual() -> Dictionary:
	for e in jogo.seguranca.eventos:
		if e.fase!="concluido":return e
	return {}
func texto_agora(inv:InvestigacaoProgressivaPlex) -> String:
	var e:=evento_atual()
	if e.is_empty():return "Nenhum agente no restaurante." if inv.ativo() else "A polícia ainda não abriu investigação."
	var quem:="O policial" if e.tipo=="policial" else "O investigador"
	if e.fase=="aguardando":return quem+" deve chegar em breve." if e.tipo=="policial" else "O investigador virá durante o dia (08:00 às 18:00)."
	if e.fase=="perguntas":return quem+" está fazendo as perguntas ao administrador ("+str(int(e.pergunta)+1)+"/3)."
	var a:PersonagemPlex=jogo.clientes.ator(int(e.get("agente",-1)))
	if not is_instance_valid(a):return quem+" está a caminho."
	var texto:=quem+" está "+str(ATIVIDADES.get(str(a.trabalho),"no restaurante"))
	if e.has("roteiro") and not e.get("apurado",false) and int(e.get("parada",0))<e.roteiro.size():
		var o:Dictionary=jogo.planta.objetos.get(int(e.roteiro[int(e.parada)]),{})
		if not o.is_empty():texto+=" · próxima parada: "+str(MobiliaPlex.dados(o).get("nome",o.tipo))+" (%d/%d)"%[int(e.parada)+1,e.roteiro.size()]
	if a.visita.get("investigador_invasao",false):texto+=" · EM ÁREA RESTRITA"
	if a.visita.get("expulso",false):texto+=" · EXPULSO"
	return texto+"."
func etapa_visual(indice:int,nivel:int) -> PanelContainer:
	var p:=PanelContainer.new();p.custom_minimum_size=Vector2(132,44)
	var atual:=indice+1==nivel;var feita:=indice+1<nivel
	p.add_theme_stylebox_override("panel",T.caixa(Color("6b3a2c") if atual else Color("43302a") if feita else Color("241916"),T.AMBAR if atual else T.LINHA,6))
	var l:=T.texto(p,str(indice+1)+" · "+str(ETAPAS[indice][0]),13,T.PAPEL if atual or feita else T.SUAVE);l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	return p
func atualizar_quadro() -> void:
	var inv:InvestigacaoProgressivaPlex=jogo.sistemas.investigacao;var nivel:=inv.nivel()
	agora_texto.text=texto_agora(inv)
	var atual:=hash([nivel,inv.pistas.size(),roundi(inv.suspeita),inv.desaparecidos.size()])
	if atual==assinatura:return
	assinatura=atual
	for filho in etapas.get_children():filho.queue_free()
	for i in 4:etapas.add_child(etapa_visual(i,nivel))
	proximo.text="Sem investigação no momento." if nivel==0 else str(ETAPAS[nivel-1][1])
	barra.value=inv.suspeita;suspeita_texto.text="Suspeita %d / 100"%roundi(inv.suspeita)
	var nomes:=PackedStringArray()
	for id in inv.desaparecidos:nomes.append(str(inv.desaparecidos[id].nome))
	desaparecidos_texto.text="Desaparecidos: "+(", ".join(nomes) if not nomes.is_empty() else "nenhum")
	for filho in pistas_lista.get_children():filho.queue_free()
	var chaves:Array=inv.pistas.keys();chaves.sort_custom(func(x,y):return float(inv.pistas[x].quando)>float(inv.pistas[y].quando))
	if chaves.is_empty():T.texto(pistas_lista,"Nenhuma pista registrada.",13,T.SUAVE)
	for chave in chaves:
		var p:Dictionary=inv.pistas[chave];var item:=HBoxContainer.new();pistas_lista.add_child(item)
		var peso:=T.texto(item,"%+d"%roundi(float(p.peso)),14,Color("d07a5e") if float(p.peso)>0 else Color("8fb48a"));peso.custom_minimum_size.x=40
		var quando:=T.texto(item,horario(float(p.quando)),12,T.SUAVE);quando.custom_minimum_size.x=120
		var desc:=T.texto(item,str(p.descricao),13,T.PAPEL);desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;desc.size_flags_horizontal=Control.SIZE_EXPAND_FILL
func _process(delta:float) -> void:
	espera+=delta
	if espera<.5:return
	espera=0.0
	var inv:InvestigacaoProgressivaPlex=jogo.sistemas.investigacao;var nivel:=inv.nivel()
	emblema.visible=nivel>0
	if nivel>0:
		emblema_titulo.text="INVESTIGAÇÃO · NÍVEL %d"%nivel;emblema_barra.value=inv.suspeita
		if total_pistas>=0 and inv.pistas.size()>total_pistas:
			var piscar:=emblema.create_tween();piscar.tween_property(emblema,"modulate",Color(1.6,1.2,.8),.15);piscar.tween_property(emblema,"modulate",Color.WHITE,.6)
			jogo.painel.mensagem("Nova pista na investigação. Veja o quadro da investigação.")
		total_pistas=inv.pistas.size()
	if aberto():atualizar_quadro()

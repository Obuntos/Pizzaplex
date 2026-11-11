class_name EscalaNoturnaUIPlex
extends CanvasLayer

var jogo:Node
var raiz:=Control.new()
var folha:=Control.new()
var linhas:=Control.new()
var noites:=5
var numero:Label
var entrada:LineEdit
var saida:LineEdit
var designado:OptionButton
var carimbo:Label
var aviso:Label
var inicio:=0
var confirmar:Button
var botoes_noites:Array[Button]=[]
func configurar(cena:Node) -> void:
	jogo=cena;layer=96;add_child(raiz);raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sombra:=ColorRect.new();sombra.color=Color(0,0,0,.65);sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raiz.add_child(sombra)
	raiz.add_child(folha);folha.size=Vector2(900,790)
	var fundo:=TextureRect.new();fundo.texture=load("res://assets/interface/documentos/turno.png");fundo.size=folha.size;folha.add_child(fundo)
	DocumentoPessoaPlex.texto(folha,"",Vector2(400,134),Vector2(116,24),15,"corpo").name="Data"
	DocumentoPessoaPlex.texto(folha,"",Vector2(532,134),Vector2(130,24),15,"corpo").name="Ordem"
	DocumentoPessoaPlex.texto(folha,"07",Vector2(828,134),Vector2(55,24),25,"forte")
	designado=OptionButton.new();designado.fit_to_longest_item=false;designado.clip_text=true;designado.position=Vector2(94,207);designado.size=Vector2(280,36);designado.add_theme_font_override("font",VintagePlex.fonte("corpo"));designado.add_theme_font_size_override("font_size",17);estilo(designado);folha.add_child(designado)
	DocumentoPessoaPlex.texto(folha,"Até oito noites consecutivas.\nRotina automática de segurança.",Vector2(432,208),Vector2(440,62),17,"corpo")
	for item in [["RONDA INTERNA",62,318,207],["PZ-6592",280,318,110],["EQUIPE",400,318,154],["Sem alteração",572,318,292],["Posto Central",62,382,206]]:DocumentoPessoaPlex.texto(folha,item[0],Vector2(item[1],item[2]),Vector2(item[3],28),17,"corpo")
	botoes_noites.append(DocumentoPessoaPlex.botao(folha,"−",Vector2(280,386),Vector2(22,24),func():ajustar_noites(-1)))
	numero=DocumentoPessoaPlex.texto(folha,"05",Vector2(306,384),Vector2(34,28),20,"forte")
	botoes_noites.append(DocumentoPessoaPlex.botao(folha,"+",Vector2(344,386),Vector2(22,24),func():ajustar_noites(1)))
	entrada=campo("22:00",Vector2(440,381));saida=campo("06:00",Vector2(620,381));entrada.text_changed.connect(func(_t):descarimbar());saida.text_changed.connect(func(_t):descarimbar())
	folha.add_child(linhas)
	carimbo=DocumentoPessoaPlex.texto(folha,"CONFERIDO\nSEGURANÇA · POSTO CENTRAL",Vector2(590,638),Vector2(290,72),28,"botao");carimbo.add_theme_color_override("font_color",Color("b3261e"));carimbo.rotation=deg_to_rad(-9);carimbo.hide()
	confirmar=DocumentoPessoaPlex.botao(folha,"CONTRATAR / AGENDAR",Vector2(588,805),Vector2(260,40),agendar);DocumentoPessoaPlex.escuro(confirmar)
	DocumentoPessoaPlex.escuro(DocumentoPessoaPlex.botao(folha,"FECHAR",Vector2(60,805),Vector2(110,40),fechar))
	aviso=DocumentoPessoaPlex.texto(folha,"",Vector2(190,804),Vector2(388,42),14,"corpo");aviso.add_theme_color_override("font_color",Color("f1e2bd"))
	designado.item_selected.connect(func(_i):descarimbar())
	get_viewport().size_changed.connect(redimensionar);raiz.hide()
func estilo(c:Control) -> void:
	for e in ["normal","hover","pressed","focus","read_only"]:c.add_theme_stylebox_override(e,StyleBoxEmpty.new())
	for e in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:c.add_theme_color_override(e,Color("241616"))
func campo(t:String,p:Vector2) -> LineEdit:
	var c:=LineEdit.new();c.text=t;c.position=p;c.size=Vector2(112,34);c.max_length=5;c.add_theme_font_override("font",VintagePlex.fonte("corpo"));c.add_theme_font_size_override("font_size",25);estilo(c);folha.add_child(c);return c
static func minutos(t:String) -> int:
	var p:=t.strip_edges().split(":")
	if p.size()!=2 or not p[0].is_valid_int() or not p[1].is_valid_int():return -1
	var h:=int(p[0]);var m:=int(p[1]);return h*60+m if h>=0 and h<24 and m>=0 and m<60 else -1
static func hora(v:int) -> String:return "%02d:%02d"%[floori(float(v)/60.0),v%60]
func aberto() -> bool:return raiz.visible
func abrir() -> void:
	var escala:EscalaNoturnaPlex=jogo.sistemas.guarda.escala;noites=escala.noites if escala.noites>0 else 5;inicio=escala.inicio if escala.carimbada else jogo.calendario.dias
	entrada.text=hora(escala.entrada);saida.text=hora(escala.saida);designado.clear()
	for a in jogo.personagens:
		if a.cargo=="funcionario" and a.funcao=="seguranca" and a.visita.get("contrato_noturno",false) and not a.visita.get("morto",false):
			designado.add_item(IdentidadesPlex.completo(a));designado.set_item_metadata(designado.item_count-1,{"ator":a.identificador})
			if escala.guarda==a.identificador:designado.select(designado.item_count-1)
	var bloqueado:=escala.vigente(jogo.calendario.dias,jogo.calendario.minutos)
	for c in ([] if bloqueado else RecrutamentoPlex.listar(jogo,"seguranca")):
		designado.add_item(str(c.nome)+" "+str(c.sobrenome));designado.set_item_metadata(designado.item_count-1,{"candidato":c.id,"salario":c.salario})
	carimbo.visible=bloqueado;raiz.show();atualizar_linhas();atualizar_custo();redimensionar()
	confirmar.disabled=bloqueado;designado.disabled=bloqueado;entrada.editable=not bloqueado;saida.editable=not bloqueado
	for b in botoes_noites:b.disabled=bloqueado
	if bloqueado:aviso.text="Contrato em andamento. Aguarde o término."
func fechar() -> void:raiz.hide()
func redimensionar() -> void:
	var tela:=get_viewport().get_visible_rect().size;var fator:=minf(1,minf((tela.x-24)/900.0,(tela.y-24)/858.0));folha.scale=Vector2.ONE*fator;folha.position=((tela-Vector2(900,858)*fator)*.5).round()
func ajustar_noites(n:int) -> void:noites=clampi(noites+n,1,8);descarimbar()
func descarimbar() -> void:carimbo.hide();atualizar_linhas();atualizar_custo()
func atualizar_custo() -> void:
	var d:Dictionary=designado.get_selected_metadata() if designado.selected>=0 else {}
	if d.has("ator"):
		var a:PersonagemPlex=jogo.clientes.ator(int(d.ator))
		aviso.text="Adiantamento: US$ %d · acerto pelas horas do ponto."%(ceili(float(HabilidadesEquipePlex.salario(a))/7)*noites) if is_instance_valid(a) else "Selecione um guarda."
	else:aviso.text="Adiantamento: US$ %d por %d noites · acerto pelo ponto."%[GuardaAutonomoPlex.preco_noites(d,noites),noites]
func atualizar_linhas() -> void:
	for n in linhas.get_children():linhas.remove_child(n);n.queue_free()
	numero.text=str(noites).pad_zeros(2)
	var escala:EscalaNoturnaPlex=jogo.sistemas.guarda.escala
	var data:Dictionary=jogo.calendario.data(inicio-jogo.calendario.dias)
	folha.get_node("Data").text="%02d/%02d/%d"%[data.dia,data.mes,data.ano];folha.get_node("Ordem").text="N-"+str(escala.numero+1).pad_zeros(4)
	for i in noites:
		var d:Dictionary=jogo.calendario.data(inicio+i-jogo.calendario.dias);var y:=495+i*29
		var valores:Array=[entrada.text,saida.text,"NOITE "+str(i+1),"%02d/%02d/%d"%[d.dia,d.mes,d.ano],str(int(escala.rondas.get(str(i),0))) if carimbo.visible else "0",["01","02","20","30","50","80","01","02"][i],"✓" if carimbo.visible and escala.presencas.get(str(i),false) else "□"]
		var xs:Array=[62,132,202,337,555,622,730];var larguras:Array=[66,66,130,208,58,90,100]
		for k in valores.size():DocumentoPessoaPlex.texto(linhas,str(valores[k]),Vector2(xs[k],y),Vector2(larguras[k],28),16,"corpo")
func agendar() -> void:
	if jogo.sistemas.guarda.escala.vigente(jogo.calendario.dias,jogo.calendario.minutos):aviso.text="Aguarde o contrato atual terminar.";return
	var de:=minutos(entrada.text);var ate:=minutos(saida.text)
	if de<0 or ate<0 or de==ate:aviso.text="Use horários distintos no formato HH:MM.";return
	if carimbo.visible:aviso.text="Esta escala já foi confirmada.";return
	var selecao:Dictionary=designado.get_selected_metadata() if designado.selected>=0 else {}
	var a:PersonagemPlex
	if selecao.has("candidato"):
		a=jogo.sistemas.guarda.contratar_noturno(str(selecao.candidato),noites)
		if not is_instance_valid(a):aviso.text="Saldo insuficiente para contratar este turno.";return
	else:
		a=jogo.clientes.ator(int(selecao.get("ator",-1)))
		if not is_instance_valid(a):aviso.text="Selecione um candidato no cartão.";return
		var custo:=ceili(float(HabilidadesEquipePlex.salario(a))/7)*noites
		if jogo.servicos.saldo<custo:aviso.text="Saldo insuficiente para renovar.";return
		jogo.servicos.saldo=snappedf(jogo.servicos.saldo-custo,.01);a.visita.contrato_pago=float(a.visita.get("contrato_pago",0))+custo
		a.visita.credito_salario=float(a.visita.get("credito_salario",0))+custo
	inicio=jogo.calendario.dias
	if jogo.calendario.minutos>de:inicio+=1
	if jogo.sistemas.guarda.escala.agendar(inicio,noites,de,ate,a.identificador):
		designado.set_item_metadata(designado.selected,{"ator":a.identificador});carimbo.show();confirmar.disabled=true;jogo.terminal_ui.montar_pagina.call_deferred();jogo.painel.mensagem("Segurança contratado. Comparece no horário marcado.");confirmar.text="CONTRATADO";carimbo.text="CONTRATADO\nSEGURANÇA · POSTO CENTRAL"
		await get_tree().create_timer(1.1).timeout
		fechar()
func _input(e:InputEvent) -> void:
	if aberto() and e is InputEventKey and e.pressed and e.keycode==KEY_ESCAPE:fechar();get_viewport().set_input_as_handled()

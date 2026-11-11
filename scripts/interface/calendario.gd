class_name UICalendarioPlex
extends Control

const TINTA=Color("2a1408")
const VERMELHO=Color("a8262b")
const PAPEL=Color("f3e6c2")
var jogo:Node
var janela:=Control.new()
var corpo:=Control.new()
var mes_base:=0
var escolhido:=0
var palco:=-1
var bilhete:Control
var grade:Control
var dias_botoes:Array[Button]=[]

func configurar(cena:Node) -> void:
	jogo=cena;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var tema:=Theme.new();tema.default_font=VintagePlex.fonte();tema.default_font_size=16;tema.set_color("font_color","Label",TINTA);theme=tema
	var sombra:=ColorRect.new();sombra.color=Color(0,0,0,.7);sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(sombra)
	add_child(janela);janela.size=Vector2(980,760)
	var madeira:=SuperficieModelosPlex.new();madeira.size=janela.size;janela.add_child(madeira)
	var folha:=SuperficieModelosPlex.new("papel");folha.position=Vector2(54,48);folha.size=Vector2(872,655);janela.add_child(folha)
	var espiral:=SuperficieModelosPlex.new("espiral");espiral.position=Vector2(50,44);espiral.size=Vector2(880,40);janela.add_child(espiral)
	janela.add_child(corpo);corpo.position=Vector2(94,88);corpo.size=Vector2(792,580)
	get_viewport().size_changed.connect(redimensionar);hide()
func redimensionar() -> void:
	if not is_inside_tree():return
	var tela:=get_viewport_rect().size;var escala:=minf(1.0,minf((tela.x-24)/980.0,(tela.y-24)/760.0))
	janela.scale=Vector2.ONE*escala;janela.position=((tela-janela.size*escala)*.5).round()
func abrir() -> void:mes_base=jogo.calendario.indice_mes();escolhido=jogo.calendario.dias;show();preencher();redimensionar()
func navegar(direcao:int) -> void:mes_base=clampi(mes_base+direcao,0,CalendarioPlex.TOTAL_MESES-1);escolhido=jogo.calendario.inicio_mes(mes_base);preencher()
func rotulo(pai:Node,valor:String,pos:Vector2,tamanho:int=16,fonte:String="corpo",cor:Color=TINTA,largura:float=0) -> Label:
	var l:=Label.new();l.text=valor;l.position=pos;var face:Font=VintagePlex.fonte(fonte)
	if fonte=="botao" or fonte=="titulo" and tamanho>=60 and valor.length()>2:
		var variacao:=FontVariation.new();variacao.base_font=face;variacao.spacing_glyph=2 if fonte=="botao" else 3;face=variacao
	l.add_theme_font_override("font",face);l.add_theme_font_size_override("font_size",tamanho);l.add_theme_color_override("font_color",cor);l.mouse_filter=Control.MOUSE_FILTER_IGNORE;pai.add_child(l)
	if largura>0:l.custom_minimum_size.x=largura;l.size.x=largura;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if largura>0 and pai is not Container:l.size=Vector2(largura,160)
	return l
func botao(pai:Node,valor:String,pos:Vector2,dim:Vector2,acao:Callable,vermelho:bool=false) -> Button:
	var b:=Button.new();b.text=valor;b.position=pos;b.size=dim;var fonte:=FontVariation.new();fonte.base_font=VintagePlex.fonte("botao");fonte.spacing_glyph=2;b.add_theme_font_override("font",fonte);b.add_theme_font_size_override("font_size",15)
	for e in ["normal","hover","pressed","disabled"]:
		var st:=StyleBoxFlat.new();st.bg_color=(VERMELHO if vermelho else TINTA).lightened(.1 if e=="hover" else 0.0);st.shadow_color=Color(0,0,0,.4);st.shadow_size=3;st.shadow_offset=Vector2(3,3);st.border_color=Color(1,1,1,.13);st.border_width_top=3;st.border_width_bottom=3;b.add_theme_stylebox_override(e,st)
	for n in ["font_color","font_hover_color","font_pressed_color"]:b.add_theme_color_override(n,PAPEL)
	b.pressed.connect(acao);pai.add_child(b);return b
func imagem(pai:Node,clima:String,pos:Vector2,dim:Vector2) -> TextureRect:
	var nome:String={"Ensolarado":"limpo","Calor":"limpo","Nublado":"nublado","Chuva":"chuva","Neve":"neve"}.get(clima,"nublado")
	var t:=TextureRect.new();t.texture=load("res://assets/interface/modelos/"+nome+".svg");t.position=pos;t.size=dim;t.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;t.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;t.mouse_filter=Control.MOUSE_FILTER_IGNORE;pai.add_child(t);return t
func preencher() -> void:
	for n in corpo.get_children():corpo.remove_child(n);n.queue_free()
	dias_botoes.clear()
	var inicio_mes:int=jogo.calendario.inicio_mes(mes_base);var data:Dictionary=jogo.calendario.data(inicio_mes-jogo.calendario.dias)
	rotulo(corpo,"CADERNO DE APRESENTAÇÕES · 1958 — 1959",Vector2.ZERO,12,"botao",Color("5e4326"))
	var mes:=rotulo(corpo,IdiomaPlex.traduzir(str(CalendarioPlex.MESES[int(data.mes)-1])).to_upper(),Vector2(0,20),60,"titulo",VERMELHO)
	mes.add_theme_color_override("font_shadow_color",Color("d9bd80"));mes.add_theme_constant_override("shadow_offset_x",3);mes.add_theme_constant_override("shadow_offset_y",3)
	var largura_mes:=mes.get_theme_font("font").get_string_size(mes.text,HORIZONTAL_ALIGNMENT_LEFT,-1,60).x
	rotulo(corpo,str(data.ano),Vector2(largura_mes+16,44),28,"titulo")
	var ant:=botao(corpo,"◀ "+IdiomaPlex.traduzir(CalendarioPlex.MESES[posmod(int(data.mes)-2,12)]).substr(0,3).to_upper(),Vector2(522,40),Vector2(80,40),func():navegar(-1));ant.disabled=mes_base==0
	var prox:=botao(corpo,IdiomaPlex.traduzir(CalendarioPlex.MESES[posmod(int(data.mes),12)]).substr(0,3).to_upper()+" ▶",Vector2(612,40),Vector2(80,40),func():navegar(1));prox.disabled=mes_base==CalendarioPlex.TOTAL_MESES-1
	botao(corpo,"FECHAR",Vector2(702,40),Vector2(90,40),hide,true)
	grade=Control.new();grade.position=Vector2(0,102);grade.size=Vector2(530,426);corpo.add_child(grade)
	var w:=530.0/7.0
	for i in 7:
		var bg:=ColorRect.new();bg.color=VERMELHO;bg.position=Vector2(i*w,0);bg.size=Vector2(w,28);grade.add_child(bg)
		var l:=rotulo(bg,["DOM","SEG","TER","QUA","QUI","SEX","SÁB"][i],Vector2(0,5),13,"botao",Color("f0c97a"));l.size.x=w;l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var inicio:int=inicio_mes-int(data.semana)
	for i in 42:
		var absoluto:=inicio+i;var d:Dictionary=jogo.calendario.data(absoluto-jogo.calendario.dias)
		var b:=Button.new();b.position=Vector2(posmod(i,7)*w,28+floori(float(i)/7.0)*66);b.size=Vector2(w,66);b.disabled=int(d.mes)!=int(data.mes)
		for e in ["normal","hover","pressed","disabled"]:
			var st:=StyleBoxFlat.new();st.bg_color=Color("fbe3a0") if absoluto==escolhido else Color(0,0,0,.06) if b.disabled else Color(VERMELHO,.07) if e=="hover" else Color.TRANSPARENT;st.border_color=VERMELHO if absoluto==escolhido else TINTA;st.border_width_right=2;st.border_width_bottom=2
			if absoluto==escolhido:st.set_border_width_all(4)
			b.add_theme_stylebox_override(e,st)
		b.add_theme_stylebox_override("focus",StyleBoxEmpty.new());grade.add_child(b);dias_botoes.append(b)
		rotulo(b,str(d.dia),Vector2(8,6),15,"forte",VERMELHO if absoluto==escolhido or posmod(i,7) in [0,6] else TINTA)
		imagem(b,jogo.calendario.previsao(absoluto-jogo.calendario.dias),Vector2(w-37,30),Vector2(30,30))
		if b.disabled:b.modulate.a=.4
		b.pressed.connect(func():escolhido=absoluto;preencher())
	for i in 4:
		imagem(corpo,["Ensolarado","Nublado","Neve","Chuva"][i],Vector2(i*110,540),Vector2(18,18))
		rotulo(corpo,["Limpo","Nublado","Neve","Chuva"][i],Vector2(i*110+24,540),13,"corpo",Color("5e4326"))
	preencher_bilhete()
func preencher_bilhete() -> void:
	bilhete=Control.new();bilhete.position=Vector2(564,116);bilhete.size=Vector2(224,466);bilhete.pivot_offset=bilhete.size*.5;bilhete.rotation=deg_to_rad(-1.5);corpo.add_child(bilhete)
	var bg:=SuperficieModelosPlex.new("bilhete");bg.size=bilhete.size;bilhete.add_child(bg)
	var fita:=ColorRect.new();fita.color=Color("e8e2cccc");fita.position=Vector2(64,-14);fita.size=Vector2(96,28);fita.pivot_offset=fita.size*.5;fita.rotation=deg_to_rad(3);fita.mouse_filter=Control.MOUSE_FILTER_IGNORE;bilhete.add_child(fita)
	var offset:int=escolhido-jogo.calendario.dias;var d:Dictionary=jogo.calendario.data(offset)
	rotulo(bilhete,IdiomaPlex.traduzir(["DOMINGO","SEGUNDA-FEIRA","TERÇA-FEIRA","QUARTA-FEIRA","QUINTA-FEIRA","SEXTA-FEIRA","SÁBADO"][int(d.semana)]),Vector2(22,34),12,"botao",Color("6b5a10"),75)
	rotulo(bilhete,"%02d"%d.dia,Vector2(22,70),62,"titulo")
	var evento:String=jogo.calendario.evento(offset)
	if not evento.is_empty():
		var stamp:=PanelContainer.new();stamp.position=Vector2(106,84);stamp.custom_minimum_size=Vector2(96,44);stamp.size=Vector2(96,44);stamp.rotation=deg_to_rad(-6);stamp.add_theme_stylebox_override("panel",TemaIBMPlex.caixa(Color.TRANSPARENT,VERMELHO,4));bilhete.add_child(stamp)
		var l:=rotulo(stamp,IdiomaPlex.traduzir(evento).to_upper(),Vector2.ZERO,16,"titulo",VERMELHO,86);l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	linha_bilhete(148)
	imagem(bilhete,jogo.calendario.previsao(offset),Vector2(22,176),Vector2(48,48))
	rotulo(bilhete,IdiomaPlex.traduzir(jogo.calendario.previsao(offset))+" ·\n"+IdiomaPlex.traduzir(jogo.calendario.estacao(offset)),Vector2(82,164),17,"forte",TINTA,120)
	rotulo(bilhete,str(jogo.calendario.temperatura(offset))+" °C",Vector2(82,204),28,"titulo")
	var perfil:Dictionary=jogo.calendario.perfil(offset)
	for i in 2:
		var y:=248+i*42;var v:=int(perfil.chuva if i==0 else perfil.neve)
		rotulo(bilhete,"CHUVA" if i==0 else "NEVE",Vector2(22,y),12,"botao",Color("6b5a10"));rotulo(bilhete,str(v)+"%",Vector2(166,y),14,"forte")
		var track:=ColorRect.new();track.color=Color(0,0,0,.16);track.position=Vector2(22,y+22);track.size=Vector2(180,10);bilhete.add_child(track)
		var fill:=ColorRect.new();fill.color=TINTA;fill.size=Vector2(180*float(v)/100,10);track.add_child(fill)
	linha_bilhete(336);rotulo(bilhete,"A FAZER",Vector2(22,352),12,"botao",Color("6b5a10"))
	var scroll:=ScrollContainer.new();scroll.position=Vector2(22,378);scroll.size=Vector2(180,76);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;bilhete.add_child(scroll)
	var tarefas:=VBoxContainer.new();tarefas.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(tarefas)
	jogo.animatronicos.palcos.atualizar();var ids:Array=[]
	for id in jogo.animatronicos.palcos.grupos.values():
		if not ids.has(id):ids.append(id)
	ids.sort()
	if ids.is_empty():rotulo(tarefas,"Construa um palco para programar apresentações.",Vector2.ZERO,16,"forte",TINTA,180);return
	if not ids.has(palco):palco=ids[0]
	var seletor:=OptionButton.new();seletor.add_theme_font_override("font",VintagePlex.fonte());seletor.add_theme_font_size_override("font_size",14);tarefas.add_child(seletor)
	for id in ids:seletor.add_item("Palco "+str(ids.find(id)+1));seletor.set_item_metadata(seletor.item_count-1,id)
	seletor.select(ids.find(palco));seletor.item_selected.connect(func(i):palco=int(seletor.get_item_metadata(i));preencher())
	for a in jogo.personagens:
		if a.robo and jogo.animatronicos.palcos.da_pose(a.pose)==palco:rotulo(tarefas,IdentidadesPlex.completo(a)+" · "+str(a.robotica.get("apresentacao","cantar")),Vector2.ZERO,14,"forte",TINTA,180)
	rotulo(tarefas,"Botão direito no animatrônico para escolher Cantar, Falar ou Dançar.",Vector2.ZERO,13,"corpo",TINTA,180)
func linha_bilhete(y:float) -> void:
	var l:=ColorRect.new();l.color=Color(TINTA,.33);l.position=Vector2(22,y);l.size=Vector2(180,2);l.mouse_filter=Control.MOUSE_FILTER_IGNORE;bilhete.add_child(l)

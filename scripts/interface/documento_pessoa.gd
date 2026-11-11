class_name DocumentoPessoaPlex
extends Control

var carteira:CarteiraPlex
var energia:MedidorDocumentoPlex
var medidor:Label
var estado:Label
var descansar:Button
var problemas:Label
static func texto(pai:Node,t:String,pos:Vector2,dim:Vector2,n:int=22,tipo:String="titulo") -> Label:
	var l:=Label.new();l.text=t;l.position=pos;l.size=dim;l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;l.add_theme_font_override("font",VintagePlex.fonte(tipo));l.add_theme_font_size_override("font_size",n);l.add_theme_color_override("font_color",Color("2a1a12"));l.clip_text=true;pai.add_child(l);return l
static func botao(pai:Node,t:String,pos:Vector2,dim:Vector2,acao:Callable) -> Button:
	var b:=Button.new();b.text=t;b.position=pos;b.size=dim;b.add_theme_font_override("font",VintagePlex.fonte("botao"));b.add_theme_font_size_override("font_size",17)
	for v in ["normal","hover","pressed","focus","disabled"]:
		var s:=StyleBoxFlat.new();s.bg_color=Color("2a1a12") if v=="hover" else Color.TRANSPARENT;s.border_color=Color("2a1a12");s.set_border_width_all(2);b.add_theme_stylebox_override(v,s)
		b.add_theme_color_override("font_"+v+"_color",Color("e8d9b4") if v=="hover" else Color("2a1a12"))
	b.add_theme_color_override("font_color",Color("2a1a12"));b.pressed.connect(acao);pai.add_child(b);return b
func construir(c:CarteiraPlex) -> void:
	carteira=c;size=Vector2(680,404);var a:=c.ator;var empregado:=a.cargo=="funcionario"
	var fundo:=TextureRect.new();fundo.texture=load("res://assets/interface/documentos/"+("emp" if empregado else "civ")+".png");fundo.size=size;fundo.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(fundo)
	var foto:=TextureRect.new();foto.texture=RetratoEquipePlex.criar(a);foto.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;foto.position=Vector2(62,48);foto.size=Vector2(126,160);foto.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;foto.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;foto.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(foto)
	campo(self,IdentidadesPlex.completo(a),Vector2(224,34),Vector2(420,36),30)
	var perfil:Dictionary={};var familia:Dictionary={}
	if "populacao" in c.jogo:
		perfil=c.jogo.populacao.perfis.get(str(a.identidade.get("morador_id","")),{})
		familia=c.jogo.populacao.familias.get(str(perfil.get("familia","")),{})
	var apoio:=PackedStringArray()
	for f in a.funcoes_secundarias:apoio.append(EquipePlex.NOMES.get(f,f))
	var valores:Array=[str(int(a.identidade.get("idade",0)))+" anos","Funcionário" if empregado else str(perfil.get("ocupacao","Criança" if a.cargo=="crianca" else "Estudante" if a.cargo=="adolescente" else "Visitante")),str(EquipePlex.NOMES.get(a.funcao,"Geral")) if empregado else str(familia.get("endereco","Bairro Jardim")),", ".join(apoio) if empregado and not apoio.is_empty() else "—" if empregado else "Morador" if a.cargo=="morador" else "Visitante"]
	for i in 4:campo(self,str(valores[i]),Vector2(224+(224 if i%2 else 0),96+floorf(float(i)/2.0)*53),Vector2(204,27),22)
	energia=MedidorDocumentoPlex.new();energia.position=Vector2(110 if empregado else 91,278 if empregado else 266);energia.size=Vector2(294 if empregado else 462,13);energia.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(energia)
	medidor=texto(self,"",Vector2(420 if empregado else 566,265 if empregado else 255),Vector2(96 if empregado else 104,34),13,"forte")
	if empregado and a.funcao!="seguranca":
		descansar=botao(self,"DESCANSAR",Vector2(530,262),Vector2(122,44),func():c.jogo.turnos.descansar(a))
		descansar.tooltip_text="Recuperar energia na sala de descanso."
	elif not empregado:botao(self,"CONVERSAR",Vector2(526,306),Vector2(126,36),func():c.fechar();c.jogo.menu_controle.abrir_social(a)).disabled=a.visita.get("morto",false)
	texto(self,"PZ  "+str(a.identificador).pad_zeros(4)+"  "+str(int(a.identidade.get("idade",0))).pad_zeros(2),Vector2(28,312),Vector2(290,26),14,"corpo")
	estado=texto(self,"",Vector2(28,337),Vector2(620,24),12,"corpo");c.atividade=estado
	problemas=texto(self,"",Vector2(28,363),Vector2(620,36),12,"corpo")
	problemas.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	atualizar()
func atualizar() -> void:
	if not is_instance_valid(carteira.ator):return
	var a:=carteira.ator
	var motivos:=EmocaoPlex.motivos(a)
	problemas.text="Tudo bem." if motivos.is_empty() else "Precisa de atenção: "+" · ".join(motivos)
	problemas.tooltip_text="\n".join(motivos)
	energia.value=a.energia if a.cargo=="funcionario" else float(a.visita.get("satisfacao",50))
	medidor.text="%d / 100"%roundi(a.energia) if a.cargo=="funcionario" else "Triste" if a.visita.get("solitario",false) else "Tranquilo" if energia.value>=50 else "Insatisfeito"
	if is_instance_valid(descansar) and a.funcao!="seguranca":descansar.disabled=a.energia>=99 or a.visita.get("fora_turno",false)
func ajustar(tela:Vector2) -> void:
	var fator:=minf(1,minf((tela.x-32)/680.0,(tela.y-90)/404.0));scale=Vector2.ONE*fator;position=((tela-size*fator)*.5).round()

static func escuro(b:Button) -> void:
	for v in ["normal","hover","pressed","focus"]:
		var estilo:=StyleBoxFlat.new();estilo.bg_color=Color("3a2218") if v=="hover" else Color("1f1712");estilo.border_color=Color("6b5a46");estilo.set_border_width_all(2);b.add_theme_stylebox_override(v,estilo)
	for v in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:b.add_theme_color_override(v,Color("e8d9b4"))

static func campo(pai:Node,t:String,pos:Vector2,dim:Vector2,n:int) -> Label:
	var recorte:=Control.new();recorte.position=pos;recorte.size=dim;recorte.clip_contents=true;recorte.mouse_filter=Control.MOUSE_FILTER_IGNORE;pai.add_child(recorte)
	var fonte:=VintagePlex.fonte("titulo");var tamanho:=n
	while tamanho>14 and fonte.get_string_size(t,HORIZONTAL_ALIGNMENT_LEFT,-1,tamanho).x>dim.x:tamanho-=1
	var l:=texto(recorte,t,Vector2.ZERO,dim,tamanho);l.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;l.tooltip_text=t;l.size=dim;return l

class_name PausaDinerPlex
extends Control
## Pausa em estilo de cardápio de lanchonete. À esquerda, a silhueta do
## administrador em dois tons; no alto, o letreiro da casa com a seta; no
## meio, a nuvem creme com as opções, e a barra preta inclinada desliza até
## a escolhida; embaixo, a nuvem amarela com o resumo do dia.

const NOMES_IDIOMA={"automatico":"Automático","pt_BR":"Português","en":"English"}
const GLIFOS={
	"continuar":["#......","###....","#####..","#######","#####..","###....","#......"],
	"salvar":["######.","#.##.##","#.##.##","#######","#.....#","#.###.#","#######"],
	"carregar":["###....","#######","#.....#","#.....#","#.....#","#.....#","#######"],
	"idioma":[".#####.","#.#.#.#","#######","#.#.#.#","#######","#.#.#.#",".#####."],
	"tela":["#######","#.....#","#.....#","#.....#","#######","..###..",".#####."],
	"inicio":["...#...","..###..",".#####.","#######",".#...#.",".#.#.#.",".#####."],
	"sair":["####...","#..#.#.","#..#..#","#.#####","#..#..#","#..#.#.","####..."]
}
var hud:HudPlex
var jogo:Node
var fundo:=Fundo.new()
var silhueta:=DinerPlex.Silhueta.new()
var letreiro:=DinerPlex.Letreiro.new("PAUSA")
var pergunta:=DinerPlex.Quadradinhos.new("O que fazer?",30.0)
var etiqueta:=DinerPlex.Quadradinhos.new("Hoje",34.0)
var barra:=Barra.new()
var selo:=Selo.new()
var lista:=VBoxContainer.new()
var resumo:=VBoxContainer.new()
var dicas:=Label.new()
var linhas:Dictionary={}
var valores:Dictionary={}
var carregar:Button
var deslize:Tween
var nuvem_lista:=Rect2()
var nuvem_resumo:=Rect2()

func configurar(painel_hud:HudPlex, cena:Node) -> void:
	hud=painel_hud;jogo=cena
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	fundo.dono=self;fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(fundo)
	add_child(silhueta)
	add_child(letreiro)
	add_child(barra)
	add_child(pergunta)
	add_child(lista);lista.add_theme_constant_override("separation",0)
	criar_linha("continuar","Continuar",hud.alternar_menu)
	criar_linha("salvar","Salvar partida",func(): jogo.salvar();ConfetePlex.sobre(linhas.salvar,14))
	carregar=criar_linha("carregar","Carregar partida",hud.abrir_saves)
	criar_linha("idioma","Idioma",trocar_idioma,true)
	criar_linha("tela","Tela cheia",func(): jogo.alternar_tela_cheia();atualizar.call_deferred(),true)
	criar_linha("inicio","Menu inicial",func(): jogo.get_tree().change_scene_to_file("res://cenas/interface/inicio.tscn"))
	criar_linha("sair","Sair do jogo",func(): jogo.get_tree().quit()).perigo=true
	add_child(selo)
	add_child(etiqueta)
	add_child(resumo);resumo.add_theme_constant_override("separation",4)
	for chave in [["dia","Dia"],["caixa","Caixa"],["avisos","Avisos"]]:
		var item:=Resumo.new(str(chave[1]));resumo.add_child(item);valores[chave[0]]=item
	add_child(dicas)
	dicas.text="ESC  continuar     ·     ENTER  escolher     ·     ↑ ↓  navegar"
	dicas.add_theme_font_override("font",VintagePlex.fonte("forte"));dicas.add_theme_font_size_override("font_size",13)
	dicas.add_theme_color_override("font_color",DinerPlex.CREME);dicas.add_theme_color_override("font_outline_color",DinerPlex.PRETO);dicas.add_theme_constant_override("outline_size",4)
	dicas.mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(organizar)
	IdiomaPlex.idioma_alterado.connect(func(_l):atualizar())
	hide()

func criar_linha(id:String, rotulo:String, acao:Callable, com_valor:bool=false) -> Linha:
	var l:=Linha.new(rotulo,GLIFOS[id],com_valor)
	l.pressed.connect(acao)
	l.focus_entered.connect(func():focar(l))
	l.mouse_entered.connect(func():
		if not l.disabled:l.grab_focus())
	lista.add_child(l);linhas[id]=l
	return l

func trocar_idioma() -> void:
	var i:int=IdiomaPlex.MODOS.find(IdiomaPlex.modo)
	IdiomaPlex.definir_modo(str(IdiomaPlex.MODOS[(i+1)%IdiomaPlex.MODOS.size()]))
	atualizar()

## Distribui as peças pela tela. As medidas seguem a proporção da janela.
func organizar() -> void:
	var w:=size.x;var h:=size.y
	nuvem_lista=Rect2(DinerPlex.par(w*.36),DinerPlex.par(h*.2),DinerPlex.par(w*.58),DinerPlex.par(maxf(372.0,h*.48)))
	nuvem_resumo=Rect2(DinerPlex.par(w*.42),DinerPlex.par(nuvem_lista.end.y+36.0),DinerPlex.par(w*.5),DinerPlex.par(maxf(150.0,h-nuvem_lista.end.y-96.0)))
	letreiro.position=Vector2(DinerPlex.par(w*.27),DinerPlex.par(h*.035))
	var miolo:=DinerPlex.miolo_nuvem(nuvem_lista)
	pergunta.reset_size()
	pergunta.position=Vector2(DinerPlex.par(miolo.end.x-pergunta.custom_minimum_size.x-24.0),DinerPlex.par(nuvem_lista.position.y+22.0))
	lista.position=Vector2(DinerPlex.par(miolo.position.x+30.0),DinerPlex.par(nuvem_lista.position.y+72.0))
	lista.size=Vector2(DinerPlex.par(miolo.size.x-70.0),0)
	for l in lista.get_children():(l as Control).custom_minimum_size=Vector2(lista.size.x,38)
	var miolo_resumo:=DinerPlex.miolo_nuvem(nuvem_resumo)
	etiqueta.position=Vector2(DinerPlex.par(nuvem_resumo.position.x-18.0),DinerPlex.par(nuvem_resumo.position.y-22.0))
	resumo.position=Vector2(DinerPlex.par(miolo_resumo.position.x+70.0),DinerPlex.par(nuvem_resumo.position.y+30.0))
	resumo.size=Vector2(DinerPlex.par(miolo_resumo.size.x-110.0),0)
	for item in resumo.get_children():(item as Control).custom_minimum_size=Vector2(resumo.size.x,30)
	selo.position=Vector2(DinerPlex.par(nuvem_resumo.position.x-116.0),DinerPlex.par(nuvem_resumo.position.y+nuvem_resumo.size.y*.62-96.0))
	dicas.reset_size()
	dicas.position=Vector2(w-dicas.size.x-28.0,h-34.0)
	posicionar_silhueta()
	fundo.queue_redraw()

func posicionar_silhueta() -> void:
	silhueta.position=Vector2(DinerPlex.par(maxf(24.0,size.x*.165-silhueta.size.x*.5)),altura_silhueta())

func altura_silhueta() -> float:
	return DinerPlex.par(size.y-silhueta.size.y-size.y*.07)

## A barra preta desliza até a opção em foco.
func focar(l:Linha, imediato:bool=false) -> void:
	var destino:=lista.position+l.position+Vector2(-18,2)
	var dimensao:=Vector2(l.size.x+36.0,34.0)
	if deslize!=null and deslize.is_valid():deslize.kill()
	for outra in lista.get_children():(outra as Linha).queue_redraw()
	if imediato or not barra.visible:
		barra.position=destino;barra.size=dimensao;barra.show();barra.queue_redraw();return
	deslize=create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	deslize.tween_property(barra,"position",destino,.14)
	deslize.tween_property(barra,"size",dimensao,.14)

func atualizar() -> void:
	(linhas.idioma as Linha).valor=tr(str(NOMES_IDIOMA.get(IdiomaPlex.modo,"Automático")))
	(linhas.tela as Linha).valor=tr("Ligada") if get_window().mode==Window.MODE_FULLSCREEN else tr("Desligada")
	var d:Dictionary=jogo.calendario.data()
	(valores.dia as Resumo).valor="%02d · %s"%[int(d.dia),tr(RelogioCalendarioPlex.SEMANA[int(d.semana)]).capitalize()]
	(valores.caixa as Resumo).valor=NumeroPixelPlex.dinheiro(float(jogo.servicos.saldo)).replace("'"," ")
	var serios:=0;var comuns:=0
	for aviso in hud.pendencias.avisos:
		if int(aviso.nivel)==2:serios+=1
		else:comuns+=1
	(valores.avisos as Resumo).valor=tr("Nenhum") if serios+comuns==0 else tr("%d urgentes · %d comuns")%[serios,comuns]
	(valores.avisos as Resumo).alerta=serios>0
	for item in lista.get_children()+resumo.get_children():(item as Control).queue_redraw()

## Mostra a pausa com as peças entrando de lados diferentes.
func abrir() -> void:
	show()
	letreiro.definir_nome(str(jogo.operacao.nome))
	var admin:PersonagemPlex=jogo.controle.administrador()
	silhueta.mostrar(RetratoEquipePlex.criar(admin) if is_instance_valid(admin) else null,size.y*.5)
	organizar();atualizar()
	barra.hide()
	(linhas.continuar as Linha).grab_focus()
	focar(linhas.continuar,true)
	var t:=create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	modulate.a=0.0
	t.tween_property(self,"modulate:a",1.0,.1)
	var alvo_silhueta:=silhueta.position
	silhueta.position.x-=90.0
	t.tween_property(silhueta,"position:x",alvo_silhueta.x,.26)
	var alvo_letreiro:=letreiro.position
	letreiro.position.y-=60.0
	t.tween_property(letreiro,"position:y",alvo_letreiro.y,.3)

func _process(_delta:float) -> void:
	if not visible:return
	# respiração leve da silhueta
	var sobe:=2.0 if int(Time.get_ticks_msec()/900.0)%2==0 else 0.0
	silhueta.position.y=altura_silhueta()-sobe


## Recortes fixos do fundo: tinta vermelha, blocos de xadrez e as nuvens.
class Fundo extends Control:
	var dono:PausaDinerPlex
	func _init() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	func _draw() -> void:
		if dono==null:return
		var ci:=get_canvas_item()
		var a:=dono.nuvem_lista;var b:=dono.nuvem_resumo
		ShowPlex.ret(ci,0,0,size.x,size.y,Color(.36,.05,.07,.55))
		# faixa vermelha inclinada atrás da silhueta
		var y:=0.0
		while y<size.y:
			ShowPlex.ret(ci,0,y,DinerPlex.par(size.x*.3-y*.12),2,Color(.62,.1,.13,.82))
			y+=2.0
		DinerPlex.xadrez(ci,Rect2(DinerPlex.par(a.position.x+a.size.x*.42),DinerPlex.par(a.position.y-66.0),DinerPlex.par(a.size.x*.5),132),22)
		DinerPlex.xadrez(ci,Rect2(DinerPlex.par(a.position.x-44.0),DinerPlex.par(a.position.y+a.size.y*.3),110,DinerPlex.par(a.size.y*.62)),22)
		DinerPlex.nuvem_cheia(ci,b,DinerPlex.AMARELO,DinerPlex.VERMELHO,3)
		DinerPlex.nuvem_cheia(ci,a,DinerPlex.CREME,DinerPlex.VERMELHO,0)
		DinerPlex.barra(ci,Rect2(DinerPlex.par(dono.dicas.position.x-26.0),DinerPlex.par(dono.dicas.position.y-6.0),DinerPlex.par(dono.dicas.size.x+60.0),28),DinerPlex.PRETO,10.0)


## Selo "em pausa", com três nuvenzinhas de vapor, por cima da silhueta.
class Selo extends Control:
	func _init() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		custom_minimum_size=Vector2(128,160);size=custom_minimum_size
	func _notification(o:int) -> void:
		if o==NOTIFICATION_TRANSLATION_CHANGED:queue_redraw()
	func _draw() -> void:
		var ci:=get_canvas_item()
		var c:=Vector2(64,96)
		for nuvenzinha in [Vector2(-34,-62),Vector2(-8,-78),Vector2(20,-66)]:
			ShowPlex.disco(ci,c+nuvenzinha,18,DinerPlex.PRETO);ShowPlex.disco(ci,c+nuvenzinha,14,DinerPlex.CREME)
		ShowPlex.disco(ci,c,62,DinerPlex.PRETO)
		ShowPlex.disco(ci,c,58,DinerPlex.CREME)
		ShowPlex.disco(ci,c,52,DinerPlex.SANGRIA)
		var fonte:=VintagePlex.fonte("titulo")
		draw_string(fonte,Vector2(c.x-58,c.y-4),tr("EM"),HORIZONTAL_ALIGNMENT_CENTER,116,22,DinerPlex.CREME)
		draw_string(fonte,Vector2(c.x-58,c.y+22),tr("PAUSA"),HORIZONTAL_ALIGNMENT_CENTER,116,26,DinerPlex.AMARELO)


class Barra extends Control:
	func _init() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		resized.connect(queue_redraw)
	func _draw() -> void:
		DinerPlex.barra(get_canvas_item(),Rect2(Vector2(4,4),size),DinerPlex.SANGRIA)
		DinerPlex.barra(get_canvas_item(),Rect2(Vector2.ZERO,size),DinerPlex.PRETO)


## Opção do cardápio: ficha escura com o símbolo, o nome e, se houver,
## a pílula com o valor atual.
class Linha extends Button:
	var rotulo:=""
	var glifo:Array=[]
	var tem_valor:=false
	var perigo:=false
	var valor:="":
		set(v):
			if v==valor:return
			valor=v;queue_redraw()
	func _init(nome:String, simbolo:Array, com_valor:bool) -> void:
		rotulo=nome;glifo=simbolo;tem_valor=com_valor
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		custom_minimum_size=Vector2(200,38)
		for estado in ["normal","hover","pressed","hover_pressed","disabled","focus"]:add_theme_stylebox_override(estado,StyleBoxEmpty.new())
		focus_exited.connect(queue_redraw)
	func _notification(o:int) -> void:
		if o==NOTIFICATION_TRANSLATION_CHANGED:queue_redraw()
	func _draw() -> void:
		var ci:=get_canvas_item()
		var foco:=has_focus()
		var afunda:=2.0 if get_draw_mode()==DRAW_PRESSED or get_draw_mode()==DRAW_HOVER_PRESSED else 0.0
		var tinta:=DinerPlex.CREME if foco else Color("9c8f78") if disabled else DinerPlex.VERMELHO if perigo else DinerPlex.PRETO
		# ficha do símbolo
		var ficha:=Rect2(8,8+afunda,44,22)
		DinerPlex.pilula(ci,ficha,DinerPlex.CREME if foco else DinerPlex.PRETO)
		var cor_glifo:=DinerPlex.PRETO if foco else DinerPlex.AMARELO
		for j in glifo.size():
			for i in str(glifo[j]).length():
				if str(glifo[j])[i]=="#":ShowPlex.ret(ci,ficha.position.x+15+i*2,ficha.position.y+4+j*2,2,2,cor_glifo)
		var fonte:=VintagePlex.fonte("titulo")
		draw_string(fonte,Vector2(66,27+afunda),tr(rotulo),HORIZONTAL_ALIGNMENT_LEFT,size.x-210.0,20,tinta)
		if tem_valor:
			var caixa:=Rect2(size.x-150.0,6+afunda,132,26)
			DinerPlex.pilula(ci,caixa,DinerPlex.PRETO)
			DinerPlex.pilula(ci,caixa.grow(-2),DinerPlex.CREME)
			draw_string(VintagePlex.fonte("forte"),Vector2(caixa.position.x,caixa.position.y+18),valor,HORIZONTAL_ALIGNMENT_CENTER,caixa.size.x,13,DinerPlex.PRETO)


## Linha do resumo do dia: nome à esquerda, valor numa pílula à direita.
class Resumo extends Control:
	var nome:=""
	var alerta:=false
	var valor:="":
		set(v):
			if v==valor:return
			valor=v;queue_redraw()
	func _init(titulo:String) -> void:
		nome=titulo
		mouse_filter=Control.MOUSE_FILTER_IGNORE;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		custom_minimum_size=Vector2(200,30)
	func _notification(o:int) -> void:
		if o==NOTIFICATION_TRANSLATION_CHANGED:queue_redraw()
	func _draw() -> void:
		var ci:=get_canvas_item()
		draw_string(VintagePlex.fonte("titulo"),Vector2(0,22),tr(nome),HORIZONTAL_ALIGNMENT_LEFT,size.x-240.0,20,DinerPlex.PRETO)
		var caixa:=Rect2(size.x-230.0,2,230,26)
		DinerPlex.pilula(ci,caixa,DinerPlex.PRETO)
		DinerPlex.pilula(ci,caixa.grow(-2),DinerPlex.VERMELHO if alerta else DinerPlex.CREME)
		draw_string(VintagePlex.fonte("forte"),Vector2(caixa.position.x,caixa.position.y+18),valor,HORIZONTAL_ALIGNMENT_CENTER,caixa.size.x,14,DinerPlex.CREME if alerta else DinerPlex.PRETO)

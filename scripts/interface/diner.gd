class_name DinerPlex
extends RefCounted
## Kit de lanchonete: o estilo de cardápio em recortes chapados. Nuvens
## creme com contorno vermelho, blocos de xadrez, barra preta inclinada na
## opção escolhida, pílulas de valor, letras em quadradinhos, letreiro com
## seta e a silhueta do personagem em dois tons. Tudo em degraus de 2 px.

const VERMELHO=Color("b3202a")
const SANGRIA=Color("6e1218")
const CREME=Color("fff3c4")
const AMARELO=Color("f2c230")
const PRETO=Color("1d0e08")
const RAIOS=[1.0,1.22,.9,1.14,.84]
static var sombreador:Shader

static func par(v:float) -> float:
	return roundf(v*.5)*2.0

## Nuvem: um miolo retangular com lóbulos redondos em toda a volta.
## `extra` engorda a forma inteira, para desenhar o contorno por baixo.
static func nuvem(ci:RID, r:Rect2, cor:Color, extra:float=0.0, semente:int=0) -> void:
	var lobo:=par(minf(r.size.y*.3,60.0))
	var miolo:=Rect2(par(r.position.x+lobo*.6),par(r.position.y+lobo*.6),par(r.size.x-lobo*1.2),par(r.size.y-lobo*1.2)).grow(extra)
	ShowPlex.ret(ci,miolo.position.x,miolo.position.y,miolo.size.x,miolo.size.y,cor)
	var n:=maxi(2,roundi(r.size.x/(lobo*1.7)))
	for i in n:
		var cima:=par(lobo*RAIOS[(i+semente)%5])
		ShowPlex.disco(ci,Vector2(par(r.position.x+r.size.x*(i+.5)/n),par(r.position.y+cima)),cima+extra,cor)
		var baixo:=par(lobo*RAIOS[(i+semente+2)%5])
		ShowPlex.disco(ci,Vector2(par(r.position.x+r.size.x*(i+.5)/n),par(r.end.y-baixo)),baixo+extra,cor)
	var m:=maxi(1,roundi(r.size.y/(lobo*1.9)))
	for i in m:
		var lado:=par(lobo*RAIOS[(i+semente+1)%5])
		var y:=par(r.position.y+r.size.y*(i+.5)/m)
		ShowPlex.disco(ci,Vector2(par(r.position.x+lado),y),lado+extra,cor)
		ShowPlex.disco(ci,Vector2(par(r.end.x-lado),y),lado+extra,cor)

## Nuvem pronta: contorno escuro fino, contorno colorido grosso e miolo.
static func nuvem_cheia(ci:RID, r:Rect2, miolo:Color=CREME, borda:Color=VERMELHO, semente:int=0) -> void:
	nuvem(ci,r,PRETO,10.0,semente)
	nuvem(ci,r,borda,8.0,semente)
	nuvem(ci,r,miolo,0.0,semente)

## Área segura para o conteúdo dentro de uma nuvem.
static func miolo_nuvem(r:Rect2) -> Rect2:
	var lobo:=par(minf(r.size.y*.3,60.0))
	return r.grow(-lobo*.5)

static func xadrez(ci:RID, r:Rect2, lado:float=22.0, a:Color=VERMELHO, b:Color=CREME) -> void:
	var y:=0.0
	var linha:=0
	while y<r.size.y:
		var x:=0.0
		var coluna:=linha
		while x<r.size.x:
			ShowPlex.ret(ci,r.position.x+x,r.position.y+y,minf(lado,r.size.x-x),minf(lado,r.size.y-y),a if coluna%2==0 else b)
			x+=lado;coluna+=1
		y+=lado;linha+=1

## Barra inclinada da opção escolhida: um paralelogramo em degraus.
static func barra(ci:RID, r:Rect2, cor:Color=PRETO, queda:float=14.0) -> void:
	var y:=0.0
	while y<r.size.y:
		var d:=par(queda*(1.0-y/r.size.y))
		ShowPlex.ret(ci,r.position.x+d,r.position.y+y,r.size.x-queda,2.0,cor)
		y+=2.0

## Pílula de pontas redondas, para valores e contadores.
static func pilula(ci:RID, r:Rect2, cor:Color) -> void:
	var raio:=par(r.size.y*.5)
	ShowPlex.disco(ci,Vector2(par(r.position.x+raio),par(r.position.y+raio)),raio,cor)
	ShowPlex.disco(ci,Vector2(par(r.end.x-raio),par(r.position.y+raio)),raio,cor)
	ShowPlex.ret(ci,par(r.position.x+raio),par(r.position.y),par(r.size.x-raio*2.0),raio*2.0,cor)

## Seta de letreiro apontando para a direita, com a ponta em degraus.
static func seta(ci:RID, r:Rect2, cor:Color) -> void:
	var ponta:=par(r.size.y*.5)
	ShowPlex.ret(ci,r.position.x,r.position.y+8.0,r.size.x-ponta-12.0,r.size.y-16.0,cor)
	var y:=0.0
	while y<r.size.y:
		var avanco:=par(ponta*(1.0-absf(y+1.0-r.size.y*.5)/(r.size.y*.5)))
		ShowPlex.ret(ci,r.end.x-ponta-14.0,r.position.y+y,avanco+14.0,2.0,cor)
		y+=2.0

## Material que transforma um retrato em estampa de dois tons. Com
## `solido`, pinta tudo de uma cor só, para o contorno.
static func estampa(clara:Color=CREME, escura:Color=VERMELHO, solido:bool=false) -> ShaderMaterial:
	if sombreador==null:
		sombreador=Shader.new()
		sombreador.code="shader_type canvas_item;\nuniform vec4 clara:source_color;\nuniform vec4 escura:source_color;\nuniform float corte=0.42;\nuniform bool solido=false;\nvoid fragment(){vec4 c=texture(TEXTURE,UV);float l=dot(c.rgb,vec3(0.299,0.587,0.114));vec3 tom=solido?escura.rgb:mix(escura.rgb,clara.rgb,step(corte,l));COLOR=vec4(tom,step(0.5,c.a));}"
	var m:=ShaderMaterial.new()
	m.shader=sombreador
	m.set_shader_parameter("clara",clara);m.set_shader_parameter("escura",escura);m.set_shader_parameter("solido",solido)
	return m


## Palavra em quadradinhos: cada letra no seu, alternando altura e cor.
class Quadradinhos extends Control:
	var palavra:="":
		set(v):
			palavra=v;medir();queue_redraw()
	var lado:=32.0
	var claro:=true
	func _init(valor:String="", tamanho:float=32.0) -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		lado=tamanho;palavra=valor
	func letras() -> String:
		return tr(palavra).to_upper()
	func medir() -> void:
		var total:=0.0
		for c in letras():total+=lado*.4 if c==" " else lado+2.0
		custom_minimum_size=Vector2(total,lado+8.0)
	func _notification(o:int) -> void:
		if o==NOTIFICATION_TRANSLATION_CHANGED:medir();queue_redraw()
	func _draw() -> void:
		var ci:=get_canvas_item()
		var fonte:=VintagePlex.fonte("titulo")
		var x:=0.0
		var i:=0
		for c in letras():
			if c==" ":x+=lado*.4;continue
			var y:=0.0 if i%2==0 else 6.0
			var invertida:=i%3==1
			ShowPlex.ret(ci,x+4.0,y+4.0,lado,lado,DinerPlex.SANGRIA)
			ShowPlex.ret(ci,x,y,lado,lado,DinerPlex.PRETO)
			ShowPlex.ret(ci,x+2.0,y+2.0,lado-4.0,lado-4.0,DinerPlex.VERMELHO if invertida else DinerPlex.CREME)
			draw_string(fonte,Vector2(x,y+lado*.76),c,HORIZONTAL_ALIGNMENT_CENTER,lado,int(lado*.72),DinerPlex.CREME if invertida else DinerPlex.PRETO)
			x+=lado+2.0;i+=1


## Letreiro da casa: placa vermelha com o nome e, por baixo, a seta com o
## nome da tela entre tracinhos.
class Letreiro extends Control:
	var nome:=Label.new()
	var tela:="PAUSA"
	var luzes:=LuzesShowPlex.new(true,22.0)
	func _init(valor:String="PAUSA") -> void:
		tela=valor
		mouse_filter=Control.MOUSE_FILTER_IGNORE;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		custom_minimum_size=Vector2(470,132);size=custom_minimum_size
		nome.hide();add_child(nome)
		add_child(luzes);luzes.position=Vector2(26,4);luzes.size=Vector2(330,10);luzes.cor=Color("ffd75e")
	func _notification(o:int) -> void:
		if o==NOTIFICATION_TRANSLATION_CHANGED:queue_redraw()
	func definir_nome(valor:String) -> void:
		if nome.text==valor:return
		nome.text=valor;queue_redraw()
	func _draw() -> void:
		var ci:=get_canvas_item()
		var titulo:=VintagePlex.fonte("titulo")
		# seta por baixo, saindo para a direita
		DinerPlex.seta(ci,Rect2(64,74,406,58),DinerPlex.PRETO)
		DinerPlex.seta(ci,Rect2(68,78,396,50),DinerPlex.SANGRIA)
		var rotulo:=tr(tela).to_upper()
		var largura:=titulo.get_string_size(rotulo,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x
		var meio:=DinerPlex.par(68.0+(396.0-30.0)*.5)
		for lado in [-1.0,1.0]:
			var x:float=meio+float(lado)*(largura*.5+14.0)
			for i in 3:ShowPlex.ret(ci,DinerPlex.par(x+lado*i*18.0-(12.0 if lado<0 else 0.0)),102.0,12.0,4.0,DinerPlex.AMARELO)
		draw_string(titulo,Vector2(meio-largura*.5,112),rotulo,HORIZONTAL_ALIGNMENT_LEFT,-1,24,DinerPlex.AMARELO)
		# placa do nome
		var placa:=Rect2(0,10,384,76)
		ShowPlex.bloco(ci,Rect2(placa.position+Vector2(6,6),placa.size),DinerPlex.PRETO,10)
		ShowPlex.bloco(ci,placa,DinerPlex.PRETO,10)
		ShowPlex.bloco(ci,placa.grow(-2),DinerPlex.AMARELO,8)
		ShowPlex.bloco(ci,placa.grow(-6),DinerPlex.VERMELHO,6)
		ShowPlex.ret(ci,placa.position.x+14,placa.position.y+8,placa.size.x-28,2,Color("d94a4a"))
		var texto_nome:=nome.text
		var tamanho:=46
		while tamanho>20 and titulo.get_string_size(texto_nome,HORIZONTAL_ALIGNMENT_LEFT,-1,tamanho).x>placa.size.x-36.0:tamanho-=2
		var base:=placa.position.y+placa.size.y*.5+tamanho*.34
		draw_string(titulo,Vector2(placa.position.x+4,base+4),texto_nome,HORIZONTAL_ALIGNMENT_CENTER,placa.size.x,tamanho,DinerPlex.SANGRIA)
		draw_string_outline(titulo,Vector2(placa.position.x,base),texto_nome,HORIZONTAL_ALIGNMENT_CENTER,placa.size.x,tamanho,6,DinerPlex.PRETO)
		draw_string(titulo,Vector2(placa.position.x,base),texto_nome,HORIZONTAL_ALIGNMENT_CENTER,placa.size.x,tamanho,DinerPlex.CREME)


## Cabeça do personagem como adesivo de dois tons: o retrato do jogo bem
## ampliado, em creme e vermelho, com contorno creme grosso.
class Silhueta extends Control:
	var escala:=12
	var figura:=TextureRect.new()
	var contornos:Array[TextureRect]=[]
	var borda:=10.0
	func _init() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		for d in [Vector2(-1,0),Vector2(1,0),Vector2(0,-1),Vector2(0,1),Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
			var c:=TextureRect.new();c.material=DinerPlex.estampa(DinerPlex.CREME,DinerPlex.CREME,true);c.set_meta("d",d);preparar(c);contornos.append(c)
		figura.material=DinerPlex.estampa();preparar(figura)
	func preparar(t:TextureRect) -> void:
		t.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;t.mouse_filter=Control.MOUSE_FILTER_IGNORE
		t.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;t.stretch_mode=TextureRect.STRETCH_SCALE
		add_child(t)
	## Mostra o retrato ocupando cerca de `altura` pixels de tela, em escala inteira.
	func mostrar(textura:Texture2D, altura:float=380.0) -> void:
		if textura==null:hide();return
		show()
		escala=clampi(int(altura/maxf(1.0,textura.get_height())),1,16)
		borda=clampf(float(escala),2.0,10.0)
		var dim:=Vector2(textura.get_width(),textura.get_height())*escala
		custom_minimum_size=dim;size=dim;pivot_offset=dim*.5
		figura.texture=textura;figura.size=dim;figura.position=Vector2.ZERO
		for c in contornos:
			c.texture=textura;c.size=dim;c.position=(c.get_meta("d") as Vector2)*borda

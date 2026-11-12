class_name NumeroPixelPlex
extends Control
## Número em dígitos de pixel, os mesmos do relógio do HUD. Usado quando o
## valor é a informação principal e precisa ser lido de relance.

const GLIFOS={"0":["11111","10001","10011","10101","11001","10001","11111"],"1":["00100","01100","00100","00100","00100","00100","01110"],"2":["11110","00001","00001","11110","10000","10000","11111"],"3":["11110","00001","00001","01110","00001","00001","11110"],"4":["10010","10010","10010","11111","00010","00010","00010"],"5":["11111","10000","10000","11110","00001","00001","11110"],"6":["01111","10000","10000","11110","10001","10001","01110"],"7":["11111","00001","00010","00100","01000","01000","01000"],"8":["01110","10001","10001","01110","10001","10001","01110"],"9":["01110","10001","10001","01111","00001","00001","11110"],":":["0","1","1","0","1","1","0"],".":["0","0","0","0","0","1","1"],",":["00","00","00","00","00","01","10"],"$":["00100","01111","10100","01110","00101","11110","00100"],"+":["000","000","010","111","010","000","000"],"-":["000","000","000","111","000","000","000"],"%":["11001","11010","00100","00100","00100","01011","10011"],"/":["001","001","010","010","010","100","100"],"h":["1000","1000","1000","1110","1001","1001","1001"]," ":["00"],"'":["0"]}
var texto:="":
	set(v):
		if v==texto:return
		texto=v;medir();queue_redraw()
var escala:=3
var cor:=Color("dfb16a")
var apagado:=Color.TRANSPARENT
var alinhamento:=HORIZONTAL_ALIGNMENT_RIGHT

func _init(valor:String="", tamanho:int=3, tinta:Color=Color("dfb16a")) -> void:
	escala=tamanho;cor=tinta;mouse_filter=Control.MOUSE_FILTER_IGNORE;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	texto=valor;medir()

func largura() -> int:
	var total:=0
	for s in texto:total+=(str(GLIFOS.get(s,GLIFOS[" "])[0]).length()+1)*escala
	return maxi(0,total-escala)

func medir() -> void:
	custom_minimum_size=Vector2(largura(),7*escala)

func _draw() -> void:
	var x:=0.0 if alinhamento==HORIZONTAL_ALIGNMENT_LEFT else roundf((size.x-largura())*.5) if alinhamento==HORIZONTAL_ALIGNMENT_CENTER else size.x-largura()
	var y:=roundf((size.y-7*escala)*.5)
	for s in texto:
		var linhas:Array=GLIFOS.get(s,GLIFOS[" "])
		var colunas:=str(linhas[0]).length()
		for j in linhas.size():
			for i in colunas:
				if str(linhas[j])[i]=="1":draw_rect(Rect2(x+i*escala,y+j*escala,escala,escala),cor)
				elif apagado.a>0 and s in "0123456789":draw_rect(Rect2(x+i*escala,y+j*escala,escala,escala),apagado)
		x+=(colunas+1)*escala

## Formata dinheiro com um respiro entre os milhares: 1'234'567.89.
static func dinheiro(valor:float) -> String:
	var inteiro:=str(int(floorf(absf(valor))))
	var agrupado:=""
	for i in inteiro.length():
		if i>0 and (inteiro.length()-i)%3==0:agrupado+="'"
		agrupado+=inteiro[i]
	return ("-" if valor<0 else "")+"$ "+agrupado+"."+("%02d"%(roundi(absf(valor)*100.0)%100))

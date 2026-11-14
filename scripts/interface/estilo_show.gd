class_name EstiloShowPlex
extends StyleBox
## StyleBox desenhado por código com as peças do ShowPlex. Como a pintura é
## feita no tamanho real do controle, molduras e veios nunca esticam.

var tipo:="painel"
var cor:=Color("8a5a38")
var folha:=Color("f6e3b8")
var tampas:=false
var tabua:=0
var labio:=0
var afundado:=false
var volutas:=false
var semente:=0

func _draw(ci:RID, r:Rect2) -> void:
	var face:=r
	if labio>0:
		# base saliente: a face encosta nela quando o botão é apertado
		ShowPlex.bloco(ci,Rect2(r.position.x,r.position.y+labio,r.size.x,r.size.y-labio),ShowPlex.TINTA,ShowPlex.U)
		ShowPlex.ret(ci,r.position.x+ShowPlex.U,r.end.y-labio-ShowPlex.U,r.size.x-ShowPlex.U*2,labio,cor.darkened(.5))
		face=Rect2(r.position.x,r.position.y+(labio if afundado else 0),r.size.x,r.size.y-labio)
	match tipo:
		"placa":
			ShowPlex.placa(ci,face,cor,folha,semente)
			if volutas and face.size.x>120 and face.size.y>70:
				var d:=face.grow(-ShowPlex.U*7)
				ShowPlex.voluta(ci,d.position,ShowPlex.NANQUIM)
				ShowPlex.voluta(ci,Vector2(d.end.x-22,d.position.y),ShowPlex.NANQUIM,true)
				ShowPlex.voluta(ci,Vector2(d.position.x,d.end.y-14),ShowPlex.NANQUIM,false,true)
				ShowPlex.voluta(ci,Vector2(d.end.x-22,d.end.y-14),ShowPlex.NANQUIM,true,true)
		"folha":
			ShowPlex.bloco(ci,face,ShowPlex.NANQUIM,ShowPlex.U)
			ShowPlex.bloco(ci,face.grow(-ShowPlex.U),folha,ShowPlex.U)
			ShowPlex.ret(ci,face.position.x+ShowPlex.U*2,face.end.y-ShowPlex.U*2,face.size.x-ShowPlex.U*4,ShowPlex.U,folha.darkened(.1))
		"tabuas":ShowPlex.painel(ci,face,cor,false,tabua if tabua>0 else 28,semente)
		"fita":
			# faixa de título: fita escura com pontas em degrau
			ShowPlex.bloco(ci,face,cor,ShowPlex.U*3)
			ShowPlex.ret(ci,face.position.x+ShowPlex.U*4,face.position.y+ShowPlex.U,face.size.x-ShowPlex.U*8,ShowPlex.U,cor.lightened(.14))
		_:ShowPlex.painel(ci,face,cor,tampas,tabua,semente)

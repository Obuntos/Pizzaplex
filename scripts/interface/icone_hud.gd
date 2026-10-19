class_name IconeHudPlex
extends Control

var tipo := "sol"

func _init(valor: String = "sol") -> void:
	tipo = valor
	custom_minimum_size = Vector2(48,48)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func ret(x: float, y: float, w: float, h: float, cor: Color) -> void:
	draw_rect(Rect2(Vector2(x,y)*2,Vector2(w,h)*2),cor)

func _draw() -> void:
	var amarelo := Color("edc669")
	var claro := Color("e4e2cc")
	var azul := Color("7eb5bd")
	match tipo:
		"sol","Ensolarado","Calor","entardecer":
			var borda:=Color("d69d45")
			ret(7,4,10,16,borda)
			ret(4,7,16,10,borda)
			ret(6,6,12,12,amarelo)
			ret(8,5,8,14,amarelo)
			for p in [Vector2(11,0),Vector2(11,22),Vector2(0,11),Vector2(22,11),Vector2(3,3),Vector2(19,3),Vector2(3,19),Vector2(19,19)]: ret(p.x,p.y,2,2,amarelo)
			var rosto:=Color("785035")
			ret(8,9,2,2,rosto)
			ret(14,9,2,2,rosto)
			ret(6,12,3,2,Color("e9a37b"))
			ret(15,12,3,2,Color("e9a37b"))
			ret(9,14,1,1,rosto)
			ret(10,15,4,1,rosto)
			ret(14,14,1,1,rosto)
			ret(7,12,1,1,Color("f7c19a"))
			ret(16,12,1,1,Color("f7c19a"))
			if tipo=="entardecer": ret(2,20,20,2,Color("bd8055"))
			if tipo=="Calor": ret(20,15,2,7,Color("cf7656"))
		"noite":
			ret(7,4,9,15,claro)
			ret(5,7,12,9,claro)
			ret(12,3,8,11,TemaHudPlex.FUNDO)
			ret(19,4,2,2,amarelo)
			ret(3,20,1,1,claro)
		"Chuva","Nublado","Neve":
			ret(5,8,14,7,claro)
			ret(8,5,8,9,claro)
			if tipo != "Nublado":
				for x in [6,11,16]:
					ret(x,17,1,4,azul)
					if tipo=="Neve": ret(x-1,18,3,1,claro)
		"calendario":
			ret(3,4,18,17,claro)
			ret(3,4,18,5,Color("739bb0"))
			for x in [7,15]: ret(x,2,2,5,amarelo)
			for x in [6,11,16]:
				for y in [12,17]: ret(x,y,2,2,Color("405a68"))
		"construir","demolir":
			ret(4,5,16,5,amarelo)
			ret(12,9,4,12,Color("bfa585"))
			ret(3,7,4,5,amarelo)
		"paredes":
			ret(3,4,17,6,claro)
			ret(3,10,6,11,claro)
			ret(11,13,9,4,Color("88ac88"))
			ret(11,19,9,2,Color("88ac88"))
		"conforto":
			for y in range(3):
				for x in range(3): ret(3+x*6,3+y*6,5,5,[Color("cf7566"),Color("d5b95c"),Color("75b390")][x])

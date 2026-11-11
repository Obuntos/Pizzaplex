class_name IconeHudPlex
extends Control

var tipo := "sol"
var minutos:=610.0
var bloqueado:=false
var escala_pixel:=2.0

func _init(valor: String = "sol") -> void:
	tipo = valor
	custom_minimum_size = Vector2(48,48)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func ret(x: float, y: float, w: float, h: float, cor: Color) -> void:
	draw_rect(Rect2(Vector2(x,y)*escala_pixel,Vector2(w,h)*escala_pixel),cor)

func _draw() -> void:
	if refinado():
		desenhar_bloqueio();return
	var amarelo := Color("f0a05c") if tipo=="entardecer" else Color("edc669")
	var claro := Color("e4e2cc")
	var azul := Color("7eb5bd")
	match tipo:
		"debug":
			var topo:=PackedVector2Array([Vector2(12,2),Vector2(22,7),Vector2(12,12),Vector2(2,7)])
			var frente:=PackedVector2Array([Vector2(2,7),Vector2(12,12),Vector2(12,23),Vector2(2,18)])
			var lado:=PackedVector2Array([Vector2(12,12),Vector2(22,7),Vector2(22,18),Vector2(12,23)])
			for i in topo.size():
				topo[i]*=escala_pixel;frente[i]*=escala_pixel;lado[i]*=escala_pixel
			draw_colored_polygon(topo,Color("e6c480"));draw_colored_polygon(frente,Color("b38549"));draw_colored_polygon(lado,Color("805a37"))
			for poligono in [topo,frente,lado]:draw_polyline(poligono+PackedVector2Array([poligono[0]]),Color("f1dfb9"),escala_pixel)
		"cadeado":
			ret(7,2,10,3,claro);ret(5,5,3,7,claro);ret(16,5,3,7,claro);ret(3,11,18,12,amarelo);ret(10,15,4,3,Color("493b28"));ret(11,18,2,3,Color("493b28"))
		"sol","Ensolarado","Calor","entardecer":
			var borda:=Color("b76e42") if tipo=="entardecer" else Color("d69d45")
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
			if tipo=="entardecer":
				ret(0,16,24,8,TemaHudPlex.FUNDO)
				ret(2,16,20,1,Color("b97b5b"))
				ret(5,18,14,1,Color("805b52"))
				ret(9,20,6,1,Color("5a4950"))
			if tipo=="Calor": ret(20,15,2,7,Color("cf7656"))
		"noite":
			for y in range(2,22):
				for x in range(2,21):
					var fora := Vector2((x-10.5)/8.3,(y-11.5)/9.3).length_squared()
					var dentro := Vector2((x-14.2)/7.2,(y-11.5)/8.4).length_squared()
					if fora<=1.0 and dentro>1.0: ret(x,y,1,1,Color("a6aed3") if fora>.78 else Color("e2e4f5"))
			ret(5,10,1,2,Color("687292"))
			ret(5,14,1,1,Color("687292"))
			ret(6,15,1,1,Color("687292"))
			ret(7,14,1,1,Color("687292"))
			ret(3,13,2,1,Color("c7b7cf"))
			for p in [Vector2(20,4),Vector2(3,2),Vector2(20,20)]:
				ret(p.x,p.y,1,3,amarelo)
				ret(p.x-1,p.y+1,3,1,amarelo)
		"Chuva","Nublado","Neve":
			ret(5,8,14,7,claro)
			ret(8,5,8,9,claro)
			if tipo != "Nublado":
				for x in [6,11,16]:
					ret(x,17,1,4,azul)
					if tipo=="Neve": ret(x-1,18,3,1,claro)
		"relogio":
			for y in range(3,22):
				for x in range(3,22):
					var r:=Vector2(x-12,y-12).length_squared()
					if r<=90: ret(x,y,1,1,Color("ba9661") if r>65 else Color("f0e0ad"))
			var angulos:=DecoracaoEstudoPlex.angulos(minutos)
			for mao in [[angulos.x,4.5],[angulos.y,6.5]]:
				for i in range(ceili(float(mao[1])*3)):
					ret(roundf(12+sin(float(mao[0]))*i/3.0),roundf(12-cos(float(mao[0]))*i/3.0),1,1,Color("42545a"))
		"interagir":
			ret(2,4,20,14,Color("af9568"));ret(3,5,18,11,Color("efe0b0"));ret(5,16,3,4,Color("efe0b0"));ret(6,8,12,1,Color("896f50"));ret(6,12,8,1,Color("896f50"))
		"fichario":
			ret(3,5,18,17,Color("12243f"));ret(4,4,17,16,Color("46728e"));ret(5,6,14,12,Color("b9cdd3"));ret(6,3,7,3,Color("d9bc7a"));ret(7,8,10,1,Color("60869c"));ret(7,11,6,1,Color("60869c"));ret(7,14,9,1,Color("60869c"))
			for y in [8,13,18]: ret(2,y,4,2,Color("e3dfc8"))
		"livro":
			ret(2,4,21,18,Color("4f342a"));ret(3,3,19,17,Color("a36b46"));ret(5,5,7,13,Color("ead5a4"));ret(13,5,7,13,Color("f4e0b1"));ret(11,4,2,16,Color("765540"));ret(20,6,3,3,Color("bd755f"))
			for y in [8,12,16]: ret(6,y,4,1,Color("b4976d"));ret(15,y,4,1,Color("b4976d"))
		"ar":
			var tinta:=Color("b1d3be")
			for y in [6,11,16]:
				ret(3,y,13 if y==11 else 16,2,tinta);ret(18 if y!=11 else 15,y-3,3,4,tinta);ret(17 if y!=11 else 14,y-4,3,1,tinta)
			ret(3,21,3,1,tinta);ret(9,21,3,1,tinta)
		"ibm":
			ret(3,2,18,14,Color("122128"));ret(4,3,16,12,Color("b3b7a0"))
			ret(6,5,12,8,Color("254c42"));ret(7,6,5,1,Color("99c98c"));ret(7,9,8,1,Color("6eaa7a"))
			ret(9,16,6,2,Color("7f8b7d"));ret(3,18,18,5,Color("a9aa90"))
			for x in range(5,19,3): ret(x,19,2,1,Color("4e6661"))
		"calendario":
			ret(3,4,18,17,claro)
			ret(3,4,18,5,Color("739bb0"))
			for x in [7,15]: ret(x,2,2,5,amarelo)
			for x in [6,11,16]:
				for y in [12,17]: ret(x,y,2,2,Color("405a68"))
		"construir","demolir":
			var contorno:=Color("26383c")
			ret(9,9,5,13,contorno)
			ret(10,10,3,11,Color("96643e"))
			ret(10,10,1,10,Color("d4ac6a"))
			ret(3,3,18,7,contorno)
			ret(4,4,16,5,Color("849b9c"))
			ret(4,4,16,1,Color("d0dacb"))
			ret(4,8,16,1,Color("526b73"))
			ret(3,5,3,3,Color("b0c2b9"))
			ret(18,5,3,3,Color("b0c2b9"))
		"paredes":
			ret(3,4,17,6,claro)
			ret(3,10,6,11,claro)
			ret(11,13,9,4,Color("88ac88"))
			ret(11,19,9,2,Color("88ac88"))
		"conforto":
			for y in range(3):
				for x in range(3): ret(3+x*6,3+y*6,5,5,[Color("cf7566"),Color("d5b95c"),Color("75b390")][x])


		"energia":
			ret(2,7,20,14,Color("111d24"))
			ret(3,8,18,11,Color("a46f40"))
			ret(4,9,16,2,Color("e1b76e"))
			ret(5,3,12,3,Color("b8bfa7"))
			ret(6,2,10,2,Color("dae0c7"))
			ret(18,4,2,4,Color("6d7c7d"))
			for x in [5,8,11]: ret(x,13,1,4,Color("4c3c32"))
			ret(15,12,4,5,Color("263e46"))
			ret(16,12,2,2,Color("98c79a"))
			ret(4,21,3,1,Color("536469"));ret(17,21,3,1,Color("536469"))
		"dinheiro":
			ret(2,7,20,11,Color("1c332c"))
			ret(3,6,18,10,Color("85a66a"))
			ret(4,7,16,7,Color("c9d29a"))
			ret(6,8,12,5,Color("84a66d"))
			ret(10,8,4,5,Color("e9d29a"))
			ret(11,9,2,3,Color("687e58"))
			ret(3,16,18,2,Color("526b4e"))
		"pizza":
			ret(6,2,12,3,Color("b27843"));ret(4,5,16,3,Color("ddaa63"))
			ret(6,8,12,4,Color("efd18a"));ret(8,12,8,4,Color("efd18a"));ret(10,16,4,4,Color("efd18a"))
			for p in [Vector2(8,8),Vector2(14,9),Vector2(11,14)]: ret(p.x,p.y,2,2,Color("c5644b"))

	desenhar_bloqueio()

func desenhar_bloqueio() -> void:
	if tipo in ["ibm","livro","fichario"] and bloqueado:
		ret(0,0,24,24,Color(.36,.39,.40,.88))
		ret(8,4,8,7,Color("f4f1e6"));ret(10,6,4,5,Color("686d6e"))
		ret(6,10,12,9,Color("f4f1e6"));ret(7,11,10,1,Color("ffffff"))
		ret(11,13,2,3,Color("686d6e"))

func linha_pixel(a:Vector2,b:Vector2,cor:Color,l:int=1) -> void:
	var total:=maxi(1,ceili(a.distance_to(b)*2))
	for i in total+1:
		var p:=a.lerp(b,float(i)/total).round();ret(p.x,p.y,l,l,cor)
func painel_pixel(x:int,y:int,w:int,h:int,base:Color) -> void:
	ret(x+1,y,w-2,h,Color("493d32"));ret(x,y+1,w,h-2,Color("493d32"));ret(x+1,y+1,w-2,h-2,base)
	ret(x+2,y+1,w-4,1,base.lightened(.28));ret(x+w-2,y+2,1,h-3,base.darkened(.26));ret(x+2,y+h-2,w-4,1,base.darkened(.3))
func refinado() -> bool:
	var claro:=Color("f0dfb5");var metal:=Color("99afb0");var sombra:=Color("4b4035");var madeira:=Color("a8794c");var verde:=Color("88ad8b");var ouro:=Color("d9b46f");var vermelho:=Color("bd7867")
	match tipo:
		"aba_fechada":
			for i in 5:ret(9+i,7+i,1,10-i*2,Color("e1c48b"))
		"aba_aberta":
			for i in 5:ret(7+i,9+i,10-i*2,1,Color("e1c48b"))
		"construir","demolir":
			var desenho:=["........................","........................","........OOOOOOOO........","......OOMMMMMMMMO.......",".....OMHHHHHHHHHMO......","....OMHHMMMMMMMMMO......","....OMHHMOOOOOMMMMO.....",".....OMMMO...OMM.MO.....","......OOO...OMM..MO.....",".........OOOMM...O......","........ODDOOO..........",".......ODLDO............","......ODLDO.............",".....ODLDO..............","....ODLDO...............","...ODLDO................","..ODLDO.................","..ODDO..................","...OO...................","........................","........................","........................","........................","........................"]
			var cores:={"O":Color("393b35"),"M":Color("9aafaa"),"H":Color("e3e4cc"),"D":Color("ad794b") if tipo=="construir" else Color("b77b64"),"L":Color("deb97e")}
			for y in desenho.size():
				for x in desenho[y].length():
					var letra:String=desenho[y][x]
					if cores.has(letra):ret(x,y,1,1,cores[letra])
		"compras","deposito":
			painel_pixel(3,7,18,14,madeira);ret(4,8,16,3,Color("c9a06b"));ret(4,18,16,2,Color("805a3d"));ret(10,8,4,12,Color("e2c68d"));ret(11,9,1,10,claro)
			ret(5,12,3,1,Color("8d653f"));ret(16,13,3,1,Color("8d653f"));ret(16,16,3,1,Color("8d653f"))
			if tipo=="compras":
				painel_pixel(14,1,8,7,verde);ret(17,3,2,3,claro);ret(19,2,1,1,claro);ret(20,1,1,1,claro)
			else:ret(5,3,14,2,ouro);ret(7,2,10,1,claro)
		"ibm":
			painel_pixel(3,2,18,14,Color("c0b898"));painel_pixel(6,5,12,8,Color("3e6453"));ret(7,6,5,1,Color("c3d5a1"));ret(7,9,8,1,verde)
			ret(9,16,6,2,Color("837e65"));painel_pixel(2,18,20,5,Color("b6ad8d"))
			for x in range(4,19,3):ret(x,19,2,1,Color("5c6658"))
			ret(16,14,2,1,ouro);ret(5,3,13,1,claro)
		"piso":
			for y in range(4,20):
				for x in range(1,23):
					var d:=absf(float(x)-11.5)/10.5+absf(float(y)-11.0)/6.0
					if d<=1.0:
						var u:=floori((x-11.5+(y-11.0)*1.75)/7.0);var v:=floori((x-11.5-(y-11.0)*1.75)/7.0)
						ret(x,y,1,1,claro if posmod(u+v,2)==0 else Color("788f80"))
					elif y>11 and absf(float(x)-11.5)/10.5+absf(float(y)-14.0)/6.0<=1.0:ret(x,y,1,1,Color("6b6c58"))
			linha_pixel(Vector2(1,11),Vector2(11,5),Color("d5c49e"));linha_pixel(Vector2(12,5),Vector2(22,11),Color("d5c49e"));linha_pixel(Vector2(1,14),Vector2(11,20),Color("443d33"));linha_pixel(Vector2(12,20),Vector2(22,14),Color("443d33"))
		"paredes":
			painel_pixel(2,4,20,17,Color("c3a781"))
			for y in [9,15]:ret(3,y,18,1,Color("8c7357"))
			ret(9,5,1,4,Color("8c7357"));ret(16,5,1,4,Color("8c7357"));ret(5,10,1,5,Color("8c7357"));ret(13,10,1,5,Color("8c7357"));ret(9,16,1,4,Color("8c7357"));ret(17,16,1,4,Color("8c7357"))
		"porta":
			painel_pixel(5,1,14,22,madeira);painel_pixel(7,4,10,17,Color("7e6248"));ret(8,5,7,1,Color("b4966b"));ret(9,8,5,4,Color("a38661"));ret(9,14,5,5,Color("8f7355"));ret(14,12,2,2,ouro);ret(3,22,18,1,claro)
		"moveis":
			painel_pixel(2,9,20,10,Color("8b7191"));painel_pixel(5,3,14,10,Color("a28da3"));ret(6,4,11,1,Color("d0b6c5"));ret(3,10,3,7,Color("b8a0b3"));ret(18,10,3,7,Color("947e99"));ret(6,13,12,3,Color("baa1b4"));ret(5,19,2,3,madeira);ret(17,19,2,3,madeira)
		"cozinha":
			painel_pixel(3,3,18,19,Color("b9bdac"));ret(4,4,16,3,Color("dfdcc4"));ret(5,5,3,1,sombra);ret(16,5,3,1,sombra);painel_pixel(6,10,12,9,Color("526966"));ret(7,11,10,1,metal);ret(9,15,6,2,Color("c08a51"));ret(9,14,6,1,ouro);ret(5,8,2,1,vermelho);ret(17,8,2,1,verde)
		"banheiro":
			painel_pixel(3,2,18,11,Color("c0d2c7"));ret(5,4,10,1,Color("e8eed7"));ret(5,6,2,4,Color("e3e7d3"));ret(4,14,16,4,claro);ret(6,18,12,2,Color("b6c4b6"));ret(10,20,4,3,metal);ret(10,12,5,2,metal);ret(10,10,2,3,metal)
		"palco":
			painel_pixel(2,3,20,18,Color("6c4e4e"));ret(3,4,5,12,vermelho);ret(17,4,4,12,Color("9e625c"));ret(3,4,18,3,Color("cf9880"));ret(5,7,2,6,Color("d69b83"));ret(18,7,1,6,Color("c18471"));ret(7,16,10,2,madeira);ret(4,18,16,3,Color("b48c56"));ret(3,21,18,1,ouro);ret(11,9,2,5,claro);ret(10,12,4,1,claro)
		"luzes":
			ret(11,1,2,4,sombra);ret(7,5,10,2,ouro);ret(5,7,14,2,Color("dfc289"));ret(3,9,18,3,claro);ret(5,12,14,1,Color("aa8c55"));ret(10,13,4,3,Color("e6d197"))
			for p in [Vector2(4,17),Vector2(11,19),Vector2(19,17)]:ret(p.x,p.y,1,3,ouro)
		"decoracao":
			painel_pixel(5,15,14,7,Color("ba7c58"));ret(7,16,10,1,Color("d5a477"));ret(11,6,2,10,Color("72946a"));ret(5,7,7,4,verde);ret(4,6,5,3,Color("a8bf86"));ret(13,9,7,4,Color("6e9974"));ret(16,8,5,3,verde);ret(10,2,4,6,Color("a6bb7f"));ret(11,2,2,4,Color("c6cd9b"))
		"limpeza":
			linha_pixel(Vector2(16,2),Vector2(7,15),sombra,3);linha_pixel(Vector2(17,2),Vector2(8,15),madeira,1);painel_pixel(3,14,12,8,ouro);ret(2,18,14,4,Color("c2a365"));ret(4,15,9,2,claro)
			for x in [4,7,10,13]:ret(x,18,1,4,Color("8d764d"))
		"fichario","livro":
			if tipo=="livro":
				painel_pixel(2,4,20,18,Color("9c7150"));ret(4,5,7,14,Color("d7c294"));ret(13,5,7,14,claro);ret(11,5,2,15,Color("82603e"))
				for y in [8,12,16]:ret(5,y,4,1,Color("b09c75"));ret(14,y,5,1,Color("baa780"))
			else:
				painel_pixel(4,3,17,19,Color("75958b"));ret(7,5,11,14,claro);ret(3,5,3,14,Color("c2ae7f"));ret(8,2,9,4,ouro);ret(10,2,5,1,claro)
				for y in [8,12,16]:ret(9,y,7 if y==8 else 5,1,Color("96a18a"))
		"pratos":
			for y in range(5,21):
				for x in range(2,23):
					var d:=Vector2((x-12.0)/10.0,(y-13.0)/7.0).length_squared()
					if d<1:ret(x,y,1,1,Color("8a9e97") if d>.82 else claro if d>.48 else Color("d5cba9"))
			ret(5,20,14,1,Color("81978e"));ret(7,22,10,1,metal)
		"engrenagem":
			for y in 24:
				for x in 24:
					var d:=Vector2(x-11.5,y-11.5)
					var r:=d.length()
					var dente:=posmod(roundi((atan2(d.y,d.x)+PI)/(TAU/8.0)*2.0),2)==0
					if r<=3.0:continue
					if r<=7.5 or r<=10.5 and dente:ret(x,y,1,1,sombra if r>9.5 or r<4.0 else metal if d.x+d.y>0 else claro)
		"conforto":
			painel_pixel(3,5,18,14,verde);ret(5,7,5,5,Color("c7d09c"));ret(14,7,5,5,Color("c7d09c"));ret(8,14,8,2,claro);ret(5,19,2,3,madeira);ret(17,19,2,3,madeira)
		_:return false
	return true

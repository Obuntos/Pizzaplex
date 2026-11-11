class_name SuperficieModelosPlex
extends Control

var tipo:="madeira"
var adquiridos: Dictionary={}
func _init(modelo:String="madeira") -> void:
	tipo=modelo;mouse_filter=Control.MOUSE_FILTER_IGNORE
func _ready() -> void:resized.connect(queue_redraw)
func _draw() -> void:
	match tipo:
		"madeira":
			draw_texture_rect(preload("res://assets/interface/modelos/madeira.png"),Rect2(Vector2.ZERO,size),false)
		"carcaca":
			draw_rect(Rect2(8,12,size.x,size.y),Color(0,0,0,.53))
			draw_rect(Rect2(-4,-4,size.x+8,size.y+8),Color("1d0e08"))
			for y in ceili(size.y):
				var t:=float(y)/maxf(1,size.y)
				var cor:=Color("cfc5a8").lerp(Color.WHITE,maxf(0,1.0-t/.12)*.25)
				cor=cor.lerp(Color.BLACK,maxf(0,(t-.8)/.2)*.19)
				draw_rect(Rect2(0,y,size.x,1),cor)
			draw_rect(Rect2(0,0,size.x,4),Color("e9e1c8"));draw_rect(Rect2(0,0,4,size.y),Color("e9e1c8"))
			draw_rect(Rect2(0,size.y-4,size.x,4),Color("9d9477"));draw_rect(Rect2(size.x-4,0,4,size.y),Color("9d9477"))
		"papel":
			draw_rect(Rect2(10,12,size.x,size.y),Color(0,0,0,.47))
			draw_rect(Rect2(-4,-4,size.x+8,size.y+8),Color("1d0e08"))
			draw_texture_rect(preload("res://assets/interface/modelos/papel.png"),Rect2(Vector2.ZERO,size),false)
		"espiral":
			for x in range(0,int(size.x),40):
				draw_circle(Vector2(x+20,28),6,Color("120a06"))
				draw_rect(Rect2(x+15,0,2,30),Color("d8d8de"));draw_rect(Rect2(x+17,0,6,30),Color("8a8a92"));draw_rect(Rect2(x+23,0,1,30),Color("55555c"))
		"bilhete":
			draw_rect(Rect2(5,5,size.x,size.y),Color(0,0,0,.4))
			for y in ceili(size.y):draw_rect(Rect2(0,y,size.x,1),Color("f6dd6c").lerp(Color("f8e48a"),maxf(0,1-float(y)/maxf(1,size.y*.3))*.3))
		"ventilacao":
			for x in range(0,int(size.x),10):draw_rect(Rect2(x,0,4,size.y),Color("6f6850"))
		"planta":
			var g:=TemaIBMPlex.VERDE;var dim:=TemaIBMPlex.SUAVE
			for x in range(11,int(size.x),12):draw_line(Vector2(x,0),Vector2(x,size.y),Color(g,.09),1)
			for y in range(11,int(size.y),12):draw_line(Vector2(0,y),Vector2(size.x,y),Color(g,.09),1)
			for y in [18,size.y-52]:
				draw_rect(Rect2(0,y,size.x,34),Color(g,.05));draw_line(Vector2(0,y),Vector2(size.x,y),dim,2);draw_line(Vector2(0,y+34),Vector2(size.x,y+34),dim,2)
				for x in range(0,int(size.x),28):draw_rect(Rect2(x,y+16,14,2),dim)
			for i in 3:
				var rect:=Rect2(34+i*140,106,120,120)
				var own:bool=i==1 or adquiridos.get("padaria" if i==0 else "farmacia",false)
				draw_rect(rect,Color(g,.23 if own else .05))
				if not own:
					for d in range(0,240,10):
						var a:=Vector2(maxi(0,d-120),mini(120,d));var b:=Vector2(mini(120,d),maxi(0,d-120));draw_line(rect.position+a,rect.position+b,Color(g,.15),2)
				if own:draw_rect(rect,g,false,3)
				else:
					for d in range(0,120,10):
						for yy in [0,118]:draw_rect(Rect2(rect.position+Vector2(d,yy),Vector2(6,2)),dim)
						for xx in [0,118]:draw_rect(Rect2(rect.position+Vector2(xx,d),Vector2(2,6)),dim)
			for i in 2:
				var topo:=Rect2(174+i*140,56,120,40)
				var comprado:bool=adquiridos.get("floricultura" if i==0 else "posto",false)
				draw_rect(topo,Color(g,.23 if comprado else .05))
				if comprado:draw_rect(topo,g,false,3)
			draw_rect(Rect2(Vector2.ZERO,size),g,false,2)

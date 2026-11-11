class_name PartidaManualPlex
extends Control

signal concluido
var rpm:=0.0
var estabilidade:=0.0
var acelerando:=false
var funcionando:=false
var venceu:=false
var puxadas:=0
var relogio:=0.0
var ultima_puxada:=-10.0
var idade:=0.0
var calor:=0.0
var evento:=3.0
var falha:=0.0
var contador_eventos:=0
var corda:=0.0
var tentativas:=0

func _init() -> void:
	custom_minimum_size=Vector2(384,354)
	focus_mode=Control.FOCUS_ALL
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST

func reiniciar() -> void:
	rpm=0;estabilidade=0;acelerando=false;funcionando=false;venceu=false;puxadas=0;relogio=0;ultima_puxada=-10;calor=0;evento=3;contador_eventos=0;corda=0;falha=0;idade=0
	grab_focus.call_deferred();queue_redraw()

func puxar() -> void:
	if funcionando or venceu: return
	if relogio-ultima_puxada>1.4: puxadas=0
	puxadas+=1;ultima_puxada=relogio;corda=1.0
	if puxadas>=3:
		funcionando=true;rpm=28;idade=0;calor=0;evento=3;puxadas=0;tentativas+=1
	queue_redraw()

func parar() -> void:
	funcionando=false;rpm=0;estabilidade=0;calor=0;acelerando=false

func cancelar() -> void:
	parar();venceu=false;puxadas=0

func avancar(delta: float) -> void:
	var dt:=clampf(delta,0,.05)
	relogio+=dt;corda=maxf(0,corda-dt*4)
	if funcionando and not venceu:
		idade+=dt;evento-=dt
		var variacao:=32.0 if acelerando else -17.0
		if evento<=0:
			evento=3.1;contador_eventos+=1;falha=.6
		if falha>0:
			variacao+=-16.0 if contador_eventos%2==1 else 18.0
			falha-=dt
		rpm=clampf(rpm+variacao*dt,0,100)
		calor=calor+dt if rpm>88 else maxf(0,calor-dt*.7)
		if calor>2.2 or (idade>1.2 and rpm<=1.5): parar();return
		estabilidade=minf(100,estabilidade+15*dt) if rpm>=42 and rpm<=62 else maxf(0,estabilidade-9*dt)
		if estabilidade>=100:
			venceu=true;acelerando=false;rpm=52;concluido.emit()
	queue_redraw()

func _process(delta: float) -> void:
	if is_visible_in_tree(): avancar(delta)
	else: acelerando=false

func _gui_input(e: InputEvent) -> void:
	if e is InputEventKey and e.keycode in [KEY_SPACE,KEY_UP]:
		acelerando=e.pressed;accept_event()
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_C,KEY_ENTER,KEY_DOWN]:
		puxar();accept_event()
	elif e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT:
		grab_focus()
		var local: Vector2=(e.position-Vector2((size.x-384)*.5,0))/3.0
		if e.pressed and local.x>88 and local.y>88: puxar()
		else: acelerando=e.pressed
		accept_event()

func ret(x: float,y: float,w: float,h: float,cor: String) -> void:
	draw_rect(Rect2(x,y,w,h),Color(cor))

func disco(x: int,y: int,r: int,cor: String) -> void:
	for yy in range(-r,r+1):
		var largura:=floori(sqrt(float(r*r-yy*yy)))
		ret(x-largura,y+yy,largura*2+1,1,cor)

func _draw() -> void:
	draw_set_transform(Vector2(roundf((size.x-384)*.5),0),0,Vector2(3,3))
	ret(1,1,126,116,"101d23");ret(3,3,122,112,"3d5247");ret(5,5,118,108,"53604b")
	ret(7,7,114,12,"33483e");ret(9,9,110,1,"7f8870")
	for xy in [Vector2(7,7),Vector2(118,7),Vector2(7,106),Vector2(118,106)]:
		ret(xy.x,xy.y,3,3,"243a39");ret(xy.x,xy.y,1,1,"b6bd9a")
	for xy in [Vector2(15,35),Vector2(110,58),Vector2(18,92),Vector2(113,28)]:
		ret(xy.x,xy.y,4,2,"88604a");ret(xy.x+1,xy.y+2,2,2,"a17b52")
	disco(64,52,30,"1b2c31");disco(64,52,28,"ab8b53");disco(64,52,26,"e8d8a4")
	for v in range(0,101,2):
		var angulo:=deg_to_rad(135+v*2.7)
		var color: String="73915c" if v>=42 and v<=62 else "b18549" if v<82 else "b75c46"
		for r in range(20,24): ret(roundf(64+cos(angulo)*r),roundf(52+sin(angulo)*r),1,1,color)
	for v in range(0,101,10):
		var angulo:=deg_to_rad(135+v*2.7)
		for r in range(16,20): ret(roundf(64+cos(angulo)*r),roundf(52+sin(angulo)*r),1,1,"68614b")
	var angulo_ponteiro:=deg_to_rad(135+rpm*2.7)
	for r in range(-4,22): ret(roundf(64+cos(angulo_ponteiro)*r),roundf(52+sin(angulo_ponteiro)*r),1,1,"b55e47" if r>13 else "293b3d")
	disco(64,52,3,"96774d");ret(63,51,2,1,"efd6a0")
	ret(22,85,84,12,"223639")
	for i in 7:
		var acesa:=float(i+1)<=estabilidade/100.0*7.0
		var color: String=("a6c883" if i>2 else "d4ad60") if acesa else "526259"
		ret(26+i*11,88,6,5,color);ret(27+i*11,88,2,1,"dce6bc" if acesa else "788472")
	ret(15,59,8,22,"1f3437");ret(18,62,2,16,"8d9a81")
	ret(14,60 if acelerando else 74,10,5,"b45e48")
	disco(100,101,9,"24383a");disco(100,101,7,"82907b");disco(100,101,5,"465d54")
	ret(99,105,2,7+floori(corda*4),"e3c789");ret(94,109+floori(corda*4),12,4,"9a714b")
	ret(31,102,47,5,"233a3b")
	for i in 3: ret(35+i*13,103,8,2,"adc384" if venceu else "7d8972")
	for x in range(6,122): ret(x,113,1,3,"cfad5b" if posmod(x,8)<4 else "2c3b38")

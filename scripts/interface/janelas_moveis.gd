class_name JanelasMoveisPlex
extends Node

var registros: Array[Dictionary]=[]
var arrastando: Control
var inicio_mouse:=Vector2.ZERO
var inicio_painel:=Vector2.ZERO
var contador:=0

func registrar(painel: Control, fechar: Callable, cabecalho: float=56.0) -> void:
	registros.append({"painel":painel,"fechar":fechar,"cabecalho":cabecalho,"visivel":false,"ordem":0})
	painel.tooltip_text=""

static func limitar(painel: Control, destino: Vector2, tela: Vector2) -> Vector2:
	return Vector2(clampf(destino.x,8,maxf(8,tela.x-painel.size.x*painel.scale.x-8)),clampf(destino.y,8,maxf(8,tela.y-painel.size.y*painel.scale.y-8))).round()

static func centralizar(painel: Control, tela: Vector2) -> void:
	painel.position=limitar(painel,painel.position if painel.get_meta("movida_pelo_player",false) else (tela-painel.size*painel.scale)*.5,tela)

func _process(_delta: float) -> void:
	for r in registros:
		var visivel: bool=is_instance_valid(r.painel) and r.painel.is_visible_in_tree()
		if visivel and not r.visivel: contador+=1;r.ordem=contador
		r.visivel=visivel
	if is_instance_valid(arrastando) and (not arrastando.is_visible_in_tree() or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)): arrastando=null

func fechar_topo() -> bool:
	var ultima: Dictionary={}
	for r in registros:
		if r.painel.is_visible_in_tree() and (ultima.is_empty() or r.ordem>=ultima.ordem): ultima=r
	if ultima.is_empty(): return false
	arrastando=null
	ultima.fechar.call()
	return true

func mover(painel: Control, destino: Vector2) -> void:
	painel.position=limitar(painel,destino,get_viewport().get_visible_rect().size)
	painel.set_meta("movida_pelo_player",true)

func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT:
		if not e.pressed:
			if is_instance_valid(arrastando): arrastando=null;get_viewport().set_input_as_handled()
			return
		var escolhido: Dictionary={}
		for r in registros:
			if not r.painel.is_visible_in_tree(): continue
			var retangulo: Rect2=r.painel.get_global_rect();retangulo.size.y=minf(retangulo.size.y,r.cabecalho*r.painel.scale.y)
			if retangulo.has_point(e.position) and (escolhido.is_empty() or r.ordem>=escolhido.ordem): escolhido=r
		if escolhido.is_empty(): return
		var sob_mouse:=get_viewport().gui_get_hovered_control()
		while sob_mouse!=null and sob_mouse!=escolhido.painel:
			if sob_mouse is BaseButton or sob_mouse is LineEdit or sob_mouse is ScrollBar: return
			sob_mouse=sob_mouse.get_parent_control()
		arrastando=escolhido.painel
		inicio_mouse=e.position;inicio_painel=arrastando.position
		contador+=1;escolhido.ordem=contador
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseMotion and is_instance_valid(arrastando):
		mover(arrastando,inicio_painel+e.position-inicio_mouse)
		get_viewport().set_input_as_handled()

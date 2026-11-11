class_name DestaqueTutorialPlex
extends Control

var areas:Array[Rect2]=[]
var cor:=Color("f2c64c")
var tempo:=0.0
var fundo:=ColorRect.new()
var pausa_do_destaque:=false
var velocidade_anterior:=1.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter=Control.MOUSE_FILTER_IGNORE
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	move_child(fundo,0)
	var shader:=Shader.new()
	shader.code="""shader_type canvas_item;
uniform sampler2D tela : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 areas[8];
uniform int total=0;
void fragment(){
 vec4 c=texture(tela,SCREEN_UV); bool livre=false;
 for(int i=0;i<8;i++){if(i>=total){break;} vec4 r=areas[i]; if(FRAGCOORD.x>=r.x && FRAGCOORD.y>=r.y && FRAGCOORD.x<=r.z && FRAGCOORD.y<=r.w){livre=true;}}
 float cinza=dot(c.rgb,vec3(.299,.587,.114)); COLOR=vec4(livre?c.rgb:mix(c.rgb,vec3(cinza),.72)*.74,c.a);
}"""
	fundo.material=ShaderMaterial.new()
	fundo.material.shader=shader

func definir(retangulos:Array[Rect2],tinta:Color=Color("f2c64c")) -> void:
	areas=retangulos
	cor=tinta
	if fundo.material!=null:
		var valores:=PackedVector4Array()
		for i in 8:
			var r:Rect2=areas[i] if i<areas.size() else Rect2()
			valores.append(Vector4(r.position.x,r.position.y,r.end.x,r.end.y))
		fundo.material.set_shader_parameter("areas",valores)
		fundo.material.set_shader_parameter("total",mini(8,areas.size()))
	queue_redraw()

func permite(p:Vector2) -> bool:
	if areas.any(func(r):return r.has_point(p)):return true
	var guia:TutorialBonniePlex=get_parent().get_parent() as TutorialBonniePlex
	if guia==null or guia.jogo==null:return false
	return guia.jogo.painel.hud.menu_aberto() or guia.jogo.painel.hud.linha_tempo.get_global_rect().has_point(p)

func _has_point(p:Vector2) -> bool:
	return not permite(p)

func _process(delta:float) -> void:
	var guia:TutorialBonniePlex=get_parent().get_parent() as TutorialBonniePlex
	if guia==null or guia.jogo==null:
		return
	var jogo:Node=guia.jogo
	var atividade:bool=guia.fase=="guiado" and guia.assunto=="intro" and get_parent().visible
	if guia.fase=="cena" and guia.assunto=="intro" or jogo.painel.hud.menu_aberto():
		if visible:hide()
	elif atividade and not visible:
		show()
	if atividade and visible:
		if not pausa_do_destaque:
			velocidade_anterior=maxf(1.0,float(jogo.velocidade_tempo))
			pausa_do_destaque=true
		elif float(jogo.velocidade_base)>0:
			velocidade_anterior=float(jogo.velocidade_base)
		jogo.velocidade_tempo=0.0
	elif pausa_do_destaque:
		pausa_do_destaque=false
		if is_zero_approx(float(jogo.velocidade_tempo)):
			jogo.velocidade_tempo=velocidade_anterior
	if visible:
		tempo+=delta
		queue_redraw()

func _exit_tree() -> void:
	if pausa_do_destaque:
		var guia:TutorialBonniePlex=get_parent().get_parent() as TutorialBonniePlex
		if guia!=null and guia.jogo!=null and is_zero_approx(float(guia.jogo.velocidade_tempo)):
			guia.jogo.velocidade_tempo=velocidade_anterior

func _draw() -> void:
	for r in areas:
		draw_rect(r.grow(3),Color(cor,.65+.3*sin(tempo*5.0)),false,3)

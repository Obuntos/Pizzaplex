class_name TransicaoNoitePlex
extends CanvasLayer

var jogo:Node
var raiz:=Control.new()
var rotulo:=Label.new()
var tempo:=0.0
var realizado:=false
var velocidade:=1.0
var acao:Callable
var lua:=IconeHudPlex.new("noite")
var sol:=IconeHudPlex.new("sol")
func iniciar(cena:Node,aplicar:Callable) -> void:
 jogo=cena;acao=aplicar;layer=200;process_mode=Node.PROCESS_MODE_ALWAYS;jogo.pausar("noite")
 add_child(raiz);raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raiz.mouse_filter=Control.MOUSE_FILTER_STOP;raiz.draw.connect(desenhar)
 for icone in [lua,sol]:icone.escala_pixel=2;raiz.add_child(icone)
 raiz.add_child(rotulo);rotulo.add_theme_font_override("font",VintagePlex.fonte("forte"));rotulo.add_theme_font_size_override("font_size",18);rotulo.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;rotulo.mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(delta:float) -> void:
 tempo+=delta
 if tempo>=.85 and not realizado:realizado=true;acao.call()
 if tempo>=1.8:jogo.retomar("noite");queue_free();return
 var mistura:=smoothstep(.5,1.3,tempo);var opacidade:=smoothstep(0,.25,tempo)*(1.0-smoothstep(1.45,1.8,tempo))
 lua.position=raiz.size*.5+Vector2(-24,-28)-Vector2(0,mistura*8);sol.position=raiz.size*.5+Vector2(-24,-28)+Vector2(0,(1-mistura)*8);lua.modulate.a=(1-mistura)*opacidade;sol.modulate.a=mistura*opacidade
 rotulo.text="06:00" if realizado else "00:00";rotulo.position=raiz.size*.5+Vector2(-100,26);rotulo.size=Vector2(200,40);raiz.queue_redraw()
func desenhar() -> void:
 var alfa:=smoothstep(0,.25,tempo)*(1.0-smoothstep(1.45,1.8,tempo))
 raiz.draw_rect(Rect2(Vector2.ZERO,raiz.size),Color(0.03,0.05,0.08,alfa*.18))
 rotulo.modulate=Color(1,1,1,alfa*.85)
func _input(_evento:InputEvent) -> void:get_viewport().set_input_as_handled()
func _exit_tree() -> void:
 if is_instance_valid(jogo):jogo.retomar("noite")

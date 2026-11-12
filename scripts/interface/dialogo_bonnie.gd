class_name DialogoBonniePlex
extends Control

signal escolha(aceita:bool)
var texto:=RichTextLabel.new()
var passo:=Label.new()
var sim:=Button.new()
var nao:=Button.new()
var rosto:=TextureRect.new()
var expressao:="feliz"
var tempo:=0.0
var caracteres:=0.0
var atlas:=AtlasTexture.new()
var escolhas:=HBoxContainer.new()
var fala_original: String = ""
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	rosto.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;rosto.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;rosto.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(rosto)
	var nome:=Label.new();nome.name="Nome";nome.text="BONNIE";nome.add_theme_color_override("font_color",Color("e88d9f"));nome.add_theme_font_size_override("font_size",19);nome.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(nome)
	texto.bbcode_enabled=false;texto.scroll_active=false;texto.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;texto.add_theme_color_override("default_color",Color("fff4d6"));texto.add_theme_font_size_override("normal_font_size",19);texto.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(texto)
	passo.text="ESPAÇO";passo.add_theme_color_override("font_color",Color("e6bb73"));passo.add_theme_font_size_override("font_size",13);passo.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(passo)
	escolhas.add_theme_constant_override("separation",12);add_child(escolhas)
	for par in [[sim,"Sim!"],[nao,"Não"]]:
		var b:Button=par[0];b.text=par[1];b.custom_minimum_size=Vector2(128,36);b.add_theme_color_override("font_color",Color("fff4d6"));b.add_theme_font_size_override("font_size",16)
		KitPlex.preparar_botao(b,Color("7a4a5c"),false,6)
		escolhas.add_child(b)
	sim.pressed.connect(func():escolha.emit(true));nao.pressed.connect(func():escolha.emit(false));escolhas.hide()
	resized.connect(organizar);organizar()
func organizar() -> void:
	var estreito:=size.x<590;var largura_rosto:=78 if estreito else 100
	rosto.position=Vector2(22,44);rosto.size=Vector2(largura_rosto,116)
	var x:=float(largura_rosto+44)
	if has_node("Nome"):get_node("Nome").position=Vector2(x,42)
	texto.position=Vector2(x,73);texto.size=Vector2(maxf(120,size.x-x-24),108);texto.add_theme_font_size_override("normal_font_size",17 if estreito else 19)
	passo.position=Vector2(size.x-87,size.y-26);escolhas.position=Vector2(x,size.y-45);queue_redraw()
func mostrar(valor:String,humor:String="feliz",pergunta:bool=false) -> void:
	fala_original=valor;expressao=humor;texto.text=IdiomaPlex.traduzir(valor);caracteres=0;texto.visible_characters=0;escolhas.visible=pergunta;passo.visible=not pergunta;atualizar_rosto();show()
func completar() -> bool:
	if texto.visible_characters<0 or texto.visible_characters>=texto.get_total_character_count():return false
	caracteres=texto.get_total_character_count();texto.visible_characters=-1;return true
func atualizar_rosto() -> void:
	var caminho:="res://assets/personagens/bonnie_visitante/"+expressao+"/parado.png"
	if not ResourceLoader.exists(caminho):return
	atlas.atlas=load(caminho);atlas.region=Rect2((floori(tempo*5.0)%12)*48+7,0,34,36);rosto.texture=atlas
func _process(delta:float) -> void:
	if not visible:return
	tempo+=delta;caracteres+=delta*42.0
	if texto.visible_characters>=0:texto.visible_characters=mini(int(caracteres),texto.get_total_character_count())
	atualizar_rosto();queue_redraw()
func degrau(r:Rect2,cor:Color,pixel:float=4) -> void:
	draw_rect(Rect2(r.position+Vector2(pixel,0),r.size-Vector2(pixel*2,0)),cor);draw_rect(Rect2(r.position+Vector2(0,pixel),r.size-Vector2(0,pixel*2)),cor)
func _draw() -> void:
	degrau(Rect2(Vector2(0,5),size),Color(0,0,0,.35));degrau(Rect2(Vector2.ZERO,size),Color("1c1218"));degrau(Rect2(Vector2(4,4),size-Vector2(8,8)),Color("f8c6dc"));degrau(Rect2(Vector2(8,8),size-Vector2(16,16)),Color("2c1a26"))
	for x in range(8,int(size.x)-8,8):
		for y in 2:draw_rect(Rect2(x,18+y*8,minf(8,size.x-8-x),8),Color("b85165") if (int(x/8.0)+y)%2==0 else Color("e8d7bc"))
	degrau(Rect2(rosto.position-Vector2(4,4),rosto.size+Vector2(8,8)),Color("1c1218"));draw_rect(Rect2(rosto.position,rosto.size),Color("67505f"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(texto):
		texto.text = IdiomaPlex.traduzir(fala_original)

class_name CarregamentoDocumentoPlex
extends Control

var barra:=MedidorDocumentoPlex.new()
var etapa:Label
var percentual:Label
var dica:Label
var pizza:=Sprite2D.new()
var tempo:=0.0
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sombra:=ColorRect.new();sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);sombra.color=Color("101915");add_child(sombra)
	var caixa:=Control.new();caixa.name="Caixa";caixa.size=Vector2(676,236);add_child(caixa)
	var fundo:=TextureRect.new();fundo.texture=load("res://assets/interface/documentos/carregamento.png");fundo.size=caixa.size;caixa.add_child(fundo)
	etapa=DocumentoPessoaPlex.texto(caixa,"Preparando o espaço...",Vector2(34,80),Vector2(525,30),20,"corpo");etapa.add_theme_color_override("font_color",Color("f1e2bd"))
	percentual=DocumentoPessoaPlex.texto(caixa,"0%",Vector2(574,80),Vector2(68,30),16,"forte");percentual.add_theme_color_override("font_color",Color("e0ae62"))
	barra.position=Vector2(39,123);barra.size=Vector2(598,14);barra.cor=Color("e0ae62");caixa.add_child(barra)
	dica=DocumentoPessoaPlex.texto(caixa,IdiomaPlex.traduzir("Dica: os funcionários recuperam energia na sala de descanso."),Vector2(34,192),Vector2(608,24),13,"corpo");dica.add_theme_color_override("font_color",Color("9a8468"))
	pizza.texture=load("res://assets/interface/documentos/pizza.svg");pizza.position=Vector2(606,24);pizza.offset=Vector2(0,32);caixa.add_child(pizza)
	get_viewport().size_changed.connect(ajustar);ajustar()
func ajustar() -> void:
	var caixa:Control=get_node("Caixa");var tela:=get_viewport_rect().size;var fator:=minf(1,minf((tela.x-40)/676.0,(tela.y-40)/236.0));caixa.scale=Vector2.ONE*fator;caixa.position=((tela-caixa.size*fator)*.5).round()
func _process(delta:float) -> void:
	tempo+=delta;pizza.rotation=sin(tempo*TAU/1.1)*.15;percentual.text=str(roundi(barra.value))+"%"
	if barra.value>=100:etapa.text=IdiomaPlex.traduzir("Pronto!")

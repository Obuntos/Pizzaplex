class_name UIArPlex
extends RefCounted
const T=preload("res://scripts/interface/tema_hud.gd")
var jogo:Node
var mapa:=MapaArPlex.new()
var botao:Button
var painel:=PanelContainer.new()
var titulo:Label
var detalhes:Label
var espera:=0.0
func configurar(cena:Node,raiz:Control,linha:Node) -> void:
	jogo=cena;mapa.jogo=jogo;mapa.z_index=121;jogo.add_child(mapa)
	botao=T.botao(linha,"",func():
		mapa.alternar();botao.button_pressed=mapa.ativo
		if mapa.ativo and jogo.mapa_conforto.ativo:jogo.painel.hud.conforto_ui.fechar()
		if not mapa.ativo:painel.hide(),T.VERDE)
	botao.toggle_mode=true;botao.custom_minimum_size=Vector2(48,48);botao.tooltip_text="Ar · qualidade por tile"
	var ic:=IconeHudPlex.new("ar");ic.escala_pixel=1.5;ic.position=Vector2(6,6);botao.add_child(ic)
	raiz.add_child(painel);painel.mouse_filter=Control.MOUSE_FILTER_IGNORE;painel.custom_minimum_size.x=352;painel.add_theme_stylebox_override("panel",T.caixa(Color("192923"),Color("779889"),12))
	var col:=VBoxContainer.new();col.mouse_filter=Control.MOUSE_FILTER_IGNORE;painel.add_child(col)
	titulo=T.texto(col,"AR",19,Color("b6d7b6"));detalhes=T.texto(col,"",14,T.PAPEL);detalhes.custom_minimum_size.x=326;detalhes.autowrap_mode=TextServer.AUTOWRAP_OFF;painel.hide()
func atualizar(delta:float) -> void:
	if not mapa.ativo or jogo.carteira.aberto() or jogo.terminal_ui.aberto() or jogo.painel.hud.menu_aberto():painel.hide();return
	espera+=delta
	if espera<.25:return
	espera=0;var c:Vector2i=jogo.apontada();var ar:AmbienciaRestaurantePlex=jogo.sistemas.ambiencia;var q:=ar.qualidade(c);titulo.text="AR · "+("BOM" if q>=85 else "ATENÇÃO" if q>=55 else "RUIM" if q>=25 else "IRRESPIRÁVEL");titulo.add_theme_color_override("font_color",MapaArPlex.cor(q))
	var linhas:=PackedStringArray(["Verde: bom · laranja: atenção","Vermelho: ruim", "Respirável" if q>=25 else "Não respirável"])
	var sala:Dictionary=jogo.ambientes.em(c)
	if sala.get("fechada",false):linhas.append("Sala: "+str(sala.tipo).capitalize())
	detalhes.text="\n".join(linhas);painel.reset_size();painel.position=Vector2(16,jogo.get_viewport().get_visible_rect().size.y-painel.size.y-76);painel.show()
func fechar() -> void:
	if mapa.ativo:mapa.alternar()
	botao.set_pressed_no_signal(false);painel.hide()

class_name MinigamesVIPlex
extends CanvasLayer

const T=preload("res://scripts/interface/tema_hud.gd")
var jogo:Node
var montagem:MontagemAtracoesPlex
var ordem:Dictionary={}
var estado:Dictionary={}
var tipo:=""
var raiz:=Control.new()
var janela:=PanelContainer.new()
var coluna:=VBoxContainer.new()
var titulo:=Label.new()
var descricao:=Label.new()
var confirmacao:=false
var web:Control
var extensao:Resource
var concluindo:=false
var tempo_conclusao:=0.0
var pronto:=false
var tempo_carga:=0.0
var saida_pendente:=0.0
var url_aberta:=""
var espera_fundo:=0.0

func configurar(cena:Node,gestor:MontagemAtracoesPlex) -> void:
	jogo=cena;montagem=gestor;layer=180;process_mode=Node.PROCESS_MODE_ALWAYS
	add_child(raiz);raiz.theme=T.criar();raiz.mouse_filter=Control.MOUSE_FILTER_IGNORE;raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(janela);janela.add_theme_stylebox_override("panel",KitPlex.moldura("janela_escura",20));janela.add_child(coluna)
	coluna.add_theme_constant_override("separation",14);coluna.add_child(titulo);titulo.add_theme_font_size_override("font_size",22)
	descricao.custom_minimum_size.x=500;descricao.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;coluna.add_child(descricao)
	var botoes:=HBoxContainer.new();coluna.add_child(botoes)
	T.botao(botoes,"Sim",mostrar_jogo,T.VERDE);T.botao(botoes,"Não / continuar depois",fechar)
	raiz.hide();get_viewport().size_changed.connect(centralizar);get_viewport().size_changed.connect(refrescar_fundo)
func aberto() -> bool:return raiz.visible
func abrir(o:Dictionary,perguntar:bool=false) -> void:
	if aberto():return
	var esperado:="plastico" if str(o.get("modelo",""))=="vi_patitas" else "olhos"
	if str(o.get("minigame_pendente",""))!=esperado:return
	ordem=o;tipo=esperado;estado=o.get("minigame_estado",{}).duplicate(true)
	confirmacao=perguntar;concluindo=false;saida_pendente=0.0;pronto=false
	raiz.show();janela.visible=perguntar;descricao.hide()
	titulo.text="Configurar a cabeça do robô?" if tipo=="olhos" else "Configurar o plástico do Patitas?"
	descricao.text="Orelhitas: instalar os olhos com o minigame original. Esc permite continuar depois." if tipo=="olhos" else "Patitas: fechar a barriga com o minigame original Plástico. Esc permite continuar depois."
	centralizar.call_deferred()
	if not perguntar:mostrar_jogo.call_deferred()
func centralizar() -> void:
	if not aberto():return
	janela.reset_size();janela.position=(get_viewport().get_visible_rect().size-janela.size)*.5
	if is_instance_valid(web):
		web.position=Vector2.ZERO;web.size=get_viewport().get_visible_rect().size
		web.call("resize")
func refrescar_fundo() -> void:
	if OS.get_name()=="Linux" and is_instance_valid(web) and pronto:atualizar_fundo()
func retangulo_jogo() -> Rect2:
	var tela:=get_viewport().get_visible_rect().size
	var fator:=minf(1.25,minf((tela.x-48)/640.0,(tela.y-48)/420.0))
	var tamanho:=Vector2(640,420)*maxf(.2,fator)
	return Rect2(((tela-tamanho)*.5).round(),tamanho.round())
func mostrar_jogo() -> void:
	if not aberto():return
	if is_instance_valid(web):
		pronto=false;tempo_carga=0.0;web.call("set_visible",false)
		var destino:="res://assets/minigames_vi/"+("patitas" if tipo=="plastico" else "orelhitas")+"/index.html"
		if url_aberta==destino:web.call("eval","window.location.reload();")
		else:web.set("url",destino);url_aberta=destino
		janela.hide();centralizar.call_deferred();return
	confirmacao=false
	if DisplayServer.get_name()=="headless":return
	if not ClassDB.class_exists("WebView"):extensao=load("res://addons/godot_wry/WRY.gdextension")
	if not ClassDB.class_exists("WebView") or DisplayServer.get_name()=="headless":
		descricao.text="O navegador incorporado não está disponível nesta instalação. Verifique se a pasta addons do jogo está completa e reinicie o jogo."
		janela.show();descricao.show();centralizar.call_deferred()
		return
	pronto=false;tempo_carga=0.0
	web=ClassDB.instantiate("WebView") as Control
	web.set("full_window_size",true);web.set("transparent",true);web.set("devtools",false);web.set("forward_input_events",false);web.set("focused_when_created",true)
	web.set("autoplay",false);web.set("incognito",false)
	if OS.get_name()!="Linux":web.set("data_directory","user://minigames_vi")
	web.connect("ipc_message",receber_mensagem)
	url_aberta="res://assets/minigames_vi/"+("patitas" if tipo=="plastico" else "orelhitas")+"/index.html"
	web.set("url",url_aberta)
	web.position=Vector2.ZERO;web.size=get_viewport().get_visible_rect().size
	web.hide();raiz.add_child(web);web.call("set_visible",false);janela.hide();centralizar.call_deferred()
func receber_mensagem(mensagem:String) -> void:
	if not aberto():return
	var dados:Variant=JSON.parse_string(mensagem)
	if not dados is Dictionary:return
	var esperado:="plastico" if tipo=="plastico" else "endo"
	if str(dados.get("game",""))!=esperado:return
	var acao:=str(dados.get("action",""))
	if acao=="fundo_pronto":
		if pronto:exibir_web.call_deferred()
		return
	if acao=="pronto":
		pronto=true;restaurar_navegador.call_deferred()
		return
	if is_instance_valid(web) and not pronto:return
	var novo:Variant=dados.get("state",{})
	if novo is Dictionary and str(novo.get("schema",""))=="zip-v1" and str(novo.get("game",""))==esperado:
		estado=novo.duplicate(true);ordem.minigame_estado=estado.duplicate(true)
	if acao=="sair":fechar.call_deferred()
	elif acao=="concluido" and estado.get("phase","")=="won":concluindo=true;tempo_conclusao=.35
func _process(delta:float) -> void:
	if not aberto():return
	if is_instance_valid(web) and not pronto:
		tempo_carga+=delta
		if tempo_carga>=15:
			remover_navegador();janela.show();descricao.show()
			descricao.text="Não foi possível abrir o minigame. No Windows, confira se o Microsoft Edge WebView2 Runtime está instalado. Seu progresso foi preservado; use continuar depois e tente novamente."
			centralizar.call_deferred()
	if saida_pendente>0:
		saida_pendente-=delta
		if saida_pendente<=0:fechar();return
	if concluindo:
		tempo_conclusao-=delta
		if tempo_conclusao<=0:concluir()
func _input(e:InputEvent) -> void:
	if aberto() and e is InputEventKey and e.pressed and e.keycode==KEY_ESCAPE:
		if is_instance_valid(web):web.call("eval","window.PlexBridge && window.PlexBridge.sair();");saida_pendente=.35
		else:fechar()
		get_viewport().set_input_as_handled()
func fechar() -> void:
	if not aberto():return
	ordem.minigame_estado=estado.duplicate(true)
	remover_navegador()
	raiz.hide();concluindo=false;saida_pendente=0.0
func remover_navegador() -> void:
	if is_instance_valid(web):
		web.call("eval","window.Mini?.preview?.current?.api?.deactivate?.();");web.hide();web.call("set_visible",false);web.call("focus_parent")
	pronto=false;tempo_carga=0.0
func restaurar_navegador() -> void:
	if is_instance_valid(web) and aberto():
		web.call("eval","window.PlexBridge.restaurar("+JSON.stringify(estado)+");")
		centralizar()
		if OS.get_name()=="Linux":atualizar_fundo(true)
		else:exibir_web()
func exibir_web() -> void:
	if not aberto() or not is_instance_valid(web):return
	web.show();web.call("set_visible",true);web.call("focus")
func atualizar_fundo(mostrar:bool=false) -> void:
	if not aberto() or not is_instance_valid(web) or DisplayServer.get_name()=="headless":return
	var im:=get_viewport().get_texture().get_image()
	if im==null or im.is_empty():return
	var dados:="data:image/png;base64,"+Marshalls.raw_to_base64(im.save_png_to_buffer())
	var aplicar:="document.body.style.setProperty('background-size','100% 100%','important');document.body.style.setProperty('background-repeat','no-repeat','important');document.body.style.setProperty('background-image','url('+src+')','important');"
	var js:="(()=>{const src="+JSON.stringify(dados)+";"+aplicar+"})();"
	if mostrar:js="(()=>{const src="+JSON.stringify(dados)+";const img=new Image();img.onload=()=>{"+aplicar+"ipc.postMessage(JSON.stringify({game:PlexMiniConfig.game,action:'fundo_pronto'}));};img.src=src;})();"
	web.call("eval",js)
func concluir() -> void:
	if estado.get("phase","")!="won":return
	var o:=ordem;var atual:=tipo;fechar();montagem.concluir_minigame(o,atual)

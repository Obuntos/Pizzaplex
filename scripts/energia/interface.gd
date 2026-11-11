class_name UIEnergiaPlex
extends CanvasLayer

const T=preload("res://scripts/interface/tema_hud.gd")
var jogo: Node
var janela:=PanelContainer.new()
var resumo: Label
var acionar: Button
var abastecer: Button
var combustivel:=ProgressBar.new()
var nome: Label
var indicador: Label
var tanque: Label
var alvo:=-1
var espera:=0.0
var secao:=VBoxContainer.new()
var painel_partida:=VBoxContainer.new()
var partida:=PartidaManualPlex.new()
var instrucao: Label
var alvo_partida:=-1

func configurar(cena: Node) -> void:
	jogo=cena
	layer=28
	var raiz:=Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter=Control.MOUSE_FILTER_IGNORE
	raiz.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(raiz)
	janela.theme=T.criar()
	janela.add_theme_stylebox_override("panel",T.caixa(Color("243039"),T.AMBAR,20))
	raiz.add_child(janela)
	var coluna:=VBoxContainer.new()
	coluna.custom_minimum_size.x=440
	coluna.add_theme_constant_override("separation",14)
	janela.add_child(coluna)
	var topo:=T.cabecalho(coluna,"CENTRAL DE ENERGIA","energia")
	T.botao(topo,"×",fechar).custom_minimum_size=Vector2(36,32)
	coluna.add_child(secao)
	secao.add_theme_constant_override("separation",12)
	var faixa:=PanelContainer.new()
	faixa.add_theme_stylebox_override("panel",T.caixa(Color("17242b"),T.LINHA,12))
	secao.add_child(faixa)
	var descricao:=VBoxContainer.new()
	faixa.add_child(descricao)
	nome=T.texto(descricao,"Gerador",20,T.PAPEL)
	indicador=T.texto(descricao,"",14,T.SUAVE)
	resumo=T.texto(secao,"",16)
	resumo.autowrap_mode=TextServer.AUTOWRAP_OFF
	tanque=T.texto(secao,"",14,T.AMBAR)
	combustivel.max_value=100
	combustivel.show_percentage=false
	combustivel.custom_minimum_size.y=20
	secao.add_child(combustivel)
	acionar=T.botao(secao,"",alternar,T.VERDE)
	abastecer=T.botao(secao,"",repor,T.MARROM)
	
	coluna.add_child(painel_partida)
	painel_partida.add_child(partida)
	instrucao=T.texto(painel_partida,"Puxe a corda 3 vezes · Depois segure e solte Espaço
para manter o ponteiro na faixa verde.",14,T.PAPEL)
	instrucao.autowrap_mode=TextServer.AUTOWRAP_OFF
	var comandos:=HBoxContainer.new();painel_partida.add_child(comandos)
	T.botao(comandos,"Voltar",cancelar_partida)
	T.botao(comandos,"Puxar corda · C",func(): partida.grab_focus();partida.puxar(),T.MARROM)
	var acelerar:=T.botao(comandos,"Acelerar",func(): pass,T.VERDE)
	acelerar.button_down.connect(func(): partida.acelerando=true)
	acelerar.button_up.connect(func(): partida.acelerando=false)
	partida.concluido.connect(concluir_partida)
	get_window().focus_exited.connect(func(): partida.acelerando=false)
	painel_partida.hide()
	get_viewport().size_changed.connect(centralizar)
	janela.hide()

func centralizar() -> void:
	janela.size=Vector2(480,560 if painel_partida.visible else 360)
	JanelasMoveisPlex.centralizar(janela,get_viewport().get_visible_rect().size)

func alternar() -> void:
	var item: Dictionary=jogo.planta.objetos.get(alvo,{})
	if item.is_empty(): return
	if item.get("ligada",true):item.ligada=false;item.reinicio_pendente=true
	else:jogo.equipamentos.solicitar_energia(int(item.id))
	jogo.iluminacao.rede.atualizar()
	jogo.iluminacao.atualizar()
	atualizar()

func repor() -> void:
	if not jogo.planta.objetos.has(alvo): return
	if MobiliaPlex.visual(jogo.planta.objetos[alvo])=="cenario_gerador_antigo":
		alvo_partida=alvo;secao.hide();painel_partida.show();partida.reiniciar();centralizar.call_deferred()
		return
	if not jogo.editor.cobrar(20): return
	jogo.iluminacao.rede.abastecer(alvo)
	jogo.iluminacao.atualizar()
	atualizar()

func aberto() -> bool: return janela.visible

func abrir(id: int) -> void:
	cancelar_partida()
	alvo=id
	janela.show()
	atualizar()
	centralizar.call_deferred()

func fechar() -> void:
	cancelar_partida()
	janela.hide()

func cancelar_partida() -> void:
	partida.cancelar();painel_partida.hide();secao.show();alvo_partida=-1
	if janela.is_visible_in_tree(): centralizar.call_deferred()

func concluir_partida() -> void:
	var item: Dictionary=jogo.planta.objetos.get(alvo_partida,{})
	if item.is_empty() or alvo_partida!=alvo or not partida.venceu: cancelar_partida();return
	var ganho:=15.0 if randf()<.08 else 10.0
	var anterior:=float(item.get("combustivel",0))
	item.combustivel=minf(100.0,anterior+ganho)
	item.ligada=false;item.reinicio_pendente=true;jogo.equipamentos.solicitar_energia(int(item.id),-1,false)
	jogo.iluminacao.rede.atualizar();jogo.iluminacao.atualizar()
	jogo.painel.mensagem("Manivela concluída · +%.0f de energia · Sem custo."%(float(item.combustivel)-anterior))
	cancelar_partida();atualizar()


func atualizar() -> void:
	var item: Dictionary=jogo.planta.objetos.get(alvo,{})
	if item.is_empty(): fechar();return
	var rede: RedeEnergiaPlex=jogo.iluminacao.rede
	var carga:=float(item.get("combustivel",0))
	var ligada:=bool(item.get("ligada",true))
	nome.text=str(MobiliaPlex.dados(item).nome)
	indicador.text="DESLIGADO" if not ligada else "SEM COMBUSTÍVEL" if carga<=0 else "RESERVA BAIXA" if carga<20 else "EM OPERAÇÃO"
	indicador.add_theme_color_override("font_color",Color("d99778") if carga<20 else Color("acd09a") if ligada else T.SUAVE)
	resumo.text="Potência disponível: %.0f\nConsumo das luzes: %.1f  ·  Fornecimento: %.0f%%"%[rede.potencia,rede.demanda,rede.fator*100]
	tanque.text="COMBUSTÍVEL                                       %.1f / 100"%carga
	combustivel.value=carga
	combustivel.add_theme_stylebox_override("fill",T.caixa(Color("ad744c") if carga<20 else T.VERDE,T.AMBAR if carga<20 else Color("9ebd8c"),0))
	acionar.text="Desligar gerador" if ligada else "Religar pela caixa de energia"
	abastecer.text="Manivela" if MobiliaPlex.visual(item)=="cenario_gerador_antigo" else "Abastecer até 100 · $ %.2f"%20.0
	abastecer.tooltip_text=""
	abastecer.disabled=carga>=100.0

func _process(delta: float) -> void:
	if not aberto(): return
	espera-=delta
	if espera<=0.0:
		espera=.2
		atualizar()

class_name CatalogoConstrucaoPlex
extends RefCounted

const T = preload("res://scripts/interface/tema_hud.gd")
const CATEGORIAS=["Paredes","Portas e janelas","Pisos","Móveis","Cozinha","Armazenamento","Banheiro","Palcos","Luzes","Energia","Decoração","Limpeza","Escritório","Oficina","Cenário"]
const OFICINA=["mesa_desenho_inclinada","area_montagem_atracao","antigo_armario_oficina","pecas_bancada_endo","pecas_bancada_plastico","pecas_bancada_carcaca","bancada_montagem_coelho","oficina_bancada_trabalho","amb_painel_diagnostico","amb_carregador_oficina","armario_ferramentas"]
const TONS={"Paredes":Color("4e2b1c"),"Pisos":Color("51442b"),"Portas e janelas":Color("493222"),"Móveis":Color("55332d"),"Cozinha":Color("394330"),"Armazenamento":Color("56402a"),"Banheiro":Color("334541"),"Palcos":Color("542b35"),"Luzes":Color("5b4528"),"Energia":Color("47432d"),"Decoração":Color("503c32"),"Limpeza":Color("394638"),"Escritório":Color("403b42"),"Oficina":Color("3d3a33"),"Cenário":Color("403324")}
var jogo: Node
var painel := PanelContainer.new()
var itens := HBoxContainer.new()
var busca := LineEdit.new()
var estilos := OptionButton.new()
var titulo: Label
var ajuda: Label
var categoria := "Paredes"
var botoes: Dictionary = {}
var selecionado := ""
var cards:Dictionary={}
var demolir: Button
var rolagem:=ScrollContainer.new()
var abas:=GridContainer.new()
const NOMES_ABAS={"Portas e janelas":"Portas","Armazenamento":"Depósito","Móveis":"Mobília","Escritório":"Escritório","Cenário":"Exterior"}
const ICONES_ABAS={"Paredes":"paredes","Pisos":"piso","Portas e janelas":"porta","Móveis":"moveis","Cozinha":"cozinha","Armazenamento":"deposito","Banheiro":"banheiro","Palcos":"palco","Luzes":"luzes","Energia":"energia","Decoração":"decoracao","Limpeza":"limpeza","Escritório":"fichario","Oficina":"engrenagem","Cenário":"sol"}

func rolar(evento:InputEvent) -> void:
	if not evento is InputEventMouseButton or not evento.pressed:return
	if evento.button_index not in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_LEFT,MOUSE_BUTTON_WHEEL_RIGHT]:return
	var passo:=-120 if evento.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_LEFT] else 120
	rolagem.scroll_horizontal+=passo
	jogo.get_viewport().set_input_as_handled()

func grupo(tipo: String) -> String:
	var d: Dictionary = CatalogoPlex.objetos[tipo]
	if tipo in OFICINA or tipo.begins_with("oficina_") and not tipo.begins_with("oficina_vestiario") and not tipo.begins_with("oficina_planta"):return "Oficina"
	if tipo in ["amb_relogio_ponto","amb_interruptor_antigo","armario_funcionarios","antigo_armario_vestiario"] or tipo.begins_with("oficina_armario_metal") or tipo.begins_with("oficina_vestiario"):return "Escritório"
	var funcional:=CatalogoPlex.base(tipo)
	if tipo in ["ponto_recebimento","suporte"]: return "Armazenamento"
	if tipo in ["pia_banheiro","vaso_sanitario","divisoria_porta"]: return "Banheiro"
	if funcional=="registradora":return "Móveis"
	if tipo=="terminal_ibm": return "Escritório"
	if funcional in ["estante","armario_ferramentas","armario_utensilios"] or "estante" in tipo or "deposito" in tipo: return "Armazenamento"
	if tipo=="armario_limpeza" or tipo.contains("lixeira"): return "Limpeza"
	if d.has("categoria"): return str(d.categoria)
	var base := CatalogoPlex.base(tipo)
	if tipo in CatalogoPlex.PORTAS or tipo.begins_with("janela"): return "Portas e janelas"
	if base=="parede": return "Paredes"
	if d.get("piso",false) or tipo=="chao" or tipo.begins_with("externo_"): return "Pisos"
	if tipo.begins_with("luz_"): return "Luzes"
	if tipo in ["palco","escada","pose"] or tipo.begins_with("cortina_"): return "Palcos"
	if tipo in ["forno","geladeira","pia","bancada_preparo","armario_utensilios"]: return "Cozinha"
	if tipo in ["lixeira","lixeira_salao","vassoura","balde","armario_limpeza"]: return "Limpeza"
	if tipo in ["cadeira","mesa","mesa_longa","mesa_longa_arredondada","balcao","bancada","suporte","terminal_ibm","registradora","banco_espera","estante","armario_funcionarios","armario_ferramentas","maquina_fliperama","divisoria_porta","pia_banheiro","vaso_sanitario","ponto_recebimento"]: return "Móveis"
	return "Decoração"

func permitido(tipo: String) -> bool:
	if tipo in ["pose","banco_espera","divisoria_porta","amb_divisoria_banheiro","cortina_central_1","lixeira","antigo_barril_enferrujado","antigo_barril_vermelho"]:return false
	if CatalogoPlex.objetos[tipo].get("oculto",false) or CatalogoPlex.objetos[tipo].get("apenas_cenario",false): return false
	var d: Dictionary = CatalogoPlex.objetos[tipo]
	if tipo in ["suporte","vassoura","balde","pose_quebrado","pose_montagem","armario_ferramentas"]: return false
	if tipo.begins_with("festa_bolo") or tipo.begins_with("festa_fatia") or tipo.begins_with("festa_prato") or tipo.begins_with("festa_pizza") or tipo.begins_with("festa_confetes") or tipo.begins_with("festa_desenho") or tipo=="festa_baloes_buque": return false
	if tipo=="chao" or tipo.begins_with("externo_") or DesgastePisosPlex.gasto(tipo): return false
	if PalcosMadeiraPlex.eh(tipo) and tipo!=PalcosMadeiraPlex.MODULO: return false
	if tipo.begins_with("cenario_trilha_") or tipo.begins_with("antigo_barricada_") or tipo.begins_with("cenario_buraco_") or tipo=="antigo_parede_quebrada_modulo" or tipo in ["cenario_parede_madeira_janela","cenario_parede_madeira_vitrine"]: return false
	if d.get("bairro",false) or tipo.begins_with("cenario_parede_predio_") or tipo.begins_with("cenario_parede_casa_") or tipo.begins_with("cenario_telhado_") or ManchasPlex.eh(tipo): return false
	return tipo not in ["caixa","pose_montagem","pose_quebrado","dinheiro","pizza","fatia_pizza","prato","bandeja","copo_bebida","mancha_chao","bebida_derramada","restos_mesa","pecas_manutencao","caixa_ferramentas","parede_fachada"] and not tipo.begins_with("caixa_") and not tipo.begins_with("guarana_") and not d.has("recurso") and not d.get("entulho",false) and not d.get("compravel",false)

func configurar(cena: Node, raiz: Control) -> void:
	jogo = cena
	painel.theme = T.criar()
	painel.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	painel.mouse_force_pass_scroll_events = false
	painel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	painel.offset_left = 16
	painel.offset_right = -16
	painel.offset_top = -388
	painel.offset_bottom = -76
	painel.add_theme_stylebox_override("panel",T.caixa(Color("2e2923"),Color("9c805b"),12))
	raiz.add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation",4)
	painel.add_child(coluna)
	var cabecalho:=T.cabecalho(coluna,"","construir")
	titulo = T.texto(cabecalho,"CATÁLOGO",16,T.AMBAR)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	estilos.custom_minimum_size.x = 150
	estilos.item_selected.connect(func(i): jogo.editor.estado_visual=str(estilos.get_item_metadata(i)))
	cabecalho.add_child(estilos)
	busca.placeholder_text = "Pesquisar item"
	busca.custom_minimum_size = Vector2(180,24)
	busca.text_changed.connect(func(_v): preencher())
	cabecalho.add_child(busca)
	demolir=T.botao(cabecalho,"",func(): selecionado=""; jogo.escolher_ferramenta("remover"); preencher(),T.MARROM)
	demolir.custom_minimum_size=Vector2(46,36)
	demolir.toggle_mode=true
	demolir.tooltip_text=""
	var martelo:=IconeHudPlex.new("demolir")
	martelo.escala_pixel=1.5;martelo.custom_minimum_size=Vector2(36,36)
	martelo.position=Vector2(5,6)
	demolir.add_child(martelo)
	T.botao(cabecalho,"×",func(): jogo.escolher_ferramenta("selecionar"); painel.hide()).tooltip_text=""
	ajuda=T.texto(coluna,"",13,T.SUAVE)
	ajuda.hide()
	abas.columns=8
	abas.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	abas.add_theme_constant_override("h_separation",6)
	abas.add_theme_constant_override("v_separation",5)
	coluna.add_child(abas)
	for nome in CATEGORIAS:
		var b:=VintagePlex.botao(abas,"      "+IdiomaPlex.traduzir(str(NOMES_ABAS.get(nome,nome))),func(): categoria=nome;busca.text="";preencher())
		b.custom_minimum_size=Vector2(126,32)
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size",14)
		b.toggle_mode=true
		var ic:=IconeHudPlex.new(ICONES_ABAS[nome]);ic.escala_pixel=1.0;ic.custom_minimum_size=Vector2(24,24);ic.position=Vector2(7,4);b.add_child(ic)
		botoes[nome]=b
	var scroll:=rolagem
	scroll.gui_input.connect(rolar)
	scroll.mouse_force_pass_scroll_events=false
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	coluna.add_child(scroll)
	scroll.add_child(itens)
	itens.add_theme_constant_override("separation",8)
	jogo.get_viewport().size_changed.connect(organizar)
	organizar.call_deferred()

func icone(tipo: String) -> Texture2D:
	if tipo == "pose": return null
	var textura := CatalogoPlex.sprite(tipo,0)
	var atlas := CatalogoPlex.atlas_vazio()
	atlas.atlas = textura
	var imagem:=SilhuetasPlex.imagem(textura)
	if imagem==null or not imagem.get_used_rect().has_area():
		textura=GeometriaPlex.obter(tipo,0,4).textura;atlas.atlas=textura;imagem=SilhuetasPlex.imagem(textura)
	if imagem==null: return null
	atlas.region = Rect2(imagem.get_used_rect())
	return atlas

static func chave_ordem(tipo:String) -> String:
	var d:Dictionary=CatalogoPlex.objetos[tipo]
	var familia:=CatalogoPlex.base(MobiliaPlex.logico(tipo))
	var preco:=MobiliaPlex.preco(tipo)
	if familia=="registradora":return "003:%01d:%06d:%s"%[0 if tipo=="registradora" else 1,preco,tipo]
	if tipo.begins_with("luz_"):return "%01d:%06d:%s"%[0 if tipo.contains("economica") else 1,preco,tipo]
	if tipo in ["palco","escada","antigo_escada_madeira_3"] or PalcosMadeiraPlex.eh(tipo):return "000:%06d:%s"%[preco,tipo]
	if tipo in ["sistema_caixa_som_chao","sistema_caixa_som_teto"]:return "001:%06d:%s"%[preco,tipo]
	if CortinasPalcoPlex.eh(tipo) or tipo.begins_with("sistema_cortina"):return "002:%06d:%s"%[preco,tipo]
	if tipo.begins_with("amb_fliperama_") or tipo=="amb_maquina_premios":familia="maquina_fliperama"
	if d.get("piso",false):
		var quadriculado:=tipo.contains("quadric") or tipo.contains("xadrez") or str(d.get("nome","")).to_lower().contains("quadric")
		return "%01d:%06d:%s"%[0 if quadriculado else 1,preco,tipo]
	if str(d.get("categoria",""))=="Decoração":
		var nome:=str(d.get("nome",tipo)).to_lower()
		var temas:Array=[["estrel"],["cartaz","desenho","placa","pôster"],["pizza","fatia de"],["nuvem"],["balão","balões"],["cordão"],["tapete","passadeira"],["pelúcia"],["recorte"],["planta"],["chapéu","bolo","confete","serpentina"],["prato","calabresa","muçarela","vegetariana","fatia"],["piscina"]]
		var tema:=99
		for i in temas.size():
			if (temas[i] as Array).any(func(chave):return nome.contains(str(chave))):tema=i;break
		return "D%02d:%s:%06d"%[tema,nome,preco]
	var familias:Array=["mesa","cadeira","balcao","registradora","bancada","maquina_fliperama","estante","armario_funcionarios","armario_ferramentas","armario_utensilios"]
	var ordem:=familias.find(familia)
	return "%03d:%06d:%01d:%s"%[ordem if ordem>=0 else 99,preco,0 if tipo.begins_with("antigo_") else 1,tipo]
func preencher() -> void:
	cards.clear()
	for filho in itens.get_children():
		itens.remove_child(filho)
		filho.queue_free()
	if demolir!=null: demolir.set_pressed_no_signal(jogo.editor.ferramenta=="remover")
	estilos.clear()
	var estados: Array = CatalogoPlex.objetos.get(selecionado,{}).get("estados",[])
	estilos.visible = estados.size()>1
	for estado in estados:
		estilos.add_item(str(estado).replace("_"," ").capitalize())
		estilos.set_item_metadata(estilos.item_count-1,estado)
		if estado==jogo.editor.estado_visual: estilos.select(estilos.item_count-1)
	titulo.text = IdiomaPlex.traduzir("CATÁLOGO")+" / "+(IdiomaPlex.traduzir("RESULTADOS") if not busca.text.is_empty() else IdiomaPlex.traduzir(categoria).to_upper())
	painel.add_theme_stylebox_override("panel",T.caixa(Color("2e2923"),Color("9c805b"),12))
	ajuda.text=""
	for nome in botoes:
		var b:Button=botoes[nome]
		b.text="      "+IdiomaPlex.traduzir(str(NOMES_ABAS.get(nome,nome)))
		VintagePlex.preparar_botao(b,TONS[nome] if nome==categoria else Color("302016"))
		b.add_theme_font_size_override("font_size",14)
		b.set_pressed_no_signal(nome==categoria)
		if nome==categoria:
			for estado in ["normal","pressed","hover_pressed"]: b.add_theme_stylebox_override(estado,VintagePlex.caixa(TONS[nome].lightened(.24),Color("bf9565"),8))
	var tipos: Array = CatalogoPlex.objetos.keys().filter(func(tipo): return permitido(tipo) and (grupo(tipo)==categoria if busca.text.is_empty() else (str(CatalogoPlex.objetos[tipo].nome)+" "+NomesItensPlex.nome(tipo)+" "+NomesItensPlex.nome_pt(tipo)).to_lower().contains(busca.text.to_lower())))
	tipos.sort_custom(func(a,b):return chave_ordem(a).naturalnocasecmp_to(chave_ordem(b))<0)
	for tipo in tipos:
		var info: Dictionary = CatalogoPlex.objetos[tipo]
		var card := Button.new()
		card.name=tipo;card.set_meta("tipo",tipo);cards[tipo]=card
		card.custom_minimum_size = Vector2(144,134)
		card.mouse_force_pass_scroll_events = false
		card.gui_input.connect(rolar)
		card.clip_contents = true
		VintagePlex.preparar_botao(card,Color(TONS.get(grupo(tipo),TONS[categoria])).lightened(.08))
		for estado in ["normal","hover","pressed","hover_pressed"]:
			card.add_theme_stylebox_override(estado,T.caixa(Color("514637") if estado=="hover" else Color("3c342c"),Color("dfbb79") if selecionado==tipo else Color("76654e"),7))
		var pacote: Array = info.get("pacote",[1,1])
		var preco: int = jogo.preco_construcao(tipo)*int(pacote[0])*int(pacote[1])
		card.tooltip_text=IdiomaPlex.traduzir(str(info.nome)) if IdiomaPlex.idioma_atual()!="en" else NomesItensPlex.nome(tipo)
		if tipo=="armario_limpeza": card.tooltip_text=""
		if FornoPlex.eh({"tipo":tipo}): card.tooltip_text=""
		card.pressed.connect(func(): selecionado=tipo; jogo.escolher_ferramenta(tipo); preencher())
		itens.add_child(card)
		var coluna := VBoxContainer.new()
		coluna.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		coluna.offset_left = 6
		coluna.offset_right = -6
		coluna.offset_top = 4
		coluna.offset_bottom = -4
		coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coluna.add_theme_constant_override("separation",0)
		card.add_child(coluna)
		var imagem := TextureRect.new()
		imagem.texture = icone(tipo)
		imagem.custom_minimum_size = Vector2(128,70)
		imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		imagem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		imagem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coluna.add_child(imagem)
		if imagem.texture==null:
			var simbolo := IconeHudPlex.new("paredes" if tipo=="pose" else "sol")
			imagem.add_child(simbolo)
			simbolo.position = Vector2(38,3)
		var nome := T.texto(coluna,NomesItensPlex.nome(tipo),14)
		nome.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		nome.max_lines_visible=2
		nome.custom_minimum_size.y=32
		nome.custom_minimum_size.x = 128
		nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var custo := T.texto(coluna,("$ %d    ★ %d"%[preco,info.conforto]) if info.conforto>0 else "$ %d"%preco,14,T.AMBAR)
		custo.clip_text = true
		custo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func alternar() -> void:
	painel.visible = not painel.visible
	if painel.visible: preencher()
	jogo.visor.enquadrar_se_automatico()


func atualizar_ar() -> void:
	if not painel.visible:return
	var t:=PoluicaoArPlex.resumo(jogo.planta,jogo.editor.ferramenta,jogo.apontada(),jogo.editor.rotacao)
	ajuda.text=t;ajuda.visible=not t.is_empty()

func organizar() -> void:
	if jogo==null:return
	var largura:=jogo.get_viewport().get_visible_rect().size.x-64
	abas.columns=clampi(int(largura/142),4,8)
	var linhas:=ceili(float(CATEGORIAS.size())/abas.columns)
	painel.offset_top=-388-maxi(0,linhas-2)*37

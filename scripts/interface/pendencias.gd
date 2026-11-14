class_name PendenciasRestaurantePlex
extends VBoxContainer

const T=preload("res://scripts/interface/tema_hud.gd")
const DESTINOS={"entrada":"Portas e janelas","mesas":"Móveis","caixa":"Móveis","cozinha":"Cozinha","banheiro":"Banheiro","limpeza":"Limpeza","lixo":"Limpeza","energia":"Energia","luzes":"Luzes","lazer":"Palcos"}
const TITULOS={"entrada":"Entrada","mesas":"Salão","caixa":"Caixa","cozinha":"Cozinha","pizza":"Pizza","bebida":"Bebidas","pratos":"Pratos","banheiro":"Banheiro","limpeza":"Limpeza","lixo":"Resíduos","energia":"Energia","luzes":"Iluminação","lazer":"Entretenimento"}
var jogo: Node
var avisos: Array[Dictionary]=[]
var botoes: Dictionary={}
var paineis: Dictionary={}
var listas: Dictionary={}
var assinaturas: Dictionary={}
var nivel_aberto:=0
var espera:=2.0

func configurar(cena: Node) -> void:
	jogo=cena
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left=-248;offset_right=-16;offset_top=190;offset_bottom=260
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation",6)
	for nivel in [2,1]:
		var secao:=VBoxContainer.new();secao.mouse_filter=Control.MOUSE_FILTER_IGNORE
		secao.add_theme_constant_override("separation",3);add_child(secao)
		var b:=Button.new()
		var cor:=Color("622f30") if nivel==2 else Color("665234")
		for estado in ["normal","hover","pressed"]: b.add_theme_stylebox_override(estado,T.caixa(cor.lightened(.15) if estado=="hover" else cor.darkened(.15) if estado=="pressed" else cor,T.LINHA,6))
		b.pressed.connect(func(): abrir(nivel))
		secao.add_child(b)
		b.toggle_mode=true
		b.custom_minimum_size.y=30
		b.add_theme_font_size_override("font_size",14)
		b.add_theme_color_override("font_color",Color("ffb4a3") if nivel==2 else Color("f0ce73"))
		var seta:=IconeHudPlex.new("aba_fechada");seta.name="Seta";seta.escala_pixel=1.0;seta.custom_minimum_size=Vector2(24,24);seta.position=Vector2(8,3);b.add_child(seta)
		botoes[nivel]=b
		var painel:=PanelContainer.new()
		painel.add_theme_stylebox_override("panel",KitPlex.moldura("hud_alerta" if nivel==2 else "hud_ativo",8))
		painel.mouse_force_pass_scroll_events=false
		secao.add_child(painel);paineis[nivel]=painel
		var scroll:=ScrollContainer.new();scroll.mouse_force_pass_scroll_events=false
		scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size=Vector2(212,220);painel.add_child(scroll)
		var lista:=VBoxContainer.new();lista.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		lista.add_theme_constant_override("separation",6);scroll.add_child(lista)
		listas[nivel]=lista
	fechar()

func aberto() -> bool:
	return nivel_aberto>0

func abrir(nivel: int) -> void:
	nivel_aberto=0 if nivel_aberto==nivel else nivel
	mostrar()

func fechar() -> void:
	nivel_aberto=0
	mostrar()

func resolver(aviso: Dictionary) -> void:
	fechar()
	var categoria: String=DESTINOS.get(aviso.codigo,"")
	if not categoria.is_empty():
		var catalogo: CatalogoConstrucaoPlex=jogo.painel.hud.catalogo
		catalogo.categoria=categoria;catalogo.busca.text="";catalogo.preencher();catalogo.painel.show()
		return
	if aviso.codigo in ["pizza","bebida","pratos"]:
		for item in jogo.planta.objetos.values():
			if item.tipo=="terminal_ibm" and jogo.compras.terminal_valido(item.id):
				jogo.terminal_ui.abrir(item.id)
				return
		jogo.painel.hud.catalogo.categoria="Escritório"
		jogo.painel.hud.catalogo.busca.text=""
		jogo.painel.hud.catalogo.preencher();jogo.painel.hud.catalogo.painel.show()

func adicionar(codigo: String, nivel: int, _descricao: String) -> void:
	var textos:Dictionary={"entrada":"Acesso indisponível.","mesas":"Salão incompleto.","caixa":"Caixa indisponível.","cozinha":"Cozinha incompleta.","pizza":"Ingredientes em falta." if nivel==2 else "Poucos ingredientes.","bebida":"Poucas bebidas.","pratos":"Pratos em falta.","banheiro":"Banheiro incompleto.","limpeza":"Limpeza incompleta.","lixo":"Descarte em falta.","energia":"Energia indisponível." if nivel==2 else "Pouca energia.","luzes":"Iluminação insuficiente.","lazer":"Poucas atrações."}
	if not avisos.any(func(a): return a.codigo==codigo): avisos.append({"codigo":codigo,"nivel":nivel,"texto":textos.get(codigo,"Sala incompleta.")})

func examinar() -> void:
	avisos.clear()
	jogo.ambientes.atualizar()
	var internos: Array=jogo.planta.objetos.values().filter(func(o): return TerrenoPlex.contem(jogo.planta,o.celula) and int(o.get("carregada_por",0))==0)
	var tem:=func(tipo): return internos.any(func(o): return o.tipo==tipo)
	if EntradaVisitantesPlex.entradas(jogo.clientes).is_empty(): adicionar("entrada",2,"Entrada sem acesso ao salão.")
	if jogo.ambientes.equipamentos("mesa",["salao"]).is_empty(): adicionar("mesas",2,"Faltam mesa e cadeiras acessíveis.")
	var caixas: Array=jogo.ambientes.equipamentos("registradora",["salao","recepcao"])
	if caixas.is_empty(): adicionar("caixa",2,"Registradora ausente ou bloqueada.")
	elif caixas.all(func(id): return jogo.atendimento.ponto(id,true).x<0 or jogo.atendimento.ponto(id,false).x<0): adicionar("caixa",2,"Libere os dois lados da registradora: caixista e clientes.")
	var faltando: Array=[]
	for tipo in ["forno","bancada_preparo","geladeira"]:
		var existe: bool=internos.any(func(o): return FornoPlex.eh(o)) if tipo=="forno" else tem.call(tipo)
		if not existe: faltando.append("Fogão ou forno de pizza" if tipo=="forno" else str(CatalogoPlex.objetos[tipo].nome))
	if not faltando.is_empty(): adicionar("cozinha",2,"Falta: "+", ".join(faltando)+".")
	elif jogo.ambientes.equipamentos("forno",["cozinha"]).is_empty(): adicionar("cozinha",2,"Libere os acessos e a abertura dos equipamentos da cozinha.")
	var pizza:=0;var bebida:=0
	for item in internos:
		if item.tipo=="geladeira":
			var estoque: Dictionary=item.get("estoque",{})
			pizza+=int(estoque.get("pizza",item.get("ingredientes",0)));bebida+=int(estoque.get("guarana",0))
		elif item.tipo.begins_with("caixa") and not InventarioPlex.peca_oficina(item) and not item.has("parte_endo"):
			if item.tipo=="caixa_guarana": bebida+=int(item.get("quantidade",0))
			elif item.tipo in ["caixa_pizza","caixa_ingredientes"]: pizza+=int(item.get("quantidade",0))
	if pizza==0: adicionar("pizza",2,"Sem ingredientes de pizza.")
	elif pizza<3: adicionar("pizza",1,"Ingredientes de pizza acabando.")
	if bebida==0: adicionar("bebida",1,"Sem guaraná no estoque.")
	elif bebida<4: adicionar("bebida",1,"Guaraná acabando.")
	var pratos: int=internos.filter(func(o): return o.tipo=="prato" and not o.get("sujo",false)).size()
	for item in internos:
		if PacotesPratosPlex.eh(item): pratos+=int(item.get("quantidade",0))
	if pratos==0: adicionar("pratos",2,"Sem pratos limpos.")
	if jogo.ambientes.equipamentos("vaso_sanitario",["banheiro"]).is_empty() or jogo.ambientes.equipamentos("pia_banheiro",["banheiro"]).is_empty(): adicionar("banheiro",1,"Banheiro incompleto ou bloqueado.")
	for sala in jogo.ambientes.ambientes:
		if sala.get("fechada",false) and sala.get("tipo","")=="banheiro" and not CamerasVigilanciaPlex.porta_banheiro_coberta(jogo,sala):adicionar("banheiro",1,"Uma câmera externa precisa cobrir a porta do banheiro.")
	if (not tem.call("vassoura") and not KitLimpezaPlex.em_uso(jogo.planta,"vassoura")) or (not tem.call("balde") and not KitLimpezaPlex.em_uso(jogo.planta,"balde")) or not tem.call("armario_limpeza"): adicionar("limpeza",1,"Faltam utensílios de limpeza.")
	if not tem.call("lixeira") and not tem.call("lixeira_salao"): adicionar("lixo",1,"Sem lixeira para os resíduos.")
	jogo.iluminacao.rede.atualizar()
	if jogo.iluminacao.rede.fator<=0: adicionar("energia",2,"Gerador ausente, desligado ou sem combustível.")
	elif jogo.iluminacao.rede.fator<.99: adicionar("energia",1,"Energia insuficiente.")
	if not internos.any(func(o): return LuminariasPlex.eh(o.tipo) and o.get("ligada",true)): adicionar("luzes",1,"Sem luminárias ligadas.")
	if not tem.call("maquina_fliperama") and not jogo.personagens.any(func(a): return a.robo and not a.visita.get("morto",false)) and not is_instance_valid(jogo.fantasias.presenter()): adicionar("lazer",1,"Sem fliperama, show ou mascote.")
	for sala in jogo.ambientes.ambientes:
		if sala.tipo=="livre" or sala.get("faltas",[]).is_empty() or not sala.celulas.keys().any(func(c): return TerrenoPlex.contem(jogo.planta,c)): continue
		adicionar("sala_"+str(sala.id),2,str(jogo.ambientes.definicoes[sala.tipo].nome)+": "+str(sala.faltas[0]))

func texto(nivel: int) -> String:
	return "Recolher avisos" if nivel_aberto==nivel else "Mostrar avisos"

func mostrar() -> void:
	for nivel in botoes:
		var selecionados:=avisos.filter(func(a): return a.nivel==nivel)
		var quantidade:=selecionados.size()
		var expandido: bool=quantidade>0 and nivel_aberto==nivel
		botoes[nivel].get_parent().visible=quantidade>0
		botoes[nivel].text="    "+(IdiomaPlex.traduzir("%d · Prioridade") if nivel==2 else IdiomaPlex.traduzir("%d · Atenção"))%quantidade
		var seta:IconeHudPlex=botoes[nivel].get_node("Seta");seta.tipo="aba_aberta" if expandido else "aba_fechada";seta.queue_redraw()
		botoes[nivel].tooltip_text=""
		botoes[nivel].set_pressed_no_signal(expandido)
		paineis[nivel].visible=expandido
		if not expandido: continue
		var chave:=hash(selecionados)
		if assinaturas.get(nivel,-1)==chave: continue
		assinaturas[nivel]=chave
		var lista: VBoxContainer=listas[nivel]
		for filho in lista.get_children(): lista.remove_child(filho);filho.queue_free()
		for aviso in selecionados:
			var linha:=HBoxContainer.new();linha.add_theme_constant_override("separation",4);lista.add_child(linha)
			var coluna:=VBoxContainer.new();coluna.add_theme_constant_override("separation",2)
			coluna.size_flags_horizontal=Control.SIZE_EXPAND_FILL;linha.add_child(coluna)
			T.texto(coluna,str(TITULOS.get(aviso.codigo,"Sala")),14,T.AMBAR)
			var descricao:=T.texto(coluna,aviso.texto,13)
			descricao.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			descricao.custom_minimum_size.x=164
			if DESTINOS.has(aviso.codigo) or aviso.codigo in ["pizza","bebida","pratos"]:
				var acao:=KitPlex.seta(linha,1,func(): resolver(aviso))
				acao.custom_minimum_size=Vector2(32,36)
				acao.tooltip_text=""
			lista.add_child(HSeparator.new())

func atualizar(delta: float) -> void:
	if jogo==null: return
	espera+=delta
	if espera<2.0: return
	espera=0.0
	examinar();mostrar()


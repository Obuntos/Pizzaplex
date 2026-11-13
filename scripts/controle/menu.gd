class_name MenuControlePlex
extends CanvasLayer

const T=preload("res://scripts/interface/tema_hud.gd")
var jogo: Node
var raiz:=Control.new()
var radial:=Control.new()
var avisos:=Control.new()
var efeitos:Array=[]
var opcoes:Array=[]
var alvo_social:PersonagemPlex
var alvo_objeto:=-1
var alvo_rato:=-1
var ponto:=Vector2.ZERO
var titulo:=""
var social:=false
var raio:=Vector2(204,126)

func configurar(cena: Node) -> void:
	jogo=cena
	layer=115
	add_child(raiz)
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter=Control.MOUSE_FILTER_STOP
	raiz.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			fechar()
			jogo.get_viewport().set_input_as_handled())
	raiz.theme=T.criar()
	radial.mouse_filter=Control.MOUSE_FILTER_IGNORE
	raiz.add_child(radial)
	avisos.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(avisos)
	fechar()

func aberto() -> bool: return raiz.visible

func fechar() -> void:
	raiz.hide()
	radial.hide()
	alvo_social=null
	alvo_objeto=-1
	alvo_rato=-1
	social=false
	opcoes.clear()

func adicionar(texto: String, acao: Callable, cor: Color=T.FUNDO) -> void:
	opcoes.append({"texto":texto,"acao":acao,"cor":cor})

func botao(texto: String, tipo: String, ator: int=-1, objeto: int=-1, cor: Color=T.FUNDO) -> void:
	adicionar(texto,func(): jogo.controle.solicitar(tipo,ator,objeto),cor)

func abrir(pessoa: PersonagemPlex, objeto: int, posicao: Vector2) -> bool:
	fechar()
	var controle: ControleAdministradorPlex=jogo.controle
	var admin:=controle.administrador()
	ponto=posicao
	if is_instance_valid(pessoa) and pessoa!=admin and not pessoa.robo and not pessoa.visita.get("morto",false): return abrir_social(pessoa)
	if is_instance_valid(pessoa):
		alvo_social=pessoa
		titulo=jogo.social.nome(pessoa)
		if pessoa==admin:
			titulo=IdentidadesPlex.completo(admin)
			adicionar("Desativar controle manual" if controle.manual() else "Ativar controle manual",controle.alternar)
			adicionar("Ver carteira",func(): jogo.carteira.abrir(admin))
			adicionar("Descansar",func():jogo.turnos.descansar(admin))
			if controle.manual():
				if not controle.seguidores.lista().is_empty(): botao("Dispensar acompanhantes","dispensar_todos")
				if admin.visita.has("faca_tipo"):
					if not admin.visita.get("faca_equipada",false): botao("Equipar faca","equipar_faca")
					botao("Largar faca","soltar_faca")
				if int(admin.visita.get("corpo_carregado",-1))>0: botao("Soltar corpo","soltar_corpo")
		elif pessoa.robo and jogo.controle_robo.opcoes(self,pessoa):
			titulo=IdentidadesPlex.completo(pessoa)+jogo.controle_robo.sufixo(pessoa)
		elif pessoa.robo:
			jogo.oficina.opcoes(self,pessoa)
			jogo.sistemas.bandas.opcoes(self,pessoa)
			if pessoa.robotica.get("sangrando",false): botao("Limpar animatrônico","limpar_robo",pessoa.identificador)
			if not pessoa.visita.get("montando_atracao",false):adicionar("Redefinir lugar",func(): jogo.atracoes.redefinir_lugar(pessoa.identificador))
			if controle.manual() and is_instance_valid(admin) and jogo.atracoes.permite_corpo(pessoa,jogo.clientes.ator(int(admin.visita.get("corpo_carregado",-1)))): botao("Colocar corpo no animatrônico","ocultar",pessoa.identificador)
		elif controle.manual() and pessoa.visita.get("morto",false):
			if int(pessoa.visita.get("carregado_por",-1))<0:
				botao("Carregar corpo","carregar",pessoa.identificador)
				for item in jogo.planta.sobre(pessoa.celula):
					if ManchasPlex.eh(item.tipo):
						botao("Limpar ao redor","limpar",-1,item.id)
						break
			elif int(pessoa.visita.get("carregado_por",-1))==admin.identificador: botao("Soltar corpo","soltar_corpo")
	elif objeto>=0 and jogo.planta.objetos.has(objeto):
		var item: Dictionary=jogo.planta.objetos[objeto]
		if CatalogoPlex.base(str(item.tipo))=="parede" or MobiliaPlex.logico(MobiliaPlex.visual(item))=="parede": return false
		if str(item.tipo).begins_with("cidade_casa"):
			alvo_objeto=objeto;titulo="Descanso em casa"
			adicionar("Pular noite · 00:00 → 06:00",func():jogo.operacao.pular_noite())
			return mostrar_baloes()
		alvo_objeto=objeto
		titulo=str(item.get("nome_sala",item.get("camera_nome",MobiliaPlex.dados(item).nome)))
		jogo.equipamentos.opcoes(self,item)
		var reparo:PersonagemPlex=jogo.clientes.ator(int(item.get("reparo_reserva",item.get("robo_reserva",item.get("reparo_robo",-1)))))
		if is_instance_valid(reparo):jogo.oficina.opcoes(self,reparo)
		if LuminariasPlex.eh(str(item.tipo)):
			var ligada:bool=item.get("ligada",true)
			titulo+=" · "+("Ligada" if ligada else "Desligada")
			adicionar("Desligar luz" if ligada else "Ligar luz",func(): LuminariasPlex.definir(jogo.planta,objeto,not ligada))
		if item.tipo in CatalogoPlex.PORTAS:adicionar("Destrancar" if item.get("trancada",false) else "Trancar",func():jogo.sistemas.trancar(objeto))
		if EscadasPlex.palco(item):adicionar("Desligar show" if jogo.sistemas.shows.ativos.has(jogo.sistemas.shows.grupo(objeto)) else "Ligar show",func():jogo.sistemas.shows.alternar(objeto))
		if MontagemAtracoesPlex.bancada(item) and not jogo.atracoes.ordem(objeto).is_empty():
			var em_andamento:Dictionary=jogo.atracoes.ordem(objeto)
			if em_andamento.fase in ["endo","plastico","carcaca","reparo","troca_carcaca","desmontar"]:adicionar("Voltar a montar",func():jogo.atracoes.retomar_trabalho(objeto))
		if MontagemAtracoesPlex.bancada(item):
			var ordem:Dictionary=jogo.atracoes.ordem(objeto)
			var fase:=str(ordem.get("fase",""))
			if str(ordem.get("minigame_pendente","")).is_empty() and (fase in ["pronto_endo","pronto_plastico","plastico_mesa"] or fase.is_empty() and jogo.atracoes.pesquisado()):adicionar("Montar VI · Orelhitas · $180" if fase.is_empty() else "Montar plástico · $110" if fase=="pronto_endo" else "Colocar plástico" if fase=="plastico_mesa" else "Colocar roupa · $150",func():jogo.atracoes.continuar(objeto))
			if fase.is_empty() and item.tipo=="area_montagem_atracao" and jogo.atracoes.pesquisado("vi_patitas"):
				adicionar("Montar VI · Patitas · $180",func():jogo.atracoes.continuar(objeto,"vi_patitas"))
		if MobiliaPlex.dados(item).get("alto_falante",false):adicionar("Desligar som" if item.get("som_ligado",false) else "Ligar som",func():item.som_ligado=not item.get("som_ligado",false))
		if EstudosPlex.eh_mesa(str(item.tipo)): adicionar("Estudo",func(): jogo.estudos_ui.abrir(objeto))
		if item.tipo=="terminal_ibm":
			adicionar("Acessar computador",func(): jogo.terminal_ui.abrir(objeto))
			adicionar("Fitas VHS · %d"%jogo.sistemas.vhs.fitas.size(),func(): jogo.sistemas.vhs.ver())
		if MobiliaPlex.dados(item).get("gerador",false):
			titulo+="\nCombustível: %d%%"%roundi(float(item.get("combustivel",100)))
			adicionar("Desligar" if item.get("ligada",true) else "Religar pela caixa de energia",func():
				if item.get("ligada",true):item.ligada=false;item.reinicio_pendente=true;jogo.planta.alterada.emit()
				else:jogo.equipamentos.solicitar_energia(int(item.id)))
			adicionar("Abastecer · $20",func():
				if jogo.editor.cobrar(20):jogo.iluminacao.rede.abastecer(objeto))
		if LimpezaItensPlex.eh(item):
			adicionar("Limpar / recolher",func():PrioridadesServicoPlex.solicitar(jogo,objeto,"lavar_item"))
			adicionar("Jogar fora",func():PrioridadesServicoPlex.solicitar(jogo,objeto,"descartar_item"))
		if LimpezaAmbientesPlex.eh(item) or LugaresPlex.mesa(str(item.tipo)):
			adicionar("Limpar · prioridade",func(): PrioridadesServicoPlex.solicitar(jogo,objeto,"limpar"))
		if LugaresPlex.mesa(str(item.tipo)):
			adicionar("Priorizar atendimento",func(): PrioridadesServicoPlex.solicitar(jogo,objeto,"atender"))
		if controle.manual():
			if item.tipo=="armario_funcionarios":
				botao("Vestir fantasia","vestir",-1,objeto)
				if admin.modelo.begins_with("fantasia_"): botao("Retirar fantasia","retirar_fantasia",-1,objeto)
			if item.tipo=="banco_espera": botao("Sentar no banco","sentar_banco",-1,objeto)
			if item.tipo=="cenario_faca_cozinha": botao("Pegar faca","pegar_faca",-1,objeto)
		if EmbalagensMoveisPlex.eh(item):
			adicionar("Desembalar",func(): EmbalagensMoveisPlex.solicitar(jogo,objeto))
			adicionar("Cancelar compra · reembolso integral",func(): BalanceamentoPlex.remover(jogo.editor,objeto))
		if MoverItensPlex.permitido(jogo,objeto): adicionar("Mover item",func(): MoverItensPlex.iniciar(jogo,objeto))
	elif controle.manual() and is_instance_valid(admin):
		titulo="Controle manual"
		botao("Parar ação atual","parar")
		if admin.visita.has("faca_tipo"): botao("Largar faca","soltar_faca")
		if int(admin.visita.get("corpo_carregado",-1))>0: botao("Soltar corpo","soltar_corpo")
		if not controle.seguidores.lista().is_empty(): botao("Dispensar acompanhantes","dispensar_todos")
	else:
		var celula: Vector2i=jogo.apontada()
		var sala: Dictionary=jogo.ambientes.em(celula)
		if not sala.get("funcoes",[]).is_empty():
			titulo="Prioridade da sala"
			adicionar("Priorizar limpeza da sala",func(): PrioridadesServicoPlex.solicitar_sala(jogo,celula))
	return mostrar_baloes()

func abrir_rato(id:int,posicao:Vector2) -> bool:
	fechar();alvo_rato=id;ponto=posicao;titulo="Rato"
	adicionar("Espantar",func():jogo.ratos.espantar(id))
	return mostrar_baloes()

func abrir_social(pessoa: PersonagemPlex) -> bool:
	fechar()
	if not is_instance_valid(pessoa) or pessoa.robo or pessoa.visita.get("morto",false): return false
	alvo_social=pessoa
	social=true
	var id:=pessoa.identificador
	var novo:bool=jogo.social.nivel(pessoa)==0
	var seguindo:=int(pessoa.visita.get("seguindo_adm",-1))>0
	var robo_controlado:PersonagemPlex=jogo.controle_robo.ator()
	if is_instance_valid(robo_controlado) and jogo.sistemas.caca.pode_matar(robo_controlado,pessoa):adicionar("Matar",func():jogo.sistemas.caca.matar(robo_controlado,pessoa),Color("7a2a24"))
	if pessoa.cargo=="funcionario" and pessoa.funcao=="seguranca":
		adicionar("Ver carteira",func():jogo.carteira.abrir(pessoa));adicionar("Escala noturna",func():jogo.sistemas.abrir_escala());return mostrar_baloes()
	botao("Apresentar-se" if novo else "Conversar","apresentar" if novo else "conversar",id)
	botao("Elogiar","elogiar",id,-1,T.VERDE)
	botao("Brincar","brincar",id)
	botao("Provocar","provocar",id,-1,Color("644139"))
	if pessoa.funcao!="seguranca":botao("Parar de seguir" if seguindo else "Acompanhar","dispensar" if seguindo else "seguir",id)
	adicionar("Ver perfil",func(): jogo.carteira.abrir(pessoa))
	jogo.sistemas.acessorios.opcoes(self,pessoa)
	jogo.sistemas.perdidas.opcoes(self,pessoa)
	if TurnosEquipePlex.funcionario(pessoa) and pessoa.funcao!="seguranca":adicionar("Descansar",func():jogo.turnos.descansar(pessoa))
	var admin: PersonagemPlex=jogo.controle.administrador()
	if jogo.controle.manual() and is_instance_valid(admin) and admin.visita.get("faca_equipada",false) and int(admin.visita.get("corpo_carregado",-1))<0: botao("Atacar","atacar",id)
	return mostrar_baloes()

func executar(acao: Callable) -> void:
	fechar()
	acao.call()

func mostrar_baloes() -> bool:
	if opcoes.is_empty():
		fechar()
		return false
	for n in radial.get_children():
		radial.remove_child(n)
		n.queue_free()
	raio=Vector2(240,156) if opcoes.size()>6 else Vector2(204,126)
	for i in opcoes.size():
		var opcao: Dictionary=opcoes[i]
		var angulo: float=-PI*.5+TAU*float(i)/opcoes.size()
		var b:=Button.new()
		b.text=str(opcao.texto)
		b.custom_minimum_size=Vector2(164,48)
		b.size=b.custom_minimum_size
		b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		b.position=(Vector2(cos(angulo)*raio.x,sin(angulo)*raio.y)-b.size*.5).round()
		b.add_theme_font_size_override("font_size",15)
		var cor: Color=opcao.cor
		for estado in ["normal","hover","pressed","focus","hover_pressed"]:
			var vazio:=StyleBoxEmpty.new()
			for lado in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:vazio.set_content_margin(lado,10)
			b.add_theme_stylebox_override(estado,vazio)
		for propriedade in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:b.add_theme_color_override(propriedade,T.PAPEL)
		b.add_theme_color_override("font_hover_color",Color("ffe9b8"))
		b.add_theme_color_override("font_outline_color",Color("1a100c"))
		b.add_theme_constant_override("outline_size",3)
		b.pressed.connect(executar.bind(opcao.acao))
		radial.add_child(b)
		var balao:=BalaoMenuPlex.new()
		balao.cor=cor
		balao.size=b.size
		balao.direcao=-Vector2(cos(angulo)*raio.x,sin(angulo)*raio.y).normalized()
		balao.ligar(b)
		b.add_child(balao)
		b.resized.connect(func():balao.size=b.size)
	var nome:=Label.new()
	nome.name="Relacao"
	nome.size=Vector2(216,56)
	nome.position=Vector2(-108,-28)
	nome.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	nome.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	nome.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	nome.add_theme_font_size_override("font_size",16)
	nome.add_theme_color_override("font_color",T.PAPEL)
	nome.add_theme_color_override("font_shadow_color",Color("101b23"))
	nome.add_theme_constant_override("shadow_offset_x",2)
	nome.add_theme_constant_override("shadow_offset_y",2)
	nome.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var placa:=BalaoMenuPlex.new()
	placa.name="Placa"
	placa.cor=Color("20150f")
	placa.cauda=false
	placa.size=nome.size+Vector2(0,8)
	placa.position=Vector2(0,-4)
	nome.add_child(placa)
	nome.add_theme_constant_override("outline_size",3)
	nome.add_theme_color_override("font_outline_color",Color("1a100c"))
	radial.add_child(nome)
	radial.show()
	raiz.show()
	posicionar_baloes()
	return true

func posicionar_baloes() -> void:
	var centro:=ponto
	if alvo_rato>=0:
		if not jogo.ratos.visuais.has(alvo_rato):fechar();return
		centro=jogo.ratos.visuais[alvo_rato].get_global_transform_with_canvas()*Vector2(0,-18)
	elif is_instance_valid(alvo_social): centro=alvo_social.get_global_transform_with_canvas()*Vector2(0,-40)
	elif alvo_objeto>=0:
		if not jogo.planta.objetos.has(alvo_objeto):
			fechar()
			return
		var pos:=ApoiosPlex.posicao(jogo.planta,jogo.planta.objetos[alvo_objeto])
		centro=jogo.mundo.get_global_transform_with_canvas()*(GradePlex.projetar(Vector2(pos.x,pos.y))-Vector2(0,pos.z+30))
	var tela:=get_viewport().get_visible_rect().size
	var margem:=raio+Vector2(90,64)
	var disponivel:=tela*.5-Vector2(8,8)
	var escala:=minf(1.0,minf(disponivel.x/margem.x,disponivel.y/margem.y))
	radial.scale=Vector2.ONE*maxf(.3,escala)
	margem*=radial.scale
	radial.position=Vector2(clampf(centro.x,margem.x,maxf(margem.x,tela.x-margem.x)),clampf(centro.y,margem.y,maxf(margem.y,tela.y-margem.y))).round()
	var nome:=radial.get_node_or_null("Relacao") as Label
	if nome!=null:
		nome.text=jogo.social.nome(alvo_social)+"\nRelação: %d"%jogo.social.relacao(alvo_social) if social and is_instance_valid(alvo_social) else titulo
		if is_instance_valid(alvo_social) and alvo_social.robo:nome.text="%d%% funcional\nBateria: %d%%"%[OficinaRobosPlex.funcional(alvo_social),roundi(float(alvo_social.robotica.get("bateria",100)))]
		var placa:=nome.get_node_or_null("Placa") as Control
		if placa!=null:placa.visible=not nome.text.strip_edges().is_empty()

func mostrar_relacao(pessoa: PersonagemPlex, valor: int) -> void:
	if not is_instance_valid(pessoa) or valor==0: return
	var l:=Label.new();l.text=("+" if valor>0 else "")+str(valor)
	l.add_theme_font_size_override("font_size",24);l.add_theme_color_override("font_color",Color("8bdb8b") if valor>0 else Color("ec8276"))
	l.add_theme_color_override("font_shadow_color",Color("101b23"));l.add_theme_constant_override("shadow_offset_x",2);l.add_theme_constant_override("shadow_offset_y",2)
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE;avisos.add_child(l)
	efeitos.append({"rotulo":l,"alvo":weakref(pessoa),"tempo":0.0})

func _process(delta: float) -> void:
	if raiz.visible and radial.visible: posicionar_baloes()
	for efeito in efeitos.duplicate():
		efeito.tempo=float(efeito.tempo)+delta
		var alvo=efeito.alvo.get_ref()
		var l: Label=efeito.rotulo
		if not is_instance_valid(alvo) or float(efeito.tempo)>=1.8:
			l.queue_free();efeitos.erase(efeito);continue
		l.position=(alvo.get_global_transform_with_canvas()*Vector2(0,-76))+Vector2(-15,-float(efeito.tempo)*24)
		l.modulate.a=1.0-clampf((float(efeito.tempo)-1.0)/.8,0,1)

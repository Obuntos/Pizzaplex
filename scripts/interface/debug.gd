class_name DebugPlex
extends CanvasLayer

const T=preload("res://scripts/interface/tema_hud.gd")
const VISAO_SEGURANCA=7.0
const ROBOS=[["Orelhitas","novo_coelho_detalhes"],["Patitas","vi_patitas"],["Toy Orelhitas","vi_toy_orelhitas"],["Orelhitas antigo (quebrado)","vi_orelhitas_quebrado"],["Toy Orelhitas (quebrado)","vi_toy_orelhitas_quebrado"],["Toy Patitas","vi_toy_patitas"],["Patitas antigo (quebrado)","vi_patitas_quebrado"],["Toy Patitas (quebrado)","vi_toy_patitas_quebrado"]]
var jogo:Node
var raiz:=Control.new()
var janela:=PanelContainer.new()
var camada:=Node2D.new()
var robo_modelo:=OptionButton.new()
var valor_saldo:=SpinBox.new()
var info_segurancas:Label
var info_geral:Label
var botao_rotas:Button
var botao_visao:Button
var visoes:Dictionary={}
var escolhendo:=""
var robo_rotacao:=0
var espera:=0.0

func configurar(cena:Node) -> void:
	jogo=cena;layer=181;add_child(raiz);raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raiz.mouse_filter=Control.MOUSE_FILTER_IGNORE
	camada.z_index=121;jogo.add_child(camada);camada.draw.connect(desenhar)
	raiz.add_child(janela);janela.theme=T.criar();janela.add_theme_stylebox_override("panel",KitPlex.moldura("janela_escura",14))
	var col:=VBoxContainer.new();col.custom_minimum_size.x=440;col.add_theme_constant_override("separation",6);janela.add_child(col)
	var topo:=T.cabecalho(col,"DEBUG","debug");T.botao(topo,"×",fechar)
	var abas:=TabContainer.new();col.add_child(abas)
	var guardas:=aba(abas,"Seguranças")
	var linha_seg:=HBoxContainer.new();guardas.add_child(linha_seg)
	botao_rotas=T.botao(linha_seg,"Rotas",camada.queue_redraw,T.AZUL);botao_rotas.toggle_mode=true
	botao_visao=T.botao(linha_seg,"Campo de visão",camada.queue_redraw,T.AZUL);botao_visao.toggle_mode=true
	var linha_criar:=HBoxContainer.new();guardas.add_child(linha_criar)
	T.botao(linha_criar,"Criar segurança de teste",criar_seguranca,T.AZUL);T.botao(linha_criar,"Remover",remover_segurancas)
	info_segurancas=rotulo(guardas)
	var geral:=aba(abas,"Robôs e dinheiro")
	T.texto(geral,"ROBÔ POSSUÍDO",14,T.AMBAR)
	var linha_robo:=HBoxContainer.new();geral.add_child(linha_robo);linha_robo.add_child(robo_modelo)
	for r in ROBOS:robo_modelo.add_item(str(r[0]))
	var linha_colocar:=HBoxContainer.new();geral.add_child(linha_colocar)
	T.botao(linha_colocar,"Colocar no mapa",func():escolhendo="robo";avisar("Debug: clique no tile onde o robô vai ficar. R gira a seta, botão direito cancela."),T.AZUL);T.botao(linha_colocar,"Remover robôs",remover_robos)
	T.botao(geral,"Ir para 22:55 (testar o Controle à noite)",func():jogo.calendario.minutos=1375.0;avisar("Debug: horário ajustado para 22:55."),T.AZUL)
	T.texto(geral,"DINHEIRO",14,T.AMBAR)
	var linha_saldo:=HBoxContainer.new();geral.add_child(linha_saldo)
	valor_saldo.min_value=0;valor_saldo.max_value=9999999;valor_saldo.step=1;valor_saldo.prefix="$";valor_saldo.custom_minimum_size.x=180;linha_saldo.add_child(valor_saldo)
	T.botao(linha_saldo,"Definir saldo",definir_saldo,T.AZUL)
	var novos:=aba(abas,"Sistemas novos")
	T.texto(novos,"PISCINA DE BOLINHAS",14,T.AMBAR)
	var linha_piscina:=HBoxContainer.new();novos.add_child(linha_piscina)
	T.botao(linha_piscina,"Crianças na piscina",criancas_piscina,T.AZUL);T.botao(linha_piscina,"Derrubar 6 bolinhas",derrubar_bolinhas,T.AZUL)
	T.texto(novos,"ENTREGAS",14,T.AMBAR)
	T.botao(novos,"Chamar entregador agora",chamar_entregador,T.AZUL)
	T.texto(novos,"GORE (clique no tile)",14,T.AMBAR)
	var linha_gore:=HBoxContainer.new();novos.add_child(linha_gore)
	for n in [1,2,3]:T.botao(linha_gore,"Nível "+str(n),func():escolhendo="gore"+str(n);avisar("Debug: clique no tile do gore nível "+str(n)+". Botão direito cancela."),T.AZUL)
	T.botao(novos,"Completar estudo atual",completar_estudo,T.AZUL)
	T.botao(novos,"Ir para 23:25 (mecânico noturno)",func():jogo.calendario.minutos=1405.0;jogo.sistemas.mecanico.feita=-1;avisar("Debug: horário ajustado para 23:25."),T.AZUL)
	var amigos:=aba(abas,"Espíritos e amigos")
	T.texto(amigos,"ADICIONAR ESPÍRITO",14,T.AMBAR)
	var linha_espiritos:=HBoxContainer.new();amigos.add_child(linha_espiritos)
	for item in [[1,"medio","Médio"],[2,"raivoso","Raivoso"],[3,"timido","Tímido"]]:
		var tipo:String=item[1];var nome:String=item[2]
		T.botao(linha_espiritos,str(item[0])+" · "+nome,func():jogo.sistemas.espiritos.adicionar(tipo);jogo.sistemas.espiritos.atribuir();avisar("Debug: espírito "+nome+" adicionado."),T.AZUL)
	T.texto(amigos,"AMIGOS DO BAIRRO",14,T.AMBAR)
	var linha_amigos:=HBoxContainer.new();amigos.add_child(linha_amigos)
	T.botao(linha_amigos,"Teste do Arlequim",func():avisar(jogo.sistemas.amigos.testar("vi_arlequim")),T.AZUL)
	T.botao(linha_amigos,"Teste da Coruja",func():avisar(jogo.sistemas.amigos.testar("vi_coruja")),T.AZUL)
	T.botao(amigos,"Ir para 04:00 (controlar o Arlequim)",func():jogo.calendario.minutos=240.0;avisar("Debug: horário ajustado para 04:00."),T.AZUL)
	T.texto(geral,"DESEMPENHO",14,T.AMBAR)
	info_geral=rotulo(geral)
	jogo.janelas_moveis.registrar(janela,fechar,48);raiz.hide()
func aba(abas:TabContainer,nome:String) -> VBoxContainer:
	var v:=VBoxContainer.new();v.name=nome;v.add_theme_constant_override("separation",6);abas.add_child(v);return v
func rotulo(pai:Node) -> Label:
	var l:=T.texto(pai,"",13,T.SUAVE);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.custom_minimum_size.x=430;return l

func aberto() -> bool:return raiz.visible
func alternar() -> void:
	if aberto():fechar()
	else:abrir()
func abrir() -> void:
	valor_saldo.value=float(jogo.servicos.saldo)
	raiz.show();janela.reset_size()
	if not janela.get_meta("movida_pelo_player",false):janela.position=Vector2(16,136)
func fechar() -> void:
	raiz.hide();escolhendo=""
	for b in [botao_rotas,botao_visao]:b.set_pressed_no_signal(false)
	visoes.clear();camada.queue_redraw()
func avisar(texto:String) -> void:jogo.painel.mensagem(texto)
func ponto(c:Vector2) -> Vector2:return GradePlex.projetar(c,jogo.planta.altura(Vector2i(c.round()))+.6)
func segurancas() -> Array:
	return jogo.personagens.filter(func(a):return a.funcao=="seguranca" and not a.robo and a.visible and not a.visita.get("morto",false) and not a.visita.get("fora_turno",false))
func definir_saldo() -> void:
	jogo.servicos.saldo=snappedf(valor_saldo.value,.01);jogo.painel.hud.atualizar(1.0);avisar("Debug: saldo definido em $ %.2f."%jogo.servicos.saldo)

func celula_livre() -> Vector2i:
	var centro:=GradePlex.selecionar(jogo.camera.position)
	for raio in 12:
		for y in range(-raio,raio+1):
			for x in range(-raio,raio+1):
				var c:=centro+Vector2i(x,y)
				if TerrenoPlex.contem(jogo.planta,c) and jogo.planta.transitavel(c) and jogo.planta.em(c).get("tipo","") not in CatalogoPlex.PORTAS:return c
	return Vector2i(-1,-1)
func criar_seguranca() -> void:
	var c:=celula_livre()
	if c.x<0:avisar("Debug: nenhum espaço livre perto da câmera.");return
	var a:PersonagemPlex=jogo.criar_personagem("humano",c,"funcionario",true,{})
	if not is_instance_valid(a):return
	a.funcao="seguranca";a.uniforme="seguranca";a.cabelo="curto";a.automatico=false
	a.identidade={"nome":"Segurança","sobrenome":"de Teste","apelido":"","idade":30,"sexo":"masculino"}
	a.visita.debug_evento=true;a.visita.debug_servico=true;a.visita.debug_seguranca=true;a.visita.turno_iniciado=true
	avisar("Debug: segurança de teste criado.")
func remover_segurancas() -> void:
	for a in jogo.personagens.duplicate():
		if a.visita.get("debug_seguranca",false):jogo.sistemas.guarda.liberar_terminal(a);jogo.despawn(a)
func texto_segurancas() -> String:
	var linhas:=PackedStringArray()
	for a in segurancas():
		var rota:Array=a.movimento.rota
		linhas.append("%s · %s · %s"%[IdentidadesPlex.completo(a),str(a.trabalho),"destino "+str(rota[-1])+" (%d passos)"%rota.size() if not rota.is_empty() else "parado"])
	return "Nenhum segurança em turno." if linhas.is_empty() else "\n".join(linhas)
func calcular_visoes() -> void:
	visoes.clear()
	if not botao_visao.button_pressed:return
	for a in segurancas():
		var lista:Array=[];var frente:=VisaoNPCPlex.frente(a);var r:=ceili(VISAO_SEGURANCA)
		for y in range(-r,r+1):
			for x in range(-r,r+1):
				var c:Vector2i=a.celula+Vector2i(x,y)
				if GradePlex.dentro(c) and VisaoNPCPlex.cone(jogo.planta,a.local,frente,Vector2(c),VISAO_SEGURANCA):lista.append(c)
		visoes[a.identificador]=lista

func colocar_robo(c:Vector2i) -> void:
	escolhendo=""
	if not jogo.planta.transitavel(c) or jogo.sistemas.armazem.ocupada(c):avisar("Debug: escolha um tile livre.");return
	var r:PersonagemPlex=jogo.criar_personagem(str(ROBOS[robo_modelo.selected][1]),c,"atracao",true,{})
	if not is_instance_valid(r):avisar("Debug: não foi possível criar o robô.");return
	r.automatico=false;AnimatronicosPlex.garantir(r);r.robotica.bateria=100.0;r.robotica.desligado_manual=true;AnimatronicosPlex.mudar(r,"desligado")
	r.visita.debug_evento=true;r.visita.debug_robo=true;r.visita.debug_possuido=true;r.trabalho="teste_diagnostico"
	r.direcao=GradePlex.direcao_suporte(robo_rotacao)
	jogo.sistemas.armazem.encaixar(r)
	jogo.animatronicos.palcos.atualizar()
	if int(jogo.animatronicos.palcos.grupos.get(c,-1))>=0 and not ArmazemRobosPlex.INTEIRO.has(r.modelo):
		var criada:bool=jogo.planta.sobre(c,"pose").is_empty()
		var seta:int=jogo.planta.colocar("pose",c,robo_rotacao)
		if seta>=0:
			r.visita.debug_seta=seta;r.visita.debug_seta_criada=criada
			jogo.sistemas.shows.prender(r,jogo.planta.objetos[seta])
	if not jogo.sistemas.armazem.deitar(r):avisar("Debug: o Toy quebrado deitado ocupa 2 tiles; o tile de trás está ocupado.")
func remover_robos() -> void:
	for a in jogo.personagens.duplicate():
		if not a.visita.get("debug_robo",false):continue
		var seta:=int(a.visita.get("debug_seta",-1)) if a.visita.get("debug_seta_criada",false) else -1
		jogo.despawn(a)
		if jogo.planta.objetos.has(seta):jogo.planta.remover(seta)

func _process(delta:float) -> void:
	if not aberto():return
	espera+=delta
	if escolhendo=="robo":camada.queue_redraw()
	if espera<.25:return
	espera=0.0;calcular_visoes()
	if botao_rotas.button_pressed:jogo.rondas.atualizar_pontos()
	for a in jogo.personagens:
		if a.visita.get("debug_robo",false):a.robotica.bateria=100.0
	info_segurancas.text=texto_segurancas();info_geral.text=jogo.desempenho.resumo()
	camada.queue_redraw()

func _input(e:InputEvent) -> void:
	if not aberto() or escolhendo.is_empty():return
	if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT and not jogo.painel.bloqueia_mouse(e.position):
		if escolhendo.begins_with("gore"):GorePlex.espalhar(jogo,jogo.apontada(),escolhendo.trim_prefix("gore").to_int());escolhendo="";jogo.planta.alterada.emit()
		else:colocar_robo(jogo.apontada())
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_RIGHT:
		escolhendo="";get_viewport().set_input_as_handled()
	elif escolhendo=="robo" and e is InputEventKey and e.pressed and not e.echo and e.keycode==KEY_R:
		robo_rotacao=posmod(robo_rotacao+1,4);get_viewport().set_input_as_handled()

func tile(c:Vector2i,cor:Color) -> void:
	var p:=GradePlex.poligono(ponto(Vector2(c)));camada.draw_colored_polygon(p,cor)
func desenhar() -> void:
	if not aberto():return
	if escolhendo=="robo":
		var alvo:Vector2i=jogo.apontada()
		tile(alvo,Color("dfb16a",.35))
		var inicio:=ponto(Vector2(alvo));var fim:=ponto(Vector2(alvo)+Vector2(GradePlex.frente(robo_rotacao))*.55)
		var lado:=(fim-inicio).normalized().orthogonal()*5.0
		camada.draw_line(inicio,fim,Color("f1dfb9"),3)
		camada.draw_colored_polygon(PackedVector2Array([fim+(fim-inicio).normalized()*6.0,fim+lado,fim-lado]),Color("f1dfb9"))
	for id in visoes:
		for c in visoes[id]:tile(c,Color(1,.92,.55,.22))
	if botao_rotas.button_pressed:
		for c in jogo.rondas.pontos:camada.draw_circle(ponto(Vector2(c)),3,Color("75aaa8"))
		for a in segurancas():
			var pontos:=PackedVector2Array([ponto(a.local)])
			if a.movimento.atravessando:pontos.append(ponto(Vector2(a.movimento.destino)))
			for c in a.movimento.rota:pontos.append(ponto(Vector2(c)))
			if pontos.size()>1:
				camada.draw_polyline(pontos,Color("b7cacb"),2)
				camada.draw_circle(pontos[-1],5,Color("d7d087"))
			camada.draw_string(ThemeDB.fallback_font,ponto(a.local)+Vector2(-60,-58),str(a.trabalho),HORIZONTAL_ALIGNMENT_CENTER,120,11,Color("f1dfb9"))

func criancas_piscina() -> void:
	var piscina:PiscinaBolinhasPlex=jogo.sistemas.piscina
	var lista:=piscina.piscinas()
	if lista.is_empty():avisar("Debug: coloque uma piscina de bolinhas primeiro.");return
	var p:Dictionary=lista[0]
	var vagas:=PiscinaBolinhasPlex.VAGAS-piscina.ocupantes(p).size()
	var colocadas:=0
	for a in jogo.personagens:
		if vagas<=0:break
		if a.cargo!="crianca" or a.visita.has("piscina") or a.visita.get("morto",false) or a.visita.get("perdida",false):continue
		a.movimento.cancelar();a.visita.brincando=true;a.trabalho="piscina";piscina.entrar(p,a);a.visita.piscina_limite=15.0;vagas-=1;colocadas+=1
	if colocadas==0:avisar("Debug: não há crianças livres no restaurante ou a piscina está cheia.")
	else:avisar("Debug: crianças colocadas na piscina. Elas saem em 15 segundos.")

func derrubar_bolinhas() -> void:
	var piscina:PiscinaBolinhasPlex=jogo.sistemas.piscina
	var lista:=piscina.piscinas()
	if lista.is_empty():avisar("Debug: coloque uma piscina de bolinhas primeiro.");return
	var p:Dictionary=lista[0]
	for i in PiscinaBolinhasPlex.LIMITE:piscina.derramar(p)
	avisar("Debug: %d montes de bolinhas no chão."%piscina.fora(p))

func chamar_entregador() -> void:
	var entregas:EntregasMercadoPlex=jogo.sistemas.entregas
	for pedido in jogo.compras.encomendas:pedido.tempo=0.0
	if entregas.pendentes().is_empty():avisar("Debug: faça uma encomenda no IBM primeiro.");return
	if entregas.etapa!="":avisar("Debug: o entregador já está a caminho.");return
	entregas.chamar()
	avisar("Debug: entregador chamado." if entregas.etapa!="" else "Debug: o entregador não achou caminho até o ponto de recebimento.")

func completar_estudo() -> void:
	if not jogo.estudos.concluir(): avisar("Debug: não há estudo pendente.")

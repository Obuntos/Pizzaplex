class_name DebugPlex
extends CanvasLayer

const T=preload("res://scripts/interface/tema_hud.gd")
const VISAO_SEGURANCA=7.0
const FORCAS=[["Passos (investigador)",.48,.22,9.0,"passos"],["Vasculhando registros",.85,.22,9.0,"mexer"],["Grito / incidente",1.0,.18,12.0,"grito"],["Música de robô",1.0,.22,14.0,"musica"]]
const ROBOS=[["Orelhitas","novo_coelho_detalhes"],["Patitas","vi_patitas"],["Toy Orelhitas","vi_toy_orelhitas"],["Orelhitas antigo (quebrado)","vi_orelhitas_quebrado"],["Toy Orelhitas (quebrado)","vi_toy_orelhitas_quebrado"],["Toy Patitas","vi_toy_patitas"],["Patitas antigo (quebrado)","vi_patitas_quebrado"],["Toy Patitas (quebrado)","vi_toy_patitas_quebrado"]]
var jogo:Node
var raiz:=Control.new()
var janela:=PanelContainer.new()
var camada:=Node2D.new()
var forca:=OptionButton.new()
var robo_modelo:=OptionButton.new()
var valor_saldo:=SpinBox.new()
var info_som:Label
var info_investigacao:Label
var info_segurancas:Label
var info_geral:Label
var botao_ruido:Button
var botao_rotas:Button
var botao_visao:Button
var botao_salas:Button
var botao_cameras:Button
var cameras_vistas:Dictionary={}
var cameras_base:Dictionary={}
var cameras_sujo:=true
var espera_cameras:=0.0
var ruido:Dictionary={}
var som:Dictionary={}
var origem_som:=Vector2i(-1,-1)
var ouvintes:Array=[]
var visoes:Dictionary={}
var escolhendo:=""
var robo_rotacao:=0
var original:Dictionary={}
var espera:=0.0
var espera_ruido:=0.0
var tempo:=0.0

func configurar(cena:Node) -> void:
	jogo=cena;layer=181;add_child(raiz);raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raiz.mouse_filter=Control.MOUSE_FILTER_IGNORE
	camada.z_index=121;jogo.add_child(camada);camada.draw.connect(desenhar);jogo.planta.alterada.connect(sujar_cameras)
	raiz.add_child(janela);janela.theme=T.criar();janela.add_theme_stylebox_override("panel",KitPlex.moldura("janela_escura",14))
	var col:=VBoxContainer.new();col.custom_minimum_size.x=440;col.add_theme_constant_override("separation",6);janela.add_child(col)
	var topo:=T.cabecalho(col,"DEBUG","debug");T.botao(topo,"×",fechar)
	var abas:=TabContainer.new();col.add_child(abas)
	var sons:=aba(abas,"Sons")
	var linha_som:=HBoxContainer.new();sons.add_child(linha_som)
	botao_ruido=T.botao(linha_som,"Mapa de ruído",func():calcular_ruido();camada.queue_redraw(),T.AZUL);botao_ruido.toggle_mode=true
	linha_som.add_child(forca)
	for f in FORCAS:forca.add_item(str(f[0]))
	var linha_emitir:=HBoxContainer.new();sons.add_child(linha_emitir)
	T.botao(linha_emitir,"Emitir som no mapa",func():escolhendo="som";info_som.text="Clique em um tile do mapa. Botão direito cancela.",T.AZUL)
	T.botao(linha_emitir,"Limpar som",limpar_som)
	var legenda_som:=T.texto(sons,"Graves (música, motor) atravessam paredes; vozes e gritos abafam; passos quase somem. Portas abertas deixam o som contornar.\nLaranja: ouvível acima do ruído de fundo · Azul: abafado\nCírculo verde: ouviu · vermelho: não ouviu",12,T.SUAVE);legenda_som.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;legenda_som.custom_minimum_size.x=430
	info_som=rotulo(sons)
	var investigacao:=aba(abas,"Investigação")
	var linha_niveis:=HBoxContainer.new();investigacao.add_child(linha_niveis)
	for n in [1,2,3,4]:T.botao(linha_niveis,"Nível "+str(n),func():nivel(n),T.AZUL)
	T.botao(investigacao,"Encerrar teste de investigação",encerrar_investigacao)
	info_investigacao=rotulo(investigacao)
	var guardas:=aba(abas,"Seguranças")
	var linha_seg:=HBoxContainer.new();guardas.add_child(linha_seg)
	botao_rotas=T.botao(linha_seg,"Rotas",camada.queue_redraw,T.AZUL);botao_rotas.toggle_mode=true
	botao_visao=T.botao(linha_seg,"Campo de visão",camada.queue_redraw,T.AZUL);botao_visao.toggle_mode=true
	var linha_criar:=HBoxContainer.new();guardas.add_child(linha_criar)
	T.botao(linha_criar,"Criar segurança de teste",criar_seguranca,T.AZUL);T.botao(linha_criar,"Remover",remover_segurancas)
	info_segurancas=rotulo(guardas)
	var mapa:=aba(abas,"Mapa")
	var linha_mapa:=HBoxContainer.new();mapa.add_child(linha_mapa)
	botao_salas=T.botao(linha_mapa,"Salas automáticas",camada.queue_redraw,T.AZUL);botao_salas.toggle_mode=true
	botao_cameras=T.botao(linha_mapa,"Visão das câmeras",func():sujar_cameras();calcular_cameras();camada.queue_redraw(),T.AZUL);botao_cameras.toggle_mode=true
	var legenda:=T.texto(mapa,"Salas: cor da função, nome no centro, \"auto\" quando dividida sozinha e o número de pendências.\nCâmeras: azul claro = alcance total do giro · amarelo = o que ela vê agora · AO VIVO = assistida por um segurança.",12,T.SUAVE);legenda.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;legenda.custom_minimum_size.x=430
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
	for b in [botao_ruido,botao_rotas,botao_visao,botao_salas,botao_cameras]:b.set_pressed_no_signal(false)
	limpar_som();ruido.clear();visoes.clear();cameras_vistas.clear()
func avisar(texto:String) -> void:jogo.painel.mensagem(texto)
func ponto(c:Vector2) -> Vector2:return GradePlex.projetar(c,jogo.planta.altura(Vector2i(c.round()))+.6)
func segurancas() -> Array:
	return jogo.personagens.filter(func(a):return a.funcao=="seguranca" and not a.robo and a.visible and not a.visita.get("morto",false) and not a.visita.get("fora_turno",false))
func definir_saldo() -> void:
	jogo.servicos.saldo=snappedf(valor_saldo.value,.01);jogo.painel.hud.atualizar(1.0);avisar("Debug: saldo definido em $ %.2f."%jogo.servicos.saldo)

func sinal(origem:Vector2,c:Vector2,valor:float,queda:float,tipo:String="") -> float:
	return valor*jogo.sistemas.ambiencia.transmissao(origem,c,tipo)/(1.0+origem.distance_to(c)*queda)
func fundo(c:Vector2,fontes:Array) -> float:
	var valor:=0.0
	for f in fontes:
		if Vector2(f.p).distance_to(c)<=16:valor+=sinal(Vector2(f.p),c,float(f.forca),.22,str(f.tipo))
	return clampf(valor,0,1)
func calcular_ruido() -> void:
	ruido.clear()
	if not botao_ruido.button_pressed:return
	var fontes:Array=jogo.sistemas.ambiencia.fontes()
	for sala in jogo.ambientes.ambientes:
		if not sala.get("fechada",false):continue
		for c in sala.celulas:
			var valor:=fundo(Vector2(c),fontes)
			if valor>.02:ruido[c]=valor
func limpar_som() -> void:
	som.clear();ouvintes.clear();origem_som=Vector2i(-1,-1);escolhendo="";info_som.text="";camada.queue_redraw()
func emitir(origem:Vector2i) -> void:
	limpar_som();origem_som=origem
	var f:Array=FORCAS[forca.selected];var valor:float=f[1];var queda:float=f[2];var alcance:float=f[3]
	var fontes:Array=jogo.sistemas.ambiencia.fontes()
	for y in range(-int(alcance),int(alcance)+1):
		for x in range(-int(alcance),int(alcance)+1):
			var c:=origem+Vector2i(x,y)
			if Vector2(c).distance_to(Vector2(origem))>alcance or not GradePlex.dentro(c):continue
			var s:=sinal(Vector2(origem),Vector2(c),valor,queda,str(f[4]))
			if s>.01:som[c]=s-(fundo(Vector2(c),fontes)+.12)
	var linhas:=PackedStringArray();var total:=0;var ouviram:=0;var guardas:=0;var guardas_ouviram:=0
	for a in jogo.personagens:
		if a.robo or a.visita.get("morto",false) or not a.visible or a.local.distance_to(Vector2(origem))>alcance:continue
		var guarda:bool=a.funcao=="seguranca"
		var s:=sinal(Vector2(origem),a.local,valor,queda,str(f[4]));var nivel_fundo:=fundo(a.local,fontes)
		var limite:float=.12+nivel_fundo*.65 if guarda else nivel_fundo+.12
		var ouviu:bool=s>limite and (not guarda or a.local.distance_to(Vector2(origem))<=9)
		ouvintes.append({"ator":a,"ouviu":ouviu});total+=1;ouviram+=int(ouviu)
		if guarda:guardas+=1;guardas_ouviram+=int(ouviu)
		linhas.append("%s %s%s · força %d%% do necessário"%["SIM ·" if ouviu else "NÃO ·",IdentidadesPlex.completo(a)," (segurança)" if guarda else "",roundi(s/maxf(.01,limite)*100)])
	info_som.text="\"%s\" em %s\nOuviram: %d de %d · Seguranças: %d de %d"%[f[0],str(origem),ouviram,total,guardas_ouviram,guardas]+("" if linhas.is_empty() else "\n"+"\n".join(linhas.slice(0,6)))
	camada.queue_redraw()

func agora() -> float:return jogo.seguranca.agora()
func guardar_investigacao() -> void:
	var admin:PersonagemPlex=jogo.controle.administrador()
	original={"inv":jogo.sistemas.investigacao.gravar().duplicate(true),"seg":jogo.seguranca.gravar().duplicate(true),"velocidade":jogo.velocidade_tempo,"automatico":admin.automatico if is_instance_valid(admin) else false}
func encerrar_investigacao() -> void:
	if original.is_empty():return
	for e in jogo.seguranca.eventos:
		if not e.get("debug",false):continue
		var a:PersonagemPlex=jogo.clientes.ator(int(e.get("agente",-1)))
		if is_instance_valid(a):jogo.despawn(a)
	var preso:bool=jogo.seguranca.preso
	var admin:PersonagemPlex=jogo.controle.administrador()
	if is_instance_valid(admin) and admin.visita.get("preso",false):admin.visita.erase("preso");admin.trabalho="";admin.automatico=bool(original.automatico)
	jogo.sistemas.investigacao.restaurar(original.inv);jogo.seguranca.restaurar(original.seg)
	if preso:jogo.velocidade_tempo=maxf(1.0,float(original.velocidade))
	original.clear();info_investigacao.text="Teste de investigação encerrado."
func evento(tipo:String,multiplo:int=1) -> Dictionary:
	var id:int=jogo.seguranca.proximo
	while posmod(id,multiplo)!=0:id+=1
	jogo.seguranca.proximo=id+1
	var e:Dictionary={"id":id,"vitima":"debug:2","nome":"Pessoa de teste 2","cargo":"cliente","tipo":tipo,"quando":agora(),"fase":"aguardando","agente":-1,"pergunta":0,"respostas":[],"ultima_rota":-1.0,"debug":true}
	jogo.seguranca.eventos.push_front(e);return e
func nivel(n:int) -> void:
	encerrar_investigacao();guardar_investigacao()
	var inv:InvestigacaoProgressivaPlex=jogo.sistemas.investigacao
	inv.restaurar({})
	inv.relatar("debug:1","Pessoa de teste 1")
	if n==1:avisar("Debug · Nível 1: um desaparecimento relatado. A investigação só fica ativa no segundo.");return
	inv.relatar("debug:2","Pessoa de teste 2")
	if n==4:
		inv.pista("debug:mandado","Indícios de teste para o mandado",75.0)
		var p:=evento("policial");p.mandado=true
		avisar("Debug · Nível 4: mandado expedido. O policial vem prender o administrador; use \"Encerrar teste de investigação\" para desfazer.");return
	if n==3:inv.pista("debug:suspeita","Indícios de teste",45.0)
	var e:=evento("investigador",3 if n==3 else 1)
	if not jogo.seguranca.chegada(e):avisar("Debug: não há ponto de chegada para o investigador.");return
	var a:PersonagemPlex=jogo.clientes.ator(int(e.agente))
	if is_instance_valid(a):
		a.visita.debug_evento=true
		if n==3:a.visita.investigador_invasao=true
	avisar("Debug · Nível 2: investigação ativa. O investigador inspeciona o local e depois faz três perguntas." if n==2 else "Debug · Nível 3: o investigador invade áreas restritas e procura os registros. Seguranças podem flagrá-lo.")
func texto_investigacao() -> String:
	var inv:InvestigacaoProgressivaPlex=jogo.sistemas.investigacao
	var linhas:=PackedStringArray(["Desaparecidos: %d · Ativa: %s"%[inv.desaparecidos.size(),"sim" if inv.ativo() else "não"],"Suspeita: %d/100 · Pistas: %d · Gravações: %d"%[roundi(inv.suspeita),inv.pistas.size(),inv.gravacoes.size()]])
	for e in jogo.seguranca.eventos:
		if e.fase=="concluido":continue
		var a:PersonagemPlex=jogo.clientes.ator(int(e.get("agente",-1)))
		var extra:=""
		if is_instance_valid(a):
			extra=" · "+str(a.trabalho)
			if e.get("debug",false):a.visita.debug_evento=true
			if a.visita.get("investigador_invasao",false):extra+=" · INVASÃO"
			if a.visita.get("expulso",false):extra+=" · EXPULSO"
		if e.has("roteiro"):extra+=" · parada %d/%d"%[int(e.get("parada",0)),e.roteiro.size()]
		linhas.append("%s%s: %s%s"%["[DEBUG] " if e.get("debug",false) else "",str(e.tipo).capitalize(),str(e.fase),extra])
	for chave in inv.pistas.keys().slice(-3):linhas.append("· "+str(inv.pistas[chave].descricao))
	return "\n".join(linhas)

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

func sujar_cameras() -> void:cameras_sujo=true
func preparar_cameras() -> void:
	cameras_base.clear();cameras_sujo=false
	for o in jogo.planta.listar("cameras"):
		if not CamerasVigilanciaPlex.instalacao_permitida(jogo,o):continue
		var frente:=Vector2(GradePlex.frente(int(o.rotacao)));var origem:=Vector2(o.celula)+frente
		var perto:Array=[];var total:Array=[]
		for y in range(-9,10):
			for x in range(-9,10):
				var c:Vector2i=o.celula+Vector2i(x,y)
				if not GradePlex.dentro(c) or jogo.sistemas.investigacao.nome_sala(c)=="banheiro":continue
				var vetor:=Vector2(c)-origem
				if vetor.length()>9.0:continue
				perto.append(c)
				if vetor.length()<=8.0 and (vetor.length()<.5 or frente.dot(vetor.normalized())>=cos(deg_to_rad(85.0))) and VisaoNPCPlex.linha(jogo.planta,origem,Vector2(c)):total.append(c)
		cameras_base[int(o.id)]={"perto":perto,"total":total}
func calcular_cameras() -> void:
	cameras_vistas.clear()
	if not botao_cameras.button_pressed:return
	if cameras_sujo:preparar_cameras()
	for id in cameras_base:
		var o:Dictionary=jogo.planta.objetos.get(id,{})
		if o.is_empty() or not CamerasVigilanciaPlex.ligada(o,jogo.iluminacao.rede.fator):continue
		var lente:=CamerasVigilanciaPlex.lente(o);var frente:=CamerasVigilanciaPlex.frente(o)
		var agora_ve:Dictionary={}
		for c in cameras_base[id].perto:
			if VisaoNPCPlex.cone(jogo.planta,lente,frente,Vector2(c),8,84):agora_ve[c]=true
		var total:Array=cameras_base[id].total.filter(func(c):return not agora_ve.has(c))
		cameras_vistas[id]={"total":total,"agora":agora_ve.keys(),"lente":lente,"nome":str(o.get("camera_nome","Câmera")),"vigiada":jogo.sistemas.guarda.camera_vigiada(id)}
func desenhar_salas() -> void:
	for sala in jogo.ambientes.ambientes:
		if not sala.get("fechada",false) and str(sala.tipo)=="livre":continue
		var definicao:Dictionary=jogo.ambientes.definicoes.get(str(sala.tipo),{})
		var cor:=Color(str(definicao.get("cor","#8a8a8a")))
		var centro:=Vector2.ZERO
		for c in sala.celulas:
			centro+=Vector2(c)
			var poli:=GradePlex.poligono(ponto(Vector2(c)))
			camada.draw_colored_polygon(poli,Color(cor,.2))
			for i in 4:
				var vizinha:Vector2i=c+[Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)][i]
				if not sala.celulas.has(vizinha):camada.draw_line(poli[i],poli[(i+1)%4],Color(cor,.9),2)
		if sala.celulas.is_empty():continue
		centro/=float(sala.celulas.size())
		var nome:=str(definicao.get("nome","Área livre"))+(" · auto" if sala.get("automatica",false) else "")
		var faltas:Array=sala.get("faltas",[])
		if not faltas.is_empty():nome+=" · %d pendência(s)"%faltas.size()
		if not sala.get("fechada",false):nome+=" · aberta"
		var p:=ponto(centro)
		camada.draw_rect(Rect2(p+Vector2(-80,-14),Vector2(160,18)),Color(0,0,0,.55))
		camada.draw_string(ThemeDB.fallback_font,p+Vector2(-80,0),nome,HORIZONTAL_ALIGNMENT_CENTER,160,12,Color.WHITE)
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
	espera+=delta;espera_ruido+=delta;espera_cameras+=delta;tempo+=delta
	if espera_cameras>=.5:espera_cameras=0.0;calcular_cameras()
	if espera_ruido>=1.5:espera_ruido=0.0;calcular_ruido()
	if not som.is_empty() or escolhendo=="robo":camada.queue_redraw()
	if espera<.25:return
	espera=0.0;calcular_visoes()
	if botao_rotas.button_pressed:jogo.rondas.atualizar_pontos()
	for a in jogo.personagens:
		if a.visita.get("debug_robo",false):a.robotica.bateria=100.0
	info_investigacao.text=texto_investigacao();info_segurancas.text=texto_segurancas();info_geral.text=jogo.desempenho.resumo()
	camada.queue_redraw()

func _input(e:InputEvent) -> void:
	if not aberto() or escolhendo.is_empty():return
	if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT and not jogo.painel.bloqueia_mouse(e.position):
		if escolhendo=="som":emitir(jogo.apontada())
		elif escolhendo.begins_with("gore"):GorePlex.espalhar(jogo,jogo.apontada(),escolhendo.trim_prefix("gore").to_int());escolhendo="";jogo.planta.alterada.emit()
		else:colocar_robo(jogo.apontada())
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_RIGHT:
		escolhendo="";get_viewport().set_input_as_handled()
	elif escolhendo=="robo" and e is InputEventKey and e.pressed and not e.echo and e.keycode==KEY_R:
		robo_rotacao=posmod(robo_rotacao+1,4);get_viewport().set_input_as_handled()

func cor_intensidade(v:float) -> Color:
	return Color("4f7fb8").lerp(Color("e3c54f"),clampf(v*2,0,1)) if v<.5 else Color("e3c54f").lerp(Color("d54b40"),clampf((v-.5)*2,0,1))
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
	for c in ruido:tile(c,Color(cor_intensidade(float(ruido[c])),.18+float(ruido[c])*.4))
	for c in som:
		var margem:float=som[c]
		if margem>0:tile(c,Color(Color("e39843").lerp(Color("d54b40"),clampf(margem*3,0,1)),.3+clampf(margem*3,0,1)*.35))
		elif margem>-.12:tile(c,Color("4f7fb8",.22))
	if origem_som.x>=0:
		var centro:=ponto(Vector2(origem_som))
		for i in 3:camada.draw_arc(centro,fmod(tempo*40+i*20,60),0,TAU,32,Color(1,.85,.5,1.0-fmod(tempo*40+i*20,60)/60.0),2)
	for o in ouvintes:
		var a=o.ator
		if not is_instance_valid(a):continue
		var cor:=Color("6cb58b") if o.ouviu else Color("d54b40")
		camada.draw_arc(ponto(a.local),14,0,TAU,24,cor,2)
		camada.draw_string(ThemeDB.fallback_font,ponto(a.local)+Vector2(-60,-62),"OUVIU" if o.ouviu else "não ouviu",HORIZONTAL_ALIGNMENT_CENTER,120,11,cor)
	for id in visoes:
		for c in visoes[id]:tile(c,Color(1,.92,.55,.22))
	for id in cameras_vistas:
		var v:Dictionary=cameras_vistas[id]
		for c in v.total:tile(c,Color(.55,.8,.95,.12))
		for c in v.agora:tile(c,Color(1,.85,.35,.3))
		var lente:=ponto(v.lente)
		camada.draw_circle(lente,4,Color("dfb16a") if v.vigiada else Color("75aaa8"))
		camada.draw_string(ThemeDB.fallback_font,lente+Vector2(-70,-10),v.nome+(" · AO VIVO" if v.vigiada else ""),HORIZONTAL_ALIGNMENT_CENTER,140,11,Color("dfb16a") if v.vigiada else Color("b7cacb"))
	if botao_salas.button_pressed:desenhar_salas()
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

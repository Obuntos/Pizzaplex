class_name DiagnosticoRobosPlex
extends CanvasLayer

const T=preload("res://scripts/interface/tema_hud.gd")
var jogo:Node
var raiz:=Control.new()
var janela:=PanelContainer.new()
var robos:=OptionButton.new()
var animacoes:=OptionButton.new()
var resumo:=Label.new()
var caminho:=Label.new()
var painel:=-1
var alvo:=-1
var inicio:Array=[]
var fim:Array=[]
var escolhendo:=""
func configurar(cena:Node) -> void:
	jogo=cena;layer=120;add_child(raiz);raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raiz.mouse_filter=Control.MOUSE_FILTER_IGNORE
	raiz.add_child(janela);janela.theme=T.criar();janela.add_theme_stylebox_override("panel",KitPlex.moldura("janela_escura",16))
	var col:=VBoxContainer.new();col.custom_minimum_size.x=470;col.add_theme_constant_override("separation",12);janela.add_child(col)
	var topo:=T.cabecalho(col,"PAINEL DE DIAGNÓSTICO","gestao");T.botao(topo,"×",fechar)
	col.add_child(robos);robos.item_selected.connect(func(i):selecionar(int(robos.get_item_metadata(i))))
	col.add_child(resumo);resumo.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	col.add_child(animacoes);T.botao(col,"Repetir animação",testar)
	var row:=HBoxContainer.new();col.add_child(row);T.botao(row,"Definir início",func():escolhendo="inicio";janela.hide());T.botao(row,"Definir fim",func():escolhendo="fim";janela.hide())
	col.add_child(caminho);T.botao(col,"Testar caminhada · ida e volta",andar);T.botao(col,"Parar teste",parar)
	jogo.janelas_moveis.registrar(janela,fechar,64);get_viewport().size_changed.connect(centralizar);raiz.hide()
func aberto() -> bool:return raiz.visible
func centralizar() -> void:
	janela.reset_size();JanelasMoveisPlex.centralizar(janela,get_viewport().get_visible_rect().size)
func abrir(id:int) -> void:
	painel=id;robos.clear();alvo=-1;inicio=[];fim=[];escolhendo=""
	var p:Dictionary=jogo.planta.objetos.get(id,{})
	if p.get("tipo","")!="amb_painel_diagnostico":return
	var sala:Dictionary=jogo.ambientes.do_objeto(id)
	for r in jogo.personagens:
		if not r.robo or not AtracoesCatalogoPlex.permitido(r.modelo) or r.visita.get("montando_atracao",false):continue
		if jogo.ambientes.em(r.celula).get("id",-1)!=sala.get("id",-2) and r.local.distance_to(Vector2(p.celula))>8:continue
		robos.add_item(IdentidadesPlex.completo(r));robos.set_item_metadata(robos.item_count-1,r.identificador)
	if robos.item_count>0:selecionar(int(robos.get_item_metadata(0)))
	else:resumo.text="Nenhum robô disponível nesta sala.";animacoes.clear()
	raiz.show();janela.show();centralizar.call_deferred();atualizar_caminho()
func selecionar(id:int) -> void:
	parar();alvo=id;animacoes.clear();ClipesPlex.carregar()
	var r:PersonagemPlex=jogo.clientes.ator(id)
	if not is_instance_valid(r):return
	var clipes:Dictionary=ClipesPlex.modelos.get(r.modelo,{}).get("clipes",{})
	var nomes:Dictionary={"parado":"Ligado","andar":"Andar","cantar":"Cantar","dancar":"Dançar","ativando":"Ligar","desligando":"Desligar","desligado":"Desligar","cantar_possuido":"Possuído","andar_possuido":"Andar possuído"}
	var vistos:Dictionary={}
	for nome in ["parado","andar","cantar","dancar","ativando","desligando","desligado","cantar_possuido","andar_possuido"]:
		if not clipes.has(nome) or vistos.has(nomes[nome]):continue
		var clip:Dictionary=clipes[nome]
		var assinatura:=str([clip.get("pasta",""),clip.get("quadros",clip.get("frames",0)),clip.get("colunas",0)])
		if vistos.has(assinatura):continue
		vistos[assinatura]=true;vistos[nomes[nome]]=true
		animacoes.add_item(nomes[nome]);animacoes.set_item_metadata(animacoes.item_count-1,nome)
	resumo.text="Funcional: %d%% · Bateria: %d%%\nEscolha uma animação ou dois pontos do percurso."%[OficinaRobosPlex.funcional(r),roundi(float(r.robotica.get("bateria",100)))]
func pronto() -> PersonagemPlex:
	var r:PersonagemPlex=jogo.clientes.ator(alvo)
	if not is_instance_valid(r) or float(r.robotica.get("bateria",100))<=0 or jogo.iluminacao.rede.fator<=.05:return null
	var d:Dictionary=r.visita.get("oficina_robo",{})
	if not d.is_empty() and d.get("etapa","")!="estacionado":return null
	return r
func testar() -> void:
	var r:=pronto()
	if not is_instance_valid(r) or animacoes.item_count==0:return
	jogo.oficina.liberar_palco(r);r.movimento.cancelar();r.visita.erase("diagnostico_rota");r.visita.diagnostico_animacao=str(animacoes.get_item_metadata(animacoes.selected));r.visita.diagnostico_tempo=0.0;r.trabalho="teste_diagnostico"
func andar() -> void:
	var r:=pronto()
	if not is_instance_valid(r) or inicio.size()!=2 or fim.size()!=2:return
	var primeiro:=Vector2i(inicio[0],inicio[1]);var ultimo:=Vector2i(fim[0],fim[1])
	var rota:Array[Vector2i]=jogo.rotas.caminho(r.origem_rota(),primeiro)
	if primeiro==ultimo or rota.is_empty() or jogo.rotas.caminho(primeiro,ultimo).is_empty():resumo.text="Os dois pontos precisam ter um caminho livre entre eles.";return
	jogo.oficina.liberar_palco(r);r.visita.erase("diagnostico_animacao");r.visita.diagnostico_rota={"inicio":inicio.duplicate(),"fim":fim.duplicate(),"ida":true};r.andar(rota);r.trabalho="teste_diagnostico"
func parar() -> void:
	var r:PersonagemPlex=jogo.clientes.ator(alvo)
	if not is_instance_valid(r) or not r.visita.has("diagnostico_animacao") and not r.visita.has("diagnostico_rota"):return
	r.visita.erase("diagnostico_animacao");r.visita.erase("diagnostico_rota");r.movimento.cancelar();r.robotica.desligado_manual=true;AnimatronicosPlex.mudar(r,"desligado")
	if r.visita.has("oficina_robo"):r.visita.oficina_robo.etapa="indo"
	elif int(r.visita.get("palco_anterior",-1))>=0:jogo.oficina.voltar(r)
func fechar() -> void:parar();escolhendo="";raiz.hide()
func atualizar_caminho() -> void:caminho.text="Início: %s · Fim: %s"%[str(inicio) if inicio.size()==2 else "—",str(fim) if fim.size()==2 else "—"]
func _input(e:InputEvent) -> void:
	if not aberto():return
	if e is InputEventKey and e.pressed and e.keycode==KEY_ESCAPE:fechar();get_viewport().set_input_as_handled()
	elif not escolhendo.is_empty() and e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:
		var c:Vector2i=jogo.apontada()
		if TerrenoPlex.contem(jogo.planta,c) and jogo.planta.transitavel(c):
			if escolhendo=="inicio":inicio=[c.x,c.y]
			else:fim=[c.x,c.y]
			escolhendo="";janela.show();atualizar_caminho();centralizar.call_deferred()
		get_viewport().set_input_as_handled()

class_name TutorialBonniePlex
extends CanvasLayer

const T=preload("res://scripts/interface/tema_hud.gd")
const INTRO=[
	"UWAAAH! Esse lugar está podre... Mas tudo bem!",
	"Acredito que você vá conseguir fazer esse restaurante dar certo! Bem, como ele vai precisar de alguns cuidados, acho que posso te ajudar!",
	"Seria bom você comprar uma lixeira... Em Catálogo, você pode comprar uma lixeira! Mas, para isso, é bom sempre ter um armário de limpeza...",
	"O que é bom, já que já temos isso... Então, compre só a lixeira mesmo, hehehe!",
	"Bem, temos o simples: R gira o item. Alguns itens precisam de espaço, nos dando liberdade para usá-los. Evite colocar algum obstáculo na frente...",
	"Eu vou ficar para te dar uma mãozinha, que tal?! Hein... Hein... Hein..."
]
const EQUIPE=[
	"Seu primeiro funcionário chegou! No painel da equipe você escolhe a função e acompanha as necessidades de cada pessoa.",
	"O ciclo alterna trabalho e descanso. Quando a energia da pessoa baixa, ela precisa descansar. Prepare uma sala de descanso com cadeiras e acesso livre.",
	"Deixe o vestiário e o relógio de ponto acessíveis: a equipe veste o uniforme antes de bater a entrada e bate a saída antes de tirá-lo.",
	"A energia do prédio vem do gerador. Mantenha combustível e uma caixa de energia por perto para religá-lo. Feche as salas com paredes e portas e defina a função de cada ambiente."
]
var jogo:Node
var fase:=""
var assunto:=""
var indice:=0
var falas:Array=[]
var intro_concluida:=true
var equipe_concluida:=false
var equipe_pendente:=false
var retomar:=""
var retomar_indice:=0
var bonnie_id:=-1
var criada:=false
var entrada:Dictionary={}
var destino_admin:=Vector2i(-1,-1)
var destino_bonnie:=Vector2i(-1,-1)
var inicio_bonnie:Array[Vector2i]=[]
var tempo:=0.0
var destino_saida:=Vector2i(-1,-1)
var espera_saida:=0.0
var sumindo:=0.0
var admin_automatico:=true
var bonnie_automatico:=true
var camera_anterior:=Vector2.ZERO
var zoom_anterior:=Vector2.ONE
var raiz:=Control.new()
var painel:=DialogoBonniePlex.new()
var texto:RichTextLabel
var passo:Label
var destaque:=DestaqueTutorialPlex.new()
var tarefas:TarefasTutorialPlex
var etapa:=""
var depois_fala:=""
var humor:="feliz"
var aceita:=false
var ids:Dictionary={}
var existentes:Array=[]
var parede_alvo:Dictionary={}
var tempo_etapa:=0.0
var espera_tarefa:=0.0
var retomada:Dictionary={}
var compra_id:=-1
var faca_alertada:=false
var espera_visao:=0.0
func configurar(cena:Node) -> void:
	jogo=cena;layer=220;tarefas=TarefasTutorialPlex.new(jogo);add_child(raiz);raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raiz.mouse_filter=Control.MOUSE_FILTER_IGNORE;raiz.theme=T.criar()
	raiz.add_child(destaque);raiz.add_child(painel);texto=painel.texto;passo=painel.passo;painel.escolha.connect(responder)
	get_viewport().size_changed.connect(posicionar_painel);painel.hide();destaque.hide();raiz.hide()
func bloqueia() -> bool:return fase in ["aguardando","entrada","fala","escolha"]
func admin() -> PersonagemPlex:return jogo.controle.administrador()
func bonnie() -> PersonagemPlex:return jogo.clientes.ator(bonnie_id)
func posicionar_painel() -> void:
	var tela:=get_viewport().get_visible_rect().size
	painel.size=Vector2(minf(760,maxf(300,tela.x-32)),222);painel.position=Vector2((tela.x-painel.size.x)*.5,maxf(12,tela.y-painel.size.y-24)).round()
func porta_entrada(a:PersonagemPlex) -> Dictionary:
	var portas:=ChegadasEquipePlex.entradas(jogo)
	portas.sort_custom(func(x,y):return Vector2(x.dentro).distance_squared_to(a.local)<Vector2(y.dentro).distance_squared_to(a.local))
	for p in portas:
		if jogo.planta.transitavel(p.dentro) and not jogo.rotas.caminho(p.fora,p.dentro).is_empty():return p
	return {}
func obter_bonnie(c:Vector2i) -> PersonagemPlex:
	for a in jogo.personagens:
		if BonnieSemanalPlex.eh(a) and a.visible and not a.visita.get("morto",false):criada=false;bonnie_id=a.identificador;return a
	var a:PersonagemPlex=jogo.criar_personagem(BonnieSemanalPlex.MODELO,c,"tutorial",true,{})
	a.identidade={"nome":"Bonnie","sobrenome":"","apelido":"","idade":24,"sexo":"feminino"};a.cabelo="nenhum";a.uniforme="nenhum";a.visita.bonnie_unica=true;a.visita.tutorial_guia=true;a.automatico=false;a.atualizar_visual(false);criada=true;bonnie_id=a.identificador;return a
func guardar_atores(a:PersonagemPlex,b:PersonagemPlex) -> void:
	admin_automatico=a.automatico;bonnie_automatico=b.automatico;a.visita.tutorial_automatico=a.automatico;b.visita.tutorial_automatico=b.automatico;a.automatico=false;b.automatico=false;a.visita.tutorial_ativo=true;b.visita.tutorial_ativo=true;b.visita.tutorial_servico=true;b.visita.humor_cliente="feliz"
	camera_anterior=jogo.camera.position;zoom_anterior=jogo.camera.zoom
func perto_livre(c:Vector2i,excluir:Vector2i) -> Vector2i:
	for raio in [1,2,3]:
		for d in GradePlex.VIZINHOS:
			var p:Vector2i=c+d*raio
			if p!=excluir and jogo.planta.transitavel(p) and not jogo.rotas.caminho(c,p).is_empty() and not jogo.personagens.any(func(a):return a.celula==p):return p
	return excluir
func preparar_intro(a:PersonagemPlex) -> void:
	limpar();intro_concluida=false;equipe_concluida=false;equipe_pendente=false;assunto="intro";indice=0;falas=paginar(INTRO);depois_fala="escolher";entrada=porta_entrada(a)
	var origem:Vector2i=entrada.get("fora",a.celula)
	var atras:Vector2i=origem+entrada.get("frente",Vector2i(1,0))
	if not jogo.planta.transitavel(atras):atras=perto_livre(origem,a.celula)
	var b:=obter_bonnie(atras);guardar_atores(a,b);a.movimento.cancelar();b.movimento.cancelar()
	if not entrada.is_empty():
		a.celula=origem;a.local=Vector2(origem);destino_bonnie=entrada.dentro;destino_admin=perto_livre(destino_bonnie,origem)
		if destino_admin==origem:destino_admin=destino_bonnie;destino_bonnie=perto_livre(destino_admin,atras)
	else:destino_admin=a.celula;destino_bonnie=perto_livre(a.celula,b.celula)
	a.andar(jogo.rotas.caminho(a.celula,destino_admin));inicio_bonnie=jogo.rotas.caminho(b.celula,destino_bonnie)
	fase="aguardando";tempo=0.0
func iniciar_intro() -> void:
	if fase!="aguardando":return
	fase="entrada";tempo=0.0;focar()
func contratado() -> void:
	if not equipe_concluida:equipe_pendente=true
func iniciar_equipe() -> void:
	var a:=admin()
	if not is_instance_valid(a):return
	equipe_pendente=false;assunto="equipe";falas=paginar(EQUIPE);depois_fala="sair";indice=0;entrada=porta_entrada(a)
	var origem:Vector2i=entrada.get("fora",perto_livre(a.celula,a.celula))
	var b:=obter_bonnie(origem);guardar_atores(a,b);b.movimento.cancelar()
	destino_admin=a.celula;destino_bonnie=perto_livre(a.celula,b.celula);inicio_bonnie=jogo.rotas.caminho(b.origem_rota(),destino_bonnie)
	b.andar(inicio_bonnie);inicio_bonnie=[];fase="entrada";tempo=0.0
func focar() -> void:
	var a:=admin();var b:=bonnie()
	if is_instance_valid(a) and is_instance_valid(b):jogo.camera.position=GradePlex.projetar((a.local+b.local)*.5)
func simular(delta:float) -> void:
	if not bloqueia() or fase=="aguardando":return
	var a:=admin();var b:=bonnie()
	if not is_instance_valid(a) or not is_instance_valid(b):terminar();return
	if fase in ["fala","escolha"]:
		for ator in [a,b]:
			ator.relogio+=delta;ator.atualizar_visual(false);jogo.composicao.atualizar_personagem(ator)
		return
	tempo+=delta
	if tempo>=.65 and not inicio_bonnie.is_empty():b.andar(inicio_bonnie);inicio_bonnie=[]
	jogo.portas.atualizar(delta,jogo.planta,[a,b])
	for ator in [a,b]:
		ator.atualizar(delta,jogo.planta,jogo.rotas,jogo.personagens);jogo.composicao.atualizar_personagem(ator)
	for sombra in jogo.sombras_luzes.get_children():sombra.atualizar(delta)
	focar()
	if not a.ocupado() and not b.ocupado() and inicio_bonnie.is_empty():mostrar_fala()
func mostrar_fala() -> void:
	fase="fala";jogo.menu_controle.fechar();raiz.show();destaque.hide();painel.mostrar(str(falas[clampi(indice,0,falas.size()-1)]),humor);posicionar_painel()
	var a:=admin();var b:=bonnie()
	if is_instance_valid(a) and is_instance_valid(b):
		preparar_fala(a);preparar_fala(b);definir_humor(humor)
		jogo.tarefas.orientar(a,b.local);jogo.tarefas.orientar(b,a.local)
		for ator in [a,b]:ator.atualizar_visual(false);jogo.composicao.atualizar_personagem(ator)
func entrada_evento(e:InputEvent) -> bool:
	if jogo.painel.hud.menu_aberto():return false
	if e is InputEventKey and e.keycode==KEY_ESCAPE:return false
	if bloqueia():
		if fase=="escolha" and e is InputEventMouse and painel.get_global_rect().has_point(e.position):return false
		if fase=="escolha" and e is InputEventKey and e.keycode in [KEY_TAB,KEY_ENTER,KEY_KP_ENTER,KEY_LEFT,KEY_RIGHT]:return false
		if fase=="fala" and e is InputEventKey and e.pressed and not e.echo and e.keycode==KEY_SPACE:
			if not painel.completar():avancar()
		return true
	if fase not in ["guiado","cena"]:return false
	if e is InputEventKey:
		if e.keycode in [KEY_R,KEY_A,KEY_S,KEY_D,KEY_W,KEY_CTRL,KEY_SPACE]:return false
		return true
	if e is InputEventMouseButton and e.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_MIDDLE,MOUSE_BUTTON_RIGHT]:return false
	if e is InputEventMouse:return not destaque.permite(e.position)
	return false
func avancar() -> void:
	if fase!="fala":return
	indice+=1
	if indice<falas.size():mostrar_fala();return
	if assunto!="intro":terminar();return
	match depois_fala:
		"escolher":
			fase="escolha";painel.mostrar("Eu vou ficar para te dar uma mãozinha, que tal?!", "feliz",true);posicionar_painel();painel.sim.grab_focus()
		"sair":terminar()
		"lixeira":comprar_item("lixeira")
		"limpar":mudar_etapa("limpar_primeiro","cena")
		"demolir":jogo.painel.hud.catalogo.painel.hide();jogo.escolher_ferramenta("selecionar");mudar_etapa("demolir_ferramenta")
		"computador":comprar_item("ibm")
		"ventilar":comprar_item("vent")
		"mercado":mudar_etapa("ibm_abrir")
		"recebimento":comprar_item("receb")
		"estante":comprar_item("estante")
func terminar_fala(linhas:Array,proxima:String,expressao:String="feliz") -> void:
	falas=paginar(linhas);indice=0;depois_fala=proxima;humor=expressao;mostrar_fala()
func paginar(linhas:Array) -> Array:
	var resultado:Array=[]
	for linha in linhas:
		var pagina:=""
		for palavra in IdiomaPlex.traduzir(str(linha)).replace("{player}",nome_player()).split(" "):
			if pagina.length()+palavra.length()>175:resultado.append(pagina);pagina=""
			pagina+=(" " if not pagina.is_empty() else "")+palavra
		if not pagina.is_empty():resultado.append(pagina)
	return resultado
func nome_player() -> String:
	var a:=admin()
	return str(a.identidade.get("nome","")) if is_instance_valid(a) and not str(a.identidade.get("nome","")).is_empty() else "chefe"
func responder(sim:bool) -> void:
	if fase!="escolha":return
	aceita=sim
	if sim:comprar_item("lixeira")
	else:terminar_fala(["Augh, você mata meu pobre coraçãozinho, {player}!! Mas okay! Eu vou voltar de vez em quando para ajudar quando precisar e, claro, comer pizza grátis, hehehehe!"],"sair")
func definir_humor(valor:String) -> void:
	humor=valor;var b:=bonnie()
	if is_instance_valid(b):b.visita.humor_cliente=valor;b.animacao.expressao=valor
func terminar() -> void:
	raiz.hide();destaque.hide();etapa="";tarefas.guardar_ferramentas();var a:=admin();var b:=bonnie()
	if is_instance_valid(a):a.automatico=admin_automatico;a.visita.erase("tutorial_automatico");a.visita.erase("tutorial_ativo")
	if assunto=="intro":intro_concluida=true
	elif assunto=="equipe":equipe_concluida=true
	if is_instance_valid(b):
		b.automatico=bonnie_automatico;b.visita.erase("tutorial_automatico");b.visita.erase("tutorial_ativo");b.visita.erase("tutorial_servico")
		if criada:
			b.automatico=false;b.visita.tutorial_saindo=true;b.trabalho="sair_tutorial";fase="saindo";espera_saida=0.0;sumindo=0.0
			destino_saida=ChegadasEquipePlex.destino_saida(jogo,b)
			if destino_saida.x>=0:b.andar(jogo.rotas.caminho(b.origem_rota(),destino_saida))
		else:fase=""
	else:fase=""
	if assunto!="faca":jogo.camera.position=camera_anterior;jogo.camera.zoom=zoom_anterior
	jogo.sistemas.bonnie.proximo_dia=maxi(jogo.sistemas.bonnie.proximo_dia,jogo.calendario.dias+7)
	assunto=""
func observar_faca() -> void:
	var a:=admin()
	if not is_instance_valid(a):return
	if not a.visita.get("faca_equipada",false):faca_alertada=false;return
	if faca_alertada:return
	for b in jogo.personagens:
		if BonnieSemanalPlex.eh(b) and VisaoNPCPlex.ve(jogo,b,a):
			faca_alertada=true;bonnie_id=b.identificador;criada=false;guardar_atores(a,b);assunto="faca";humor="incomodado";falas=["Cuidado com essa faca! Andar por aí com ela na mão é perigoso e pode parecer suspeito. Melhor guardá-la quando não estiver usando."];indice=0;mostrar_fala();return
func _process(delta:float) -> void:
	if jogo==null or not is_instance_valid(jogo.controle):return
	if fase in ["guiado","cena"]:
		tempo_etapa+=delta;espera_tarefa+=delta
		atualizar_guia(delta);atualizar_destaque();return
	if fase=="saindo":
		var b:=bonnie()
		if not is_instance_valid(b):fase="";return
		if ChegadasEquipePlex.pode_sumir(jogo,b):
			sumindo+=delta;b.modulate.a=1.0-smoothstep(0.0,.6,sumindo)
			if sumindo>=.6:jogo.despawn(b);fase=""
			return
		espera_saida+=delta
		if not b.ocupado() and espera_saida>=1.0:
			espera_saida=0.0;destino_saida=ChegadasEquipePlex.destino_saida(jogo,b)
			if destino_saida.x>=0:b.andar(jogo.rotas.caminho(b.origem_rota(),destino_saida))
		return
	if not fase.is_empty():return
	if not retomada.is_empty():retomar_guia();return
	if not retomar.is_empty():
		var salvo:=retomar;retomar=""
		if salvo=="intro":preparar_intro(admin());iniciar_intro()
		else:iniciar_equipe()
		indice=retomar_indice;return
	if equipe_pendente and intro_concluida:
		if jogo.terminal_ui.aberto() or jogo.carteira.aberto() or jogo.painel.hud.menu_aberto() or jogo.atracoes.minigame_aberto():return
		iniciar_equipe();return
	espera_visao+=delta
	if espera_visao>=.5:espera_visao=0.0;observar_faca()
func limpar() -> void:
	if tarefas!=null:tarefas.guardar_ferramentas()
	raiz.hide();destaque.hide();fase="";assunto="";etapa="";destino_saida=Vector2i(-1,-1);sumindo=0.0;inicio_bonnie=[];retomar="";retomada={};bonnie_id=-1;criada=false;ids={};existentes=[];aceita=false;parede_alvo={};compra_id=-1;humor="feliz"
	if jogo==null:return
	for a in jogo.personagens.duplicate():
		if a.visita.has("tutorial_automatico"):a.automatico=bool(a.visita.tutorial_automatico);a.visita.erase("tutorial_automatico")
		a.visita.erase("tutorial_ativo");a.visita.erase("tutorial_servico")
		if a.visita.get("tutorial_guia",false):jogo.despawn(a)
func gravar() -> Dictionary:
	var guia:Dictionary={}
	if assunto=="intro" and not fase.is_empty() and fase!="saindo":
		var b:=bonnie();var c:=b.celula if is_instance_valid(b) else Vector2i.ZERO
		guia={"fase":fase,"etapa":etapa,"aceita":aceita,"ids":ids.duplicate(),"existentes":existentes.duplicate(),"compra":compra_id,"rotacao":jogo.editor.rotacao,"falas":falas.duplicate(),"indice":indice,"depois":depois_fala,"humor":humor,"bonnie":[c.x,c.y],"parede":int(parede_alvo.get("id",-1)),"olhar":[parede_alvo.get("olhar",Vector2i(-1,-1)).x,parede_alvo.get("olhar",Vector2i(-1,-1)).y],"admin_auto":admin_automatico,"bonnie_auto":bonnie_automatico}
	return {"intro":intro_concluida,"equipe":equipe_concluida,"equipe_pendente":equipe_pendente,"retomar":assunto if bloqueia() and assunto=="equipe" else "","indice":indice,"faca_alertada":faca_alertada,"guia":guia}
func restaurar(d:Dictionary) -> void:
	limpar();intro_concluida=bool(d.get("intro",true));equipe_concluida=bool(d.get("equipe",false));equipe_pendente=bool(d.get("equipe_pendente",false));retomar=str(d.get("retomar",""));retomar_indice=int(d.get("indice",0));faca_alertada=bool(d.get("faca_alertada",false));retomada=d.get("guia",{}).duplicate(true)
	if retomar=="intro" and retomada.is_empty():retomada={"fase":"entrada","etapa":"","falas":paginar(INTRO),"depois":"escolher"};retomar=""
func retomar_guia() -> void:
	var d:=retomada.duplicate(true);retomada={};var a:=admin()
	if not is_instance_valid(a):retomada=d;return
	var c:Array=d.get("bonnie",[a.celula.x,a.celula.y]);var origem:=Vector2i(c[0],c[1])
	if not jogo.planta.transitavel(origem):origem=perto_livre(a.celula,a.celula)
	var b:=obter_bonnie(origem);guardar_atores(a,b);admin_automatico=bool(d.get("admin_auto",true));bonnie_automatico=bool(d.get("bonnie_auto",true));assunto="intro";aceita=bool(d.get("aceita",false));etapa=str(d.get("etapa",""));ids=d.get("ids",{}).duplicate();existentes=d.get("existentes",[]).duplicate();compra_id=int(d.get("compra",-1));falas=d.get("falas",paginar(INTRO)).duplicate();indice=clampi(int(d.get("indice",0)),0,maxi(0,falas.size()-1));depois_fala=str(d.get("depois","escolher"));humor=str(d.get("humor","feliz"));fase=str(d.get("fase","guiado"));tempo_etapa=0;espera_tarefa=0
	for k in ids:ids[k]=int(ids[k])
	var id_parede:=int(d.get("parede",-1))
	if jogo.planta.objetos.has(id_parede):parede_alvo={"id":id_parede,"celula":jogo.planta.objetos[id_parede].celula,"olhar":Vector2i(int(d.get("olhar",[-1,-1])[0]),int(d.get("olhar",[-1,-1])[1]))}
	definir_humor(humor);raiz.show()
	if fase in ["entrada","aguardando"]:mostrar_fala()
	elif fase=="fala":mostrar_fala()
	elif fase=="escolha":painel.mostrar("Eu vou ficar para te dar uma mãozinha, que tal?!","feliz",true);posicionar_painel()
	else:
		painel.hide();destaque.show()
		if etapa.ends_with("_por"):
			var compra:=dados_compra(etapa.trim_suffix("_por"))
			if not compra.is_empty():jogo.escolher_ferramenta(compra.tipo);jogo.editor.rotacao=int(d.get("rotacao",0))
		elif etapa in ["demolir_parede","demolir_buracos"]:jogo.escolher_ferramenta("remover")
		if etapa=="parede_andar" and parede_alvo.get("olhar",Vector2i(-1,-1)).x>=0:aandar(b,parede_alvo.olhar)
		elif etapa=="ibm_entrada":posicionado("ibm")
func preparar_fala(ator:PersonagemPlex) -> void:
	if ator.modelo not in ["humano","humana"]:return
	PosesHumanasPlex.carregar()
	var uniforme:=AparenciaPlex.roupa(ator)
	if not PosesHumanasPlex.dados.uniformes.has(uniforme):uniforme="nenhum"
	var acao:=ator.poses_humanas.selecionar(ator,false)
	var pasta:="res://assets/poses_humanas/"+uniforme+"/"+ator.modelo+"/"
	var arquivos:Array=[acao+"_corpo.png",acao+"_bracos.png",acao+"_maos.png"]
	if acao in ["carregar_faca","matar"]:arquivos=[acao+"_repouso_integrado.png"]
	for arquivo in arquivos:
		if ResourceLoader.exists(pasta+arquivo):CatalogoPlex.textura_iluminada(pasta+arquivo)

func dados_compra(chave:String) -> Dictionary:
	return {"lixeira":{"tipo":"antigo_barril_escuro","aba":"Limpeza"},"ibm":{"tipo":"terminal_ibm","aba":"Escritório"},"vent":{"tipo":"oficina_duto_grade","aba":jogo.painel.hud.catalogo.grupo("oficina_duto_grade")},"receb":{"tipo":"ponto_recebimento","aba":"Armazenamento"},"estante":{"tipo":"antigo_estante_velha_2","aba":"Armazenamento"}}.get(chave,{})
func comprar_item(chave:String) -> void:
	existentes=jogo.planta.objetos.keys();jogo.terminal_ui.fechar();jogo.painel.hud.catalogo.painel.hide();jogo.escolher_ferramenta("selecionar");mudar_etapa(chave+"_catalogo")
func mudar_etapa(valor:String,modo:String="guiado") -> void:
	etapa=valor;fase=modo;tempo_etapa=0.0;espera_tarefa=0.0;painel.hide();raiz.show();destaque.show();jogo.arrastando=false;jogo.apagando=false
	if jogo.velocidade_tempo<=0:jogo.velocidade_tempo=1.0
func atualizar_guia(_delta:float) -> void:
	var a:=admin();var b:=bonnie()
	if not is_instance_valid(a) or not is_instance_valid(b):return
	if espera_tarefa<.12:return
	espera_tarefa=0
	var partes:=etapa.rsplit("_",true,1)
	if partes.size()==2 and partes[1] in ["catalogo","aba","item","por"] and not dados_compra(partes[0]).is_empty():
		var chave:String=partes[0];var alvo:=dados_compra(chave);var c:CatalogoConstrucaoPlex=jogo.painel.hud.catalogo
		match partes[1]:
			"catalogo":
				if c.painel.visible:c.busca.text="";mudar_etapa(chave+"_aba")
			"aba":
				if not c.painel.visible:mudar_etapa(chave+"_catalogo")
				elif c.categoria==alvo.aba:c.preencher();mudar_etapa(chave+"_item")
			"item":
				if not c.painel.visible:mudar_etapa(chave+"_catalogo")
				elif jogo.editor.ferramenta==alvo.tipo:
					c.painel.hide();mudar_etapa(chave+"_por")
					if chave=="ibm":
						var m:=tarefas.mesa()
						if not m.is_empty():ids.mesa=int(m.id);focar_objeto(m)
					elif chave=="vent":
						var opcoes:=tarefas.ventilacoes()
						if not opcoes.is_empty():jogo.camera.position=GradePlex.projetar(Vector2(opcoes[0].celula));jogo.camera.force_update_scroll()
			"por":
				for item in tarefas.objetos(alvo.tipo):
					if existentes.has(item.id):continue
					ids[chave]=int(item.id);jogo.escolher_ferramenta("selecionar");posicionado(chave);return
		return
	match etapa:
		"lixeira_abrir":
			if aberto("lixeira"):
				terminar_fala(["Yuck! Bem, é inegável que esse é bem feio! Temos que ter cuidado com coisas, objetos e comidas que deixem seu restaurante feio ou com mau cheiro...","Itens baratos, comidas estragadas e pisos quebrados podem deixar seus clientes desconfortáveis. Eu sei que eu estou..."],"limpar","incomodado")
			elif not tarefas.desembalar(a,int(ids.get("lixeira",-1))) and not tarefas.ocupados([a]):tarefas.liberar_passagem(b,true)
		"limpar_primeiro","limpar_final":
			var ajudou:=tarefas.limpar(b,true);var trabalhou:=tarefas.limpar(a,false)
			if ajudou or trabalhou or tarefas.ocupados([a,b]):tempo_etapa=0;return
			if etapa=="limpar_final" and not tarefas.residuos().is_empty():
				if tarefas.liberar_passagem(a) or tarefas.liberar_passagem(b):tempo_etapa=0;return
			if tempo_etapa<2:return
			if not tarefas.residuos().is_empty():
				if etapa=="limpar_primeiro":iniciar_parede()
				return
			if etapa=="limpar_primeiro":iniciar_parede()
			else:terminar_fala(["Ah, muito mais limpo! Mãos ao trabalho!","Ok! Vamos montar seu computador? Afinal, precisamos encomendar as comidas... Ah, já me imagino comendo uma pizza saborosa nesse lugar...","Bem, meio, né... Enfim!"],"computador")
		"parede_andar":
			if b.ocupado():tempo_etapa=0;return
			if parede_alvo.has("celula"):jogo.tarefas.orientar(b,Vector2(parede_alvo.celula))
			if tempo_etapa<.8:return
			b.emocao.exibir("festa");a.emocao.exibir("exclamacao");definir_humor("muito_feliz")
			var perto:=perto_livre(b.celula,a.celula);a.andar(jogo.rotas.caminho(a.origem_rota(),perto));mudar_etapa("parede_player","cena")
		"parede_player":
			if a.ocupado() or tempo_etapa<1.0:return
			terminar_fala(["Hora de quebrar tudo! Vamos abrir umas paredes e remover alguns objetos!"],"demolir","muito_feliz")
		"demolir_ferramenta":
			if jogo.painel.hud.catalogo.painel.visible and jogo.editor.ferramenta!="remover":return
			if jogo.editor.ferramenta=="remover":jogo.painel.hud.catalogo.painel.hide();mudar_etapa("demolir_parede")
		"demolir_parede":
			if not jogo.planta.objetos.has(int(parede_alvo.get("id",-1))):mudar_etapa("demolir_buracos")
		"demolir_buracos":
			if tarefas.objetos("cenario_buraco_madeira").is_empty():jogo.escolher_ferramenta("selecionar");mudar_etapa("limpar_final","cena")
		"ibm_entrada":
			if b.ocupado() or a.ocupado():tempo_etapa=0;return
			if tempo_etapa<.7:return
			b.emocao.exibir("irritado");terminar_fala(["Augh! Que lugar quente, meu Deus... Rápido, compre uma tubulação para dissipar esse ar podre!"],"ventilar","triste")
		"ibm_desembalar":
			if not aberto("ibm"):tarefas.desembalar(a,int(ids.get("ibm",-1)));return
			definir_humor("feliz");b.emocao.exibir("feliz");mudar_etapa("ibm_abrir")
		"ibm_abrir":
			if jogo.terminal_ui.aberto():mudar_etapa("pizza_confirmar")
		"pizza_confirmar":
			if compra_id>0:
				jogo.terminal_ui.fechar();terminar_fala(["Ah! Eu me esqueci, perdão! Precisamos de um ponto de coleta! Vamos criar um?"],"recebimento")
			elif not jogo.terminal_ui.aberto():mudar_etapa("ibm_abrir")
		"estante_abrir":
			if not aberto("estante"):
				if not tarefas.desembalar(a,int(ids.get("estante",-1))) and not tarefas.ocupados([a]):tarefas.liberar_passagem(b,true)
				return
			terminar_fala(["Nossa! Fizemos muita coisa! Mas ainda temos muito por vir! Por agora, você fica por conta própria! Ok?","Olha, eu adoraria te ajudar mais! Mas eu não sou dona de restaurante! Então, acho que o restante ficará por sua conta e risco! Boa sorte, {player}!!"],"sair")
func posicionado(chave:String) -> void:
	match chave:
		"lixeira":mudar_etapa("lixeira_abrir","cena")
		"ibm":
			var item:Dictionary=jogo.planta.objetos.get(int(ids.ibm),{});var acesso:Array[Vector2i]=jogo.planta.interacoes(int(ids.get("mesa",-1)))
			if not acesso.is_empty():aandar(admin(),acesso[0])
			var destino:=perto_livre(item.get("celula",admin().celula),admin().celula);aandar(bonnie(),destino);focar_objeto(item);mudar_etapa("ibm_entrada","cena")
		"vent":definir_humor("feliz");mudar_etapa("ibm_desembalar","cena")
		"receb":terminar_fala(["Ok! Agora, uma estante, né... Não podemos deixar nossas pizzas no chão! Rápido, compre uma estante!"],"estante")
		"estante":mudar_etapa("estante_abrir","cena")
func aberto(chave:String) -> bool:
	var item:Dictionary=jogo.planta.objetos.get(int(ids.get(chave,-1)),{})
	return not item.is_empty() and not EmbalagensMoveisPlex.eh(item)
func aandar(a:PersonagemPlex,c:Vector2i) -> void:
	if is_instance_valid(a):a.andar(jogo.rotas.caminho(a.origem_rota(),c))
func iniciar_parede() -> void:
	tarefas.guardar_ferramentas();parede_alvo=tarefas.parede(bonnie())
	if not parede_alvo.is_empty():aandar(bonnie(),parede_alvo.olhar);focar_objeto(parede_alvo)
	mudar_etapa("parede_andar","cena")
func focar_objeto(item:Dictionary) -> void:
	if not item.has("celula"):return
	jogo.visor.automatico=false;jogo.camera.position=GradePlex.projetar(Vector2(item.celula));jogo.camera.force_update_scroll()
func retangulo_controle(c:Control) -> Rect2:
	return c.get_global_rect() if is_instance_valid(c) and c.is_visible_in_tree() else Rect2()
func retangulo_objeto(item:Dictionary) -> Rect2:
	if not item.has("celula"):return Rect2()
	var pos:Vector2=jogo.camera.get_canvas_transform()*GradePlex.projetar(Vector2(item.celula))
	var zoom:float=jogo.camera.zoom.x
	return Rect2(pos-Vector2(38,85)*zoom,Vector2(76,112)*zoom)
func atualizar_destaque() -> void:
	var areas:Array[Rect2]=[];var tinta:=Color("f2c64c");var c:CatalogoConstrucaoPlex=jogo.painel.hud.catalogo
	var partes:=etapa.rsplit("_",true,1)
	if partes.size()==2 and not dados_compra(partes[0]).is_empty():
		var alvo:=dados_compra(partes[0]);var chave:String=partes[0]
		match partes[1]:
			"catalogo":areas.append(retangulo_controle(jogo.painel.hud.catalogo_botao))
			"aba":areas.append(retangulo_controle(c.botoes[alvo.aba]))
			"item":
				if c.cards.has(alvo.tipo):
					var card:Control=c.cards[alvo.tipo];c.rolagem.ensure_control_visible(card);areas.append(retangulo_controle(card).intersection(retangulo_controle(c.rolagem)))
			"por":
				if chave=="ibm":areas.append(retangulo_objeto(jogo.planta.objetos.get(int(ids.get("mesa",-1)),{})))
				elif chave=="vent":
					for opcao in tarefas.ventilacoes():
						if areas.size()<8:areas.append(retangulo_objeto(opcao))
				else:
					var tela:=get_viewport().get_visible_rect().size;areas.append(Rect2(0,205,tela.x,maxf(40,tela.y-285)))
	match etapa:
		"demolir_ferramenta":areas.append(retangulo_controle(c.demolir) if c.painel.visible else retangulo_controle(jogo.painel.hud.catalogo_botao))
		"demolir_parede":areas.append(retangulo_objeto(parede_alvo));tinta=Color("ed7369")
		"demolir_buracos":
			for item in tarefas.objetos("cenario_buraco_madeira"):areas.append(retangulo_objeto(item))
			tinta=Color("ed7369")
		"ibm_abrir":areas.append(retangulo_controle(jogo.painel.hud.terminal_atalho))
		"pizza_confirmar":areas.append(retangulo_controle(jogo.terminal_ui.comprar_botao));tinta=Color("9cec9a")
	destaque.definir(areas.filter(func(r):return r.has_area()),tinta)
func permite_editor(tipo:String,c:Vector2i,r:int) -> bool:
	if assunto!="intro" or fase not in ["guiado","cena"]:return true
	if etapa=="demolir_parede":return tipo=="remover" and c==parede_alvo.get("celula",Vector2i(-1,-1))
	if etapa=="demolir_buracos":return tipo=="remover" and tarefas.objetos("cenario_buraco_madeira").any(func(o):return o.celula==c)
	if not etapa.ends_with("_por"):return false
	var chave:=etapa.trim_suffix("_por");var d:=dados_compra(chave)
	if tipo!=d.get("tipo",""):return false
	if chave=="ibm":return jogo.planta.objetos.has(int(ids.get("mesa",-1))) and jogo.planta.celulas(jogo.planta.objetos[int(ids.mesa)].tipo,jogo.planta.objetos[int(ids.mesa)].celula,jogo.planta.objetos[int(ids.mesa)].rotacao).has(c)
	if chave=="vent":return tarefas.ventilacoes().any(func(o):return o.celula==c and int(o.r)==r)
	return true
func permite_pizza(terminal:int,produto:String,quantidade:int) -> bool:
	return assunto=="intro" and aceita and etapa=="pizza_confirmar" and fase=="guiado" and compra_id<0 and terminal==int(ids.get("ibm",-1)) and produto=="pizza" and quantidade==1
func pizza_comprada(id:int) -> void:
	if etapa=="pizza_confirmar":compra_id=id

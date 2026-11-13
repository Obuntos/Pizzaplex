class_name JogosInfantisPlex
extends RefCounted

var jogo:Node
var referencia:WeakRef
var gestor:RefCounted:
	get:return referencia.get_ref()
var acumulado:=0.0
func _init(g:RefCounted,cena:Node) -> void:referencia=weakref(g);jogo=cena
func ator(id:int) -> PersonagemPlex:return jogo.clientes.ator(id)
func cantos() -> Array[Vector2i]:
	jogo.ambientes.atualizar()
	var lista:Array[Vector2i]=[]
	for sala in jogo.ambientes.ambientes:
		if not sala.get("fechada",false):continue
		var vagas:Array[Vector2i]=[]
		for c in sala.celulas:
			if jogo.planta.transitavel(c) and TerrenoPlex.contem(jogo.planta,c) and jogo.planta.em(c).get("tipo","") not in CatalogoPlex.PORTAS:vagas.append(c)
		for eixo in [Vector2(1,1),Vector2(1,-1),Vector2(-1,1),Vector2(-1,-1)]:
			vagas.sort_custom(func(a,b):return Vector2(a).dot(eixo)>Vector2(b).dot(eixo))
			if not vagas.is_empty() and not lista.has(vagas[0]):lista.append(vagas[0])
	return lista
func mover(a:PersonagemPlex,c:Vector2i,privado:bool=false) -> bool:
	var rota:Array[Vector2i]=jogo.rotas.caminho(a.origem_rota(),c) if privado else CirculacaoVisitantesPlex.rota(jogo,a.origem_rota(),c)
	if rota.is_empty():return false
	if privado and a.has_meta("limites_rota"):a.remove_meta("limites_rota")
	a.andar(rota);return true
func nota(c:Vector2i,contador:PersonagemPlex,escolhidos:Array[Vector2i]) -> float:
	var fora:=not VisaoNPCPlex.cone(jogo.planta,contador.local,VisaoNPCPlex.frente(contador),Vector2(c))
	var oculto:=not VisaoNPCPlex.linha(jogo.planta,contador.local,Vector2(c))
	var livre_funcionarios:bool=not jogo.personagens.any(func(a):return a.cargo=="funcionario" and VisaoNPCPlex.ve_ponto(jogo,a,Vector2(c)))
	var separado:=20.0 if escolhidos.all(func(p):return jogo.ambientes.em(p).get("id",-1)!=jogo.ambientes.em(c).get("id",-1)) else 0.0
	return Vector2(c).distance_to(contador.local)+float(fora)*35+float(oculto)*50+float(livre_funcionarios)*25+separado
func escolher(g:Dictionary,lista:Array) -> bool:
	var escolhidos:Array[Vector2i]=[]
	var contador:PersonagemPlex=lista[0]
	for a in lista.slice(1):
		var viaveis:Array=g.patrulha.filter(func(c):return Vector2(c).distance_to(contador.local)>3 and escolhidos.all(func(p):return Vector2(p).distance_to(Vector2(c))>=4))
		viaveis.sort_custom(func(x,y):return nota(x,contador,escolhidos)>nota(y,contador,escolhidos))
		var escolhido:=Vector2i(-1,-1)
		for c in viaveis:
			if not jogo.rotas.caminho(a.origem_rota(),c).is_empty():escolhido=c;break
		if escolhido.x<0:return false
		escolhidos.append(escolhido);g.esconderijos[a.identificador]=escolhido
	g.patrulha.sort_custom(func(x,y):return prioridade_busca(x,contador)<prioridade_busca(y,contador));return true
func prioridade_busca(c:Vector2i,busca:PersonagemPlex) -> float:
	return Vector2(c).distance_to(busca.local)-(35.0 if not VisaoNPCPlex.linha(jogo.planta,busca.local,Vector2(c)) else 0.0)
func iniciar(tipo:String,lista:Array,debug:bool) -> bool:
	if tipo not in ["pega_pega","esconde_esconde"] or lista.size()<2:return false
	var g:Dictionary={"ids":lista.map(func(a):return a.identificador),"tipo":tipo,"tempo":0.0,"troca":0.0,"vez":0,"debug":debug,"encontrados":[],"esconderijos":{},"memoria":{},"rotas_em":{},"etapa":"contar" if tipo=="esconde_esconde" else "correr","contagem":0,"patrulha":cantos(),"parada":0,"giro":0.0,"giros":0,"imune":3.0,"trocas":0,"visitados":{},"bloqueados":{},"salas_vistas":{},"ponto_busca":Vector2i(-1,-1),"destino_busca":Vector2i(-1,-1),"ultima_posicao":Vector2.ZERO,"parado":0.0}
	if tipo=="esconde_esconde" and not escolher(g,lista):return false
	if tipo=="esconde_esconde" and not posto_contagem(g,lista[0]):return false
	for a in lista:
		a.movimento.cancelar();a.assento=-1;a.visita.brincando=true;a.visita.brincadeira_tipo=tipo;a.visita.humor_cliente="feliz"
		a.trabalho="contar_esconde" if tipo=="esconde_esconde" and a==lista[0] else "brincar_grupo"
		if tipo=="pega_pega" or a!=lista[0]:a.visita.correndo=true
	gestor.grupos.append(g)
	if tipo=="esconde_esconde":
		mover(lista[0],g.posto_contagem,true)
		for a in lista.slice(1):mover(a,g.esconderijos[a.identificador],true)
	else:jogo.sistemas.baloes.exibir(lista[0],"Eu sou o pegador!",3)
	return true
func posto_contagem(g:Dictionary,busca:PersonagemPlex) -> bool:
	var candidatos:Array=[]
	var sala:Dictionary=jogo.ambientes.em(busca.celula)
	for c in sala.get("celulas",{}):
		if not jogo.planta.transitavel(c):continue
		for d in GradePlex.VIZINHOS:
			var o:Dictionary=jogo.planta.em(c+d)
			if o.get("tipo","") in SalasPlex.ESTRUTURA and o.get("tipo","") not in CatalogoPlex.PORTAS:candidatos.append({"celula":c,"parede":c+d})
	candidatos.sort_custom(func(x,y):return Vector2(x.celula).distance_squared_to(busca.local)<Vector2(y.celula).distance_squared_to(busca.local))
	for p in candidatos:
		if not jogo.rotas.caminho(busca.origem_rota(),p.celula).is_empty():g.posto_contagem=p.celula;g.parede_contagem=p.parede;return true
	return false
func observar_pontos(g:Dictionary,busca:PersonagemPlex) -> void:
	for c in g.patrulha:
		if not g.visitados.has(c) and VisaoNPCPlex.ve_ponto(jogo,busca,Vector2(c)):g.visitados[c]=true
func ampliar_busca(g:Dictionary) -> bool:
	var antes:int=g.patrulha.size()
	for sala in jogo.ambientes.ambientes:
		if not sala.get("fechada",false):continue
		for c in sala.celulas:
			if posmod(c.x,3)!=1 or posmod(c.y,3)!=1 or g.patrulha.has(c) or not jogo.planta.transitavel(c) or not TerrenoPlex.contem(jogo.planta,c):continue
			g.patrulha.append(c)
	return g.patrulha.size()>antes
func escolher_busca(g:Dictionary,busca:PersonagemPlex) -> bool:
	for c in g.bloqueados.keys():
		if float(g.bloqueados[c])<=float(g.tempo):g.bloqueados.erase(c)
	var candidatos:Array=g.patrulha.filter(func(c):return not g.visitados.has(c) and float(g.bloqueados.get(c,0))<=float(g.tempo))
	candidatos.sort_custom(func(x,y):return prioridade_busca(x,busca)+float(g.salas_vistas.get(jogo.ambientes.em(x).get("id",-1),0))*12<prioridade_busca(y,busca)+float(g.salas_vistas.get(jogo.ambientes.em(y).get("id",-1),0))*12)
	for c in candidatos:
		var vagas:Array[Vector2i]=[c]
		for d in GradePlex.VIZINHOS:vagas.append(c+d)
		for destino in vagas:
			if not jogo.planta.transitavel(destino) or jogo.personagens.any(func(a):return a!=busca and a.celula==destino):continue
			var rota:Array[Vector2i]=jogo.rotas.caminho(busca.origem_rota(),destino)
			if rota.is_empty():continue
			g.ponto_busca=c;g.destino_busca=destino;g.giros=0;g.giro=0.0;g.parado=0.0;g.ultima_posicao=busca.local
			busca.andar(rota);return true
		g.bloqueados[c]=float(g.tempo)+12.0
	if ampliar_busca(g):return escolher_busca(g,busca)
	if candidatos.is_empty() and g.bloqueados.is_empty():g.visitados.clear()
	return false
func esconder(g:Dictionary,dt:float) -> void:
	var busca:=ator(int(g.ids[0]))
	for id in g.ids.slice(1):
		var a:=ator(int(id))
		if g.encontrados.has(id):continue
		if a.visita.get("voltar_responsavel",false):a.visita.erase("escondido");continue
		if not a.ocupado():
			if a.celula==g.esconderijos[id]:a.visita.escondido=true;a.visita.erase("correndo");a.trabalho="esconder"
			else:mover(a,g.esconderijos[id],true)
	if g.etapa=="contar":
		if busca.ocupado():return
		if busca.celula!=g.posto_contagem:mover(busca,g.posto_contagem,true);return
		busca.trabalho="contar_esconde";jogo.tarefas.orientar(busca,Vector2(g.parede_contagem));g.contagem=float(g.contagem)+dt
		if float(g.contagem)<60:return
		g.etapa="buscar";busca.trabalho="procurar_criancas";busca.visita.correndo=true;busca.visita.brincadeira_velocidade=1.15;busca.emocao.exibir("exclamacao")
	for id in g.ids.slice(1):
		var a:=ator(int(id))
		if not g.encontrados.has(id) and VisaoNPCPlex.ve(jogo,busca,a):
			g.encontrados.append(id);a.visita.erase("escondido");a.emocao.exibir("exclamacao");a.trabalho="encontrado"
	if g.encontrados.size()>=g.ids.size()-1:gestor.terminar(g);return
	observar_pontos(g,busca)
	if busca.ocupado():
		g.parado=float(g.parado)+dt if busca.local.distance_to(g.ultima_posicao)<.02 else 0.0;g.ultima_posicao=busca.local
		if float(g.parado)>6:busca.movimento.cancelar();g.bloqueados[g.ponto_busca]=float(g.tempo)+12;g.ponto_busca=Vector2i(-1,-1)
		return
	if g.ponto_busca==Vector2i(-1,-1):escolher_busca(g,busca);return
	g.giro=float(g.giro)+dt
	if float(g.giro)<.35:return
	g.giro=0.0;busca.direcao=posmod(busca.direcao+1,8);g.giros=int(g.giros)+1
	if int(g.giros)<8:return
	g.visitados[g.ponto_busca]=true
	var sala:int=jogo.ambientes.em(busca.celula).get("id",-1)
	g.salas_vistas[sala]=int(g.salas_vistas.get(sala,0))+1;g.ponto_busca=Vector2i(-1,-1)

func correr(g:Dictionary,dt:float) -> void:
	g.imune=maxf(0,float(g.imune)-dt)
	var pegador:=ator(int(g.ids[int(g.vez)]))
	var outros:Array=g.ids.filter(func(id):return int(id)!=pegador.identificador).map(func(id):return ator(int(id)))
	for a in outros:
		if float(g.imune)<=0 and pegador.local.distance_to(a.local)<1.05 and VisaoNPCPlex.linha(jogo.planta,pegador.local,a.local):
			g.vez=g.ids.find(a.identificador);g.imune=3.2;g.trocas=int(g.trocas)+1;a.emocao.exibir("exclamacao");jogo.sistemas.baloes.exibir(a,"Agora eu sou o pegador!",3);return
	for id in g.ids:
		var a:=ator(int(id));var chaser:bool=a==pegador
		a.visita.correndo=true;a.visita.pegador=chaser;a.visita.brincadeira_velocidade=clampf(.97+float(posmod(a.identificador,5))*.065+sin(float(g.tempo)*.34+a.identificador)*.12+(.10 if chaser else 0.0),.82,1.4)
		if float(g.tempo)<float(g.rotas_em.get(id,0)):continue
		g.rotas_em[id]=float(g.tempo)+1.1+float(posmod(a.identificador,4))*.17
		var vistos:Array=[]
		if chaser:vistos=outros.filter(func(b):return VisaoNPCPlex.ve(jogo,a,b))
		if not vistos.is_empty():
			vistos.sort_custom(func(x,y):return a.local.distance_squared_to(x.local)<a.local.distance_squared_to(y.local));g.memoria[id]=vistos[0].origem_rota()
		if chaser and g.memoria.has(id) and a.origem_rota()!=g.memoria[id]:
			if mover(a,g.memoria[id]):a.trabalho="brincar_grupo";continue
		var destinos:Array[Vector2i]=[]
		for r in [3,5,7]:
			for d in GradePlex.VIZINHOS:
				var c:Vector2i=a.origem_rota()+d*r
				if TerrenoPlex.contem(jogo.planta,c) and jogo.planta.transitavel(c) and CirculacaoVisitantesPlex.permitida(jogo,c):destinos.append(c)
		destinos.shuffle()
		if not chaser:destinos.sort_custom(func(x,y):return Vector2(x).distance_squared_to(pegador.local)>Vector2(y).distance_squared_to(pegador.local))
		for c in destinos:
			if mover(a,c):a.trabalho="brincar_grupo";break
func atualizar(delta:float) -> void:
	acumulado+=delta
	if acumulado<.25:return
	var dt:=acumulado;acumulado=0.0
	for g in gestor.grupos.duplicate():
		g.tempo=float(g.tempo)+dt
		var limite:=INF if g.tipo=="esconde_esconde" else 45.0
		if float(g.tempo)>limite or (not jogo.operacao.aberto and not g.debug) or g.ids.any(func(id):return not is_instance_valid(ator(int(id))) or ator(int(id)).visita.get("morto",false) or int(ator(int(id)).visita.get("seguindo_adm",-1))>0 or ator(int(id)).familia>=0 and jogo.clientes.grupos.get(ator(int(id)).familia,{}).get("estado","")!="visita"):gestor.terminar(g);continue
		if g.tipo=="esconde_esconde":esconder(g,dt)
		else:correr(g,dt)

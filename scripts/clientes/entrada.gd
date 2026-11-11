class_name EntradaVisitantesPlex
extends RefCounted

static func principal(clientes: ClientesPlex, porta: Dictionary) -> bool:
	return porta.get("tipo","") in CatalogoPlex.PORTAS and TerrenoPlex.contem(clientes.jogo.planta,porta.celula)

static func entradas(clientes: ClientesPlex) -> Array[Dictionary]:
	var jogo:Node=clientes.jogo
	jogo.ambientes.atualizar()
	var caixas:Array=[]
	var estrutura:Array=[]
	for id in jogo.ambientes.equipamentos("registradora",["recepcao","salao"]):
		var item:Dictionary=jogo.planta.objetos.get(id,{})
		if item.is_empty() or int(item.get("carregada_por",0))>0: continue
		var posto:Vector2i=jogo.atendimento.ponto(id,false)
		if not GradePlex.dentro(posto) or not GradePlex.dentro(jogo.atendimento.ponto(id,true)): continue
		caixas.append({"id":id,"posto":posto})
		estrutura.append([id,posto])
	var assinatura:=hash([jogo.ambientes.assinatura_estrutura,jogo.rotas.revisao,estrutura])
	if clientes.assinatura_entradas==assinatura: return clientes.entradas_visitantes
	clientes.assinatura_entradas=assinatura
	clientes.entradas_visitantes.clear()
	var externas:=clientes.portas_externas()
	var candidatos:Array[Dictionary]=[]
	for porta in jogo.planta.objetos.values():
		if not principal(clientes,porta): continue
		var frente:=GradePlex.frente(porta.rotacao)
		for tile in jogo.planta.celulas(porta.tipo,porta.celula,porta.rotacao):
			for sentido in [frente,-frente]:
				var fora:Vector2i=tile+sentido
				var dentro:Vector2i=tile-sentido
				if not clientes.chao(fora) or not clientes.chao(dentro): continue
				if jogo.ambientes.em(fora).get("fechada",false) or not jogo.ambientes.em(dentro).get("fechada",false): continue
				if not jogo.rotas.conectavel(fora,tile) or not jogo.rotas.conectavel(tile,dentro): continue
				var melhor:=2147483647
				var registradora:=-1
				for caixa in caixas:
					var rota:Array[Vector2i]=jogo.rotas.caminho(dentro,caixa.posto,externas)
					if rota.is_empty() or rota.any(func(c): return not clientes.chao(c) or not TerrenoPlex.contem(jogo.planta,c)): continue
					if rota.size()<melhor or rota.size()==melhor and int(caixa.id)<registradora:
						melhor=rota.size()
						registradora=int(caixa.id)
				if registradora>=0: candidatos.append({"porta":porta.id,"tile":tile,"fora":fora,"dentro":dentro,"sentido":sentido,"caixa":registradora,"distancia_caixa":melhor})
	if candidatos.is_empty(): return clientes.entradas_visitantes
	candidatos.sort_custom(func(a,b): return int(a.distancia_caixa)<int(b.distancia_caixa) or int(a.distancia_caixa)==int(b.distancia_caixa) and int(a.porta)<int(b.porta))
	var escolhida:=int(candidatos[0].porta)
	for entrada in candidatos:
		if int(entrada.porta)==escolhida: clientes.entradas_visitantes.append(entrada)
	return clientes.entradas_visitantes

static func escolher(clientes: ClientesPlex, ponto_partida: Vector2i) -> Dictionary:
	var melhor: Dictionary={}
	var distancia := INF
	for entrada in entradas(clientes):
		var valor := ponto_partida.distance_squared_to(entrada.fora)
		if valor<distancia:
			distancia=valor
			melhor=entrada
	return melhor

static func chegada(clientes:ClientesPlex,ponto_partida:Vector2i) -> Vector2i:
	var entrada:=escolher(clientes,ponto_partida)
	if entrada.is_empty():return Vector2i(-1,-1)
	var jogo:Node=clientes.jogo
	var area:=ChegadasEquipePlex.campo(jogo)
	var candidatos:=ChegadasEquipePlex.bordas(clientes.proximo_grupo)
	candidatos.sort_custom(func(a,b):return a.distance_squared_to(entrada.fora)<b.distance_squared_to(entrada.fora))
	for fora_da_tela in [true,false]:
		for p in candidatos:
			if fora_da_tela and area.has_point(GradePlex.projetar(Vector2(p))):continue
			if clientes.chao(p) and not jogo.rotas.caminho(p,entrada.fora,clientes.portas_externas()).is_empty():return p
	return Vector2i(-1,-1)

static func origem(clientes: ClientesPlex, referencia: Vector2i) -> Vector2i:
	return chegada(clientes,referencia)

static func rota_exterior(clientes: ClientesPlex, origem_rota: Vector2i, destino: Vector2i, preferencia: int=0) -> Array[Vector2i]:
	var bairro: PopulacaoBairroPlex=clientes.jogo.populacao
	if bairro.cidade_presente and bairro.locais.permitidas.has(origem_rota):
		var fim:=bairro.locais.parada_proxima(destino)
		var calcada:=bairro.locais.caminho(origem_rota,fim,preferencia).duplicate()
		var trecho: Array[Vector2i]=clientes.jogo.rotas.caminho(fim,destino,clientes.portas_externas())
		if not calcada.is_empty() and not trecho.is_empty():
			calcada.append_array(trecho.slice(1))
			return calcada
	return clientes.jogo.rotas.caminho(origem_rota,destino,clientes.portas_externas())

static func bloqueios(clientes: ClientesPlex) -> Array[Vector2i]:
	var resultado:Array[Vector2i]=[]
	var permitidas:Array[Vector2i]=[]
	for entrada in entradas(clientes): permitidas.append(entrada.tile)
	if permitidas.is_empty(): return resultado
	for tile in clientes.portas_externas():
		if not permitidas.has(tile): resultado.append(tile)
	return resultado

static func configurar(clientes: ClientesPlex, pessoa: PersonagemPlex, entrada: Dictionary) -> void:
	pessoa.visita.porta_entrada=int(entrada.porta)
	pessoa.visita.entrou=false
	pessoa.set_meta("limites_rota",bloqueios(clientes))

static func atualizar(clientes: ClientesPlex, pessoa: PersonagemPlex) -> bool:
	if pessoa.visita.get("entrou",false): return true
	if not pessoa.visita.has("porta_entrada") and clientes.jogo.ambientes.em(pessoa.celula).get("fechada",false):
		pessoa.visita.entrou=true
		return true
	var opcoes:=entradas(clientes)
	if not opcoes.is_empty() and int(pessoa.visita.get("porta_entrada",-1))!=int(opcoes[0].porta):
		if clientes.jogo.ambientes.em(pessoa.celula).get("fechada",false):
			pessoa.visita.entrou=true
			return true
		pessoa.movimento.cancelar()
		pessoa.visita.porta_entrada=int(opcoes[0].porta)
		pessoa.visita.reavaliar_entrada=0.0
		pessoa.set_meta("limites_rota",bloqueios(clientes))
	if pessoa.ocupado(): return false
	for entrada in opcoes:
		if pessoa.celula==entrada.dentro and int(pessoa.visita.get("porta_entrada",entrada.porta))==int(entrada.porta):
			pessoa.visita.entrou=true
			return true
	if pessoa.relogio<float(pessoa.visita.get("reavaliar_entrada",0.0)): return false
	pessoa.visita.reavaliar_entrada=pessoa.relogio+1.5
	var candidatos := opcoes.duplicate()
	candidatos.sort_custom(func(a,b): return pessoa.celula.distance_squared_to(a.fora)<pessoa.celula.distance_squared_to(b.fora))
	for entrada in candidatos:
		var rota: Array[Vector2i]=rota_exterior(clientes,pessoa.origem_rota(),entrada.fora,pessoa.identificador)
		if rota.is_empty(): continue
		rota.append(entrada.tile)
		rota.append(entrada.dentro)
		pessoa.visita.porta_entrada=int(entrada.porta)
		pessoa.assento=-1
		pessoa.trabalho="entrar_restaurante"
		pessoa.set_meta("limites_rota",bloqueios(clientes))
		pessoa.andar(rota)
		return false
	pessoa.trabalho="aguardar_entrada"
	return false


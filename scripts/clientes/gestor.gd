class_name ClientesPlex
extends RefCounted

var jogo: Node
var grupos: Dictionary = {}
var proximo_grupo := 1
var espera := 0.0
var visitas_concluidas := 0

func _init(cena: Node) -> void:
	jogo = cena

func ator(id: int) -> PersonagemPlex:
	for a in jogo.personagens:
		if a.identificador == id: return a
	return null

func chao(c: Vector2i) -> bool:
	return GradePlex.dentro(c) and jogo.planta.transitavel(c) and is_zero_approx(jogo.planta.altura(c)) and jogo.planta.em(c).get("tipo", "") != "escada" and CabinesPlex.em(jogo.planta,c).is_empty()

func caminho(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var rota: Array[Vector2i] = jogo.rotas.caminho(a,b)
	if rota.any(func(c): return not chao(c)): return []
	return rota

func vagas(origem: Vector2i, total: int, raio: int = 3) -> Array[Vector2i]:
	var locais: Array[Vector2i] = []
	for y in range(maxi(0,origem.y-raio),mini(GradePlex.TAMANHO.y,origem.y+raio+1)):
		for x in range(maxi(0,origem.x-raio),mini(GradePlex.TAMANHO.x,origem.x+raio+1)):
			var c := Vector2i(x,y)
			if not chao(c) or jogo.personagens.any(func(a): return a.celula == c): continue
			if caminho(origem,c).is_empty(): continue
			locais.append(c)
	locais.sort_custom(func(a,b): return a.distance_squared_to(origem)<b.distance_squared_to(origem))
	locais.resize(mini(total,locais.size()))
	return locais

func saida(origem: Vector2i) -> Vector2i:
	var melhor := Vector2i(-1,-1)
	var distancia := 99999
	for y in GradePlex.TAMANHO.y:
		for x in GradePlex.TAMANHO.x:
			if x not in [0,GradePlex.TAMANHO.x-1] and y not in [0,GradePlex.TAMANHO.y-1]: continue
			var c := Vector2i(x,y)
			if not chao(c): continue
			var rota := caminho(origem,c)
			if not rota.is_empty() and rota.size()<distancia:
				distancia = rota.size()
				melhor = c
	return melhor

func criar(local: Vector2i, quantidade: int) -> bool:
	if quantidade not in [1,2] or not chao(local):
		jogo.painel.mensagem("Coloque a família em um tile de chão livre.")
		return false
	var destino := saida(local)
	var locais := vagas(local,quantidade+1)
	if destino.x < 0 or locais.size() < quantidade+1:
		jogo.painel.mensagem("A família precisa de espaço livre e de uma saída alcançável na borda da construção.")
		return false
	var id := proximo_grupo
	proximo_grupo += 1
	var adulta: PersonagemPlex = jogo.spawn("humana",locais[0],"cliente")
	adulta.familia = id
	adulta.visita = {"etapa":"pedido","banheiro":false,"higiene":false}
	var filhos: Array[int] = []
	for i in quantidade:
		var filho: PersonagemPlex = jogo.spawn("crianca",locais[i+1],"crianca")
		filho.familia = id
		filho.responsavel = adulta.identificador
		IdentidadesPlex.familiar(filho,adulta)
		filho.visita = {"etapa":"jogar","jogou":false,"assistiu":false,"tempo":0.0}
		filhos.append(filho.identificador)
	grupos[id] = {"id":id,"adulta":adulta.identificador,"criancas":filhos,"mesa":-1,"slot":-1,"cadeira":-1,"pedido":-1,"estado":"visita","tempo":0.0,"pago":false,"saida":[destino.x,destino.y]}
	jogo.selecionar(adulta)
	jogo.painel.mensagem("Cliente com " + str(quantidade) + " criança(s). A família fará a visita automaticamente.")
	return true

func adicionar_crianca(local: Vector2i) -> bool:
	var adulta: PersonagemPlex = jogo.selecionado
	if not is_instance_valid(adulta) or adulta.cargo != "cliente" or not grupos.has(adulta.familia):
		jogo.painel.mensagem("Selecione a adulta responsável antes de adicionar uma criança.")
		return false
	var grupo: Dictionary = grupos[adulta.familia]
	if grupo.estado != "visita" or grupo.criancas.size() >= 2:
		jogo.painel.mensagem("Cada adulta acompanha uma ou duas crianças.")
		return false
	if not chao(local) or caminho(adulta.origem_rota(),local).is_empty(): return false
	var locais := vagas(local,1,1)
	if locais.is_empty(): return false
	var filho: PersonagemPlex = jogo.spawn("crianca",locais[0],"crianca")
	filho.familia = adulta.familia
	filho.responsavel = adulta.identificador
	IdentidadesPlex.familiar(filho,adulta)
	filho.visita = {"etapa":"jogar","jogou":false,"assistiu":false,"tempo":0.0}
	grupo.criancas.append(filho.identificador)
	jogo.selecionar(adulta)
	return true

func ir(a: PersonagemPlex, alvo: Vector2i) -> bool:
	if a.ocupado(): return false
	if a.celula == alvo: return true
	var rota := caminho(a.origem_rota(),alvo)
	if not rota.is_empty():
		a.assento = -1
		a.trabalho = "visitar"
		a.andar(rota)
	return false

func aproximar(a: PersonagemPlex, id: int) -> bool:
	var alvos: Array[Vector2i] = jogo.planta.interacoes(id)
	alvos.sort_custom(func(x,y): return x.distance_squared_to(a.celula)<y.distance_squared_to(a.celula))
	for alvo in alvos:
		if not caminho(a.origem_rota(),alvo).is_empty(): return ir(a,alvo)
	return false

func escolher_mesa(a: PersonagemPlex, grupo: Dictionary) -> bool:
	for id in jogo.ambientes.equipamentos("mesa",["salao"]):
		var mesa: Dictionary = jogo.planta.objetos[id]
		if int(mesa.get("familia_cliente",-1)) >= 0 or not ApoiosPlex.filhos(jogo.planta,id).is_empty(): continue
		if jogo.servicos.pedidos.any(func(p): return p.mesa == id and p.estado not in ["consumido","cancelado"]): continue
		var cadeiras := LugaresPlex.cadeiras(jogo.planta,mesa)
		for i in 4:
			if cadeiras[i] < 0: continue
			var acesso: Array[Vector2i] = jogo.planta.interacoes(cadeiras[i])
			if not acesso.any(func(c): return not caminho(a.origem_rota(),c).is_empty()): continue
			mesa.familia_cliente = grupo.id
			grupo.mesa = id
			grupo.slot = i
			grupo.cadeira = cadeiras[i]
			return true
	return false

func sentar(a: PersonagemPlex, grupo: Dictionary) -> bool:
	if not jogo.planta.objetos.has(grupo.cadeira): return false
	if not aproximar(a,grupo.cadeira): return false
	a.assento = grupo.cadeira
	a.direcao = GradePlex.direcao_suporte(jogo.planta.objetos[grupo.cadeira].rotacao)
	a.trabalho = "sentar_mesa"
	a.animacao.expressao = "feliz"
	return true

func adulta(a: PersonagemPlex, grupo: Dictionary) -> void:
	if jogo.servicos.trabalhos.has(a.identificador) or a.ocupado(): return
	if not jogo.planta.objetos.has(grupo.mesa):
		if not escolher_mesa(a,grupo): return
	if not LugaresPlex.ativo(jogo.planta,grupo.mesa,grupo.slot):
		sair(grupo)
		return
	if not sentar(a,grupo): return
	if grupo.pedido < 0:
		if jogo.servicos.criar_pedido(grupo.mesa,a.identificador,grupo.id,grupo.slot):
			grupo.pedido = jogo.servicos.proximo_pedido-1
		a.visita.etapa = "refeicao"
		return
	var pedido: Dictionary = jogo.servicos.pedido_por_id(grupo.pedido)
	if pedido.get("estado","") == "consumido":
		pagamento(grupo)
		return
	if pedido.get("estado","") in ["aguardando","preparando","assando"]:
		if float(a.necessidades.banheiro) < 25:
			for vaso in jogo.servicos.encontrar("vaso_sanitario",["banheiro"]):
				if RotinasPlex.iniciar(jogo.servicos,a,vaso):
					a.assento = -1
					a.trabalho = "visitar"
					return
		elif float(a.necessidades.higiene) < 30:
			for pia in jogo.servicos.encontrar("pia_banheiro",["banheiro"]):
				if RotinasPlex.iniciar(jogo.servicos,a,pia):
					a.assento = -1
					a.trabalho = "visitar"
					return

func ponto_show(a: PersonagemPlex) -> Dictionary:
	for robo in jogo.personagens:
		if not robo.robo or robo.trabalho != "apresentar" or robo.pose < 0: continue
		var marca: Dictionary = jogo.planta.objetos.get(robo.pose,{})
		if marca.is_empty(): continue
		var frente := GradePlex.frente(marca.rotacao)
		var lado := Vector2i(frente.y,-frente.x)
		for dist in [4,3,5,2]:
			for lateral in [0,1,-1,2,-2]:
				var c: Vector2i = marca.celula + frente*dist+lado*lateral
				if not chao(c) or jogo.personagens.any(func(outro): return outro!=a and (outro.celula==c or outro.visita.get("show",[])==[c.x,c.y])): continue
				if not caminho(a.origem_rota(),c).is_empty(): return {"celula":[c.x,c.y],"pose":robo.pose}
	return {}

func crianca(a: PersonagemPlex, grupo: Dictionary, delta: float) -> void:
	a.visita.tempo = float(a.visita.get("tempo",0.0))+delta
	if jogo.servicos.trabalhos.has(a.identificador) or a.ocupado(): return
	match str(a.visita.get("etapa","jogar")):
		"jogar":
			if a.visita.get("jogou",false):
				a.visita.etapa = "show"
				a.visita.tempo = 0.0
				return
			for maquina in jogo.servicos.encontrar("maquina_fliperama",["jogos"]):
				if RotinasPlex.iniciar(jogo.servicos,a,maquina): return
			if a.visita.tempo > 45 and jogo.ambientes.equipamentos("maquina_fliperama",["jogos"]).is_empty(): a.visita.etapa = "show"
		"show":
			if not a.visita.has("show"):
				var p := ponto_show(a)
				if p.is_empty():
					if a.visita.tempo > 90: a.visita.etapa = "aguardar"
					return
				a.visita.show = p.celula
				a.visita.pose = p.pose
				a.visita.tempo = 0.0
			var local: Array = a.visita.show
			if not chao(Vector2i(local[0],local[1])) or not jogo.poses.valida(int(a.visita.pose)):
				a.visita.erase("show")
				return
			var robo: PersonagemPlex = null
			for candidato in jogo.personagens:
				if candidato.robo and candidato.pose == int(a.visita.pose) and candidato.trabalho == "apresentar" and not candidato.ocupado():
					robo = candidato
					break
			if not is_instance_valid(robo):
				a.visita.erase("show")
				a.trabalho = "visitar"
				return
			if ir(a,Vector2i(local[0],local[1])):
				a.trabalho = "assistir"
				jogo.tarefas.orientar(a,robo.local)
				a.animacao.expressao = "feliz"
				a.visita.tempo_show = float(a.visita.get("tempo_show",0.0))+delta
				if a.visita.tempo_show >= 12: a.visita.assistiu = true
		"aguardar":
			if a.visita.get("assistiu",false) or not ponto_show(a).is_empty():
				a.visita.etapa = "show"
			else:
				var mae := ator(grupo.adulta)
				if not is_instance_valid(mae): return
				if a.local.distance_to(mae.local) > 4:
					var perto := vagas(mae.celula,1,2)
					if not perto.is_empty(): ir(a,perto[0])

func sair(grupo: Dictionary) -> void:
	grupo.estado = "saindo"
	for id in [grupo.adulta] + grupo.criancas:
		var a := ator(int(id))
		if not is_instance_valid(a): continue
		if jogo.servicos.trabalhos.has(a.identificador): jogo.servicos.cancelar(a)
		a.assento = -1
		a.trabalho = "sair_visita"
		a.visita.erase("show")

func pagamento(grupo: Dictionary) -> void:
	if grupo.pago: return
	var pedido: Dictionary = jogo.servicos.pedido_por_id(grupo.pedido)
	if pedido.get("estado","") != "consumido" or not jogo.planta.objetos.has(grupo.mesa): return
	var id: int = jogo.servicos.inventario.criar("dinheiro",jogo.planta.objetos[grupo.mesa].celula)
	jogo.planta.objetos[id].valor = 25
	jogo.planta.objetos[id].familia = grupo.id
	if ApoiosPlex.fixar(jogo.planta,id,grupo.mesa,4): grupo.pago = true
	else: jogo.planta.remover(id)

func remover_grupo(grupo: Dictionary, pagar: bool = false) -> void:
	var pedido: Dictionary = jogo.servicos.pedido_por_id(grupo.pedido)
	if not pedido.is_empty() and pedido.estado not in ["consumido","cancelado"]:
		for id in jogo.servicos.trabalhos.keys():
			if jogo.servicos.trabalhos[id].pedido == grupo.pedido:
				var funcionario := ator(int(id))
				if is_instance_valid(funcionario): jogo.servicos.cancelar(funcionario)
		if jogo.planta.objetos.has(pedido.pizza): jogo.planta.remover(pedido.pizza)
		pedido.estado = "cancelado"
	if pagar:
		pagamento(grupo)
		visitas_concluidas += 1
	for id in [grupo.adulta]+grupo.criancas:
		var a := ator(int(id))
		if is_instance_valid(a): jogo.despawn(a)
	if jogo.planta.objetos.has(grupo.mesa): jogo.planta.objetos[grupo.mesa].familia_cliente = -1
	grupos.erase(grupo.id)

func atualizar_saida(grupo: Dictionary) -> void:
	var destino := Vector2i(grupo.saida[0],grupo.saida[1])
	var mae := ator(grupo.adulta)
	if not is_instance_valid(mae): return
	if not chao(destino) or caminho(mae.origem_rota(),destino).is_empty():
		destino = saida(mae.origem_rota())
		if destino.x < 0: return
		grupo.saida = [destino.x,destino.y]
	var todos := true
	for id in [grupo.adulta]+grupo.criancas:
		var a := ator(int(id))
		if not is_instance_valid(a): continue
		if a.ocupado() or a.celula.distance_to(destino) > 1.5:
			todos = false
			ir(a,destino)
	if todos: remover_grupo(grupo,true)

func atualizar(delta: float) -> void:
	espera += delta
	if espera < .25: return
	var tempo := espera
	espera = 0
	for id in grupos.keys():
		var grupo: Dictionary = grupos[id]
		var mae := ator(grupo.adulta)
		if not is_instance_valid(mae):
			remover_grupo(grupo)
			continue
		grupo.tempo += tempo
		if grupo.estado == "saindo":
			atualizar_saida(grupo)
			continue
		adulta(mae,grupo)
		for filho_id in grupo.criancas:
			var filho := ator(int(filho_id))
			if is_instance_valid(filho): crianca(filho,grupo,tempo)
		var pedido: Dictionary = jogo.servicos.pedido_por_id(grupo.pedido)
		var filhos_prontos: bool = grupo.criancas.all(func(f): return is_instance_valid(ator(f)) and (ator(f).visita.get("assistiu",false) or ator(f).visita.get("etapa","")=="aguardar"))
		if (pedido.get("estado","") == "consumido" and grupo.pago and filhos_prontos) or grupo.tempo > 600: sair(grupo)

func gravar() -> Dictionary:
	return {"versao":2,"grupos":grupos.values(),"proximo_grupo":proximo_grupo,"visitas_concluidas":visitas_concluidas}

func restaurar(dados: Dictionary) -> void:
	grupos.clear()
	proximo_grupo = int(dados.get("proximo_grupo",1))
	visitas_concluidas = int(dados.get("visitas_concluidas",0))
	for registro in dados.get("grupos",[]):
		var g: Dictionary = registro.duplicate(true)
		for campo in ["id","adulta","mesa","slot","cadeira","pedido"]: g[campo] = int(g.get(campo,-1))
		g.criancas = g.criancas.map(func(id): return int(id))
		grupos[g.id] = g
		if jogo.planta.objetos.has(g.mesa): jogo.planta.objetos[g.mesa].familia_cliente = g.id
	for a in jogo.personagens.duplicate():
		if a.cargo in ["cliente","crianca"] and not grupos.has(a.familia): jogo.despawn(a)
		elif a.cargo == "crianca" and (not is_instance_valid(ator(a.responsavel)) or not grupos[a.familia].criancas.has(a.identificador)): jogo.despawn(a)
		elif a.cargo == "cliente" and grupos[a.familia].estado == "visita": a.visita.etapa = "refeicao"
		elif a.cargo == "crianca" and a.visita.get("etapa", "") == "aguardar" and a.visita.get("assistiu",false): a.visita.etapa = "show"

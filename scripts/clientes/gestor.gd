class_name ClientesPlex
extends RefCounted

var jogo: Node
var grupos: Dictionary = {}
var proximo_grupo := 1
var espera := 0.0
var visitas_concluidas := 0
var visitas_frustradas := 0
var assinatura_acessos := -1
var acessos_externos: Array[Vector2i] = []

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
	var principal := Vector2i(-1,-1)
	var tamanho := 99999
	for porta in jogo.planta.objetos.values():
		if porta.tipo != "porta_principal": continue
		var frente := GradePlex.frente(porta.rotacao)
		for c in jogo.planta.celulas(porta.tipo,porta.celula,porta.rotacao):
			for sinal in [-1,1]:
				var fora: Vector2i = c+frente*sinal*2
				if not chao(fora) or jogo.ambientes.em(fora).get("fechada",false): continue
				var rota := caminho(origem,fora)
				if not rota.is_empty() and rota.size()<tamanho:
					principal=fora
					tamanho=rota.size()
	if principal.x>=0: return principal
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

func criar(local: Vector2i, quantidade: int, modelo: String = "") -> bool:
	return FamiliasVisitantesPlex.criar(self,local,1,quantidade,0,modelo)

func criar_grupo(local: Vector2i, adultos: int, criancas: int, adolescentes: int, modelo: String = "") -> bool:
	return FamiliasVisitantesPlex.criar(self,local,adultos,criancas,adolescentes,modelo)

func criar_preset(local: Vector2i, id: String) -> bool:
	return FamiliasVisitantesPlex.preset(self,local,id)

func adicionar_crianca(local: Vector2i) -> bool:
	var adulta: PersonagemPlex = jogo.selecionado
	if not is_instance_valid(adulta) or adulta.cargo != "cliente" or not grupos.has(adulta.familia):
		jogo.painel.mensagem("Selecione o adulto responsável antes de adicionar uma criança.")
		return false
	var grupo: Dictionary = grupos[adulta.familia]
	if grupo.estado != "visita" or grupo.criancas.size() >= 2:
		jogo.painel.mensagem("Cada adulto acompanha uma ou duas crianças.")
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
	var lugares_minimos: int=FamiliasVisitantesPlex.adultos(grupo).size()+grupo.get("adolescentes",[]).size()
	for id in jogo.ambientes.equipamentos("mesa",["salao"]):
		var mesa: Dictionary=jogo.planta.objetos[id]
		if int(mesa.get("familia_cliente",-1))>=0 or not ApoiosPlex.filhos(jogo.planta,id).is_empty(): continue
		if jogo.servicos.pedidos.any(func(pedido): return pedido.mesa==id and pedido.estado not in ["consumido","cancelado"]): continue
		var cadeiras:=LugaresPlex.cadeiras(jogo.planta,mesa)
		if cadeiras.filter(func(valor): return int(valor)>=0).size()<lugares_minimos: continue
		grupo.mesa=id
		var lugar:=AcompanhamentoVisitantesPlex.lugar(self,a,grupo)
		if lugar.is_empty():
			grupo.mesa=-1
			continue
		mesa.familia_cliente=grupo.id
		grupo.slot=lugar.slot
		grupo.cadeira=lugar.cadeira
		return true
	return false

func sentar(a: PersonagemPlex, grupo: Dictionary) -> bool:
	if not jogo.planta.objetos.has(grupo.cadeira): return false
	if a.assento==int(grupo.cadeira) and a.trabalho=="sentar_mesa" and not a.ocupado(): return true
	if not aproximar(a,grupo.cadeira): return false
	a.assento = grupo.cadeira
	a.direcao = GradePlex.direcao_suporte(jogo.planta.objetos[grupo.cadeira].rotacao)
	a.trabalho = "sentar_mesa"
	a.animacao.expressao = "feliz"
	return true

func atender_adulto(pessoa: PersonagemPlex, grupo: Dictionary) -> void:
	if jogo.servicos.trabalhos.has(pessoa.identificador) or pessoa.ocupado(): return
	if not jogo.planta.objetos.has(int(grupo.mesa)):
		if pessoa.identificador!=int(grupo.adulta) or not escolher_mesa(pessoa,grupo): return
	var lugar:=AcompanhamentoVisitantesPlex.lugar(self,pessoa,grupo)
	if lugar.is_empty(): return
	if not LugaresPlex.ativo(jogo.planta,grupo.mesa,int(lugar.slot)):
		sair(grupo)
		return
	if not sentar(pessoa,lugar): return
	var id_pedido:=int(pessoa.visita.get("pedido",grupo.pedido if pessoa.identificador==int(grupo.adulta) else -1))
	if id_pedido<0:
		if jogo.servicos.criar_pedido(grupo.mesa,pessoa.identificador,grupo.id,int(lugar.slot)):
			id_pedido=jogo.servicos.proximo_pedido-1
			pessoa.visita.pedido=id_pedido
			if pessoa.identificador==int(grupo.adulta): grupo.pedido=id_pedido
		pessoa.visita.etapa="refeicao"
		return
	var pedido: Dictionary=jogo.servicos.pedido_por_id(id_pedido)
	if pedido.get("estado","")=="consumido" and pedido.get("bebida_estado","consumida")=="consumida":
		pessoa.visita.comeu=true
		pagamento(grupo)
		return
	if pedido.get("estado","") in ["aguardando","preparando","assando"]:
		if float(pessoa.necessidades.banheiro)<25:
			for vaso in jogo.servicos.encontrar("vaso_sanitario",["banheiro"]):
				if RotinasPlex.iniciar(jogo.servicos,pessoa,vaso):
					pessoa.assento=-1
					pessoa.trabalho="visitar"
					return
		elif float(pessoa.necessidades.higiene)<30:
			for pia in jogo.servicos.encontrar("pia_banheiro",["banheiro"]):
				if RotinasPlex.iniciar(jogo.servicos,pessoa,pia):
					pessoa.assento=-1
					pessoa.trabalho="visitar"
					return

func ponto_show(a: PersonagemPlex) -> Dictionary:
	for robo in jogo.personagens:
		if not robo.robo or robo.trabalho != "apresentar" or robo.pose < 0 or bool(robo.robotica.get("avariado",false)) or AnimatronicosPlex.pausado(robo): continue
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
	if jogo.servicos.trabalhos.has(a.identificador): return
	if jogo.fantasias.entreter(a,grupo,delta): return
	if LazerPlex.brincar(jogo,a,grupo,delta): return
	if a.ocupado(): return
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
				if candidato.robo and candidato.pose == int(a.visita.pose) and candidato.trabalho == "apresentar" and not candidato.ocupado() and not bool(candidato.robotica.get("avariado",false)) and not AnimatronicosPlex.pausado(candidato):
					robo = candidato
					break
			if not is_instance_valid(robo):
				var palco: int=jogo.animatronicos.palcos.da_pose(int(a.visita.pose))
				for candidato in jogo.personagens:
					if candidato.robo and candidato.trabalho=="apresentar" and not candidato.ocupado() and not bool(candidato.robotica.get("avariado",false)) and not AnimatronicosPlex.pausado(candidato) and palco>=0 and jogo.animatronicos.palcos.da_pose(candidato.pose)==palco:
						robo=candidato
						a.visita.pose=candidato.pose
						break
			if not is_instance_valid(robo):
				a.visita.erase("show")
				a.trabalho = "visitar"
				return
			if ir(a,Vector2i(local[0],local[1])):
				a.trabalho = "assistir"
				jogo.tarefas.orientar(a,robo.local)
				a.animacao.expressao = "feliz"
				if robo.robotica.get("estado","")=="ligado": a.visita.tempo_show = float(a.visita.get("tempo_show",0.0))+delta
				if float(a.visita.get("tempo_show",0.0)) >= 12: a.visita.assistiu = true
		"aguardar":
			if a.visita.get("assistiu",false) or not ponto_show(a).is_empty():
				a.visita.etapa = "show"
			else:
				var mae := ator(grupo.adulta)
				if not is_instance_valid(mae): return
				if a.local.distance_to(mae.local) > 4:
					var perto := vagas(mae.celula,1,2)
					if not perto.is_empty(): ir(a,perto[0])

func membros(grupo: Dictionary) -> Array[int]:
	return FamiliasVisitantesPlex.membros(grupo)

func acompanhantes_servidos(grupo: Dictionary) -> bool:
	var refeicoes:=FamiliasVisitantesPlex.adultos(grupo)
	for id in grupo.get("adolescentes",[]): refeicoes.append(int(id))
	for id in refeicoes:
		var pessoa:=ator(id)
		if not is_instance_valid(pessoa): continue
		if not pessoa.visita.get("comeu",false): return false
	return true

func portas_externas() -> Array[Vector2i]:
	jogo.ambientes.atualizar()
	var revisao: int=jogo.ambientes.assinatura_estrutura
	if assinatura_acessos==revisao: return acessos_externos
	assinatura_acessos=revisao
	acessos_externos.clear()
	for porta in jogo.planta.objetos.values():
		if porta.tipo not in CatalogoPlex.PORTAS: continue
		var frente:=GradePlex.frente(porta.rotacao)
		for c in jogo.planta.celulas(porta.tipo,porta.celula,porta.rotacao):
			if not jogo.ambientes.em(c+frente).get("fechada",false) or not jogo.ambientes.em(c-frente).get("fechada",false): acessos_externos.append(c)
	return acessos_externos

func acesso_salao(a: PersonagemPlex, grupo: Dictionary, delta: float) -> bool:
	if grupo.get("acesso",false): return true
	if "salao" in jogo.ambientes.em(a.celula).get("funcoes",[]):
		grupo.lider_no_salao=true
		grupo.espera_acesso=0.0
		return true
	grupo.espera_acesso=float(grupo.get("espera_acesso",0.0))+delta
	if grupo.espera_acesso>=120.0:
		grupo.irritado=true
		for id in membros(grupo):
			var visitante:=ator(int(id))
			if is_instance_valid(visitante):
				visitante.visita.irritado=true
				visitante.animacao.expressao="triste"
		sair(grupo)
		return false
	if a.ocupado(): return false
	grupo.proxima_busca=float(grupo.get("proxima_busca",0.0))-delta
	if grupo.proxima_busca>0.0: return false
	grupo.proxima_busca=2.0
	var melhor: Array[Vector2i]=[]
	var bloqueadas: Array[Vector2i]=[]
	if jogo.ambientes.em(a.celula).get("fechada",false): bloqueadas.assign(portas_externas())
	for sala in jogo.ambientes.ambientes:
		if "salao" not in sala.get("funcoes",[]): continue
		for id in sala.portas:
			var porta: Dictionary=jogo.planta.objetos.get(id,{})
			if porta.is_empty(): continue
			var frente:=GradePlex.frente(porta.rotacao)
			for c in jogo.planta.celulas(porta.tipo,porta.celula,porta.rotacao):
				for sinal in [-1,1]:
					var local: Vector2i=c+frente*sinal
					if not sala.celulas.has(local) or not chao(local): continue
					var rota: Array[Vector2i]=jogo.rotas.caminho(a.origem_rota(),local,bloqueadas)
					if rota.any(func(tile): return not chao(tile)): continue
					if not rota.is_empty() and (melhor.is_empty() or rota.size()<melhor.size()): melhor=rota
	if not melhor.is_empty():
		a.trabalho="procurar_salao"
		a.andar(melhor)
	else: a.trabalho="aguardar_acesso"
	return false

func sair(grupo: Dictionary) -> void:
	grupo.estado = "saindo"
	for id in membros(grupo):
		var a := ator(int(id))
		if not is_instance_valid(a): continue
		if jogo.servicos.trabalhos.has(a.identificador): jogo.servicos.cancelar(a)
		a.assento = -1
		a.movimento.cancelar()
		a.trabalho = "sair_visita"
		a.visita.erase("show")

func pagamento(grupo: Dictionary) -> void:
	if grupo.get("pago",false) or not acompanhantes_servidos(grupo): return
	var pedido: Dictionary=jogo.servicos.pedido_por_id(grupo.pedido)
	if pedido.get("estado","")=="consumido" and pedido.get("bebida_estado","consumida")=="consumida": jogo.atendimento.solicitar(grupo)

func remover_grupo(grupo: Dictionary, pagar: bool = false) -> void:
	for pedido in jogo.servicos.pedidos:
		if int(pedido.get("familia",-1))!=int(grupo.id) and int(pedido.id)!=int(grupo.pedido): continue
		if pedido.estado in ["consumido","cancelado"]: continue
		for ator_id in jogo.servicos.trabalhos.keys():
			var trabalho: Dictionary=jogo.servicos.trabalhos[ator_id]
			if int(pedido.id) not in trabalho.get("pedidos",[trabalho.get("pedido",-1)]): continue
			var funcionario:=ator(int(ator_id))
			if is_instance_valid(funcionario): jogo.servicos.cancelar(funcionario)
		var pizza: Dictionary=jogo.planta.objetos.get(int(pedido.get("pizza",-1)),{})
		var prato: Dictionary=jogo.planta.objetos.get(int(pizza.get("sobre",-1)),{})
		if prato.get("tipo","")=="prato": prato.sujo=true
		if not pizza.is_empty(): jogo.planta.remover(pizza.id)
		var copo:=int(pedido.get("bebida",-1))
		if jogo.planta.objetos.has(copo): jogo.planta.remover(copo)
		FornoPlex.liberar(jogo.planta,int(pedido.id))
		pedido.estado="cancelado"
		pedido.bebida_estado="cancelada"
	if pagar:
		if grupo.get("irritado",false): visitas_frustradas += 1
		else: visitas_concluidas += 1
	var dinheiro := int(grupo.get("dinheiro_pagamento",-1))
	if jogo.planta.objetos.has(dinheiro): jogo.planta.remover(dinheiro)
	for id in membros(grupo):
		var a := ator(int(id))
		if is_instance_valid(a): jogo.despawn(a)
	if jogo.planta.objetos.has(grupo.mesa): jogo.planta.objetos[grupo.mesa].familia_cliente = -1
	grupos.erase(grupo.id)

func atualizar_saida(grupo: Dictionary) -> void:
	var destino:=Vector2i(grupo.saida[0],grupo.saida[1])
	var lider:=ator(int(grupo.adulta))
	if not is_instance_valid(lider): return
	if not chao(destino) or caminho(lider.origem_rota(),destino).is_empty():
		destino=saida(lider.origem_rota())
		if destino.x<0: return
		grupo.saida=[destino.x,destino.y]
		grupo.erase("pontos_saida")
	if not grupo.has("pontos_saida"): grupo.pontos_saida={}
	var usados: Array[Vector2i]=[]
	for valor in grupo.pontos_saida.values(): usados.append(Vector2i(valor[0],valor[1]))
	var todos:=true
	for id in membros(grupo):
		var pessoa:=ator(id)
		if not is_instance_valid(pessoa): continue
		var chave:=str(id)
		if not grupo.pontos_saida.has(chave):
			var pontos: Array[Vector2i]=[]
			for y in range(destino.y-2,destino.y+3):
				for x in range(destino.x-2,destino.x+3):
					var tile:=Vector2i(x,y)
					if usados.has(tile) or not chao(tile) or jogo.ambientes.em(tile).get("fechada",false): continue
					pontos.append(tile)
			pontos.sort_custom(func(a,b): return a.distance_squared_to(destino)<b.distance_squared_to(destino))
			for tile in pontos:
				if caminho(pessoa.origem_rota(),tile).is_empty(): continue
				grupo.pontos_saida[chave]=[tile.x,tile.y]
				usados.append(tile)
				break
		if not grupo.pontos_saida.has(chave):
			todos=false
			continue
		var alvo: Array=grupo.pontos_saida[chave]
		var ponto:=Vector2i(alvo[0],alvo[1])
		if pessoa.ocupado() or pessoa.celula!=ponto:
			todos=false
			ir(pessoa,ponto)
	if todos: remover_grupo(grupo,true)

func atualizar(delta: float) -> void:
	espera+=delta
	if espera<.25: return
	var tempo:=espera
	espera=0.0
	for id in grupos.keys():
		var grupo: Dictionary=grupos[id]
		var lider:=ator(int(grupo.adulta))
		if not is_instance_valid(lider):
			remover_grupo(grupo)
			continue
		grupo.tempo+=tempo
		if grupo.estado=="saindo":
			atualizar_saida(grupo)
			continue
		if not grupo.get("acesso",false):
			var encontrou:=acesso_salao(lider,grupo,tempo)
			if grupo.estado=="saindo": continue
			var juntos:=AcompanhamentoVisitantesPlex.entrar(self,grupo)
			if not encontrou or not juntos: continue
			grupo.acesso=true
		if grupo.estado=="visita":
			for adulto_id in FamiliasVisitantesPlex.adultos(grupo):
				var pessoa:=ator(adulto_id)
				if is_instance_valid(pessoa): atender_adulto(pessoa,grupo)
		elif grupo.estado=="pagamento": jogo.atendimento.solicitar(grupo)
		for filho_id in grupo.criancas:
			var filho:=ator(int(filho_id))
			if is_instance_valid(filho): crianca(filho,grupo,tempo)
		var filhos_prontos: bool=grupo.criancas.all(func(f): return is_instance_valid(ator(int(f))) and (ator(int(f)).visita.get("assistiu",false) or ator(int(f)).visita.get("etapa","")=="aguardar"))
		if grupo.pago and filhos_prontos and acompanhantes_servidos(grupo): sair(grupo)
		elif grupo.tempo>720.0+45.0*float(lider.visita.get("conforto",5.0)) and not acompanhantes_servidos(grupo):
			grupo.irritado=true
			sair(grupo)

func gravar() -> Dictionary:
	return {"versao":3,"grupos":grupos.values(),"proximo_grupo":proximo_grupo,"visitas_concluidas":visitas_concluidas,"visitas_frustradas":visitas_frustradas}

func restaurar(dados: Dictionary) -> void:
	grupos.clear()
	proximo_grupo = int(dados.get("proximo_grupo",1))
	visitas_concluidas = int(dados.get("visitas_concluidas",0))
	visitas_frustradas = int(dados.get("visitas_frustradas",0))
	for registro in dados.get("grupos",[]):
		var g: Dictionary = registro.duplicate(true)
		for campo in ["id","adulta","mesa","slot","cadeira","pedido"]: g[campo] = int(g.get(campo,-1))
		g.adultos = g.get("adultos",[g.adulta]).map(func(id): return int(id))
		g.criancas = g.criancas.map(func(id): return int(id))
		g.adolescentes = g.get("adolescentes",[]).map(func(id): return int(id))
		if int(dados.get("versao",2))<3 and g.estado=="visita": g.acesso=false
		grupos[g.id] = g
		if jogo.planta.objetos.has(g.mesa): jogo.planta.objetos[g.mesa].familia_cliente = g.id
	for a in jogo.personagens.duplicate():
		if a.cargo in ["cliente","crianca"] and not grupos.has(a.familia): jogo.despawn(a)
		elif a.cargo == "crianca" and (not is_instance_valid(ator(a.responsavel)) or not grupos[a.familia].criancas.has(a.identificador)): jogo.despawn(a)
		elif a.cargo == "cliente" and grupos[a.familia].estado == "visita": a.visita.etapa = "refeicao"
		elif a.cargo == "crianca" and a.visita.get("etapa", "") == "aguardar" and a.visita.get("assistiu",false): a.visita.etapa = "show"


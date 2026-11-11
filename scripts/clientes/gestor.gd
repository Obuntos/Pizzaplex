class_name ClientesPlex
extends RefCounted

var jogo: Node
var grupos: Dictionary = {}
var proximo_grupo := 1
var espera := 0.0
var espera_mesas:=0.0
var visitas_concluidas := 0
var visitas_frustradas := 0
var assinatura_acessos := -1
var acessos_externos: Array[Vector2i] = []
var assinatura_entradas := -1
var entradas_visitantes: Array[Dictionary] = []
var recepcao: RecepcaoVisitantesPlex
var indice_atores:Dictionary={}
var assinatura_atores:=""
var espera_orfaos:=0.0
const LIBERAVEIS=["brincando","brincadeira_tipo","correndo","brincadeira_velocidade","escondido","rindo","show_forcado","show_destino","show_balao","socializando"]

func _init(cena: Node) -> void:
	jogo = cena
	recepcao=RecepcaoVisitantesPlex.new(self)

func ator(id: int) -> PersonagemPlex:
	var assinatura:=str(jogo.personagens.size())+":"+str(jogo.proximo_personagem if "proximo_personagem" in jogo else 0)
	if assinatura!=assinatura_atores:
		indice_atores.clear();assinatura_atores=assinatura
		for a in jogo.personagens:indice_atores[int(a.identificador)]=a
	var a:PersonagemPlex=indice_atores.get(id)
	return a if is_instance_valid(a) else null

func chao(c: Vector2i) -> bool:
	return GradePlex.dentro(c) and jogo.planta.transitavel(c) and is_zero_approx(jogo.planta.altura(c)) and jogo.planta.em(c).get("tipo", "") != "escada" and CabinesPlex.em(jogo.planta,c).is_empty()

func caminho(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var rota:=CirculacaoVisitantesPlex.rota(jogo,a,b,EntradaVisitantesPlex.bloqueios(self))
	if rota.any(func(c): return not chao(c)): return []
	return rota

func vagas(origem: Vector2i, total: int, raio: int = 3, exterior: bool = false) -> Array[Vector2i]:
	var locais: Array[Vector2i] = []
	var candidatos: Array[Vector2i] = []
	for y in range(maxi(0,origem.y-raio),mini(GradePlex.TAMANHO.y,origem.y+raio+1)):
		for x in range(maxi(0,origem.x-raio),mini(GradePlex.TAMANHO.x,origem.x+raio+1)):
			var c := Vector2i(x,y)
			if not chao(c) or jogo.personagens.any(func(a): return a.celula == c): continue
			if exterior and (jogo.ambientes.em(c).get("fechada",false) or jogo.planta.em(c).get("tipo","") in CatalogoPlex.PORTAS): continue
			candidatos.append(c)
	candidatos.sort_custom(func(a,b): return a.distance_squared_to(origem)<b.distance_squared_to(origem))
	for c in candidatos:
		var rota: Array[Vector2i]=jogo.rotas.caminho(origem,c,portas_externas()) if exterior else caminho(origem,c)
		if rota.is_empty(): continue
		locais.append(c)
		if locais.size()>=total: break
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
	var candidatos:=ChegadasEquipePlex.bordas()
	candidatos.sort_custom(func(a,b):return a.distance_squared_to(origem)<b.distance_squared_to(origem))
	for c in candidatos:
		if chao(c) and not caminho(origem,c).is_empty():return c
	return Vector2i(-1,-1)

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
	if ControleAdministradorPlex.ocupado(a): return false
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
		if int(mesa.get("familia_cliente",-1))>=0 or ApoiosPlex.filhos(jogo.planta,id).any(func(o): return not ApoiosPlex.decoracao_mesa(str(o.tipo)) and not MobiliaPlex.visual(o).begins_with("festa_bolo") and not MobiliaPlex.visual(o).begins_with("festa_fatia_bolo")): continue
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
	PassagemCadeirasPlex.iniciar(a,jogo.planta,jogo.planta.objetos[grupo.cadeira])
	a.assento = grupo.cadeira
	a.direcao = GradePlex.direcao_suporte(jogo.planta.objetos[grupo.cadeira].rotacao)
	a.trabalho = "sentar_mesa"
	a.animacao.expressao = str(a.visita.get("humor_cliente","feliz"))
	return true

func atender_adulto(pessoa: PersonagemPlex, grupo: Dictionary) -> void:
	if ControleAdministradorPlex.ocupado(pessoa): return
	if jogo.servicos.trabalhos.has(pessoa.identificador) or pessoa.ocupado(): return
	if not jogo.planta.objetos.has(int(grupo.mesa)):
		if pessoa.identificador!=int(grupo.adulta) or not escolher_mesa(pessoa,grupo): return
	var lugar:=AcompanhamentoVisitantesPlex.lugar(self,pessoa,grupo)
	if lugar.is_empty(): return
	if not LugaresPlex.ativo(jogo.planta,int(lugar.mesa),int(lugar.slot)):
		sair(grupo)
		return
	if not sentar(pessoa,lugar): return
	var id_pedido:=int(pessoa.visita.get("pedido",grupo.pedido if pessoa.identificador==int(grupo.adulta) else -1))
	if id_pedido<0:
		if jogo.servicos.criar_pedido(int(lugar.mesa),pessoa.identificador,grupo.id,int(lugar.slot)):
			id_pedido=jogo.servicos.proximo_pedido-1
			pessoa.visita.pedido=id_pedido
			if pessoa.identificador==int(grupo.adulta): grupo.pedido=id_pedido
		pessoa.visita.etapa="refeicao"
		return
	var pedido: Dictionary=jogo.servicos.pedido_por_id(id_pedido)
	if pedido.get("estado","")=="consumido" and pedido.get("bebida_estado","consumida")=="consumida":
		pessoa.visita.comeu=true
		if pessoa.cargo in ["crianca","adolescente"]:
			pessoa.assento=-1;pessoa.trabalho="visitar";pessoa.visita.etapa="show"
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
		var distancias: Array=[5,4] if int(a.visita.get("medo_animatronico",0))>=3 else [4,3,5,2]
		for dist in distancias:
			for lateral in [0,1,-1,2,-2]:
				var c: Vector2i = marca.celula + frente*dist+lado*lateral
				if not chao(c) or jogo.personagens.any(func(outro): return outro!=a and (outro.celula==c or outro.visita.get("show",[])==[c.x,c.y])): continue
				if not caminho(a.origem_rota(),c).is_empty(): return {"celula":[c.x,c.y],"pose":robo.pose}
	return {}

func crianca(a: PersonagemPlex, grupo: Dictionary, delta: float) -> void:
	if a.visita.get("perdida",false): return
	if a.visita.get("voltar_responsavel",false):CirculacaoVisitantesPlex.voltar(jogo,a);return
	if FestasRestaurantePlex.pendente(grupo) and a.visita.get("comeu",false): return
	if ControleAdministradorPlex.ocupado(a): return
	if grupo.get("estado","")=="visita" and not a.visita.get("comeu",false):
		if jogo.servicos.trabalhos.has(a.identificador): jogo.servicos.cancelar(a)
		a.visita.correndo=false
		if a.trabalho in ["jogar","assistir","assistir_mascote"]: a.assento=-1;a.trabalho="visitar"
		atender_adulto(a,grupo)
		return
	a.visita.tempo = float(a.visita.get("tempo",0.0))+delta
	if jogo.servicos.trabalhos.has(a.identificador): return
	if LazerPlex.brincar(jogo,a,grupo,delta): return
	if DiversaoFamiliaPlex.atualizar(jogo,a,grupo,delta): return
	if jogo.fantasias.entreter(a,grupo,delta): return
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
				a.animacao.expressao = str(a.visita.get("humor_cliente","feliz"))
				if robo.robotica.get("estado","")=="ligado": DiversaoFamiliaPlex.contar_show(jogo,a,delta)
				if float(a.visita.get("tempo_show",0.0)) >= DiversaoFamiliaPlex.DURACAO_SHOW_REAL: a.visita.assistiu = true
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
	if not grupo.get("filhos_pendentes",[]).is_empty(): return false
	var refeicoes:=FamiliasVisitantesPlex.membros(grupo)
	for id in refeicoes:
		var pessoa:=ator(id)
		if not is_instance_valid(pessoa) or ControleAdministradorPlex.ocupado(pessoa): continue
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
	var entrou:=EntradaVisitantesPlex.atualizar(self,a)
	if entrou or (not a.ocupado() and a.trabalho=="aguardar_entrada"):
		grupo.espera_acesso=float(grupo.get("espera_acesso",0.0))+delta
	if grupo.espera_acesso>=270.0:
		grupo.irritado=true
		for id in membros(grupo):
			var visitante:=ator(int(id))
			if is_instance_valid(visitante):
				visitante.visita.irritado=true
				visitante.animacao.expressao="raivoso";visitante.visita.humor_cliente="raivoso"
		sair(grupo)
		return false
	if not entrou: return false
	if "salao" in jogo.ambientes.em(a.celula).get("funcoes",[]):
		grupo.lider_no_salao=true
		grupo.espera_acesso=0.0
		return true
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
	if not grupo.get("irritado",false) and "venda_baloes" in jogo and jogo.venda_baloes!=null and jogo.venda_baloes.preparar(grupo):return
	ReputacaoClientesPlex.registrar(jogo,grupo)
	MesasVisitasPlex.liberar(self,grupo)
	recepcao.liberar(grupo)
	grupo.estado = "saindo"
	for id in membros(grupo):
		var a := ator(int(id))
		if not is_instance_valid(a) or ControleAdministradorPlex.ocupado(a): continue
		if jogo.servicos.trabalhos.has(a.identificador): jogo.servicos.cancelar(a)
		a.assento = -1
		a.movimento.cancelar()
		a.trabalho = "sair_visita"
		a.visita.erase("show")

func pagamento(grupo: Dictionary) -> void:
	if grupo.get("aniversario_solicitado",false) and not grupo.get("pedido_bolo",false):return
	if FestasRestaurantePlex.pendente(grupo): return
	if grupo.get("pago",false) or not acompanhantes_servidos(grupo) or not DiversaoFamiliaPlex.prontos(jogo,grupo): return
	var pedido: Dictionary=jogo.servicos.pedido_por_id(grupo.pedido)
	if pedido.get("estado","")=="consumido" and pedido.get("bebida_estado","consumida")=="consumida": jogo.atendimento.solicitar(grupo)

func remover_grupo(grupo: Dictionary, pagar: bool = false) -> void:
	MesasVisitasPlex.liberar(self,grupo)
	if FestasRestaurantePlex.pendente(grupo):
		grupo.festa_estado="concluido"
		var bolo:=int(grupo.get("bolo",-1))
		if jogo.planta.objetos.has(bolo): jogo.planta.remover(bolo)
	recepcao.liberar(grupo)
	for id in membros(grupo):
		var pessoa:=ator(int(id))
		if is_instance_valid(pessoa) and pessoa.visita.get("socializando",false): jogo.social.cancelar()
		if is_instance_valid(pessoa) and int(pessoa.visita.get("seguindo_adm",-1))<=0:
			for chave in LIBERAVEIS: pessoa.visita.erase(chave)
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
		if not is_instance_valid(a): continue
		if int(a.visita.get("seguindo_adm",-1))<=0:
			for chave in LIBERAVEIS: a.visita.erase(chave)
		if ControleAdministradorPlex.ocupado(a):
			if int(a.visita.get("seguindo_adm",-1))>0: a.familia=-1; a.responsavel=-1; a.visita.solo=true
		else: jogo.despawn(a)
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
		if not is_instance_valid(pessoa) or ControleAdministradorPlex.ocupado(pessoa): continue
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
	espera_mesas+=delta
	if espera_mesas>=1.0:
		espera_mesas=0.0
		MesasVisitasPlex.reconciliar(self)
		CirculacaoVisitantesPlex.atualizar(jogo)
	espera+=delta
	if espera<.25: return
	limpar_orfaos(espera)
	assinatura_atores=""
	var tempo:=espera
	espera=0.0
	for id in grupos.keys():
		var grupo: Dictionary=grupos[id]
		if grupo.get("debug_evento",false):continue
		if grupo.get("pago",false):
			grupo.tempo_pago=float(grupo.get("tempo_pago",0.0))+tempo
			if float(grupo.tempo_pago)>=150.0:
				remover_grupo(grupo,true)
				continue
			if float(grupo.tempo_pago)>=45.0 and grupo.get("estado","") not in ["saindo","comprar_baloes"]: sair(grupo)
		else: grupo.erase("tempo_pago")
		if grupo.get("estado","")=="saindo":
			grupo.tempo_saida=float(grupo.get("tempo_saida",0.0))+tempo
			if float(grupo.tempo_saida)>=90.0:
				remover_grupo(grupo,true)
				continue
		else: grupo.erase("tempo_saida")
		var lider:=ator(int(grupo.adulta))
		if not is_instance_valid(lider) or ControleAdministradorPlex.ocupado(lider):
			var alternativas:=membros(grupo).filter(func(i): return is_instance_valid(ator(i)) and not ControleAdministradorPlex.ocupado(ator(i)))
			if not alternativas.is_empty():
				grupo.adulta=alternativas[0]
				lider=ator(int(grupo.adulta))
			else:
				if not is_instance_valid(lider): remover_grupo(grupo)
				continue
		if not is_instance_valid(lider):
			remover_grupo(grupo)
			continue
		grupo.tempo+=tempo
		if grupo.estado=="comprar_baloes":jogo.venda_baloes.visitar(grupo,tempo);continue
		HumorClientesPlex.atualizar(self,grupo,tempo)
		if grupo.estado=="saindo":
			atualizar_saida(grupo)
			continue
		if not grupo.get("acesso",false):
			var encontrou:=acesso_salao(lider,grupo,tempo)
			if grupo.estado=="saindo": continue
			var juntos:=AcompanhamentoVisitantesPlex.entrar(self,grupo)
			if not encontrou or not juntos: continue
			grupo.acesso=true
		if PacienciaClientesPlex.atualizar(jogo,grupo,tempo):continue
		if grupo.estado=="recepcao":
			recepcao.atualizar(grupo,tempo)
			continue
		if grupo.estado=="visita":
			for adulto_id in FamiliasVisitantesPlex.adultos(grupo):
				var pessoa:=ator(adulto_id)
				if is_instance_valid(pessoa): atender_adulto(pessoa,grupo)
		elif grupo.estado=="pagamento": jogo.atendimento.solicitar(grupo)
		for filho_id in grupo.criancas:
			var filho:=ator(int(filho_id))
			if is_instance_valid(filho): crianca(filho,grupo,tempo)
		var filhos_prontos: bool=DiversaoFamiliaPlex.prontos(jogo,grupo)
		if grupo.pago and filhos_prontos and acompanhantes_servidos(grupo): sair(grupo)
		elif grupo.tempo>720.0 and not acompanhantes_servidos(grupo): grupo.aguardando_servico=true

func limpar_orfaos(tempo: float) -> void:
	espera_orfaos+=tempo
	if espera_orfaos<5.0: return
	var passo:=espera_orfaos
	espera_orfaos=0.0
	for a in jogo.personagens.duplicate():
		if not is_instance_valid(a): continue
		if a.cargo not in ["cliente","crianca"] or int(a.familia)<0 or grupos.has(int(a.familia)) or a.visita.get("solo",false) or a.visita.get("morto",false):
			a.visita.erase("orfao_tempo")
			continue
		if int(a.visita.get("seguindo_adm",-1))<=0:
			for chave in LIBERAVEIS: a.visita.erase(chave)
		if ControleAdministradorPlex.ocupado(a):
			a.visita.erase("orfao_tempo")
			continue
		a.visita.orfao_tempo=float(a.visita.get("orfao_tempo",0.0))+passo
		if float(a.visita.orfao_tempo)>=20.0: jogo.despawn(a)

func gravar() -> Dictionary:
	return {"versao":3,"grupos":grupos.values(),"proximo_grupo":proximo_grupo,"visitas_concluidas":visitas_concluidas,"visitas_frustradas":visitas_frustradas}

func restaurar(dados: Dictionary) -> void:
	indice_atores.clear();assinatura_atores=""
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
		if g.estado!="saindo" and jogo.planta.objetos.has(g.mesa): jogo.planta.objetos[g.mesa].familia_cliente = g.id
	for a in jogo.personagens.duplicate():
		a.visita.erase("recepcao_grupo")
		if ControleAdministradorPlex.ocupado(a): continue
		if a.cargo in ["cliente","crianca"] and not grupos.has(a.familia): jogo.despawn(a)
		elif a.cargo == "crianca" and (not is_instance_valid(ator(a.responsavel)) or not grupos[a.familia].criancas.has(a.identificador)): jogo.despawn(a)
		elif a.cargo == "cliente" and grupos[a.familia].estado == "visita": a.visita.etapa = "refeicao"
		elif a.cargo == "crianca" and a.visita.get("etapa", "") == "aguardar" and a.visita.get("assistiu",false): a.visita.etapa = "show"



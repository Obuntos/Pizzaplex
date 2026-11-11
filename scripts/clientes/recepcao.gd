class_name RecepcaoVisitantesPlex
extends RefCounted

var referencia: WeakRef
var clientes: ClientesPlex:
	get: return referencia.get_ref()
var jogo: Node

func _init(gestor: ClientesPlex) -> void:
	referencia=weakref(gestor)
	jogo=gestor.jogo

func mesa_livre(total: int, ignorar: int = -1) -> int:
	if ignorar<0 and not limite_visitantes(total): return -1
	if jogo.ambientes.equipamentos("registradora",["recepcao","salao"]).all(func(id): return jogo.atendimento.ponto(id,true).x<0 or jogo.atendimento.ponto(id,false).x<0): return -1
	for id in jogo.ambientes.equipamentos("mesa",["salao"]):
		var mesa: Dictionary=jogo.planta.objetos[id]
		if int(mesa.get("familia_cliente",-1)) not in [-1,ignorar]: continue
		if ApoiosPlex.filhos(jogo.planta,id).any(func(o): return not ApoiosPlex.decoracao_mesa(str(o.tipo)) and not MobiliaPlex.visual(o).begins_with("festa_bolo") and not MobiliaPlex.visual(o).begins_with("festa_fatia_bolo")): continue
		if LugaresPlex.total(jogo.planta,id)<total: continue
		if jogo.servicos.pedidos.any(func(p): return p.mesa==id and p.estado not in ["consumido","cancelado"]): continue
		for entrada in EntradaVisitantesPlex.entradas(clientes):
			var cadeiras:=LugaresPlex.cadeiras(jogo.planta,mesa)
			var acessiveis:=cadeiras.filter(func(c): return c>=0 and not jogo.rotas.aproximar(entrada.dentro,c).is_empty()).size()
			if acessiveis>=total and not jogo.rotas.aproximar(entrada.dentro,id).is_empty(): return id
	return -1

func tem_vaga(total: int) -> bool:
	return mesa_livre(total)>=0

func vaga_arcade() -> bool:
	if not limite_visitantes(1): return false
	var total: int=jogo.ambientes.equipamentos("maquina_fliperama",["jogos"]).size()
	var visitantes: int=jogo.personagens.filter(func(a): return a.cargo=="adolescente" and a.familia<0 and a.visita.get("etapa","")!="sair").size()
	return visitantes<total

func limite_visitantes(novos: int) -> bool:
	var presentes: int=jogo.personagens.filter(func(a): return a.cargo in ["cliente","crianca","adolescente"] and not a.visita.get("morto",false)).size()
	return presentes+novos<=int(jogo.populacao.limites.visitas)

func pendente() -> bool:
	return clientes.grupos.values().any(func(g): return g.get("estado","")=="recepcao")

func precisa_atendimento() -> bool:
	return clientes.grupos.values().any(func(g): return g.get("estado","")=="recepcao" and g.get("acesso",false))

func liberar(grupo: Dictionary) -> void:
	var host:=clientes.ator(int(grupo.get("anfitriao",-1)))
	if is_instance_valid(host) and int(host.visita.get("recepcao_grupo",-1))==int(grupo.id):
		host.visita.erase("recepcao_grupo")
		if host.trabalho in ["recepcionar","acompanhar_mesa"]:
			host.movimento.cancelar()
			host.trabalho=""
	grupo.erase("anfitriao")
	grupo.erase("posto_anfitriao");grupo.erase("posto_recepcao")

func interromper(ator: PersonagemPlex) -> void:
	var grupo: Dictionary=clientes.grupos.get(int(ator.visita.get("recepcao_grupo",-1)),{})
	if not grupo.is_empty(): liberar(grupo);grupo.fase_recepcao="fila";grupo.tempo_recepcao=0.0
	ator.visita.erase("recepcao_grupo")

func mover(ator: PersonagemPlex, ponto: Vector2i, trabalho: String) -> bool:
	if not TerrenoPlex.contem(jogo.planta,ponto) or not clientes.chao(ponto): return false
	if ator.ocupado(): return false
	ator.assento=-1
	ator.trabalho=trabalho
	if ator.celula==ponto: return true
	var rota:=clientes.caminho(ator.origem_rota(),ponto)
	if not rota.is_empty() and rota.all(func(c): return TerrenoPlex.contem(jogo.planta,c)): ator.andar(rota)
	return false

func caixa(grupo: Dictionary) -> int:
	var atual:=int(grupo.get("recepcao_caixa",-1))
	if jogo.planta.objetos.has(atual) and jogo.atendimento.ponto(atual,true).x>=0 and jogo.atendimento.ponto(atual,false).x>=0: return atual
	for entrada in EntradaVisitantesPlex.entradas(clientes):
		var preferida:=int(entrada.get("caixa",-1))
		if preferida>=0:
			grupo.recepcao_caixa=preferida
			return preferida
	for id in jogo.ambientes.equipamentos("registradora",["recepcao","salao"]):
		if jogo.atendimento.ponto(id,true).x>=0 and jogo.atendimento.ponto(id,false).x>=0:
			grupo.recepcao_caixa=id
			return id
	return -1

func formar_fila(grupo: Dictionary, id_caixa: int) -> bool:
	var raiz: Vector2i=jogo.atendimento.ponto(id_caixa,false)
	var opcoes: Array[Vector2i]=[]
	var outras: Array[Vector2i]=[]
	for outro in clientes.grupos.values():
		if outro.id==grupo.id or outro.estado!="recepcao": continue
		for p in outro.get("fila_recepcao",[]): outras.append(Vector2i(p[0],p[1]))
	var membros:=clientes.membros(grupo)
	var fila: Array=grupo.get("fila_recepcao",[])
	if fila.size()!=membros.size() or fila.any(func(p): return not clientes.chao(Vector2i(p[0],p[1])) or outras.has(Vector2i(p[0],p[1]))):
		var operador: Vector2i=jogo.atendimento.ponto(id_caixa,true)
		for y in range(raiz.y-4,raiz.y+5):
			for x in range(raiz.x-4,raiz.x+5):
				var c:=Vector2i(x,y)
				if not TerrenoPlex.contem(jogo.planta,c) or TerrenoPlex.borda(jogo.planta,c) or not clientes.chao(c) or c==operador or outras.has(c): continue
				if jogo.ambientes.em(c).get("id",-1)!=jogo.ambientes.em(raiz).get("id",-2): continue
				if jogo.personagens.any(func(a): return a.familia!=grupo.id and a.celula==c): continue
				opcoes.append(c)
		opcoes.sort_custom(func(a,b): return a.distance_squared_to(raiz)<b.distance_squared_to(raiz))
		fila=[]
		for i in mini(opcoes.size(),membros.size()): fila.append([opcoes[i].x,opcoes[i].y])
		grupo.fila_recepcao=fila
	if fila.size()!=membros.size(): return false
	var chegou:=false
	for i in membros.size():
		var a:=clientes.ator(membros[i])
		if not is_instance_valid(a) or ControleAdministradorPlex.ocupado(a): continue
		var ponto:=Vector2i(fila[i][0],fila[i][1])
		var pronto:=mover(a,ponto,"fila_recepcao")
		if i==0: chegou=pronto
	return chegou

func escolher_anfitriao(grupo: Dictionary) -> PersonagemPlex:
	var reservado:=clientes.ator(int(grupo.get("anfitriao",-1)))
	if is_instance_valid(reservado) and int(reservado.visita.get("recepcao_grupo",-1))==int(grupo.id): return reservado
	grupo.erase("anfitriao")
	var pagando: bool=clientes.grupos.values().any(func(g): return g.estado=="pagamento")
	for a in jogo.personagens:
		if a.cargo!="funcionario" or a.robo or not a.automatico or EquipePlex.em_comando(a) or FantasiasRestaurantePlex.ocupando(a): continue
		if a.funcao=="caixa" or not EquipePlex.permite(a,"atendimento"): continue
		if jogo.servicos.trabalhos.has(a.identificador) or jogo.tarefas.trabalhos.has(a.identificador) or a.carga_item>=0 or a.carregando: continue
		if pagando and (a.funcao=="caixa" or AdministradorPlex.eh(a)): continue
		if not TerrenoPlex.contem(jogo.planta,a.celula): continue
		a.movimento.cancelar()
		a.visita.recepcao_grupo=grupo.id
		grupo.anfitriao=a.identificador
		return a
	return null

func ponto_mesa(grupo: Dictionary, origem: Vector2i) -> Vector2i:
	var mesa: Dictionary=jogo.planta.objetos.get(int(grupo.mesa),{})
	if mesa.is_empty(): return Vector2i(-1,-1)
	var passagem: Dictionary={}
	for cadeira in LugaresPlex.cadeiras(jogo.planta,mesa):
		if cadeira<0: continue
		for c in jogo.planta.interacoes(cadeira): passagem[c]=true
	for id in FamiliasVisitantesPlex.membros(grupo):
		var pessoa:=clientes.ator(id)
		if not is_instance_valid(pessoa): continue
		var lugar:=AcompanhamentoVisitantesPlex.lugar(clientes,pessoa,grupo)
		if lugar.is_empty(): continue
		for c in jogo.rotas.aproximar(pessoa.origem_rota(),int(lugar.cadeira)): passagem[c]=true
	if grupo.has("posto_anfitriao"):
		var atual: Array=grupo.posto_anfitriao
		var c:=Vector2i(atual[0],atual[1])
		if clientes.chao(c) and not passagem.has(c): return c
	var pontos: Array[Vector2i]=[]
	for y in range(mesa.celula.y-3,mesa.celula.y+4):
		for x in range(mesa.celula.x-3,mesa.celula.x+4):
			var c:=Vector2i(x,y)
			if not TerrenoPlex.contem(jogo.planta,c) or TerrenoPlex.borda(jogo.planta,c) or not clientes.chao(c) or passagem.has(c): continue
			if jogo.planta.em(c).get("tipo","") in CatalogoPlex.PORTAS: continue
			if jogo.ambientes.em(c).get("id",-1)!=jogo.ambientes.em(mesa.celula).get("id",-2): continue
			if jogo.personagens.any(func(a): return a.celula==c and a.identificador!=int(grupo.get("anfitriao",-1))): continue
			pontos.append(c)
	pontos.sort_custom(func(a,b): return a.distance_squared_to(mesa.celula)*2+a.distance_squared_to(origem)<b.distance_squared_to(mesa.celula)*2+b.distance_squared_to(origem))
	for c in pontos:
		if not clientes.caminho(origem,c).is_empty():
			grupo.posto_anfitriao=[c.x,c.y]
			return c
	return Vector2i(-1,-1)

func atualizar(grupo: Dictionary, delta: float) -> void:
	if not jogo.operacao.aberto: liberar(grupo);return
	if not jogo.planta.objetos.has(int(grupo.mesa)):
		liberar(grupo)
		if not clientes.escolher_mesa(clientes.ator(int(grupo.adulta)),grupo): clientes.sair(grupo);return
	var id_caixa:=caixa(grupo)
	if id_caixa<0: liberar(grupo);return
	var fase:=str(grupo.get("fase_recepcao","fila"))
	var na_fila:=formar_fila(grupo,id_caixa) if fase!="acompanhar" else true
	var lider:=clientes.ator(int(grupo.adulta))
	if not is_instance_valid(lider):return
	if fase=="fila":
		var operador:PersonagemPlex=jogo.atendimento.funcionario(id_caixa)
		if not na_fila or not is_instance_valid(operador) or operador.ocupado() or operador.celula!=jogo.atendimento.ponto(id_caixa,true):return
		jogo.tarefas.orientar(operador,lider.local);jogo.tarefas.orientar(lider,operador.local)
		grupo.tempo_recepcao=float(grupo.get("tempo_recepcao",0.0))+delta
		if float(grupo.tempo_recepcao)<1.5:return
		grupo.atendido_por=operador.identificador;grupo.fase_recepcao="aguardar_anfitriao";grupo.tempo_recepcao=0.0
	var host:=escolher_anfitriao(grupo)
	if not is_instance_valid(host):return
	if grupo.fase_recepcao=="aguardar_anfitriao":
		var recepcao:=ao_lado_cliente(grupo,host,lider,id_caixa)
		if recepcao.x<0 or not mover(host,recepcao,"recepcionar"):return
		jogo.tarefas.orientar(host,lider.local);jogo.tarefas.orientar(lider,host.local)
		grupo.tempo_recepcao=float(grupo.get("tempo_recepcao",0.0))+delta
		if float(grupo.tempo_recepcao)<.75:return
		grupo.fase_recepcao="acompanhar";grupo.erase("fila_recepcao");grupo.acompanhado_por=host.identificador
	var ponto:=ponto_mesa(grupo,host.origem_rota())
	if ponto.x<0:
		grupo.estado="visita"
		grupo.recebido=true
		liberar(grupo)
		return
	mover(host,ponto,"acompanhar_mesa")
	var adultos:=FamiliasVisitantesPlex.adultos(grupo)
	for id in adultos:
		var a:=clientes.ator(id)
		if not is_instance_valid(a): continue
		var lugar:=AcompanhamentoVisitantesPlex.lugar(clientes,a,grupo)
		if not lugar.is_empty(): clientes.sentar(a,lugar)
	if adultos.all(func(id): return is_instance_valid(clientes.ator(id)) and clientes.ator(id).assento>=0 and not clientes.ator(id).ocupado()):
		grupo.estado="visita"
		grupo.recebido=true
		liberar(grupo)


func ao_lado_cliente(grupo:Dictionary,host:PersonagemPlex,lider:PersonagemPlex,id_caixa:int) -> Vector2i:
	var operador:Vector2i=jogo.atendimento.ponto(id_caixa,true)
	var opcoes:Array[Vector2i]=[]
	for d in GradePlex.VIZINHOS:
		var c:Vector2i=lider.celula+d
		if c==operador or not TerrenoPlex.contem(jogo.planta,c) or not clientes.chao(c):continue
		if jogo.ambientes.em(c).get("id",-1)!=jogo.ambientes.em(lider.celula).get("id",-2):continue
		if jogo.personagens.any(func(p):return p!=host and p.celula==c):continue
		opcoes.append(c)
	if grupo.has("posto_recepcao"):
		var salvo:Array=grupo.posto_recepcao;var c:=Vector2i(salvo[0],salvo[1])
		if opcoes.has(c):return c
	opcoes.sort_custom(func(a,b):return a.distance_squared_to(host.celula)<b.distance_squared_to(host.celula))
	for c in opcoes:
		if not clientes.caminho(host.origem_rota(),c).is_empty():grupo.posto_recepcao=[c.x,c.y];return c
	return Vector2i(-1,-1)

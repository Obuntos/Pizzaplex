class_name PartilhaPizzaPlex
extends RefCounted

const TEMPO_CORTE=2.4

static func lote_da_pessoa(todos: Array, adultos_ids: Array, cliente: int) -> Array:
	var adultos: Array=[]
	var criancas: Array=[]
	for membro in todos:
		var id:=int(membro)
		if adultos_ids.has(id): adultos.append(id)
		else: criancas.append(id)
	var lotes: Array=[]
	var solitaria:=-1
	for inicio in range(0,criancas.size(),4):
		var parte: Array=criancas.slice(inicio,inicio+4)
		if parte.size()==1 and not adultos.is_empty(): solitaria=int(parte[0])
		else: lotes.append(parte)
	var restantes: Array=adultos.duplicate()
	if solitaria>=0: lotes.append([int(restantes.pop_front()),solitaria])
	if not criancas.is_empty():
		while restantes.size()>=2: lotes.append([int(restantes.pop_front()),int(restantes.pop_front())])
	for id in restantes: lotes.append([int(id)])
	for lote in lotes:
		if lote.has(cliente): return lote
	return [cliente]

static func registrar(s: ServicosPlex, pedido: Dictionary) -> void:
	if int(pedido.get("familia",-1))<0 or s.recepcao==null: return
	var grupo: Dictionary=s.recepcao.clientes.grupos.get(int(pedido.familia),{})
	if grupo.is_empty(): return
	var todos: Array=FamiliasVisitantesPlex.membros(grupo)
	var adultos_ids:=FamiliasVisitantesPlex.adultos(grupo)
	var pessoas: Array=lote_da_pessoa(todos,adultos_ids,int(pedido.cliente))
	pedido.lote_partilha=str(pedido.familia)+";lote:"+str(pessoas[0])
	pedido.pessoas_partilha=pessoas
	pedido.porcoes_lote=pessoas.size()
	pedido.quota=4 if pessoas.size()==1 else 1
	pedido.fatias_restantes=pedido.quota
	for outro in s.pedidos:
		if outro.id==pedido.id or outro.get("lote_partilha","")!=pedido.lote_partilha or outro.has("partilha_raiz") or outro.estado=="cancelado": continue
		if outro.estado in ["entregue","consumido"] or outro.get("dividida",false):
			pedido.lote_partilha=str(pedido.familia)+";solo:"+str(pedido.id)
			pedido.pessoas_partilha=[int(pedido.cliente)]
			pedido.porcoes_lote=1
			pedido.quota=4
			pedido.fatias_restantes=4
			return
		outro.porcoes_lote=maxi(int(outro.get("porcoes_lote",1)),int(pedido.porcoes_lote))
		pedido.partilha_raiz=outro.id;pedido.estado="partilha";return

static func raiz(s: ServicosPlex, pedido: Dictionary) -> Dictionary:
	return s.pedido_por_id(int(pedido.get("partilha_raiz",pedido.id)))

static func fonte(s: ServicosPlex, pedido: Dictionary) -> int:
	return int(raiz(s,pedido).get("fonte_partilha",pedido.pizza)) if pedido.has("lote_partilha") else int(pedido.pizza)

static func compartilhada(pedido: Dictionary) -> bool:
	return pedido.has("lote_partilha") and int(pedido.get("porcoes_lote",1))>1

static func receber(s: ServicosPlex, pedido: Dictionary) -> void:
	pedido.estado="cortando" if compartilhada(pedido) and not pedido.get("dividida",false) else "entregue"
	pedido.tempo=RefeicoesPlex.TEMPO_FATIA
	pedido.tempo_corte=0.0
	RefeicoesPlex.visualizar(s,pedido)

static func marcar_fonte(s: ServicosPlex, pedido: Dictionary) -> void:
	if pedido.has("lote_partilha") and not pedido.has("partilha_raiz"): pedido.fonte_partilha=pedido.pizza
	if s.planta.objetos.has(int(pedido.pizza)): s.planta.objetos[int(pedido.pizza)].partilha_inteira=compartilhada(pedido)

static func emplatar(s: ServicosPlex, pedido: Dictionary, prato: int) -> bool:
	if pedido.has("partilha_raiz"): return false
	var colocado:=ApoiosPlex.fixar(s.planta,int(pedido.pizza),prato,ApoiosPlex.livre(s.planta,prato,"pizza"))
	if colocado: RefeicoesPlex.visualizar(s,pedido)
	return colocado

static func dividir(s: ServicosPlex, original: Dictionary, pedido: Dictionary) -> bool:
	var jogo: Node=s.recepcao.clientes.jogo
	var pessoa: PersonagemPlex=jogo.clientes.ator(int(pedido.cliente))
	if not is_instance_valid(pessoa) or pessoa.assento<0 or pessoa.ocupado(): return false
	var prato:=int(pedido.get("prato",-1))
	if not s.planta.objetos.has(prato): prato=FestasRestaurantePlex.new(jogo).prato(pessoa,int(pedido.mesa),int(pedido.slot))
	if prato<0: return false
	var id:=int(pedido.pizza)
	if pedido.has("partilha_raiz"):
		id=s.inventario.criar("pizza",pessoa.celula)
		if not ApoiosPlex.fixar(s.planta,id,prato,ApoiosPlex.livre(s.planta,prato,"pizza")): s.planta.remover(id);return false
	if not s.planta.objetos.has(id): return false
	pedido.pizza=id;pedido.prato=prato;pedido.dividida=true;pedido.estado="entregue";pedido.sabor=original.get("sabor","mucarela");pedido.tempo=RefeicoesPlex.TEMPO_FATIA;pedido.fatias_comidas=0
	var grupo: Dictionary=jogo.clientes.grupos.get(int(pedido.familia),{})
	var membros: Array=FamiliasVisitantesPlex.membros(grupo) if not grupo.is_empty() else []
	var lote: Array=pedido.get("pessoas_partilha",membros.slice(floori(float(membros.find(int(pedido.cliente)))/4)*4,floori(float(membros.find(int(pedido.cliente)))/4)*4+4))
	pedido.quota=maxi(1,floori(4.0/float(maxi(1,lote.size())))+(1 if lote.find(int(pedido.cliente))<posmod(4,maxi(1,lote.size())) else 0))
	pedido.fatias_restantes=pedido.quota
	s.planta.objetos[id].partilha_inteira=false
	RefeicoesPlex.visualizar(s,pedido)
	return true

static func atualizar(s: ServicosPlex, delta: float=0.0) -> void:
	for pedido in s.pedidos:
		if pedido.estado not in ["preparando","assando","pronta","entregando"]: continue
		var comida: Dictionary=s.planta.objetos.get(int(pedido.get("pizza",-1)),{})
		if not comida.is_empty() and (MobiliaPlex.visual(comida).begins_with("festa_fatia_pizza_") or str(comida.get("estado_visual",comida.get("estado","")))!="fatias_4"): RefeicoesPlex.visualizar(s,pedido)
	if s.recepcao==null: return
	var jogo: Node=s.recepcao.clientes.jogo
	var pendentes: Dictionary={}
	for pedido in s.pedidos:
		if pedido.estado!="partilha" or not pedido.has("partilha_raiz"): continue
		var id:=int(pedido.partilha_raiz)
		if not pendentes.has(id): pendentes[id]=[]
		pendentes[id].append(pedido)
	for original in s.pedidos:
		if original.has("partilha_raiz") or not compartilhada(original) or original.estado!="cortando" and not pendentes.has(int(original.id)): continue
		if original.estado=="cortando":
			var grupo: Dictionary=jogo.clientes.grupos.get(int(original.familia),{})
			var adulto: PersonagemPlex=jogo.clientes.ator(int(grupo.get("adulta",-1)))
			if not is_instance_valid(adulto) or adulto.assento<0 or adulto.ocupado(): continue
			adulto.visita.cortando_pizza=true
			original.tempo_corte=float(original.get("tempo_corte",0.0))+delta
			if float(original.tempo_corte)<TEMPO_CORTE: continue
			adulto.visita.erase("cortando_pizza")
			if dividir(s,original,original): original.corte_concluido=true
		if not original.get("corte_concluido",false): continue
		for pedido in pendentes.get(int(original.id),[]): dividir(s,original,pedido)

static func valor_por_pessoas(quantidade: int) -> float:
	if quantidade<=0: return 0.0
	if quantidade<=2: return float(quantidade)
	return 2.0+float(quantidade-2)*1.5

static func conta(s: ServicosPlex, familia: int) -> Dictionary:
	var mesas: Dictionary={}
	var lotes: Dictionary={}
	for pedido in s.pedidos:
		if int(pedido.get("familia",-1))!=familia or pedido.estado!="consumido": continue
		lotes[str(pedido.get("lote_partilha",pedido.id))]=true
		var mesa:=int(pedido.get("mesa",-1))
		var cliente:=int(pedido.get("cliente",-1))
		if cliente<0: continue
		if not mesas.has(mesa): mesas[mesa]={}
		mesas[mesa][cliente]=true
	var acrescimo:=0.0
	var atendidos:=0
	for pessoas in mesas.values():
		atendidos+=pessoas.size()
		acrescimo+=valor_por_pessoas(pessoas.size())
	var base:=25.0*lotes.size()
	return {"base":base,"acrescimo":acrescimo,"pessoas":atendidos,"total":snappedf(base+acrescimo,.01)}

static func valor(s: ServicosPlex, familia: int) -> float:
	return float(conta(s,familia).total)

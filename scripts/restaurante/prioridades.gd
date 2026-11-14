class_name PrioridadesServicoPlex
extends RefCounted

static func solicitar(jogo: Node, alvo: int, acao: String="limpar") -> void:
	if not jogo.planta.objetos.has(alvo): return
	var s: ServicosPlex=jogo.servicos
	s.prioridades=s.prioridades.filter(func(p): return int(p.alvo)!=alvo)
	s.prioridades.push_front({"alvo":alvo,"acao":acao})
	if acao=="atender": ordenar(s,alvo)

static func ordenar(s: ServicosPlex, mesa: int) -> void:
	var primeiros: Array[Dictionary]=[]
	var outros: Array[Dictionary]=[]
	for p in s.pedidos:
		if int(p.mesa)==mesa: primeiros.append(p)
		else: outros.append(p)
	s.pedidos.assign(primeiros+outros)

static func suja(s: ServicosPlex, id: int) -> bool:
	for f in ApoiosPlex.filhos(s.planta,id):
		if f.tipo=="prato" and (f.get("sujo",false) or ApoiosPlex.filhos(s.planta,f.id).any(func(o): return o.tipo=="restos_mesa")): return true
		if f.tipo in ["guarana_copo","guarana_tampa"] and f.estado=="vazio": return true
	return false

static func atribuir(s: ServicosPlex, a: PersonagemPlex) -> bool:
	for p in s.prioridades.duplicate():
		var id:=int(p.alvo)
		var item: Dictionary=s.planta.objetos.get(id,{})
		if item.is_empty(): s.prioridades.erase(p);continue
		if p.acao in ["lavar_item","descartar_item"]:
			if not LimpezaItensPlex.eh(item):s.prioridades.erase(p);continue
			if EquipePlex.permite(a,"limpeza") and LimpezaItensPlex.iniciar(s,a,id,p.acao=="descartar_item"):return true
		elif p.acao=="atender":
			if not s.pedidos.any(func(o): return int(o.mesa)==id and o.estado not in ["consumido","cancelado"]):
				s.prioridades.erase(p);continue
			ordenar(s,id)
			if EquipePlex.permite(a,"atendimento") and (s.servir(a) or BebidasPlex.servir(s,a)): return true
			if EquipePlex.permite(a,"cozinha") and s.cozinhar(a): return true
		elif p.acao=="limpar":
			if LugaresPlex.mesa(str(item.tipo)):
				if not suja(s,id): s.prioridades.erase(p);continue
				if not EquipePlex.permite(a,"limpeza"): continue
				if s.lavar(a,id) or BebidasPlex.recolher(s,a,id): return true
			elif LimpezaAmbientesPlex.eh(item):
				if EquipePlex.permite(a,"limpeza") and s.limpar_alvo(a,id): return true
			else: s.prioridades.erase(p)
	return false

static func solicitar_sala(jogo: Node, celula: Vector2i) -> void:
	var sala: Dictionary=jogo.ambientes.em(celula)
	var total:=0
	for item in jogo.planta.objetos.values():
		if not sala.get("celulas",[]).has(item.celula):continue
		if LimpezaAmbientesPlex.eh(item) or LugaresPlex.mesa(str(item.tipo)) and suja(jogo.servicos,int(item.id)):
			solicitar(jogo,int(item.id),"limpar");total+=1

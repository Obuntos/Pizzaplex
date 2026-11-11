class_name MesasVisitasPlex
extends RefCounted

static func mesas(clientes: ClientesPlex, grupo: Dictionary) -> Array[int]:
	var ids: Array[int]=[]
	for item in clientes.jogo.planta.objetos.values():
		if LugaresPlex.mesa(item.tipo) and (int(item.get("familia_cliente",-1))==int(grupo.get("id",-2)) or int(item.id)==int(grupo.get("mesa",-1)) or grupo.get("mesas_extras",[]).has(item.id)): ids.append(int(item.id))
	return ids

static func sujar(clientes: ClientesPlex, mesa: int) -> bool:
	var mudou:=false
	var planta: PlantaPlex=clientes.jogo.planta
	for prato in ApoiosPlex.filhos(planta,mesa):
		if prato.tipo!="prato" or int(prato.get("carregada_por",0))>0: continue
		if not prato.get("sujo",false): prato.sujo=true;mudou=true
		for comida in ApoiosPlex.filhos(planta,prato.id):
			if comida.tipo=="pizza" or str(MobiliaPlex.visual(comida)).begins_with("festa_fatia_"):
				planta.remover(comida.id);mudou=true
		var reserva:=int(prato.get("reserva",0))
		if reserva>0 and not clientes.jogo.servicos.trabalhos.has(reserva) and not clientes.jogo.tarefas.trabalhos.has(reserva): prato.reserva=0;mudou=true
	return mudou

static func reserva_orfa(clientes: ClientesPlex, item: Dictionary) -> bool:
	var dono:=int(item.get("reserva",0))
	if dono<=0 or clientes.jogo.servicos.trabalhos.has(dono) or clientes.jogo.tarefas.trabalhos.has(dono): return false
	item.reserva=0
	return true

static func pedidos(clientes: ClientesPlex, mesa: int) -> Dictionary:
	var resultado: Dictionary={"pendente":false,"mudou":false}
	var servicos: ServicosPlex=clientes.jogo.servicos
	for pedido in servicos.pedidos:
		if int(pedido.mesa)!=mesa or pedido.estado in ["consumido","cancelado"]: continue
		var familia:=int(pedido.get("familia",-1))
		var grupo: Dictionary=clientes.grupos.get(familia,{})
		if familia<0 or not grupo.is_empty() and grupo.get("estado","")!="saindo": resultado.pendente=true;continue
		for id in servicos.trabalhos.keys():
			var tarefa: Dictionary=servicos.trabalhos[id]
			if not tarefa.get("pedidos",[tarefa.get("pedido",-1)]).has(int(pedido.id)): continue
			var funcionario:=clientes.ator(int(id))
			if is_instance_valid(funcionario): servicos.cancelar(funcionario)
		FornoPlex.liberar(servicos.planta,int(pedido.id))
		pedido.estado="cancelado";pedido.bebida_estado="cancelada"
		resultado.mudou=true
	return resultado

static func liberar(clientes: ClientesPlex, grupo: Dictionary) -> void:
	var planta: PlantaPlex=clientes.jogo.planta
	var mudou:=false
	for membro in clientes.membros(grupo):
		var pessoa:=clientes.ator(membro)
		if is_instance_valid(pessoa):
			pessoa.assento=-1;pessoa.visita.erase("cadeira");pessoa.visita.erase("mesa")
	for id in mesas(clientes,grupo):
		var item: Dictionary=planta.objetos[id]
		if int(item.get("familia_cliente",-1)) not in [-1,int(grupo.get("id",-2))]: continue
		if int(item.get("familia_cliente",-1))>=0: item.familia_cliente=-1;mudou=true
		mudou=reserva_orfa(clientes,item) or mudou
		mudou=sujar(clientes,id) or mudou
		for cadeira_id in LugaresPlex.cadeiras(planta,item):
			var cadeira: Dictionary=planta.objetos.get(cadeira_id,{})
			if not cadeira.is_empty() and clientes.membros(grupo).has(int(cadeira.get("reserva",0))): cadeira.reserva=0;mudou=true
	if mudou: planta.alterada.emit()

static func reconciliar(clientes: ClientesPlex) -> void:
	var planta: PlantaPlex=clientes.jogo.planta
	var mudou:=false
	for item in planta.objetos.values():
		if not LugaresPlex.mesa(item.tipo): continue
		var dono:=int(item.get("familia_cliente",-1))
		var g: Dictionary=clientes.grupos.get(dono,{})
		if not g.is_empty() and g.get("estado","")!="saindo" and clientes.membros(g).any(func(id): return is_instance_valid(clientes.ator(id)) and not clientes.ator(id).visita.get("morto",false)): continue
		var cadeiras:=LugaresPlex.cadeiras(planta,item)
		if clientes.jogo.personagens.any(func(a): return a.assento>=0 and cadeiras.has(a.assento) and a.trabalho=="sentar_mesa"): continue
		mudou=reserva_orfa(clientes,item) or mudou
		if dono>=0: item.familia_cliente=-1;mudou=true
		var estado:=pedidos(clientes,int(item.id))
		mudou=estado.mudou or mudou
		if estado.pendente: continue
		mudou=sujar(clientes,item.id) or mudou
	if mudou: planta.alterada.emit()

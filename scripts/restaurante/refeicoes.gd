class_name RefeicoesPlex
extends RefCounted

const FATIAS=4
const TEMPO_FATIA=12.0

static func preparar(pedido: Dictionary) -> void:
	if not pedido.has("fatias_restantes"): pedido.fatias_restantes=FATIAS
	if not pedido.has("fatias_comidas"): pedido.fatias_comidas=0

static func visualizar(servico: ServicosPlex, pedido: Dictionary) -> void:
	var pizza: Dictionary=servico.planta.objetos.get(int(pedido.get("pizza",-1)),{})
	if pizza.is_empty(): return
	var prato: Dictionary=servico.planta.objetos.get(int(pizza.get("sobre",-1)),{})
	var na_mesa: bool=prato.get("tipo","")=="prato" and int(prato.get("sobre",-1))==int(pedido.get("mesa",-2))
	var servida: bool=na_mesa and bool(pedido.get("dividida",false)) and pedido.estado in ["entregue","consumido"]
	var sabor:=str(pedido.get("sabor",["mucarela","calabresa","vegetariana"][posmod(int(pedido.id),3)]))
	pedido.sabor=sabor
	var variante:="festa_fatia_pizza_"+sabor if servida else "festa_pizza_quatro_fatias"
	var inteira: bool=not na_mesa or pedido.estado not in ["entregue","consumido"] or PartilhaPizzaPlex.compartilhada(pedido) and not pedido.get("dividida",false)
	var estado:=("mordida" if float(pedido.get("tempo",TEMPO_FATIA))<TEMPO_FATIA*.5 else "inteira") if servida else "fatias_"+str(4 if inteira else maxi(1,int(pedido.fatias_restantes)))
	var fatias:=4 if inteira else int(pedido.fatias_restantes)
	if pizza.get("variante","")==variante and pizza.get("estado_visual","")==estado and pizza.get("estado","")==estado and int(pizza.get("fatias",-1))==fatias:return
	pizza.variante=variante;pizza.estado_visual=estado;pizza.estado=estado;pizza.fatias=fatias
	servico.planta.alterada.emit()

static func consumir(servico: ServicosPlex, pedido: Dictionary, delta: float) -> void:
	preparar(pedido)
	var cliente: PersonagemPlex=null
	if int(pedido.get("cliente",-1))>=0:
		for a in servico.personagens:
			if a.identificador==int(pedido.cliente): cliente=a;break
		if not is_instance_valid(cliente) or cliente.ocupado() or cliente.trabalho!="sentar_mesa": return
		var mesa: Dictionary=servico.planta.objetos.get(int(pedido.mesa),{})
		if mesa.is_empty(): return
		var cadeiras:=LugaresPlex.cadeiras(servico.planta,mesa)
		var slot:=int(pedido.get("slot",-1))
		if slot<0 or slot>=cadeiras.size() or cliente.assento!=cadeiras[slot]: return
	OcorrenciasClientesPlex.derramar(servico,pedido,cliente,false)
	pedido.tempo=float(pedido.get("tempo",TEMPO_FATIA))-delta
	if pedido.tempo>0:
		var item: Dictionary=servico.planta.objetos.get(int(pedido.get("pizza",-1)),{})
		if pedido.tempo<TEMPO_FATIA*.5 and item.get("estado","")!="mordida": visualizar(servico,pedido)
		return
	pedido.fatias_restantes=maxi(0,int(pedido.fatias_restantes)-1)
	pedido.fatias_comidas=int(pedido.fatias_comidas)+1
	pedido.tempo=TEMPO_FATIA
	if is_instance_valid(cliente): cliente.visita.fatias_comidas=int(cliente.visita.get("fatias_comidas",0))+1
	if int(pedido.fatias_restantes)>0: visualizar(servico,pedido);return
	var pizza: Dictionary=servico.planta.objetos.get(int(pedido.pizza),{})
	var pai:=int(pizza.get("sobre",pedido.mesa))
	if not pizza.is_empty(): servico.planta.remover(pizza.id)
	var prato: Dictionary=servico.planta.objetos.get(pai,{})
	if prato.get("tipo","")=="prato": prato.sujo=true;prato.limpeza_liberar=servico.tempo_servico+EsperaLimpezaPlex.INTERVALO
	var restos:=servico.inventario.criar("restos_mesa",servico.planta.objetos[pedido.mesa].celula)
	var slot_restos:=ApoiosPlex.livre(servico.planta,pai,"restos_mesa")
	if slot_restos>=0: ApoiosPlex.fixar(servico.planta,restos,pai,slot_restos)
	else: servico.planta.remover(restos)
	pedido.estado="consumido"

static func mesa_livre(grupo: Dictionary, pessoa: PersonagemPlex, clientes: ClientesPlex) -> Dictionary:
	var planta: PlantaPlex=clientes.jogo.planta
	var mesas: Array=[int(pessoa.visita.get("mesa",grupo.mesa)),int(grupo.mesa)]
	mesas.append_array(grupo.get("mesas_extras",[]))
	mesas.append_array(clientes.jogo.ambientes.equipamentos("mesa",["salao"]))
	var vistos: Dictionary={}
	for valor in mesas:
		var id:=int(valor)
		if vistos.has(id): continue
		vistos[id]=true
		var mesa: Dictionary=planta.objetos.get(id,{})
		if mesa.is_empty() or int(mesa.get("familia_cliente",-1)) not in [-1,int(grupo.id)]: continue
		if not clientes.jogo.ambientes.permite(id,["salao","salao_festas"]):continue
		var cadeiras:=LugaresPlex.cadeiras(planta,mesa)
		var atual:=int(pessoa.visita.get("cadeira",-1))
		if atual>=0 and cadeiras.has(atual): return {"mesa":id,"cadeira":atual,"slot":cadeiras.find(atual)}
		for slot in cadeiras.size():
			var cadeira:=cadeiras[slot]
			if cadeira<0 or clientes.jogo.personagens.any(func(a): return a!=pessoa and (a.assento==cadeira or int(a.visita.get("cadeira",-1))==cadeira)): continue
			if not ApoiosPlex.filhos(planta,id,slot).is_empty(): continue
			if clientes.jogo.rotas.aproximar(pessoa.origem_rota(),cadeira).is_empty(): continue
			mesa.familia_cliente=int(grupo.id)
			if id!=int(grupo.mesa):
				if not grupo.has("mesas_extras"): grupo.mesas_extras=[]
				if not grupo.mesas_extras.has(id): grupo.mesas_extras.append(id)
			pessoa.visita.merge({"mesa":id,"cadeira":cadeira,"slot":slot},true)
			return {"mesa":id,"cadeira":cadeira,"slot":slot}
	return {}

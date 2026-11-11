class_name SacosLixoPlex
extends RefCounted

static func externa(planta: PlantaPlex, item: Dictionary) -> bool:
	return DescartePlex.eh(item) and not TerrenoPlex.contem(planta,item.celula)

static func iniciar(servico: ServicosPlex, ator: PersonagemPlex) -> bool:
	if not ator.carga_extra.is_empty(): return false
	var carregado: Dictionary=servico.planta.objetos.get(ator.carga_item,{})
	if not carregado.is_empty() and carregado.tipo!="saco_lixo": return false
	var origens: Array=[]
	if carregado.get("tipo","")=="saco_lixo": origens.append(carregado)
	else:
		for item in servico.planta.objetos.values():
			if not servico.livre(item.id): continue
			if item.tipo=="saco_lixo" or (DescartePlex.interna(servico.planta,item) and int(item.get("lixo",0))>=6): origens.append(item)
	var externas:=servico.planta.objetos.values().filter(func(item): return externa(servico.planta,item) and servico.livre(item.id))
	externas.sort_custom(func(a,b): return ator.celula.distance_squared_to(a.celula)<ator.celula.distance_squared_to(b.celula))
	for origem in origens:
		for destino in externas:
			var passos: Array=[]
			var reservas: Array=[destino.id]
			if origem.id!=ator.carga_item:
				passos.append(servico.etapa(origem.id,"pegar" if origem.tipo=="saco_lixo" else "coletar_lixo",1.0))
				reservas.append(origem.id)
			passos.append(servico.etapa(destino.id,"descartar_saco",1.2,{"descarte_externo":true}))
			var retorno:=Vector2i(origem.get("origem_interna",[ator.celula.x,ator.celula.y])[0],origem.get("origem_interna",[ator.celula.x,ator.celula.y])[1]) if origem.tipo=="saco_lixo" else ator.celula
			if not TerrenoPlex.contem(servico.planta,retorno) or not servico.planta.transitavel(retorno): continue
			passos.append(servico.etapa(-1,"retornar_restaurante",.1,{"celula":[retorno.x,retorno.y],"descarte_externo":true}))
			if servico.iniciar(ator,"Retirar saco de lixo",passos,reservas): return true
	return false

static func executar(servico: ServicosPlex, ator: PersonagemPlex, passo: Dictionary) -> bool:
	var item: Dictionary=servico.planta.objetos.get(passo.alvo,{})
	if passo.acao=="coletar_lixo":
		if ator.carga_item>=0 or not DescartePlex.interna(servico.planta,item) or int(item.get("lixo",0))<6: return false
		var id:=servico.inventario.criar("saco_lixo",ator.celula)
		var saco: Dictionary=servico.planta.objetos[id]
		saco.origem_interna=[ator.celula.x,ator.celula.y]
		saco.lixo_quantidade=int(item.lixo)
		saco.solto=true
		if not servico.inventario.pegar(ator,id): servico.planta.remover(id);return false
		item.lixo=0;item.estado=str(MobiliaPlex.dados(item).get("estado_padrao","vazia"))
		servico.planta.alterada.emit()
		return true
	if passo.acao=="descartar_saco":
		var saco: Dictionary=servico.planta.objetos.get(ator.carga_item,{})
		if not externa(servico.planta,item) or saco.get("tipo","")!="saco_lixo": return false
		item.sacos_recolhidos=int(item.get("sacos_recolhidos",0))+1
		var id:=ator.carga_item
		ator.carga_item=-1
		servico.planta.remover(id)
		return true
	return passo.acao=="retornar_restaurante"

class_name PratosPlex
extends RefCounted

static func papel(item: Dictionary) -> bool:
	return bool(item.get("descartavel",false)) or str(item.get("material_prato",""))=="papel" or MobiliaPlex.visual(item).contains("prato_papel")

static func criar(inventario: InventarioPlex, caixa: Dictionary, celula: Vector2i) -> int:
	var material:=str(caixa.get("material_prato","ceramica"))
	var id:=inventario.criar("prato",celula)
	var prato: Dictionary=inventario.planta.objetos[id]
	prato.material_prato=material
	prato.descartavel=material=="papel"
	prato.variante=str(caixa.get("visual_prato","festa_prato_papel_liso" if prato.descartavel else "festa_prato_ceramica_raso"))
	prato.estado_visual=str(caixa.get("cor_prato","branco")) if prato.descartavel else "padrao"
	prato.estado=prato.estado_visual
	prato.sujo=false
	return id

static func descartar(servico: ServicosPlex, ator: PersonagemPlex, mesa_alvo: int=-1, prato_alvo:int=-1) -> bool:
	for prato in servico.planta.objetos.values():
		if prato_alvo>=0 and int(prato.id)!=prato_alvo:continue
		if mesa_alvo>=0 and int(prato.get("sobre",-1))!=mesa_alvo:continue
		if prato.tipo!="prato" or not papel(prato) or FestasRestaurantePlex.reservar_prato(servico,prato) or not prato.get("sujo",false) or not servico.livre(prato.id): continue
		if not EsperaLimpezaPlex.pode(servico,prato,prato_alvo>=0 or mesa_alvo>=0):continue
		var filhos:=ApoiosPlex.filhos(servico.planta,prato.id)
		if filhos.any(func(f): return f.tipo!="restos_mesa" or not servico.livre(f.id)): continue
		var opcoes:=servico.encontrar("lixeira")
		opcoes=DescartePlex.ordenar(servico,ator.origem_rota(),ator,opcoes.map(func(id): return servico.planta.objetos[id]))
		for lixeira in opcoes:
			if int(lixeira.get("lixo",0))>=6: continue
			var reservas:=RotinasPlex.reservas(servico,[prato.id,lixeira.id])
			for filho in filhos: reservas.append(filho.id)
			if servico.iniciar(ator,"Descartar prato de papel",[servico.etapa(prato.id,"pegar"),servico.etapa(lixeira.id,"descartar_prato",.8)],reservas): return true
	return false

static func executar(servico: ServicosPlex, ator: PersonagemPlex, lixeira: Dictionary) -> bool:
	var id:=ator.carga_item
	var prato: Dictionary=servico.planta.objetos.get(id,{})
	if prato.get("tipo","")!="prato" or not papel(prato) or int(lixeira.get("lixo",0))>=6: return false
	for filho in ApoiosPlex.filhos(servico.planta,id): servico.planta.remover(filho.id)
	ator.carga_item=ator.carga_extra.pop_front() if not ator.carga_extra.is_empty() else -1
	servico.planta.remover(id)
	lixeira.lixo=int(lixeira.get("lixo",0))+1
	if int(lixeira.lixo)>=6: lixeira.estado="cheia"
	servico.limpezas+=1
	return true

static func preferidos(servico: ServicosPlex, itens: Array) -> Array:
	var resultado:=itens.duplicate()
	resultado.sort_custom(func(a,b):
		var primeiro: bool=str(a.get("material_prato","ceramica"))==servico.preferencia_prato
		var segundo: bool=str(b.get("material_prato","ceramica"))==servico.preferencia_prato
		return primeiro and not segundo if primeiro!=segundo else int(a.id)<int(b.id))
	return resultado

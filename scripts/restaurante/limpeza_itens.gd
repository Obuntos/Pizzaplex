class_name LimpezaItensPlex
extends RefCounted

static func eh(item:Dictionary) -> bool:
	return item.get("tipo","") in ["prato","guarana_copo","guarana_tampa","copo_bebida"] and int(item.get("sobre",-1))<0 and int(item.get("carregada_por",0))==0

static func iniciar(s:ServicosPlex,a:PersonagemPlex,id:int,descartar:bool=false) -> bool:
	var item:Dictionary=s.planta.objetos.get(id,{})
	if not eh(item) or not s.livre(id):return false
	if item.tipo=="prato" and not PratosPlex.papel(item) and not descartar:
		item.sujo=true
		return s.lavar(a,-1,id)
	for lixeira in DescartePlex.ordenar(s,a.origem_rota(),a,s.planta.objetos.values().filter(func(o):return DescartePlex.interna(s.planta,o) and s.livre(o.id) and int(o.get("lixo",0))<6)):
		var reservas:Array=[id,lixeira.id]
		for f in ApoiosPlex.filhos(s.planta,id):reservas.append(f.id)
		var passos:Array=[s.etapa(id,"pegar"),s.etapa(lixeira.id,"descartar_item",.7,{"item":id})]
		if s.iniciar(a,"Recolher item do chão",passos,reservas):return true
	return false

static func executar(s:ServicosPlex,a:PersonagemPlex,passo:Dictionary) -> bool:
	var id:=int(passo.dados.item)
	if not InventarioPlex.tem(a,id):return false
	for filho in ApoiosPlex.filhos(s.planta,id):s.planta.remover(filho.id)
	s.planta.remover(id)
	if a.carga_item==id:a.carga_item=a.carga_extra.pop_front() if not a.carga_extra.is_empty() else -1
	else:a.carga_extra.erase(id)
	s.planta.objetos[passo.alvo].lixo=int(s.planta.objetos[passo.alvo].get("lixo",0))+1
	s.planta.reindexar();s.planta.alterada.emit()
	return true

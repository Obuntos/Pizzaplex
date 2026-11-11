class_name LimpezaAmbientesPlex
extends RefCounted

static func eh(item: Dictionary) -> bool:
	if item.is_empty(): return false
	return (item.get("tipo","")=="restos_mesa" and int(item.get("sobre",-1))<0) or item.get("tipo","") in ["mancha_chao","bebida_derramada"] or ManchasPlex.eh(str(item.get("tipo",""))) or str(item.get("tipo","")).begins_with("festa_confetes") or MobiliaPlex.dados(item).get("entulho",false) or MobiliaPlex.dados(item).get("sujeira",false)

static func acessivel(servico: ServicosPlex, item: Dictionary) -> bool:
	return servico.tempo_servico>=float(item.get("limpeza_apos",0.0)) and eh(item) and TerrenoPlex.contem(servico.planta,item.celula) and int(item.get("sobre",-1))<0 and servico.livre(item.id)

static func iniciar(servico: ServicosPlex, ator: PersonagemPlex, id: int) -> bool:
	var item: Dictionary=servico.planta.objetos.get(id,{})
	if item.is_empty() or not acessivel(servico,item): return false
	var tipo: String="balde" if item.tipo=="bebida_derramada" else "vassoura"
	var lixeiras:=servico.planta.objetos.values().filter(func(o): return DescartePlex.interna(servico.planta,o) and servico.livre(o.id) and int(o.get("lixo",0))<6)
	if lixeiras.is_empty(): return false
	var ferramentas:=servico.planta.objetos.values().filter(func(o): return o.tipo==tipo and not o.has("tutorial_dono") and servico.livre(o.id))
	ferramentas.sort_custom(func(a,b): return Vector2(a.celula).distance_squared_to(ator.local)<Vector2(b.celula).distance_squared_to(ator.local))
	lixeiras=DescartePlex.ordenar(servico,item.celula,ator,lixeiras)
	for ferramenta in ferramentas:
		var passos: Array=[servico.etapa(ferramenta.id,"pegar"),servico.etapa(id,"limpar",2.5)]
		var reservas: Array=[id,ferramenta.id]
		for lixeira in lixeiras:
			var com_descarte:=passos+[servico.etapa(lixeira.id,"lixo",.7),servico.etapa(ferramenta.id,"devolver",.5)]
			if servico.iniciar(ator,"Limpar ambiente",com_descarte,reservas+[lixeira.id]): return true
	return false

static func descartar(servico: ServicosPlex, ator: PersonagemPlex) -> bool:
	if int(ator.visita.get("lixo_limpeza",0))<=0: return false
	var lixeiras:=servico.planta.objetos.values().filter(func(item): return DescartePlex.eh(item) and servico.livre(item.id) and int(item.get("lixo",0))<6)
	for item in DescartePlex.ordenar(servico,ator.origem_rota(),ator,lixeiras):
		if servico.iniciar(ator,"Descartar resíduos",[servico.etapa(item.id,"lixo",.7)],[item.id]): return true
	return false


static func remocao_direta(item:Dictionary) -> bool:
	return item.get("tipo","")=="cenario_buraco_madeira"

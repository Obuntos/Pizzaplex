class_name CompraTerrenosPlex
extends RefCounted

const LOTES={"padaria":{"nome":"Padaria","preco":500,"lado":"Esquerda","area":[23,25,10,10],"predio":"cidade_padaria_10_10"},"farmacia":{"nome":"Farmácia","preco":1000,"lado":"Direita","area":[45,25,10,10],"predio":"cidade_farmacia_10_10"},"floricultura":{"nome":"Floricultura","preco":750,"lado":"Fundos","area":[33,13,10,12],"predio":"cidade_floricultura_10_10"},"posto":{"nome":"Posto de gasolina","preco":1500,"lado":"Fundos à direita","area":[47,12,10,13],"predio":"cidade_posto_gasolina_10_10","requer":"farmacia"}}

static func lote(id: String) -> Rect2i:
	var r: Array=LOTES.get(id,{}).get("area",[])
	return Rect2i(r[0],r[1],r[2],r[3]) if r.size()==4 else Rect2i()

static func preco(_jogo: Node, id: String="padaria") -> int: return int(LOTES.get(id,{}).get("preco",0))

static func substituido(planta: PlantaPlex, tipo: String) -> bool:
	for id in LOTES:
		if planta.terrenos_adquiridos.get(id,false) and tipo==LOTES[id].predio: return true
	return false

static func motivo(jogo: Node, id: String) -> String:
	if not LOTES.has(id): return "Terreno indisponível."
	if not jogo.planta.bairro_ativo: return "Disponível no bairro."
	if jogo.planta.terrenos_adquiridos.get(id,false): return "Adquirido"
	var requer:=str(LOTES[id].get("requer",""))
	if not requer.is_empty() and not jogo.planta.terrenos_adquiridos.get(requer,false): return "Compre a "+str(LOTES[requer].nome)+" antes."
	if not jogo.planta.objetos.values().any(func(o): return o.tipo==LOTES[id].predio and o.celula==lote(id).position): return "Imóvel indisponível."
	if jogo.servicos.saldo<preco(jogo,id): return "Saldo insuficiente."
	return ""

static func comprar(jogo: Node, id: String) -> bool:
	var erro:=motivo(jogo,id)
	if not erro.is_empty(): return false
	var layout:=LayoutsImoveisPlex.carregar(id)
	if layout.is_empty(): return false
	var planta: PlantaPlex=jogo.planta
	var limite:=lote(id)
	var bloqueado:=planta.is_blocking_signals()
	planta.set_block_signals(true)
	jogo.servicos.saldo-=preco(jogo,id)
	planta.terrenos_adquiridos[id]=true
	for objeto in planta.objetos.values():
		if not limite.has_point(objeto.celula): continue
		if objeto.get("cidade",false) or objeto.get("cidade_fixo",false) or objeto.tipo==LOTES[id].predio: planta.remover(objeto.id)
	LayoutsImoveisPlex.aplicar(planta,id,layout)
	if "visuais" in jogo.bairro:
		for efeito in jogo.bairro.visuais.duplicate():
			if str(efeito.registro[0])==LOTES[id].predio: jogo.bairro.visuais.erase(efeito);efeito.queue_free()
	if "ids_mapa" in jogo.bairro:
		for indice in jogo.bairro.ids_mapa.keys():
			if not planta.objetos.has(jogo.bairro.ids_mapa[indice]): jogo.bairro.ids_mapa.erase(indice)
	planta.reindexar()
	planta.set_block_signals(bloqueado)
	planta.alterada.emit()
	planta.notificar_piso()
	jogo.bairro.assinatura=""
	jogo.bairro.terreno.assinatura=""
	jogo.bairro.terreno.atualizar()
	jogo.chao.queue_redraw()
	jogo.limites_terreno.assinatura=-1
	jogo.limites_terreno.atualizar()
	aplicar_moradores(jogo)
	jogo.painel.mensagem(str(LOTES[id].nome)+" adquirida.")
	return true

static func aplicar_moradores(jogo: Node) -> void:
	if jogo.populacao==null: return
	var fechados: Array=["floricultura","posto"].filter(func(id): return jogo.planta.terrenos_adquiridos.get(id,false))
	if fechados.is_empty(): return
	for perfil in jogo.populacao.perfis.values():
		if str(perfil.get("trabalho","")) in fechados:
			perfil.fora_mapa=true
			for a in jogo.personagens.duplicate():
				if str(a.identidade.get("morador_id",""))==str(perfil.id): jogo.despawn(a)
			continue
		for lista in perfil.get("rotinas",{}).values():
			for passo in lista:
				if str(passo.get("local","")) in fechados: passo.local="rua"

static func expandir_lotes(jogo: Node) -> void:
	var planta: PlantaPlex=jogo.planta
	var mudou:=false
	for id in ["floricultura","posto"]:
		if not planta.terrenos_adquiridos.get(id,false): continue
		var limite:=lote(id)
		for objeto in planta.objetos.values():
			if limite.has_point(objeto.celula) and (objeto.get("cidade",false) or objeto.get("cidade_fixo",false)): planta.remover(objeto.id);mudou=true
		for y in range(limite.position.y,limite.end.y):
			for x in range(limite.position.x,limite.end.x):
				var c:=Vector2i(x,y)
				if str(planta.pisos.get(c,""))=="antigo_piso_velho" and not planta.bairro_bloqueios.has(c): continue
				planta.bairro_bloqueios.erase(c);planta.pisos[c]="antigo_piso_velho";planta.rotacoes_pisos[c]=0;mudou=true
	if not mudou: return
	planta.reindexar();planta.alterada.emit();planta.notificar_piso()
	jogo.bairro.assinatura="";jogo.bairro.terreno.assinatura="";jogo.bairro.terreno.atualizar()
	jogo.chao.queue_redraw();jogo.limites_terreno.assinatura=-1;jogo.limites_terreno.atualizar()

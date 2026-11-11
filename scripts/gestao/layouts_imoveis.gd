class_name LayoutsImoveisPlex
extends RefCounted

static func carregar(id: String) -> Dictionary:
	if not CompraTerrenosPlex.LOTES.has(id): return {}
	var caminho:="res://dados/imoveis/"+id+".json"
	if not FileAccess.file_exists(caminho): return {}
	var valor: Variant=JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if not valor is Dictionary: return {}
	var dados: Dictionary=valor
	if dados.get("formato","")!="pizzaplex_terreno_layout" or dados.get("terreno","")!=id: return {}
	if Vector2i(int(dados.get("grade",{}).get("largura",0)),int(dados.get("grade",{}).get("profundidade",0)))!=CompraTerrenosPlex.lote(id).size: return {}
	if dados.get("pisos",[]).size()!=CompraTerrenosPlex.lote(id).size.x*CompraTerrenosPlex.lote(id).size.y or dados.get("objetos",[]).is_empty(): return {}
	var locais: Dictionary={}
	var ids: Dictionary={}
	var limite:=Rect2i(Vector2i.ZERO,CompraTerrenosPlex.lote(id).size)
	for registro in dados.pisos+dados.objetos:
		if not registro.get("celula") is Array or registro.celula.size()!=2: return {}
		if not limite.has_point(Vector2i(int(registro.celula[0]),int(registro.celula[1]))): return {}
		if not CatalogoPlex.objetos.has(str(registro.get("tipo",""))): return {}
	for piso in dados.pisos:
		var c:=Vector2i(int(piso.celula[0]),int(piso.celula[1]))
		if locais.has(c): return {}
		locais[c]=true
	for registro in dados.objetos:
		var chave:=str(registro.get("id",""))
		if chave.is_empty() or ids.has(chave): return {}
		ids[chave]=true
	return dados

static func aplicar(planta: PlantaPlex, id: String, dados: Dictionary={}) -> bool:
	if dados.is_empty(): dados=carregar(id)
	if dados.is_empty(): return false
	var lote:=CompraTerrenosPlex.lote(id)
	var bloqueado:=planta.is_blocking_signals()
	planta.set_block_signals(true)
	var ids: Dictionary={}
	for piso in dados.pisos:
		var c:=lote.position+Vector2i(int(piso.celula[0]),int(piso.celula[1]))
		planta.bairro_bloqueios.erase(c)
		planta.pisos[c]=str(piso.tipo)
		planta.rotacoes_pisos[c]=posmod(int(piso.get("r",0)),4)
		planta.uso_pisos.erase(c)
	for registro in dados.objetos:
		var tipo:=str(registro.tipo)
		var c:=lote.position+Vector2i(int(registro.celula[0]),int(registro.celula[1]))
		var numero:=planta.inserir(tipo,c,posmod(int(registro.rotacao),4),{})
		var item: Dictionary=planta.objetos[numero]
		item.layout_imovel=id
		item.layout_objeto=str(registro.id)
		item.estado_visual=str(registro.get("estado",MobiliaPlex.estado(item)))
		if item.tipo==tipo: item.estado=item.estado_visual
		item.elevacao_layout=float(registro.get("elevacao",0.0))
		if CatalogoPlex.objetos[tipo].get("entulho",false) or tipo.begins_with("antigo_barricada") or tipo.begins_with("antigo_fragmento"): item.solto=true
		if item.tipo in CatalogoPlex.PORTAS and (c.x in [lote.position.x,lote.end.x-1] or c.y in [lote.position.y,lote.end.y-1]): item.entrada_clientes=true
		ids[str(registro.id)]=numero
	planta.reindexar()
	for registro in dados.objetos:
		var apoio:=str(registro.get("apoio",""))
		if not ids.has(apoio): continue
		var numero:=int(ids[str(registro.id)])
		var pai:=int(ids[apoio])
		var slot:=ApoiosPlex.livre(planta,pai,str(planta.objetos[numero].tipo))
		if slot>=0: ApoiosPlex.fixar(planta,numero,pai,slot)
	for area in dados.get("salas",[]):
		var c:=lote.position+Vector2i(int(area.celula[0]),int(area.celula[1]))
		if lote.has_point(c): planta.funcoes_salas[c]=str(area.tipo)
	planta.set_block_signals(bloqueado)
	if not bloqueado:
		planta.alterada.emit()
		planta.notificar_piso()
	return true

static func modelo_antigo(planta: PlantaPlex, id: String) -> bool:
	var lote:=CompraTerrenosPlex.lote(id)
	var esperados: Dictionary={}
	for y in range(10):
		for x in range(10):
			var c:=lote.position+Vector2i(x,y)
			if planta.pisos.get(c,"")!="antigo_piso_velho" or int(planta.rotacoes_pisos.get(c,0))!=0 or planta.funcoes_salas.has(c): return false
			if x not in [0,9] and y not in [0,9]: continue
			var porta: bool=y==9 and x==4
			var tipo:="antigo_porta_antiga_1" if porta else "antigo_parede_quebrada_modulo"
			var rotacao:=1 if x==0 else 3 if x==9 else 2 if y==9 else 0
			esperados[str([tipo,c,rotacao])]=true
	for detalhe in [["antigo_fragmento_parede_medio",2,3],["antigo_fragmento_piso_pequeno",6,5],["antigo_fragmento_parede_pequeno",3,7],["oficina_papeis_folhas",4,3],["oficina_papeis_folhas",6,7],["oficina_papeis_blueprints",7,2]]:
		esperados[str([str(detalhe[0]),lote.position+Vector2i(detalhe[1],detalhe[2]),0])]=true
	for item in planta.objetos.values():
		if not lote.has_point(item.celula): continue
		if item.has("layout_imovel") or item.has("valor_pago") or int(item.get("carregada_por",0))>0 or int(item.get("sobre",-1))>=0: return false
		var tipo:=MobiliaPlex.visual(item)
		var chave:=str([tipo,item.celula,int(item.rotacao)])
		if not esperados.has(chave): return false
		if tipo=="antigo_parede_quebrada_modulo" and MobiliaPlex.estado(item)!="rachada": return false
		esperados.erase(chave)
	return esperados.is_empty()

static func atualizar_antigos(planta: PlantaPlex) -> void:
	for id in CompraTerrenosPlex.LOTES:
		if not planta.terrenos_adquiridos.get(id,false) or not modelo_antigo(planta,id): continue
		var dados:=carregar(id)
		if dados.is_empty(): continue
		var lote:=CompraTerrenosPlex.lote(id)
		var bloqueado:=planta.is_blocking_signals()
		planta.set_block_signals(true)
		for item in planta.objetos.values():
			if lote.has_point(item.celula): planta.remover(item.id)
		aplicar(planta,id,dados)
		planta.set_block_signals(bloqueado)
		if not bloqueado:
			planta.alterada.emit()
			planta.notificar_piso()

static func corrigir_farmacia(planta:PlantaPlex) -> void:
	if not planta.terrenos_adquiridos.get("farmacia",false):return
	var originais:Array=planta.objetos.values().filter(func(o):return o.get("layout_imovel","")=="farmacia")
	if originais.is_empty() or originais.any(func(o):return o.get("correcao_farmacia_v65",false)):return
	var lote:=CompraTerrenosPlex.lote("farmacia")
	for registro in carregar("farmacia").get("objetos",[]):
		if not str(registro.id).begins_with("v65_"):continue
		var c:=lote.position+Vector2i(registro.celula[0],registro.celula[1])
		if not planta.em(c).is_empty():continue
		var numero:=planta.inserir(str(registro.tipo),c,int(registro.rotacao),{})
		planta.objetos[numero].layout_imovel="farmacia";planta.objetos[numero].layout_objeto=str(registro.id)
		planta.objetos[numero].estado_visual=str(registro.estado)
	for item in originais:item.correcao_farmacia_v65=true

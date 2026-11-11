class_name LayoutRestaurantePlex
extends RefCounted

static func aplicar(planta: PlantaPlex, lote: Rect2i) -> bool:
	var caminho:="res://dados/restaurante_inicial.json"
	if not FileAccess.file_exists(caminho): return false
	var dados: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if dados.get("formato","")!="pizzaplex_restaurante_layout": return false
	var tamanho:=Vector2i(int(dados.grade.largura),int(dados.grade.profundidade))
	if tamanho!=lote.size: return false
	var ids: Dictionary={}
	for y in range(lote.position.y,lote.end.y):
		for x in range(lote.position.x,lote.end.x): planta.pisos[Vector2i(x,y)]="antigo_piso_velho"
	for piso in dados.get("pisos",[]):
		var c:=lote.position+Vector2i(int(piso.celula[0]),int(piso.celula[1]))
		if not lote.has_point(c) or not CatalogoPlex.objetos.has(str(piso.tipo)): continue
		planta.pisos[c]=str(piso.tipo)
	for registro in dados.get("objetos",[]):
		var tipo:=str(registro.tipo)
		var c:=lote.position+Vector2i(int(registro.celula[0]),int(registro.celula[1]))
		if not CatalogoPlex.objetos.has(tipo) or not lote.has_point(c): continue
		var id:=planta.inserir(tipo,c,posmod(int(registro.rotacao),4),{})
		var item: Dictionary=planta.objetos[id]
		item.layout_objeto=str(registro.id)
		item.rotacao=posmod(int(registro.rotacao),4)
		item.estado_visual=str(registro.get("estado",MobiliaPlex.estado(item)))
		if item.tipo==tipo: item.estado=item.estado_visual
		item.elevacao_layout=float(registro.get("elevacao",0.0))
		if CatalogoPlex.objetos[tipo].get("entulho",false) and not SubstituicaoParedesPlex.estrutural(item): item.solto=true
		if tipo.begins_with("cenario_trilha") or tipo.begins_with("cenario_poca") or tipo.begins_with("antigo_fragmento"): item.solto=true
		if item.tipo in CatalogoPlex.PORTAS and (c.x in [lote.position.x,lote.end.x-1] or c.y in [lote.position.y,lote.end.y-1]): item.entrada_clientes=true
		if tipo.begins_with("cenario_gerador"): item.combustivel=100.0;item.carga=100.0;item.ligado=true
		ids[str(registro.id)]=id
	planta.reindexar()
	for registro in dados.get("objetos",[]):
		if not ids.has(str(registro.id)) or not ids.has(str(registro.get("apoio",""))): continue
		var id:=int(ids[str(registro.id)])
		var pai:=int(ids[str(registro.apoio)])
		var slot:=ApoiosPlex.livre(planta,pai,str(planta.objetos[id].tipo))
		if slot>=0: ApoiosPlex.fixar(planta,id,pai,slot)
	for area in dados.get("salas",[]):
		var c:=lote.position+Vector2i(int(area.celula[0]),int(area.celula[1]))
		if lote.has_point(c): planta.funcoes_salas[c]=str(area.tipo)
	return not ids.is_empty()

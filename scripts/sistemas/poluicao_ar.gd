class_name PoluicaoArPlex
extends RefCounted

static func potencial(tipo:String) -> Dictionary:
	if CatalogoPlex.objetos.get(tipo,{}).get("gerador",false):return {"raio":7,"motivo":"Gases do gerador","condicao":"ao funcionar; maior se velho"}
	if FornoPlex.eh({"tipo":tipo}):return {"raio":4,"motivo":"Frituras / preparo","condicao":"ao funcionar"}
	if tipo=="geladeira" or tipo.contains("geladeira"):return {"raio":2,"motivo":"Calor / odor da geladeira","condicao":"conforme o estado"}
	if tipo.contains("lixeira") or tipo.contains("lixo"):return {"raio":3,"motivo":"Odor de lixo","condicao":"quando houver resíduos"}
	if tipo.contains("poca") or tipo.contains("restos") or tipo.contains("derramada"):return {"raio":2,"motivo":"Sujeira / restos","condicao":"enquanto sujo"}
	return {}
static func area(planta:PlantaPlex,origens:Array,raio:int) -> Dictionary:
	var fila:Array=[];var distancia:Dictionary={};var forca:Dictionary={}
	for c in origens:
		if not GradePlex.dentro(c) or distancia.has(c):continue
		distancia[c]=0;forca[c]=1.0;fila.append(c)
	var i:=0
	while i<fila.size():
		var c:Vector2i=fila[i];i+=1
		if int(distancia[c])>=raio:continue
		for d in GradePlex.VIZINHOS:
			var n:Vector2i=c+d
			if not GradePlex.dentro(n) or distancia.has(n):continue
			var o:Dictionary=planta.em(n)
			if CatalogoPlex.base(str(o.get("tipo","")))=="parede":continue
			distancia[n]=int(distancia[c])+1;forca[n]=float(forca[c])*(.35 if o.get("tipo","") in CatalogoPlex.PORTAS and not o.get("aberta",false) else 1.0);fila.append(n)
	var resultado:Dictionary={}
	for c in distancia:resultado[c]=float(forca[c])*(1.0-float(distancia[c])/float(raio+1))
	return resultado
static func previa(planta:PlantaPlex,tipo:String,c:Vector2i,r:int) -> Dictionary:
	var p:=potencial(tipo)
	if p.is_empty():return {}
	var tiles:=area(planta,planta.celulas(tipo,c,r),int(p.raio))
	return {"raio":p.raio,"tiles":tiles,"motivo":p.motivo,"condicao":p.condicao}
static func resumo(planta:PlantaPlex,tipo:String,c:Vector2i,r:int) -> String:
	var p:=previa(planta,tipo,c,r)
	return "Ar: até %d tiles de distância · %d tiles alcançados %s"%[p.raio,p.tiles.size(),p.condicao] if not p.is_empty() else "Ventilação: conecte tubulação e grade ao exterior." if tipo.begins_with("oficina_duto_") else ""
static func desenhar_alcance(cursor:CursorPlex,tipo:String,c:Vector2i,r:int) -> void:
	var p:=previa(cursor.editor.planta,tipo,c,r)
	if p.is_empty():return
	for tile in p.tiles:
		var forma:=GradePlex.poligono(GradePlex.projetar(Vector2(tile),.8))
		cursor.draw_colored_polygon(forma,Color(.83,.56,.25,float(p.tiles[tile])*.13));cursor.draw_polyline(forma+PackedVector2Array([forma[0]]),Color(.91,.64,.33,.35),1)

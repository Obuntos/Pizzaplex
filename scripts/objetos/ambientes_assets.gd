class_name AmbientesAssetsPlex
extends RefCounted

static var volumes:Dictionary={}
static var cache:Dictionary={}
static func catalogar(objetos:Dictionary) -> void:
	var novos:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://dados/assets_ambientes.json"))
	novos.merge(JSON.parse_string(FileAccess.get_file_as_string("res://dados/assets_decoracao.json")),true)
	for tipo in novos:
		var dados:Dictionary=objetos.get(tipo,{}).duplicate(true);dados.merge(novos[tipo],true);objetos[tipo]=dados
	for tipo in ["antigo_armario_duplo","mesa","mesa_longa_arredondada","maquina_fliperama","antigo_arcade_quebrado","sistema_mesa_redonda_forro","sistema_mesa_banquete_forro","sistema_palco_picadeiro"]:
		if objetos.has(tipo):objetos[tipo].oculto=true
	for tipo in objetos:
		if str(tipo).begins_with("pecas_") or str(tipo).begins_with("caixa_pecas_") or tipo in ["pecas_manutencao","caixa_ferramentas"]:objetos[tipo].oculto=true
		if str(tipo).contains("fliperama") and not str(tipo).begins_with("amb_"):objetos[tipo].oculto=true
	for tipo in objetos:
		if str(tipo).begins_with("cortina_central_"):
			objetos[tipo].nome="Cortina · "+str(objetos[tipo].largura)+(" tile" if int(objetos[tipo].largura)==1 else " tiles")
	for tipo in ["olhos","plastico","fantasia"]:
		objetos["ajuste_cabeca_"+tipo]={"nome":"Cabeça em ajuste" if tipo=="olhos" else "Plástico da cabeça" if tipo=="plastico" else "Fantasia da cabeça","largura":1,"profundidade":1,"altura":25,"oculto":true,"apoio":true,"sobreposto":true,"categoria_apoio":"modulo-coelho","preco":0,"conforto":0}
	for tipo in ["plastico","fantasia"]:
		objetos["ajuste_estrutura_"+tipo]={"nome":"Plásticos em ajuste" if tipo=="plastico" else "Fantasia retirada","largura":1,"profundidade":1,"altura":45,"oculto":true,"apoio":true,"sobreposto":true,"categoria_apoio":"modulo-coelho","preco":0,"conforto":0}
static func eh(tipo:String) -> bool:return CatalogoPlex.objetos.get(tipo,{}).get("ambiente_novo",false)
static func obter(tipo:String,rotacao:int,estado:String="") -> Dictionary:
	if volumes.is_empty():
		volumes=JSON.parse_string(FileAccess.get_file_as_string("res://dados/volumes_ambientes.json"))
		volumes.merge(JSON.parse_string(FileAccess.get_file_as_string("res://dados/volumes_decoracao.json")),true)
	var padrao:=str(CatalogoPlex.objetos[tipo].estado_padrao)
	var chave:=tipo+":"+str(posmod(rotacao,4))+":"+(estado if volumes.has(tipo+":"+str(posmod(rotacao,4))+":"+estado) else padrao)
	if cache.has(chave):return cache[chave]
	var d:Dictionary=volumes[chave].duplicate(true)
	var im:=CatalogoPlex.imagem(d.image);var n:=CatalogoPlex.imagem(d.normal);var mapa:=FileAccess.get_file_as_bytes(d.depth).to_float32_array()
	var pontos:=PackedVector3Array();var cores:=PackedColorArray();var normais:=PackedColorArray()
	for y in im.get_height():
		for x in im.get_width():
			var cor:=im.get_pixel(x,y)
			if cor.a<=0:continue
			pontos.append(Vector3(x+float(d.origin[0]),y+float(d.origin[1]),mapa[y*im.get_width()+x]));cores.append(cor);normais.append(n.get_pixel(x,y))
	d.textura=CatalogoPlex.textura(d.image);d.pontos=pontos;d.cores=cores;d.superficies=normais;d=EncaixesMobiliaPlex.volume(d,tipo,rotacao);cache[chave]=d;return d

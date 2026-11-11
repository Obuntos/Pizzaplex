class_name AssetsSistemasPlex
extends RefCounted

static var volumes:Dictionary={}
static var cache:Dictionary={}
static func eh(tipo:String) -> bool:return tipo.begins_with("sistema_") or tipo.begins_with("pecas_") or tipo in ["bancada_montagem_coelho","oficina_bancada_trabalho","oficina_duto_grade"]
static func catalogar(objetos:Dictionary) -> void:
	var dados:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://dados/sistemas_objetos.json"))
	for tipo in dados:
		if str(tipo).begins_with("sistema_palco_"):dados[tipo].novo_palco=true;dados[tipo].familia="palco";dados[tipo].categoria="Palcos"
	objetos.merge(dados,true)
	for tipo in objetos:
		if str(tipo).begins_with("oficina_cadeira_escritorio_"):objetos[tipo].familia="cadeira";objetos[tipo].logico="cadeira";objetos[tipo].categoria="Escritório"
		if objetos[tipo].get("familia","")=="parede":objetos[tipo].logico="parede";objetos[tipo].estrutura=true;objetos[tipo].mobilia=true
	objetos.sistema_mesa_redonda_forro.oculto=true
	objetos.area_montagem_atracao.merge({"oculto":false,"nome":"Base cinza de montagem","categoria":"Escritório","temporario":false,"preco":35,"altura":.12},true)
	for tipo in ["pecas_bancada_endo","pecas_bancada_plastico","pecas_bancada_carcaca","oficina_bancada_trabalho"]:objetos[tipo].oculto=true
	objetos.bancada_montagem_coelho.nome="Bancada de montagem e trabalho"
	objetos.sistema_modulo_coelho_3.nome="Roupa do animatrônico"
	for removido in ["cortina_quina_interna","cortina_quina_externa","cortina_lateral_fixa","cortina_lateral_esquerda","cortina_lateral_direita"]:
		if objetos.has(removido):objetos[removido].oculto=true
	for tipo in objetos:
		if not str(tipo).begins_with("oficina_duto_"):continue
		objetos[tipo].oculto=tipo!="oficina_duto_grade";objetos[tipo].categoria="Escritório";objetos[tipo].parede_requerida=tipo=="oficina_duto_grade";objetos[tipo].tubulacao=true
		if tipo=="oficina_duto_grade":objetos[tipo].nome="Tubulação";objetos[tipo].duas_faces=true
static func obter(tipo:String,rotacao:int,estado:String="",ligacoes:int=0) -> Dictionary:
	if volumes.is_empty():volumes=JSON.parse_string(FileAccess.get_file_as_string("res://dados/sistemas_volumes.json"))
	if estado.is_empty():estado=str(CatalogoPlex.objetos[tipo].get("estado_padrao","padrao"))
	var chave:=tipo+":"+str(posmod(rotacao,4))+":"+estado
	if not volumes.has(chave):chave=tipo+":"+str(posmod(rotacao,4))+":"+str(CatalogoPlex.objetos[tipo].estado_padrao)
	if ligacoes>0 and volumes.has(chave+":m"+str(ligacoes)):chave+=":m"+str(ligacoes)
	if cache.has(chave):return cache[chave]
	var fonte:Dictionary=volumes[chave]
	var pontos:=PackedVector3Array();var cores:=PackedColorArray();var normais:=PackedColorArray()
	var dados:=FileAccess.get_file_as_bytes(str(fonte.arquivo));var quantidade:=int(fonte.quantidade)
	var coordenadas:=dados.slice(0,quantidade*12).to_float32_array()
	for i in quantidade:
		pontos.append(Vector3(coordenadas[i*3],coordenadas[i*3+1],coordenadas[i*3+2]))
		var c:=quantidade*12+i*4;var n:=quantidade*16+i*4
		cores.append(Color(dados[c]/255.0,dados[c+1]/255.0,dados[c+2]/255.0,dados[c+3]/255.0));normais.append(Color(dados[n]/255.0,dados[n+1]/255.0,dados[n+2]/255.0,.2))

	var origem:Array=fonte.origin.duplicate()
	if tipo=="oficina_duto_grade":
		origem[1]=int(origem[1])+24
		for i in pontos.size():pontos[i]+=Vector3(0,24,-24)
	var resultado:Dictionary={"image":fonte.image,"origin":origem,"textura":CatalogoPlex.textura(fonte.image),"pontos":pontos,"cores":cores,"superficies":normais}
	resultado=EncaixesMobiliaPlex.volume(resultado,tipo,rotacao)
	cache[chave]=resultado
	return resultado

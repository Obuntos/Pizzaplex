class_name PelePlex
extends RefCounted

const PADRAO:="bege"
static var dados:Dictionary={}
static var cache:Dictionary={}

static func carregar() -> void:
	if dados.is_empty():dados=JSON.parse_string(FileAccess.get_file_as_string("res://dados/peles.json"))

static func opcoes() -> Array:
	carregar()
	return dados.opcoes

static func validar(id:String) -> String:
	carregar()
	return id if dados.mapas.has(id) else PADRAO

static func de(ator:PersonagemPlex) -> String:
	return validar(str(ator.visita.get("pele",PADRAO)))

static func paleta(id:String) -> Array:
	carregar()
	if cache.has(id):return cache[id]
	var origem:=PackedVector3Array();var destino:=PackedVector3Array()
	var mapa:Dictionary=dados.mapas.get(id,{})
	for chave in mapa:
		var a:=Color("#"+str(chave));var b:=Color("#"+str(mapa[chave]))
		origem.append(Vector3(a.r,a.g,a.b));destino.append(Vector3(b.r,b.g,b.b))
	while origem.size()<64:origem.append(Vector3(-1,-1,-1));destino.append(Vector3.ZERO)
	cache[id]=[origem,destino,mapa.size()]
	return cache[id]

static func aplicar(material:ShaderMaterial,id:String) -> void:
	var p:=paleta(validar(id))
	material.set_shader_parameter("pele_origem",p[0])
	material.set_shader_parameter("pele_destino",p[1])
	material.set_shader_parameter("pele_total",int(p[2]))

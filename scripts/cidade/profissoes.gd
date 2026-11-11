class_name ProfissoesBairroPlex
extends RefCounted

static func registrar(catalogo:Dictionary) -> void:
	for oficio in ["policial","investigador","jornalista"]:
		var modelo:Dictionary=catalogo.humano.duplicate(true)
		modelo.layered=false;modelo.oculto=true
		catalogo["profissao_"+oficio]=modelo

static func preparar(perfis:Dictionary) -> void:
	for id in ["M021","M040"]:
		if not perfis.has(id):continue
		perfis[id].modelo="profissao_investigador" if id=="M021" else "profissao_policial"

static func eh(modelo:String) -> bool:return modelo.begins_with("profissao_")

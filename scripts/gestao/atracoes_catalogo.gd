class_name AtracoesCatalogoPlex
extends RefCounted

const DISPONIVEIS=["novo_coelho_detalhes","vi_patitas","vi_toy_orelhitas","vi_orelhitas_quebrado","vi_toy_orelhitas_quebrado","vi_toy_patitas","vi_patitas_quebrado","vi_toy_patitas_quebrado","vi_coruja","vi_arlequim"]
static var dados: Array=[]

static func permitido(id: String) -> bool: return id in DISPONIVEIS

static func carregar() -> void:
	if dados.is_empty(): dados=JSON.parse_string(FileAccess.get_file_as_string("res://dados/coelho_detalhes.json"))

static func registrar(personagens: Dictionary) -> void:
	carregar()
	for r in dados:
		if int(r.categoria)<0 or r.get("interno",false): continue
		personagens[r.id]={"width":r.width,"height":r.height,"pivot":r.pivo,"scale":[float(r.escala[0]),float(r.escala[1])],"frames":12,"directions":8,"layered":false}

static func registrar_clipes(modelos: Dictionary) -> void:
	carregar()
	modelos.erase("fantasia_coelho")
	for r in dados:
		if int(r.categoria)<0 or r.get("interno",false): continue
		if modelos.has(r.id) and str(r.id).begins_with("novo_"): continue
		modelos[r.id]={"width":r.width,"height":r.height,"clipes":r.clipes,"cabeca_y":float(r.get("cabeca_y",49.0))}

static func registro(id: String) -> Dictionary:
	carregar()
	for r in dados:
		if r.id==id: return r
	return {}

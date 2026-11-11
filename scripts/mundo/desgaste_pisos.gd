class_name DesgastePisosPlex
extends RefCounted

const PASSAGENS=400

static func gasto(tipo: String) -> bool:
	return tipo=="antigo_piso_velho" or (CatalogoPlex.objetos.get(tipo,{}).get("piso",false) and tipo.ends_with("_gasto"))

static func variante(tipo: String) -> String:
	if tipo=="antigo_piso_novo": return "antigo_piso_velho"
	var destino:=tipo.trim_suffix("_novo")+"_gasto"
	return destino if tipo.ends_with("_novo") and CatalogoPlex.objetos.has(destino) else ""

static func registrar(planta: PlantaPlex, celula: Vector2i) -> void:
	if not TerrenoPlex.contem(planta,celula) or not is_zero_approx(planta.altura(celula)): return
	var tipo: String=planta.pisos.get(celula,"")
	var destino:=variante(tipo)
	if destino.is_empty(): return
	var registro: Dictionary=planta.uso_pisos.get(celula,{})
	if registro.get("tipo","")!=tipo: registro={"tipo":tipo,"passos":0}
	registro.passos=int(registro.passos)+1
	planta.uso_pisos[celula]=registro
	if registro.passos<PASSAGENS: return
	planta.pisos[celula]=destino
	planta.uso_pisos.erase(celula)
	planta.notificar_piso()

static func gravar(planta: PlantaPlex) -> Array:
	var resultado: Array=[]
	for celula in planta.uso_pisos:
		var registro: Dictionary=planta.uso_pisos[celula]
		resultado.append([celula.x,celula.y,registro.tipo,registro.passos])
	return resultado

static func restaurar(planta: PlantaPlex, registros: Array) -> void:
	planta.uso_pisos.clear()
	for r in registros:
		if not r is Array or r.size()!=4: continue
		var celula:=Vector2i(int(r[0]),int(r[1]))
		if planta.pisos.get(celula,"")!=str(r[2]) or variante(str(r[2])).is_empty(): continue
		planta.uso_pisos[celula]={"tipo":str(r[2]),"passos":clampi(int(r[3]),0,PASSAGENS-1)}


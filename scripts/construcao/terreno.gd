class_name TerrenoPlex
extends RefCounted

const DEMONSTRACAO := Rect2i(10,8,40,28)

static func base(planta: PlantaPlex) -> Rect2i:
	if planta.area_construcao.has_area(): return planta.area_construcao
	return planta.lote_restaurante if planta.bairro_ativo else CidadeInicialPlex.RESTAURANTE

static func contem(planta: PlantaPlex, celula: Vector2i) -> bool:
	if not GradePlex.dentro(celula): return false
	if base(planta).has_point(celula): return true
	for id in planta.terrenos_adquiridos:
		if planta.terrenos_adquiridos[id] and CompraTerrenosPlex.lote(str(id)).has_point(celula): return true
	return false

static func cabe(planta: PlantaPlex, tipo: String, celula: Vector2i, rotacao: int) -> bool:
	for local in planta.celulas(tipo,celula,rotacao):
		if not contem(planta,local): return false
	return true

static func permite(planta: PlantaPlex, tipo: String, celula: Vector2i, rotacao: int) -> bool:
	for origem in MobiliaPlex.modulos(tipo,celula,rotacao):
		var direcao := PortasPlex.rotacao_para(planta,tipo,origem,rotacao) if PortasPlex.ajusta(str(tipo)) else rotacao
		if not cabe(planta,tipo,origem,direcao): return false
	return true

static func borda(planta: PlantaPlex, celula: Vector2i) -> bool:
	if not contem(planta,celula): return false
	for d in GradePlex.VIZINHOS:
		if not contem(planta,celula+d): return true
	return false

static func protegido(planta: PlantaPlex, item: Dictionary) -> bool:
	if item.get("tipo","") not in SalasPlex.ESTRUTURA: return false
	return planta.celulas(item.tipo,item.celula,item.rotacao).any(func(c): return borda(planta,c))

static func gravar(planta: PlantaPlex) -> Array[int]:
	var limite := base(planta)
	return [limite.position.x,limite.position.y,limite.size.x,limite.size.y]

static func restaurar(planta: PlantaPlex, registro: Array) -> void:
	planta.area_construcao = planta.lote_restaurante if planta.bairro_ativo else (CidadeInicialPlex.RESTAURANTE if CidadeInicialPlex.presente(planta) else DEMONSTRACAO)
	if registro.size()!=4: return
	var limite := Rect2i(int(registro[0]),int(registro[1]),int(registro[2]),int(registro[3]))
	if limite.has_area() and Rect2i(Vector2i.ZERO,GradePlex.TAMANHO).encloses(limite): planta.area_construcao=limite


static func lotes(planta: PlantaPlex) -> Array[Rect2i]:
	var resultado: Array[Rect2i]=[base(planta)]
	for id in planta.terrenos_adquiridos:
		if planta.terrenos_adquiridos[id] and CompraTerrenosPlex.LOTES.has(id): resultado.append(CompraTerrenosPlex.lote(str(id)))
	return resultado

static func area(planta: PlantaPlex) -> Rect2i:
	var resultado:=base(planta)
	for r in lotes(planta): resultado=resultado.merge(r)
	return resultado

static func restaurar_lotes(planta: PlantaPlex, dados: Dictionary) -> void:
	planta.terrenos_adquiridos.clear()
	for id in CompraTerrenosPlex.LOTES:
		if dados.get(id,false): planta.terrenos_adquiridos[id]=true

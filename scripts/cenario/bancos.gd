class_name BancosCidadePlex
extends RefCounted

static func acessos(planta: PlantaPlex, banco: Dictionary) -> Array[Vector2i]:
	var resultado: Array[Vector2i]=[]
	var frente:=GradePlex.frente(banco.rotacao)
	for c in planta.celulas(banco.tipo,banco.celula,banco.rotacao):
		if planta.transitavel(c+frente): resultado.append(c+frente)
	if resultado.is_empty():
		var lateral := Vector2i(frente.y,-frente.x)
		for c in planta.celulas(banco.tipo,banco.celula,banco.rotacao):
			for d in [lateral,-lateral]:
				if planta.transitavel(c+d) and not resultado.has(c+d): resultado.append(c+d)
	return resultado

static func sentar(a: PersonagemPlex, planta: PlantaPlex, id: int, pessoas: Array) -> bool:
	var banco: Dictionary=planta.objetos.get(id,{})
	if banco.get("tipo","")!="banco_espera" or a.robo or a.ocupado(): return false
	var usados: Dictionary={}
	for pessoa in pessoas:
		if pessoa!=a and pessoa.assento==id: usados[int(pessoa.visita.get("banco_slot",0))]=true
	for slot in 3:
		if usados.has(slot): continue
		a.visita.banco_slot=slot
		a.assento=id
		a.trabalho="sentar_banco"
		a.direcao=GradePlex.direcao_suporte(banco.rotacao)
		a.atualizar_visual(false)
		return true
	return false

static func ponto(a: PersonagemPlex, banco: Dictionary) -> Vector3:
	var dimensao:=CatalogoPlex.dimensoes(banco.tipo,banco.rotacao)
	var centro:=Vector2(banco.celula)+Vector2(dimensao-Vector2i.ONE)*.5
	var apoios:=ApoiosPlex.pontos(banco)
	var slot:=clampi(int(a.visita.get("banco_slot",0)),0,apoios.size()-1)
	var apoio: Dictionary=apoios[slot]
	centro+=Vector2(float(apoio.u),float(apoio.v))
	var quadril:=11.0 if a.modelo=="crianca" else 12.9 if a.modelo.begins_with("adolescente") else 15.0
	return Vector3(centro.x,centro.y,float(apoio.z)-quadril*a.animacao.scale.y)

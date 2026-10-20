class_name MovimentoPlex
extends RefCounted

var rota: Array[Vector2i] = []
var destino := Vector2i.ZERO
var inicio := Vector2i.ZERO
var progresso: float = 0.0
var atravessando: bool = false
var ponto_inicio := Vector2.ZERO
var ponto_destino := Vector2.ZERO
var escala := EscalaPlex.new()
var cedendo := false
var retomar := Vector2i(-1,-1)
var passante := -1
var bloqueado := 0.0

func iniciar(personagem: Node2D, caminho: Array[Vector2i]) -> void:
	cedendo = false
	bloqueado = 0.0
	var proximos: Array[Vector2i] = caminho.duplicate()
	if escala.ativo:
		if not proximos.is_empty() and proximos[0] == destino:
			proximos.pop_front()
		rota.assign([destino])
		rota.append_array(proximos)
		return
	if atravessando:
		if not proximos.is_empty() and proximos[0] == destino:
			proximos.pop_front()
		if not proximos.is_empty() and proximos[0] == inicio:
			var antigo_inicio := inicio
			var antigo_ponto := ponto_inicio
			inicio = destino
			destino = antigo_inicio
			ponto_inicio = ponto_destino
			ponto_destino = antigo_ponto
			personagem.celula = inicio
			progresso = 1.0 - progresso
			proximos.pop_front()
		rota.assign([destino])
		rota.append_array(proximos)
		return
	rota = proximos
	if not rota.is_empty() and rota[0] == personagem.celula:
		rota.pop_front()
	progresso = 0.0

func aproximar(personagem: Node2D, ponto: Vector2) -> void:
	inicio = personagem.celula
	destino = personagem.celula
	ponto_inicio = personagem.local
	ponto_destino = ponto
	progresso = 0.0
	atravessando = true
	rota.assign([destino])

func origem_planejamento(personagem: Node2D) -> Vector2i:
	return destino if atravessando else personagem.celula

func cancelar() -> void:
	cedendo = false
	if atravessando:
		rota.assign([destino])
		return
	rota.clear()
	progresso = 0.0

func travessia(personagem: Node2D, planta: PlantaPlex) -> Dictionary:
	var proxima := planta.em(rota[0])
	var atual := planta.em(personagem.celula)
	if EscadasPlex.eh(proxima):
		var frente := GradePlex.frente(proxima.rotacao)
		if personagem.celula == proxima.celula + frente:
			var completa: bool = rota.size() > 1 and rota[1] == proxima.celula - frente
			return {"escada": proxima.celula, "modo": "subir" if completa else "subir_alto", "fim": rota[1] if completa else rota[0], "consumir": 1 if completa else 0}
		if personagem.celula == proxima.celula - frente and rota.size() > 1 and rota[1] == proxima.celula + frente:
			return {"escada": proxima.celula, "modo": "descer", "fim": rota[1], "consumir": 1}
	if EscadasPlex.eh(atual) and rota[0] == personagem.celula + GradePlex.frente(atual.rotacao):
		return {"escada": personagem.celula, "modo": "descer_alto", "fim": rota[0], "consumir": 0}
	return {}

func atualizar(personagem: Node2D, delta: float, planta: PlantaPlex, rotas: RotasPlex, personagens: Array) -> float:
	if cedendo and rota.is_empty():
		if not CirculacaoPlex.liberou(personagem, personagens): return 0.0
		cedendo = false
		passante = -1
	if rota.is_empty():
		return 0.0
	if escala.ativo:
		var anterior_local := personagem.local as Vector2
		var terminou := escala.atualizar(personagem, delta)
		progresso = escala.relogio / float(escala.percurso.duration)
		if terminou:
			personagem.celula = destino
			rota.pop_front()
			atravessando = false
			escala.ativo = false
			if not rota.is_empty():
				personagem.fase += 0.25
		return anterior_local.distance_to(personagem.local)
	if not atravessando:
		inicio = personagem.celula
		var primeiro: Vector2i = rota[0]
		var plano := travessia(personagem, planta)
		destino = plano.get("fim", primeiro)
		if not planta.transitavel(destino):
			cancelar()
			return 0.0
		var origem_suporte: bool = planta.em(inicio).get("tipo", "") == "suporte"
		if not origem_suporte and not rotas.conectavel(inicio, primeiro):
			cancelar()
			return 0.0
		if not CirculacaoPlex.permitir(personagem, primeiro, destino, planta, rotas, personagens, delta):
			return 0.0
		bloqueado = 0.0
		atravessando = true
		progresso = 0.0
		ponto_inicio = personagem.local
		ponto_destino = Vector2(destino)
		if not plano.is_empty() and escala.iniciar(personagem, planta, plano.escada, plano.modo):
			for i in plano.consumir:
				rota.pop_front()
			return 0.0
		var objeto := planta.em(destino)
		if EscadasPlex.eh(objeto):
			ponto_destino -= Vector2(GradePlex.frente(objeto.rotacao)) / 3.0
	var caixa: bool = personagem.carregando or planta.objetos.get(personagem.carga_item,{}).get("tipo","").begins_with("caixa")
	var velocidade: float = 0.425 if personagem.robo else (0.475 if caixa else 0.55)
	if personagem.cargo == "crianca" and personagem.visita.get("correndo",false): velocidade *= 1.6
	if EscadasPlex.eh(planta.em(inicio)) or EscadasPlex.eh(planta.em(destino)):
		velocidade *= 0.62
	var anterior := progresso
	var comprimento := maxf(0.001, ponto_inicio.distance_to(ponto_destino))
	progresso = minf(1.0, progresso + delta * velocidade / comprimento)
	personagem.local = ponto_inicio.lerp(ponto_destino, progresso)
	var deslocamento := GradePlex.projetar_local(ponto_destino - ponto_inicio)
	personagem.direcao = posmod(int(round(atan2(deslocamento.x, deslocamento.y * 2.0) / (PI / 4.0))), 8)
	if progresso >= 1.0:
		personagem.celula = destino
		personagem.local = ponto_destino
		rota.pop_front()
		atravessando = false
	return (progresso - anterior) * comprimento


class_name PosicaoTrabalhoPlex
extends RefCounted

const MARGEM = 0.22

static func entrada(origem: Vector2, destino: Vector2, caixa: Rect2) -> float:
	var vetor := destino - origem
	var inicio := 0.0
	var fim := 1.0
	for eixo in 2:
		if absf(vetor[eixo]) < 0.000001:
			if origem[eixo] <= caixa.position[eixo] or origem[eixo] >= caixa.end[eixo]: return 1.0
		else:
			var a: float = (caixa.position[eixo] - origem[eixo]) / vetor[eixo]
			var b: float = (caixa.end[eixo] - origem[eixo]) / vetor[eixo]
			inicio = maxf(inicio, minf(a, b))
			fim = minf(fim, maxf(a, b))
			if fim <= inicio: return 1.0
	return maxf(0.0, inicio - 0.001) if fim > 0.0 else 1.0

static func limitar(planta: PlantaPlex, origem: Vector2, destino: Vector2) -> Vector2:
	var limite := 1.0
	for y in GradePlex.TAMANHO.y:
		for x in GradePlex.TAMANHO.x:
			var celula := Vector2i(x, y)
			if planta.transitavel(celula): continue
			var caixa := Rect2(Vector2(celula) - Vector2(.5, .5), Vector2.ONE).grow(MARGEM)
			limite = minf(limite, entrada(origem, destino, caixa))
	return origem.lerp(destino, limite)

static func aproximacao(ator: PersonagemPlex, planta: PlantaPlex, alvo: Vector2, proporcao: float) -> Vector2:
	var origem := Vector2(ator.celula)
	return limitar(planta, origem, origem.lerp(alvo, proporcao))

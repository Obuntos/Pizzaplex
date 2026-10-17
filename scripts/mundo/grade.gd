class_name GradePlex
extends RefCounted

const TAMANHO = Vector2i(32, 24)
const TILE = Vector2(64, 32)
const ALTURA_PALCO = 18.0
const CENTRO = Vector2(TAMANHO - Vector2i.ONE) * 0.5
static var visao: int = 0
const VIZINHOS = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

static func dentro(celula: Vector2i) -> bool:
	return celula.x >= 0 and celula.y >= 0 and celula.x < TAMANHO.x and celula.y < TAMANHO.y

static func girar(vetor: Vector2, quartos: int) -> Vector2:
	match posmod(quartos, 4):
		1: return Vector2(-vetor.y, vetor.x)
		2: return -vetor
		3: return Vector2(vetor.y, -vetor.x)
	return vetor

static func posicao_visao(ponto: Vector2) -> Vector2:
	return girar(ponto - CENTRO, visao) + CENTRO

static func posicao_mundo(ponto: Vector2) -> Vector2:
	return girar(ponto - CENTRO, -visao) + CENTRO

static func projetar_local(vetor: Vector2, altura: float = 0.0) -> Vector2:
	return Vector2((vetor.x - vetor.y) * 32.0, (vetor.x + vetor.y) * 16.0 - altura)

static func projetar_vetor(vetor: Vector2, altura: float = 0.0) -> Vector2:
	return projetar_local(girar(vetor, visao), altura)

static func projetar(celula: Vector2, altura: float = 0.0) -> Vector2:
	return projetar_local(posicao_visao(celula), altura)

static func inverter_local(posicao: Vector2) -> Vector2:
	return Vector2(posicao.x / 64.0 + posicao.y / 32.0, posicao.y / 32.0 - posicao.x / 64.0)

static func inverter_vetor(posicao: Vector2) -> Vector2:
	return girar(inverter_local(posicao), -visao)

static func inverter(posicao: Vector2) -> Vector2:
	return posicao_mundo(inverter_local(posicao))

static func profundidade(ponto: Vector2, altura: float = 0.0) -> float:
	return projetar(ponto).y * 2.0 + altura

static func rotacao_visual(rotacao: int) -> int:
	return posmod(rotacao + visao, 4)

static func direcao_visual(direcao: int) -> int:
	return posmod(direcao - visao * 2, 8)

static func mascara_visual(mascara: int) -> int:
	var resultado := 0
	for i in 4:
		if mascara & (1 << i): resultado |= 1 << posmod(i + visao, 4)
	return resultado

static func selecionar(posicao: Vector2) -> Vector2i:
	return Vector2i(inverter(posicao).round())

static func frente(rotacao: int) -> Vector2i:
	return [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0)][posmod(rotacao, 4)]

static func direcao_suporte(rotacao: int) -> int:
	var frente := frente(rotacao)
	var tela := projetar_local(Vector2(frente))
	return posmod(int(round(atan2(tela.x, tela.y * 2.0) / (PI / 4.0))), 8)

static func poligono(centro: Vector2) -> PackedVector2Array:
	return PackedVector2Array([centro + Vector2(0, -16), centro + Vector2(32, 0), centro + Vector2(0, 16), centro + Vector2(-32, 0)])

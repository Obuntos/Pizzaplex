class_name EscalaPlex
extends RefCounted

static var dados: Dictionary = {}
var ativo: bool = false
var celula := Vector2i.ZERO
var rotacao: int = 0
var sentido: String = "subir"
var carregando: bool = false
var relogio: float = 0.0
var indice: int = 0
var quadro: int = 0
var definicao: Dictionary = {}
var percurso: Dictionary = {}
var pes: Array[Vector3] = []
var pisos: Array[float] = []
var ajuste_entrada := Vector2.ZERO
var fase_continua:=0.0

static func carregar() -> void:
	if dados.is_empty():
		dados = JSON.parse_string(FileAccess.get_file_as_string("res://dados/escadas.json"))

func iniciar(personagem: Node2D, planta: PlantaPlex, escada: Vector2i, modo: String) -> bool:
	carregar()
	var modelo: String = personagem.modelo
	if not dados.has(modelo) and (modelo.begins_with("novo_") or AtracoesCatalogoPlex.permitido(modelo)): modelo="coelho"
	if not dados.has(modelo): modelo=AnimatronicosPlex.base(modelo)
	if not dados.get(modelo,{}).has(modo):
		return false
	var objeto := planta.em(escada)
	if not EscadasPlex.eh(objeto) or not EscadasPlex.acessivel(escada,planta):
		return false
	celula = escada
	rotacao = objeto.rotacao
	sentido = modo
	carregando = personagem.carregando or personagem.carga_item>=0
	definicao = dados[modelo][sentido]
	percurso = definicao.tracks[rotacao]
	var primeiro: Array=percurso.frames[0]
	ajuste_entrada=personagem.local-Vector2(celula)-Vector2(primeiro[1],primeiro[2])
	relogio = 0.0
	indice = 0
	quadro = 0
	ativo = true
	aplicar(personagem, 0.0)
	return true

func aplicar(personagem: Node2D, mistura: float) -> void:
	var a: Array = percurso.frames[indice]
	var b: Array = percurso.frames[mini(indice + 1, percurso.frames.size() - 1)]
	var ajuste := ajuste_entrada*(1.0-smoothstep(0.0,.24,relogio))
	personagem.local = Vector2(celula) + Vector2(lerpf(a[1], b[1], mistura), lerpf(a[2], b[2], mistura)) + ajuste
	personagem.altura = lerpf(a[3], b[3], mistura)
	personagem.fase = lerpf(a[4], b[4], mistura)
	fase_continua=personagem.fase
	personagem.direcao = percurso.facing
	quadro = indice + (1 if mistura >= 0.5 and indice + 1 < percurso.frames.size() else 0)
	pes.clear()
	pisos.clear()
	for pe in 2:
		var inicio: int = 5 + pe * 4
		pes.append(Vector3(celula.x + lerpf(a[inicio], b[inicio], mistura) + ajuste.x, celula.y + lerpf(a[inicio + 1], b[inicio + 1], mistura) + ajuste.y, lerpf(a[inicio + 2], b[inicio + 2], mistura)))
		pisos.append(a[inicio + 3] if mistura < 0.5 else b[inicio + 3])

func fase_visual() -> float:
	return fase_continua if not percurso.is_empty() else 0.0

func atualizar(personagem: Node2D, delta: float) -> bool:
	relogio = minf(percurso.duration, relogio + delta * (1.0 if personagem.robo else 1.25) / (1.16 if carregando else 1.0))
	while indice + 1 < percurso.frames.size() and percurso.frames[indice + 1][0] <= relogio:
		indice += 1
	var a: Array = percurso.frames[indice]
	var b: Array = percurso.frames[mini(indice + 1, percurso.frames.size() - 1)]
	var mistura: float = clampf((relogio - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])), 0.0, 1.0)
	var altura_anterior:float=personagem.altura
	aplicar(personagem, mistura)
	var altura_alvo:float=personagem.altura
	if not definicao.get("apoios_tile",false): personagem.altura=move_toward(altura_anterior,altura_alvo,delta*30.0)
	return relogio >= float(percurso.duration) - 0.00001 and is_equal_approx(personagem.altura,altura_alvo)



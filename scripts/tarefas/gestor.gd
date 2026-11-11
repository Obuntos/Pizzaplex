class_name TarefasPlex
extends RefCounted

var planta: PlantaPlex
var rotas: RotasPlex
var personagens: Array = []
var trabalhos: Dictionary = {}
var inventario: InventarioPlex

func _init(valor: PlantaPlex, caminhos: RotasPlex) -> void:
	planta = valor
	rotas = caminhos
	inventario = InventarioPlex.new(planta)

func liberar(personagem: PersonagemPlex) -> void:
	var trabalho: Dictionary = trabalhos.get(personagem.identificador,{})
	var caixa: int = trabalho.get("caixa",-1)
	if planta.objetos.has(caixa) and planta.objetos[caixa].get("carregada_por",0)==personagem.identificador:
		personagem.carga_item = caixa
		inventario.devolver(personagem)
	var bancada: Dictionary = planta.objetos.get(trabalho.get("bancada",-1),{})
	if bancada.get("caixa_montagem",-1)==caixa:
		bancada.caixa = false
		bancada.erase("caixa_montagem")
	for item in planta.objetos.values():
		if item.get("reserva",0)==personagem.identificador: item.reserva = 0
	trabalhos.erase(personagem.identificador)
	personagem.trabalho = ""
	personagem.carregando = false
	personagem.progresso_acao = 0.0

func orientar(personagem: PersonagemPlex, destino: Vector2) -> void:
	var deslocamento := GradePlex.projetar_local(destino-personagem.local)
	personagem.direcao = posmod(int(round(atan2(deslocamento.x,deslocamento.y*2.0)/(PI/4.0))),8)


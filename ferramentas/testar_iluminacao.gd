extends SceneTree

var falhas: Array[String] = []
var verificacoes := 0

func _initialize() -> void:
	_executar.call_deferred()

func verificar(condicao: bool, mensagem: String) -> void:
	verificacoes += 1
	if not condicao: falhas.append(mensagem)

func ponto(celula: Vector2, altura: float) -> Vector3:
	var tela := GradePlex.projetar(celula)
	return Vector3(tela.x, tela.y * 2.0, altura)

func inserir(planta: PlantaPlex, tipo: String, celula: Vector2i, rotacao: int = 0, aberta: bool = false) -> int:
	var id := planta.objetos.size() + 1
	planta.objetos[id] = {"id":id, "tipo":tipo, "celula":celula, "rotacao":rotacao, "aberta":aberta}
	if tipo in SalasPlex.ESTRUTURA or tipo == "palco":
		for c in planta.celulas(tipo, celula, rotacao): planta.ocupacao[c] = id
	return id

func testar_raios() -> void:
	for visao in 4:
		GradePlex.visao = visao
		var planta := PlantaPlex.new()
		inserir(planta, "parede", Vector2i(8, 7))
		verificar(OclusaoPlex.visibilidade(planta, ponto(Vector2(7, 7), 40), ponto(Vector2(9, 9), 40)) == 1.0, "Raio tangente a uma quina: visão " + str(visao))
		verificar(OclusaoPlex.visibilidade(planta, ponto(Vector2(7, 6.99), 40), ponto(Vector2(9, 8.99), 40)) == 0.0, "Raio atravessando a lateral da quina: visão " + str(visao))
		verificar(OclusaoPlex.visibilidade(planta, ponto(Vector2(7.5, 7), 40), ponto(Vector2(6, 7), 40)) == 1.0, "Raio saindo da face da parede: visão " + str(visao))
		verificar(OclusaoPlex.visibilidade(planta, ponto(Vector2(7.5, 7), 40), ponto(Vector2(10, 7), 40)) == 0.0, "Raio entrando na parede: visão " + str(visao))
		verificar(OclusaoPlex.visibilidade(planta, ponto(Vector2(6, 7), 40), ponto(Vector2(10, 7), 40)) == 0.0, "Parede continua bloqueando: visão " + str(visao))
		planta = PlantaPlex.new()
		inserir(planta, "palco", Vector2i(8, 8))
		verificar(OclusaoPlex.visibilidade(planta, ponto(Vector2(8, 8), 19.5), ponto(Vector2(10, 8), 72)) == 1.0, "Topo do palco recebe luz: visão " + str(visao))
		verificar(OclusaoPlex.visibilidade(planta, ponto(Vector2(6, 8), 5), ponto(Vector2(10, 8), 5)) == 0.0, "Volume do palco bloqueia luz: visão " + str(visao))

func testar_portas() -> void:
	for visao in 4:
		GradePlex.visao = visao
		for rotacao in 4:
			var planta := PlantaPlex.new()
			var centro := Vector2(8, 8)
			var frente := Vector2(GradePlex.frente(rotacao))
			var id := inserir(planta, "porta", Vector2i(8, 8), rotacao)
			var a := ponto(centro - frente * 2.0, 40)
			var b := ponto(centro + frente * 2.0, 40)
			verificar(OclusaoPlex.visibilidade(planta, a, b) == 0.0, "Folha fechada bloqueia: " + str([visao, rotacao]))
			planta.objetos[id].aberta = true
			verificar(OclusaoPlex.visibilidade(planta, a, b) == 1.0, "Passagem aberta recebe luz: " + str([visao, rotacao]))
			a.z = 110
			b.z = 110
			verificar(OclusaoPlex.visibilidade(planta, a, b) == 0.0, "Verga continua bloqueando: " + str([visao, rotacao]))

func testar_luminarias() -> void:
	for visao in 4:
		GradePlex.visao = visao
		var planta := PlantaPlex.new()
		inserir(planta, "luz_chao", Vector2i(12, 12))
		var luzes := IluminacaoPlex.new(planta)
		luzes.atualizar()
		var origem := ponto(Vector2(12, 12), 0)
		verificar(luzes.energia_recebida(0, origem) > 0.0, "Luminária ilumina o piso sob ela: visão " + str(visao))
		verificar(luzes.energia_recebida(0, origem + Vector3(32, 0, 0)) > 0.0, "Luminária ilumina o piso ao redor: visão " + str(visao))
		verificar(luzes.energia_recebida(0, origem + Vector3(0, 0, 55)) > 0.0, "Luminária alcança o personagem: visão " + str(visao))
		verificar(luzes.energia_recebida(0, origem + Vector3(200, 0, 0)) == 0.0, "Alcance continua limitado: visão " + str(visao))
		var antes := luzes.energia_recebida(0, origem + Vector3(32, 0, 0))
		inserir(planta, "luz_chao", Vector2i(13, 12))
		luzes.invalidar()
		luzes.atualizar()
		var depois := luzes.energia_recebida(0, origem + Vector3(32, 0, 0)) + luzes.energia_recebida(1, origem + Vector3(32, 0, 0))
		verificar(depois > antes, "Segunda luminária soma luz na interseção: visão " + str(visao))

func testar_previa() -> void:
	GradePlex.visao = 0
	var previa := CriacaoPartidaPlex.new()
	root.add_child(previa)
	previa.abrir(true)
	await process_frame
	await process_frame
	previa.centralizar()
	var posicao := previa.ator.position
	var id := previa.ator.get_instance_id()
	for i in previa.cabelo.item_count:
		previa.trocar_cabelo(1)
		verificar(previa.ator.position.is_equal_approx(posicao), "Troca de cabelo mantém o centro: " + str(i))
		verificar(previa.ator.get_instance_id() == id, "Troca de cabelo preserva o personagem: " + str(i))
	previa.queue_free()

func _executar() -> void:
	CatalogoPlex.carregar()
	testar_raios()
	testar_portas()
	testar_luminarias()
	await testar_previa()
	GradePlex.visao = 0
	for falha in falhas: push_error(falha)
	print(str(verificacoes) + " verificações; " + str(falhas.size()) + " falhas")
	quit(0 if falhas.is_empty() else 1)

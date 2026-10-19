class_name PersonagemPlex
extends Node2D

var identificador: int = 0
var identidade: Dictionary = {}
var equipe: Array = []
var modelo: String = "humano"
var robo: bool = false
var celula := Vector2i.ZERO
var local := Vector2.ZERO
var altura: float = 0.0
var direcao: int = 7
var fase: float = 0.25
var relogio: float = 0.0
var carregando: bool = false
var trabalho: String = ""
var automatico: bool = true
var suporte: int = -1
var pose: int = -1
var selecionado: bool = false
var animacao := AnimacaoPlex.new()
var movimento := MovimentoPlex.new()
var visual := Node2D.new()
var carga := Sprite2D.new()
var pecas: int = -1
var progresso_acao: float = 0.0
var alvo_carga := Vector3.ZERO
var em_degraus: bool = false
var aguardando_saida: bool = false
var carga_item: int = -1
var carga_extra: Array[int] = []
var energia: float = 100.0
var cargo: String = "funcionario"
var funcao: String = "geral"
var funcoes_secundarias: Array = []
var caixa_tipo: String = "caixa"
var caixa_qualidade: String = "boa"
var caixa_durabilidade: int = 100
var cabelo: String = "automatico"
var uniforme: String = "automatico"
var personalizacao := AparenciaPlex.new()
var familia: int = -1
var responsavel: int = -1
var visita: Dictionary = {}
var robotica: Dictionary = {}
var planta_visual: PlantaPlex
var manuseio := ManuseioPlex.new()
var necessidades: Dictionary = {"banheiro":100.0,"higiene":100.0,"lazer":100.0,"turno":false}
var assento: int = -1
var postura := PosturaPlex.new()
var identificacao := IdentificacaoPlex.new()
var pintura := ComposicaoPersonagemPlex.new()

func configurar(id: int, aparencia: String, local_inicial: Vector2i, robotico: bool = false) -> void:
	identificador = id
	modelo = aparencia
	robo = robotico
	IdentidadesPlex.garantir(self)
	celula = local_inicial
	local = Vector2(celula)
	name = modelo.capitalize() + str(id)
	add_child(visual)
	visual.add_child(animacao)
	animacao.configurar(modelo)
	carga.texture = CatalogoPlex.sprite(caixa_tipo, GradePlex.rotacao_visual(0))
	carga.centered = false
	carga.scale = Vector2.ONE
	carga.position = Vector2(-96, -144)
	carga.visible = false
	visual.add_child(carga)
	visual.add_child(manuseio)
	visual.add_child(postura)
	add_child(personalizacao)
	personalizacao.configurar(self)
	add_child(identificacao)
	add_child(pintura)

func mudar_modelo(valor: String) -> void:
	modelo = valor
	animacao.configurar(valor)
	pecas = -1
	animacao.endo_config.clear()
	animacao.endo_partes.clear()

func andar(caminho: Array[Vector2i]) -> void:
	if not ocupado():
		fase = 0.25
	movimento.iniciar(self, caminho)

func origem_rota() -> Vector2i:
	return movimento.origem_planejamento(self)

func ocupado() -> bool:
	return movimento.cedendo or movimento.atravessando or not movimento.rota.is_empty()

func atualizar(delta: float, planta: PlantaPlex, rotas: RotasPlex, personagens: Array) -> void:
	planta_visual = planta
	relogio += delta
	if suporte >= 0 and planta.objetos.has(suporte) and not ocupado():
		direcao = GradePlex.direcao_suporte(planta.objetos[suporte].rotacao)
	em_degraus = movimento.escala.ativo
	var distancia := movimento.atualizar(self, delta, planta, rotas, personagens)
	em_degraus = em_degraus or movimento.escala.ativo
	if distancia > 0.0 and not em_degraus:
		fase += distancia / (0.34 if robo else 0.42)
	if not movimento.escala.ativo:
		altura = EscadasPlex.altura(local, planta)
		if suporte >= 0 and not ocupado():
			altura += ApoioMontagemPlex.elevacao(self)
	atualizar_visual(distancia > 0.0)

func atualizar_visual(andando: bool) -> void:
	if trabalho=="usar_caixa": progresso_acao=fposmod(relogio/1.6,1.0)
	animacao.roupa_visitante=RoupasVisitantesPlex.pasta(self)
	var ponto := ponto_visual()
	position = GradePlex.projetar(Vector2(ponto.x, ponto.y)) + Vector2(0.0, 0.01)
	visual.position.y = -ponto.z
	var acao: String = "parado"
	var tempo_visual:=relogio
	animacao.desgaste=float(robotica.get("desgaste",0.0))
	if trabalho=="assistir_mascote" and (modelo=="crianca" or modelo.begins_with("adolescente")):
		acao="assistir"
	elif trabalho=="animar_visitantes" and modelo.begins_with("fantasia_"):
		acao="montar"
	elif trabalho in ["montar", "colocar", "reparar"]:
		acao = "montar" if trabalho=="reparar" else trabalho
	elif trabalho in ["preparar", "lavar", "usar_caixa"] and not ocupado():
		acao = "parado"
	elif trabalho in ["jogar", "assistir"] and (modelo == "crianca" or modelo.begins_with("adolescente")) and not ocupado():
		acao = "parado" if trabalho == "assistir" and visita.get("assistiu",false) else trabalho
	elif trabalho == "sentar_mesa" and assento >= 0 and not ocupado():
		acao = "sentar"
	elif andando or (robo and ocupado()):
		acao = "carregar" if carregando else "andar"
	elif robo and pronto_para_destino() and not ocupado():
		var estado:=str(robotica.get("estado","desligado"))
		acao=(str(robotica.get("apresentacao","cantar")) if trabalho=="apresentar" else "parado") if estado=="ligado" else "ativando" if estado in ["ativando","desligando"] else "desligado"
		tempo_visual=float(robotica.get("tempo_estado",0.0))
		if estado=="desligando": tempo_visual=(1.0-clampf(tempo_visual/1.6,0.0,1.0))*AnimatronicosPlex.duracao_partida(self)
		if not ClipesPlex.possui(modelo,acao):
			acao="parado"
			if estado!="ligado": tempo_visual=0.0
	if CatalogoMontagemPlex.quebrado(modelo): acao="andar" if andando and ClipesPlex.possui(modelo,"andar") else "parado"
	if em_degraus:
		animacao.atualizar_escada(movimento.escala, GradePlex.direcao_visual(direcao), relogio)
	else:
		animacao.atualizar(acao, GradePlex.direcao_visual(direcao), fase, tempo_visual, pecas, progresso_acao)
	carga.visible = (carregando or carga_item>=0) and not em_degraus and trabalho == "colocar" and animacao.definicao.layered
	carga.texture = CatalogoPlex.sprite(caixa_tipo, GradePlex.rotacao_visual(0))
	if carga.visible:
		var angulo := GradePlex.direcao_visual(direcao) * PI / 4.0
		var origem := Vector2(sin(angulo) * 6.75, cos(angulo) * 3.375 - 19.75) - Vector2(96, 144)
		carga.position = origem
		if trabalho == "colocar":
			carga.position = origem.lerp(GradePlex.projetar(Vector2(alvo_carga.x, alvo_carga.y), alvo_carga.z) - position - visual.position - Vector2(96, 144), smoothstep(0.0, 1.0, progresso_acao))
		visual.move_child(carga, 0 if GradePlex.direcao_visual(direcao) in [3, 4, 5] else visual.get_child_count() - 1)
	manuseio.atualizar(self,planta_visual,andando or em_degraus)
	personalizacao.atualizar(self,andando or em_degraus)
	postura.atualizar(self)
	identificacao.atualizar(self)
	pintura.atualizar(self)
	queue_redraw()

func _draw() -> void:
	if selecionado:
		draw_polyline(GradePlex.poligono(Vector2(0, -altura)) + PackedVector2Array([Vector2(0, -16 - altura)]), Color("a4c2b0"), 1.0)

func ponto_visual() -> Vector3:
	if assento >= 0 and trabalho in ["usar_vaso", "sentar_mesa"] and planta_visual != null and planta_visual.objetos.has(assento):
		var item: Dictionary = planta_visual.objetos[assento]
		var centro := ApoiosPlex.posicao(planta_visual, item)
		var frente := Vector2(GradePlex.frente(item.rotacao)) * (0.12 if trabalho == "usar_vaso" else 0.12)
		var altura_assento := 18.0 if trabalho == "usar_vaso" else 21.2
		var quadril := 11.0 if modelo == "crianca" else 12.9 if modelo.begins_with("adolescente") else 15.0
		return centro + Vector3(frente.x, frente.y, altura_assento - quadril * animacao.scale.y)
	return Vector3(local.x, local.y, altura)

func pronto_para_destino() -> bool:
	return robo and modelo!="endo" and animacao.endo_config.is_empty()


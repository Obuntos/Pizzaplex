class_name OperacaoRestaurantePlex
extends RefCounted

var jogo: Node
var candidatos:Dictionary={}
var nome := "Pizzaplex"
var aberto := false
var administrador := -1
var criacao: Dictionary = {}
var espera_chegada := 25.0
var mostrar_controle := true
var motivo_chegada := ""
var credito_v5:=true

func _init(cena: Node) -> void:
	jogo = cena

func configurar(valor: Dictionary) -> void:
	candidatos.clear();credito_v5=true
	criacao = valor.duplicate(true)
	nome = str(criacao.get("restaurante","Pizzaplex")).strip_edges().left(40)
	if nome.is_empty(): nome = "Pizzaplex"
	aberto = false
	espera_chegada=3.0
	jogo.livro.restaurar({})
	jogo.sistemas.restaurar({})
	aplicar_precos()

func aplicar_precos() -> void:
	jogo.compras.catalogo = JSON.parse_string(FileAccess.get_file_as_string("res://dados/compras.json"))
	for id in jogo.compras.catalogo.keys():
		if jogo.compras.catalogo[id].get("grupo","")=="oficina": jogo.compras.catalogo.erase(id)

func bloqueado_por_seguranca() -> bool:
	return jogo.sistemas.guarda.escala.noite_atual(jogo.calendario.dias,jogo.calendario.minutos)>=0
func aplicar_credito() -> void:
	credito_v5=true
func mudar_abertura(valor: bool) -> void:
	if valor and bloqueado_por_seguranca():jogo.painel.mensagem("Abertura trancada durante o turno do segurança.");return
	if aberto!=valor:
		if valor: jogo.fantasias.abertura(); jogo.encerramento.reabrir()
		else: jogo.encerramento.iniciar()
	aberto = valor
	espera_chegada = minf(espera_chegada,3.0)
	jogo.painel.mensagem("Restaurante aberto. Novas visitas chegam quando houver uma entrada e espaço interno para recebê-las." if aberto else "Restaurante fechado. Visitantes e funcionários interrompem as tarefas e seguem para a saída.")
	jogo.painel.hud.atualizar(1.0)

func chegada() -> Vector2i:
	return EntradaVisitantesPlex.chegada(jogo.clientes,GradePlex.TAMANHO-Vector2i.ONE)

func atualizar(delta: float) -> void:
	aplicar_credito()
	if bloqueado_por_seguranca():
		if aberto:mudar_abertura(false)
		return
	if not aberto: return
	espera_chegada -= delta
	if espera_chegada>0: return
	espera_chegada = 5.0
	jogo.ambientes.atualizar()
	var salao: bool=jogo.ambientes.ambientes.any(func(sala): return sala.fechada and (sala.funcoes.has("salao") or sala.objetos.any(func(id):return LugaresPlex.mesa(jogo.planta.objetos[id].tipo) and LugaresPlex.total(jogo.planta,id)>0)))
	var arcade: bool=not jogo.ambientes.equipamentos("maquina_fliperama",["jogos"]).is_empty()
	salao=salao and jogo.clientes.recepcao.tem_vaga(1)
	arcade=arcade and jogo.clientes.recepcao.vaga_arcade()
	if not salao and not arcade:
		motivo_chegada="Sem vagas: libere mesas e cadeiras ou máquinas de fliperama antes de receber mais visitantes."
		return
	var local := chegada()
	if not GradePlex.dentro(local):
		motivo_chegada="A entrada precisa ligar o exterior a uma área interna, com passagem livre."
		return
	var criou: bool=false
	if jogo.populacao.iniciado and jogo.populacao.cidade_presente: criou=jogo.populacao.visitas.solicitar(local,salao,arcade)
	elif arcade and (not salao or randi()%4==0): criou=jogo.lazer.criar(local,randi()%2==0)
	else: criou=jogo.clientes.criar_preset(local,"variada")
	if criou:
		motivo_chegada=""
		espera_chegada=45.0
	else: motivo_chegada="Os moradores estão ocupados ou já visitaram hoje." if jogo.populacao.iniciado else "Libere espaço próximo à entrada para os visitantes chegarem juntos."

func gravar() -> Dictionary:
	return {"credito_v5":credito_v5,"candidatos":candidatos.duplicate(true),"nome":nome,"aberto":aberto,"administrador":administrador,"criacao":criacao,"espera_chegada":espera_chegada,"mostrar_controle":mostrar_controle,"fantasia_adiada":jogo.fantasias.adiou,"livro":jogo.livro.gravar()}

func restaurar(valor: Dictionary) -> void:
	credito_v5=true
	candidatos=valor.get("candidatos",{}).duplicate(true)
	nome = str(valor.get("nome","Pizzaplex"))
	aberto = bool(valor.get("aberto",true))
	administrador = int(valor.get("administrador",-1))
	criacao = valor.get("criacao",{}).duplicate(true)
	espera_chegada = float(valor.get("espera_chegada",25.0))
	mostrar_controle = bool(valor.get("mostrar_controle",true))
	jogo.fantasias.adiou=bool(valor.get("fantasia_adiada",false))
	jogo.livro.restaurar(valor.get("livro",{}))
	aplicar_precos()

func pular_noite() -> void:
	if jogo.get_node_or_null("TransicaoNoite")!=null:return
	if jogo.calendario.minutos>=360:jogo.painel.mensagem("Pule a noite entre 00:00 e 06:00.");return
	var transicao:=TransicaoNoitePlex.new();transicao.name="TransicaoNoite";jogo.add_child(transicao);transicao.iniciar(jogo,pular_noite_imediato)
func pular_noite_imediato() -> void:
	if jogo.calendario.minutos>=360:
		jogo.painel.mensagem("Pule a noite entre 00:00 e 06:00.");return
	if aberto:mudar_abertura(false)
	var indice:int=jogo.sistemas.guarda.escala.noite_atual(jogo.calendario.dias,jogo.calendario.minutos)
	if indice>=0 and jogo.personagens.any(func(a):return a.funcao=="seguranca" and jogo.sistemas.guarda.escala.ativo(a,jogo.calendario.dias,jogo.calendario.minutos)):jogo.sistemas.guarda.escala.presencas[str(indice)]=true
	var tempo:float=(360.0-jogo.calendario.minutos)/CalendarioPlex.MINUTOS_POR_SEGUNDO
	jogo.iluminacao.rede.atualizar(tempo*CalendarioPlex.MINUTOS_POR_SEGUNDO)
	for a in jogo.personagens:
		if a.cargo=="funcionario" and not a.visita.get("morto",false):TurnosEquipePlex.recuperar_descanso(a)
	jogo.calendario.minutos=360.0
	jogo.sistemas.guarda.atualizar(1.0);jogo.turnos.atualizar(1.0);jogo.iluminacao.rede.atualizar(0.0)
	jogo.painel.hud.atualizar(1.0);jogo.painel.mensagem("06:00. A noite terminou.")

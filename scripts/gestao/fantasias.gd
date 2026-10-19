class_name FantasiasRestaurantePlex
extends RefCounted

const MODELOS = ["fantasia_coelho","fantasia_ovelha","fantasia_raposa"]
var jogo: Node
var espera := 0.0
var adiou := false

func _init(cena: Node) -> void:
	jogo=cena

static func ocupando(ator: PersonagemPlex) -> bool:
	return str(ator.visita.get("fantasia_etapa","")) not in ["","esperando"]

func administrador() -> PersonagemPlex:
	return jogo.clientes.ator(jogo.operacao.administrador)

func tem_animatronico() -> bool:
	return jogo.personagens.any(func(a): return a.robo and not a.modelo.begins_with("endo") and not CatalogoMontagemPlex.quebrado(a.modelo))

func presenter() -> PersonagemPlex:
	var a:=administrador()
	return a if is_instance_valid(a) and a.modelo.begins_with("fantasia_") and str(a.visita.get("fantasia_etapa","")) in ["passear","animar"] else null

func abertura() -> void:
	adiou=false
	var a:=administrador()
	if is_instance_valid(a): a.visita.erase("fantasia_preferida")

func urgente(a: PersonagemPlex) -> bool:
	if EquipePlex.permite(a,"caixa") and jogo.clientes.grupos.values().any(func(g): return g.get("estado","")=="pagamento"): return true
	if EquipePlex.permite(a,"cozinha") and jogo.servicos.pedidos.any(func(p): return p.estado in ["aguardando","preparando","assando"]): return true
	return EquipePlex.permite(a,"atendimento") and jogo.servicos.pedidos.any(func(p): return (p.estado in ["pronta","entregando"] or p.estado in ["entregue","consumido"] and p.get("bebida_estado","") not in ["servida","consumida"]))

func escolher_armario(a: PersonagemPlex) -> int:
	var itens: Array=jogo.planta.objetos.values().filter(func(o): return o.tipo=="armario_funcionarios" and int(o.get("reserva",0)) in [0,a.identificador])
	itens.sort_custom(func(x,y): return a.local.distance_squared_to(Vector2(x.celula))<a.local.distance_squared_to(Vector2(y.celula)))
	for item in itens:
		if not jogo.rotas.aproximar(a.origem_rota(),item.id).is_empty(): return item.id
	return -1

func mover_armario(a: PersonagemPlex) -> bool:
	var id:=int(a.visita.get("fantasia_armario",-1))
	if not jogo.planta.objetos.has(id):
		id=escolher_armario(a)
		a.visita.fantasia_armario=id
	if id<0: return false
	var item: Dictionary=jogo.planta.objetos[id]
	item.reserva=a.identificador
	if a.ocupado(): return false
	if not jogo.planta.interacoes(id).has(a.celula):
		var rota: Array[Vector2i]=jogo.rotas.aproximar(a.origem_rota(),id)
		if not rota.is_empty(): a.andar(rota)
		return false
	jogo.tarefas.orientar(a,Vector2(item.celula))
	ArmariosPlex.estado(jogo.planta,id,true)
	return true

func liberar_armario(a: PersonagemPlex) -> void:
	var id:=int(a.visita.get("fantasia_armario",-1))
	if jogo.planta.objetos.has(id):
		ArmariosPlex.estado(jogo.planta,id,false)
		if int(jogo.planta.objetos[id].get("reserva",0))==a.identificador: jogo.planta.objetos[id].reserva=0

func vestir(modelo: String) -> void:
	var a:=administrador()
	if not is_instance_valid(a) or modelo not in MODELOS: return
	if not a.visita.has("fantasia_original"):
		a.visita.fantasia_original={"modelo":a.modelo,"uniforme":a.uniforme,"cabelo":a.cabelo}
	a.visita.fantasia_preferida=modelo
	a.mudar_modelo(modelo)
	a.uniforme="nenhum"
	a.cabelo="nenhum"
	a.visita.fantasia_etapa="passear"
	a.visita.fantasia_tempo=1.5
	a.trabalho="mascote"
	liberar_armario(a)
	a.atualizar_visual(false)
	jogo.composicao.atualizar_personagem(a)
	jogo.painel.mensagem("Fantasia vestida. O administrador vai circular pelo salão e entreter os visitantes.")

func retirar(a: PersonagemPlex) -> void:
	var original: Dictionary=a.visita.get("fantasia_original",jogo.operacao.criacao)
	a.mudar_modelo(str(original.get("modelo","humano")))
	a.uniforme=str(original.get("uniforme","administrador_masculino_1"))
	a.cabelo=str(original.get("cabelo","curto"))
	a.visita.erase("fantasia_original")
	a.visita.fantasia_etapa=""
	a.visita.fantasia_retorno_apos=a.relogio+12.0
	a.trabalho=""
	liberar_armario(a)
	a.atualizar_visual(false)
	jogo.composicao.atualizar_personagem(a)

func adiar() -> void:
	adiou=true
	var a:=administrador()
	if not is_instance_valid(a): return
	liberar_armario(a)
	a.visita.fantasia_etapa=""
	a.trabalho=""

func passear(a: PersonagemPlex) -> void:
	if a.ocupado(): return
	var jovens: Array=jogo.personagens.filter(func(p): return p.cargo in ["crianca","adolescente"] and "salao" in jogo.ambientes.em(p.celula).get("funcoes",[]))
	var origem: Vector2i=a.celula
	if not jovens.is_empty(): origem=jovens[randi()%jovens.size()].celula
	var locais: Array[Vector2i]=jogo.clientes.vagas(origem,16,4)
	locais.shuffle()
	for c in locais:
		if c==a.celula or jogo.planta.em(c).get("tipo","") in CatalogoPlex.PORTAS: continue
		if "salao" not in jogo.ambientes.em(c).get("funcoes",[]): continue
		var rota: Array[Vector2i]=jogo.rotas.caminho(a.origem_rota(),c)
		if rota.is_empty() or rota.size()>28: continue
		a.andar(rota)
		a.trabalho="mascote"
		return

func entreter(visitante: PersonagemPlex, grupo: Dictionary, delta: float) -> bool:
	var a:=presenter()
	if not is_instance_valid(a) or not jogo.operacao.aberto or visitante.assento>=0 or visitante.ocupado() or jogo.servicos.trabalhos.has(visitante.identificador): return false
	if grupo.get("estado","") in ["saindo","pago","pagamento"]: return false
	if visitante.local.distance_to(a.local)>3.5 or "salao" not in jogo.ambientes.em(visitante.celula).get("funcoes",[]): return false
	if visitante.relogio<float(visitante.visita.get("mascote_apos",0)): return false
	if a.ocupado(): return false
	visitante.visita.mascote_tempo=float(visitante.visita.get("mascote_tempo",0))+delta
	visitante.trabalho="assistir_mascote"
	visitante.animacao.expressao="feliz"
	visitante.necessidades.lazer=minf(100,visitante.necessidades.lazer+delta*2)
	jogo.tarefas.orientar(visitante,a.local)
	jogo.tarefas.orientar(a,visitante.local)
	a.visita.fantasia_etapa="animar"
	a.visita.fantasia_tempo=1.0
	a.trabalho="animar_visitantes"
	if float(visitante.visita.mascote_tempo)>=7.0:
		visitante.visita.mascote_tempo=0.0
		visitante.visita.mascote_apos=visitante.relogio+45.0
		visitante.visita.assistiu=true
		visitante.visita.tempo_show=maxf(16,float(visitante.visita.get("tempo_show",0)))
		visitante.visita.erase("show")
		visitante.visita.etapa=("arcade" if visitante.visita.get("comeu",false) else "refeicao") if visitante.cargo=="adolescente" and visitante.familia>=0 else "jogar" if visitante.cargo=="crianca" else "arcade"
		visitante.trabalho="visitar"
	return true

func atualizar(delta: float) -> void:
	espera+=delta
	if espera<.25: return
	var tempo:=espera
	espera=0
	var a:=administrador()
	if not is_instance_valid(a): return
	var fase:=str(a.visita.get("fantasia_etapa",""))
	var precisa: bool=jogo.operacao.aberto and not tem_animatronico() and not adiou and not urgente(a)
	if fase.is_empty():
		if precisa and a.relogio>=float(a.visita.get("fantasia_retorno_apos",0)) and escolher_armario(a)>=0: a.visita.fantasia_etapa="esperando"
		return
	if not precisa and fase not in ["retornar","tirar"]:
		if a.modelo.begins_with("fantasia_"):
			a.movimento.cancelar()
			a.visita.fantasia_etapa="retornar"
		else:
			liberar_armario(a)
			a.visita.fantasia_etapa=""
			if not jogo.servicos.trabalhos.has(a.identificador) and not jogo.tarefas.trabalhos.has(a.identificador): a.trabalho=""
		return
	match fase:
		"esperando":
			if jogo.servicos.trabalhos.has(a.identificador) or jogo.tarefas.trabalhos.has(a.identificador) or a.carregando or a.carga_item>=0 or a.trabalho in ["usar_caixa","ir_caixa"]: return
			a.movimento.cancelar()
			a.visita.fantasia_etapa="ir_armario"
			a.visita.fantasia_armario=escolher_armario(a)
			a.trabalho="ir_vestiario"
		"ir_armario":
			if not mover_armario(a):
				if int(a.visita.get("fantasia_armario",-1))<0: adiar()
				return
			a.visita.fantasia_etapa="escolher"
			a.trabalho="usar_armario"
			var preferida:=str(a.visita.get("fantasia_preferida",""))
			if preferida in MODELOS: vestir(preferida)
			else: jogo.vestiario_ui.abrir()
		"escolher":
			if not jogo.vestiario_ui.aberto(): jogo.vestiario_ui.abrir()
		"passear","animar":
			a.visita.fantasia_tempo=float(a.visita.get("fantasia_tempo",0))-tempo
			if float(a.visita.fantasia_tempo)>0: return
			a.visita.fantasia_etapa="passear"
			a.visita.fantasia_tempo=5.0
			passear(a)
		"retornar":
			if mover_armario(a):
				a.visita.fantasia_etapa="tirar"
				a.visita.fantasia_tempo=1.0
				a.trabalho="usar_armario"
			elif int(a.visita.get("fantasia_armario",-1))<0: retirar(a)
		"tirar":
			a.visita.fantasia_tempo=float(a.visita.get("fantasia_tempo",0))-tempo
			if float(a.visita.fantasia_tempo)<=0: retirar(a)

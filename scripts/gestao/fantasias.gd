class_name FantasiasRestaurantePlex
extends RefCounted

const MODELOS = ["fantasia_coelho"]
var jogo: Node
var espera := 0.0
var adiou := false

func _init(cena: Node) -> void:
	jogo=cena

static func ocupando(ator: PersonagemPlex) -> bool:
	return str(ator.visita.get("fantasia_etapa","")) in ["ir_armario","escolher","vestir","retornar","tirar"]

func administrador() -> PersonagemPlex:
	return jogo.clientes.ator(jogo.operacao.administrador)

func presenter() -> PersonagemPlex:
	var a:=administrador()
	return a if is_instance_valid(a) and a.modelo.begins_with("fantasia_") and str(a.visita.get("fantasia_etapa","")) in ["vestido","passear","animar"] and not a.ocupado() and a.trabalho in ["","mascote","animar_visitantes","circular_salao"] else null

func abertura() -> void:
	adiou=false
	var a:=administrador()
	if is_instance_valid(a): a.visita.erase("fantasia_preferida")

func urgente(a: PersonagemPlex) -> bool:
	if EquipePlex.permite(a,"limpeza") and jogo.planta.objetos.values().any(func(o): return o.tipo=="prato" and o.get("sujo",false) and int(o.get("carregada_por",0))==0): return true
	if jogo.clientes.recepcao.pendente() and (EquipePlex.permite(a,"atendimento") or EquipePlex.permite(a,"caixa")): return true
	if EquipePlex.permite(a,"caixa") and jogo.clientes.grupos.values().any(func(g): return g.get("estado","")=="pagamento"): return true
	if EquipePlex.permite(a,"cozinha") and jogo.servicos.pedidos.any(func(p): return p.estado in ["aguardando","preparando","assando"]): return true
	return EquipePlex.permite(a,"atendimento") and jogo.servicos.pedidos.any(func(p): return (p.estado in ["pronta","entregando"] or p.estado in ["entregue","consumido"] and p.get("bebida_estado","") not in ["servida","consumida"]))

func escolher_armario(a: PersonagemPlex) -> int:
	var itens: Array=jogo.planta.objetos.values().filter(func(o): return o.tipo=="armario_funcionarios")
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
	if not jogo.turnos.obter_vez(a,id):return false
	item.reserva=a.identificador
	if a.ocupado(): return false
	if not ArmariosPlex.em_vestiario(jogo.planta,a,id):
		var rota: Array[Vector2i]=jogo.rotas.aproximar(a.origem_rota(),id)
		if not rota.is_empty(): a.andar(rota)
		return false
	jogo.tarefas.orientar(a,Vector2(item.celula))
	ArmariosPlex.estado(jogo.planta,id,true)
	return true

func liberar_armario(a: PersonagemPlex) -> void:
	jogo.turnos.liberar_vestiario(a)
	var id:=int(a.visita.get("fantasia_armario",-1))
	if jogo.planta.objetos.has(id):
		ArmariosPlex.estado(jogo.planta,id,false)
		if int(jogo.planta.objetos[id].get("reserva",0))==a.identificador: jogo.planta.objetos[id].reserva=0

func vestir(modelo: String) -> void:
	var a:=administrador()
	if not is_instance_valid(a) or modelo not in MODELOS or escolher_armario(a)<0: return
	var id:=int(a.visita.get("fantasia_armario",-1))
	if not ArmariosPlex.em_vestiario(jogo.planta,a,id):
		if a.visita.get("controle_manual",false):jogo.painel.mensagem("Fique em frente ao armário verde para vestir a fantasia.");return
		a.visita.fantasia_preferida=modelo;a.visita.fantasia_etapa="ir_armario";a.visita.fantasia_armario=escolher_armario(a)
		a.trabalho="ir_vestiario";return
	if not a.visita.has("fantasia_original"):
		a.visita.fantasia_original={"modelo":a.modelo,"uniforme":a.uniforme,"cabelo":a.cabelo}
	a.visita.fantasia_preferida=modelo
	a.mudar_modelo(modelo)
	a.uniforme="nenhum"
	a.cabelo="nenhum"
	a.visita.fantasia_etapa="vestido"
	a.visita.fantasia_tempo=1.5
	a.trabalho="manual" if a.visita.get("controle_manual",false) else "mascote"
	if a.visita.get("controle_manual",false): a.visita.fantasia_etapa="manual"
	liberar_armario(a)
	jogo.turnos.afastar_armario(a,id)
	jogo.preparacao.personagem(a)
	a.atualizar_visual(false)
	jogo.composicao.atualizar_personagem(a)

func retirar(a: PersonagemPlex) -> void:
	if not ArmariosPlex.em_vestiario(jogo.planta,a,int(a.visita.get("fantasia_armario",-1))):return
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
	if int(visitante.visita.get("medo_fantasia",0))>=4 or int(visitante.visita.get("afinidade",3))==0: return false
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
		jogo.livro.divertir(visitante)
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
	if TurnosEquipePlex.ocupado(a) or a.visita.get("controle_manual",false): return
	var fase:=str(a.visita.get("fantasia_etapa",""))
	var vestido:=a.modelo=="fantasia_coelho"
	if vestido and jogo.operacao.aberto:
		if fase in ["retornar","tirar"]: liberar_armario(a)
		a.visita.fantasia_etapa="vestido"
		if urgente(a) and a.trabalho in ["mascote","animar_visitantes","circular_salao"]:
			a.movimento.cancelar();a.trabalho=""
		if EquipePlex.em_comando(a) or jogo.servicos.trabalhos.has(a.identificador) or jogo.tarefas.trabalhos.has(a.identificador) or int(a.visita.get("recepcao_grupo",-1))>=0 or a.carga_item>=0 or urgente(a): return
		if a.relogio<float(a.visita.get("conversando_ate",0)): a.trabalho="animar_visitantes";return
		if a.trabalho=="animar_visitantes": a.trabalho="mascote"
		a.visita.fantasia_tempo=float(a.visita.get("fantasia_tempo",0))-tempo
		if a.visita.fantasia_tempo<=0:
			a.visita.fantasia_tempo=5.0
			passear(a)
		return
	if not jogo.operacao.aberto:
		if not vestido:
			if not fase.is_empty(): liberar_armario(a);a.visita.fantasia_etapa=""
			return
		if fase not in ["retornar","tirar"]:
			if jogo.servicos.trabalhos.has(a.identificador): jogo.servicos.cancelar(a)
			if jogo.tarefas.trabalhos.has(a.identificador): jogo.tarefas.liberar(a)
			a.movimento.cancelar();a.visita.fantasia_etapa="retornar"
			fase="retornar"
		if fase=="retornar":
			if mover_armario(a): a.visita.fantasia_etapa="tirar";a.visita.fantasia_tempo=1.0;a.trabalho="usar_armario"
			elif int(a.visita.get("fantasia_armario",-1))<0: retirar(a)
		elif fase=="tirar":
			a.visita.fantasia_tempo=float(a.visita.get("fantasia_tempo",0))-tempo
			if a.visita.fantasia_tempo<=0: retirar(a)
		return
	if adiou or EquipePlex.em_comando(a) or str(a.visita.get("rotina_casa_etapa","")) not in ["", "preparar_saida"]: return
	if fase.is_empty() or fase=="esperando":
		if jogo.servicos.trabalhos.has(a.identificador): jogo.servicos.cancelar(a)
		if jogo.tarefas.trabalhos.has(a.identificador): jogo.tarefas.liberar(a)
		if a.carga_item>=0: jogo.servicos.inventario.devolver(a)
		a.movimento.cancelar();a.trabalho="ir_vestiario"
		a.visita.fantasia_etapa="ir_armario";a.visita.fantasia_armario=escolher_armario(a)
		fase="ir_armario"
	if fase=="ir_armario":
		if mover_armario(a): a.visita.fantasia_etapa="vestir";a.visita.fantasia_tempo=1.0;a.trabalho="usar_armario"
		elif int(a.visita.get("fantasia_armario",-1))<0:adiar()
	elif fase=="vestir":
		if not jogo.planta.objetos.has(int(a.visita.get("fantasia_armario",-1))):adiar();return
		if not ArmariosPlex.em_vestiario(jogo.planta,a,int(a.visita.fantasia_armario)):a.visita.fantasia_etapa="ir_armario";return
		a.visita.fantasia_tempo=float(a.visita.get("fantasia_tempo",0))-tempo
		if a.visita.fantasia_tempo<=0: vestir("fantasia_coelho")

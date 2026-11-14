class_name DestinosQuebradosPlex
extends RefCounted

var jogo: Node
var candidatos: Dictionary = {}
var revisao_candidatos := -1

func _init(cena: Node) -> void:
	jogo = cena

func livre(celula: Vector2i, ignorar: int = -1) -> bool:
	if jogo.planta.objetos.get(ignorar,{}).get("tipo","")=="pose_montagem":
		if not jogo.planta.transitavel(celula) or jogo.planta.em(celula).get("tipo","") not in ["","palco"]: return false
		if jogo.planta.sobre(celula).any(func(o): return o.id!=ignorar and o.tipo in ["pose_montagem","pose_quebrado","ponto_recebimento"]): return false
		return not jogo.personagens.any(func(a): return a.identificador!=jogo.planta.objetos[ignorar].get("dono",-1) and (a.celula==celula or (a.movimento.atravessando and a.movimento.destino==celula)))
	if not GradePlex.dentro(celula) or not jogo.planta.em(celula).is_empty() or not is_zero_approx(jogo.planta.altura(celula)): return false
	if jogo.planta.reservas_abertura.has(celula): return false
	if jogo.planta.sobre(celula).any(func(o): return o.id!=ignorar and o.tipo in ["pose_quebrado","pose_montagem","ponto_recebimento"]): return false
	var marca: Dictionary = jogo.planta.objetos.get(ignorar,{})
	if jogo.personagens.any(func(a): return a.identificador!=marca.get("dono",-1) and (a.celula==celula or (a.movimento.atravessando and a.movimento.destino==celula))): return false
	return true

func caminho(suporte: int, celula: Vector2i) -> Array[Vector2i]:
	var rota: Array[Vector2i] = jogo.rotas.sair_suporte(suporte,celula)
	if rota.any(func(c): return not is_zero_approx(jogo.planta.altura(c)) or jogo.planta.em(c).get("tipo","")=="escada"): return []
	return rota

func escolher(suporte: int) -> Vector2i:
	if revisao_candidatos!=jogo.planta.revisao:
		revisao_candidatos = jogo.planta.revisao
		candidatos.clear()
	if candidatos.has(suporte) and livre(candidatos[suporte]): return candidatos[suporte]
	var estacao: Dictionary = jogo.planta.objetos.get(suporte,{})
	if estacao.is_empty(): return Vector2i(-1,-1)
	var sala: Dictionary = jogo.ambientes.do_objeto(suporte)
	var melhor := Vector2i(-1,-1)
	var nota := -INF
	for y in GradePlex.TAMANHO.y:
		for x in GradePlex.TAMANHO.x:
			var c := Vector2i(x,y)
			if not livre(c) or jogo.planta.interacoes(suporte).has(c): continue
			if not sala.get("celulas",{}).has(c) or (not sala.get("fechada",false) and Vector2(c).distance_to(Vector2(estacao.celula))>7): continue
			var paredes := 0
			var perto_porta := false
			for d in GradePlex.VIZINHOS:
				var tipo: String = jogo.planta.em(c+d).get("tipo","")
				if tipo=="parede" or not GradePlex.dentro(c+d): paredes+=1
				if tipo in CatalogoPlex.PORTAS: perto_porta=true
			if perto_porta: continue
			var atual := paredes*100.0-Vector2(c).distance_to(Vector2(estacao.celula))
			if atual<=nota or caminho(suporte,c).is_empty(): continue
			nota = atual
			melhor = c
	candidatos[suporte] = melhor
	return melhor

func reservar(suporte: int, modelo: String, pedido: int) -> int:
	var c := escolher(suporte)
	if not GradePlex.dentro(c): return -1
	var id: int = jogo.planta.colocar("pose_quebrado" if CatalogoMontagemPlex.quebrado(modelo) else "pose_montagem",c,jogo.planta.objetos[suporte].rotacao)
	if id<0: return -1
	var marca: Dictionary = jogo.planta.objetos[id]
	marca.suporte_origem = suporte
	marca.modelo_alvo = modelo
	marca.pedido_endo = pedido
	marca.dono = -1
	marca.confirmado = false
	return id

func mover(id: int, celula: Vector2i, rotacao: int) -> bool:
	var marca: Dictionary = jogo.planta.objetos.get(id,{})
	if marca.get("tipo","") not in ["pose_quebrado","pose_montagem"] or not livre(celula,id):
		jogo.painel.mensagem("Escolha um tile livre no chão ou em um palco acessível.")
		return false
	var origem: int = marca.get("suporte_origem",-1)
	var ator: PersonagemPlex
	for a in jogo.personagens:
		if a.identificador==marca.get("dono",-1): ator=a
	var rota: Array[Vector2i] = jogo.rotas.caminho(ator.origem_rota(),celula) if ator!=null and ator.suporte<0 else jogo.rotas.sair_suporte(origem,celula)
	if rota.is_empty() or (marca.tipo=="pose_quebrado" and rota.any(func(c): return jogo.planta.altura(c)>0)):
		jogo.painel.mensagem("O destino precisa de caminho livre. Um palco precisa de escada conectada.")
		return false
	marca.celula = celula
	marca.rotacao = posmod(rotacao,4)
	marca.confirmado = true
	var suporte: Dictionary = jogo.planta.objetos.get(origem,{})
	if int(suporte.get("pedido_endo",-1))==int(marca.get("pedido_endo",-2)):
		suporte.destino_confirmado = true
	jogo.planta.alterada.emit()
	if ator!=null: jogo.poses.encaminhar(ator,id)
	jogo.escolher_ferramenta("selecionar")
	return true


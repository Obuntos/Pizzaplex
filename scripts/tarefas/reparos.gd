class_name ReparosPlex
extends RefCounted

static func ator(servico: ServicosPlex, id: int) -> PersonagemPlex:
	for a in servico.personagens:
		if a.identificador == id: return a
	return null

static func reparavel(a: PersonagemPlex) -> bool:
	return a.robo and a.pronto_para_destino()

static func danificado(a: PersonagemPlex) -> bool:
	return reparavel(a) and (float(a.robotica.get("desgaste",0.0)) > 0.001 or bool(a.robotica.get("avariado",false)))

static func desligado(a: PersonagemPlex) -> bool:
	return not a.ocupado() and not a.aguardando_saida and str(a.robotica.get("estado","desligado")) in ["desligado","avariado"]

static func pontos(servico: ServicosPlex, a: PersonagemPlex) -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	for d in GradePlex.VIZINHOS:
		var c: Vector2i = a.celula+d
		if not servico.planta.transitavel(c) or not is_equal_approx(servico.planta.altura(c),servico.planta.altura(a.celula)): continue
		if servico.planta.em(c).get("tipo","") in ["porta","porta_dupla","escada"]: continue
		if servico.personagens.any(func(outro): return outro != a and outro.robo and outro.celula == c): continue
		resultado.append(c)
	return resultado

static func iniciar(servico: ServicosPlex, mecanico: PersonagemPlex) -> bool:
	if not EquipePlex.permite(mecanico,"manutencao") or mecanico.carga_item>=0 or servico.trabalhos.has(mecanico.identificador) or servico.montagem.trabalhos.has(mecanico.identificador): return false
	for a in servico.personagens:
		if a.robo: AnimatronicosPlex.garantir(a)
	var robos: Array = servico.personagens.filter(func(a): return danificado(a) and desligado(a) and int(a.robotica.get("reparo_por",0)) == 0)
	robos.sort_custom(func(a,b): return float(a.robotica.get("desgaste",0.0)) > float(b.robotica.get("desgaste",0.0)))
	var caixas := servico.inventario.pecas_oficina()
	caixas.sort_custom(func(a,b): return int(a.get("durabilidade",100)) > int(b.get("durabilidade",100)))
	for robo in robos:
		if pontos(servico,robo).is_empty(): continue
		for caixa in caixas:
			var passo := servico.etapa(caixa.id,"reparar",8.0,{"robo":robo.identificador,"caixa":caixa.id})
			if not servico.iniciar(mecanico,"Reparar animatrônico",[servico.etapa(caixa.id,"pegar"),passo],[caixa.id]): continue
			robo.robotica.reparo_por = mecanico.identificador
			return true
	return false

static func alvo(servico: ServicosPlex, passo: Dictionary) -> PersonagemPlex:
	return ator(servico,int(passo.dados.get("robo",-1)))

static func valido(servico: ServicosPlex, mecanico: PersonagemPlex, trabalho: Dictionary) -> bool:
	if trabalho.get("tipo","") != "Reparar animatrônico": return true
	var passo: Dictionary = trabalho.passos[-1]
	var robo := alvo(servico,passo)
	return is_instance_valid(robo) and danificado(robo) and desligado(robo) and int(robo.robotica.get("reparo_por",0)) == mecanico.identificador and EquipePlex.permite(mecanico,"manutencao")

static func preparar(servico: ServicosPlex, mecanico: PersonagemPlex, passo: Dictionary) -> void:
	var caixa: Dictionary = servico.planta.objetos.get(int(passo.dados.caixa),{})
	if mecanico.carga_item == int(passo.dados.caixa) and not caixa.is_empty():
		mecanico.carga_item = -1
		mecanico.carregando = false
	mecanico.trabalho = "reparar"

static func concluir(servico: ServicosPlex, mecanico: PersonagemPlex, passo: Dictionary) -> bool:
	var robo := alvo(servico,passo)
	var id := int(passo.dados.caixa)
	var caixa: Dictionary = servico.planta.objetos.get(id,{})
	if not is_instance_valid(robo) or caixa.is_empty() or int(robo.robotica.get("reparo_por",0)) != mecanico.identificador or not desligado(robo): return false
	var qualidade: String = caixa.get("qualidade","media")
	if not AnimatronicosPlex.INCREMENTOS.has(qualidade): qualidade = "media"
	var normal := AnimatronicosPlex.base(robo.modelo)
	if not normal.is_empty() and normal != robo.modelo:
		robo.mudar_modelo(normal)
		var marca: Dictionary=servico.planta.objetos.get(robo.pose,{})
		if marca.get("tipo","")=="pose_quebrado":
			robo.pose=-1
			robo.trabalho=""
			if int(marca.get("dono",-1))==robo.identificador: servico.planta.remover(marca.id)
	robo.caixa_qualidade = qualidade
	robo.robotica.qualidade = qualidade
	robo.robotica.desgaste = 0.0
	robo.robotica.avariado = false
	robo.robotica.segundos_uso = 0.0
	robo.robotica.reparos = int(robo.robotica.get("reparos",0))+1
	robo.robotica.manutencao_solicitada = false
	AnimatronicosPlex.mudar(robo,"desligado")
	caixa.carregada_por = 0
	if not servico.inventario.consumir_caixa(id): return false
	if servico.planta.objetos.has(id):
		mecanico.carga_item = id
		servico.inventario.devolver(mecanico)
	return true

static func liberar(servico: ServicosPlex, mecanico: PersonagemPlex, trabalho: Dictionary) -> void:
	if trabalho.get("tipo","") != "Reparar animatrônico": return
	var passo: Dictionary = trabalho.passos[-1]
	var robo := alvo(servico,passo)
	if is_instance_valid(robo) and int(robo.robotica.get("reparo_por",0)) == mecanico.identificador: robo.robotica.reparo_por = 0
	var id := int(passo.dados.caixa)
	var caixa: Dictionary = servico.planta.objetos.get(id,{})
	if caixa.get("carregada_por",0) == mecanico.identificador:
		mecanico.carga_item = id
		servico.inventario.devolver(mecanico)

static func resumo(servico: ServicosPlex) -> String:
	var linhas: Array[String] = []
	var pecas := not servico.inventario.pecas_oficina().is_empty()
	for a in servico.personagens:
		if not danificado(a): continue
		var situacao := "Em reparo" if int(a.robotica.get("reparo_por",0)) > 0 else "Aguardando desligar" if not desligado(a) else "Aguardando mecânico" if pecas else "Aguardando peças"
		linhas.append(IdentidadesPlex.completo(a)+" · "+str(roundi(float(a.robotica.get("desgaste",0.0))*50))+"% · "+situacao)
	return "Nenhum animatrônico precisa de reparo." if linhas.is_empty() else "\n".join(linhas)

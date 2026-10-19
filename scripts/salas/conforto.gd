class_name ConfortoPlex
extends RefCounted

var jogo: Node
var notas: Dictionary = {}
var espera := 1.0
var ultima_revisao := -1

func _init(cena: Node) -> void:
	jogo = cena

static func catalogar(objetos: Dictionary) -> void:
	for tipo in objetos:
		var item: Dictionary = objetos[tipo]
		if not item.has("conforto"): item.conforto = 7 if tipo in ["cadeira","mesa","mesa_longa","mesa_longa_arredondada","banco_espera"] else 8 if tipo in ["geladeira","forno","maquina_fliperama"] else 6
		if not item.has("preco"): item.preco = 10 if CatalogoPlex.base(tipo)=="parede" else 35 if CatalogoPlex.base(tipo)=="cadeira" else 75 if LugaresPlex.mesa(tipo) else 180 if tipo in ["forno","geladeira","maquina_fliperama"] else 45
		if tipo in ["pose","luz_chao"]: item.preco = 15

static func titulo(nota: float) -> String:
	var n := clampi(roundi(nota),1,10)
	return ["Péssimo","Muito ruim","Ruim","Precário","Regular","Razoável","Bom","Muito bom","Excelente","Perfeito"][n-1]

static func robo(ator: PersonagemPlex) -> int:
	if CatalogoMontagemPlex.quebrado(ator.modelo) or ator.robotica.get("avariado",false): return 1
	var qualidade := str(ator.robotica.get("qualidade",ator.caixa_qualidade))
	var base: float = {"media":5.0,"boa":8.0,"otima":10.0,"perfeita":10.0}.get(qualidade,8.0)
	return clampi(roundi(base - float(ator.robotica.get("desgaste",0.0))*4.5),1,10)

func calcular(sala: Dictionary) -> Dictionary:
	if sala.is_empty() or not sala.get("fechada",false): return {"nota":1.0,"titulo":"Área externa","itens":0,"sujeira":0,"robos":0}
	var soma := 0.0
	var peso := 0.0
	var itens := 0
	var sujeira := 0
	for id in sala.get("objetos",[]):
		var item: Dictionary = jogo.planta.objetos.get(id,{})
		if item.is_empty() or item.get("carregada_por",0)>0: continue
		var info := MobiliaPlex.dados(item)
		if info.get("entulho",false) or item.tipo in ["mancha_chao","bebida_derramada"] or (item.tipo=="prato" and item.get("sujo",false)):
			sujeira += 1
			continue
		if item.tipo.begins_with("caixa") or item.get("sobre",-1)>=0 or item.tipo in ["pose","pose_quebrado","vassoura","balde"]: continue
		var p := 2.0 if item.tipo in ["cadeira","mesa","mesa_longa","mesa_longa_arredondada"] else 1.0
		soma += MobiliaPlex.nota(item)*p
		peso += p
		itens += 1
	var piso_total := 0.0
	for c in sala.celulas:
		piso_total += float(CatalogoPlex.objetos.get(jogo.planta.pisos.get(c,""),{}).get("conforto",4))
	if not sala.celulas.is_empty():
		soma += piso_total / sala.celulas.size() * 2.0
		peso += 2.0
	var robos := 0
	for ator in jogo.personagens:
		if ator.robo and sala.celulas.has(ator.celula):
			soma += robo(ator)*2.0
			peso += 2.0
			robos += 1
	var nota := clampf(soma / maxf(1.0,peso) - minf(3.0,sujeira*.4),1.0,10.0)
	return {"nota":snappedf(nota,.1),"titulo":titulo(nota),"itens":itens,"sujeira":sujeira,"robos":robos}

func em(celula: Vector2i) -> Dictionary:
	var sala: Dictionary = jogo.ambientes.em(celula)
	return notas[sala.id] if notas.has(sala.get("id",-1)) else calcular(sala)

func atualizar(delta: float) -> void:
	espera += delta
	if espera < 2.0 and ultima_revisao == jogo.planta.revisao: return
	var tempo := minf(2.0,espera)
	espera = 0.0
	ultima_revisao = jogo.planta.revisao
	jogo.ambientes.atualizar()
	notas.clear()
	for sala in jogo.ambientes.ambientes:
		if sala.fechada: notas[sala.id] = calcular(sala)
	for ator in jogo.personagens:
		if ator.cargo not in ["cliente","crianca","adolescente"]: continue
		var info := em(ator.celula)
		if info.titulo == "Área externa": continue
		ator.visita.conforto = info.nota
		ator.visita.satisfacao = clampf(float(ator.visita.get("satisfacao",70.0)) + (float(info.nota)-5.0)*tempo*.035,0.0,100.0)

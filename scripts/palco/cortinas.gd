class_name CortinasPalcoPlex
extends RefCounted

var jogo: Node
var espera := 0.0
var ligacoes: Dictionary = {}
var fases: Dictionary = {}
var assinatura := 0

func _init(cena: Node) -> void:
	jogo = cena

func vincular() -> void:
	jogo.animatronicos.palcos.atualizar()
	var cortinas: Array = jogo.planta.objetos.values().filter(func(o): return CatalogoPlex.objetos[o.tipo].get("cortina", false))
	var atual := hash([jogo.animatronicos.palcos.assinatura, cortinas.map(func(o): return [o.id, o.celula, o.rotacao])])
	if atual == assinatura: return
	assinatura = atual
	ligacoes.clear()
	for o in cortinas:
		var frente := GradePlex.frente(o.rotacao)
		for c in jogo.planta.celulas(o.tipo, o.celula, o.rotacao):
			for distancia in range(7):
				var palco := int(jogo.animatronicos.palcos.grupos.get(c - frente * distancia, -1))
				if palco >= 0:
					ligacoes[o.id] = palco
					break
			if ligacoes.has(o.id): break
	for id in fases.keys():
		if not jogo.planta.objetos.has(id): fases.erase(id)

func atualizar(delta: float) -> void:
	espera += delta
	if espera < .1: return
	var tempo := espera
	espera = 0.0
	vincular()
	var palcos: Dictionary = {}
	for a in jogo.personagens:
		if not a.robo: continue
		var palco: int = jogo.animatronicos.palcos.da_pose(a.pose)
		if palco < 0: continue
		if not palcos.has(palco): palcos[palco] = []
		palcos[palco].append(a)
	for id in ligacoes:
		var item: Dictionary = jogo.planta.objetos.get(id, {})
		if item.is_empty(): continue
		var robos: Array = palcos.get(ligacoes[id], [])
		var abrir := not robos.is_empty() and robos.all(func(a): return not a.ocupado() and a.trabalho == "apresentar" and a.robotica.get("estado", "") == "ligado" and not a.robotica.get("avariado", false) and not AnimatronicosPlex.pausado(a))
		var inicial := float(str(item.estado).trim_prefix("abertura_").to_int()) / 8.0
		var fase := move_toward(float(fases.get(id, inicial)), 1.0 if abrir else 0.0, tempo / 1.6)
		fases[id] = fase
		item.estado = "abertura_" + str(clampi(roundi(fase * 8), 0, 8))

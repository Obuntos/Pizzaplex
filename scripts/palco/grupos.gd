class_name PalcosPlex
extends RefCounted

var planta: PlantaPlex
var grupos: Dictionary = {}
var assinatura := -1
var sujo := true

func _init(p: PlantaPlex) -> void:
	planta = p
	planta.alterada.connect(invalidar)

func invalidar() -> void:
	sujo = true

func atualizar() -> void:
	if not sujo: return
	sujo = false
	var blocos: Dictionary = {}
	for item in planta.objetos.values():
		if EscadasPlex.palco(item):
			for c in planta.celulas(item.tipo,item.celula,item.rotacao): blocos[c] = item.id
	var nova := hash(blocos)
	if nova == assinatura: return
	assinatura = nova
	grupos.clear()
	for inicio in blocos:
		if grupos.has(inicio): continue
		var fila: Array[Vector2i] = [inicio]
		var indice := 0
		var id: int = blocos[inicio]
		grupos[inicio] = id
		while indice < fila.size():
			var c := fila[indice]
			indice += 1
			for d in GradePlex.VIZINHOS:
				var vizinha: Vector2i = c+d
				if blocos.has(vizinha) and not grupos.has(vizinha):
					grupos[vizinha] = id
					fila.append(vizinha)

func da_pose(pose: int) -> int:
	atualizar()
	var marca: Dictionary = planta.objetos.get(pose,{})
	return int(grupos.get(marca.get("celula",Vector2i(-1,-1)),-1)) if marca.get("tipo","") == "pose" else -1


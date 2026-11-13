class_name RecorteParedesPlex
extends RefCounted

const ESTRUTURA = SalasPlex.ESTRUTURA
var niveis: Dictionary = {}

func eh(item: Dictionary) -> bool:
	var tipo := str(item.get("tipo", ""))
	return tipo in ESTRUTURA or CatalogoPlex.base(tipo)=="parede" and bool(CatalogoPlex.objetos.get(tipo,{}).get("estrutura",false))

func estrutura(planta: PlantaPlex, celula: Vector2i) -> bool:
	return eh(planta.em(celula))

func tem_atras(planta: PlantaPlex, celula: Vector2i, direcao: Vector2i, id: int) -> bool:
	var orientada := Vector2i(GradePlex.girar(Vector2(direcao), -GradePlex.visao))
	var ponto := celula - orientada
	while GradePlex.dentro(ponto):
		var outro := planta.em(ponto)
		if eh(outro) and outro.id != id:
			return true
		ponto -= orientada
	return false

func calcular(planta: PlantaPlex, nivel: int, automatico: bool) -> void:
	niveis.clear()
	if not automatico:
		for item in planta.objetos.values():
			if item.tipo in ESTRUTURA: niveis[item.id]=4
		return
	if nivel == 1: return
	var vistos:Dictionary={};var pequenos:Dictionary={}
	for inicio in planta.objetos.values():
		if inicio.tipo not in ESTRUTURA or vistos.has(inicio.id):continue
		var fila:Array=[inicio];var indice:=0;vistos[inicio.id]=true
		while indice<fila.size():
			var parte:Dictionary=fila[indice];indice+=1
			for c in planta.celulas(parte.tipo,parte.celula,parte.rotacao):
				for direcao in GradePlex.VIZINHOS:
					var vizinha:=planta.em(c+direcao)
					if vizinha.get("tipo","") in ESTRUTURA and not vistos.has(vizinha.id):vistos[vizinha.id]=true;fila.append(vizinha)
		if fila.size()<=3:
			for parte in fila:pequenos[parte.id]=true
	for item in planta.objetos.values():
		if item.tipo not in ESTRUTURA:
			continue
		if pequenos.has(item.id):niveis[item.id]=1;continue
		var fundo := false
		var ocupadas := planta.celulas(item.tipo, item.celula, item.rotacao)
		for celula in ocupadas:
			var eixo_x := estrutura(planta, celula + Vector2i(1, 0)) or estrutura(planta, celula - Vector2i(1, 0))
			var eixo_y := estrutura(planta, celula + Vector2i(0, 1)) or estrutura(planta, celula - Vector2i(0, 1))
			if item.tipo in CatalogoPlex.PORTAS:
				eixo_x = item.rotacao % 2 == 0
				eixo_y = not eixo_x
			if GradePlex.visao % 2 == 1:
				var anterior := eixo_x
				eixo_x = eixo_y
				eixo_y = anterior
			if eixo_x and not tem_atras(planta, celula, Vector2i(0, 1), item.id):
				fundo = true
			if eixo_y and not tem_atras(planta, celula, Vector2i(1, 0), item.id):
				fundo = true
			if not eixo_x and not eixo_y:
				fundo = false
		niveis[item.id] = nivel if fundo else 1
	var base: Dictionary=niveis.duplicate()
	for item in planta.objetos.values():
		if item.tipo not in ESTRUTURA or item.tipo in CatalogoPlex.PORTAS or pequenos.has(item.id): continue
		var lados: Dictionary={}
		for direcao in GradePlex.VIZINHOS:
			var outro := planta.em(item.celula+direcao)
			if outro.get("tipo","") in ESTRUTURA and outro.get("tipo","") not in CatalogoPlex.PORTAS and int(outro.id)!=int(item.id) and base.has(outro.id): lados[direcao]=int(base[outro.id])
		if lados.is_empty(): continue
		var maior: int=lados.values().max()
		if lados.size()==1 or maior<=1: niveis[item.id]=int(lados.values().min())
		elif lados.size()==2 and not lados.keys().any(func(d): return lados.has(-d)): niveis[item.id]=maior

func nivel_para(item: Dictionary, padrao: int) -> int:
	return int(niveis.get(item.id, padrao))



class_name SuperficiesPlex
extends RefCounted

static func codificar(normal: Vector3, neutra: bool = false) -> Color:
	return Color(normal.x * .5 + .5, normal.y * .5 + .5, normal.z * .5 + .5, 1.0 if neutra else .5)

static func normais_volume(pontos: PackedVector3Array) -> PackedColorArray:
	var resultado := PackedColorArray()
	var profundidades: Dictionary = {}
	for ponto in pontos:
		profundidades[Vector2i(int(ponto.x), int(ponto.y))] = ponto.z
	var gradientes := [Vector2(-1.5, -1), Vector2(1.5, -1), Vector2(0, 2)]
	var normais := [Vector3(.707107, .707107, 0), Vector3(-.707107, .707107, 0), Vector3(0, 0, 1)]
	var vizinhas := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]
	for ponto in pontos:
		var pixel := Vector2i(int(ponto.x), int(ponto.y))
		var melhor := 0
		var nota_melhor := -1.0
		for face in 3:
			var nota := 0.0
			for deslocamento in vizinhas:
				if not profundidades.has(pixel + deslocamento): continue
				var diferenca: float = profundidades[pixel + deslocamento] - ponto.z
				if absf(diferenca - gradientes[face].dot(Vector2(deslocamento))) < .2:
					nota += 1.0 / Vector2(deslocamento).length()
			if nota > nota_melhor:
				nota_melhor = nota
				melhor = face
		resultado.append(codificar(normais[melhor]))
	return resultado

static func porta(pontos: PackedVector3Array, cores: PackedColorArray, nivel: int) -> PackedColorArray:
	var resultado:=normais_volume(pontos)
	var altura: float=[6.0,22.0,52.0,104.0][clampi(nivel-1,0,3)]
	for i in pontos.size():
		var ponto:=pontos[i]
		var z: float=(ponto.z-ponto.y*2.0)/3.0
		var cor:=cores[i]
		var madeira: bool=cor.r>cor.g*1.04 and cor.g>cor.b*1.08
		if (nivel<4 and not madeira) or z>=altura-.7: resultado[i].a=1.0
	return resultado

static func parede(pontos: PackedVector3Array, nivel: int, ligacoes: int = 0) -> PackedColorArray:
	var resultado := PackedColorArray()
	var altura: float = [6.0, 22.0, 52.0, 104.0][clampi(nivel - 1, 0, 3)]
	for ponto in pontos:
		var z := (ponto.z - ponto.y * 2.0) / 3.0
		if z >= altura - .7:
			resultado.append(Color(.5, .5, 1, 1))
			continue
		var y := ponto.z - z
		var grade := Vector2((ponto.x + y) / 64.0, (y - ponto.x) / 64.0)
		var normal: Vector3
		var face_x := (ligacoes & (2 if grade.x >= 0 else 8)) == 0
		var face_y := (ligacoes & (4 if grade.y >= 0 else 1)) == 0
		if face_x and (not face_y or absf(absf(grade.x) - .5) <= absf(absf(grade.y) - .5)):
			var sinal := 1.0 if grade.x >= 0 else -1.0
			normal = Vector3(.707107, .707107, 0) * sinal
		else:
			var sinal := 1.0 if grade.y >= 0 else -1.0
			normal = Vector3(-.707107, .707107, 0) * sinal
		resultado.append(Color(normal.x * .5 + .5, normal.y * .5 + .5, normal.z * .5 + .5, .5))
	return resultado

static func cores_continuas(pontos: PackedVector3Array, cores: PackedColorArray, faces: PackedColorArray) -> PackedColorArray:
	var resultado := cores.duplicate()
	for i in pontos.size():
		if faces[i].a > .75: continue
		var cor := cores[i]
		var altura := (pontos[i].z - pontos[i].y * 2.0) / 3.0
		var pintura: bool = cor.r > .47 and cor.g > .47 and cor.b > .40 and absf(cor.r - cor.g) < .05 and cor.g - cor.b > .015 and cor.g - cor.b < .14
		if pintura and altura > 12.0 and altura < 100.0:
			var base := Color("a09d8f") if faces[i].r > .5 else Color("c8c3ae")
			base.a = cor.a
			resultado[i] = base
	return resultado


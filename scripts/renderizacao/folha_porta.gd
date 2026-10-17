class_name FolhaPortaPlex
extends RefCounted

static func ponto(local: Vector2, altura: float) -> Vector3:
	var tela := GradePlex.projetar_local(local, altura)
	return Vector3(tela.x, tela.y, (local.x + local.y) * 32.0 + altura)

static func face(vertices: Array[Vector3], cor: Color, pontos: PackedVector3Array, cores: PackedColorArray) -> void:
	for triangulo in [[0, 1, 2], [0, 2, 3]]:
		var a := vertices[triangulo[0]]
		var b := vertices[triangulo[1]]
		var c := vertices[triangulo[2]]
		var u := Vector2(b.x - a.x, b.y - a.y)
		var v := Vector2(c.x - a.x, c.y - a.y)
		var area := u.cross(v)
		if absf(area) < .001: continue
		for y in range(floori(minf(a.y, minf(b.y, c.y))), ceili(maxf(a.y, maxf(b.y, c.y)))):
			for x in range(floori(minf(a.x, minf(b.x, c.x))), ceili(maxf(a.x, maxf(b.x, c.x)))):
				var d := Vector2(x + .5 - a.x, y + .5 - a.y)
				var s := d.cross(v) / area
				var t := u.cross(d) / area
				if s >= -.001 and t >= -.001 and s + t <= 1.001:
					pontos.append(Vector3(x, y, a.z + (b.z - a.z) * s + (c.z - a.z) * t))
					cores.append(cor)

static func acrescentar(tipo: String, rotacao: int, pontos: PackedVector3Array, cores: PackedColorArray) -> void:
	var frente := Vector2(GradePlex.frente(rotacao))
	var lado := Vector2(frente.y, -frente.x)
	var largura := (2.0 if tipo == "porta_dupla" else 1.0) - .26
	var quantidade := 2 if tipo == "porta_dupla" else 1
	for i in quantidade:
		var minimo := -largura * .5 + largura * float(i) / quantidade + .008
		var maximo := -largura * .5 + largura * float(i + 1) / quantidade - .008
		var a := lado * minimo - frente * .045
		var b := lado * maximo - frente * .045
		var c := lado * maximo + frente * .045
		var d := lado * minimo + frente * .045
		face([ponto(a, 0), ponto(b, 0), ponto(b, 6), ponto(a, 6)], Color("a08257"), pontos, cores)
		face([ponto(b, 0), ponto(c, 0), ponto(c, 6), ponto(b, 6)], Color("8b714e"), pontos, cores)
		face([ponto(c, 0), ponto(d, 0), ponto(d, 6), ponto(c, 6)], Color("b49565"), pontos, cores)
		face([ponto(d, 0), ponto(a, 0), ponto(a, 6), ponto(d, 6)], Color("927750"), pontos, cores)
		face([ponto(a, 6), ponto(b, 6), ponto(c, 6), ponto(d, 6)], Color("bfa574"), pontos, cores)

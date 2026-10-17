class_name CenaPlex
extends Node2D

const ORIGEM = Vector2i(-864, -176)
const TAMANHO = Vector2i(1984, 1216)
const MATERIAL = preload("res://shaders/profundidade.gdshader")
var sprite := Sprite2D.new()
var imagem: Image
var mapa: Image
var textura: ImageTexture
var profundidade: ImageTexture
var assinatura: String = ""
var assinatura_portas: String = ""
var fundo: Image
var distancias := PackedFloat32Array()
var recorte := RecorteParedesPlex.new()
var mapa_superficies: Image
var superficies: ImageTexture
var fundo_superficies: Image

func _init() -> void:
	z_index = -1
	imagem = Image.create_empty(TAMANHO.x, TAMANHO.y, false, Image.FORMAT_RGBA8)
	mapa = Image.create_empty(TAMANHO.x, TAMANHO.y, false, Image.FORMAT_RF)
	mapa.fill(Color(-10000.0, 0.0, 0.0))
	textura = ImageTexture.create_from_image(imagem)
	profundidade = ImageTexture.create_from_image(mapa)
	mapa_superficies = Image.create_empty(TAMANHO.x, TAMANHO.y, false, Image.FORMAT_RGBA8)
	superficies = ImageTexture.create_from_image(mapa_superficies)
	sprite.centered = false
	sprite.position = Vector2(ORIGEM)
	sprite.texture = textura
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

func compor(volume: Dictionary, centro: Vector2, altura: float, buffer: PackedFloat32Array) -> void:
	var ponto := GradePlex.projetar(centro, altura)
	var base := Vector2i(ponto.round()) - ORIGEM
	var distancia: float = GradePlex.profundidade(centro, altura) + 2.0*(roundf(ponto.y)-ponto.y)
	var pontos: PackedVector3Array = volume.pontos
	var cores: PackedColorArray = volume.cores
	var faces: PackedColorArray = volume.get("superficies", PackedColorArray())
	for i in pontos.size():
		var local := pontos[i]
		var x: int = base.x + int(local.x)
		var y: int = base.y + int(local.y)
		if x < 0 or x >= TAMANHO.x or y < 0 or y >= TAMANHO.y:
			continue
		var indice: int = y * TAMANHO.x + x
		var valor: float = distancia + local.z
		if valor < buffer[indice] - 0.05:
			continue
		var cor := cores[i]
		if cor.a < 1.0:
			var anterior := imagem.get_pixel(x, y)
			if absf(valor - buffer[indice]) < 1.0 and absf(cor.r - anterior.r) + absf(cor.g - anterior.g) + absf(cor.b - anterior.b) < 0.04:
				cor.a = minf(1.0, cor.a + anterior.a)
			else:
				cor = anterior.blend(cor)
		buffer[indice] = maxf(buffer[indice], valor)
		imagem.set_pixel(x, y, cor)
		mapa_superficies.set_pixel(x, y, faces[i] if faces.size() == pontos.size() else Color(.5, .5, 1, 0))

func atualizar(planta: PlantaPlex, nivel: int, cortar_frente: bool = false) -> void:
	var estados := PackedStringArray([str(nivel), str(cortar_frente), str(GradePlex.visao)])
	var estados_portas := PackedStringArray()
	for registro in planta.objetos.values():
		if registro.tipo in ["luz_teto", "luz_parede", "luz_chao", "pose", "pose_quebrado"] or ApoiosPlex.portador(planta,registro.id) > 0:
			continue
		estados.append(str([registro.id, registro.tipo, registro.celula, registro.rotacao, registro.caixa, registro.get("ponto_caixa", []), registro.get("caixa_tipo","caixa"), registro.get("estado", ""), registro.get("sobre", -1), registro.get("slot", -1)]))
		if registro.tipo in ["porta", "porta_dupla"]:
			estados_portas.append(str([registro.id, registro.aberta]))
	var atual := "|".join(estados)
	var atuais_portas := "|".join(estados_portas)
	if assinatura == atual and assinatura_portas == atuais_portas:
		return
	recorte.calcular(planta, nivel, cortar_frente)
	var buffer := PackedFloat32Array()
	if assinatura != atual:
		assinatura = atual
		imagem.fill(Color.TRANSPARENT)
		mapa_superficies.fill(Color.TRANSPARENT)
		buffer.resize(TAMANHO.x * TAMANHO.y)
		buffer.fill(-10000.0)
		for registro in planta.objetos.values():
			if registro.tipo in ["porta", "porta_dupla", "luz_teto", "luz_parede", "luz_chao", "pose", "pose_quebrado"] or ApoiosPlex.portador(planta,registro.id) > 0:
				continue
			var posicao := ApoiosPlex.posicao(planta, registro)
			var centro := Vector2(posicao.x, posicao.y)
			compor(GeometriaPlex.objeto(registro, planta, recorte.nivel_para(registro, nivel), recorte.niveis), centro, posicao.z, buffer)
			if registro.tipo == "bancada" and registro.caixa:
				var caixa := planta.ponto_caixa(registro.id)
				compor(GeometriaPlex.obter(registro.get("caixa_tipo","caixa"), GradePlex.rotacao_visual(0), 4, 0, false, "aberta"), Vector2(caixa.x, caixa.y), caixa.z, buffer)
		fundo = imagem.duplicate() as Image
		fundo_superficies = mapa_superficies.duplicate() as Image
		distancias = buffer.duplicate()
	else:
		imagem = fundo.duplicate() as Image
		mapa_superficies = fundo_superficies.duplicate() as Image
		buffer = distancias.duplicate()
	assinatura_portas = atuais_portas
	for registro in planta.objetos.values():
		if registro.tipo not in ["porta", "porta_dupla"]:
			continue
		var dimensao := CatalogoPlex.dimensoes(registro.tipo, registro.rotacao)
		var centro := Vector2(registro.celula) + Vector2(dimensao - Vector2i.ONE) * 0.5
		compor(GeometriaPlex.objeto(registro, planta, recorte.nivel_para(registro, nivel), recorte.niveis), centro, 0.0, buffer)
	conectar_topos(planta, nivel, buffer)
	mapa = Image.create_from_data(TAMANHO.x, TAMANHO.y, false, Image.FORMAT_RF, buffer.to_byte_array())
	textura.update(imagem)
	profundidade.update(mapa)
	superficies.update(mapa_superficies)

func conectar_topos(planta: PlantaPlex, nivel: int, buffer: PackedFloat32Array) -> void:
	var tipos: Array[String] = ["parede", "porta", "porta_dupla"]
	for celula in planta.ocupacao:
		var primeiro := planta.em(celula)
		if primeiro.tipo not in tipos:
			continue
		for deslocamento in [Vector2i(1, 0), Vector2i(0, 1)]:
			var segundo := planta.em(celula + deslocamento)
			if segundo.get("tipo", "") not in tipos or primeiro.id == segundo.id:
				continue
			var nivel_local := recorte.nivel_para(primeiro, nivel)
			if nivel_local != recorte.nivel_para(segundo, nivel):
				continue
			var altura: float = [6.0, 22.0, 52.0, 104.0][nivel_local - 1]
			var continua: bool = true
			if nivel_local < 4:
				for item in [primeiro, segundo]:
					if item.tipo != "parede" and Vector2(deslocamento).dot(Vector2(GradePlex.frente(item.rotacao))) != 0.0:
						continua = false
			if not continua:
				continue
			var centro := Vector2(celula) + Vector2(deslocamento) * 0.5
			var lado := Vector2(deslocamento.y, -deslocamento.x) * 0.5
			var a := GradePlex.projetar(centro - lado, altura) - Vector2(ORIGEM)
			var b := GradePlex.projetar(centro + lado, altura) - Vector2(ORIGEM)
			var segmento := b - a
			for y in range(floori(minf(a.y, b.y)) - 1, ceili(maxf(a.y, b.y)) + 2):
				for x in range(floori(minf(a.x, b.x)) - 1, ceili(maxf(a.x, b.x)) + 2):
					if x < 0 or y < 0 or x >= TAMANHO.x or y >= TAMANHO.y:
						continue
					var ponto := Vector2(x + 0.5, y + 0.5)
					var t: float = (ponto - a).dot(segmento) / segmento.length_squared()
					if t < 0.025 or t > 0.975 or ponto.distance_squared_to(a + segmento * t) > 0.64:
						continue
					var indice: int = y * TAMANHO.x + x
					var distancia: float = (ponto.y + ORIGEM.y) * 2.0 + altura * 3.0
					if distancia >= buffer[indice] - 1.25:
						buffer[indice] = maxf(buffer[indice], distancia)
						imagem.set_pixel(x, y, Color("818783"))
						mapa_superficies.set_pixel(x, y, Color(.5, .5, 1, 1))

func vincular(personagem: PersonagemPlex) -> void:
	var material_novo := ShaderMaterial.new()
	material_novo.shader = MATERIAL
	material_novo.set_shader_parameter("profundidade", profundidade)
	material_novo.set_shader_parameter("origem", Vector2(ORIGEM))
	material_novo.set_shader_parameter("tamanho", Vector2(TAMANHO))
	personagem.material = material_novo
	personagem.visual.use_parent_material = true
	personagem.animacao.use_parent_material = true
	personagem.carga.use_parent_material = true

func osso(ponto: Vector3) -> Vector4:
	var tela := GradePlex.projetar(Vector2(ponto.x, ponto.y), ponto.z)
	return Vector4(tela.x, tela.y, GradePlex.profundidade(Vector2(ponto.x, ponto.y), ponto.z), 0.0)

func local_osso(personagem: PersonagemPlex, ponto: Vector3) -> Vector3:
	var angulo: float = personagem.direcao * PI / 4.0
	var escala: Vector2 = personagem.animacao.scale
	var x: float = (cos(angulo) * ponto.x + sin(angulo) * ponto.y) * escala.x
	var y: float = (-sin(angulo) * ponto.x + cos(angulo) * ponto.y) * 0.5 * escala.y
	var local := personagem.local + GradePlex.inverter_local(Vector2(x, y))
	return Vector3(local.x, local.y, personagem.altura + ponto.z * escala.y)

func joelho(inicio: Vector3, fim: Vector3, superior: float, inferior: float) -> Vector3:
	var diferenca := fim - inicio
	var eixo := diferenca.normalized()
	var distancia := clampf(diferenca.length(), 0.001, superior + inferior - 0.001)
	var avanco: float = (superior * superior - inferior * inferior + distancia * distancia) / (2.0 * distancia)
	var altura: float = sqrt(maxf(0.0, superior * superior - avanco * avanco))
	var normal := Vector3(-eixo.x * eixo.y, 1.0 - eixo.y * eixo.y, -eixo.z * eixo.y).normalized()
	return inicio + eixo * avanco + normal * altura

func atualizar_personagem(personagem: PersonagemPlex) -> void:
	var material_atual := personagem.material as ShaderMaterial
	if material_atual == null:
		vincular(personagem)
		material_atual = personagem.material
	material_atual.set_shader_parameter("normal_automatica",personagem.robo and personagem.modelo not in ["endo","coelho","ovelha","raposa"])
	material_atual.set_shader_parameter("quadro_nativo",Vector2(personagem.animacao.definicao.width,personagem.animacao.definicao.height))
	var ponto_visual := personagem.ponto_visual()
	material_atual.set_shader_parameter("plano", GradePlex.projetar(Vector2(ponto_visual.x, ponto_visual.y)).y * 3.0)
	var cabeca: float = 49.0 if personagem.robo or personagem.modelo.begins_with("fantasia_") else 33.0 if personagem.modelo == "crianca" else 29.0
	var pivo: float = personagem.animacao.definicao.pivot[1]
	material_atual.set_shader_parameter("inicio_cabeca", ponto_visual.z + (pivo - cabeca) * personagem.animacao.scale.y)
	var pernas := PackedVector4Array()
	if personagem.em_degraus and personagem.movimento.escala.pes.size() == 2:
		var angulo: float = personagem.direcao * PI / 4.0
		var escala: Vector2 = personagem.animacao.scale
		var abertura: float = (3.0 if personagem.modelo == "endo" else 2.65) if personagem.robo else 2.45
		var quadril: float = 24.9 if personagem.robo else 15.2
		for i in 2:
			var pe: Vector3 = personagem.movimento.escala.pes[i]
			var diferenca := GradePlex.projetar_local(Vector2(pe.x, pe.y) - personagem.local)
			var x: float = diferenca.x / escala.x
			var y: float = diferenca.y * 2.0 / escala.y
			var destino := Vector3(cos(angulo) * x - sin(angulo) * y, sin(angulo) * x + cos(angulo) * y - (0.0 if personagem.robo else 0.7), (pe.z - personagem.altura) / escala.y + (1.8 if personagem.robo else 1.775))
			var inicio := Vector3((-1 if i == 0 else 1) * abertura, 1.4 if personagem.robo else 0.0, quadril)
			var meio := joelho(inicio, destino, 11.95 if personagem.robo else 7.15, 11.95 if personagem.robo else 6.75)
			pernas.append(osso(local_osso(personagem, inicio)))
			pernas.append(osso(local_osso(personagem, meio)))
			pernas.append(osso(pe))
	if PosturaPlex.sentada(personagem): pernas = PosturaPlex.ossos(personagem)
	while pernas.size() < 6:
		pernas.append(Vector4(-10000, -10000, 0, 0))
	material_atual.set_shader_parameter("pernas", pernas)
	material_atual.set_shader_parameter("raio", 3.8 if personagem.robo else 3.5)
	material_atual.set_shader_parameter("em_escada", personagem.em_degraus or PosturaPlex.sentada(personagem))

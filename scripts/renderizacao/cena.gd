class_name CenaPlex
extends Node2D

const ORIGEM = Vector2i(-1632, -176)
const TAMANHO = Vector2i(3776, 2176)
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
var buffer_atual := PackedFloat32Array()
var anteriores: Dictionary = {}
var regiao := Rect2i(Vector2i.ZERO, TAMANHO)
var fixos_anteriores: Dictionary = {}
var contexto_fundo := ""

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
		if x < 0 or x >= TAMANHO.x or y < 0 or y >= TAMANHO.y or not regiao.has_point(Vector2i(x,y)):
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

func dinamico(registro: Dictionary) -> bool:
	return registro.tipo in CatalogoPlex.PORTAS or registro.tipo.begins_with("caixa") or registro.get("sobre",-1)>=0 or CatalogoPlex.objetos[registro.tipo].get("estados",[]).size()>1

func desenho(registro: Dictionary, planta: PlantaPlex, nivel: int) -> Dictionary:
	var p := ApoiosPlex.posicao(planta,registro)
	var volume := GeometriaPlex.objeto(registro,planta,recorte.nivel_para(registro,nivel),recorte.niveis)
	var origem := Vector2i(GradePlex.projetar(Vector2(p.x,p.y),p.z).round())-ORIGEM
	var limites := Rect2i(origem+Vector2i(volume.origin[0],volume.origin[1]),volume.textura.get_size())
	return {"id":registro.id,"volume":volume,"posicao":Vector2(p.x,p.y),"altura":p.z,"limites":limites,"chave":hash([registro.tipo,registro.get("variante",""),MobiliaPlex.estado(registro),registro.rotacao,FachadaPlex.estado(planta,registro),registro.get("aberta",false),p,nivel,recorte.nivel_para(registro,nivel),GeometriaPlex.mascara(registro,planta,recorte.niveis),GradePlex.visao])}

func unir(a: Rect2i, b: Rect2i) -> Rect2i:
	if not b.has_area(): return a
	return a.merge(b) if a.has_area() else b

func alteracoes(desenhos: Array, anteriores_base: Dictionary) -> Dictionary:
	var atuais: Dictionary = {}
	var area := Rect2i()
	for d in desenhos:
		atuais[d.id] = {"chave":d.chave,"limites":d.limites}
		if not anteriores_base.has(d.id) or anteriores_base[d.id].chave != d.chave:
			area = unir(area,d.limites)
			if anteriores_base.has(d.id): area=unir(area,anteriores_base[d.id].limites)
	for id in anteriores_base:
		if not atuais.has(id): area=unir(area,anteriores_base[id].limites)
	return {"registros":atuais,"area":area}

func atualizar_fundo(desenhos: Array, area: Rect2i, planta: PlantaPlex, nivel: int) -> void:
	regiao=area.grow(2).intersection(Rect2i(Vector2i.ZERO,TAMANHO))
	if not regiao.has_area(): return
	var final_imagem:=imagem
	var final_superficies:=mapa_superficies
	imagem=fundo
	mapa_superficies=fundo_superficies
	imagem.fill_rect(regiao,Color.TRANSPARENT)
	mapa_superficies.fill_rect(regiao,Color.TRANSPARENT)
	for y in range(regiao.position.y,regiao.end.y):
		for x in range(regiao.position.x,regiao.end.x): distancias[y*TAMANHO.x+x]=-10000.0
	for d in desenhos:
		if d.limites.intersects(regiao): compor(d.volume,d.posicao,d.altura,distancias)
	conectar_topos(planta,nivel,distancias)
	imagem=final_imagem
	mapa_superficies=final_superficies

func atualizar(planta: PlantaPlex, nivel: int, cortar_frente: bool = false) -> void:
	var fixos: Array=[]
	var moveis: Array=[]
	var estados: Array=[nivel,cortar_frente,GradePlex.visao]
	var variacoes: Array=[]
	for registro in planta.objetos.values():
		if registro.tipo in ["luz_teto","luz_parede","luz_chao","pose","pose_quebrado"] or ApoiosPlex.portador(planta,registro.id)>0: continue
		var dados: Array=[registro.id,registro.tipo,registro.celula,registro.rotacao,registro.get("estado",""),registro.get("sobre",-1),registro.get("slot",-1),registro.get("variante",""),MobiliaPlex.estado(registro)]
		if registro.tipo in SalasPlex.ESTRUTURA: estados.append(dados.slice(0,4))
		if dinamico(registro):
			moveis.append(registro)
			variacoes.append(dados+[registro.get("aberta",false)])
		else:
			fixos.append(registro)
			estados.append(dados)
		if registro.tipo=="bancada" and registro.caixa: variacoes.append([registro.id,registro.get("caixa_tipo","caixa"),registro.get("ponto_caixa",[])])
	var atual:=str(hash(estados))
	var atual_moveis:=str(hash(variacoes))
	if assinatura==atual and assinatura_portas==atual_moveis: return
	var contexto:=str(hash([nivel,cortar_frente,GradePlex.visao]))
	var completa:=fundo==null or contexto_fundo!=contexto or assinatura.is_empty()
	var mudou_fundo:=assinatura!=atual or completa
	var estatica:=Rect2i()
	if mudou_fundo:
		recorte.calcular(planta,nivel,cortar_frente)
		var desenhos_fixos: Array=[]
		for r in fixos: desenhos_fixos.append(desenho(r,planta,nivel))
		var diferenca:=alteracoes(desenhos_fixos,fixos_anteriores)
		fixos_anteriores=diferenca.registros
		estatica=diferenca.area
		if completa:
			regiao=Rect2i(Vector2i.ZERO,TAMANHO)
			imagem.fill(Color.TRANSPARENT)
			mapa_superficies.fill(Color.TRANSPARENT)
			buffer_atual.resize(TAMANHO.x*TAMANHO.y)
			buffer_atual.fill(-10000.0)
			for d in desenhos_fixos: compor(d.volume,d.posicao,d.altura,buffer_atual)
			conectar_topos(planta,nivel,buffer_atual)
			fundo=imagem.duplicate() as Image
			fundo_superficies=mapa_superficies.duplicate() as Image
			distancias=buffer_atual.duplicate()
			anteriores.clear()
		elif estatica.has_area(): atualizar_fundo(desenhos_fixos,estatica,planta,nivel)
		contexto_fundo=contexto
	var desenhos: Array=[]
	for r in moveis: desenhos.append(desenho(r,planta,nivel))
	for registro in fixos+moveis:
		if registro.tipo=="bancada" and registro.caixa:
			var p:=planta.ponto_caixa(registro.id)
			var v:=GeometriaPlex.obter(registro.get("caixa_tipo","caixa"),GradePlex.rotacao_visual(0),4,0,false,"aberta")
			var base:=Vector2i(GradePlex.projetar(Vector2(p.x,p.y),p.z).round())-ORIGEM
			desenhos.append({"id":-registro.id,"volume":v,"posicao":Vector2(p.x,p.y),"altura":p.z,"limites":Rect2i(base+Vector2i(v.origin[0],v.origin[1]),v.textura.get_size()),"chave":hash([p,registro.get("caixa_tipo","caixa")])})
	var diferenca:=alteracoes(desenhos,anteriores)
	anteriores=diferenca.registros
	assinatura=atual
	assinatura_portas=atual_moveis
	if completa: regiao=Rect2i(Vector2i.ZERO,TAMANHO)
	else:
		regiao=unir(estatica,diferenca.area).grow(3).intersection(Rect2i(Vector2i.ZERO,TAMANHO))
		if not regiao.has_area(): return
		imagem.blit_rect(fundo,regiao,regiao.position)
		mapa_superficies.blit_rect(fundo_superficies,regiao,regiao.position)
		for y in range(regiao.position.y,regiao.end.y):
			for x in range(regiao.position.x,regiao.end.x): buffer_atual[y*TAMANHO.x+x]=distancias[y*TAMANHO.x+x]
	for d in desenhos:
		if d.limites.intersects(regiao): compor(d.volume,d.posicao,d.altura,buffer_atual)
	if completa: mapa=Image.create_from_data(TAMANHO.x,TAMANHO.y,false,Image.FORMAT_RF,buffer_atual.to_byte_array())
	else:
		for y in range(regiao.position.y,regiao.end.y):
			for x in range(regiao.position.x,regiao.end.x): mapa.set_pixel(x,y,Color(buffer_atual[y*TAMANHO.x+x],0,0))
	textura.update(imagem)
	profundidade.update(mapa)
	superficies.update(mapa_superficies)

func conectar_topos(planta: PlantaPlex, nivel: int, buffer: PackedFloat32Array) -> void:
	var tipos: Array = SalasPlex.ESTRUTURA
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
					if CatalogoPlex.base(item.tipo) != "parede" and Vector2(deslocamento).dot(Vector2(GradePlex.frente(item.rotacao))) != 0.0:
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
					if x < 0 or y < 0 or x >= TAMANHO.x or y >= TAMANHO.y or not regiao.has_point(Vector2i(x,y)):
						continue
					var ponto := Vector2(x + 0.5, y + 0.5)
					var t: float = (ponto - a).dot(segmento) / segmento.length_squared()
					if t < 0.025 or t > 0.975 or ponto.distance_squared_to(a + segmento * t) > 0.64:
						continue
					var indice: int = y * TAMANHO.x + x
					var distancia: float = (ponto.y + ORIGEM.y) * 2.0 + altura * 3.0
					if distancia >= buffer[indice] - 1.25:
						buffer[indice] = maxf(buffer[indice], distancia)
						imagem.set_pixel(x, y, Color("ded9c5") if nivel_local<4 and MobiliaPlex.dados(primeiro).get("mobilia",false) else Color("818783"))
						mapa_superficies.set_pixel(x, y, Color(.5, .5, 1, .5 if MobiliaPlex.dados(primeiro).get("mobilia",false) else 1.0))

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
	var atlas: AtlasTexture=personagem.animacao.atlases.get("modelo",null)
	var fonte: Texture2D=atlas.atlas if atlas!=null else null
	var possui_normal: bool=fonte is CanvasTexture and fonte.normal_texture!=null and fonte.normal_texture.get_size()==fonte.diffuse_texture.get_size()
	material_atual.set_shader_parameter("normal_automatica",personagem.robo and not possui_normal)
	material_atual.set_shader_parameter("desgaste_plex",float(personagem.robotica.get("desgaste",0.0))*.5 if personagem.robo and AnimatronicosPlex.base(personagem.modelo).is_empty() and not CatalogoMontagemPlex.quebrado(personagem.modelo) else 0.0)
	material_atual.set_shader_parameter("quadro_nativo",Vector2(personagem.animacao.definicao.width,personagem.animacao.definicao.height))
	var ponto_visual := personagem.ponto_visual()
	material_atual.set_shader_parameter("plano", GradePlex.projetar(Vector2(ponto_visual.x, ponto_visual.y)).y * 3.0)
	material_atual.set_shader_parameter("apoiar_solas", not personagem.em_degraus and (personagem.assento<0 or PosturaPlex.sentada(personagem)))
	material_atual.set_shader_parameter("apoiar_degraus", personagem.em_degraus)
	material_atual.set_shader_parameter("altura_apoio", personagem.altura if PosturaPlex.sentada(personagem) else ponto_visual.z)
	var cabeca: float = 49.0 if personagem.robo or personagem.modelo.begins_with("fantasia_") else 33.0 if personagem.modelo == "crianca" else 29.0
	if personagem.robo: cabeca=float(ClipesPlex.modelos.get(personagem.modelo,{}).get("cabeca_y",cabeca))
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
			var sola := osso(pe)
			sola.w = pe.z
			pernas.append(sola)
	if PosturaPlex.sentada(personagem): pernas = PosturaPlex.ossos(personagem)
	while pernas.size() < 6:
		pernas.append(Vector4(-10000, -10000, 0, 0))
	material_atual.set_shader_parameter("pernas", pernas)
	material_atual.set_shader_parameter("raio", (3.8 if personagem.robo else 3.5)*personagem.animacao.scale.x/1.25)
	material_atual.set_shader_parameter("em_escada", personagem.em_degraus or PosturaPlex.sentada(personagem))


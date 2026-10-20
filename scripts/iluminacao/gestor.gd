class_name IluminacaoPlex
extends RefCounted

const LIMITE = 32
var planta: PlantaPlex
var materiais: Array[WeakRef] = []
var posicoes := PackedVector4Array()
var cores := PackedVector4Array()
var direcoes := PackedVector4Array()
var posicoes_mundo := PackedVector4Array()
var direcoes_mundo := PackedVector4Array()
var quantidade: int = 0
var ambiente_diurno := 0.55
var direcao_solar := Vector3(0.7,0.0,0.7)
var energia_solar := 0.0
var cor_solar := Color(1.0,.96,.87)
var cor_ambiente := Color.WHITE
var assinatura: String = ""
var portas_anteriores: String = ""
var bloqueios: ImageTexture
var salas: Dictionary = {}
var mapa_bloqueios: Image
var passagens: ImageTexture
var revisao := 0
var sujo := true
var estrutura_anterior: int = -1

func _init(p: PlantaPlex) -> void:
	planta = p
	var imagem := Image.create_empty(GradePlex.TAMANHO.x, GradePlex.TAMANHO.y, false, Image.FORMAT_RGBA8)
	mapa_bloqueios = imagem
	bloqueios = ImageTexture.create_from_image(imagem)
	passagens = ImageTexture.create_from_image(Image.create_empty(GradePlex.TAMANHO.x, GradePlex.TAMANHO.y, false, Image.FORMAT_RGBAF))
	planta.alterada.connect(invalidar)

func invalidar() -> void:
	sujo = true

func atualizar_sol(calendario: CalendarioPlex) -> void:
	var estado := calendario.estado_solar()
	ambiente_diurno=float(estado.ambiente)
	direcao_solar=estado.direcao
	energia_solar=float(estado.energia)
	cor_solar=estado.cor
	cor_ambiente=estado.cor_ambiente
	RenderingServer.set_default_clear_color(Color("020407").lerp(Color("263338"),clampf(ambiente_diurno,0.0,1.0)))
	revisao+=1
	for referencia in materiais.duplicate():
		var mat := referencia.get_ref() as ShaderMaterial
		if mat==null: materiais.erase(referencia)
		else: aplicar_sol(mat)

func aplicar_sol(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("ambiente",ambiente_diurno)
	mat.set_shader_parameter("direcao_solar",direcao_solar)
	mat.set_shader_parameter("energia_solar",energia_solar)
	mat.set_shader_parameter("cor_solar",Vector3(cor_solar.r,cor_solar.g,cor_solar.b))
	mat.set_shader_parameter("cor_ambiente",Vector3(cor_ambiente.r,cor_ambiente.g,cor_ambiente.b))

func sol_recebido(ponto: Vector3) -> float:
	if energia_solar<=.001 or salas.has(celula_fisica(ponto)): return 0.0
	var vetor := Vector2(direcao_solar.x,direcao_solar.y).rotated(GradePlex.visao*PI*.5)
	var direcao := Vector3(vetor.x,vetor.y,direcao_solar.z)
	return energia_solar*visibilidade(ponto,ponto+direcao*1200.0)

func posicao_sol(ponto: Vector3) -> Vector4:
	var vetor := Vector2(direcao_solar.x,direcao_solar.y).rotated(GradePlex.visao*PI*.5)
	var origem := ponto+Vector3(vetor.x,vetor.y,direcao_solar.z)*1200.0
	return Vector4(origem.x,origem.y,origem.z,2000.0)

func configurar(chao: ChaoPlex, composicao: CenaPlex) -> void:
	var piso := ShaderMaterial.new()
	piso.shader = load("res://shaders/piso_iluminado.gdshader")
	chao.material = piso
	vincular(piso)
	var objetos := ShaderMaterial.new()
	objetos.shader = load("res://shaders/objetos_iluminados.gdshader")
	objetos.set_shader_parameter("profundidade", composicao.profundidade)
	objetos.set_shader_parameter("superficies", composicao.superficies)
	objetos.set_shader_parameter("origem", Vector2(composicao.ORIGEM))
	objetos.set_shader_parameter("tamanho", Vector2(composicao.TAMANHO))
	composicao.sprite.material = objetos
	vincular(objetos)
	atualizar()

func vincular(material_novo: ShaderMaterial) -> void:
	materiais.append(weakref(material_novo))
	aplicar(material_novo)

func aplicar(mat: ShaderMaterial) -> void:
	var eixos: Vector4 = [Vector4(1, 0, 0, 1), Vector4(0, 1, -1, 0), Vector4(-1, 0, 0, -1), Vector4(0, -1, 1, 0)][posmod(GradePlex.visao, 4)]
	aplicar_sol(mat)
	mat.set_shader_parameter("eixos_visao", eixos)
	mat.set_shader_parameter("tamanho_grade", Vector2(GradePlex.TAMANHO))
	var centro := GradePlex.projetar_local(GradePlex.CENTRO)
	mat.set_shader_parameter("centro_grade", Vector2(centro.x, centro.y * 2.0))
	mat.set_shader_parameter("quantidade_luzes", quantidade)
	mat.set_shader_parameter("luzes_posicao", posicoes_mundo)
	mat.set_shader_parameter("luzes_cor", cores)
	mat.set_shader_parameter("luzes_direcao", direcoes_mundo)
	mat.set_shader_parameter("bloqueios", bloqueios)
	mat.set_shader_parameter("passagens", passagens)

func celula_fisica(ponto: Vector3) -> Vector2i:
	return Vector2i((GradePlex.inverter(Vector2(ponto.x, ponto.y * .5)) + Vector2(.5, .5)).floor())

func visibilidade(ponto: Vector3, luz: Vector3) -> float:
	return OclusaoPlex.visibilidade(planta, ponto, luz)

func energia_recebida(indice: int, ponto: Vector3) -> float:
	if indice < 0 or indice >= quantidade:
		return 0.0
	var p := posicoes[indice]
	var origem_luz := Vector3(p.x, p.y, p.z)
	var delta := origem_luz - ponto
	var distancia := maxf(1.0, delta.length())
	if distancia > p.w:
		return 0.0
	var d := direcoes[indice]
	var cone := smoothstep(d.w, minf(0.99, d.w + 0.3), (-delta / distancia).dot(Vector3(d.x, d.y, d.z)))
	var queda := (1.0 - smoothstep(p.w * 0.8, p.w, distancia)) / (1.0 + distancia * distancia / (p.w * p.w))
	var cor := cores[indice]
	var brilho := cor.x * 0.2126 + cor.y * 0.7152 + cor.z * 0.0722
	return cor.w * brilho * cone * queda * visibilidade(ponto, origem_luz)

func atualizar() -> void:
	var estados := str(GradePlex.visao)
	for item in planta.objetos.values():
		if item.tipo in CatalogoPlex.PORTAS:
			estados += str(item.id) + str(item.aberta)
	if not sujo and assinatura=="atual" and estados==portas_anteriores: return
	var estrutura: Array = [GradePlex.visao]
	for item in planta.objetos.values():
		if item.tipo in (SalasPlex.ESTRUTURA + ["palco"]) or item.tipo.begins_with("luz_"):
			estrutura.append([item.id,item.tipo,item.celula,item.rotacao,item.get("aberta",false),item.get("ligada",true),item.get("energia",1.2),item.get("cor_luz","#fff0d5")])
	var atual := hash(estrutura)
	sujo = false
	if estrutura_anterior==atual: return
	estrutura_anterior = atual
	revisao += 1
	portas_anteriores = estados
	assinatura = "atual"
	posicoes.resize(LIMITE)
	posicoes_mundo.resize(LIMITE)
	direcoes_mundo.resize(LIMITE)
	cores.resize(LIMITE)
	direcoes.resize(LIMITE)
	quantidade = 0
	salas = SalasPlex.fechadas(planta)
	var imagem := SalasPlex.mapa_ambiente(SalasPlex.ambiente_com_portas(planta, salas))
	for objeto in planta.objetos.values():
		if objeto.tipo in (SalasPlex.ESTRUTURA + ["palco"]):
			var altura := 18.0 if objeto.tipo == "palco" else (0.0 if objeto.get("aberta", false) else 160.0)
			for celula in planta.celulas(objeto.tipo, objeto.celula, objeto.rotacao):
				var marca := imagem.get_pixel(celula.x, celula.y)
				marca.r = altura / 160.0
				marca.a = 1.0
				imagem.set_pixel(celula.x, celula.y, marca)
		if not objeto.tipo.begins_with("luz_") or not objeto.get("ligada", true) or quantidade >= LIMITE:
			continue
		var dados := LuminariasPlex.especificacao(objeto, planta, salas)
		var fisicos := LuminariasPlex.especificacao(objeto, planta, salas, true)
		var p_mundo: Vector3 = fisicos.posicao
		var d_mundo: Vector3 = fisicos.direcao
		posicoes_mundo[quantidade] = Vector4(p_mundo.x, p_mundo.y, p_mundo.z, fisicos.alcance)
		direcoes_mundo[quantidade] = Vector4(d_mundo.x, d_mundo.y, d_mundo.z, fisicos.cone)
		var p: Vector3 = dados.posicao
		var d: Vector3 = dados.direcao
		var cor: Color = dados.cor
		posicoes[quantidade] = Vector4(p.x, p.y, p.z, dados.alcance)
		cores[quantidade] = Vector4(cor.r, cor.g, cor.b, dados.energia)
		direcoes[quantidade] = Vector4(d.x, d.y, d.z, dados.cone)
		quantidade += 1
	mapa_bloqueios = imagem
	bloqueios.update(imagem)
	passagens.update(OclusaoPlex.mapa_portas(planta))
	for referencia in materiais.duplicate():
		var mat := referencia.get_ref() as ShaderMaterial
		if mat != null:
			aplicar(mat)
		else:
			materiais.erase(referencia)


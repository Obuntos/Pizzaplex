class_name IluminacaoPlex
extends RefCounted
const LIMITE = 32
var circuito:=CircuitoLuzesPlex.new()
var ids_luzes: Dictionary={}
var planta: PlantaPlex
var materiais: Array[WeakRef] = []
var posicoes := PackedVector4Array()
var cores := PackedVector4Array()
var direcoes := PackedVector4Array()
var posicoes_mundo := PackedVector4Array()
var direcoes_mundo := PackedVector4Array()
var quantidade: int = 0
var rede: RedeEnergiaPlex
var cidade: LuzesCidadePlex
var estruturas: SombrasEstruturasPlex
var energia_anterior := -1.0
var revisao_portas := -1
var fontes_portas: Array[Dictionary] = []
var ambiente_diurno := 0.55
var direcao_solar := Vector3(0.7,0.0,0.7)
var energia_solar := 0.0
var cor_solar := Color(1.0,.96,.87)
var cor_ambiente := Color.WHITE
var assinatura: String = ""
var portas_anteriores: String = ""
var bloqueios: ImageTexture
var salas: Dictionary = {}
var entrada_natural: EntradaNaturalPlex
var mapa_bloqueios: Image
var passagens: ImageTexture
var revisao := 0
var sujo := true
var estrutura_anterior: int = -1
var mapa_lanternas := Image.create_empty(4,3,false,Image.FORMAT_RGBAF)
var lanternas: ImageTexture
var espera_lanternas := 0.0
var assinatura_lanternas := -1
var quantidade_lanternas := 0
var mapa_variacao:=Image.create_empty(LIMITE,1,false,Image.FORMAT_RF)
var variacao_luzes: ImageTexture
var fatores:=PackedFloat32Array()
var espera_variacao:=0.0
var assinatura_salas:=-1
var ambiente_salas: Image
func _init(p: PlantaPlex) -> void:
	planta = p
	entrada_natural=EntradaNaturalPlex.new(p)
	rede = RedeEnergiaPlex.new(p)
	cidade = LuzesCidadePlex.new(p)
	estruturas=SombrasEstruturasPlex.new(p,cidade.dados)
	cidade.estruturas=estruturas
	lanternas=ImageTexture.create_from_image(mapa_lanternas)
	mapa_variacao.fill(Color.WHITE)
	variacao_luzes=ImageTexture.create_from_image(mapa_variacao)
	fatores.resize(LIMITE)
	fatores.fill(1.0)
	var imagem := Image.create_empty(GradePlex.TAMANHO.x, GradePlex.TAMANHO.y, false, Image.FORMAT_RGBA8)
	atualizar_variacao(0.0,true)
	mapa_bloqueios = imagem
	bloqueios = ImageTexture.create_from_image(imagem)
	passagens = ImageTexture.create_from_image(Image.create_empty(GradePlex.TAMANHO.x, GradePlex.TAMANHO.y, false, Image.FORMAT_RGBAF))
	planta.alterada.connect(invalidar)
func invalidar() -> void:
	sujo = true
func atualizar_sol(calendario: CalendarioPlex) -> void:
	var estado := calendario.estado_solar()
	cidade.fator = LuzesCidadePlex.intensidade(calendario.minutos)
	cidade.atualizar_horario(calendario.minutos)
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
	cidade.aplicar(mat)
	mat.set_shader_parameter("ambiente",ambiente_diurno)
	mat.set_shader_parameter("direcao_solar",direcao_solar)
	mat.set_shader_parameter("energia_solar",energia_solar)
	mat.set_shader_parameter("cor_solar",Vector3(cor_solar.r,cor_solar.g,cor_solar.b))
	mat.set_shader_parameter("cor_ambiente",Vector3(cor_ambiente.r,cor_ambiente.g,cor_ambiente.b))
func sol_recebido(ponto: Vector3) -> float:
	if energia_solar<=.001: return 0.0
	var vetor := Vector2(direcao_solar.x,direcao_solar.y).rotated(GradePlex.visao*PI*.5)
	var direcao := Vector3(vetor.x,vetor.y,direcao_solar.z)
	if salas.has(celula_fisica(ponto)) and not entrada_natural.permite_raio(ponto,direcao): return 0.0
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
	estruturas.aplicar(mat)
	mat.set_shader_parameter("energia_rede",1.0)
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
	mat.set_shader_parameter("luz_janelas",entrada_natural.textura)
	mat.set_shader_parameter("lanternas",lanternas)
	mat.set_shader_parameter("variacao_luzes",variacao_luzes)
	mat.set_shader_parameter("quantidade_lanternas",quantidade_lanternas)
func celula_fisica(ponto: Vector3) -> Vector2i:
	return Vector2i((GradePlex.inverter(Vector2(ponto.x, ponto.y * .5)) + Vector2(.5, .5)).floor())
func visibilidade(ponto: Vector3, luz: Vector3) -> float:
	if OclusaoPlex.visibilidade(planta,ponto,luz)<.5: return 0.0
	var a:=GradePlex.inverter(Vector2(ponto.x,ponto.y*.5))
	var b:=GradePlex.inverter(Vector2(luz.x,luz.y*.5))
	return 1.0 if estruturas.visivel(Vector3(a.x,a.y,ponto.z),Vector3(b.x,b.y,luz.z)) else 0.0
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
	var cone := 1.0 if d.w <= -.99 else smoothstep(d.w, minf(0.99, d.w + 0.3), (-delta / distancia).dot(Vector3(d.x, d.y, d.z)))
	var queda := (1.0 - smoothstep(p.w * 0.55, p.w, distancia)) / (1.0 + distancia * distancia / (p.w * p.w))
	var cor := cores[indice]
	var brilho := cor.x * 0.2126 + cor.y * 0.7152 + cor.z * 0.0722
	return fatores[indice] * maxf(0.0,cor.w) * brilho * cone * queda * visibilidade(ponto, origem_luz)
func atualizar() -> void:
	rede.atualizar()
	if not is_equal_approx(energia_anterior,rede.fator):
		energia_anterior = rede.fator
		revisao += 1
		for referencia in materiais:
			var mat := referencia.get_ref() as ShaderMaterial
			if mat!=null: mat.set_shader_parameter("energia_rede",1.0)
	if revisao_portas!=planta.revisao:
		revisao_portas = planta.revisao
		fontes_portas.clear()
		for item in planta.objetos.values():
			if item.tipo in CatalogoPlex.PORTAS or EntradaNaturalPlex.eh(item): fontes_portas.append(item)
	var estados := str(GradePlex.visao)
	for item in fontes_portas: estados += str(item.id)+str(item.aberta)
	estruturas.atualizar()
	cidade.atualizar(estados)
	if not sujo and assinatura=="atual" and estados==portas_anteriores: return
	var estrutura: Array = [GradePlex.visao]
	var paredes: Array=[]
	for item in planta.objetos.values():
		if item.tipo in SalasPlex.ESTRUTURA: paredes.append([item.id,item.tipo,item.get("variante",""),item.celula,item.rotacao])
		if item.tipo in (SalasPlex.ESTRUTURA + ["palco"]) or item.tipo.begins_with("luz_"):
			estrutura.append([item.id,item.tipo,item.get("variante",""),item.celula,item.rotacao,item.get("ligada",true),item.get("energia",1.2),item.get("cor_luz","#fff0d5")])
	var atual := hash(estrutura)
	sujo = false
	if estrutura_anterior==atual:
		if estados!=portas_anteriores:
			portas_anteriores=estados
			atualizar_portas()
		return
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
	ids_luzes.clear()
	fatores.fill(1.0)
	mapa_variacao.fill(Color.WHITE)
	variacao_luzes.update(mapa_variacao)
	var topologia:=hash(paredes)
	if assinatura_salas!=topologia or ambiente_salas==null:
		assinatura_salas=topologia
		salas=SalasPlex.fechadas(planta)
		ambiente_salas=SalasPlex.mapa_ambiente(SalasPlex.ambiente_com_portas(planta,salas))
	entrada_natural.atualizar(salas)
	var imagem:=ambiente_salas.duplicate() as Image
	for objeto in planta.objetos.values():
		if objeto.tipo in (SalasPlex.ESTRUTURA + ["palco"]):
			var altura := 18.0 if objeto.tipo == "palco" else (0.0 if objeto.get("aberta", false) else 160.0)
			for celula in planta.celulas(objeto.tipo, objeto.celula, objeto.rotacao):
				var marca := imagem.get_pixel(celula.x, celula.y)
				marca.r = altura / 160.0
				marca.a = 1.0
				imagem.set_pixel(celula.x, celula.y, marca)
		if not objeto.tipo.begins_with("luz_") or quantidade >= LIMITE:
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
		ids_luzes[quantidade]=objeto.id
		quantidade += 1
	atualizar_variacao(0.0,true)
	mapa_bloqueios = imagem
	bloqueios.update(imagem)
	passagens.update(OclusaoPlex.mapa_portas(planta))
	for referencia in materiais.duplicate():
		var mat := referencia.get_ref() as ShaderMaterial
		if mat != null:
			aplicar(mat)
		else:
			materiais.erase(referencia)
func precisa_atualizar() -> bool:
	if sujo or revisao_portas!=planta.revisao or not is_equal_approx(energia_anterior,rede.fator): return true
	var estados:=str(GradePlex.visao)
	for item in fontes_portas: estados+=str(item.id)+str(item.aberta)
	return estados!=portas_anteriores
func atualizar_portas() -> void:
	for porta in fontes_portas:
		for celula in planta.celulas(porta.tipo,porta.celula,porta.rotacao):
			var marca:=mapa_bloqueios.get_pixelv(celula)
			marca.r=0.0 if porta.aberta else 1.0
			mapa_bloqueios.set_pixelv(celula,marca)
	bloqueios.update(mapa_bloqueios)
	passagens.update(OclusaoPlex.mapa_portas(planta))
	revisao+=1
func atualizar_variacao(delta: float, forcar: bool=false) -> void:
	circuito.atualizar(delta,planta,rede)
	espera_variacao+=delta
	if espera_variacao<.05 and not forcar: return
	espera_variacao=fmod(espera_variacao,.05)
	var mudou:=false
	for indice in ids_luzes:
		var valor:=circuito.fator(int(ids_luzes[indice]))
		if not is_equal_approx(fatores[indice],valor) or forcar:
			fatores[indice]=valor
			mapa_variacao.set_pixel(indice,0,Color(valor,0,0,1))
			mudou=true
	if mudou: variacao_luzes.update(mapa_variacao)
func fator_lampada(id: int) -> float:
	return circuito.fator(id)
func atualizar_moveis(atores: Array, delta: float) -> void:
	cidade.atualizar_falhas(delta)
	atualizar_variacao(delta)
	espera_lanternas+=delta
	if espera_lanternas<1.0/30.0: return
	espera_lanternas=0.0
	var dados: Array=[]
	for a in atores:
		if dados.size()>=4: break
		if not a.get_meta("visivel_cena",true): continue
		if not a.visita.get("lanterna_equipada",false) or a.visita.get("morto",false) or a.visita.get("fora_turno",false): continue
		if a.postura_manual.punhos.size()!=2: continue
		var mao: Vector3=a.postura_manual.punhos[1]
		var centro:=GradePlex.projetar_local(GradePlex.CENTRO)
		centro.y*=2.0
		var vista:=Vector2(a.position.x+mao.x,a.position.y*2.0+2.0*(mao.y+mao.z))
		var fisica: Vector2=centro+(vista-centro).rotated(-GradePlex.visao*PI*.5)
		var angulo: float=a.direcao*PI/4.0
		var frente:=Vector3(sin(angulo),cos(angulo),-.18).normalized()
		var origem:=Vector3(fisica.x,fisica.y,a.altura+mao.z)+frente*7.0
		dados.append([origem,frente])
	var chave:=hash(dados)
	if chave==assinatura_lanternas: return
	assinatura_lanternas=chave
	if quantidade_lanternas!=dados.size():
		quantidade_lanternas=dados.size()
		for referencia in materiais:
			var mat:=referencia.get_ref() as ShaderMaterial
			if mat!=null: mat.set_shader_parameter("quantidade_lanternas",quantidade_lanternas)
	mapa_lanternas.fill(Color(0,0,0,0))
	for i in dados.size():
		var origem: Vector3=dados[i][0]
		var frente: Vector3=dados[i][1]
		mapa_lanternas.set_pixel(i,0,Color(origem.x,origem.y,origem.z,240.0))
		mapa_lanternas.set_pixel(i,1,Color(frente.x,frente.y,frente.z,.82))
		mapa_lanternas.set_pixel(i,2,Color(1.0,.94,.79,2.2))
	lanternas.update(mapa_lanternas)

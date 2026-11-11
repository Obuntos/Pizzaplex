class_name VizinhancaPlex
extends Node2D
var planta: PlantaPlex
var luz: IluminacaoPlex
var composicao: CenaPlex
var revisao := -1
var visao := -1
var desativada := false
var sprites: Dictionary = {}
var pivos: Dictionary = {}
var horario := -1
var nivel_paredes := 4
var corte_automatico := false
var bases_postes: Dictionary={}
var bairro: BairroCidadePlex
var clima_versao := -1
var neves: Dictionary = {}
var animados: Dictionary = {}
var fila: Array[Dictionary] = []
var limites_atuais := Vector4.ZERO
var visao_geometria := -1
func definir_recorte(nivel: int, automatico: bool = false) -> void:
	if nivel_paredes==nivel and corte_automatico==automatico: return
	nivel_paredes=nivel
	corte_automatico=automatico
	visao=-1
func _init() -> void:
	y_sort_enabled = true
static func montar(p: PlantaPlex) -> void:
	CidadeInicialPlex.montar(p)
func atualizar() -> void:
	var retomando:=not visible and not desativada
	visible = not desativada
	if desativada:
		revisao=planta.revisao
		visao=GradePlex.visao
		clima_versao=CatalogoCidadePlex.versao
		horario=luz.cidade.versao_horario
		fila.clear()
		return
	if retomando: revisao=-1
	var girou:=visao_geometria!=GradePlex.visao
	if revisao==planta.revisao and visao==GradePlex.visao and clima_versao==CatalogoCidadePlex.versao:
		if horario!=luz.cidade.versao_horario:
			horario=luz.cidade.versao_horario
			for id in luz.cidade.predios.keys()+luz.cidade.postes.keys():
				var item: Dictionary=luz.cidade.predios.get(id,luz.cidade.postes.get(id,{}))
				if sprites.has(id): luz.cidade.emissao(sprites[id].material,item,GradePlex.rotacao_visual(item.rotacao))
		return
	revisao = planta.revisao
	visao = GradePlex.visao
	visao_geometria=GradePlex.visao
	clima_versao = CatalogoCidadePlex.versao
	animados.clear()
	horario=luz.cidade.versao_horario
	var lote:=Rect2(TerrenoPlex.area(planta))
	var inicio:=GradePlex.posicao_visao(lote.position-Vector2(.5,.5))
	var fim:=GradePlex.posicao_visao(lote.end-Vector2(.5,.5))
	var limites:=Vector4(minf(inicio.x,fim.x),minf(inicio.y,fim.y),maxf(inicio.x,fim.x),maxf(inicio.y,fim.y))
	bases_postes.clear()
	limites_atuais=limites
	fila.clear()
	var presentes: Dictionary={}
	for item in planta.objetos.values():
		if not MobiliaPlex.dados(item).get("bairro",false): continue
		presentes[item.id]=true
		fila.append(item)
		if girou and sprites.has(item.id): sprites[item.id].hide()
	for id in sprites.keys():
		if not presentes.has(id):
			pivos[id].queue_free()
			pivos.erase(id)
			sprites.erase(id)
			neves.erase(id)
func processar(orcamento_us: int = 2200) -> void:
	if desativada:
		fila.clear()
		return
	var inicio:=Time.get_ticks_usec()
	while not fila.is_empty():
		var item: Dictionary=fila.pop_front()
		if planta.objetos.has(item.id): desenhar_item(item)
		if Time.get_ticks_usec()-inicio>=orcamento_us: break
func desenhar_item(item: Dictionary) -> void:
	var info := MobiliaPlex.dados(item)
	if not info.get("bairro",false): return
	var s: Sprite2D = sprites.get(item.id)
	if s==null:
		s = Sprite2D.new()
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var material_novo := ShaderMaterial.new()
		material_novo.shader = load("res://shaders/vizinhanca.gdshader")
		s.material = material_novo
		luz.vincular(material_novo)
		var pivo := Node2D.new()
		add_child(pivo)
		pivo.add_child(s)
		pivos[item.id] = pivo
		sprites[item.id] = s
	var r := GradePlex.rotacao_visual(item.rotacao)
	var dimensao := CatalogoPlex.dimensoes(item.tipo,item.rotacao)
	var centro := Vector2(item.celula)+Vector2(dimensao-Vector2i.ONE)*.5
	var ancora:=centro
	if info.get("origem_celula",false):
		var cantos: Array[Vector2]=[Vector2.ZERO,Vector2(dimensao.x-1,0),Vector2(dimensao-Vector2i.ONE),Vector2(0,dimensao.y-1)]
		ancora=Vector2(item.celula)+cantos[item.rotacao]
	var origem: Array = info.origens[CatalogoPlex.DIRECOES[r]]
	var estado := "apagado" if item.tipo==luz.cidade.dados.postes.tipo else MobiliaPlex.estado(item)
	var do_mapa: bool=bairro!=null and bairro.ativo and item.get("cidade_mapa",false)
	var quadro: Dictionary={}
	if do_mapa and item.tipo!="cidade_poste_de_luz":
		var variante: String=bairro.estado_objeto(bairro.mapa.objetos[int(item.indice_mapa)],int(item.indice_mapa))
		quadro=CatalogoCidadePlex.quadro(item.tipo,r,"sprites",variante)
		s.texture=CatalogoPlex.textura(quadro.arquivo)
		origem=quadro.origem
	else: s.texture=CatalogoPlex.sprite(item.tipo,r,estado)
	var mat: ShaderMaterial=s.material
	mat.set_shader_parameter("emissao_continua",false)
	var origem_emissao := luz.cidade.emissao(mat,item,r)
	if not origem_emissao.is_empty(): origem=origem_emissao
	mat.set_shader_parameter("recepcao_externa",0.0 if dimensao.x>=10 else 1.0)
	mat.set_shader_parameter("recortar_vizinho",corte_automatico and dimensao.x>=10 and dimensao.y>=10)
	mat.set_shader_parameter("limites_lote",limites_atuais)
	if composicao!=null:
		mat.set_shader_parameter("profundidade_cena",composicao.profundidade)
		mat.set_shader_parameter("origem",Vector2(CenaPlex.ORIGEM))
		mat.set_shader_parameter("tamanho",Vector2(CenaPlex.TAMANHO))
	mat.set_shader_parameter("usar_altura",info.has("alturas") and composicao!=null)
	var aproximada:=dimensao==Vector2i.ONE and composicao!=null
	mat.set_shader_parameter("altura_aproximada",aproximada)
	mat.set_shader_parameter("apoio_tela",GradePlex.projetar(ancora))
	if (info.has("alturas") or aproximada) and composicao!=null:
		if info.has("alturas"): mat.set_shader_parameter("altura_sprite",CatalogoPlex.textura(info.alturas[CatalogoPlex.DIRECOES[r]]))
		mat.set_shader_parameter("profundidade_cena",composicao.profundidade)
		mat.set_shader_parameter("origem",Vector2(CenaPlex.ORIGEM))
		mat.set_shader_parameter("tamanho",Vector2(CenaPlex.TAMANHO))
	pivos[item.id].position = GradePlex.projetar(centro)
	s.position = Vector2(origem[0],origem[1])+GradePlex.projetar(ancora)-pivos[item.id].position
	s.z_index = 0
	if item.tipo==luz.cidade.dados.postes.tipo: bases_postes[item.id]={"celula":item.celula,"pivo":pivos[item.id].position,"sprite":s.position}
	pivos[item.id].z_index=-2 if info.get("decalque",false) else 0
	mat.set_shader_parameter("balanco",1.0 if do_mapa and str(item.tipo).contains("arvore") else 0.0)
	mat.set_shader_parameter("altura_textura",float(s.texture.get_height()))
	if do_mapa and (str(item.tipo).contains("arvore") or item.tipo=="cidade_semaforo"):
		animados[item.id]=item
		if item.tipo=="cidade_semaforo": CatalogoCidadePlex.sinal(mat,bairro.estado_objeto(bairro.mapa.objetos[int(item.indice_mapa)],int(item.indice_mapa)),r)
	if do_mapa and CatalogoCidadePlex.dados[item.tipo].sprites.has("neve"):
		if not neves.has(item.id):
			var neve:=Sprite2D.new()
			neve.centered=false;neve.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			pivos[item.id].add_child(neve);neves[item.id]=neve
		var coberta: Sprite2D=neves[item.id]
		var frio: Dictionary=CatalogoCidadePlex.dados[item.tipo].sprites.neve[r]
		coberta.texture=CatalogoPlex.textura(frio.arquivo)
		coberta.material=s.material
		coberta.position=Vector2(frio.origem[0],frio.origem[1])+GradePlex.projetar(ancora)-pivos[item.id].position
		coberta.visible=CatalogoCidadePlex.neve>0.0
		coberta.modulate=Color(1,1,1,CatalogoCidadePlex.neve)
	elif neves.has(item.id): neves[item.id].hide()
	s.modulate = Color.WHITE
	s.show()
func atualizar_postes(pessoas: Array) -> void:
	if desativada or bases_postes.is_empty(): return
	var ocupadas: Dictionary={}
	for a in pessoas:
		if a.robo or not a.visible or a.visita.get("morto",false) or a.visita.get("fora_turno",false): continue
		var ponto: Vector3=a.ponto_visual()
		var c:=Vector2i(Vector2(ponto.x,ponto.y).round())
		var y:=GradePlex.projetar(Vector2(ponto.x,ponto.y)).y
		ocupadas[c]=minf(float(ocupadas.get(c,INF)),y)
	for id in bases_postes:
		if not pivos.has(id): continue
		var b: Dictionary=bases_postes[id]
		var base: Vector2=b.pivo
		var y:=minf(base.y,float(ocupadas[b.celula])-.1) if ocupadas.has(b.celula) else base.y
		pivos[id].position=Vector2(base.x,y)
		sprites[id].position=b.sprite+Vector2(0,base.y-y)
func atualizar_animacoes(tempo: float) -> void:
	if desativada or bairro==null or not bairro.ativo: return
	for id in animados:
		if not sprites.has(id): continue
		var item: Dictionary=animados[id]
		var s: Sprite2D=sprites[id]
		var mat: ShaderMaterial=s.material
		if item.tipo=="cidade_semaforo":
			var r:=GradePlex.rotacao_visual(item.rotacao)
			var atual:=bairro.estado_objeto(bairro.mapa.objetos[int(item.indice_mapa)],int(item.indice_mapa))
			var quadro:=CatalogoCidadePlex.quadro(item.tipo,r,"sprites",atual)
			s.texture=CatalogoPlex.textura(quadro.arquivo)
			CatalogoCidadePlex.sinal(mat,atual,r)
		else: mat.set_shader_parameter("fase",tempo+float(id))

class_name PosesHumanasPlex
extends Node2D

static var dados: Dictionary = {}
var ativa := false
var nativa := false
var acao := ""
var quadro := 0
var pasta := ""
var frente := Sprite2D.new()
var maos := Sprite2D.new()
var pernas := Sprite2D.new()
var item := Sprite2D.new()
var ordem_frente := 2
var ordem_maos := 5
var atual: Dictionary = {}
var fontes: Dictionary = {}
var ultima_animacao := ""
var inicio_animacao := 0.0

func _init() -> void:
	use_parent_material = true
	for sprite in [frente, maos, pernas, item]:
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.use_parent_material = true
		sprite.texture = CatalogoPlex.atlas_vazio()
		add_child(sprite)

static func carregar() -> void:
	if dados.is_empty():
		dados = JSON.parse_string(FileAccess.get_file_as_string("res://dados/poses_humanas.json"))
		for modelo in ["humano","humana"]:
			for definicao in dados[modelo].values():
				definicao.direcoes=definicao.direcoes.map(func(valor): return int(valor))

func selecionar(a: PersonagemPlex, andando: bool) -> String:
	if a.visita.get("estudando",false) and a.trabalho=="estudar":return "preparar"
	if a.visita.get("morto", false): return "morto"
	if int(a.visita.get("corpo_carregado", -1)) > 0: return "carregar_corpo"
	if a.visita.get("controle_manual", false) and a.visita.get("faca_equipada", false):
		return "matar" if a.trabalho == "montar" and a.visita.get("gesto_manual", "") == "atacar" else "carregar_faca"
	if a.em_degraus:
		return a.movimento.escala.sentido + ("_caixa" if a.movimento.escala.carregando else "")
	if a.visita.get("lanterna_equipada", false) and a.carga_item<0:return "segurar_lanterna"
	if andando and not a.carregando and a.carga_item<0:return "andar"
	if a.manuseio.visible: return a.manuseio.movimento
	if a.trabalho in ["montar", "reparar", "colocar"]: return "montar" if a.trabalho == "reparar" else a.trabalho
	if a.trabalho in ["sentar_mesa","sentar_banco","descansar","vigiar_ibm","aguardar_vestiario","caixa_sentado"] and a.assento >= 0 and not andando: return "sentar"
	return ("carregar" if a.carregando else "andar") if andando else "parado"

func aplicar_sprite(sprite: Sprite2D, caminho: String, regiao: Rect2, pivo: Vector2, a: PersonagemPlex) -> void:
	var atlas := sprite.texture as AtlasTexture
	if caminho.begins_with("res://assets/poses_humanas/"):
		TexturasPosesPlex.aplicar(atlas,caminho,regiao)
		fontes[sprite]=caminho
	elif fontes.get(sprite, "") != caminho:
		atlas.atlas = CatalogoPlex.textura_iluminada(caminho)
		fontes[sprite] = caminho
	if not caminho.begins_with("res://assets/poses_humanas/"): atlas.region = regiao
	sprite.scale = a.animacao.scale
	sprite.position = -pivo * sprite.scale
	sprite.show()

func corpo(a: PersonagemPlex, caminho: String, regiao: Rect2, pivo: Vector2) -> void:
	var atlas: AtlasTexture = a.animacao.atlases.corpo
	if caminho.begins_with("res://assets/poses_humanas/"):
		TexturasPosesPlex.aplicar(atlas,caminho,regiao)
	else:
		atlas.atlas = CatalogoPlex.textura_iluminada(caminho)
		atlas.region = regiao
	a.animacao.arquivos.corpo = caminho
	a.animacao.camadas.corpo.position = -pivo

func rosto(a: PersonagemPlex, d: int, relogio: float, andar_nativo: bool = false) -> void:
	var f := posmod(floori(relogio / 4.0 * 12.0), 12)
	for parte in ["cabeca", "olhos", "boca"]:
		if parte!="cabeca" and acao!="morto":continue
		var nome: String = ("andar_cabeca" if andar_nativo else "parado_cabeca") if parte == "cabeca" else ("cansado" if acao == "morto" else a.animacao.expressao) + "_" + parte
		var caminho := "res://assets/personagens/" + a.modelo + "/" + nome + ".png"
		var col: int = quadro if parte == "cabeca" and andar_nativo else 0 if parte == "cabeca" else 10 if acao == "morto" and parte == "olhos" else f
		var atlas: AtlasTexture = a.animacao.atlases[parte]
		atlas.atlas = CatalogoPlex.textura_iluminada(caminho)
		atlas.region = Rect2(col * 48, d * 60, 48, 60)
		a.animacao.arquivos[parte] = caminho
		a.animacao.camadas[parte].position = Vector2(-24, -55)

func visitante(a: PersonagemPlex, d: int) -> bool:
	if not RoupasVisitantesPlex.visitante(a) or a.em_degraus: return false
	var origem := RoupasVisitantesPlex.pasta(a)
	if not origem.is_empty() and a.visita.get("cortando_pizza",false): return cortar(a,d,origem)
	if origem.is_empty() or acao not in ["parado", "andar", "sentar", "segurar_prato", "levar_prato", "lavar", "preparar", "morto"]: return false
	nativa = true
	var servico := acao in ["segurar_prato", "levar_prato", "lavar", "preparar"]
	quadro = posmod(floori(a.fase * 12), 12) if acao in ["andar", "levar_prato"] else posmod(floori((a.relogio-inicio_animacao)/1.1635528347*12), 12) if servico else posmod(floori(a.relogio * 3), 12)
	var regiao := Rect2(quadro * 48, d * 60, 48, 60)
	corpo(a, origem + ("/servico/" if servico else "/") + ("parado" if acao == "morto" else acao) + "_corpo.png", regiao, Vector2(24, 55))
	if servico and ResourceLoader.exists(origem+"/servico/"+acao+"_maos.png"):
		aplicar_sprite(maos, origem + "/servico/" + acao + "_maos.png", regiao, Vector2(24, 55), a)
		ordem_maos = -1 if d in [3, 4, 5] else 5
	rosto(a, d, a.relogio, acao in ["andar", "levar_prato"])
	if servico:
		var offset: Array = ManuseioPlex.definicoes[a.modelo][acao].offsets[d][quadro]
		for nome in ["cabeca", "olhos", "boca"]: a.animacao.camadas[nome].position += Vector2(offset[0], offset[1])
		var config: Dictionary=ManuseioPlex.definicoes[a.modelo][acao]
		if a.manuseio.objeto.visible and a.planta_visual.objetos.has(a.carga_item):
			var objeto: Dictionary=a.planta_visual.objetos[a.carga_item]
			EncaixeCargaPlex.aplicar(a.manuseio.objeto,a.manuseio.uniforme,a,EncaixeCargaPlex.ponto(a,objeto,config,d,quadro))
	return true

func aguardando(a: PersonagemPlex, andando: bool) -> bool:
	if a.modelo not in ["humano","humana"]: return false
	carregar()
	var desejada:=selecionar(a,andando)
	if desejada=="sentar" or not dados[a.modelo].has(desejada): return false
	if RoupasVisitantesPlex.visitante(a) and not a.em_degraus and not RoupasVisitantesPlex.pasta(a).is_empty() and desejada in ["parado","andar","sentar","segurar_prato","levar_prato","lavar","preparar","morto"]: return false
	var uniforme:=AparenciaPlex.roupa(a)
	if not dados.uniformes.has(uniforme): uniforme="nenhum"
	var origem:="res://assets/poses_humanas/"+uniforme+"/"+a.modelo+"/"
	var integrada:=desejada in ["carregar_faca","matar"]
	var repouso:=not andando and not a.em_degraus and desejada in ["carregar_faca","carregar_corpo","segurar_lanterna"]
	var arquivo:=desejada+("_repouso" if repouso else "")+("_integrado.png" if integrada else "_corpo.png")
	var pronto:=TexturasPosesPlex.pronta(origem+arquivo)
	if not integrada:
		for parte in ["bracos","maos"]:
			if not TexturasPosesPlex.pronta(origem+desejada+"_"+parte+".png"): pronto=false
	if desejada=="segurar_lanterna" and not TexturasPosesPlex.pronta(origem+desejada+"_item.png"): pronto=false
	if desejada=="segurar_lanterna" and andando and not TexturasPosesPlex.pronta(origem+"andar_corpo.png"):pronto=false
	return not pronto

func atualizar(a: PersonagemPlex, andando: bool) -> void:
	if aguardando(a,andando):
		if not a.animacao.arquivos.has("corpo"):
			ativa=false
			nativa=false
			for sprite in [frente,maos,pernas,item]: sprite.hide()
		return
	ativa = false
	nativa = false
	for sprite in [frente, maos, pernas, item]: sprite.hide()
	if a.modelo not in ["humano", "humana"]: return
	carregar()
	acao = selecionar(a, andando)
	if ultima_animacao != acao:
		ultima_animacao = acao
		inicio_animacao = a.relogio
	var d := GradePlex.direcao_visual(a.direcao)
	if visitante(a, d):
		ativa = true
		return
	if acao == "sentar":
		ativa = true
		nativa = true
		quadro = 0
		var origem := AparenciaPlex.vestir(a,"res://assets/personagens/"+a.modelo+"/sentar_corpo.png")
		corpo(a,origem,Rect2(0,d*60,48,60),Vector2(24,55))
		if a.trabalho=="sentar_banco":
			var em_pe:=AparenciaPlex.vestir(a,"res://assets/personagens/"+a.modelo+"/parado_corpo.png")
			a.animacao.atlases.corpo.atlas=PoseBancoPlex.textura(origem,em_pe,60,55)
		rosto(a,d,a.relogio)
		return
	if not dados[a.modelo].has(acao): return
	ativa = true
	var definicao: Dictionary = dados[a.modelo][acao]
	var total := int(definicao.quadros)
	if a.em_degraus:
		quadro = roundi(float(a.movimento.escala.quadro) / maxf(1, float(a.movimento.escala.definicao.frames) - 1) * (total - 1))
	elif acao in ["colocar", "matar"]:
		quadro = clampi(floori(a.progresso_acao * total), 0, total - 1)
	elif acao in ["andar", "carregar", "carregar_faca", "carregar_corpo", "segurar_lanterna"] or acao.begins_with("levar_"):
		quadro = posmod(floori(a.fase * total), total) if andando else 0
	elif acao in ["montar", "varrer", "esfregar", "lavar", "preparar"]:
		quadro = posmod(floori((a.relogio-inicio_animacao)/float(definicao.duracao)*total), total)
	else:
		quadro = posmod(floori(a.relogio / float(definicao.duracao) * total), total)
	var linha: int = definicao.direcoes.find(d)
	if linha < 0: linha = 0
	var uniforme := AparenciaPlex.roupa(a)
	if not dados.uniformes.has(uniforme): uniforme = "nenhum"
	pasta = "res://assets/poses_humanas/" + uniforme + "/" + a.modelo + "/"
	var regiao := Rect2(quadro * 80, linha * 80, 80, 80)
	var integrada:=acao in ["carregar_faca","matar"]
	var repouso:=not andando and not a.em_degraus and acao in ["carregar_faca","carregar_corpo","segurar_lanterna"]
	var nome:=acao+("_repouso" if repouso else "")+("_integrado.png" if integrada else "_corpo.png")
	corpo(a,pasta+nome,Rect2(0,linha*80,80,80) if repouso else regiao,Vector2(40,67))
	if not integrada:
		aplicar_sprite(frente, pasta + acao + "_bracos.png", regiao, Vector2(40, 67), a)
		aplicar_sprite(maos, pasta + acao + "_maos.png", regiao, Vector2(40, 67), a)
	ordem_frente = 2
	ordem_maos = 5
	if acao in ["levar_prato","segurar_prato","levar_dois_pratos","segurar_dois_pratos","levar_caixa","segurar_caixa","carregar"] and d in [3,4,5]:
		ordem_frente=-2
		ordem_maos=-2
	atual = definicao.clipes[str(d if definicao.clipes.has(str(d)) else definicao.direcoes[linha])][quadro]
	if acao=="segurar_lanterna":
		aplicar_sprite(item, pasta + acao + "_item.png", regiao, Vector2(40, 67), a)
		if andando and not a.em_degraus:
			corpo(a,pasta+nome,Rect2(regiao.position,Vector2(80,52)),Vector2(40,67))
			var passo:=posmod(floori(a.fase*12.0),12)
			aplicar_sprite(pernas,pasta+"andar_corpo.png",Rect2(passo*80,linha*80+52,80,28),Vector2(40,15),a)
	if a.em_degraus: escada(a)
	rosto(a, d, a.relogio)
	encaixar(a, andando)

func escada(a: PersonagemPlex) -> void:
	var e: EscalaPlex = a.movimento.escala
	var direcao: String = CatalogoPlex.DIRECOES[GradePlex.rotacao_visual(e.rotacao)]
	var caminho: String = pasta + "escadas/" + e.sentido + "_pernas/" + direcao + ".png"
	var regiao := Rect2(posmod(e.quadro, int(e.definicao.columns)) * 48, floori(float(e.quadro) / int(e.definicao.columns)) * 60, 48, 60)
	aplicar_sprite(pernas, caminho, regiao, Vector2(24, 55), a)

func encaixar(a: PersonagemPlex, _andando: bool) -> void:
	var pose := a.postura_manual
	pose.punhos.clear()
	for b in atual.bracos:
		var p: Array = b[2]
		var h := (float(p[2]) - 2 * (float(p[1]) - 55)) / 3.0
		pose.punhos.append(Vector3((float(p[0]) - 24) * a.animacao.scale.x, (float(p[1]) + .45 - 55) * a.animacao.scale.y, h * a.animacao.scale.y))
	pose.ponto_carga = (pose.punhos[0] + pose.punhos[1]) * .5
	pose.ativo = acao in ["carregar_faca", "matar", "carregar_corpo", "segurar_lanterna"]
	pose.modo_atual = "corpo" if acao == "carregar_corpo" else "faca" if acao in ["carregar_faca", "matar"] else "lanterna" if acao == "segurar_lanterna" else ""
	pose.quadro_atual = quadro
	pose.arma_atras = false
	pose.angulo_faca = atan2(float(atual.eixo[1]), float(atual.eixo[0]))
	if a.material is ShaderMaterial:
		var ossos := PackedVector4Array()
		for b in atual.bracos:
			for p in b:
				var ponto := a.position + a.visual.position + (Vector2(p[0], p[1]) - Vector2(24, 55)) * a.animacao.scale
				ossos.append(Vector4(ponto.x, ponto.y, GradePlex.profundidade(a.local, a.altura) + float(p[2]) * a.animacao.scale.y, 0))
		a.material.set_shader_parameter("usar_bracos", true)
		a.material.set_shader_parameter("bracos", ossos)
	if a.carga.visible and a.trabalho == "colocar":
		var inicio := Vector2(pose.ponto_carga.x,pose.ponto_carga.y+9.8)-Vector2(96,144)
		var destino := GradePlex.projetar(Vector2(a.alvo_carga.x,a.alvo_carga.y),a.alvo_carga.z)-a.position-a.visual.position-Vector2(96,144)
		a.carga.position=inicio.lerp(destino,smoothstep(.35,.9,a.progresso_acao))
	if a.manuseio.visible and VassouraPosePlex.usa(acao) and a.planta_visual.objetos.get(a.carga_item,{}).get("tipo","")=="vassoura":
		VassouraPosePlex.aplicar(a)
		return
	if a.manuseio.visible and not pose.ativo:
		for i in 2:
			var sprite: Sprite2D = a.manuseio.objeto if i == 0 else a.manuseio.objeto_extra
			if not sprite.visible: continue
			var id: int = a.carga_item if i == 0 else a.carga_extra[0] if not a.carga_extra.is_empty() else -1
			var objeto: Dictionary = a.planta_visual.objetos.get(id, {"tipo":a.caixa_tipo,"rotacao":0})
			var local: Vector3 = pose.punhos[i if acao.contains("dois_pratos") else 1] if not acao.contains("caixa") else pose.ponto_carga
			if ItensPlex.categoria(str(objeto.tipo))=="caixa":
				local-=EncaixeCargaPlex.encaixe(objeto.tipo,GradePlex.rotacao_visual(int(objeto.get("rotacao",0))))
			elif EncaixeCargaPlex.apoiado(str(objeto.tipo)):
				local-=EncaixeCargaPlex.apoio(objeto.tipo,GradePlex.rotacao_visual(int(objeto.get("rotacao",0))))
			else:
				local -= EncaixeCargaPlex.encaixe(objeto.tipo,GradePlex.rotacao_visual(int(objeto.get("rotacao",0))),str(objeto.get("estado","")))
			EncaixeCargaPlex.aplicar(sprite, a.manuseio.uniforme if i == 0 else a.manuseio.uniforme_extra, a, local)

func finalizar(a: PersonagemPlex) -> void:
	if not ativa: return
	a.manuseio.maos.hide()
	a.manuseio.pernas.hide()
	a.postura_manual.hide()


func cortar(a: PersonagemPlex, d: int, origem: String) -> bool:
	var caminho:=origem+"/servico/preparar_corpo.png"
	if not ResourceLoader.exists(caminho): return false
	nativa=true
	quadro=posmod(floori(a.relogio*7.0),12)
	corpo(a,caminho,Rect2(quadro*48,d*60,48,40),Vector2(24,55))
	aplicar_sprite(pernas,origem+"/sentar_corpo.png",Rect2(0,d*60+40,48,20),Vector2(24,15),a)
	var caminho_maos:=origem+"/servico/preparar_maos.png"
	if ResourceLoader.exists(caminho_maos): aplicar_sprite(maos,caminho_maos,Rect2(quadro*48,d*60,48,60),Vector2(24,55),a)
	ordem_maos=-1 if d in [3,4,5] else 5
	rosto(a,d,a.relogio)
	var offsets: Array=ManuseioPlex.definicoes[a.modelo].preparar.offsets[d][quadro]
	for parte in ["cabeca","olhos","boca"]: a.animacao.camadas[parte].position+=Vector2(offsets[0],offsets[1])
	return true

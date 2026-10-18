class_name AnimacaoPlex
extends Node2D

var desgaste: float = 0.0
var modelo: String = "humano"
var expressao: String = "neutro"
var camadas: Dictionary = {}
var atlases: Dictionary = {}
var arquivos: Dictionary = {}
var definicao: Dictionary = {}
var endo_config: Dictionary = {}
var endo_partes: Array = []

func configurar(valor: String) -> void:
	CatalogoPlex.carregar()
	modelo = valor
	definicao = CatalogoPlex.personagens[modelo]
	scale = Vector2(definicao.scale[0], definicao.scale[1])
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	camadas.clear()
	atlases.clear()
	arquivos.clear()
	var nomes: Array = ["corpo", "cabeca", "olhos", "boca"] if definicao.layered else ["modelo"]
	for nome in nomes:
		var sprite := Sprite2D.new()
		sprite.name = nome.capitalize()
		sprite.centered = false
		sprite.position = -Vector2(definicao.pivot[0], definicao.pivot[1])
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.use_parent_material = true
		var atlas := AtlasTexture.new()
		sprite.texture = atlas
		atlases[nome] = atlas
		camadas[nome] = sprite
		add_child(sprite)

func atualizar(acao: String, direcao: int, fase: float, relogio: float, pecas: int = -1, progresso_acao: float = 0.0) -> void:
	if definicao.is_empty():
		return
	if modelo.begins_with("endo") and not endo_config.is_empty():
		atlases.modelo.atlas = EndoPecasPlex.textura(endo_config,endo_partes,direcao)
		atlases.modelo.region = Rect2(0,0,int(definicao.width),int(definicao.height))
		arquivos.modelo = "modular:"+EndoPecasPlex.chave(endo_config,endo_partes,direcao)
		return
	if not definicao.layered and pecas < 0 and ClipesPlex.possui(modelo,acao):
		var clipe := ClipesPlex.quadro(modelo,acao,direcao,fase,relogio,desgaste)
		if arquivos.get("modelo","") != clipe.arquivo:
			atlases.modelo.atlas = CatalogoPlex.textura_iluminada(clipe.arquivo)
			arquivos.modelo = clipe.arquivo
		atlases.modelo.region = clipe.regiao
		camadas.modelo.position=-Vector2(definicao.pivot[0],definicao.pivot[1])+clipe.get("deslocamento",Vector2.ZERO)
		return
	var largura: int = definicao.width
	var altura: int = definicao.height
	var quadro: int = int(floor(fposmod(fase, 1.0) * definicao.frames))
	if acao in ["parado", "montar", "cantar", "dancar", "jogar"]:
		quadro = int(floor(fposmod(relogio / 4.0, 1.0) * definicao.frames))
	if acao in ["cantar", "dancar"]:
		quadro = int(floor(fposmod(relogio / (1.2 if acao == "cantar" else 1.5),1.0) * definicao.frames))
	if modelo == "crianca" and acao in ["jogar", "assistir"]:
		quadro = int(floor(fposmod(relogio / (1.6 if acao == "jogar" else 2.4),1.0) * definicao.frames))
	var deslocamento := Vector2.ZERO
	if acao in ["colocar", "montar"] and definicao.layered:
		var total: int = definicao.trabalho[acao].get("frames", definicao.frames)
		quadro = clampi(int(progresso_acao * total), 0, total - 1)
		var posicao: Array = definicao.trabalho[acao].offsets[posmod(direcao, 8)][quadro]
		deslocamento = Vector2(posicao[0], posicao[1])
	if acao == "colocar" and not definicao.layered:
		acao = "carregar"
	for nome in camadas:
		var arquivo := "res://assets/personagens/" + modelo + "/"
		var coluna: int = quadro
		if definicao.layered:
			if nome in ["olhos", "boca"]:
				arquivo += expressao + "_" + nome + ".png"
				coluna = int(floor(fposmod(relogio / 4.0, 1.0) * definicao.frames))
			elif nome == "cabeca" and acao in ["colocar", "montar", "sentar"]:
				arquivo += "parado_cabeca.png"
				coluna = int(floor(fposmod(relogio / 4.0, 1.0) * definicao.frames))
			else:
				arquivo += acao + "_" + nome + ".png"
		else:
			arquivo += acao + ".png"
			if modelo == "endo" and pecas >= 0:
				arquivo = "res://assets/personagens/endo/montagem.png"
				coluna = clampi(pecas, 0, 4)
		if arquivos.get(nome, "") != arquivo:
			atlases[nome].atlas = CatalogoPlex.textura_iluminada(arquivo)
			arquivos[nome] = arquivo
		atlases[nome].region = Rect2(coluna * largura, posmod(direcao, 8) * altura, largura, altura)
		camadas[nome].position = -Vector2(definicao.pivot[0], definicao.pivot[1]) + (deslocamento if nome != "corpo" else Vector2.ZERO)

func atualizar_escada(escala: EscalaPlex, direcao: int, relogio: float) -> void:
	atualizar("parado", direcao, 0.0, relogio)
	var nome: String = "corpo" if definicao.layered else "modelo"
	camadas[nome].position=-Vector2(definicao.pivot[0],definicao.pivot[1])
	var sufixo: String = "_corpo" if definicao.layered else ""
	var caixa: String = "_caixa" if escala.carregando else ""
	var caminho: String = "res://assets/personagens/" + (AnimatronicosPlex.base(modelo) if not AnimatronicosPlex.base(modelo).is_empty() else modelo) + "/escada/" + escala.sentido + caixa + sufixo + "/" + CatalogoPlex.DIRECOES[GradePlex.rotacao_visual(escala.rotacao)] + ".png"
	atlases[nome].atlas = CatalogoPlex.textura_iluminada(caminho)
	arquivos[nome] = caminho
	var coluna: int = escala.quadro % int(escala.definicao.columns)
	var linha: int = escala.quadro / int(escala.definicao.columns)
	atlases[nome].region = Rect2(coluna * int(definicao.width), linha * int(definicao.height), int(definicao.width), int(definicao.height))

class_name AnimacaoPlex
extends Node2D

static var cache_expressoes:Dictionary={}
var desgaste: float = 0.0
var modelo: String = "humano"
var expressao: String = "neutro"
var camadas: Dictionary = {}
var atlases: Dictionary = {}
var arquivos: Dictionary = {}
var definicao: Dictionary = {}
var endo_config: Dictionary = {}
var endo_partes: Array = []
var roupa_visitante: String = ""
var externo := false

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
		var atlas := CatalogoPlex.atlas_vazio()
		sprite.texture = atlas
		atlases[nome] = atlas
		camadas[nome] = sprite
		add_child(sprite)

func atualizar(acao: String, direcao: int, fase: float, relogio: float, pecas: int = -1, progresso_acao: float = 0.0) -> void:
	if externo: return
	if definicao.is_empty():
		return
	if modelo.begins_with("endo") and not endo_config.is_empty():
		atlases.modelo.atlas = EndoPecasPlex.textura(endo_config,endo_partes,direcao)
		atlases.modelo.region = Rect2(0,0,int(definicao.width),int(definicao.height))
		arquivos.modelo = "modular:"+EndoPecasPlex.chave(endo_config,endo_partes,direcao)
		return
	if not definicao.layered and modelo!="fantasia_coelho" and pecas < 0 and ClipesPlex.possui(modelo,acao):
		var clipe := ClipesPlex.quadro(modelo,acao,direcao,fase,relogio,desgaste)
		if ResourceLoader.exists(clipe.arquivo):
			if get_parent()!=null and get_parent().get_parent() is PersonagemPlex and not ClipesPlex.pronto(clipe.arquivo): return
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
	if (modelo == "crianca" or modelo.begins_with("adolescente")) and acao in ["jogar", "assistir"]:
		quadro = int(floor(fposmod(relogio / (1.6 if acao == "jogar" else 2.4),1.0) * definicao.frames))
	if modelo in ["fantasia_coelho"] and acao not in ["andar","carregar"] and not acao.begins_with("levar_"):
		quadro=floori(fposmod(relogio/(9.0 if acao in ["varrer","esfregar","segurar_vassoura","falar"] else 2.5),1.0)*int(definicao.frames))
	if modelo=="fantasia_coelho" and acao=="matar": quadro=clampi(floori(progresso_acao*int(definicao.frames)),0,int(definicao.frames)-1)
	var deslocamento := Vector2.ZERO
	if acao in ["colocar", "montar"] and definicao.layered:
		var total: int = definicao.trabalho[acao].get("frames", definicao.frames)
		quadro = clampi(int(progresso_acao * total), 0, total - 1)
		var posicao: Array = definicao.trabalho[acao].offsets[posmod(direcao, 8)][quadro]
		deslocamento = Vector2(posicao[0], posicao[1])
	if acao == "colocar" and not definicao.layered and modelo not in ["fantasia_coelho"]:
		acao = "carregar"
	for nome in camadas:
		if nome=="cabelo_profissional":continue
		if modelo in ["humano","humana"] and nome in ["olhos","boca"]:
			camadas[nome].position=-Vector2(definicao.pivot[0],definicao.pivot[1])+deslocamento
			continue
		if externo and nome == "corpo": continue
		var arquivo := "res://assets/personagens/" + modelo + ("/ancoras_3/" if modelo=="fantasia_coelho" else "/")
		var coluna: int = quadro
		if definicao.layered:
			if nome in ["olhos", "boca"]:
				arquivo += expressao_disponivel(modelo,expressao) + "_" + nome + ".png"
				coluna = int(floor(fposmod(relogio / 4.0, 1.0) * definicao.frames))
			elif nome == "cabeca" and acao in ["colocar", "montar", "sentar"]:
				arquivo += "parado_cabeca.png"
				coluna = int(floor(fposmod(relogio / 4.0, 1.0) * definicao.frames))
			else:
				arquivo += acao + "_" + nome + ".png"
		else:
			arquivo += acao + ".png"
			if modelo=="bonnie_visitante":
				var anim:=acao if acao in ["parado","andar","sentar","levar_prato","segurar_prato","lavar","preparar"] else "preparar" if acao in ["varrer","esfregar"] else "andar" if acao=="carregar" else "parado"
				var humor:=expressao if expressao in ["neutro","feliz","muito_feliz","triste","chateado","depressivo","ansioso","medo","pavor","incomodado","raivoso","confuso","surpreso","shocked"] else "neutro"
				arquivo="res://assets/personagens/bonnie_visitante/"+humor+"/"+anim+".png"
			if not ResourceLoader.exists(arquivo): arquivo = "res://assets/personagens/" + modelo + "/parado.png"
			if modelo == "endo" and pecas >= 0:
				arquivo = "res://assets/personagens/endo/montagem.png"
				coluna = clampi(pecas, 0, 4)
		if nome=="corpo" and not roupa_visitante.is_empty():
			var vestido:=roupa_visitante+"/"+acao+"_corpo.png"
			if ResourceLoader.exists(vestido): arquivo=vestido
		if modelo.begins_with("fantasia_") and get_parent()!=null and get_parent().get_parent() is PersonagemPlex and not ClipesPlex.pronto(arquivo): return
		if arquivos.get(nome, "") != arquivo:
			atlases[nome].atlas = CatalogoPlex.textura_iluminada(arquivo)
			arquivos[nome] = arquivo
		atlases[nome].region = Rect2(coluna * largura, posmod(direcao, 8) * altura, largura, altura)
		camadas[nome].position = -Vector2(definicao.pivot[0], definicao.pivot[1]) + (deslocamento if nome != "corpo" else Vector2.ZERO)

func atualizar_escada(escala: EscalaPlex, direcao: int, relogio: float) -> void:
	if modelo.begins_with("novo_") or AtracoesCatalogoPlex.permitido(modelo):
		var fase_final:=maxf(.001,float(escala.percurso.frames[-1][4]))
		ClipesPlex.carregar()
		var clipe:Dictionary=ClipesPlex.modelos.get(modelo,{}).get("clipes",{}).get("escada_"+escala.sentido,{})
		var duracao:=float(clipe.get("duracao",4.8))
		var modo:=str(escala.definicao.get("clipe",escala.sentido))
		if escala.definicao.get("apoios_tile",false):
			clipe=ClipesPlex.modelos[modelo].clipes["escada_"+modo]
			duracao=float(clipe.duracao)
			var quadro_tile:=escala.quadro+int(escala.percurso.get("quadro_inicial",0))
			atualizar("escada_"+modo,direcao,escala.fase_visual(),(float(quadro_tile)+.01)/float(clipe.frames)*duracao)
		else:
			atualizar("escada_"+modo,direcao,escala.fase_visual(),clampf(escala.fase_visual()/fase_final,0.0,1.0)*duracao)
		return
	atualizar("parado", direcao, 0.0, relogio)
	if externo: return
	var nome: String = "corpo" if definicao.layered else "modelo"
	camadas[nome].position=-Vector2(definicao.pivot[0],definicao.pivot[1])
	var sufixo: String = "_corpo" if definicao.layered else ""
	var caixa: String = "_caixa" if escala.carregando and (definicao.layered or modelo in ["fantasia_coelho"]) else ""
	var caminho: String = "res://assets/personagens/" + (AnimatronicosPlex.base(modelo) if not AnimatronicosPlex.base(modelo).is_empty() else modelo) + "/escada/" + escala.sentido + caixa + sufixo + "/" + CatalogoPlex.DIRECOES[GradePlex.rotacao_visual(escala.rotacao)] + ".png"
	if not ResourceLoader.exists(caminho):
		atualizar("carregar" if escala.carregando else "andar",direcao,escala.fase_visual(),relogio)
		return
	atlases[nome].atlas = CatalogoPlex.textura_iluminada(caminho)
	arquivos[nome] = caminho
	var coluna: int = escala.quadro % int(escala.definicao.columns)
	var linha: int = floori(float(escala.quadro) / int(escala.definicao.columns))
	atlases[nome].region = Rect2(coluna * int(definicao.width), linha * int(definicao.height), int(definicao.width), int(definicao.height))



static func expressao_disponivel(modelo_local:String,estado:String) -> String:
	var chave:=modelo_local+":"+estado
	if cache_expressoes.has(chave):return str(cache_expressoes[chave])
	var alternativas:Array=[estado]
	var equivalente:String={"muito_feliz":"feliz","chateado":"triste","incomodado":"triste","raivoso":"triste","depressivo":"cansado","ansioso":"cansado","medo":"assustado","pavor":"assustado","surpreso":"assustado","shocked":"assustado","confuso":"cansado"}.get(estado,"neutro")
	alternativas.append(equivalente);alternativas.append("neutro")
	for opcao in alternativas:
		var base:="res://assets/personagens/"+modelo_local+"/"+str(opcao)
		if ResourceLoader.exists(base+"_olhos.png") and ResourceLoader.exists(base+"_boca.png"):cache_expressoes[chave]=str(opcao);return str(opcao)
	cache_expressoes[chave]="neutro";return "neutro"

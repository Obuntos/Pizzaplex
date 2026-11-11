class_name AparenciaPlex
extends Node

static var dados: Dictionary = {}
var camadas: Dictionary = {}
var arquivos: Dictionary = {}

static func carregar() -> void:
	if dados.is_empty(): dados = JSON.parse_string(FileAccess.get_file_as_string("res://dados/aparencias.json"))

static func permitida(ator: PersonagemPlex) -> bool:
	return not ator.robo and ator.modelo in ["humano","humana","adolescente","adolescente_feminina","crianca"]

static func roupa(ator: PersonagemPlex) -> String:
	carregar()
	if not permitida(ator) or RoupasVisitantesPlex.visitante(ator): return "nenhum"
	return dados.padroes.get(ator.funcao,"funcionario") if ator.uniforme == "automatico" else ator.uniforme

static func cabelo(ator: PersonagemPlex) -> String:
	if not permitida(ator): return "nenhum"
	var reservado:=str(ator.get_meta("cabelo_reservado","nenhum"))
	if ator.funcao=="seguranca" and ator.cabelo in ["nenhum","automatico"]:return "curto"
	if ator.cabelo=="automatico": return VariedadeAparenciaPlex.escolher_cabelo(ator,reservado)
	if not AdministradorPlex.eh(ator) and ator.cabelo!="nenhum" and ator.cabelo==reservado:
		return VariedadeAparenciaPlex.escolher_cabelo(ator,reservado)
	return ator.cabelo

static func vestir(ator: PersonagemPlex, arquivo: String) -> String:
	if RoupasVisitantesPlex.visitante(ator): return RoupasVisitantesPlex.arquivo(ator,arquivo)
	var uniforme := roupa(ator)
	if uniforme == "nenhum": return arquivo
	var novo := arquivo.replace("res://assets/personagens/","res://assets/aparencias/uniformes/"+uniforme+"/")
	return novo if ResourceLoader.exists(novo) else arquivo

func configurar(ator: PersonagemPlex) -> void:
	for nome in ["tras","frente","chapeu"]:
		var s := Sprite2D.new()
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.use_parent_material = true
		s.texture = CatalogoPlex.atlas_vazio()
		ator.visual.add_child(s)
		camadas[nome] = s
	ator.visual.move_child(camadas.tras,0)

func aplicar(nome: String, arquivo: String, regiao: Rect2, pivo: Vector2, ator: PersonagemPlex, deslocamento: Vector2) -> void:
	var s: Sprite2D = camadas[nome]
	s.show()
	var atlas := s.texture as AtlasTexture
	var cor:=CoresCabeloPlex.cor(ator)
	var chave := arquivo+":"+roupa(ator)+":"+cor+":"+ator.modelo if nome in ["tras","frente"] else arquivo
	if arquivos.get(nome,"") != chave:
		atlas.atlas = CabeloChapeuPlex.textura(arquivo,roupa(ator),cor,ator.modelo) if nome in ["tras","frente"] else CatalogoPlex.textura_iluminada(arquivo)
		arquivos[nome] = chave
	atlas.region = regiao
	s.scale = ator.animacao.scale
	s.position = (-pivo+deslocamento)*s.scale

func atualizar(ator: PersonagemPlex, andando: bool) -> void:
	for s in camadas.values(): s.hide()
	if not permitida(ator): return
	var corpo: AtlasTexture = ator.animacao.atlases.get("corpo")
	var fonte_corpo:=str(ator.animacao.arquivos.get("corpo",""))
	if corpo==null or corpo.atlas==null or fonte_corpo.is_empty() or not ator.animacao.camadas.has("cabeca"): return
	var vestido := vestir(ator,fonte_corpo)
	if vestido != fonte_corpo:
		corpo.atlas = CatalogoPlex.textura_iluminada(vestido)
		ator.animacao.arquivos.corpo = vestido
	if not ator.poses_humanas.ativa and ator.manuseio.visible and ator.manuseio.pernas.visible and not ator.manuseio.arquivo_pernas.is_empty():
		ator.manuseio.atlas_pernas.atlas = CatalogoPlex.textura_iluminada(vestir(ator,ator.manuseio.arquivo_pernas))
	if ator.manuseio.visible and not ator.poses_humanas.ativa:
		var caminho: String = "res://assets/personagens/"+ator.modelo+"/servico/"+str(ator.manuseio.movimento)+"_maos.png"
		var vestido_maos := vestir(ator,caminho)
		ator.manuseio.atlas_maos.atlas = CatalogoPlex.textura_iluminada(vestido_maos)
		if vestido_maos==caminho and roupa(ator)!="nenhum" and ator.animacao.arquivos.corpo.begins_with("res://assets/aparencias/uniformes/"):
			ator.manuseio.maos.hide()
	var direcao := GradePlex.direcao_visual(ator.direcao)
	var deslocamento: Vector2 = ator.animacao.camadas.cabeca.position+Vector2(24,55)
	var estilo := cabelo(ator)
	if estilo != "nenhum":
		var acao := "andar" if andando else "parado"
		var fase: float = float(ator.movimento.escala.quadro)/12.0 if ator.em_degraus else ator.fase
		var quadro := int(floor(fposmod(fase,1.0)*12)) if andando else 0
		for nome in ["tras","frente"]:
			aplicar(nome,"res://assets/aparencias/cabelos/"+estilo+"/"+acao+"_"+nome+".png",Rect2(quadro*48,direcao*68,48,68),Vector2(24,63),ator,deslocamento)
			EncaixeCabeloPlex.aplicar(camadas[nome],ator,estilo,andando,quadro,direcao)
	var uniforme := roupa(ator)
	var arquivo_chapeu:="res://assets/aparencias/uniformes/"+uniforme+"/chapeu.png"
	if uniforme != "nenhum" and ResourceLoader.exists(arquivo_chapeu): aplicar("chapeu",arquivo_chapeu,Rect2(0,direcao*80,48,80),Vector2(24,75),ator,deslocamento)
	ator.visual.move_child(camadas.tras,0)
	ator.visual.move_child(camadas.frente,ator.visual.get_child_count()-1)
	ator.visual.move_child(camadas.chapeu,ator.visual.get_child_count()-1)


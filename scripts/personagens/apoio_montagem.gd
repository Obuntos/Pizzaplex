class_name ApoioMontagemPlex
extends RefCounted

static var alturas: Dictionary = {}

static func elevacao(ator: PersonagemPlex) -> float:
	var direcao := GradePlex.direcao_visual(ator.direcao)
	var chave := ator.modelo+":"+str(direcao)
	if alturas.has(chave): return alturas[chave]
	var d: Dictionary = CatalogoPlex.personagens[ator.modelo]
	var imagem: Image
	if ClipesPlex.possui(ator.modelo,"parado"):
		var q := ClipesPlex.quadro(ator.modelo,"parado",direcao,0,0)
		imagem = CatalogoPlex.imagem(q.arquivo).get_region(q.regiao)
	else:
		imagem = CatalogoPlex.imagem("res://assets/personagens/"+ator.modelo+"/parado.png").get_region(Rect2i(0,direcao*int(d.height),int(d.width),int(d.height)))
	var base := imagem.get_used_rect().end.y-1
	alturas[chave] = ceilf(2.5+maxf(0,(base-float(d.pivot[1]))*float(d.scale[1])))
	return alturas[chave]

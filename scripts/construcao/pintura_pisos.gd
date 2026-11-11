class_name PinturaPisosPlex
extends RefCounted

static func eh(tipo: String) -> bool:
	return tipo=="chao" or bool(CatalogoPlex.objetos.get(tipo,{}).get("piso",false))

static func rotacao_visual(tipo: String, rotacao: int) -> int:
	return GradePlex.rotacao_visual(rotacao+int(CatalogoPlex.objetos.get(tipo,{}).get("rotacao_base",0)))

static func diferente(editor: EditorPlex, c: Vector2i) -> bool:
	return editor.planta.pisos.has(c) or int(editor.planta.cores.get(c,0))!=editor.cor if editor.ferramenta=="chao" else editor.planta.pisos.get(c,"")!=editor.ferramenta or int(editor.planta.rotacoes_pisos.get(c,0))!=editor.rotacao

static func aplicar(editor: EditorPlex, locais: Array[Vector2i]) -> int:
	var pintar: Array[Vector2i]=[]
	for c in locais:
		if not pintar.has(c) and TerrenoPlex.contem(editor.planta,c) and diferente(editor,c): pintar.append(c)
	if pintar.is_empty(): return 0
	var preco:=2 if editor.ferramenta=="chao" else MobiliaPlex.preco(editor.ferramenta)
	if not editor.cobrar(preco*pintar.size()): return 0
	var anteriores:Array[Dictionary]=[]
	for c in pintar:
		var anterior:Dictionary={"celula":c}
		for campo in ["pisos","rotacoes_pisos","cores","uso_pisos"]:
			var mapa:Dictionary=editor.planta.get(campo)
			if mapa.has(c):anterior[campo]=mapa[c]
		anteriores.append(anterior)
		if editor.ferramenta=="chao":
			editor.planta.pisos.erase(c)
			editor.planta.rotacoes_pisos.erase(c)
			editor.planta.cores[c]=editor.cor
		else:
			editor.planta.pisos[c]=editor.ferramenta
			editor.planta.rotacoes_pisos[c]=editor.rotacao
		editor.planta.uso_pisos.erase(c)
	var custo:=preco*pintar.size() if editor.jogo!=null and editor.jogo.campanha else 0
	if editor.pintura_ativa and not editor.pintura_acao.is_empty():
		for anterior in anteriores:
			if not editor.pintura_acao.pisos.any(func(p):return p.celula==anterior.celula):editor.pintura_acao.pisos.append(anterior)
		editor.pintura_acao.custo+=custo
	else:
		var acao:Dictionary={"pisos":anteriores,"custo":custo}
		editor.historico.append(acao)
		if editor.pintura_ativa:editor.pintura_acao=acao
		if editor.historico.size()>64:editor.historico.pop_front()
	editor.planta.notificar_piso()
	return pintar.size()

static func sala(planta: PlantaPlex, origem: Vector2i) -> Array[Vector2i]:
	var vazia: Array[Vector2i]=[]
	if not TerrenoPlex.contem(planta,origem) or SubstituicaoParedesPlex.estrutural(planta.em(origem)): return vazia
	var fila: Array[Vector2i]=[origem]
	var vistas: Dictionary={origem:true}
	var indice:=0
	var material:=assinatura(planta,origem)
	while indice<fila.size():
		var c:=fila[indice];indice+=1
		for d in GradePlex.VIZINHOS:
			var vizinha: Vector2i=c+d
			if not TerrenoPlex.contem(planta,vizinha) or assinatura(planta,vizinha)!=material:continue
			if vistas.has(vizinha) or SubstituicaoParedesPlex.estrutural(planta.em(vizinha)): continue
			vistas[vizinha]=true;fila.append(vizinha)
	return fila

static func assinatura(planta:PlantaPlex,c:Vector2i) -> String:
	return "piso:"+str(planta.pisos[c]) if planta.pisos.has(c) else "chao:"+str(planta.cores.get(c,0))

static func preencher(editor: EditorPlex, origem: Vector2i) -> int:
	var locais:=sala(editor.planta,origem)
	if locais.is_empty():
		editor.aviso.emit("Escolha uma área de piso dentro do terreno.")
		return 0
	return aplicar(editor,locais)

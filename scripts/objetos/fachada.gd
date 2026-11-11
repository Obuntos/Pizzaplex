class_name FachadaPlex
extends RefCounted

static func estado(planta: PlantaPlex, item: Dictionary) -> String:
	if not str(item.tipo).begins_with("janela"): return str(item.get("estado", ""))
	var frente := GradePlex.frente(item.rotacao)
	var lado := Vector2i(frente.y, -frente.x)
	var antes := false
	var depois := false
	var ocupadas := planta.celulas(item.tipo, item.celula, item.rotacao)
	for celula in ocupadas:
		for sinal in [-1, 1]:
			var vizinha: Vector2i = celula + lado * sinal
			if ocupadas.has(vizinha): continue
			var outro := planta.em(vizinha)
			if str(outro.get("tipo", "")).begins_with("janela") and int(outro.rotacao) % 2 == int(item.rotacao) % 2:
				if sinal < 0: antes = true
				else: depois = true
	return "meio" if antes and depois else "inicio" if depois else "fim" if antes else "isolada"

static func corrigir_decoracao(planta: PlantaPlex) -> void:
	var estantes: Array = planta.objetos.values().filter(func(o): return CatalogoPlex.base(o.tipo)=="estante")
	for item in planta.objetos.values():
		if not str(item.tipo).begins_with("presente_"): continue
		var pai: int = item.get("sobre",-1)
		if pai<0 or not ApoiosPlex.filhos(planta,pai).any(func(f): return f.tipo in ["terminal_ibm","registradora"]): continue
		var transferido := false
		for estante in estantes:
			var slot := ApoiosPlex.livre(planta,estante.id,item.tipo)
			if slot>=0 and ApoiosPlex.fixar(planta,item.id,estante.id,slot):
				transferido=true
				break
		if transferido: continue
		for d in GradePlex.VIZINHOS:
			var c: Vector2i=item.celula+d
			if planta.transitavel(c) and is_zero_approx(planta.altura(c)):
				item.sobre=-1
				item.slot=-1
				item.celula=c
				break


static var previas_janelas: Dictionary={}

static func recortar_janela(base: Dictionary, tipo: String, rotacao: int) -> Dictionary:
	var largura:=int(CatalogoPlex.objetos[tipo].get("largura",1))
	var normal:=GradePlex.frente(rotacao)
	var lado:=Vector2(normal.y,-normal.x)
	var pontos:=PackedVector3Array()
	var cores:=PackedColorArray()
	var faces:=PackedColorArray()
	var previa:=Image.create_empty(base.textura.get_width(),base.textura.get_height(),false,Image.FORMAT_RGBA8)
	for i in base.pontos.size():
		var p: Vector3=base.pontos[i]
		if not is_finite(p.z) or p.z<=-9000.0: continue
		var z: float=(p.z-p.y*2.0)/3.0
		var u:=GradePlex.inverter_local(Vector2(p.x,p.y+z)).dot(lado)
		var vao:=z>28.0 and z<85.0 and absf(u)<float(largura)*.5-.11
		if vao: continue
		pontos.append(p);cores.append(base.cores[i]);faces.append(base.superficies[i])
		var pixel:=Vector2i(roundi(p.x)-int(base.origin[0]),roundi(p.y)-int(base.origin[1]))
		if Rect2i(Vector2i.ZERO,previa.get_size()).has_point(pixel): previa.set_pixelv(pixel,base.cores[i])
	var resultado:=base.duplicate()
	resultado.pontos=pontos;resultado.cores=cores;resultado.superficies=faces;resultado.textura=ImageTexture.create_from_image(previa)
	return resultado

static func previa_janela(tipo: String, rotacao: int, acabamento: String, nivel: int) -> Texture2D:
	var chave:=str([tipo,rotacao,acabamento,nivel])
	if not previas_janelas.has(chave):
		var volume:=GeometriaPlex.obter(tipo,rotacao,nivel,0,false,acabamento)
		var imagem:=Image.create_empty(192,192,false,Image.FORMAT_RGBA8)
		var fonte:=SilhuetasPlex.imagem(volume.textura)
		if fonte!=null: imagem.blit_rect(fonte,Rect2i(Vector2i.ZERO,fonte.get_size()),Vector2i(int(volume.origin[0])+96,int(volume.origin[1])+144))
		previas_janelas[chave]=ImageTexture.create_from_image(imagem)
	return previas_janelas[chave]

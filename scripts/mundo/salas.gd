class_name SalasPlex
extends RefCounted

const ESTRUTURA = ["parede", "porta", "porta_dupla", "porta_principal", "porta_servico", "parede_fachada", "janela", "janela_2", "janela_3"]

static func ambiente_com_portas(planta: PlantaPlex, salas: Dictionary) -> Dictionary:
	var resultado := salas.duplicate()
	for porta in planta.objetos.values():
		if porta.tipo not in CatalogoPlex.PORTAS: continue
		var ocupadas := planta.celulas(porta.tipo, porta.celula, porta.rotacao)
		var frente := GradePlex.frente(porta.rotacao)
		var interna := false
		for celula in ocupadas:
			interna = interna or salas.has(celula + frente) or salas.has(celula - frente)
		if interna:
			for celula in ocupadas:
				resultado[celula] = true
	return resultado

static func mapa_ambiente(salas: Dictionary) -> Image:
	var dados:=PackedByteArray()
	dados.resize(GradePlex.TAMANHO.x*GradePlex.TAMANHO.y*4)
	for c in salas:
		if GradePlex.dentro(c): dados[(c.y*GradePlex.TAMANHO.x+c.x)*4+1]=255
		for dy in range(-1,2):
			for dx in range(-1,2):
				var vizinha: Vector2i=c+Vector2i(dx,dy)
				if GradePlex.dentro(vizinha): dados[(vizinha.y*GradePlex.TAMANHO.x+vizinha.x)*4+2]=255
	return Image.create_from_data(GradePlex.TAMANHO.x,GradePlex.TAMANHO.y,false,Image.FORMAT_RGBA8,dados)

static func fechadas(planta: PlantaPlex) -> Dictionary:
	var largura:=GradePlex.TAMANHO.x
	var altura:=GradePlex.TAMANHO.y
	var estados:=PackedByteArray()
	estados.resize(largura*altura)
	for c in planta.ocupacao:
		if planta.em(c).get("tipo","") in ESTRUTURA: estados[c.y*largura+c.x]=1
	var fila:=PackedInt32Array()
	fila.resize(largura*altura)
	var fim:=0
	for y in altura:
		for x in largura:
			if x!=0 and y!=0 and x!=largura-1 and y!=altura-1: continue
			var i:=y*largura+x
			if estados[i]!=0: continue
			estados[i]=2;fila[fim]=i;fim+=1
	var indice:=0
	while indice<fim:
		var atual:=fila[indice];indice+=1
		var x:=atual%largura
		for d in [1,largura,-1,-largura]:
			var proxima: int=atual+d
			if proxima<0 or proxima>=estados.size() or (d==1 and x==largura-1) or (d==-1 and x==0) or estados[proxima]!=0: continue
			estados[proxima]=2;fila[fim]=proxima;fim+=1
	var resultado: Dictionary = {}
	for i in estados.size():
		if estados[i]==0: resultado[Vector2i(i%largura,floori(float(i)/largura))]=true
	return resultado



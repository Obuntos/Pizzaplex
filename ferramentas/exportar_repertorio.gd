extends SceneTree
var visuais: Dictionary = {}

func _init() -> void:
	call_deferred("executar")

func exportar(tipo: String, rotacao: int, nivel: int = 4, mascara: int = 0, aberta: bool = false, estado: String = "") -> void:
	var volume := GeometriaPlex.obter(tipo,rotacao,nivel,mascara,aberta,estado)
	var pontos: PackedVector3Array = volume.pontos
	var minimo := Vector2i(10000,10000)
	var maximo := Vector2i(-10000,-10000)
	for ponto in pontos:
		minimo = minimo.min(Vector2i(ponto.x,ponto.y))
		maximo = maximo.max(Vector2i(ponto.x,ponto.y))
	var tamanho := maximo-minimo+Vector2i.ONE
	var imagem := Image.create_empty(tamanho.x,tamanho.y,false,Image.FORMAT_RGBA8)
	var profundidade := PackedFloat32Array()
	profundidade.resize(tamanho.x*tamanho.y)
	profundidade.fill(-10000)
	for i in pontos.size():
		var ponto := pontos[i]
		var x := int(ponto.x)-minimo.x
		var y := int(ponto.y)-minimo.y
		var indice := y*tamanho.x+x
		if ponto.z < profundidade[indice]-.05: continue
		profundidade[indice] = ponto.z
		var cor: Color = volume.cores[i]
		if cor.a < 1: cor = imagem.get_pixel(x,y).blend(cor)
		imagem.set_pixel(x,y,cor)
	var chave := ":".join([tipo,str(rotacao),str(nivel),str(mascara),str(int(aberta)),estado])
	visuais[chave] = {"png":Marshalls.raw_to_base64(imagem.save_png_to_buffer()),"depth":Marshalls.raw_to_base64(profundidade.to_byte_array()),"w":tamanho.x,"h":tamanho.y,"x":minimo.x,"y":minimo.y}

func executar() -> void:
	CatalogoPlex.carregar()
	for tipo in CatalogoPlex.objetos:
		if tipo in ["chao","parede","porta","porta_dupla","luz_teto","luz_parede","luz_chao","pose"]: continue
		var estados: Array = CatalogoPlex.objetos[tipo].get("estados",[""])
		for r in 4:
			for estado in estados: exportar(tipo,r,4,0,false,estado)
	for mascara in range(1,16): exportar("palco",0,4,mascara)
	for r in 4:
		for mascara in range(1,4): exportar("escada",r,4,mascara)
	for nivel in range(1,5):
		for mascara in 16: exportar("parede",0,nivel,mascara)
		for r in 4:
			for tipo in ["porta","porta_dupla"]:
				for mascara in 4:
					for aberta in [false,true]: exportar(tipo,r,nivel,mascara,aberta)
	var argumentos := OS.get_cmdline_user_args()
	var destino := argumentos[0] if not argumentos.is_empty() else "user://visuais.js"
	FileAccess.open(destino,FileAccess.WRITE).store_string("window.PlexSalaVisuais="+JSON.stringify(visuais)+";\n")
	print("Visuais exportados: ",visuais.size())
	quit()

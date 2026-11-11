class_name PisosCidadePlex
extends Node2D
var bairro: Node2D
var grupos: Dictionary = {}
var assinatura := ""
var instancias := 0
var atlas_estacao := ""
var atlas: ImageTexture
var recortes: Dictionary = {}
var mesh: ArrayMesh
var atuais: Dictionary = {}
var neves: Array[MultiMeshInstance2D] = []
func malha() -> ArrayMesh:
	if mesh!=null: return mesh
	mesh=ArrayMesh.new()
	var dados: Array=[];dados.resize(Mesh.ARRAY_MAX)
	dados[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-.5,-.5,0),Vector3(.5,-.5,0),Vector3(.5,.5,0),Vector3(-.5,.5,0)])
	dados[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
	dados[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,dados)
	return mesh
func preparar_atlas(estacao: String) -> void:
	if atlas_estacao==estacao: return
	atlas_estacao=estacao
	var arquivos: Dictionary={}
	var tipos: Dictionary={}
	for piso in bairro.mapa.pisos: tipos[str(piso[2])]=true
	for tipo in tipos:
		for r in 4:
			arquivos[bairro.quadro(tipo,estacao,r).arquivo]=true
			if bairro.catalogo[tipo].sprites.has("neve"): arquivos[bairro.catalogo[tipo].sprites.neve[r].arquivo]=true
	var chaves: Array=arquivos.keys();chaves.sort()
	var imagens: Dictionary={}
	var slot:=Vector2i.ZERO
	for arquivo in chaves:
		var imagem:=CatalogoPlex.imagem(arquivo)
		imagens[arquivo]=imagem
		slot=slot.max(imagem.get_size()+Vector2i(4,4))
	var colunas:=ceili(sqrt(float(chaves.size())))
	var linhas:=ceili(float(chaves.size())/maxi(1,colunas))
	var tamanho:=Vector2i(colunas,linhas)*slot
	var imagem_atlas:=Image.create_empty(tamanho.x,tamanho.y,false,Image.FORMAT_RGBA8)
	recortes.clear()
	for i in chaves.size():
		var arquivo: String=chaves[i]
		var origem:=Vector2i(i%colunas,floori(float(i)/colunas))*slot+Vector2i(2,2)
		var imagem: Image=imagens[arquivo]
		imagem_atlas.blit_rect(imagem,Rect2i(Vector2i.ZERO,imagem.get_size()),origem)
		recortes[arquivo]={"tamanho":Vector2(imagem.get_size()),"uv":Color(float(origem.x)/tamanho.x,float(origem.y)/tamanho.y,float(imagem.get_width())/tamanho.x,float(imagem.get_height())/tamanho.y)}
	atlas=ImageTexture.create_from_image(imagem_atlas)
func grupo(chave: String, textura: Texture2D, camada: int, opacidade: float) -> MultiMeshInstance2D:
	if not grupos.has(chave):
		var desenho:=MultiMeshInstance2D.new()
		desenho.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;desenho.use_parent_material=true
		desenho.z_index=camada
		var lote:=MultiMesh.new();lote.transform_format=MultiMesh.TRANSFORM_2D;lote.use_custom_data=true;lote.mesh=malha()
		desenho.multimesh=lote
		add_child(desenho);grupos[chave]=desenho
	var resultado: MultiMeshInstance2D=grupos[chave]
	resultado.texture=textura;resultado.modulate=Color(1,1,1,opacidade);resultado.visible=opacidade>0.0
	atuais[chave]=true
	if camada%2==1: neves.append(resultado)
	return resultado
func atualizar() -> void:
	if bairro==null or not bairro.ativo: return
	var estacao: String=bairro.jogo.calendario.variacao()
	if estacao=="neve": estacao="padrao"
	var nova:=str([GradePlex.visao,estacao,bairro.jogo.planta.terrenos_adquiridos])
	if assinatura==nova:
		for desenho in neves:
			desenho.modulate=Color(1,1,1,bairro.cobertura_neve);desenho.visible=bairro.cobertura_neve>0.0
		return
	assinatura=nova;instancias=0;atuais.clear();neves.clear()
	for desenho in grupos.values(): desenho.hide()
	preparar_atlas(estacao)
	var filas: Dictionary={}
	for piso in bairro.mapa.pisos:
		if TerrenoPlex.contem(bairro.jogo.planta,Vector2i(piso[0],piso[1])): continue
		var ponto:=GradePlex.projetar(Vector2(piso[0],piso[1]))
		var ordem:=roundi(ponto.y)
		if not filas.has(ordem): filas[ordem]=[]
		filas[ordem].append({"piso":piso,"ponto":ponto})
	var ordens: Array=filas.keys();ordens.sort()
	for camada in 2:
		var registros: Array=[]
		for ordem in ordens:
			for registro in filas[ordem]:
				var tipo:=str(registro.piso[2]);var info: Dictionary=bairro.catalogo[tipo]
				var r:=posmod(GradePlex.visao+int(info.rotacaoBase),4)
				if camada==1 and not info.sprites.has("neve"): continue
				var quadro: Dictionary=info.sprites.neve[r] if camada==1 else bairro.quadro(tipo,estacao,r)
				registros.append({"quadro":quadro,"ponto":registro.ponto})
		var desenho:=grupo("pisos:"+str(camada),atlas,camada,bairro.cobertura_neve if camada==1 else 1.0)
		desenho.multimesh.instance_count=registros.size()
		for i in registros.size():
			var quadro: Dictionary=registros[i].quadro;var recorte: Dictionary=recortes[quadro.arquivo]
			var ponto: Vector2=(registros[i].ponto+Vector2(quadro.origem[0],quadro.origem[1])).round()+recorte.tamanho*.5
			desenho.multimesh.set_instance_transform_2d(i,Transform2D(0,recorte.tamanho,0,ponto))
			desenho.multimesh.set_instance_custom_data(i,recorte.uv)
		instancias+=registros.size()
	for item in bairro.mapa.objetos:
		var tipo:=str(item[0])
		if CompraTerrenosPlex.substituido(bairro.jogo.planta,tipo) or not bairro.catalogo.has(tipo) or bairro.catalogo[tipo].chao.is_empty(): continue
		var info: Dictionary=bairro.catalogo[tipo];var r:=posmod(GradePlex.visao+int(item[3]),4)
		for camada in 2:
			if camada==1 and not info.chao.has("neve"): continue
			var quadro: Dictionary=info.chao.neve[r] if camada==1 else bairro.quadro(tipo,estacao,r,"chao")
			var textura:=CatalogoPlex.textura(quadro.arquivo);var tamanho:=Vector2(textura.get_size())
			var desenho:=grupo("base:"+str(item)+":"+str(camada),textura,camada+2,bairro.cobertura_neve if camada==1 else 1.0)
			desenho.multimesh.instance_count=1
			var ponto: Vector2=(GradePlex.projetar(bairro.ancora(item))+Vector2(quadro.origem[0],quadro.origem[1])).round()+tamanho*.5
			desenho.multimesh.set_instance_transform_2d(0,Transform2D(0,tamanho,0,ponto));desenho.multimesh.set_instance_custom_data(0,Color(0,0,1,1))
			instancias+=1

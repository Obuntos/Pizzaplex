class_name ViVisuaisPlex
extends RefCounted

static var cache:Dictionary={}
static func volume(item:Dictionary) -> Dictionary:
	var modelo:=str(item.modelo_vi);var indice:=int(item.get("modulo",0));var rotacao:=0
	var vazia:bool=indice==2 and modelo!="vi_patitas" and not item.get("olhos_configurados",false)
	var chave:=str([modelo,indice,rotacao,vazia])
	if cache.has(chave):return cache[chave]
	var arquivo:="res://assets/sistemas/vi/"+("patitas" if modelo=="vi_patitas" else "orelhitas")+"/modulos/"+str(indice)+("_vazia" if vazia else "")+"/"+str(rotacao)+".png"
	var textura:=CatalogoPlex.textura(arquivo);var imagem:=CatalogoPlex.imagem(arquivo)
	var pontos:=PackedVector3Array();var cores:=PackedColorArray();var normais:=PackedColorArray()
	for y in imagem.get_height():
		for x in imagem.get_width():
			var cor:=imagem.get_pixel(x,y)
			if cor.a<=0:continue
			var p:=Vector2(x-96,y-144)
			pontos.append(Vector3(p.x,p.y,p.y*2+maxf(0,-p.y)*3));cores.append(cor);normais.append(Color(.5,.5,1,.2))
	var resultado:Dictionary={"image":arquivo,"origin":[-96,-144],"textura":textura,"pontos":pontos,"cores":cores,"superficies":normais}
	cache[chave]=resultado;return resultado

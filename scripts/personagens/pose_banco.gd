class_name PoseBancoPlex
extends RefCounted

static var cache: Dictionary={}

static func ponto(lado: float, frente: float, altura: float, direcao: int, pivo: float) -> Vector2:
	var angulo:=float(direcao)*PI/4.0
	return Vector2(24.0+cos(angulo)*lado+sin(angulo)*frente,pivo+(-sin(angulo)*lado+cos(angulo)*frente)*.5-altura)

static func compor(sentado: Image, em_pe: Image, altura: int, pivo: float) -> Image:
	var resultado:=sentado.duplicate() as Image
	resultado.convert(Image.FORMAT_RGBA8)
	for d in 8:
		var lados: Array=[-2.45,2.45] if sin(d*PI/4.0)<0.0 else [2.45,-2.45]
		for f in 12:
			var origem:=Vector2i(f*48,d*altura)
			resultado.fill_rect(Rect2i(origem+Vector2i(0,int(pivo)-15),Vector2i(48,altura-int(pivo)+15)),Color.TRANSPARENT)
			for lado in lados:
				var fonte: Array[Vector2]=[ponto(lado,0,15,d,pivo),ponto(lado,0,7.5,d,pivo),ponto(lado,0,.4,d,pivo)]
				var destino: Array[Vector2]=[fonte[0],ponto(lado,6.5,14.2,d,pivo),ponto(lado,7,.4,d,pivo)]
				for segmento in 2:
					var inicio:=destino[segmento]
					var delta:=destino[segmento+1]-inicio
					var normal:=Vector2(-delta.y,delta.x).normalized()
					var eixo:=fonte[segmento+1]-fonte[segmento]
					var lateral:=Vector2(-eixo.y,eixo.x).normalized()
					for y in range(int(pivo)-17,altura):
						for x in range(12,36):
							var local:=Vector2(x,y)-inicio
							var t:=local.dot(delta)/delta.length_squared()
							var margem:=.2 if segmento==1 else .08
							var afastamento:=local.dot(normal)
							if t<-.08 or t>1.0+margem or absf(afastamento)>2.6: continue
							var amostra:=Vector2i((fonte[segmento]+eixo*t+lateral*afastamento).round())+origem
							if not Rect2i(origem,Vector2i(48,altura)).has_point(amostra): continue
							var cor:=em_pe.get_pixelv(amostra)
							if cor.a>.15: resultado.set_pixelv(origem+Vector2i(x,y),cor)
	return resultado

static func textura(sentado: String, em_pe: String, altura: int, pivo: float) -> CanvasTexture:
	var chave:=sentado+":"+em_pe
	if cache.has(chave): return cache[chave]
	var base:=CatalogoPlex.textura_iluminada(sentado) as CanvasTexture
	var fonte:=CatalogoPlex.textura_iluminada(em_pe) as CanvasTexture
	var nova:=CanvasTexture.new()
	nova.diffuse_texture=ImageTexture.create_from_image(compor(base.diffuse_texture.get_image(),fonte.diffuse_texture.get_image(),altura,pivo))
	if base.normal_texture!=null and fonte.normal_texture!=null: nova.normal_texture=ImageTexture.create_from_image(compor(base.normal_texture.get_image(),fonte.normal_texture.get_image(),altura,pivo))
	if base.specular_texture!=null and fonte.specular_texture!=null: nova.specular_texture=ImageTexture.create_from_image(compor(base.specular_texture.get_image(),fonte.specular_texture.get_image(),altura,pivo))
	nova.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	cache[chave]=nova
	return nova

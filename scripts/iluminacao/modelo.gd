class_name ModeloLuminariaPlex
extends RefCounted

static var cache: Dictionary={}

static func elipse(img: Image, r: Rect2i, cor: Color) -> void:
	for y in range(maxi(0,r.position.y),mini(img.get_height(),r.end.y)):
		for x in range(maxi(0,r.position.x),mini(img.get_width(),r.end.x)):
			var v:=(Vector2(x,y)+Vector2(.5,.5)-Vector2(r.get_center()))/(Vector2(r.size)*.5)
			if v.length_squared()<=1.0: img.set_pixel(x,y,cor)

static func poligono(img: Image, pontos: PackedVector2Array, cor: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			if Geometry2D.is_point_in_polygon(Vector2(x+.5,y+.5),pontos): img.set_pixel(x,y,cor)

static func textura(tipo: String, rotacao: int=0, ligada: bool=true, corte: bool=false, cor: Color=Color("fff0d5")) -> Texture2D:
	var chave:=str([tipo,rotacao,ligada,corte,cor.to_html()])
	if cache.has(chave): return cache[chave]
	var img:=Image.create_empty(48,48,false,Image.FORMAT_RGBA8)
	var base:=LuminariasPlex.tipo(tipo)
	var barata:=LuminariasPlex.economica(tipo)
	var contorno:=Color("343b41")
	var metal:=Color("88918d") if not barata else Color("797d70")
	var claro:=Color("d8d4b9") if not barata else Color("b5af8b")
	var vidro:=Color("fff4d7").lerp(cor,.28) if ligada else Color("6e7978")
	var vidro_sombra:=Color("e9c985").lerp(cor,.2) if ligada else Color("4e5a5d")
	if base=="luz_parede" and not corte:
		var frente:=Vector2(GradePlex.frente(rotacao))
		var tangente:=Vector2(frente.y,-frente.x)
		var lateral:=GradePlex.projetar_local(tangente*.24)
		var espessura:=GradePlex.projetar_local(frente*.085)
		var centro:=Vector2(24,24)
		var alto:=Vector2(0,11)
		var a:=centro-lateral-alto
		var b:=centro+lateral-alto
		var c:=centro+lateral+alto
		var d:=centro-lateral+alto
		poligono(img,PackedVector2Array([a,b,c,d]),contorno)
		var visivel:=frente.x+frente.y>0.0
		var face:=espessura if visivel else -espessura
		poligono(img,PackedVector2Array([a,b,b+face,a+face]),claro)
		poligono(img,PackedVector2Array([b,c,c+face,b+face]),metal)
		var origem:=centro+face
		poligono(img,PackedVector2Array([origem-lateral-alto,origem+lateral-alto,origem+lateral+alto,origem-lateral+alto]),contorno)
		poligono(img,PackedVector2Array([origem-lateral*.82-alto*.86,origem+lateral*.82-alto*.86,origem+lateral*.82+alto*.86,origem-lateral*.82+alto*.86]),metal)
		if visivel:
			poligono(img,PackedVector2Array([origem-lateral*.6-alto*.7,origem+lateral*.6-alto*.7,origem+lateral*.6+alto*.7,origem-lateral*.6+alto*.7]),vidro_sombra)
			poligono(img,PackedVector2Array([origem-lateral*.44-alto*.64,origem+lateral*.44-alto*.64,origem+lateral*.44+alto*.64,origem-lateral*.44+alto*.64]),vidro)
			if barata:
				poligono(img,PackedVector2Array([origem-Vector2(1,8),origem+Vector2(1,-8),origem+Vector2(1,8),origem+Vector2(-1,8)]),metal)
			else:
				img.set_pixel(clampi(roundi(origem.x),0,47),clampi(roundi(origem.y+8),0,47),claro)

	elif base=="luz_teto" and barata:
		elipse(img,Rect2i(16,12,16,9),contorno)
		elipse(img,Rect2i(17,12,14,6),claro)
		img.fill_rect(Rect2i(21,18,6,6),contorno)
		img.fill_rect(Rect2i(22,19,4,5),metal)
		elipse(img,Rect2i(18,21,12,14),contorno)
		elipse(img,Rect2i(19,21,10,11),vidro_sombra)
		elipse(img,Rect2i(20,21,8,7),vidro)
	else:
		var teto:=base=="luz_teto"
		var w:=30 if teto else 16 if not corte else 12
		var h:=16 if teto else 9 if not corte else 7
		var x:=24-floori(w*.5)
		var y:=24-floori(h*.5)
		elipse(img,Rect2i(x,y+3,w,h),contorno)
		elipse(img,Rect2i(x,y+1,w,h),metal)
		elipse(img,Rect2i(x+1,y,w-2,h-1),claro if teto else contorno)
		elipse(img,Rect2i(x+3,y+2,w-6,h-4),vidro_sombra)
		elipse(img,Rect2i(x+4,y+2,w-8,maxi(2,h-6)),vidro)
		if not teto:
			img.set_pixel(x+2,24,claro)
			img.set_pixel(x+w-3,24,claro)
		if barata:
			img.fill_rect(Rect2i(23,y+2,2,maxi(2,h-4)),metal)
		elif teto:
			img.set_pixel(x+3,25,contorno)
			img.set_pixel(x+w-4,24,contorno)
	var textura_nova:=ImageTexture.create_from_image(img)
	cache[chave]=textura_nova
	return textura_nova

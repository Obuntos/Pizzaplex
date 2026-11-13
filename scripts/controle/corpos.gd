class_name CorposPlex
extends RefCounted

var referencia: WeakRef
var controle: ControleAdministradorPlex:
	get: return referencia.get_ref()
var visuais: Dictionary = {}
var visuais_tras: Dictionary = {}
var retratos: Dictionary = {}
var retratos_direcoes: Dictionary = {}
var anatomia: Dictionary = {}
var dobrados: Dictionary = {}
var pivos: Dictionary = {}
var visao := -1
var arma_pivo: Node2D
var arma: Sprite2D
var arma_chave:=""

func _init(c: ControleAdministradorPlex) -> void:
	referencia=weakref(c)

func material() -> ShaderMaterial:
	var mat:=ShaderMaterial.new()
	mat.shader=load("res://shaders/objeto_manual.gdshader")
	mat.set_shader_parameter("profundidade_cena",controle.jogo.composicao.profundidade)
	mat.set_shader_parameter("origem",Vector2(CenaPlex.ORIGEM))
	mat.set_shader_parameter("tamanho",Vector2(CenaPlex.TAMANHO))
	controle.jogo.iluminacao.vincular(mat)
	return mat

func retratar(a: PersonagemPlex, direcao: int = -1) -> Texture2D:
	var original:=a.direcao
	var visual:=GradePlex.direcao_visual(original) if direcao<0 else direcao
	var chave:=str(a.identificador)+":"+str([a.modelo,AparenciaPlex.roupa(a),RoupasVisitantesPlex.pasta(a),AparenciaPlex.cabelo(a),CoresCabeloPlex.cor(a),visual])
	if retratos_direcoes.has(chave): return retratos_direcoes[chave]
	a.direcao=posmod(visual+GradePlex.visao*2,8)
	var imagem:=Image.create_empty(112,128,false,Image.FORMAT_RGBA8)
	var antes:=a.visible
	a.visible=true
	a.assento=-1
	a.atualizar_visual(false)
	for fonte in a.pintura.fontes:
		var s: Sprite2D=fonte.sprite
		if s.texture==null or s in [a.manuseio.objeto,a.manuseio.objeto_extra,a.carga]: continue
		var tex: Texture2D=s.texture
		var regiao:=Rect2i(Vector2i.ZERO,Vector2i(tex.get_size()))
		if tex is AtlasTexture:
			regiao=Rect2i(tex.region)
			tex=tex.atlas
		if tex is CanvasTexture: tex=tex.diffuse_texture
		if tex==null: continue
		var im:=tex.get_image().get_region(regiao)
		if im==null: continue
		var transformacao:=a.visual.global_transform.affine_inverse()*s.global_transform
		var offset:=s.offset-(Vector2(im.get_size())*.5 if s.centered else Vector2.ZERO)
		var inversa:=transformacao.affine_inverse()
		var limites:=Rect2(transformacao*offset+Vector2(56,110),Vector2.ZERO)
		for canto in [Vector2(im.get_width(),0),Vector2(0,im.get_height()),Vector2(im.get_size())]: limites=limites.expand(transformacao*(canto+offset)+Vector2(56,110))
		var inicio:=Vector2i(limites.position.floor()).max(Vector2i.ZERO)
		var fim:=Vector2i(limites.end.ceil()).min(imagem.get_size())
		for y in range(inicio.y,fim.y):
			for x in range(inicio.x,fim.x):
				var local:=inversa*(Vector2(x+.5,y+.5)-Vector2(56,110))-offset
				if s.flip_h: local.x=im.get_width()-local.x
				if s.flip_v: local.y=im.get_height()-local.y
				var origem:=Vector2i(local.floor())
				if not Rect2i(Vector2i.ZERO,im.get_size()).has_point(origem): continue
				var c:=im.get_pixelv(origem)
				if c.a>.05: imagem.set_pixel(x,y,imagem.get_pixel(x,y).blend(c))
	a.visible=antes
	a.direcao=original
	var usado:=imagem.get_used_rect()
	if not usado.has_area(): return null
	var resultado:=ImageTexture.create_from_image(imagem.get_region(usado))
	anatomia[resultado.get_instance_id()]={"quadril":Vector2(56,110-15*a.animacao.scale.y)-Vector2(usado.position),"joelho":Vector2(56,110-8*a.animacao.scale.y)-Vector2(usado.position),"escala":a.animacao.scale}
	retratos_direcoes[chave]=resultado
	return resultado

func criar(a: PersonagemPlex) -> Sprite2D:
	var s:=Sprite2D.new()
	s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	s.texture=retratar(a)
	retratos[a.identificador]=s.texture
	s.rotation=-PI*.5
	s.scale=Vector2.ONE
	s.material=material()
	var pivo:=Node2D.new()
	controle.jogo.mundo.add_child(pivo)
	pivo.add_child(s)
	pivos[a.identificador]=pivo
	visuais[a.identificador]=s
	var tras:=Sprite2D.new()
	tras.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	tras.centered=false
	tras.material=s.material
	tras.hide()
	pivo.add_child(tras)
	visuais_tras[a.identificador]=tras
	return s

func pegar(a: PersonagemPlex) -> bool:
	var admin:=controle.administrador()
	if not controle.manual() or not is_instance_valid(a) or not a.visita.get("morto",false) or int(a.visita.get("carregado_por",-1))>0 or int(a.visita.get("oculto_em",-1))>0: return false
	if int(admin.visita.get("corpo_carregado",-1))>0: return false
	admin.visita.corpo_carregado=a.identificador
	admin.visita.faca_equipada=false
	a.visita.carregado_por=admin.identificador
	a.visible=false
	controle.aviso("Corpo carregado. Botão direito no chão para soltar ou em um animatrônico para colocar nele.")
	return true

func soltar() -> bool:
	var admin:=controle.administrador()
	if not is_instance_valid(admin): return false
	var a:=controle.ator(int(admin.visita.get("corpo_carregado",-1)))
	admin.visita.erase("corpo_carregado")
	if not is_instance_valid(a): return false
	a.visita.erase("carregado_por")
	a.visita.erase("oculto_em")
	a.local=admin.local
	a.celula=admin.celula
	a.altura=admin.altura
	return true

func ocultar(robo: PersonagemPlex) -> bool:
	var admin:=controle.administrador()
	if not controle.manual() or not is_instance_valid(robo) or not robo.robo or int(robo.visita.get("corpo_oculto",-1))>0: return false
	var a:=controle.ator(int(admin.visita.get("corpo_carregado",-1)))
	if not is_instance_valid(a) or not controle.jogo.atracoes.permite_corpo(robo,a):return false
	robo.visita.corpo_oculto=a.identificador
	robo.robotica.assombrado=true;robo.robotica.contaminacao=0.0;robo.robotica.cheiro=0.0
	a.visita.oculto_em=robo.identificador
	a.visita.erase("carregado_por")
	a.local=robo.local
	a.celula=robo.celula
	a.altura=robo.altura
	admin.visita.erase("corpo_carregado")
	if visuais.has(a.identificador): visuais[a.identificador].hide()
	if visuais_tras.has(a.identificador): visuais_tras[a.identificador].hide()
	controle.aviso("Corpo colocado no animatrônico.")
	return true

func apontado(ponto: Vector2) -> PersonagemPlex:
	for id in visuais:
		var s: Sprite2D=visuais[id]
		if not s.visible or s.texture==null: continue
		var local:=s.to_local(ponto)
		if s.get_rect().has_point(local): return controle.ator(id)
	return null

func atualizar_arma(admin: PersonagemPlex) -> void:
	if is_instance_valid(admin) and admin.modelo in ["humano","humana","fantasia_coelho"]:
		if is_instance_valid(arma): arma.hide()
		if admin.has_meta("arma_visual"): admin.remove_meta("arma_visual")
		return
	if not is_instance_valid(admin):
		if is_instance_valid(arma): arma.hide()
		return
	if not is_instance_valid(arma):
		arma=Sprite2D.new()
		arma.centered=false
		arma.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		arma.material=material()
		arma_pivo=Node2D.new()
		controle.jogo.mundo.add_child(arma_pivo)
		arma_pivo.add_child(arma)
	arma.visible=is_instance_valid(admin) and controle.manual() and bool(admin.visita.get("faca_equipada",false))
	if not arma.visible: return
	var tipo:=str(admin.visita.get("faca_tipo","cenario_faca_cozinha"))
	var chave:=tipo
	if chave!=arma_chave:
		arma_chave=chave
		var origem_arma:=CatalogoPlex.sprite(tipo,0)
		var atlas:=CatalogoPlex.atlas_vazio()
		atlas.atlas=origem_arma
		atlas.region=Rect2(origem_arma.get_image().get_used_rect())
		arma.texture=atlas
		arma.scale=Vector2.ONE*(11.0/maxf(atlas.region.size.x,atlas.region.size.y))
	var mao:=Vector2(admin.postura_manual.punhos[1].x,admin.postura_manual.punhos[1].y) if admin.postura_manual.punhos.size()==2 else Vector2(0,-18)
	arma_pivo.position=admin.position
	arma.position=admin.visual.position+mao
	arma.offset=Vector2(-arma.texture.get_width()*.18,-arma.texture.get_height()*.10)
	arma.rotation=admin.postura_manual.angulo_faca
	arma.material.set_shader_parameter("altura",maxf(2.0,admin.altura-mao.y))
	admin.set_meta("arma_visual",arma)

func atualizar() -> void:
	var administrador:=controle.administrador()
	if is_instance_valid(administrador):
		var modo:="corpo" if int(administrador.visita.get("corpo_carregado",-1))>0 else "faca" if administrador.visita.get("controle_manual",false) and administrador.visita.get("faca_equipada",false) else ""
		if administrador.postura_manual.modo_atual!=modo: administrador.atualizar_visual(administrador.ocupado())
	var mudou:=visao!=GradePlex.visao
	visao=GradePlex.visao
	var presentes: Dictionary={}
	for a in controle.jogo.personagens:
		if not a.visita.get("morto",false) or a.visita.get("em_ataque",false): continue
		presentes[a.identificador]=true
		var s: Sprite2D=visuais.get(a.identificador)
		if not is_instance_valid(s): s=criar(a)
		elif mudou: retratos[a.identificador]=retratar(a)
		var tras: Sprite2D=visuais_tras[a.identificador]
		tras.hide()
		a.visible=false
		s.visible=int(a.visita.get("oculto_em",-1))<0 and not controle.jogo.sistemas.ataques.ocultar_padrao(a)
		var dono:=controle.ator(int(a.visita.get("carregado_por",-1)))
		var altura: float=a.altura+4.0
		if is_instance_valid(dono):
			a.local=dono.local
			a.celula=dono.celula
			a.altura=dono.altura
			altura=dono.altura+dono.postura_manual.ponto_carga.z
		pivos[a.identificador].position=GradePlex.projetar(a.local)+Vector2(0,-.1 if is_instance_valid(dono) and GradePlex.direcao_visual(dono.direcao) in [3,4,5] else .1)
		if is_instance_valid(dono):
			var lado:=GradePlex.direcao_visual(dono.direcao)
			s.centered=false
			s.flip_v=false
			s.flip_h=false
			if CorpoArticuladoPlex.aceita(a):
				var partes:=CorpoArticuladoPlex.camadas(a,lado)
				var centro: Vector2=partes.centro
				s.texture=partes.frente
				tras.texture=partes.tras
				s.rotation=0
				s.scale=a.animacao.scale
				s.position=dono.visual.position+Vector2(dono.postura_manual.ponto_carga.x,dono.postura_manual.ponto_carga.y)-centro*s.scale
				tras.position=s.position
				tras.scale=s.scale
				tras.visible=s.visible
				dono.set_meta("corpo_visual_tras",tras)
			else:
				var angulo:=float(lado)*PI/4.0
				s.texture=dobrar(retratar(a,lado))
				s.rotation=atan2(-sin(angulo)*.5-.08,cos(angulo))
				s.scale=Vector2.ONE
				s.position=dono.visual.position+Vector2(dono.postura_manual.ponto_carga.x,dono.postura_manual.ponto_carga.y)-Vector2(80,64).rotated(s.rotation)
				if dono.has_meta("corpo_visual_tras"): dono.remove_meta("corpo_visual_tras")
			dono.set_meta("corpo_visual",s)
		else:
			s.centered=true
			s.texture=retratos[a.identificador]
			s.rotation=-PI*.5
			s.flip_h=false
			s.flip_v=false
			s.scale=Vector2.ONE
			s.position=Vector2(0,-altura)
			s.visibility_layer=1
		s.material.set_shader_parameter("altura",altura)
	for id in visuais.keys():
		if not presentes.has(id):
			pivos[id].queue_free()
			pivos.erase(id)
			visuais.erase(id)
			visuais_tras.erase(id)
			retratos.erase(id)
			for chave in retratos_direcoes.keys():
				if not str(chave).begins_with(str(id)+":"): continue
				var fonte: Texture2D=retratos_direcoes[chave]
				dobrados.erase(fonte.get_instance_id())
				anatomia.erase(fonte.get_instance_id())
				retratos_direcoes.erase(chave)
	var admin:=controle.administrador()
	atualizar_arma(admin)
	if is_instance_valid(admin): admin.pintura.atualizar(admin)

func limpar() -> void:
	for p in pivos.values(): p.queue_free()
	pivos.clear()
	visuais.clear()
	visuais_tras.clear()
	retratos.clear()
	retratos_direcoes.clear()
	anatomia.clear()
	dobrados.clear()
	if is_instance_valid(arma_pivo): arma_pivo.queue_free()
	arma_pivo=null
	arma=null
	arma_chave=""
	visao=-1

func dobrar(fonte: Texture2D) -> Texture2D:
	if fonte==null: return null
	var id:=fonte.get_instance_id()
	if dobrados.has(id): return dobrados[id]
	var im:=fonte.get_image()
	var desenho:=Image.create_empty(160,128,false,Image.FORMAT_RGBA8)
	var corpo: Dictionary=anatomia[id]
	var apoio: Vector2=corpo.quadril-Vector2(0,3*corpo.escala.y)
	var joelho: Vector2=corpo.joelho
	for parte in 2:
		var angulo: float=-PI*.5 if parte==0 else -PI*.38
		var origem:=Vector2(80,64) if parte==0 else Vector2(80+joelho.y-apoio.y,64)
		var pivo: Vector2=apoio if parte==0 else joelho
		for y in 128:
			for x in 160:
				var p:=(Vector2(x+.5,y+.5)-origem).rotated(-angulo)+pivo
				if (parte==0 and p.y>joelho.y+.5) or (parte==1 and p.y<joelho.y-.5): continue
				var q:=Vector2i(p.floor())
				if not Rect2i(Vector2i.ZERO,im.get_size()).has_point(q): continue
				var cor:=im.get_pixelv(q)
				if cor.a>.1: desenho.set_pixel(x,y,cor)
	var resultado:=ImageTexture.create_from_image(desenho)
	dobrados[id]=resultado
	return resultado



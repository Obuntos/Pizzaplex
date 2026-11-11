class_name MapaSegurancaPlex
extends Control
var jogo:Node
var tempo:=0.0
var espera:=0.0
var pontos:Array=[]
var salas_rotulos:Array=[]
var tempo_salas:=0.0
var revisao:=-1
var minimo:=Vector2.ZERO
var extensao:=Vector2.ONE
func _ready() -> void:mouse_filter=Control.MOUSE_FILTER_PASS;custom_minimum_size=Vector2(410,280);recalcular()
func recalcular() -> void:
	if jogo==null or revisao==jogo.planta.revisao:return
	revisao=jogo.planta.revisao;pontos.clear()
	var area:=TerrenoPlex.area(jogo.planta);minimo=Vector2(area.position)-Vector2(.5,.5);extensao=Vector2(area.size)
	for o in jogo.planta.objetos.values():
		if TerrenoPlex.contem(jogo.planta,o.celula):pontos.append(o)
func escala() -> float:return minf((size.x-24)/extensao.x,(size.y-24)/extensao.y)
func lugar(c:Vector2) -> Vector2:return (size-extensao*escala())*.5+(c-minimo)*escala()
func retangulo(o:Dictionary) -> Rect2:return Rect2(lugar(Vector2(o.celula)-Vector2(.5,.5)),Vector2(CatalogoPlex.dimensoes(str(o.tipo),int(o.rotacao)))*escala())
func atores_localizados() -> Array:
	var lista:Array=[]
	for a in jogo.personagens:
		if a.visita.get("morto",false) or a.visita.get("fora_turno",false) or not a.visible or not TerrenoPlex.contem(jogo.planta,a.celula):continue
		var filmado:bool=jogo.sistemas.investigacao.filmado(a.local)
		if a.robo or a.funcao=="seguranca" or filmado:lista.append({"ator":a,"filmado":filmado,"p":lugar(a.local)})
	return lista
func _process(delta:float) -> void:
	tempo+=delta;espera+=delta;tempo_salas+=delta
	if tempo_salas>=1.0:tempo_salas=0;rotular_salas()
	if espera>=.2:espera=0;recalcular();queue_redraw()
func _draw() -> void:
	var verde:=Color("8ca58a");draw_rect(Rect2(Vector2.ZERO,size),Color("09130c"));draw_rect(Rect2(Vector2.ZERO,size),verde,false,1)
	if jogo==null:return
	for sala in jogo.ambientes.ambientes:
		if not sala.get("fechada",false):continue
		for c in sala.celulas:
			if TerrenoPlex.contem(jogo.planta,c):draw_rect(Rect2(lugar(Vector2(c)-Vector2(.5,.5)),Vector2.ONE*escala()),Color("203024"))
	for o in pontos:
		var r:=retangulo(o);var tipo:=str(o.tipo)
		if tipo in CatalogoPlex.PORTAS:draw_rect(r.grow(-1),Color("527662") if o.get("aberta",false) else Color("ce9a62"))
		elif CatalogoPlex.base(tipo)=="parede":draw_rect(r.grow(-1),verde)
		elif MobiliaPlex.dados(o).get("camera",false):
			var p:=lugar(CamerasVigilanciaPlex.lente(o));draw_circle(p,3,Color("75aaa8"));draw_line(p,p+CamerasVigilanciaPlex.frente(o)*11,Color("75aaa8"),1)
			if jogo.sistemas.guarda.camera_vigiada(int(o.id)):draw_arc(p,7+sin(tempo*5),0,TAU,16,Color("dfb16a"),2);draw_string(ThemeDB.fallback_font,p+Vector2(-40,-10),"AO VIVO",HORIZONTAL_ALIGNMENT_CENTER,80,10,Color("dfb16a"))
	for sala in salas_rotulos:
		var p:Vector2=sala.p
		if not sala.coberta:
			for c in sala.celulas:draw_rect(Rect2(lugar(Vector2(c)-Vector2(.5,.5)),Vector2.ONE*escala()),Color(1,.17,.13,.06+.07*(sin(tempo*3)+1)*.5))
		draw_string(ThemeDB.fallback_font,p-Vector2(50,0),sala.nome,HORIZONTAL_ALIGNMENT_CENTER,100,11,Color("d2ddcc"))
	for d in atores_localizados():
		var a:PersonagemPlex=d.ator;var p:Vector2=d.p
		if a.robo:
			if not d.filmado or fmod(tempo,.9)<.55:draw_rect(Rect2(p-Vector2(4,4),Vector2(8,8)),Color("d7d087") if d.filmado else Color("53634f"))
		elif a.funcao=="seguranca":draw_colored_polygon(PackedVector2Array([p+Vector2(0,-4),p+Vector2(4,0),p+Vector2(0,4),p+Vector2(-4,0)]),Color("b7cacb"))
		else:draw_circle(p,3,Color("d4ad80"))

func rotular_salas() -> void:
	salas_rotulos.clear()
	if jogo==null:return
	var numeros:Dictionary={}
	for sala in jogo.ambientes.ambientes:
		if not sala.get("fechada",false) or sala.celulas.is_empty():continue
		var tipo:=str(sala.tipo);numeros[tipo]=int(numeros.get(tipo,0))+1
		var nome:String={"oficina":"Manutenção","cozinha":"Cozinha","salao":"Salão","salao_festas":"Festas","vestiario":"Vestiário","descanso":"Sala de descanso","deposito":"Depósito","escritorio":"Escritório","banheiro":"Banheiro"}.get(tipo,tipo.capitalize())
		var centro:=Vector2.ZERO;var coberta:=false
		for c in sala.celulas:
			centro+=Vector2(c)
			if not coberta and jogo.sistemas.investigacao.filmado(Vector2(c)):coberta=true
		if tipo=="banheiro":coberta=CamerasVigilanciaPlex.porta_banheiro_coberta(jogo,sala)
		centro/=float(sala.celulas.size());salas_rotulos.append({"nome":nome+" "+str(numeros[tipo]),"p":lugar(centro),"celulas":sala.celulas,"coberta":coberta})

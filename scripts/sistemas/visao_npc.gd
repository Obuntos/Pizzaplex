class_name VisaoNPCPlex
extends RefCounted

const ALCANCE=9.0
const ABERTURA=110.0
static func frente(a:PersonagemPlex) -> Vector2:
	var angulo:=float(a.direcao)*PI/4.0
	return Vector2(cos(angulo)+sin(angulo),cos(angulo)-sin(angulo)).normalized()
static func opaco(planta:PlantaPlex,c:Vector2i) -> bool:
	var o:Dictionary=planta.em(c)
	var tipo:=str(o.get("tipo",""))
	if tipo in CatalogoPlex.PORTAS:return not o.get("aberta",false)
	if tipo in SalasPlex.ESTRUTURA or CatalogoPlex.base(tipo) in SalasPlex.ESTRUTURA or tipo.contains("parede"):return true
	return CatalogoPlex.base(tipo) in ["armario_limpeza","armario_utensilios","armario_ferramentas","armario_roupas","geladeira","estante"] or tipo.contains("armario")
static func linha(planta:PlantaPlex,origem:Vector2,destino:Vector2) -> bool:
	var a:=Vector2i(origem.round());var fim:=Vector2i(destino.round());var d:=destino-origem
	if a==fim:return true
	var passo:=Vector2i(int(signf(d.x)),int(signf(d.y)))
	var incremento:=Vector2(INF if is_zero_approx(d.x) else absf(1.0/d.x),INF if is_zero_approx(d.y) else absf(1.0/d.y))
	var borda:=Vector2(a)+Vector2(.5*passo.x,.5*passo.y)
	var t:=Vector2(INF if passo.x==0 else (borda.x-origem.x)/d.x,INF if passo.y==0 else (borda.y-origem.y)/d.y)
	for _i in 512:
		if is_equal_approx(t.x,t.y):
			if opaco(planta,a+Vector2i(passo.x,0)) or opaco(planta,a+Vector2i(0,passo.y)):return false
			a+=passo;t+=incremento
		elif t.x<t.y:a.x+=passo.x;t.x+=incremento.x
		else:a.y+=passo.y;t.y+=incremento.y
		if a==fim:return true
		if opaco(planta,a):return false
	return false
static func cone(planta:PlantaPlex,origem:Vector2,direcao:Vector2,alvo:Vector2,alcance:float=ALCANCE,abertura:float=ABERTURA) -> bool:
	var vetor:=alvo-origem;var distancia:=vetor.length()
	return distancia<=alcance and (distancia<.25 or direcao.normalized().dot(vetor/distancia)>=cos(deg_to_rad(abertura*.5))) and linha(planta,origem,alvo)
static func ve_ponto(jogo:Node,a:PersonagemPlex,p:Vector2,alcance:float=ALCANCE) -> bool:
	if not is_instance_valid(a) or not a.visible or a.visita.get("morto",false) or a.visita.get("fora_turno",false) or a.trabalho=="contar_esconde":return false
	return cone(jogo.planta,a.local,frente(a),p,alcance)
static func ve(jogo:Node,a:PersonagemPlex,b:PersonagemPlex,alcance:float=ALCANCE) -> bool:
	return is_instance_valid(b) and b.visible and not b.visita.get("fora_turno",false) and ve_ponto(jogo,a,b.local,alcance)

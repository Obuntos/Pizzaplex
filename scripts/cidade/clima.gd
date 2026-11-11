class_name ClimaCidadePlex
extends Node2D

var jogo: Node
var sementes: Array[Vector4] = []
var tempo := 0.0
var espera := 0.0
var desenhados := 0
var respingos: Array[Dictionary] = []
var proximo_respingo := 0.0
var ciclo := 0

func configurar(cena: Node) -> void:
	jogo=cena
	z_index=90
	var sorteio:=RandomNumberGenerator.new()
	sorteio.seed=1958
	for i in 300: sementes.append(Vector4(sorteio.randf(),sorteio.randf(),sorteio.randf(),float(i%3)))

func atualizar(delta: float) -> void:
	tempo+=clampf(delta,.0,.1)
	espera+=delta
	respingos=respingos.filter(func(r): return tempo-float(r.inicio)<.45)
	if jogo.calendario.previsao()!="Chuva": respingos.clear()
	elif tempo>=proximo_respingo and respingos.size()<48:
		proximo_respingo=tempo+.06
		var inversa:=get_canvas_transform().affine_inverse()
		var tela:=get_viewport_rect().size
		for i in 2:
			var s:=sementes[posmod(ciclo,sementes.size())]
			ciclo+=1
			var ponto:=Vector2(s.x*tela.x,s.y*tela.y)
			var local:=GradePlex.inverter(inversa*ponto)
			var celula:=Vector2i(local.round())
			if protegido(ponto,inversa) or jogo.planta.bairro_bloqueios.has(celula) or not jogo.planta.em(celula).is_empty(): continue
			respingos.append({"local":local,"inicio":tempo})
	if espera>=1.0/30.0 or is_zero_approx(delta):
		espera=.0
		queue_redraw()

func protegido(ponto: Vector2, inversa: Transform2D) -> bool:
	var celula:=GradePlex.selecionar(inversa*ponto)
	return not GradePlex.dentro(celula) or jogo.iluminacao.salas.has(celula)

func _draw() -> void:
	desenhados=0
	if jogo==null: return
	var cal: CalendarioPlex=jogo.calendario
	var modo:=cal.previsao()
	var outono:=cal.estacao()=="Outono"
	if modo not in ["Chuva","Neve"] and not outono: return
	var intensidade:=cal.intensidade()
	var tela:=get_viewport_rect().size
	var inversa:=get_canvas_transform().affine_inverse()
	draw_set_transform_matrix(inversa)
	var total:=mini(300,roundi((190 if modo=="Chuva" else 110 if modo=="Neve" else 28)*intensidade*minf(1.8,tela.x*tela.y/700000.0)))
	var vento:=GradePlex.projetar_vetor(Vector2(.3,.12)).x*.8
	for i in total:
		var s:=sementes[i]
		var camada:=int(s.w)
		var velocidade:=190.0+camada*120 if modo=="Chuva" else 22.0+camada*15
		var x:=fposmod(s.x*(tela.x+60)+tempo*vento+sin(tempo+s.z*30)*(0 if modo=="Chuva" else 12),tela.x+60)-30
		var y:=fposmod(s.y*(tela.y+40)+tempo*velocidade,tela.y+40)-20
		var p:=Vector2(roundf(x),roundf(y))
		if protegido(p,inversa): continue
		desenhados+=1
		if modo=="Chuva":
			var cor:=Color(.65,.77,.85,.25+camada*.12)
			for k in range(0,4+camada*4,2): draw_rect(Rect2(p+Vector2(roundf(vento/velocidade*k),k),Vector2(1+int(camada==2),2)),cor)
		elif modo=="Neve":
			var tamanho:=1+camada
			draw_rect(Rect2(p,Vector2.ONE*tamanho),Color(.9,.95,1,.5+camada*.17))
			if camada==2:
				draw_rect(Rect2(p+Vector2(-1,1),Vector2(5,1)),Color(.94,.97,1,.65))
				draw_rect(Rect2(p+Vector2(1,-1),Vector2(1,5)),Color(.94,.97,1,.65))
		else:
			var fase:=floori(tempo*4+s.z*7)%4
			var cor: Color=[Color("ca8542"),Color("bd643b"),Color("d3aa55")][i%3]
			var forma:=Vector2(2,5) if fase%2==0 else Vector2(5,2)
			draw_rect(Rect2(p,forma),cor)
			draw_rect(Rect2(p+Vector2(forma.x*.5,forma.y-1).round(),Vector2(1,3)),Color("795632"))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	for r in respingos:
		var fase:=clampf((tempo-float(r.inicio))/.45,0.0,1.0)
		var p:=GradePlex.projetar(r.local)
		for i in 16:
			var angulo:=float(i)*TAU/16.0
			var ponto: Vector2=p+Vector2(cos(angulo)*(2+fase*7),sin(angulo)*(1+fase*3))
			draw_rect(Rect2(ponto.round(),Vector2.ONE),Color(.7,.84,.9,(1-fase)*.5))

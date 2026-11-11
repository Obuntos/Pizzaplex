class_name PassagemCadeirasPlex
extends RefCounted

static func conteudo(item:Dictionary) -> Dictionary:
	if not EmbalagensMoveisPlex.eh(item):return item
	var final:Dictionary=item.get("conteudo_movel",{}).duplicate(true)
	for campo in ["id","celula","rotacao"]:
		if item.has(campo):final[campo]=item[campo]
	return final
static func mesa(planta:PlantaPlex,item:Dictionary) -> Dictionary:
	var cadeira:=conteudo(item)
	if cadeira.get("tipo","")!="cadeira":return {}
	var frente:=GradePlex.frente(int(cadeira.rotacao))
	var m:=conteudo(planta.em(cadeira.celula+frente))
	if not LugaresPlex.mesa(str(m.get("tipo",""))):return {}
	if not LugaresPlex.posicoes(m).any(func(p):return p.celula==cadeira.celula and p.frente==frente):return {}
	return m
static func rede(planta:PlantaPlex,item:Dictionary) -> Dictionary:
	var m:=mesa(planta,item)
	if m.is_empty():return {}
	var lugares:Dictionary={}
	for posto in LugaresPlex.posicoes(m):
		var c:Dictionary=planta.em(posto.celula)
		if c.get("id",-2)==item.get("id",-1) or (c.get("tipo","")=="cadeira" and GradePlex.frente(int(c.rotacao))==posto.frente):lugares[posto.celula]=c
	var fila:Array[Vector2i]=[item.celula];var ligados:Dictionary={};var i:=0
	while i<fila.size():
		var c:Vector2i=fila[i];i+=1
		if ligados.has(c) or not lugares.has(c):continue
		ligados[c]=lugares[c]
		for d in GradePlex.VIZINHOS:
			if lugares.has(c+d) and not ligados.has(c+d):fila.append(c+d)
	return ligados
static func entradas(planta:PlantaPlex,item:Dictionary) -> Array[Vector2i]:
	var resultado:Array[Vector2i]=[]
	for c in rede(planta,item):
		for d in GradePlex.VIZINHOS:
			var p:Vector2i=c+d
			if planta.transitavel(p) and is_zero_approx(planta.altura(p)) and not resultado.has(p):resultado.append(p)
	return resultado
static func entradas_diretas(planta:PlantaPlex,item:Dictionary) -> Array[Vector2i]:
	var resultado:Array[Vector2i]=[]
	for d in GradePlex.VIZINHOS:
		var p:Vector2i=item.celula+d
		if planta.transitavel(p) and is_zero_approx(planta.altura(p)):resultado.append(p)
	return resultado
static func percurso(planta:PlantaPlex,item:Dictionary,entrada:Vector2i) -> Array[Vector2i]:
	var ligados:=rede(planta,item);var fila:Array[Vector2i]=[];var pais:Dictionary={}
	for d in GradePlex.VIZINHOS:
		var c:Vector2i=entrada+d
		if ligados.has(c):fila.append(c);pais[c]=entrada
	var i:=0
	while i<fila.size():
		var c:Vector2i=fila[i];i+=1
		if c==item.celula:
			var caminho:Array[Vector2i]=[c]
			while pais[c]!=entrada:c=pais[c];caminho.push_front(c)
			return caminho
		for d in GradePlex.VIZINHOS:
			var p:Vector2i=c+d
			if ligados.has(p) and not pais.has(p):pais[p]=c;fila.append(p)
	return []
static func iniciar(a:PersonagemPlex,planta:PlantaPlex,item:Dictionary,sentado:bool=true) -> bool:
	var caminho:=percurso(planta,item,a.celula)
	if not sentado and not caminho.is_empty():caminho.pop_back()
	if caminho.is_empty():return false
	var inicio:=a.ponto_visual();var pontos:Array=[[inicio.x,inicio.y,inicio.z]]
	for c in caminho:
		var cadeira:Dictionary=planta.em(c);var frente:=Vector2(GradePlex.frente(int(cadeira.rotacao)))*.12
		var quadril:=11.0 if a.modelo=="crianca" else 12.9 if a.modelo.begins_with("adolescente") else 15.0
		pontos.append([float(c.x)+frente.x,float(c.y)+frente.y,21.2-quadril*a.animacao.scale.y if sentado else 0.0])
	a.visita.passagem_cadeiras={"pontos":pontos,"tempo":0.0,"duracao":.38*(pontos.size()-1),"modo":"sentar" if sentado else "desembalar","voltando":false}
	return true
static func movendo(a:PersonagemPlex) -> bool:
	var d:Dictionary=a.visita.get("passagem_cadeiras",{})
	return not d.is_empty() and float(d.tempo)<float(d.duracao)
static func atualizar(a:PersonagemPlex,delta:float) -> void:
	var d:Dictionary=a.visita.get("passagem_cadeiras",{})
	if d.is_empty():return
	if d.modo=="sentar" and (a.assento<0 or a.trabalho!="sentar_mesa"):a.visita.erase("passagem_cadeiras");return
	if d.modo=="desembalar" and a.trabalho not in ["montar","servico"] and not d.voltando:
		d.pontos.reverse();d.tempo=0.0;d.voltando=true
	d.tempo=minf(float(d.duracao),float(d.tempo)+delta)
	if movendo(a):a.fase+=delta*1.4
	elif d.modo=="sentar" or d.voltando:a.visita.erase("passagem_cadeiras")
static func ponto(a:PersonagemPlex) -> Vector3:
	var d:Dictionary=a.visita.passagem_cadeiras
	var indice:=minf(float(d.pontos.size()-1),float(d.tempo)/.38)
	var k:=mini(int(indice),d.pontos.size()-2);var u:=smoothstep(0.0,1.0,indice-k)
	var p:Array=d.pontos[k];var q:Array=d.pontos[k+1]
	var atual:=Vector3(p[0],p[1],p[2]).lerp(Vector3(q[0],q[1],q[2]),u)
	if d.modo=="sentar":atual.z+=sin(u*PI)*.7
	return atual

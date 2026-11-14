class_name FitasVhsPlex
extends RefCounted

const MAXIMO:=12
var jogo:Node
var fitas:Array=[]
var proximo:=1
var espera:=0.0
var gravadas:Dictionary={}

func _init(cena:Node) -> void:jogo=cena
func noite() -> bool:return jogo.calendario.minutos>=1380.0 or jogo.calendario.minutos<360.0
func filmado(p:Vector2) -> bool:return jogo.sistemas.investigacao.filmado(p)

func gravar_fita(tipo:String,titulo:String,chave:String,_onde:Vector2=Vector2(-1,-1)) -> void:
	var marca:=chave+":"+str(jogo.calendario.dias)
	if gravadas.has(marca):return
	gravadas[marca]=true
	fitas.append({"id":proximo,"tipo":tipo,"titulo":titulo,"dia":int(jogo.calendario.dias),"hora":"%02d:%02d"%[floori(float(jogo.calendario.minutos)/60.0),posmod(int(jogo.calendario.minutos),60)]})
	proximo+=1
	while fitas.size()>MAXIMO:fitas.pop_front()

func atualizar(delta:float) -> void:
	espera+=delta
	if espera<2.0:return
	espera=0.0
	for r in jogo.personagens:
		if not r.robo or not filmado(r.local):continue
		var nome:=IdentidadesPlex.completo(r)
		if r.modelo.ends_with("_quebrado") and r.ocupado():gravar_fita("Assustador",nome+" (quebrado) andando sozinho","q"+str(r.identificador),r.local)
		elif noite() and r.ocupado() and (jogo.controle_robo.controlado(r) or r.robotica.get("assombrado",false)):gravar_fita("Assustador",nome+" andando de madrugada","m"+str(r.identificador),r.local)
		elif noite() and jogo.sistemas.bandas.cantando(r):gravar_fita("Assustador","Show de madrugada do nada: "+nome,"s"+str(r.identificador),r.local)

func incidente(v:PersonagemPlex) -> void:
	var admin:PersonagemPlex=jogo.controle.administrador()
	if v.cargo=="crianca" and is_instance_valid(admin) and admin.local.distance_to(v.local)<=6.0 and filmado(admin.local):
		gravar_fita("Suspeito",IdentidadesPlex.completo(admin)+" entrou com uma criança e saiu sozinho","a"+str(v.identificador),v.local)
		return
	for r in jogo.personagens:
		if r.robo and r.local.distance_to(v.local)<=2.0 and filmado(v.local):
			gravar_fita("Assustador",IdentidadesPlex.completo(r)+" atacou "+IdentidadesPlex.completo(v),"k"+str(v.identificador),v.local);return

func assistir(inv:InvestigacaoProgressivaPlex) -> void:
	for f in fitas:inv.pista("vhs:"+str(f.id),"Fita VHS ("+str(f.tipo)+"): "+str(f.titulo),16.0 if f.tipo=="Suspeito" else 6.0)

func triturar(id:int) -> void:
	for f in fitas.duplicate():
		if int(f.id)==id:fitas.erase(f)

func opcoes(menu:CanvasLayer,_o:Dictionary) -> void:
	if fitas.is_empty():menu.adicionar("Nenhuma fita VHS gravada",func():pass);return
	for f in fitas:
		var id:=int(f.id)
		menu.adicionar("Triturar fita · %s · dia %d %s · %s"%[str(f.tipo),int(f.dia)+1,str(f.hora),str(f.titulo)],func():triturar(id))

func ver() -> void:
	var linhas:=PackedStringArray()
	for f in fitas:linhas.append("[%s] dia %d %s · %s"%[str(f.tipo),int(f.dia)+1,str(f.hora),str(f.titulo)])
	AvisoPlex.mostrar(jogo,"Fitas VHS das câmeras","\n".join(linhas) if not linhas.is_empty() else "Nenhuma fita gravada.","Fechar","",560)

func gravar() -> Dictionary:return {"fitas":fitas.duplicate(true),"proximo":proximo}
func restaurar(d:Dictionary) -> void:
	fitas=d.get("fitas",[]).duplicate(true);proximo=int(d.get("proximo",1))

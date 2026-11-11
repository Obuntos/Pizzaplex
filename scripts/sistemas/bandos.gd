class_name BandosCriancasPlex
extends RefCounted

const TAMANHO:=4
static var cache:Dictionary={}

static func mapa(jogo:Node) -> Dictionary:
	var mes:int=jogo.calendario.indice_mes()
	if jogo.populacao==null:return {}
	if int(cache.get("mes",-1))==mes and int(cache.get("total",-1))==jogo.populacao.perfis.size():return cache.bandos
	var criancas:Array=jogo.populacao.perfis.values().filter(func(p):return str(p.get("grupo",""))=="criança").map(func(p):return str(p.id))
	criancas.sort_custom(func(a,b):return hash(a+"bando")<hash(b+"bando"))
	var bandos:Dictionary={}
	for i in criancas.size():
		var id:String=criancas[i]
		var sozinha:=posmod(hash(id+"sozinha"),5)==0
		if sozinha and posmod(hash([id,mes]),4)!=0:continue
		bandos[id]=floori(float(i)/float(TAMANHO))
	cache={"mes":mes,"total":jogo.populacao.perfis.size(),"bandos":bandos}
	return bandos

static func de_perfil(jogo:Node,id:String) -> int:return int(mapa(jogo).get(id,-1))
static func de(jogo:Node,a:PersonagemPlex) -> int:return de_perfil(jogo,str(a.identidade.get("morador_id","")))
static func amigos(jogo:Node,a:PersonagemPlex,b:PersonagemPlex) -> bool:
	var x:=de(jogo,a)
	return x>=0 and x==de(jogo,b)

static func convidados(jogo:Node,perfis:Array,criancas_familia:Array) -> Array:
	var turmas:Array=criancas_familia.map(func(id):return de_perfil(jogo,str(id))).filter(func(b):return b>=0)
	var lista:=perfis.duplicate()
	lista.sort_custom(func(x,y):return int(de_perfil(jogo,str(x.id)) in turmas)>int(de_perfil(jogo,str(y.id)) in turmas))
	return lista

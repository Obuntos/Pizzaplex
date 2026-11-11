class_name LivroAtracoesPlex
extends RefCounted
signal alterado
const CATEGORIAS=["Pijamas","Cozinha","Piratas","VI"]
var jogo: Node
var moedas:=0
var criancas_felizes:=0
var clientes_atendidos:=0
var primeira_brincadeira:=false
var adquiridos: Dictionary={}
var reservas: Dictionary={}
var ofertas: Array=[]

func _init(cena: Node) -> void: jogo=cena
func disponivel() -> bool: return true
func possui(id: String) -> bool: return AtracoesCatalogoPlex.permitido(id) and adquiridos.has(id)
func registros(categoria: int) -> Array[Dictionary]:
	AtracoesCatalogoPlex.carregar()
	var lista: Array[Dictionary]=[]
	for r in AtracoesCatalogoPlex.dados:
		if int(r.categoria)==categoria and AtracoesCatalogoPlex.permitido(str(r.id)) and not r.get("livro_oculto",false): lista.append(r)
	return lista

func divertir(pessoa: PersonagemPlex) -> void:
	if pessoa==null or pessoa.cargo not in ["crianca","adolescente"] or pessoa.visita.get("livro_divertiu",false): return
	pessoa.visita.livro_divertiu=true;criancas_felizes+=1;moedas+=1
	primeira_brincadeira=true;alterado.emit()

func atender(grupo: Dictionary) -> void:
	if grupo.get("livro_atendido",false): return
	grupo.livro_atendido=true
	var total: int=maxi(1,grupo.get("adultos",[]).size()+grupo.get("criancas",[]).size()+grupo.get("adolescentes",[]).size())
	clientes_atendidos+=total;moedas+=total;alterado.emit()

func reservar(id: String, ponto: int) -> bool:
	if not possui(id): return false
	return jogo.atracoes.enfileirar(id,ponto)

func gravar() -> Dictionary:
	return {"metodo":"estudo","moedas":moedas,"criancas":criancas_felizes,"clientes":clientes_atendidos,"aberto":primeira_brincadeira,"adquiridos":adquiridos.duplicate(),"montagens":jogo.atracoes.gravar()}

func restaurar(dados: Dictionary) -> void:
	moedas=maxi(0,int(dados.get("moedas",0)));criancas_felizes=maxi(0,int(dados.get("criancas",0)));clientes_atendidos=maxi(0,int(dados.get("clientes",0)))
	primeira_brincadeira=bool(dados.get("aberto",false));adquiridos=dados.get("adquiridos",{}).duplicate();reservas.clear()
	if dados.get("metodo","")!="estudo":adquiridos.clear()
	for c in 4:
		var lista:=registros(c)
		for i in lista.size():
			if adquiridos.has(str(c)+":"+str(i)): adquiridos[lista[i].id]=true
	for id in adquiridos.keys():
		if not AtracoesCatalogoPlex.permitido(str(id)): adquiridos.erase(id)
	ofertas.clear()
	jogo.atracoes.restaurar(dados.get("montagens",[]));alterado.emit()

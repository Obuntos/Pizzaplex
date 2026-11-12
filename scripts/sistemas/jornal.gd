class_name JornalCidadePlex
extends RefCounted

const MESES=["Janeiro","Fevereiro","Março","Abril","Maio","Junho","Julho","Agosto","Setembro","Outubro","Novembro","Dezembro"]
var jogo:Node
var mes:=-1
var base:Dictionary={}
var espera:=0.0
var eventos:Array=[]

func _init(cena:Node) -> void:jogo=cena

func estatisticas() -> Dictionary:
	var inv:InvestigacaoProgressivaPlex=jogo.sistemas.investigacao
	return {"clientes":int(jogo.livro.clientes_atendidos),"criancas":int(jogo.livro.criancas_felizes),"desaparecidos":inv.desaparecidos.size(),"suspeita":float(inv.suspeita),"nota":ReputacaoClientesPlex.nota(jogo.servicos)}

func noticiar(texto:String) -> void:
	if eventos.size()<6 and texto not in eventos:eventos.append(texto)

func atualizar(delta:float) -> void:
	espera+=delta
	if espera<2.0:return
	espera=0.0
	var atual:int=jogo.calendario.indice_mes()
	if mes<0:mes=atual;base=estatisticas();return
	if atual==mes:return
	publicar()
	mes=atual;base=estatisticas();eventos.clear()

func publicar() -> void:
	var agora_:=estatisticas()
	var manchetes:=PackedStringArray()
	var nota:=float(agora_.nota)
	if nota>=75.0:manchetes.append("PIZZAPLEX É O QUERIDINHO DAS FAMÍLIAS DO BAIRRO")
	elif nota<=40.0:manchetes.append("CLIENTES RECLAMAM DO ATENDIMENTO NA PIZZARIA")
	else:manchetes.append("PIZZARIA DO BAIRRO SEGUE MOVIMENTADA")
	var clientes:=int(agora_.clientes)-int(base.get("clientes",0))
	if clientes>0:manchetes.append("%d clientes passaram pelo restaurante neste mês."%clientes)
	var criancas:=int(agora_.criancas)-int(base.get("criancas",0))
	if criancas>0:manchetes.append("%d crianças saíram sorrindo dos shows e brincadeiras."%criancas)
	var sumiram:=int(agora_.desaparecidos)-int(base.get("desaparecidos",0))
	if sumiram>0:manchetes.append("POLÍCIA INVESTIGA %d DESAPARECIMENTO(S) PERTO DA PIZZARIA"%sumiram)
	if float(agora_.suspeita)>=40.0:manchetes.append("Investigação aperta o cerco: moradores pedem respostas.")
	for e in eventos:manchetes.append(str(e))
	AvisoPlex.mostrar(jogo,"Jornal do Bairro · "+MESES[posmod(int(jogo.calendario.data().mes)-2,12)],"\n\n".join(manchetes))

func gravar() -> Dictionary:return {"mes":mes,"base":base.duplicate(),"eventos":eventos.duplicate()}
func restaurar(d:Dictionary) -> void:
	mes=int(d.get("mes",-1));base=d.get("base",{}).duplicate();eventos=d.get("eventos",[]).duplicate()

class_name FamiliasVisitantesPlex
extends RefCounted

const PRESETS = {
	"adulto_crianca":{"adultos":1,"criancas":1,"adolescentes":0},
	"adulto_criancas":{"adultos":1,"criancas":2,"adolescentes":0},
	"dupla_criancas":{"adultos":2,"criancas":2,"adolescentes":0},
	"dupla_mista":{"adultos":2,"criancas":1,"adolescentes":1},
	"adulto_adolescente":{"adultos":1,"criancas":0,"adolescentes":1},
	"casal":{"adultos":2,"criancas":0,"adolescentes":0},
	"adulto":{"adultos":1,"criancas":0,"adolescentes":0}
}

static func adultos(grupo: Dictionary) -> Array[int]:
	var ids: Array[int] = []
	for valor in grupo.get("adultos",[grupo.adulta]):
		var id:=int(valor)
		if not ids.has(id): ids.append(id)
	return ids

static func membros(grupo: Dictionary) -> Array[int]:
	var ids:=adultos(grupo)
	for campo in ["criancas","adolescentes"]:
		for valor in grupo.get(campo,[]):
			var id:=int(valor)
			if not ids.has(id): ids.append(id)
	return ids

static func criar(clientes: ClientesPlex, local: Vector2i, total_adultos: int, total_criancas: int, total_jovens: int, modelo: String = "") -> bool:
	if "operacao" in clientes.jogo and not clientes.jogo.operacao.aberto:
		clientes.jogo.painel.mensagem("Abra o restaurante para receber novas visitas.")
		return false
	var total:=total_adultos+total_criancas+total_jovens
	if total_adultos<1 or total_adultos>2 or total_criancas<0 or total_criancas>2 or total_jovens<0 or total_jovens>2 or total>6 or not clientes.chao(local):
		clientes.jogo.painel.mensagem("Escolha um tile de chão livre para a família.")
		return false
	var destino:=clientes.saida(local)
	var locais:=clientes.vagas(local,total,4)
	if destino.x<0 or locais.size()<total:
		clientes.jogo.painel.mensagem("A família precisa de espaço livre e de uma saída alcançável.")
		return false
	var id:=clientes.proximo_grupo
	clientes.proximo_grupo+=1
	var grupo: Dictionary={"id":id,"adulta":-1,"adultos":[],"criancas":[],"adolescentes":[],"espera_acesso":0.0,"acesso":false,"mesa":-1,"slot":-1,"cadeira":-1,"pedido":-1,"estado":"visita","tempo":0.0,"pago":false,"saida":[destino.x,destino.y]}
	clientes.grupos[id]=grupo
	var indice:=0
	for n in total_adultos:
		var aparencia:=modelo
		if n>0: aparencia="humana" if clientes.ator(grupo.adulta).modelo=="humano" else "humano"
		elif aparencia not in ["humano","humana"]: aparencia="humano" if id%2==0 else "humana"
		var pessoa: PersonagemPlex=clientes.jogo.spawn(aparencia,locais[indice],"cliente")
		indice+=1
		pessoa.familia=id
		pessoa.visita.merge({"etapa":"chegada","banheiro":false,"higiene":false,"comeu":false},true)
		grupo.adultos.append(pessoa.identificador)
		if n==0: grupo.adulta=pessoa.identificador
	var responsavel:=clientes.ator(grupo.adulta)
	for n in total_criancas+total_jovens:
		var adolescente:=n>=total_criancas
		var aparencia: String=("adolescente_feminina" if (id+n)%2==0 else "adolescente") if adolescente else "crianca"
		var filho: PersonagemPlex=clientes.jogo.spawn(aparencia,locais[indice],"adolescente" if adolescente else "crianca")
		indice+=1
		filho.familia=id
		filho.responsavel=responsavel.identificador
		IdentidadesPlex.familiar(filho,responsavel)
		filho.visita={"etapa":"arcade" if adolescente else "jogar","jogou":false,"assistiu":false,"tempo":0.0,"partidas":0,"espera_jogo":0.0,"comeu":false,"solo":false}
		if adolescente:
			filho.cabelo="camadas" if aparencia=="adolescente_feminina" else "curto"
			filho.uniforme="nenhum"
			grupo.adolescentes.append(filho.identificador)
		else: grupo.criancas.append(filho.identificador)
	for adulto_id in grupo.adultos:
		var adulto:=clientes.ator(int(adulto_id))
		for filho_id in grupo.criancas+grupo.adolescentes:
			adulto.identidade.idade=maxi(int(adulto.identidade.idade),int(clientes.ator(int(filho_id)).identidade.idade)+18)
	clientes.jogo.selecionar(responsavel)
	clientes.jogo.painel.mensagem("Família: "+str(total_adultos)+" adulto(s), "+str(total_criancas)+" criança(s) e "+str(total_jovens)+" adolescente(s).")
	return true

static func preset(clientes: ClientesPlex, local: Vector2i, id: String) -> bool:
	if id=="variada": id=str(PRESETS.keys()[randi()%PRESETS.size()])
	if not PRESETS.has(id): return false
	var p: Dictionary=PRESETS[id]
	return criar(clientes,local,int(p.adultos),int(p.criancas),int(p.adolescentes))

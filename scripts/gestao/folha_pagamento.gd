class_name FolhaPagamentoPlex
extends RefCounted

const SALARIOS={"limpeza":50,"cozinha":100,"atendimento":70,"estoque":60,"manutencao":90,"caixa":80,"seguranca":90,"geral":120}
const DIAS_SEMANA=7
const MINUTOS_SEMANA=40.0*60.0
var ultimo_dia:=-1

static func salario(funcao: String) -> int:
	return int(SALARIOS.get(funcao,0))

static func registrar(ator: PersonagemPlex, dia: int) -> void:
	ator.visita.contratado_dia=dia
	ator.visita.salario_proximo_dia=dia+DIAS_SEMANA

func atualizar(jogo: Node) -> float:
	var dia:=int(jogo.calendario.dias)
	if ultimo_dia==dia: return 0.0
	ultimo_dia=dia
	var total:=0.0
	for ator in jogo.personagens:
		if ator.visita.get("demitido",false):continue
		if ator.robo or ator.cargo!="funcionario" or AdministradorPlex.eh(ator) or ator.visita.get("morto",false): continue
		if not ator.visita.has("salario_proximo_dia"): registrar(ator,dia)
		var proximo:=int(ator.visita.salario_proximo_dia)
		if dia<proximo: continue
		var semanas:=floori(float(dia-proximo)/DIAS_SEMANA)+1
		var valor:=snappedf(HabilidadesEquipePlex.salario(ator)*maxf(0,float(ator.visita.get("minutos_folha",0)))/MINUTOS_SEMANA,.01)
		if ator.visita.get("contrato_noturno",false) and not ator.visita.has("credito_salario"):ator.visita.credito_salario=float(ator.visita.get("contrato_pago",0))
		var credito:=minf(valor,maxf(0,float(ator.visita.get("credito_salario",0))))
		ator.visita.credito_salario=maxf(0,float(ator.visita.get("credito_salario",0))-credito);valor-=credito
		ator.visita.minutos_folha=0.0
		ator.visita.salario_proximo_dia=proximo+DIAS_SEMANA*semanas
		ator.visita.salario_total_pago=float(ator.visita.get("salario_total_pago",0.0))+valor
		total+=valor
	if total>0:
		jogo.servicos.saldo=snappedf(jogo.servicos.saldo-total,.01)
		jogo.painel.mensagem("Salários pagos: US$ %.2f."%total)
	return total

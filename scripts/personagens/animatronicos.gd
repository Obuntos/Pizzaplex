class_name AnimatronicosPlex
extends RefCounted
const INCREMENTOS={"media":0.2,"boa":0.1,"otima":0.05}
var jogo: Node
var palcos: PalcosPlex
func _init(cena: Node) -> void:
	jogo=cena
	palcos=PalcosPlex.new(jogo.planta)
static func base(id: String) -> String:
	for nome in ["coelho","ovelha","raposa"]:
		if id==nome or id.begins_with(nome+"_"): return nome
	return ""
static func garantir(a: PersonagemPlex) -> void:
	if not a.robo: return
	var desgaste:=2.0 if CatalogoMontagemPlex.quebrado(a.modelo) else 1.0 if "travad" in a.modelo else 0.0
	var qualidade:=a.caixa_qualidade
	if qualidade in ["perfeita","perfeito","otimo"]: qualidade="otima"
	if not INCREMENTOS.has(qualidade): qualidade="boa"
	var padrao: Dictionary={"apresentacao":"cantar","modo":"automatico","estado":"desligado","tempo_estado":0.0,"segundos_uso":0.0,"minutos_uso":0,"desgaste":desgaste,"qualidade":qualidade,"avariado":desgaste>=2.0,"reparo_por":0,"manutencao_solicitada":false,"desligado_manual":false,"reparos":0}
	for chave in padrao:
		if not a.robotica.has(chave): a.robotica[chave]=padrao[chave]
static func pausado(a: PersonagemPlex) -> bool:
	return bool(a.robotica.get("desligado_manual",false)) or bool(a.robotica.get("manutencao_solicitada",false)) or int(a.robotica.get("reparo_por",0))>0
static func comandar_energia(a: PersonagemPlex, ligar: bool) -> void:
	garantir(a)
	a.robotica.desligado_manual=not ligar
	if ligar:
		a.robotica.manutencao_solicitada=false
	else:
		a.movimento.cancelar()
static func titulo(a: PersonagemPlex) -> String:
	garantir(a)
	return {"sangrando":"Precisa de limpeza","deslocando":"Em deslocamento","desligado":"Desligado","ativando":"Ativando","ligado":"Ligado","desligando":"Desligando","avariado":"Avariado"}.get(str(a.robotica.get("estado","desligado")),"Desligado")
static func mudar(a: PersonagemPlex, estado: String) -> void:
	if str(a.robotica.estado)==estado: return
	a.robotica.estado=estado
	a.robotica.tempo_estado=0.0

static func duracao_partida(a: PersonagemPlex) -> float:
	ClipesPlex.carregar()
	return float(ClipesPlex.modelos.get(a.modelo,{}).get("clipes",{}).get("ativando",{}).get("duracao",1.6))

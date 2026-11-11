class_name BonnieSemanalPlex
extends RefCounted

const MODELO="bonnie_visitante"
var jogo:Node
var proximo_dia:=0
var morta:=false
var espera:=0.0
func _init(cena:Node) -> void:jogo=cena
static func eh(a:PersonagemPlex) -> bool:return is_instance_valid(a) and a.modelo==MODELO
func atualizar(delta:float) -> void:
	espera+=delta
	if espera<5.0:return
	espera=0.0
	for a in jogo.personagens:
		if eh(a):
			if a.visita.get("morto",false):morta=true
			return
	if morta or not jogo.operacao.aberto or jogo.calendario.dias<proximo_dia or jogo.calendario.minutos>=1140:return
	if not jogo.clientes.recepcao.tem_vaga(1):return
	var admin:PersonagemPlex=jogo.controle.administrador()
	if not is_instance_valid(admin):return
	var destino:Vector2i=jogo.clientes.saida(admin.celula)
	if destino.x<0:return
	var origem:=ChegadasEquipePlex.origem(jogo,admin,destino)
	if origem.x<0 or not jogo.clientes.criar_grupo(origem,1,0,0,"humana"):return
	var grupo:Dictionary=jogo.clientes.grupos[jogo.clientes.proximo_grupo-1]
	var bonnie:PersonagemPlex=jogo.clientes.ator(int(grupo.adulta))
	bonnie.movimento.cancelar();bonnie.celula=origem;bonnie.local=Vector2(origem)
	bonnie.mudar_modelo(MODELO);bonnie.cabelo="nenhum";bonnie.uniforme="nenhum"
	bonnie.identidade={"nome":"Bonnie","sobrenome":"","apelido":"","idade":24,"sexo":"feminino","pessoa_unica":"bonnie"}
	bonnie.visita.bonnie_unica=true;bonnie.atualizar_visual(false)
	proximo_dia=jogo.calendario.dias+7
func gravar() -> Dictionary:return {"proximo_dia":proximo_dia,"morta":morta}
func restaurar(d:Dictionary) -> void:proximo_dia=int(d.get("proximo_dia",0));morta=bool(d.get("morta",false))

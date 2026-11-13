class_name EstudosPlex
extends RefCounted

const ORDEM=["novo_coelho_detalhes","vi_patitas"]
const MINUTOS_PROJETO=960.0
var jogo:Node
var projeto:=""
var mesa:=-1
var pesquisador:=-1
var horas:=8
var progresso:=0.0
var dia:=-1
var minutos_dia:=0.0
var espera:=0.0
var concluidos:Dictionary={}
var forcado:=false

func _init(cena:Node) -> void: jogo=cena
static func eh_mesa(tipo:String) -> bool: return tipo in ["mesa_desenho_inclinada","bancada","oficina_bancada_trabalho"]
static func elegivel(a:PersonagemPlex) -> bool:
	return is_instance_valid(a) and not a.robo and a.cargo=="funcionario" and not a.visita.get("morto",false) and (AdministradorPlex.eh(a) or a.funcao=="manutencao")
func proximo() -> String:
	for id in ORDEM:
		if not concluidos.has(id): return id
	return ""
func liberar() -> void:
	var a:PersonagemPlex=jogo.clientes.ator(pesquisador)
	if is_instance_valid(a) and a.visita.get("estudando",false):
		a.visita.erase("estudando");a.visita.erase("estudo_forcado");a.trabalho="";a.movimento.cancelar()
		if a.assento>=0 and int(jogo.planta.objetos.get(a.assento,{}).get("reserva",0))==a.identificador:jogo.planta.objetos[a.assento].reserva=0
		a.assento=-1
func cadeira(id_mesa:int,a:PersonagemPlex) -> int:
	var m:Dictionary=jogo.planta.objetos.get(id_mesa,{})
	if m.is_empty():return -1
	var celulas:Array[Vector2i]=jogo.planta.celulas(str(m.tipo),m.celula,int(m.rotacao))
	for o in jogo.planta.objetos.values():
		if CatalogoPlex.base(str(o.tipo))!="cadeira" or int(o.get("carregada_por",0))>0 or int(o.get("sobre",-1))>=0:continue
		if not celulas.has(Vector2i(o.celula)+GradePlex.frente(int(o.rotacao))):continue
		if int(o.get("reserva",0)) not in [0,a.identificador if is_instance_valid(a) else -1]:continue
		if jogo.personagens.any(func(p):return p!=a and p.assento==int(o.id)):continue
		return int(o.id)
	return -1
## Projeto que pode ser escolhido agora: qualquer um ainda não estudado,
## desde que nenhum outro tenha progresso em andamento.
func pode_escolher(id:String) -> bool:
	return id in ORDEM and not concluidos.has(id) and (projeto.is_empty() or projeto==id or progresso<=0.0)
func configurar(id_mesa:int,id_pessoa:int,quantidade_horas:int,forcar:bool=false,alvo:String="") -> bool:
	var m:Dictionary=jogo.planta.objetos.get(id_mesa,{})
	var a:PersonagemPlex=jogo.clientes.ator(id_pessoa)
	if not eh_mesa(str(m.get("tipo",""))) or not elegivel(a) or proximo().is_empty(): return false
	if cadeira(id_mesa,a)<0:jogo.painel.mensagem("Coloque uma cadeira de frente para a mesa de estudo.");return false
	if forcar:
		if TurnosEquipePlex.ocupado(a) or a.visita.get("morto",false) or a.visita.get("fora_turno",false) or a.visita.get("controle_manual",false) or a.visita.get("fugindo",false) or a.visita.get("saindo_fechamento",false):return false
		if jogo.rotas.aproximar(a.origem_rota(),cadeira(id_mesa,a)).is_empty():return false
		jogo.controle.interromper(a)
	else:
		if ControleAdministradorPlex.ocupado(a) and not a.visita.get("estudando",false): return false
		if jogo.servicos.trabalhos.has(a.identificador) or jogo.tarefas.trabalhos.has(a.identificador): return false
	liberar();mesa=id_mesa;pesquisador=id_pessoa;horas=clampi(quantidade_horas,1,12)
	forcado=forcar
	a.visita.estudando=true;a.visita.estudo_forcado=forcado
	if not alvo.is_empty() and pode_escolher(alvo): projeto=alvo
	if projeto.is_empty(): projeto=proximo()
	return true
func pausar() -> void: liberar();pesquisador=-1;forcado=false
func atualizar(delta:float) -> void:
	if pesquisador<0 or projeto.is_empty(): return
	var a:PersonagemPlex=jogo.clientes.ator(pesquisador)
	var m:Dictionary=jogo.planta.objetos.get(mesa,{})
	if m.is_empty() or not eh_mesa(str(m.tipo)) or not elegivel(a): pausar();return
	if dia!=jogo.calendario.dias: dia=jogo.calendario.dias;minutos_dia=0.0
	if not forcado and (minutos_dia>=horas*60 or jogo.calendario.minutos<480 or jogo.calendario.minutos>=1200): liberar();return
	if TurnosEquipePlex.ocupado(a) or a.visita.get("saindo_fechamento",false) or a.visita.get("controle_manual",false) or a.visita.get("fora_turno",false) or a.visita.get("socializando",false) or a.visita.get("fugindo",false): liberar();return
	if jogo.servicos.trabalhos.has(a.identificador) or jogo.tarefas.trabalhos.has(a.identificador): return
	a.visita.estudando=true;a.visita.estudo_forcado=forcado
	var assento:=cadeira(mesa,a)
	if assento<0:jogo.painel.mensagem("O estudo parou: falta uma cadeira de frente para a mesa.");pausar();return
	if a.assento!=assento:
		if a.ocupado(): return
		a.assento=-1
		if not jogo.planta.interacoes(assento).has(a.celula):
			espera-=delta
			if espera>0: return
			espera=2.0
			var rota:Array[Vector2i]=jogo.rotas.aproximar(a.origem_rota(),assento)
			if rota.is_empty(): a.visita.erase("estudando");return
			a.trabalho="ir_estudar";a.andar(rota);return
		a.assento=assento;jogo.planta.objetos[assento].reserva=a.identificador
	a.trabalho="estudar";a.direcao=GradePlex.direcao_suporte(int(jogo.planta.objetos[assento].rotacao))
	var minutos:=delta*CalendarioPlex.MINUTOS_POR_SEGUNDO if forcado else minf(delta*CalendarioPlex.MINUTOS_POR_SEGUNDO,float(horas*60)-minutos_dia)
	progresso=minf(MINUTOS_PROJETO,progresso+minutos);minutos_dia+=minutos;a.progresso_acao=fposmod(a.relogio/2.5,1.0)
	if progresso>=MINUTOS_PROJETO: concluir()
func concluir() -> bool:
	var id:=projeto if not projeto.is_empty() else proximo()
	if id.is_empty(): return false
	concluidos[id]=true;jogo.livro.adquiridos[id]=true
	liberar();projeto="";pesquisador=-1;progresso=0.0;forcado=false
	jogo.livro.alterado.emit();jogo.painel.mensagem("Estudo concluído: "+CatalogoMontagemPlex.nome(id)+".")
	return true
func gravar() -> Dictionary:
	return {"projeto":projeto,"mesa":mesa,"pesquisador":pesquisador,"horas":horas,"progresso":progresso,"dia":dia,"minutos_dia":minutos_dia,"concluidos":concluidos.duplicate(),"forcado":forcado}
func restaurar(d:Dictionary) -> void:
	forcado=bool(d.get("forcado",false))
	liberar();projeto=str(d.get("projeto",""));mesa=int(d.get("mesa",-1));pesquisador=int(d.get("pesquisador",-1));horas=clampi(int(d.get("horas",8)),1,12);progresso=clampf(float(d.get("progresso",0)),0,MINUTOS_PROJETO);dia=int(d.get("dia",-1));minutos_dia=maxf(0,float(d.get("minutos_dia",0)));concluidos=d.get("concluidos",{}).duplicate()
	for id in concluidos.keys():
		if id not in ORDEM: concluidos.erase(id)
		else:jogo.livro.adquiridos[id]=true
	if projeto not in ORDEM: projeto="";pesquisador=-1;progresso=0.0

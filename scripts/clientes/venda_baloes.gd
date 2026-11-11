class_name VendaBaloesPlex
extends RefCounted

var jogo:Node
var espera:=0.0
var visuais:Dictionary={}
func _init(cena:Node) -> void:jogo=cena

func preparar(grupo:Dictionary) -> bool:
	if not jogo.operacao.aberto or not grupo.get("pago",false) or grupo.get("baloes_encerrados",false) or grupo.get("irritado",false) or grupo.get("criancas",[]).is_empty():return false
	var adulto:PersonagemPlex=jogo.clientes.ator(int(grupo.get("adulta",-1)))
	if not is_instance_valid(adulto):return false
	for item in jogo.planta.objetos.values():
		if item.tipo!=DecoracaoEstudoPlex.CARRINHO or item.get("estado","tres")=="vazio":continue
		var rota:Array[Vector2i]=jogo.rotas.aproximar(adulto.origem_rota(),item.id)
		if rota.is_empty() or rota.size()>18:continue
		grupo.estado="comprar_baloes";grupo.baloes_carrinho=item.id;grupo.baloes_tempo=0.0;grupo.baloes_atendimento=0.0
		adulto.assento=-1;adulto.movimento.cancelar();adulto.andar(rota);adulto.trabalho="comprar_balao"
		return true
	return false

func visitar(grupo:Dictionary,delta:float) -> void:
	grupo.baloes_tempo=float(grupo.get("baloes_tempo",0))+delta
	var pai:PersonagemPlex=jogo.clientes.ator(int(grupo.get("adulta",-1)))
	var carrinho:Dictionary=jogo.planta.objetos.get(int(grupo.get("baloes_carrinho",-1)),{})
	if not is_instance_valid(pai) or carrinho.is_empty() or not jogo.operacao.aberto or carrinho.get("estado","tres")=="vazio" or float(grupo.baloes_tempo)>50.0:
		grupo.baloes_encerrados=true;jogo.clientes.sair(grupo);return
	if pai.local.distance_to(Vector2(carrinho.celula))>3.6:
		if not pai.ocupado():pai.andar(jogo.rotas.aproximar(pai.origem_rota(),carrinho.id));pai.trabalho="comprar_balao"
		return
	pai.trabalho="comprar_balao";grupo.baloes_atendimento=float(grupo.get("baloes_atendimento",0))+delta
	if float(grupo.baloes_atendimento)<1.5:return
	for id in grupo.get("criancas",[]):
		var crianca:PersonagemPlex=jogo.clientes.ator(int(id))
		if is_instance_valid(crianca):vender(pai,crianca,carrinho)
	grupo.baloes_encerrados=true;jogo.clientes.sair(grupo)

func vender(a:PersonagemPlex,crianca:PersonagemPlex,carrinho:Dictionary) -> bool:
	if crianca.visita.get("balao_comprado",false) or carrinho.get("estado","tres")=="vazio":return false
	crianca.visita.balao_comprado=true;crianca.visita.balao_cor=posmod(crianca.identificador,3)
	a.visita.gasto_baloes=snappedf(float(a.visita.get("gasto_baloes",0.0))+1.5,.01)
	jogo.servicos.receber(1.5);carrinho.vendas_baloes=int(carrinho.get("vendas_baloes",0))+1
	crianca.animacao.expressao="feliz";crianca.visita.satisfacao=minf(100,float(crianca.visita.get("satisfacao",50.0))+5)
	return true

func atualizar(delta:float) -> void:
	espera+=delta
	if espera<.15:return
	espera=0.0
	for a in jogo.personagens:
		if not a.visita.get("balao_comprado",false) or a.visita.get("morto",false):continue
		if not visuais.has(a.identificador):
			var visual:=BalaoInfantilPlex.new();visual.cor=Color(["9b5b60","5e8597","b4a061"][int(a.visita.get("balao_cor",0))]);a.add_child(visual);visuais[a.identificador]=visual
		var v:Node2D=visuais[a.identificador];v.position=Vector2(12,-a.altura-28);v.visible=a.visible
	for id in visuais.keys():
		if not is_instance_valid(visuais[id]):visuais.erase(id);continue
		var dono:PersonagemPlex=visuais[id].get_parent()
		if not is_instance_valid(dono) or dono.identificador!=int(id) or not dono.visita.get("balao_comprado",false):visuais[id].queue_free();visuais.erase(id)

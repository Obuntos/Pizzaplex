class_name ShowsPalcoPlex
extends RefCounted

var jogo:Node
var ativos:Dictionary={}
var espera:=0.0
func _init(cena:Node) -> void:jogo=cena
func grupo(id:int) -> int:
	jogo.animatronicos.palcos.atualizar()
	var o:Dictionary=jogo.planta.objetos.get(id,{})
	return int(jogo.animatronicos.palcos.grupos.get(o.get("celula",Vector2i(-1,-1)),-1))
func ativo(a:PersonagemPlex) -> bool:return ativos.has(jogo.animatronicos.palcos.da_pose(a.pose))
func alternar(id:int) -> bool:
	var palco:=grupo(id)
	if palco<0:jogo.painel.mensagem("Este palco ainda não foi reconhecido. Mova ou recoloque uma peça do palco.");return false
	if ativos.has(palco):encerrar(palco);return true
	vincular(palco)
	var robos:Array=jogo.personagens.filter(func(a):return a.robo and not a.visita.get("montando_atracao",false) and jogo.animatronicos.palcos.da_pose(a.pose)==palco and not a.robotica.get("avariado",false))
	if robos.is_empty():jogo.painel.mensagem("Coloque um animatrônico montado no palco antes de ligar o show.");return false
	ativos[palco]=180.0
	for a in robos:AnimatronicosPlex.comandar_energia(a,true)
	for o in jogo.planta.objetos.values():
		if MobiliaPlex.dados(o).get("alto_falante",false):o.som_ligado=true
	jogo.painel.mensagem("Show ligado. As crianças com atividades livres podem se aproximar para assistir.")
	return true
func vincular(palco:int) -> void:
	jogo.animatronicos.palcos.atualizar()
	var marcas:Array=jogo.planta.objetos.values().filter(func(o):return o.tipo=="pose" and jogo.animatronicos.palcos.da_pose(int(o.id))==palco)
	for r in jogo.personagens:
		if not r.robo or r.pose>=0 or ArmazemRobosPlex.INTEIRO.has(r.modelo) or r.visita.get("montando_atracao",false) or r.robotica.get("armazenado",false) or jogo.controle_robo.controlado(r):continue
		if int(jogo.animatronicos.palcos.grupos.get(r.celula,-1))!=palco:continue
		marcas.sort_custom(func(x,y):return Vector2(x.celula).distance_to(r.local)<Vector2(y.celula).distance_to(r.local))
		for o in marcas:
			if o.celula==r.celula and jogo.poses.livre(int(o.id),r):prender(r,o);break
			if jogo.atracoes.definir_pose(r.identificador,int(o.id)):break
func prender(r:PersonagemPlex,marca:Dictionary) -> void:
	marca.dono=r.identificador;r.pose=int(marca.id);r.automatico=true;r.robotica.desligado_manual=false
	r.trabalho="apresentar";r.direcao=GradePlex.direcao_suporte(int(marca.rotacao));r.visita.erase("aguarda_seta")
	jogo.livro.alterado.emit()
func encerrar(id:int) -> void:
	ativos.erase(id)
	for r in jogo.personagens:
		if r.robo and jogo.animatronicos.palcos.da_pose(r.pose)==id:AnimatronicosPlex.comandar_energia(r,false)
	for a in jogo.personagens:
		if int(a.visita.get("show_forcado",-1))==id:
			a.visita.erase("show_balao");a.visita.erase("show_forcado");a.visita.erase("show_destino");a.visita.erase("pose");a.trabalho="visitar";a.movimento.cancelar();a.visita.assistiu=true
	if ativos.is_empty():
		for o in jogo.planta.objetos.values():
			if MobiliaPlex.dados(o).get("alto_falante",false):o.som_ligado=false
func atualizar(delta:float) -> void:
	for id in ativos.keys():
		ativos[id]=float(ativos[id])-delta
		if float(ativos[id])<=0:encerrar(int(id))
	espera+=delta
	if espera<1:return
	espera=0
	for r in jogo.personagens.duplicate():
		if r.robo and r.visita.has("debug_seta") and not jogo.planta.objetos.has(int(r.visita.debug_seta)):jogo.despawn(r)
	for id in ativos.keys():
		var robos:Array=jogo.personagens.filter(func(a):return a.robo and jogo.animatronicos.palcos.da_pose(a.pose)==int(id) and not a.visita.get("montando_atracao",false))
		if robos.is_empty():encerrar(int(id));continue
		var r:PersonagemPlex=robos[0]
		for a in jogo.personagens:
			if a.cargo not in ["crianca","adolescente"] or a.visita.get("morto",false) or a.assento>=0:continue
			var seguindo:int=a.visita.get("show_forcado",-1)
			if seguindo<0:
				if ControleAdministradorPlex.ocupado(a) or a.visita.get("brincando",false) or a.visita.get("etapa","") in ["sair","refeicao","recepcao","comer"] or a.local.distance_to(r.local)>14:continue
				if a.cargo=="adolescente" and posmod(a.identificador,3)!=0:continue
				var ponto:Dictionary=jogo.clientes.ponto_show(a)
				if ponto.is_empty() or jogo.animatronicos.palcos.da_pose(int(ponto.get("pose",-1)))!=int(id):continue
				a.movimento.cancelar();a.visita.show_forcado=id;a.visita.pose=int(ponto.pose);a.visita.show_destino=ponto.celula.duplicate()
			if int(a.visita.get("show_forcado",-1))!=int(id) or a.ocupado():continue
			var destino:=Vector2i(a.visita.show_destino[0],a.visita.show_destino[1])
			if a.celula!=destino:
				var rota:Array[Vector2i]=jogo.rotas.caminho(a.origem_rota(),destino)
				if not rota.is_empty():a.andar(rota);a.trabalho="ir_show"
			else:
				a.trabalho="assistir";jogo.tarefas.orientar(a,r.local);a.animacao.expressao="feliz"
				if not a.visita.get("show_balao",false):a.visita.show_balao=true;jogo.sistemas.baloes.exibir(a,"O show começou!",4)
func gravar() -> Dictionary:return ativos.duplicate()
func restaurar(d:Dictionary) -> void:
	ativos.clear()
	for id in d:ativos[int(id)]=float(d[id])

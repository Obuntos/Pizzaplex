class_name MontagemAtracoesPlex
extends RefCounted

const TEMPO_PARTE=3.5
const MODELO="novo_coelho_detalhes"
const BANCADA="bancada_montagem_coelho"
const PRECOS={"endo":180,"plastico":110,"carcaca":150,"reparo":65,"troca_carcaca":90,"desmontar":0}
var jogo:Node
var fila:Array=[]
var espera:=0.0
var partes_tempo:=0.0
var revisao_migrada:=-1
var minigame_ui:MinigamesVIPlex
func _init(cena:Node) -> void:jogo=cena
func ator(id:int) -> PersonagemPlex:return jogo.clientes.ator(id)
static func bancada(item:Dictionary) -> bool:return item.get("tipo","") in [BANCADA,"area_montagem_atracao","pecas_bancada_endo","pecas_bancada_plastico","pecas_bancada_carcaca","oficina_bancada_trabalho"]
func pagar(fase:String) -> bool:
	var preco:=float(PRECOS.get(fase,0))
	if jogo.servicos.saldo<preco:jogo.painel.mensagem("Saldo insuficiente. Esta etapa custa US$ %.0f."%preco);return false
	jogo.servicos.saldo=snappedf(jogo.servicos.saldo-preco,.01);return true
func enfileirar(modelo:String,ponto:int) -> bool:
	if not jogo.oficina.base_livre(jogo.planta.objetos.get(ponto,{})):return false
	if not AtracoesCatalogoPlex.permitido(modelo) or not pesquisado(modelo) or jogo.planta.objetos.get(ponto,{}).get("tipo","")!="area_montagem_atracao" or mesa_livre(ponto)<0 or ocupado(modelo):return false
	if not pagar("endo"):return false
	fila.append({"modelo":modelo,"ponto":ponto,"fase":"endo","operacao":"preparar","preparadas":0,"instaladas":0,"bancada":mesa_livre(ponto),"tempo":0.0,"parte":0,"robo":-1,"ator":-1,"caixas":[],"pago":true,"conjunto_vi":true})
	jogo.livro.alterado.emit()
	if jogo.controle.manual():retomar_trabalho(ponto)
	return true
func iniciar_disponivel(modelo:String=MODELO) -> bool:
	for item in jogo.planta.objetos.values():
		if item.tipo=="area_montagem_atracao" and enfileirar(modelo,int(item.id)):return true
	jogo.painel.mensagem("Conclua a pesquisa e coloque uma base cinza e uma bancada com acesso livre.");return false
func ordem(id:int) -> Dictionary:
	for o in fila:
		if int(o.ponto)==id or int(o.get("bancada",-1))==id or int(jogo.planta.objetos.get(id,{}).get("ordem_montagem",-2))==int(o.ponto):return o
	return {}
func continuar(id:int,modelo:String=MODELO) -> bool:
	var o:=ordem(id)
	if not o.is_empty() and not str(o.get("minigame_pendente","")).is_empty():abrir_minigame(o);return true
	if o.is_empty():
		for suspensa in fila:
			if int(suspensa.ponto)<0 and jogo.planta.objetos.get(id,{}).get("tipo","")=="area_montagem_atracao":
				suspensa.ponto=id;suspensa.fase=str(suspensa.get("fase_suspendida","endo"))
				var r:=ator(int(suspensa.robo));var p:Dictionary=jogo.planta.objetos[id]
				if is_instance_valid(r):r.local=Vector2(p.celula)+Vector2(CatalogoPlex.dimensoes(str(p.tipo),int(p.rotacao))-Vector2i.ONE)*.5;r.celula=Vector2i(r.local.round())
				return true
		return enfileirar(modelo,id)
	if o.fase in ["endo","plastico","carcaca","reparo","troca_carcaca","desmontar"]:return retomar_trabalho(id)
	if o.fase=="plastico_mesa":
		o.fase="plastico";o.operacao="buscar";o.instaladas=0;o.tempo=0.0;jogo.livro.alterado.emit();return retomar_trabalho(id)
	var proxima:="plastico" if o.fase=="pronto_endo" else "carcaca" if o.fase=="pronto_plastico" else ""
	if proxima.is_empty() or not pagar(proxima):return false
	o.fase=proxima;o.operacao="preparar";o.preparadas=0;o.instaladas=0;o.tempo=0.0;jogo.livro.alterado.emit();return retomar_trabalho(id)
func disponivel(a:PersonagemPlex) -> bool:
	return a.cargo=="funcionario" and not a.robo and a.automatico and (a.funcao=="manutencao" or AdministradorPlex.eh(a)) and not ControleAdministradorPlex.ocupado(a) and not TurnosEquipePlex.ocupado(a) and not a.visita.get("fora_turno",false) and not a.visita.get("saindo_fechamento",false) and not a.ocupado() and a.carga_item<0 and not jogo.servicos.trabalhos.has(a.identificador) and not jogo.tarefas.trabalhos.has(a.identificador) and not FantasiasRestaurantePlex.ocupando(a) and not a.visita.get("obra_atracao",false)
func posicao_trabalho(a:PersonagemPlex,ponto:Dictionary) -> Array[Vector2i]:return jogo.rotas.aproximar(a.origem_rota(),int(ponto.id))
func ocupado(modelo:String) -> bool:return fila.any(func(o):return o.modelo==modelo) or jogo.personagens.any(func(a):return a.modelo==modelo)
func liberar(o:Dictionary) -> void:
	var a:=ator(int(o.get("ator",-1)))
	if is_instance_valid(a):
		if jogo.controle.acao.get("tipo","")=="montar_atracao" and int(jogo.controle.acao.get("ponto",-1))==int(o.ponto):jogo.controle.acao.clear()
		if a.visita.get("modulo_montagem",false):
			if jogo.planta.objetos.has(a.carga_item):
				var item:Dictionary=jogo.planta.objetos[a.carga_item];item.carregada_por=0
				var mesa:Dictionary=jogo.planta.objetos.get(int(o.get("bancada",-1)),{})
				if not mesa.is_empty():item.sobre=mesa.id;item.slot=slot_modulo(int(item.get("modulo",0)));item.celula=mesa.celula
			if o.fase in ["endo","plastico","carcaca"]:o.operacao="buscar"
			a.carga_item=-1;a.carregando=false;a.visita.erase("modulo_montagem");jogo.planta.reindexar();jogo.planta.alterada.emit()
		a.visita.erase("obra_atracao");a.trabalho="manual" if a.visita.get("controle_manual",false) else "";a.progresso_acao=0.0
	o.ator=-1
func permite_corpo(r:PersonagemPlex,corpo:PersonagemPlex) -> bool:
	if not is_instance_valid(r) or not AtracoesCatalogoPlex.permitido(r.modelo) or not BonnieSemanalPlex.eh(corpo) or not corpo.visita.get("morto",false) or int(r.visita.get("corpo_oculto",-1))>0:return false
	return fila.any(func(o):return int(o.robo)==r.identificador and o.fase=="pronto_endo" and int(o.parte)==17)
func montagem(delta:float) -> void:
	for o in fila.duplicate():
		if not str(o.get("minigame_pendente","")).is_empty():solicitar_minigame(o,str(o.minigame_pendente))
		if o.get("retomar_apos_migracao",false):o.erase("retomar_apos_migracao");continuar(int(o.ponto))
		if minigame_aberto():return
		if not str(o.get("minigame_pendente","")).is_empty():continue
		var r:=ator(int(o.robo))
		if is_instance_valid(r) and r.visita.get("montagem_olhar_jogador",false):
			var adm:PersonagemPlex=jogo.controle.administrador()
			if is_instance_valid(adm) and adm.celula!=r.celula:
				jogo.tarefas.olhar_tela(r,Vector2(adm.celula))
		if o.get("pausada",false):
			if o.get("motivo","")=="Sem acesso" and int(o.get("bloqueio_revisao",-1))!=jogo.planta.revisao:o.pausada=false
			elif o.get("motivo","")=="Aguardando" and jogo.personagens.any(disponivel):o.pausada=false
			else:continue
		if o.fase=="caminhando":
			if not is_instance_valid(r) or not r.ocupado() and r.trabalho=="apresentar":fila.erase(o);jogo.livro.alterado.emit()
			continue
		if o.fase in ["pronto_endo","pronto_plastico","plastico_mesa","seta","aguardar_bancada"]:continue
		var base:Dictionary=jogo.planta.objetos.get(int(o.ponto),{})
		var ponto:Dictionary=base
		if o.fase in ["endo","plastico","carcaca"] and o.get("operacao","") in ["preparar","buscar"]:
			var id_mesa:=int(o.get("bancada",-1))
			if not jogo.planta.objetos.has(id_mesa):id_mesa=mesa_livre(int(o.ponto));o.bancada=id_mesa
			ponto=jogo.planta.objetos.get(id_mesa,{})
		if base.is_empty():
			liberar(o)
			o.fase_suspendida=o.fase;o.fase="aguardar_bancada";o.ponto=-1
			jogo.painel.mensagem("Montagem pausada. Coloque uma bancada livre e use Montar para retomar o progresso.");continue
		if ponto.is_empty():liberar(o);continue
		if o.fase=="aguardar_robo":
			if not is_instance_valid(r):fila.erase(o);continue
			if r.ocupado():continue
			if r.local.distance_to(Vector2(ponto.celula))>5:
				var trajeto:Array[Vector2i]=jogo.rotas.aproximar(r.origem_rota(),int(ponto.id))
				if not trajeto.is_empty():r.andar(trajeto)
				continue
			o.fase=o.servico;r.visita.montando_atracao=true;r.visita.montagem_passos=52
			if o.servico!="desmontar":posicionar_na_bancada(r,ponto)
		var a:=ator(int(o.ator))
		if is_instance_valid(a) and bloqueado(a,o):
			pausar_ator(a,"Aguardando");continue
		if not is_instance_valid(a):
			o.busca=float(o.get("busca",0))-delta
			if float(o.busca)>0:continue
			o.busca=2.0
			for candidato in jogo.personagens.filter(disponivel):
				var rota:=posicao_trabalho(candidato,ponto)
				if rota.is_empty():continue
				a=candidato;o.ator=a.identificador;a.visita.obra_atracao=true;a.assento=-1;a.trabalho="ir_montar_atracao";a.andar(rota);break
		if not is_instance_valid(a) or a.ocupado():continue
		if not jogo.planta.interacoes(int(ponto.id)).has(a.celula):
			var rota:=posicao_trabalho(a,ponto)
			if not rota.is_empty():a.trabalho="ir_montar_atracao";a.progresso_acao=0.0;a.andar(rota)
			else:pausar_ator(a,"Sem acesso")
			continue
		if o.fase in ["endo","plastico","carcaca"]:
			if executar_preparacao(o,a,ponto,delta):continue
		a.trabalho="montar";a.visita.anim_ferramenta=o.fase in ["carcaca","reparo","troca_carcaca"];jogo.tarefas.olhar_objeto(a,int(ponto.id))
		o.tempo=float(o.tempo)+delta*HabilidadesEquipePlex.fator(a,"manutencao");a.progresso_acao=fposmod(float(o.tempo)/2.4,1.0)
		if not is_instance_valid(r):
			var tamanho:=CatalogoPlex.dimensoes(str(base.tipo),int(base.rotacao));var centro:=Vector2(base.celula)+Vector2(tamanho-Vector2i.ONE)*.5
			r=jogo.criar_personagem(str(o.modelo),Vector2i(centro.round()),"atracao",true,{})
			if not is_instance_valid(r):liberar(o);continue
			o.robo=r.identificador;r.local=centro;posicionar_na_bancada(r,base);r.visita.montando_atracao=true;r.visita.montagem_passos=int(o.parte);r.suporte=-1;r.automatico=false;AnimatronicosPlex.garantir(r)
		if float(o.tempo)<TEMPO_PARTE:continue
		o.tempo-=TEMPO_PARTE
		if o.fase in ["reparo","troca_carcaca"]:
			o.parte=int(o.parte)+1
			if int(o.parte)>=17:
				r.robotica.desgaste=0.0;r.robotica.avariado=false;r.robotica.sangrando=false;r.robotica.cheiro=0.0;r.robotica.contaminacao=0.0;r.robotica.manutencao_solicitada=false;r.robotica.manutencoes=int(r.robotica.get("manutencoes",0))+1
				liberar(o);r.visita.erase("montando_atracao");r.visita.erase("montagem_passos");o.fase="seta";pedir_seta(o)
			continue
		if o.fase=="desmontar":
			o.parte=int(o.parte)-1;r.visita.montagem_passos=maxi(0,int(o.parte))
			if int(o.parte)<=0:
				var corpo:=ator(int(r.visita.get("corpo_oculto",-1)))
				if is_instance_valid(corpo):jogo.despawn(corpo)
				r.visita.erase("corpo_oculto");liberar(o);fila.erase(o);jogo.despawn(r);jogo.painel.mensagem("Peças recicladas. As gravações e pistas já recolhidas permanecem no caso.")
			continue
		if o.fase in ["endo","plastico"] and o.get("operacao","")=="instalar":
			o.instaladas=int(o.get("instaladas",0))+1;o.parte=([6,13,17] if o.fase=="endo" else [23,29,34])[mini(int(o.instaladas),3)-1];retirar_modulo(a);o.operacao="buscar" if int(o.instaladas)<3 else "concluir"
		else:o.parte=int(o.parte)+1
		r.visita.montagem_passos=int(o.parte)
		var limite:=17 if o.fase=="endo" else 34 if o.fase=="plastico" else 52
		if int(o.parte)>=limite:
			liberar(o)
			if o.fase=="endo":
				o.fase="pronto_endo"
				if o.get("conjunto_vi",false):continuar(int(o.ponto))
				else:jogo.painel.mensagem("Endoesqueleto pronto. Agora é possível inserir somente o corpo de Bonnie; continuar com plástico encerra essa possibilidade.")
			elif o.fase=="plastico":
				o.fase="pronto_plastico";o.plastico_configurado=true
				jogo.painel.mensagem("Plástico encaixado. Clique no animatrônico ou na base e escolha Colocar roupa para costurar e vestir.")
			else:
				r.visita.erase("montando_atracao");r.visita.erase("montagem_passos");r.visita.aguarda_seta=true;r.automatico=true;o.fase="seta";pedir_seta(o)
			jogo.livro.alterado.emit()
func opcoes_robo(menu:CanvasLayer,r:PersonagemPlex) -> void:
	for o in fila:
		if int(o.get("robo",-1))!=r.identificador:continue
		if o.fase=="plastico_mesa":menu.adicionar("Colocar plástico",func():continuar(int(o.ponto)))
		elif o.fase=="pronto_plastico":menu.adicionar("Colocar roupa · $%d"%int(PRECOS.carcaca),func():continuar(int(o.ponto)))
func pedir_seta(o:Dictionary) -> void:
	var r:=ator(int(o.robo))
	if not is_instance_valid(r):return
	if is_instance_valid(jogo.painel.hud):jogo.painel.hud.livro_ui.fechar()
	jogo.editor.alvo_pose_atracao=r.identificador;jogo.escolher_ferramenta("pose");jogo.pausa_automatica();jogo.painel.mensagem("Posicione a seta do animatrônico no palco.")
func definir_pose(id:int,pose:int) -> bool:
	var r:=ator(id);var marca:Dictionary=jogo.planta.objetos.get(pose,{})
	if is_instance_valid(r) and r.visita.has("oficina_robo") and r.visita.oficina_robo.get("etapa","") not in ["indo","estacionado"]:return false
	if not is_instance_valid(r) or marca.is_empty() or not jogo.poses.livre(pose,r) or r.visita.get("montando_atracao",false):return false
	var rota:Array[Vector2i]=jogo.rotas.caminho(r.origem_rota(),marca.celula)
	if rota.is_empty():return false
	var antiga:Dictionary=jogo.planta.objetos.get(r.pose,{})
	if not antiga.is_empty() and int(antiga.id)!=pose and str(antiga.tipo)=="pose":
		if int(antiga.get("seta_de",-1))==id:jogo.planta.remover(int(antiga.id))
		elif int(antiga.get("dono",-1))==id:antiga.dono=-1
	jogo.oficina.liberar_reservas(r);r.visita.erase("oficina_robo");r.visita.erase("diagnostico_animacao");r.visita.erase("diagnostico_rota")
	r.visita.erase("recolhendo_deposito");r.visita.erase("destino_deposito");r.visita.erase("bancada_montagem");r.visita.erase("montagem_olhar_jogador");r.visita.erase("montagem_tela");r.visita.erase("montagem_rotacao");marca.dono=id;r.pose=pose;r.robotica.pose_palco=pose;r.visita.erase("aguarda_seta");r.trabalho="ir_pose";r.automatico=true;AnimatronicosPlex.garantir(r);r.robotica.desligado_manual=false;AnimatronicosPlex.mudar(r,"deslocando");r.andar(rota)
	for o in fila:
		if int(o.robo)==id:o.fase="caminhando"
	jogo.livro.alterado.emit();return true
func manutencao(id:int,servico:String) -> bool:
	var r:=ator(id)
	if servico=="reparo" and is_instance_valid(r):return jogo.oficina.recolher(r,"olhos" if r.modelo==MODELO else "estrutura")
	if servico not in ["reparo","troca_carcaca","desmontar"]:return false
	if not is_instance_valid(r) or not AtracoesCatalogoPlex.permitido(r.modelo) or r.visita.get("montando_atracao",false) or fila.any(func(o):return int(o.robo)==id):return false
	var pontos:Array=jogo.planta.objetos.values().filter(func(o):return o.tipo=="area_montagem_atracao" and ordem(int(o.id)).is_empty())
	if servico=="desmontar":pontos=jogo.planta.objetos.values().filter(func(o):return MobiliaPlex.dados(o).get("triturador",false))
	if pontos.is_empty():jogo.painel.mensagem("Coloque uma bancada de montagem livre ou um triturador para a reciclagem.");return false
	for p in pontos:
		var rota:Array[Vector2i]=jogo.rotas.aproximar(r.origem_rota(),int(p.id))
		if rota.is_empty():continue
		if not pagar(servico):return false
		r.pose=-1;r.robotica.desligado_manual=true;r.trabalho="ir_manutencao";r.andar(rota)
		fila.append({"modelo":r.modelo,"ponto":p.id,"fase":"aguardar_robo","servico":servico,"tempo":0.0,"parte":52 if servico=="desmontar" else 0,"robo":id,"ator":-1,"caixas":[]});return true
	return false
func atualizar(delta:float) -> void:
	partes_tempo+=delta;espera+=delta
	if espera<.2:return
	var tempo:=partes_tempo;espera=0;partes_tempo=0;montagem(tempo)
	for r in jogo.personagens:
		if not r.robo or not AtracoesCatalogoPlex.permitido(r.modelo):continue
		AnimatronicosPlex.garantir(r)
		if OficinaRobosPlex.controlado(r):continue
		if r.visita.get("montando_atracao",false) or r.visita.get("aguarda_seta",false):AnimatronicosPlex.mudar(r,"desligado");continue
		if fila.any(func(o):return int(o.robo)==r.identificador and o.fase=="aguardar_robo"):continue
		if PossessaoPlex.atualizar(r,tempo):continue
		r.robotica.tempo_estado=float(r.robotica.tempo_estado)+tempo
		if r.ocupado():AnimatronicosPlex.mudar(r,"deslocando");continue
		var marca:Dictionary=jogo.planta.objetos.get(r.pose,{})
		if marca.is_empty():r.pose=-1;continue
		if r.celula!=marca.celula:
			var rota:Array[Vector2i]=jogo.rotas.caminho(r.origem_rota(),marca.celula)
			if not rota.is_empty():r.andar(rota)
			continue
		r.trabalho="apresentar";r.direcao=GradePlex.direcao_suporte(int(marca.rotacao))
		var plateia:bool=jogo.personagens.any(func(a):return a.cargo in ["crianca","adolescente"] and a.trabalho=="assistir" and jogo.animatronicos.palcos.da_pose(int(a.visita.get("pose",-1)))==jogo.animatronicos.palcos.da_pose(r.pose))
		var ligar:bool=not AnimatronicosPlex.pausado(r) and not r.robotica.avariado and (plateia or jogo.sistemas.shows.ativo(r) or r.robotica.get("modo","")=="sempre")
		var estado:=str(r.robotica.estado)
		if r.robotica.avariado:AnimatronicosPlex.mudar(r,"avariado")
		elif ligar:
			if estado in ["desligado","desligando","avariado","deslocando"]:AnimatronicosPlex.mudar(r,"ativando")
			elif estado=="ativando" and float(r.robotica.tempo_estado)>=1.9:AnimatronicosPlex.mudar(r,"ligado")
		else:
			if estado in ["ligado","ativando"]:AnimatronicosPlex.mudar(r,"desligando")
			elif estado=="desligando" and float(r.robotica.tempo_estado)>=1.5:AnimatronicosPlex.mudar(r,"desligado")
		if ligar:
			r.robotica.segundos_uso=float(r.robotica.get("segundos_uso",0.0))+tempo
			while float(r.robotica.segundos_uso)>=60.0:
				r.robotica.segundos_uso-=60.0
				r.robotica.minutos_uso=int(r.robotica.get("minutos_uso",0))+1
			r.robotica.desgaste=minf(2.0,float(r.robotica.get("desgaste",0))+tempo*.0004)
			if float(r.robotica.desgaste)>=2.0:
				r.robotica.avariado=true
				AnimatronicosPlex.mudar(r,"avariado")
func gravar() -> Array:return fila.duplicate(true)
func restaurar(dados:Array) -> void:
	fila=[]
	for o in dados:
		if not AtracoesCatalogoPlex.permitido(str(o.get("modelo",""))):continue
		liberar(o)
		if not o.has("conjunto_vi"):
			o.conjunto_vi=true
			var etapa:=str(o.get("fase_suspendida","endo")) if o.fase=="aguardar_bancada" else str(o.fase)
			o.olhos_configurados=etapa!="endo" or int(o.get("instaladas",0))>=3 or int(o.get("parte",0))>=17
			o.plastico_configurado=etapa in ["carcaca","seta","caminhando","reparo","troca_carcaca","desmontar","aguardar_robo"]
			if etapa=="endo" and not o.olhos_configurados and int(o.get("preparadas",0))>=17:o.minigame_pendente="olhos";o.minigame_estado={}
			elif etapa=="pronto_plastico" and not o.plastico_configurado:o.minigame_pendente="plastico";o.minigame_estado={}
		if o.fase in ["endo","plastico","carcaca"] and not o.has("operacao"):
			o.operacao="preparar" if o.fase in ["endo","carcaca"] else "instalar";o.preparadas=0;o.instaladas=0
			o.bancada=int(o.ponto)
			var livres:Array=jogo.planta.objetos.values().filter(func(p):return p.tipo=="area_montagem_atracao" and not fila.any(func(v):return int(v.ponto)==int(p.id)))
			if not livres.is_empty():o.ponto=livres[0].id
			else:o.fase_suspendida=o.fase;o.fase="aguardar_bancada";o.ponto=-1
			var robo:=ator(int(o.robo))
			if is_instance_valid(robo) and jogo.planta.objetos.has(int(o.ponto)):posicionar_na_bancada(robo,jogo.planta.objetos[int(o.ponto)])
		for item in jogo.planta.objetos.values():
			if int(item.get("ordem_montagem",-1))!=int(o.ponto):continue
			item.modelo_vi=str(o.modelo)
			if int(item.get("modulo",-1))==2:item.olhos_configurados=bool(o.get("olhos_configurados",false))
		var pendente:=str(o.get("minigame_pendente",""))
		if (str(o.modelo)=="vi_patitas" and pendente=="olhos") or (str(o.modelo)==MODELO and pendente=="plastico"):
			o.minigame_pendente="";o.minigame_estado={}
			if pendente=="olhos":o.olhos_configurados=true;o.operacao="buscar"
			else:o.plastico_configurado=true;o.retomar_apos_migracao=true
		fila.append(o.duplicate(true))
func retomar(modelo:String) -> bool:
	for o in fila:
		if o.modelo==modelo and o.fase=="seta":pedir_seta(o);return true
	return false
func redefinir_lugar(id:int) -> bool:
	var r:=ator(id)
	if not is_instance_valid(r) or not r.robo or r.visita.get("montando_atracao",false):return false
	jogo.carteira.fechar();pedir_seta({"robo":id});return true
func destino_valido(id:int,celula:Vector2i) -> bool:
	var r:=ator(id)
	return is_instance_valid(r) and jogo.planta.transitavel(celula) and not jogo.rotas.caminho(r.origem_rota(),celula).is_empty()

func posicionar_na_bancada(r:PersonagemPlex,p:Dictionary) -> void:
	var tamanho:=CatalogoPlex.dimensoes(str(p.tipo),int(p.rotacao));r.local=Vector2(p.celula)+Vector2(tamanho-Vector2i.ONE)*.5;r.celula=Vector2i(r.local.round());r.visita.bancada_montagem=p.id;r.visita.montagem_rotacao=posmod(-GradePlex.visao,4);r.visita.montagem_olhar_jogador=true;r.visita.montagem_altura=.12;r.direcao=posmod(GradePlex.visao*2,8)

func pesquisado(modelo:String=MODELO) -> bool:return jogo.livro.possui(modelo) and jogo.estudos.concluidos.has(modelo)
func mesa_livre(base:int) -> int:
	var candidatos:Array=jogo.planta.objetos.values().filter(func(p):return p.tipo in [BANCADA,"oficina_bancada_trabalho"] and not p.has("reparo_reserva") and not fila.any(func(o):return int(o.get("bancada",-1))==int(p.id) and int(o.ponto)!=base))
	if candidatos.is_empty():return -1
	var pos:Vector2=Vector2(jogo.planta.objetos.get(base,{"celula":Vector2i.ZERO}).celula)
	candidatos.sort_custom(func(a,b):return Vector2(a.celula).distance_squared_to(pos)<Vector2(b.celula).distance_squared_to(pos))
	return int(candidatos[0].id)
func criar_modulo(o:Dictionary,indice:int) -> int:
	var mesa:Dictionary=jogo.planta.objetos.get(int(o.bancada),{})
	if mesa.is_empty():return -1
	var id:int=jogo.planta.inserir("sistema_modulo_coelho_"+str(indice),mesa.celula,int(mesa.rotacao),{"pai":mesa.id,"slot":slot_modulo(indice)},{"ordem_montagem":int(o.ponto),"modulo":indice,"modelo_vi":str(o.modelo),"olhos_configurados":bool(o.get("olhos_configurados",false))})
	return id
static func slot_modulo(indice:int) -> int:return indice-4 if indice>=4 else mini(indice,2)
func retirar_modulo(a:PersonagemPlex) -> void:
	if a.visita.get("modulo_montagem",false):
		var id:=a.carga_item;a.carga_item=-1;a.carregando=false;a.visita.erase("modulo_montagem")
		if jogo.planta.objetos.has(id):jogo.planta.remover(id)
func executar_preparacao(o:Dictionary,a:PersonagemPlex,ponto:Dictionary,delta:float) -> bool:
	var operacao:=str(o.get("operacao","instalar"))
	if operacao=="preparar":
		a.trabalho="montar";a.visita.anim_ferramenta=o.fase=="carcaca";jogo.tarefas.olhar_objeto(a,int(ponto.id));o.tempo=float(o.tempo)+delta*HabilidadesEquipePlex.fator(a,"manutencao")
		a.progresso_acao=fposmod(float(o.tempo)/2.4,1)
		if float(o.tempo)<TEMPO_PARTE:return true
		o.tempo=0.0;o.preparadas=int(o.get("preparadas",0))+1
		if o.fase=="endo":
			if int(o.preparadas) in [6,14,17]:
				var indice:=[6,14,17].find(int(o.preparadas));criar_modulo(o,indice);jogo.sistemas.baloes.exibir(a,["Pernas e pélvis prontas.","Busto e braços prontos.","Cabeça pronta."][indice],4)
			if int(o.preparadas)>=17:
				o.operacao="buscar"
				if o.get("conjunto_vi",false) and str(o.modelo)==MODELO and not o.get("olhos_configurados",false):solicitar_minigame(o,"olhos")
				elif str(o.modelo)=="vi_patitas":o.olhos_configurados=true
		elif o.fase=="plastico":
			if int(o.preparadas) in [6,12,17]:
				var parte:=[6,12,17].find(int(o.preparadas));criar_modulo(o,4+parte);jogo.sistemas.baloes.exibir(a,["Pernas de plástico prontas.","Busto de plástico pronto.","Cabeça de plástico pronta."][parte],4)
			if int(o.preparadas)>=17:
				liberar(o);o.fase="plastico_mesa"
				jogo.painel.mensagem("As 3 peças de plástico estão na bancada. Clique no endo ou na base e escolha Colocar plástico.")
				jogo.livro.alterado.emit()
		else:
			if int(o.preparadas)==1:jogo.sistemas.baloes.exibir(a,"Costurando a roupa...",4)
			if int(o.preparadas)>=18:criar_modulo(o,3);o.operacao="buscar";jogo.sistemas.baloes.exibir(a,"Roupa costurada. Vou vesti-la no animatrônico.",4)
		return true
	if operacao=="buscar":
		var indice:=int(o.get("instaladas",0)) if o.fase=="endo" else 4+int(o.get("instaladas",0)) if o.fase=="plastico" else 3
		var modulos:Array=jogo.planta.objetos.values().filter(func(peca):return int(peca.get("ordem_montagem",-1))==int(o.ponto) and int(peca.get("modulo",-1))==indice)
		var id:=int(modulos[0].id) if not modulos.is_empty() else criar_modulo(o,indice)
		if id<0:return true
		var base:Dictionary=jogo.planta.objetos.get(int(o.ponto),{})
		if base.is_empty() or posicao_trabalho(a,base).is_empty():pausar_ator(a,"Sem acesso");return true
		var p:Dictionary=jogo.planta.objetos[id];p.sobre=-1;p.slot=-1;p.carregada_por=a.identificador
		a.carga_item=id;a.caixa_tipo=str(p.tipo);a.carregando=true;p.origem_sobre=ponto.id;p.origem_slot=slot_modulo(indice);p.origem_celula=[ponto.celula.x,ponto.celula.y];a.visita.modulo_montagem=true;o.operacao="instalar";o.tempo=0.0;jogo.planta.alterada.emit()
		jogo.sistemas.baloes.exibir(a,"Levando "+str(MobiliaPlex.dados(p).nome).to_lower()+" à base.",4)
		return true
	if o.fase=="carcaca" and a.visita.get("modulo_montagem",false):retirar_modulo(a)
	return false

func bloqueado(a:PersonagemPlex,o:Dictionary) -> bool:
	if a.visita.get("morto",false) or a.visita.get("fora_turno",false) or not str(a.visita.get("rotina_casa_etapa","")).is_empty() or TurnosEquipePlex.ocupado(a) or a.visita.get("saindo_fechamento",false):return true
	if int(o.get("manual",-1))==a.identificador and a.visita.get("controle_manual",false):return a.visita.get("preso",false) or a.visita.get("fugindo",false)
	return ControleAdministradorPlex.ocupado(a)
func pausar_ator(a:PersonagemPlex,motivo:String="Pausada") -> void:
	for o in fila:
		if int(o.get("ator",-1))!=a.identificador:continue
		liberar(o);o.pausada=true;o.motivo=motivo;o.bloqueio_revisao=jogo.planta.revisao
func retomar_trabalho(id:int) -> bool:
	var o:=ordem(id)
	if not o.is_empty() and not str(o.get("minigame_pendente","")).is_empty():abrir_minigame(o);return true
	if o.is_empty() or o.fase not in ["endo","plastico","carcaca","reparo","troca_carcaca","desmontar"]:return false
	liberar(o);o.pausada=false;o.motivo="";o.busca=0.0;o.manual=-1
	var a:PersonagemPlex=jogo.controle.administrador()
	if jogo.controle.manual() and is_instance_valid(a):
		jogo.controle.cancelar_acao();jogo.controle.interromper(a)
		o.ator=a.identificador;o.manual=a.identificador;a.visita.obra_atracao=true;jogo.controle.acao={"tipo":"montar_atracao","ponto":int(o.ponto)}
	return true

func solicitar_minigame(o:Dictionary,tipo:String) -> void:
	if tipo!=("plastico" if str(o.modelo)=="vi_patitas" else "olhos"):return
	o.minigame_pendente="";o.minigame_estado={}
	if tipo=="olhos":
		o.olhos_configurados=true
		for item in jogo.planta.objetos.values():
			if int(item.get("ordem_montagem",-1))==int(o.ponto) and int(item.get("modulo",-1))==2:item.olhos_configurados=true
	else:o.plastico_configurado=true;continuar(int(o.ponto))
func abrir_minigame(o:Dictionary,_confirmar:bool=false) -> void:
	solicitar_minigame(o,"plastico" if str(o.modelo)=="vi_patitas" else "olhos")
func minigame_aberto() -> bool:return is_instance_valid(minigame_ui) and minigame_ui.aberto()
func abrir_reparo_olhos(o:Dictionary) -> void:
	if not is_instance_valid(minigame_ui):minigame_ui=MinigamesVIPlex.new();jogo.add_child(minigame_ui);minigame_ui.configurar(jogo,self)
	minigame_ui.abrir(o)
func concluir_minigame(o:Dictionary,tipo:String) -> bool:
	if int(o.get("oficina_reparo",-1))>0:return tipo=="olhos" and jogo.oficina.concluir_olhos(o)
	if not fila.has(o) or str(o.get("minigame_pendente",""))!=tipo:return false
	o.minigame_pendente="";o.minigame_estado={};o.pausada=false;o.busca=0.0
	if tipo=="olhos":
		o.olhos_configurados=true;o.operacao="buscar";o.tempo=0.0
		for item in jogo.planta.objetos.values():
			if int(item.get("ordem_montagem",-1))==int(o.ponto) and int(item.get("modulo",-1))==2:item.olhos_configurados=true
		jogo.planta.alterada.emit()
	else:
		o.plastico_configurado=true
		continuar(int(o.ponto))
	jogo.livro.alterado.emit()
	return true

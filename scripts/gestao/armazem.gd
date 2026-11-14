class_name ArmazemRobosPlex
extends RefCounted

const PAR={"novo_coelho_detalhes":"vi_toy_orelhitas","vi_toy_orelhitas":"novo_coelho_detalhes","vi_patitas":"vi_toy_patitas","vi_toy_patitas":"vi_patitas"}
const DEITADOS=["vi_toy_orelhitas_quebrado"]
const ANTIGOS=["novo_coelho_detalhes","vi_patitas"]
const QUEBRADO={"novo_coelho_detalhes":"vi_orelhitas_quebrado","vi_toy_orelhitas":"vi_toy_orelhitas_quebrado","vi_patitas":"vi_patitas_quebrado","vi_toy_patitas":"vi_toy_patitas_quebrado"}
const INTEIRO={"vi_orelhitas_quebrado":"novo_coelho_detalhes","vi_toy_orelhitas_quebrado":"vi_toy_orelhitas","vi_patitas_quebrado":"vi_patitas","vi_toy_patitas_quebrado":"vi_toy_patitas"}
var jogo:Node
var escolhendo:=-1
var lugar:=-1
var espera:=0.0
const PASSOS:=52
const DESMONTE={"novo_coelho_detalhes":"of_desmonte_orelhitas","vi_toy_orelhitas":"of_desmonte_toy_orelhitas"}
const QUADROS_DESMONTE=["e0","s1","e1","s2","e2","s3","e3","s4","e4","e5"]
const TEMPO_PASSO:=1.2

func _init(cena:Node) -> void:jogo=cena
func ator(id:int) -> PersonagemPlex:return jogo.clientes.ator(id)
func custo() -> float:
	var p:Dictionary=MontagemAtracoesPlex.PRECOS
	return (float(p.endo)+float(p.plastico)+float(p.carcaca))*.5
func aviso(texto:String) -> void:jogo.painel.mensagem(texto)
func existe(modelo:String) -> bool:return jogo.personagens.any(func(p):return p.robo and p.modelo==modelo)
func celula_armazem() -> Vector2i:
	for p in jogo.personagens:
		if p.robo and p.robotica.has("armazem"):
			var c:Array=p.robotica.armazem
			if jogo.ambientes.em(Vector2i(int(c[0]),int(c[1]))).get("fechada",false):return Vector2i(int(c[0]),int(c[1]))
	return Vector2i(-1,-1)
func sala_vazia(sala:Dictionary) -> bool:
	if not sala.get("fechada",false) or sala.get("celulas",{}).is_empty():return false
	for o in jogo.planta.objetos.values():
		var tipo:=str(o.tipo)
		if tipo in SalasPlex.ESTRUTURA or tipo in CatalogoPlex.PORTAS or LuminariasPlex.eh(tipo) or MobiliaPlex.dados(o).get("piso",false):continue
		if sala.celulas.has(o.celula):return false
	return true
func livre(celula:Vector2i,r:PersonagemPlex) -> Vector2i:
	var sala:Dictionary=jogo.ambientes.em(celula)
	var lista:Array=sala.get("celulas",{}).keys()
	lista.sort_custom(func(x,y):return Vector2i(x).distance_squared_to(celula)<Vector2i(y).distance_squared_to(celula))
	for c in lista:
		var alvo:Vector2i=c
		if not jogo.planta.transitavel(alvo) or ocupada(alvo,r):continue
		if alvo==r.celula or not jogo.rotas.caminho(r.origem_rota(),alvo).is_empty():return alvo
	return Vector2i(-1,-1)

func opcao_atualizar(menu:CanvasLayer,r:PersonagemPlex) -> void:
	if r.robotica.get("armazenado",false) or r.visita.has("troca_toy") or r.visita.has("toy_em_montagem") or not PAR.has(r.modelo) or r.modelo not in ANTIGOS or jogo.controle_robo.controlado(r):return
	if existe(PAR[r.modelo]) or existe(QUEBRADO[PAR[r.modelo]]):return
	menu.adicionar("Atualizar · Toy (US$ %.0f)"%custo(),func():iniciar(r))
func iniciar(r:PersonagemPlex) -> void:
	if jogo.servicos.saldo<custo():aviso("Saldo insuficiente. A atualização custa US$ %.0f (50%% das peças, reaproveitando o antigo)."%custo());return
	var destino:Dictionary=jogo.oficina.vaga(r,true)
	if destino.is_empty():aviso("Para atualizar é preciso uma base de montagem livre com bancada de conserto acessível.");return
	var rota:Array[Vector2i]=jogo.rotas.aproximar(r.origem_rota(),int(destino.mesa))
	if rota.is_empty() and not jogo.planta.interacoes(int(destino.mesa)).has(r.celula):aviso("O animatrônico não tem caminho até a bancada.");return
	jogo.servicos.saldo=snappedf(jogo.servicos.saldo-custo(),.01)
	var pose:=r.pose if r.pose>=0 else int(r.visita.get("palco_anterior",r.robotica.get("pose_palco",-1)))
	jogo.oficina.liberar_palco(r)
	jogo.planta.objetos[int(destino.base)].robo_reserva=r.identificador
	jogo.planta.objetos[int(destino.mesa)].reparo_reserva=r.identificador
	r.visita.troca_toy={"etapa":"indo","base":int(destino.base),"mesa":int(destino.mesa),"novo":-1,"progresso":0.0,"ator":-1,"pose":pose,"modelo":str(PAR[r.modelo])}
	r.automatico=false;r.trabalho="ir_oficina_robo"
	if not rota.is_empty():r.andar(rota)
func clicar(celula:Vector2i) -> bool:
	if escolhendo<0:return false
	var r:=ator(escolhendo);escolhendo=-1
	if not is_instance_valid(r):return true
	if not sala_vazia(jogo.ambientes.em(celula)):aviso("Essa sala não serve. O armazém precisa ser uma sala fechada e sem itens.");return true
	confirmar(r,celula);return true
func cancelar() -> bool:
	if lugar>=0:
		lugar=-1;jogo.escolher_ferramenta("selecionar");aviso("Escolha do lugar cancelada. Clique no animatrônico quebrado para escolher depois.");return true
	if escolhendo<0:return false
	escolhendo=-1;aviso("Escolha do armazém cancelada.");return true
func confirmar(r:PersonagemPlex,celula:Vector2i) -> void:
	var destino:=livre(celula,r)
	if destino.x<0:aviso("O animatrônico não tem caminho até o armazém.");return
	jogo.servicos.saldo=snappedf(jogo.servicos.saldo-custo(),.01)
	var pose:=r.pose if r.pose>=0 else int(r.visita.get("palco_anterior",r.robotica.get("pose_palco",-1)))
	jogo.oficina.liberar_palco(r)
	r.robotica.armazem=[celula.x,celula.y];r.robotica.troca={"novo":PAR[r.modelo],"pose":pose}
	marcar_sala(celula)
	mandar(r,destino)
func mandar(r:PersonagemPlex,destino:Vector2i) -> void:
	r.automatico=false;r.visita.indo_armazem=true;r.trabalho="ir_armazem"
	if destino==r.celula:return
	r.andar(jogo.rotas.caminho(r.origem_rota(),destino))
func guardar(r:PersonagemPlex) -> void:
	var c:Array=r.robotica.get("armazem",[r.celula.x,r.celula.y])
	var destino:=livre(Vector2i(int(c[0]),int(c[1])),r)
	if destino.x>=0:mandar(r,destino)
	else:desligar(r)

func trocar(r:PersonagemPlex,modelo:String) -> PersonagemPlex:
	var n:PersonagemPlex=jogo.criar_personagem(modelo,r.celula,r.cargo,true,{})
	if not is_instance_valid(n):return null
	n.robotica=r.robotica.duplicate(true);n.identidade=r.identidade.duplicate(true);n.identidade.erase("nome");n.direcao=r.direcao
	if r.visita.has("corpo_oculto"):n.visita.corpo_oculto=r.visita.corpo_oculto
	IdentidadesPlex.garantir(n)
	jogo.despawn(r)
	return n
func desligar(r:PersonagemPlex) -> void:
	r.robotica.armazenado=true;r.robotica.bateria=0.0;r.robotica.desligado_manual=true;r.robotica.erase("pose_dia")
	r.automatico=false;r.pose=-1;r.trabalho="armazenado";r.movimento.cancelar();AnimatronicosPlex.mudar(r,"desligado")
	deitar(r)
func segunda(p:PersonagemPlex) -> Vector2i:
	if p.modelo not in DEITADOS or not p.robotica.has("deitado"):return Vector2i(-1,-1)
	var d:Array=p.robotica.deitado
	if Vector2i(int(d[0]),int(d[1]))!=p.celula:return Vector2i(-1,-1)
	return Vector2i(int(d[2]),int(d[3]))
func ocupada(c:Vector2i,r:PersonagemPlex=null) -> bool:
	return jogo.personagens.any(func(p):return p!=r and (p.celula==c or p.robo and segunda(p)==c))
func deitar(r:PersonagemPlex) -> bool:
	if r.modelo not in DEITADOS:return true
	for passo in [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]:
		var atras:Vector2i=r.celula-passo
		if GradePlex.projetar_vetor(Vector2(-passo)).y>=0.0 or not jogo.planta.transitavel(atras) or ocupada(atras,r):continue
		jogo.tarefas.orientar(r,r.local+Vector2(passo))
		r.robotica.deitado=[r.celula.x,r.celula.y,atras.x,atras.y]
		return true
	r.robotica.erase("deitado")
	return false
func ativar(n:PersonagemPlex,pose:int,celula:Array) -> void:
	n.robotica.erase("armazenado");n.robotica.bateria=100.0;n.robotica.desligado_manual=false;n.robotica.armazem=celula;n.trabalho=""
	AnimatronicosPlex.garantir(n)
	if pose<0:pose=int(n.robotica.get("pose_palco",-1))
	if pose>=0 and jogo.planta.objetos.has(pose) and jogo.atracoes.definir_pose(n.identificador,pose):return
	n.visita.palco_anterior=pose
	aviso("O lugar no palco está ocupado ou sem acesso. Use Redefinir lugar no "+IdentidadesPlex.completo(n)+".")

func chegou(r:PersonagemPlex) -> void:
	r.visita.erase("indo_armazem")
	var troca:Dictionary=r.robotica.get("troca",{})
	r.robotica.erase("troca")
	if troca.is_empty() or not QUEBRADO.has(r.modelo):desligar(r);return
	var celula:Array=r.robotica.get("armazem",[r.celula.x,r.celula.y])
	var novo_modelo:=str(troca.novo);var pose:=int(troca.get("pose",-1))
	var carcaca:PersonagemPlex=null
	for p in jogo.personagens:
		if p.robo and p.modelo==str(QUEBRADO.get(novo_modelo,"")) and p.robotica.get("armazenado",false):carcaca=p
	var velho:=trocar(r,str(QUEBRADO[r.modelo]))
	if is_instance_valid(velho):desligar(velho)
	var novo:PersonagemPlex
	if is_instance_valid(carcaca):
		var vaga:Vector2i=carcaca.celula
		novo=trocar(carcaca,novo_modelo)
		if is_instance_valid(novo):novo.celula=vaga;novo.local=Vector2(vaga)
	else:
		var c:=livre(Vector2i(int(celula[0]),int(celula[1])),velho if is_instance_valid(velho) else r)
		if c.x<0:c=Vector2i(int(celula[0]),int(celula[1]))
		novo=jogo.criar_personagem(novo_modelo,c,"atracao",true,{})
		if is_instance_valid(novo):novo.robotica.assombrado=false
	if not is_instance_valid(novo):aviso("Não foi possível montar o novo animatrônico.");return
	ativar(novo,pose,celula)
	aviso(IdentidadesPlex.completo(novo)+" está pronto e indo para o palco. A carcaça antiga ficou no armazém.")

func opcoes(menu:CanvasLayer,r:PersonagemPlex) -> bool:
	if r.visita.has("toy_em_montagem"):return true
	if r.visita.has("troca_toy"):
		if str(r.visita.troca_toy.etapa)=="posicionar":menu.adicionar("Escolher lugar",func():pedir_lugar(r))
		return true
	if not r.robotica.get("armazenado",false):return false
	if not INTEIRO.has(r.modelo):return true
	var inteiro:=str(INTEIRO[r.modelo])
	if not existe(inteiro):menu.adicionar("Reconstruir (US$ %.0f)"%custo()+(" · quebra o Toy" if inteiro in ANTIGOS else " · quebra o antigo"),func():reconstruir(r))
	return true
func reconstruir(carcaca:PersonagemPlex) -> void:
	if jogo.servicos.saldo<custo():aviso("Saldo insuficiente. A reconstrução custa US$ %.0f."%custo());return
	var inteiro:=str(INTEIRO[carcaca.modelo])
	var ativo:PersonagemPlex=null
	for p in jogo.personagens:
		if p.robo and p.modelo==str(PAR.get(inteiro,"")) and not p.robotica.get("armazenado",false):ativo=p
	var celula:Array=carcaca.robotica.get("armazem",[carcaca.celula.x,carcaca.celula.y])
	jogo.servicos.saldo=snappedf(jogo.servicos.saldo-custo(),.01)
	if not is_instance_valid(ativo):
		var palco_antigo:=int(carcaca.visita.get("palco_anterior",-1))
		var n:=trocar(carcaca,inteiro)
		if is_instance_valid(n):ativar(n,palco_antigo,celula)
		return
	if jogo.controle_robo.controlado(ativo):jogo.controle_robo.soltar(false)
	var destino:=livre(Vector2i(int(celula[0]),int(celula[1])),ativo)
	if destino.x<0:aviso("O "+IdentidadesPlex.completo(ativo)+" não tem caminho até o armazém.");jogo.servicos.saldo=snappedf(jogo.servicos.saldo+custo(),.01);return
	var pose:=ativo.pose if ativo.pose>=0 else int(ativo.visita.get("palco_anterior",ativo.robotica.get("pose_palco",-1)))
	jogo.oficina.liberar_palco(ativo)
	ativo.robotica.armazem=celula;ativo.robotica.troca={"novo":inteiro,"pose":pose}
	mandar(ativo,destino)

func marcar_sala(celula:Vector2i) -> void:
	var sala:Dictionary=jogo.ambientes.em(celula)
	if not sala.get("fechada",false) or str(sala.get("tipo",""))=="armazem_robos":return
	jogo.ambientes.definir(celula,"armazem_robos")
func base(modelo:String) -> String:return str(INTEIRO.get(modelo,modelo))
func encaixar(novo:PersonagemPlex) -> void:
	var familia:=base(novo.modelo)
	for p in jogo.personagens.duplicate():
		if p!=novo and p.robo and base(p.modelo)==familia:jogo.despawn(p)
	if not PAR.has(familia):return
	var par:=str(PAR[familia])
	var quebrado:=INTEIRO.has(novo.modelo)
	for p in jogo.personagens.duplicate():
		if p==novo or not p.robo or base(p.modelo)!=par:continue
		if not quebrado and p.modelo==par:
			var q:=trocar(p,str(QUEBRADO[par]))
			if is_instance_valid(q):guardar_aqui(q)
		elif quebrado and p.modelo!=par:
			var n:=trocar(p,par)
			if is_instance_valid(n):n.robotica.erase("armazenado");n.robotica.bateria=100.0;n.trabalho="";n.automatico=false;n.robotica.desligado_manual=true;AnimatronicosPlex.mudar(n,"desligado")
func guardar_aqui(r:PersonagemPlex) -> void:
	if not r.robotica.has("armazem"):r.robotica.armazem=[r.celula.x,r.celula.y]
	desligar(r)
	var c:Array=r.robotica.armazem
	marcar_sala(Vector2i(int(c[0]),int(c[1])))
func atualizar(delta:float) -> void:
	espera+=delta
	if espera<.4:return
	var dt:=espera;espera=0.0
	for r in jogo.personagens.duplicate():
		if not r.robo:continue
		if r.visita.has("troca_toy"):atualizar_troca(r,dt);continue
		if r.visita.get("indo_armazem",false):
			if not r.ocupado():chegou(r)
		elif INTEIRO.has(r.modelo) and not r.robotica.get("armazenado",false) and not jogo.controle_robo.controlado(r):guardar_aqui(r)
func atualizar_troca(r:PersonagemPlex,dt:float) -> void:
	var d:Dictionary=r.visita.troca_toy
	var base_toy:Dictionary=jogo.planta.objetos.get(int(d.base),{})
	var mesa:Dictionary=jogo.planta.objetos.get(int(d.mesa),{})
	match str(d.etapa):
		"indo":
			if r.ocupado() or base_toy.is_empty() or mesa.is_empty():return
			if not jogo.planta.interacoes(int(d.mesa)).has(r.celula):
				var rota:Array[Vector2i]=jogo.rotas.aproximar(r.origem_rota(),int(d.mesa))
				if not rota.is_empty():r.andar(rota)
				return
			r.trabalho="armazenado";r.robotica.bateria=100.0;jogo.tarefas.orientar_cardinal(r,Vector2(mesa.celula));AnimatronicosPlex.mudar(r,"desligado")
			var n:PersonagemPlex=jogo.criar_personagem(str(d.modelo),base_toy.celula,"atracao",true,{})
			if not is_instance_valid(n):return
			n.robotica.assombrado=false;n.automatico=false;n.visita.montando_atracao=true;n.visita.montagem_passos=1;n.visita.toy_em_montagem=r.identificador
			jogo.atracoes.posicionar_na_bancada(n,base_toy);base_toy.robo_reserva=n.identificador
			d.novo=n.identificador;d.etapa="transferir"
			if DESMONTE.has(r.modelo) and str(mesa.tipo)==MontagemAtracoesPlex.BANCADA:
				d.desmonte=str(DESMONTE[r.modelo])+("_sangue" if int(r.visita.get("corpo_oculto",-1))>0 else "")
				if not CatalogoPlex.objetos.has(d.desmonte):d.erase("desmonte")
			desmonte(r,d,mesa)
		"transferir":
			var n:=ator(int(d.novo))
			if not is_instance_valid(n) or base_toy.is_empty() or mesa.is_empty():return
			var progresso:=float(d.progresso)
			var fase:=0 if progresso<17.0 else 1 if progresso<34.0 else 2
			var local:float=progresso-[0.0,17.0,34.0][fase]
			var peca:=mini(2,floori(local/6.0))
			var inicio:=float(peca)*6.0
			var na_mesa:=local<inicio+((17.0 if peca==2 else inicio+6.0)-inicio)*.5
			var alvo:=int(d.mesa) if na_mesa else int(d.base)
			var adm:PersonagemPlex=jogo.controle.administrador()
			var a:PersonagemPlex=jogo.oficina.operario(d,alvo)
			var m:PersonagemPlex=jogo.sistemas.mecanico.mecanico()
			if not is_instance_valid(a) and is_instance_valid(m) and m.visita.get("mec_toy",false) and not m.visita.get("fora_turno",false) and not TurnosEquipePlex.ocupado(m):
				d.ator=m.identificador;d.manual=m.identificador;m.visita.obra_atracao=true;m.visita.oficina_trabalho=true;a=m
			if not is_instance_valid(a) and is_instance_valid(adm) and not adm.visita.get("fora_turno",false) and str(adm.visita.get("rotina_casa_etapa","")).is_empty() and not TurnosEquipePlex.ocupado(adm) and not adm.visita.get("morto",false):
				if jogo.controle.manual():jogo.controle.cancelar_acao();jogo.controle.interromper(adm)
				d.ator=adm.identificador;d.manual=adm.identificador;adm.visita.obra_atracao=true;adm.visita.oficina_trabalho=true
				a=adm
			var carregada:Dictionary=jogo.planta.objetos.get(int(d.get("peca_id",-1)),{})
			if not carregada.is_empty() and (not is_instance_valid(a) or int(carregada.get("carregada_por",0))!=a.identificador or na_mesa):soltar_peca(ator(int(carregada.get("carregada_por",0))),d)
			if not is_instance_valid(a) or a.ocupado():return
			if not na_mesa and fase<2 and not d.has("peca_id"):d.peca_id=pegar_peca(a,mesa,d,peca if fase==0 else 4+peca)
			if not jogo.planta.interacoes(alvo).has(a.celula):
				var rota:Array[Vector2i]=jogo.rotas.aproximar(a.origem_rota(),alvo)
				if not rota.is_empty():a.andar(rota);a.trabalho="ir_montar_atracao"
				return
			if int(d.get("fase_toy",-1))!=fase:
				d.fase_toy=fase
				jogo.sistemas.baloes.exibir(a,["Montando o endo do Toy com as peças do antigo.","Encaixando o plástico do Toy.","Costurando o pelo do Toy."][fase],4)
			jogo.tarefas.olhar_objeto(a,alvo)
			if is_instance_valid(adm) and adm.celula!=n.celula:jogo.tarefas.olhar_tela(n,Vector2(adm.celula))
			progresso+=dt*HabilidadesEquipePlex.fator(a,"manutencao")/TEMPO_PASSO
			d.progresso=progresso;a.trabalho="montar";a.visita.anim_ferramenta=fase==2;a.progresso_acao=fposmod(progresso,1.0)
			n.visita.montagem_passos=clampi(floori(progresso),1,PASSOS)
			desmonte(r,d,mesa)
			if progresso>=26.0 and not d.get("quebrou",false):
				d.quebrou=true
				var celula_velho:=r.celula
				var velho:=trocar(r,str(QUEBRADO[r.modelo]))
				if not is_instance_valid(velho):return
				velho.visita.troca_toy=d;velho.automatico=false;velho.trabalho="armazenado";velho.celula=celula_velho;velho.local=Vector2(celula_velho)
				AnimatronicosPlex.mudar(velho,"desligado")
				desmonte(velho,d,mesa)
				base_toy.robo_reserva=n.identificador;mesa.reparo_reserva=velho.identificador;n.visita.toy_em_montagem=velho.identificador
				return
			if progresso<PASSOS:return
			soltar_peca(a,d)
			if d.has("desmonte"):
				mesa.erase("desmonte_bancada");mesa.erase("desmonte_tipo");r.visita.erase("em_animacao");d.erase("desmonte")
			for chave in ["montando_atracao","montagem_passos","toy_em_montagem","bancada_montagem","montagem_olhar_jogador","montagem_tela","montagem_rotacao","montagem_altura"]:n.visita.erase(chave)
			n.robotica.desligado_manual=false;AnimatronicosPlex.mudar(n,"ligado")
			d.etapa="testar";d.teste=0;d.tempo_teste=0.0
			jogo.sistemas.baloes.exibir(a,"Pronto. Agora vamos testar as animações do Toy.",4)
			jogo.planta.alterada.emit()
		"testar":
			var n:=ator(int(d.novo))
			if not is_instance_valid(n):return
			var a:=ator(int(d.ator))
			if is_instance_valid(a) and not a.ocupado():a.trabalho="montar";a.visita.anim_ferramenta=false;jogo.tarefas.orientar_cardinal(a,n.local)
			var lista:Array=jogo.sistemas.mecanico.clipes(n)
			d.tempo_teste=float(d.tempo_teste)+dt
			if int(d.teste)<lista.size():
				n.visita.diagnostico_animacao=str(lista[int(d.teste)]);n.visita.diagnostico_tempo=float(d.tempo_teste)
				if float(d.tempo_teste)>=MecanicoNoturnoPlex.TEMPO_CLIPE:d.teste=int(d.teste)+1;d.tempo_teste=0.0
				return
			n.visita.erase("diagnostico_animacao");n.visita.erase("diagnostico_tempo")
			if is_instance_valid(a):a.visita.erase("mec_toy");jogo.sistemas.baloes.exibir(a,"Testes concluídos. O Toy está pronto!",4)
			jogo.oficina.liberar_operario(d)
			base_toy.erase("robo_reserva");mesa.erase("reparo_reserva")
			ativar(n,int(d.pose),[base_toy.celula.x,base_toy.celula.y])
			d.etapa="posicionar";jogo.planta.alterada.emit()
			perguntar_sala(r)
		"indo_lugar":
			if r.ocupado():return
			var c:Array=d.lugar;var celula:=Vector2i(int(c[0]),int(c[1]))
			if r.celula!=celula:
				var rota:Array[Vector2i]=jogo.rotas.caminho(r.origem_rota(),celula)
				if rota.is_empty():d.etapa="posicionar";aviso("O "+IdentidadesPlex.completo(r)+" não alcança o lugar escolhido. Escolha outro.");return
				r.andar(rota);return
			r.visita.erase("troca_toy");r.robotica.armazem=[celula.x,celula.y]
			desligar(r)
			var frente:=GradePlex.frente(int(c[2]))
			jogo.tarefas.orientar(r,r.local+Vector2(frente))
			if r.modelo in DEITADOS:
				var atras:=celula-frente
				r.robotica.deitado=[celula.x,celula.y,atras.x,atras.y]
			jogo.planta.alterada.emit()
func pegar_peca(a:PersonagemPlex,mesa:Dictionary,d:Dictionary,indice:int) -> int:
	var id:int=jogo.planta.inserir("sistema_modulo_coelho_"+str(indice),mesa.celula,int(mesa.rotacao),{"pai":mesa.id,"slot":MontagemAtracoesPlex.slot_modulo(indice)},{"modulo":indice,"modelo_vi":"vi_patitas" if str(d.modelo).contains("patitas") else MontagemAtracoesPlex.MODELO,"olhos_configurados":true})
	var p:Dictionary=jogo.planta.objetos[id];p.sobre=-1;p.slot=-1;p.carregada_por=a.identificador
	a.carga_item=id;a.caixa_tipo=str(p.tipo);a.carregando=true;jogo.planta.alterada.emit()
	return id
func soltar_peca(a:PersonagemPlex,d:Dictionary) -> void:
	var id:=int(d.get("peca_id",-1));d.erase("peca_id")
	if is_instance_valid(a) and a.carga_item==id:a.carga_item=-1;a.carregando=false
	if jogo.planta.objetos.has(id):jogo.planta.remover(id)
func desmonte(r:PersonagemPlex,d:Dictionary,mesa:Dictionary) -> void:
	if not d.has("desmonte"):return
	var quadro:=str(QUADROS_DESMONTE[clampi(floori(float(d.progresso)/float(PASSOS)*10.0),0,9)])
	if AmbientesAssetsPlex.obter(str(d.desmonte),GradePlex.rotacao_visual(int(mesa.rotacao)),quadro).get("textura")==null:
		d.erase("desmonte");r.visita.erase("em_animacao");mesa.erase("desmonte_bancada");mesa.erase("desmonte_tipo");jogo.planta.alterada.emit();return
	r.visita.em_animacao="desmonte"
	if str(mesa.get("desmonte_bancada",""))==quadro and str(mesa.get("desmonte_tipo",""))==str(d.desmonte):return
	mesa.desmonte_bancada=quadro;mesa.desmonte_tipo=str(d.desmonte)
	jogo.planta.alterada.emit()
func perguntar_sala(r:PersonagemPlex) -> void:
	var janela:=AvisoPlex.mostrar(jogo,"Guardar o antigo","Levar o "+IdentidadesPlex.completo(r)+" para uma sala vazia?","Sim","Não",420)
	janela.confirmado.connect(pedir_lugar.bind(r))
	janela.cancelado.connect(aviso.bind("O "+IdentidadesPlex.completo(r)+" fica ao lado da bancada. Clique nele para escolher um lugar depois."))
func pedir_lugar(r:PersonagemPlex) -> void:
	lugar=r.identificador
	jogo.escolher_ferramenta("pose_quebrado");jogo.pausa_automatica()
	aviso("Escolha onde o "+IdentidadesPlex.completo(r)+" vai ficar. A seta mostra para onde ele olha; R gira. Botão direito cancela.")
func posicionar(celula:Vector2i,rotacao:int) -> void:
	var r:=ator(lugar)
	if not is_instance_valid(r) or not r.visita.has("troca_toy"):lugar=-1;return
	if not GradePlex.dentro(celula) or not jogo.planta.transitavel(celula) or not jogo.planta.em(celula).is_empty() or not is_zero_approx(jogo.planta.altura(celula)) or ocupada(celula,r):aviso("Escolha um tile livre no chão.");return
	if r.modelo in DEITADOS:
		var atras:=celula-GradePlex.frente(rotacao)
		if not GradePlex.dentro(atras) or not jogo.planta.transitavel(atras) or not jogo.planta.em(atras).is_empty() or ocupada(atras,r):aviso("Deitado, ele ocupa 2 tiles: o da seta e o de trás. Os dois precisam estar livres e sem parede.");return
	if celula!=r.celula and jogo.rotas.caminho(r.origem_rota(),celula).is_empty():aviso("Sem caminho até esse lugar.");return
	var d:Dictionary=r.visita.troca_toy
	for id in [int(d.base),int(d.mesa)]:
		var p:Dictionary=jogo.planta.objetos.get(id,{})
		p.erase("robo_reserva");p.erase("reparo_reserva")
	d.lugar=[celula.x,celula.y,posmod(rotacao,4)];d.etapa="indo_lugar"
	lugar=-1;jogo.escolher_ferramenta("selecionar")


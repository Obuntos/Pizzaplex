class_name AmigosBairroPlex
extends RefCounted

const MODELOS={"amigo_coruja":"vi_coruja","amigo_arlequim":"vi_arlequim"}
const SESSAO:=12.0
const SUJEIRA_MAX:=4
var jogo:Node
var espera:=0.0
var noite_conserto:=-1
var consertos:=0

func _init(cena:Node) -> void:jogo=cena
static func eh(r:PersonagemPlex) -> bool:return is_instance_valid(r) and r.robo and r.modelo in ["vi_coruja","vi_arlequim"]
func dia() -> int:return int(jogo.calendario.dias)
func hora_controle() -> bool:return jogo.calendario.minutos>=240.0 and jogo.calendario.minutos<300.0
func fora_servico(r:PersonagemPlex) -> bool:return r.robotica.get("fora_servico",false)

func base(r:PersonagemPlex) -> Dictionary:return jogo.planta.objetos.get(int(r.robotica.get("amigo",-1)),{})
func frente(o:Dictionary) -> Vector2i:return o.celula+GradePlex.frente(int(o.rotacao))

func atualizar(delta:float) -> void:
	espera+=delta
	if espera<.25:return
	var dt:=espera;espera=0.0
	for o in jogo.planta.objetos.values():
		if MODELOS.has(str(o.tipo)) and not is_instance_valid(jogo.clientes.ator(int(o.get("amigo_robo",-1)))):criar(o)
	for r in jogo.personagens.duplicate():
		if not eh(r):continue
		var o:=base(r)
		if o.is_empty():
			if not r.visita.has("controle_animatronico"):jogo.despawn(r)
			continue
		if r.visita.has("controle_animatronico"):controle(r,o,dt);continue
		r.visita.diagnostico_tempo=float(r.visita.get("diagnostico_tempo",0.0))+dt
		if r.modelo=="vi_coruja":coruja(r,o,dt)
		else:arlequim(r,o,dt)
		r.modulate=Color.WHITE.darkened(.1*float(r.robotica.get("sujeira",0)))
	conserto_noturno(dt)

func criar(o:Dictionary) -> void:
	var r:PersonagemPlex=jogo.criar_personagem(str(MODELOS[str(o.tipo)]),o.celula,"atracao",true,{})
	if not is_instance_valid(r):return
	r.automatico=false;r.robotica.amigo=int(o.id);r.robotica.desligado_manual=true;r.local=Vector2(o.celula);r.celula=o.celula
	r.direcao=GradePlex.direcao_suporte(int(o.rotacao));r.trabalho="amigo"
	o.amigo_robo=r.identificador;o.variante="amigo_base"
	jogo.planta.alterada.emit()

func clipe(r:PersonagemPlex,nome:String) -> void:
	if str(r.visita.get("diagnostico_animacao",""))!=nome:r.visita.diagnostico_animacao=nome;r.visita.diagnostico_tempo=0.0

func ligado(r:PersonagemPlex) -> bool:return jogo.operacao.aberto and not fora_servico(r)

func criancas_livres(perto:Vector2i,raio:float) -> Array:
	return jogo.personagens.filter(func(a):return a.modelo=="crianca" and not a.visita.get("morto",false) and not a.ocupado() and not a.visita.has("em_animacao") and a.trabalho in ["visitar","aguardar_familia","assistir","assistir_mascote",""] and not a.visita.has("coruja") and not a.visita.has("arlequim") and a.local.distance_to(Vector2(perto))<=raio and str(jogo.clientes.grupos.get(a.familia,{}).get("estado",""))=="visita")

func coruja(r:PersonagemPlex,o:Dictionary,dt:float) -> void:
	r.direcao=GradePlex.direcao_suporte(int(o.rotacao))
	if not ligado(r):
		clipe(r,"desligado")
		liberar_coruja(r,o)
		return
	var sujeira:=int(r.robotica.get("sujeira",0))
	var grupo:Array=jogo.personagens.filter(func(a):return int(a.visita.get("coruja",-1))==r.identificador)
	if sujeira<SUJEIRA_MAX and grupo.size()<3 and randf()<.08:
		for a in criancas_livres(o.celula,14.0):
			if grupo.size()>=3:break
			if chamar_coruja(r,o,a):grupo.append(a)
	var presentes:Array=grupo.filter(func(a):return not a.ocupado() and a.local.distance_to(Vector2(o.celula))<=2.6)
	for a in presentes:jogo.tarefas.orientar(a,r.local)
	if presentes.is_empty():
		o.erase("coruja_sessao")
		var t:=fposmod(float(r.relogio),25.0)
		clipe(r,"olhar" if t<10.2 else "cantar" if t<16.0 else "parado")
		return
	clipe(r,"cantar" if fposmod(float(r.relogio),9.0)<6.0 else "olhar")
	o.coruja_sessao=float(o.get("coruja_sessao",0.0))+dt
	if float(o.coruja_sessao)<SESSAO:return
	if presentes.size()>=3:
		var tipo:=LembrancasPlex.desenho_palco(jogo)
		if tipo.is_empty():tipo=["festa_desenho_coelho","festa_desenho_casa","festa_desenho_estrelas"][randi()%3]
		jogo.servicos.recompensas.append({"tipo":tipo})
	else:
		r.robotica.sujeira=mini(SUJEIRA_MAX,sujeira+1)
		if int(r.robotica.sujeira)>=SUJEIRA_MAX:jogo.painel.mensagem("A Coruja está muito suja. Coloque-a Fora de serviço para o mecânico limpar à noite.")
	liberar_coruja(r,o)

func chamar_coruja(r:PersonagemPlex,o:Dictionary,a:PersonagemPlex) -> bool:
	var vagas:Array=jogo.clientes.vagas(frente(o),1,2)
	if vagas.is_empty():return false
	var rota:Array[Vector2i]=jogo.clientes.caminho(a.origem_rota(),vagas[0])
	if rota.is_empty():return false
	a.visita.coruja=r.identificador;a.trabalho="ver_coruja";a.andar(rota)
	return true

func liberar_coruja(r:PersonagemPlex,o:Dictionary) -> void:
	o.erase("coruja_sessao")
	for a in jogo.personagens:
		if int(a.visita.get("coruja",-1))!=r.identificador:continue
		a.visita.erase("coruja");a.visita.coruja_visitou=true
		if a.trabalho=="ver_coruja":a.trabalho="visitar"

func arlequim(r:PersonagemPlex,o:Dictionary,dt:float) -> void:
	if r.ocupado():return
	if r.celula!=o.celula:voltar(r,o);return
	r.direcao=GradePlex.direcao_suporte(int(o.rotacao))
	if not ligado(r):clipe(r,"desligado");return
	var alvo:PersonagemPlex=jogo.clientes.ator(int(o.get("arlequim_crianca",-1)))
	if not is_instance_valid(alvo):
		o.erase("arlequim_crianca")
		if int(o.get("arlequim_dia",-1))==dia():clipe(r,"parado");return
		for a in criancas_livres(o.celula,20.0):
			if a.visita.get("presente_arlequim",false):continue
			if float(a.visita.get("medo",0.0))<1.0 and str(a.trabalho)!="perdida" and randf()>.02:continue
			if chamar_arlequim(r,o,a):break
		clipe(r,"parado")
		return
	if alvo.ocupado() or alvo.celula!=frente(o):
		if not alvo.ocupado():
			var rota:Array[Vector2i]=jogo.clientes.caminho(alvo.origem_rota(),frente(o))
			if rota.is_empty():o.erase("arlequim_crianca");alvo.visita.erase("arlequim");return
			alvo.andar(rota)
		return
	jogo.tarefas.orientar(alvo,r.local);alvo.trabalho="ganhar_presente"
	clipe(r,"ativando")
	o.arlequim_tempo=float(o.get("arlequim_tempo",0.0))+dt
	if float(o.arlequim_tempo)<6.8:return
	alvo.visita.erase("arlequim");alvo.visita.presente_arlequim=true;alvo.visita.medo=0.0;alvo.emocao.exibir("muito_feliz");alvo.trabalho="visitar"
	o.erase("arlequim_crianca");o.arlequim_dia=dia()
	clipe(r,"parado")

func chamar_arlequim(r:PersonagemPlex,o:Dictionary,a:PersonagemPlex) -> bool:
	var rota:Array[Vector2i]=jogo.clientes.caminho(a.origem_rota(),frente(o))
	if rota.is_empty():return false
	o.arlequim_crianca=a.identificador;o.arlequim_tempo=0.0;a.visita.arlequim=r.identificador;a.trabalho="ir_arlequim";a.andar(rota)
	return true

func testar(modelo:String) -> String:
	for r in jogo.personagens:
		if not eh(r) or r.modelo!=modelo:continue
		var o:=base(r)
		if o.is_empty():continue
		if not ligado(r):return "Debug: o restaurante precisa estar aberto e o robô em serviço."
		var chamadas:=0
		if modelo=="vi_arlequim":
			if is_instance_valid(jogo.clientes.ator(int(o.get("arlequim_crianca",-1)))):return "Debug: já há uma criança indo até o Arlequim."
			o.erase("arlequim_dia")
			for a in criancas_livres(o.celula,999.0):
				if chamar_arlequim(r,o,a):return "Debug: uma criança está indo até o Arlequim."
			return "Debug: nenhuma criança livre conseguiu chegar ao Arlequim."
		r.robotica.sujeira=0
		for a in criancas_livres(o.celula,999.0):
			if chamadas>=3:break
			if chamar_coruja(r,o,a):chamadas+=1
		return "Debug: %d criança(s) indo até a Coruja."%chamadas
	return "Debug: coloque "+("a Coruja" if modelo=="vi_coruja" else "o Arlequim")+" no mapa primeiro."

func pode_controlar(r:PersonagemPlex) -> bool:return r.modelo=="vi_arlequim" and hora_controle() and not fora_servico(r)

func controle(r:PersonagemPlex,o:Dictionary,dt:float) -> void:
	if r.ocupado():r.visita.erase("diagnostico_animacao");r.visita.erase("arlequim_levantar");return
	r.visita.diagnostico_tempo=float(r.visita.get("diagnostico_tempo",0.0))+dt
	if r.celula==o.celula:
		if not r.visita.has("arlequim_levantar"):r.visita.arlequim_levantar=0.0;clipe(r,"levantar")
		r.visita.arlequim_levantar=float(r.visita.arlequim_levantar)+dt
		if float(r.visita.arlequim_levantar)>=4.6:clipe(r,"parado")
	else:
		r.visita.erase("arlequim_levantar");clipe(r,"caido")
	if not hora_controle():jogo.controle_robo.soltar(false);r.movimento.cancelar();voltar(r,o)

func voltar(r:PersonagemPlex,o:Dictionary) -> void:
	if r.celula==o.celula:return
	var rota:Array[Vector2i]=jogo.rotas.caminho(r.origem_rota(),o.celula)
	if rota.is_empty():r.celula=o.celula;r.local=Vector2(o.celula)
	else:r.andar(rota)

func opcoes(menu:CanvasLayer,r:PersonagemPlex) -> void:
	if not r.robo or r.visita.has("controle_animatronico"):return
	if fora_servico(r):menu.adicionar("Voltar ao serviço",func():r.robotica.fora_servico=false;r.robotica.desligado_manual=false)
	else:menu.adicionar("Fora de serviço",func():colocar_fora(r))

func colocar_fora(r:PersonagemPlex) -> void:
	r.robotica.fora_servico=true;r.robotica.fora_servico_dia=dia();r.robotica.desligado_manual=true;r.movimento.cancelar()
	AnimatronicosPlex.mudar(r,"desligado")

func conserto_noturno(dt:float) -> void:
	var minutos:float=jogo.calendario.minutos
	if minutos<1410.0 and minutos>=300.0:return
	var noite:=dia() if minutos>=1380.0 else dia()-1
	if noite!=noite_conserto:noite_conserto=noite;consertos=0
	if consertos>=2:return
	var m:PersonagemPlex=jogo.sistemas.mecanico.mecanico()
	if not is_instance_valid(m) or m.visita.has("mec") or m.visita.get("mec_toy",false):return
	var alvo:PersonagemPlex=null
	for r in jogo.personagens:
		if r.robo and fora_servico(r) and int(r.robotica.get("fora_servico_dia",-1))<=noite and not r.visita.has("mec_noturno"):alvo=r;break
	if alvo==null:
		if m.visita.has("conserto_amigo"):m.visita.erase("conserto_amigo");m.trabalho=""
		return
	if m.visita.get("fora_turno",false) or m.visita.get("saindo_fechamento",false):
		if not TurnosEquipePlex.ocupado(m):jogo.turnos.chegada(m,.5)
		return
	if TurnosEquipePlex.ocupado(m) or m.ocupado():return
	if int(m.visita.get("conserto_amigo",-1))!=alvo.identificador:m.visita.conserto_amigo=alvo.identificador;m.visita.conserto_tempo=0.0
	if m.local.distance_to(alvo.local)>1.6:
		if not jogo.sistemas.mecanico.ir_ate(m,alvo.celula):alvo.robotica.fora_servico_dia=noite+1
		return
	m.trabalho="montar";m.visita.anim_ferramenta=true;jogo.tarefas.orientar_cardinal(m,alvo.local)
	m.visita.conserto_tempo=float(m.visita.get("conserto_tempo",0.0))+dt
	if float(m.visita.conserto_tempo)<20.0:return
	alvo.robotica.fora_servico=false;alvo.robotica.sujeira=0;alvo.robotica.desgaste=0.0;alvo.robotica.avariado=false;alvo.robotica.manutencao_solicitada=false
	m.visita.erase("conserto_amigo");m.visita.erase("anim_ferramenta");m.trabalho="";consertos+=1
	jogo.sistemas.baloes.exibir(m,"Pronto, consertado e limpo.",3)

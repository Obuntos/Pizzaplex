class_name CacaAnimatronicosPlex
extends RefCounted

const MEDO_MAX:=4.0
const FOME_MAX:=4.0
const FOME_POR_MINUTO:=4.0/(21.0*1440.0)
const FOLGA_EXTRA:=7.0*1440.0
const POSES={"pose_apresentar":"Apresentar","pose_tocando":"Tocando","pose_tchau":"Tchauzinho","pose_crooner":"Crooner","pose_cintura":"Mão na cintura"}
var jogo:Node
var camada:Node2D
var espera:=0.0
var ultimo:=-1.0
var tremor:=0.0
var icone:Texture2D
var visao_cache:Dictionary={}

func _init(cena:Node) -> void:jogo=cena
func agora() -> float:return float(jogo.calendario.dias)*1440.0+float(jogo.calendario.minutos)
func noite() -> bool:return jogo.calendario.minutos>=1380.0 or jogo.calendario.minutos<360.0
func medo(a:PersonagemPlex) -> float:return float(a.visita.get("medo",0.0))
func fome(r:PersonagemPlex) -> float:return float(r.robotica.get("fome",0.0))
func guarda(a:PersonagemPlex) -> bool:return a.cargo=="funcionario" and a.funcao=="seguranca" and not a.visita.get("morto",false) and not a.visita.get("fora_turno",false)
func vivo(a:PersonagemPlex) -> bool:return is_instance_valid(a) and not a.robo and not AdministradorPlex.eh(a) and not a.visita.get("morto",false)
func paralisado(a:PersonagemPlex) -> bool:return a.visita.get("paralisado",false)
func escondido(a:PersonagemPlex) -> bool:return a.visita.has("escondido")

func somar_medo(a:PersonagemPlex,valor:float) -> void:
	var antes:=medo(a)
	a.visita.medo=clampf(antes+valor,0.0,MEDO_MAX)
	if valor>0 and floori(medo(a))>floori(antes):a.emocao.exibir("pavor" if medo(a)>=3.0 else "medo")

func possuido_ativo(r:PersonagemPlex) -> bool:
	return r.robo and (r.robotica.get("assombrado",false) or r.visita.get("debug_possuido",false))

func pode_matar(r:PersonagemPlex,v:PersonagemPlex) -> bool:
	if not jogo.controle_robo.controlado(r) or not vivo(v) or escondido(v):return false
	if r.visita.get("controle_desligado",false) or r.local.distance_to(v.local)>1.7:return false
	if paralisado(v):return true
	var frente:=VisaoNPCPlex.frente(v)
	return frente.dot((r.local-v.local).normalized())<-.2

func matar(r:PersonagemPlex,v:PersonagemPlex) -> void:
	if not pode_matar(r,v):jogo.painel.mensagem("Chegue por trás, colado nas costas da pessoa.");return
	r.movimento.cancelar();jogo.tarefas.orientar(r,v.local)
	var presentes:Array=jogo.personagens.filter(func(a):return a!=v and vivo(a) and VisaoNPCPlex.ve(jogo,a,v))
	var saciou:=medo(v)>=MEDO_MAX
	jogo.sistemas.investigacao.registrar_incidente(v)
	jogo.sistemas.espiritos.por_vitima(v)
	if jogo.seguranca!=null:jogo.seguranca.registrar(v,presentes)
	var violencia:=3 if saciou or r.modelo.ends_with("_quebrado") else 2
	for a in presentes:jogo.controle.incidentes.fugir(a)
	r.robotica.fome=0.0
	if saciou:r.robotica.fome_folga_ate=agora()+FOLGA_EXTRA
	if jogo.sistemas.ataques.suporta(r,v):jogo.sistemas.ataques.iniciar(r,v,violencia)
	else:
		GorePlex.espalhar(jogo,v.celula,violencia,posmod(roundi(float(r.direcao)/2.0),4))
		jogo.despawn(v)
	jogo.painel.mensagem(("A vítima estava em pânico: o animatrônico ficou saciado por mais tempo." if saciou else "O animatrônico se alimentou. A fome voltou a zero.")+(" Houve testemunhas." if not presentes.is_empty() else ""))

func sangue_camera(a:PersonagemPlex) -> void:
	var o:Dictionary=jogo.planta.objetos.get(int(a.visita.get("guarda_camera",-1)),{})
	if o.is_empty():return
	var area:=visao_camera(o)
	for p in jogo.planta.objetos.values():
		if not MobiliaPlex.visual(p).contains("poca") or not area.has(p.celula):continue
		var vistas:Array=a.visita.get("pocas_vistas",[])
		if int(p.id) in vistas:continue
		vistas.append(int(p.id));a.visita.pocas_vistas=vistas;somar_medo(a,.8);jogo.sistemas.baloes.exibir(a,"Isso é... sangue?",3)

func chance_falha(a:PersonagemPlex) -> float:return .15+medo(a)*.08

func revelar(a:PersonagemPlex) -> void:
	var dados:Variant=a.visita.get("escondido",{})
	if dados is Dictionary and dados.has("celula"):a.celula=Vector2i(int(dados.celula[0]),int(dados.celula[1]));a.local=Vector2(a.celula)
	a.visible=true;a.modulate.a=1.0
	a.visita.erase("escondido");a.visita.erase("escondido_calmo");a.visita.erase("escondido_armario")

func paralisar(a:PersonagemPlex) -> void:
	if paralisado(a):return
	a.visita.paralisado=true;a.movimento.cancelar();a.trabalho="paralisado";a.emocao.exibir("pavor")
	jogo.sistemas.baloes.exibir(a,"Não consigo me mexer...",3)

func soltar_paralisia(a:PersonagemPlex) -> void:
	if not paralisado(a):return
	a.visita.erase("paralisado")
	if a.trabalho=="paralisado":a.trabalho=""

func atualizar(delta:float) -> void:
	if camada==null:
		camada=Node2D.new();camada.z_index=119;jogo.add_child(camada);camada.draw.connect(desenhar)
	tremor+=delta
	camada.queue_redraw()
	espera+=delta
	if espera<.5:return
	espera=0.0
	var instante:=agora()
	var minutos:=0.0 if ultimo<0 else clampf(instante-ultimo,0.0,60.0)
	ultimo=instante
	var guarda_sistema:GuardaAutonomoPlex=jogo.sistemas.guarda
	var vigiando:=false
	for a in jogo.personagens:
		if a.robo:
			if possuido_ativo(a) and instante>=float(a.robotica.get("fome_folga_ate",0.0)):a.robotica.fome=minf(FOME_MAX,fome(a)+FOME_POR_MINUTO*minutos)
			continue
		if a.visita.get("morto",false):continue
		if not noite():a.visita.erase("seguranca_maxima")
		if guarda(a) and guarda_sistema.monitorando(a):vigiando=true;sangue_camera(a)
		var luz:bool=jogo.iluminacao.rede.fator>.05
		if medo(a)>0 and luz:a.visita.medo=maxf(0.0,medo(a)-minutos*(.5 if noite() else 1.0)/60.0)
	jogo.iluminacao.rede.extra=.25 if vigiando else 0.0
	if jogo.iluminacao.rede.fator<=.05:
		for a in jogo.personagens:
			if guarda(a) and medo(a)<MEDO_MAX:somar_medo(a,MEDO_MAX)
	poses_dia(minutos)
	var r:PersonagemPlex=jogo.controle_robo.ator()
	if not is_instance_valid(r):
		for a in jogo.personagens:soltar_paralisia(a)
		return
	var andando:=r.ocupado()
	var pose:=str(r.visita.get("controle_pose",""))
	var quebrado:=str(r.modelo).ends_with("_quebrado")
	for a in jogo.personagens:
		if not vivo(a) or escondido(a):continue
		var distancia:float=a.local.distance_to(r.local)
		var ve:=VisaoNPCPlex.ve(jogo,a,r,7.0)
		var ve_camera:bool=guarda(a) and guarda_sistema.monitorando(a) and guarda_sistema.camera_atual_ve(a,r.local)
		if (ve or ve_camera) and (andando or quebrado) and instante>=float(a.visita.get("medo_visto_ate",0.0)):
			a.visita.medo_visto_ate=instante+5.0;somar_medo(a,.6)
			if quebrado and guarda(a):
				a.visita.medo=maxf(medo(a),2.0);guarda_sistema.seguranca_maxima(a)
		if (ve or ve_camera) and not pose.is_empty() and not andando and noite():somar_medo(a,.03)
		if ve_camera:
			var visto:Array=a.visita.get("robo_visto",[])
			var camera_atual:=int(a.visita.get("guarda_camera",-1))
			if not visto.is_empty() and (int(visto[2])!=camera_atual or Vector2(float(visto[0]),float(visto[1])).distance_to(r.local)>=3.0):
				somar_medo(a,.5);jogo.sistemas.baloes.exibir(a,"Ele... mudou de lugar?",3)
			a.visita.robo_visto=[r.local.x,r.local.y,camera_atual]
		if jogo.controle_robo.tocando(r) and distancia<=12.0:
			var sinal:float=jogo.sistemas.ambiencia.transmissao(r.local,a.local,"musica")/(1.0+distancia*.22)
			if sinal>.12+jogo.sistemas.ambiencia.nivel(a.local)*.65:somar_medo(a,.2*minutos)
		if distancia<=4.0 and (medo(a)>=MEDO_MAX or fome(r)>=FOME_MAX):
			paralisar(a);jogo.tarefas.orientar(a,r.local)
		elif paralisado(a) and distancia>6.0:soltar_paralisia(a)

func poses_dia(minutos:float) -> void:
	if noite() or minutos<=0:return
	for r in jogo.personagens:
		if not r.robo or str(r.robotica.get("pose_dia","")).is_empty() or str(r.robotica.get("estado",""))!="ligado":continue
		for a in jogo.personagens:
			if a.robo or a.visita.get("morto",false) or a.local.distance_to(r.local)>7.0 or not VisaoNPCPlex.ve(jogo,a,r,7.0):continue
			if a.modelo=="crianca":
				a.visita.medo=maxf(0.0,medo(a)-.2*minutos)
				if not a.visita.get("pose_animado",false):a.visita.pose_animado=true;a.emocao.exibir("muito_feliz")

func barra(centro:Vector2,valor:float,maximo:float,cor:Color) -> void:
	var largura:=34.0;var origem:=centro-Vector2(largura*.5,0)
	camada.draw_rect(Rect2(origem-Vector2(2,2),Vector2(largura+4,9)),Color(0,0,0,.65))
	for i in 4:
		var cheio:=clampf(valor/maximo*4.0-float(i),0.0,1.0)
		var r:=Rect2(origem+Vector2(float(i)*(largura/4.0),0),Vector2(largura/4.0-2.0,5))
		camada.draw_rect(r,Color(cor,.25))
		if cheio>0:camada.draw_rect(Rect2(r.position,Vector2(r.size.x*cheio,r.size.y)),cor)

func visao_camera(o:Dictionary) -> Dictionary:
	var chave:=str(jogo.planta.revisao)+":"+str(jogo.iluminacao.rede.fator>.05)+":"+str(CamerasVigilanciaPlex.quadro(o))
	var guardado:Dictionary=visao_cache.get(int(o.id),{})
	if str(guardado.get("chave",""))==chave:return guardado.celulas
	var celulas:Dictionary={}
	for alvo in CamerasVigilanciaPlex.area(jogo,o):
		if jogo.sistemas.investigacao.camera_ve(o,Vector2(alvo)):celulas[alvo]=true
	visao_cache[int(o.id)]={"chave":chave,"celulas":celulas}
	return celulas

func area_camera(o:Dictionary) -> void:
	var celulas:=visao_camera(o)
	var brilho:=.5+sin(tremor*2.2)*.15
	for c in celulas:
		var poligono:=GradePlex.poligono(GradePlex.projetar(Vector2(c),jogo.planta.altura(c)))
		camada.draw_colored_polygon(poligono,Color(.85,.12,.1,.1*brilho+.05))
		for d in GradePlex.VIZINHOS:
			if celulas.has(c+d):continue
			var tela:=GradePlex.projetar_vetor(Vector2(d))
			var i:=(0 if tela.y<0 else 1) if tela.x>0 else (2 if tela.y>0 else 3)
			camada.draw_line(poligono[i],poligono[(i+1)%4],Color(.95,.2,.15,.75*brilho+.2),1.5)

func previa_camera() -> void:
	var tipo:=str(jogo.editor.ferramenta)
	if not CatalogoPlex.objetos.get(tipo,{}).get("camera",false):return
	var c:Vector2i=jogo.apontada()
	var celulas:Dictionary={}
	for q in [0,6,12]:celulas.merge(CamerasVigilanciaPlex.area(jogo,{"id":-1,"celula":c,"rotacao":int(jogo.editor.rotacao),"camera_quadro":q}))
	for x in celulas:
		var poligono:=GradePlex.poligono(GradePlex.projetar(Vector2(x),jogo.planta.altura(x)))
		camada.draw_colored_polygon(poligono,Color(.85,.12,.1,.16))

func desenhar() -> void:
	previa_camera()
	if icone==null:icone=load("res://assets/interface/icone_seguranca.png")
	var guarda_sistema:GuardaAutonomoPlex=jogo.sistemas.guarda
	for a in jogo.personagens:
		if not guarda(a) or not guarda_sistema.monitorando(a):continue
		var o:Dictionary=jogo.planta.objetos.get(int(a.visita.get("guarda_camera",-1)),{})
		if o.is_empty():continue
		area_camera(o)
		var lugar:=GradePlex.projetar(CamerasVigilanciaPlex.lente(o),jogo.planta.altura(o.celula))+Vector2(0,-104.0+sin(tremor*3.0)*1.5)
		camada.draw_texture(icone,(lugar-icone.get_size()*.5).round())
	for a in jogo.personagens:
		if not a.visible:continue
		var topo:=GradePlex.projetar(a.local,jogo.planta.altura(a.celula))+Vector2(0,-108)
		if not a.robo and guarda(a) and (noite() or medo(a)>0):
			var abalo:=Vector2(sin(tremor*40.0),0)*(1.5 if paralisado(a) else 0.0)
			barra(topo+abalo,medo(a),MEDO_MAX,Color("b56fd6").lerp(Color("e04848"),medo(a)/MEDO_MAX))
		elif a.robo and jogo.controle_robo.controlado(a):
			barra(topo+Vector2(0,-12),fome(a),FOME_MAX,Color("d9a441").lerp(Color("d03a2a"),fome(a)/FOME_MAX))

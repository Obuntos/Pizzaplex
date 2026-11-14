class_name EspiritosPlex
extends RefCounted

const TIPOS=["medio","raivoso","timido"]
const POSES=["pose_apresentar","pose_tchau","pose_tocando","pose_cintura","pose_crooner","cantar_possuido"]
var jogo:Node
var espiritos:Array=[]
var proximo:=1
var espera:=0.0
var proxima_aparicao:=30.0
var aparicoes:Array=[]

func _init(cena:Node) -> void:jogo=cena
func minutos() -> float:return float(jogo.calendario.minutos)
func nivel() -> int:
	var m:=minutos()
	if m>=1380.0 or m<60.0:return 1
	if m<180.0:return 2
	if m<270.0:return 3
	if m<360.0:return 4
	return 0
func noite() -> bool:return nivel()>0 and not jogo.operacao.aberto

func adicionar(tipo:String) -> void:
	espiritos.append({"id":proximo,"tipo":tipo if tipo in TIPOS else "medio","robo":-1});proximo+=1

func por_vitima(v:PersonagemPlex) -> void:
	if not is_instance_valid(v) or v.robo:return
	if v.modelo=="crianca":adicionar("timido")
	elif v.cargo=="funcionario" or v.funcao in ["seguranca","investigador"]:adicionar("raivoso")
	else:adicionar("medio")

func gravar() -> Dictionary:return {"espiritos":espiritos.duplicate(true),"proximo":proximo}
func restaurar(d:Dictionary) -> void:
	espiritos=d.get("espiritos",[]).duplicate(true);proximo=int(d.get("proximo",espiritos.size()+1))

func robo(e:Dictionary) -> PersonagemPlex:
	var r:PersonagemPlex=jogo.clientes.ator(int(e.get("robo",-1)))
	return r if is_instance_valid(r) and r.robo and str(r.robotica.get("espirito",""))==str(e.tipo) else null

func livre(r:PersonagemPlex) -> bool:
	return r.robo and AtracoesCatalogoPlex.permitido(r.modelo) and not AmigosBairroPlex.eh(r) and str(r.robotica.get("espirito","")).is_empty() and not r.visita.get("montando_atracao",false)

func preferencia(tipo:String,r:PersonagemPlex) -> int:
	var nota:=0
	if tipo=="raivoso":
		if r.modelo.contains("coelho") or r.modelo.contains("orelhitas"):nota+=3
		if CatalogoMontagemPlex.quebrado(r.modelo) or r.robotica.get("armazenado",false):nota+=2
	elif tipo=="timido":
		if r.modelo.contains("toy") or r.modelo.contains("patitas"):nota+=3
	elif r.pose>=0:nota+=3
	return nota

func atribuir() -> void:
	for e in espiritos:
		if robo(e)!=null or int(e.robo)==-2 and e.tipo=="timido" and fliperama().size()>0:continue
		e.robo=-1
		var melhor:PersonagemPlex=null;var nota:=-1
		for r in jogo.personagens:
			if not livre(r):continue
			if e.tipo=="medio" and r.pose<0:continue
			var n:=preferencia(str(e.tipo),r)
			if n>nota:nota=n;melhor=r
		if melhor!=null:
			e.robo=melhor.identificador;melhor.robotica.espirito=str(e.tipo);melhor.robotica.assombrado=true
		elif e.tipo=="timido" and not fliperama().is_empty():e.robo=-2

func fliperama() -> Array:return jogo.planta.objetos.values().filter(func(o):return CatalogoPlex.base(str(o.tipo))=="maquina_fliperama")

func atualizar(delta:float) -> void:
	animar_aparicoes(delta)
	espera+=delta
	if espera<.5:return
	var dt:=espera;espera=0.0
	atribuir()
	var livres_raivosos:=espiritos.filter(func(e):return e.tipo=="raivoso" and robo(e)==null).size()
	if livres_raivosos>0:assombrar(dt,livres_raivosos)
	for e in espiritos:
		var r:=robo(e)
		if r==null:continue
		if noite():vagar(r,str(e.tipo),dt)
		elif r.visita.has("vagar"):voltar_palco(r)

func pode_vagar(r:PersonagemPlex) -> bool:
	return not jogo.controle_robo.controlado(r) and not r.robotica.get("fora_servico",false) and not r.robotica.get("armazenado",false) and not r.visita.has("oficina_robo") and not r.visita.has("troca_toy") and not r.visita.has("mec_noturno") and not r.visita.get("em_ataque",false) and float(r.robotica.get("bateria",100.0))>0.0

func guarda() -> PersonagemPlex:
	for a in jogo.personagens:
		if jogo.sistemas.caca.guarda(a) and not a.visita.get("morto",false):return a
	return null

func vagar(r:PersonagemPlex,tipo:String,dt:float) -> void:
	if not pode_vagar(r):return
	var n:=nivel()
	var v:Dictionary=r.visita.get("vagar",{})
	if tipo=="medio":
		if n>=4 and r.pose>=0 and not r.ocupado():r.robotica.desligado_manual=false;AnimatronicosPlex.mudar(r,"ligado");r.trabalho="apresentar"
		return
	if tipo=="timido" and n<2:return
	if v.is_empty():v={"etapa":"escolher","tempo":0.0};r.visita.vagar=v;r.automatico=false
	v.tempo=float(v.tempo)+dt
	if r.ocupado():return
	var g:=guarda()
	match str(v.etapa):
		"escolher":
			r.visita.erase("diagnostico_animacao")
			if tipo=="timido" and randf()<.7:
				var alvo:=celula_camera(r,n>=3)
				if alvo.x>=0 and ir(r,alvo):v.etapa="camera";v.tempo=0.0;return
			if g==null:return
			var porta:=porta_guarda(g)
			if porta.is_empty():return
			v.porta=int(porta.id)
			var fora:=fora_porta(g,porta)
			if fora.x>=0 and ir(r,fora):v.etapa="porta";v.tempo=0.0
		"camera":
			var pose:=""
			for p in POSES:
				if ClipesPlex.possui(r.modelo,p):pose=p;break
			if not pose.is_empty():r.visita.diagnostico_animacao=pose;r.visita.diagnostico_tempo=float(v.tempo)
			if is_instance_valid(g) and jogo.sistemas.guarda.monitorando(g) and jogo.sistemas.guarda.camera_atual_ve(g,r.local):
				jogo.sistemas.caca.somar_medo(g,.15*dt)
				if randf()<.05:jogo.sistemas.baloes.exibir(g,"Ele está olhando para a câmera...",3)
			if float(v.tempo)>=25.0:r.visita.erase("diagnostico_animacao");v.etapa="escolher_porta"
		"escolher_porta":
			if g==null:v.etapa="voltar";return
			var porta:=porta_guarda(g)
			if porta.is_empty():v.etapa="voltar";return
			v.porta=int(porta.id);var fora:=fora_porta(g,porta)
			if fora.x>=0 and ir(r,fora):v.etapa="porta";v.tempo=0.0
			else:v.etapa="voltar"
		"porta":
			porta_etapa(r,tipo,v,g,n,dt)
		"entrar":
			if not is_instance_valid(g) or g.visita.get("morto",false):v.etapa="voltar";return
			if r.local.distance_to(g.local)<=1.6:matar(r,g);v.etapa="voltar";return
			var vagas:Array=jogo.clientes.vagas(g.celula,1,1)
			if vagas.is_empty() or not ir(r,vagas[0]):v.etapa="voltar"
		"voltar":
			voltar_palco(r)
	if tipo=="raivoso" and n>=4:
		for a in jogo.personagens:
			if not a.robo and jogo.sistemas.guarda.invasor(a) and a.local.distance_to(r.local)<=1.6:matar(r,a);break
	if tipo=="timido" and n>=4 and is_instance_valid(g) and g.local.distance_to(r.local)<=9.0 and randf()<.1:
		jogo.sistemas.caca.somar_medo(g,.2);jogo.sistemas.baloes.exibir(g,["*passos*","*algo arranhando*","*um estalo metálico*"][randi()%3],3)

func porta_etapa(r:PersonagemPlex,tipo:String,v:Dictionary,g:PersonagemPlex,n:int,dt:float) -> void:
	var porta:Dictionary=jogo.planta.objetos.get(int(v.get("porta",-1)),{})
	if porta.is_empty() or not is_instance_valid(g):v.etapa="voltar";return
	var espera_porta:float={1:90.0,2:70.0,3:40.0,4:20.0}.get(n,60.0)
	if tipo=="timido":espera_porta*=1.6
	if porta.get("trancada",false):
		if float(v.tempo)>=8.0:v.etapa="voltar"
		return
	var chance:float=(.05 if tipo=="raivoso" and n<=2 else .02)*dt
	if (jogo.sistemas.guarda.disponivel(g) and randf()<chance) or (g.visita.has("ouvindo_porta") and int(g.visita.ouvindo_porta)==int(porta.id)):
		if jogo.sistemas.guarda.trancar(porta):
			jogo.sistemas.baloes.exibir(g,"Tem alguma coisa na porta! Tranquei.",3);jogo.sistemas.caca.somar_medo(g,.6);v.tempo=0.0
		return
	if float(v.tempo)<espera_porta:return
	if tipo=="timido" and float(g.visita.get("medo",0.0))<2.0:v.etapa="voltar";return
	v.etapa="entrar"

func porta_guarda(g:PersonagemPlex) -> Dictionary:
	var portas:Array=jogo.sistemas.guarda.portas_sala(jogo.sistemas.guarda.sala_guarda(g))
	if portas.is_empty():return {}
	portas.sort_custom(func(x,y):return Vector2(x.celula).distance_to(g.local)<Vector2(y.celula).distance_to(g.local))
	return portas[0]

func fora_porta(g:PersonagemPlex,porta:Dictionary) -> Vector2i:
	var sala:Dictionary=jogo.sistemas.guarda.sala_guarda(g)
	var celulas:Dictionary=sala.get("total",sala.get("celulas",{}))
	var tiles:Array[Vector2i]=jogo.planta.celulas(porta.tipo,porta.celula,porta.rotacao)
	for t in tiles:
		for d in GradePlex.VIZINHOS:
			var c:Vector2i=t+d
			if not tiles.has(c) and not celulas.has(c) and jogo.planta.transitavel(c):return c
	return Vector2i(-1,-1)

func celula_camera(r:PersonagemPlex,perto_escritorio:bool) -> Vector2i:
	var lista:Array=jogo.sistemas.guarda.cameras()
	if lista.is_empty():return Vector2i(-1,-1)
	var g:=guarda()
	if perto_escritorio and g!=null:
		lista.sort_custom(func(x,y):return Vector2(x.celula).distance_to(g.local)<Vector2(y.celula).distance_to(g.local))
		lista=lista.slice(0,2)
	else:lista.shuffle()
	for o in lista:
		if not perto_escritorio and jogo.sistemas.guarda.camera_vigiada(int(o.id)):continue
		var area=CamerasVigilanciaPlex.area(jogo,o)
		var celulas:Array=area.keys() if area is Dictionary else area
		celulas.shuffle()
		for c in celulas.slice(0,12):
			var alvo:Vector2i=c
			if jogo.planta.transitavel(alvo) and not jogo.rotas.caminho(r.origem_rota(),alvo).is_empty():return alvo
	return Vector2i(-1,-1)

func ir(r:PersonagemPlex,alvo:Vector2i) -> bool:
	if r.celula==alvo:return true
	var rota:Array[Vector2i]=jogo.rotas.caminho(r.origem_rota(),alvo)
	if rota.is_empty():return false
	r.robotica.desligado_manual=false;r.andar(rota);r.trabalho="vagar"
	return true

func voltar_palco(r:PersonagemPlex) -> void:
	if r.ocupado():return
	r.visita.erase("diagnostico_animacao")
	var marca:Dictionary=jogo.planta.objetos.get(r.pose,{})
	if marca.is_empty() or r.celula==marca.celula:
		r.visita.erase("vagar");r.automatico=true;r.trabalho="apresentar" if r.pose>=0 else ""
		if not marca.is_empty():r.direcao=GradePlex.direcao_suporte(int(marca.rotacao))
		return
	if not ir(r,marca.celula):r.visita.erase("vagar");r.automatico=true

func matar(r:PersonagemPlex,v:PersonagemPlex) -> void:
	if not is_instance_valid(v) or v.visita.get("morto",false):return
	jogo.sistemas.investigacao.registrar_incidente(v)
	por_vitima(v)
	if jogo.sistemas.ataques.suporta(r,v):jogo.sistemas.ataques.iniciar(r,v,3)
	else:GorePlex.espalhar(jogo,v.celula,3,posmod(roundi(float(r.direcao)/2.0),4));jogo.despawn(v)

func assombrar(dt:float,quantidade:int) -> void:
	var escuro:bool=jogo.iluminacao.rede.fator<=.05
	if not escuro and not noite():return
	jogo.sistemas.perdidas.reputacao("geral",-.02*dt*quantidade)
	proxima_aparicao-=dt
	if proxima_aparicao>0:return
	proxima_aparicao=45.0+randf()*60.0
	var pessoas:Array=jogo.personagens.filter(func(a):return not a.robo and not a.visita.get("morto",false) and a.visible and TerrenoPlex.contem(jogo.planta,a.celula))
	if pessoas.is_empty():return
	var alvo:PersonagemPlex=pessoas[randi()%pessoas.size()]
	var vagas:Array=jogo.clientes.vagas(alvo.celula,6,5)
	if vagas.is_empty():return
	var c:Vector2i=vagas[vagas.size()-1]
	aparecer(c,"raivoso")
	for a in pessoas:
		if a.local.distance_to(Vector2(c))<=6.0:jogo.sistemas.caca.somar_medo(a,.8)
	var funcionarios:Array=pessoas.filter(func(a):return a.cargo=="funcionario" and not a.ocupado() and a.local.distance_to(Vector2(c))<=12.0)
	if not funcionarios.is_empty():
		var f:PersonagemPlex=funcionarios[0]
		jogo.sistemas.baloes.exibir(f,"Ouvi um barulho ali...",3)
		var rota:Array[Vector2i]=jogo.rotas.caminho(f.origem_rota(),c)
		if not rota.is_empty():f.andar(rota);f.visita.susto_vazio=true

func aparecer(c:Vector2i,tipo:String) -> void:
	var s:=Sprite2D.new();s.centered=false;s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	s.offset=Vector2(-48,-112);s.position=GradePlex.projetar(Vector2(c),jogo.planta.altura(c));s.modulate=Color(1,1,1,.85)
	var direcao:=randi()%8
	var atlas:=AtlasTexture.new();atlas.atlas=CatalogoPlex.textura("res://assets/sistemas/espiritos/"+tipo+"/parado/"+str(direcao)+".png");atlas.region=Rect2(0,0,96,120);s.texture=atlas
	jogo.mundo.add_child(s)
	aparicoes.append({"no":s,"tipo":tipo,"direcao":direcao,"tempo":0.0})

func animar_aparicoes(delta:float) -> void:
	for ap in aparicoes.duplicate():
		var s:Sprite2D=ap.no
		if not is_instance_valid(s):aparicoes.erase(ap);continue
		ap.tempo=float(ap.tempo)+delta
		var sumindo:bool=float(ap.tempo)>=3.0
		var quadros:=40 if sumindo else 32
		var q:=mini(quadros-1,floori((float(ap.tempo)-3.0)*20.0)) if sumindo else floori(float(ap.tempo)*8.0)%quadros
		var atlas:AtlasTexture=s.texture
		if sumindo:atlas.atlas=CatalogoPlex.textura("res://assets/sistemas/espiritos/"+str(ap.tipo)+"/sumir/"+str(ap.direcao)+".png")
		atlas.region=Rect2((q%16)*96,floori(float(q)/16.0)*120,96,120)
		if sumindo and q>=quadros-1:s.queue_free();aparicoes.erase(ap)
	for a in jogo.personagens:
		if a.visita.get("susto_vazio",false) and not a.ocupado():
			a.visita.erase("susto_vazio");jogo.sistemas.caca.somar_medo(a,.4);jogo.sistemas.baloes.exibir(a,"Não tem nada aqui...",3)

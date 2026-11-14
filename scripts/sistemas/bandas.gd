class_name BandasPlex
extends RefCounted

const INTENSIDADE:=0.6
const TRANSICAO:=4.0
const MAX_BANDAS:=4
const FADE:=1.5
const MUSICAS={
	"orelhitas":{"melodia":"res://assets/audio/orelhitas_melodia.ogg","baixo":"res://assets/audio/orelhitas_baixo.ogg"},
	"toy":{"melodia":"res://assets/audio/orelhitas_toy_melodia.ogg","baixo":"res://assets/audio/orelhitas_toy_baixo.ogg"}
}
const BANDA=["novo_coelho_detalhes","vi_patitas","vi_toy_orelhitas","vi_toy_patitas"]
const FITAS={
	"classico":{"nome":"Show Clássico","musica":"orelhitas","clipe":"cantar"},
	"toy":{"nome":"Show Toy","musica":"toy","clipe":"cantar"},
	"apresentacao":{"nome":"Apresentação","musica":"orelhitas","clipe":"pose_apresentar"},
	"danca":{"nome":"Dança","musica":"toy","clipe":"dancar"}
}
const ANIMACOES=["cantar","dancar","falar","apresentar"]
var jogo:Node
var bandas:Dictionary={}
var raiz:Node
var tempo:=0.0
var espera:=0.0
var espera_parede:=1.0

func _init(cena:Node) -> void:jogo=cena

static func fita(a:PersonagemPlex) -> String:
	var padrao:="toy" if a.modelo.begins_with("vi_toy") else "classico"
	var atual:=str(a.robotica.get("fita",padrao))
	return atual if FITAS.has(atual) else padrao
static func papel(a:PersonagemPlex) -> String:return "baixo" if a.modelo.contains("patitas") else "melodia"
static func clipe(a:PersonagemPlex,padrao:String) -> String:
	if a.modelo not in BANDA:return padrao
	var nome:=str(a.robotica.get("clipe_show",FITAS[fita(a)].clipe))
	return nome if ClipesPlex.possui(a.modelo,nome) else padrao
func musica(a:PersonagemPlex) -> String:
	return str(a.robotica.get("musica_show",FITAS[fita(a)].musica)) if a.modelo in BANDA else ""

func cantando(a:PersonagemPlex) -> bool:
	if not a.robo or musica(a).is_empty() or a.robotica.get("avariado",false) or AnimatronicosPlex.pausado(a):return false
	if str(a.visita.get("diagnostico_animacao","")) in ANIMACOES:return true
	if jogo.controle_robo.controlado(a):return a.visita.get("controle_cantando",false) and not a.ocupado()
	return a.trabalho=="apresentar" and str(a.robotica.get("estado",""))=="ligado" and not a.ocupado() and str(a.robotica.get("pose_dia","")).is_empty()

func chave(a:PersonagemPlex) -> String:
	var palco:int=jogo.animatronicos.palcos.da_pose(a.pose) if a.pose>=0 else -1
	return musica(a)+":"+(str(palco) if palco>=0 else "solo"+str(a.identificador))

func barramento() -> String:
	var usados:Array=bandas.values().map(func(b):return b.bus)
	for i in MAX_BANDAS:
		var nome:="Banda"+str(i)
		if nome in usados:continue
		if AudioServer.get_bus_index(nome)<0:
			AudioServer.add_bus()
			var indice:=AudioServer.bus_count-1
			AudioServer.set_bus_name(indice,nome);AudioServer.set_bus_send(indice,"Master")
			var filtro:=AudioEffectLowPassFilter.new();filtro.cutoff_hz=16000.0;filtro.resonance=.65
			var eco:=AudioEffectDelay.new();eco.tap1_active=true;eco.tap1_delay_ms=300.0;eco.tap1_level_db=-80.0;eco.tap2_active=false;eco.feedback_active=true;eco.feedback_delay_ms=300.0;eco.feedback_level_db=-80.0
			AudioServer.add_bus_effect(indice,filtro);AudioServer.add_bus_effect(indice,eco);AudioServer.add_bus_effect(indice,AudioEffectCompressor.new())
		return nome
	return ""

func criar(id:String) -> void:
	var nome:=barramento()
	if nome.is_empty():return
	if raiz==null:raiz=Node.new();raiz.name="Bandas";jogo.add_child(raiz)
	var faixas:Dictionary={}
	for modelo in MUSICAS[id.get_slice(":",0)]:
		var stream:AudioStreamOggVorbis=load(str(MUSICAS[id.get_slice(":",0)][modelo]))
		if stream==null:continue
		stream.loop=true
		var som:=AudioStreamPlayer.new();som.stream=stream;som.bus=nome;som.volume_db=-80.0
		raiz.add_child(som);faixas[modelo]={"som":som,"nivel":0.0}
	for f in faixas.values():f.som.play()
	bandas[id]={"bus":nome,"faixas":faixas,"estresse":0.0,"membros":[],"presentes":[],"centro":Vector2.ZERO,"fade":0.0,"parede":1.0,"parede_alvo":1.0,"ganho":0.0,"ganho_alvo":0.0}

func encerrar(id:String) -> void:
	for f in bandas[id].faixas.values():
		if is_instance_valid(f.som):f.som.queue_free()
	var indice:=AudioServer.get_bus_index(str(bandas[id].bus))
	if indice>=0:AudioServer.set_bus_volume_db(indice,0.0)
	bandas.erase(id)

func atualizar(delta:float) -> void:
	tempo+=delta
	var grupos:Dictionary={}
	for a in jogo.personagens:
		if not cantando(a):continue
		var id:=chave(a)
		if not grupos.has(id):grupos[id]=[]
		grupos[id].append(a)
	for id in grupos:
		if not bandas.has(id):criar(id)
	espera_parede+=delta
	var medir:=espera_parede>=.25
	if medir:espera_parede=0.0
	var foco:Vector2=GradePlex.inverter(jogo.camera.position)
	var zoom:float=jogo.camera.zoom.x/1.4
	for id in bandas.keys():
		var b:Dictionary=bandas[id]
		var membros:Array=grupos.get(id,[])
		b.fade=move_toward(float(b.fade),0.0 if membros.is_empty() else 1.0,delta/FADE)
		if membros.is_empty() and float(b.fade)<=0.0:encerrar(id);continue
		if not membros.is_empty():
			b.membros=membros
			var soma:=Vector2.ZERO
			for r in membros:soma+=r.local
			b.centro=soma/float(membros.size())
			b.presentes=membros.map(func(r):return papel(r))
		var presentes:Array=b.presentes
		var total:int=b.faixas.size()
		var faltam:=0
		for modelo in b.faixas:
			if modelo not in presentes:faltam+=1
		var alvo:=minf(1.0,float(faltam)/float(maxi(1,total-1)))
		b.estresse=lerpf(float(b.estresse),alvo,1.0-exp(-delta/maxf(.15,TRANSICAO*.4)))
		var triste:=float(b.estresse)*INTENSIDADE
		var oscila:=sin(tempo*3.25)*.008*triste+sin(tempo*1.18)*.006*triste
		var velocidade:=clampf(1.0-triste*.048+oscila,.88,1.02)
		for modelo in b.faixas:
			var f:Dictionary=b.faixas[modelo]
			f.nivel=lerpf(float(f.nivel),1.0 if modelo in presentes else 0.0,1.0-exp(-delta/maxf(.09,TRANSICAO*.12)))
			f.som.volume_db=linear_to_db(maxf(float(f.nivel),.0001))
			f.som.pitch_scale=velocidade
		if medir:ouvir(b,foco,zoom)
		b.parede=lerpf(float(b.parede),float(b.parede_alvo),1.0-exp(-delta/.35))
		b.ganho=lerpf(float(b.ganho),float(b.ganho_alvo),1.0-exp(-delta/.35))
		var volume:=float(b.ganho)*clampf(zoom,.4,1.0)*float(b.fade)*.9
		var indice:=AudioServer.get_bus_index(str(b.bus))
		if indice<0:continue
		AudioServer.set_bus_volume_db(indice,linear_to_db(maxf(volume,.0001)))
		var filtro:AudioEffectLowPassFilter=AudioServer.get_bus_effect(indice,0)
		filtro.cutoff_hz=minf(lerpf(16000.0,1900.0,triste),lerpf(700.0,16000.0,float(b.parede)))
		var eco:AudioEffectDelay=AudioServer.get_bus_effect(indice,1)
		eco.dry=1.0-triste*.09
		eco.tap1_level_db=linear_to_db(maxf(triste*.2,.0001))
		eco.feedback_level_db=linear_to_db(maxf(triste*.2*.25,.0001))
	espera+=delta
	if espera<.5:return
	plateia(espera)
	espera=0.0

func ouvir(b:Dictionary,foco:Vector2,zoom:float) -> void:
	var centro:Vector2=b.centro
	var fontes:Array=[[centro,1.0]]
	for o in jogo.planta.objetos.values():
		if MobiliaPlex.dados(o).get("alto_falante",false) and o.get("som_ligado",false) and Vector2(o.celula).distance_to(centro)<=14.0:fontes.append([Vector2(o.celula),1.1])
	var alcance:=16.0/clampf(zoom,.6,1.6)
	var melhor:=0.0;var parede:=0.0
	for f in fontes:
		var ponto:Vector2=f[0]
		var perto:=pow(clampf(1.0-foco.distance_to(ponto)/alcance,0.0,1.0),1.4)
		if perto<=0.0:continue
		var passa:float=jogo.sistemas.ambiencia.transmissao(ponto,foco,"musica")
		var valor:=perto*lerpf(.2,1.0,passa)*float(f[1])
		if valor>melhor:melhor=valor;parede=passa
	b.ganho_alvo=minf(1.0,melhor);b.parede_alvo=parede if melhor>0.0 else 1.0

func plateia(passo:float) -> void:
	for b in bandas.values():
		if b.membros.is_empty() or not is_instance_valid(b.membros[0]):continue
		var triste:=float(b.estresse)*INTENSIDADE
		var palco:int=jogo.animatronicos.palcos.da_pose(b.membros[0].pose) if b.membros[0].pose>=0 else -1
		for a in jogo.personagens:
			if a.robo or a.trabalho!="assistir":continue
			if palco<0 or jogo.animatronicos.palcos.da_pose(int(a.visita.get("pose",-1)))!=palco:continue
			a.visita.satisfacao=clampf(float(a.visita.get("satisfacao",70.0))+passo*(.4-triste*1.5),0.0,100.0)
			if triste>.3:a.animacao.expressao="triste"

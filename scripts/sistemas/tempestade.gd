class_name TempestadeEnergiaPlex
extends RefCounted

const DESGASTE_MINUTO:=.002
const DESGASTE_CHUVA:=.004
const CHANCE_RAIO:=.0015
const CHANCE_FUSIVEL:=.0005
const PRECO_MANUTENCAO:=15
var jogo:Node
var espera:=0.0
var ultimo:=-1.0
var quedas:=0

func _init(cena:Node) -> void:jogo=cena
func agora() -> float:return float(jogo.calendario.dias)*1440.0+float(jogo.calendario.minutos)
func quadros() -> Array:return jogo.planta.objetos.values().filter(func(o):return o.tipo=="amb_quadro_energia")
func chovendo() -> bool:return jogo.calendario.previsao()=="Chuva"
func sem_energia() -> bool:return jogo.iluminacao.rede.fator<=.05

func apagar(motivo:String) -> void:
	var houve:=false
	for g in jogo.planta.objetos.values():
		if MobiliaPlex.dados(g).get("gerador",false) and g.get("ligada",true) and not g.get("reinicio_pendente",false):g.reinicio_pendente=true;houve=true
	if not houve:return
	quedas+=1
	jogo.iluminacao.rede.atualizar();jogo.planta.alterada.emit()
	jogo.painel.mensagem(motivo)
	jogo.sistemas.jornal.noticiar("Queda de energia na pizzaria: "+motivo.to_lower())

func atualizar(delta:float) -> void:
	espera+=delta
	if espera<1.0:return
	espera=0.0
	var instante:=agora()
	var minutos:=0.0 if ultimo<0 else clampf(instante-ultimo,0.0,60.0)
	ultimo=instante
	var lista:=quadros()
	var pior:=0.0
	for q in lista:
		q.desgaste=minf(100.0,float(q.get("desgaste",0.0))+minutos*(DESGASTE_MINUTO+(DESGASTE_CHUVA if chovendo() else 0.0)))
		pior=maxf(pior,float(q.desgaste))
	manutencoes(1.0)
	if minutos<=0.0 or sem_energia() or lista.is_empty():return
	if chovendo() and randf()<CHANCE_RAIO*minutos*(1.0+pior/50.0):apagar("Tempestade! Um raio derrubou a energia.");return
	if pior>=80.0 and randf()<CHANCE_FUSIVEL*minutos:apagar("A caixa de fusíveis desarmou: o desgaste está alto.")

func tecnico() -> PersonagemPlex:
	for a in jogo.personagens:
		if a.cargo=="funcionario" and not a.robo and a.funcao=="manutencao" and not a.ocupado() and not a.visita.get("fora_turno",false) and not a.visita.get("morto",false) and not a.visita.has("fusivel") and not a.visita.has("mec"):return a
	return null

func pedir(q:Dictionary,a:PersonagemPlex=null) -> bool:
	if int(q.get("manutencao_por",0))>0 and is_instance_valid(jogo.clientes.ator(int(q.manutencao_por))):return true
	if a==null:a=tecnico()
	if a==null:jogo.painel.mensagem("Contrate um funcionário de Manutenção para cuidar dos fusíveis.");return false
	var rota:Array[Vector2i]=jogo.rotas.aproximar(a.origem_rota(),int(q.id))
	if rota.is_empty() and not jogo.planta.interacoes(int(q.id)).has(a.celula):jogo.painel.mensagem("A caixa de energia não tem acesso livre.");return false
	q.manutencao_por=a.identificador;a.visita.fusivel=int(q.id);a.visita.fusivel_tempo=0.0
	if not rota.is_empty():a.andar(rota)
	a.trabalho="manutencao_fusiveis";jogo.sistemas.baloes.exibir(a,"Vou revisar os fusíveis.",3)
	return true

func manutencoes(passo:float) -> void:
	for a in jogo.personagens:
		if not a.visita.has("fusivel"):continue
		var q:Dictionary=jogo.planta.objetos.get(int(a.visita.fusivel),{})
		if q.is_empty() or a.visita.get("morto",false):a.visita.erase("fusivel");continue
		if a.ocupado():continue
		a.trabalho="manutencao_fusiveis";jogo.tarefas.orientar(a,Vector2(q.celula))
		a.visita.fusivel_tempo=float(a.visita.get("fusivel_tempo",0.0))+passo
		if float(a.visita.fusivel_tempo)<5.0:continue
		q.desgaste=0.0;q.manutencao_por=0;a.visita.erase("fusivel");a.visita.erase("fusivel_tempo");a.trabalho=""
		jogo.sistemas.baloes.exibir(a,"Fusíveis trocados.",3)

func opcoes(menu:CanvasLayer,q:Dictionary) -> void:
	menu.adicionar("Manutenção dos fusíveis (desgaste %d%%) · US$ %d"%[roundi(float(q.get("desgaste",0.0))),PRECO_MANUTENCAO],func():
		if int(q.get("manutencao_por",0))>0 and is_instance_valid(jogo.clientes.ator(int(q.manutencao_por))):jogo.painel.mensagem("A manutenção já está a caminho.");return
		if jogo.editor.cobrar(PRECO_MANUTENCAO) and not pedir(q):jogo.servicos.saldo=snappedf(jogo.servicos.saldo+PRECO_MANUTENCAO,.01))

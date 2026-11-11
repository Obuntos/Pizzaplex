class_name RatosPlex
extends RefCounted

const MAXIMO=4
var jogo:Node
var ratos:Dictionary={}
var visuais:Dictionary={}
var proximo:=1
var ultimo_surgimento:=-1440.0
var espera:=0.0
var animacoes:Dictionary={}
func _init(cena:Node) -> void:jogo=cena
func agora() -> float:return float(jogo.calendario.dias)*1440.0+float(jogo.calendario.minutos)
static func comida(item:Dictionary) -> bool:
	return (item.get("tipo","")=="prato" and item.get("sujo",false)) or int(item.get("sobre",-1))<0 and (item.get("tipo","") in ["restos_mesa","bebida_derramada","pizza","guarana_copo","guarana_tampa"])
static func velha(item:Dictionary) -> bool:
	return item.get("tipo","") in SalasPlex.ESTRUTURA and str(MobiliaPlex.visual(item)).begins_with("antigo_")
func avaliar() -> void:
	var tempo:=agora()
	var sujeiras:int=jogo.planta.objetos.values().filter(func(o):return LimpezaAmbientesPlex.eh(o)).size()
	for item in jogo.planta.objetos.values():
		if not TerrenoPlex.contem(jogo.planta,item.celula) or int(item.get("carregada_por",0))>0:continue
		var atraso:=1440.0 if comida(item) else 4320.0 if velha(item) or sujeiras>=4 and LimpezaAmbientesPlex.eh(item) else 0.0
		if atraso<=0:item.erase("praga_desde");continue
		if not item.has("praga_desde"):item.praga_desde=tempo
		if tempo-float(item.praga_desde)<atraso or ratos.size()>=MAXIMO or tempo-ultimo_surgimento<1440.0:continue
		var local:=ponto_perto(item.celula)
		if local.x>=0:
			criar(local);ultimo_surgimento=tempo
			jogo.sistemas.avisos.marcar(Vector2(local),"Um rato apareceu")
func ponto_perto(centro:Vector2i) -> Vector2i:
	for raio in [1,2,3]:
		for d in GradePlex.VIZINHOS:
			var c:Vector2i=centro+d*raio
			if TerrenoPlex.contem(jogo.planta,c) and jogo.planta.transitavel(c) and is_zero_approx(jogo.planta.altura(c)):return c
	return Vector2i(-1,-1)
func criar(local:Vector2i) -> int:
	var id:=proximo;proximo+=1
	ratos[id]={"id":id,"local":[float(local.x),float(local.y)],"base":[local.x,local.y],"rota":[],"tempo":0.0,"parada":2.0,"estado":"sentado","flip":false,"espantado":false}
	visual(id)
	return id
func visual(id:int) -> Sprite2D:
	if visuais.has(id):return visuais[id]
	var s:=Sprite2D.new();s.centered=false;s.offset=Vector2(-32,-34);s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;s.texture=CatalogoPlex.atlas_vazio()
	jogo.mundo.add_child(s);visuais[id]=s
	if "composicao" in jogo and jogo.composicao!=null:
		var mat:=ShaderMaterial.new();mat.shader=load("res://shaders/objeto_manual.gdshader");mat.set_shader_parameter("altura",14.0);mat.set_shader_parameter("profundidade_cena",jogo.composicao.profundidade);mat.set_shader_parameter("origem",Vector2(CenaPlex.ORIGEM));mat.set_shader_parameter("tamanho",Vector2(CenaPlex.TAMANHO));jogo.iluminacao.vincular(mat);s.material=mat
	return s
func espantar(id:int) -> void:
	if not ratos.has(id):return
	ratos[id].espantado=true;ratos[id].parada=0.0;ratos[id].rota=[];ratos[id].fuga=1.2
	ultimo_surgimento=agora()
	jogo.painel.mensagem("O rato foi espantado. Remova a comida e a sujeira para evitar novos ratos.")
func remover(id:int) -> void:
	if visuais.has(id):visuais[id].queue_free();visuais.erase(id)
	ratos.erase(id)
func atualizar(delta:float) -> void:
	espera+=delta
	if espera>=1.0:espera=0.0;avaliar()
	for id in ratos.keys():
		var r:Dictionary=ratos[id];r.tempo=float(r.tempo)+delta
		if r.espantado:
			r.fuga=float(r.get("fuga",1.2))-delta
			if r.fuga<=0:remover(id);continue
		var local:=Vector2(r.local[0],r.local[1]);var base:=Vector2i(r.base[0],r.base[1])
		r.parada=maxf(0,float(r.parada)-delta)
		if r.rota.is_empty() and r.parada<=0:
			for d in GradePlex.VIZINHOS:
				var c:Vector2i=base+d*(2+posmod(int(r.id)+floori(float(r.tempo)),3))
				if not TerrenoPlex.contem(jogo.planta,c) or not jogo.planta.transitavel(c):continue
				var rota:Array[Vector2i]=jogo.rotas.caminho(Vector2i(local.round()),c)
				if rota.size()>1:r.rota=rota.slice(1).map(func(p):return [p.x,p.y]);break
			if r.rota.is_empty():r.parada=2.0
		if not r.rota.is_empty():
			var destino:=Vector2(r.rota[0][0],r.rota[0][1]);var proxima:=local.move_toward(destino,delta*(4.0 if r.espantado else 1.1))
			r.flip=GradePlex.projetar(proxima).x<GradePlex.projetar(local).x;local=proxima;r.local=[local.x,local.y];r.estado="correr" if r.espantado else "andar"
			if local.distance_to(destino)<.01:
				r.rota.pop_front()
				if r.rota.is_empty():r.parada=2.0+float(posmod(int(id),3));r.estado=["sentado","frente","farejando","parado"][posmod(int(id)+floori(float(r.tempo)),4)]
		var s:=visual(id);s.position=GradePlex.projetar(local);s.flip_h=bool(r.flip)
		var estado:=str(r.estado);var t:Texture2D=load("res://assets/animais/rato/"+estado+".png") if not animacoes.has(estado) else animacoes[estado]
		animacoes[estado]=t;var total:=floori(float(t.get_width())/64.0);var fps:=10.0 if estado=="andar" else 40.0/3.0 if estado=="correr" else 12.0
		var atlas:AtlasTexture=s.texture;atlas.atlas=t;atlas.region=Rect2(posmod(floori(float(r.tempo)*fps),total)*64,0,64,48)
func apontado(mouse:Vector2) -> int:
	for id in visuais:
		var s:Sprite2D=visuais[id];var ponto:Vector2=s.to_local(mouse);var rect:=s.get_rect()
		if not rect.has_point(ponto) or s.texture==null:continue
		var p:=Vector2i((ponto-rect.position).floor());var im:=s.texture.get_image()
		if s.flip_h:p.x=63-p.x
		if Rect2i(Vector2i.ZERO,im.get_size()).has_point(p) and im.get_pixelv(p).a>.1:return int(id)
	return -1
func gravar() -> Dictionary:return {"ratos":ratos.values(),"proximo":proximo,"ultimo_surgimento":ultimo_surgimento}
func restaurar(dados:Dictionary) -> void:
	for id in ratos.keys():remover(int(id))
	proximo=int(dados.get("proximo",1));ultimo_surgimento=float(dados.get("ultimo_surgimento",-1440))
	for r in dados.get("ratos",[]):r.id=int(r.id);ratos[r.id]=r.duplicate(true);visual(r.id)

class_name EmocaoPlex
extends Node2D

const ICONES={"feliz":"feliz","muito_feliz":"festa","chateado":"triste","triste":"triste","depressivo":"cansado","ansioso":"gota","medo":"assustado","pavor":"assustado","incomodado":"irritado","raivoso":"irritado","confuso":"exclamacao","surpreso":"exclamacao","shocked":"assustado"}
var atual:=""
var tempo:=0.0
var proximo:=0.0
var inicio:=0.0
var forcada_ate:=0.0
var forcada_expressao:=""
var sprite:=Sprite2D.new()
var fundo:=Sprite2D.new()
var rastro:=Sprite2D.new()
var quadros:=1
var intervalo:=.1
var aleatorio:=RandomNumberGenerator.new()
static func motivos(a:PersonagemPlex) -> PackedStringArray:
	var lista:=PackedStringArray()
	if a.energia<25:lista.append("Energia baixa: precisa descansar")
	if float(a.necessidades.get("banheiro",100))<25:lista.append("Precisa ir ao banheiro")
	if float(a.necessidades.get("higiene",100))<30:lista.append("Higiene baixa: precisa lavar as mãos")
	if float(a.necessidades.get("lazer",100))<40:lista.append("Precisa de lazer")
	if a.visita.get("reativar_gerador",false) or a.visita.get("medo_apagao",false):lista.append("Assustado com a falta de energia")
	if a.visita.get("fugindo",false):lista.append("Em fuga: sente medo")
	if a.visita.get("solitario",false):lista.append("Está se sentindo sozinho")
	if a.cargo!="funcionario" and float(a.visita.get("conforto",10))<5:lista.append("Conforto baixo")
	if a.cargo!="funcionario" and float(a.visita.get("satisfacao",100))<50:lista.append("Insatisfeito com a visita")
	return lista
static func base(a:PersonagemPlex) -> String:
	if a.visita.get("reativar_gerador",false) or a.visita.get("medo_apagao",false) or a.visita.get("fugindo",false):return "medo"
	if a.energia<25:return "cansado"
	if float(a.necessidades.get("banheiro",100))<25 or float(a.necessidades.get("higiene",100))<30:return "incomodado"
	if float(a.necessidades.get("lazer",100))<40:return "chateado"
	return "neutro"
func _init() -> void:
	add_child(fundo);add_child(rastro);add_child(sprite)
	fundo.texture=preload("res://assets/interface/emocoes/balao.png");fundo.centered=false
	rastro.texture=preload("res://assets/interface/emocoes/rastro.png");rastro.hframes=12;rastro.centered=false
	sprite.centered=false;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;z_index=65;aleatorio.randomize();hide()
func atualizar(a:PersonagemPlex,delta:float) -> void:
	if a.robo  or a.visita.get("morto",false):hide();return
	tempo+=delta
	if tempo>=forcada_ate and not forcada_expressao.is_empty():
		forcada_expressao=""
		a.animacao.expressao=base(a) if a.cargo=="funcionario" else str(a.visita.get("humor_cliente","neutro"))
	if a.cargo=="funcionario" and not a.visita.get("socializando",false) and tempo>=forcada_ate:a.animacao.expressao=base(a)
	if a.cargo!="funcionario" and a.visita.get("humor_cliente","")!="" and not a.visita.get("socializando",false):a.animacao.expressao=str(a.visita.humor_cliente)
	if tempo<forcada_ate and not forcada_expressao.is_empty():a.animacao.expressao=forcada_expressao
	var estado:=RostoPlex.estado(a.animacao.expressao)
	if estado!=atual and tempo>=forcada_ate:
		hide()
		var antes:=atual;atual=estado
		if tempo>=proximo and ICONES.has(estado) and (antes.is_empty() or aleatorio.randf()<.6 or estado in ["triste","raivoso"]):
			var textura:Texture2D=load("res://assets/interface/emocoes/"+str(ICONES[estado])+".png")
			intervalo=float({"feliz":80,"festa":80,"triste":90,"cansado":110,"gota":70,"assustado":60,"irritado":70,"exclamacao":80}.get(str(ICONES[estado]),100))/1000.0
			quadros=maxi(1,floori(float(textura.get_width())/28.0));sprite.texture=textura;sprite.hframes=quadros;inicio=tempo;proximo=tempo+aleatorio.randf_range(12,22);show()
	if visible:
		var decorrido:=tempo-inicio
		if decorrido>=minf(3.0,float(quadros)*intervalo+.4):hide()
		else:sprite.frame=mini(quadros-1,floori(decorrido/intervalo));rastro.frame=posmod(floori(decorrido/.12),12)
	posicionar(a)

func posicionar(a:PersonagemPlex) -> void:
	position=a.identificacao.position+Vector2(a.identificacao.texto.get_minimum_size().x+6,-8) if a.cargo=="funcionario" else Vector2(-14,a.visual.position.y-112)

func exibir(icone: String) -> void:
	var caminho:="res://assets/interface/emocoes/"+icone+".png"
	if not ResourceLoader.exists(caminho): return
	var textura:=load(caminho) as Texture2D
	if textura==null: return
	quadros=maxi(1,floori(float(textura.get_width())/28.0))
	intervalo=.08;sprite.texture=textura;sprite.hframes=quadros;sprite.frame=0
	forcada_expressao="surpreso" if icone=="exclamacao" else "muito_feliz" if icone=="festa" else {"triste":"triste","irritado":"raivoso","assustado":"medo","cansado":"cansado","gota":"ansioso"}.get(icone,"feliz")
	inicio=tempo;forcada_ate=tempo+minf(3.0,float(quadros)*intervalo+.4)
	proximo=tempo+12.0
	show()

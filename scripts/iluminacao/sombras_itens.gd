class_name SombrasItensPlex
extends Node2D

static var malhas:Dictionary={}
var jogo:Node
var itens:Dictionary={}
var revisao:=-1
var candidatos:Array=[]
var indice:=0
var espera:=0.0
static func elegivel(item:Dictionary) -> bool:
	var tipo:=str(item.get("tipo",""));var info:=MobiliaPlex.dados(item)
	if item.is_empty() or int(item.get("carregada_por",0))>0 or tipo in SalasPlex.ESTRUTURA or tipo in ["pose","pose_montagem","pose_quebrado"] or EscadasPlex.tipo(item) in ["palco","escada"] or LuminariasPlex.eh(tipo) or info.get("piso",false) or info.get("entulho",false):return false
	if info.get("bairro",false):return false
	return float(info.get("altura",0))>2.0
static func malha(volume:Dictionary) -> ArrayMesh:
	var chave:=str([volume.image,volume.origin,volume.pontos.size()])
	if malhas.has(chave):return malhas[chave]
	var minimo:=Vector2(INF,INF);var maximo:=-minimo;var altura:=0.0
	for ponto in volume.pontos:
		minimo=minimo.min(Vector2(ponto.x,ponto.y));maximo=maximo.max(Vector2(ponto.x,ponto.y));altura=maxf(altura,(ponto.z-2*ponto.y)/3.0)
	var vertices:=PackedVector3Array();var uv:=PackedVector2Array();var cores:=PackedColorArray();var indices:=PackedInt32Array()
	var tamanho:Vector2=volume.textura.get_size();var origem:=Vector2(volume.origin[0],volume.origin[1])
	if not volume.pontos.is_empty():
		for ponto in [minimo-Vector2(.5,.5),Vector2(maximo.x+.5,minimo.y-.5),maximo+Vector2(.5,.5),Vector2(minimo.x-.5,maximo.y+.5)]:
			vertices.append(Vector3(ponto.x,ponto.y,0));uv.append((ponto-origem+Vector2(.5,.5))/tamanho)
			cores.append(Color(clampf(altura/256.0,0,1) if ponto.y<minimo.y else 0.0,0,0,1))
		indices=PackedInt32Array([0,1,2,0,2,3])
	var resultado:=ArrayMesh.new()
	if not vertices.is_empty():
		var dados:Array=[];dados.resize(Mesh.ARRAY_MAX);dados[Mesh.ARRAY_VERTEX]=vertices;dados[Mesh.ARRAY_TEX_UV]=uv;dados[Mesh.ARRAY_COLOR]=cores;dados[Mesh.ARRAY_INDEX]=indices;resultado.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,dados)
	if malhas.size()>128:malhas.erase(malhas.keys()[0])
	malhas[chave]=resultado;return resultado
func configurar(cena:Node) -> void:
	jogo=cena;z_index=-1
func atualizar(delta:float) -> void:
	if jogo==null:return
	espera+=delta
	if revisao!=jogo.planta.revisao:
		revisao=jogo.planta.revisao;candidatos=jogo.planta.objetos.values().filter(elegivel);indice=0
		for id in itens.keys():
			if not jogo.planta.objetos.has(id) or not elegivel(jogo.planta.objetos[id]):itens[id].queue_free();itens.erase(id)
	var area:Rect2=jogo.visibilidade.area.grow(180)
	var novas:=0
	for item in candidatos:
		var apoio:=ApoiosPlex.posicao(jogo.planta,item);var p:=GradePlex.projetar(Vector2(apoio.x,apoio.y),apoio.z)
		if not area.has_point(p):
			if itens.has(item.id):itens[item.id].hide()
			continue
		if not itens.has(item.id):
			if novas>=2:continue
			novas+=1;var sprite_novo:=MeshInstance2D.new();sprite_novo.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(sprite_novo);sprite_novo.hide();itens[item.id]=sprite_novo
			var material_novo:=ShaderMaterial.new();material_novo.shader=preload("res://shaders/sombra_item.gdshader");sprite_novo.material=material_novo
			material_novo.set_shader_parameter("profundidade",jogo.composicao.profundidade);material_novo.set_shader_parameter("superficies",jogo.composicao.superficies);material_novo.set_shader_parameter("origem",Vector2(CenaPlex.ORIGEM));material_novo.set_shader_parameter("tamanho",Vector2(CenaPlex.TAMANHO));jogo.iluminacao.vincular(material_novo)
		var sprite:MeshInstance2D=itens[item.id]
		if espera<.12 and sprite.has_meta("preparada"):continue
		sprite.set_meta("preparada",true)
		var volume:=GeometriaPlex.objeto(item,jogo.planta,4)
		if volume.pontos.is_empty():sprite.hide();continue
		sprite.mesh=malha(volume);sprite.texture=volume.textura;sprite.position=p
		var fonte:=Vector3(p.x,(p.y+apoio.z)*2.0,apoio.z+15.0)
		var melhor:=-1;var energia:=0.0
		for i in SombraLuminariaPlex.candidatas(jogo.iluminacao,fonte):
			var valor:float=jogo.iluminacao.energia_recebida(i,fonte)
			if valor>energia:energia=valor;melhor=i
		var solar:float=jogo.iluminacao.sol_recebido(fonte)
		if solar>energia:energia=solar;melhor=-2
		sprite.visible=melhor!=-1 and energia>.015
		if not sprite.visible:continue
		var luz:Vector4=jogo.iluminacao.posicao_sol(fonte) if melhor==-2 else jogo.iluminacao.posicoes[melhor]
		var mat:=sprite.material as ShaderMaterial
		mat.set_shader_parameter("apoio",Vector3(fonte.x,fonte.y,apoio.z));mat.set_shader_parameter("altura_destino",apoio.z);mat.set_shader_parameter("altura_luz",luz.z);mat.set_shader_parameter("direcao",((Vector2(fonte.x,fonte.y)-Vector2(luz.x,luz.y))/maxf(12,luz.z-apoio.z)).limit_length(6));mat.set_shader_parameter("posicao_luz",Vector3(luz.x,luz.y,luz.z));mat.set_shader_parameter("indice_luz",melhor);mat.set_shader_parameter("sombra_solar",melhor==-2);mat.set_shader_parameter("opacidade",.38);mat.set_shader_parameter("peso_sombra",clampf(energia/(energia+jogo.iluminacao.ambiente_diurno*.45+.04),.15,1))
	if espera>=.12:espera=0

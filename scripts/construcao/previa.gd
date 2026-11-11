class_name PreviaConstrucaoPlex
extends RefCounted

static func obter(editor:EditorPlex,c:Vector2i) -> Dictionary:
	if not CatalogoPlex.objetos.has(editor.ferramenta):return {}
	var base:=MoverItensPlex.sem_original(editor) if editor.item_movendo>=0 else editor.planta
	var item:Dictionary=editor.planta.objetos[editor.item_movendo].duplicate(true) if editor.item_movendo>=0 else {"id":-1000,"tipo":editor.ferramenta,"estado":editor.estado_visual,"sobre":-1,"slot":-1,"aberta":false,"carregada_por":0}
	if editor.item_movendo<0:
		MobiliaPlex.preparar(item,editor.ferramenta)
		if not editor.estado_visual.is_empty():item.estado_visual=editor.estado_visual
	item.celula=c;item.rotacao=PortasPlex.rotacao_para(base,item.tipo,c,editor.rotacao) if PortasPlex.ajusta(str(item.tipo)) else editor.rotacao
	if ApoiosPlex.superficie(item.tipo) or ApoiosPlex.decoracao_mesa(item.tipo):
		var apoio:=ApoiosPlex.encontrar(base,c,item.tipo)
		item.sobre=int(apoio.get("pai",-1));item.slot=int(apoio.get("slot",-1))
	var p:=ApoiosPlex.posicao(base,item)
	var volume:=GeometriaPlex.objeto(item,base,4)
	return {"item":item,"posicao":p,"ponto":GradePlex.projetar(Vector2(p.x,p.y),p.z),"volume":volume}
static func desenhar(cursor:CursorPlex,alpha:float) -> void:
	var d:=obter(cursor.editor,cursor.celula)
	if d.is_empty():return
	var v:Dictionary=d.volume
	cursor.draw_texture(v.textura,d.ponto+Vector2(v.origin[0],v.origin[1]),Color(1,1,1,alpha))
	var editor:EditorPlex=cursor.editor
	if editor.item_movendo<0:return
	var ids:Array[int]=[]
	MoverItensPlex.grupo(editor.planta,editor.item_movendo,ids)
	if ids.size()<=1:return
	var base:=MoverItensPlex.sem_original(editor)
	var original:Dictionary=editor.planta.objetos[editor.item_movendo]
	var anterior:Vector2i=original.celula
	var giro:=posmod(int(d.item.rotacao)-int(original.rotacao),4)
	var copias:Array=[]
	for id in ids:
		var parte:Dictionary=d.item if id==editor.item_movendo else editor.planta.objetos[id].duplicate(true)
		if id!=editor.item_movendo:
			parte.celula=cursor.celula+Vector2i(GradePlex.girar(Vector2(parte.celula-anterior),giro))
			parte.rotacao=posmod(int(parte.rotacao)+giro,4)
		base.objetos[id]=parte;copias.append(parte)
	for parte in copias:
		if int(parte.id)==editor.item_movendo:continue
		var p:=ApoiosPlex.posicao(base,parte)
		var volume:=GeometriaPlex.objeto(parte,base,4)
		if volume.is_empty() or not volume.has("textura"):continue
		cursor.draw_texture(volume.textura,GradePlex.projetar(Vector2(p.x,p.y),p.z)+Vector2(volume.origin[0],volume.origin[1]),Color(1,1,1,alpha))
	for id in ids:base.objetos.erase(id)

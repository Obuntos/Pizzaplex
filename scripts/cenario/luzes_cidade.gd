class_name LuzesCidadePlex
extends RefCounted
var planta: PlantaPlex
var estruturas: SombrasEstruturasPlex
var dados: Dictionary
var imagem: Image
var textura: ImageTexture
var fator := 0.0
var revisao := -1
var portas := ""
var assinatura := 0
var fontes: Array[Vector4] = []
var bloqueados: Dictionary = {}
var resolucao := 4
var grupos: Array[int] = []
var minutos := 480.0
var horario := -1
var versao_horario := 0
var predios: Dictionary = {}
var janelas: Dictionary = {}
var campos: Dictionary = {}
var base_postes := PackedFloat32Array()
var postes: Dictionary={}
var niveis_postes: Dictionary={}
var buffer_atual:=PackedFloat32Array()
var fatores_campos: Dictionary={}
var tempo_falhas:=0.0
var espera_falhas:=0.0
var casa_administrador:=-1
var administrador_em_casa:=false
var chegada_casa:=-1.0
var dia_casa:=0
var combinacoes:=0
var cache_fontes: Dictionary={}
var campos_calculados:=0
var campos_reutilizados:=0
func chave_campo(luz: Vector4, grupo: int) -> int:
	var obstaculos: Array=[]
	var volumes: Dictionary={}
	for y in range(maxi(0,floori(luz.y-luz.z-.5)),mini(GradePlex.TAMANHO.y,ceili(luz.y+luz.z+.5)+1)):
		for x in range(maxi(0,floori(luz.x-luz.z-.5)),mini(GradePlex.TAMANHO.x,ceili(luz.x+luz.z+.5)+1)):
			var c:=Vector2i(x,y)
			if bloqueados.has(c): obstaculos.append(c)
			if estruturas==null: continue
			for id in estruturas.celulas.get(c,[]):
				var v: Dictionary=estruturas.volumes[id-1]
				volumes[hash([v.a,v.b,v.elipse])]=[v.a,v.b,v.elipse]
	var chaves: Array=volumes.keys()
	chaves.sort()
	for chave in chaves: obstaculos.append(volumes[chave])
	return hash([luz,grupo,obstaculos,resolucao])
func calcular_campo(luz: Vector4, largura: int, altura: int, grupo:int=0) -> Dictionary:
	campos_calculados+=1
	var indices:=PackedInt32Array()
	var valores:=PackedFloat64Array()
	var origem:=Vector2(luz.x,luz.y)
	var raio:=luz.z
	for y in range(maxi(0,floori((luz.y-raio+.5)*resolucao)),mini(altura-1,ceili((luz.y+raio+.5)*resolucao))+1):
		for x in range(maxi(0,floori((luz.x-raio+.5)*resolucao)),mini(largura-1,ceili((luz.x+raio+.5)*resolucao))+1):
			var alvo:=(Vector2(x,y)+Vector2(.5,.5))/float(resolucao)-Vector2(.5,.5)
			var distancia:=origem.distance_squared_to(alvo)/(raio*raio)
			if distancia>=1.0 or not visivel(origem,alvo): continue
			if estruturas!=null and not estruturas.visivel(Vector3(origem.x,origem.y,110.0 if grupo<0 else 74.0),Vector3(alvo.x,alvo.y,.5)): continue
			var queda:=1.0-distancia
			indices.append(y*largura+x);valores.append(luz.w*queda*queda)
	return {"indices":indices,"valores":valores}
func definir_lar(id: int, presente: bool, agora: float, chegada: float=-1.0) -> void:
	dia_casa=floori(agora/1440.0)
	if id==casa_administrador and presente==administrador_em_casa: return
	casa_administrador=id
	administrador_em_casa=presente
	chegada_casa=(chegada if chegada>=0.0 else agora) if presente else -1.0
	atualizar_horario(agora,true)
func nivel_poste(objeto: Dictionary, tempo: float) -> float:
	var semente:=posmod(objeto.celula.x*131+objeto.celula.y*71+int(objeto.rotacao)*37,10007)
	if semente%13==0: return 0.0
	if semente%5==0:
		var fase:=fposmod(tempo+float(semente)*.137,35.0+float(semente%37))
		if fase<.12: return .28
		if fase<.26: return 1.0
		if fase<.4: return .55
	elif semente%11==0:
		var fase:=fposmod(tempo+float(semente)*.19,110.0+float(semente%61))
		if fase<12.0: return 0.0
	return 1.0
func atualizar_falhas(delta: float) -> void:
	tempo_falhas+=delta
	espera_falhas+=delta
	if espera_falhas<.1 or fator<.001 or postes.is_empty(): return
	espera_falhas=fmod(espera_falhas,.1)
	var mudou:=false
	for id in postes:
		var nivel:=nivel_poste(postes[id],tempo_falhas)
		if not is_equal_approx(float(niveis_postes.get(id,1.0)),nivel):
			niveis_postes[id]=nivel
			mudou=true
	if mudou:
		versao_horario+=1
		combinar()
func _init(p: PlantaPlex) -> void:
	planta = p
	dados = JSON.parse_string(FileAccess.get_file_as_string("res://dados/luzes_cidade.json"))
	resolucao = int(dados.get("resolucao",4))
	imagem = Image.create_empty(GradePlex.TAMANHO.x*resolucao,GradePlex.TAMANHO.y*resolucao,false,Image.FORMAT_RF)
	textura = ImageTexture.create_from_image(imagem)
static func intensidade(tempo: float) -> float:
	var hora := fposmod(tempo,1440.0)/60.0
	return clampf(1.0-smoothstep(5.5,6.5,hora)+smoothstep(18.0,19.25,hora),0.0,1.0)
func nivel_janela(objeto: Dictionary, indice: int, tempo: float) -> float:
	if objeto.get("id",-2)==casa_administrador:
		if not administrador_em_casa or chegada_casa<0.0: return 0.0
		var decorrido:=float(dia_casa)*1440.0+fposmod(tempo,1440.0)-chegada_casa
		var ordem:=posmod(indice*7+objeto.celula.x*3+objeto.celula.y,17)
		var apagar_lar:=2.5+float(ordem)*.7
		return 1.0-smoothstep(apagar_lar,apagar_lar+2.0,maxf(0.0,decorrido))
	var config: Dictionary=dados.emissoes.get(objeto.tipo,{})
	var rotina:=str(config.get("rotina","permanente"))
	if rotina=="permanente": return 1.0
	var semente:=posmod(objeto.celula.x*127+objeto.celula.y*41+indice*67,997)
	if rotina=="hospital" and semente%3==0: return 1.0
	if rotina=="residencial" and semente%5==0: return 0.0
	var noite:=fposmod(tempo,1440.0)
	if noite<720.0: noite+=1440.0
	var apagar:=1260.0+float(semente%180)
	if rotina=="hospital": apagar=1305.0+float(semente%120)
	return 1.0-smoothstep(apagar,apagar+10.0,noite)
func atualizar_horario(tempo: float, forcar: bool = false) -> void:
	minutos=fposmod(tempo,1440.0)
	var atual:=floori(minutos)
	if horario==atual and not forcar: return
	horario=atual
	var novas: Dictionary={}
	for id in predios:
		var objeto: Dictionary=predios[id]
		var total:=int(dados.emissoes.get(objeto.tipo,{}).get("janelas",0))
		var niveis:=PackedFloat32Array()
		niveis.resize(64)
		for i in mini(total,64): niveis[i]=nivel_janela(objeto,i,minutos)
		novas[id]=niveis
	if not forcar and novas==janelas: return
	janelas=novas
	versao_horario+=1
	combinar()
func aplicar(material: ShaderMaterial) -> void:
	material.set_shader_parameter("mapa_luzes_cidade",textura)
	material.set_shader_parameter("noite_cidade",fator)
	material.set_shader_parameter("tamanho_luzes_cidade",Vector2(GradePlex.TAMANHO))
	var centro := GradePlex.projetar_local(GradePlex.CENTRO)
	material.set_shader_parameter("centro_luzes_cidade",Vector2(centro.x,centro.y*2.0))
	material.set_shader_parameter("eixos_luzes_cidade",[Vector4(1,0,0,1),Vector4(0,1,-1,0),Vector4(-1,0,0,-1),Vector4(0,-1,1,0)][posmod(GradePlex.visao,4)])
func emissao(material: ShaderMaterial, objeto: Dictionary, rotacao_visual: int) -> Array:
	var config: Dictionary = dados.emissoes.get(objeto.tipo,{})
	material.set_shader_parameter("tem_emissao",not config.is_empty())
	material.set_shader_parameter("nivel_emissao",float(niveis_postes.get(objeto.get("id",-1),1.0)) if objeto.tipo==dados.postes.tipo else 1.0)
	if config.is_empty(): return []
	var direcao: String = CatalogoPlex.DIRECOES[rotacao_visual]
	var cor: Array = config.cor
	material.set_shader_parameter("mascara_emissao",CatalogoPlex.textura(config.mascaras[direcao]))
	material.set_shader_parameter("cor_emissao",Vector3(cor[0],cor[1],cor[2])*float(config.energia))
	material.set_shader_parameter("janelas_agrupadas",int(config.get("janelas",0))>0)
	if janelas.has(objeto.id): material.set_shader_parameter("niveis_janelas",janelas[objeto.id])
	return config.get("origens",{}).get(direcao,[])
func ponto(objeto: Dictionary, local: Vector2) -> Vector2:
	var tamanho := Vector2(CatalogoPlex.dimensoes(objeto.tipo,objeto.rotacao))
	var centro := Vector2(objeto.celula)+(tamanho-Vector2.ONE)*.5
	return centro+GradePlex.girar(local-Vector2(5,5),objeto.rotacao)
func fonte(origem: Vector2, alcance: float, energia: float, grupo: int = 0) -> void:
	fontes.append(Vector4(origem.x,origem.y,alcance,energia))
	grupos.append(grupo)
func atualizar(estado_portas: String) -> void:
	if revisao==planta.revisao and portas==estado_portas: return
	revisao = planta.revisao
	portas = estado_portas
	var registros: Array = []
	var relevantes: Array[Dictionary] = []
	for objeto in planta.objetos.values():
		var tipo: String = objeto.tipo
		var info: Dictionary = CatalogoPlex.objetos[tipo]
		if tipo==dados.postes.tipo or (info.get("bairro",false) and int(info.largura)>=10) or tipo in SalasPlex.ESTRUTURA:
			registros.append([tipo,objeto.celula,objeto.rotacao,objeto.get("aberta",false)])
			relevantes.append(objeto)
	var atual := hash([registros,estruturas.assinatura_externa if estruturas!=null else 0])
	if assinatura==atual: return
	assinatura = atual
	fontes.clear()
	grupos.clear()
	predios.clear()
	postes.clear()
	bloqueados.clear()
	for objeto in relevantes:
		if objeto.tipo==dados.postes.tipo:
			var deslocamento := Vector2(dados.postes.deslocamento[0],dados.postes.deslocamento[1])
			postes[objeto.id]=objeto
			niveis_postes[objeto.id]=nivel_poste(objeto,tempo_falhas)
			fonte(Vector2(objeto.celula)+GradePlex.girar(deslocamento,objeto.rotacao),float(dados.postes.alcance),float(dados.postes.energia),-objeto.id)
		elif objeto.tipo in SalasPlex.ESTRUTURA:
			if not objeto.get("aberta",false):
				for c in planta.celulas(objeto.tipo,objeto.celula,objeto.rotacao): bloqueados[c]=true
		else:
			var casa: Dictionary = dados.casas.get(objeto.tipo,{})
			var volume: Array = casa.get("volume",[1.0,1.0,9.0,8.4])
			var a := ponto(objeto,Vector2(volume[0],volume[1]))
			var b := ponto(objeto,Vector2(volume[2],volume[3]))
			for y in range(ceili(minf(a.y,b.y)),floori(maxf(a.y,b.y))+1):
				for x in range(ceili(minf(a.x,b.x)),floori(maxf(a.x,b.x))+1): bloqueados[Vector2i(x,y)]=true
			if casa.is_empty(): continue
			if casa_administrador<0 and objeto.tipo==CaminhosCidadePlex.CASA: casa_administrador=objeto.id
			predios[objeto.id]=objeto
			var meio_x := (float(volume[0])+float(volume[2]))*.5
			var meio_y := (float(volume[1])+float(volume[3]))*.5
			for local in [Vector2(meio_x,float(volume[1])-.7),Vector2(meio_x,float(volume[3])+.7),Vector2(float(volume[0])-.7,meio_y),Vector2(float(volume[2])+.7,meio_y)]:
				fonte(ponto(objeto,local),float(casa.alcance),float(casa.energia),objeto.id)
			for extra in casa.get("extras",[]): fonte(ponto(objeto,Vector2(extra[0],extra[1])),float(extra[2]),float(extra[3]),objeto.id)
	reconstruir()
func visivel(a: Vector2, b: Vector2) -> bool:
	var origem:=a+Vector2(.5,.5)
	var delta:=b-a
	var celula:=Vector2i(origem.floor())
	var passo:=Vector2i(int(signf(delta.x)),int(signf(delta.y)))
	var incremento:=Vector2(1e20 if passo.x==0 else absf(1.0/delta.x),1e20 if passo.y==0 else absf(1.0/delta.y))
	var limite:=Vector2(celula)+Vector2(1 if passo.x>0 else 0,1 if passo.y>0 else 0)
	var proximos:=Vector2(1e20 if passo.x==0 else absf(limite.x-origem.x)*incremento.x,1e20 if passo.y==0 else absf(limite.y-origem.y)*incremento.y)
	for i in GradePlex.TAMANHO.x+GradePlex.TAMANHO.y+4:
		if bloqueados.has(celula): return false
		if minf(proximos.x,proximos.y)>=1.0: return true
		if absf(proximos.x-proximos.y)<.000001:
			if bloqueados.has(celula+Vector2i(passo.x,0)) or bloqueados.has(celula+Vector2i(0,passo.y)): return false
			celula+=passo
			proximos+=incremento
		elif proximos.x<proximos.y:
			celula.x+=passo.x
			proximos.x+=incremento.x
		else:
			celula.y+=passo.y
			proximos.y+=incremento.y
	return false
func reconstruir() -> void:
	var largura := imagem.get_width()
	var altura := imagem.get_height()
	base_postes.resize(largura*altura)
	base_postes.fill(0.0)
	campos.clear()
	var acumulados: Dictionary={}
	var proximos: Dictionary={}
	for indice_fonte in fontes.size():
		var luz: Vector4=fontes[indice_fonte]
		var grupo: int=grupos[indice_fonte]
		if grupo!=0 and not acumulados.has(grupo): acumulados[grupo]={}
		var chave:=chave_campo(luz,grupo)
		var campo: Dictionary
		if cache_fontes.has(chave): campo=cache_fontes[chave];campos_reutilizados+=1
		else: campo=calcular_campo(luz,largura,altura,grupo)
		proximos[chave]=campo
		for i in campo.indices.size():
			var indice: int=campo.indices[i]
			var energia: float=campo.valores[i]
			if grupo==0: base_postes[indice]+=energia
			else: acumulados[grupo][indice]=float(acumulados[grupo].get(indice,0.0))+energia
	cache_fontes=proximos
	for grupo in acumulados:
		campos[grupo]={"indices":PackedInt32Array(acumulados[grupo].keys()),"valores":PackedFloat32Array(acumulados[grupo].values())}
	buffer_atual=base_postes.duplicate()
	fatores_campos.clear()
	atualizar_horario(minutos,true)
func combinar() -> void:
	if base_postes.is_empty(): return
	var mudou:=false
	for id in campos:
		var energia:=0.0
		if id<0: energia=float(niveis_postes.get(-id,1.0))
		elif predios.has(id) and janelas.has(id):
			var total:=int(dados.emissoes[predios[id].tipo].janelas)
			for i in total: energia+=janelas[id][i]
			energia/=maxf(1.0,total)
		var diferenca:=energia-float(fatores_campos.get(id,0.0))
		if is_zero_approx(diferenca): continue
		fatores_campos[id]=energia
		var campo: Dictionary=campos[id]
		for i in campo.indices.size(): buffer_atual[campo.indices[i]]=maxf(0.0,buffer_atual[campo.indices[i]]+campo.valores[i]*diferenca)
		mudou=true
	if not mudou and not fatores_campos.is_empty(): return
	combinacoes+=1
	imagem=Image.create_from_data(GradePlex.TAMANHO.x*resolucao,GradePlex.TAMANHO.y*resolucao,false,Image.FORMAT_RF,buffer_atual.to_byte_array())
	textura.update(imagem)

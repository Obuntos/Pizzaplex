class_name DesempenhoPlex
extends RefCounted
var tempos:Dictionary={}
var quadros:Array[float]=[]
var espera:=0.0
var ultimo:=0
var neste_quadro:Dictionary={}
var piores:Array=[]
var espera_registro:=0.0
var passos:=0
var fisica_ms:=0.0
var processo_ms:=0.0
var retorno_us:=0
func medir(nome:String,inicio:int) -> void:
	var ms:float=(Time.get_ticks_usec()-inicio)/1000.0
	var d:Dictionary=tempos.get(nome,{"media":ms,"pico":0.0,"amostras":0})
	d.media=lerpf(float(d.media),ms,.08);d.pico=maxf(float(d.pico)*.995,ms);d.amostras=int(d.amostras)+1;tempos[nome]=d
	neste_quadro[nome]=float(neste_quadro.get(nome,0.0))+ms
func fisica(inicio:int) -> void:
	passos+=1;fisica_ms+=(Time.get_ticks_usec()-inicio)/1000.0
func processo(inicio:int) -> void:
	processo_ms=(Time.get_ticks_usec()-inicio)/1000.0
func janela(ativa:bool) -> void:
	if ativa:retorno_us=Time.get_ticks_usec()
	print("[Janela] %s · %s"%["voltou ao foco" if ativa else "saiu do foco",Time.get_time_string_from_system()])
func travamento(ms:float,sistemas:String) -> void:
	var linha:="[Travamento] %.0f ms"%ms
	if retorno_us>0:linha+=" · %.1f s depois de voltar à janela"%((Time.get_ticks_usec()-retorno_us)/1000000.0)
	linha+=" · quadro %.0f ms · simulação %d passos, %.0f ms"%[processo_ms,passos,fisica_ms]
	linha+=" · fora dos scripts (Godot, desenho, sistema) %.0f ms"%maxf(0.0,ms-processo_ms-fisica_ms)
	linha+=" · desenho %d chamadas · vídeo %.0f MB"%[int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0]
	if not sistemas.is_empty():linha+=" · mais lentos: "+sistemas
	print(linha)
func quadro(delta:float) -> void:
	if delta<=0:return
	quadros.append(delta*1000.0)
	if quadros.size()>300:quadros.pop_front()
	if delta*1000.0>=50.0:
		var nomes:Array=neste_quadro.keys();nomes.sort_custom(func(a,b):return float(neste_quadro[a])>float(neste_quadro[b]))
		var partes:=PackedStringArray()
		for n in nomes.slice(0,3):partes.append(str(n)+" %.1f ms"%float(neste_quadro[n]))
		piores.append({"ms":delta*1000.0,"quando":Time.get_datetime_string_from_system(),"sistemas":", ".join(partes)})
		if delta*1000.0>=100.0:travamento(delta*1000.0,", ".join(partes))
		piores.sort_custom(func(a,b):return float(a.ms)>float(b.ms))
		if piores.size()>10:piores.resize(10)
	neste_quadro.clear()
	passos=0;fisica_ms=0.0
	espera_registro+=delta
	if espera_registro>=30.0:espera_registro=0.0;registrar()
func registrar() -> void:
	if piores.is_empty():return
	var arquivo:=FileAccess.open("user://desempenho.txt",FileAccess.WRITE)
	if arquivo==null:return
	arquivo.store_line("Piores quadros (ms) · "+Time.get_datetime_string_from_system())
	for p in piores:arquivo.store_line("%.0f ms · %s · %s"%[float(p.ms),str(p.quando),str(p.sistemas)])
	arquivo.close()
func resumo() -> String:
	var linhas:=PackedStringArray(["FPS: %d"%Engine.get_frames_per_second(),"Memória: %.0f MB"%(Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0)])
	if not quadros.is_empty():
		var ordenados:=quadros.duplicate();ordenados.sort();linhas.append("Quadro p95: %.1f ms"%float(ordenados[mini(ordenados.size()-1,floori(ordenados.size()*.95))]))
	var nomes:Array=tempos.keys();nomes.sort_custom(func(a,b):return float(tempos[a].media)>float(tempos[b].media))
	for n in nomes.slice(0,5):linhas.append(str(n)+": %.2f ms · pico %.1f"%[float(tempos[n].media),float(tempos[n].pico)])
	return "\n".join(linhas)

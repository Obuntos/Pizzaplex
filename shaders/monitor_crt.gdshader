shader_type canvas_item;
render_mode unshaded;
uniform vec2 dimensao=vec2(812.0,650.0);
void fragment(){
 float linha=step(2.0,mod(UV.y*dimensao.y,3.0))*.035;
 vec2 p=(UV-.5)*2.0;
 float vinheta=smoothstep(.55,1.3,length(p))*.13;
 float pulso=(sin(TIME*1.1)*.5+.5)*.003;
 float momento=mod(TIME,21.0);
 float falha=step(20.88,momento)*step(abs(UV.y-fract(TIME*1.7)),.018);
 float risco=step(16.0,mod(TIME,17.0))*step(.997,fract(UV.y*137.0+TIME*.2))*.012;
 COLOR=vec4(.08,.12,.08,linha+vinheta+pulso+falha*.065+risco);
}

"""
lz.py -- Mad Mix Game v9990: compresor LZ sencillo para la portada del
V9990 (lo descomprime V9_DESCOMPRIMIR en src/rom/rom.asm, leyendo las
coincidencias de la propia VRAM del V9990).

Formato: byte t. t = 0: fin. t = 1-127: t bytes literales. t = 128-255:
copia de t - 125 bytes (3-130) desde dist bytes atras (DW dist, 16-65535;
con 16 o mas, lo que se lee de la VRAM ya esta escrito).
"""


def comprimir(d, min_off=16, max_len=130):
    out=bytearray(); lit=bytearray(); i=0; n=len(d)
    pos={}
    def flush():
        nonlocal lit
        while lit:
            k=lit[:127]; out.append(len(k)); out.extend(k); lit=lit[127:]
    def add(j):
        if j+3<=n: pos.setdefault(bytes(d[j:j+3]),[]).append(j)
    while i<n:
        best=0; bo=0
        if i+3<=n:
            for j in reversed(pos.get(bytes(d[i:i+3]),[])[-256:]):
                o=i-j
                if o<min_off: continue
                if o>65535: break
                l=0
                while l<max_len and i+l<n and d[j+l]==d[i+l]: l+=1
                if l>best: best,bo=l,o
                if l==max_len: break
        if best>=3:
            flush(); out.append(128+best-3); out+=bo.to_bytes(2,'little')
            for k in range(best): add(i+k)
            i+=best
        else:
            lit.append(d[i]); add(i); i+=1
    flush(); out.append(0); return bytes(out)
def descomprimir(z):
    o=bytearray(); p=0
    while True:
        t=z[p]; p+=1
        if t==0: return bytes(o)
        if t<128: o+=z[p:p+t]; p+=t
        else:
            l=t-125; off=z[p]|z[p+1]<<8; p+=2
            for k in range(l): o.append(o[-off])

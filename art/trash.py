"""ArkadeOS dock trash (T069, approved by Roland 2026-11-01): a perforated metal
bin in the macOS manner, empty and full.

Usage: python3 -I art/trash.py <out dir> (writes mac.svg and mac-full.svg;
they ship as system_files/usr/share/arkadeos/icons/user-trash{,-full}.svg)."""
import math,sys
out=sys.argv[1]
CX=128; TY=58; BY=222; RT=86; RB=68; RYT=19; RYB=13
def r_at(y): return RT+(RB-RT)*(y-TY)/(BY-TY)
def ry_at(y): return RYT+(RYB-RYT)*(y-TY)/(BY-TY)
body=f"M{CX-RT} {TY} L{CX-RB} {BY} A{RB} {RYB} 0 0 0 {CX+RB} {BY} L{CX+RT} {TY} A{RT} {RYT} 0 0 1 {CX-RT} {TY} Z"
slots=[];hl=[]
y=82
row=0
while y<205:
    r=r_at(y); ry=ry_at(y)
    off=6 if row%2 else 0
    a=-84+off
    while a<=84:
        t=math.radians(a); c=math.cos(t)
        x=CX+r*math.sin(t); yy=y+ry*c*0.55
        w=max(1.0,6.0*c); h=8.5
        slots.append(f'<rect x="{x-w/2:.2f}" y="{yy-h/2:.2f}" width="{w:.2f}" height="{h}" rx="{min(w,h)/2:.2f}" opacity="{0.55+0.45*c:.2f}"/>')
        hl.append(f'<rect x="{x-w/2:.2f}" y="{yy+h/2-.4:.2f}" width="{w:.2f}" height="1.6" rx=".8" opacity="{0.7*c:.2f}"/>')
        a+=12
    y+=12.5; row+=1
defs=f'''<defs>
<linearGradient id="body" x1="0" y1="0" x2="1" y2="0">
 <stop offset="0" stop-color="#aeb4bf"/><stop offset=".18" stop-color="#e4e7ec"/><stop offset=".38" stop-color="#fbfbfc"/><stop offset=".62" stop-color="#eef0f3"/><stop offset=".86" stop-color="#c4c9d1"/><stop offset="1" stop-color="#9da4b0"/></linearGradient>
<linearGradient id="vshade" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".0"/><stop offset=".75" stop-color="#5a606b" stop-opacity=".0"/><stop offset="1" stop-color="#5a606b" stop-opacity=".28"/></linearGradient>
<linearGradient id="inside" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7c838f"/><stop offset="1" stop-color="#b7bcc5"/></linearGradient>
<linearGradient id="rim" gradientUnits="userSpaceOnUse" x1="0" y1="{TY-RYT-4}" x2="0" y2="{TY+RYT+4}"><stop offset="0" stop-color="#ffffff"/><stop offset=".45" stop-color="#e3e6eb"/><stop offset="1" stop-color="#a9afb9"/></linearGradient>
<linearGradient id="spec" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#fff" stop-opacity="0"/><stop offset=".5" stop-color="#fff" stop-opacity=".85"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>
<linearGradient id="slot" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#5d6470"/><stop offset="1" stop-color="#8d94a0"/></linearGradient>
<linearGradient id="paper" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#d9dce2"/></linearGradient>
<linearGradient id="paper2" x1="1" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fdfdfd"/><stop offset="1" stop-color="#c9cdd5"/></linearGradient>
<radialGradient id="ball" cx=".38" cy=".32" r=".75"><stop offset="0" stop-color="#ffffff"/><stop offset=".6" stop-color="#eef0f3"/><stop offset="1" stop-color="#c3c8d0"/></radialGradient><radialGradient id="ballsh" cx=".7" cy=".8" r=".7"><stop offset="0" stop-color="#6c727d" stop-opacity=".22"/><stop offset="1" stop-color="#6c727d" stop-opacity="0"/></radialGradient><clipPath id="clip"><path d="{body}"/></clipPath>
<filter id="sh" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="5"/></filter>
<filter id="soft" x="-10%" y="-10%" width="120%" height="120%"><feGaussianBlur stdDeviation=".6"/></filter>
</defs>'''
shadow=f'<ellipse cx="{CX}" cy="{BY+8}" rx="{RB+6}" ry="{RYB+3}" fill="#000" opacity=".32" filter="url(#sh)"/>'
inside=f'<ellipse cx="{CX}" cy="{TY}" rx="{RT-3}" ry="{RYT-3}" fill="url(#inside)"/>'
# back wall slots visible through the opening: soft darker band
backwall=f'<ellipse cx="{CX}" cy="{TY+3}" rx="{RT-9}" ry="{RYT-8}" fill="#5f6672" opacity=".45" filter="url(#soft)"/>'
bodyp=f'<path d="{body}" fill="url(#body)" opacity=".97"/>'
slotg=f'<g clip-path="url(#clip)"><g fill="url(#slot)">{"".join(slots)}</g><g fill="#fff">{"".join(hl)}</g><path d="{body}" fill="url(#vshade)"/><rect x="{CX-46}" y="{TY}" width="22" height="{BY-TY+20}" fill="url(#spec)" opacity=".55"/><rect x="{CX+40}" y="{TY}" width="10" height="{BY-TY+20}" fill="url(#spec)" opacity=".3"/></g>'
edge=f'<path d="{body}" fill="none" stroke="#8a919c" stroke-width="1.4" opacity=".7"/>'
rim_back=f'<path d="M{CX-RT} {TY} A{RT} {RYT} 0 0 1 {CX+RT} {TY}" fill="none" stroke="url(#rim)" stroke-width="8" stroke-linecap="round"/>'
rim_front=f'<path d="M{CX-RT} {TY} A{RT} {RYT} 0 0 0 {CX+RT} {TY}" fill="none" stroke="url(#rim)" stroke-width="8" stroke-linecap="round"/><path d="M{CX-RT+2} {TY+3} A{RT-2} {RYT-1} 0 0 0 {CX+RT-2} {TY+3}" fill="none" stroke="#7d8490" stroke-width="1.2" opacity=".6"/><path d="M{CX-RT+6} {TY-2} A{RT-6} {RYT-4} 0 0 0 {CX+RT-6} {TY-2}" fill="none" stroke="#fff" stroke-width="1.6" opacity=".9"/>'
def ball(cx,cy,r,k):
    import random
    rnd=random.Random(k*7+3)
    n=11; pts=[]
    for i in range(n):
        a=2*math.pi*i/n; rr=r*(0.82+0.3*rnd.random())
        pts.append((cx+rr*math.cos(a),cy+rr*math.sin(a)*0.92))
    d="M%.1f %.1f "%pts[0]
    for i in range(1,n+1):
        x0,y0=pts[i-1]; x1,y1=pts[i%n]
        mx,my=(x0+x1)/2,(y0+y1)/2
        d+="Q%.1f %.1f %.1f %.1f "%(x0,y0,mx,my)
    d+="Z"
    folds=""
    for i in range(5):
        a=rnd.random()*2*math.pi; b=a+1.6+rnd.random()
        x0,y0=cx+r*0.15*math.cos(a),cy+r*0.15*math.sin(a)
        x1,y1=cx+r*0.85*math.cos(b),cy+r*0.8*math.sin(b)
        qx,qy=cx+r*0.55*math.cos((a+b)/2+0.5),cy+r*0.5*math.sin((a+b)/2+0.5)
        folds+='<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f" stroke="#b9bec7" stroke-width="1.4" fill="none" stroke-linecap="round"/>'%(x0,y0,qx,qy,x1,y1)
        folds+='<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f" stroke="#fff" stroke-width="1.1" fill="none" stroke-linecap="round" opacity=".9" transform="translate(1.2 1.2)"/>'%(x0,y0,qx,qy,x1,y1)
    return '<g><path d="%s" fill="url(#ball)" stroke="#a2a8b2" stroke-width="1.2"/>%s<path d="%s" fill="url(#ballsh)"/></g>'%(d,folds,d)
def svg(full):
    parts=[defs,shadow,bodyp,slotg,edge,rim_back,inside,backwall]
    if full: parts.append(ball(98,46,30,0)+ball(160,40,33,1)+ball(128,60,22,2))
    parts.append(rim_front)
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">{"".join(parts)}</svg>'
open(f'{out}/mac.svg','w').write(svg(False)); open(f'{out}/mac-full.svg','w').write(svg(True))

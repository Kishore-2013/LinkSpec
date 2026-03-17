((a,b,c)=>{a[b]=a[b]||{}
a[b][c]=a[b][c]||[]
a[b][c].push({p:"main.dart.js_1",e:"beginPart"})})(self,"$__dart_deferred_initializers__","eventLog")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,B,C={
bv1(d,e){return new C.td(d,null)},
td:function td(d,e){this.c=d
this.a=e},
PB:function PB(d,e,f,g){var _=this
_.d=d
_.e=e
_.f=f
_.r=!0
_.w=g
_.x=""
_.c=_.a=null},
aTI:function aTI(d){this.a=d},
aTH:function aTH(d){this.a=d},
aTA:function aTA(d){this.a=d},
aTB:function aTB(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
aTz:function aTz(){},
aTC:function aTC(d){this.a=d},
aTy:function aTy(d){this.a=d},
aTD:function aTD(d){this.a=d},
aTE:function aTE(d){this.a=d},
aTG:function aTG(){},
aTF:function aTF(d,e){this.a=d
this.b=e},
aTx:function aTx(d,e,f,g){var _=this
_.a=d
_.b=e
_.c=f
_.d=g},
aTu:function aTu(d,e){this.a=d
this.b=e},
aTv:function aTv(d){this.a=d},
aTw:function aTw(d){this.a=d},
aE0(d){var x=0,w=A.o(y.p),v,u,t,s,r,q
var $async$aE0=A.k(function(e,f){if(e===1)return A.l(f,w)
while(true)switch(x){case 0:s=$.bM()
r=s.gaR().c
r=r==null?null:r.r
u=r==null?null:r.a
if(u==null){v=A.a([],y.t)
x=1
break}t=s.aU("profiles").hw().U4("id",u)
q=A
x=3
return A.i(t.ew("full_name",!0).yc(0,d-1),$async$aE0)
case 3:v=q.c8(f,!0,y.P)
x=1
break
case 1:return A.m(v,w)}})
return A.n($async$aE0,w)},
aEm(){var x=0,w=A.o(y.C),v,u=2,t,s,r,q,p,o,n,m
var $async$aEm=A.k(function(d,e){if(d===1){t=e
x=u}while(true)switch(x){case 0:o=$.bM()
n=o.gaR().c
n=n==null?null:n.r
s=n==null?null:n.a
if(s==null){v=A.az(y.N)
x=1
break}u=4
x=7
return A.i(o.aU("messages").d4("sender_id").b6("receiver_id",s).nJ("is_read.eq.false,is_read.is.null"),$async$aEm)
case 7:r=e
o=J.ds(r,new C.aEn(),y.N).hp(0)
v=o
x=1
break
u=2
x=6
break
case 4:u=3
m=t
q=A.Q(m)
A.cm().$1("getUnreadSenderIds error: "+A.h(q))
v=A.az(y.N)
x=1
break
x=6
break
case 3:x=2
break
case 6:case 1:return A.m(v,w)
case 2:return A.l(t,w)}})
return A.n($async$aEm,w)},
aE5(){var x=0,w=A.o(y.p),v,u,t,s,r,q,p,o,n,m,l
var $async$aE5=A.k(function(d,e){if(d===1)return A.l(e,w)
while(true)switch(x){case 0:n=$.bM()
m=n.gaR().c
m=m==null?null:m.r
u=m==null?null:m.a
if(u==null){v=A.a([],y.t)
x=1
break}m=y.P
l=A
x=3
return A.i(n.aU("messages").d4("          sender_id,\n          receiver_id,\n          sender:profiles!sender_id (id, full_name, avatar_url, domain_id),\n          receiver:profiles!receiver_id (id, full_name, avatar_url, domain_id)\n        ").nJ("sender_id.eq."+u+",receiver_id.eq."+u).ew("created_at",!1),$async$aE5)
case 3:t=l.c8(e,!0,m)
n=y.N
s=A.v(n,m)
for(m=t.length,r=y.z,q=0;q<m;++q){p=t[q]
o=J.e(p.h(0,"sender_id"),u)?p.h(0,"receiver"):p.h(0,"sender")
if(o!=null&&!s.af(J.au(o,"id")))s.n(0,J.au(o,"id"),A.lh(o,n,r))}n=s.gb1()
v=A.O(n,!0,A.p(n).i("A.E"))
x=1
break
case 1:return A.m(v,w)}})
return A.n($async$aE5,w)},
aEn:function aEn(){}},D
J=c[1]
A=c[0]
B=c[2]
C=a.updateHolder(c[3],C)
D=c[5]
C.td.prototype={
Z(){var x=A.a([],y.t),w=y.N
return new C.PB(x,A.az(w),A.az(w),new A.c_(B.a8,$.af()))}}
C.PB.prototype={
ai(){var x=this
x.aA()
x.vB()
x.w.V(new C.aTI(x))},
m(){var x=this.w
x.L$=$.af()
x.O$=0
this.am()},
vB(){var x=0,w=A.o(y.H),v,u=2,t,s=this,r,q,p,o,n,m,l,k
var $async$vB=A.k(function(d,e){if(d===1){t=e
x=u}while(true)switch(x){case 0:if(s.c==null){x=1
break}s.D(new C.aTA(s))
u=4
x=7
return A.i(A.f7(A.a([C.aE0(200),C.aE5(),C.aEm()],y.U),y.K),$async$vB)
case 7:r=e
m=y.p
q=m.a(J.au(r,0))
p=m.a(J.au(r,1))
o=y.C.a(J.au(r,2))
if(s.c!=null)s.D(new C.aTB(s,q,p,o))
u=2
x=6
break
case 4:u=3
k=t
n=A.Q(k)
A.cm().$1("Error loading messaging directory: "+A.h(n))
if(s.c!=null)s.D(new C.aTC(s))
x=6
break
case 3:x=2
break
case 6:case 1:return A.m(v,w)
case 2:return A.l(t,w)}})
return A.n($async$vB,w)},
gark(){var x,w=this
if(w.x.length===0)return w.d
x=J.v4(w.d,new C.aTy(w))
return A.O(x,!0,x.$ti.i("A.E"))},
I(d){var x,w,v,u,t,s,r,q,p,o=this,n=null,m=o.gark(),l=J.cv(m)
l.fs(m,new C.aTD(o))
x=A.t(d)
w=o.a.c
w=A.ch(n,n,n,B.da,n,n,w,n,n,n,n)
v=o.gays()
u=y.D
w=A.hL(A.a([A.ch(n,n,n,D.Vw,n,n,v,n,n,n,"Refresh")],u),B.u,n,0,n,w,n,D.aeo,n)
t=A.o8(0,A.jB(new A.dF(B.hM,n,n,new A.ae(B.ij,A.o4(A.oo("assets/svg/undraw_text-messages_978a.svg",n,n,B.c1,n,n,n,450),0.25),n),n),!0,n))
s=A.t(d).xr.b
if(s==null)s=B.k
r=A.an(14)
q=A.a([new A.cw(0,B.aw,A.a7(13,B.o.gk()>>>16&255,B.o.gk()>>>8&255,B.o.gk()&255),B.iN,8)],y.V)
s=A.ax(n,A.eZ(!0,B.aJ,!1,n,!0,B.p,n,A.fi(),o.w,n,n,n,n,n,2,A.eQ(n,B.cd,n,B.il,n,n,n,n,!0,n,n,n,n,n,n,n,n,n,n,n,n,n,n,n,n,n,n,n,n,B.HZ,"Search people...",n,n,n,n,n,n,n,n,n,!0,n,D.Wj,n,n,n,n,n,n,o.x.length!==0?A.ch(n,n,n,D.VV,n,n,new C.aTE(o),n,n,n,n):n,n,n,n,n),B.t,!0,n,!0,n,!1,n,B.aG,n,n,n,n,n,n,n,1,n,n,!1,"\u2022",n,n,n,n,n,!1,n,!1,n,!0,n,B.at,n,n,B.aF,B.aB,n,n,n,n,n,n,n,B.M,n,B.ap,n,n,n,n),B.m,n,n,new A.aE(s,n,n,r,q,n,B.x),n,n,n,n,n,n,n,n)
if(o.r)l=B.bm
else if(l.ga8(m)){l=o.x
r=l.length===0
p=!r
q=A.bz(p?B.vs:D.Ve,B.i8,n,n,64)
l=A.a([q,B.U,A.G(p?'No users match "'+l+'"':"No users found",n,n,n,n,D.a9p,B.bq,n,n)],u)
if(r)B.b.G(l,A.a([B.ae,D.ag0],u))
l=A.ce(new A.ae(D.SV,A.aa(l,B.l,n,B.bd,B.i),n),n,n)}else l=A.wM(new C.aTF(o,m),l.gv(m),D.Sx,B.es,new C.aTG(),!1)
return A.eH(w,x.go,A.dx(B.ar,A.a([t,A.aa(A.a([new A.ae(D.Sz,s,n),A.bn(A.xu(l,40,v),1)],u),B.l,n,B.f,B.i)],u),B.p,B.al,n),n,n,n)},
anL(d){var x,w,v,u,t,s,r,q,p,o,n,m,l=this,k=null,j=A.ay(d.h(0,"id"))
l.e.p(0,j)
x=l.f.p(0,j)
w=A.aJ(d.h(0,"full_name"))
if(w==null)w="Unknown"
v=A.aJ(d.h(0,"domain_id"))
if(v==null)v=""
u=A.aJ(d.h(0,"avatar_url"))
t=l.c
t.toString
t=A.t(t).xr.b
if(t==null)t=B.k
t=A.a7(217,t.gk()>>>16&255,t.gk()>>>8&255,t.gk()&255)
s=A.an(16)
r=x?A.a7(89,B.v.gk()>>>16&255,B.v.gk()>>>8&255,B.v.gk()&255):A.a7(B.d.R(25.5),B.a3.gk()>>>16&255,B.a3.gk()>>>8&255,B.a3.gk()&255)
q=x?1.5:1
p=u==null
o=!p?new A.fH(u,1,k):k
o=A.dx(B.ar,A.a([A.fY(B.bc,o,p?A.G(w[0].toUpperCase(),k,k,k,k,B.HV,k,k,k):k,k,24)],y.D),B.p,B.al,k)
p=A.G(w,k,k,k,k,A.aq(k,k,k,k,k,k,k,k,k,k,k,15,k,k,x?B.dD:B.z,k,k,!0,k,k,k,k,k,k,k,k),k,k,k)
n=v.length!==0?v.toUpperCase():"Member"
n=A.G(n,k,k,k,k,A.aq(k,k,B.an,k,k,k,k,k,k,k,k,11,k,k,B.aa,k,k,!0,k,0.3,k,k,k,k,k,k),k,k,k)
m=x?A.ax(k,D.Wt,B.m,k,k,B.mr,k,k,k,k,B.ux,k,k,k):B.VT
return A.zu(A.mi(B.nw,o,new C.aTx(l,x,j,d),n,p,m),k,t,0,k,new A.bw(s,new A.aV(r,q,B.A,-1)))}}
var z=a.updateTypes(["a0<~>()"])
C.aTI.prototype={
$0(){var x=this.a
x.D(new C.aTH(x))},
$S:0}
C.aTH.prototype={
$0(){var x=this.a
return x.x=B.c.b_(x.w.a.a).toLowerCase()},
$S:0}
C.aTA.prototype={
$0(){return this.a.r=!0},
$S:0}
C.aTB.prototype={
$0(){var x=this,w=x.a
w.d=x.b
w.e=J.ds(x.c,new C.aTz(),y.N).hp(0)
w.f=x.d
w.r=!1},
$S:0}
C.aTz.prototype={
$1(d){return A.ay(d.h(0,"id"))},
$S:67}
C.aTC.prototype={
$0(){return this.a.r=!1},
$S:0}
C.aTy.prototype={
$1(d){var x,w,v=A.aJ(d.h(0,"full_name"))
if(v==null)v=""
x=A.aJ(d.h(0,"domain_id"))
if(x==null)x=""
w=this.a.x
return B.c.p(v.toLowerCase(),w)||B.c.p(x.toLowerCase(),w)},
$S:92}
C.aTD.prototype={
$2(d,e){var x="full_name",w=this.a,v=w.e.p(0,d.h(0,"id"))?0:1,u=w.e.p(0,e.h(0,"id"))?0:1
if(v!==u)return B.e.bm(v,u)
return B.c.bm(A.ay(d.h(0,x)),A.ay(e.h(0,x)))},
$S:120}
C.aTE.prototype={
$0(){this.a.w.ks(B.ji)
return null},
$S:0}
C.aTG.prototype={
$2(d,e){return B.bX},
$S:71}
C.aTF.prototype={
$2(d,e){return this.a.anL(J.au(this.b,e))},
$S:50}
C.aTx.prototype={
$0(){var x,w,v,u=this
if(u.b){x=u.a
w=u.c
x.D(new C.aTu(x,w))
A.Ml(w)}x=u.a
w=x.c
w.toString
v=A.h8(new C.aTv(u.d),null,y.z)
A.bb(w,!1).dm(v).aZ(new C.aTw(x),y.H)},
$S:0}
C.aTu.prototype={
$0(){return this.a.f.F(0,this.b)},
$S:0}
C.aTv.prototype={
$1(d){return new A.lY(this.a,null)},
$S:94}
C.aTw.prototype={
$1(d){return this.a.vB()},
$S:101}
C.aEn.prototype={
$1(d){return A.ay(J.au(d,"sender_id"))},
$S:25};(function installTearOffs(){var x=a._instance_0u
x(C.PB.prototype,"gays","vB",0)})();(function inheritance(){var x=a.inherit,w=a.inheritMany
x(C.td,A.W)
x(C.PB,A.Y)
w(A.Gn,[C.aTI,C.aTH,C.aTA,C.aTB,C.aTC,C.aTE,C.aTx,C.aTu])
w(A.p5,[C.aTz,C.aTy,C.aTv,C.aTw,C.aEn])
w(A.Go,[C.aTD,C.aTG,C.aTF])})()
A.bip(b.typeUniverse,JSON.parse('{"td":{"W":[],"f":[]},"PB":{"Y":["td"]}}'))
var y=(function rtii(){var x=A.al
return{V:x("w<cw>"),U:x("w<a0<z>>"),t:x("w<a3<c,@>>"),D:x("w<f>"),p:x("I<a3<c,@>>"),P:x("a3<c,@>"),K:x("z"),C:x("bQ<c>"),N:x("c"),z:x("@"),H:x("~")}})();(function constants(){D.Sx=new A.Z(16,8,16,16)
D.Sz=new A.Z(16,8,16,4)
D.SV=new A.Z(40,40,40,40)
D.Ve=new A.aj(983133,"MaterialIcons",null,!1)
D.Vh=new A.aj(983273,"MaterialIcons",null,!1)
D.Vw=new A.b9(D.Vh,null,B.v,null,null)
D.VV=new A.b9(B.nQ,18,B.a3,null,null)
D.Wj=new A.b9(B.kF,20,B.v,null,null)
D.Wt=new A.b9(B.vo,14,B.k,null,null)
D.a9p=new A.u(!0,B.aM,null,null,null,null,16,B.z,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
D.aeo=new A.as("Messages",null,null,null,null,null,null,null,null,null,null)
D.ag0=new A.as("Registered users will appear here",null,B.cW,B.bq,null,null,null,null,null,null,null)})()};
((a,b)=>{a[b]=a.current
a.eventLog.push({p:"main.dart.js_1",e:"endPart",h:b})})($__dart_deferred_initializers__,"Yv1xv4iiXUWbkSsSaGlaHZJTwM0=");
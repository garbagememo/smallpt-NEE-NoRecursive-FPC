program smallpt;
{$MODE objfpc}
{$modeswitch advancedrecords}
{$INLINE ON}

uses SysUtils,Classes,uVect,WriteBMP,Math,uModel,GetOpts;

const
// Aspect=0.5135;
Aspect=0.35;
//Aspect=0.7;

var
  sph:TList;

var
  DF:boolean;//debug
  DebugInt:integer;//DebugX,DebugY:integer;

var
  AutoFlag:boolean;
  AutoIndex:integer;


function intersect(const r:RayRecord;var t:real; var id:integer):boolean;
var
  n,d:real;
  i:integer;
BEGIN
  t:=INF;
  for i:=0 to sph.count-1 do BEGIN
    d:=SphereClass(sph[i]).intersect(r);
    IF d<t THEN BEGIN
      t:=d;
      id:=i;
    END;
  END;
  result:=(t<inf);
END;


function radiance(r:RayRecord):VecRecord;
var
  id,i,tid:integer;
  obj,s:SphereClass;
  x,n,f,nl,u,v,w,d:VecRecord;
  p,r1,r2,r2s,t:real;
  into:boolean;
  RefRay:RayRecord;
  nc,nt,nnt,ddn,cos2t,q,a,b,c,R0,Re,RP,Tr,TP:real;
  tDir:VecRecord;
  EL,sw,su,sv,l,tw,tu,tv:VecRecord;
  cos_a_max,eps1,eps2,eps2s,cos_a,sin_a,phi,omega:real;
  cl,cf,bcf:VecRecord;
  E,depth:integer;
BEGIN
//writeln(' DebugY=',DebugY,' DebugX=',DebugX);
  depth:=0;
  id:=0;cl:=ZeroVec;cf:=CreateVec(1,1,1);E:=1;
  WHILE (TRUE) DO BEGIN
    Inc(depth);
    IF intersect(r,t,id)=FALSE THEN BEGIN
      result:=cl;
      exit;
    END;
    obj:=SphereClass(sph[id]);
    x:=r.o+r.d*t; n:=VecNorm(x-obj.p); f:=obj.c;
    IF n*r.d<0 THEN nl:=n ELSE nl:=n*-1;
    IF (f.x>f.y)and(f.x>f.z) THEN
      p:=f.x
    ELSE IF f.y>f.z THEN
      p:=f.y
    ELSE
      p:=f.z;
    tw:=obj.e*E;
    cl:=cl+VecMul(cf,tw);
    IF (depth>5) THEN BEGIN
      IF random<p THEN
        f:=f/p
      ELSE BEGIN
        result:=cl;
        exit;
      END;
    END;
    bcf:=cf;cf:=VecMul(cf,f);
    CASE obj.refl OF
      DIFF:BEGIN
 //       x:=x+nl*eps;(*ad hoc 突き抜け防止*)
        r1:=2*PI*random;r2:=random;r2s:=sqrt(r2);
        w:=nl;
        IF abs(w.x)>0.1 THEN
          u:=VecNorm(CreateVec(0,1,0)/w)
        ELSE BEGIN
          u:=VecNorm(CreateVec(1,0,0)/w );
        END;
        v:=w/u;
        tu:=u*(cos(r1)*r2s);tu:=tu+v*(sin(r1)*r2s);tu:=tu+w*sqrt(1-r2);
        d := VecNorm(tu);

      // Loop over any lights
        EL:=ZeroVec;
        tid:=id;
        for i:=0 to sph.count-1 do BEGIN
          s:=SphereClass(sph[i]);
          IF (i=tid) THEN BEGIN
            continue;
          END;
          IF (s.e.x<=0) and  (s.e.y<=0) and (s.e.z<=0)  THEN continue; // skip non-lights
          sw:=s.p-x;
          tr:=sw*sw;  tr:=s.rad2/tr;
          IF abs(sw.x)/sqrt(tr)>1e-8 THEN 
            su:=VecNorm(CreateVec(0,1,0)/sw) 
          ELSE 
            su:=VecNorm(CreateVec(1,0,0)/sw);
          sv:=sw/su;
          IF tr>1 THEN BEGIN
            (*半球の内外=cos_aがマイナスとsin_aが＋、－で場合分け*)
            (*半球内部なら乱反射した寄与全てを取ればよい・・はず*)
            eps1:=2*pi*random;eps2:=random;eps2s:=sqrt(eps2);
            tu:=u*(cos(eps1)*eps2s);tu:=tu+v*(sin(eps1)*eps2s);tu:=tu+w*sqrt(1-eps2);
            l:=VecNorm(tu);
            IF intersect(CreateRay(x,l),t,id) THEN BEGIN
              IF id=i THEN BEGIN
                tr:=l*nl;
                tw:=s.e*tr;
                EL:=EL+VecMul(f,tw);
              END;
            END;
            CONTINUE;
          END;
          cos_a_max := sqrt(1-tr );
          eps1 := random; eps2:=random;
          cos_a := 1-eps1+eps1*cos_a_max;
          sin_a := sqrt(1-cos_a*cos_a);
          IF (1-2*random)<0 THEN sin_a:=-sin_a; 
          phi := 2*PI*eps2;
          tw:=sw*(cos(phi)*sin_a);tw:=tw+sv*(sin(phi)*sin_a);tw:=tw+sw*cos_a;
          l:=VecNorm(tw);
          IF (intersect(CreateRay(x,l), t, id) ) THEN BEGIN 
            IF id=i THEN BEGIN  // shadow ray
              omega := 2*PI*(1-cos_a_max);
              tr:=l*nl;
              IF tr<0 THEN tr:=0;
              tw:=s.e*tr*omega;tw:=VecMul(f,tw);tw:=tw*M_1_PI;
              EL := EL + tw;  // 1/pi for brdf
            END;
          END;
        END;(*for*)
        tw:=obj.e*e+EL;
        cl:= cl+VecMul(bcf,tw );
        E:=0;
        r:=CreateRay(x,d)
      END;(*DIFF*)
      SPEC:BEGIN
        tw:=obj.e*e;
        cl:=cl+VecMul(bcf,tw);
        E:=1;tv:=n*2*(n*r.d) ;tv:=r.d-tv;
        r:=CreateRay(x,tv);
      END;(*SPEC*)
      REFR:BEGIN
        tv:=n*2*(n*r.d) ;tv:=r.d-tv;
        RefRay:=CreateRay(x,tv);
        into:= (n*nl>0);
        nc:=1;nt:=1.5; IF into THEN nnt:=nc/nt ELSE nnt:=nt/nc; ddn:=r.d*nl;
        cos2t:=1-nnt*nnt*(1-ddn*ddn);
        IF cos2t<0 THEN BEGIN   // Total internal reflection
          cl:=cl+VecMul(bcf,obj.e*E);
          E:=1;
          r:=RefRay;
          continue;
        END;
        IF into THEN q:=1 ELSE q:=-1;
        tdir := VecNorm(r.d*nnt - n*(q*(ddn*nnt+sqrt(cos2t))));
        IF into THEN Q:=-ddn ELSE Q:=tdir*n;
        a:=nt-nc; b:=nt+nc; R0:=a*a/(b*b); c := 1-Q;
        Re:=R0+(1-R0)*c*c*c*c*c;Tr:=1-Re;P:=0.25+0.5*Re;RP:=Re/P;TP:=Tr/(1-P);
        IF random<p THEN BEGIN// 反射
          cf:=cf*RP;
          cl:=cl+VecMul(bcf,obj.e*E);
          E:=1;
          r:=RefRay;
        END
        ELSE BEGIN//屈折
          cf:=cf*TP;
          cl:=cl+VecMul(bcf,obj.e*E);
          E:=1;
          r:=CreateRay(x,tdir);
        END
      END;(*REFR*)
    END;(*CASE*)
  END;(*WHILE LOOP *)
END;


VAR
  x,y,sx,sy,s: INTEGER;
  w,h,samps,height    : INTEGER;
  temp,d       : VecRecord;
  tColor,r: VecRecord;
  cam:CameraRecord;

  BMPClass:BMPIOClass;
  ScrWidth,ScrHeight:integer;
  vColor:rgbColor;
  FN:string;
  T1,T2:TDateTime;
  HH,MM,SS,MS:WORD;
  c:char;
  ArgFN:String;
  ArgInt,ModelId:integer;
  AutoFileName:String;
  SR:SnapRecord;
BEGIN
//DEBUG
  DF:=FALSE;
  DebugInt:=0;

  FN:=ExtractFileName(paramStr(0));
  Delete(FN,Length(FN)-3,4);
  FN:=FN+'.bmp';

  randomize;
  w:=320 ;h:=240;  samps := 16;

  AutoFlag:=FALSE;

//----Scene Setup----
  InitScene;
  ModelId:=1;
  sph:=CopyScene(ModelId);

  c:=#0;
  repeat
    c:=getopt('am:o:s:w:');

    case c of
      'a':BEGIN
        autoflag:=TRUE;
        SR.MakeSnap;
        AutoIndex:=0;
        AutoFileName:=FN;
        delete(AutoFileName,length(AutoFileName)-3,4);
      END;
      'm' :BEGIN
        ArgInt:=StrToInt(OptArg);
        IF (ArgInt<Sc.count) and (ArgInt>-1) THEN BEGIN
          ModelId:=ArgInt;
          FN:=ExtractFileName(paramStr(0));
          Delete(FN,Length(FN)-3,4);
          FN:=FN+IntToStr(ModelId)+'.bmp';
          sph:=CopyScene(ArgInt);
          writeln('Model of Scene =',ArgInt,' ',ScName[ArgInt]);
        END;
      END;
      'o' : BEGIN
         ArgFN:=OptArg;
         IF ArgFN<>'' THEN FN:=ArgFN;
         writeln ('Output FileName =',FN);
      END;
      's' : BEGIN
        ArgInt:=StrToInt(OptArg);
        samps:=ArgInt;
        writeln('samples =',ArgInt);
      END;
      'w' : BEGIN
         ArgInt:=StrToInt(OptArg);
         w:=ArgInt;h:=w *3 div 4;
         writeln('w=',w,' ,h=',h);
      END;
      '?',':' : BEGIN
         writeln(' -a AutoFlag ON ');
         writeln(' -m [index] built in Mode Number');
         writeln(' -o [finename] output filename');
         writeln(' -s [samps] sampling count');
         writeln(' -w [width] screen width pixel');
      END;
    end; { case }
  until c=endofoptions;

  BMPClass:=BMPIOClass.Create(w,h);
  cam:=CameraSet(CreateVec(50, 52, 295.6),
                 VecNorm(CreateVec(0,-0.042612,-1) ),
                 w,h,0.5135,140);


  repeat
    IF AutoFlag THEN BEGIN
      cam:=CameraSet(CreateVec(0, 300, 0),
                     VecNorm(CreateVec(0,-1,0) ),
                     w,h,0.5135,140);
      sph:=SR.CopySnap(AutoIndex);
      Writeln(' Auto Scene Index=',AutoIndex);
      FN:=AutoFileName+IntToStr(AutoIndex)+'.bmp';
      Writeln(' Auto File Name=',FN);
      inc(AutoIndex);
      IF AutoIndex > SR.SnapList.count THEN AutoFlag:=FALSE;
    END;

    T1:=Time;
    Writeln ('The time is : ',TimeToStr(Time));

    FOR y :=0 TO h-1 DO BEGIN
      IF y mod 10 =0 THEN writeln('y=',y);
      FOR x := 0 TO w - 1 DO BEGIN
        FOR sy := 0 TO 1 DO BEGIN
          r:=CreateVec(0, 0, 0);
          tColor:=ZeroVec;
          FOR sx := 0 TO 1 DO BEGIN
            FOR s := 0 TO samps - 1 DO BEGIN
              r:= r+Radiance(GetRay(cam,x,y,sx,sy))/samps;
            END;(*samps*)
            temp:= r* 0.24;
            tColor:=tColor+ temp;
            r:=CreateVec(0, 0, 0);
          END;(*sx*)
        END;(*sy*)
        vColor:=ColToRGB(tColor);
        BMPClass.SetPixel(x,h-y,vColor);
      END;(* for x *)
    END;(*for y*)
    T2:=Time-T1;
    DecodeTime(T2,HH,MM,SS,MS);
    Writeln ('The time is : ',HH,'h:',MM,'min:',SS,'sec');
    BMPClass.WriteBMPFile(FN);
  UNTIL AutoFlag=FALSE;

  writeln('DebugInt=',DebugInt);
END.

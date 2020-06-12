program smallpt;
{$MODE objfpc}
{$INLINE ON}

uses SysUtils,Classes,uVect,WriteBMP,Math,uModel,GetOpts;

var
  DF:boolean;//debug
  DebugInt:integer;
  Debugx,DebugY,StartY:integer;

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
  nc,nt,nnt,ddn,cos2t,q,a,b,c,R0,Re,RP,Tr,TTr,TP:real;
  tDir:VecRecord;
  cl,cf:VecRecord;
  depth:integer;
  
BEGIN
//writeln(' DebugY=',DebugY,' DebugX=',DebugX);
  depth:=0;
  id:=0;cl:=ZeroVec;cf:=CreateVec(1,1,1);;
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
    cl:=cl+VecMul(cf,obj.e);
    IF (depth>5) THEN BEGIN
      IF random<p THEN
        f:=f/p
      ELSE BEGIN
        result:=cl;
        exit;
      END;
    END;
    cf:=VecMul(cf,f);
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
        d := VecNorm(u*cos(r1)*r2s + v*sin(r1)*r2s + w*sqrt(1-r2));

        r:=CreateRay(x,d)
      END;(*DIFF*)
      SPEC:BEGIN
        r:=CreateRay(x,r.d-n*2*(n*r.d));
      END;(*SPEC*)
      REFR:BEGIN
        RefRay:=CreateRay(x,r.d-n*2*(n*r.d) );
        into:= (n*nl>0);
        nc:=1;nt:=1.5; IF into THEN nnt:=nc/nt ELSE nnt:=nt/nc; ddn:=r.d*nl;
        cos2t:=1-nnt*nnt*(1-ddn*ddn);
        IF cos2t<0 THEN BEGIN   // Total internal reflection
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
          r:=RefRay;
        END
        ELSE BEGIN//屈折
          cf:=cf*TP;
          r:=CreateRay(x,tdir);
        END
      END;(*REFR*)
    END;(*CASE*)
  END;(*WHILE LOOP *)
END;


VAR
  x,y,sx,sy,i,s: INTEGER;
  w,h,samps,height    : INTEGER;
  temp,d       : VecRecord;
  r1,r2,dx,dy  : real;
  cam,tempRay  : RayRecord;
  cx,cy: VecRecord;
  tColor,r: VecRecord;

  BMPClass:BMPIOClass;
  ScrWidth,ScrHeight:integer;
  vColor:rgbColor;
  FN:string;
  T1,T2:TDateTime;
  HH,MM,SS,MS:WORD;
  c:char;
  ArgFN:String;
  ArgInt:integer;
BEGIN
//DEBUG
  DF:=FALSE;
  DebugInt:=0;

  FN:=ExtractFileName(paramStr(0));
  Delete(FN,Length(FN)-3,4);
  FN:=FN+'.bmp';

  randomize;
  w:=320 ;h:=240;  samps := 16;

//----Scene Setup----
  InitScene;
  sph:=CopyScene(0);

  c:=#0;
  repeat
//    c:=getopt('osw:z:012');
    c:=getopt('m:o:s:w:');

    case c of
      'm' :BEGIN
        ArgInt:=StrToInt(OptArg);
        IF (ArgInt<MaxScName+1) and (ArgInt>-1) THEN BEGIN
          sph:=CopyScene(ArgInt);
          writeln('Model of Scene =',ArgInt);
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
      '?',':' : writeln ('Error with opt : ',optopt);
    end; { case }
  until c=endofoptions;

  BMPClass:=BMPIOClass.Create(w,h);


  cam.o:=CreateVec(50, 52, 295.6);  cam.d:=VecNorm(CreateVec(0,-0.042612,-1) );
  cx:=CreateVec(w * 0.5135 / h, 0, 0);
  cy:= cx/ cam.d;
  cy:=VecNorm(cy);
  cy:= cy* 0.5135;

  ScrWidth:=0;
  ScrHeight:=0;
  T1:=Time;
  Writeln ('The time is : ',TimeToStr(Time));

StartY:=60;
  FOR y :=0 TO h-1 DO BEGIN
DebugY:=y;
    IF y mod 10 =0 THEN writeln('y=',y);
    FOR x := 0 TO w - 1 DO BEGIN
DebugX:=X;
      FOR sy := 0 TO 1 DO BEGIN
        r:=CreateVec(0, 0, 0);
        tColor:=ZeroVec;
        FOR sx := 0 TO 1 DO BEGIN
          FOR s := 0 TO samps - 1 DO BEGIN
            r1 := 2 * random;
            IF (r1 < 1) THEN
              dx := sqrt(r1) - 1
            ELSE
              dx := 1 - sqrt(2 - r1);

            r2 := 2 * random;
            IF (r2 < 1) THEN
              dy := sqrt(r2) - 1
            ELSE
              dy := 1 - sqrt(2 - r2);
            temp:= cx* (((sx + 0.5 + dx) / 2 + x) / w - 0.5);
            d:= cy* (((sy + 0.5 + dy) / 2 + (h - y - 1)) / h - 0.5);
            d:= d +temp;
            d:= d +cam.d;

            d:=VecNorm(d);
            tempRay.o:= d* 140;
            tempRay.o:= tempRay.o+ cam.o;
            tempRay.d := d;

            temp:=Radiance(tempRay);
            temp:= temp/ samps;
            r:= r+temp;
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
  writeln('DebugInt=',DebugInt);
END.

pico-8 cartridge // http://www.pico-8.com
version 35
__lua__
page,src,nbpage,hit,tot=
 0,0,peek(0),0,0
--bench
ben,benx,beny={},{},{}
function init()
 cls()
 dtime=stat(1)
 unpack_gfx()
 dtime=stat(1)-dtime
 palt(0,false)
 srand(42)
 for i=1,32767 do
  add(ben,rnd(1024)\1)
  add(benx,rnd(121)\1)
  add(beny,rnd(121)\1)
 end
end
--[[
function _update()
 if (btnp(⬅️)) page-=1 redraw=true
 if (btnp(➡️)) page+=1 redraw=true
 page=mid(0,page,3)
 if redraw then
  if page==4 then
   gfx2spr(spr_title,0,0)
  else
   src=0x8000+page*8192
   memcpy(0x0,src,0x2000)
  end
  redraw=false
 end
end
]]--
--function _draw()
function draw()
 cls()
 color(1)
 spr(0,0,0,16,16)

 print(page.."/"..nbpage.." "..src,0,0)
 print(" "..dtime.." cpu")

end



function unpack_gfx()
 local off=1+nbpage*2
 --decomp pack1 to 0x8000
 --decomp pack2 to 0xa000
 --decomp pack3 to 0xc000
 --decomp pack4 to 0xe000
 for i=1,nbpage do
  px9_decomp(0,0,off,pget,pset)
  local addr=0x6000+i*0x2000
  memcpy(addr,0x6000,0x2000)
  local len=%(-1+i*2)
  off+=len 
 end
 --unpack gfx title
-- unpack_str_gfx(spr_title)
end

function unpack_str_gfx(img)
 px9_decomp(0,0,img.gfx,sget,sset)
 local w,h=img.w/2,img.h
 local len,raw=w*h,{}
 --
 for x=1,len,4 do
  local addr=x-1
  addr=addr%w+addr\w*64
  add(raw,peek4(addr))  
 end
 img.raw=raw
end

function gfx2spr(img,x,y)
 local w,raw,off=
  img.w/2,img.raw,x/2+y*64
 for i=1,#raw do
  local addr=i*4-4
  addr=addr%w+addr\w*64
  poke4(off+addr,raw[i])
 end
end


-- virt sprite
local vsprtbl,vsprq=
 {},{len=0}

function draw_vspr(nspr,x,y)
 local nxtspr
 --nspr in cache ?
 if vsprtbl[nspr]!=nil then
  --yes update age queue
--d  del(vsprq,nspr)
--d  add(vsprq,nspr)
  ldel(vsprq,nspr)--d
  laddlast(vsprq,nspr)--d
  nxtspr=vsprtbl[nspr]
  hit+=1
--debug  ?"update age queue"
 else
  nxtspr=vsprq.len--d
--d  nxtspr=#vsprq
	 --if vsprq full(length 8)
	 if nxtspr==256 then
	  --remove first
--d	  local o=deli(vsprq,1)
	  local o=vsprq.f--d
	  ldel(vsprq,o)--d
--	  print("del "..o)
	  nxtspr=vsprtbl[o]
	  vsprtbl[o]=nil
--debug   ?"remove first"
	 end
--d  add(vsprq,nspr)
  laddlast(vsprq,nspr)--d
  vsprtbl[nspr]=nxtspr
--debug  ?"add last"
  --copy 
  local dst,src=
   0x0000+(nxtspr\16)*512+nxtspr%16*4,
   0x8000+(nspr\16)*512+nspr%16*4
  for i=0,7 do
   memcpy(dst+i*64,src+i*64,4)
  end
 end
 --draw spr
 spr(nxtspr,x,y)
end


function ldel(tbl,ielt)
--debug print("del "..ielt)
 local o=tbl[ielt]
 if (o==nil) return
 --delete first ? update first
 if (tbl.f==ielt) tbl.f=o.n
 --delete last ? update last
 if (tbl.l==ielt) tbl.l=o.p
 --if prev, update prev.next
 if (o.p) tbl[o.p].n=o.n
 --if next, update next.prev
 if (o.n) tbl[o.n].p=o.p
 --as deleted,nomore prev or next
 o.p,o.n=nil,nil
 tbl.len-=1
end

function laddlast(tbl,ielt)
--debug print("add "..ielt)
 local l,f=tbl.l,tbl.f
 if (l) tbl[l].n=ielt--add next to last
 if (not f) tbl.f=ielt--init
 local o=tbl[ielt]
 if (o==nil) o={} tbl[ielt]=o
 o.p=l
 o.n=nil
 tbl.l=ielt
 tbl.len+=1
end

-->8
-- px9 decompress

-- x0,y0 where to draw to
-- src   compressed data address
-- vget  read function (x,y)
-- vset  write function (x,y,v)

function
    px9_decomp(x0,y0,src,vget,vset)

    local function vlist_val(l, val)
        -- find position and move
        -- to head of the list

--[ 2-3x faster than block below
        local v,i=l[1],1
        while v!=val do
            i+=1
            v,l[i]=l[i],v
        end
        l[1]=val
--]]

--[[ 7 tokens smaller than above
        for i,v in ipairs(l) do
            if v==val then
                add(l,deli(l,i),1)
                return
            end
        end
--]]
    end

    -- bit cache is between 8 and
    -- 15 bits long with the next
    -- bits in these positions:
    --   0b0000.12345678...
    -- (1 is the next bit in the
    --   stream, 2 is the next bit
    --   after that, etc.
    --  0 is a literal zero)
    local cache,cache_bits=0,0
local str=ord(src,8)--dho
local pos=str and 1 or src--dho
    function getval(bits)
        if cache_bits<8 then
            -- cache next 8 bits
            cache_bits+=8
            --cache+=@src>>cache_bits
            --src+=1
cache+=(str and ord(src,pos) or @pos)>>cache_bits --dho
pos+=1 --dho
        end

        -- shift requested bits up
        -- into the integer slots
        cache<<=bits
        local val=cache&0xffff
        -- remove the integer bits
        cache^^=val
        cache_bits-=bits
        return val
    end

    -- get number plus n
    function gnp(n)
        local bits=0
        repeat
            bits+=1
            local vv=getval(bits)
            n+=vv
        until vv<(1<<bits)-1
        return n
    end

    -- header

    local
        w,h_1,      -- w,h-1
        eb,el,pr,
        x,y,
        splen,
        predict
        =
        gnp"1",gnp"0",
        gnp"1",{},{},
        0,0,
        0
        --,nil

    for i=1,gnp"1" do
        add(el,getval(eb))
    end
    for y=y0,y0+h_1 do
        for x=x0,x0+w-1 do
            splen-=1

            if(splen<1) then
                splen,predict=gnp"1",not predict
            end

            local a=y>y0 and vget(x,y-1) or 0

            -- create vlist if needed
            local l=pr[a] or {unpack(el)}
            pr[a]=l

            -- grab index from stream
            -- iff predicted, always 1

            local v=l[predict and 1 or gnp"2"]

            -- update predictions
            vlist_val(l, v)
            vlist_val(el, v)

            -- set
            vset(x,y,v)
        end
    end
end
-->8
function bench()
 cls()
 local ctime=stat(1)
 for i=1,#ben do
  local nb=ben[i]
  local x=benx[i]
  local y=beny[i]
  draw_vspr(nb,x,y)
  tot+=1
 end
 ctime=stat(1)-ctime
 spr(0,0,64,16,4)
 spr(128,0,96,16,4)
 rectfill(0,81,127,92,0)
 print("ratio "..(hit/tot)..
  " time "..(ctime/30),0,81,7)
 print("vspr/sec "..(#ben/(ctime/30)))
end

function debug()
	cls() x=0
	seq={0,1,2,3,4,1,3,3,4,5}
	while tot<32678 do
	 rectfill(0,0,64,24,0)
  tot+=1
--	 nb=2*(rnd(5))\1+256
  nb=seq[tot]
 	print("nb "..nb.." next "..(seq[tot+1]or-1),0,0,2)
		draw_vspr(nb,x,32) x=(x+8)%128--0
--[[		draw_vspr(258,x,32) x+=8--1
		draw_vspr(260,x,32) x+=8--2
		draw_vspr(262,x,32) x+=8--3
		draw_vspr(264,x,32) x+=8--4
		draw_vspr(266,x,32) x+=8--5
		draw_vspr(264,x,32) x+=8--4
		draw_vspr(262,x,32) x+=8--3
		draw_vspr(260,x,32) x+=8--2
		draw_vspr(258,x,32) x+=8--1
	]]--
--d	 print(""..#vsprq,0,0,2)
	 print("tot "..tot)
	 spr(0,0,64,16,4)
	 --flip()
	
	 rectfill(0,96,127,127,0)
	 color(2)
	 print("len "..vsprq.len,0,96)
--d	 print(tbl2str(vsprq))
	 print("f "..vsprq.f.." ".." l "..vsprq.l)
	 print(llist2str(vsprq))
	 print(llist2str_rev(vsprq))
	 flip()
	 repeat until btnp(❎)
 end
end

function llist2str(tbl)
 local res=""
 if (tbl.f==tbl.l) return res
 local c=tbl.f
 repeat 
  res=res..c..","
  c=tbl[c].n
 until c==nil 
 
 return res
end
function llist2str_rev(tbl)
 local res=""
 if (tbl.f==tbl.l) return res
 local c=tbl.l
 repeat 
  res=c..","..res
  c=tbl[c].p
 until c==nil 
 
 return res
end
function tbl2str(tbl)
 local res=""
 for x in all(tbl) do
  res=res..x..","
 end
 return res
end

init()
bench()
--debug()
__gfx__
402680cea0cea0cea0ffff8ff7ffff78fd89920bce31cdef52f7ff81ffef92ad34ff199052f18e00ff14dd46f320f118f08a4899ff087aef300f781e44d32af1
c892ffcf78019c8f21745ef09efb3b2afaeed95778a0b3c229848e299432299c808337df83ceea93f3d7400bee3034aa02780301d1734fe770921ccf8ccf1eec
f02ef18ff8cd1e92af344ac1342f3aa88378ef33df12be12c2a32922a4930e21e8468829f8ff6e7005302c00071b22e740005ffd2ee77a720fae2ef5b02ae4bc
4ca49ee2d25e47fe7c06014ecf70007ace02e301d101a0c301c1a9bb1450f14c0248e924f72e129f61a3ce789e8c80f78bc1304fd9f3a284870dcfc68487f70f
29e79d16382a317040198a0e480df7ff1343cb72e0e45210e47aebe8d0e578ff4f76fccdcf90e36726f9ffdc7e0fe7a08f04d78be107c0f9ffdca6fdeff0ff6e
0adff44cf198ffc2f30ee73f1fcf161ff47ad13c2ef9bd5bf18e78703d3712ce42d3b872fc1612ef89ffe0f44ab4e02e0d774415cd82f3ffa9d0b2aa8378027c
7e74ff5f129c5dc1c11d1dccf3fff1493f0f0b8edfd93e3b7ef11eff0c84cf40706ef06cf1ffec41f74e785ef0ffaee90ff06c80e720c172ff74f3cbb4f0cf20
308e121cff4a1ff7b7fb71ff0ff08ece7c5fc3948c9bcad802c674ef93ece8f3ff9842d8a0899042423bffdf52e53189982241ffffc4f9b895e5d5261192ffcf
9fe1341f294c72968369adc3141affcf81c59af41c46700749486e211593f4c0f7000dcf1a2686e700cf80d7b0021742ae4c89a24f898288f344c901df312ff4
ac213a4a51a286313f641194ac4744df3ff198e44a3440b6a259d38a72802388cb7290548414e00b59e3c6fd02451688ce59220c47699c2192ce889ac1ad67f9
1aac5e1e44e5e0bc8e8287394529725e404ac1ac9abf6a410736382cc10969414e3e5401e798255219cf9152694231f12af75e880921f322213adf020201effc
cf9e06788e53f12f2134ff11ff496ef10bf3ff0df9ff6d49159f84ffff6842988f95f1ff1ff52d309ac534ffcfb0d6f865846e3d30494fff35380f5878056fbc
43f40248c44a5e03d3c3598f4c4e6f2a44840031bc02442f84585e304b40b8aee790f02dd1f9ce491b944e59e01971110078e9052027f92aef45d846e75229c7
2b742195acb532709e718b1b12af84ceee85f33055e954342b5d0b4eb04601e11de4942984e7b8144f6209eebc11f39080120d096819a447263c384f129f613a
dc25e72361e10178708e341545e7789e4519fe51360f295ae09cf0cf8ba2e79e9f04389d22f86ca13a21f19f07d651ffe824f1a4349ff38fd12efb1f3c1f706f
97b2ff97ff49ffff3ae81a9c1cafc420340f18fc330fd7f0c5947c5e7269b406699cc2699c96972b9337cffd0369d825463049ff90f2157cb883e5d1082035ba
a6b401c12f369ad9737272e8fb1e260001e0704e002242e8ab05df38ee7640a83712328ff9f3102d840c00b200002021bd07cfbd746de71231cf7803784e8240
00228200001b42070e884402132a75c1d5622bd4469992dc01cf000812009580a008239457c6441b80c94c6a3b23f7097c080f4095145908e09002545e17bfdd
1583e41e2e364fd3080794007098dee8ec97179f8c4e0e942cc130c07a01f1dbf1a9314af1199f75e075bdb4c6066145a994bf69f12d17b27d810b575c2bb401
6aee74b08fc9f9dde1344fcbd19c2780a31e82cfc1953c214513e0e01a9f34bdf8315f3936b9daf1880b3415184cf30ff1f27a8ecb8a194c8c482420027966cb
747080d3f3ef985383444b8812b191a3f44f4ef18f5de018352f599f7b210198ac8567f0d4e0108e93179fc3ff8c073e593f898084e7014f2bedb519f21e5c2b
8431ffa117c6a93c0a212cf9810ba19c8be62ee772ef632e949c1e1d862ed1418eeee54690ff98928f948b09198f84848e8ecfe07eb199c13c1ff39062e36907
546f743f74de651f42ae945c29e77a74cb94466d944a552e4acf1a129f8df72ee335512ac325e70fef84e778ff203227d32948c3441183f388e776ef331f2917
32bb428017208507e01216ccf3c174ef8ecfa3db7ca79590a2d446292d9dd1348935890642f98ff8a3f8ac4801fe121c9ce8e08cf0168c08effee737af2b9c6c
3a4ab49ae071c4ae64128a0c0ba1f159b6ac2f976117d5efe534bc89388824243400c727369a7a73757274ae959c02e04a29178b163ca45309e3e3b3a92f47f9
198fd98c6eb4316fe484f77676ffb03d1f88194e398ae70124012e743ef042f73eb31493e974478a57f221379f941f876e94c66baf7bac5bd5578d572fb23c9c
00cfc705614f09ae474f49ee138fb4422e4da350000071840065cb7f0464cfb700dec30d342c1fac731e429402db8400000070be8d709e0e30d8705ecc2e0ad9
e3c12e2d8a0000000067fe3a3fa3a3a1f0cd7df82227cfb208000000004039393e3e3e984c5e9f356f7b07e4e083bb94050000000093e0aff3333a3b79f1cd3b
3ad814c1240480009502c152c37054c360f3e973130c2364904ccd328b6ed3ff38c7c7c73731cf2263941c4cfacffcacf99bf4dfdf7de0fbf1d7f48ca4173398
f948f350f1a9f04ef18f3d38ff43f3ff3b5cb483d3f33f0acfecf04d1ffd708edd4293f5ff72ffbb7221072e969c01f74ef65cc3f331ffe0eec72edf11319384
f9c8e818f9f874787074ef344b3988a758e63d4ff4ce8ecfecf85c7c7848a36ec96679f8cf989f7bef84f70e19fde15809e781008024c920895813000000f778
8ec91f214238fbff5f7497d32c50b8c0000000e000000000000910109f2849defe2eb35c48ffef9bffd1dd42d2a89392a025495a92e4100c929e9fd9c1c12d57
f0ffaed9f1d8997ac57c631fd195828e4100100c08080000200180f0108fc942b2f86df1ff5df39f4878020a00e000000000000000708ff7ffdf92c00526090e
00802500000000f00fffff8f54ffacf7ff85d1c1f14243f3ff0c07969f728c0084a42ae00ef0ffbe304b0cffff8ff7ffff78fd7a98a1b2c3d4e5f6004cc446c1
029ca4499aa4499cc009980ce480499a84c9402e0228020898c0098a00020008200022255a13c024020008a0e010ac34424293785092a425498a0888088e8e58
92e4e8e8c2500bf12b85440b8a2a3a1b201f30496884466884078846050d140adf0d24027853c145444cc4b005d254514145453422002420f1ade00101073841
2028025100fffc948790061424a0455aa4924241296144c288924241292142489812e4e8e0f8ffefea3236021e60a4455aa4456a844648e42007445aa4440e72
1140114040844658041000400001102159928826110040000507e025911212cc8392a425495a44404470744492a447471706d208df292c52585451d1887188c1
4a23344223344834226828d070ee281140938a2e2a622206a518a6828a2a2a2a9101200101ef0d07083848810a4111008a70efa7b40cb420a001255aa2159402
4a092b12461494024a0919424294a0470747f7ff9f9aa5599225997080220731285aa205899888c94c6e7213936100c20002000880499a443048100504100005
4c024c02020828208080f77e041000f12a1219e0908831119c1d9016901626848429215242a4e79e1225151dff021e7080831405000440128807499aa4a2828a
ff0d47071248f348c1028ec1306f4c7020008c6844600943c847172124440919424294101dac17944c4294902126c221c221838a2e52a235383affffdaa44d9a
a4498c83143108c9519225484cc4446e721393988c0b100610004000445aa402c102a0280080206812601210404001010434ffa3008000df11c08807c40489e8
e488b480b4b021244409199222357f94a029e8f89f708083142ca008200012c034485aa415155474ef383a18c012cf021e70040ef16b0283016044230243184a
363a882921424898122284e0e835a8e4122284843911061906195c74119225c9d1f1ffcf17887e91708023255aa2255a2334422207312852a225721083880288
02223442a200800002000880499ac4340188000220380827099c90e0161ca425495aa2022202a3a312a4353a3ab810c670ce6911c2a2828ace04cb045e122991
1229c1229141430186f347018812dc7451111331204db01554545151018c080108786f384840c1025c000a885004f33f2de52085010528599225a89450425819
b022a09450424898122284353a383affffea1bd13e021e60a4455aa4456a844648e42007445aa4440e7211401140408446580410004000011021599288261100
40000507e025911212cc8392a425495a44404470744492a447471706d208df292c52585451d1887188c14a23344223344834226828d070ee281140938a2e2a62
2206a518a6828a2a2a2a9101200101ef0d07083848810a4111008a70efa7b40cb420a001255aa21594024a092b12461494024a0919424294a0470747f7ff9f9a
a5599225997080220731285aa205899888c94c6e7213936100c20002000880499a4430481005041000054c024c02020828208080f77e041000f12a1219e09088
31119c1d9016901626848429215242a4e79e1225151dff021e7080831405000440128807499aa4a2828aff0d47071248f348c1028ec1306f4c7020008c684460
0943c847172124440919424294101dac17944c4294902126c221c221838a2e52a235383affffdaa44d9aa4498c83143108c9519225484cc4446e721393988c0b
100610004000445aa402c102a0280080206812601210404001010434ffa3008000df11c08807c40489e8e488b480b4b021244409199222357f94a029e8f89f70
8083142ca008200012c034485aa415155474ef383a18c012cf021e70040ef16b0283016044230243184a363a882921424898122284e0e835a8e4122284843911
061906195c74119225c9d1f1ffcf97887f91708023255aa2255a2334422207312852a22572108388028802223442a200800002000880499ac434018800022038
0827099c90e0161ca425495aa2022202a3a312a4353a3ab810c670ce6911c2a2828ace04cb045e1229911229c1229141430186f347018812dc7451111331204d
b01554545151018c080108786f384840c1025c000a885004f33f2de52085010528599225a89450425819b022a09450424898122284353a383afffffa1bf16823
e001465aa4455aa4466884440e7240a4454ae4201701140104446884450001000410001192258968120100045070005e122921c13c28495a92a4450444044747
24497a747461208df09dc222854515158d188718ac34422334428344238286020de78e120134a9e8a2222662508a612aa8a8a2a21219001210f0de7080808314
a8101401a008f77e4acb400b021a50a2255a4129a094b02261444129a09490212444097a747074ffffa9599a255992090728721083a2255a90888998cce42637
311906200c2000800098a4490483045140000150c024c02420808002020878ef47000110af2291010e891813c1d90169016961424898122225447aee295152d1
f12fe0010738485100400024817890a4492a2aa8f8df70742081348f142ce0180cf3c6040702c08846049630847c74114242949021244409d1c17a41c9244409
1962221c221c32a8e822255a83a3f3ffaf4ddaa4499ac438481183901c255982c4444ce426373189c9b800610001000440a4452a102c008a0200088226012601
010414104040f33f0a0008f01d018c78404c90884e8e480b480b1b42429490212952f347099a828eff09073848c1028a000220014c83a4455a514145f78ea383
012cf12ce00147e010bf263018004634223084a164a3839812228484292142088e5e834a2e214248981361906190c145172159921c1dffff7c3e88cf1b090738
52a2255aa23542232472108322255a22073188288028204223240a00082000800098a4494c138008200082837092c009096ec1415a92a4252a2022303a2a415a
a3a3830b610ce79c16212c2aa8e84cb04ce02591122991122c1219341460387f148028c14d1715311103d2045b4145151515c088108080f7868304142cc005a0
80084530ffd3520e52185080922559824a09258495012b024a0925848429214258a383a3f3ffafcf1f93cff31323e8d23bd2f22129daf26139c2635b220fa34b
42a5e55242e5706b48fba9a08b1021a1c5a200a00e850530aa61545a59c0340444002126aca003070b9c90e014a8858424692111011124d1d1016a4293a3680b
6125f12b85b49221aab8d2c9ac71a8c14a6359233c963558342268280f3a7f148088e0a683aa9858b522b04548aa2a2a271115c009200141ef09175658c1b566
8201495420bd06fffcb4869515a0822b495996561b412b105c4a2b1a15659246309894228ca3d252a383a378ffffc5258b5aa4456a142c80c9400e9aa4496222
2672139398cce45408b0008000022052a215001e00450100044113801380800202082820f19f0d0004708e8846342826404c2747248524858529214248989421
f9ab84454947f78c83142ce001450001108026c152a225a8a8a2f34fd1c18016f01e7080a37000df1b100c08231219104ad032d1c14409194242949021044727
c925179021244489b840b840e8a28398a4490e8effffbea8e57340bab45c4aac832b8ccbe0da906579b884c5e4d621f2e35a40cb8f4911862035614100ae5819
961565029174124000c31a065c855202020e10107000e1f9ad00800e951eac1a5910948804422725096941858529e0b894221d1c86f9ab8c95a23a3aef155c6b
073a5851004007c2488301bcb4d29854550e7576cf57c0128acfe40917d6d930c8f1ea8202496bc48a0488d0226164a38398028e4b29c2382a2de0ec71a89592
21540987a5a40b22a2227551b4446959463b388af7ff8effff8ff7ffff78fd1af0a9b2c3d4e5f6004cc446c1029ca4499aa4499cc009980ce480499a84c9402e
0228020898c0098a00020008200022255a13c024020008a0e010ac34424293785092a425498a0888088e8e5892e4e8e8c2500bf12b85440b8a2a3a1b201f3049
6884466884078846050d140adf0d24027853c145444cc4b005d254514145453422002420f1ade001010738412028025100fffc948790061424a0455aa4924241
296144c288924241292142489812e4e8e0f8ffefea3236021e60a4455aa4456a844648e42007445aa4440e721140114040844658041000400001102159928826
110040000507e025911212cc8392a425495a44404470744492a447471706d208df292c52585451d1887188c14a23344223344834226828d070ee281140938a2e
2a622206a518a6828a2a2a2a9101200101ef0d07083848810a4111008a70efa7b40cb420a001255aa21594024a092b12461494024a0919424294a0470747f7ff
9f9aa5599225997080220731285aa205899888c94c6e7213936100c20002000880499a4430481005041000054c024c02020828208080f77e041000f12a1219e0
908831119c1d9016901626848429215242a4e79e1225151dff021e7080831405000440128807499aa4a2828aff0d47071248f348c1028ec1306f4c7020008c68
44600943c847172124440919424294101dac17944c4294902126c221c221838a2e52a235383affffdaa44d9aa4498c83143108c9519225484cc4446e72139398
8c0b100610004000445aa402c102a0280080206812601210404001010434ffa3008000df11c08807c40489e8e488b480b4b021244409199222357f94a029e8f8
9f708083142ca008200012c034485aa415155474ef383a18c012cf021e70040ef16b0283016044230243184a363a882921424898122284e0e835a8e412228484
3911061906195c74119225c9d1f1ffcf17887e91708023255aa2255a2334422207312852a22572108388028802223442a200800002000880499ac43401880002
20380827099c90e0161ca425495aa2022202a3a312a4353a3ab810c670ce6911c2a2828ace04cb045e1229911229c1229141430186f347018812dc7451111331
204db01554545151018c080108786f384840c1025c000a885004f33f2de52085010528599225a89450425819b022a09450424898122284353a383affffea1bd1
3e021e60a4455aa4456a844648e42007445aa4440e721140114040844658041000400001102159928826110040000507e025911212cc8392a425495a44404470
744492a447471706d208df292c52585451d1887188c14a23344223344834226828d070ee281140938a2e2a622206a518a6828a2a2a2a9101200101ef0d070838
48810a4111008a70efa7b40cb420a001255aa21594024a092b12461494024a0919424294a0470747f7ff9f9aa5599225997080220731285aa205899888c94c6e
7213936100c20002000880499a4430481005041000054c024c02020828208080f77e041000f12a1219e0908831119c1d9016901626848429215242a4e79e1225
151dff021e7080831405000440128807499aa4a2828aff0d47071248f348c1028ec1306f4c7020008c6844600943c847172124440919424294101dac17944c42
94902126c221c221838a2e52a235383affffdaa44d9aa4498c83143108c9519225484cc4446e721393988c0b100610004000445aa402c102a028008020681260
1210404001010434ffa3008000df11c08807c40489e8e488b480b4b021244409199222357f94a029e8f89f708083142ca008200012c034485aa415155474ef38
3a18c012cf021e70040ef16b0283016044230243184a363a882921424898122284e0e835a8e4122284843911061906195c74119225c9d1f1ffcf97887f917080
23255aa2255a2334422207312852a22572108388028802223442a200800002000880499ac4340188000220380827099c90e0161ca425495aa2022202a3a312a4
353a3ab810c670ce6911c2a2828ace04cb045e1229911229c1229141430186f347018812dc7451111331204db01554545151018c080108786f384840c1025c00
0a885004f33f2de52085010528599225a89450425819b022a09450424898122284353a383afffffa1bf16823e001465aa4455aa4466884440e7240a4454ae420
1701140104446884450001000410001192258968120100045070005e122921c13c28495a92a445044404474724497a747461208df09dc222854515158d188718
ac34422334428344238286020de78e120134a9e8a2222662508a612aa8a8a2a21219001210f0de7080808314a8101401a008f77e4acb400b021a50a2255a4129
a094b02261444129a09490212444097a747074ffffa9599a255992090728721083a2255a90888998cce42637311906200c2000800098a4490483045140000150
c024c02420808002020878ef47000110af2291010e891813c1d90169016961424898122225447aee295152d1f12fe0010738485100400024817890a4492a2aa8
f8df70742081348f142ce0180cf3c6040702c08846049630847c74114242949021244409d1c17a41c92444091962221c221c32a8e822255a83a3f3ffaf4ddaa4
499ac438481183901c255982c4444ce426373189c9b800610001000440a4452a102c008a0200088226012601010414104040f33f0a0008f01d018c78404c9088
4e8e480b480b1b42429490212952f347099a828eff09073848c1028a000220014c83a4455a514145f78ea383012cf12ce00147e010bf263018004634223084a1
64a3839812228484292142088e5e834a2e214248981361906190c145172159921c1dffff7c3e88cf1b09073852a2255aa23542232472108322255a2207318828
8028204223240a00082000800098a4494c138008200082837092c009096ec1415a92a4252a2022303a2a415aa3a3830b610ce79c16212c2aa8e84cb04ce02591
122991122c1219341460387f148028c14d1715311103d2045b4145151515c088108080f7868304142cc005a080084530ffd3520e52185080922559824a092584
95012b024a0925848429214258a383a3f3ffafcf1f93cff31323e8d23bd2f22129daf26139c2635b220fa34b42a5e55242e5706b48fba9a08b1021a1c5a200a0
0e850530aa61545a59c0340444002126aca003070b9c90e014a8858424692111011124d1d1016a4293a3680b6125f12b85b49221aab8d2c9ac71a8c14a635923
3c963558342268280f3a7f148088e0a683aa9858b522b04548aa2a2a271115c009200141ef09175658c1b5668201495420bd06fffcb4869515a0822b49599656
1b412b105c4a2b1a15659246309894228ca3d252a383a378ffffc5258b5aa4456a142c80c9400e9aa44962222672139398cce45408b0008000022052a215001e
00450100044113801380800202082820f19f0d0004708e8846342826404c2747248524858529214248989421f9ab84454947f78c83142ce001450001108026c1
52a225a8a8a2f34fd1c18016f01e7080a37000df1b100c08231219104ad032d1c14409194242949021044727c925179021244489b840b840e8a28398a4490e8e
ffffbea8e57340bab45c4aac832b8ccbe0da906579b884c5e4d621f2e35a40cb8f4911862035614100ae5819961565029174124000c31a065c855202020e1010
7000e1f9ad00800e951eac1a5910948804422725096941858529e0b894221d1c86f9ab8c95a23a3aef155c6b073a5851004007c2488301bcb4d29854550e7576
cf57c0128acfe40917d6d930c8f1ea8202496bc48a0488d0226164a38398028e4b29c2382a2de0ec71a8959221540987a5a40b22a2227551b4446959463b388a
f7ff8effff8ff7ffff78fd1af829b2c3d4e5f6004cc446c1029ca4499aa4499cc009980ce480499a84c9402e0228020898c0098a00020008200022255a13c024
020008a0e010ac34424293785092a425498a0888088e8e5892e4e8e8c2500bf12b85440b8a2a3a1b201f30496884466884078846050d140adf0d24027853c145
444cc4b005d254514145453422002420f1ade001010738412028025100fffc948790061424a0455aa4924241296144c288924241292142489812e4e8e0f8ffef
ea3236021e60a4455aa4456a844648e42007445aa4440e721140114040844658041000400001102159928826110040000507e025911212cc8392a425495a4440
4470744492a447471706d208df292c52585451d1887188c14a23344223344834226828d070ee281140938a2e2a622206a518a6828a2a2a2a9101200101ef0d07
083848810a4111008a70efa7b40cb420a001255aa21594024a092b12461494024a0919424294a0470747f7ff9f9aa5599225997080220731285aa205899888c9
4c6e7213936100c20002000880499a4430481005041000054c024c02020828208080f77e041000f12a1219e0908831119c1d9016901626848429215242a4e79e
__map__
215251d1ff20e1070838415000400421887094a94a2a28a8ffd0747021843f841c20e81c03f6c4070200c886440690348c7471124244909124244901d1ca7149c424490912622c122c1238a8e2252a5383a3ffffad4ad4a94a94c8384113809c15295284c44c44e627313989c8b001600100040044a54a201c200a8200080286
21062101040410104043ff3a000800fd110c88704c40988e4e884b084b0b1242449091292253f7490a928e8ff907083841c20a800200210c4384a54a51514547fe83a3810c21fc20e10740e01fb6203810064432203481a463a38892122484892122480e8e538a4e21224848931160916091c5471129529c1d1ffffc7188e719
07083252a52a52a532432422701382252a52270138882088202243242a0008002000800894a94c43108800200283807290c9090e61c14a5294a52a2022203a3a214a53a3a38b016c07ec96112c2a28a8ec40bc40e521921921921c2219143410683f74108821cd471511311302d40b514545151510c880108087f68384041c20
c500a08805403ff3d25e02581050829529528a49052485910b220a490524848921224853a383a3ffffaeb11de320e1064a54a54a54a64864844e027044a54a44e02711041104044864854001000400100112952988621100040050700e52192121cc38294a5294a5440444074744294a747471602d80fd92c2258545151d8817
881ca4324324324384432286820d07ee82110439a8e2a22622605a816a28a8a2a2a21910021010fed07080838418a0141100a807fe7a4bc04b020a1052a52a514920a490b22164414920a490912424490a7470747ffff9a95a95295299070822701382a52a509889889cc4e627313916002c002000800894a944038401504001
0050c420c4202080820208087fe74001001fa221910e09881311c9d109610961624848921225244a7ee9215251d1ff20e1070838415000400421887094a94a2a28a8ffd0747021843f841c20e81c03f6c4070200c886440690348c7471124244909124244901d1ca7149c424490912622c122c1238a8e2252a5383a3ffffad4a
d4a94a94c8384113809c15295284c44c44e627313989c8b001600100040044a54a201c200a820008028621062101040410104043ff3a000800fd110c88704c40988e4e884b084b0b1242449091292253f7490a928e8ff907083841c20a800200210c4384a54a51514547fe83a3810c21fc20e10740e01fb62038100644322034
81a463a38892122484892122480e8e538a4e21224848931160916091c5471129529c1d1ffffc7988f71907083252a52a52a532432422701382252a52270138882088202243242a0008002000800894a94c43108800200283807290c9090e61c14a5294a52a2022203a3a214a53a3a38b016c07ec96112c2a28a8ec40bc40e521
921921921c2219143410683f74108821cd471511311302d40b514545151510c880108087f68384041c20c500a08805403ff3d25e02581050829529528a49052485910b220a490524848921224853a383a3ffffafb11f86320e1064a54a54a54a64864844e027044a54a44e027110411040448648540010004001001129529886
21100040050700e52192121cc38294a5294a5440444074744294a747471602d80fd92c2258545151d8817881ca4324324324384432286820d07ee82110439a8e2a22622605a816a28a8a2a2a21910021010fed07080838418a0141100a807fe7a4bc04b020a1052a52a514920a490b22164414920a490912424490a7470747ff
ff9a95a95295299070822701382a52a509889889cc4e627313916002c002000800894a9440384015040010050c420c4202080820208087fe74001001fa221910e09881311c9d109610961624848921225244a7ee9215251d1ff20e1070838415000400421887094a94a2a28a8ffd0747021843f841c20e81c03f6c4070200c88
6440690348c7471124244909124244901d1ca7149c424490912622c122c1238a8e2252a5383a3ffffad4ad4a94a94c8384113809c15295284c44c44e627313989c8b001600100040044a54a201c200a820008028621062101040410104043ff3a000800fd110c88704c40988e4e884b084b0b1242449091292253f7490a928e8
ff907083841c20a800200210c4384a54a51514547fe83a3810c21fc20e10740e01fb6203810064432203481a463a38892122484892122480e8e538a4e21224848931160916091c5471129529c1d1ffffc7e388fcb1907083252a52a52a532432422701382252a52270138882088202243242a0008002000800894a94c4310880
0200283807290c9090e61c14a5294a52a2022203a3a214a53a3a38b016c07ec96112c2a28a8ec40bc40e521921921921c2219143410683f74108821cd471511311302d40b514545151510c880108087f68384041c20c500a08805403ff3d25e02581050829529528a49052485910b220a490524848921224853a383a3ffffafc
f139fc3f31328e2db32d2f1292ad2f16932c36b522f03ab4245a5e25245e07b684bf9a0ab801121a5c2a000ae0585003aa1645a5950c434044001262ca0a3070b0c9090e418a5848429612111011421d1d10a624393a86b016521fb2584b2912aa8b2d9cca178a1ca4369532c369538543228682f0a3f74108880e6a38aa8985
5b220b5484aaa2a27211510c90021014fe907165851c5b662810944502db60ffcf4b6859510a28b294956965b114b201c5a4b2a15156296403894922c83a2d253a383a87ffff5c52b8a54a54a641c2089c04e0a94a9426226227313989cc4e45800b0008002002252a5100e1005410004014310831080820208082021ff9d000
4007e8886443826204c472744258425858921224848949129fba485494747fc83841c20e105400100108621c252a528a8a2a3ff41d1c08610fe107083a0700fdb101c08032219101a40d231d1c44909124244909124074729c527109124244988b048b048e2a38894a94e0e8ffffeb8a5e3704ab4bc5a4ca38b2c8bc0ead0956
978b485c4e6d122f3ea504bcf89411680253161400ea85916951562019472104003ca160c558252020e0010107001e9fda0008e059e1caa195014988402472529096145858920e8b4922d1c1689fbac8592aa3a3fe51c5b670a385150004702c843810cb4b2d894555e05767fc750c21a8fc4e90716d9d038c1fae282094b64c
a840880d2216463a388920e8b4922c83a2d20ece178a5929124590785a4ab0222a2257154b44969564b383a87fffe8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

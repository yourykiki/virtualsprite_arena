pico-8 cartridge // http://www.pico-8.com
version 35
__lua__
function _init()

    -- test: compress from
    -- spritesheet to map, and
    -- then decomp back to screen

    cls()
    print("compressing..",5)
    flip()

    w=128 h=128
    raw_size=(w*h+1)\2 -- bytes

    ctime=stat(1)

    -- compress spritesheet to map
    -- area (0x2000) and save cart

    clen = px9_comp(
        0,0,
        w,h,
        0x2000,
        sget)

    ctime=stat(1)-ctime

    --cstore() -- save to cart

    -- show compression stats
    print("                 "..(ctime/30).." seconds",0,0)
    print("")
    print("compressed spritesheet to map",6)
    ratio=tostr(clen/raw_size*100)
    print("bytes: "
        ..clen.." / "..raw_size
        .." ("..sub(ratio,1,4).."%)"
        ,12)
    print("")
    print("press ❎ to decompress",14)

    memcpy(0x7000,0x2000,0x1000)

    -- wait for user
    repeat until btn(❎)

    print("")
    print("decompressing..",5)
    flip()

    -- save stats screen
    local cx,cy=cursor()
    local sdata={}
    for a=0x6000,0x7ffc do
        sdata[a]=peek4(a)
    end

    dtime=stat(1)

    -- decompress data from map
    -- (0x2000) to screen

    px9_decomp(0,0,0x2000,pget,pset)

    dtime=stat(1)-dtime

    -- wait for user
    repeat until btn(❎)

    -- restore stats screen
    for a,v in pairs(sdata) do
        poke4(a,v)
    end

    -- add decompression stats
    print("                 "..(dtime/30).." seconds",cx,cy-6,5)
    print("")

end

-->8
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
    function getval(bits)
        if cache_bits<8 then
            -- cache next 8 bits
            cache_bits+=8
            cache+=@src>>cache_bits
            src+=1
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
-- px9 compress

-- x0,y0 where to read from
-- w,h   image width,height
-- dest  address to store
-- vget  read function (x,y)

function
    px9_comp(x0,y0,w,h,dest,vget)

    local dest0=dest
    local bit=1
    local byte=0

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
        return i
--]]

--[[ 8 tokens smaller than above
        for i,v in ipairs(l) do
            if v==val then
                add(l,deli(l,i),1)
                return i
            end
        end
--]]
    end

    local cache,cache_bits=0,0
    function putbit(bval)
     cache=cache<<1|bval
     cache_bits+=1
        if cache_bits==8 then
            poke(dest,cache)
            dest+=1
            cache,cache_bits=0,0
        end
    end

    function putval(val, bits)
        for i=bits-1,0,-1 do
            putbit(val>>i&1)
        end
    end

    function putnum(val)
        local bits = 0
        repeat
            bits += 1
            local mx=(1<<bits)-1
            local vv=min(val,mx)
            putval(vv,bits)
            val -= vv
        until vv<mx
    end


    -- first_used

    local el={}
    local found={}
    local highest=0
    for y=y0,y0+h-1 do
        for x=x0,x0+w-1 do
            c=vget(x,y)
            if not found[c] then
                found[c]=true
                add(el,c)
                highest=max(highest,c)
            end
        end
    end

    -- header

    local bits=1
    while highest >= 1<<bits do
        bits+=1
    end

    putnum(w-1)
    putnum(h-1)
    putnum(bits-1)
    putnum(#el-1)
    for i=1,#el do
        putval(el[i],bits)
    end


    -- data

    local pr={} -- predictions

    local dat={}

    for y=y0,y0+h-1 do
        for x=x0,x0+w-1 do
            local v=vget(x,y)

            local a=y>y0 and vget(x,y-1) or 0

            -- create vlist if needed
            local l=pr[a] or {unpack(el)}
            pr[a]=l

            -- add to vlist
            add(dat,vlist_val(l,v))
           
            -- and to running list
            vlist_val(el, v)
        end
    end

    -- write
    -- store bit-0 as runtime len
    -- start of each run

    local nopredict
    local pos=1

    while pos <= #dat do
        -- count length
        local pos0=pos

        if nopredict then
            while dat[pos]!=1 and pos<=#dat do
                pos+=1
            end
        else
            while dat[pos]==1 and pos<=#dat do
                pos+=1
            end
        end

        local splen = pos-pos0
        putnum(splen-1)

        if nopredict then
            -- values will all be >= 2
            while pos0 < pos do
                putnum(dat[pos0]-2)
                pos0+=1
            end
        end

        nopredict=not nopredict
    end

    if cache_bits>0 then
        -- flush
        poke(dest,cache<<8-cache_bits)
        dest+=1
    end

    return dest-dest0
end

__gfx__
f11111fff22222fffff11ffffff22fffff1111ffff2222ffff1111ffff2222fffff111fffff222fff111111ff222222fff1111ffff2222fff111111ff222222f
11fff11f22fff22fff111fffff222ffff11ff11ff22ff22ff11ff11ff22ff22fff1111ffff2222fff11fff1ff22fff2ff11ff11ff22ff22ff11ff11ff22ff22f
11ff111f22ff222ffff11ffffff22ffffffff11ffffff22ffffff11ffffff22ff11f11fff22f22fff11ffffff22ffffff11ffffff22ffffffffff11ffffff22f
11f1f11f22f2f22ffff11ffffff22fffff1111ffff2222fffff111fffff222ff11ff11ff22ff22fff11111fff22222fff11111fff22222ffffff11ffffff22ff
111ff11f222ff22ffff11ffffff22ffff11ffffff22ffffffffff11ffffff22f1111111f2222222ffffff11ffffff22ff11ff11ff22ff22ffff11ffffff22fff
11fff11f22fff22ffff11ffffff22ffff11ff11ff22ff22ff11ff11ff22ff22fffff11ffffff22fff11ff11ff22ff22ff11ff11ff22ff22ffff11ffffff22fff
f11111fff22222fff111111ff222222ff111111ff222222fff1111ffff2222fffff1111ffff2222fff1111ffff2222ffff1111ffff2222fffff11ffffff22fff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
f33333fff44444fffff33ffffff44fffff3333ffff4444ffff3333ffff4444fffff333fffff444fff333333ff444444fff3333ffff4444fff333333ff444444f
33fff33f44fff44fff333fffff444ffff33ff33ff44ff44ff33ff33ff44ff44fff3333ffff4444fff33fff3ff44fff4ff33ff33ff44ff44ff33ff33ff44ff44f
33ff333f44ff444ffff33ffffff44ffffffff33ffffff44ffffff33ffffff44ff33f33fff44f44fff33ffffff44ffffff33ffffff44ffffffffff33ffffff44f
33f3f33f44f4f44ffff33ffffff44fffff3333ffff4444fffff333fffff444ff33ff33ff44ff44fff33333fff44444fff33333fff44444ffffff33ffffff44ff
333ff33f444ff44ffff33ffffff44ffff33ffffff44ffffffffff33ffffff44f3333333f4444444ffffff33ffffff44ff33ff33ff44ff44ffff33ffffff44fff
33fff33f44fff44ffff33ffffff44ffff33ff33ff44ff44ff33ff33ff44ff44fffff33ffffff44fff33ff33ff44ff44ff33ff33ff44ff44ffff33ffffff44fff
f33333fff44444fff333333ff444444ff333333ff444444fff3333ffff4444fffff3333ffff4444fff3333ffff4444ffff3333ffff4444fffff33ffffff44fff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ff1111ffff2222ffff1111ffff2222fffff11ffffff22fff111111ff222222ffff1111ffff2222ff11111fff22222fff1111111f2222222f1111111f2222222f
f11ff11ff22ff22ff11ff11ff22ff22fff1111ffff2222fff11ff11ff22ff22ff11ff11ff22ff22ff11f11fff22f22fff11fff1ff22fff2ff11fff1ff22fff2f
f11ff11ff22ff22ff11ff11ff22ff22ff11ff11ff22ff22ff11ff11ff22ff22f11ffffff22fffffff11ff11ff22ff22ff11ffffff22ffffff11f1ffff22f2fff
ff1111ffff2222ffff11111fff22222ff11ff11ff22ff22ff11111fff22222ff11ffffff22fffffff11ff11ff22ff22ff1111ffff2222ffff1111ffff2222fff
f11ff11ff22ff22ffffff11ffffff22ff111111ff222222ff11ff11ff22ff22f11ffffff22fffffff11ff11ff22ff22ff11ffffff22ffffff11f1ffff22f2fff
f11ff11ff22ff22ff11ff11ff22ff22ff11ff11ff22ff22ff11ff11ff22ff22ff11ff11ff22ff22ff11f11fff22f22fff11fff1ff22fff2ff11ffffff22fffff
ff1111ffff2222ffff1111ffff2222fff11ff11ff22ff22f111111ff222222ffff1111ffff2222ff11111fff22222fff1111111f2222222f1111ffff2222ffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ff3333ffff4444ffff3333ffff4444fffff33ffffff44fff333333ff444444ffff3333ffff4444ff33333fff44444fff3333333f4444444f3333333f4444444f
f33ff33ff44ff44ff33ff33ff44ff44fff3333ffff4444fff33ff33ff44ff44ff33ff33ff44ff44ff33f33fff44f44fff33fff3ff44fff4ff33fff3ff44fff4f
f33ff33ff44ff44ff33ff33ff44ff44ff33ff33ff44ff44ff33ff33ff44ff44f33ffffff44fffffff33ff33ff44ff44ff33ffffff44ffffff33f3ffff44f4fff
ff3333ffff4444ffff33333fff44444ff33ff33ff44ff44ff33333fff44444ff33ffffff44fffffff33ff33ff44ff44ff3333ffff4444ffff3333ffff4444fff
f33ff33ff44ff44ffffff33ffffff44ff333333ff444444ff33ff33ff44ff44f33ffffff44fffffff33ff33ff44ff44ff33ffffff44ffffff33f3ffff44f4fff
f33ff33ff44ff44ff33ff33ff44ff44ff33ff33ff44ff44ff33ff33ff44ff44ff33ff33ff44ff44ff33f33fff44f44fff33fff3ff44fff4ff33ffffff44fffff
ff3333ffff4444ffff3333ffff4444fff33ff33ff44ff44f333333ff444444ffff3333ffff4444ff33333fff44444fff3333333f4444444f3333ffff4444ffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
f55555fff66666fffff55ffffff66fffff5555ffff6666ffff5555ffff6666fffff555fffff666fff555555ff666666fff5555ffff6666fff555555ff666666f
55fff55f66fff66fff555fffff666ffff55ff55ff66ff66ff55ff55ff66ff66fff5555ffff6666fff55fff5ff66fff6ff55ff55ff66ff66ff55ff55ff66ff66f
55ff555f66ff666ffff55ffffff66ffffffff55ffffff66ffffff55ffffff66ff55f55fff66f66fff55ffffff66ffffff55ffffff66ffffffffff55ffffff66f
55f5f55f66f6f66ffff55ffffff66fffff5555ffff6666fffff555fffff666ff55ff55ff66ff66fff55555fff66666fff55555fff66666ffffff55ffffff66ff
555ff55f666ff66ffff55ffffff66ffff55ffffff66ffffffffff55ffffff66f5555555f6666666ffffff55ffffff66ff55ff55ff66ff66ffff55ffffff66fff
55fff55f66fff66ffff55ffffff66ffff55ff55ff66ff66ff55ff55ff66ff66fffff55ffffff66fff55ff55ff66ff66ff55ff55ff66ff66ffff55ffffff66fff
f55555fff66666fff555555ff666666ff555555ff666666fff5555ffff6666fffff5555ffff6666fff5555ffff6666ffff5555ffff6666fffff55ffffff66fff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
f77777fff88888fffff77ffffff88fffff7777ffff8888ffff7777ffff8888fffff777fffff888fff777777ff888888fff7777ffff8888fff777777ff888888f
77fff77f88fff88fff777fffff888ffff77ff77ff88ff88ff77ff77ff88ff88fff7777ffff8888fff77fff7ff88fff8ff77ff77ff88ff88ff77ff77ff88ff88f
77ff777f88ff888ffff77ffffff88ffffffff77ffffff88ffffff77ffffff88ff77f77fff88f88fff77ffffff88ffffff77ffffff88ffffffffff77ffffff88f
77f7f77f88f8f88ffff77ffffff88fffff7777ffff8888fffff777fffff888ff77ff77ff88ff88fff77777fff88888fff77777fff88888ffffff77ffffff88ff
777ff77f888ff88ffff77ffffff88ffff77ffffff88ffffffffff77ffffff88f7777777f8888888ffffff77ffffff88ff77ff77ff88ff88ffff77ffffff88fff
77fff77f88fff88ffff77ffffff88ffff77ff77ff88ff88ff77ff77ff88ff88fffff77ffffff88fff77ff77ff88ff88ff77ff77ff88ff88ffff77ffffff88fff
f77777fff88888fff777777ff888888ff777777ff888888fff7777ffff8888fffff7777ffff8888fff7777ffff8888ffff7777ffff8888fffff77ffffff88fff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ff5555ffff6666ffff5555ffff6666fffff55ffffff66fff555555ff666666ffff5555ffff6666ff55555fff66666fff5555555f6666666f5555555f6666666f
f55ff55ff66ff66ff55ff55ff66ff66fff5555ffff6666fff55ff55ff66ff66ff55ff55ff66ff66ff55f55fff66f66fff55fff5ff66fff6ff55fff5ff66fff6f
f55ff55ff66ff66ff55ff55ff66ff66ff55ff55ff66ff66ff55ff55ff66ff66f55ffffff66fffffff55ff55ff66ff66ff55ffffff66ffffff55f5ffff66f6fff
ff5555ffff6666ffff55555fff66666ff55ff55ff66ff66ff55555fff66666ff55ffffff66fffffff55ff55ff66ff66ff5555ffff6666ffff5555ffff6666fff
f55ff55ff66ff66ffffff55ffffff66ff555555ff666666ff55ff55ff66ff66f55ffffff66fffffff55ff55ff66ff66ff55ffffff66ffffff55f5ffff66f6fff
f55ff55ff66ff66ff55ff55ff66ff66ff55ff55ff66ff66ff55ff55ff66ff66ff55ff55ff66ff66ff55f55fff66f66fff55fff5ff66fff6ff55ffffff66fffff
ff5555ffff6666ffff5555ffff6666fff55ff55ff66ff66f555555ff666666ffff5555ffff6666ff55555fff66666fff5555555f6666666f5555ffff6666ffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ff7777ffff8888ffff7777ffff8888fffff77ffffff88fff777777ff888888ffff7777ffff8888ff77777fff88888fff7777777f8888888f7777777f8888888f
f77ff77ff88ff88ff77ff77ff88ff88fff7777ffff8888fff77ff77ff88ff88ff77ff77ff88ff88ff77f77fff88f88fff77fff7ff88fff8ff77fff7ff88fff8f
f77ff77ff88ff88ff77ff77ff88ff88ff77ff77ff88ff88ff77ff77ff88ff88f77ffffff88fffffff77ff77ff88ff88ff77ffffff88ffffff77f7ffff88f8fff
ff7777ffff8888ffff77777fff88888ff77ff77ff88ff88ff77777fff88888ff77ffffff88fffffff77ff77ff88ff88ff7777ffff8888ffff7777ffff8888fff
f77ff77ff88ff88ffffff77ffffff88ff777777ff888888ff77ff77ff88ff88f77ffffff88fffffff77ff77ff88ff88ff77ffffff88ffffff77f7ffff88f8fff
f77ff77ff88ff88ff77ff77ff88ff88ff77ff77ff88ff88ff77ff77ff88ff88ff77ff77ff88ff88ff77f77fff88f88fff77fff7ff88fff8ff77ffffff88fffff
ff7777ffff8888ffff7777ffff8888fff77ff77ff88ff88f777777ff888888ffff7777ffff8888ff77777fff88888fff7777777f8888888f7777ffff8888ffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
f99999fffaaaaafffff99ffffffaafffff9999ffffaaaaffff9999ffffaaaafffff999fffffaaafff999999ffaaaaaafff9999ffffaaaafff999999ffaaaaaaf
99fff99faafffaafff999fffffaaaffff99ff99ffaaffaaff99ff99ffaaffaafff9999ffffaaaafff99fff9ffaafffaff99ff99ffaaffaaff99ff99ffaaffaaf
99ff999faaffaaaffff99ffffffaaffffffff99ffffffaaffffff99ffffffaaff99f99fffaafaafff99ffffffaaffffff99ffffffaaffffffffff99ffffffaaf
99f9f99faafafaaffff99ffffffaafffff9999ffffaaaafffff999fffffaaaff99ff99ffaaffaafff99999fffaaaaafff99999fffaaaaaffffff99ffffffaaff
999ff99faaaffaaffff99ffffffaaffff99ffffffaaffffffffff99ffffffaaf9999999faaaaaaaffffff99ffffffaaff99ff99ffaaffaaffff99ffffffaafff
99fff99faafffaaffff99ffffffaaffff99ff99ffaaffaaff99ff99ffaaffaafffff99ffffffaafff99ff99ffaaffaaff99ff99ffaaffaaffff99ffffffaafff
f99999fffaaaaafff999999ffaaaaaaff999999ffaaaaaafff9999ffffaaaafffff9999ffffaaaafff9999ffffaaaaffff9999ffffaaaafffff99ffffffaafff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fbbbbbfffcccccfffffbbffffffccfffffbbbbffffccccffffbbbbffffccccfffffbbbfffffcccfffbbbbbbffccccccfffbbbbffffccccfffbbbbbbffccccccf
bbfffbbfccfffccfffbbbfffffcccffffbbffbbffccffccffbbffbbffccffccfffbbbbffffccccfffbbfffbffccfffcffbbffbbffccffccffbbffbbffccffccf
bbffbbbfccffcccffffbbffffffccffffffffbbffffffccffffffbbffffffccffbbfbbfffccfccfffbbffffffccffffffbbffffffccffffffffffbbffffffccf
bbfbfbbfccfcfccffffbbffffffccfffffbbbbffffccccfffffbbbfffffcccffbbffbbffccffccfffbbbbbfffcccccfffbbbbbfffcccccffffffbbffffffccff
bbbffbbfcccffccffffbbffffffccffffbbffffffccffffffffffbbffffffccfbbbbbbbfcccccccffffffbbffffffccffbbffbbffccffccffffbbffffffccfff
bbfffbbfccfffccffffbbffffffccffffbbffbbffccffccffbbffbbffccffccfffffbbffffffccfffbbffbbffccffccffbbffbbffccffccffffbbffffffccfff
fbbbbbfffcccccfffbbbbbbffccccccffbbbbbbffccccccfffbbbbffffccccfffffbbbbffffccccfffbbbbffffccccffffbbbbffffccccfffffbbffffffccfff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ff9999ffffaaaaffff9999ffffaaaafffff99ffffffaafff999999ffaaaaaaffff9999ffffaaaaff99999fffaaaaafff9999999faaaaaaaf9999999faaaaaaaf
f99ff99ffaaffaaff99ff99ffaaffaafff9999ffffaaaafff99ff99ffaaffaaff99ff99ffaaffaaff99f99fffaafaafff99fff9ffaafffaff99fff9ffaafffaf
f99ff99ffaaffaaff99ff99ffaaffaaff99ff99ffaaffaaff99ff99ffaaffaaf99ffffffaafffffff99ff99ffaaffaaff99ffffffaaffffff99f9ffffaafafff
ff9999ffffaaaaffff99999fffaaaaaff99ff99ffaaffaaff99999fffaaaaaff99ffffffaafffffff99ff99ffaaffaaff9999ffffaaaaffff9999ffffaaaafff
f99ff99ffaaffaaffffff99ffffffaaff999999ffaaaaaaff99ff99ffaaffaaf99ffffffaafffffff99ff99ffaaffaaff99ffffffaaffffff99f9ffffaafafff
f99ff99ffaaffaaff99ff99ffaaffaaff99ff99ffaaffaaff99ff99ffaaffaaff99ff99ffaaffaaff99f99fffaafaafff99fff9ffaafffaff99ffffffaafffff
ff9999ffffaaaaffff9999ffffaaaafff99ff99ffaaffaaf999999ffaaaaaaffff9999ffffaaaaff99999fffaaaaafff9999999faaaaaaaf9999ffffaaaaffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffbbbbffffccccffffbbbbffffccccfffffbbffffffccfffbbbbbbffccccccffffbbbbffffccccffbbbbbfffcccccfffbbbbbbbfcccccccfbbbbbbbfcccccccf
fbbffbbffccffccffbbffbbffccffccfffbbbbffffccccfffbbffbbffccffccffbbffbbffccffccffbbfbbfffccfccfffbbfffbffccfffcffbbfffbffccfffcf
fbbffbbffccffccffbbffbbffccffccffbbffbbffccffccffbbffbbffccffccfbbffffffccfffffffbbffbbffccffccffbbffffffccffffffbbfbffffccfcfff
ffbbbbffffccccffffbbbbbfffcccccffbbffbbffccffccffbbbbbfffcccccffbbffffffccfffffffbbffbbffccffccffbbbbffffccccffffbbbbffffccccfff
fbbffbbffccffccffffffbbffffffccffbbbbbbffccccccffbbffbbffccffccfbbffffffccfffffffbbffbbffccffccffbbffffffccffffffbbfbffffccfcfff
fbbffbbffccffccffbbffbbffccffccffbbffbbffccffccffbbffbbffccffccffbbffbbffccffccffbbfbbfffccfccfffbbfffbffccfffcffbbffffffccfffff
ffbbbbffffccccffffbbbbffffccccfffbbffbbffccffccfbbbbbbffccccccffffbbbbffffccccffbbbbbfffcccccfffbbbbbbbfcccccccfbbbbffffccccffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fdddddfffeeeeefffffddffffffeefffffddddffffeeeeffffddddffffeeeefffffdddfffffeeefffddddddffeeeeeefffddddffffeeeefffddddddffeeeeeef
ddfffddfeefffeefffdddfffffeeeffffddffddffeeffeeffddffddffeeffeefffddddffffeeeefffddfffdffeefffeffddffddffeeffeeffddffddffeeffeef
ddffdddfeeffeeeffffddffffffeeffffffffddffffffeeffffffddffffffeeffddfddfffeefeefffddffffffeeffffffddffffffeeffffffffffddffffffeef
ddfdfddfeefefeeffffddffffffeefffffddddffffeeeefffffdddfffffeeeffddffddffeeffeefffdddddfffeeeeefffdddddfffeeeeeffffffddffffffeeff
dddffddfeeeffeeffffddffffffeeffffddffffffeeffffffffffddffffffeefdddddddfeeeeeeeffffffddffffffeeffddffddffeeffeeffffddffffffeefff
ddfffddfeefffeeffffddffffffeeffffddffddffeeffeeffddffddffeeffeefffffddffffffeefffddffddffeeffeeffddffddffeeffeeffffddffffffeefff
fdddddfffeeeeefffddddddffeeeeeeffddddddffeeeeeefffddddffffeeeefffffddddffffeeeefffddddffffeeeeffffddddffffeeeefffffddffffffeefff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
f00000fff41414fffff00ffffff14fffff0000ffff4141ffff0000ffff4141fffff000fffff414fff000000ff141414fff0000ffff4141fff000000ff414141f
00fff00f41fff14fff000fffff141ffff00ff00ff41ff41ff00ff00ff41ff41fff0000ffff4141fff00fff0ff41fff1ff00ff00ff41ff41ff00ff00ff14ff14f
00ff000f14ff141ffff00ffffff14ffffffff00ffffff14ffffff00ffffff14ff00f00fff41f14fff00ffffff14ffffff00ffffff14ffffffffff00ffffff41f
00f0f00f41f1f14ffff00ffffff41fffff0000ffff1414fffff000fffff414ff00ff00ff41ff41fff00000fff41414fff00000fff41414ffffff00ffffff41ff
000ff00f141ff41ffff00ffffff14ffff00ffffff14ffffffffff00ffffff14f0000000f1414141ffffff00ffffff14ff00ff00ff14ff14ffff00ffffff41fff
00fff00f41fff14ffff00ffffff41ffff00ff00ff41ff41ff00ff00ff41ff41fffff00ffffff41fff00ff00ff41ff41ff00ff00ff41ff41ffff00ffffff14fff
f00000fff41414fff000000ff141414ff000000ff141414fff0000ffff4141fffff0000ffff4141fff0000ffff4141ffff0000ffff4141fffff00ffffff41fff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffddddffffeeeeffffddddffffeeeefffffddffffffeefffddddddffeeeeeeffffddddffffeeeeffdddddfffeeeeefffdddddddfeeeeeeefdddddddfeeeeeeef
fddffddffeeffeeffddffddffeeffeefffddddffffeeeefffddffddffeeffeeffddffddffeeffeeffddfddfffeefeefffddfffdffeefffeffddfffdffeefffef
fddffddffeeffeeffddffddffeeffeeffddffddffeeffeeffddffddffeeffeefddffffffeefffffffddffddffeeffeeffddffffffeeffffffddfdffffeefefff
ffddddffffeeeeffffdddddfffeeeeeffddffddffeeffeeffdddddfffeeeeeffddffffffeefffffffddffddffeeffeeffddddffffeeeeffffddddffffeeeefff
fddffddffeeffeeffffffddffffffeeffddddddffeeeeeeffddffddffeeffeefddffffffeefffffffddffddffeeffeeffddffffffeeffffffddfdffffeefefff
fddffddffeeffeeffddffddffeeffeeffddffddffeeffeeffddffddffeeffeeffddffddffeeffeeffddfddfffeefeefffddfffdffeefffeffddffffffeefffff
ffddddffffeeeeffffddddffffeeeefffddffddffeeffeefddddddffeeeeeeffffddddffffeeeeffdddddfffeeeeefffdddddddfeeeeeeefddddffffeeeeffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ff0000ffff4141ffff0000ffff4141fffff00ffffff14fff000000ff141414ffff0000ffff1414ff00000fff14141fff0000000f1414141f0000000f1414141f
f00ff00ff41ff41ff00ff00ff41ff41fff0000ffff1414fff00ff00ff14ff14ff00ff00ff14ff14ff00f00fff14f41fff00fff0ff14fff4ff00fff0ff14fff4f
f00ff00ff14ff14ff00ff00ff14ff14ff00ff00ff14ff14ff00ff00ff41ff41f00ffffff14fffffff00ff00ff41ff41ff00ffffff41ffffff00f0ffff41f1fff
ff0000ffff1414ffff00000fff14141ff00ff00ff41ff41ff00000fff14141ff00ffffff41fffffff00ff00ff14ff14ff0000ffff1414ffff0000ffff1414fff
f00ff00ff14ff14ffffff00ffffff14ff000000ff141414ff00ff00ff41ff41f00ffffff14fffffff00ff00ff41ff41ff00ffffff41ffffff00f0ffff41f1fff
f00ff00ff41ff41ff00ff00ff41ff41ff00ff00ff41ff41ff00ff00ff14ff14ff00ff00ff14ff14ff00f00fff14f41fff00fff0ff14fff4ff00ffffff14fffff
ff0000ffff4141ffff0000ffff4141fff00ff00ff14ff14f000000ff141414ffff0000ffff1414ff00000fff14141fff0000000f1414141f0000ffff1414ffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff

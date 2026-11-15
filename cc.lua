--[[
CAZIELX ARCHX V6.1 — SATU FILE (tanpa server buatan sendiri)

FIREBASE RTDB (opsional; implementasi V6.1 yang dipertahankan hanya sinkronisasi announcement):
  Dibutuhkan 1 penyimpanan bersama di internet. Cara gratis tanpa coding (Firebase Realtime Database):
  1) console.firebase.google.com -> buat project -> Build -> Realtime Database -> Create (mode locked)
  2) Gunakan rules tertutup dari CAZIELX_FIREBASE_SECURITY_RULES.json; jangan aktifkan public read/write.
  3) Salin URL database (contoh https://xxxx-default-rtdb.firebaseio.com) ke CX_CONFIG.CLOUD_URL
  4) Jangan memasukkan service-account key/database secret ke source Lua. Gunakan backend tepercaya / Firebase Auth custom token.
  Client hanya membaca announcement sesuai Rules. Operasi admin/role/ban/preset harus lewat backend tepercaya.
  Peringatan: secret di source bisa dibaca siapa pun yang punya file ini. Jangan bagikan source publik
  yang berisi key/secret asli. Tanpa CLOUD_URL, pengumuman hanya lokal di perangkat sendiri.
Role lokal hanya tampilan/kompatibilitas, bukan otorisasi aman. Hak admin wajib diputuskan backend.
Cek izin: jalankan  _G.CAZX_PERMTEST()  di executor.
]]
print("[CAZX][RUNNING] V6.2 source compiled")
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local HttpService=game:GetService("HttpService")
local StatsSvc=game:GetService("Stats")
local GuiService=game:GetService("GuiService")
local VirtualUser=game:GetService("VirtualUser")
local Player=Players.LocalPlayer
local PlayerGui=Player:WaitForChild("PlayerGui",15)
assert(PlayerGui,"[CAZX][FAILED] PlayerGui not found within 15s")
if _G.__CAZX_CLEANUP then pcall(_G.__CAZX_CLEANUP) end


-- V6.2 BOOT EXPERIENCE: progress advances only when a real startup stage completes.
local Boot={gui=nil,label=nil,percent=nil,fill=nil,done=0,total=6,closed=false}
do
    local ok,err=pcall(function()
        local g=Instance.new("ScreenGui")
        g.Name="CAZIELX_ARCHX_BOOT_V62" g.IgnoreGuiInset=true
        g.ResetOnSpawn=false g.DisplayOrder=100000 g.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
        g.Parent=PlayerGui
        local bg=Instance.new("Frame")
        bg.Size=UDim2.fromScale(1,1) bg.BackgroundColor3=Color3.fromRGB(7,9,14)
        bg.BorderSizePixel=0 bg.Parent=g
        local glow=Instance.new("Frame")
        glow.AnchorPoint=Vector2.new(.5,.5) glow.Position=UDim2.fromScale(.5,.43)
        glow.Size=UDim2.fromOffset(190,190) glow.BackgroundColor3=Color3.fromRGB(27,39,59)
        glow.BackgroundTransparency=.35 glow.BorderSizePixel=0 glow.Parent=bg
        local cr=Instance.new("UICorner") cr.CornerRadius=UDim.new(1,0) cr.Parent=glow
        local logo=Instance.new("TextLabel")
        logo.BackgroundTransparency=1 logo.AnchorPoint=Vector2.new(.5,.5)
        logo.Position=UDim2.fromScale(.5,.40) logo.Size=UDim2.fromOffset(240,92)
        logo.Font=Enum.Font.GothamBlack logo.Text="C X" logo.TextSize=66
        logo.TextColor3=Color3.fromRGB(232,238,248) logo.Parent=bg
        local sub=Instance.new("TextLabel")
        sub.BackgroundTransparency=1 sub.AnchorPoint=Vector2.new(.5,.5)
        sub.Position=UDim2.fromScale(.5,.49) sub.Size=UDim2.fromOffset(300,28)
        sub.Font=Enum.Font.GothamBold sub.Text="CAZIELX  /  ARCHX"
        sub.TextSize=13 sub.TextColor3=Color3.fromRGB(222,158,73) sub.Parent=bg
        local status=Instance.new("TextLabel")
        status.BackgroundTransparency=1 status.AnchorPoint=Vector2.new(.5,.5)
        status.Position=UDim2.fromScale(.5,.72) status.Size=UDim2.new(.82,0,0,24)
        status.Font=Enum.Font.Gotham status.Text="INITIALIZING CAZIELX"
        status.TextSize=12 status.TextColor3=Color3.fromRGB(190,199,214)
        status.TextXAlignment=Enum.TextXAlignment.Center status.Parent=bg
        local track=Instance.new("Frame")
        track.AnchorPoint=Vector2.new(.5,.5) track.Position=UDim2.fromScale(.5,.77)
        track.Size=UDim2.new(.72,0,0,5) track.BackgroundColor3=Color3.fromRGB(34,41,53)
        track.BorderSizePixel=0 track.Parent=bg
        local tc=Instance.new("UICorner") tc.CornerRadius=UDim.new(1,0) tc.Parent=track
        local fill=Instance.new("Frame")
        fill.Size=UDim2.new(0,0,1,0) fill.BackgroundColor3=Color3.fromRGB(222,158,73)
        fill.BorderSizePixel=0 fill.Parent=track
        local fc=Instance.new("UICorner") fc.CornerRadius=UDim.new(1,0) fc.Parent=fill
        local pct=Instance.new("TextLabel")
        pct.BackgroundTransparency=1 pct.AnchorPoint=Vector2.new(.5,.5)
        pct.Position=UDim2.fromScale(.5,.82) pct.Size=UDim2.fromOffset(100,20)
        pct.Font=Enum.Font.GothamBold pct.Text="0%" pct.TextSize=11
        pct.TextColor3=Color3.fromRGB(222,158,73) pct.Parent=bg
        local foot=Instance.new("TextLabel")
        foot.BackgroundTransparency=1 foot.AnchorPoint=Vector2.new(.5,.5)
        foot.Position=UDim2.fromScale(.5,.94) foot.Size=UDim2.new(.9,0,0,18)
        foot.Font=Enum.Font.Gotham foot.Text="CONNECTING TO SESSION"
        foot.TextSize=9 foot.TextColor3=Color3.fromRGB(102,114,133) foot.Parent=bg
        Boot.gui,Boot.label,Boot.percent,Boot.fill=g,status,pct,fill
        local scale=Instance.new("UIScale") scale.Scale=1 scale.Parent=bg
        local cam=workspace.CurrentCamera
        if cam then
            local vp=cam.ViewportSize
            if vp.X<520 then scale.Scale=.86 end
        end
    end)
    if not ok then warn("[CAZX][BOOT] "..tostring(err)) end
end
function Boot.stage(name)
    if Boot.closed then return end
    Boot.done=math.min(Boot.total,Boot.done+1)
    local p=Boot.done/Boot.total
    if Boot.label then Boot.label.Text=string.upper(tostring(name)) end
    if Boot.percent then Boot.percent.Text=("%d%%"):format(math.floor(p*100+.5)) end
    if Boot.fill then
        pcall(function()
            TweenService:Create(Boot.fill,TweenInfo.new(.22,Enum.EasingStyle.Quint),{Size=UDim2.new(p,0,1,0)}):Play()
        end)
    end
end
function Boot.finish()
    if Boot.closed then return end
    Boot.closed=true
    if Boot.label then Boot.label.Text="SESSION READY" end
    if Boot.percent then Boot.percent.Text="100%" end
    if Boot.fill then Boot.fill.Size=UDim2.new(1,0,1,0) end
    task.delay(.35,function()
        if Boot.gui and Boot.gui.Parent then
            local bg=Boot.gui:FindFirstChildOfClass("Frame")
            if bg then
                local ok=pcall(function()
                    TweenService:Create(bg,TweenInfo.new(.25,Enum.EasingStyle.Quad),{BackgroundTransparency=1}):Play()
                end)
                if ok then task.wait(.28) end
            end
            if Boot.gui then Boot.gui:Destroy() end
        end
    end)
end

local X={VERSION="6.2.0",BUILD="20261115-CX-V62",game={name="Universal",target=false},on={},sync={},live={},paused=false,t0=os.clock()}
local IS_TOUCH=UIS.TouchEnabled and not UIS.KeyboardEnabled
local HAS_FILES=typeof(writefile)=="function" and typeof(readfile)=="function" and typeof(isfile)=="function"
local HAS_CLIP=typeof(setclipboard)=="function"
local HTTP_REQUEST=(typeof(request)=="function" and request) or (typeof(http_request)=="function" and http_request) or nil
local CONFIG_FILE,WEBHOOK_FILE="CAZIELX_ARCHX_config.json","CAZIELX_ARCHX_webhook.json"
local alive=true
local function tb(m) return tostring(m).."\n"..debug.traceback() end

local function newMaid()
    local m={items={}}
    function m.add(x) m.items[#m.items+1]=x return x end
    function m.clean()
        local it=m.items
        for i=#it,1,-1 do
            local x=it[i] it[i]=nil
            local t=typeof(x)
            if t=="RBXScriptConnection" then x:Disconnect()
            elseif t=="Instance" then pcall(x.Destroy,x)
            elseif t=="function" then pcall(x)
            elseif t=="table" and x.Cancel then pcall(x.Cancel,x) end
        end
    end
    return m
end
local Root=newMaid()
local Diag={f={},errs={},stages={},cleanup={},last="",lastAt=0}
_G.CAZX_DIAG=Diag
function Diag.err(id,msg)
    local line=("["..id.."] "..tostring(msg)):sub(1,400)
    if line==Diag.last and os.clock()-Diag.lastAt<5 then return end
    Diag.last,Diag.lastAt=line,os.clock()
    Diag.errs[#Diag.errs+1]=os.date("%H:%M:%S").." "..line
    while #Diag.errs>40 do table.remove(Diag.errs,1) end
    warn("[CAZX]"..line)
end
function Diag.set(id,st,why)
    local o=Diag.f[id]
    if o and o.st==st and o.why==why then return end
    Diag.f[id]={st=st,why=why,at=os.date("%H:%M:%S")}
    if st=="FAILED" then Diag.err(id,why) end
end
local Sched={tasks={},conn=nil,fps=60}
function Sched.add(id,interval,fn)
    local h={id=id,interval=interval,fn=fn,nextAt=0,fails=0,busy=false,alive=true}
    Sched.tasks[#Sched.tasks+1]=h
    if not Sched.conn then
        Sched.conn=RunService.Heartbeat:Connect(function(dt)
            Sched.fps=Sched.fps*.95+(1/math.max(dt,.001))*.05
            local now,t=os.clock(),Sched.tasks
            for i=#t,1,-1 do
                local k=t[i]
                if not k.alive then table.remove(t,i)
                elseif now>=k.nextAt and not k.busy then
                    k.nextAt=now+k.interval
                    k.busy=true
                    local ok,err=xpcall(k.fn,tb,k,now)
                    k.busy=false
                    if ok then k.fails=0 else
                        k.fails+=1 Diag.err(k.id,err)
                        if k.fails>=8 then k.alive=false Diag.set(k.id,"FAILED","auto-stopped after 8 consecutive errors") if k.onfail then pcall(k.onfail) end end
                    end
                end
            end
        end)
        Root.add(function() if Sched.conn then Sched.conn:Disconnect() Sched.conn=nil end Sched.tasks={} end)
    end
    return h
end
local function stopTask(h) if h then h.alive=false end end

local D={
    farm_auto=false,farm_break=false,farm_collect=false,farm_pause=false,
    swing_mult=1,farm_equipmode="Auto equip best",farm_zone="Any",break_reach=10,
    farm_maxdist=2000,farm_minrar="Any",farm_ignore="",farm_filter="",farm_priority="Nearest",
    steal_auto=false,steal_species="",steal_minrar="Any",steal_minincome="",steal_priority="Nearest",steal_guard=false,
    pet_rare_min="legendary",pet_alert=true,
    esp_egg=false,esp_pet=false,esp_player=false,esp_dist=true,esp_color="Cyan",esp_fill="Soft",esp_range=1000,
    wh_enable=false,wh_ev_egg=false,wh_ev_pet=true,wh_ev_rare=false,wh_ev_error=false,wh_ev_summary=false,
    theme="Amber",anim_quality="Medium",ui_scale=1,perf_mode=false,anti_afk=true,auto_save=true,
    fly=false,fly_speed=65,speed_boost=false,speed_value=80,low_graphics=false,

    about_discord="",about_social="",about_link="",
}
local RUNTIME_OFF={farm_auto=true,farm_break=true,farm_collect=true,steal_auto=true,farm_pause=true,fly=true,speed_boost=true,low_graphics=true}
local S={}
for k,v in pairs(D) do S[k]=v end
local POS={wx=.5,wy=.5,fx=.04,fy=.5}
local notify=function(m) print("[CAZX] "..tostring(m)) end
X.notify=function(...) return notify(...) end
function X.set(k,v,silent)
    if D[k]==nil or type(v)~=type(D[k]) or S[k]==v then return end
    local old=S[k]
    S[k]=v
    if X.sync[k] then pcall(X.sync[k],v) end
    local fn=X.on[k]
    if fn then
        local ok,r,why=xpcall(fn,tb,v)
        if not ok then Diag.err("cfg:"..k,r) S[k]=old if X.sync[k] then pcall(X.sync[k],old) end return end
        if r==false then
            S[k]=old
            if X.sync[k] then pcall(X.sync[k],old) end
            if why then X.notify(why,"bad",4) end
            return
        end
    end
    if not silent then X.dirty=os.clock() end
end
local function activeFeatureNames()
    local map={farm_auto="Auto Farm",farm_break="Auto Break",farm_collect="Auto Collect",steal_auto="Auto Steal",fly="Fly",speed_boost="Speed Boost",low_graphics="Low Graphics",esp_egg="Egg ESP",esp_pet="Pet ESP",esp_player="Player ESP",wh_enable="Webhook",anti_afk="Anti-AFK"}
    local out={}
    for key,label in pairs(map) do if S[key] then out[#out+1]=label end end
    table.sort(out)
    return out
end
local function encodeConfig()
    local st={} for k,v in pairs(S) do st[k]=v end
    return HttpService:JSONEncode({v=5,state=st,pos=POS,meta={owner=Player.Name,displayName=Player.DisplayName,features=activeFeatureNames(),createdAt=os.date("!%Y-%m-%dT%H:%M:%SZ")}})
end
local function applyConfig(data)
    if type(data)~="table" or type(data.state)~="table" then return false,"Invalid config structure" end
    local st,n,skip=data.state,0,0
    if (data.v or 0)<4 and tonumber(st.swing_mult) then st.swing_mult=math.clamp(math.floor(st.swing_mult),1,5) end
    for k,v in pairs(st) do
        if D[k]~=nil and type(v)==type(D[k]) and not RUNTIME_OFF[k] then
            if k=="swing_mult" then v=math.clamp(math.floor(v),1,5)
            elseif k=="ui_scale" then v=math.clamp(v,.8,1.2)
            elseif k=="break_reach" then v=math.clamp(v,4,30) end
            X.set(k,v,true) n+=1
        else skip+=1 end
    end
    if type(data.pos)=="table" then
        local p=data.pos
        local function c(v,d) return (type(v)=="number" and v==v) and math.clamp(v,0,1) or d end
        POS.wx,POS.wy=c(p.wx,.5),c(p.wy,.5)
        POS.fx,POS.fy=c(p.fx,.04),c(p.fy,.5)
    end
    return true,("Applied %d, skipped %d"):format(n,skip)
end
local function readConfig()
    if not HAS_FILES then return nil end
    local ok,ex=pcall(isfile,CONFIG_FILE)
    if ok and ex then local ok2,c=pcall(readfile,CONFIG_FILE) if ok2 then return c end end
end
local function saveConfig(silent)
    local ok,json=pcall(encodeConfig)
    if not ok then Diag.err("config",json) return false end
    X.memCfg=json
    if not HAS_FILES then if not silent then X.notify("No file API: saved for this session only","warn") end return false end
    local ok2,err=pcall(writefile,CONFIG_FILE,json)
    if not ok2 then Diag.err("config","write failed: "..tostring(err)) end
    if not silent then X.notify(ok2 and "Configuration saved" or "File write failed (kept in session)",ok2 and "good" or "warn") end
    return ok2
end
local function importConfig(str)
    if type(str)~="string" or str:match("^%s*$") then return false,"Config is empty" end
    local ok,d=pcall(HttpService.JSONDecode,HttpService,str)
    if not ok then return false,"Invalid JSON" end
    return applyConfig(d)
end

local function getHum() local c=Player.Character return c and c:FindFirstChildOfClass("Humanoid") end
local function inWorld(i) return i~=nil and i:IsDescendantOf(workspace) end
local function numAttr(n) local v=Player:GetAttribute(n) return type(v)=="number" and v or nil end
local function getCash()
    local a=numAttr("Cash") if a then return a end
    local ls=Player:FindFirstChild("leaderstats")
    if ls then for _,n in ipairs({"Cash","Coins","Money","Gold"}) do local v=ls:FindFirstChild(n) if v and (v:IsA("NumberValue") or v:IsA("IntValue")) then return v.Value end end end
    return nil
end
local function parseNum(s)
    s=tostring(s):gsub(",",""):gsub("%s","")
    local n,suf=s:match("^([%d%.]+)([KkMmBbTt]?)$")
    n=tonumber(n) if not n then return nil end
    return n*(({k=1e3,m=1e6,b=1e9,t=1e12})[suf:lower()] or 1)
end
local function shortNum(n)
    if not n then return "N/A" end
    local a=math.abs(n)
    for _,u in ipairs({{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}}) do if a>=u[1] then return ("%.2f%s"):format(n/u[1],u[2]) end end
    return tostring(math.floor(n))
end
local function fmtDur(s) s=math.floor(s) return ("%02d:%02d:%02d"):format(s//3600,(s%3600)//60,s%60) end
local RAR={"common","uncommon","rare","epic","legendary","mythic","divine","secret"}
local function rarityIndex(v)
    if type(v)=="number" then local n=math.floor(v) return n>=1 and math.min(n,99) or 0 end
    if type(v)=="string" then
        local s=v:lower()
        local i=table.find(RAR,s) if i then return i end
        for k=#RAR,1,-1 do if s:find("%f[%a]"..RAR[k].."%f[%A]") then return k end end
    end
    return 0
end
local function rarityInfo(inst,hint)
    if inst then
        for _,o in ipairs({inst,inst.Parent}) do
            if o then
                for _,key in ipairs({"Rarity","RarityName","Tier"}) do
                    local ok,a=pcall(o.GetAttribute,o,key)
                    local i=ok and rarityIndex(a) or 0
                    if i>0 then return i,RAR[i] or ("tier "..i) end
                end
                local rv=o:FindFirstChild("Rarity")
                if rv and rv:IsA("ValueBase") then local i=rarityIndex(rv.Value) if i>0 then return i,RAR[i] or ("tier "..i) end end
            end
        end
    end
    local i=rarityIndex(hint or (inst and inst.Name))
    if i>0 then return i,RAR[i] or ("tier "..i) end
    return 0,"unknown"
end
local function parseList(str)
    local out={}
    for p in tostring(str or ""):gmatch("[^,]+") do p=p:lower():match("^%s*(.-)%s*$") if p~="" then out[#out+1]=p end end
    return out
end
local function labelHas(label,list) for _,p in ipairs(list) do if label:find(p,1,true) then return true end end return false end
local function onChar(bag,fn)
    local cm=newMaid() bag.add(cm.clean)
    local function go(c) cm.clean() fn(c,cm) end
    bag.add(Player.CharacterAdded:Connect(go))
    if Player.Character then task.defer(go,Player.Character) end
end

local Ses={earn=0,lastCash=nil,history={},pets={},petCounts={},petTotal=0,bestIdx=0,bestName="none",broken=0,animals=0,lastAnimal="none"}
local Inv={dirty=true}

local Tools={dirty=true}
local AXE_POWER={stone=1,wood=1,iron=15,golden=60,gold=60,diamond=250,strawberry=1000}
function Tools.classify(t)
    if not (t and t:IsA("Tool")) then return nil end
    if t:GetAttribute("Pet") or t:GetAttribute("Animal") or t:GetAttribute("IsPet") then return nil end
    local n=t.Name:lower()
    local why
    if n:find("pickaxe",1,true) or n:find("pick axe",1,true) then why="name (pickaxe)"
    elseif n:find("axe",1,true) or n:find("pick",1,true) then why="name (axe/pick)" end
    for k,v in pairs(t:GetAttributes()) do
        local lk=k:lower()
        if (lk:find("pick",1,true) and v==true) or ((lk=="tooltype" or lk=="type" or lk=="category" or lk=="class") and tostring(v):lower():find("pick",1,true)) then why=why or ("attribute "..k) end
    end
    local tip=(t.ToolTip or ""):lower()
    if tip:find("pick",1,true) or tip:find("axe",1,true) then why=why or "tooltip" end
    if Tools.used==t then why=why or "used by you" end
    if not why then return nil end
    if n:find("bat",1,true) and not n:find("axe",1,true) then return nil end
    local score=1
    for _,k in ipairs({"Power","Damage","Dmg","Strength","HitDamage"}) do local v=t:GetAttribute(k) if type(v)=="number" then score=math.max(score,v) end end
    for key,p in pairs(AXE_POWER) do if n:find(key,1,true) then score=math.max(score,p) end end
    return score,why
end
function Tools.best()
    local char,bp=Player.Character,Player:FindFirstChild("Backpack")
    local t=Tools.tool
    if t and not Tools.dirty and t.Parent and (t.Parent==char or t.Parent==bp) then return t,Tools.why,t.Parent==char end
    Tools.dirty=false
    local best,bs,bwhy
    for _,c in ipairs({char,bp}) do
        if c then for _,tl in ipairs(c:GetChildren()) do
            local sc,why=Tools.classify(tl)
            if sc then
                local val=sc+((Tools.used==tl) and 1e12 or 0)+((S.farm_equipmode=="Keep equipped" and c==char) and 1e9 or 0)
                if not bs or val>bs then best,bs,bwhy=tl,val,why end
            end
        end end
    end
    Tools.tool,Tools.why=best,bwhy
    return best,bwhy,best~=nil and best.Parent==char
end
function Tools.watch()
    local bag=newMaid() Root.add(bag.clean)
    local function hookTool(t,cm) if t:IsA("Tool") then cm.add(t.Activated:Connect(function() if Tools.classify(t) then Tools.used=t Tools.dirty=true end end)) end end
    local function hookC(c,cm)
        if not c then return end
        for _,t in ipairs(c:GetChildren()) do hookTool(t,cm) end
        cm.add(c.ChildAdded:Connect(function(t) hookTool(t,cm) Tools.dirty=true Inv.dirty=true end))
        cm.add(c.ChildRemoved:Connect(function() Tools.dirty=true Inv.dirty=true end))
    end
    local bm=newMaid() bag.add(bm.clean)
    local function bp() bm.clean() hookC(Player:FindFirstChild("Backpack"),bm) Tools.dirty=true Inv.dirty=true end
    bp()
    bag.add(Player.ChildAdded:Connect(function(c) if c.Name=="Backpack" then bp() end end))
    onChar(bag,function(c,cm) hookC(c,cm) Tools.dirty=true end)
end
function Inv.pets()
    local list={}
    for _,c in ipairs({Player:FindFirstChild("Backpack"),Player.Character}) do
        if c then for _,t in ipairs(c:GetChildren()) do
            if t:IsA("Tool") and t.Name~="Bat" and not Tools.classify(t) then
                local idx,rl=rarityInfo(t,t.Name)
                list[#list+1]={name=t.Name,idx=idx,rarity=rl,held=c==Player.Character}
            end
        end end
    end
    table.sort(list,function(a,b) if a.idx~=b.idx then return a.idx>b.idx end return a.name<b.name end)
    return list
end


-- Auto Place Best Animal: HANYA antarmuka integrasi. Tidak menebak RemoteEvent. Game milik sendiri
-- mendaftarkan adapter resmi lewat X.Place.register{getOwned=,getSlots=,place=[,canPlace=]}.
local Place={adapter=nil,placed={},busy=false,state="NO_ADAPTER"}
X.Place=Place
function Place.register(a)
    if type(a)~="table" then return false,"adapter harus table" end
    for _,f in ipairs({"getOwned","getSlots","place"}) do
        if type(a[f])~="function" then return false,"adapter kurang fungsi: "..f end
    end
    Place.adapter=a Place.state="READY" table.clear(Place.placed)
    return true
end
function Place.score(it)
    local idx=tonumber(it.rarityIdx) or rarityIndex(it.rarity)
    return idx*1e12+(tonumber(it.value) or 0)+(tonumber(it.priority) or 0)*1e9
end
function Place.run()
    local a=Place.adapter
    if not a then return false,"Adapter game belum terdaftar (lihat BACKEND_SPEC: Placement API)" end
    if Place.busy then return false,"Penempatan sedang berjalan" end
    Place.busy=true
    local ok,r1,r2=xpcall(function()
        local owned,slots=a.getOwned(),a.getSlots()
        if type(owned)~="table" or type(slots)~="table" then error("adapter mengembalikan data tidak valid") end
        local free={}
        for _,sl in ipairs(slots) do if sl.free==true then free[#free+1]=sl end end
        if #free==0 then return false,"Tidak ada slot kosong" end
        local cands={}
        for _,it in ipairs(owned) do
            if it.id~=nil and not it.placed and not Place.placed[it.id] and (a.canPlace==nil or a.canPlace(it)==true) then cands[#cands+1]=it end
        end
        if #cands==0 then return false,"Tidak ada hewan yang bisa ditempatkan" end
        table.sort(cands,function(x,y) local sx,sy=Place.score(x),Place.score(y) if sx~=sy then return sx>sy end return tostring(x.id)<tostring(y.id) end)
        local n=0
        for i=1,math.min(#cands,#free) do
            local okp,err=a.place(cands[i],free[i])
            if okp~=true then return n>0,n.." ditempatkan, lalu gagal: "..tostring(err) end
            Place.placed[cands[i].id]=true n+=1
        end
        return true,n.." hewan ditempatkan"
    end,tb)
    Place.busy=false
    if not ok then Diag.err("place",r1) return false,"Error: "..tostring(r1):sub(1,120) end
    return r1,r2
end
local OWNER_KEYS={"Owner","OwnerId","OwnerUserId","UserId","Player","PlayerName","Username"}
local function isMine(v) if v==Player or v==Player.UserId or v==Player.Name or v==Player.DisplayName then return true end return type(v)=="string" and tonumber(v)==Player.UserId end
local function ownedByMe(inst)
    for _,k in ipairs(OWNER_KEYS) do local ok,a=pcall(inst.GetAttribute,inst,k) if ok and a~=nil and isMine(a) then return true,"attribute "..k end end
    for _,c in ipairs(inst:GetChildren()) do
        if c:IsA("ValueBase") and table.find(OWNER_KEYS,c.Name) then local ok,v=pcall(function() return c.Value end) if ok and isMine(v) then return true,"value "..c.Name end end
    end
    return false
end
local function instPos(i)
    if i:IsA("Model") then return i:GetPivot().Position end
    if i:IsA("BasePart") then return i.Position end
    local p=i:FindFirstChildWhichIsA("BasePart",true) return p and p.Position or nil
end
local function inChar(inst)
    local a=inst
    while a and a~=workspace do if a:IsA("Model") and Players:GetPlayerFromCharacter(a) then return true end a=a.Parent end
    return false
end
local Base={obj=nil,why="not scanned",lastScan=0}
local function scanBase()
    for _,k in ipairs({"Plot","PlotId","Base","BaseId","PlotName"}) do
        local v=Player:GetAttribute(k)
        if v~=nil then for _,r in ipairs({workspace:FindFirstChild("WorldRuntime"),workspace:FindFirstChild("MapNew"),workspace}) do
            local f=r and r:FindFirstChild(tostring(v),true)
            if f and (f:IsA("Model") or f:IsA("Folder")) then return f,"Player attribute "..k end
        end end
    end
    local q,head,seen={{workspace,0}},1,0
    while q[head] do
        local cur,depth=q[head][1],q[head][2] head+=1
        for _,c in ipairs(cur:GetChildren()) do
            seen+=1 if seen>6000 then break end
            if c:IsA("Model") or c:IsA("Folder") or c:IsA("BasePart") then
                local ok,why=ownedByMe(c) if ok then return c,why end
                if depth<4 and not c:IsA("BasePart") and c~=Player.Character and not inChar(c) then q[#q+1]={c,depth+1} end
            end
        end
    end
    local rl=Player.RespawnLocation
    if rl and rl.Parent then return rl,"Player.RespawnLocation" end
    if Base.spawnPos then
        if not (Base.anchor and Base.anchor.Parent) then
            local a=Instance.new("Part")
            a.Name,a.Anchored,a.CanCollide,a.CanQuery,a.CanTouch,a.Transparency,a.Size="CazxBaseAnchor",true,false,false,false,1,Vector3.new(1,1,1)
            a.Position=Base.spawnPos a.Parent=workspace Base.anchor=Root.add(a)
        end
        return Base.anchor,"first spawn position (no ownership tag found)"
    end
    return nil,"no plot tagged with your UserId/Name, no RespawnLocation, no spawn recorded"
end
function Base.get(force)
    local now=os.clock()
    if (force and now-Base.lastScan>10) or not Base.obj or not Base.obj.Parent then Base.lastScan=now Base.obj,Base.why=scanBase() end
    return Base.obj
end
function Base.tp()
    local hrp=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false,"No character" end
    Base.lastScan=0
    local b=Base.get(true) local p=b and instPos(b)
    if not p then return false,"Base not detected: "..Base.why end
    local before=(hrp.Position-p).Magnitude
    hrp.CFrame=CFrame.new(p+Vector3.new(0,5,0))
    task.wait(.7)
    hrp=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false,"Character lost" end
    local after=(hrp.Position-p).Magnitude
    if after>before-5 and after>30 then return false,"Server rejected the teleport (position reverted)" end
    return true
end

local HP_KEYS={"HP","Hp","Health","CurrentHP","CurHP","EggHP"}
local Eggs={cache={},at=0,dirty=true,model=setmetatable({},{__mode="k"}),seen=setmetatable({},{__mode="k"}),seenCount=0,hooked={},err=nil}
function Eggs.hook()
    for _,n in ipairs({"WorldRuntime","MapNew","Build"}) do
        local r=workspace:FindFirstChild(n)
        if r and not Eggs.hooked[r] then
            Eggs.hooked[r]=true
            local mark=function() Eggs.dirty=true end
            Root.add(r.DescendantAdded:Connect(mark)) Root.add(r.DescendantRemoving:Connect(mark))
        end
    end
end
function Eggs.findHp(model)
    for _,o in ipairs({model,model.Parent}) do
        if o then for _,k in ipairs(HP_KEYS) do if type(o:GetAttribute(k))=="number" then return {o=o,k=k,t="attr"} end end end
    end
    for _,c in ipairs(model:GetDescendants()) do
        if c:IsA("ValueBase") and table.find(HP_KEYS,c.Name) and type(c.Value)=="number" then return {o=c,t="val"}
        elseif c:IsA("TextLabel") and c.Text:match("([%d%.,]+[KkMmBbTt]?)%s*/%s*([%d%.,]+[KkMmBbTt]?)") then return {o=c,t="txt"} end
    end
end
function Eggs.readHp(src)
    if not src or not src.o.Parent then return nil end
    if src.t=="attr" then local v=src.o:GetAttribute(src.k) return type(v)=="number" and v or nil end
    if src.t=="val" then local v=src.o.Value return type(v)=="number" and v or nil end
    local a=src.o.Text:match("([%d%.,]+[KkMmBbTt]?)%s*/")
    return a and parseNum(a) or nil
end
function Eggs.zoneOf(inst)
    local o=inst
    while o and o~=workspace do
        for _,k in ipairs({"Zone","ZoneId","ZoneIndex"}) do
            local v=o:GetAttribute(k)
            if type(v)=="number" then return v end
            if type(v)=="string" and tonumber(v:match("%d+") or "") then return tonumber(v:match("%d+")) end
        end
        local n=o.Name:lower():match("zone%s*_?(%d+)")
        if n then return tonumber(n) end
        o=o.Parent
    end
end
function Eggs.label(egg)
    local model=Eggs.model[egg] or egg.Parent
    for _,k in ipairs({"EggName","EggType","Type","DisplayName"}) do
        local v=egg:GetAttribute(k) if v==nil and model then v=model:GetAttribute(k) end
        if type(v)=="string" and v~="" then return v end
    end
    return model and model.Name or "Egg"
end
function Eggs.scan()
    Eggs.hook()
    local out,seen,count={},{},0
    local roots={workspace:FindFirstChild("WorldRuntime"),workspace:FindFirstChild("MapNew"),workspace:FindFirstChild("Build")}
    local any=false
    local b=Base.obj
    local bm=b and (b:IsA("Model") or b:IsA("Folder")) and b or nil
    for ri,root in ipairs(roots) do
        if root then
            any=true
            for _,o in ipairs(root:GetDescendants()) do
                count+=1 if count>12000 then break end
                if (o:IsA("Model") or o:IsA("BasePart")) and o.Name:lower():find("egg",1,true) and not o.Name:lower():find("nest",1,true) then
                    local anc=o:FindFirstAncestorOfClass("Model")
                    local model=o:IsA("Model") and o or ((anc and anc.Name:lower():find("egg",1,true)) and anc) or o
                    if not seen[model] and not inChar(model) and not (bm and model:IsDescendantOf(bm)) then
                        local part=model:IsA("Model") and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart",true)) or model
                        if part and (ri==1 or Eggs.findHp(model)) then
                            seen[model]=true Eggs.model[part]=model out[#out+1]=part
                            if not Eggs.seen[model] then Eggs.seen[model]=true Eggs.seenCount+=1 end
                        end
                    end
                end
            end
        end
    end
    Eggs.err=(not any) and "Workspace.WorldRuntime / MapNew / Build not found (wrong map?)" or nil
    return out
end
function Eggs.get(force)
    local now=os.clock()
    if force or (Eggs.dirty and now-Eggs.at>2.5) or now-Eggs.at>12 then
        Eggs.cache,Eggs.at,Eggs.dirty=Eggs.scan(),now,false
    end
    return Eggs.cache
end

local Fly={active=false,conn=nil,bv=nil,bg=nil,character=nil,vertical=0,speed=65,keys={}}
local function flyDetach()
    if Fly.conn then Fly.conn:Disconnect() Fly.conn=nil end
    if Fly.bv then Fly.bv:Destroy() Fly.bv=nil end
    if Fly.bg then Fly.bg:Destroy() Fly.bg=nil end
    local hum=getHum()
    if hum then pcall(hum.ChangeState,hum,Enum.HumanoidStateType.GettingUp) end
    Fly.character=nil
end
local function flyAttach()
    flyDetach()
    if not Fly.active then return false,"Fly is disabled" end
    local char=Player.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local root=char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return false,"Character is not ready" end
    Fly.character=char
    local bv=Instance.new("BodyVelocity")
    bv.Name="CAZX_FlyVelocity" bv.MaxForce=Vector3.new(1e6,1e6,1e6) bv.P=2e4 bv.Velocity=Vector3.zero bv.Parent=root
    local bg=Instance.new("BodyGyro")
    bg.Name="CAZX_FlyGyro" bg.MaxTorque=Vector3.new(1e6,1e6,1e6) bg.P=2e4 bg.CFrame=root.CFrame bg.Parent=root
    Fly.bv,Fly.bg=bv,bg
    Fly.conn=RunService.Heartbeat:Connect(function()
        if not Fly.active or not root.Parent or not hum.Parent then flyDetach() return end
        local cam=workspace.CurrentCamera
        local move=hum.MoveDirection
        local horizontal=Vector3.zero
        if move.Magnitude>0 then horizontal=Vector3.new(move.X,0,move.Z).Unit*Fly.speed end
        local vertical=Fly.vertical
        if UIS:IsKeyDown(Enum.KeyCode.Space) then vertical=1
        elseif UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.C) then vertical=-1 end
        local flySpeed=math.clamp(tonumber(S.fly_speed) or 65,20,120)
        bv.Velocity=horizontal+Vector3.new(0,vertical*flySpeed,0)
        if cam then bg.CFrame=CFrame.lookAt(root.Position,root.Position+cam.CFrame.LookVector) end
        pcall(hum.ChangeState,hum,Enum.HumanoidStateType.Physics)
    end)
    return true
end
X.on.fly=function(on)
    Fly.active=on==true
    if not Fly.active then flyDetach() return true end
    local ok,why=flyAttach()
    if not ok then Fly.active=false return false,why end
    return true
end
Root.add(Player.CharacterAdded:Connect(function()
    if Fly.active then task.wait(.35) local ok,why=flyAttach() if not ok then Diag.set("fly","FAILED",why) end end
end))
local speedOriginal=nil
local speedChar=nil
local speedTask=nil
X.on.speed_boost=function(on)
    if speedTask then stopTask(speedTask) speedTask=nil end
    local hum=getHum()
    if not on then
        if hum and speedChar==Player.Character and speedOriginal then pcall(function() hum.WalkSpeed=speedOriginal end) end
        speedOriginal,speedChar=nil,nil
        Diag.set("speed","STOPPED","WalkSpeed restored when possible")
        return true
    end
    if not hum then return false,"No Humanoid (respawn first)" end
    speedOriginal,speedChar=hum.WalkSpeed,Player.Character
    local failures=0
    speedTask=Sched.add("speed-boost",.25,function()
        local h=getHum()
        if not h then Diag.set("speed","FAILED","Humanoid unavailable") return end
        if speedChar~=Player.Character then speedOriginal=h.WalkSpeed speedChar=Player.Character end
        local target=math.clamp(tonumber(S.speed_value) or 80,16,150)
        if math.abs(h.WalkSpeed-target)>1 then
            pcall(function() h.WalkSpeed=target end)
            failures+=1
            if failures>=8 then
                Diag.set("speed","SERVER-LIMITED","Game repeatedly overrides WalkSpeed; requested value is not confirmed")
                X.notify("Speed Boost is being overridden by the game","warn",4)
                stopTask(speedTask) speedTask=nil
            end
        else
            failures=0
            Diag.set("speed","RUNNING","WalkSpeed property matches "..target.."; actual movement still depends on game physics")
        end
    end)
    return true
end
local lowSaved=setmetatable({},{__mode="k"})
local lowConn=nil
local function applyLowObject(o,on)
    if on then
        if lowSaved[o]~=nil then return end
        if o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Beam") or o:IsA("Fire") or o:IsA("Smoke") or o:IsA("Sparkles") or o:IsA("PostEffect") then
            local ok,v=pcall(function() return o.Enabled end)
            if ok then lowSaved[o]=v pcall(function() o.Enabled=false end) end
        end
    else
        local old=lowSaved[o]
        if old~=nil and o.Parent then pcall(function() o.Enabled=old end) end
        lowSaved[o]=nil
    end
end
X.on.low_graphics=function(on)
    if lowConn then lowConn:Disconnect() lowConn=nil end
    if on then
        for _,o in ipairs(game:GetDescendants()) do applyLowObject(o,true) end
        lowConn=game.DescendantAdded:Connect(function(o) applyLowObject(o,true) end)
    else
        for o in pairs(lowSaved) do applyLowObject(o,false) end
    end
    Diag.set("graphics",on and "RUNNING" or "STOPPED",on and "Local visual effects disabled" or "Original effect states restored")
    return true
end
local function teleportToPosition(pos)
    local char=Player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false,"Character is not ready" end
    if typeof(pos)~="Vector3" then return false,"Invalid destination" end
    local origin=root.Position
    local before=(origin-pos).Magnitude
    root.CFrame=CFrame.new(pos+Vector3.new(0,4,0))
    task.wait(.35)
    root=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return false,"Character changed during teleport" end
    local after=(root.Position-pos).Magnitude
    local moved=(root.Position-origin).Magnitude
    if moved<2 and before>3 then return false,"Teleport did not move the character" end
    if after>before-2 and after>8 then return false,"Game/server reverted the teleport" end
    return true
end
local function teleportToEgg(name)
    name=tostring(name or ""):lower():gsub("^%s+",""):gsub("%s+$","")
    if name=="" then return false,"Enter an egg name first" end
    local matches={}
    for _,e in ipairs(Eggs.get(true)) do
        if inWorld(e) and Eggs.label(e):lower():find(name,1,true) then matches[#matches+1]=e end
    end
    if #matches==0 then return false,"No matching egg found: "..name end
    local root=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    table.sort(matches,function(a,b)
        if not root then return a:GetFullName()<b:GetFullName() end
        return (a.Position-root.Position).Magnitude<(b.Position-root.Position).Magnitude
    end)
    local target=matches[1]
    local ok,why=teleportToPosition(target.Position)
    if ok then Diag.set("teleport","SUCCESS","Moved near "..Eggs.label(target)) end
    return ok,why or ("Teleported near "..Eggs.label(target))
end
local E={target=nil,label="",hits=0,flat=0,lastHp=nil,src=nil,srcAt=0,since=0,moveAt=0,skip=setmetatable({},{__mode="k"}),lastPos=nil}
local function pickTarget(eggs,hrp)
    local filter,ignore=parseList(S.farm_filter),parseList(S.farm_ignore)
    local mode=S.farm_priority
    local maxD=S.farm_maxdist<2000 and S.farm_maxdist or math.huge
    local minRar=table.find(RAR,S.farm_minrar:lower()) or 0
    local zsel=tonumber(S.farm_zone)
    local now,best,bk=os.clock()
    for _,e in ipairs(eggs) do
        if inWorld(e) and not (E.skip[e] and E.skip[e]>now) then
            local name=Eggs.label(e)
            local idx,rn=rarityInfo(Eggs.model[e] or e,name)
            local ze=Eggs.zoneOf(Eggs.model[e] or e)
            local match=#filter==0 or labelHas(name:lower(),filter)
            local d=(e.Position-hrp.Position).Magnitude
            local ign=labelHas(name:lower(),ignore) or (rn~="unknown" and labelHas(rn,ignore))
            if not ign and (not zsel or ze==nil or ze==zsel) and d<=maxD and idx>=minRar and not (mode=="Selected only" and not match) then
                local key=d
                if mode=="Selected first" then key=(match and 0 or 1e6)+d elseif mode=="Highest rarity" then key=-idx*1e6+d end
                if not bk or key<bk then best,bk=e,key end
            end
        end
    end
    return best
end

local Sw={BASE=.7,WINDOW=6,mult=1,state="IDLE",tool="none",target="none",sent=0,sentV=0,unver=0,conf=0,lastSend=0,lastHit=0,cap=0,
    probing=false,verdict="Idle",effRate=0,nextProbe=0,win={t0=0,sentV=0,conf=0},verifiable=true}
local MULT_NAMES={"Normal Swing","Fast Swing","Faster Swing","Ultra Swing","Maximum Swing"}
function Sw.req() return Sw.BASE/Sw.mult end
function Sw.interval()
    if not Sw.verifiable and Sw.mult>1 then return Sw.BASE end
    if Sw.probing then return Sw.req() end
    return math.max(Sw.req(),Sw.cap)
end
function Sw.reset(now) Sw.win={t0=now or os.clock(),sentV=0,conf=0} end
function Sw.setMult(n)
    n=math.clamp(math.floor(n),1,5)
    Sw.mult,Sw.cap,Sw.effRate=n,0,0
    Sw.probing=n>1
    Sw.verdict=n>1 and "Measuring server response..." or "Normal speed (1x)"
    Sw.reset()
    if X.ui and X.ui.mult then pcall(X.ui.mult,n) end
end
function Sw.active() return (Sw.state=="SWINGING" or Sw.state=="PROBING") and os.clock()-Sw.lastSend<1.5 end
function Sw.confirm(now)
    Sw.conf+=1 Sw.win.conf+=1 Sw.lastHit=now
    if X.ui and X.ui.hit then pcall(X.ui.hit) end
end
function Sw.evaluate(now)
    local w=Sw.win
    local span=now-w.t0
    if span<Sw.WINDOW then return end
    if w.sentV>=4 then
        Sw.effRate=w.conf/span
        if Sw.probing then
            if Sw.effRate>=(1/Sw.req())*.85 then
                Sw.cap=0 Sw.verdict=("Achieved: server accepts ~%.1f hits/s"):format(Sw.effRate)
            else
                Sw.cap=math.clamp(1/math.max(Sw.effRate,.5),Sw.req(),1.2)
                Sw.verdict=("SERVER-LIMITED: ~%.1f hits/s accepted (about x%.1f)"):format(Sw.effRate,Sw.effRate*Sw.BASE)
            end
            Sw.probing,Sw.nextProbe=false,now+60
        end
    end
    if not Sw.probing and Sw.mult>1 and Sw.cap>0 and now>=Sw.nextProbe then Sw.probing=true Sw.verdict="Re-measuring server limit..." end
    Sw.reset(now)
end
function Sw.effMult() return Sw.effRate*Sw.BASE end

local function farmMode() return S.farm_auto and "farm" or (S.farm_break and "break" or nil) end
local function onBroken()
    Ses.broken+=1
    Ses.history[#Ses.history+1]={at=os.date("%H:%M:%S"),label=E.label,hits=E.hits}
    while #Ses.history>50 do table.remove(Ses.history,1) end
    Diag.set("farm","SUCCESS","egg broken: "..E.label)
    X.pkHint={pos=E.lastPos,untilT=os.clock()+40}
    if X.ui and X.ui.broken then pcall(X.ui.broken,E.label) end
    if X.event then X.event("egg","Egg broken",("**%s** broken in %d swing(s)"):format(E.label,E.hits),"good") end
end
local function farmTick(h,now)
    local mode=farmMode()
    if not mode then return end
    local char,hum=Player.Character,getHum()
    local hrp=char and char:FindFirstChild("HumanoidRootPart")
    if not hum or hum.Health<=0 or not hrp then Sw.state="RESPAWNING" E.target=nil return end
    if X.paused then Sw.state="PAUSED" return end
    local tool,_,eq=Tools.best()
    if not tool then Sw.state="NO PICKAXE" Sw.tool="none" h.interval=.5 Diag.set("swing","FAILED","no pickaxe detected") return end
    Sw.tool=tool.Name
    if not eq then
        if S.farm_equipmode=="Keep equipped" then Sw.state="NOT EQUIPPED" h.interval=.3 return end
        pcall(hum.EquipTool,hum,tool) Sw.state="EQUIPPING" h.interval=.3 return
    end
    h.interval=.03
    if E.target and not inWorld(E.target) then if E.hits>0 then onBroken() end E.target=nil end
    local reach=S.break_reach
    if not E.target then
        local cand={}
        local list=Eggs.get()
        for _,e in ipairs(list) do if inWorld(e) and (mode=="farm" or (e.Position-hrp.Position).Magnitude<=reach) then cand[#cand+1]=e end end
        local e=pickTarget(cand,hrp)
        if not e then Sw.state=(#list==0) and "NO EGGS" or "NO TARGET" Sw.target="none" h.interval=.4 return end
        E.target,E.hits,E.flat,E.lastHp,E.src,E.srcAt,E.label,E.since=e,0,0,nil,nil,0,Eggs.label(e),now
    end
    local e=E.target
    E.lastPos=e.Position
    Sw.target=E.label
    local d=(e.Position-hrp.Position).Magnitude
    if d>reach then
        if mode=="farm" then
            Sw.state="MOVING"
            if now-E.moveAt>.25 then E.moveAt=now hum:MoveTo(e.Position) end
            if now-E.since>25 then E.skip[e]=now+30 E.target=nil Diag.set("farm","RUNNING","skipped unreachable egg") end
        else E.target=nil end
        return
    end
    local model=Eggs.model[e] or e
    if not E.src and now-E.srcAt>.5 then E.src=Eggs.findHp(model) E.srcAt=now end
    local hp=Eggs.readHp(E.src)
    if hp==nil and E.src then E.src=nil end
    Sw.verifiable=hp~=nil
    if hp then
        if E.lastHp and hp<E.lastHp-1e-6 then Sw.confirm(now) E.flat=0 end
        E.lastHp=hp
    end
    if now-Sw.lastSend>3 then Sw.reset(now) end
    Sw.state=Sw.probing and "PROBING" or "SWINGING"
    if now-Sw.lastSend>=Sw.interval() then
        pcall(function() hrp.CFrame=CFrame.lookAt(hrp.Position,Vector3.new(e.Position.X,hrp.Position.Y,e.Position.Z)) end)
        local ok,err=pcall(tool.Activate,tool)
        if not ok then Diag.set("swing","FAILED",tostring(err)) Sw.state="ERROR" return end
        Sw.sent+=1 E.hits+=1 E.flat+=1 Sw.lastSend=now
        if hp then Sw.sentV+=1 Sw.win.sentV+=1 else Sw.unver+=1 end
        Diag.set("swing","RUNNING",Sw.verdict)
        if E.flat>=14 and hp then
            E.skip[e]=now+30 E.target=nil
            X.notify("Auto Break: "..E.label.." takes no damage, skipped 30s","warn",4)
        end
    end
    Sw.evaluate(now)
end
local farmH
local function farmSync()
    local want=farmMode()~=nil
    if want and not farmH then
        Diag.set("farm","STARTING")
        farmH=Sched.add("farm",.03,farmTick)
        farmH.onfail=function() farmH=nil Sw.state="IDLE" X.set("farm_auto",false,true) X.set("farm_break",false,true) end
        Sw.reset() Diag.set("farm","RUNNING")
    elseif not want and farmH then
        stopTask(farmH) farmH=nil E.target=nil Sw.state="IDLE" Sw.target="none"
        Diag.set("farm","STOPPED")
        local hum=getHum() if hum then pcall(hum.Move,hum,Vector3.zero) end
    end
end
X.on.farm_auto=function(v)
    if v and S.farm_break then S.farm_break=false if X.sync.farm_break then X.sync.farm_break(false) end end
    if v and not Tools.best() then S.farm_auto=false task.defer(farmSync) return false,"No pickaxe detected in Backpack/Character" end
    farmSync()
end
X.on.farm_break=function(v)
    if v and S.farm_auto then S.farm_auto=false if X.sync.farm_auto then X.sync.farm_auto(false) end end
    if v and not Tools.best() then S.farm_break=false task.defer(farmSync) return false,"No pickaxe detected in Backpack/Character" end
    farmSync()
end
X.on.swing_mult=function(v) Sw.setMult(v) X.notify(("Swing x%d requested: measuring server limit"):format(v),"info",3) end
X.on.farm_pause=function(v) X.paused=v end

local Pk={state="IDLE",status="OFF",target=nil,delivered=0,failed=0,unverified=0,since=0,list={},listAt=0,skip=setmetatable({},{__mode="k"}),conf="none"}
local function carryState()
    local char=Player.Character
    for _,o in ipairs({Player,char}) do
        if o then for k,v in pairs(o:GetAttributes()) do
            if k:lower():find("carr",1,true) then
                if v==true or (type(v)=="number" and v~=0) or (type(v)=="string" and v~="") or typeof(v)=="Instance" then return true,"attribute "..k,"game" end
                return false,"attribute "..k,"game"
            end
        end end
    end
    if char then for _,c in ipairs(char:GetChildren()) do
        if c:IsA("Model") then return true,"model "..c.Name,"heuristic" end
        if c:IsA("Tool") and not Tools.classify(c) and c.Name~="Bat" then return true,"tool "..c.Name,"heuristic" end
    end end
    return false,"no carry signal","heuristic"
end
local function findPickups()
    local out={}
    local root=workspace:FindFirstChild("WorldRuntime") or workspace
    for _,pp in ipairs(root:GetDescendants()) do
        if pp:IsA("ProximityPrompt") and pp.Enabled then
            local txt=(pp.ActionText.." "..pp.ObjectText.." "..pp.Name):lower()
            if txt:find("pick",1,true) or txt:find("grab",1,true) or txt:find("carry",1,true) then
                local model=pp:FindFirstAncestorOfClass("Model") or pp.Parent
                local part=pp.Parent and (pp.Parent:IsA("BasePart") and pp.Parent or pp.Parent:FindFirstChildWhichIsA("BasePart",true))
                if model and part and not inChar(model) then
                    local other=false
                    for _,k in ipairs(OWNER_KEYS) do local v=model:GetAttribute(k) if v~=nil and not isMine(v) and tostring(v)~="" and tostring(v)~="0" then other=true end end
                    if not other then out[#out+1]={prompt=pp,model=model,part=part} end
                end
            end
        end
    end
    return out
end
local function incomeOf(model)
    for _,o in ipairs({model,model.Parent}) do for _,k in ipairs({"Income","IncomePerSecond","CashPerSecond","Cps","Earn","Value"}) do
        local v=o and o:GetAttribute(k) if type(v)=="number" then return v end
    end end
end
local function doPickup(prompt)
    if typeof(fireproximityprompt)=="function" then return pcall(fireproximityprompt,prompt) end
    task.spawn(function() pcall(function() prompt:InputHoldBegin() task.wait(math.max(prompt.HoldDuration,.05)+.1) prompt:InputHoldEnd() end) end)
    return true
end
local guardCache={at=0,list={}}
local function guardNear(pos)
    local now=os.clock()
    if now-guardCache.at>5 then
        guardCache.at,guardCache.list=now,{}
        for _,g in ipairs(workspace:GetDescendants()) do
            if g:IsA("Model") then local n=g.Name:lower() if n:find("guard",1,true) or n:find("protector",1,true) then
                local gp=g.PrimaryPart or g:FindFirstChildWhichIsA("BasePart",true)
                if gp then guardCache.list[#guardCache.list+1]=gp end
            end end
        end
    end
    for _,gp in ipairs(guardCache.list) do if gp.Parent and (gp.Position-pos).Magnitude<25 then return true end end
    return false
end
local function pkTick(h,now)
    local char,hum=Player.Character,getHum()
    local hrp=char and char:FindFirstChild("HumanoidRootPart")
    if not hum or hum.Health<=0 or not hrp then
        if Pk.state~="IDLE" then Pk.failed+=1 Pk.status="RESPAWNING (target dropped)" end
        Pk.state,Pk.target="IDLE",nil return
    end
    if X.paused then Pk.status="PAUSED" return end
    local hint=X.pkHint
    local mode=S.steal_auto and "full" or "hint"
    if mode=="hint" and Pk.state=="IDLE" and not (hint and now<hint.untilT) then Pk.status="WAITING (break an egg first)" return end
    local base=Base.get(false) or Base.get(true)
    local bpos=base and instPos(base)
    local carrying,_,conf=carryState()
    if Pk.state=="IDLE" or Pk.state=="SCAN" then
        if carrying and conf=="game" then Pk.state,Pk.since="CARRY",now return end
        Pk.state="SCAN"
        if now-Pk.listAt>1.2 then Pk.list,Pk.listAt=findPickups(),now end
        local filt=parseList(S.steal_species)
        local minRar=table.find(RAR,S.steal_minrar:lower()) or 0
        local minInc=tonumber(S.steal_minincome) or 0
        local best,bk
        for _,c in ipairs(Pk.list) do
            if inWorld(c.part) and c.prompt.Enabled and not (Pk.skip[c.model] and Pk.skip[c.model]>now) then
                local label=c.model.Name
                local d=(c.part.Position-hrp.Position).Magnitude
                local idx=rarityInfo(c.model,label)
                local inc=incomeOf(c.model)
                local near=mode=="full" or (hint and hint.pos and (c.part.Position-hint.pos).Magnitude<=45)
                if near and (#filt==0 or labelHas(label:lower(),filt)) and idx>=minRar and (minInc<=0 or (inc and inc>=minInc))
                    and not (S.steal_guard and guardNear(c.part.Position)) then
                    local key=d
                    if S.steal_priority=="Highest rarity" then key=-idx*1e6+d elseif S.steal_priority=="Highest income" then key=-(inc or 0)*1e3+d end
                    if not bk or key<bk then best,bk=c,key end
                end
            end
        end
        if not best then Pk.status=mode=="hint" and "WAITING (no animal near the broken egg)" or "SCANNING (no valid animal)" return end
        Pk.target,Pk.state,Pk.since=best,"GOTO",now
        Pk.status="TARGET "..best.model.Name
        return
    end
    local t=Pk.target
    if Pk.state=="GOTO" then
        if not t or not inWorld(t.part) or not t.prompt.Enabled then Pk.state,Pk.target,Pk.status="SCAN",nil,"TARGET LOST" return end
        local dist=(t.part.Position-hrp.Position).Magnitude
        local reach=math.max((t.prompt.MaxActivationDistance or 10)-1.5,3)
        if dist>reach then
            Pk.status=("WALKING TO %s (%d studs)"):format(t.model.Name,math.floor(dist))
            hum:MoveTo(t.part.Position)
            if now-Pk.since>40 then Pk.skip[t.model]=now+30 Pk.state,Pk.target=("SCAN"),nil Pk.failed+=1 X.notify("Auto Steal: could not reach "..t.model.Name,"bad",3) end
            return
        end
        local ok,err=doPickup(t.prompt)
        if not ok then Pk.failed+=1 Pk.skip[t.model]=now+30 Pk.state,Pk.target="SCAN",nil Diag.err("steal","pickup failed: "..tostring(err)) return end
        Pk.state,Pk.since,Pk.status="CONFIRM",now,"PICKING UP "..t.model.Name
        return
    end
    if Pk.state=="CONFIRM" then
        if now-Pk.since<.4 then return end
        local c2,why2,conf2=carryState()
        if c2 then Pk.state,Pk.since,Pk.conf="CARRY",now,conf2 Pk.status="CARRYING "..t.model.Name.." ("..why2..")" return end
        if now-Pk.since>6 then
            Pk.skip[t.model]=now+30 Pk.failed+=1 Pk.state,Pk.target="SCAN",nil
            X.notify("Auto Steal: pickup not confirmed for "..t.model.Name,"bad",4)
        end
        return
    end
    if Pk.state=="CARRY" then
        if not bpos then Pk.status="NO BASE (cannot deliver)" return end
        local dist=(bpos-hrp.Position).Magnitude
        local c3,why3,conf3=carryState()
        if not c3 and now-Pk.since>1.5 then
            if dist<=40 then
                Pk.delivered+=1
                if conf3~="game" and Pk.conf~="game" then Pk.unverified+=1 end
                Ses.animals+=1 Ses.lastAnimal=Pk.target and Pk.target.model.Name or "animal"
                Pk.status="DELIVERED"
                X.notify("Auto Steal: delivered ("..why3..")","good",3)
            else
                Pk.failed+=1 Pk.status="LOST (dropped "..math.floor(dist).." studs from base)"
                X.notify("Auto Steal: animal lost before reaching base","bad",4)
            end
            Pk.state,Pk.target="IDLE",nil return
        end
        Pk.status=("DELIVERING (%d studs to base)"):format(math.floor(dist))
        hum:MoveTo(bpos)
        if now-Pk.since>45 then Pk.failed+=1 Pk.state,Pk.target="IDLE",nil X.notify("Auto Steal: delivery timed out","bad",4) end
    end
end
local pkH
local function pkSync()
    local want=S.steal_auto or S.farm_collect
    if want and not pkH then
        Pk.state,Pk.status="IDLE","STARTING"
        pkH=Sched.add("steal",.25,pkTick)
        pkH.onfail=function() pkH=nil Pk.status="FAILED" end
        Diag.set("steal","RUNNING")
    elseif not want and pkH then
        stopTask(pkH) pkH=nil Pk.state,Pk.target,Pk.status="IDLE",nil,"OFF"
        Diag.set("steal","STOPPED")
        local hum=getHum() if hum then pcall(hum.Move,hum,Vector3.zero) end
    end
end
X.on.steal_auto=function() pkSync() end
X.on.farm_collect=function() pkSync() end
function Pk.carrying() return Pk.state=="GOTO" or Pk.state=="CONFIRM" or Pk.state=="CARRY" end

local function petWatch()
    local bag=newMaid() Root.add(bag.clean)
    local seen=setmetatable({},{__mode="k"})
    local ignoreUntil=0
    local function onTool(t)
        if not t:IsA("Tool") or seen[t] then return end
        seen[t]=true
        if os.clock()<ignoreUntil or t.Name=="Bat" or Tools.classify(t) then return end
        local idx,rl=rarityInfo(t,t.Name)
        Ses.animals+=1 Ses.lastAnimal=t.Name..(idx>0 and (" ["..rl.."]") or "")
        Ses.pets[#Ses.pets+1]={at=os.date("%H:%M:%S"),name=t.Name,rarity=rl,idx=idx}
        while #Ses.pets>100 do table.remove(Ses.pets,1) end
        Ses.petCounts[t.Name]=(Ses.petCounts[t.Name] or 0)+1 Ses.petTotal+=1
        if idx>Ses.bestIdx or Ses.bestName=="none" then Ses.bestIdx,Ses.bestName=idx,t.Name..(idx>0 and (" ("..rl..")") or "") end
        local rare=idx>0 and idx>=(table.find(RAR,S.pet_rare_min) or #RAR)
        if S.pet_alert then X.notify("New pet: "..t.Name..(idx>0 and (" ["..rl.."]") or ""),rare and "good" or "info",3) end
        if S.wh_enable and S.wh_ev_pet and WH.url~="" and X.petCollect and (Ses.lastPetName~=t.Name or os.clock()-(Ses.lastPetAt or 0)>.75) then
            local okI,info=pcall(X.petCollect,t,idx,rl)
            if okI then X.petEvent(info,false) else Diag.err("webhook",info) end
        end
        Ses.lastPetName,Ses.lastPetAt=t.Name,os.clock()
    end
    local bm=newMaid() bag.add(bm.clean)
    local function hook(c,cm) if not c then return end for _,t in ipairs(c:GetChildren()) do seen[t]=true end cm.add(c.ChildAdded:Connect(onTool)) end
    local function hookBp() bm.clean() ignoreUntil=os.clock()+1.5 hook(Player:FindFirstChild("Backpack"),bm) end
    hookBp()
    bag.add(Player.ChildAdded:Connect(function(c) if c.Name=="Backpack" then hookBp() end end))
    onChar(bag,function(c,cm) ignoreUntil=os.clock()+1.5 hook(c,cm) end)
end

local WH={url="",state="BELUM DIATUR",kind="warn",detail="URL belum diisi",sent=0,failed=0,lastAt=0,queue={},pumping=false}
local function whValidate(u)
    if type(u)~="string" then return false,"URL kosong" end
    u=u:match("^%s*(.-)%s*$")
    if u=="" then return false,"URL kosong" end
    local host=u:match("^https://([%w%.]+)/api/webhooks/%d+/[%w%-_]+$") or u:match("^https://([%w%.]+)/api/v%d+/webhooks/%d+/[%w%-_]+$")
    if not host then return false,"Bukan URL webhook Discord" end
    if host~="discord.com" and host~="discordapp.com" and host~="ptb.discord.com" and host~="canary.discord.com" then return false,"Host harus discord.com" end
    return true,u
end
local function whPost(payload)
    if not HTTP_REQUEST then return false,"No HTTP request function in this executor" end
    local ok,url=whValidate(WH.url) if not ok then return false,url end
    local okE,body=pcall(HttpService.JSONEncode,HttpService,payload) if not okE then return false,"Payload encode failed" end
    local okR,res=pcall(HTTP_REQUEST,{Url=url,Method="POST",Headers={["Content-Type"]="application/json"},Body=body})
    if not okR then return false,"Request error: "..tostring(res) end
    if type(res)~="table" then return false,"No response" end
    local code=res.StatusCode or res.status_code
    if type(code)=="number" and code>=200 and code<300 then return true,"HTTP "..code end
    if code==429 then return false,"Rate limited (HTTP 429)",true end
    if code==401 or code==404 then return false,("Webhook rejected (HTTP %d)"):format(code) end
    return false,"HTTP "..tostring(code or "?")
end
local EMBED={info=0x22D3EE,good=0x34D399,warn=0xFBBF24,bad=0xF43F5E}
local function whEmbed(title,desc,kind,fields,extra)
    extra=extra or {}
    local e={author={name=Player.DisplayName.." (@"..Player.Name..")"},title=title,description=desc,color=extra.color or EMBED[kind or "info"],fields=fields,
        footer={text="CAZIELX ARCHX | "..X.game.name.." | v"..X.VERSION},timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ")}
    if extra.icon then e.author.icon_url=extra.icon end
    if extra.thumb then e.thumbnail={url=extra.thumb} end
    return {username="CAZIELX ARCHX",embeds={e}}
end
local function whPump()
    if WH.pumping then return end
    WH.pumping=true
    task.spawn(function()
        while alive and #WH.queue>0 do
            local w=2-(os.clock()-WH.lastAt)
            if w>0 then task.wait(w) end
            local item=table.remove(WH.queue,1)
            WH.lastAt=os.clock()
            local ok,why,limited=whPost(item)
            if ok then WH.sent+=1 WH.state,WH.kind,WH.detail="CONNECTED","good",why.." @ "..os.date("%H:%M:%S")
            else WH.failed+=1 WH.state,WH.kind,WH.detail=limited and "RATE LIMITED" or "ERROR","bad",tostring(why) if limited then task.wait(5) end end
        end
        WH.pumping=false
    end)
end
function X.event(ev,title,desc,kind,fields,extra,force)
    if WH.url=="" then return false end
    if not force and (not S.wh_enable or S["wh_ev_"..ev]==false) then return false end
    while #WH.queue>=10 do table.remove(WH.queue,1) end
    WH.queue[#WH.queue+1]=whEmbed(title,desc,kind,fields,extra) whPump() return true
end
local function whSave()
    local ok,u=whValidate(WH.url) if not ok then return false,u end
    if not HAS_FILES then return false,"No file API: URL kept for this session only" end
    local okW,err=pcall(writefile,WEBHOOK_FILE,HttpService:JSONEncode({v=1,url=u}))
    if not okW then return false,"File write failed: "..tostring(err) end
    return true
end
local function whLoad()
    if not HAS_FILES then return false,"No file API" end
    local ok,ex=pcall(isfile,WEBHOOK_FILE) if not ok or not ex then return false,"No saved webhook" end
    local okR,c=pcall(readfile,WEBHOOK_FILE) if not okR then return false,"Read failed" end
    local okD,d=pcall(HttpService.JSONDecode,HttpService,c)
    if not okD or type(d)~="table" then return false,"Saved webhook file is corrupt" end
    local v,u=whValidate(d.url) if not v then return false,"Saved URL invalid: "..tostring(u) end
    WH.url=u WH.state,WH.kind,WH.detail="LOADED","warn","not tested yet" return true
end
local function summaryFields()
    return {{name="Session",value=fmtDur(os.clock()-X.t0),inline=true},{name="Eggs broken",value=tostring(Ses.broken),inline=true},
        {name="Animals",value=tostring(Ses.animals),inline=true},{name="Earnings",value=shortNum(Ses.earn),inline=true},{name="Best pet",value=Ses.bestName,inline=true}}
end

local Esp={ents={},gui=nil,h=nil}
local ESP_COL={Cyan=Color3.fromRGB(34,211,238),Red=Color3.fromRGB(244,63,94),Green=Color3.fromRGB(52,211,153),Yellow=Color3.fromRGB(251,191,36),White=Color3.fromRGB(240,244,250)}
local FILL={Off=1,Soft=.82,Strong=.55}
local function espDrop(key) local e=Esp.ents[key] if e then pcall(e.hl.Destroy,e.hl) pcall(e.bb.Destroy,e.bb) Esp.ents[key]=nil end end
local function espEnt(key,model,part)
    local e=Esp.ents[key]
    if e and e.hl.Parent and e.part==part then return e end
    espDrop(key)
    local hl=Instance.new("Highlight") hl.Adornee=model hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop hl.Parent=Esp.gui
    local bb=Instance.new("BillboardGui") bb.Adornee=part bb.Size=UDim2.fromOffset(170,30) bb.StudsOffset=Vector3.new(0,3,0) bb.AlwaysOnTop=true bb.ResetOnSpawn=false bb.Parent=Esp.gui
    local l=Instance.new("TextLabel") l.BackgroundTransparency=1 l.Size=UDim2.fromScale(1,1) l.Font=Enum.Font.GothamBold l.TextSize=12 l.TextStrokeTransparency=.4 l.Parent=bb
    e={hl=hl,bb=bb,lbl=l,part=part} Esp.ents[key]=e return e
end
local function espRefresh()
    if not (S.esp_egg or S.esp_pet or S.esp_player) then return end
    local hrp=Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local col,fill,range=ESP_COL[S.esp_color] or ESP_COL.Cyan,FILL[S.esp_fill] or .82,S.esp_range
    local want={}
    if S.esp_player or S.esp_pet then
        local n=0
        for _,pl in ipairs(Players:GetPlayers()) do
            local ch=pl~=Player and pl.Character
            local part=ch and (ch:FindFirstChild("Head") or ch:FindFirstChild("HumanoidRootPart"))
            if part and n<12 then
                local d=(part.Position-hrp.Position).Magnitude
                if d<=range then
                    local carry
                    if S.esp_pet then for _,c in ipairs(ch:GetChildren()) do if c:IsA("Tool") and not Tools.classify(c) and c.Name~="Bat" then carry=c.Name break end end end
                    if S.esp_player or carry then
                        n+=1
                        local key="p"..pl.UserId want[key]=true
                        local e=espEnt(key,ch,part)
                        e.hl.Enabled=S.esp_player e.hl.FillColor,e.hl.OutlineColor,e.hl.FillTransparency=col,col,fill
                        local txt=S.esp_player and pl.DisplayName or ""
                        if S.esp_dist and S.esp_player then txt..=(" · %dm"):format(math.floor(d)) end
                        if carry then txt..=((txt~="" and "\n" or "").."carrying "..carry) end
                        e.lbl.Text,e.lbl.TextColor3=txt,col
                    end
                end
            end
        end
    end
    if S.esp_egg then
        local list={}
        for _,e in ipairs(Eggs.get()) do if inWorld(e) then local d=(e.Position-hrp.Position).Magnitude if d<=range then list[#list+1]={e,d} end end end
        table.sort(list,function(a,b) return a[2]<b[2] end)
        for i=1,math.min(#list,15) do
            local egg,d=list[i][1],list[i][2]
            local model=Eggs.model[egg] or egg
            local key="e"..tostring(egg) want[key]=true
            local en=espEnt(key,model,egg)
            en.hl.Enabled=true en.hl.FillColor,en.hl.OutlineColor,en.hl.FillTransparency=col,col,fill
            local nm=Eggs.label(egg) local _,rn=rarityInfo(model,nm)
            local txt=nm..(rn~="unknown" and (" ["..rn.."]") or "")
            if S.esp_dist then txt..=(" · %dm"):format(math.floor(d)) end
            en.lbl.Text,en.lbl.TextColor3=txt,col
        end
    end
    for key in pairs(Esp.ents) do if not want[key] then espDrop(key) end end
end
local function espSync()
    local on=S.esp_egg or S.esp_pet or S.esp_player
    if on and not Esp.h then
        if not Esp.gui then Esp.gui=Instance.new("ScreenGui") Esp.gui.Name="CAZX_ESP" Esp.gui.ResetOnSpawn=false Esp.gui.Parent=PlayerGui Root.add(Esp.gui) end
        Esp.h=Sched.add("esp",S.perf_mode and .6 or .25,espRefresh)
        Esp.h.onfail=function() Esp.h=nil Diag.set("esp","FAILED","auto-stopped") end
        Diag.set("esp","RUNNING")
    elseif not on and Esp.h then
        stopTask(Esp.h) Esp.h=nil
        for k in pairs(Esp.ents) do espDrop(k) end
        Diag.set("esp","STOPPED")
    end
end
for _,k in ipairs({"esp_egg","esp_pet","esp_player"}) do X.on[k]=espSync end
X.on.perf_mode=function(v) if Esp.h then Esp.h.interval=v and .6 or .25 end end
Root.add(function() for k in pairs(Esp.ents) do espDrop(k) end end)
Root.add(Players.PlayerRemoving:Connect(function(p) espDrop("p"..p.UserId) end))

X.on.anti_afk=function(v)
    if X.afk then X.afk:Disconnect() X.afk=nil end
    if v then X.afk=Player.Idled:Connect(function() pcall(function() VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end) end) end
    Diag.set("anti_afk",v and "RUNNING" or "STOPPED")
end
Root.add(function() if X.afk then X.afk:Disconnect() X.afk=nil end end)
local function zoneNow()
    for _,o in ipairs({Player,Player.Character}) do
        if o then for _,k in ipairs({"Zone","ZoneId","CurrentZone","ZoneIndex"}) do local v=o:GetAttribute(k) if v~=nil then return tostring(v) end end end
    end
    if E.target then local z=Eggs.zoneOf(Eggs.model[E.target] or E.target) if z then return tostring(z) end end
    return "Unknown"
end
local function activeCount()
    local n=0
    for _,k in ipairs({"farm_auto","farm_break","farm_collect","steal_auto","esp_egg","esp_pet","esp_player","wh_enable","anti_afk"}) do if S[k] then n+=1 end end
    return n
end
local function ping()
    local ok,v=pcall(function() return StatsSvc.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    return ok and math.floor(v) or nil
end
-- =====================================================================
-- CX CONFIG TERPUSAT (edit hanya di bagian ini)
-- Catatan keamanan: isi file Lua dapat dibaca siapa pun yang memegang source.
-- Key di bawah hanya gerbang klien. Autentikasi sungguhan = verifikasi server
-- (BACKEND_URL) dengan secret yang TIDAK ada di client (lihat BACKEND_SPEC).
-- =====================================================================
local CX_CONFIG={
    DEV_NAME="yyy46366",
    CLOUD_URL="https://laxzyx-53d9d-default-rtdb.asia-southeast1.firebasedatabase.app",
    BACKEND_URL="",
    STAFF_LOCAL={},
}
local CX_CREDENTIAL={      -- jangan dipakai di UI/log/preset/webhook. Ganti nilainya sesuai keinginan.
    DEV_KEY="cipaayy",
    ADMIN_KEY="",
    MOD_KEY="",
    CLOUD_WRITE_AUTH="",   -- HARUS KOSONG di client; gunakan backend tepercaya
}
local Cred={}
do
    local KEYS={dev=CX_CREDENTIAL.DEV_KEY,admin=CX_CREDENTIAL.ADMIN_KEY,moderator=CX_CREDENTIAL.MOD_KEY}
    local WAUTH=CX_CREDENTIAL.CLOUD_WRITE_AUTH
    CX_CREDENTIAL=nil -- tidak ada referensi tersisa selain closure Cred.verify
    local function ctEq(a,b)
        a,b=tostring(a),tostring(b)
        local diff=(#a~=#b) and 1 or 0
        for i=1,math.max(#a,#b) do diff=bit32.bor(diff,bit32.bxor(a:byte(i) or 0,b:byte(i) or 0)) end
        return diff==0
    end
    function Cred.cloudAuth(role) -- hanya Developer/Admin yang boleh menulis
        if (role=="dev" or role=="admin") and type(WAUTH)=="string" and WAUTH~="" then return WAUTH end
        return nil
    end
    function Cred.verify(role,key)
        local k=KEYS[role]
        return type(k)=="string" and k~="" and ctEq(k,key)
    end
end
local DEV_NAME=CX_CONFIG.DEV_NAME:lower()
local DEFAULT_BACKEND=CX_CONFIG.BACKEND_URL
local SCHEMA=5
local ROLE_RANK={user=1,vip=2,moderator=3,admin=4,dev=5}
local ROLE_LIST={"user","vip","moderator","admin","dev"}
local PERM={ban=3,blacklist=3,unban=3,kick=3,delpreset=3,delann=3,users=3,logs=3,saveann=4,setrole=5}
local DEV_ONLY={setrole=true,sysconfig=true,rolecfg=true} -- hanya Developer (login + username dev)
local DUR_OPTS={{"1 menit",60},{"10 menit",600},{"1 jam",3600},{"1 hari",86400},{"1 minggu",604800},{"2 minggu",1209600},{"30 hari",2592000},{"Permanen",0}}
local ANN_CATS={"Info","Update","Event","Maintenance","Peringatan"}
local STORE_FILE,BACKEND_FILE="CAZIELX_ARCHX_store.json","CAZIELX_ARCHX_backend.json"
local Store,Net,Auth,Users,Presets,Ann,Adm,Sync,Guard,Avatar={},{},{},{},{},{},{},{},{},{}
local Clock={skew=0}
local function nowT() return os.time()+Clock.skew end
local function fmtLeft(s)
    s=math.max(0,math.floor(s))
    if s>=86400 then return ("%d hari %d jam"):format(s//86400,(s%86400)//3600) end
    if s>=3600 then return ("%d jam %d mnt"):format(s//3600,(s%3600)//60) end
    if s>=60 then return ("%d mnt %d dtk"):format(s//60,s%60) end
    return s.." dtk"
end
local function fmtDate(t) return os.date("%d/%m/%Y %H:%M",tonumber(t) or 0) end
local function hashStr(s)
    local a,b=5381,52711
    for i=1,#s do local c=s:byte(i) a=(a*33+c)%4294967296 b=(b*131+c+i)%4294967296 end
    return ("%08x%08x"):format(a,b)
end
local function canon(v)
    if type(v)~="table" then return tostring(v) end
    local keys={}
    for k in pairs(v) do keys[#keys+1]=tostring(k) end
    table.sort(keys)
    local o={}
    for _,k in ipairs(keys) do o[#o+1]=k.."="..canon(v[k]) end
    return "{"..table.concat(o,",").."}"
end
local function trim(s) return (tostring(s or ""):match("^%s*(.-)%s*$")) end
local function genId(prefix) return prefix..nowT().."-"..math.random(1000,9999) end

local function storeDefault()
    return {v=1,lp={},cp={},la={},ca={},fav={},seen={},users={},bans={},logs={},active=nil}
end
function Store.load()
    local d
    if HAS_FILES then
        local ok,ex=pcall(isfile,STORE_FILE)
        if ok and ex then
            local ok2,raw=pcall(readfile,STORE_FILE)
            if ok2 then
                local ok3,dec=pcall(HttpService.JSONDecode,HttpService,raw)
                if ok3 and type(dec)=="table" then d=dec end
            end
        end
    end
    d=d or X.memStore or {}
    for k,v in pairs(storeDefault()) do if type(d[k])~=type(v) and v~=nil then d[k]=v end end
    Store.d=d
end
function Store.save()
    if not Store.d then return false end
    X.memStore=Store.d
    if not HAS_FILES then return false end
    local ok,json=pcall(HttpService.JSONEncode,HttpService,Store.d)
    if not ok then Diag.err("store",json) return false end
    local ok2,err=pcall(writefile,STORE_FILE,json)
    if not ok2 then Diag.err("store","write: "..tostring(err)) end
    return ok2
end
Store.d=storeDefault()
function Store.touch() Store.dirty=os.clock() end
local function logAct(action,target,detail)
    local L=Store.d.logs
    L[#L+1]={t=nowT(),by=Player.Name,a=action,to=target or "-",d=detail or ""}
    while #L>120 do table.remove(L,1) end
    Store.touch()
end

Net.url=""
Net.token=nil
Net.role="user"
Net.state,Net.kind,Net.detail="LOKAL","warn","backend belum diatur"
Net.fails=0
Net.rev={p=-1,a=-1}
function Net.validate(u)
    u=trim(u):gsub("/+$","")
    if u=="" then return false,"URL kosong" end
    if not u:match("^https://[%w%.%-]+") or u:find("%s") then return false,"URL harus diawali https:// dan valid" end
    return true,u
end
function Net.loadFile()
    local u=DEFAULT_BACKEND
    if HAS_FILES then
        local ok,ex=pcall(isfile,BACKEND_FILE)
        if ok and ex then
            local ok2,raw=pcall(readfile,BACKEND_FILE)
            if ok2 then
                local ok3,d=pcall(HttpService.JSONDecode,HttpService,raw)
                if ok3 and type(d)=="table" and type(d.url)=="string" then u=d.url end
            end
        end
    end
    if u~="" then
        local ok,v=Net.validate(u)
        if ok then Net.url=v Net.state,Net.kind,Net.detail="MENGHUBUNGKAN","warn","belum ada respons" end
    end
end
function Net.saveFile()
    if not HAS_FILES then return false,"File API tidak tersedia; URL hanya untuk sesi ini" end
    local ok,err=pcall(writefile,BACKEND_FILE,HttpService:JSONEncode({v=1,url=Net.url}))
    if not ok then return false,tostring(err) end
    return true
end
function Net.call(path,body,auth)
    if Net.url=="" then return false,"backend belum diatur" end
    if not HTTP_REQUEST then return false,"executor tidak punya fungsi HTTP" end
    local payload=body or {}
    payload.userId,payload.username=Player.UserId,Player.Name
    local okE,json=pcall(HttpService.JSONEncode,HttpService,payload)
    if not okE then return false,"gagal encode data" end
    local headers={["Content-Type"]="application/json",["X-CX-User"]=tostring(Player.UserId),["X-CX-Client"]="CAZIELX-ARCHX/"..X.VERSION}
    if auth and Net.token then headers["X-CX-Token"]=Net.token end
    local last="gagal"
    for attempt=1,3 do
        if not alive then return false,"dibatalkan" end
        local okR,res=pcall(HTTP_REQUEST,{Url=Net.url..path,Method="POST",Headers=headers,Body=json})
        if okR and type(res)=="table" then
            local code=res.StatusCode or res.status_code
            if type(code)=="number" and code>=200 and code<300 then
                local okD,data=pcall(HttpService.JSONDecode,HttpService,res.Body or "")
                if okD and type(data)=="table" then
                    Net.fails=0
                    Net.state,Net.kind,Net.detail="ONLINE","good","OK "..os.date("%H:%M:%S")
                    if type(data.serverTime)=="number" then Clock.skew=data.serverTime-os.time() end
                    return true,data
                end
                last="respons bukan JSON"
                break
            end
            last="HTTP "..tostring(code)
            if code==401 or code==403 then
                if auth then Net.token=nil Auth.logged=false end
                return false,last,code
            end
            if type(code)=="number" and code>=400 and code<500 and code~=429 then return false,last,code end
        else
            last=okR and "tidak ada respons" or tostring(res)
        end
        task.wait(attempt*1.5)
    end
    Net.fails+=1
    Net.state,Net.kind,Net.detail="OFFLINE","bad",last
    return false,last
end

-- Long-poll satu kali (tanpa retry internal): server menahan request sampai ada perubahan atau timeout.
function Net.poll(path,body)
    if Net.url=="" then return false,"backend belum diatur" end
    if not HTTP_REQUEST then return false,"executor tidak punya fungsi HTTP" end
    local payload=body or {}
    payload.userId,payload.username=Player.UserId,Player.Name
    local okE,json=pcall(HttpService.JSONEncode,HttpService,payload)
    if not okE then return false,"gagal encode data" end
    local headers={["Content-Type"]="application/json",["X-CX-User"]=tostring(Player.UserId),["X-CX-Client"]="CAZIELX-ARCHX/"..X.VERSION}
    local okR,res=pcall(HTTP_REQUEST,{Url=Net.url..path,Method="POST",Headers=headers,Body=json})
    if not okR or type(res)~="table" then return false,okR and "tidak ada respons" or tostring(res) end
    local code=res.StatusCode or res.status_code
    if type(code)~="number" or code<200 or code>=300 then return false,"HTTP "..tostring(code) end
    local okD,data=pcall(HttpService.JSONDecode,HttpService,res.Body or "")
    if not okD or type(data)~="table" then return false,"respons bukan JSON" end
    if type(data.serverTime)=="number" then Clock.skew=data.serverTime-os.time() end
    return true,data
end

Auth.isDev=Player.Name:lower()==DEV_NAME
Auth.role="user"
Auth.logged=false
Auth.mode="none"
Auth.fails=0
Auth.lockUntil=0
Auth.prompted=false
-- Role yang butuh key, berdasarkan identitas akun (bukan input). User/VIP => nil (tanpa key).
function Auth.claimRole()
    if Auth.isDev then return "dev" end
    local r=Net.role
    if Net.url=="" then r=CX_CONFIG.STAFF_LOCAL[Player.UserId] end
    if r=="admin" or r=="moderator" then return r end
    return nil
end
function Auth.needsKey() return (not Auth.logged) and Auth.claimRole()~=nil end
function Auth.staffVisible() return Auth.logged or Auth.claimRole()~=nil end
function Auth.can(action)
    if not Auth.logged then return false end
    if DEV_ONLY[action] then return Auth.isDev and Auth.role=="dev" end
    return (ROLE_RANK[Auth.role] or 1)>=(PERM[action] or 99)
end
function Auth.login(key)
    key=tostring(key or "")
    if key=="" then return false,"Key kosong" end
    if os.clock()<Auth.lockUntil then return false,"Terlalu banyak percobaan, tunggu "..math.ceil(Auth.lockUntil-os.clock()).." dtk" end
    local claim=Auth.claimRole()
    if not claim then return false,"Akun ini bukan staf, key tidak diperlukan" end
    local function failed(msg)
        Auth.fails+=1
        if Auth.fails>=5 then Auth.fails=0 Auth.lockUntil=os.clock()+60 end
        return false,msg
    end
    local role
    if Net.url~="" then
        local ok,res=Net.call("/admin/login",{key=key,claim=claim})
        if not ok then return failed("Login ditolak: "..tostring(res)) end
        if type(res.token)~="string" or res.token=="" then return failed("Backend tidak mengirim token") end
        role=res.role
        if role=="dev" and not Auth.isDev then return failed("Role tidak valid untuk akun ini") end
        if role~="dev" and role~="admin" and role~="moderator" then return failed("Akun tidak punya role staf di server") end
        Net.token=res.token
        Auth.mode="backend"
    else
        if not Cred.verify(claim,key) then return failed("Key salah") end
        role=claim
        Auth.mode="lokal"
    end
    Auth.role,Auth.logged,Auth.fails=role,true,0
    logAct("login",Player.Name,Auth.mode.." "..role)
    return true,"Login berhasil sebagai "..role
end
function Auth.logout() Auth.logged=false Auth.mode="none" Auth.role="user" Net.token=nil end

function Users.self(first)
    local d=Store.d
    local k=tostring(Player.UserId)
    local u=d.users[k] or {id=Player.UserId,first=nowT(),role="user",sessions=0}
    u.id,u.name,u.display,u.last=Player.UserId,Player.Name,Player.DisplayName,nowT()
    if first then u.sessions=(u.sessions or 0)+1 end
    if Auth.isDev then u.role="dev" end
    d.users[k]=u
    Store.touch()
    return u
end
function Users.banOf(uid)
    local k=tostring(uid)
    local b=Store.d.bans[k]
    if b and (tonumber(b.exp) or 0)>0 and b.exp<=nowT() then Store.d.bans[k]=nil Store.touch() return nil end
    return b
end
function Users.resolve(txt)
    txt=trim(txt)
    if txt=="" then return nil,"Isi username atau UserId" end
    local id=tonumber(txt)
    if id then
        id=math.floor(id)
        local u=Store.d.users[tostring(id)]
        if u and u.name then return id,u.name end
        local ok,name=pcall(Players.GetNameFromUserIdAsync,Players,id)
        if ok and name then return id,name end
        return nil,"UserId tidak ditemukan"
    end
    local clean=txt:gsub("^@","")
    for _,u in pairs(Store.d.users) do
        if type(u)=="table" and u.name and u.name:lower()==clean:lower() then return u.id,u.name end
    end
    local ok,id2=pcall(Players.GetUserIdFromNameAsync,Players,clean)
    if ok and id2 then return id2,clean end
    return nil,"Username tidak ditemukan"
end

local FEATURES={{"farm_auto","Auto Farm"},{"farm_break","Auto Break"},{"farm_collect","Auto Collect"},{"steal_auto","Auto Steal"},{"steal_guard","Steal Guard"},{"fly","Fly"},{"speed_boost","Speed Boost"},{"low_graphics","Low Graphics"},{"esp_egg","Egg ESP"},{"esp_pet","Pet ESP"},{"esp_player","Player ESP"},{"anti_afk","Anti-AFK"},{"pet_alert","Peringatan Pet"},{"perf_mode","Mode Performa"}}
local RUNTIME_KEYS={"farm_auto","farm_break","farm_collect","steal_auto","fly","speed_boost","low_graphics"}
function Presets.shareable(k) return D[k]~=nil and not k:find("^wh_") and not k:find("^about_") and k~="auto_save" and k~="farm_pause" end
function Presets.src() return Net.url~="" and Store.d.cp or Store.d.lp end
function Presets.make(name,desc)
    local st={}
    for k,v in pairs(S) do if Presets.shareable(k) then st[k]=v end end
    local on,off={},{}
    for _,f in ipairs(FEATURES) do if st[f[1]] then on[#on+1]=f[2] else off[#off+1]=f[2] end end
    return {id="",name=name,desc=desc,uid=Player.UserId,by=Player.Name,display=Player.DisplayName,at=nowT(),rev=1,schema=SCHEMA,game=X.game.name,on=on,off=off,settings=st,hash=hashStr(canon(st))}
end
function Presets.validate(p)
    if type(p)~="table" or type(p.settings)~="table" then return "bad","Struktur preset rusak",{},0 end
    if (tonumber(p.schema) or 0)>SCHEMA then return "bad","Preset dari versi script lebih baru (schema "..tostring(p.schema)..")",{},0 end
    local clean,ignored,n={},0,0
    for k,v in pairs(p.settings) do
        if type(k)=="string" and Presets.shareable(k) and type(v)==type(D[k]) and v==v then
            if k=="swing_mult" then v=math.clamp(math.floor(v),1,5)
            elseif k=="ui_scale" then v=math.clamp(v,.8,1.2)
            elseif k=="break_reach" then v=math.clamp(v,4,30)
            elseif k=="fly_speed" then v=math.clamp(v,20,120)
            elseif k=="speed_value" then v=math.clamp(v,16,150)
            elseif type(v)=="string" then v=v:sub(1,120) end
            clean[k]=v n+=1
        else ignored+=1 end
    end
    if n==0 then return "bad","Preset kosong atau tidak ada pengaturan yang cocok",clean,ignored end
    local other=type(p.game)=="string" and p.game~="Universal" and p.game~=X.game.name
    if ignored>0 or other then
        local parts={}
        if ignored>0 then parts[#parts+1]=ignored.." pengaturan tidak dikenal akan dilewati" end
        if other then parts[#parts+1]="dibuat untuk game: "..p.game end
        return "partial",table.concat(parts,"; "),clean,ignored
    end
    return "ok","Kompatibel",clean,0
end
function Presets.apply(p)
    local st,msg,clean=Presets.validate(p)
    if st=="bad" then return false,msg end
    local act=Store.d.active
    local prev=(act and act.prev) or {}
    for k in pairs(clean) do if prev[k]==nil then prev[k]=S[k] end end
    Store.d.active={id=p.id,name=p.name,by=p.by,at=nowT(),prev=prev}
    Store.touch()
    local okN,total=0,0
    local order={}
    for k in pairs(clean) do if not table.find(RUNTIME_KEYS,k) then order[#order+1]=k end end
    table.sort(order)
    for _,k in ipairs(RUNTIME_KEYS) do if clean[k]~=nil then order[#order+1]=k end end
    for _,k in ipairs(order) do
        total+=1
        X.set(k,clean[k],false)
        if S[k]==clean[k] then okN+=1 end
    end
    X.dirty=os.clock()
    logAct("preset_pakai",p.name,okN.."/"..total)
    if X.presetsChanged then X.presetsChanged() end
    return true,("Preset '%s' diterapkan: %d/%d pengaturan"):format(p.name,okN,total)
end
function Presets.release()
    local act=Store.d.active
    if not act then return false,"Tidak ada preset yang sedang dipakai" end
    local n=0
    local order={}
    for k in pairs(act.prev or {}) do if not table.find(RUNTIME_KEYS,k) then order[#order+1]=k end end
    table.sort(order)
    for _,k in ipairs(RUNTIME_KEYS) do if act.prev and act.prev[k]~=nil then order[#order+1]=k end end
    for _,k in ipairs(order) do
        if D[k]~=nil and type(act.prev[k])==type(D[k]) then X.set(k,act.prev[k],false) n+=1 end
    end
    Store.d.active=nil Store.touch() X.dirty=os.clock()
    if X.presetsChanged then X.presetsChanged() end
    return true,"Preset dilepas, "..n.." pengaturan dikembalikan"
end
function Presets.isBlacklisted(uid)
    local b=Store.d.bans[tostring(uid)]
    return b~=nil and b.kind=="blacklist" and ((tonumber(b.exp) or 0)==0 or b.exp>nowT())
end
function Presets.upload(name,desc)
    name=trim(tostring(name or ""):gsub("[^%w _%-%.]",""))
    if #name<3 then return false,"Nama preset minimal 3 karakter" end
    name=name:sub(1,32)
    desc=trim(desc):sub(1,140)
    if Presets.isBlacklisted(Player.UserId) and not Auth.isDev then return false,"Akun ini di-blacklist dari upload preset" end
    local p=Presets.make(name,desc)
    local n=0
    for _ in pairs(p.settings) do n+=1 end
    if n==0 then return false,"Tidak ada pengaturan untuk diunggah" end
    if Net.url~="" then
        local ok,res=Net.call("/presets/upload",{preset=p})
        if not ok then return false,"Upload gagal: "..tostring(res) end
        Net.rev.p=-1 Sync.requestNow()
        logAct("preset_upload",name,"backend")
        return true,res.message or ("Preset '"..name.."' diunggah")
    end
    local list=Store.d.lp
    for _,e in ipairs(list) do
        if e.uid==p.uid and e.hash==p.hash and e.name~=name then return false,"Duplikat: pengaturan sama dengan preset '"..e.name.."'" end
    end
    for i,e in ipairs(list) do
        if e.uid==p.uid and e.name:lower()==name:lower() then
            if e.hash==p.hash then return false,"Tidak ada perubahan dari versi sebelumnya" end
            p.id,p.rev=e.id,(tonumber(e.rev) or 1)+1
            list[i]=p
            Store.touch() logAct("preset_update",name,"v"..p.rev)
            if X.presetsChanged then X.presetsChanged() end
            return true,("Preset '%s' diperbarui ke v%d (lokal)"):format(name,p.rev)
        end
    end
    p.id=genId(tostring(p.uid).."-")
    list[#list+1]=p
    Store.touch() logAct("preset_upload",name,"lokal")
    if X.presetsChanged then X.presetsChanged() end
    return true,"Preset '"..name.."' disimpan di library lokal"
end
function Presets.deleteOwn(id)
    if Net.url~="" then
        local ok,res=Net.call("/presets/delete",{id=id})
        if not ok then return false,tostring(res) end
        Net.rev.p=-1 Sync.requestNow()
        return true,"Preset dihapus"
    end
    local list=Store.d.lp
    for i,e in ipairs(list) do
        if e.id==id then
            if e.uid~=Player.UserId and not Auth.can("delpreset") then return false,"Bukan preset milikmu" end
            table.remove(list,i) Store.d.fav[id]=nil Store.touch()
            logAct("preset_hapus",e.name,"lokal")
            if X.presetsChanged then X.presetsChanged() end
            return true,"Preset dihapus"
        end
    end
    return false,"Preset tidak ditemukan"
end
function Presets.importJson(raw)
    raw=trim(raw)
    if raw=="" then return false,"JSON kosong" end
    local ok,d=pcall(HttpService.JSONDecode,HttpService,raw)
    if not ok or type(d)~="table" then return false,"JSON tidak valid" end
    local p
    if type(d.settings)=="table" then p=d
    elseif type(d.state)=="table" then
        local meta=type(d.meta)=="table" and d.meta or {}
        p={name="Import-"..os.date("%H%M%S"),desc="Diimpor dari config",uid=0,by=tostring(meta.owner or "unknown"),at=nowT(),rev=1,schema=tonumber(d.v) or 4,game="Universal",settings=d.state}
    else return false,"Bukan format preset/config CAZIELX" end
    local st,msg,clean=Presets.validate(p)
    if st=="bad" then return false,msg end
    local on,off={},{}
    for _,f in ipairs(FEATURES) do if clean[f[1]] then on[#on+1]=f[2] elseif clean[f[1]]==false then off[#off+1]=f[2] end end
    local item={id=genId("imp-"),name=tostring(p.name or "Import"):sub(1,32),desc=tostring(p.desc or ""):sub(1,140),uid=tonumber(p.uid) or 0,by=tostring(p.by or "unknown"):sub(1,24),display=tostring(p.display or p.by or ""),at=tonumber(p.at) or nowT(),rev=tonumber(p.rev) or 1,schema=tonumber(p.schema) or SCHEMA,game=tostring(p.game or "Universal"),on=on,off=off,settings=clean,hash=hashStr(canon(clean))}
    for _,e in ipairs(Store.d.lp) do if e.hash==item.hash and e.by==item.by then return false,"Duplikat: preset sama sudah ada ("..e.name..")" end end
    Store.d.lp[#Store.d.lp+1]=item Store.touch()
    if X.presetsChanged then X.presetsChanged() end
    return true,"Preset diimpor ke library lokal: "..item.name
end
function Presets.exportJson(item)
    local p=item or Presets.make("Export-"..Player.Name,"")
    return HttpService:JSONEncode(p)
end
function Presets.query(opts)
    local out={}
    local q=trim(opts.search):lower()
    for _,p in ipairs(Presets.src()) do
        if type(p)=="table" and p.id and type(p.settings)=="table" and not Presets.isBlacklisted(p.uid) then
            local st=Presets.validate(p)
            local hay=((p.name or "").." "..(p.by or "").." "..table.concat(type(p.on)=="table" and p.on or {}," ")):lower()
            local pass=(q=="" or hay:find(q,1,true)~=nil)
            if pass and opts.filter=="Milikku" then pass=p.uid==Player.UserId end
            if pass and opts.filter=="Favorit" then pass=Store.d.fav[p.id]==true end
            if pass and opts.filter=="Kompatibel" then pass=st=="ok" end
            if pass then out[#out+1]=p end
        end
    end
    local s=opts.sort
    table.sort(out,function(a,b)
        if s=="Nama" then return (a.name or ""):lower()<(b.name or ""):lower() end
        if s=="Fitur" then return #(a.on or {})>#(b.on or {}) end
        if s=="Favorit" then
            local fa,fb=Store.d.fav[a.id] and 1 or 0,Store.d.fav[b.id] and 1 or 0
            if fa~=fb then return fa>fb end
        end
        return (tonumber(a.at) or 0)>(tonumber(b.at) or 0)
    end)
    return out
end

function Ann.src() return Net.url~="" and Store.d.ca or Store.d.la end
function Ann.status(a)
    local t=nowT()
    if a.status~="published" then return "DRAFT" end
    if (tonumber(a.expiresAt) or 0)>0 and a.expiresAt<=t then return "KEDALUWARSA" end
    if (tonumber(a.publishAt) or 0)>t then return "TERJADWAL" end
    return "TERBIT"
end
Ann.queue={}
Ann.showing=false
function Ann.check()
    if not Store.d then return end
    local seen=Store.d.seen
    local fresh={}
    for _,a in ipairs(Ann.src()) do
        if type(a)=="table" and a.id and Ann.status(a)=="TERBIT" then
            local key=tostring(a.id).."@"..tostring(a.rev or 1)
            if not seen[key] then fresh[#fresh+1]={a=a,key=key} end
        end
    end
    table.sort(fresh,function(x,y) return (tonumber(x.a.publishAt) or 0)<(tonumber(y.a.publishAt) or 0) end)
    for _,e in ipairs(fresh) do seen[e.key]=true Ann.queue[#Ann.queue+1]=e.a end
    if #fresh>0 then Store.touch() end
    Ann.pump()
end
function Ann.pump()
    if Ann.showing or #Ann.queue==0 or not X.showAnnouncement or not alive then return end
    Ann.showing=true
    local a=table.remove(Ann.queue,1)
    X.showAnnouncement({title=a.title,message=a.body,category=a.category,onClose=function() Ann.showing=false task.defer(Ann.pump) end})
end
-- Cloud sync tanpa server buatan sendiri: Firebase Realtime Database via REST (poll ~3 dtk).
local Cloud={rev=nil}
function Cloud.enabled() return CX_CONFIG.CLOUD_URL~="" and Net.url=="" end
function Cloud.req(method,path,body,auth)
    if not HTTP_REQUEST then return false,"executor tidak punya fungsi HTTP" end
    local url=CX_CONFIG.CLOUD_URL:gsub("/+$","").."/"..(path=="" and "cx" or ("cx/"..path))..".json"
    if auth then url=url.."?auth="..HttpService:UrlEncode(auth) end
    local args={Url=url,Method=method,Headers={["Content-Type"]="application/json"}}
    if body~=nil then
        local okE,j=pcall(HttpService.JSONEncode,HttpService,body)
        if not okE then return false,"gagal encode" end
        args.Body=j
    end
    local okR,res=pcall(HTTP_REQUEST,args)
    if not okR or type(res)~="table" then return false,okR and "tidak ada respons" or tostring(res) end
    local code=res.StatusCode or res.status_code
    if code==401 or code==403 then return false,"ditolak server cloud (HTTP "..tostring(code)..")" end
    if type(code)~="number" or code<200 or code>=300 then return false,"HTTP "..tostring(code) end
    local okD,data=pcall(HttpService.JSONDecode,HttpService,res.Body or "null")
    if not okD then return false,"respons bukan JSON" end
    return true,data
end
function Cloud.pull()
    local ok,rev=Cloud.req("GET","annRev")
    if not ok then return false,rev end
    if rev==nil then rev=0 end
    if rev==Cloud.rev then return true end
    local ok2,items=Cloud.req("GET","ann")
    if not ok2 then return false,items end
    local list={}
    if type(items)=="table" then
        for _,a in pairs(items) do
            if type(a)=="table" and a.id and type(a.title)=="string" and type(a.body)=="string" and a.status=="published" then list[#list+1]=a end
        end
    end
    for _,a in ipairs(Store.d.la) do if type(a)=="table" and a.status=="draft" then list[#list+1]=a end end -- draft tetap lokal
    table.sort(list,function(x,y) return (tonumber(x.createdAt) or 0)<(tonumber(y.createdAt) or 0) end)
    Store.d.la=list Cloud.rev=rev Store.touch()
    Ann.check()
    return true
end
function Cloud.push()
    if not Cloud.enabled() then return true end
    if not Auth.logged then return false,"belum login" end
    local tok=Cred.cloudAuth(Auth.role)
    if not tok then return false,"role ini tidak boleh menulis ke cloud atau CLOUD_WRITE_AUTH kosong" end
    local pub={}
    for _,a in ipairs(Store.d.la) do if type(a)=="table" and a.status=="published" then pub[#pub+1]=a end end
    local rev=os.time()*1000+math.random(0,999)
    local ok,err=Cloud.req("PATCH","",{ann=pub,annRev=rev},tok)
    if not ok then return false,err end
    Cloud.rev=rev
    return true
end
Ann.streamState="OFF"
Ann.gen=0
function Ann.apply(items,rev)
    Store.d.ca=items
    Net.rev.a=rev
    Store.touch()
    Ann.check()
end
-- Realtime: long-poll. Server membalas segera saat admin menerbitkan/mengubah/menghapus pengumuman.
function Ann.stream()
    Ann.gen+=1
    local my=Ann.gen
    task.spawn(function()
        local misses=0
        while alive and Ann.gen==my do
            if Net.url=="" then
                if Cloud.enabled() then
                    local okC,errC=Cloud.pull()
                    if not alive or Ann.gen~=my then break end
                    if okC then
                        misses=0 Ann.streamState="LIVE" Diag.set("announce","RUNNING","realtime LIVE (cloud)")
                        task.wait(3)
                    else
                        misses+=1 Ann.streamState="RECONNECT" Diag.set("announce","UNAVAILABLE","cloud: "..tostring(errC))
                        task.wait(math.min(30,3*2^misses))
                    end
                else
                    Ann.streamState="OFF"
                    Diag.set("announce","UNAVAILABLE","CLOUD_URL belum diisi: pengumuman hanya lokal")
                    task.wait(3)
                end
            else
                local t0=os.clock()
                local ok,res=Net.poll("/announcements/poll",{rev=Net.rev.a,wait=25})
                if not alive or Ann.gen~=my then break end
                if ok then
                    misses=0
                    Ann.streamState="LIVE"
                    Diag.set("announce","RUNNING","realtime LIVE")
                    local rev=tonumber(res.rev)
                    if res.changed==true and type(res.items)=="table" and rev then Ann.apply(res.items,rev) end
                    if os.clock()-t0<1 and res.changed~=true then task.wait(1) end
                else
                    misses+=1
                    Ann.streamState="RECONNECT"
                    Diag.set("announce","UNAVAILABLE","stream putus: "..tostring(res))
                    task.wait(math.min(30,2^misses))
                end
            end
        end
    end)
end
function Ann.validate(p)
    local title,body=trim(p.title),trim(p.body)
    if #title<3 then return false,"Judul minimal 3 karakter" end
    if #title>90 then return false,"Judul maksimal 90 karakter" end
    if #body<3 then return false,"Isi pengumuman minimal 3 karakter" end
    if #body>900 then return false,"Isi pengumuman maksimal 900 karakter" end
    if not table.find(ANN_CATS,p.category) then return false,"Kategori tidak valid" end
    local pa,ex=tonumber(p.publishAt) or nowT(),tonumber(p.expiresAt) or 0
    if ex>0 and ex<=pa then return false,"Masa berlaku harus setelah waktu publikasi" end
    return true,{id=p.id,title=title,body=body,category=p.category,publishAt=pa,expiresAt=ex,status=p.status=="draft" and "draft" or "published"}
end

function Adm.fetch(kind)
    if not Auth.logged then return false,"Belum login staf" end
    if (kind=="users" or kind=="logs") and not Auth.can(kind) then return false,"Tidak punya izin" end
    if Auth.mode=="backend" then
        local ok,res=Net.call("/admin/"..kind,{},true)
        if not ok then return false,tostring(res) end
        return true,type(res.items)=="table" and res.items or {}
    end
    if kind=="anns" then
        local out={}
        for _,a in ipairs(Store.d.la) do out[#out+1]=a end
        return true,out
    end
    if kind=="users" then
        local out={}
        for k,u in pairs(Store.d.users) do
            if type(u)=="table" then
                local b=Users.banOf(k)
                out[#out+1]={id=u.id,name=u.name,display=u.display,role=u.role or "user",last=u.last,first=u.first,ban=b}
            end
        end
        for k,b in pairs(Store.d.bans) do
            if not Store.d.users[k] and type(b)=="table" then out[#out+1]={id=tonumber(k),name=b.name or k,role="user",ban=b} end
        end
        return true,out
    end
    local out={}
    for i=#Store.d.logs,1,-1 do out[#out+1]=Store.d.logs[i] end
    return true,out
end
function Adm.exec(action,p)
    if not Auth.logged then return false,"Belum login admin" end
    if DEV_ONLY[action] and not (Auth.isDev and Auth.role=="dev") then return false,"Aksi "..action.." hanya untuk Developer" end
    if not Auth.can(action) then return false,"Role "..Auth.role.." tidak punya izin untuk "..action end
    p=p or {}
    if Auth.mode=="backend" then
        if p.target then
            local id,name=Users.resolve(p.target)
            if not id then return false,name end
            p.targetId,p.targetName=id,name
        end
        local ok,res=Net.call("/admin/"..action,p,true)
        if not ok then return false,tostring(res) end
        Sync.requestNow()
        if action=="saveann" or action=="delann" then Net.rev.a=-1 end
        if action=="delpreset" then Net.rev.p=-1 end
        return true,res.message or "Berhasil"
    end
    local okL,mL=Adm.runLocal(action,p)
    if okL and (action=="saveann" or action=="delann") and Cloud.enabled() then
        mL=(tostring(mL):gsub("%s*%(lokal[^%)]*%)",""))
        local okP,eP=Cloud.push()
        if okP then return true,mL.." - disiarkan realtime ke semua user" end
        return true,mL.." - TAPI gagal disiarkan: "..tostring(eP)
    end
    return okL,mL
end
function Adm.runLocal(action,p)
    local d=Store.d
    -- pemeriksaan ulang di level fungsi (bukan hanya UI): pemanggilan langsung tetap ditolak
    if not Auth.logged or not Auth.can(action) then return false,"Tidak punya izin untuk "..tostring(action) end
    if action=="ban" or action=="blacklist" or action=="unban" or action=="setrole" or action=="kick" then
        local id,name=Users.resolve(p.target)
        if not id then return false,name end
        if tostring(name):lower()==DEV_NAME then return false,"Akun developer dilindungi" end
        if id==Player.UserId then return false,"Tidak bisa menarget akun sendiri" end
        local k=tostring(id)
        local tu=d.users[k]
        local trank=ROLE_RANK[(tu and tu.role) or "user"] or 1
        if not Auth.isDev and trank>=(ROLE_RANK[Auth.role] or 1) then return false,"Tidak bisa menarget role setara atau lebih tinggi" end
        if action=="kick" then return false,"Kick membutuhkan backend" end
        if action=="unban" then
            if not d.bans[k] then return false,name.." tidak sedang di-ban/blacklist" end
            d.bans[k]=nil Store.touch() logAct("unban",name,"")
            return true,name.." di-unban (lokal)"
        end
        if action=="setrole" then
            if not ROLE_RANK[p.role] or p.role=="dev" then return false,"Role tidak valid (Developer ditentukan username, tidak bisa diberikan)" end
            if not Auth.can("setrole") then return false,"Set Role hanya untuk Developer" end
            local u=d.users[k] or {id=id,name=name,first=nowT(),sessions=0}
            u.role=p.role d.users[k]=u Store.touch() logAct("setrole",name,p.role)
            return true,name.." sekarang "..p.role.." (lokal)"
        end
        local dur=tonumber(p.duration) or 0
        d.bans[k]={kind=action,exp=dur>0 and nowT()+dur or 0,reason=trim(p.reason):sub(1,120),by=Player.Name,at=nowT(),name=name}
        Store.touch() logAct(action,name,dur>0 and fmtLeft(dur) or "permanen")
        return true,("%s: %s (%s) - hanya berlaku di perangkat ini"):format(action,name,dur>0 and fmtLeft(dur) or "permanen")
    elseif action=="delpreset" then
        for i,e in ipairs(d.lp) do
            if e.id==p.id then table.remove(d.lp,i) Store.touch() logAct("delpreset",e.name,"lokal") if X.presetsChanged then X.presetsChanged() end return true,"Preset dihapus" end
        end
        return false,"Preset tidak ditemukan"
    elseif action=="saveann" then
        local ok,a=Ann.validate(p)
        if not ok then return false,a end
        local list=d.la
        for _,e in ipairs(list) do
            if e.id~=p.id and e.title==a.title and e.body==a.body and e.status=="published" then return false,"Duplikat: pengumuman sama sudah terbit" end
        end
        if a.id then
            for i,e in ipairs(list) do
                if e.id==a.id then
                    a.rev=(tonumber(e.rev) or 1)+1 a.by=e.by a.createdAt=e.createdAt a.updatedAt=nowT()
                    list[i]=a Store.touch() logAct("ann_edit",a.title,"v"..a.rev)
                    Ann.check()
                    return true,"Pengumuman diperbarui (lokal)"
                end
            end
        end
        a.id=genId("A") a.rev=1 a.by=Player.Name a.createdAt=nowT() a.updatedAt=nowT()
        list[#list+1]=a Store.touch() logAct("ann_baru",a.title,a.category)
        Ann.check()
        return true,"Pengumuman disimpan (lokal, hanya di perangkat ini)"
    elseif action=="delann" then
        for i,e in ipairs(d.la) do
            if e.id==p.id then table.remove(d.la,i) Store.touch() logAct("ann_hapus",e.title,"") return true,"Pengumuman dihapus" end
        end
        return false,"Pengumuman tidak ditemukan"
    end
    return false,"Aksi tidak dikenal"
end

-- Self-test izin: jalankan manual dari executor -> _G.CAZX_PERMTEST(). Semua aksi harus DITOLAK; data tidak diubah.
function X.permTest()
    local sv={Auth.logged,Auth.role,Auth.mode,Auth.isDev}
    local res,allOk={},true
    local function deny(name,fn)
        local ok,r=pcall(fn)
        local pass=ok and r==false
        if not pass then allOk=false end
        res[#res+1]=(pass and "PASS " or "FAIL ")..name
    end
    local okRun,err=pcall(function()
        for _,role in ipairs({"admin","moderator","user","vip"}) do
            Auth.logged,Auth.role,Auth.mode,Auth.isDev=true,role,"lokal",false
            deny(role..": Adm.exec setrole",function() return (Adm.exec("setrole",{target="1",role="admin"})) end)
            deny(role..": Adm.runLocal setrole",function() return (Adm.runLocal("setrole",{target="1",role="admin"})) end)
            deny(role..": Auth.can(setrole)",function() return Auth.can("setrole") end)
            deny(role..": Auth.can(sysconfig)",function() return Auth.can("sysconfig") end)
        end
        Auth.logged,Auth.role,Auth.mode,Auth.isDev=true,"dev","lokal",false -- role dev dipalsukan tanpa username dev
        deny("forged dev role (bukan username dev): Auth.can(setrole)",function() return Auth.can("setrole") end)
        deny("forged dev role: Adm.exec setrole",function() return (Adm.exec("setrole",{target="1",role="admin"})) end)
        Auth.logged,Auth.role,Auth.mode,Auth.isDev=false,"dev","none",true
        deny("dev tanpa login key: Auth.can(setrole)",function() return Auth.can("setrole") end)
    end)
    Auth.logged,Auth.role,Auth.mode,Auth.isDev=sv[1],sv[2],sv[3],sv[4]
    if not okRun then allOk=false res[#res+1]="ERROR "..tostring(err) end
    return allOk,res
end
_G.CAZX_PERMTEST=function() local ok,r=X.permTest() for _,l in ipairs(r) do print("[CAZX][PERM] "..l) end print("[CAZX][PERM] "..(ok and "SEMUA LOLOS" or "ADA YANG GAGAL")) return ok end

Sync.nextAt=0
Sync.running=false
function Sync.requestNow() Sync.nextAt=0 end
function Sync.interval()
    local base=(X.ui and X.ui.open) and 20 or 45
    if S.perf_mode then base*=1.5 end
    return math.min(300,base*(2^math.min(Net.fails,4)))
end
function Sync.step()
    local d=Store.d
    Users.self(false)
    if Net.url=="" then
        Net.state,Net.kind,Net.detail="LOKAL","warn","backend belum diatur: data hanya di perangkat ini"
        Guard.check(Users.banOf(Player.UserId))
        Ann.check()
        Diag.set("sync","RUNNING","mode lokal")
        return
    end
    local ok,res=Net.call("/session",{display=Player.DisplayName,game=X.game.name,placeId=game.PlaceId,version=X.VERSION})
    if not ok then
        Diag.set("sync","UNAVAILABLE","offline: "..tostring(res))
        Ann.check()
        return
    end
    Diag.set("sync","RUNNING","online (polling adaptif)")
    if ROLE_RANK[res.role] then Net.role=res.role end
    if X.refreshAdmin then X.refreshAdmin() end
    if X.promptLogin and Auth.needsKey() and not Auth.prompted then Auth.prompted=true task.defer(X.promptLogin) end
    if res.kick==true then Guard.kick(tostring(res.message or "Sesi dihentikan oleh admin")) return end
    local b=type(res.ban)=="table" and {kind=res.ban.kind or "ban",exp=tonumber(res.ban.exp) or 0,reason=tostring(res.ban.reason or "")} or nil
    Guard.check(b)
    local rev=type(res.rev)=="table" and res.rev or {}
    local rp,ra=tonumber(rev.p) or 0,tonumber(rev.a) or 0
    if rp~=Net.rev.p then
        local ok2,r2=Net.call("/presets/list",{})
        if ok2 and type(r2.items)=="table" then
            d.cp=r2.items Net.rev.p=rp Store.touch()
            if X.presetsChanged then X.presetsChanged() end
        end
    end
    if ra~=Net.rev.a then
        local ok3,r3=Net.call("/announcements/list",{})
        if ok3 and type(r3.items)=="table" then d.ca=r3.items Net.rev.a=ra Store.touch() end
    end
    Ann.check()
end
function Sync.run()
    if Sync.running or not alive then return end
    Sync.running=true
    local ok,err=xpcall(Sync.step,tb)
    Sync.running=false
    Sync.nextAt=os.clock()+Sync.interval()
    if not ok then Diag.err("sync",err) end
end
function Sync.start()
    Ann.stream()
    Root.add(function() Ann.gen+=1 end)
    Sched.add("annwatch",1,function() if alive then Ann.check() end end) -- pengumuman terjadwal tampil tepat waktu
    Sched.add("sync",1,function() if alive and not Sync.running and os.clock()>=Sync.nextAt then task.spawn(Sync.run) end end)
    Sched.add("storesave",2,function() if Store.dirty and os.clock()-Store.dirty>1.5 then Store.dirty=nil Store.save() end end)
    Root.add(function() Store.save() end)
end

do
local imgCache={}
local function thumbUrl(kind,id)
    local key=kind..tostring(id)
    if imgCache[key]~=nil then return imgCache[key] or nil end
    if not HTTP_REQUEST then return nil end
    local url
    if kind=="asset" then url=("https://thumbnails.roblox.com/v1/assets?assetIds=%s&size=420x420&format=Png&isCircular=false"):format(id)
    else url=("https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=%s&size=150x150&format=Png&isCircular=false"):format(id) end
    for _=1,2 do
        local ok,res=pcall(HTTP_REQUEST,{Url=url,Method="GET"})
        if ok and type(res)=="table" and (res.StatusCode or res.status_code)==200 then
            local okD,d=pcall(HttpService.JSONDecode,HttpService,res.Body or "")
            local it=okD and type(d)=="table" and type(d.data)=="table" and d.data[1]
            if it and it.state=="Completed" and type(it.imageUrl)=="string" then imgCache[key]=it.imageUrl return it.imageUrl end
            if it and it.state=="Pending" then task.wait(1.5) else break end
        else break end
    end
    imgCache[key]=false
    return nil
end
local function petAssetId(tool)
    local cands={}
    local function add(v)
        if type(v)=="number" then v="rbxassetid://"..v end
        if type(v)=="string" and v~="" then cands[#cands+1]=v end
    end
    add(tool.TextureId)
    for _,k in ipairs({"Image","Icon","Thumbnail","ImageId","TextureId"}) do add(tool:GetAttribute(k)) end
    local n=0
    for _,o in ipairs(tool:GetDescendants()) do
        n+=1 if n>200 then break end
        if o:IsA("ImageLabel") or o:IsA("ImageButton") then add(o.Image)
        elseif o:IsA("Decal") or o:IsA("Texture") then add(o.Texture) end
    end
    for _,v in ipairs(cands) do
        local id=v:match("rbxassetid://(%d+)") or v:match("[?&]id=(%d+)") or v:match("^(%d+)$")
        if id then return id end
    end
end
local PET_COL={0x9CA3AF,0x34D399,0x3B82F6,0x8B5CF6,0xF59E0B,0xF43F5E,0xFDE68A,0x22D3EE}
function X.petCollect(tool,idx,rl)
    local extra={}
    local keys={}
    for k,v in pairs(tool:GetAttributes()) do
        local t=type(v)
        if (t=="string" or t=="number" or t=="boolean") and k~="Rarity" and k~="RarityName" and k~="Tier" and k~="Image" and k~="Icon" and k~="Thumbnail" then keys[#keys+1]=k end
    end
    table.sort(keys)
    for i=1,math.min(#keys,5) do extra[#extra+1]={name=keys[i],value=tostring(tool:GetAttribute(keys[i])):sub(1,100),inline=true} end
    return {name=tool.Name,rarity=idx>0 and rl or "tidak diketahui",idx=idx,asset=petAssetId(tool),extra=extra,count=Ses.petCounts[tool.Name] or 1}
end

function X.petEvent(info,isTest)
    task.spawn(function()
        local img=info.asset and thumbUrl("asset",info.asset) or nil
        local icon=thumbUrl("user",Player.UserId)
        local fields={
            {name="Nama Pet",value=info.name,inline=true},
            {name="Rarity",value=info.rarity,inline=true},
            {name="Jumlah Sesi Ini",value=tostring(info.count).."x",inline=true},
            {name="Total Pet Sesi Ini",value=tostring(Ses.petTotal),inline=true},
            {name="Zona",value=zoneNow(),inline=true},
            {name="Pet Terbaik Sesi",value=Ses.bestName,inline=true},
        }
        for _,f in ipairs(info.extra) do fields[#fields+1]=f end
        if not img then fields[#fields+1]={name="Gambar",value="Tidak tersedia dari data event",inline=false} end
        local title=isTest and "CONTOH TES - Pet Baru Didapatkan" or "Pet Baru Didapatkan"
        local desc=(isTest and "Ini hanya contoh tampilan embed. " or "")..("**%s** berhasil didapatkan oleh **%s** (@%s)"):format(info.name,Player.DisplayName,Player.Name)
        local queued=X.event("pet",title,desc,"good",fields,{thumb=img,icon=icon,color=PET_COL[math.clamp(info.idx,1,#PET_COL)]},isTest)
        if isTest then
            if not queued then X.notify("Contoh tidak terkirim: aktifkan webhook dan isi URL","bad",4) else X.notify("Contoh embed pet dikirim","good",3) end
        end
    end)
end
end


local C={bg=Color3.fromRGB(7,9,13),p1=Color3.fromRGB(13,16,22),p2=Color3.fromRGB(19,23,31),p3=Color3.fromRGB(28,33,44),line=Color3.fromRGB(36,43,56),
    tx=Color3.fromRGB(232,238,246),mut=Color3.fromRGB(122,135,154),good=Color3.fromRGB(52,211,153),warn=Color3.fromRGB(251,191,36),bad=Color3.fromRGB(244,63,94),ac=Color3.fromRGB(245,158,11)}
local ACCENTS={Amber=Color3.fromRGB(245,158,11),Cyan=Color3.fromRGB(34,211,238),Electric=Color3.fromRGB(59,130,246),Emerald=Color3.fromRGB(52,211,153),Violet=Color3.fromRGB(139,92,246)}
local ANIM={Off=0,Low=.5,Medium=1,High=1}
local activeTw={}
local function tw(o,t,props,style)
    local q=ANIM[S.anim_quality] or 1
    if q==0 or t<=0 or not o.Parent then for k,v in pairs(props) do pcall(function() o[k]=v end) end return nil end
    local tr=TweenService:Create(o,TweenInfo.new(t*q,style or Enum.EasingStyle.Quad,Enum.EasingDirection.Out),props)
    activeTw[tr]=true
    tr.Completed:Once(function() activeTw[tr]=nil end)
    tr:Play() return tr
end
local function twLoop(o,props)
    if (ANIM[S.anim_quality] or 1)<1 or S.anim_quality=="Low" then return nil end
    local tr=TweenService:Create(o,TweenInfo.new(.8,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),props)
    activeTw[tr]=true tr:Play() return tr
end
Root.add(function() for tr in pairs(activeTw) do pcall(tr.Cancel,tr) end table.clear(activeTw) end)
local function N(class,props,parent)
    local o=Instance.new(class)
    for k,v in pairs(props) do o[k]=v end
    if parent then o.Parent=parent end
    return o
end
local K={accs={},curPage=nil}
local function acc(inst,prop) inst[prop]=C.ac K.accs[#K.accs+1]={inst,prop} return inst end
local function corner(o,r) return N("UICorner",{CornerRadius=UDim.new(0,r)},o) end
local function strokeOf(o,col,th) return N("UIStroke",{Color=col or C.line,Thickness=th or 1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},o) end
local function T(parent,txt,size,col,bold,props)
    size=math.max(size,10) -- teks < 10 tidak terbaca
    local p={BackgroundTransparency=1,Text=txt,TextSize=size,TextColor3=col or C.tx,Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,0,0,size+6)}
    if props then for k,v in pairs(props) do p[k]=v end end
    return N("TextLabel",p,parent)
end
local WRAP={TextWrapped=true,AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,0,0,0),TextYAlignment=Enum.TextYAlignment.Top}
local function wrapT(parent,txt,size,col,bold)
    local p={} for k,v in pairs(WRAP) do p[k]=v end
    return T(parent,txt,size,col,bold,p)
end
local function pressFx(btn,base)
    local sc=N("UIScale",{},btn)
    btn.MouseEnter:Connect(function() if not IS_TOUCH then tw(btn,.12,{BackgroundColor3=base:Lerp(C.tx,.08)}) end end)
    btn.MouseLeave:Connect(function() tw(btn,.15,{BackgroundColor3=base}) tw(sc,.1,{Scale=1}) end)
    btn.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then tw(sc,.07,{Scale=.96}) end end)
    btn.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then tw(sc,.1,{Scale=1}) end end)
end
local function mkBtn(parent,txt,size,bg,props)
    local p={Text=txt,Font=Enum.Font.GothamBold,TextSize=12,TextColor3=C.tx,BackgroundColor3=bg or C.p3,AutoButtonColor=false,Size=size,BorderSizePixel=0}
    if props then for k,v in pairs(props) do p[k]=v end end
    local b=N("TextButton",p,parent) corner(b,7) pressFx(b,bg or C.p3) return b
end
local function cxMark(parent,size)
    local mark=N("Frame",{Name="CXMark",Size=UDim2.fromOffset(size,size),BackgroundColor3=C.p1,BorderSizePixel=0},parent)
    corner(mark,math.floor(size*.28))
    strokeOf(mark,C.ac,1.5)
    local txt=T(mark,"CX",math.max(12,math.floor(size*.38)),C.tx,true,{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center})
    txt.ZIndex=2
    N("Frame",{Name="CXSlash",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(.8,0,0,2),Rotation=-48,BackgroundColor3=C.ac,BackgroundTransparency=.5,BorderSizePixel=0,ZIndex=1},mark) -- di belakang huruf
    return mark
end

local Pages={}
-- Mask input key: teks asli disimpan di closure, kotak hanya menampilkan "*".
function K.maskInput(box)
    local real,busy="",false
    box:GetPropertyChangedSignal("Text"):Connect(function()
        if busy then return end
        local t=box.Text
        local lead=t:match("^(%*+)") or ""
        local rest=t:sub(#lead+1)
        if rest=="" then real=real:sub(1,#lead) else real=real:sub(1,math.min(#real,#lead))..rest end
        busy=true box.Text=string.rep("*",#real) busy=false
    end)
    return function() return real end,function() real="" busy=true box.Text="" busy=false end
end
function K.Card(page,title)
    local f=N("Frame",{BackgroundColor3=C.p2,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BorderSizePixel=0},page)
    corner(f,9) strokeOf(f)
    N("UIPadding",{PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,10),PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)},f)
    N("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},f)
    if title then T(f,title:upper(),10,C.mut,true) end
    return f
end
local function Row(parent,name,desc,rw)
    local r=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},parent)
    N("UISizeConstraint",{MinSize=Vector2.new(0,30)},r)
    local left=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,-(rw+12),0,0),AutomaticSize=Enum.AutomaticSize.Y},r)
    N("UIListLayout",{Padding=UDim.new(0,2)},left)
    T(left,name,13,C.tx,true,{TextTruncate=Enum.TextTruncate.AtEnd})
    if desc and desc~="" then wrapT(left,desc,11,C.mut) end
    local right=N("Frame",{BackgroundTransparency=1,AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,0,.5,0),Size=UDim2.fromOffset(rw,28)},r)
    return r,right
end
function K.Toggle(parent,key,name,desc)
    local _,right=Row(parent,name,desc,46)
    local sw=N("TextButton",{Text="",AutoButtonColor=false,Size=UDim2.fromOffset(42,24),AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,0,.5,0),BackgroundColor3=C.p3},right)
    corner(sw,12)
    local knob=N("Frame",{Size=UDim2.fromOffset(18,18),Position=UDim2.fromOffset(3,3),BackgroundColor3=C.tx},sw) corner(knob,9)
    X.sync[key]=function(v)
        tw(sw,.15,{BackgroundColor3=v and C.ac or C.p3})
        tw(knob,.15,{Position=v and UDim2.fromOffset(21,3) or UDim2.fromOffset(3,3)})
    end
    X.sync[key](S[key])
    sw.Activated:Connect(function() X.set(key,not S[key]) end)
end
function K.Choice(parent,key,name,desc,opts,onPick)
    local box=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},parent)
    N("UIListLayout",{Padding=UDim.new(0,6)},box)
    T(box,name,13,C.tx,true)
    if desc and desc~="" then wrapT(box,desc,11,C.mut) end
    local bar=N("ScrollingFrame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,32),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.X,ScrollBarThickness=0,ScrollingDirection=Enum.ScrollingDirection.X,BorderSizePixel=0},box)
    N("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,5),VerticalAlignment=Enum.VerticalAlignment.Center},bar)
    local btns={}
    for _,o in ipairs(opts) do
        local b=mkBtn(bar,tostring(o),UDim2.new(0,0,0,30),C.p3,{AutomaticSize=Enum.AutomaticSize.X,TextColor3=C.mut})
        N("UIPadding",{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)},b)
        btns[o]=b
        b.Activated:Connect(function() if onPick then onPick(o) else X.set(key,o) end end)
    end
    X.sync[key]=function(v) for o,b in pairs(btns) do local sel=tostring(o)==tostring(v) tw(b,.15,{BackgroundColor3=sel and C.ac:Lerp(C.p1,.65) or C.p3,TextColor3=sel and C.tx or C.mut}) end end
    X.sync[key](S[key])
end
function K.Slider(parent,key,name,desc,mn,mx,step,fmt)
    local box=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},parent)
    N("UIListLayout",{Padding=UDim.new(0,4)},box)
    local top=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,18)},box)
    T(top,name,13,C.tx,true,{Size=UDim2.new(.7,0,1,0)})
    local val=T(top,"",12,C.ac,true,{Size=UDim2.new(.3,0,1,0),Position=UDim2.new(.7,0,0,0),TextXAlignment=Enum.TextXAlignment.Right})
    if desc and desc~="" then wrapT(box,desc,11,C.mut) end
    local hit=N("TextButton",{Text="",AutoButtonColor=false,BackgroundTransparency=1,Size=UDim2.new(1,0,0,26)},box)
    local trk=N("Frame",{BackgroundColor3=C.p3,Size=UDim2.new(1,0,0,6),Position=UDim2.new(0,0,.5,-3),BorderSizePixel=0},hit) corner(trk,3)
    local fill=acc(N("Frame",{Size=UDim2.new(0,0,1,0),BorderSizePixel=0},trk),"BackgroundColor3") corner(fill,3)
    local page=K.curPage
    local function paint(v) fill.Size=UDim2.new((v-mn)/(mx-mn),0,1,0) val.Text=fmt and fmt(v) or tostring(v) end
    X.sync[key]=paint paint(S[key])
    local dragging=false
    local function upd(x)
        local a=(x-trk.AbsolutePosition.X)/math.max(trk.AbsoluteSize.X,1)
        local v=math.clamp(math.floor((mn+a*(mx-mn))/step+.5)*step,mn,mx)
        X.set(key,tonumber(("%.3f"):format(v)))
    end
    hit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true page.ScrollingEnabled=false upd(i.Position.X) end end)
    Root.add(UIS.InputChanged:Connect(function(i) if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then upd(i.Position.X) end end))
    Root.add(UIS.InputEnded:Connect(function(i) if dragging and (i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch) then dragging=false page.ScrollingEnabled=true end end))
end
function K.Button(parent,text,fn,col)
    local b=mkBtn(parent,text,UDim2.new(1,0,0,34),col or C.p3)
    b.Activated:Connect(function()
        task.spawn(function()
            local ok,r,why=xpcall(fn,tb)
            if not ok then Diag.err("button:"..text,r) X.notify(text..": error (see Diagnostics)","bad",4)
            elseif r==false then X.notify(why or (text.." failed"),"bad",4) end
        end)
    end)
    return b
end
function K.Input(parent,key,name,desc,ph,validate,private)
    local box=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},parent)
    N("UIListLayout",{Padding=UDim.new(0,6)},box)
    T(box,name,13,C.tx,true)
    if desc and desc~="" then wrapT(box,desc,11,C.mut) end
    local tbx=N("TextBox",{Text=private and "" or tostring(S[key] or ""),PlaceholderText=ph or "",PlaceholderColor3=C.mut,TextColor3=C.tx,Font=Enum.Font.Gotham,TextSize=12,
        BackgroundColor3=C.p1,Size=UDim2.new(1,0,0,32),ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Left,BorderSizePixel=0},box)
    corner(tbx,7) strokeOf(tbx) N("UIPadding",{PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)},tbx)
    tbx.FocusLost:Connect(function()
        local v=tbx.Text
        if validate and not validate(v) then X.notify(name..": invalid value","bad",3) if not private then tbx.Text=tostring(S[key] or "") end return end
        if private then if X.onPrivate then X.onPrivate(key,v) end else X.set(key,v) end
    end)
    return tbx
end
function K.Live(parent,label,fn,fast)
    local r=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,20)},parent)
    T(r,label,12,C.mut,false,{Size=UDim2.new(.45,0,1,0)})
    local v=T(r,"-",12,C.tx,true,{Size=UDim2.new(.55,0,1,0),Position=UDim2.new(.45,0,0,0),TextXAlignment=Enum.TextXAlignment.Right,TextTruncate=Enum.TextTruncate.AtEnd})
    X.live[#X.live+1]={page=K.curPage,fast=fast,fn=function() local t,c=fn() v.Text=tostring(t) v.TextColor3=c or C.tx end}
end
function K.List(parent,getRows,empty)
    local box=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},parent)
    N("UIListLayout",{Padding=UDim.new(0,3)},box)
    local sig
    X.live[#X.live+1]={page=K.curPage,fn=function()
        local rows=getRows()
        local s=table.concat(rows,"\n")
        if s==sig then return end
        sig=s
        for _,c in ipairs(box:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
        if #rows==0 then T(box,empty or "Nothing yet",12,C.mut) end
        for i=1,math.min(#rows,25) do T(box,rows[i],12,C.tx,false,{TextTruncate=Enum.TextTruncate.AtEnd}) end
    end}
end
function K.Section(page,txt) return T(page,txt,11,C.mut,true,{Size=UDim2.new(1,0,0,18)}) end
function K.Grid(parent,cols)
    local g=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},parent)
    N("UIGridLayout",{CellSize=UDim2.new(1/cols,-6,0,52),CellPadding=UDim2.fromOffset(6,6),SortOrder=Enum.SortOrder.LayoutOrder},g)
    return g
end
function K.Tile(grid,label,fn)
    local f=N("Frame",{BackgroundColor3=C.p2,BorderSizePixel=0},grid) corner(f,8) strokeOf(f)
    N("UIPadding",{PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,8),PaddingTop=UDim.new(0,7)},f)
    T(f,label:upper(),9,C.mut,true,{Size=UDim2.new(1,0,0,12)})
    local v=T(f,"-",16,C.tx,true,{Size=UDim2.new(1,0,0,22),Position=UDim2.fromOffset(0,16),TextTruncate=Enum.TextTruncate.AtEnd})
    X.live[#X.live+1]={page=K.curPage,fn=function() local t,c=fn() v.Text=tostring(t) v.TextColor3=c or C.tx end}
end
local STC={RUNNING=C.good,SUCCESS=C.good,STARTING=C.warn,PAUSED=C.warn,FAILED=C.bad,UNAVAILABLE=C.mut,IDLE=C.mut,STOPPED=C.mut}
local function fstat(id) local f=Diag.f[id] if not f then return "IDLE",C.mut end return f.st,STC[f.st] or C.tx end
do
    local function sanitizeRig(m)
        for _,o in ipairs(m:GetDescendants()) do
            if o:IsA("BaseScript") or o:IsA("Sound") or o:IsA("ForceField") or o:IsA("Highlight") then pcall(o.Destroy,o)
            elseif o:IsA("BasePart") then o.Anchored=true o.CanCollide=false end
        end
        local hum=m:FindFirstChildOfClass("Humanoid")
        if hum then hum.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None end
    end
    Avatar.cache,Avatar.order,Avatar.busy={},{},false
    function Avatar.fetch(uid)
        if Avatar.cache[uid] then return Avatar.cache[uid] end
        local m
        if uid==Player.UserId and Player.Character then
            local c=Player.Character
            local old=c.Archivable
            c.Archivable=true
            local ok,cl=pcall(c.Clone,c)
            c.Archivable=old
            if ok and typeof(cl)=="Instance" then m=cl end
        end
        if not m and uid>0 then
            local ok,r=pcall(Players.CreateHumanoidModelFromUserId,Players,uid)
            if ok and typeof(r)=="Instance" then m=r end
        end
        if not m and uid>0 then
            local ok,r=pcall(Players.GetCharacterAppearanceAsync,Players,uid)
            if ok and typeof(r)=="Instance" then m=r end
        end
        if not m then return nil end
        sanitizeRig(m)
        Avatar.cache[uid]=m
        Avatar.order[#Avatar.order+1]=uid
        while #Avatar.order>24 do
            local old=table.remove(Avatar.order,1)
            local om=Avatar.cache[old]
            Avatar.cache[old]=nil
            if om then pcall(om.Destroy,om) end
        end
        return m
    end
    function Avatar.mount(parent,uid,size,bust,label)
        local vp=N("ViewportFrame",{BackgroundColor3=C.p1,Size=UDim2.fromOffset(size,size),BorderSizePixel=0,Ambient=Color3.fromRGB(185,185,195),LightColor=Color3.fromRGB(255,255,255),LightDirection=Vector3.new(-.3,-.5,1)},parent)
        corner(vp,math.floor(size*.28))
        strokeOf(vp)
        local letter=T(vp,string.upper(string.sub(tostring(label or "?"),1,1)),math.max(12,math.floor(size*.4)),C.mut,true,{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center})
        local cam=N("Camera",{FieldOfView=bust and 26 or 38},vp)
        vp.CurrentCamera=cam
        task.spawn(function()
            local waited=0
            while Avatar.busy do
                task.wait(.2) waited+=.2
                if not vp.Parent or waited>20 then return end
            end
            Avatar.busy=true
            local tmpl=Avatar.cache[uid]
            if not tmpl then
                local ok,r=pcall(Avatar.fetch,uid)
                tmpl=ok and r or nil
            end
            Avatar.busy=false
            if not tmpl or not vp.Parent then return end
            local m=tmpl:Clone()
            m.Parent=vp
            local root=m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
            if not root then m:Destroy() return end
            pcall(function() m:PivotTo(CFrame.new(0,3,0)) end)
            if bust then cam.CFrame=CFrame.lookAt(Vector3.new(0,4.3,-5.5),Vector3.new(0,4.2,0))
            else cam.CFrame=CFrame.lookAt(Vector3.new(0,3.3,-12),Vector3.new(0,3,0)) end
            if letter.Parent then letter:Destroy() end
        end)
        return vp
    end

    local function stopFeatures()
        for _,k in ipairs(RUNTIME_KEYS) do if S[k] then X.set(k,false,true) end end
    end
    Guard.locked=false
    function Guard.build(kind,reason,exp)
        local gui=X.ui and X.ui.gui
        if not gui then return end
        if Guard.overlay and Guard.overlay.Parent then Guard.overlay:Destroy() end
        local o=N("Frame",{Name="GuardOverlay",BackgroundColor3=C.bg,Size=UDim2.fromScale(1,1),ZIndex=300,Active=true,BorderSizePixel=0},gui)
        local card=N("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(.86,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=C.p2,BorderSizePixel=0},o)
        N("UISizeConstraint",{MaxSize=Vector2.new(420,420),MinSize=Vector2.new(240,120)},card)
        corner(card,12) strokeOf(card,C.bad,1.5)
        N("UIPadding",{PaddingTop=UDim.new(0,16),PaddingBottom=UDim.new(0,16),PaddingLeft=UDim.new(0,16),PaddingRight=UDim.new(0,16)},card)
        N("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},card)
        local title=kind=="blacklist" and "AKSES DI-BLACKLIST" or (kind=="kick" and "SESI DIHENTIKAN ADMIN" or "AKSES DI-BAN")
        T(card,title,16,C.bad,true)
        wrapT(card,kind=="kick" and tostring(reason or "") or ("Alasan: "..((reason and reason~="") and reason or "tidak dicantumkan")),12,C.tx)
        Guard.timeLbl=nil
        if kind~="kick" then Guard.timeLbl=wrapT(card,"",12,C.warn,true) end
        Guard.exp=exp or 0
        local b=mkBtn(card,"TUTUP SCRIPT",UDim2.new(1,0,0,34),C.bad:Lerp(C.p3,.5))
        b.Activated:Connect(function() X.unload() end)
        Guard.overlay=o
        Guard.tick()
    end
    function Guard.tick()
        if not Guard.timeLbl or not Guard.timeLbl.Parent then return end
        if (Guard.exp or 0)>0 then Guard.timeLbl.Text="Sisa waktu: "..fmtLeft(Guard.exp-nowT())
        else Guard.timeLbl.Text="Durasi: permanen" end
    end
    function Guard.lock(b)
        if Auth.isDev then return end
        stopFeatures()
        local first=not Guard.locked
        Guard.locked=true
        Guard.info=b
        if first or not (Guard.overlay and Guard.overlay.Parent) then Guard.build(b.kind or "ban",b.reason,tonumber(b.exp) or 0) end
        Diag.set("guard","STOPPED","diblokir: "..tostring(b.kind or "ban"))
    end
    function Guard.unlock()
        Guard.locked=false Guard.info=nil
        if Guard.overlay then pcall(Guard.overlay.Destroy,Guard.overlay) Guard.overlay=nil end
        Diag.set("guard","IDLE","tidak diblokir")
        X.notify("Blokir berakhir. Akses dipulihkan.","good",4)
    end
    function Guard.check(b)
        if Auth.isDev then b=nil end
        if b and (tonumber(b.exp) or 0)>0 and b.exp<=nowT() then b=nil end
        if b then Guard.lock(b) elseif Guard.locked then Guard.unlock() end
    end
    function Guard.kick(msg)
        if Auth.isDev then return end
        stopFeatures()
        Guard.locked=true
        Guard.build("kick",msg,0)
        task.delay(5,function() if alive then X.unload() end end)
    end
    Sched.add("guardui",1,function()
        if not Guard.locked then return end
        Guard.tick()
        if (Guard.exp or 0)>0 and Guard.exp<=nowT() then task.spawn(Sync.requestNow) Guard.check(nil) end
    end)

    local function runAct(fn,tag)
        task.spawn(function()
            local ok,r,msg=xpcall(fn,tb)
            if not ok then Diag.err(tag or "ui",r) X.notify("Terjadi error (lihat Diagnostics)","bad",4)
            elseif r==false then X.notify(tostring(msg or "Gagal"),"bad",4)
            elseif type(msg)=="string" then X.notify(msg,"good",4) end
        end)
    end
    local function abtn(parent,text,fn,col,size)
        local b=mkBtn(parent,text,size or UDim2.new(1,0,0,34),col or C.p3)
        b.Activated:Connect(function() runAct(fn,"btn:"..text) end)
        return b
    end
    local function cbtn(parent,text,fn,col,size)
        local b=mkBtn(parent,text,size or UDim2.new(1,0,0,34),col or C.p3)
        local armed=false
        b.Activated:Connect(function()
            if not armed then
                armed=true b.Text="YAKIN? TAP LAGI"
                task.delay(3,function() if armed and b.Parent then armed=false b.Text=text end end)
                return
            end
            armed=false b.Text=text
            runAct(fn,"confirm:"..text)
        end)
        return b
    end
    local function chips(parent,opts,default,onPick)
        local bar=N("ScrollingFrame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,32),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.X,ScrollBarThickness=0,ScrollingDirection=Enum.ScrollingDirection.X,BorderSizePixel=0},parent)
        N("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,5),VerticalAlignment=Enum.VerticalAlignment.Center},bar)
        local cur=default
        local btns={}
        local function paint()
            for o,b in pairs(btns) do
                local sel=o==cur
                tw(b,.12,{BackgroundColor3=sel and C.ac:Lerp(C.p1,.55) or C.p3,TextColor3=sel and C.tx or C.mut})
            end
        end
        for _,o in ipairs(opts) do
            local label=type(o)=="table" and o[1] or o
            local b=mkBtn(bar,tostring(label),UDim2.new(0,0,0,30),C.p3,{AutomaticSize=Enum.AutomaticSize.X,TextColor3=C.mut})
            N("UIPadding",{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)},b)
            btns[o]=b
            b.Activated:Connect(function() cur=o paint() if onPick then onPick(o) end end)
        end
        paint()
        return {get=function() return cur end,set=function(v) cur=v paint() end}
    end
    local function field(parent,label,ph,default)
        local t=K.Input(parent,"__f",label,nil,ph,nil,true)
        if default then t.Text=default end
        return t
    end
    local function kv(parent,label,value,col)
        local r=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,20)},parent)
        T(r,label,12,C.mut,false,{Size=UDim2.new(.5,0,1,0)})
        return T(r,tostring(value),12,col or C.tx,true,{Size=UDim2.new(.5,0,1,0),Position=UDim2.new(.5,0,0,0),TextXAlignment=Enum.TextXAlignment.Right,TextTruncate=Enum.TextTruncate.AtEnd})
    end
    local function clearKids(f) for _,c in ipairs(f:GetChildren()) do if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end end end
    local function modal(titleTxt,build)
        local gui=X.ui.gui
        local shade=N("TextButton",{Text="",AutoButtonColor=false,BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.45,Size=UDim2.fromScale(1,1),ZIndex=150},gui)
        local card=N("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(.92,0,.84,0),BackgroundColor3=C.p2,BorderSizePixel=0},shade)
        N("UISizeConstraint",{MaxSize=Vector2.new(460,430)},card)
        corner(card,12) strokeOf(card,C.ac,1.2)
        T(card,titleTxt,14,C.tx,true,{Position=UDim2.fromOffset(14,12),Size=UDim2.new(1,-64,0,20),TextTruncate=Enum.TextTruncate.AtEnd})
        local x=mkBtn(card,"×",UDim2.fromOffset(30,28),C.p3,{Position=UDim2.new(1,-40,0,8),TextSize=14})
        local sc=N("ScrollingFrame",{BackgroundTransparency=1,Position=UDim2.fromOffset(0,44),Size=UDim2.new(1,0,1,-44),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3,BorderSizePixel=0},card)
        N("UIListLayout",{Padding=UDim.new(0,8)},sc)
        N("UIPadding",{PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14),PaddingBottom=UDim.new(0,12)},sc)
        local function close() if shade.Parent then shade:Destroy() end end
        x.Activated:Connect(close)
        build(sc,close)
    end

    local function showPreview(p)
        local st,msg,clean=Presets.validate(p)
        modal("Preview: "..tostring(p.name),function(sc,close)
            local stCol=st=="ok" and C.good or (st=="partial" and C.warn or C.bad)
            wrapT(sc,("Uploader: @%s  |  v%s  |  %s"):format(tostring(p.by),tostring(p.rev or 1),fmtDate(p.at)),11,C.mut)
            wrapT(sc,"Game: "..tostring(p.game or "Universal"),11,C.mut)
            wrapT(sc,"Kompatibilitas: "..(st=="ok" and "KOMPATIBEL" or (st=="partial" and "SEBAGIAN" or "TIDAK KOMPATIBEL")).." - "..msg,11,stCol,true)
            if p.desc and p.desc~="" then wrapT(sc,tostring(p.desc),12,C.tx) end
            local on,off={},{}
            for _,f in ipairs(FEATURES) do
                if clean[f[1]]==true then on[#on+1]=f[2] elseif clean[f[1]]==false then off[#off+1]=f[2] end
            end
            K.Section(sc,"FITUR AKTIF ("..#on..")")
            if #on==0 then wrapT(sc,"Tidak ada fitur yang dinyalakan.",11,C.mut) end
            for _,n in ipairs(on) do wrapT(sc,"+ "..n,12,C.good) end
            K.Section(sc,"FITUR NONAKTIF ("..#off..")")
            if #off==0 then wrapT(sc,"-",11,C.mut) end
            for _,n in ipairs(off) do wrapT(sc,"- "..n,12,C.mut) end
            local isFeat={}
            for _,f in ipairs(FEATURES) do isFeat[f[1]]=true end
            local keys={}
            for k in pairs(clean) do if not isFeat[k] then keys[#keys+1]=k end end
            table.sort(keys)
            K.Section(sc,"PENGATURAN LAIN ("..#keys..")")
            for i=1,math.min(#keys,16) do wrapT(sc,keys[i].." = "..tostring(clean[keys[i]]),11,C.tx) end
            abtn(sc,"APPLY PRESET",function() local ok,m=Presets.apply(p) if ok then close() end return ok,m end,C.ac:Lerp(C.p3,.5))
            abtn(sc,"SALIN JSON PRESET",function()
                if not HAS_CLIP then return false,"Clipboard API tidak tersedia" end
                setclipboard(Presets.exportJson(p)) return true,"JSON preset disalin"
            end)
        end)
    end

    local function bubble(parent,p)
        local mine=tonumber(p.uid)==Player.UserId
        local st,msg=Presets.validate(p)
        local isAct=Store.d.active~=nil and Store.d.active.id==p.id
        local row=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},parent)
        N("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},row)
        local avWrap=N("Frame",{BackgroundTransparency=1,Size=UDim2.fromOffset(46,46),LayoutOrder=1},row)
        Avatar.mount(avWrap,tonumber(p.uid) or 0,46,true,p.by)
        local bub=N("Frame",{BackgroundColor3=isAct and C.ac:Lerp(C.p2,.82) or C.p2,Size=UDim2.new(1,-54,0,0),AutomaticSize=Enum.AutomaticSize.Y,BorderSizePixel=0,LayoutOrder=2},row)
        corner(bub,12) strokeOf(bub,isAct and C.ac or C.line,isAct and 1.4 or 1)
        N("UIPadding",{PaddingTop=UDim.new(0,9),PaddingBottom=UDim.new(0,9),PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)},bub)
        N("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},bub)
        local head=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,34)},bub)
        T(head,tostring(p.name),14,C.tx,true,{Size=UDim2.new(1,-90,0,18),TextTruncate=Enum.TextTruncate.AtEnd})
        T(head,("%s (@%s) | v%s | %s"):format(tostring(p.display or p.by or "?"),tostring(p.by or "?"),tostring(p.rev or 1),fmtDate(p.at)),10,C.mut,false,{Position=UDim2.fromOffset(0,19),Size=UDim2.new(1,0,0,14),TextTruncate=Enum.TextTruncate.AtEnd})
        T(head,st=="ok" and "KOMPATIBEL" or (st=="partial" and "SEBAGIAN" or "TIDAK COCOK"),9,st=="ok" and C.good or (st=="partial" and C.warn or C.bad),true,{Size=UDim2.new(0,88,0,14),Position=UDim2.new(1,-88,0,2),TextXAlignment=Enum.TextXAlignment.Right})
        if p.desc and p.desc~="" then wrapT(bub,tostring(p.desc),11,C.mut) end
        local on=type(p.on)=="table" and p.on or {}
        local off=type(p.off)=="table" and p.off or {}
        local chipBox=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},bub)
        N("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Wraps=true,Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder},chipBox)
        for i=1,math.min(#on,12) do
            local c=N("TextLabel",{Text=tostring(on[i]),TextSize=10,Font=Enum.Font.GothamBold,TextColor3=C.tx,BackgroundColor3=C.ac:Lerp(C.p1,.6),AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.fromOffset(0,20),BorderSizePixel=0},chipBox)
            corner(c,10) N("UIPadding",{PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)},c)
        end
        if #on==0 then T(chipBox,"Tidak ada fitur aktif",10,C.mut,false,{Size=UDim2.new(1,0,0,16)}) end
        T(bub,("%d fitur aktif | %d nonaktif"):format(#on,#off),10,C.mut,false,{Size=UDim2.new(1,0,0,14)})
        if st~="ok" then wrapT(bub,msg,10,st=="partial" and C.warn or C.bad) end
        local grid=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},bub)
        N("UIGridLayout",{CellSize=UDim2.new(.25,-5,0,28),CellPadding=UDim2.fromOffset(5,5),SortOrder=Enum.SortOrder.LayoutOrder},grid)
        local function gb(txt,order,col,fn,confirm)
            local x=mkBtn(grid,txt,UDim2.new(),col or C.p3,{TextSize=10,LayoutOrder=order})
            local armed=false
            x.Activated:Connect(function()
                if confirm and not armed then
                    armed=true x.Text="YAKIN?"
                    task.delay(3,function() if armed and x.Parent then armed=false x.Text=txt end end)
                    return
                end
                armed=false
                runAct(fn,"preset:"..txt)
            end)
            return x
        end
        gb("SHOW",1,C.p3,function() showPreview(p) return true end)
        gb(isAct and "LEPAS" or "PAKAI",2,isAct and C.bad:Lerp(C.p3,.5) or C.ac:Lerp(C.p3,.5),function()
            if isAct then return Presets.release() end
            return Presets.apply(p)
        end)
        local fav=Store.d.fav[p.id]==true
        local fb
        fb=gb(fav and "FAV *" or "FAV",3,fav and C.warn:Lerp(C.p3,.6) or C.p3,function()
            local v=not Store.d.fav[p.id]
            Store.d.fav[p.id]=v or nil
            Store.touch()
            fb.Text=v and "FAV *" or "FAV"
            tw(fb,.12,{BackgroundColor3=v and C.warn:Lerp(C.p3,.6) or C.p3})
            return true,v and "Ditambahkan ke favorit" or "Dihapus dari favorit"
        end)
        if mine or Auth.can("delpreset") then
            gb("HAPUS",4,C.bad:Lerp(C.p3,.6),function()
                if mine then return Presets.deleteOwn(p.id) end
                return Adm.exec("delpreset",{id=p.id})
            end,true)
        end
    end

    function Pages.Preset(page)
        local Q={search="",filter="Semua",sort="Terbaru",limit=12}
        local act=K.Card(page,"Preset Aktif")
        K.Live(act,"Sedang dipakai",function()
            local a=Store.d.active
            if a then return tostring(a.name).." oleh @"..tostring(a.by),C.good end
            return "Tidak ada (pengaturan manual)",C.mut
        end)
        abtn(act,"Lepas Preset (kembalikan pengaturan)",function() return Presets.release() end)
        local src=K.Card(page,"Sumber Data")
        K.Live(src,"Mode",function() return Net.url~="" and "BACKEND" or "LOKAL (perangkat ini)",Net.url~="" and C.good or C.warn end)
        K.Live(src,"Koneksi",function() return Net.state,Net.kind=="good" and C.good or (Net.kind=="bad" and C.bad or C.warn) end)
        K.Live(src,"Jumlah preset",function() return #Presets.src() end)
        local up=K.Card(page,"Unggah Preset")
        local nameBox=field(up,"Nama preset","3-32 karakter: huruf, angka, spasi, - _ .","MyPreset")
        local descBox=field(up,"Deskripsi","Opsional, maks 140 karakter")
        abtn(up,"Unggah Pengaturan Saat Ini",function() return Presets.upload(nameBox.Text,descBox.Text) end,C.ac:Lerp(C.p3,.55))
        local io=K.Card(page,"Impor / Ekspor")
        abtn(io,"Salin Pengaturan Saat Ini (JSON)",function()
            if not HAS_CLIP then return false,"Clipboard API tidak tersedia" end
            setclipboard(Presets.exportJson()) return true,"JSON disalin ke clipboard"
        end)
        local impBox=field(io,"Impor JSON preset / config","Tempel JSON di sini")
        abtn(io,"Impor ke Library Lokal",function()
            local ok,m=Presets.importJson(impBox.Text)
            if ok then impBox.Text="" end
            return ok,m
        end)
        local flt=K.Card(page,"Cari, Filter, Urutkan")
        local searchBox=field(flt,"Cari","Nama, uploader, atau fitur")
        local listBox=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},page)
        N("UIListLayout",{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder},listBox)
        local render
        local token=0
        render=function()
            token+=1
            clearKids(listBox)
            local items=Presets.query(Q)
            if #items==0 then wrapT(listBox,"Belum ada preset yang cocok. Unggah preset pertama atau ubah filter.",12,C.mut) return end
            for i=1,math.min(#items,Q.limit) do
                local ok,err=pcall(bubble,listBox,items[i])
                if not ok then Diag.err("preset-ui",err) end
            end
            if #items>Q.limit then
                abtn(listBox,"Muat lebih banyak ("..(#items-Q.limit).." lagi)",function() Q.limit+=12 render() return true end)
            end
        end
        chips(flt,{"Semua","Milikku","Favorit","Kompatibel"},"Semua",function(o) Q.filter=o Q.limit=12 render() end)
        chips(flt,{"Terbaru","Nama","Favorit","Fitur"},"Terbaru",function(o) Q.sort=o render() end)
        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
            local my=token+1
            task.delay(.35,function()
                if my~=token+1 then return end
                Q.search=searchBox.Text Q.limit=12
                if listBox.Parent then render() end
            end)
        end)
        X.presetsChanged=function() if listBox.Parent then render() end end
        render()
    end

    function Pages.Admin(page)
        local head=K.Card(page)
        local hrow=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,40)},head)
        cxMark(hrow,36)
        local titleLbl=T(hrow,"STAFF LOGIN",15,C.ac,true,{Position=UDim2.fromOffset(46,2),Size=UDim2.new(1,-50,0,18)})
        T(hrow,"CAZIELX ARCHX / manajemen pengguna script",10,C.mut,false,{Position=UDim2.fromOffset(46,22),Size=UDim2.new(1,-50,0,14),TextTruncate=Enum.TextTruncate.AtEnd})
        local body=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},page)
        N("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},body)
        local V={}
        local state={gen=0,cur="OVERVIEW",target=nil}
        local function dashTitle()
            if not Auth.logged then return "STAFF LOGIN" end
            if Auth.role=="dev" then return "DEVELOPER DASHBOARD" end
            if Auth.role=="admin" then return "ADMIN DASHBOARD" end
            return "MODERATOR PANEL"
        end
        local renderBody
        local function stale(g,v) return g~=state.gen or not v.Parent end
        local function userLine(u)
            local ban=type(u.ban)=="table" and u.ban or nil
            local parts={tostring(u.role or "user")}
            if u.last and nowT()-(tonumber(u.last) or 0)<=120 then parts[#parts+1]="ONLINE" elseif u.last then parts[#parts+1]="terakhir "..fmtDate(u.last) end
            if ban and ((tonumber(ban.exp) or 0)==0 or ban.exp>nowT()) then
                parts[#parts+1]=string.upper(tostring(ban.kind or "ban")).." "..(((tonumber(ban.exp) or 0)>0) and fmtLeft(ban.exp-nowT()) or "permanen")
            end
            return table.concat(parts," | ")
        end
        local function userRow(parent,u,onPick)
            local r=N("Frame",{BackgroundColor3=C.p1,Size=UDim2.new(1,0,0,50),BorderSizePixel=0},parent)
            corner(r,8) strokeOf(r)
            local av=N("Frame",{BackgroundTransparency=1,Position=UDim2.fromOffset(7,8),Size=UDim2.fromOffset(34,34)},r)
            Avatar.mount(av,tonumber(u.id) or 0,34,true,u.name)
            T(r,"@"..tostring(u.name or u.id),12,C.tx,true,{Position=UDim2.fromOffset(50,6),Size=UDim2.new(1,-120,0,16),TextTruncate=Enum.TextTruncate.AtEnd})
            T(r,userLine(u),10,C.mut,false,{Position=UDim2.fromOffset(50,25),Size=UDim2.new(1,-120,0,14),TextTruncate=Enum.TextTruncate.AtEnd})
            if onPick then
                local b=mkBtn(r,"PILIH",UDim2.fromOffset(58,28),C.p3,{Position=UDim2.new(1,-66,.5,-14),TextSize=10})
                b.Activated:Connect(function() onPick(u) end)
            end
        end
        local function loadUsers(v,g,cb)
            local lbl=wrapT(v,"Memuat data pengguna...",11,C.mut)
            task.spawn(function()
                local ok,items=Adm.fetch("users")
                if stale(g,v) then return end
                if lbl.Parent then lbl:Destroy() end
                if not ok then wrapT(v,"Gagal memuat: "..tostring(items),11,C.bad) return end
                table.sort(items,function(a,b) return (tonumber(a.last) or 0)>(tonumber(b.last) or 0) end)
                cb(items)
            end)
        end

        V.OVERVIEW=function(v,g)
            local c=K.Card(v,"Ringkasan")
            kv(c,"Mode",Auth.mode=="backend" and "BACKEND" or "LOKAL",Auth.mode=="backend" and C.good or C.warn)
            kv(c,"Koneksi",Net.state,Net.kind=="good" and C.good or (Net.kind=="bad" and C.bad or C.warn))
            kv(c,"Role saya",Auth.role)
            kv(c,"Interval polling",math.floor(Sync.interval()).." dtk")
            kv(c,"Preset di library",#Presets.src())
            local pub=0
            for _,a in ipairs(Ann.src()) do if type(a)=="table" and Ann.status(a)=="TERBIT" then pub+=1 end end
            kv(c,"Pengumuman terbit",pub)
            local uL=kv(c,"Pengguna terdaftar","memuat...",C.mut)
            local oL=kv(c,"Pengguna online","memuat...",C.mut)
            local bL=kv(c,"Ban aktif","memuat...",C.mut)
            local kL=kv(c,"Blacklist aktif","memuat...",C.mut)
            task.spawn(function()
                local ok,items=Adm.fetch("users")
                if stale(g,v) then return end
                if not ok then uL.Text="gagal" oL.Text="gagal" bL.Text="gagal" kL.Text="gagal" return end
                local on,bn,kn=0,0,0
                for _,u in ipairs(items) do
                    if u.last and nowT()-(tonumber(u.last) or 0)<=120 then on+=1 end
                    local b=type(u.ban)=="table" and u.ban or nil
                    if b and ((tonumber(b.exp) or 0)==0 or b.exp>nowT()) then if b.kind=="blacklist" then kn+=1 else bn+=1 end end
                end
                uL.Text,oL.Text,bL.Text,kL.Text=tostring(#items),tostring(on),tostring(bn),tostring(kn)
                uL.TextColor3,oL.TextColor3,bL.TextColor3,kL.TextColor3=C.tx,C.tx,C.tx,C.tx
            end)
            abtn(c,"Segarkan",function() Sync.requestNow() renderBody() return true end)
            if Auth.mode~="backend" then wrapT(c,"Mode lokal: data hanya mencakup perangkat ini. Ban, role, dan pengumuman global membutuhkan backend.",10,C.warn) end
        end

        V.PENGGUNA=function(v,g)
            local a=K.Card(v,"Tindakan Moderasi")
            local target=field(a,"Target (username atau UserId)","contoh: Roblox atau 1")
            if state.target then target.Text=state.target end
            K.Section(a,"DURASI")
            local dur=chips(a,DUR_OPTS,DUR_OPTS[3])
            local custom=field(a,"Durasi kustom (menit, opsional)","kosongkan untuk memakai pilihan di atas")
            local reason=field(a,"Alasan","opsional, maks 120 karakter")
            local function params()
                local m=tonumber(custom.Text)
                local d=(m and m>0) and math.floor(m*60) or dur.get()[2]
                return {target=target.Text,duration=d,reason=reason.Text}
            end
            local grid=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},a)
            N("UIGridLayout",{CellSize=UDim2.new(.5,-4,0,34),CellPadding=UDim2.fromOffset(8,6),SortOrder=Enum.SortOrder.LayoutOrder},grid)
            local bad=C.bad:Lerp(C.p3,.5)
            cbtn(grid,"BAN",function() return Adm.exec("ban",params()) end,bad,UDim2.new())
            cbtn(grid,"BLACKLIST",function() return Adm.exec("blacklist",params()) end,bad,UDim2.new())
            cbtn(grid,"UNBAN",function() local r,m=Adm.exec("unban",params()) if r then renderBody() end return r,m end,C.good:Lerp(C.p3,.6),UDim2.new())
            cbtn(grid,"KICK",function() return Adm.exec("kick",params()) end,C.warn:Lerp(C.p3,.6),UDim2.new())
            wrapT(a,"Ban: pengguna tidak bisa memakai script. Blacklist: ban + preset pengguna disembunyikan dan upload diblokir. Kick membutuhkan backend.",10,C.mut)
            local lc=K.Card(v,"Pengguna Script")
            abtn(lc,"Segarkan Daftar",function() renderBody() return true end)
            local listF=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},lc)
            N("UIListLayout",{Padding=UDim.new(0,6)},listF)
            loadUsers(listF,g,function(items)
                if #items==0 then wrapT(listF,"Belum ada data pengguna.",11,C.mut) return end
                for i=1,math.min(#items,20) do
                    userRow(listF,items[i],function(u) state.target=tostring(u.name or u.id) target.Text=state.target X.notify("Target: @"..state.target,"info",2) end)
                end
                if #items>20 then wrapT(listF,"Menampilkan 20 dari "..#items.." pengguna. Gunakan kolom target untuk yang lain.",10,C.mut) end
            end)
        end

        V.PRESET=function(v,g)
            local c=K.Card(v,"Semua Preset")
            local q=field(c,"Cari","Nama atau uploader")
            local listF=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},c)
            N("UIListLayout",{Padding=UDim.new(0,6)},listF)
            local function draw()
                clearKids(listF)
                local items=Presets.query({search=q.Text,filter="Semua",sort="Terbaru"})
                if #items==0 then wrapT(listF,"Tidak ada preset.",11,C.mut) return end
                for i=1,math.min(#items,30) do
                    local p=items[i]
                    local r=N("Frame",{BackgroundColor3=C.p1,Size=UDim2.new(1,0,0,50),BorderSizePixel=0},listF)
                    corner(r,8) strokeOf(r)
                    T(r,tostring(p.name),12,C.tx,true,{Position=UDim2.fromOffset(10,6),Size=UDim2.new(1,-90,0,16),TextTruncate=Enum.TextTruncate.AtEnd})
                    T(r,("@%s | v%s | %d fitur aktif | %s"):format(tostring(p.by),tostring(p.rev or 1),#(p.on or {}),fmtDate(p.at)),10,C.mut,false,{Position=UDim2.fromOffset(10,26),Size=UDim2.new(1,-90,0,14),TextTruncate=Enum.TextTruncate.AtEnd})
                    local b=mkBtn(r,"HAPUS",UDim2.fromOffset(64,28),C.bad:Lerp(C.p3,.6),{Position=UDim2.new(1,-72,.5,-14),TextSize=10})
                    local armed=false
                    b.Activated:Connect(function()
                        if not armed then armed=true b.Text="YAKIN?" task.delay(3,function() if armed and b.Parent then armed=false b.Text="HAPUS" end end) return end
                        armed=false
                        runAct(function()
                            local ok,m=Adm.exec("delpreset",{id=p.id})
                            if ok then draw() end
                            return ok,m
                        end,"admin-delpreset")
                    end)
                end
            end
            local debounce=0
            q:GetPropertyChangedSignal("Text"):Connect(function()
                debounce+=1 local my=debounce
                task.delay(.35,function() if my==debounce and listF.Parent then draw() end end)
            end)
            draw()
            if not Auth.can("delpreset") then wrapT(c,"Role kamu tidak punya izin menghapus preset.",10,C.warn) end
        end

        V.PENGUMUMAN=function(v,g)
            local f=K.Card(v,"Buat / Edit Pengumuman")
            local title=field(f,"Judul","3-90 karakter")
            local bodyBox=field(f,"Isi","3-900 karakter")
            K.Section(f,"KATEGORI")
            local cat=chips(f,ANN_CATS,ANN_CATS[1])
            local fixedPub,fixedExp
            local PUB={{"Sekarang",0},{"+10 mnt",600},{"+1 jam",3600},{"+1 hari",86400}}
            local EXP={{"Tanpa batas",0},{"1 jam",3600},{"1 hari",86400},{"7 hari",604800},{"30 hari",2592000}}
            K.Section(f,"WAKTU PUBLIKASI")
            local pub=chips(f,PUB,PUB[1],function() fixedPub=nil end)
            K.Section(f,"MASA BERLAKU")
            local exp=chips(f,EXP,EXP[1],function() fixedExp=nil end)
            K.Section(f,"STATUS")
            local stt=chips(f,{"Terbitkan","Draft"},"Terbitkan")
            local editId,editLabel
            editLabel=wrapT(f,"",10,C.warn)
            local function params()
                local pa=fixedPub or (nowT()+pub.get()[2])
                local ex=fixedExp
                if ex==nil then local d=exp.get()[2] ex=d>0 and (pa+d) or 0 end
                return {id=editId,title=title.Text,body=bodyBox.Text,category=cat.get(),publishAt=pa,expiresAt=ex,status=stt.get()=="Draft" and "draft" or "published"}
            end
            abtn(f,editId and "Simpan Perubahan" or "Simpan Pengumuman",function()
                local ok,m=Adm.exec("saveann",params())
                if ok then renderBody() end
                return ok,m
            end,C.ac:Lerp(C.p3,.55))
            abtn(f,"Preview Dialog",function()
                local p=params()
                local ok,a=Ann.validate(p)
                if not ok then return false,a end
                X.showAnnouncement({title=a.title,message=a.body,category=a.category})
                return true
            end)
            if not Auth.can("saveann") then wrapT(f,"Role kamu tidak punya izin membuat pengumuman.",10,C.warn) end
            local lc=K.Card(v,"Daftar Pengumuman")
            local listF=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},lc)
            N("UIListLayout",{Padding=UDim.new(0,6)},listF)
            local lbl=wrapT(listF,"Memuat...",11,C.mut)
            task.spawn(function()
                local ok,items=Adm.fetch("anns")
                if stale(g,v) then return end
                if lbl.Parent then lbl:Destroy() end
                if not ok then wrapT(listF,"Gagal memuat: "..tostring(items),11,C.bad) return end
                table.sort(items,function(a,b) return (tonumber(a.createdAt) or 0)>(tonumber(b.createdAt) or 0) end)
                if #items==0 then wrapT(listF,"Belum ada pengumuman.",11,C.mut) return end
                for i=1,math.min(#items,25) do
                    local a=items[i]
                    local st=Ann.status(a)
                    local r=N("Frame",{BackgroundColor3=C.p1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BorderSizePixel=0},listF)
                    corner(r,8) strokeOf(r)
                    N("UIPadding",{PaddingTop=UDim.new(0,8),PaddingBottom=UDim.new(0,8),PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)},r)
                    N("UIListLayout",{Padding=UDim.new(0,4)},r)
                    wrapT(r,tostring(a.title),12,C.tx,true)
                    wrapT(r,("%s | %s | v%s | %s"):format(tostring(a.category),st,tostring(a.rev or 1),fmtDate(a.publishAt)),10,st=="TERBIT" and C.good or C.mut)
                    local gr=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},r)
                    N("UIGridLayout",{CellSize=UDim2.new(.5,-4,0,28),CellPadding=UDim2.fromOffset(8,6)},gr)
                    local eb=mkBtn(gr,"EDIT",UDim2.new(),C.p3,{TextSize=10})
                    eb.Activated:Connect(function()
                        editId=a.id title.Text=tostring(a.title) bodyBox.Text=tostring(a.body)
                        if table.find(ANN_CATS,a.category) then cat.set(a.category) end
                        stt.set(a.status=="draft" and "Draft" or "Terbitkan")
                        fixedPub,fixedExp=tonumber(a.publishAt),tonumber(a.expiresAt) or 0
                        editLabel.Text="Mode edit: "..tostring(a.title).." (waktu lama dipertahankan sampai kamu memilih ulang)"
                        X.notify("Data dimuat ke form di atas","info",2)
                    end)
                    cbtn(gr,"HAPUS",function()
                        local ok2,m=Adm.exec("delann",{id=a.id})
                        if ok2 then renderBody() end
                        return ok2,m
                    end,C.bad:Lerp(C.p3,.6),UDim2.new())
                end
            end)
        end

        V.ROLE=function(v,g)
            if not Auth.can("setrole") then wrapT(K.Card(v,"Akses ditolak"),"Set Role hanya untuk Developer.",11,C.bad) return end
            local a=K.Card(v,"Atur Role")
            local target=field(a,"Target (username atau UserId)","contoh: Roblox")
            local opts={}
            for _,r in ipairs(ROLE_LIST) do if (ROLE_RANK[r] or 1)<(ROLE_RANK[Auth.role] or 1) then opts[#opts+1]=r end end
            if #opts==0 then wrapT(a,"Role kamu tidak bisa mengatur role lain.",11,C.warn) return end
            local pick=chips(a,opts,opts[1])
            cbtn(a,"SET ROLE",function()
                local ok,m=Adm.exec("setrole",{target=target.Text,role=pick.get()})
                if ok then renderBody() end
                return ok,m
            end,C.ac:Lerp(C.p3,.55))
            local lc=K.Card(v,"Staf dan VIP")
            local listF=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},lc)
            N("UIListLayout",{Padding=UDim.new(0,6)},listF)
            loadUsers(listF,g,function(items)
                local n=0
                for _,u in ipairs(items) do
                    if u.role and u.role~="user" then n+=1 userRow(listF,u,function(x) target.Text=tostring(x.name or x.id) end) end
                end
                if n==0 then wrapT(listF,"Belum ada pengguna dengan role khusus.",11,C.mut) end
            end)
        end

        V.LOG=function(v,g)
            local c=K.Card(v,"Log Aktivitas")
            local lbl=wrapT(c,"Memuat...",11,C.mut)
            task.spawn(function()
                local ok,items=Adm.fetch("logs")
                if stale(g,v) then return end
                if lbl.Parent then lbl:Destroy() end
                if not ok then wrapT(c,"Gagal memuat: "..tostring(items),11,C.bad) return end
                if #items==0 then wrapT(c,"Belum ada aktivitas.",11,C.mut) return end
                for i=1,math.min(#items,40) do
                    local l=items[i]
                    wrapT(c,("%s | %s | %s -> %s %s"):format(fmtDate(l.t),tostring(l.by),tostring(l.a),tostring(l.to),tostring(l.d or "")),10,C.tx)
                end
            end)
            abtn(c,"Segarkan",function() renderBody() return true end)
        end

        local function accountCard(v)
            local a=K.Card(v,"Akun")
            kv(a,"Akun",Player.Name)
            kv(a,"Developer terdeteksi",Auth.isDev and "YA" or "TIDAK",Auth.isDev and C.good or C.mut)
            kv(a,"Role sesi",Auth.role)
            kv(a,"Pengumuman realtime",Ann.streamState,Ann.streamState=="LIVE" and C.good or C.warn)
            abtn(a,"Logout",function() Auth.logout() X.refreshAdmin() renderBody() return true,"Logout berhasil" end)
        end
        V.AKUN=function(v,g) accountCard(v) end
        V.PENGATURAN=function(v,g)
            if not Auth.can("sysconfig") then wrapT(K.Card(v,"Akses ditolak"),"Pengaturan sistem hanya untuk Developer.",11,C.bad) return end
            local c=K.Card(v,"Backend Sinkronisasi")
            kv(c,"Mode",Net.url~="" and "BACKEND" or "LOKAL",Net.url~="" and C.good or C.warn)
            kv(c,"Status",Net.state,Net.kind=="good" and C.good or (Net.kind=="bad" and C.bad or C.warn))
            local urlBox=field(c,"URL backend (https://)","https://contoh.domain/api",Net.url)
            abtn(c,"Simpan dan Uji Koneksi",function()
                local ok,u=Net.validate(urlBox.Text)
                if not ok then return false,u end
                Net.url=u Net.token=nil Net.rev={p=-1,a=-1} Net.fails=0
                Auth.logout()
                local saved,why=Net.saveFile()
                local r,res=Net.call("/session",{display=Player.DisplayName,game=X.game.name,placeId=game.PlaceId,version=X.VERSION})
                Sync.requestNow()
                renderBody()
                if not r then return false,"URL disimpan"..(saved and "" or " (sesi ini saja)")..", tetapi koneksi gagal: "..tostring(res) end
                return true,"Terhubung ke backend. Login admin ulang diperlukan."
            end,C.ac:Lerp(C.p3,.55))
            cbtn(c,"Kembali ke Mode Lokal",function()
                Net.url="" Net.token=nil Net.state,Net.kind,Net.detail="LOKAL","warn","backend dinonaktifkan"
                Auth.logout()
                if HAS_FILES then pcall(writefile,BACKEND_FILE,HttpService:JSONEncode({v=1,url=""})) end
                renderBody()
                return true,"Mode lokal aktif"
            end)
            wrapT(c,"Verifikasi key, ban, role, dan penghapusan data global dilakukan oleh backend. Script ini hanya klien: tanpa backend, semua efek hanya berlaku di perangkat ini.",10,C.mut)
            accountCard(v)
        end

        local NAVS={
            dev={"OVERVIEW","PENGGUNA","PRESET","PENGUMUMAN","ROLE","LOG","PENGATURAN"},
            admin={"OVERVIEW","PENGGUNA","PRESET","PENGUMUMAN","LOG","AKUN"},
            moderator={"OVERVIEW","PENGGUNA","PRESET","LOG","AKUN"},
        }
        local function navList() if Auth.can("setrole") then return NAVS.dev end return NAVS[Auth.role] or NAVS.moderator end
        local navHolder=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=1},body)
        N("UIListLayout",{},navHolder)
        local view=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=2},body)
        N("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},view)
        local navChips
        renderBody=function()
            state.gen+=1
            local g=state.gen
            clearKids(view)
            clearKids(navHolder)
            titleLbl.Text=dashTitle()
            if not Auth.logged then
                local role=Auth.claimRole()
                local c=K.Card(view,"Login Staf")
                if not role then
                    wrapT(c,"Akun ini tidak terdaftar sebagai staf. Fitur biasa tidak memerlukan login.",11,C.mut)
                    return
                end
                wrapT(c,(role=="dev" and ("Developer terdeteksi otomatis: @"..Player.Name..". ") or "Akun staf terdeteksi. ").."Masukkan key untuk membuka dashboard.",11,C.good)
                kv(c,"Verifikasi",Net.url~="" and "SERVER (backend)" or "LOKAL (hanya perangkat ini)",Net.url~="" and C.good or C.warn)
                local key=field(c,"Key","masukkan key")
                local getKey,clearKey=K.maskInput(key)
                abtn(c,"Masuk",function()
                    local ok,m=Auth.login(getKey())
                    clearKey()
                    if ok then X.refreshAdmin() renderBody() end
                    return ok,m
                end,C.ac:Lerp(C.p3,.55))
                return
            end
            local NAV=navList()
            if not table.find(NAV,state.cur) then state.cur="OVERVIEW" end
            navChips=chips(navHolder,NAV,state.cur,function(o) state.cur=o renderBody() end)
            local fn=V[state.cur]
            if fn then
                local ok,err=pcall(fn,view,g)
                if not ok then Diag.err("admin:"..state.cur,err) wrapT(view,"Bagian ini gagal dibuat: "..tostring(err):sub(1,140),11,C.bad) end
            end
        end
        X.adminRender=function() if body.Parent then renderBody() end end
        renderBody()
    end
end

function Pages.Home(page)
    local compact=X.ui.compact
    local hd=K.Card(page)
    local top=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,124)},hd)
    Avatar.mount(top,Player.UserId,116,false,Player.DisplayName)
    local info=N("Frame",{BackgroundTransparency=1,Position=UDim2.fromOffset(128,0),Size=UDim2.new(1,-128,1,0)},top)
    N("UIListLayout",{Padding=UDim.new(0,3),VerticalAlignment=Enum.VerticalAlignment.Center},info)
    T(info,"CAZIELX ARCHX",20,C.tx,true)
    T(info,("v%s | build %s"):format(X.VERSION,X.BUILD),11,C.mut)
    T(info,"Game: "..X.game.name,11,X.game.target and C.good or C.warn,false,{TextTruncate=Enum.TextTruncate.AtEnd})
    T(info,("%s (@%s)"):format(Player.DisplayName,Player.Name),12,C.tx,true,{TextTruncate=Enum.TextTruncate.AtEnd})
    T(info,("ID %d | role %s"):format(Player.UserId,Auth.logged and Auth.role or (Auth.claimRole() and (Auth.claimRole().." (belum login)") or Net.role)),11,C.mut)
    K.Section(page,"SESSION")
    local g=K.Grid(page,compact and 2 or 3)
    K.Tile(g,"Zone",zoneNow)
    K.Tile(g,"Duration",function() return fmtDur(os.clock()-X.t0) end)
    K.Tile(g,"Money",function() return shortNum(getCash()) end)
    K.Tile(g,"Earnings",function() return shortNum(Ses.earn) end)
    K.Tile(g,"Eggs detected",function() return Eggs.seenCount end)
    K.Tile(g,"Eggs broken",function() return Ses.broken end)
    K.Tile(g,"Animals",function() return Ses.animals end)
    K.Tile(g,"Active features",activeCount)
    K.Section(page,"RUNTIME STATUS")
    local rt=K.Card(page)
    K.Live(rt,"FPS / Ping",function() local p=ping() return ("%d / %s"):format(math.floor(Sched.fps),p and (p.." ms") or "N/A") end)
    for _,f in ipairs({{"farm","Farm / Break"},{"steal","Steal / Collect"},{"swing","Swing"},{"esp","ESP"},{"anti_afk","Anti-AFK"}}) do
        K.Live(rt,f[2],function() local s=fstat(f[1]) return s,select(2,fstat(f[1])) end)
    end
    K.Live(rt,"Webhook",function() return WH.state,WH.kind=="good" and C.good or (WH.kind=="bad" and C.bad or C.warn) end)
end
function Pages.Farm(page)
    local compact=X.ui.compact
    local c=K.Card(page,"Swing Multiplier")
    local grid=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},c)
    N("UIGridLayout",{CellSize=UDim2.new(compact and 1/3 or 1/5,-6,0,54),CellPadding=UDim2.fromOffset(6,6)},grid)
    local cards={}
    for n=1,5 do
        local b=N("TextButton",{Text="",AutoButtonColor=false,BackgroundColor3=C.p3,BorderSizePixel=0},grid) corner(b,8)
        local st=strokeOf(b,C.line,1)
        T(b,n.."x",18,C.tx,true,{Size=UDim2.new(1,0,0,26),Position=UDim2.fromOffset(0,6),TextXAlignment=Enum.TextXAlignment.Center,Name="big"})
        T(b,MULT_NAMES[n],9,C.mut,false,{Size=UDim2.new(1,0,0,14),Position=UDim2.fromOffset(0,32),TextXAlignment=Enum.TextXAlignment.Center,Name="sub"})
        pressFx(b,C.p3)
        b.Activated:Connect(function() X.set("swing_mult",n) end)
        cards[n]=b
    end
    local pulse
    X.ui.mult=function(n)
        if pulse then pcall(pulse.Cancel,pulse) pulse=nil end
        for i,b in pairs(cards) do
            local sel=i==n
            tw(b,.18,{BackgroundColor3=sel and C.ac:Lerp(C.p1,.7) or C.p3})
            local s=b:FindFirstChildOfClass("UIStroke") tw(s,.18,{Color=sel and C.ac or C.line,Thickness=sel and 1.6 or 1,Transparency=0})
            tw(b.big,.18,{TextColor3=sel and C.ac or C.tx})
        end
    end
    X.sync.swing_mult=X.ui.mult X.ui.mult(S.swing_mult)
    local bar=N("Frame",{BackgroundColor3=C.p1,Size=UDim2.new(1,0,0,6),BorderSizePixel=0},c) corner(bar,3)
    local fill=acc(N("Frame",{Size=UDim2.new(0,0,1,0),BorderSizePixel=0},bar),"BackgroundColor3") corner(fill,3)
    X.ui.hit=function() if page.Visible and X.ui.open then fill.BackgroundColor3=C.good tw(fill,.25,{BackgroundColor3=C.ac}) end end
    X.ui.broken=function(l) X.notify("Egg broken: "..l,"good",2.5) end
    K.Live(c,"Swing state",function()
        local a=Sw.active()
        local col=a and C.good or ((Sw.state=="NO PICKAXE" or Sw.state=="ERROR") and C.bad or C.mut)
        local s=cards[S.swing_mult] and cards[S.swing_mult]:FindFirstChildOfClass("UIStroke")
        if s then
            if a and not pulse then pulse=twLoop(s,{Transparency=.6}) elseif not a and pulse then pcall(pulse.Cancel,pulse) pulse=nil s.Transparency=0 end
        end
        local w=Sw.interval()
        local p=a and math.clamp((os.clock()-Sw.lastSend)/w,0,1) or 0
        fill.Size=UDim2.new(p,0,1,0)
        return Sw.state,col
    end,true)
    K.Live(c,"Selected multiplier",function() return ("x%d · %s"):format(Sw.mult,MULT_NAMES[Sw.mult]) end)
    K.Live(c,"Requested speed",function() return ("%.2f hits/s (%.2fs)"):format(1/Sw.req(),Sw.req()) end)
    K.Live(c,"Effective speed",function()
        if Sw.sentV==0 then return "not measured" end
        return ("%.2f hits/s (x%.1f)"):format(Sw.effRate,Sw.effMult()),Sw.effMult()>=Sw.mult*.85 and C.good or C.warn
    end)
    K.Live(c,"Total swings",function() return Sw.sent end)
    K.Live(c,"Successful hits",function() return Sw.conf,C.good end)
    K.Live(c,"Rejected / unconfirmed",function() return ("%d rejected · %d unverified"):format(math.max(Sw.sentV-Sw.conf,0),Sw.unver),C.warn end)
    K.Live(c,"Current pickaxe",function() return Sw.tool end)
    K.Live(c,"Current target",function() return Sw.target end)
    local vd=wrapT(c,"",11,C.mut)
    X.live[#X.live+1]={page=page,fn=function() vd.Text=Sw.verdict..(Sw.verifiable and "" or " | Egg HP unreadable: capped at 1x, cannot verify faster hits.") end}
    local a=K.Card(page,"Automation")
    K.Toggle(a,"farm_auto","Auto Farm","Walks to eggs in the world and breaks them with the swing engine.")
    K.Toggle(a,"farm_break","Auto Break","Swings at eggs within reach, no walking. Auto Farm and Auto Break share one engine (never both).")
    K.Toggle(a,"farm_collect","Auto Collect Animal","After an egg breaks, picks up the animal near it and carries it to your base.")
    K.Toggle(a,"farm_pause","Pause Farm","Pauses farm and pickup without losing statistics.")
    K.Button(a,"Skip Current Egg",function() if not E.target then return false,"No current target" end E.skip[E.target]=os.clock()+120 E.target=nil end)
    K.Choice(a,"farm_equipmode","Pickaxe Equip Mode","Auto equip best, or keep what you hold.",{"Auto equip best","Keep equipped"})
    K.Slider(a,"break_reach","Hit Reach (studs)","Distance before swinging. The server decides the real hit range.",4,30,1)
    local p=K.Card(page,"Pickaxe Detection")
    K.Live(p,"Pickaxe",function() local t,why,eq=Tools.best() if not t then return "none found",C.bad end return t.Name.." · "..(eq and "equipped" or "backpack") end)
    K.Live(p,"Matched by",function() local _,why=Tools.best() return why or "-" end)
    K.Button(p,"Re-detect Pickaxe",function() Tools.dirty=true local t,why=Tools.best() if not t then Diag.set("pickaxe","FAILED","none found") return false,"No pickaxe-like Tool in Backpack/Character" end Diag.set("pickaxe","SUCCESS",t.Name.." via "..why) X.notify("Pickaxe: "..t.Name.." ("..why..")","good",4) end)
    local sc=K.Card(page,"Egg Scanner")
    K.Live(sc,"Eggs in world",function() if Eggs.err then return Eggs.err,C.bad end return #Eggs.cache end)
    K.Live(sc,"Base",function() return Base.obj and "detected" or "not detected",Base.obj and C.good or C.warn end)
    K.Button(sc,"Scan Eggs Now",function()
        local list=Eggs.get(true)
        if Eggs.err then return false,Eggs.err end
        if #list==0 then return false,"No eggs found" end
        local counts,order={}, {}
        for _,e in ipairs(list) do local nm=Eggs.label(e) local _,rn=rarityInfo(Eggs.model[e] or e,nm) local l=nm..(rn~="unknown" and (" ["..rn.."]") or "") if not counts[l] then counts[l]=0 order[#order+1]=l end counts[l]+=1 end
        local parts={} for i=1,math.min(#order,8) do parts[#parts+1]=order[i].." x"..counts[order[i]] end
        X.notify(#list.." eggs: "..table.concat(parts,", "),"info",7)
    end)
    local f=K.Card(page,"Egg Filters & Zone")
    K.Choice(f,"farm_zone","Zone Selection","Only eggs whose zone matches. Eggs with no readable zone stay under Any.",{"Any","1","2","3","4","5","6","7","8","9","10"})
    K.Slider(f,"farm_maxdist","Egg Distance Limit","Maximum (2000) means no limit.",50,2000,50)
    K.Choice(f,"farm_minrar","Egg Rarity Filter","Needs a Rarity attribute/value or a rarity word in the name.",{"Any",table.unpack(RAR)})
    K.Choice(f,"farm_priority","Target Priority","",{"Nearest","Highest rarity","Selected first","Selected only"})
    K.Input(f,"farm_filter","Selected Eggs","Comma-separated names for Selected first/only.","e.g. dragon, golden",function(v) return #v<=120 end)
    K.Input(f,"farm_ignore","Ignore Eggs","Names or rarities that are never targeted.","e.g. common",function(v) return #v<=120 end)
    K.Button(f,"Select All Eggs (clear filters)",function() X.set("farm_filter","",true) X.set("farm_ignore","",true) X.set("farm_minrar","Any",true) X.set("farm_maxdist",2000,true) X.set("farm_priority","Nearest",true) X.set("farm_zone","Any",true) X.notify("Filters cleared","good",2.5) end)
    local tp=K.Card(page,"Teleport Destinations")
    K.Input(tp,"__tp_egg","Egg Name","Find the nearest matching egg by its detected name.","e.g. Golden Egg",nil,true)
    K.Button(tp,"Teleport To Selected Egg",function()
        local ok,why=teleportToEgg(X.tpEggName)
        if not ok then return false,why end
        X.notify(why or "Teleport request completed","good",3)
    end)
    K.Input(tp,"__tp_pos","Custom Position","Enter world coordinates as X, Y, Z.","0, 10, 0",nil,true)
    K.Button(tp,"Teleport To Position",function()
        local a,b,c=tostring(X.tpPosition or ""):match("^%s*(-?[%d%.]+)%s*,%s*(-?[%d%.]+)%s*,%s*(-?[%d%.]+)%s*$")
        a,b,c=tonumber(a),tonumber(b),tonumber(c)
        if not a or not b or not c then return false,"Use coordinates like 120, 15, -40" end
        local ok,why=teleportToPosition(Vector3.new(a,b,c))
        if not ok then return false,why end
        Diag.set("teleport","SUCCESS","Custom position requested")
        X.notify("Position teleport completed","good",3)
    end)
end

function Pages.Steal(page)
    local a=K.Card(page,"Auto Steal")
    K.Toggle(a,"steal_auto","Auto Steal","Pick up animals (ProximityPrompt), carry them to your base, confirm from the carry state. Never targets other players' pets.")
    K.Toggle(a,"steal_guard","Guard Safety","Skip animals with a guard/protector model within 25 studs (name heuristic).")
    K.Choice(a,"steal_priority","Priority","",{"Nearest","Highest rarity","Highest income"})
    K.Choice(a,"steal_minrar","Rarity Filter","",{"Any",table.unpack(RAR)})
    K.Input(a,"steal_species","Animal Names","Comma-separated, empty = any.","e.g. lion, wolf",function(v) return #v<=120 end)
    K.Input(a,"steal_minincome","Minimum Income","Only if the animal exposes income. Empty = none.","e.g. 500",function(v) return v=="" or tonumber(v)~=nil end)
    local t=K.Card(page,"Target Detection")
    K.Live(t,"State",function() return Pk.state.." · "..Pk.status end)
    K.Live(t,"Target",function() return Pk.target and Pk.target.model.Name or "none" end)
    K.Live(t,"Pickups seen",function() return #Pk.list end)
    local c=K.Card(page,"Carry & Collection")
    K.Live(c,"Carrying",function() local v=carryState() return v and "yes" or "no",v and C.good or C.mut end)
    K.Live(c,"Delivered",function() return Pk.delivered,C.good end)
    K.Live(c,"Unverified deliveries",function() return Pk.unverified,C.warn end)
    K.Live(c,"Failed",function() return Pk.failed,Pk.failed>0 and C.bad or C.mut end)
    K.Button(c,"Teleport To Base",function()
        local ok,why=Base.tp()
        if ok then X.notify("Teleported to base","good",3) return end
        return false,why
    end)
end
function Pages.Inventory(page)
    local a=K.Card(page,"Pet Inventory")
    K.List(a,function() local r={} for _,p in ipairs(Inv.pets()) do r[#r+1]=p.name..(p.idx>0 and (" ["..p.rarity.."]") or "")..(p.held and " (held)" or "") end return r end,"No animal Tools in Backpack/hands")
    local b=K.Card(page,"Animal Tracker (session)")
    K.Live(b,"Obtained",function() return Ses.petTotal end)
    K.Live(b,"Best pet",function() return Ses.bestName end)
    K.Live(b,"Last animal",function() return Ses.lastAnimal end)
    K.List(b,function() local r={} for n,c in pairs(Ses.petCounts) do r[#r+1]=n.." x"..c end table.sort(r) return r end,"No pets recorded yet")
    local r=K.Card(page,"Rarity Information")
    K.Choice(r,"pet_rare_min","Rare Pet Threshold","Pets at or above this count as rare (alert + webhook).",RAR)
    K.Toggle(r,"pet_alert","New Pet Alerts","Notification when a pet enters your backpack.")
    K.List(r,function() local cnt,out={}, {} for _,p in ipairs(Inv.pets()) do cnt[p.rarity]=(cnt[p.rarity] or 0)+1 end for k,v in pairs(cnt) do out[#out+1]=k..": "..v end table.sort(out) return out end,"No rarity data exposed")
    local h=K.Card(page,"Collection History")
    T(h,"EGGS BROKEN",10,C.mut,true)
    K.List(h,function() local o={} for i=#Ses.history,math.max(1,#Ses.history-9),-1 do local x=Ses.history[i] o[#o+1]=("%s  %s  x%d"):format(x.at,x.label,x.hits) end return o end,"No eggs broken yet")
    T(h,"PETS",10,C.mut,true)
    K.List(h,function() local o={} for i=#Ses.pets,math.max(1,#Ses.pets-9),-1 do local x=Ses.pets[i] o[#o+1]=("%s  %s%s"):format(x.at,x.name,x.idx>0 and (" ["..x.rarity.."]") or "") end return o end,"No pets recorded yet")
end
function Pages.Visuals(page)
    local a=K.Card(page,"ESP")
    K.Toggle(a,"esp_egg","Egg ESP","Highlights the 15 nearest eggs with name and rarity.")
    K.Toggle(a,"esp_pet","Pet ESP","Shows the animal Tool other players carry.")
    K.Toggle(a,"esp_player","Player ESP","Highlights up to 12 nearby players.")
    K.Toggle(a,"esp_dist","Distance Indicator","Shows distance in studs on labels.")
    local c=K.Card(page,"Visual Customization")
    K.Choice(c,"esp_color","ESP Color","",{"Cyan","Red","Green","Yellow","White"})
    K.Choice(c,"esp_fill","Highlight Fill","",{"Off","Soft","Strong"})
    K.Slider(c,"esp_range","ESP Range (studs)","",100,2000,100)
end
function Pages.Webhook(page)
    local a=K.Card(page,"Konfigurasi Webhook")
    K.Toggle(a,"wh_enable","Aktifkan Webhook","Kirim notifikasi Discord setiap kali kamu berhasil mendapatkan pet. URL tidak ikut diekspor ke config.")
    K.Input(a,"__wh","URL Webhook Discord","Tempel https://discord.com/api/webhooks/ID/TOKEN. Disimpan di file terpisah di perangkat ini.","https://discord.com/api/webhooks/...",nil,true)
    K.Button(a,"Simpan URL",function() local ok,why=whSave() if not ok then return false,why end X.notify("URL webhook disimpan","good",3) end)
    K.Button(a,"Muat URL Tersimpan",function() local ok,why=whLoad() if not ok then return false,why end X.notify("URL webhook dimuat","good",3) end)
    local e=K.Card(page,"Event")
    K.Toggle(e,"wh_ev_pet","Pet didapatkan","Dikirim hanya saat pet benar-benar muncul di inventory. Membuka menu atau event lain tidak mengirim apa pun.")
    wrapT(e,"Isi embed: nama pet, rarity, gambar pet (jika bisa diambil dari data pet), jumlah sesi ini, total pet, zona, pet terbaik sesi, dan info tambahan dari atribut pet.",10,C.mut)
    local s=K.Card(page,"Status Koneksi")
    K.Live(s,"Status",function() return WH.state,WH.kind=="good" and C.good or (WH.kind=="bad" and C.bad or C.warn) end)
    K.Live(s,"Detail",function() return WH.detail end)
    K.Live(s,"Terkirim / gagal",function() return WH.sent.." / "..WH.failed end)
    K.Button(s,"Kirim Contoh Embed Pet",function()
        if not HTTP_REQUEST then return false,"Executor tidak punya fungsi HTTP" end
        local ok,why=whValidate(WH.url) if not ok then return false,why end
        X.petEvent({name="Contoh Pet",rarity="legendary",idx=5,asset=nil,extra={},count=1},true)
        return true
    end)
end
function Pages.Settings(page)
    local t=K.Card(page,"Theme & Animation")
    K.Choice(t,"theme","Theme Accent","",{"Amber","Cyan","Electric","Emerald","Violet"})
    K.Choice(t,"anim_quality","Animation Quality","Off disables every UI tween.",{"Off","Low","Medium","High"})
    K.Slider(t,"ui_scale","UI Scale","",.8,1.2,.05,function(v) return ("%.2fx"):format(v) end)
    local p=K.Card(page,"Performance")
    K.Toggle(p,"perf_mode","Performance Mode","Slower ESP and UI refresh to save FPS.")
    K.Toggle(p,"anti_afk","Anti-AFK","Prevents idle kick (VirtualUser).")
    local c=K.Card(page,"Configuration")
    K.Toggle(c,"auto_save","Auto Save","Saves a moment after any change.")
    K.Button(c,"Save Now",function() saveConfig(false) end)
    K.Button(c,"Load Saved",function() local j=readConfig() or X.memCfg if not j then return false,"No saved configuration" end local ok,m=importConfig(j) if not ok then return false,m end X.notify(m,"good",3) end)
    K.Button(c,"Export To Clipboard",function() if not HAS_CLIP then return false,"No clipboard API" end setclipboard(encodeConfig()) X.notify("Config copied","good",2.5) end)
    K.Input(c,"__imp","Import JSON","Paste an exported config.","{...}",nil,true)
    K.Button(c,"Reset Settings",function() for k,v in pairs(D) do if not k:find("^about_") then X.set(k,v,true) end end saveConfig(true) X.notify("Settings reset","good",3) end,C.bad:Lerp(C.p3,.6))

    local movement=K.Card(page,"Movement")
    K.Toggle(movement,"fly","Fly","Client-side flight using movement input. Server validation may limit or revert it.")
    K.Slider(movement,"fly_speed","Fly Speed","Requested flight speed.",20,120,5)
    K.Button(movement,"Fly Up / Stop Up",function()
        if not S.fly then return false,"Enable Fly first" end
        Fly.vertical=Fly.vertical==1 and 0 or 1
        X.notify(Fly.vertical==1 and "Fly ascent enabled" or "Fly vertical input cleared","info",2)
    end)
    K.Button(movement,"Fly Down / Stop Down",function()
        if not S.fly then return false,"Enable Fly first" end
        Fly.vertical=Fly.vertical==-1 and 0 or -1
        X.notify(Fly.vertical==-1 and "Fly descent enabled" or "Fly vertical input cleared","info",2)
    end)
    K.Toggle(movement,"speed_boost","Speed Boost","Requests a higher local WalkSpeed; the game may override it.")
    K.Slider(movement,"speed_value","Speed Value","Higher values are requests, not guaranteed server movement.",16,150,2)
    K.Toggle(movement,"low_graphics","Low Graphics","Disables local particles, trails, beams and post effects; restores prior states when disabled.")
    wrapT(K.Card(page,"Preset dan Pengumuman"),"Preset ada di tab PRESET. Pengumuman dikelola dari tab ADMIN (khusus developer dan staf).",11,C.mut)
    local d=K.Card(page,"Diagnostics")
    K.List(d,function()
        local r={} for id,f in pairs(Diag.f) do r[#r+1]=("%s: %s%s"):format(id,f.st,f.why and (" ("..tostring(f.why)..")") or "") end table.sort(r) return r end,"No feature state yet")
    T(d,"STARTUP",10,C.mut,true)
    K.List(d,function() local r={} for _,s in ipairs(Diag.stages) do r[#r+1]=s end return r end)
    T(d,"RUNTIME ERRORS",10,C.mut,true)
    K.List(d,function() local r={} for i=#Diag.errs,math.max(1,#Diag.errs-7),-1 do r[#r+1]=Diag.errs[i] end return r end,"No errors recorded")
    K.Button(d,"Copy Diagnostics",function()
        if not HAS_CLIP then return false,"No clipboard API" end
        local o={"CAZIELX ARCHX v"..X.VERSION}
        for id,f in pairs(Diag.f) do o[#o+1]=id.."="..f.st.." "..tostring(f.why) end
        for _,s in ipairs(Diag.stages) do o[#o+1]=s end
        for _,e in ipairs(Diag.errs) do o[#o+1]=e end
        for _,e in ipairs(Diag.cleanup) do o[#o+1]=e end
        setclipboard(table.concat(o,"\n")) X.notify("Diagnostics copied","good",2.5)
    end)
    K.Button(d,"Unload CAZIELX ARCHX",function() X.unload() end,C.bad:Lerp(C.p3,.6))
end
local CHANGELOG={
    "V5.1.1: Admin panel (login key, pengguna, preset, pengumuman, role, log), ban/blacklist berdurasi, set role, unban, kick (backend).",
    "Preset bubble dengan avatar uploader, nama Roblox, preview dialog SHOW, APPLY, validasi kompatibilitas, pakai/lepas, favorit, pencarian, filter, impor dan ekspor. Pengaturan yang dikecualikan (credential, webhook, private, runtime-sensitive) tidak ikut dibagikan.",
    "Pengumuman dari Lua (tanpa GitHub): kategori, jadwal, masa berlaku, riwayat, anti-duplikat, dialog dengan progress 10 detik.",
    "Sinkronisasi backend opsional dengan polling adaptif, retry terbatas, cache lokal, indikator online/offline. Tanpa backend semua data bersifat lokal.",
    "Webhook hanya untuk pet berhasil didapat: nama, rarity, gambar pet, jumlah, total, zona. Avatar profil memakai model karakter.",
    "V6.2: full-screen startup sequence berbasis stage aktual, preset card action SHOW/APPLY, metadata uploader DisplayName + username, identitas build diperbarui. Backend dan fitur game tetap memerlukan pengujian runtime.",
}
function Pages.About(page)
    local a=K.Card(page,"CAZIELX ARCHX")
    T(a,("Version %s · Build %s"):format(X.VERSION,X.BUILD),12,C.tx,true)
    wrapT(a,"Credits: CAZIELX. Based on publicly documented Steal an Egg mechanics; everything else is detected at runtime.",11,C.mut)
    local sy=K.Card(page,"Status Sinkronisasi")
    K.Live(sy,"Mode",function() return Net.url~="" and "BACKEND" or "LOKAL",Net.url~="" and C.good or C.warn end)
    K.Live(sy,"Status",function() return Net.state,Net.kind=="good" and C.good or (Net.kind=="bad" and C.bad or C.warn) end)
    K.Live(sy,"Detail",function() return Net.detail end)
    K.Live(sy,"Polling",function() return math.floor(Sync.interval()).." dtk (polling, bukan push)" end)
    K.Live(sy,"Role sesi",function() return Net.role end)
    K.Button(sy,"Sinkronkan Sekarang",function() Sync.requestNow() X.notify("Sinkronisasi dijadwalkan","info",2) end)
    local hx=K.Card(page,"Riwayat Pengumuman")
    K.List(hx,function()
        local list={}
        for _,a in ipairs(Ann.src()) do if type(a)=="table" and a.title then list[#list+1]=a end end
        table.sort(list,function(x,y) return (tonumber(x.publishAt) or 0)>(tonumber(y.publishAt) or 0) end)
        local rows={}
        for i=1,math.min(#list,15) do rows[#rows+1]=("[%s] %s | %s"):format(tostring(list[i].category),tostring(list[i].title),Ann.status(list[i])) end
        return rows
    end,"Belum ada pengumuman")
    K.Button(hx,"Tampilkan Pengumuman Terbaru",function()
        local best
        for _,a in ipairs(Ann.src()) do if type(a)=="table" and Ann.status(a)=="TERBIT" and (not best or (tonumber(a.publishAt) or 0)>(tonumber(best.publishAt) or 0)) then best=a end end
        if not best then return false,"Belum ada pengumuman terbit" end
        X.showAnnouncement({title=best.title,message=best.body,category=best.category})
    end)
    local c=K.Card(page,"Changelog")
    for _,l in ipairs(CHANGELOG) do wrapT(c,"• "..l,11,C.tx) end
    local s=K.Card(page,"Social Links")
    local function isUrl(v) return v=="" or v:match("^https?://%S+$")~=nil end
    for _,l in ipairs({{"about_discord","Discord"},{"about_social","Social"},{"about_link","Credit"}}) do
        K.Input(s,l[1],l[2].." Link","Nothing is pre-filled.","https://",isUrl)
        K.Button(s,"Copy "..l[2].." Link",function() if S[l[1]]=="" then return false,"Link is empty" end if not HAS_CLIP then return false,"No clipboard API" end setclipboard(S[l[1]]) X.notify("Link copied","good",2) end)
    end
end

local TABS={"HOME","FARM","STEAL","INVENTORY","VISUALS","PRESET","WEBHOOK","SETTINGS","ADMIN","ABOUT"}
local PAGE_FN={HOME="Home",FARM="Farm",STEAL="Steal",INVENTORY="Inventory",VISUALS="Visuals",PRESET="Preset",ADMIN="Admin",WEBHOOK="Webhook",SETTINGS="Settings",ABOUT="About"}
function X.buildUI()
    local gui=N("ScreenGui",{Name="CAZIELX_ARCHX_V6_2",ResetOnSpawn=false,DisplayOrder=999,IgnoreGuiInset=true,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
    pcall(function() gui.ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets end)
    gui.Parent=PlayerGui Root.add(gui)
    X.ui={open=true,compact=false,gui=gui}
    local win=N("Frame",{Name="Window",AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=C.bg,BorderSizePixel=0,ClipsDescendants=true},gui)
    corner(win,12) strokeOf(win)
    local wscale=N("UIScale",{},win)
    local ascale=N("UIScale",{},win)
    local top=N("Frame",{BackgroundColor3=C.p1,Size=UDim2.new(1,0,0,40),BorderSizePixel=0},win)
    local mark=cxMark(top,28)
    mark.Position=UDim2.fromOffset(8,6)
    local brand=T(top,"CAZIELX",14,C.tx,true,{Position=UDim2.fromOffset(44,4),Size=UDim2.new(0,170,0,18),RichText=true})
    brand.Text='CAZIELX <font color="rgb(245,158,11)">ARCHX</font>'
    T(top,"CONTROL INTERFACE",10,C.mut,true,{Position=UDim2.fromOffset(45,22),Size=UDim2.new(0,170,0,13),TextTruncate=Enum.TextTruncate.AtEnd})
    local function ctrl(txt,xoff) return mkBtn(top,txt,UDim2.fromOffset(30,28),C.p3,{Position=UDim2.new(1,xoff,.5,-14),TextSize=14}) end
    local bMin,bClose=ctrl("–",-76),ctrl("×",-40)
    local sidebar=N("ScrollingFrame",{BackgroundColor3=C.p1,Position=UDim2.fromOffset(0,40),BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=0},win)
    N("UIListLayout",{Padding=UDim.new(0,4)},sidebar) N("UIPadding",{PaddingTop=UDim.new(0,8),PaddingLeft=UDim.new(0,6),PaddingRight=UDim.new(0,6),PaddingBottom=UDim.new(0,8)},sidebar)
    local content=N("Frame",{BackgroundTransparency=1,ClipsDescendants=true,Position=UDim2.fromOffset(0,40),BorderSizePixel=0},win)
    local toasts=N("Frame",{BackgroundTransparency=1,AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-10,0,10),Size=UDim2.fromOffset(250,300),ZIndex=50},gui)
    N("UIListLayout",{Padding=UDim.new(0,6),HorizontalAlignment=Enum.HorizontalAlignment.Right},toasts)
    local float=N("TextButton",{Text="CX",Font=Enum.Font.GothamBlack,TextSize=15,TextColor3=C.tx,BackgroundColor3=C.p1,AutoButtonColor=false,Size=UDim2.fromOffset(46,46),AnchorPoint=Vector2.new(.5,.5),BorderSizePixel=0,ZIndex=40},gui)
    corner(float,16) local fst=acc(strokeOf(float,C.ac,1.8),"Color")
    local fscale=N("UIScale",{},float)
    notify=function(msg,kind,dur)
        if not alive then return end
        local col=kind=="good" and C.good or (kind=="bad" and C.bad or (kind=="warn" and C.warn or C.ac))
        for _,c in ipairs(toasts:GetChildren()) do if c:IsA("Frame") and #toasts:GetChildren()>5 then c:Destroy() break end end
        local t=N("Frame",{BackgroundColor3=C.p2,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BorderSizePixel=0},toasts)
        corner(t,8) strokeOf(t,col,1)
        N("UIPadding",{PaddingTop=UDim.new(0,8),PaddingBottom=UDim.new(0,8),PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)},t)
        wrapT(t,tostring(msg),12,C.tx)
        task.delay(dur or 3,function() if t.Parent then t:Destroy() end end)
        if kind=="bad" and X.event then X.event("error","Error",tostring(msg):sub(1,300),"bad") end
    end

    local shownAnnouncement={}
    local function showAnnouncement(data)
        if not alive or type(data)~="table" then return end
        local title=tostring(data.title or "CAZIELX Announcement"):sub(1,90)
        local message=tostring(data.message or ""):sub(1,900)
        local shade=N("Frame",{Name="AnnouncementOverlay",BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=200},gui)
        local card=N("Frame",{Name="AnnouncementDialog",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.46),Size=UDim2.new(.88,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=C.p2,BorderSizePixel=0,ZIndex=201},shade)
        N("UISizeConstraint",{MaxSize=Vector2.new(460,520),MinSize=Vector2.new(260,150)},card)
        corner(card,13) strokeOf(card,C.ac,1.4)
        N("UIPadding",{PaddingTop=UDim.new(0,18),PaddingBottom=UDim.new(0,16),PaddingLeft=UDim.new(0,18),PaddingRight=UDim.new(0,18)},card)
        N("UIListLayout",{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder},card)
        local tag=T(card,"CAZIELX  /  "..string.upper(tostring(data.category or "INFO")),10,C.ac,true,{ZIndex=202})
        local heading=wrapT(card,title,18,C.tx,true) heading.ZIndex=202
        local body=wrapT(card,message,13,C.mut,false) body.ZIndex=202
        local close=mkBtn(card,"DISMISS",UDim2.new(1,0,0,34),C.p3,{ZIndex=203})
        local track=N("Frame",{BackgroundColor3=C.p3,Size=UDim2.new(1,0,0,4),BorderSizePixel=0,ZIndex=203},card)
        corner(track,3)
        local fill=N("Frame",{BackgroundColor3=C.ac,Size=UDim2.new(1,0,1,0),BorderSizePixel=0,ZIndex=204},track)
        corner(fill,3)
        local closed=false
        local function dismiss()
            if closed then return end closed=true
            if data.onClose then pcall(data.onClose) end
            local tr=tw(card,.22,{Position=UDim2.fromScale(.5,.43)})
            tw(shade,.22,{BackgroundTransparency=1})
            if tr then tr.Completed:Once(function() if shade.Parent then shade:Destroy() end end) else shade:Destroy() end
        end
        close.Activated:Connect(dismiss)
        tw(shade,.2,{BackgroundTransparency=.38})
        tw(card,.28,{Position=UDim2.fromScale(.5,.5)},Enum.EasingStyle.Quint)
        local bar=TweenService:Create(fill,TweenInfo.new(10,Enum.EasingStyle.Linear),{Size=UDim2.new(0,0,1,0)})
        bar:Play()
        task.delay(10,dismiss)
    end
    X.showAnnouncement=showAnnouncement
    local loginOpen=false
    function X.promptLogin()
        if loginOpen or not alive or not Auth.needsKey() then return end
        loginOpen=true
        local role=Auth.claimRole()
        local shade=N("Frame",{Name="CXLogin",BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.35,Size=UDim2.fromScale(1,1),ZIndex=210,Active=true},gui)
        local card=N("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(.88,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=C.p2,BorderSizePixel=0,ZIndex=211},shade)
        N("UISizeConstraint",{MaxSize=Vector2.new(400,400),MinSize=Vector2.new(250,120)},card)
        corner(card,12) strokeOf(card,C.ac,1.4)
        N("UIPadding",{PaddingTop=UDim.new(0,16),PaddingBottom=UDim.new(0,16),PaddingLeft=UDim.new(0,16),PaddingRight=UDim.new(0,16)},card)
        N("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},card)
        T(card,"CAZIELX  /  LOGIN "..(role=="dev" and "DEVELOPER" or string.upper(role)),11,C.ac,true,{ZIndex=212})
        local msg=wrapT(card,(role=="dev" and ("Developer terdeteksi: @"..Player.Name..". ") or "Akun staf terdeteksi. ").."Masukkan key untuk membuka dashboard.",12,C.mut) msg.ZIndex=212
        local box=N("TextBox",{PlaceholderText="key",Text="",ClearTextOnFocus=false,Font=Enum.Font.Gotham,TextSize=13,TextColor3=C.tx,PlaceholderColor3=C.mut,BackgroundColor3=C.p1,BorderSizePixel=0,Size=UDim2.new(1,0,0,34),ZIndex=212},card)
        corner(box,7) strokeOf(box)
        local getKey,clearKey=K.maskInput(box)
        local ok=mkBtn(card,"MASUK",UDim2.new(1,0,0,34),C.ac:Lerp(C.p3,.55),{ZIndex=212})
        local skip=mkBtn(card,"LEWATI (pakai fitur biasa)",UDim2.new(1,0,0,30),C.p3,{ZIndex=212,TextSize=11})
        local busy=false
        local function close() loginOpen=false if shade.Parent then shade:Destroy() end end
        ok.Activated:Connect(function()
            if busy then return end
            busy=true msg.Text="Memeriksa..." msg.TextColor3=C.mut
            task.spawn(function()
                local r,m=Auth.login(getKey())
                clearKey()
                busy=false
                if not alive then return end
                if r then
                    close() X.refreshAdmin()
                    if X.adminRender then pcall(X.adminRender) end
                    X.notify(m,"good",3)
                elseif msg.Parent then
                    msg.Text=tostring(m) msg.TextColor3=C.bad
                end
            end)
        end)
        skip.Activated:Connect(close)
    end
    local function placeWin()
        local s=gui.AbsoluteSize
        win.Position=UDim2.fromOffset(math.floor(s.X*math.clamp(POS.wx,.05,.95)+.5),math.floor(s.Y*math.clamp(POS.wy,.05,.95)+.5))
    end
    local function layout()
        local s=gui.AbsoluteSize
        local sc=math.min(s.X/740,s.Y/460,1)*S.ui_scale -- tidak pernah memperbesar: teks tetap tajam
        sc=math.clamp(math.floor(sc*20+.5)/20,.6,1.5)
        wscale.Scale,fscale.Scale=sc,math.clamp(sc,.8,1.1)
        local lw,lh=s.X/sc,s.Y/sc
        local function snap(v) return math.floor(v*sc/2)*2/sc end -- ukuran piksel layar genap => tidak ada setengah piksel
        local w,h=snap(math.min(lw-16,680)),snap(math.min(lh-16,430))
        win.Size=UDim2.fromOffset(w,h)
        X.ui.compact=w<560
        local sw=X.ui.compact and 56 or 140
        sidebar.Size=UDim2.fromOffset(sw,h-40)
        content.Position=UDim2.fromOffset(sw,40) content.Size=UDim2.fromOffset(w-sw,h-40)
        placeWin()
        float.Position=UDim2.fromScale(math.clamp(POS.fx,.03,.97),math.clamp(POS.fy,.05,.95))
        if X.ui.tabLabels then for _,l in pairs(X.ui.tabLabels) do l.Visible=not X.ui.compact end end
    end
    layout()
    Root.add(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout))
    X.sync.ui_scale=function() layout() end
    local function drag(handle,onBegin,onMove,onTap)
        local st
        handle.InputBegan:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then st={p=i.Position,moved=false,id=i} onBegin() end
        end)
        Root.add(UIS.InputChanged:Connect(function(i)
            if not st then return end
            if i.UserInputType==Enum.UserInputType.MouseMovement or (i.UserInputType==Enum.UserInputType.Touch and i==st.id) then
                local d=i.Position-st.p
                if not st.moved and d.Magnitude>6 then st.moved=true end
                if st.moved then onMove(d) end
            end
        end))
        Root.add(UIS.InputEnded:Connect(function(i)
            if st and (i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch) then
                local s2=st st=nil
                if s2.moved then X.dirty=os.clock() elseif onTap then onTap() end
            end
        end))
    end
    local sx,sy
    drag(top,function() sx,sy=POS.wx,POS.wy end,function(d) local s=gui.AbsoluteSize POS.wx,POS.wy=math.clamp(sx+d.X/s.X,.05,.95),math.clamp(sy+d.Y/s.Y,.05,.95) placeWin() end)
    drag(float,function() sx,sy=POS.fx,POS.fy end,function(d) local s=gui.AbsoluteSize POS.fx,POS.fy=math.clamp(sx+d.X/s.X,.03,.97),math.clamp(sy+d.Y/s.Y,.05,.95) float.Position=UDim2.fromScale(POS.fx,POS.fy) end,function() X.toggleWindow() end)
    local token=0
    local floatPulse
    local function updFloat()
        local want=(not X.ui.open) and activeCount()>0
        if want and not floatPulse then floatPulse=twLoop(fst,{Transparency=.7}) elseif not want and floatPulse then pcall(floatPulse.Cancel,floatPulse) floatPulse=nil fst.Transparency=0 end
    end
    function X.openWindow()
        token+=1 X.ui.open=true win.Visible=true
        ascale.Scale=.96
        tw(ascale,.18,{Scale=1},Enum.EasingStyle.Quad)
        updFloat()
    end
    function X.hideWindow()
        token+=1 local my=token X.ui.open=false
        local tr=tw(ascale,.12,{Scale=.96})
        if tr then tr.Completed:Once(function() if token==my then win.Visible=false end end) else win.Visible=false end
        updFloat()
    end
    function X.toggleWindow() if X.ui.open then X.hideWindow() else X.openWindow() end end
    bMin.Activated:Connect(X.hideWindow)
    local armed=false
    bClose.Activated:Connect(function()
        if armed then X.unload() return end
        armed=true bClose.Text="?" tw(bClose,.15,{BackgroundColor3=C.bad}) X.notify("Tap × again to unload CAZIELX ARCHX","warn",3)
        task.delay(3,function() armed=false if bClose.Parent then bClose.Text="×" tw(bClose,.15,{BackgroundColor3=C.p3}) end end)
    end)
    Root.add(UIS.InputBegan:Connect(function(i,gp) if not gp and i.KeyCode==Enum.KeyCode.RightControl then X.toggleWindow() end end))
    local tabBtns,pages,built={}, {}, {}
    local cur
    local function selectTab(name,instant)
        if cur==name then return end
        cur=name
        for n,b in pairs(tabBtns) do
            local sel=n==name
            tw(b.btn,.15,{BackgroundColor3=sel and C.p3 or C.p1})
            if b.paint then local pc=sel and C.ac or C.mut b.paint(pc) b.lbl.TextColor3=sel and C.tx or C.mut end
            tw(b.bar,.15,{BackgroundTransparency=sel and 0 or 1})
        end
        if not built[name] then
            built[name]=true
            local pg=N("ScrollingFrame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3,ScrollBarImageColor3=C.line,BorderSizePixel=0,Visible=false,ScrollingDirection=Enum.ScrollingDirection.Y},content)
            N("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},pg)
            N("UIPadding",{PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,16),PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,12)},pg)
            pages[name]=pg
            K.curPage=pg
            local ok,err=xpcall(Pages[PAGE_FN[name]],tb,pg)
            if not ok then Diag.err("page:"..name,err) T(pg,"This page failed to build: "..tostring(err):sub(1,160),12,C.bad,false,WRAP) end
        end
        for n,pg in pairs(pages) do pg.Visible=n==name end
        local pg=pages[name]
        pg.Position=UDim2.fromOffset(0,instant and 0 or 8)
        tw(pg,.15,{Position=UDim2.fromOffset(0,0)})
        pg.CanvasPosition=Vector2.zero
    end
    -- Ikon digambar dari Frame (tidak bergantung glyph font, selalu tampil jelas)
    local function mkIcon(parent,kind,col)
        local h=N("Frame",{Name="Icon",BackgroundTransparency=1,Size=UDim2.fromOffset(20,20),Position=UDim2.new(0,10,.5,-10),Active=false},parent)
        local paint={}
        local function box(x,y,w,hh,r,filled,rot)
            local f=N("Frame",{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,hh),BorderSizePixel=0,BackgroundColor3=col,BackgroundTransparency=filled and 0 or 1,Rotation=rot or 0},h)
            if r then corner(f,r) end
            if filled then paint[#paint+1]={f,"BackgroundColor3"} else paint[#paint+1]={strokeOf(f,col,1.6),"Color"} end
        end
        if kind=="HOME" then box(5,1,10,10,1,true,45) box(4,9,12,9,2,true)
        elseif kind=="FARM" then box(9,8,2,10,1,true) box(3,5,8,5,2.5,true,-25) box(9,2,8,5,2.5,true,25)
        elseif kind=="STEAL" then box(2,2,16,16,8,false) box(8,8,4,4,2,true)
        elseif kind=="INVENTORY" then box(3,3,6,6,1.5,true) box(11,3,6,6,1.5,true) box(3,11,6,6,1.5,true) box(11,11,6,6,1.5,true)
        elseif kind=="VISUALS" then box(1,5,18,10,5,false) box(7,7,6,6,3,true)
        elseif kind=="PRESET" then box(3,3,14,3,1.5,true) box(3,8,14,3,1.5,true) box(3,13,14,3,1.5,true)
        elseif kind=="WEBHOOK" then box(2,9,15,2,1,true) box(11,6,8,2,1,true,45) box(11,12,8,2,1,true,-45)
        elseif kind=="SETTINGS" then box(2,4,16,2,1,true) box(2,9,16,2,1,true) box(2,14,16,2,1,true) box(11,2,5,6,2.5,true) box(4,7,5,6,2.5,true) box(10,12,5,6,2.5,true)
        elseif kind=="ADMIN" then box(7,1,6,6,3,true) box(3,9,14,9,4,true)
        else box(2,2,16,16,8,false) box(9,5,2,2,1,true) box(9,9,2,6,1,true) end
        return function(c) for _,p in ipairs(paint) do p[1][p[2]]=c end end
    end
    X.ui.tabLabels={}
    for _,n in ipairs(TABS) do
        local b=mkBtn(sidebar,"",UDim2.new(1,0,0,38),C.p1,{TextColor3=C.mut})
        local paint=mkIcon(b,n,C.mut)
        local lbl=T(b,n,11,C.mut,true,{Position=UDim2.fromOffset(38,0),Size=UDim2.new(1,-42,1,0),TextYAlignment=Enum.TextYAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd})
        lbl.Visible=not X.ui.compact
        X.ui.tabLabels[n]=lbl
        local bar=acc(N("Frame",{Size=UDim2.fromOffset(3,18),Position=UDim2.new(0,0,.5,-9),BackgroundTransparency=1,BorderSizePixel=0},b),"BackgroundColor3") corner(bar,2)
        tabBtns[n]={btn=b,bar=bar,paint=paint,lbl=lbl}
        if n=="ADMIN" then b.Visible=Auth.staffVisible() X.adminBtn=b end
        b.Activated:Connect(function() selectTab(n) end)
    end
    X.ui.select=selectTab
    X.refreshAdmin=function() if X.adminBtn and X.adminBtn.Parent then X.adminBtn.Visible=Auth.staffVisible() end end
    X.on.theme=function(v)
        C.ac=ACCENTS[v] or C.ac
        for i=#K.accs,1,-1 do local a=K.accs[i] if a[1].Parent then pcall(function() a[1][a[2]]=C.ac end) else table.remove(K.accs,i) end end
        for _,k in ipairs({"farm_auto","farm_break","farm_collect","farm_pause","steal_auto","steal_guard"}) do if X.sync[k] then pcall(X.sync[k],S[k]) end end
        if X.sync.swing_mult then pcall(X.sync.swing_mult,S.swing_mult) end
        for _,k in ipairs({"esp_egg","esp_pet","esp_player","esp_dist","wh_enable","perf_mode","anti_afk","auto_save","pet_alert"}) do if X.sync[k] then pcall(X.sync[k],S[k]) end end
    end
    C.ac=ACCENTS[S.theme] or C.ac for _,a in ipairs(K.accs) do pcall(function() a[1][a[2]]=C.ac end) end
    X.on.anim_quality=function() end
    local function runLive(fast)
        if not X.ui.open then return end
        for _,e in ipairs(X.live) do
            if e.page and e.page.Visible and (e.fast or false)==fast then local ok,err=pcall(e.fn) if not ok then Diag.err("ui",err) end end
        end
    end
    local slow=Sched.add("ui",.3,function(h) h.interval=S.perf_mode and .7 or .3 runLive(false) updFloat() end)
    local fast=Sched.add("uifast",.06,function(h) h.interval=S.perf_mode and .15 or .06 runLive(true) end)
    slow.onfail=function() Diag.set("ui","FAILED","ui ticker stopped") end
    selectTab("HOME",true)
    X.openWindow()
end

function X.unload()
    if not alive then return end
    alive=false
    local function step(n,f) local ok,e=xpcall(f,tb) Diag.cleanup[#Diag.cleanup+1]=(ok and "OK " or "FAIL ")..n..(ok and "" or (": "..tostring(e):sub(1,120))) end
    step("session summary",function()
        if S.wh_enable and S.wh_ev_summary and WH.url~="" then whPost(whEmbed("Session summary","Session ended","info",summaryFields())) end
    end)
    step("save config",function() saveConfig(true) end)
    step("stop features",function()
        for _,k in ipairs({"farm_auto","farm_break","farm_collect","steal_auto","fly","speed_boost","low_graphics"}) do
            if X.on[k] then pcall(X.on[k],false) end
            S[k]=false
        end
        farmSync() pkSync()
        S.esp_egg,S.esp_pet,S.esp_player=false,false,false espSync()
        local hum=getHum() if hum then pcall(hum.Move,hum,Vector3.zero) end
    end)
    step("root cleanup",Root.clean)
    _G.__CAZX_CLEANUP=nil
    _G.CAZX_PERMTEST=nil
    print("[CAZX] unloaded: "..table.concat(Diag.cleanup," | "))
end
_G.__CAZX_CLEANUP=X.unload

local function stage(name,fn)
    Boot.stage(name=="watchers" and "LOADING SESSION" or name=="config" and "LOADING CONFIGURATION" or name=="core" and "CHECKING SESSION DATA" or name=="features" and "INITIALIZING MODULES" or name=="ui" and "BUILDING INTERFACE" or name=="sync" and "SYNCHRONIZING ACCOUNT")
    Diag.stages[#Diag.stages+1]="STARTING "..name
    local idx=#Diag.stages
    print("[CAZX][STARTING] "..name)
    local ok,err=xpcall(fn,tb)
    Diag.stages[idx]=(ok and "SUCCESS " or "FAILED ")..name..(ok and "" or (": "..tostring(err):sub(1,160)))
    if ok then print("[CAZX][SUCCESS] "..name) else warn("[CAZX][FAILED] "..name.." :: "..tostring(err)) Diag.err("boot:"..name,err) end
    return ok
end
stage("watchers",function()
    Tools.watch() petWatch()
    local bag=newMaid() Root.add(bag.clean)
    onChar(bag,function(char) Base.obj=nil E.target=nil Pk.state="IDLE" Pk.target=nil
        if not Base.spawnPos then task.spawn(function() local hrp=char:WaitForChild("HumanoidRootPart",8) if hrp then task.wait(.8) if hrp.Parent and not Base.spawnPos then Base.spawnPos=hrp.Position end end end) end
    end)
    Root.add(Player:GetPropertyChangedSignal("RespawnLocation"):Connect(function() Base.obj=nil end))
    Eggs.hook()
end)
stage("config",function()
    local j=readConfig()
    if j then
        local ok,m=importConfig(j)
        if not ok then error("config load: "..tostring(m)) end
        print("[CAZX] config: "..tostring(m))
    else print("[CAZX] config: no saved file (defaults)") end
    whLoad()
    X.onPrivate=function(key,v)
        if key=="__wh" then
            local ok,u=whValidate(v)
            if not ok then X.notify(u,"bad",4) return end
            WH.url=u WH.state,WH.kind,WH.detail="LOADED","warn","not tested yet"
            X.notify("Webhook URL accepted (tap Save URL to keep it)","good",3)
        elseif key=="__imp" then
            local ok,m=importConfig(v) X.notify(ok and ("Imported. "..m) or m,ok and "good" or "bad",4)
        elseif key=="__tp_egg" then X.tpEggName=v
        elseif key=="__tp_pos" then X.tpPosition=v
        end
    end
end)
stage("core",function()
    Store.load()
    Net.loadFile()
    local ok,info=pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId) end)
    local gname=(ok and type(info)=="table" and tostring(info.Name)) or ""
    local l=gname:lower()
    if l:find("steal",1,true) and l:find("egg",1,true) then X.game={name="Break and Steal an Egg",target=true}
    else X.game={name=(gname~="" and gname:sub(1,40)) or "Universal",target=false} end
end)
stage("features",function()
    Ses.lastCash=getCash()
    Sched.add("session",1,function()
        local c=getCash()
        if c and Ses.lastCash and c>Ses.lastCash then Ses.earn+=c-Ses.lastCash end
        Ses.lastCash=c
    end)
    Sched.add("autosave",2,function()
        if S.auto_save and X.dirty and os.clock()-X.dirty>1.5 then X.dirty=nil saveConfig(true) end
    end)
    Sw.setMult(S.swing_mult)
    for k,fn in pairs(X.on) do if type(S[k])=="boolean" and S[k] and not RUNTIME_OFF[k] then pcall(fn,true) end end
    Diag.set("swing","IDLE","waiting for Auto Farm / Auto Break")
end)
stage("ui",function() X.buildUI() end)
stage("sync",function()
    Users.self(true)
    Sync.start()
    Guard.check(Users.banOf(Player.UserId))
    if not X.game.target then X.notify("Game terdeteksi: "..X.game.name..". Fitur Farm dan Steal dirancang untuk Break and Steal an Egg.","warn",6) end
    X.refreshAdmin()
    if Auth.needsKey() and not Auth.prompted then Auth.prompted=true X.promptLogin() end
end)
if not Diag.stages[#Diag.stages]:find("^SUCCESS") then
    warn("[CAZX][FAILED] UI did not build; see _G.CAZX_DIAG.stages / .errs")
end
Boot.finish()
print("[CAZX][SUCCESS] CAZIELX ARCHX V6.2.0 ready")

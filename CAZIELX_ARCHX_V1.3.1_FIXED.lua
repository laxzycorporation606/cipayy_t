print("[CAZX][RUNNING] source compiled, startup begins")
local CAZX_T0=os.clock()
local CAZX_NAME="CAZIELX ARCHX"
local CAZX_REV="1.3.1"
local DIAG_FILE="CAZIELX_ARCHX_diag.txt"
local DIAG={
version=CAZX_REV,
t0=CAZX_T0,
stages={},
errors={},
log={},
trace={},
caps={},
optionalFailures={},
optionalReported=0,
phase="prelude",
phaseIndex=0,
compiled=true,
bootVisible=false,
finished=false,
failed=false,
superseded=false,
cleanup=nil,
}

local function envTable()
local ok,g=pcall(function()return getgenv()end)
if ok and type(g)=="table"then return g end
return nil
end
local function slotGet(key)
local v=nil
pcall(function()v=_G[key]end)
if v==nil then
local g=envTable()
if g then pcall(function()v=g[key]end)end
end
return v
end
local function slotSet(key,value)
pcall(function()_G[key]=value end)
local g=envTable()
if g then pcall(function()g[key]=value end)end
end

local function logLine(line)
local log=DIAG.log
log[#log+1]=("%8.3f %s"):format(os.clock()-CAZX_T0,line)
if#log>500 then table.remove(log,1)end
end
local function emit(level,msg)
local line=("[CAZX][%s] %s"):format(level,msg)
logLine(line)
if level=="FAILED"or level=="ERROR"or level=="WARN"then warn(line)else print(line)end
end
local function flushLog()
if typeof(writefile)~="function"then return false end
local ok=pcall(writefile,DIAG_FILE,table.concat(DIAG.log,"\n"))
return ok
end
DIAG.report=function()return table.concat(DIAG.log,"\n")end
slotSet("CAZX_DIAG",DIAG)

local function traceHandler(e)
return tostring(e).."\n"..debug.traceback("",2)
end

local beacon={gui=nil,panel=nil,label=nil,bad=false,closeBtn=nil,copyBtn=nil}
local function beaconRoots()
local roots={}
local okP,pg=pcall(function()
local lp=game:GetService("Players").LocalPlayer
return lp and lp:FindFirstChildOfClass("PlayerGui")
end)
if okP and pg then roots[#roots+1]=pg end
local okC,cg=pcall(function()return game:GetService("CoreGui")end)
if okC and cg then roots[#roots+1]=cg end
return roots
end
local function beaconEnsure()
if beacon.gui and beacon.gui.Parent then return true end
for _,root in ipairs(beaconRoots())do
local ok,sg=pcall(function()
local g=Instance.new("ScreenGui")
g.Name="CazielxArchxBeacon"
g.ResetOnSpawn=false
g.IgnoreGuiInset=true
g.DisplayOrder=2000000000
g.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
local fr=Instance.new("Frame")
fr.Name="Panel"
fr.AnchorPoint=Vector2.new(.5,0)
fr.Position=UDim2.new(.5,0,0,12)
fr.Size=UDim2.new(1,-24,0,54)
fr.BackgroundColor3=Color3.fromRGB(10,8,24)
fr.BackgroundTransparency=.08
fr.BorderSizePixel=0
fr.Parent=g
local lb=Instance.new("TextLabel")
lb.Name="Text"
lb.BackgroundTransparency=1
lb.Position=UDim2.fromOffset(10,6)
lb.Size=UDim2.new(1,-20,1,-12)
lb.Font=Enum.Font.Code
lb.TextSize=12
lb.TextWrapped=true
lb.TextXAlignment=Enum.TextXAlignment.Left
lb.TextYAlignment=Enum.TextYAlignment.Top
lb.TextColor3=Color3.fromRGB(196,170,255)
lb.Text=""
lb.Parent=fr
g.Parent=root
return g
end)
if ok and sg and sg.Parent==root then
beacon.gui=sg
beacon.panel=sg:FindFirstChild("Panel")
beacon.label=beacon.panel and beacon.panel:FindFirstChild("Text")
return beacon.label~=nil
end
if ok and sg then pcall(function()sg:Destroy()end)end
end
return false
end
local function beaconButton(name,text,yOffset,onClick)
pcall(function()
local b=Instance.new("TextButton")
b.Name=name
b.AnchorPoint=Vector2.new(1,0)
b.Position=UDim2.new(1,-8,0,yOffset)
b.Size=UDim2.fromOffset(64,24)
b.BackgroundColor3=Color3.fromRGB(58,38,122)
b.BorderSizePixel=0
b.Font=Enum.Font.GothamBold
b.TextSize=11
b.TextColor3=Color3.fromRGB(255,255,255)
b.Text=text
b.Parent=beacon.panel
b.Activated:Connect(onClick)
beacon[name=="Close"and"closeBtn"or"copyBtn"]=b
end)
end
local function beaconShow(text,bad)
if not beaconEnsure()then return false end
pcall(function()
beacon.label.Text=text
beacon.label.TextColor3=bad and Color3.fromRGB(255,120,132)or Color3.fromRGB(196,170,255)
beacon.panel.Size=bad and UDim2.new(1,-24,0,200)or UDim2.new(1,-24,0,54)
beacon.label.Size=bad and UDim2.new(1,-84,1,-12)or UDim2.new(1,-20,1,-12)
end)
if bad then
beacon.bad=true
if not beacon.closeBtn then
beaconButton("Close","CLOSE",8,function()
if beacon.gui then pcall(function()beacon.gui:Destroy()end)end
beacon.gui=nil
beacon.closeBtn=nil
beacon.copyBtn=nil
end)
end
if not beacon.copyBtn and typeof(setclipboard)=="function"then
beaconButton("Copy","COPY",38,function()pcall(setclipboard,DIAG.report())end)
end
end
return true
end
local function beaconHide()
if beacon.bad then return end
if beacon.gui then pcall(function()beacon.gui:Destroy()end)end
beacon.gui=nil
end

local function phaseMark(name)
DIAG.phaseIndex+=1
DIAG.phase=name
local at=os.clock()-CAZX_T0
DIAG.trace[#DIAG.trace+1]={n=DIAG.phaseIndex,name=name,at=at}
emit("PHASE",("%02d %s (+%.3fs)"):format(DIAG.phaseIndex,name,at))
if beacon.gui and not beacon.bad then
beaconShow(("%s v%s\nphase %02d: %s"):format(CAZX_NAME,CAZX_REV,DIAG.phaseIndex,name),false)
end
end

local function diag(name,status,why,dur,kind)
local rec={name=name,status=status,why=why,dur=dur,kind=kind,at=os.clock()-CAZX_T0}
DIAG.stages[#DIAG.stages+1]=rec
if status=="FAILED"then DIAG.errors[#DIAG.errors+1]=rec end
local line=("[CAZX][%s] %s%s%s%s"):format(
status,name,
kind and(" {"..kind.."}")or"",
dur and(" (%.3fs)"):format(dur)or"",
why and(" :: "..tostring(why))or"")
logLine(line)
if status=="FAILED"then warn(line)else print(line)end
end

local function optional(name,fn,...)
local ok,err=xpcall(fn,traceHandler,...)
if not ok then
DIAG.optionalFailures[#DIAG.optionalFailures+1]={name=name,err=err}
emit("WARN",("optional step '%s' failed: %s"):format(name,tostring(err)))
else
logLine(("[CAZX][OK] optional %s"):format(name))
end
return ok
end
local function safeSpawn(name,fn)
return task.spawn(function()
local ok,err=xpcall(fn,traceHandler)
if not ok then emit("ERROR",("task '%s' failed: %s"):format(name,tostring(err)))end
end)
end

local function probe(name,fn)
local ok,res=pcall(fn)
DIAG.caps[name]=(ok and res~=false)and true or false
end
probe("writefile",function()return typeof(writefile)=="function"end)
probe("readfile",function()return typeof(readfile)=="function"end)
probe("isfile",function()return typeof(isfile)=="function"end)
probe("setclipboard",function()return typeof(setclipboard)=="function"end)
probe("setfpscap",function()return typeof(setfpscap)=="function"end)
probe("request",function()return typeof(request)=="function"or typeof(http_request)=="function"end)
probe("getcustomasset",function()return typeof(getcustomasset)=="function"end)
probe("CanvasGroup",function()Instance.new("CanvasGroup"):Destroy()return true end)
probe("UIGradient",function()Instance.new("UIGradient"):Destroy()return true end)
probe("Highlight",function()Instance.new("Highlight"):Destroy()return true end)
probe("VirtualUser",function()return game:GetService("VirtualUser")~=nil end)
local execName="unknown"
if typeof(identifyexecutor)=="function"then
local okE,n,v=pcall(identifyexecutor)
if okE and n then execName=tostring(n)..(v and(" "..tostring(v))or"")end
end
DIAG.executor=execName
do
local capNames={}
for k in pairs(DIAG.caps)do capNames[#capNames+1]=k end
table.sort(capNames)
local capParts={}
for _,k in ipairs(capNames)do capParts[#capParts+1]=k.."="..(DIAG.caps[k]and"yes"or"no")end
emit("INFO",("v%s executor=%s %s"):format(CAZX_REV,execName,table.concat(capParts," ")))
end

local function startupFailed(info)
DIAG.failed=true
local msg=type(info)=="table"and info.message or tostring(info)
local tb=type(info)=="table"and(info.trace or"")or""
DIAG.failure={phase=DIAG.phase,index=DIAG.phaseIndex,message=msg,trace=tb}
if DIAG.superseded then
emit("WARN",("startup of a superseded session stopped after phase %02d '%s': %s"):format(DIAG.phaseIndex,DIAG.phase,msg))
return
end
emit("FAILED",("runtime error, startup aborted after phase %02d '%s': %s"):format(DIAG.phaseIndex,DIAG.phase,msg))
emit("FAILED","traceback: "..(tb:gsub("\n"," | ")))
if DIAG.cleanup then pcall(DIAG.cleanup)end
flushLog()
beaconShow(("%s v%s  STARTUP FAILED\nafter phase %02d: %s\n%s"):format(CAZX_NAME,CAZX_REV,DIAG.phaseIndex,DIAG.phase,msg:sub(1,420)),true)
end

task.delay(1.5,function()
if DIAG.bootVisible or DIAG.finished or DIAG.failed then return end
emit("WARN",("loading screen not visible after 1.5s, last phase %02d '%s'"):format(DIAG.phaseIndex,DIAG.phase))
beaconShow(("%s v%s\nstarting...\nphase %02d: %s"):format(CAZX_NAME,CAZX_REV,DIAG.phaseIndex,DIAG.phase),false)
flushLog()
end)
task.delay(25,function()
if DIAG.finished or DIAG.failed then return end
emit("WARN",("startup still running after 25s, current phase '%s'"):format(DIAG.phase))
beaconShow(("%s v%s\nstill starting after 25s\nphase: %s"):format(CAZX_NAME,CAZX_REV,DIAG.phase),false)
flushLog()
end)
phaseMark("prelude ready")

local function CAZX_MAIN()
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local Lighting=game:GetService("Lighting")
local TeleportService=game:GetService("TeleportService")
local HttpService=game:GetService("HttpService")
local GuiService=game:GetService("GuiService")
local Stats=game:GetService("Stats")
local VirtualUser=game:GetService("VirtualUser")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ContentProvider=game:GetService("ContentProvider")

phaseMark("services resolved")
local Player=Players.LocalPlayer
if not Player then
local waitedPlayer=0
while not Players.LocalPlayer and waitedPlayer<15 do waitedPlayer+=task.wait(.1)end
Player=Players.LocalPlayer
end
assert(Player,"LocalPlayer unavailable after 15s")
local PlayerGui=Player:FindFirstChildOfClass("PlayerGui")or Player:WaitForChild("PlayerGui",15)
if not PlayerGui then
local okCG,cg=pcall(game.GetService,game,"CoreGui")
if okCG and cg then
PlayerGui=cg
diag("PlayerGui","FAILED","PlayerGui missing, using CoreGui as parent",nil,"dependency")
end
end
assert(PlayerGui,"PlayerGui not found within 15s and no fallback parent is available")
phaseMark("player and gui root ready")
do
local prev=slotGet("__CAZX_CLEANUP")
if prev then
local okc,errc=pcall(prev)
diag("Previous Session Cleanup",okc and"SUCCESS"or"FAILED",(not okc)and tostring(errc)or nil,nil,"runtime")
end
pcall(function()
for _,c in ipairs(PlayerGui:GetChildren())do
if c.Name=="CazielxArchx"or c.Name=="CazxBlack"or c.Name=="CazielxArchxBeacon"then pcall(c.Destroy,c)end
end
end)
end
phaseMark("previous session cleaned")

local APP_NAME="CAZIELX"
local EDITION="ARCHX"
local VERSION="1.3.1"
local BUILD="20261120"
local CHANGELOG={
"1.1.0: Fly rebuilt. Aim the camera up, push the stick forward, and you climb with smooth acceleration.",
"Save fixed: re-executing no longer wipes the saved state. Writes are verified by reading the file back.",
"New Presets and Community pages: create presets from live settings, share codes, SHOW details, USE to apply.",
"News: announcements are read from the admin's Roblox profile. The admin dialog runs real account checks.",
"White Mode added to Visuals. Every original color, material and texture is restored when it is turned off.",
"Teleport To Base: farm loops kept walking you back to their old target. They are now held during the teleport.",
"New loading screen with process log, tips and a staged entrance. Source cleaned of decorative comments.",
"1.2.0: Owner identity uses resolved Roblox UserId; added role-control center UI and explicit trusted-backend status.",
"1.2.0: Added role catalogue, role permission descriptions, target validation and admin action audit feedback.",
"1.2.1: Replaced inert webhook, autosave, community endpoint and announcement callbacks with validated behavior.",
"1.2.1: ESP option callbacks now explicitly hide their owned drawing layers when disabled without adding render loops.",
"1.3.0: Violet interface redesign: new sidebar, page headers, Home hub, centered loading screen, developer verification flow and a live Admin Panel dashboard.",
"1.3.1: Startup diagnostics from the first line, per-page build isolation, safer session cleanup and fixes for hover colors and farm summary.",
}
local CONFIG_FILE="CAZIELX_ARCHX_config.json"
local IS_TOUCH=UIS.TouchEnabled and not UIS.KeyboardEnabled
local HAS_FILES=typeof(writefile)=="function"and typeof(readfile)=="function"and typeof(isfile)=="function"
local HAS_CLIPBOARD=typeof(setclipboard)=="function"
local HAS_FPSCAP=typeof(setfpscap)=="function"
local HTTP_REQUEST=(typeof(request)=="function"and request)or(typeof(http_request)=="function"and http_request)or nil
local FONT,BOLD,MONO=Enum.Font.Gotham,Enum.Font.GothamBold,Enum.Font.Code

local alive=true
local S={_tab="Home"}
local notify,markDirty,updateActive,applyScale,switchTab,applyTheme,placeAll,whEvent,farmFields
local UI={}

local POS={win={x=.5,y=.5},float={x=-1,y=.5}}

local function newBag()
local items,bag={},{}
function bag.add(x)items[#items+1]=x return x end
function bag.clear()
for i=#items,1,-1 do
local x=items[i]
items[i]=nil
pcall(function()
local t=typeof(x)
if t=="RBXScriptConnection"then x:Disconnect()
elseif t=="Instance"then x:Destroy()
elseif t=="function"then x()end
end)
end
end
return bag
end
local Root=newBag()

local function getHum()
local c=Player.Character
return c and c:FindFirstChildOfClass("Humanoid")
end

local function hookCharacter(bag,fn)
local cb=newBag()
bag.add(cb.clear)
local function go(c)cb.clear()fn(c,cb)end
if Player.Character then task.spawn(go,Player.Character)end
bag.add(Player.CharacterAdded:Connect(function(c)task.spawn(go,c)end))
end

phaseMark("helpers and bags ready")
local PRESET_ORDER={"Cazielx Violet","Obsidian Dark","Midnight Blue","Crimson Core","Cyber Violet","Emerald Matrix","Arctic Light","Pure Black"}
local PRESETS={
["Cazielx Violet"]={Bg=Color3.fromRGB(8,6,20),Panel=Color3.fromRGB(16,11,36),Border=Color3.fromRGB(58,38,122),Accent=Color3.fromRGB(122,64,255),Text=Color3.fromRGB(240,236,255),Sub=Color3.fromRGB(150,138,192)},
["Obsidian Dark"]={Bg=Color3.fromRGB(10,10,13),Panel=Color3.fromRGB(18,18,22),Border=Color3.fromRGB(46,48,58),Accent=Color3.fromRGB(132,62,255),Text=Color3.fromRGB(236,240,248),Sub=Color3.fromRGB(132,140,158)},
["Midnight Blue"]={Bg=Color3.fromRGB(8,12,26),Panel=Color3.fromRGB(13,20,40),Border=Color3.fromRGB(32,48,88),Accent=Color3.fromRGB(62,136,255),Text=Color3.fromRGB(230,238,255),Sub=Color3.fromRGB(122,140,180)},
["Crimson Core"]={Bg=Color3.fromRGB(12,8,9),Panel=Color3.fromRGB(21,12,14),Border=Color3.fromRGB(62,30,34),Accent=Color3.fromRGB(238,66,84),Text=Color3.fromRGB(246,232,234),Sub=Color3.fromRGB(160,130,136)},
["Cyber Violet"]={Bg=Color3.fromRGB(10,8,18),Panel=Color3.fromRGB(18,13,32),Border=Color3.fromRGB(50,36,90),Accent=Color3.fromRGB(158,94,255),Text=Color3.fromRGB(240,234,255),Sub=Color3.fromRGB(144,130,178)},
["Emerald Matrix"]={Bg=Color3.fromRGB(6,13,11),Panel=Color3.fromRGB(10,22,18),Border=Color3.fromRGB(26,62,50),Accent=Color3.fromRGB(40,214,142),Text=Color3.fromRGB(228,248,240),Sub=Color3.fromRGB(116,156,140)},
["Arctic Light"]={Bg=Color3.fromRGB(234,240,248),Panel=Color3.fromRGB(255,255,255),Border=Color3.fromRGB(204,214,228),Accent=Color3.fromRGB(0,120,255),Text=Color3.fromRGB(20,28,44),Sub=Color3.fromRGB(94,106,128)},
["Pure Black"]={Bg=Color3.fromRGB(0,0,0),Panel=Color3.fromRGB(7,7,9),Border=Color3.fromRGB(32,32,38),Accent=Color3.fromRGB(122,172,255),Text=Color3.fromRGB(238,238,244),Sub=Color3.fromRGB(128,128,140)},
}
local ACCENT_SWATCHES={"#40c4ff","#3e88ff","#9e5eff","#ee4254","#28d68e","#ffb84d","#ff6ec7","#ffffff"}

local T={}

local function hexColor(h)
if type(h)=="string"and h:match("^#%x%x%x%x%x%x$")then
local ok,c=pcall(Color3.fromHex,h)
if ok then return c end
end
return nil
end

local computeTheme,bindings,pruneBindings,activeTween,tween,new,round,stroke,text,Icons,CreateIcon,SetIconColor,SetIconState,DestroyIcon,refreshIcons,iconHover,Tabs,TabByName,Feat,FeatList,addTab,def,na
do
local function lum(c)return.2126*c.R+.7152*c.G+.0722*c.B end

function computeTheme()
local p=PRESETS[S.theme_preset]or PRESETS["Cazielx Violet"]
local bg=hexColor(S.theme_bg)or p.Bg
local panel=hexColor(S.theme_panel)or p.Panel
local border=hexColor(S.theme_border)or p.Border
local accent=hexColor(S.theme_accent)or p.Accent
local tx=hexColor(S.theme_text)or p.Text
local sub=hexColor(S.theme_sub)or p.Sub
local light=lum(bg)>.6
T.Bg,T.Panel,T.Border,T.Accent,T.Text,T.Sub=bg,panel,border,accent,tx,sub
T.Card=panel:Lerp(tx,light and.04 or.05)
T.CardHover=panel:Lerp(tx,light and.09 or.1)
T.Off=panel:Lerp(tx,.22)
T.AccentDim=accent:Lerp(bg,light and.72 or.62)
T.OnAccent=lum(accent)>.55 and Color3.fromRGB(10,12,18)or Color3.fromRGB(250,252,255)
T.Good=light and Color3.fromRGB(14,156,92)or Color3.fromRGB(60,220,140)
T.Warn=light and Color3.fromRGB(196,120,0)or Color3.fromRGB(255,184,77)
T.Bad=light and Color3.fromRGB(205,38,56)or Color3.fromRGB(255,84,98)
T.Tr=math.clamp(S.theme_tr or 0,0,.6)
T.Light=light
end
computeTheme()
phaseMark("theme tokens computed")

bindings={}
local COLOR_PROPS={BackgroundColor3=true,TextColor3=true,ImageColor3=true,Color=true,ScrollBarImageColor3=true,PlaceholderColor3=true}

local function bind(o,prop,key)
bindings[#bindings+1]={o,prop,key}
o[prop]=T[key]
end

function pruneBindings()
local j=0
for i=1,#bindings do
local b=bindings[i]
if b[1].Parent then j+=1 bindings[j]=b end
end
for i=#bindings,j+1,-1 do bindings[i]=nil end
end

activeTween=setmetatable({},{__mode="k"})
function tween(obj,t,props,style,dir)
local k=S.anim_level
if k==nil then k=1 end
local reg=activeTween[obj]
if not reg then reg={}activeTween[obj]=reg end
for prop,val in pairs(props)do
local old=reg[prop]
if old then old:Cancel()reg[prop]=nil end
if k<=0 then
obj[prop]=val
else
local tw=TweenService:Create(obj,TweenInfo.new(math.max(t*k,.03),style or Enum.EasingStyle.Quad,dir or Enum.EasingDirection.Out),{[prop]=val})
reg[prop]=tw
tw:Play()
end
end
end

function new(class,props,parent)
local o=Instance.new(class)
for k,v in pairs(props or{})do
if type(v)=="string"and(COLOR_PROPS[k]or k=="BackgroundTransparency")then bind(o,k,v)
else o[k]=v end
end
if parent then o.Parent=parent end
return o
end
function round(o,r)return new("UICorner",{CornerRadius=UDim.new(0,r or 6)},o)end
function stroke(o,key,th,tr)
return new("UIStroke",{Color=key or"Border",Thickness=th or 1,Transparency=tr or 0,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},o)
end
function text(parent,t,size,key,bold,extra)
local p={BackgroundTransparency=1,Text=t,TextSize=size,TextColor3=key or"Text",
Font=bold and BOLD or FONT,TextXAlignment=Enum.TextXAlignment.Left,
TextTruncate=Enum.TextTruncate.AtEnd,BorderSizePixel=0}
if extra then for k,v in pairs(extra)do p[k]=v end end
return new("TextLabel",p,parent)
end

local ICON_DEFS={
home={{"l",3,12,12,4},{"l",12,4,21,12},{"l",6,11,6,20},{"l",18,11,18,20},{"l",6,20,18,20}},
farm={{"l",12,21,12,10},{"l",12,14,6,9},{"l",12,11,18,6},{"l",7,21,17,21}},
automation={{"l",13,3,6,13},{"l",6,13,12,13},{"l",12,13,10,21},{"l",10,21,18,10},{"l",18,10,12,10},{"l",12,10,13,3}},
movement={{"l",5,19,19,5},{"l",10,5,19,5},{"l",19,5,19,14}},
visuals={{"o",3,7,18,10,5},{"d",12,12,2.6}},
player={{"c",12,8,4},{"o",5,14,14,8,5}},
statistics={{"f",5,12,3,8,1},{"f",10.5,7,3,13,1},{"f",16,4,3,16,1}},
server={{"o",4,4,16,6,2},{"o",4,14,16,6,2},{"d",8,7,1},{"d",8,17,1}},
webhook={{"o",3,5,11,9,3},{"o",10,10,11,9,3},{"l",11,9,14,12},{"l",14,12,17,15},{"d",5,9,1.2},{"d",19,15,1.2}},
settings={{"l",4,8,20,8},{"l",4,16,20,16},{"d",9,8,2.8},{"d",15,16,2.8}},
diagnostics={{"l",3,12,8,12},{"l",8,12,10,6},{"l",10,6,14,18},{"l",14,18,16,12},{"l",16,12,21,12}},
about={{"c",12,12,9},{"l",12,11,12,17},{"d",12,7.6,1.1}},
theme={{"c",12,12,9},{"d",8,10,1.4},{"d",12,7,1.4},{"d",16,10,1.4}},
search={{"c",10.5,10.5,6.5},{"l",15.5,15.5,20,20}},
notification={{"o",6,5,12,11,6},{"l",4,17,20,17},{"d",12,20,1.6}},
minimize={{"l",6,17,18,17}},
close={{"l",6,6,18,18},{"l",18,6,6,18}},
expand={{"o",4,4,16,16,3}},
collapse={{"o",4,8,12,12,2},{"l",8,4,20,4},{"l",20,4,20,16}},
save={{"o",4,4,16,16,2},{"l",8,4,8,9},{"l",8,9,16,9},{"o",8,14,8,6,1}},
reset={{"c",12,13,7},{"l",6,3,6,9},{"l",6,9,12,9}},
refresh={{"c",12,12,7},{"l",18,3,18,9},{"l",18,9,12,9}},
import={{"l",12,4,12,15},{"l",8,11,12,15},{"l",16,11,12,15},{"l",5,20,19,20}},
export={{"l",12,16,12,5},{"l",8,9,12,5},{"l",16,9,12,5},{"l",5,20,19,20}},
play={{"l",8,5,19,12},{"l",19,12,8,19},{"l",8,19,8,5}},
pause={{"f",7,5,3,14,1},{"f",14,5,3,14,1}},
stop={{"f",6,6,12,12,2}},
chevron={{"l",6,9,12,15},{"l",12,15,18,9}},
check={{"l",5,12,10,17},{"l",10,17,19,7}},
warning={{"l",12,4,21,19},{"l",21,19,3,19},{"l",3,19,12,4},{"l",12,10,12,14},{"d",12,16.8,1}},
error={{"c",12,12,9},{"l",8.5,8.5,15.5,15.5},{"l",15.5,8.5,8.5,15.5}},
menu={{"l",4,7,20,7},{"l",4,12,20,12},{"l",4,17,20,17}},
presets={{"o",4,4,16,16,3},{"l",8,9,16,9},{"l",8,13,16,13},{"l",8,17,13,17}},
community={{"c",8,8,3},{"c",16,8,3},{"o",3,14,10,6,3},{"o",11,14,10,6,3}},
logo={{"o",4.5,4.5,15,15,3.5,45},{"o",8.5,8.5,7,7,1.5,45},{"d",12,12,1.6}},
shield={{"l",12,3,20,6},{"l",20,6,20,12},{"l",20,12,12,21},{"l",12,21,4,12},{"l",4,12,4,6},{"l",4,6,12,3},{"l",8.5,12,11,14.5},{"l",11,14.5,15.5,9.5}},
crown={{"l",4,18,20,18},{"l",4,18,3,8},{"l",3,8,8,12},{"l",8,12,12,5},{"l",12,5,16,12},{"l",16,12,21,8},{"l",21,8,20,18}},
megaphone={{"l",4,9,10,9},{"l",10,9,18,5},{"l",18,5,18,19},{"l",18,19,10,15},{"l",10,15,4,15},{"l",4,15,4,9}},
trash={{"l",5,7,19,7},{"o",7,8,10,12,2},{"l",10,4,14,4}},
logs={{"o",5,3,14,18,2},{"l",8,8,16,8},{"l",8,12,16,12},{"l",8,16,13,16}},
arrow={{"l",5,12,19,12},{"l",13,6,19,12},{"l",13,18,19,12}},
}

Icons={}
local function iconColor(ic)
if ic.override then return ic.override end
if ic.state=="hover"then return T.Text end
if ic.state=="active"then return T.Accent end
if ic.state=="disabled"then return T.Off end
return T.Sub
end
local function paintIcon(ic,animate)
local col=iconColor(ic)
for _,pt in ipairs(ic.parts)do
local prop=pt[2]=="stroke"and"Color"or"BackgroundColor3"
if animate then tween(pt[1],.16,{[prop]=col})else pt[1][prop]=col end
end
end
phaseMark("icon system")
function CreateIcon(name,size,parent,props)
local def=ICON_DEFS[name]or ICON_DEFS.about
local k=size/24
local th=math.max(1.5,1.9*k)
local root=new("Frame",{BackgroundTransparency=1,Size=UDim2.fromOffset(size,size),BorderSizePixel=0},parent)
if props then for a,b in pairs(props)do root[a]=b end end
local ic={root=root,parts={},state="normal",name=name,size=size}
local function add(inst,mode)ic.parts[#ic.parts+1]={inst,mode}end
for _,d in ipairs(def)do
local kind=d[1]
if kind=="l"then
local dx,dy=(d[4]-d[2])*k,(d[5]-d[3])*k
local f=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset((d[2]+d[4])/2*k,(d[3]+d[5])/2*k),
Size=UDim2.fromOffset(math.sqrt(dx*dx+dy*dy)+th*.5,th),Rotation=math.deg(math.atan2(dy,dx)),BorderSizePixel=0},root)
new("UICorner",{CornerRadius=UDim.new(.5,0)},f)
add(f,"bg")
elseif kind=="d"then
local r=d[4]*k
local f=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(d[2]*k,d[3]*k),Size=UDim2.fromOffset(r*2,r*2),BorderSizePixel=0},root)
new("UICorner",{CornerRadius=UDim.new(.5,0)},f)
add(f,"bg")
elseif kind=="c"then
local r=d[4]*k
local f=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(d[2]*k,d[3]*k),Size=UDim2.fromOffset(r*2-th,r*2-th),BackgroundTransparency=1,BorderSizePixel=0},root)
new("UICorner",{CornerRadius=UDim.new(.5,0)},f)
add(new("UIStroke",{Thickness=th,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},f),"stroke")
elseif kind=="o"then
local f=new("Frame",{Position=UDim2.fromOffset(d[2]*k+th/2,d[3]*k+th/2),Size=UDim2.fromOffset(d[4]*k-th,d[5]*k-th),
BackgroundTransparency=1,BorderSizePixel=0,Rotation=d[7]or 0},root)
new("UICorner",{CornerRadius=UDim.new(0,d[6]*k)},f)
add(new("UIStroke",{Thickness=th,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},f),"stroke")
elseif kind=="f"then
local f=new("Frame",{Position=UDim2.fromOffset(d[2]*k,d[3]*k),Size=UDim2.fromOffset(d[4]*k,d[5]*k),BorderSizePixel=0},root)
new("UICorner",{CornerRadius=UDim.new(0,d[6]*k)},f)
add(f,"bg")
end
end
Icons[#Icons+1]=ic
paintIcon(ic,false)
return ic
end
function SetIconColor(ic,color)
if not ic or not ic.root.Parent then return end
ic.override=color
paintIcon(ic,true)
end
function SetIconState(ic,state)
if not ic or not ic.root.Parent or ic.state==state then return end
ic.state=state
ic.override=nil
paintIcon(ic,true)
end
function DestroyIcon(ic)
if not ic then return end
local i=table.find(Icons,ic)
if i then table.remove(Icons,i)end
if ic.root then ic.root:Destroy()end
end
function refreshIcons(animate)
local j=0
for i=1,#Icons do
local ic=Icons[i]
if ic.root.Parent then j+=1 Icons[j]=ic paintIcon(ic,animate)end
end
for i=#Icons,j+1,-1 do Icons[i]=nil end
end
function iconHover(btn,ic,isActive)
if IS_TOUCH then return end
btn.MouseEnter:Connect(function()if not isActive or not isActive()then SetIconState(ic,"hover")end end)
btn.MouseLeave:Connect(function()SetIconState(ic,(isActive and isActive())and"active"or"normal")end)
end

phaseMark("feature registry")
Tabs,TabByName,Feat,FeatList={},{},{},{}

function addTab(name,icon)
local t={name=name,icon=icon,items={}}
Tabs[#Tabs+1]=t
TabByName[name]=t
return t
end

function def(tabName,id,f)
assert(not Feat[id],"duplicate feature id "..id)
f.id,f.tab,f.views=id,tabName,{}
Feat[id]=f
FeatList[#FeatList+1]=f
table.insert(TabByName[tabName].items,f)
if f.kind=="toggle"then S[id]=false
elseif f.kind=="slider"or f.kind=="dropdown"then S[id]=f.default
elseif f.kind=="color"then S[id]=""
elseif f.kind=="input"then
if not f.private then S[id]=f.default or""end
end
return f
end

local NEEDS="Needs this game's own remotes/objects. They are not verified, so nothing is faked."
function na(tabName,id,name,desc,reason,badge)
def(tabName,id,{kind="toggle",name=name,desc=desc,unavailable=reason or NEEDS,badge=badge or"NEEDS INTEGRATION"})
end

end
local function refreshViews(f)
for _,u in pairs(f.views)do pcall(u)end
end

local valid,setValue,V2,THEME_IDS,encodeConfig,applyConfig,importJSON,readStoredConfig,saveConfig,loadConfig,resetConfig,gui,WIN_W,WIN_H,TITLE_H,SB_OPEN,SB_MIN,ROW_H,TAB_H,state,uiRefs,baseScale,notifScale,liveNotifs
do
function valid(f,v)
if f.kind=="slider"then return type(v)=="number"end
if f.kind=="dropdown"then return type(v)=="string"and table.find(f.options,v)~=nil end
if f.kind=="color"then return type(v)=="string"and(v==""or hexColor(v)~=nil)end
if f.kind=="toggle"then return type(v)=="boolean"end
if f.kind=="input"then return type(v)=="string"and#v<=300 and(v==""or not f.validate or f.validate(v)==true)end
return false
end

function setValue(id,v,silent)
local f=Feat[id]
if not f then return false end
if f.kind=="toggle"then
v=(v==true)
if v and f.unavailable then
if not silent then notify(f.name..": "..f.unavailable,"warn",4)end
refreshViews(f)
return false
end
if S[id]==v then refreshViews(f)return true end
if v then
local ok,r1,r2=pcall(f.fn,true)
if not ok then
warn("[CAZX] "..f.name..": "..tostring(r1))
pcall(f.fn,false)
S[id]=false
notify(f.name.." failed to start","bad")
refreshViews(f)updateActive()
return false
end
if r1==false then
pcall(f.fn,false)
S[id]=false
notify(r2 or(f.name.." is not available"),"warn",4)
refreshViews(f)updateActive()
return false
end
S[id]=true
if not silent then notify(f.name.." enabled","good",1.6)end
else
local ok,err=pcall(f.fn,false)
if not ok then warn("[CAZX] "..f.name.." cleanup: "..tostring(err))end
S[id]=false
if not silent then notify(f.name.." disabled","info",1.4)end
end
updateActive()
elseif f.kind=="slider"then
if type(v)~="number"or f.unavailable then return false end
local step=f.step or 1
v=math.clamp(math.floor(v/step+.5)*step,f.min,f.max)
v=tonumber(string.format("%.4f",v))
if S[id]==v then return true end
S[id]=v
if f.fn then
local ok,err=pcall(f.fn,v)
if not ok then warn("[CAZX] "..f.name..": "..tostring(err))end
end
elseif f.kind=="dropdown"then
if f.unavailable or not table.find(f.options,v)then return false end
if S[id]==v then refreshViews(f)return true end
S[id]=v
if f.fn then pcall(f.fn,v)end
elseif f.kind=="color"then
if not valid(f,v)then return false end
v=v:lower()
if S[id]==v then refreshViews(f)return true end
S[id]=v
if f.fn then pcall(f.fn,v)end
elseif f.kind=="input"then
if f.private or f.unavailable or not valid(f,v)then return false end
if S[id]==v then refreshViews(f)return true end
S[id]=v
if f.fn then pcall(f.fn,v)end
end
refreshViews(f)
markDirty()
return true
end

phaseMark("config and state")
V2={on={}}
local memoryConfig=_G.__CAZX_MEMCFG
local dirty=false
THEME_IDS={"theme_preset","theme_accent","theme_bg","theme_panel","theme_border","theme_text","theme_sub","theme_tr","anim_level","ui_scale"}

function encodeConfig()
local out={v=2,tab=S._tab,state={},pos={wx=POS.win.x,wy=POS.win.y,fx=POS.float.x,fy=POS.float.y}}
for _,f in ipairs(FeatList)do
if f.kind=="toggle"or f.kind=="slider"or f.kind=="dropdown"or f.kind=="color"or(f.kind=="input"and not f.private)then out.state[f.id]=S[f.id]end
end
return HttpService:JSONEncode(out)
end

function applyConfig(data)
if type(data)~="table"or type(data.state)~="table"then return false,"Invalid config structure"end
local applied,skipped=0,0
for pass=1,2 do
for _,f in ipairs(FeatList)do
local isToggle=f.kind=="toggle"
if(pass==1 and not isToggle)or(pass==2 and isToggle)then
local v=data.state[f.id]
if v~=nil then
if valid(f,v)and not(isToggle and v and f.unavailable)and not(f.unavailable and not isToggle)then
setValue(f.id,v,true)
applied+=1
else
skipped+=1
end
end
end
end
end
for k in pairs(data.state)do if not Feat[k]then skipped+=1 end end
if type(data.pos)=="table"then
local function n(v,d)return(type(v)=="number"and v==v and v>=-1 and v<=1)and v or d end
POS.win.x,POS.win.y=math.clamp(n(data.pos.wx,.5),0,1),math.clamp(n(data.pos.wy,.5),0,1)
local fx=n(data.pos.fx,-1)
POS.float.x,POS.float.y=fx<0 and-1 or math.clamp(fx,0,1),math.clamp(n(data.pos.fy,.5),0,1)
if placeAll then placeAll()end
end
if type(data.tab)=="string"and TabByName[data.tab]and TabByName[data.tab].page then switchTab(data.tab,true)end
return true,("Applied %d, skipped %d"):format(applied,skipped)
end

function importJSON(str)
if type(str)~="string"or str:match("^%s*$")then return false,"Config is empty"end
local ok,data=pcall(HttpService.JSONDecode,HttpService,str)
if not ok then return false,"Invalid JSON"end
return applyConfig(data)
end

function readStoredConfig()
local json
if HAS_FILES then
local ok,exists=pcall(isfile,CONFIG_FILE)
if ok and exists then
local ok2,c=pcall(readfile,CONFIG_FILE)
if ok2 then json=c end
end
end
return json or memoryConfig
end

function saveConfig(silent)
if V2.noSave or V2.booting then return end
local json=encodeConfig()
memoryConfig=json
_G.__CAZX_MEMCFG=json
if HAS_FILES then
local ok=pcall(writefile,CONFIG_FILE,json)
if ok then
local okr,back=pcall(readfile,CONFIG_FILE)
ok=okr and back==json
end
if not silent then notify(ok and"Configuration saved to file"or"File write failed (kept in session)",ok and"good"or"warn")
elseif not ok and os.clock()-(V2.lastSaveWarn or-100)>60 then
V2.lastSaveWarn=os.clock()
notify("Auto-save failed: file write error (settings kept for this session)","warn",4)
end
elseif not silent then
notify("No file access: saved for this session only","warn")
end
end

function loadConfig(silent)
local json=readStoredConfig()
if not json then
if not silent then notify("No saved configuration found","warn")end
return
end
local ok,msg=importJSON(json)
if not silent then notify(ok and("Loaded. "..msg)or msg,ok and"good"or"bad")end
end

function resetConfig()
for _,f in ipairs(FeatList)do
if f.kind=="toggle"then setValue(f.id,V2.on[f.id]==true,true)
elseif f.kind=="slider"or f.kind=="dropdown"then setValue(f.id,f.default,true)
elseif f.kind=="color"then setValue(f.id,"",true)
elseif f.kind=="input"and not f.private then setValue(f.id,f.default or"",true)end
end
notify("Configuration reset to defaults","good")
end

markDirty=function()
if dirty or S.cfg_autosave==false then return end
dirty=true
task.delay(.6,function()
dirty=false
if alive then pcall(saveConfig,true)end
end)
end

gui=Root.add(new("ScreenGui",{Name="CazielxArchx",ResetOnSpawn=false,DisplayOrder=100,
ZIndexBehavior=Enum.ZIndexBehavior.Sibling,IgnoreGuiInset=true},PlayerGui))
assert(gui.Parent==PlayerGui,"ScreenGui was not parented to "..PlayerGui.Name)
do
local earlyCleanup
earlyCleanup=function()
DIAG.superseded=true
alive=false
Root.clear()
if slotGet("__CAZX_CLEANUP")==earlyCleanup then slotSet("__CAZX_CLEANUP",nil)end
end
DIAG.cleanup=earlyCleanup
slotSet("__CAZX_CLEANUP",earlyCleanup)
end
phaseMark("root gui created")

WIN_W,WIN_H,TITLE_H=700,440,44
SB_OPEN,SB_MIN=158,52
ROW_H=IS_TOUCH and 52 or 46
TAB_H=IS_TOUCH and 44 or 38
state={open=false,min=false,max=false,sb=not IS_TOUCH,unloadArmed=false}
uiRefs={}

function baseScale()
local vp=gui.AbsoluteSize
if vp.X<10 or vp.Y<10 then return 1 end
local fit=math.max(math.min((vp.X-12)/WIN_W,(vp.Y-12)/WIN_H),.4)
local s=math.min(fit,1.15)*(S.ui_scale or 1)
return math.min(s,fit)
end

local notifHolder=new("Frame",{Name="Notifications",BackgroundTransparency=1,AnchorPoint=Vector2.new(1,0),
Position=UDim2.new(1,-10,0,10),Size=UDim2.fromOffset(280,400),ZIndex=50},gui)
notifScale=new("UIScale",{Scale=1},notifHolder)
new("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},notifHolder)
liveNotifs={}
local NOTIF_ICON={good="check",warn="warning",bad="error",info="about"}
local NOTIF_KEY={good="Good",warn="Warn",bad="Bad",info="Accent"}

local function dropNotif(wrap)
local i=table.find(liveNotifs,wrap)
if i then table.remove(liveNotifs,i)end
if wrap.icon then DestroyIcon(wrap.icon)end
if wrap.frame and wrap.frame.Parent then wrap.frame:Destroy()end
end

phaseMark("notification system")
notify=function(msg,kind,dur)
if not alive then return end
kind=NOTIF_ICON[kind]and kind or"info"
local lvl=S.notif_level or"All"
if lvl=="Off"or(lvl=="Important"and(kind=="info"or kind=="good"))then return end
while#liveNotifs>=4 do dropNotif(table.remove(liveNotifs,1))end
local frame=new("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,50)},notifHolder)
local card=new("Frame",{BackgroundColor3="Panel",Size=UDim2.fromScale(1,1),Position=UDim2.new(1.3,0,0,0),BorderSizePixel=0},frame)
round(card,8)stroke(card,NOTIF_KEY[kind],1,.45)
new("Frame",{BackgroundColor3=NOTIF_KEY[kind],Size=UDim2.new(0,3,1,-16),Position=UDim2.fromOffset(7,8),BorderSizePixel=0},card)
local ic=CreateIcon(NOTIF_ICON[kind],16,card,{Position=UDim2.new(0,18,.5,-8)})
SetIconColor(ic,T[NOTIF_KEY[kind]])
text(card,tostring(msg),12,"Text",false,{Position=UDim2.fromOffset(42,0),Size=UDim2.new(1,-50,1,0),TextWrapped=true,TextTruncate=Enum.TextTruncate.None})
local entry={frame=frame,icon=ic}
liveNotifs[#liveNotifs+1]=entry
tween(card,.28,{Position=UDim2.new(0,0,0,0)},Enum.EasingStyle.Back)
task.delay(dur or 3,function()
if not frame.Parent then return end
tween(card,.2,{Position=UDim2.new(1.3,0,0,0)})
task.delay(.24,function()dropNotif(entry)end)
end)
end

end
local tip,bindTooltip,beginDrag,isPress,rejoin,loop,getRemote,numAttr,getCash,humanoidOverride
do
tip=new("TextLabel",{Visible=false,AutomaticSize=Enum.AutomaticSize.XY,BackgroundColor3="Bg",
TextColor3="Text",Font=FONT,TextSize=12,TextWrapped=true,Text="",ZIndex=200,
BorderSizePixel=0,TextXAlignment=Enum.TextXAlignment.Left},gui)
round(tip,6)stroke(tip,"Accent",1,.4)
new("UIPadding",{PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8),PaddingTop=UDim.new(0,5),PaddingBottom=UDim.new(0,5)},tip)
new("UISizeConstraint",{MaxSize=Vector2.new(260,220)},tip)

function bindTooltip(obj,msg)
if IS_TOUCH or not msg or msg==""then return end
local function place()
local m=UIS:GetMouseLocation()
tip.Position=UDim2.fromOffset(math.min(m.X+14,gui.AbsoluteSize.X-280),m.Y+16)
end
obj.MouseEnter:Connect(function()tip.Text=msg place()tip.Visible=true end)
obj.MouseMoved:Connect(place)
obj.MouseLeave:Connect(function()tip.Visible=false end)
end

local drag
function beginDrag(input,update,finish)
drag={input=input,update=update,finish=finish}
end
optional("InputChanged hook",function()Root.add(UIS.InputChanged:Connect(function(input)
if not drag then return end
local t=input.UserInputType
if t==Enum.UserInputType.MouseMovement or(t==Enum.UserInputType.Touch and input==drag.input)then
drag.update(input.Position)
end
end))end)
optional("InputEnded hook",function()Root.add(UIS.InputEnded:Connect(function(input)
if not drag then return end
if input==drag.input or(drag.input.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseButton1)then
local d=drag
drag=nil
if d.finish then pcall(d.finish)end
end
end))end)
function isPress(input)
return input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch
end

addTab("Home","home")addTab("Farm","farm")addTab("Automation","automation")addTab("Movement","movement")
addTab("Visuals","visuals")addTab("Player","player")addTab("Statistics","statistics")addTab("Server","server")
addTab("Webhook","webhook")addTab("Presets","presets")addTab("Community","community")addTab("News","notification")addTab("Admin Panel","shield")addTab("Settings","settings")addTab("Theme","theme")addTab("Diagnostics","diagnostics")addTab("About","about")

function rejoin()
if#Players:GetPlayers()<=1 then TeleportService:Teleport(game.PlaceId,Player)
else TeleportService:TeleportToPlaceInstance(game.PlaceId,game.JobId,Player)end
end
optional("TeleportInitFailed hook",function()Root.add(TeleportService.TeleportInitFailed:Connect(function(_,_,msg)notify("Teleport failed: "..tostring(msg),"bad",5)end))end)

do

local tasks,conn={},nil
V2.sched={errors=0,lastErr="none",count=function()return#tasks end}
local function tick()
local now=os.clock()
local j=0
for i=1,#tasks do
local h=tasks[i]
if h.alive and alive then
j+=1
tasks[j]=h
if not h.paused and not h.busy and now>=h.nextAt then
h.busy=true
task.spawn(function()
local ok,err=pcall(h.step,h)
h.busy=false
h.nextAt=os.clock()+h.interval
if ok then
h.fails=0
else
h.fails+=1
V2.sched.errors+=1
V2.sched.lastErr=tostring(err)
warn("[CAZX] "..tostring(err))
if h.fails>=8 then
h.alive=false
if notify then pcall(notify,"A feature loop stopped after 8 consecutive errors. See Diagnostics.","bad",5)end
end
end
end)
end
end
end
for i=#tasks,j+1,-1 do tasks[i]=nil end
end
loop=function(interval,step)
local h={alive=true,paused=false,busy=false,fails=0,step=step,interval=interval,nextAt=0}
tasks[#tasks+1]=h
if not conn then
conn=RunService.Heartbeat:Connect(tick)
Root.add(function()
if conn then conn:Disconnect()conn=nil end
table.clear(tasks)
end)
end
return h
end
end

function getRemote(name)
local r=ReplicatedStorage:FindFirstChild(name)
if r and r:IsA("RemoteEvent")then return r end
return nil
end
local function fireRemote(name,...)
local r=getRemote(name)
if not r then return false end
return(pcall(r.FireServer,r,...))
end
function numAttr(name)
local v=Player:GetAttribute(name)
return type(v)=="number"and v or nil
end
local function findStat(names)
local ls=Player:FindFirstChild("leaderstats")
if not ls then return nil end
for _,n in ipairs(names)do
local v=ls:FindFirstChild(n)
if v and(v:IsA("NumberValue")or v:IsA("IntValue"))then return v.Value end
end
return nil
end
function getCash()
return numAttr("Cash")or findStat({"Cash","Coins","Money","Gold"})
end

function humanoidOverride(prop,valueFn,aux)
local self,bag,origs,auxOrigs={},nil,nil,nil
local function enforce(h)local v=valueFn()if h[prop]~=v then h[prop]=v end end
function self.enable()
self.disable()
bag,origs,auxOrigs=newBag(),setmetatable({},{__mode="k"}),setmetatable({},{__mode="k"})
hookCharacter(bag,function(char,cb)
local h=char:FindFirstChildOfClass("Humanoid")or char:WaitForChild("Humanoid",5)
if not h or not origs then return end
if origs[h]==nil then origs[h]=h[prop]if aux then auxOrigs[h]=h[aux.prop]end end
if aux then h[aux.prop]=aux.value end
enforce(h)
cb.add(h:GetPropertyChangedSignal(prop):Connect(function()enforce(h)end))
end)
end
function self.refresh()if bag then local h=getHum()if h then enforce(h)end end end
function self.disable()
if not bag then return end
bag.clear()bag=nil
for h,v in pairs(origs)do
if h.Parent then pcall(function()h[prop]=v if aux then h[aux.prop]=auxOrigs[h]end end)end
end
origs,auxOrigs=nil,nil
end
return self
end

local function hasAnimalTool()
for _,c in ipairs({Player:FindFirstChild("Backpack"),Player.Character})do
if c then
for _,t in ipairs(c:GetChildren())do
if t:IsA("Tool")and t.Name~="Bat"and not V2.classifyTool(t)then return true end
end
end
end
return false
end

local bestLoop
def("Farm","auto_best",{kind="toggle",name="Place Best Pets",desc="Equips your best pets whenever you hold an animal (PetsInventoryRemote).",fn=function(on)
if bestLoop then bestLoop.alive=false bestLoop=nil end
if not on then return end
if not getRemote("PetsInventoryRemote")then return false,"PetsInventoryRemote was not found in ReplicatedStorage"end
bestLoop=loop(3,function()if hasAnimalTool()then fireRemote("PetsInventoryRemote","EquipBest")end end)
end})
def("Farm","auto_bestnow",{kind="button",name="Place Best Now",desc="Sends one EquipBest request now.",run=function()
if not getRemote("PetsInventoryRemote")then return false,"PetsInventoryRemote was not found in ReplicatedStorage"end
if not fireRemote("PetsInventoryRemote","EquipBest")then return false,"EquipBest request failed"end
notify("EquipBest sent","good",1.8)
end})

local function buyLoop(remoteName,argsFn,progressFn,confirmed)
local gate={wait=5,nextAt=0}
return loop(1,function()
if os.clock()<gate.nextAt then return end
local args=argsFn()
if not args then return end
local before=progressFn()
if not fireRemote(remoteName,table.unpack(args))then return end
task.wait(1.2)
if confirmed(before,progressFn())then
gate.wait=5
gate.nextAt=os.clock()+1
else
gate.wait=math.min(gate.wait*1.5,40)
gate.nextAt=os.clock()+gate.wait
end
end)
end

local pickLoop
def("Farm","inv_pick",{kind="toggle",name="Buy Pickaxes",desc="Buys the next pickaxe tier (PickaxeShopRequest) and backs off when it fails.",fn=function(on)
if pickLoop then pickLoop.alive=false pickLoop=nil end
if not on then return end
if not getRemote("PickaxeShopRequest")then return false,"PickaxeShopRequest was not found in ReplicatedStorage"end
if not numAttr("PickaxeTier")then return false,"PickaxeTier attribute was not found on your player"end
pickLoop=buyLoop("PickaxeShopRequest",function()
local tier=numAttr("PickaxeTier")
return tier and{"Buy",tier+1}or nil
end,function()return numAttr("PickaxeTier")end,function(a,b)return a~=b end)
end})

local plotLoop
def("Farm","up_plot",{kind="toggle",name="Upgrade Plot",desc="Requests plot upgrades (UpgradePlotRequest); success is confirmed by a cash drop.",fn=function(on)
if plotLoop then plotLoop.alive=false plotLoop=nil end
if not on then return end
if not getRemote("UpgradePlotRequest")then return false,"UpgradePlotRequest was not found in ReplicatedStorage"end
if not numAttr("Cash")then return false,"Cash attribute was not found on your player"end
plotLoop=buyLoop("UpgradePlotRequest",function()return numAttr("Cash")and{}or nil end,
function()return numAttr("Cash")end,function(a,b)return a and b and b<a end)
end})

end
local FarmInfo,farmErr,instPos,getBase,farmEvent,isAxeName,eggLabel
do
FarmInfo={base=nil,baseWhy="not scanned",eggs=0,eggState="TESTING",interact="not checked",breakState="OFF",errors={},broken=0,animals=0,t0=os.clock(),status="OFF",target="none",lastAnimal="none",catalog="not scanned",carrying=false,paused=false,respawns=0,vanished=0}
phaseMark("farm module")
V2.session={earnings=0,bestIdx=0,bestName="none",history={},pets={},petCounts={},petTotal=0,lastCash=nil}
function farmErr(msg)
FarmInfo.errors[#FarmInfo.errors+1]=os.date("%H:%M:%S").." "..tostring(msg)
while#FarmInfo.errors>15 do table.remove(FarmInfo.errors,1)end
end
local OWNER_KEYS={"Owner","OwnerId","OwnerUserId","UserId","Player","PlayerName","Username"}
local function isMine(v)
if v==Player or v==Player.UserId or v==Player.Name or v==Player.DisplayName then return true end
return type(v)=="string"and tonumber(v)==Player.UserId
end
local function ownedByMe(inst)
for _,k in ipairs(OWNER_KEYS)do
local ok,a=pcall(inst.GetAttribute,inst,k)
if ok and a~=nil and isMine(a)then return true,"attribute "..k end
end
for _,c in ipairs(inst:GetChildren())do
if c:IsA("ValueBase")and table.find(OWNER_KEYS,c.Name)then
local ok,v=pcall(function()return c.Value end)
if ok and isMine(v)then return true,"value "..c.Name end
end
end
return false
end
function instPos(inst)
if inst:IsA("Model")then return inst:GetPivot().Position end
if inst:IsA("BasePart")then return inst.Position end
local p=inst:FindFirstChildWhichIsA("BasePart",true)
return p and p.Position or nil
end
local function scanBase()

local queue,head,seen={{workspace,0}},1,0
while queue[head]do
local cur,depth=queue[head][1],queue[head][2]
head+=1
for _,c in ipairs(cur:GetChildren())do
seen+=1
if seen>2500 then break end
if c:IsA("Model")or c:IsA("Folder")or c:IsA("BasePart")then
local ok,why=ownedByMe(c)
if ok then return c,why end
if depth<2 and not c:IsA("BasePart")and c~=Player.Character then queue[#queue+1]={c,depth+1}end
end
end
end
local rl=Player.RespawnLocation
if rl and rl.Parent then return rl,"Player.RespawnLocation"end
return nil,"no object tagged with your UserId/Name (Owner attributes/values) and no RespawnLocation"
end
function getBase(force)
local b=FarmInfo.base
if force or not b or not b.Parent then
FarmInfo.base,FarmInfo.baseWhy=V2.scanBase()
b=FarmInfo.base
end
return b
end
optional("Respawn and character hooks",function()
Root.add(Player:GetPropertyChangedSignal("RespawnLocation"):Connect(function()FarmInfo.base=nil end))
hookCharacter(Root,function(char)FarmInfo.base=nil FarmInfo.interact="not checked"end)
end)

local function findEggs(base)
local out={}
local build=workspace:FindFirstChild("Build")
local zones=build and build:FindFirstChild("ZoneBuilds")
if not zones then return out,"Workspace.Build.ZoneBuilds not found"end
for _,o in ipairs(zones:GetDescendants())do
if o.Name=="Egg"and o:IsA("BasePart")and o.Parent and o.Parent.Parent and o.Parent.Parent.Name=="Eggs"then
if not base or o:IsDescendantOf(base)then out[#out+1]=o end
end
end
return out
end
local function eggInteraction(egg)

local model=V2.eggModel[egg]or egg
local pp=model:FindFirstChildWhichIsA("ProximityPrompt",true)
if pp then
local t=(pp.ActionText.." "..pp.ObjectText):lower()
if t:find("break")or t:find("hit")or t:find("smash")or t:find("crack")then return"prompt",pp end
end
return nil
end

na("Farm","farm_onehit","Egg Breaker One-Hit","Break an egg with a single hit.","Cannot be verified: whether one hit is possible is decided by the game's server, and no documented mechanism exists to force it. Not faked.","NOT SUPPORTED")
def("Farm","farm_scan",{kind="button",name="Scan Farm Status",desc="Re-detects your base, eggs and interaction type and reports the result.",run=function()
local base=getBase(true)
if not base then notify("Base: "..tostring(FarmInfo.baseWhy),"warn",5)return false,"Base not detected"end
local eggs,why=findEggs(base)
FarmInfo.eggs=#eggs
local kind=#eggs>0 and eggInteraction(eggs[1])or nil
FarmInfo.interact=kind or(#eggs>0 and"none found"or"no eggs")
FarmInfo.eggState=why and("ERROR: "..why)or(#eggs>0 and(#eggs.." egg(s) detected")or"NO EGGS IN BASE")
notify(("Base OK (%s) | %s | interaction: %s"):format(FarmInfo.baseWhy,FarmInfo.eggState,FarmInfo.interact),"info",5)
end})

local RARITY_ORDER={"common","uncommon","rare","epic","legendary","mythic","divine","secret"}
local farmSkip=setmetatable({},{__mode="k"})
local lastFail={}

function farmEvent(title,desc,kind,fields,evType)
if not(S.wh_events and whEvent)then return end
if evType and S["wh_ev_"..evType]==false then return end
pcall(whEvent,title,desc,kind,fields)
end
local function farmFail(msg)
farmErr(msg)
local now=os.clock()
if lastFail[msg]and now-lastFail[msg]<30 then return end
lastFail[msg]=now
notify("Auto Farm: "..msg,"bad",4)
farmEvent("Farm error",msg,"bad",nil,"error")
end

function isAxeName(n)
n=tostring(n):lower()
if n:find("bat",1,true)and not n:find("axe",1,true)then return false end
return n:find("axe",1,true)~=nil or n:find("pick",1,true)~=nil
end
local function findAxe()
for _,c in ipairs({Player.Character,Player:FindFirstChild("Backpack")})do
if c then
for _,t in ipairs(c:GetChildren())do
if t:IsA("Tool")and isAxeName(t.Name)then return t end
end
end
end
return nil
end
local function heldKey()
local names={}
for _,c in ipairs({Player:FindFirstChild("Backpack"),Player.Character})do
if c then
for _,t in ipairs(c:GetChildren())do
if t:IsA("Tool")and t.Name~="Bat"and not t.Name:lower():find("axe",1,true)then names[#names+1]=t.Name end
end
end
end
table.sort(names)
return table.concat(names,"|")
end

function eggLabel(egg)
local holder=egg.Parent
for _,k in ipairs({"EggName","EggType","Type","Name"})do
local v=egg:GetAttribute(k)
if v==nil and holder then v=holder:GetAttribute(k)end
if type(v)=="string"and v~=""then return v end
end
return holder and holder.Name or"Egg"
end
function V2.rarityIndex(v)
if type(v)=="number"then
local n=math.floor(v)
if n>=1 then return math.min(n,99)end
return 0
end
if type(v)=="string"then
local str=v:lower()
local i=table.find(RARITY_ORDER,str)
if i then return i end
for k=#RARITY_ORDER,1,-1 do
if str:find("%f[%a]"..RARITY_ORDER[k].."%f[%A]")then return k end
end
end
return 0
end

function V2.rarityInfo(inst,nameHint)
if inst then
for _,o in ipairs({inst,inst.Parent})do
if o then
for _,key in ipairs({"Rarity","RarityName","Tier"})do
local ok,a=pcall(o.GetAttribute,o,key)
local i=ok and V2.rarityIndex(a)or 0
if i>0 then return i,RARITY_ORDER[i]or("tier "..i),"attribute "..key end
end
local rv=o:FindFirstChild("Rarity")
if rv and rv:IsA("ValueBase")then
local ok,a=pcall(function()return rv.Value end)
local i=ok and V2.rarityIndex(a)or 0
if i>0 then return i,RARITY_ORDER[i]or("tier "..i),"value Rarity"end
end
end
end
end
local i=V2.rarityIndex(nameHint or(inst and inst.Name))
if i>0 then return i,RARITY_ORDER[i]or("tier "..i),"name"end
return 0,"unknown","none"
end
function V2.rareMin()
return table.find(RARITY_ORDER,tostring(S.pet_rare_min or"legendary"))or#RARITY_ORDER
end

V2.knownEggs=setmetatable({},{__mode="k"})
function V2.trackEggs(eggs)
local known,first=V2.knownEggs,not FarmInfo.eggSnap
local present={}
for _,e in ipairs(eggs)do
present[e]=true
if not known[e]then
known[e]=true
if not first then FarmInfo.respawns+=1 end
end
end
for e in pairs(known)do
if not present[e]then
known[e]=nil
FarmInfo.vanished+=1
end
end
FarmInfo.eggSnap=true
end

function V2.parseList(str)
local out={}
for tok in tostring(str or""):gmatch("[^,]+")do
local t=tok:match("^%s*(.-)%s*$"):lower()
if t~=""then out[#out+1]=t end
end
return out
end
function V2.labelHas(label,list)
for _,tok in ipairs(list)do
if label:find(tok,1,true)then return true end
end
return false
end

local function pickTarget(eggs,hrp)
local filter,ignore=V2.parseList(S.farm_filter),V2.parseList(S.farm_ignore)
local mode=S.farm_priority or"Nearest"
local limit=S.farm_maxdist or 2000
local maxDist=limit<2000 and limit or math.huge
local minRar=table.find(RARITY_ORDER,tostring(S.farm_minrar or""):lower())or 0
local now=os.clock()
local best,bestKey
for _,e in ipairs(eggs)do
local skipUntil=farmSkip[e]
if V2.alive(e)and not(skipUntil and skipUntil>now)then
local name=eggLabel(e)
local label=name:lower()
local idx,rname=V2.rarityInfo(V2.eggModel[e]or e,name)
local zsel,zeg=tonumber(S.farm_zone),V2.zoneOf(V2.eggModel[e]or e)
local zoneOk=not zsel or zeg==nil or zeg==zsel
local match=#filter==0 or V2.labelHas(label,filter)
local ignored=V2.labelHas(label,ignore)or(rname~="unknown"and V2.labelHas(rname:lower(),ignore))
local d=(e.Position-hrp.Position).Magnitude
if not ignored and zoneOk and d<=maxDist and idx>=minRar and not(mode=="Selected only"and not match)then
local key=d
if mode=="Selected first"then key=(match and 0 or 1e6)+d
elseif mode=="Highest rarity"then key=-idx*1e6+d end
if not bestKey or key<bestKey then best,bestKey=e,key end
end
end
end
return best
end

function V2.scanEggs(report)
local base=getBase(false)
if not base then
FarmInfo.eggState="no base"
if report then notify("Base not detected: "..tostring(FarmInfo.baseWhy),"warn",5)end
return nil,"Base not detected: "..tostring(FarmInfo.baseWhy)
end
local eggs,why=findEggs(base)
if why then
FarmInfo.eggState="ERROR: "..why
return nil,why
end
FarmInfo.eggs=#eggs
V2.trackEggs(eggs)
if#eggs==0 then
FarmInfo.catalog,FarmInfo.eggState="no eggs in base","NO EGGS IN BASE"
if report then notify("Egg Scanner: no eggs in your base","warn",4)end
return eggs
end
local counts,order={},{}
for _,e in ipairs(eggs)do
local l=eggLabel(e)
local _,rl=V2.rarityInfo(e,l)
if rl~="unknown"then l=l.." ["..rl.."]"end
if not counts[l]then counts[l]=0 order[#order+1]=l end
counts[l]+=1
end
local parts={}
for _,l in ipairs(order)do parts[#parts+1]=l.." x"..counts[l]end
FarmInfo.catalog=table.concat(parts,", ")
FarmInfo.eggState=#eggs.." egg(s) detected"
if report then notify("Eggs: "..FarmInfo.catalog,"info",6)end
return eggs
end

function V2.scanPets()
local list={}
for _,c in ipairs({Player:FindFirstChild("Backpack"),Player.Character})do
if c then
for _,t in ipairs(c:GetChildren())do
if t:IsA("Tool")and t.Name~="Bat"and not t.Name:lower():find("axe",1,true)then
local idx,rl=V2.rarityInfo(t,t.Name)
list[#list+1]={tool=t,name=t.Name,idx=idx,rarity=rl,held=c==Player.Character}
end
end
end
end
table.sort(list,function(a,b)
if a.idx~=b.idx then return a.idx>b.idx end
return a.name<b.name
end)
return list
end

local function watchAnimals(bag)
local seen=setmetatable({},{__mode="k"})
local ignoreUntil=0
local function onTool(t)
if not t:IsA("Tool")or seen[t]then return end
seen[t]=true
if os.clock()<ignoreUntil then return end
if t.Name=="Bat"or t.Name:lower():find("axe",1,true)then return end
local idx,rl=V2.rarityInfo(t,t.Name)
local ses=V2.session
FarmInfo.animals+=1
FarmInfo.lastAnimal=t.Name..(idx>0 and(" ["..rl.."]")or"")
ses.pets[#ses.pets+1]={at=os.date("%H:%M:%S"),name=t.Name,rarity=rl,idx=idx}
while#ses.pets>100 do table.remove(ses.pets,1)end
ses.petCounts[t.Name]=(ses.petCounts[t.Name]or 0)+1
ses.petTotal+=1
if idx>ses.bestIdx or ses.bestName=="none"then
ses.bestIdx,ses.bestName=idx,t.Name..(idx>0 and(" ("..rl..")")or"")
end
local isRare=idx>0 and idx>=V2.rareMin()
local fields={
{name="Pet",value=t.Name,inline=true},
{name="Rarity",value=idx>0 and rl or"not exposed by the game",inline=true},
}
if S.pet_alert then notify("New pet: "..t.Name..(idx>0 and(" ["..rl.."]")or""),isRare and"good"or"info",3)end
farmEvent("Animal collected",("**%s** appeared in your inventory"):format(t.Name),"good",fields,"pet")
if isRare then farmEvent("Rare pet obtained",("**%s** (%s)"):format(t.Name,rl),"warn",fields,"rare")end
end
local function hook(container,cb)
if not container then return end
for _,t in ipairs(container:GetChildren())do seen[t]=true end
cb.add(container.ChildAdded:Connect(onTool))
end
local bpBag=newBag()
bag.add(bpBag.clear)
local function hookBackpack()
bpBag.clear()
ignoreUntil=os.clock()+1.5
hook(Player:FindFirstChild("Backpack"),bpBag)
end
hookBackpack()
bag.add(Player.ChildAdded:Connect(function(c)if c.Name=="Backpack"then hookBackpack()end end))
hookCharacter(bag,function(char,cb)
ignoreUntil=os.clock()+1.5
hook(char,cb)
end)
end

V2.petRefs=0
function V2.petTrackStart()
V2.petRefs+=1
if V2.petRefs==1 then
V2.petBag=newBag()
watchAnimals(V2.petBag)
end
local released=false
return function()
if released then return end
released=true
V2.petRefs-=1
if V2.petRefs<=0 then
V2.petRefs=0
if V2.petBag then V2.petBag.clear()V2.petBag=nil end
end
end
end
Root.add(function()if V2.petBag then V2.petBag.clear()V2.petBag=nil end end)

local function stopWalk()
local h=getHum()
local r=h and h.RootPart
if h and r then h:MoveTo(r.Position)end
end

V2.eggModel=setmetatable({},{__mode="k"})
V2.fstate=V2.fstate or{}
function V2.setState(id,status,why)
local old=V2.fstate[id]
if old and old.status==status and old.why==why then return end
V2.fstate[id]={status=status,why=why,at=os.date("%H:%M:%S")}
print(("[CAZX][%s] %s%s"):format(status,id,why and(" :: "..tostring(why))or""))
end
function V2.alive(inst)return inst~=nil and inst:IsDescendantOf(workspace)end
function V2.inCharacter(inst)
local anc=inst
while anc and anc~=workspace do
if anc:IsA("Model")and Players:GetPlayerFromCharacter(anc)then return true end
anc=anc.Parent
end
return false
end
local function parseNum(s)
s=tostring(s):gsub(",",""):gsub("%s","")
local n,suf=s:match("^([%d%.]+)([KkMmBbTt]?)$")
n=tonumber(n)
if not n then return nil end
local mul={k=1e3,m=1e6,b=1e9,t=1e12}
return n*(mul[suf:lower()]or 1)
end
V2.parseNum=parseNum

local AXE_POWER={stone=1,wood=1,iron=15,golden=60,gold=60,diamond=250,strawberry=1000}
function V2.classifyTool(t)
if not(t and t:IsA("Tool"))then return nil end
if t:GetAttribute("Pet")or t:GetAttribute("Animal")or t:GetAttribute("IsPet")then return nil end
local n=t.Name:lower()
local why
if n:find("pickaxe",1,true)or n:find("pick axe",1,true)then why="name (pickaxe)"
elseif n:find("axe",1,true)or n:find("pick",1,true)then why="name (axe/pick)"end
for k,v in pairs(t:GetAttributes())do
local lk=k:lower()
if(lk:find("pick",1,true)and v==true)or((lk=="tooltype"or lk=="type"or lk=="category"or lk=="class")and tostring(v):lower():find("pick",1,true))then
why=why or("attribute "..k)
end
end
local tip=(t.ToolTip or""):lower()
if tip:find("pick",1,true)or tip:find("axe",1,true)then why=why or"tooltip"end
if V2.axeUsed==t then why=why or"used by you"end
if not why then return nil end
if n:find("bat",1,true)and not(n:find("axe",1,true))then return nil end
local score=1
for _,k in ipairs({"Power","Damage","Dmg","Strength","HitDamage"})do
local v=t:GetAttribute(k)
if type(v)=="number"then score=math.max(score,v)end
end
for key,p in pairs(AXE_POWER)do if n:find(key,1,true)then score=math.max(score,p)end end
return score,why
end
function V2.axeInfo()
local best,bs,bwhy,equipped
local char=Player.Character
for _,c in ipairs({char,Player:FindFirstChild("Backpack")})do
if c then
for _,t in ipairs(c:GetChildren())do
local sc,why=V2.classifyTool(t)
if sc then
local eq=(c==char)
local pref=(V2.axeUsed==t)and 1e12 or 0
local val=sc+pref
if S.farm_equipmode=="Keep equipped"then val=val+(eq and 1e9 or 0)end
if not bs or val>bs then best,bs,bwhy,equipped=t,val,why,eq end
end
end
end
end
return best,bwhy,equipped
end
function findAxe()local t=V2.axeInfo()return t end
V2.axeBag=V2.axeBag or newBag()
function V2.axeWatch()
V2.axeBag.clear()
local function hookTool(t)
if t:IsA("Tool")then
V2.axeBag.add(t.Activated:Connect(function()if V2.classifyTool(t)then V2.axeUsed=t end end))
end
end
local function hookContainer(c)
if not c then return end
for _,t in ipairs(c:GetChildren())do hookTool(t)end
V2.axeBag.add(c.ChildAdded:Connect(function(t)hookTool(t)V2.axeChanged=os.clock()end))
V2.axeBag.add(c.ChildRemoved:Connect(function()V2.axeChanged=os.clock()end))
end
hookContainer(Player:FindFirstChild("Backpack")or Player:WaitForChild("Backpack",5))
hookContainer(Player.Character)
V2.axeBag.add(Player.CharacterAdded:Connect(function(c)task.defer(function()hookContainer(c)hookContainer(Player:FindFirstChild("Backpack"))end)end))
end
Root.add(V2.axeBag.clear)
task.spawn(function()pcall(V2.axeWatch)end)

local HP_KEYS={"HP","Hp","Health","CurrentHP","CurHP","EggHP"}
function V2.eggHp(model)
if not model then return nil end
for _,o in ipairs({model,model.Parent})do
if o then
for _,k in ipairs(HP_KEYS)do
local v=o:GetAttribute(k)
if type(v)=="number"then return v,o:GetAttribute("MaxHP")or o:GetAttribute("MaxHealth")end
end
end
end
for _,c in ipairs(model:GetDescendants())do
if c:IsA("ValueBase")and table.find(HP_KEYS,c.Name)then
local ok,v=pcall(function()return c.Value end)
if ok and type(v)=="number"then return v end
elseif c:IsA("TextLabel")and c.Visible then
local a,b=c.Text:match("([%d%.,]+[KkMmBbTt]?)%s*/%s*([%d%.,]+[KkMmBbTt]?)")
if a then local x=parseNum(a)if x then return x,parseNum(b)end end
end
end
return nil
end
function V2.zoneOf(inst)
local o=inst
while o and o~=workspace do
for _,k in ipairs({"Zone","ZoneId","ZoneIndex"})do
local v=o:GetAttribute(k)
if type(v)=="number"then return v end
if type(v)=="string"and tonumber(v:match("%d+")or"")then return tonumber(v:match("%d+"))end
end
local n=o.Name:lower():match("zone%s*_?(%d+)")
if n then return tonumber(n)end
o=o.Parent
end
return nil
end

function findEggs(base)
local out,seen={},{}
local roots={workspace:FindFirstChild("WorldRuntime"),workspace:FindFirstChild("MapNew"),workspace:FindFirstChild("Build")}
local any,count=false,0
for ri,root in ipairs(roots)do
if root then
any=true
for _,o in ipairs(root:GetDescendants())do
count+=1
if count>12000 then break end
if(o:IsA("Model")or o:IsA("BasePart"))and o.Name:lower():find("egg",1,true)and not o.Name:lower():find("nest",1,true)then
local model=o:IsA("Model")and o or(o:FindFirstAncestorOfClass("Model")and o:FindFirstAncestorOfClass("Model").Name:lower():find("egg",1,true)and o:FindFirstAncestorOfClass("Model"))or o
if not seen[model]and not V2.inCharacter(model)then
local part=model:IsA("Model")and(model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart",true))or model
local mine=base and base~=workspace and base:IsA("Model")or base and base:IsA("Folder")
if part and not(mine and model:IsDescendantOf(base))and(ri==1 or V2.eggHp(model))then
seen[model]=true
V2.eggModel[part]=model
out[#out+1]=part
end
end
end
end
end
end
if not any then return out,"Workspace.WorldRuntime / MapNew not found (not the Break and Steal an Egg map?)"end
return out
end
function eggLabel(egg)
local model=V2.eggModel[egg]or egg.Parent
for _,k in ipairs({"EggName","EggType","Type","DisplayName"})do
local v=egg:GetAttribute(k)
if v==nil and model then v=model:GetAttribute(k)end
if type(v)=="string"and v~=""then return v end
end
return model and model.Name or"Egg"
end

function V2.carryState()
local char=Player.Character
for _,o in ipairs({Player,char})do
if o then
for k,v in pairs(o:GetAttributes())do
if k:lower():find("carr",1,true)then
if v==true or(type(v)=="number"and v~=0)or(type(v)=="string"and v~="")or typeof(v)=="Instance"then return true,"attribute "..k,"game"end
return false,"attribute "..k,"game"
end
end
end
end
if char then
for _,c in ipairs(char:GetChildren())do
if c:IsA("Model")then return true,"model "..c.Name.." on character","heuristic"end
if c:IsA("Tool")and not V2.classifyTool(c)and c.Name~="Bat"then return true,"tool "..c.Name,"heuristic"end
end
end
return false,"no carry signal","heuristic"
end
function V2.findPickups()
local out={}
local roots={workspace:FindFirstChild("WorldRuntime")or workspace}
for _,root in ipairs(roots)do
for _,pp in ipairs(root:GetDescendants())do
if pp:IsA("ProximityPrompt")and pp.Enabled then
local txt=(pp.ActionText.." "..pp.ObjectText.." "..pp.Name):lower()
if txt:find("pick",1,true)or txt:find("grab",1,true)or txt:find("carry",1,true)then
local model=pp:FindFirstAncestorOfClass("Model")or pp.Parent
local isChar,anc=false,model
while anc and anc~=workspace do
if anc:IsA("Model")and Players:GetPlayerFromCharacter(anc)then isChar=true break end
anc=anc.Parent
end
local part=pp.Parent and(pp.Parent:IsA("BasePart")and pp.Parent or pp.Parent:FindFirstChildWhichIsA("BasePart",true))
if model and part and not isChar then
local ownerOther=false
for _,k in ipairs(OWNER_KEYS)do
local v=model:GetAttribute(k)
if v~=nil and not isMine(v)and tostring(v)~=""and tostring(v)~="0"then ownerOther=true end
end
if not ownerOther then out[#out+1]={prompt=pp,model=model,part=part}end
end
end
end
end
end
return out
end
function V2.incomeOf(model)
for _,o in ipairs({model,model.Parent})do
for _,k in ipairs({"Income","IncomePerSecond","CashPerSecond","Cps","Earn","Value"})do
local v=o and o:GetAttribute(k)
if type(v)=="number"then return v end
end
end
return nil
end
function V2.doPickup(prompt)
if typeof(fireproximityprompt)=="function"then return pcall(fireproximityprompt,prompt)end
local ok,err=pcall(function()
prompt:InputHoldBegin()
task.wait(math.max(prompt.HoldDuration,.05)+.1)
prompt:InputHoldEnd()
end)
return ok,err
end

local function textOwnedByMe(inst)
for _,d in ipairs(inst:GetDescendants())do
if d:IsA("TextLabel")and d.Text~=""then
local t=d.Text:lower()
if t:find(Player.Name:lower(),1,true)or t:find(Player.DisplayName:lower(),1,true)then return true,"sign text"end
end
end
return false
end
V2.spawnAnchor=nil
function V2.recordSpawn(char)
task.spawn(function()
local hrp=char:WaitForChild("HumanoidRootPart",8)
if not hrp then return end
task.wait(.8)
if not hrp.Parent then return end
if not V2.spawnPos then V2.spawnPos=hrp.Position end
end)
end
optional("Spawn recorder hook",function()hookCharacter(Root,function(char)V2.recordSpawn(char)end)end)
V2.scanBase=function()
for _,k in ipairs({"Plot","PlotId","Base","BaseId","PlotName"})do
local v=Player:GetAttribute(k)
if v~=nil then
for _,root in ipairs({workspace:FindFirstChild("WorldRuntime"),workspace:FindFirstChild("MapNew"),workspace})do
local f=root and(root:FindFirstChild(tostring(v),true))
if f and(f:IsA("Model")or f:IsA("Folder"))then return f,"Player attribute "..k end
end
end
end
local queue,head,seen={{workspace,0}},1,0
while queue[head]do
local cur,depth=queue[head][1],queue[head][2]
head+=1
for _,c in ipairs(cur:GetChildren())do
seen+=1
if seen>6000 then break end
if c:IsA("Model")or c:IsA("Folder")or c:IsA("BasePart")then
local ok,why=ownedByMe(c)
if ok then return c,why end
local nm=c.Name:lower()
if(nm:find("plot",1,true)or nm:find("base",1,true)or nm:find("pen",1,true))and not c:IsA("BasePart")then
local ok2,why2=textOwnedByMe(c)
if ok2 then return c,why2 end
end
if depth<4 and not c:IsA("BasePart")and c~=Player.Character and not V2.inCharacter(c)then queue[#queue+1]={c,depth+1}end
end
end
end
local rl=Player.RespawnLocation
if rl and rl.Parent then return rl,"Player.RespawnLocation"end
if V2.spawnPos then
if not(V2.spawnAnchor and V2.spawnAnchor.Parent)then
local a=Instance.new("Part")
a.Name,a.Anchored,a.CanCollide,a.CanQuery,a.CanTouch,a.Transparency,a.Size="CazxBaseAnchor",true,false,false,false,1,Vector3.new(1,1,1)
a.Position=V2.spawnPos
a.Parent=workspace
V2.spawnAnchor=Root.add(a)
end
return V2.spawnAnchor,"first spawn position (no ownership tag found on any plot)"
end
return nil,"no plot tagged with your UserId/Name, no RespawnLocation and no spawn position recorded yet"
end

V2.swing={floor=.7,probeAt=0,probing=false,probeUntil=0,hits=0,lastHp=nil,accepted=0,window=0,note="idle",effMult=1}
function V2.swingInterval()
local sw=V2.swing
local mult=math.clamp(S.swing_mult or 1,1,100)
local want=(S.break_interval or.7)/mult
local eff=math.max(want,sw.floor)
if sw.probing then eff=math.max(want,sw.floor/3)end
sw.effMult=.7/math.max(eff,.05)
return math.max(eff,.05)
end
function V2.swingNote()
local sw=V2.swing
return("requested %dx | effective %.1fx (%.2fs/hit) | %s"):format(S.swing_mult or 1,sw.effMult,sw.floor,sw.note)
end

function V2.swingFeedback(model)
local sw=V2.swing
local hp=V2.eggHp(model)
if not hp then sw.note="HP unreadable: cannot verify hits, staying at server cap"return end
if sw.lastHp and hp<sw.lastHp then sw.accepted+=1 end
sw.lastHp=hp
local now=os.clock()
if sw.window==0 then sw.window=now end
if sw.probing and now>=sw.probeUntil then
local rate=sw.accepted/math.max(now-sw.window,.1)
local base=1/sw.floor
if rate>base*1.3 then
sw.floor=math.max(sw.floor/2,.05)
sw.note=("server accepted %.1f hits/s, cap lowered"):format(rate)
else
sw.note=("SERVER-LIMITED (probe %.1f hits/s)"):format(rate)
end
sw.probing,sw.accepted,sw.window,sw.probeAt=false,0,0,now+25
elseif not sw.probing and(S.swing_mult or 1)>1 and now>=sw.probeAt and sw.floor>.06 then
sw.probing,sw.probeUntil,sw.accepted,sw.window=true,now+4,0,now
end
end
function V2.swingTool(tool,model)
local ok,err=pcall(function()tool:Activate()end)
if ok then V2.swing.hits+=1 pcall(V2.swingFeedback,model)end
return ok,err
end

V2.pk={state="IDLE",status="OFF",target=nil,delivered=0,failed=0,unverified=0,since=0,hint=nil}
function V2.pkTick(mode)
local pk=V2.pk
local char,hum=Player.Character,getHum()
local hrp=char and char:FindFirstChild("HumanoidRootPart")
if not hum or hum.Health<=0 or not hrp then
if pk.state~="IDLE"then pk.failed+=1 pk.status="RESPAWNING (target dropped)"end
pk.state,pk.target="IDLE",nil
return
end
if FarmInfo.paused then pk.status="PAUSED"return end
local now=os.clock()
local base=getBase(false)or getBase(true)
local bpos=base and instPos(base)
local carrying,cwhy,conf=V2.carryState()
if pk.state=="IDLE"or pk.state=="SCAN"then
if carrying and conf=="game"then pk.state,pk.since="CARRY",now return end
pk.state="SCAN"
local filt,minRar=V2.parseList(S.steal_species),table.find(RARITY_ORDER,tostring(S.steal_minrar or""):lower())or 0
local minInc=tonumber(S.steal_minincome or"")or 0
local best,bk
for _,c in ipairs(V2.findPickups())do
local label=c.model.Name
local d=(c.part.Position-hrp.Position).Magnitude
local idx=V2.rarityInfo(c.model,label)
local inc=V2.incomeOf(c.model)
local near=mode=="hint"and pk.hint and(c.part.Position-pk.hint.pos).Magnitude<=45
local okMode=mode~="hint"or near
local okSpecies=#filt==0 or V2.labelHas(label:lower(),filt)
local okRar=idx>=minRar or idx==0 and minRar==0
local okInc=minInc<=0 or(inc~=nil and inc>=minInc)
local guarded=false
if S.steal_guard then
for _,g in ipairs(workspace:GetDescendants())do
if g:IsA("Model")and g~=c.model and(g.Name:lower():find("guard",1,true)or g.Name:lower():find("protector",1,true))then
local gp=g.PrimaryPart or g:FindFirstChildWhichIsA("BasePart",true)
if gp and(gp.Position-c.part.Position).Magnitude<25 then guarded=true break end
end
end
end
if okMode and okSpecies and okRar and okInc and not guarded and not(farmSkip[c.model]and farmSkip[c.model]>now)then
local key=d
local prio=S.steal_priority or"Nearest"
if prio=="Highest rarity"then key=-idx*1e6+d elseif prio=="Highest income"then key=-(inc or 0)*1e3+d end
if not bk or key<bk then best,bk=c,key end
end
end
if not best then pk.status=mode=="hint"and"WAITING (no animal near the broken egg)"or"SCANNING (no valid animal)"return end
pk.target,pk.state,pk.since=best,"GOTO",now
pk.status="TARGET "..best.model.Name
return
end
local t=pk.target
if pk.state=="GOTO"then
if not t or not V2.alive(t.part)or not t.prompt.Enabled then pk.state,pk.target,pk.status="SCAN",nil,"TARGET LOST (invalid)"return end
local dist=(t.part.Position-hrp.Position).Magnitude
local reach=math.max((t.prompt.MaxActivationDistance or 10)-1.5,3)
if dist>reach then
pk.status=("WALKING TO %s (%d studs)"):format(t.model.Name,math.floor(dist))
V2.mv(hum,t.part.Position)
if now-pk.since>40 then farmSkip[t.model]=now+30 pk.state,pk.target,pk.failed="SCAN",nil,pk.failed+1 notify("Auto Steal: could not reach "..t.model.Name,"bad",3)end
return
end
pk.state,pk.since,pk.status="PICKUP",now,"PICKING UP "..t.model.Name
return
end
if pk.state=="PICKUP"then
if not t or not V2.alive(t.part)then pk.state,pk.target="SCAN",nil return end
local ok,err=V2.doPickup(t.prompt)
if not ok then pk.failed+=1 farmSkip[t.model]=now+30 pk.state,pk.target="SCAN",nil notify("Auto Steal: pickup action failed: "..tostring(err),"bad",4)return end
task.wait(.4)
local c2,why2,conf2=V2.carryState()
if c2 then pk.state,pk.since,pk.how="CARRY",now,conf2 pk.status="CARRYING "..t.model.Name.." ("..why2..")"return end
if now-pk.since>6 then
farmSkip[t.model]=now+30
pk.failed+=1
pk.state,pk.target="SCAN",nil
notify("Auto Steal: pickup not confirmed by the game for "..t.model.Name,"bad",4)
end
return
end
if pk.state=="CARRY"then
if not bpos then pk.status="NO BASE (cannot deliver)"return end
local dist=(bpos-hrp.Position).Magnitude
local c3,why3,conf3=V2.carryState()
if not c3 and now-pk.since>1.5 then
if dist<=40 then
pk.delivered+=1
if conf3=="game"or conf=="game"then notify("Auto Steal: delivered ("..why3..")","good",3)
else pk.unverified+=1 notify("Auto Steal: delivered? (carry signal gone near base, game gave no explicit state)","warn",4)end
FarmInfo.animals+=1
pk.status="DELIVERED"
else
pk.failed+=1
pk.status="LOST (dropped "..math.floor(dist).." studs from base)"
notify("Auto Steal: animal lost before reaching base","bad",4)
end
pk.state,pk.target="IDLE",nil
return
end
pk.status=("DELIVERING (%d studs to base)"):format(math.floor(dist))
V2.mv(hum,bpos)
if now-pk.since>45 then pk.failed+=1 pk.state,pk.target="IDLE",nil notify("Auto Steal: delivery timed out","bad",4)end
end
end

phaseMark("game info and scheduler")
V2.game={name=nil,status="Loading",placeId=game.PlaceId,universeId=game.GameId}
function V2.refreshGame()
V2.game.status,V2.game.placeId,V2.game.universeId="Loading",game.PlaceId,game.GameId
task.spawn(function()
local ok,info=pcall(function()return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)end)
if ok and type(info)=="table"and type(info.Name)=="string"and info.Name~=""and info.Name:upper()~="UGC"then
V2.game.name,V2.game.status=info.Name,"OK"
else
V2.game.name,V2.game.status=nil,"Unknown"
end
V2.setState("game_info",V2.game.status=="OK"and"SUCCESS"or"FAILED",V2.game.name or"GetProductInfo gave no usable name")
end)
end
function V2.gameName()
if V2.game.name then return V2.game.name end
return V2.game.status=="Loading"and"Loading..."or"Unknown"
end
optional("Game info refresh",V2.refreshGame)
optional("Game info watcher",function()loop(15,function()if V2.game.placeId~=game.PlaceId then V2.refreshGame()end end)end)

local farmLoop,farmBag
def("Farm","farm_auto",{kind="toggle",name="Auto Farm [TESTING]",desc="Walks to eggs in YOUR base, equips the axe and hits them. Skips unreachable eggs and keeps running after respawn.",fn=function(on)
if farmLoop then farmLoop.alive=false farmLoop=nil end
if farmBag then farmBag.clear()farmBag=nil end
V2.setState("farm_auto",on and"STARTING"or"SKIPPED",(not on)and"turned off"or nil)
FarmInfo.carrying=false
if not on then
FarmInfo.status,FarmInfo.target="OFF","none"
pcall(stopWalk)
if FarmInfo.broken>0 or FarmInfo.animals>0 then farmEvent("Farm session ended","Auto Farm was turned off","info",farmFields(),"session")end
return
end
if S.farm_break then FarmInfo.status="OFF"return false,"Turn Auto Break off first: both would hit the same eggs"end
if S.steal_auto then return false,"Turn Auto Steal off first: use Auto Collect Animal with Auto Farm instead"end
if not getHum()then FarmInfo.status="ERROR: no character"return false,"Character is not ready (respawning?)"end
if not getBase(true)then FarmInfo.status="ERROR: base not detected"return false,"Base not detected: "..tostring(FarmInfo.baseWhy)end
if not findAxe()then FarmInfo.status="ERROR: no axe"return false,"No pickaxe detected (checked name, attributes, tooltip and what you used)"end
FarmInfo.broken,FarmInfo.animals,FarmInfo.t0,FarmInfo.status=0,0,os.clock(),"STARTING"
farmBag=newBag()
farmBag.add(V2.petTrackStart())
local st={cache=nil,cacheAt=0,hits=0,fails=0,label="Egg"}
farmLoop=loop(.15,function()
local char=Player.Character
local hum=getHum()
local hrp=char and char:FindFirstChild("HumanoidRootPart")
if not hum or hum.Health<=0 or not hrp then
FarmInfo.status,FarmInfo.target,st.target="RESPAWNING","none",nil
return
end
if FarmInfo.paused then
if FarmInfo.status~="PAUSED"then pcall(stopWalk)end
FarmInfo.status="PAUSED"
return
end
if FarmInfo.carrying then FarmInfo.status="CARRYING TO BASE"return end
local now=os.clock()
local b=getBase(false)
if not b then
b=getBase(true)
if not b then FarmInfo.status="NO BASE (retrying)"return end
end
if not st.cache or now-st.cacheAt>1.5 then
local eggs,why=findEggs(b)
if why then FarmInfo.status="ERROR: "..why farmFail(why)return end
st.cache,st.cacheAt=eggs,now
FarmInfo.eggs=#eggs
V2.trackEggs(eggs)
end
if st.target then
local gone=not V2.alive(st.target)
if gone or(farmSkip[st.target]and farmSkip[st.target]>now)then
if gone and st.hits>0 then
FarmInfo.broken+=1
V2.pk.hint={pos=st.target.Position,untilT=now+40}
local hist=V2.session.history
hist[#hist+1]={at=os.date("%H:%M:%S"),label=st.label,hits=st.hits,rarity=st.rname or"unknown"}
while#hist>60 do table.remove(hist,1)end
farmEvent("Egg broken",("**%s** left your base after %d hit(s)"):format(st.label,st.hits),"good",
{{name="Egg",value=tostring(st.label),inline=true},{name="Rarity",value=tostring(st.rname or"unknown"),inline=true}},"egg")
end
st.target=nil
end
end
if not st.target then
local e=pickTarget(st.cache,hrp)
if not e then FarmInfo.status,FarmInfo.target="WAITING (no valid egg)","none"return end
st.target,st.label,st.hits,st.fails,st.since=e,eggLabel(e),0,0,now
st.lastDist,st.progressAt,st.lastHit=nil,now,0
st.kind,st.obj=eggInteraction(e)
st.ridx,st.rname=V2.rarityInfo(V2.eggModel[e]or e,st.label)
end
FarmInfo.target=st.label
local e=st.target
local dist=(e.Position-hrp.Position).Magnitude
if not st.lastDist or dist<st.lastDist-.5 then st.lastDist,st.progressAt=dist,now end
local kind,obj=st.kind,st.obj
local reach=S.break_reach or 9
if kind=="prompt"and obj and obj.Parent then reach=math.max((obj.MaxActivationDistance or 10)-2,4)end
if dist>reach then
FarmInfo.status=("WALKING TO %s (%d studs)"):format(st.label,math.floor(dist))
V2.mv(hum,e.Position)
if now-st.progressAt>5 then
farmSkip[e]=now+20
farmFail("could not reach "..st.label..", skipping it for 20s")
st.target=nil
end
return
end
if now-st.since>90 then
farmSkip[e]=now+30
farmFail(st.label.." did not break within 90s ("..st.hits.." hits), skipping it")
st.target=nil
return
end
if now-st.lastHit<V2.swingInterval()then return end
st.lastHit=now
local axe=findAxe()
if not axe then FarmInfo.status="ERROR: axe missing"farmFail("axe Tool not found in Backpack/Character")return end
if axe.Parent~=char then
hum:EquipTool(axe)
FarmInfo.status="EQUIPPING AXE"
return
end
FarmInfo.status="BREAKING "..st.label
local ok,err
if kind=="prompt"and obj and typeof(fireproximityprompt)=="function"then ok,err=pcall(fireproximityprompt,obj)
elseif kind=="click"and obj and typeof(fireclickdetector)=="function"then ok,err=pcall(fireclickdetector,obj)
else
pcall(function()hrp.CFrame=CFrame.lookAt(hrp.Position,Vector3.new(e.Position.X,hrp.Position.Y,e.Position.Z))end)
ok,err=V2.swingTool(axe,V2.eggModel[e]or e)
end
if ok then
st.hits+=1
st.fails=0
else
st.fails+=1
farmErr(err)
if st.fails>=5 then
farmSkip[e]=now+30
farmFail("hit action failed 5 times: "..tostring(err))
st.target=nil
end
end
end)
end})

local carryLoop
def("Farm","farm_carry",{kind="toggle",name="Auto Carry [TESTING]",desc="Walks to your base while you hold an animal Tool (any Tool except the axe), then lets Auto Farm continue.",fn=function(on)
if carryLoop then carryLoop.alive=false carryLoop=nil end
FarmInfo.carrying=false
if not on then pcall(stopWalk)return end
if not getBase(true)then return false,"Base not detected: "..tostring(FarmInfo.baseWhy)end
local delivered
carryLoop=loop(.4,function()
if S.steal_auto or S.farm_collect then return end
local char=Player.Character
local hum=getHum()
local hrp=char and char:FindFirstChild("HumanoidRootPart")
if not hum or hum.Health<=0 or not hrp then FarmInfo.carrying=false return end
if FarmInfo.paused then return end
local key=heldKey()
if key==""then FarmInfo.carrying,delivered=false,nil return end
local b=getBase(false)
local p=b and instPos(b)
if not p or key==delivered then FarmInfo.carrying=false return end
if(p-hrp.Position).Magnitude>20 then
FarmInfo.carrying=true
V2.mv(hum,p)
else
FarmInfo.carrying,delivered=false,key
end
end)
end})

def("Farm","farm_eggscan",{kind="button",name="Egg Scanner",desc="Lists the egg types in your base with rarity (rarity only when the game exposes it).",run=function()
local eggs,why=V2.scanEggs(true)
if not eggs then return false,why end
end})
def("Farm","farm_filter",{kind="input",name="Egg Selector",desc="Comma-separated names to target (matches the egg type text). Empty means any egg.",placeholder="e.g. golden, dragon",default="",
validate=function(v)return#v<=120 end})
def("Farm","farm_priority",{kind="dropdown",name="Best Egg Priority",desc="Nearest | Selected first | Selected only | Highest rarity (uses a Rarity attribute if the egg exposes one, else distance).",
options={"Nearest","Selected first","Selected only","Highest rarity"},default="Nearest"})

def("Farm","farm_stop",{kind="button",name="Stop Farm",desc="Turns off Auto Farm, Auto Break, Auto Carry and Place Best Pets.",run=function()
for _,id in ipairs({"farm_auto","farm_break","farm_carry","auto_best","farm_pause"})do
if S[id]then setValue(id,false)end
end
end})

def("Farm","farm_equipmode",{kind="dropdown",name="Pickaxe Equip Mode",desc="Auto equip best: equips the strongest pickaxe found (attribute/name power). Keep equipped: uses what you hold.",
options={"Auto equip best","Keep equipped"},default="Auto equip best"})
def("Farm","farm_zone",{kind="dropdown",name="Zone Selection",desc="Only target eggs whose Zone (attribute or 'ZoneN' name in the world tree) matches. Eggs with no readable zone are kept under Any.",
options={"Any","1","2","3","4","5","6","7","8","9","10"},default="Any"})
def("Farm","break_reach",{kind="slider",name="Hit Reach (studs)",desc="How close you stand to an egg before swinging. The server decides the real hit range; eggs that never lose HP get skipped.",min=4,max=30,step=1,default=10})
def("Farm","break_interval",{kind="slider",name="Swing Interval (s)",desc="Base time per swing at 1x. Real rate = this / Hit Speed, never faster than the server accepts (measured).",min=.05,max=1,step=.05,default=.7})
local swingNoteAt=0
local function swingReport(force)
local now=os.clock()
if not force and now-swingNoteAt<1.2 then return end
swingNoteAt=now
notify("Swing: "..V2.swingNote(),"info",4)
end
def("Farm","swing_mult",{kind="slider",name="Pickaxe Hit Speed (x)",desc="1x-100x requested swing speed. The game enforces ~0.7s per hit on the server; this hub probes in small steps and only goes faster if hits (egg HP drops) are really accepted. Real value: Swing Status.",
min=1,max=100,step=1,default=1,fn=function()swingReport(false)end})
def("Farm","swing_preset",{kind="dropdown",name="Hit Speed Preset",desc="Sets Pickaxe Hit Speed to 1x, 5x, 10x, 25x, 50x or 100x.",options={"1x","5x","10x","25x","50x","100x"},default="1x",
fn=function(v)local n=tonumber(tostring(v):match("%d+"))if n then setValue("swing_mult",n,true)swingReport(true)end end})
def("Farm","swing_status",{kind="button",name="Swing Status",desc="Shows requested vs effective swing speed and swings sent.",run=function()
notify(("Swing: %s | swings sent %d"):format(V2.swingNote(),V2.swing.hits),"info",6)
end})
def("Farm","pickaxe_info",{kind="button",name="Pickaxe Detection",desc="Reports the pickaxe the hub will use, why it matched, and whether it is equipped.",run=function()
local t,why,eq=V2.axeInfo()
if not t then V2.setState("pickaxe","FAILED","no pickaxe-like Tool in Backpack/Character")return false,"No pickaxe found (checked name, attributes, tooltip, usage)"end
V2.setState("pickaxe","SUCCESS",t.Name.." via "..why)
notify(("Pickaxe: %s | matched by %s | %s%s"):format(t.Name,why,eq and"equipped"or"in backpack",V2.axeUsed==t and" | you used it"or""),"good",5)
end})

local breakH,breakSt
def("Farm","farm_break",{kind="toggle",name="Auto Break",desc="Swings your pickaxe at the nearest reachable egg (Zone/priority/filters apply). Does not walk; use Auto Farm for that. Verifies damage by reading egg HP.",
fn=function(on)
if breakH then breakH.alive=false breakH=nil end
FarmInfo.breakState="OFF"
if not on then V2.setState("farm_break","SKIPPED","turned off")return end
if S.farm_auto then return false,"Turn Auto Farm off first: both would hit the same eggs"end
if not V2.axeInfo()then FarmInfo.breakState="NO PICKAXE"V2.setState("farm_break","FAILED","no pickaxe")return false,"No pickaxe detected in Backpack/Character"end
V2.setState("farm_break","STARTING")
breakSt={target=nil,hits=0,flat=0,lastHp=nil,cache=nil,cacheAt=0}
breakH=loop(.1,function(h)
local char,hum=Player.Character,getHum()
local hrp=char and char:FindFirstChild("HumanoidRootPart")
if not hum or hum.Health<=0 or not hrp then FarmInfo.breakState="RESPAWNING"breakSt.target=nil return end
if FarmInfo.paused then FarmInfo.breakState="PAUSED"return end
local tool,_,eq=V2.axeInfo()
if not tool then FarmInfo.breakState="NO PICKAXE"return end
if not eq then
if S.farm_equipmode=="Keep equipped"then FarmInfo.breakState="PICKAXE NOT EQUIPPED"return end
hum:EquipTool(tool)FarmInfo.breakState="EQUIPPING "..tool.Name h.interval=.3 return
end
local now,st=os.clock(),breakSt
if st.target and not V2.alive(st.target)then
if st.hits>0 then
FarmInfo.broken+=1
V2.pk.hint={pos=st.lastPos or hrp.Position,untilT=now+40}
FarmInfo.breakState="BROKEN ("..tostring(st.label)..")"
V2.setState("farm_break","SUCCESS","egg broken: "..tostring(st.label))
end
st.target=nil
end
if not st.target then
if not st.cache or now-st.cacheAt>1 then st.cache,st.cacheAt=findEggs(nil),now FarmInfo.eggs=#st.cache end
local reach,list=S.break_reach or 10,{}
for _,e in ipairs(st.cache)do
if V2.alive(e)and(e.Position-hrp.Position).Magnitude<=reach then list[#list+1]=e end
end
local e=pickTarget(list,hrp)
if not e then FarmInfo.breakState=#st.cache==0 and"NO EGGS FOUND"or"NO EGG IN REACH"h.interval=.4 return end
st.target,st.hits,st.flat,st.lastHp,st.label=e,0,0,nil,eggLabel(e)
V2.swing.lastHp=nil
end
local e=st.target
st.lastPos=e.Position
local model=V2.eggModel[e]or e
if(e.Position-hrp.Position).Magnitude>(S.break_reach or 10)+2 then st.target=nil return end
pcall(function()hrp.CFrame=CFrame.lookAt(hrp.Position,Vector3.new(e.Position.X,hrp.Position.Y,e.Position.Z))end)
local hp0=V2.eggHp(model)
local ok,err=V2.swingTool(tool,model)
if not ok then farmErr(err)FarmInfo.breakState="ERROR: swing failed"return end
st.hits+=1
local hp1=V2.eggHp(model)
if hp0 and hp1 and hp1>=hp0 then st.flat+=1 else st.flat=0 end
FarmInfo.breakState=("BREAKING %s (%d hits%s)"):format(st.label,st.hits,hp1 and(", HP "..math.floor(hp1))or", HP unreadable")
if st.flat>=14 then
farmSkip[e]=now+30
notify("Auto Break: "..st.label.." takes no damage (out of range or too strong), skipping 30s","warn",4)
V2.setState("farm_break","RUNNING","skipped egg without damage")
st.target=nil
end
h.interval=V2.swingInterval()
end)
V2.setState("farm_break","RUNNING")
end})
def("Farm","break_skip",{kind="button",name="Skip Current Egg",desc="Skips the egg Auto Break is hitting for 2 minutes.",run=function()
if not(breakSt and breakSt.target)then return false,"No current target"end
farmSkip[breakSt.target]=os.clock()+120
breakSt.target=nil
end})
def("Farm","break_status",{kind="button",name="Break Status",desc="Reports Auto Break status, swings and eggs broken.",run=function()
notify(("Break: %s | eggs seen %d | broken %d | %s"):format(FarmInfo.breakState,FarmInfo.eggs,FarmInfo.broken,V2.swingNote()),"info",6)
end})

local pkH
local function pkSync()
local want=S.steal_auto or S.farm_collect
if want and not pkH then
V2.pk.state,V2.pk.status="IDLE","STARTING"
pkH=loop(.25,function()
local pk=V2.pk
if S.steal_auto then V2.pkTick("full")
elseif pk.state~="IDLE"or(pk.hint and os.clock()<pk.hint.untilT)then V2.pkTick("hint")
else pk.status="WAITING (break an egg first)"end
FarmInfo.carrying=(pk.state=="GOTO"or pk.state=="PICKUP"or pk.state=="CARRY")
end)
V2.setState("steal","RUNNING")
elseif not want and pkH then
pkH.alive=false pkH=nil
V2.pk.state,V2.pk.target,V2.pk.status="IDLE",nil,"OFF"
FarmInfo.carrying=false
pcall(stopWalk)
V2.setState("steal","SKIPPED","turned off")
end
end
def("Farm","farm_collect",{kind="toggle",name="Auto Collect Animal",desc="After an egg breaks, picks up the animal that appeared near it and carries it to your base. Uses the same pickup system as Auto Steal.",
fn=function(on)
if on and(S.carry or S.farm_carry)then return false,"Turn the old Auto Carry off first"end
task.defer(pkSync)
end})
def("Automation","steal_auto",{kind="toggle",name="Auto Steal",desc="Pick up animals revealed in the zones (ProximityPrompt), carry them to your own base and confirm delivery from the game's carry state. Filters below apply. Not used on other players' pets.",
fn=function(on)
if on and S.farm_carry then return false,"Turn the old Auto Carry off first"end
task.defer(pkSync)
end})
def("Automation","steal_species",{kind="input",name="Steal: Animal Names",desc="Comma-separated animal names to take. Empty means any animal.",placeholder="e.g. lion, wolf",default="",validate=function(v)return#v<=120 end})
def("Automation","steal_minrar",{kind="dropdown",name="Steal: Rarity Filter",desc="Minimum rarity (works when the animal exposes a Rarity attribute/value or a rarity word in its name).",options={"Any",table.unpack(RARITY_ORDER)},default="Any"})
def("Automation","steal_minincome",{kind="input",name="Steal: Minimum Income",desc="Minimum income per second (only when the animal exposes Income/CashPerSecond). Empty = no minimum.",placeholder="e.g. 500",default="",validate=function(v)return v==""or tonumber(v)~=nil end})
def("Automation","steal_priority",{kind="dropdown",name="Steal: Priority",desc="Nearest | Highest rarity | Highest income (income needs readable data).",options={"Nearest","Highest rarity","Highest income"},default="Nearest"})
def("Automation","steal_guard",{kind="toggle",name="Steal: Guard Safety",desc="Skips animals with a guard/protector model within 25 studs (name heuristic)."})
def("Automation","steal_status",{kind="button",name="Steal Status",desc="Shows the pickup state, delivered / unverified / failed counts.",run=function()
local pk=V2.pk
notify(("Steal: %s [%s] | delivered %d (unverified %d) | failed %d"):format(pk.status,pk.state,pk.delivered,pk.unverified,pk.failed),"info",6)
end})

na("Farm","farm_diamond","Auto Collect Diamond","Collect Diamonds produced by breaking eggs.",
"Not verified: public docs list Cash and Speed as the economy and a 'Diamond Pickaxe' tool, but no Diamond pickup. Use Diamond Scan to see what exists in your server, then it can be integrated.","NEEDS INTEGRATION")
def("Farm","farm_diamondscan",{kind="button",name="Diamond Scan",desc="Looks for anything named Diamond/Gem in your stats, attributes, Backpack and the world, and reports it.",run=function()
local found={}
local ls=Player:FindFirstChild("leaderstats")
if ls then for _,v in ipairs(ls:GetChildren())do if v.Name:lower():find("diamond")or v.Name:lower():find("gem")then found[#found+1]="leaderstat "..v.Name end end end
for k in pairs(Player:GetAttributes())do if k:lower():find("diamond")or k:lower():find("gem")then found[#found+1]="attribute "..k end end
local n=0
for _,root in ipairs({workspace:FindFirstChild("WorldRuntime"),Player:FindFirstChild("Backpack")})do
if root then for _,o in ipairs(root:GetDescendants())do
local nm=o.Name:lower()
if(nm:find("diamond")or nm:find("gem"))and not(o:IsA("Tool")and V2.classifyTool(o))then n+=1 if n<=3 then found[#found+1]=o.ClassName.." "..o.Name end end
end end
end
if#found==0 then V2.setState("diamond","NEEDS INTEGRATION","no Diamond object/stat found")notify("Diamond Scan: nothing found in stats, attributes or the world. No Diamond collectible exists to automate here.","warn",6)return end
V2.setState("diamond","NEEDS INTEGRATION",table.concat(found,"; "))
notify("Diamond Scan found: "..table.concat(found,"; "),"info",7)
end})
def("Farm","diag_features",{kind="button",name="Feature Diagnostics",desc="Prints every feature state (STARTING/RUNNING/SUCCESS/FAILED/SKIPPED/NEEDS INTEGRATION) to the console.",run=function()
local n=0
for id,st in pairs(V2.fstate)do n+=1 print(("[CAZX][DIAG] %s = %s (%s) @%s"):format(id,st.status,tostring(st.why),st.at))end
notify(n.." feature state(s) printed to the console (F9)","info",4)
end})

do
local scanH
def("Farm","farm_autoscan",{kind="toggle",name="Auto Egg Scanner",desc="Re-scans your base every 2s: egg count, types with rarity, respawned and vanished eggs (read-only).",fn=function(on)
if scanH then scanH.alive=false scanH=nil end
if not on then return end
scanH=loop(2,function()
if FarmInfo.scanBackoff and os.clock()<FarmInfo.scanBackoff then return end
local eggs=V2.scanEggs(false)
FarmInfo.scanBackoff=(not eggs)and(os.clock()+8)or nil
end)
end})
end
def("Farm","farm_maxdist",{kind="slider",name="Egg Distance Limit",desc="Ignore eggs farther than this many studs. The maximum means no limit.",min=50,max=2000,step=50,default=2000})
def("Farm","farm_minrar",{kind="dropdown",name="Egg Rarity Filter",desc="Only target eggs at or above this rarity. Works only if the egg exposes a Rarity attribute/value or a rarity word in its name; otherwise those eggs are skipped while a filter is set.",
options={"Any",table.unpack(RARITY_ORDER)},default="Any"})
def("Farm","farm_ignore",{kind="input",name="Ignore Eggs",desc="Comma-separated names or rarities that are never targeted.",placeholder="e.g. common, basic",default="",
validate=function(v)return#v<=120 end})
def("Farm","farm_selectall",{kind="button",name="Select All Eggs",desc="Clears selector, ignore list, rarity filter and distance limit so every egg is a valid target.",run=function()
setValue("farm_filter","",true)setValue("farm_ignore","",true)setValue("farm_minrar","Any",true)
setValue("farm_maxdist",2000,true)setValue("farm_priority","Nearest",true)
notify("All eggs selected (filters cleared)","good",2.5)
end})
def("Farm","farm_pause",{kind="toggle",name="Pause Farm",desc="Pauses Auto Farm and Auto Carry without losing statistics. Turn it off to resume.",fn=function(on)
FarmInfo.paused=on
if on then pcall(stopWalk)end
end})
def("Farm","farm_history",{kind="button",name="Egg Collection History",desc="Shows the last eggs you broke this session.",run=function()
local h=V2.session.history
if#h==0 then return false,"No eggs broken yet this session"end
local parts={}
for i=#h,math.max(1,#h-4),-1 do parts[#parts+1]=("%s %s x%d"):format(h[i].at,h[i].label,h[i].hits)end
notify(#h.." egg(s): "..table.concat(parts," | "),"info",8)
end})
def("Farm","pet_scan",{kind="button",name="Pet Scanner",desc="Lists animal Tools in your Backpack/hands (any Tool except the axe) with rarity when the game exposes it.",run=function()
local pets=V2.scanPets()
if#pets==0 then return false,"No animal Tools in your Backpack or hands"end
local parts={}
for i=1,math.min(#pets,8)do
local p=pets[i]
parts[#parts+1]=p.name..(p.idx>0 and(" ["..p.rarity.."]")or"")..(p.held and" (held)"or"")
end
notify(#pets.." pet(s): "..table.concat(parts,", ")..(#pets>8 and", ..."or""),"info",7)
end})
def("Farm","pet_best",{kind="button",name="Best Pet Detection",desc="Finds the highest-rarity animal Tool you carry.",run=function()
local pets=V2.scanPets()
if#pets==0 then return false,"No animal Tools in your Backpack or hands"end
local b=pets[1]
if b.idx>0 then notify(("Best pet: %s [%s]"):format(b.name,b.rarity),"good",5)
else notify("No rarity info exposed by the game. First animal: "..b.name,"warn",5)end
end})
def("Farm","pet_inv",{kind="button",name="Pet Inventory Tracker",desc="Animal Tools you hold now, plus how many you obtained this session.",run=function()
local pets=V2.scanPets()
local counts,order={},{}
for _,p in ipairs(pets)do
if not counts[p.name]then counts[p.name]=0 order[#order+1]=p.name end
counts[p.name]+=1
end
local parts={}
for _,n in ipairs(order)do parts[#parts+1]=n.." x"..counts[n]end
notify(("Holding: %s | Obtained this session: %d"):format(#pets>0 and table.concat(parts,", ")or"none",V2.session.petTotal),"info",7)
end})
def("Farm","pet_history",{kind="button",name="Pet Collection History",desc="Shows the last pets that entered your Backpack while a pet watcher was running.",run=function()
local h=V2.session.pets
if#h==0 then return false,"No pets recorded yet (turn on Auto Farm or New Pet Alerts first)"end
local parts={}
for i=#h,math.max(1,#h-4),-1 do parts[#parts+1]=h[i].at.." "..h[i].name..(h[i].idx>0 and(" ["..h[i].rarity.."]")or"")end
notify(#h.." pet(s): "..table.concat(parts," | "),"info",8)
end})
def("Farm","pet_rare_min",{kind="dropdown",name="Pet Rarity Filter (Rare Alerts)",desc="Pets at or above this rarity count as rare: highlighted alert and Rare Pet webhook.",options=RARITY_ORDER,default="legendary"})
def("Farm","session_reset",{kind="button",name="Reset Session Stats",desc="Clears farm counters, earnings, best pet and the history lists.",run=function()
V2.session={earnings=0,bestIdx=0,bestName="none",history={},pets={},petCounts={},petTotal=0,lastCash=getCash()}
FarmInfo.broken,FarmInfo.animals,FarmInfo.respawns,FarmInfo.vanished=0,0,0,0
FarmInfo.lastAnimal,FarmInfo.t0="none",os.clock()
notify("Session statistics reset","good",2)
end})

end
local WH,whValidate,whPost,whEmbed,whLoad
do
local WEBHOOK_FILE="CAZIELX_ARCHX_webhook.json"
phaseMark("webhook module")
WH={url="",state="NOT CONFIGURED",kind="Warn",detail="no URL set",sent=0,failed=0,lastAt=0,queue={},pumping=false}

function whValidate(u)
if type(u)~="string"then return false,"URL is empty"end
u=u:match("^%s*(.-)%s*$")
if u==""then return false,"URL is empty"end
local host,id=u:match("^https://([%w%.]+)/api/webhooks/(%d+)/[%w%-_]+$")
if not host then host,id=u:match("^https://([%w%.]+)/api/v%d+/webhooks/(%d+)/[%w%-_]+$")end
if not host then return false,"Not a Discord webhook URL (expected https://discord.com/api/webhooks/ID/TOKEN)"end
if host~="discord.com"and host~="discordapp.com"and host~="ptb.discord.com"and host~="canary.discord.com"then
return false,"Host must be discord.com"
end
return true,u
end
local function whMask(u)
if type(u)~="string"or u==""then return""end
local id=u:match("/webhooks/(%d+)/")
return id and("discord.com/api/webhooks/"..id.."/************")or"************"
end
local function whSetState(s,kind,detail)
WH.state,WH.kind=s,kind or"Warn"
if detail then WH.detail=detail end
end

function whPost(payload)
if not HTTP_REQUEST then return false,"No HTTP request function in this environment"end
local ok,url=whValidate(WH.url)
if not ok then return false,url end
local okE,body=pcall(HttpService.JSONEncode,HttpService,payload)
if not okE then return false,"Payload encode failed"end
local okR,res=pcall(HTTP_REQUEST,{Url=url,Method="POST",Headers={["Content-Type"]="application/json"},Body=body})
if not okR then return false,"Request error: "..tostring(res)end
if type(res)~="table"then return false,"No response from the request function"end
local code=res.StatusCode or res.status_code
if type(code)=="number"and code>=200 and code<300 then return true,"HTTP "..code end
if code==429 then return false,"Rate limited by Discord (HTTP 429)",true end
if code==401 or code==404 then return false,("Webhook rejected (HTTP %d): invalid or deleted webhook"):format(code)end
return false,"HTTP "..tostring(code or"?")..(res.StatusMessage and(" "..tostring(res.StatusMessage))or"")
end

local EMBED_COLOR={info=0x40C4FF,good=0x28D68E,warn=0xFFB84D,bad=0xEE4254}
function whEmbed(title,desc,kind,fields)
return{username="CAZIELX ARCHX",embeds={{
author={name=Player.DisplayName.." (@"..Player.Name..")"},
title=title,description=desc,color=EMBED_COLOR[kind or"info"],fields=fields,
footer={text=APP_NAME.." "..EDITION.."  |  v"..VERSION},
timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ"),
}}}
end

local function whPump()
if WH.pumping then return end
WH.pumping=true
task.spawn(function()
while alive and#WH.queue>0 do
local wait=2-(os.clock()-WH.lastAt)
if wait>0 then task.wait(wait)end
local item=table.remove(WH.queue,1)
WH.lastAt=os.clock()
local ok,why,limited=whPost(item)
if ok then
WH.sent+=1
whSetState("CONNECTED","Good",why.." @ "..os.date("%H:%M:%S"))
else
WH.failed+=1
whSetState(limited and"RATE LIMITED"or"ERROR","Bad",tostring(why))
if limited then task.wait(5)end
end
end
WH.pumping=false
end)
end

whEvent=function(title,desc,kind,fields)
if not S.wh_enable or WH.url==""then return false end
while#WH.queue>=10 do table.remove(WH.queue,1)end
WH.queue[#WH.queue+1]=whEmbed(title,desc,kind,fields)
whPump()
return true
end

local function whSave()
local ok,u=whValidate(WH.url)
if not ok then return false,u end
if not HAS_FILES then return false,"No file API in this environment: the URL is kept for this session only and is NOT saved"end
local okE,json=pcall(HttpService.JSONEncode,HttpService,{v=1,url=u})
if not okE then return false,"Encode failed"end
local okW,err=pcall(writefile,WEBHOOK_FILE,json)
if not okW then return false,"File write failed: "..tostring(err)end
return true
end
function whLoad()
if not HAS_FILES then return false,"No file API in this environment"end
local okX,exists=pcall(isfile,WEBHOOK_FILE)
if not okX or not exists then return false,"No saved webhook found"end
local okR,c=pcall(readfile,WEBHOOK_FILE)
if not okR then return false,"File read failed"end
local okD,d=pcall(HttpService.JSONDecode,HttpService,c)
if not okD or type(d)~="table"then return false,"Saved webhook file is corrupt"end
local ok,u=whValidate(d.url)
if not ok then return false,"Saved URL is invalid: "..tostring(u)end
WH.url=u
whSetState("LOADED","Warn","not tested yet")
return true
end

local function fmtDur(sec)
sec=math.floor(sec)
return("%dh %02dm %02ds"):format(math.floor(sec/3600),math.floor(sec%3600/60),sec%60)
end
local function shortNum(n)
if type(n)~="number"then return"N/A"end
local a=math.abs(n)
for _,u in ipairs({{1e15,"Qa"},{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}})do
if a>=u[1]then return("%.2f%s"):format(n/u[1],u[2])end
end
return tostring(math.floor(n*100+.5)/100)
end
farmFields=function()
local up=os.clock()-FarmInfo.t0
local rate=FarmInfo.broken/math.max(up/3600,1/3600)
local earn=V2.session.earnings
return{
{name="Eggs processed",value=tostring(FarmInfo.broken),inline=true},
{name="Pets obtained",value=tostring(FarmInfo.animals),inline=true},
{name="Eggs / hour",value=("%.1f"):format(rate),inline=true},
{name="Best pet",value=tostring(V2.session.bestName),inline=true},
{name="Cash gained",value=shortNum(earn),inline=true},
{name="Avg / egg",value=FarmInfo.broken>0 and shortNum(earn/FarmInfo.broken)or"N/A",inline=true},
{name="Farm status",value=tostring(FarmInfo.status),inline=true},
{name="Uptime",value=fmtDur(up),inline=true},
{name="Last error",value=tostring(FarmInfo.errors[#FarmInfo.errors]or"none"),inline=false},
}
end

def("Webhook","wh_url",{kind="input",private=true,name="Webhook URL",desc="Discord webhook. Kept in its own file, never in exported configs.",
placeholder="https://discord.com/api/webhooks/ID/TOKEN",mask=whMask,get=function()return WH.url end,
set=function(v)
if v==""then
WH.url=""
whSetState("NOT CONFIGURED","Warn","URL cleared (not saved)")
refreshViews(Feat.wh_url)
return true
end
local ok,u=whValidate(v)
if not ok then return false,u end
WH.url=u
whSetState("URL SET","Warn","not saved, not tested")
refreshViews(Feat.wh_url)
return true
end})
def("Webhook","wh_enable",{kind="toggle",name="Enable Webhook",desc="Allows events and statistics to be posted to Discord.",fn=function(on)
if not on then WH.queue={}return end
if not HTTP_REQUEST then return false,"This environment has no HTTP request function (request / http_request)"end
local ok,why=whValidate(WH.url)
if not ok then return false,"Cannot enable: "..tostring(why)end
end})
def("Webhook","wh_events",{kind="toggle",name="Event Notifications",desc="Master switch for individual farm event notifications.",fn=function(on)
if on and not S.wh_enable then
return false,"Enable Webhook and validate its URL first"
end
if not on then
WH.queue={}
end
return true
end})
local statsLoop
def("Webhook","wh_stats",{kind="toggle",name="Farming Statistics",desc="Posts a farming summary on the interval below.",fn=function(on)
if statsLoop then statsLoop.alive=false statsLoop=nil end
if not on then return end
if not S.wh_enable then return false,"Enable Webhook first"end
local nextAt=os.clock()+(S.wh_interval or 10)*60
statsLoop=loop(5,function()
if os.clock()<nextAt then return end
nextAt=os.clock()+(S.wh_interval or 10)*60
whEvent("Farming Statistics","Periodic summary","info",farmFields())
end)
end})
def("Webhook","wh_interval",{kind="slider",name="Statistics Interval (min)",desc="Time between statistics posts.",min=1,max=60,step=1,default=10})
for _,e in ipairs({
{"wh_ev_egg","Notify: Egg Broken","Post when an egg you hit leaves your base."},
{"wh_ev_pet","Notify: Any New Pet","Post for every new animal Tool."},
{"wh_ev_rare","Notify: Rare Pet","Post when a pet reaches the Pet Rarity Filter."},
{"wh_ev_error","Notify: Errors","Post farm errors."},
{"wh_ev_session","Notify: Session Summary","Post a summary when Auto Farm stops or the hub unloads."},
{"wh_ev_event","Notify: Game Events","Post when Event Detection spots something."},
})do
def("Webhook",e[1],{kind="toggle",name=e[2],desc=e[3].." Needs Event Notifications on.",fn=function(on)
if on and not S.wh_events then
return false,"Enable Event Notifications first"
end
return true
end})
S[e[1]]=true
V2.on[e[1]]=true
end
def("Webhook","wh_summary",{kind="button",name="Send Session Summary",desc="Posts the current farm statistics to Discord now.",run=function()
if not S.wh_enable then return false,"Enable Webhook first"end
if not whEvent("Session summary","Requested from the hub","info",farmFields())then return false,"Webhook URL is not set"end
notify("Session summary queued","good",2)
end})
def("Webhook","wh_test",{kind="button",name="Test Webhook",desc="Sends one test embed and shows the real HTTP result.",run=function()
if not HTTP_REQUEST then
whSetState("UNAVAILABLE","Bad","no HTTP request function")
return false,"This environment has no HTTP request function (request / http_request)"
end
local ok,why=whValidate(WH.url)
if not ok then
whSetState("NOT CONFIGURED","Bad",tostring(why))
return false,tostring(why)
end
whSetState("SENDING...","Warn","test in progress")
task.spawn(function()
local sent,reason=whPost(whEmbed("CAZIELX ARCHX | Test","Webhook test sent from the hub.","info",{
{name="Player",value=Player.DisplayName,inline=true},
{name="Game",value=V2.gameName().." ("..tostring(game.PlaceId)..")",inline=true},
}))
if sent then
WH.sent+=1
whSetState("CONNECTED","Good",tostring(reason).." @ "..os.date("%H:%M:%S"))
notify("Discord test delivered ("..tostring(reason)..")","good",3)
else
WH.failed+=1
whSetState("ERROR","Bad",tostring(reason))
notify("Webhook test failed: "..tostring(reason),"bad",6)
end
end)
end})
def("Webhook","wh_save",{kind="button",name="Save Webhook",desc="Validates and saves the URL to its own file.",run=function()
local ok,why=whSave()
if not ok then whSetState("NOT SAVED","Bad",tostring(why))return false,tostring(why)end
whSetState("SAVED","Good","saved to "..WEBHOOK_FILE)
notify("Webhook URL saved","good",2.5)
end})
def("Webhook","wh_load",{kind="button",name="Load Webhook",desc="Loads the saved URL from file.",run=function()
local ok,why=whLoad()
if not ok then return false,tostring(why)end
refreshViews(Feat.wh_url)
notify("Webhook URL loaded","good",2.5)
end})
def("Webhook","wh_clear",{kind="button",name="Clear Webhook",desc="Removes the URL from this session and from the saved file.",run=function()
if S.wh_enable then setValue("wh_enable",false,true)end
if S.wh_stats then setValue("wh_stats",false,true)end
WH.url,WH.queue="",{}
if HAS_FILES then
if typeof(delfile)=="function"then pcall(delfile,WEBHOOK_FILE)else pcall(writefile,WEBHOOK_FILE,"{}")end
end
whSetState("NOT CONFIGURED","Warn","URL cleared")
refreshViews(Feat.wh_url)
notify("Webhook cleared","info",2)
end})

for _,e in ipairs({{"min_gen","Minimum Generation Filter"},
{"titanic","Titanic Eggs"},{"keep_gd","Keep Gold And Diamond"},{"sell_weak","Sell Weakest When Full"}})do
na("Farm",e[1],e[2],"Needs game integration.")
end
for _,e in ipairs({{"inv_trail","Buy Trails"},{"inv_gear","Use Best Gear"},{"up_tread","Upgrade Treadmill"},
{"claim_rewards","Claim Rewards"},{"claim_now","Claim Now"},{"sell_now","Sell Now"}})do
na("Farm",e[1],e[2],"Needs game integration.")
end

end
local speed
do
local NOSTEAL="Not provided: taking items from other players is out of scope for this hub."
for _,e in ipairs({{"steal_instant","Instant Steal"},{"steal_hold","Hold After Teleport"}})do
na("Automation",e[1],e[2],"Not available.","Not provided: the server validates range, carry state and base ownership, so an instant version cannot be verified.","NOT PROVIDED")
end
for _,e in ipairs({{"auto_train","Train When Idle"},{"auto_place","Auto Place Eggs"},{"auto_open","Open Ready Eggs"},
{"auto_merge","Merge Pets"},{"auto_fuse","Fuse Pets"},{"auto_sell","Auto Sell"},
{"auto_potions","Keep Potions Running"}})do
na("Automation",e[1],e[2],"Needs game integration.")
end
for _,e in ipairs({{"ev_halloween","Halloween Events"},{"ev_shield","Pumpkin King Shield"},{"ev_candy","Buy Eggs With Candy"},
{"ev_predict","Event Predictor"}})do
na("Automation",e[1],e[2],"Needs game integration.")
end
do
local EVENT_WORDS={"event","halloween","christmas","easter","boss","invasion","meteor","blizzard","admin","lucky"}
local evBag
def("Automation","ev_alert",{kind="toggle",name="Event Detection",desc="Heuristic: watches the top level of Workspace and ReplicatedStorage (and their attributes) for new things whose names look like events. No game-specific names are assumed.",fn=function(on)
if evBag then evBag.clear()evBag=nil end
if not on then return end
local bag=newBag()
evBag=bag
local lastAt={}
local function looks(n)
n=tostring(n):lower()
for _,w in ipairs(EVENT_WORDS)do
if n:find(w,1,true)then return true end
end
return false
end
local function report(kind,name,detail)
local key=kind..name
local now=os.clock()
if lastAt[key]and now-lastAt[key]<60 then return end
lastAt[key]=now
notify("Possible event: "..name.." ("..kind..")","info",5)
farmEvent("Possible game event",("**%s** (%s)%s"):format(name,kind,detail and(" "..detail)or""),"warn",nil,"event")
end
for _,root in ipairs({workspace,ReplicatedStorage})do
bag.add(root.ChildAdded:Connect(function(c)
if looks(c.Name)and not Players:FindFirstChild(c.Name)then report("new object in "..root.Name,c.Name)end
end))
bag.add(root.AttributeChanged:Connect(function(a)
if looks(a)then report("attribute on "..root.Name,a,"= "..tostring(root:GetAttribute(a)))end
end))
end
end})
end

local noclip={}
def("Movement","noclip",{kind="toggle",name="NoClip",desc="Walk through walls (local). Collisions restored when off.",fn=function(on)
if noclip.bag then noclip.bag.clear()noclip.bag=nil end
if noclip.orig then for p in pairs(noclip.orig)do if p.Parent then p.CanCollide=true end end noclip.orig=nil end
if not on then return end
local bag=newBag()
local parts,orig=setmetatable({},{__mode="k"}),setmetatable({},{__mode="k"})
noclip.bag,noclip.orig=bag,orig
hookCharacter(bag,function(char,cb)
table.clear(parts)
for _,d in ipairs(char:GetDescendants())do if d:IsA("BasePart")then parts[d]=true end end
cb.add(char.DescendantAdded:Connect(function(d)if d:IsA("BasePart")then parts[d]=true end end))
end)
bag.add(RunService.Stepped:Connect(function()
for p in pairs(parts)do if p.Parent and p.CanCollide then orig[p]=true p.CanCollide=false end end
end))
end})

local ij
def("Movement","infjump",{kind="toggle",name="Infinite Jump",desc="Jump again while in the air.",fn=function(on)
if ij then ij.clear()ij=nil end
if on then
ij=newBag()
ij.add(UIS.JumpRequest:Connect(function()
local h=getHum()
if h and h.Health>0 then h:ChangeState(Enum.HumanoidStateType.Jumping)end
end))
end
end})

phaseMark("movement features")
speed=humanoidOverride("WalkSpeed",function()return S.speed_value end)
local speedWatch,speedBad=nil,0
def("Movement","speed",{kind="toggle",name="Speed Boost",desc="Sets WalkSpeed to the slider value and verifies it by measuring your real movement speed. Turns itself OFF if the game overrides it (Speed is a server-side stat in this game).",fn=function(on)
if speedWatch then speedWatch.alive=false speedWatch=nil end
speedBad=0
if not on then speed.disable()V2.setState("speed","SKIPPED","turned off, WalkSpeed restored")return end
local h=getHum()
if not h then V2.setState("speed","FAILED","no Humanoid")return false,"No Humanoid (respawning?)"end
V2.setState("speed","STARTING")
speed.enable()
speedWatch=loop(1,function()
local hum=getHum()
local hrp=hum and hum.RootPart
if not hum or not hrp then return end
local want=S.speed_value
if math.abs(hum.WalkSpeed-want)>.5 then
speedBad+=1
V2.setState("speed","RUNNING","WalkSpeed differs from target ("..math.floor(hum.WalkSpeed)..")")
elseif hum.MoveDirection.Magnitude>.1 and hum.FloorMaterial~=Enum.Material.Air then
local v=Vector3.new(hrp.AssemblyLinearVelocity.X,0,hrp.AssemblyLinearVelocity.Z).Magnitude
if v<want*.6 then speedBad+=1 V2.setState("speed","RUNNING",("moving at %.0f of %d studs/s"):format(v,want))else
speedBad=0
V2.setState("speed","SUCCESS",("measured %.0f studs/s (target %d)"):format(v,want))
end
end
if speedBad>=4 then
V2.setState("speed","FAILED","game overrides movement speed")
task.defer(function()setValue("speed",false,true)notify("Speed Boost: the game overrides your speed, so it was turned OFF (no real effect)","bad",5)end)
end
end)
end})
def("Movement","speed_value",{kind="slider",name="Walk Speed",desc="Value used by Speed Boost.",min=16,max=150,step=1,default=32,fn=function()speed.refresh()end})

local jump=humanoidOverride("JumpPower",function()return S.jump_value end,{prop="UseJumpPower",value=true})
def("Movement","jump",{kind="toggle",name="Jump Boost",desc="Sets JumpPower to the slider value; restored when off.",fn=function(on)
if on then jump.enable()else jump.disable()end
end})
def("Movement","jump_value",{kind="slider",name="Jump Power",desc="Value used by Jump Boost.",min=50,max=250,step=5,default=90,fn=function()jump.refresh()end})

def("Movement","tp_base",{kind="button",name="Teleport To Base",desc="Moves you to your own base: plot ownership tag, plot sign, Player attribute, RespawnLocation, then your first spawn point. Validates before and after; the server may still reject teleports.",run=function()
local char=Player.Character
local hrp=char and char:FindFirstChild("HumanoidRootPart")
local hum=getHum()
if not hrp or not hum or hum.Health<=0 then V2.setState("tp_base","FAILED","character not ready")return false,"Character is not ready (respawning?)"end
local base=getBase(true)
if not base then V2.setState("tp_base","FAILED",FarmInfo.baseWhy)return false,"Base not detected: "..tostring(FarmInfo.baseWhy)end
local p=instPos(base)
if not p or p~=p then V2.setState("tp_base","FAILED","base has no position")return false,"Base has no position to teleport to"end
local params=RaycastParams.new()
params.FilterType=Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances={char}
local hit=workspace:Raycast(p+Vector3.new(0,60,0),Vector3.new(0,-200,0),params)
local dest=(hit and hit.Position or p)+Vector3.new(0,4,0)
if dest~=dest or dest.Magnitude>1e5 or math.abs(dest.Y)>5000 then V2.setState("tp_base","FAILED","destination failed validation")return false,"Destination failed validation"end
local before=(hrp.Position-dest).Magnitude
local keep=hrp.CFrame-hrp.CFrame.Position
V2.tpHold=os.clock()+8
local ok,err=pcall(function()
hum:MoveTo(hrp.Position)
hum.Sit=false
hrp.AssemblyLinearVelocity=Vector3.zero
hrp.AssemblyAngularVelocity=Vector3.zero
char:PivotTo(CFrame.new(dest)*keep)
hum:MoveTo(dest)
end)
if not ok then V2.tpHold=nil farmErr(err)V2.setState("tp_base","FAILED",tostring(err))return false,"Teleport failed: "..tostring(err)end
local worst,t0=0,os.clock()
while os.clock()-t0<3 do
task.wait(.15)
if not hrp.Parent then break end
worst=math.max(worst,(hrp.Position-dest).Magnitude)
end
V2.tpHold=os.clock()+1.5
local after=hrp.Parent and(hrp.Position-dest).Magnitude or math.huge
local busy={}
for _,f in ipairs(FeatList)do
if f.kind=="toggle"and S[f.id]and(f.tab=="Farm"or f.tab=="Automation")then busy[#busy+1]=f.name end
end
if worst>25 or after>25 then
local why=#busy>0 and("automation is still active: "..table.concat(busy,", "))or"the game moved the character back (server-side position reset)"
V2.setState("tp_base","FAILED",("%.0f studs from base after teleport; %s"):format(after,why))
return false,("Pulled away from base (%d studs). Cause: %s"):format(math.floor(after),why)
end
V2.setState("tp_base","SUCCESS",("moved %d studs via %s"):format(math.floor(before),tostring(FarmInfo.baseWhy)))
notify("Teleported to base ("..tostring(FarmInfo.baseWhy)..")","good",2)
if#busy>0 then notify("Active automation will walk away from base again: "..table.concat(busy,", "),"warn",5)end
end})
na("Movement","walk_zone","Walk To Zone","Walk to a zone.","Needs the game's zone objects (names unknown/unverified).")
na("Movement","walk_tread","Walk To Treadmill","Walk to the treadmill.","Needs the game's treadmill point (found at runtime by KryvenHub; not verified here).")
na("Movement","walk_plot","Walk To Plot","Walk to your plot.","Needs the game's plot objects (names unknown/unverified).")
na("Movement","walk_safe","Walk To Safe Zone","Walk to the safe zone.","Needs the game's safe-zone objects (names unknown/unverified).")

local FB_PROPS={Brightness=2,Ambient=Color3.new(1,1,1),OutdoorAmbient=Color3.new(1,1,1),GlobalShadows=false,FogEnd=1e6}
local fbState
def("Visuals","fullbright",{kind="toggle",name="Fullbright",desc="Removes darkness and fog; original lighting restored when off.",fn=function(on)
if fbState then
fbState.bag.clear()
for k,v in pairs(fbState.orig)do pcall(function()Lighting[k]=v end)end
fbState=nil
end
if not on then return end
local bag,orig=newBag(),{}
fbState={bag=bag,orig=orig}
for k,v in pairs(FB_PROPS)do
orig[k]=Lighting[k]
Lighting[k]=v
bag.add(Lighting:GetPropertyChangedSignal(k):Connect(function()if Lighting[k]~=v then Lighting[k]=v end end))
end
end})

local lowState
local function isEffect(o)
return o:IsA("ParticleEmitter")or o:IsA("Trail")or o:IsA("Beam")or o:IsA("Smoke")or o:IsA("Fire")or o:IsA("Sparkles")or o:IsA("PostEffect")
end
def("Visuals","lowgfx",{kind="toggle",name="Low Graphics",desc="Disables particles, trails, beams and post effects (also new ones).",fn=function(on)
if lowState then
lowState.bag.clear()
for o,v in pairs(lowState.orig)do if o.Parent then pcall(function()o.Enabled=v end)end end
lowState=nil
end
if not on then return end
local bag,orig=newBag(),setmetatable({},{__mode="k"})
lowState={bag=bag,orig=orig}
local function cut(o)
if isEffect(o)then
if orig[o]==nil then orig[o]=o.Enabled end
o.Enabled=false
end
end
for _,o in ipairs(workspace:GetDescendants())do cut(o)end
for _,o in ipairs(Lighting:GetDescendants())do cut(o)end
bag.add(workspace.DescendantAdded:Connect(cut))
bag.add(Lighting.DescendantAdded:Connect(cut))
end})

local fpsState
def("Visuals","fpsboost",{kind="toggle",name="FPS Boost",desc="Lowest render quality + no terrain decoration; restored when off.",fn=function(on)
if not on then
if fpsState then
pcall(function()settings().Rendering.QualityLevel=fpsState.q end)
if fpsState.deco~=nil then pcall(function()workspace.Terrain.Decoration=fpsState.deco end)end
fpsState=nil
end
return
end
local ok,q=pcall(function()
local r=settings().Rendering
local old=r.QualityLevel
r.QualityLevel=Enum.QualityLevel.Level01
return old
end)
if not ok then return false,"Render quality can't be changed from this context"end
fpsState={q=q}
local ok2,d=pcall(function()local t=workspace.Terrain local old=t.Decoration t.Decoration=false return old end)
if ok2 then fpsState.deco=d end
end})

local ESP_COLORS={Blue=Color3.fromRGB(0,136,255),Red=Color3.fromRGB(255,70,80),Green=Color3.fromRGB(60,220,140),
Purple=Color3.fromRGB(170,100,255),White=Color3.fromRGB(240,245,255)}
local R15_BONES={
{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local R6_BONES={{"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"}}
local esp={ents={},frame=0}

local function espColor()return hexColor(S.esp_custom)or ESP_COLORS[S.esp_color]or ESP_COLORS.Blue end
local function espTypeColor(key)return hexColor(S["esp_c_"..key])or espColor()end

local function espNewEnt(plr,parent)
local folder=Instance.new("Folder")
folder.Name=plr.Name
folder.Parent=parent
local box=Instance.new("Frame")
box.BackgroundTransparency=1
box.BorderSizePixel=0
box.Visible=false
box.Parent=folder
local bs=Instance.new("UIStroke")
bs.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
bs.Parent=box
local label=Instance.new("TextLabel")
label.BackgroundTransparency=1
label.AnchorPoint=Vector2.new(.5,1)
label.Size=UDim2.fromOffset(200,14)
label.Font=BOLD
label.TextSize=12
label.TextStrokeTransparency=.5
label.Visible=false
label.Parent=folder
local bones={}
for i=1,#R15_BONES do
local l=Instance.new("Frame")
l.AnchorPoint=Vector2.new(.5,.5)
l.BorderSizePixel=0
l.Visible=false
l.Parent=folder
bones[i]=l
end
return{folder=folder,box=box,stroke=bs,label=label,bones=bones}
end

local function espHide(ent)
ent.box.Visible=false
ent.label.Visible=false
for _,l in ipairs(ent.bones)do l.Visible=false end
if ent.hl then ent.hl:Destroy()ent.hl,ent.hlChar=nil,nil end
end
local function espDrop(plr)
local ent=esp.ents[plr]
if not ent then return end
esp.ents[plr]=nil
if ent.hl then pcall(function()ent.hl:Destroy()end)end
pcall(function()ent.folder:Destroy()end)
end

local function espUpdate(plr,cam,myPos)
local ent=esp.ents[plr]
local char=plr.Character
local hrp=char and char:FindFirstChild("HumanoidRootPart")
local head=char and char:FindFirstChild("Head")
local hum=char and char:FindFirstChildOfClass("Humanoid")
if not(hrp and head and hum)or hum.Health<=0 then
if ent then espHide(ent)end
return
end
local dist=(hrp.Position-myPos).Magnitude
if dist>(S.esp_range or 1000)then
if ent then espHide(ent)end
return
end
if not ent then
ent=espNewEnt(plr,esp.gui)
esp.ents[plr]=ent
end
local tr,th=S.esp_trans or 0,S.esp_thick or 1.5
local cHl,cBox,cName,cSkel=espTypeColor("hl"),espTypeColor("box"),espTypeColor("name"),espTypeColor("skel")

if S.esp_hl then
if ent.hlChar~=char or not ent.hl or not ent.hl.Parent then
if ent.hl then ent.hl:Destroy()end
local hl=Instance.new("Highlight")
hl.Name="CAZX_ESP"
hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
hl.Adornee=char
hl.Parent=char
ent.hl,ent.hlChar=hl,char
end
if ent.hl.FillColor~=cHl then ent.hl.FillColor=cHl ent.hl.OutlineColor=cHl end
ent.hl.FillTransparency=math.clamp(.35+tr*.65,0,1)
ent.hl.OutlineTransparency=tr
elseif ent.hl then
ent.hl:Destroy()
ent.hl,ent.hlChar=nil,nil
end

local top=cam:WorldToViewportPoint(head.Position+Vector3.new(0,head.Size.Y*.5+.2,0))
local bot=cam:WorldToViewportPoint(hrp.Position-Vector3.new(0,3,0))
if top.Z<=0 or bot.Z<=0 then
ent.box.Visible,ent.label.Visible=false,false
for _,l in ipairs(ent.bones)do l.Visible=false end
return
end
local h=math.max(math.abs(bot.Y-top.Y),8)
local w=h*.55
local cx=(top.X+bot.X)*.5

if S.esp_box then
ent.box.Position=UDim2.fromOffset(cx-w/2,top.Y)
ent.box.Size=UDim2.fromOffset(w,h)
ent.stroke.Color,ent.stroke.Thickness,ent.stroke.Transparency=cBox,th,tr
ent.box.Visible=true
else
ent.box.Visible=false
end

if S.esp_name or S.esp_dist or S.esp_pet then
local s=S.esp_name and plr.DisplayName or""
if S.esp_dist then s=(s~=""and(s.."  ")or"")..("[%d]"):format(math.floor(dist))end
if S.esp_pet then
local tool=char:FindFirstChildOfClass("Tool")
if tool and tool.Name~="Bat"and not isAxeName(tool.Name)then s=(s~=""and(s.."  ")or"").."<"..tool.Name..">"end
end
ent.label.Text=s
ent.label.TextColor3=cName
ent.label.TextTransparency=tr
ent.label.Position=UDim2.fromOffset(cx,top.Y-3)
ent.label.Visible=true
else
ent.label.Visible=false
end

if S.esp_skel then
local rig=char:FindFirstChild("UpperTorso")and R15_BONES or R6_BONES
for i,pair in ipairs(ent.bones)do
local bone=rig[i]
local a=bone and char:FindFirstChild(bone[1])
local b=bone and char:FindFirstChild(bone[2])
local shown=false
if a and b and a:IsA("BasePart")and b:IsA("BasePart")then
local pa=cam:WorldToViewportPoint(a.Position)
local pb=cam:WorldToViewportPoint(b.Position)
if pa.Z>0 and pb.Z>0 then
local dx,dy=pb.X-pa.X,pb.Y-pa.Y
pair.Position=UDim2.fromOffset((pa.X+pb.X)*.5,(pa.Y+pb.Y)*.5)
pair.Size=UDim2.fromOffset(math.sqrt(dx*dx+dy*dy),th)
pair.Rotation=math.deg(math.atan2(dy,dx))
if pair.BackgroundColor3~=cSkel then pair.BackgroundColor3=cSkel end
pair.BackgroundTransparency=tr
shown=true
end
end
pair.Visible=shown
end
else
for _,l in ipairs(ent.bones)do l.Visible=false end
end
end

local function espStop()
if esp.bag then esp.bag.clear()esp.bag=nil end
for p in pairs(esp.ents)do espDrop(p)end
esp.gui=nil
end
local function espStart()
espStop()
local sg=Instance.new("ScreenGui")
sg.Name="CazxEsp"
sg.ResetOnSpawn=false
sg.IgnoreGuiInset=true
sg.DisplayOrder=90
sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
sg.Parent=PlayerGui
local bag=newBag()
bag.add(sg)
esp.bag,esp.gui,esp.frame,esp.warned=bag,sg,0,false
bag.add(Players.PlayerRemoving:Connect(espDrop))
bag.add(RunService.RenderStepped:Connect(function()
local cam=workspace.CurrentCamera
if not cam then return end
esp.frame+=1
local list=Players:GetPlayers()
local stagger=#list>30
local mc=Player.Character
local mh=mc and mc:FindFirstChild("HumanoidRootPart")
local myPos=mh and mh.Position or cam.CFrame.Position
for _,plr in ipairs(list)do
if plr~=Player and(not stagger or(esp.frame+plr.UserId)%2==0)then
local ok,err=pcall(espUpdate,plr,cam,myPos)
if not ok and not esp.warned then
esp.warned=true
warn("[CAZX] ESP: "..tostring(err))
farmErr("ESP: "..tostring(err))
end
end
end
end))
end

def("Visuals","esp_players",{kind="toggle",name="Player ESP",desc="Master switch for the player visuals chosen below (screen-space, event-free, cleaned up when a player leaves).",fn=function(on)
if not on then espStop()return end
if not(S.esp_skel or S.esp_box or S.esp_name or S.esp_dist or S.esp_hl)then
setValue("esp_skel",true,true)
setValue("esp_name",true,true)
end
espStart()
end})
for _,e in ipairs({
{"esp_skel","Skeleton ESP","Bone skeleton over each player (R15 and R6)."},
{"esp_box","Box ESP","Bounding box around each player."},
{"esp_name","Name ESP","Display name above each player."},
{"esp_dist","Distance ESP","Distance in studs above each player."},
{"esp_hl","Highlight ESP","Colored highlight through walls."},
})do
def("Visuals",e[1],{kind="toggle",name=e[2],desc=e[3],fn=function(on)


if not on then
local st=V2.playerEsp
if st and st.entities then
for _,ent in pairs(st.entities)do
if e[1]=="esp_box"and ent.box then ent.box.Visible=false end
if e[1]=="esp_name"or e[1]=="esp_dist"or e[1]=="esp_pet"then
if ent.label then ent.label.Visible=false end
end
if e[1]=="esp_hl"and ent.hl then ent.hl.Enabled=false end
if e[1]=="esp_skel"and ent.bones then
for _,bone in ipairs(ent.bones)do bone.Visible=false end
end
end
end
end
return true
end})
end
def("Visuals","esp_color",{kind="dropdown",name="ESP Color",desc="Preset color. Custom ESP Color overrides it when set.",options={"Blue","Red","Green","Purple","White"},default="Blue"})
def("Visuals","esp_custom",{kind="color",name="Custom ESP Color",desc="Hex like #ff4466 or tap a swatch. Empty uses the preset.",key="Accent",palette=true})
def("Visuals","esp_trans",{kind="slider",name="ESP Transparency",desc="0 is solid, 0.9 is almost invisible.",min=0,max=.9,step=.05,default=.1})
def("Visuals","esp_thick",{kind="slider",name="ESP Thickness",desc="Line thickness for box and skeleton.",min=1,max=4,step=.5,default=1.5})
def("Visuals","esp_range",{kind="slider",name="ESP Max Distance",desc="Players farther than this are not drawn (saves FPS).",min=100,max=3000,step=50,default=1000})

end
local bootWarnings,preloadTheme,fpsValue,frameCount,lastFpsAt,sampleStats,buildInterface
do
local eggEsp
phaseMark("esp features")
V2.rarityColors={Color3.fromRGB(190,190,200),Color3.fromRGB(80,220,120),Color3.fromRGB(70,140,255),Color3.fromRGB(170,90,255),
Color3.fromRGB(255,184,77),Color3.fromRGB(255,84,98),Color3.fromRGB(80,230,255),Color3.fromRGB(255,110,200)}
function V2.eggEspStyle(o,rec)
if not rec.hl.Parent then return end
local name=eggLabel(o)
local idx,rl=V2.rarityInfo(o,name)
local col=(S.esp_rarity and V2.rarityColors[idx])or hexColor(S.esp_c_egg)or T.Accent
rec.hl.FillColor,rec.hl.OutlineColor=col,Color3.new(1,1,1)
rec.hl.FillTransparency=math.clamp(.35+(S.esp_trans or.1)*.65,0,1)
if S.esp_rarity then name=name..(idx>0 and("  ["..rl.."]")or"  [rarity n/a]")end
rec.lbl.Text=name
rec.lbl.TextColor3=col
end
function V2.refreshEggEsp()
if not eggEsp then return end
for o,rec in pairs(eggEsp.rec)do pcall(V2.eggEspStyle,o,rec)end
end
def("Visuals","esp_egg",{kind="toggle",name="Egg ESP",desc="Highlights and labels eggs under Workspace.Build.ZoneBuilds (event-driven, cleaned up when off).",fn=function(on)
if eggEsp then
eggEsp.bag.clear()
for _,rec in pairs(eggEsp.rec)do pcall(function()rec.hl:Destroy()rec.bb:Destroy()end)end
eggEsp=nil
end
if not on then return end
local build=workspace:FindFirstChild("Build")
local zones=build and build:FindFirstChild("ZoneBuilds")
if not zones then return false,"Workspace.Build.ZoneBuilds was not found in this server"end
local st={bag=newBag(),rec={}}
eggEsp=st
local function tag(o)
if o.Name=="Egg"and o:IsA("BasePart")and not st.rec[o]then
local holder=o.Parent
local folder=holder and holder.Parent
if folder and folder.Name=="Eggs"then
local hl=Instance.new("Highlight")
hl.Name="CAZX_EGG"
hl.Adornee=o
hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
hl.Parent=o
local bb=Instance.new("BillboardGui")
bb.Name="CAZX_EGGLBL"
bb.Adornee=o
bb.AlwaysOnTop=true
bb.Size=UDim2.fromOffset(190,18)
bb.StudsOffset=Vector3.new(0,3,0)
bb.MaxDistance=S.esp_range or 1000
bb.Parent=o
local lbl=Instance.new("TextLabel")
lbl.BackgroundTransparency=1
lbl.Size=UDim2.fromScale(1,1)
lbl.Font=BOLD
lbl.TextSize=12
lbl.TextStrokeTransparency=.4
lbl.Parent=bb
st.rec[o]={hl=hl,bb=bb,lbl=lbl}
pcall(V2.eggEspStyle,o,st.rec[o])
end
end
end
for _,d in ipairs(zones:GetDescendants())do tag(d)end
st.bag.add(zones.DescendantAdded:Connect(tag))
st.bag.add(zones.DescendantRemoving:Connect(function(o)
local rec=st.rec[o]
if rec then
pcall(function()rec.hl:Destroy()rec.bb:Destroy()end)
st.rec[o]=nil
end
end))
end})
na("Visuals","esp_lucky","Lucky Egg ESP","Marks lucky eggs.","The game's definition of a lucky egg is not known or verified, so it is not guessed.")
def("Visuals","esp_rarity",{kind="toggle",name="Rarity Indicator",desc="Egg ESP shows the rarity next to the egg name and colors it by rarity (only when the egg exposes a rarity).",fn=function()task.defer(V2.refreshEggEsp)end})
def("Visuals","esp_pet",{kind="toggle",name="Pet ESP (carried)",desc="Player ESP also shows the animal Tool each other player is holding. Pets standing in the world have no verified object, so they are not drawn.",fn=function(on)
if not on then
local st=V2.playerEsp
if st and st.entities then
for _,ent in pairs(st.entities)do
if ent.label then ent.label.Visible=S.esp_name or S.esp_dist or false end
end
end
end
return true
end})
for _,e in ipairs({{"esp_c_skel","Skeleton Color"},{"esp_c_box","Box Color"},{"esp_c_name","Name / Distance Color"},{"esp_c_hl","Highlight Color"},{"esp_c_egg","Egg ESP Color"}})do
def("Visuals",e[1],{kind="color",name=e[2],desc="Hex color for this ESP type. Empty uses the main ESP color.",key="Accent",palette=true,fn=function()V2.refreshEggEsp()end})
end

local inv={}
def("Player","invisible",{kind="toggle",name="Invisible (Local)",desc="Hides your character on your screen only.",fn=function(on)
if inv.bag then inv.bag.clear()inv.bag=nil end
if inv.orig then for o,v in pairs(inv.orig)do if o.Parent then o.Transparency=v end end inv.orig=nil end
if not on then return end
local bag,orig=newBag(),setmetatable({},{__mode="k"})
inv.bag,inv.orig=bag,orig
local function hide(o)
if o:IsA("BasePart")or o:IsA("Decal")then
if orig[o]==nil then orig[o]=o.Transparency end
o.Transparency=1
end
end
hookCharacter(bag,function(char,cb)
for _,d in ipairs(char:GetDescendants())do hide(d)end
cb.add(char.DescendantAdded:Connect(hide))
end)
end})
def("Player","reset",{kind="button",name="Reset Character",desc="Respawns your character.",run=function()
local h=getHum()
if not h then return false,"No character to reset"end
h.Health=0
end})

local dcAlert
def("Player","dc_alert",{kind="toggle",name="Disconnect Alert",desc="Notifies when Roblox shows a disconnect/error message.",fn=function(on)
if dcAlert then dcAlert.clear()dcAlert=nil end
if on then
dcAlert=newBag()
dcAlert.add(GuiService.ErrorMessageChanged:Connect(function(msg)
if msg and msg~=""then notify("Disconnected: "..msg,"bad",10)end
end))
end
end})

local afk
def("Player","antiafk",{kind="toggle",name="Anti AFK",desc="Prevents the idle kick by simulating input.",fn=function(on)
if afk then afk.clear()afk=nil end
if on then
afk=newBag()
afk.add(Player.Idled:Connect(function()
pcall(function()VirtualUser:CaptureController()VirtualUser:ClickButton2(Vector2.new())end)
end))
end
end})

local reco
def("Player","autoreconnect",{kind="toggle",name="Auto Reconnect",desc="Best effort: teleports back to this place after a disconnect message.",fn=function(on)
if reco then reco.clear()reco=nil end
if on then
reco=newBag()
local busy=false
reco.add(GuiService.ErrorMessageChanged:Connect(function(msg)
if busy or not msg or msg==""then return end
busy=true
notify("Connection lost. Reconnecting in 3s...","warn",4)
task.delay(3,function()
pcall(function()TeleportService:Teleport(game.PlaceId,Player)end)
busy=false
end)
end))
end
end})

local pingW
def("Player","pingfreeze",{kind="toggle",name="Rejoin If Ping Freezes",desc="Rejoins when ping stays above the limit for ~9 seconds.",fn=function(on)
if pingW then pingW.alive=false pingW=nil end
if not on then return end
local w={alive=true}
pingW=w
task.spawn(function()
local strikes=0
while w.alive and alive do
task.wait(3)
if not w.alive then break end
local ok,p=pcall(function()return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()end)
if ok and p and p>S.ping_limit then strikes+=1 else strikes=0 end
if strikes>=3 then
w.alive=false
notify("Ping frozen. Rejoining...","warn",4)
pcall(rejoin)
end
end
end)
end})
def("Player","ping_limit",{kind="slider",name="Ping Limit (ms)",desc="Threshold for Rejoin If Ping Freezes.",min=300,max=5000,step=100,default=1500})
na("Player","rejoin_each","Rejoin Every Join","Auto rejoin on each join.","Needs a persistent loader across teleports; not available in a plain LocalScript.","UNAVAILABLE")
na("Player","nopause","No Gameplay Paused","Disable the gameplay-paused screen.","Pause state is controlled by the engine/server; the client can't override it.","UNAVAILABLE")

local rep
def("Statistics","reports",{kind="toggle",name="Progress Reports",desc="Periodic session report: uptime, FPS, ping, players.",fn=function(on)
if rep then rep.alive=false rep.bag.clear()rep=nil end
if not on then return end
local r={alive=true,bag=newBag(),frames=0}
rep=r
r.bag.add(RunService.Heartbeat:Connect(function()r.frames+=1 end))
local startTime,last=os.time(),time()
task.spawn(function()
while r.alive and alive do
task.wait(math.max(S.report_minutes,1)*60)
if not r.alive then break end
local now=time()
local fps=r.frames/math.max(now-last,1)
r.frames,last=0,now
local ping=0
pcall(function()ping=Stats.Network.ServerStatsItem["Data Ping"]:GetValue()end)
notify(("Session %d min | %d FPS | %d ms | %d players"):format(math.floor((os.time()-startTime)/60),
math.floor(fps),math.floor(ping),#Players:GetPlayers()),"info",6)
end
end)
end})
def("Statistics","report_minutes",{kind="slider",name="Report Interval (min)",desc="Time between reports.",min=1,max=30,step=1,default=5})
do
local release
def("Statistics","pet_alert",{kind="toggle",name="New Pet Alerts",desc="Alert for every new animal Tool in your Backpack (works without Auto Farm). Rare pets are highlighted.",fn=function(on)
if release then release()release=nil end
if on then release=V2.petTrackStart()end
end})
end

local blackGui
def("Settings","blackscreen",{kind="toggle",name="Black Screen",desc="Covers the 3D view with black. This hub stays on top.",fn=function(on)
if blackGui then blackGui:Destroy()blackGui=nil end
if on then
blackGui=new("ScreenGui",{Name="CazxBlack",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=50},PlayerGui)
new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0},blackGui)
end
end})
def("Settings","no3d",{kind="toggle",name="Disable 3D Rendering",desc="Stops 3D rendering to save GPU. UI keeps working.",fn=function(on)
local ok=pcall(function()RunService:Set3dRenderingEnabled(not on)end)
if not ok then return false,"3D rendering can't be toggled from this context"end
end})
def("Settings","fps_limit",{kind="toggle",name="Limit FPS",desc="Caps frame rate (needs setfpscap). Restores 60 when off.",
check=function()return HAS_FPSCAP,"Requires an environment that provides setfpscap"end,
fn=function(on)
local ok=pcall(setfpscap,on and S.fps_cap or 60)
if not ok then return false,"setfpscap failed"end
end})
def("Settings","fps_cap",{kind="slider",name="FPS Cap",desc="Value used by Limit FPS.",min=15,max=240,step=5,default=60,
check=function()return HAS_FPSCAP,"Requires setfpscap"end,
fn=function(v)if S.fps_limit and HAS_FPSCAP then pcall(setfpscap,v)end end})
na("Settings","backpack_lag","Fix Backpack Lag","Reduce backpack lag.","Needs the game's backpack UI/objects (unverified).")
def("Settings","notif_level",{kind="dropdown",name="Notifications",desc="All, only warnings/errors, or none.",options={"All","Important","Off"},default="All"})
def("Settings","toggle_key",{kind="dropdown",name="Toggle Key (PC)",desc="Keyboard shortcut to show/hide. Mobile uses the floating button.",options={"RightShift","RightControl","Insert","Home","K"},default="RightShift"})
def("Settings","config_box",{kind="textbox",name="Config JSON",desc="Export fills this box. Paste JSON here to import."})
def("Settings","cfg_autosave",{kind="toggle",name="Auto Save",desc="Saves the configuration about 1.5s after any change. A warning appears if the file cannot be written.",fn=function(on)
if on then
task.defer(function()
if alive and not V2.booting then
local ok,err=saveConfig(true)
if not ok then notify("Auto Save unavailable: "..tostring(err or"session-only storage"),"warn",4)end
end
end)
end
return true
end})
phaseMark("settings features")
S.cfg_autosave=true
V2.on.cfg_autosave=true
def("Settings","cfg_save",{kind="button",name="Save Configuration",desc="Saves to file (if available) and session.",run=function()saveConfig(false)end})
def("Settings","cfg_load",{kind="button",name="Load Configuration",desc="Loads the last saved configuration.",run=function()loadConfig(false)end})
def("Settings","cfg_export",{kind="button",name="Export Configuration",desc="Writes JSON into the box (and clipboard if possible).",run=function()
local json=encodeConfig()
if uiRefs.configBox then uiRefs.configBox.Text=json end
if HAS_CLIPBOARD and pcall(setclipboard,json)then notify("Config exported and copied","good")
else notify("Config exported. Copy it from the box.","good")end
end})
def("Settings","cfg_import",{kind="button",name="Import Configuration",desc="Validates and applies the JSON in the box.",run=function()
local ok,msg=importJSON(uiRefs.configBox and uiRefs.configBox.Text or"")
notify(ok and msg or("Import failed: "..msg),ok and"good"or"bad",4)
end})
def("Settings","cfg_reset",{kind="button",name="Reset Configuration",desc="Turns everything off and restores defaults.",run=resetConfig})
function V2.unloadNow()
if S.wh_enable and WH.url~=""and S.wh_ev_session~=false and HTTP_REQUEST then
pcall(whPost,whEmbed("Session summary","The hub was unloaded","info",farmFields()))
end
local cleanupFn=slotGet("__CAZX_CLEANUP")
if cleanupFn then cleanupFn()end
end
def("Settings","cfg_unload",{kind="button",name="Unload Hub",desc="Sends a session summary (if enabled), disables all features, closes connections and removes the UI.",run=function()
task.defer(V2.unloadNow)
end})

def("Server","rejoin",{kind="button",name="Rejoin Server",desc="Rejoins this server (or a fresh one if you're alone).",run=function()
notify("Rejoining...","info",2)
local ok=pcall(rejoin)
if not ok then return false,"Rejoin failed (teleport not allowed here)"end
end})
def("Server","copyjob",{kind="button",name="Copy JobId",desc="Copies this server's JobId.",run=function()
local id=game.JobId~=""and game.JobId or"(empty - Studio)"
if HAS_CLIPBOARD and pcall(setclipboard,id)then notify("JobId copied","good")
else notify("Clipboard unavailable. JobId: "..id,"warn",8)end
end})
def("Server","showjob",{kind="button",name="Show JobId",desc="Shows this server's JobId.",run=function()
notify("JobId: "..(game.JobId~=""and game.JobId or"(empty - Studio)"),"info",8)
end})
def("Server","hop",{kind="button",name="Server Hop",desc="Joins another public server (needs an HTTP request function).",
check=function()return HTTP_REQUEST~=nil,"Requires an environment that provides an HTTP request function"end,
run=function()
notify("Searching for a server...","info",2)
task.spawn(function()
local url=("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
local ok,res=pcall(HTTP_REQUEST,{Url=url,Method="GET"})
if not ok or type(res)~="table"or res.StatusCode~=200 then notify("Server list request failed","bad")return end
local okj,data=pcall(HttpService.JSONDecode,HttpService,res.Body)
if not okj or type(data)~="table"or type(data.data)~="table"then notify("Unexpected server list format","bad")return end
for _,s in ipairs(data.data)do
if s.id~=game.JobId and type(s.playing)=="number"and type(s.maxPlayers)=="number"and s.playing<s.maxPlayers-1 then
notify("Hopping...","good",2)
pcall(function()TeleportService:TeleportToPlaceInstance(game.PlaceId,s.id,Player)end)
return
end
end
notify("No suitable server found","warn")
end)
end})

def("Theme","theme_preset",{kind="dropdown",name="Theme Preset",desc="Switches the whole interface. Clears custom colors.",options=PRESET_ORDER,default="Cazielx Violet",fn=function()
for _,id in ipairs({"theme_accent","theme_bg","theme_panel","theme_border","theme_text","theme_sub"})do
S[id]=""
refreshViews(Feat[id])
end
applyTheme(true)
end})
local function colorFeat(id,name,desc,key,palette)
def("Theme",id,{kind="color",name=name,desc=desc,key=key,palette=palette,fn=function()applyTheme(true)end})
end
colorFeat("theme_accent","Accent Color","Hex like #40c4ff. Empty follows the preset.","Accent",true)
colorFeat("theme_bg","Background Color","Window background.","Bg")
colorFeat("theme_panel","Panel Color","Sidebar, title bar and cards.","Panel")
colorFeat("theme_border","Border Color","Outlines and dividers.","Border")
colorFeat("theme_text","Text Color","Primary text.","Text")
colorFeat("theme_sub","Secondary Text Color","Descriptions and hints.","Sub")
def("Theme","theme_tr",{kind="slider",name="UI Transparency",desc="Window and card transparency.",min=0,max=.5,step=.05,default=0,fn=function()applyTheme(false)end})
def("Theme","ui_scale",{kind="slider",name="UI Scale",desc="Scales the whole hub.",min=.7,max=1.3,step=.05,default=1,fn=function()applyScale()end})
def("Theme","anim_level",{kind="slider",name="Animation Intensity",desc="0 disables animation, 1 is normal, 2 is slower and softer.",min=0,max=2,step=.25,default=1})
def("Theme","theme_reset",{kind="button",name="Reset Theme",desc="Restores Cazielx Violet and default theme settings.",run=function()
for _,id in ipairs({"theme_accent","theme_bg","theme_panel","theme_border","theme_text","theme_sub"})do
S[id]=""
refreshViews(Feat[id])
end
S.theme_preset="Cazielx Violet"refreshViews(Feat.theme_preset)
setValue("theme_tr",0,true)setValue("ui_scale",1,true)setValue("anim_level",1,true)
applyTheme(true)
markDirty()
notify("Theme reset","good")
end})
def("Theme","theme_save",{kind="button",name="Save Theme",desc="Saves the theme with the configuration.",run=function()saveConfig(false)end})
def("Theme","loading_art",{kind="input",name="Loading Artwork",desc="Your own image: a Roblox asset ID you uploaded (digits or rbxassetid://) or an image file in the executor workspace (.png/.jpg/.webp, needs getcustomasset). Applied on the next launch; empty uses the built-in logo.",
placeholder="e.g. 1234567890 or nagi.png",default="",
validate=function(v)
if v:match("^%d+$")or v:match("^rbxassetid://%d+$")then return true end
local lv=v:lower()
return not v:find("..",1,true)and v:match("^[%w%._%-/ ]+$")~=nil and(lv:match("%.png$")~=nil or lv:match("%.jpe?g$")~=nil or lv:match("%.webp$")~=nil)
end})

local function isUrl(v)
return type(v)=="string"and#v<=300 and v:match("^https?://[%w%-%.]+[^%s]*$")~=nil
end
local function copyLink(v,what)
if type(v)~="string"or v==""then return false,what.." is empty. Set it above first."end
if HAS_CLIPBOARD and pcall(setclipboard,v)then
notify(what.." copied","good",2)
return
end
return false,"Clipboard is not available in this environment"
end
def("About","about_dev",{kind="input",name="Developer Credit",desc="Name shown on the About page.",placeholder="developer name",default="CAZIELX",
validate=function(v)return#v<=60 end})
def("About","about_src",{kind="input",name="Original Source Credit",desc="Who or what the original source came from. Left empty until you fill it in.",placeholder="original author or project",default="",
validate=function(v)return#v<=80 end})
def("About","about_discord",{kind="input",name="Discord Link",desc="Your invite link (http/https). Nothing is pre-filled.",placeholder="https://",default="",validate=isUrl})
def("About","about_social",{kind="input",name="Social Link",desc="Your social page link (http/https). Nothing is pre-filled.",placeholder="https://",default="",validate=isUrl})
def("About","about_link",{kind="input",name="Credit Link",desc="Link to the original source or credits page (http/https).",placeholder="https://",default="",validate=isUrl})
def("About","about_copy_discord",{kind="button",name="Copy Discord Link",desc="Copies the Discord link to the clipboard.",run=function()return copyLink(S.about_discord,"Discord link")end})
def("About","about_copy_social",{kind="button",name="Copy Social Link",desc="Copies the social link to the clipboard.",run=function()return copyLink(S.about_social,"Social link")end})
def("About","about_copy_credit",{kind="button",name="Copy Credit Link",desc="Copies the credit link to the clipboard.",run=function()return copyLink(S.about_link,"Credit link")end})
local function openLink(v,what)
if type(v)~="string"or v==""then return false,what.." is empty. Set it above first."end
if not isUrl(v)then return false,what.." is not a valid http(s) link"end
if pcall(function()GuiService:OpenBrowserWindow(v)end)then
notify("Opening "..what.."...","info",2)
return
end
if HAS_CLIPBOARD and pcall(setclipboard,v)then
notify("This environment cannot open a browser. "..what.." copied instead.","warn",4)
return
end
return false,"Cannot open links here and the clipboard is unavailable"
end
def("About","about_open_discord",{kind="button",name="Open Discord",desc="Opens the Discord link (falls back to copying it).",run=function()return openLink(S.about_discord,"Discord link")end})
def("About","about_open_social",{kind="button",name="Open Social",desc="Opens the social link (falls back to copying it).",run=function()return openLink(S.about_social,"Social link")end})
def("About","about_open_credit",{kind="button",name="Open Credit",desc="Opens the credit link (falls back to copying it).",run=function()return openLink(S.about_link,"Credit link")end})

phaseMark("theme application and diagnostics")
bootWarnings=0
local sessionStart=os.clock()

local function refreshAllViews()
for _,f in ipairs(FeatList)do refreshViews(f)end
end

applyTheme=function(animate)
computeTheme()
local j=0
for i=1,#bindings do
local b=bindings[i]
local o=b[1]
if o.Parent then
j+=1
bindings[j]=b
local v=T[b[3]]
if v~=nil then
if animate then tween(o,.3,{[b[2]]=v})else o[b[2]]=v end
end
end
end
for i=#bindings,j+1,-1 do bindings[i]=nil end
refreshIcons(animate)
refreshAllViews()
for _,t in ipairs(Tabs)do if t.setActive then t.setActive(t.isActive==true,animate)end end
if UI.onTheme then pcall(UI.onTheme)end
end

function preloadTheme(data)
if type(data)~="table"or type(data.state)~="table"then return end
for _,id in ipairs(THEME_IDS)do
local f,v=Feat[id],data.state[id]
if f and valid(f,v)then
if f.kind=="slider"then v=math.clamp(v,f.min,f.max)end
if f.kind=="color"then v=v:lower()end
S[id]=v
end
end
applyTheme(true)
end

local function formatNumber(n)
if type(n)~="number"then return"N/A"end
local a=math.abs(n)
local units={{1e15,"Qa"},{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}}
for _,u in ipairs(units)do
if a>=u[1]then return("%.2f%s"):format(n/u[1],u[2])end
end
return tostring(math.floor(n*100+.5)/100)
end
local function formatTime(sec)
sec=math.floor(sec)
return("%d:%02d:%02d"):format(math.floor(sec/3600),math.floor(sec%3600/60),sec%60)
end

local cashSamples,cashBase={},nil
fpsValue,frameCount,lastFpsAt=0,0,os.clock()
function sampleStats()
local now=os.clock()
local cash=getCash()
if cash then
if not cashBase then cashBase=cash end
local ses=V2.session
if ses.lastCash and cash>ses.lastCash then ses.earnings+=cash-ses.lastCash end
ses.lastCash=cash
cashSamples[#cashSamples+1]={now,cash}
while#cashSamples>60 do table.remove(cashSamples,1)end
end
end
local function cashPerSecond()
local attr=numAttr("CashPerSecond")
if attr then return attr end
local n=#cashSamples
if n<2 then return nil end
local first,last=cashSamples[math.max(1,n-30)],cashSamples[n]
local dt=last[1]-first[1]
if dt<1 then return nil end
return(last[2]-first[2])/dt
end
local function activeCount()
local n=0
for _,f in ipairs(FeatList)do if f.kind=="toggle"and S[f.id]then n+=1 end end
return n
end

local diagItems={}
diagItems[#diagItems+1]={label="Farm / Base",fn=function()return FarmInfo.base and(FarmInfo.base:GetFullName().." ("..tostring(FarmInfo.baseWhy)..")")or("not detected: "..tostring(FarmInfo.baseWhy))end}
diagItems[#diagItems+1]={label="Farm / Eggs",fn=function()return tostring(FarmInfo.eggs).." | "..tostring(FarmInfo.eggState)end}
diagItems[#diagItems+1]={label="Farm / Interaction",fn=function()return tostring(FarmInfo.interact)end}
diagItems[#diagItems+1]={label="Farm / Auto Break",fn=function()return tostring(FarmInfo.breakState)end}
diagItems[#diagItems+1]={label="Farm / Auto Farm",fn=function()return tostring(FarmInfo.status)end}
diagItems[#diagItems+1]={label="Farm / Egg types",fn=function()return tostring(FarmInfo.catalog)end}
diagItems[#diagItems+1]={label="Farm / Last Error",fn=function()return FarmInfo.errors[#FarmInfo.errors]or"none"end}
diagItems[#diagItems+1]={label="Scheduler / Tasks",fn=function()return V2.sched.count().." active, "..V2.sched.errors.." error(s)"end}
diagItems[#diagItems+1]={label="Scheduler / Last Error",fn=function()return V2.sched.lastErr end}
diagItems[#diagItems+1]={label="Pets / Obtained",fn=function()return V2.session.petTotal.." | best: "..V2.session.bestName end}
local function diagReport()
local lines={APP_NAME.." "..EDITION.." v"..VERSION.." build "..BUILD}
for _,it in ipairs(diagItems)do
local ok,val=pcall(it.fn)
lines[#lines+1]=it.label..": "..(ok and tostring(val)or"error")
end
return table.concat(lines,"\n")
end
def("Diagnostics","diag_refresh",{kind="button",name="Refresh Diagnostics",desc="Re-runs every check on this page.",run=function()
if UI.runLive then UI.runLive(true)end
notify("Diagnostics refreshed","good",1.6)
end})
def("Diagnostics","diag_copy",{kind="button",name="Copy Report",desc="Copies the diagnostics report (or shows it if clipboard is unavailable).",run=function()
local rep=diagReport()
if HAS_CLIPBOARD and pcall(setclipboard,rep)then notify("Report copied","good")
else notify("Clipboard unavailable. See Diagnostics page.","warn",5)end
end})

local function cazxEnvA()
return{Players=Players,UIS=UIS,Stats=Stats,Player=Player,APP_NAME=APP_NAME,EDITION=EDITION,VERSION=VERSION,BUILD=BUILD,CHANGELOG=CHANGELOG,IS_TOUCH=IS_TOUCH,HAS_FILES=HAS_FILES,HAS_CLIPBOARD=HAS_CLIPBOARD,HAS_FPSCAP=HAS_FPSCAP,HTTP_REQUEST=HTTP_REQUEST,FONT=FONT,MONO=MONO,S=S,UI=UI,POS=POS,Root=Root,ACCENT_SWATCHES=ACCENT_SWATCHES,T=T,hexColor=hexColor,bindings=bindings,pruneBindings=pruneBindings,tween=tween,new=new,round=round,stroke=stroke,text=text,Icons=Icons,CreateIcon=CreateIcon,SetIconColor=SetIconColor}
end
local function cazxEnvB()
return{SetIconState=SetIconState,DestroyIcon=DestroyIcon,iconHover=iconHover,Tabs=Tabs,TabByName=TabByName,FeatList=FeatList,valid=valid,setValue=setValue,V2=V2,gui=gui,WIN_W=WIN_W,WIN_H=WIN_H,TITLE_H=TITLE_H,SB_OPEN=SB_OPEN,SB_MIN=SB_MIN,ROW_H=ROW_H,TAB_H=TAB_H,state=state,uiRefs=uiRefs,tip=tip,bindTooltip=bindTooltip,beginDrag=beginDrag,isPress=isPress,getRemote=getRemote,numAttr=numAttr,getCash=getCash,FarmInfo=FarmInfo,WH=WH,whValidate=whValidate,formatNumber=formatNumber,formatTime=formatTime,cashPerSecond=cashPerSecond,activeCount=activeCount,diagItems=diagItems}
end
phaseMark("interface builder defined")
function buildInterface()

local EA,EB=cazxEnvA(),cazxEnvB()
local Players,UIS,Stats,Player,APP_NAME,EDITION,VERSION,BUILD,CHANGELOG,IS_TOUCH,HAS_FILES,HAS_CLIPBOARD,HAS_FPSCAP,HTTP_REQUEST,FONT,MONO=(EA).Players,(EA).UIS,(EA).Stats,(EA).Player,(EA).APP_NAME,(EA).EDITION,(EA).VERSION,(EA).BUILD,(EA).CHANGELOG,(EA).IS_TOUCH,(EA).HAS_FILES,(EA).HAS_CLIPBOARD,(EA).HAS_FPSCAP,(EA).HTTP_REQUEST,(EA).FONT,(EA).MONO
local S,UI,POS,Root,ACCENT_SWATCHES,T,hexColor,bindings,pruneBindings,tween,new,round,stroke,text,Icons,CreateIcon=(EA).S,(EA).UI,(EA).POS,(EA).Root,(EA).ACCENT_SWATCHES,(EA).T,(EA).hexColor,(EA).bindings,(EA).pruneBindings,(EA).tween,(EA).new,(EA).round,(EA).stroke,(EA).text,(EA).Icons,(EA).CreateIcon
local SetIconColor,SetIconState,DestroyIcon,iconHover,Tabs,TabByName,FeatList,valid,setValue,V2,gui,WIN_W,WIN_H,TITLE_H,SB_OPEN,SB_MIN=(EA).SetIconColor,(EB).SetIconState,(EB).DestroyIcon,(EB).iconHover,(EB).Tabs,(EB).TabByName,(EB).FeatList,(EB).valid,(EB).setValue,(EB).V2,(EB).gui,(EB).WIN_W,(EB).WIN_H,(EB).TITLE_H,(EB).SB_OPEN,(EB).SB_MIN
local ROW_H,TAB_H,state,uiRefs,tip,bindTooltip,beginDrag,isPress,getRemote,numAttr,getCash,FarmInfo,WH,whValidate,formatNumber,formatTime=(EB).ROW_H,(EB).TAB_H,(EB).state,(EB).uiRefs,(EB).tip,(EB).bindTooltip,(EB).beginDrag,(EB).isPress,(EB).getRemote,(EB).numAttr,(EB).getCash,(EB).FarmInfo,(EB).WH,(EB).whValidate,(EB).formatNumber,(EB).formatTime
local cashPerSecond,activeCount,diagItems=(EB).cashPerSecond,(EB).activeCount,(EB).diagItems
local win=new("Frame",{Name="Window",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
Size=UDim2.fromOffset(WIN_W,WIN_H),BackgroundColor3="Bg",BackgroundTransparency="Tr",BorderSizePixel=0,
Visible=false,ClipsDescendants=true,Active=true},gui)
round(win,12)stroke(win,"Accent",1.2,.5)
do
local wash=new("Frame",{Name="Wash",Size=UDim2.fromScale(1,1),BackgroundColor3="Accent",BackgroundTransparency=.9,BorderSizePixel=0,ZIndex=0},win)
round(wash,12)
new("UIGradient",{Rotation=35,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.5),NumberSequenceKeypoint.new(.4,1),NumberSequenceKeypoint.new(.72,1),NumberSequenceKeypoint.new(1,.55)})},wash)
for _,cfg in ipairs({{.86,120},{.62,36}})do
local streak=new("Frame",{Name="Streak",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(cfg[1],.5),Size=UDim2.fromOffset(cfg[2],900),Rotation=32,BackgroundColor3="Accent",BackgroundTransparency=.86,BorderSizePixel=0,ZIndex=0},win)
new("UIGradient",{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(1,1)})},streak)
end
end
local winScale=new("UIScale",{Scale=1},win)
UI.win,UI.winScale=win,winScale

local titleBar=new("Frame",{Size=UDim2.new(1,0,0,TITLE_H),BackgroundColor3="Panel",BackgroundTransparency="Tr",BorderSizePixel=0,Active=true},win)
new("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3="Border",BorderSizePixel=0},titleBar)
new("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)})},
new("Frame",{Size=UDim2.new(0,260,0,2),Position=UDim2.new(0,0,1,-2),BackgroundColor3="Accent",BorderSizePixel=0},titleBar))

local bw=IS_TOUCH and 38 or 34
local function ctrl(iconName,x,hoverKey)
local b=new("TextButton",{Text="",Size=UDim2.fromOffset(bw,30),Position=UDim2.new(1,x,.5,-15),
BackgroundColor3="Card",AutoButtonColor=false,BorderSizePixel=0},titleBar)
round(b,7)
local ic=CreateIcon(iconName,16,b,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5)})
b.MouseEnter:Connect(function()tween(b,.12,{BackgroundColor3=T[hoverKey or"CardHover"]})SetIconState(ic,"hover")end)
b.MouseLeave:Connect(function()tween(b,.15,{BackgroundColor3=T.Card})SetIconState(ic,"normal")end)
b.MouseButton1Down:Connect(function()tween(b,.06,{BackgroundColor3=T.AccentDim})end)
return b,ic
end
local btnClose=ctrl("close",-(bw+8),"Bad")
local btnMax,icMax=ctrl("expand",-(2*bw+12))
local icMaxAlt=CreateIcon("collapse",16,btnMax,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Visible=false})
local btnMin=ctrl("minimize",-(3*bw+16))
local btnUnload,icUnload=ctrl("stop",-(4*bw+20),"Bad")
local btnMenu=new("TextButton",{Text="",Size=UDim2.fromOffset(bw,30),Position=UDim2.new(0,8,.5,-15),
BackgroundColor3="Card",AutoButtonColor=false,BorderSizePixel=0},titleBar)
round(btnMenu,7)
local icMenu=CreateIcon("menu",16,btnMenu,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5)})
iconHover(btnMenu,icMenu)
bindTooltip(btnMenu,"Toggle sidebar")
bindTooltip(btnClose,"Close: hides the interface; features keep running")
bindTooltip(btnMax,"Expand or restore the window")
bindTooltip(btnMin,"Minimize: hides the window; features keep running")
bindTooltip(btnUnload,"Unload Hub: stops every feature and removes all UI")

CreateIcon("logo",22,titleBar,{Position=UDim2.new(0,14+bw,.5,-11)})
text(titleBar,APP_NAME,15,"Text",true,{Position=UDim2.fromOffset(46+bw,0),Size=UDim2.fromOffset(80,TITLE_H)})
text(titleBar,EDITION.."  v"..VERSION,10,"Accent",true,{Position=UDim2.fromOffset(122+bw,0),Size=UDim2.fromOffset(110,TITLE_H)})
local activeLbl=text(titleBar,"0 active",11,"Sub",false,{Position=UDim2.fromOffset(232+bw,0),Size=UDim2.fromOffset(90,TITLE_H)})
updateActive=function()
local n=activeCount()
activeLbl.Text=n.." active"
if UI.sbSub then UI.sbSub.Text=n>0 and(n.." feature"..(n==1 and""or"s").." running")or"Ready to use!"end
end

local body=new("Frame",{Position=UDim2.fromOffset(0,TITLE_H),Size=UDim2.new(1,0,1,-TITLE_H),BackgroundTransparency=1,ClipsDescendants=true},win)
local sbW=state.sb and SB_OPEN or SB_MIN
local sidebar=new("Frame",{Size=UDim2.new(0,sbW,1,0),BackgroundColor3="Panel",BackgroundTransparency="Tr",BorderSizePixel=0,ClipsDescendants=true},body)
new("Frame",{Size=UDim2.new(0,1,1,0),Position=UDim2.new(1,-1,0,0),BackgroundColor3="Border",BorderSizePixel=0},sidebar)
local sideList=new("ScrollingFrame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,
ScrollBarThickness=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new()},sidebar)
new("UIListLayout",{Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder},sideList)
new("UIPadding",{PaddingTop=UDim.new(0,8),PaddingLeft=UDim.new(0,5),PaddingBottom=UDim.new(0,62)},sideList)
do
local st=new("Frame",{AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,6,1,-8),Size=UDim2.new(1,-13,0,44),BackgroundColor3="Card",BackgroundTransparency="Tr",BorderSizePixel=0,ZIndex=3},sidebar)
round(st,10)stroke(st,"Good",1,.6)
local dot=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(18,22),Size=UDim2.fromOffset(10,10),BackgroundColor3="Good",BorderSizePixel=0,ZIndex=4},st)
round(dot,5)
local halo=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(18,22),Size=UDim2.fromOffset(18,18),BackgroundColor3="Good",BackgroundTransparency=.8,BorderSizePixel=0,ZIndex=3},st)
round(halo,9)
local grp=new("Frame",{Position=UDim2.fromOffset(34,0),Size=UDim2.new(1,-34,1,0),BackgroundTransparency=1,Visible=state.sb,ZIndex=4},st)
text(grp,"Status",11,"Text",true,{Position=UDim2.fromOffset(0,7),Size=UDim2.new(1,-4,0,15),ZIndex=4})
UI.sbSub=text(grp,"Ready to use!",10,"Good",false,{Position=UDim2.fromOffset(0,22),Size=UDim2.new(1,-4,0,14),ZIndex=4})
UI.sbText=grp
end
local content=new("Frame",{Position=UDim2.fromOffset(sbW,0),Size=UDim2.new(1,-sbW,1,0),BackgroundTransparency=1},body)

local searchCard=new("Frame",{Position=UDim2.fromOffset(10,8),Size=UDim2.new(1,-22,0,34),BackgroundColor3="Card",BackgroundTransparency="Tr",BorderSizePixel=0},content)
round(searchCard,9)
local searchStroke=stroke(searchCard,"Border",1,.2)
local icSearch=CreateIcon("search",16,searchCard,{Position=UDim2.fromOffset(10,9)})
local searchBox=new("TextBox",{Position=UDim2.fromOffset(34,0),Size=UDim2.new(1,-70,1,0),BackgroundTransparency=1,
Text="",PlaceholderText="Search features...",PlaceholderColor3="Sub",TextColor3="Text",Font=FONT,
TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,ClearTextOnFocus=false,BorderSizePixel=0},searchCard)
local clearBtn=new("TextButton",{Text="",Size=UDim2.fromOffset(30,34),Position=UDim2.new(1,-32,0,0),BackgroundTransparency=1,Visible=false},searchCard)
local icClear=CreateIcon("close",12,clearBtn,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5)})
iconHover(clearBtn,icClear)
searchBox.Focused:Connect(function()tween(searchStroke,.15,{Color=T.Accent})SetIconState(icSearch,"active")end)
searchBox.FocusLost:Connect(function()tween(searchStroke,.15,{Color=T.Border})SetIconState(icSearch,"normal")end)
clearBtn.Activated:Connect(function()searchBox.Text=""end)

local host=new("Frame",{Position=UDim2.fromOffset(0,48),Size=UDim2.new(1,0,1,-48),BackgroundTransparency=1,ClipsDescendants=true},content)

local function dims()
if state.max then
local vp,s=gui.AbsoluteSize,baseScale()
return math.floor((vp.X-12)/s),math.floor((vp.Y-12)/s)
end
return WIN_W,WIN_H
end
local FLOAT_SZ=46
local function vpSize()
local v=gui.AbsoluteSize
if v.X<10 or v.Y<10 then return Vector2.new(1280,720)end
return v
end
local function axis(f,half,vp)
local lo,hi=half/vp,1-half/vp
if lo>=hi then return.5 end
return math.clamp(f,lo,hi)
end
local function placeWin(animate)
local fx,fy=.5,.5
if not state.max then
local vp,s=vpSize(),baseScale()
local w,h=dims()
POS.win.x=axis(POS.win.x,w*s/2,vp.X)
POS.win.y=axis(POS.win.y,h*s/2,vp.Y)
fx,fy=POS.win.x,POS.win.y
end
local target=UDim2.fromScale(fx,fy)
if animate then tween(win,.26,{Position=target},Enum.EasingStyle.Quint)else win.Position=target end
end
local function applySize(animate)
local w,h=dims()
local goal=UDim2.fromOffset(w,h)
if animate then tween(win,.26,{Size=goal},Enum.EasingStyle.Quint)else win.Size=goal end
placeWin(animate)
end

local float=new("TextButton",{Text="",Size=UDim2.fromOffset(FLOAT_SZ,FLOAT_SZ),AnchorPoint=Vector2.new(.5,.5),
Position=UDim2.fromScale(.5,.5),BackgroundColor3="Bg",AutoButtonColor=false,BorderSizePixel=0,Visible=false,ZIndex=60},gui)
round(float,23)stroke(float,"Accent",1.5,.15)
local cxLabel=text(float,"CX",17,"Accent",true,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1,1),ZIndex=61})
local floatScale=new("UIScale",{Scale=1},float)
local function floatTo(sc)if float.Parent then tween(floatScale,.12,{Scale=sc})end end
float.MouseEnter:Connect(function()floatTo(1.08)end)
float.MouseLeave:Connect(function()floatTo(1)end)
float.InputBegan:Connect(function(i)if isPress(i)then floatTo(.92)end end)
float.InputEnded:Connect(function(i)if isPress(i)then floatTo(1)end end)
local function placeFloat()
local vp,half=vpSize(),FLOAT_SZ/2
local fx=POS.float.x<0 and(38/vp.X)or POS.float.x
fx=axis(fx,half,vp.X)
if POS.float.x>=0 then POS.float.x=fx end
POS.float.y=axis(POS.float.y,half,vp.Y)
float.Position=UDim2.fromScale(fx,POS.float.y)
end
placeAll=function()placeWin(false)placeFloat()end
UI.place=placeAll

applyScale=function()
local s=baseScale()
if state.open then winScale.Scale=s end
notifScale.Scale=math.clamp(s,.7,1)
applySize(false)
placeFloat()
end
UI.float=float

local function openWindow()
state.open=true
win.Visible=true
local s=baseScale()
winScale.Scale=s*.88
tween(winScale,.3,{Scale=s},Enum.EasingStyle.Back)
float.Visible=false
placeWin(false)
if UI.runLive then task.defer(UI.runLive,true)end
end
local function hideWindow(mode)
state.open=false
tip.Visible=false
tween(winScale,.18,{Scale=baseScale()*.88})
task.delay(.2,function()if not state.open and win.Parent then win.Visible=false end end)
if mode=="min"or IS_TOUCH then
placeFloat()
float.Visible=true
float.BackgroundTransparency=mode=="min"and 0 or.55
float.Size=UDim2.fromOffset(0,0)
tween(float,.3,{Size=UDim2.fromOffset(46,46)},Enum.EasingStyle.Back)
end
if mode=="close"then
notify(IS_TOUCH and"Interface closed. Tap the faded button to reopen."or("Interface closed. Press "..tostring(S.toggle_key or"RightShift").." to reopen."),"info",3)
end
end
local function toggleWindow()if state.open then hideWindow("min")else openWindow()end end
UI.openWindow,UI.toggleWindow=openWindow,toggleWindow

btnClose.Activated:Connect(function()hideWindow("close")end)
btnMin.Activated:Connect(function()hideWindow("min")end)
btnMax.Activated:Connect(function()
state.max=not state.max
icMax.root.Visible=not state.max
icMaxAlt.root.Visible=state.max
applySize(true)
task.delay(.28,function()if alive then placeWin(false)end end)
end)
local unloadToken=0
btnUnload.Activated:Connect(function()
if state.unloadArmed then
task.defer(V2.unloadNow)
return
end
state.unloadArmed=true
unloadToken+=1
local mine=unloadToken
SetIconColor(icUnload,T.Bad)
notify("Tap Unload again within 4 seconds to remove the hub","warn",4)
task.delay(4,function()
if mine==unloadToken and alive then
state.unloadArmed=false
SetIconColor(icUnload,nil)
end
end)
end)

local function applySidebar(animate)
local w=state.sb and SB_OPEN or SB_MIN
if UI.sbText then UI.sbText.Visible=state.sb end
local p1,p2={Size=UDim2.new(0,w,1,0)},{Position=UDim2.fromOffset(w,0),Size=UDim2.new(1,-w,1,0)}
if animate then
tween(sidebar,.22,p1,Enum.EasingStyle.Quint)
tween(content,.22,p2,Enum.EasingStyle.Quint)
else
for k,v in pairs(p1)do sidebar[k]=v end
for k,v in pairs(p2)do content[k]=v end
end
end
UI.applySidebar=applySidebar
btnMenu.Activated:Connect(function()state.sb=not state.sb applySidebar(true)end)

local function savePos()if markDirty then markDirty()end end
titleBar.InputBegan:Connect(function(input)
if not isPress(input)or state.max then return end
local startIn,sx,sy=input.Position,POS.win.x,POS.win.y
beginDrag(input,function(pos)
local d,vp=pos-startIn,vpSize()
POS.win.x,POS.win.y=sx+d.X/vp.X,sy+d.Y/vp.Y
placeWin(false)
end,savePos)
end)
float.InputBegan:Connect(function(input)
if not isPress(input)then return end
local startIn,moved=input.Position,false
local vp0=vpSize()
local sx=POS.float.x<0 and(38/vp0.X)or POS.float.x
local sy=POS.float.y
beginDrag(input,function(pos)
local d,vp=pos-startIn,vpSize()
if d.Magnitude>6 then moved=true end
if moved then
POS.float.x,POS.float.y=sx+d.X/vp.X,sy+d.Y/vp.Y
placeFloat()
end
end,function()if moved then savePos()else openWindow()end end)
end)

Root.add(UIS.InputBegan:Connect(function(input,gp)
if gp then return end
local ok,key=pcall(function()return Enum.KeyCode[S.toggle_key or"RightShift"]end)
if ok and input.KeyCode==key then
if state.open then hideWindow("min")else openWindow()end
end
end))
Root.add(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()applyScale()end))
Root.add(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()task.defer(function()if alive then applyScale()end end)end))

local function makeCard(parent,h)
local c=new("Frame",{Size=UDim2.new(1,0,0,h),BackgroundColor3="Card",BackgroundTransparency="Tr",
BorderSizePixel=0,LayoutOrder=#parent:GetChildren()},parent)
round(c,9)
new("UIGradient",{Rotation=0,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,.22)})},c)
return c,stroke(c,"Border",1,.2)
end
local function attachFx(card,st,hit)
if hit:IsA("GuiButton")then
hit.MouseButton1Down:Connect(function()tween(card,.08,{BackgroundColor3=T.AccentDim})end)
hit.MouseButton1Up:Connect(function()tween(card,.12,{BackgroundColor3=IS_TOUCH and T.Card or T.CardHover})end)
end
if not IS_TOUCH then
hit.MouseEnter:Connect(function()tween(card,.12,{BackgroundColor3=T.CardHover})tween(st,.12,{Color=T.Accent})end)
end
hit.MouseLeave:Connect(function()tween(card,.15,{BackgroundColor3=T.Card})tween(st,.15,{Color=T.Border})end)
end
local function nameDesc(card,f,rightPad)
local py=math.floor((ROW_H-36)/2)
local dim=f.unavailable~=nil
text(card,f.name,13,dim and"Sub"or"Text",true,{Position=UDim2.fromOffset(12,py),Size=UDim2.new(1,-rightPad,0,18)})
text(card,f.desc or"",11,"Sub",false,{Position=UDim2.fromOffset(12,py+19),Size=UDim2.new(1,-rightPad,0,16),TextTransparency=dim and.35 or 0})
end
local function tipFor(f)
return(f.desc or"")..(f.unavailable and("\n[!] "..f.unavailable)or"")
end

local function buildToggle(f,parent)
local card,st=makeCard(parent,ROW_H)
nameDesc(card,f,176)
local status=text(card,"OFF",10,T.Sub,true,{Position=UDim2.new(1,-166,0,0),Size=UDim2.new(0,106,1,0),TextXAlignment=Enum.TextXAlignment.Right})
local track=new("Frame",{Size=UDim2.fromOffset(40,20),Position=UDim2.new(1,-50,.5,-10),BackgroundColor3=T.Off,BorderSizePixel=0},card)
round(track,10)
local knob=new("Frame",{Size=UDim2.fromOffset(14,14),Position=UDim2.new(0,3,.5,-7),BackgroundColor3="OnAccent",BorderSizePixel=0},track)
round(knob,7)
local hit=new("TextButton",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",AutoButtonColor=false},card)
attachFx(card,st,hit)
bindTooltip(hit,tipFor(f))
hit.Activated:Connect(function()
if f.unavailable then notify(f.name..": "..f.unavailable,"warn",4)return end
setValue(f.id,not S[f.id])
end)
local function update(instant)
local on=S[f.id]==true
local nav=f.unavailable~=nil
local col=(not nav and on)and T.Accent or T.Off
local kp=on and UDim2.new(1,-17,.5,-7)or UDim2.new(0,3,.5,-7)
if instant then track.BackgroundColor3=col knob.Position=kp
else tween(track,.16,{BackgroundColor3=col})tween(knob,.16,{Position=kp},Enum.EasingStyle.Back)end
status.Text=nav and(f.badge or"UNAVAILABLE")or(on and"ON"or"OFF")
status.TextColor3=nav and T.Warn or(on and T.Good or T.Sub)
end
return card,update
end

local function fmt(f,v)if(f.step or 1)<1 then return("%.2f"):format(v)end return tostring(v)end

local function buildSlider(f,parent)
local card,st=makeCard(parent,ROW_H+22)
nameDesc(card,f,110)
local py=math.floor((ROW_H-36)/2)
local valLbl=text(card,"",12,"Accent",true,{Position=UDim2.new(1,-92,0,py),Size=UDim2.new(0,80,0,18),TextXAlignment=Enum.TextXAlignment.Right})
local track=new("Frame",{Position=UDim2.new(0,12,0,ROW_H+4),Size=UDim2.new(1,-24,0,6),BackgroundColor3="Off",BorderSizePixel=0},card)
round(track,3)
local fill=new("Frame",{Size=UDim2.fromScale(0,1),BackgroundColor3=T.Accent,BorderSizePixel=0},track)
round(fill,3)
local knob=new("Frame",{Size=UDim2.fromOffset(14,14),AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(0,0,.5,0),BackgroundColor3="Text",BorderSizePixel=0},track)
round(knob,7)
local hit=new("TextButton",{Position=UDim2.new(0,0,0,ROW_H-8),Size=UDim2.new(1,0,0,30),BackgroundTransparency=1,Text="",AutoButtonColor=false},card)
attachFx(card,st,card)
bindTooltip(hit,tipFor(f))
local function setFromX(x)
local r=math.clamp((x-track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1),0,1)
setValue(f.id,f.min+(f.max-f.min)*r)
end
hit.InputBegan:Connect(function(input)
if not isPress(input)then return end
if f.unavailable then notify(f.name..": "..f.unavailable,"warn",4)return end
parent.ScrollingEnabled=false
setFromX(input.Position.X)
beginDrag(input,function(pos)setFromX(pos.X)end,function()parent.ScrollingEnabled=true end)
end)
local function update()
local r=(S[f.id]-f.min)/(f.max-f.min)
fill.Size=UDim2.fromScale(r,1)
knob.Position=UDim2.new(r,0,.5,0)
valLbl.Text=f.unavailable and"N/A"or fmt(f,S[f.id])
fill.BackgroundColor3=f.unavailable and T.Off or T.Accent
end
return card,update
end

local function buildDropdown(f,parent)
local n=#f.options
local isOpen=false
local card,st=makeCard(parent,ROW_H)
card.ClipsDescendants=true
nameDesc(card,f,160)
attachFx(card,st,card)
local btn=new("TextButton",{Position=UDim2.new(1,-138,0,(ROW_H-30)/2),Size=UDim2.fromOffset(126,30),BackgroundColor3="Bg",
Text="",AutoButtonColor=false,BorderSizePixel=0},card)
round(btn,7)stroke(btn,"Border",1,.1)
local valLbl=text(btn,"",12,"Text",true,{Position=UDim2.fromOffset(8,0),Size=UDim2.new(1,-28,1,0)})
local chev=CreateIcon("chevron",14,btn,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(1,-14,.5,0)})
SetIconState(chev,"active")
bindTooltip(btn,tipFor(f))
local optBtns={}
local function setOpen(o)
isOpen=o
tween(chev.root,.18,{Rotation=o and 180 or 0})
tween(card,.2,{Size=UDim2.new(1,0,0,o and(ROW_H+n*32+6)or ROW_H)},Enum.EasingStyle.Quint)
end
for i,opt in ipairs(f.options)do
local ob=new("TextButton",{Position=UDim2.new(0,10,0,ROW_H+(i-1)*32),Size=UDim2.new(1,-20,0,28),BackgroundColor3=T.Bg,
Text=opt,TextColor3=T.Sub,Font=FONT,TextSize=12,AutoButtonColor=false,BorderSizePixel=0},card)
round(ob,7)
ob.Activated:Connect(function()setValue(f.id,opt)setOpen(false)end)
optBtns[opt]=ob
end
btn.Activated:Connect(function()
if f.unavailable then notify(f.name..": "..f.unavailable,"warn",4)return end
setOpen(not isOpen)
end)
local function update()
valLbl.Text=f.unavailable and"N/A"or tostring(S[f.id])
for opt,ob in pairs(optBtns)do
local sel=S[f.id]==opt
ob.TextColor3=sel and T.Text or T.Sub
tween(ob,.12,{BackgroundColor3=sel and T.AccentDim or T.Bg})
end
end
return card,update
end

local function buildButton(f,parent)
local card,st=makeCard(parent,ROW_H)
nameDesc(card,f,100)
local nav=f.unavailable~=nil
local pill=new("Frame",{Size=UDim2.fromOffset(62,26),Position=UDim2.new(1,-74,.5,-13),BackgroundColor3=nav and T.Off or T.AccentDim,BorderSizePixel=0},card)
round(pill,7)
local lbl=text(pill,nav and"N/A"or"RUN",11,T.Text,true,{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center})
local hit=new("TextButton",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",AutoButtonColor=false},card)
attachFx(card,st,hit)
bindTooltip(hit,tipFor(f))
hit.Activated:Connect(function()
if f.unavailable then notify(f.name..": "..f.unavailable,"warn",4)return end
local ok,r1,r2=pcall(f.run)
if not ok then notify("Error: "..tostring(r1),"bad",4)
elseif r1==false then notify(r2 or"Action failed","warn",4)end
end)
return card,function()pill.BackgroundColor3=nav and T.Off or T.AccentDim lbl.TextColor3=T.Text end
end

local function buildInput(f,parent)
local card,st=makeCard(parent,ROW_H+36)
nameDesc(card,f,20)
local box=new("TextBox",{Position=UDim2.fromOffset(10,ROW_H),Size=UDim2.new(1,-20,0,28),BackgroundColor3="Bg",Text="",
PlaceholderText=f.placeholder or"",PlaceholderColor3="Sub",TextColor3="Text",Font=MONO,TextSize=12,
ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Left,ClipsDescendants=true,BorderSizePixel=0},card)
round(box,7)
local bs=stroke(box,"Border",1,.1)
new("UIPadding",{PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)},box)
attachFx(card,st,card)
local function current()
if f.private then return f.get()end
return S[f.id]or""
end
local function shown()
local v=current()
if f.mask and not box:IsFocused()then return f.mask(v)end
return v
end
box.Focused:Connect(function()
box.Text=current()
tween(bs,.15,{Color=T.Accent})
end)
box.FocusLost:Connect(function()
tween(bs,.15,{Color=T.Border})
local v=box.Text:match("^%s*(.-)%s*$")
if v~=current()then
if f.private then
local ok,msg=f.set(v)
if ok==false then notify(msg or"Invalid value","warn",4)end
elseif not setValue(f.id,v)then
notify(f.name..": invalid value","warn",4)
end
end
box.Text=shown()
end)
return card,function()if not box:IsFocused()then box.Text=shown()end end
end

local function buildTextbox(f,parent)
local card=makeCard(parent,120)
text(card,f.name,13,"Text",true,{Position=UDim2.fromOffset(12,7),Size=UDim2.new(1,-24,0,18)})
text(card,f.desc or"",11,"Sub",false,{Position=UDim2.fromOffset(12,25),Size=UDim2.new(1,-24,0,16)})
local box=new("TextBox",{Position=UDim2.fromOffset(10,46),Size=UDim2.new(1,-20,0,66),BackgroundColor3="Bg",TextColor3="Text",
PlaceholderText="Press Export, or paste config JSON here and press Import",PlaceholderColor3="Sub",Text="",Font=MONO,
TextSize=11,MultiLine=true,TextWrapped=true,ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Left,
TextYAlignment=Enum.TextYAlignment.Top,BorderSizePixel=0},card)
round(box,7)
new("UIPadding",{PaddingLeft=UDim.new(0,6),PaddingRight=UDim.new(0,6),PaddingTop=UDim.new(0,4)},box)
uiRefs.configBox=box
return card,function()end
end

local function buildColor(f,parent)
local sw=IS_TOUCH and 30 or 26
local card,st=makeCard(parent,ROW_H+(f.palette and 38 or 0))
nameDesc(card,f,210)
attachFx(card,st,card)
local swatch=new("Frame",{Size=UDim2.fromOffset(24,24),Position=UDim2.new(1,-132,0,(ROW_H-24)/2),BackgroundColor3=T[f.key],BorderSizePixel=0},card)
round(swatch,7)stroke(swatch,"Border",1,0)
local box=new("TextBox",{Position=UDim2.new(1,-100,0,(ROW_H-28)/2),Size=UDim2.fromOffset(88,28),BackgroundColor3="Bg",Text="",
PlaceholderText="Auto",PlaceholderColor3="Sub",TextColor3="Text",Font=MONO,TextSize=12,ClearTextOnFocus=false,BorderSizePixel=0},card)
round(box,7)stroke(box,"Border",1,.1)
box.FocusLost:Connect(function()
local v=box.Text:match("^%s*(.-)%s*$")
if v~=""and v:sub(1,1)~="#"then v="#"..v end
if v~=""and not hexColor(v)then
notify("Invalid color. Use #RRGGBB","warn",3)
box.Text=S[f.id]
return
end
setValue(f.id,v)
end)
if f.palette then
for i,hex in ipairs(ACCENT_SWATCHES)do
local b=new("TextButton",{Text="",Size=UDim2.fromOffset(sw,sw),Position=UDim2.new(0,12+(i-1)*(sw+6),0,ROW_H+3),
BackgroundColor3=Color3.fromHex(hex),AutoButtonColor=false,BorderSizePixel=0},card)
round(b,sw/2)stroke(b,"Border",1,0)
b.Activated:Connect(function()setValue(f.id,hex)end)
end
end
return card,function()swatch.BackgroundColor3=hexColor(S[f.id])or T[f.key]box.Text=S[f.id]end
end

local builders={toggle=buildToggle,slider=buildSlider,dropdown=buildDropdown,button=buildButton,textbox=buildTextbox,color=buildColor,input=buildInput}
local function buildRow(f,parent)
local row,update=builders[f.kind](f,parent)
f.views[row]=update
row.Destroying:Connect(function()f.views[row]=nil end)
update(true)
return row
end

local function newPage()
local p=new("ScrollingFrame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,
ScrollBarThickness=IS_TOUCH and 5 or 3,ScrollBarImageColor3="Accent",AutomaticCanvasSize=Enum.AutomaticSize.Y,
CanvasSize=UDim2.new(),ScrollingDirection=Enum.ScrollingDirection.Y,Visible=false,
ElasticBehavior=Enum.ElasticBehavior.WhenScrollable},host)
new("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},p)
new("UIPadding",{PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,14),PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,12)},p)
return p
end

local currentPage,searchPage
local function showPage(p,animate)
tip.Visible=false
if currentPage and currentPage~=p then currentPage.Visible=false end
currentPage=p
p.Visible=true
if animate then
p.Position=UDim2.fromOffset(0,16)
tween(p,.22,{Position=UDim2.fromOffset(0,0)},Enum.EasingStyle.Quint)
else
p.Position=UDim2.fromOffset(0,0)
end
if UI.runLive then task.defer(UI.runLive)end
end
UI.currentPage=function()return currentPage end

switchTab=function(name,instant)
local t=TabByName[name]
if not t or not t.page then return end
S._tab=name
for _,tt in ipairs(Tabs)do
tt.isActive=tt==t
if tt.setActive then tt.setActive(tt.isActive,not instant)end
end
if currentPage~=searchPage then showPage(t.page,not instant)end
markDirty()
end

local function buildTab(t)
local btn=new("TextButton",{Size=UDim2.new(1,-10,0,TAB_H),BackgroundColor3="Card",BackgroundTransparency=1,
Text="",AutoButtonColor=false,BorderSizePixel=0,LayoutOrder=#sideList:GetChildren()},sideList)
round(btn,9)
local pill=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3="Accent",BackgroundTransparency=1,BorderSizePixel=0},btn)
round(pill,9)
new("UIGradient",{Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(.72,.72,.78))},pill)
local ic=CreateIcon(t.icon,18,btn,{Position=UDim2.fromOffset((SB_MIN-10-18)/2,(TAB_H-18)/2)})
local nameLbl=text(btn,t.name,12,T.Sub,true,{Position=UDim2.fromOffset(SB_MIN-10,0),Size=UDim2.new(1,-(SB_MIN-10),1,0)})
t.setActive=function(on,animate)
nameLbl.TextColor3=on and T.OnAccent or T.Sub
SetIconState(ic,on and"active"or"normal")
if on then SetIconColor(ic,T.OnAccent)end
local goal=on and.06 or 1
if animate then tween(pill,.2,{BackgroundTransparency=goal})else pill.BackgroundTransparency=goal end
end
btn.MouseEnter:Connect(function()
if t.isActive or IS_TOUCH then return end
tween(btn,.12,{BackgroundTransparency=.6})
SetIconState(ic,"hover")
end)
btn.MouseLeave:Connect(function()
if t.isActive then return end
tween(btn,.15,{BackgroundTransparency=1})
SetIconState(ic,"normal")
end)
bindTooltip(btn,t.name)
btn.Activated:Connect(function()
if searchBox.Text~=""then searchBox.Text=""end
switchTab(t.name)
end)
end

local searchToken=0
local function emptyState(parent,msg)
local c=new("Frame",{Size=UDim2.new(1,0,0,96),BackgroundTransparency=1,LayoutOrder=5},parent)
local ic=CreateIcon("search",26,c,{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,14)})
SetIconState(ic,"disabled")
text(c,msg,12,"Sub",false,{Position=UDim2.fromOffset(0,50),Size=UDim2.new(1,0,0,24),TextXAlignment=Enum.TextXAlignment.Center})
end
local function runSearch()
tip.Visible=false
local q=searchBox.Text:lower():match("^%s*(.-)%s*$")
clearBtn.Visible=searchBox.Text~=""
for _,c in ipairs(searchPage:GetChildren())do
if c:IsA("GuiObject")then
for _,d in ipairs(c:GetDescendants())do
for _,ic in ipairs(Icons)do if ic.root==d then DestroyIcon(ic)break end end
end
c:Destroy()
end
end
pruneBindings()
if q==""then
if currentPage==searchPage then showPage(TabByName[S._tab].page,false)end
return
end
text(searchPage,"SEARCH RESULTS",11,"Accent",true,{Size=UDim2.new(1,0,0,20),LayoutOrder=0})
local n=0
for _,f in ipairs(FeatList)do
if f.kind~="textbox"and n<30 and((f.name:lower():find(q,1,true))or((f.desc or""):lower():find(q,1,true))or f.tab:lower():find(q,1,true))then
buildRow(f,searchPage)
n+=1
end
end
if n==0 then emptyState(searchPage,"No features found.")end
showPage(searchPage,false)
end
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
clearBtn.Visible=searchBox.Text~=""
searchToken+=1
local mine=searchToken
task.delay(.18,function()if mine==searchToken and alive then runSearch()end end)
end)

local liveFns={}
local function runLive(force)
if not alive or not state.open then return end
local page=currentPage
for _,l in ipairs(liveFns)do
if force or l.page==page then pcall(l.fn)end
end
end
UI.runLive=runLive
UI.onTheme=function()runLive(true)if UI.themeLbl then UI.themeLbl.Text=(S.theme_preset or"Cazielx Violet")end end

local function statGrid(parent,order)
local g=new("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=order},parent)
new("UIGridLayout",{CellSize=UDim2.new(.5,-4,0,50),CellPadding=UDim2.fromOffset(8,8),SortOrder=Enum.SortOrder.LayoutOrder},g)
return g
end
local function statTile(grid,page,label,getFn,tipText)
local c=new("Frame",{BackgroundColor3="Card",BackgroundTransparency="Tr",BorderSizePixel=0,LayoutOrder=#grid:GetChildren()},grid)
round(c,9)stroke(c,"Border",1,.2)
text(c,label:upper(),9,"Sub",true,{Position=UDim2.fromOffset(10,7),Size=UDim2.new(1,-20,0,12)})
local v=text(c,"",13,T.Text,true,{Position=UDim2.fromOffset(10,22),Size=UDim2.new(1,-20,0,20)})
local function update()
local ok,val,col=pcall(getFn)
v.Text=ok and tostring(val)or"N/A"
v.TextColor3=(ok and col and T[col])or T.Text
end
liveFns[#liveFns+1]={page=page,fn=update}
c.Destroying:Connect(function()
for i,l in ipairs(liveFns)do if l.fn==update then table.remove(liveFns,i)break end end
end)
bindTooltip(c,tipText)
update()
return c
end
local function sectionLabel(parent,label,order)
return text(parent,label,11,"Accent",true,{Size=UDim2.new(1,0,0,20),LayoutOrder=order})
end
local function cashText(getter,fmtFn)
return function()
local v=getter()
if v==nil then return"Not provided by game","Warn"end
return fmtFn and fmtFn(v)or formatNumber(v)
end
end

local function buildHome(page)
local hero=new("Frame",{Size=UDim2.new(1,0,0,156),BackgroundColor3="Card",BackgroundTransparency="Tr",BorderSizePixel=0,LayoutOrder=1,ClipsDescendants=true},page)
round(hero,14)stroke(hero,"Accent",1.2,.5)
local orb=new("Frame",{AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,70,.5,0),Size=UDim2.fromOffset(280,280),BackgroundColor3="Accent",BackgroundTransparency=.88,BorderSizePixel=0},hero)
round(orb,140)
local mark=CreateIcon("logo",38,hero,{Position=UDim2.fromOffset(18,14)})
SetIconState(mark,"active")
text(hero,"Welcome to",12,"Sub",false,{Position=UDim2.fromOffset(18,56),Size=UDim2.new(1,-170,0,16)})
text(hero,"CazielX Hub!",26,"Text",true,{Position=UDim2.fromOffset(18,70),Size=UDim2.new(1,-170,0,32)})
text(hero,"Your ultimate Roblox script hub, built for the best experience.",11,"Sub",false,{Position=UDim2.fromOffset(18,104),Size=UDim2.new(1,-170,0,14)})
local explore=new("TextButton",{Position=UDim2.fromOffset(18,124),Size=UDim2.fromOffset(150,26),BackgroundColor3="Accent",Text="Explore Features",TextSize=11,
Font=BOLD,TextColor3="OnAccent",AutoButtonColor=false,BorderSizePixel=0,TextXAlignment=Enum.TextXAlignment.Left},hero)
round(explore,8)
new("UIPadding",{PaddingLeft=UDim.new(0,14)},explore)
local exploreArrow=CreateIcon("arrow",14,explore,{AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-10,.5,0)})
SetIconColor(exploreArrow,T.OnAccent)
explore.MouseEnter:Connect(function()tween(explore,.12,{BackgroundColor3=T.Accent:Lerp(Color3.new(1,1,1),.14)})end)
explore.MouseLeave:Connect(function()tween(explore,.15,{BackgroundColor3=T.Accent})end)
explore.Activated:Connect(function()switchTab("Farm")end)

local frame=new("Frame",{Size=UDim2.fromOffset(84,84),Position=UDim2.new(1,-112,0,12),BackgroundColor3="Bg",BorderSizePixel=0},hero)
round(frame,42)stroke(frame,"Accent",1.5,.15)
local img=new("ImageLabel",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Image="",ScaleType=Enum.ScaleType.Crop,BorderSizePixel=0,ImageTransparency=1},frame)
round(img,42)
local initial=text(frame,(Player.DisplayName:sub(1,1)or"?"):upper(),30,"Accent",true,{Size=UDim2.new(1,0,1,-12),TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center})
local msg=text(frame,"Loading",10,"Sub",true,{Position=UDim2.new(0,0,1,-26),Size=UDim2.new(1,0,0,16),TextXAlignment=Enum.TextXAlignment.Center})
local retry=new("TextButton",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",AutoButtonColor=false},frame)
text(hero,Player.DisplayName,13,"Text",true,{Position=UDim2.new(1,-134,0,100),Size=UDim2.fromOffset(124,16),TextXAlignment=Enum.TextXAlignment.Center})
text(hero,"@"..Player.Name,10,"Sub",false,{Position=UDim2.new(1,-134,0,116),Size=UDim2.fromOffset(124,14),TextXAlignment=Enum.TextXAlignment.Center})
local chip=new("Frame",{Position=UDim2.new(1,-114,0,134),Size=UDim2.fromOffset(84,16),BackgroundColor3="AccentDim",BorderSizePixel=0},hero)
round(chip,8)
text(chip,"SCRIPT ACTIVE",8,"Good",true,{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center})

local av={busy=false,status="loading"}
UI.avatar=av
local function fetchAvatar()
if av.busy then return end
av.busy=true
av.status="loading"
if img.Image==""then msg.Visible=true msg.Text="Loading"initial.Visible=true end
task.spawn(function()
local content,ready
for attempt=1,4 do
if not alive then break end
local ok,c,r=pcall(function()
return Players:GetUserThumbnailAsync(Player.UserId,Enum.ThumbnailType.AvatarBust,Enum.ThumbnailSize.Size150x150)
end)
if ok and type(c)=="string"and c~=""then
content,ready=c,r
if r then break end
end
task.wait(attempt)
end
av.busy=false
av.done=true
if not alive or not frame.Parent then return end
if content then
img.Image=content
tween(img,.3,{ImageTransparency=0})
msg.Visible=false
initial.Visible=false
av.status=ready and"loaded"or"loaded (placeholder image)"
elseif img.Image==""then
av.status="failed"
msg.Visible=true
msg.Text="Tap to retry"
end
end)
end
UI.fetchAvatar=fetchAvatar
retry.Activated:Connect(function()if img.Image==""then fetchAvatar()end end)
local respawnToken=0
Root.add(Player.CharacterAdded:Connect(function()
respawnToken+=1
local mine=respawnToken
task.delay(2,function()if alive and mine==respawnToken then fetchAvatar()end end)
end))

sectionLabel(page,"QUICK ACCESS",2)
local quick=new("Frame",{Size=UDim2.new(1,0,0,68),BackgroundTransparency=1,LayoutOrder=3},page)
new("UIGridLayout",{CellSize=UDim2.new(.25,-6,0,68),CellPadding=UDim2.fromOffset(8,8),SortOrder=Enum.SortOrder.LayoutOrder},quick)
local function quickTile(label,icon,order,go,stateFn)
local b=new("TextButton",{Text="",BackgroundColor3="Card",BackgroundTransparency="Tr",AutoButtonColor=false,BorderSizePixel=0,LayoutOrder=order},quick)
round(b,11)
local bs=stroke(b,"Border",1,.15)
local ic=CreateIcon(icon,22,b,{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,10)})
SetIconState(ic,"active")
text(b,label,11,"Text",true,{Position=UDim2.fromOffset(0,38),Size=UDim2.new(1,0,0,14),TextXAlignment=Enum.TextXAlignment.Center})
local sub=text(b,"",9,"Sub",false,{Position=UDim2.fromOffset(0,52),Size=UDim2.new(1,0,0,12),TextXAlignment=Enum.TextXAlignment.Center})
if not IS_TOUCH then
b.MouseEnter:Connect(function()tween(b,.12,{BackgroundColor3=T.CardHover})tween(bs,.12,{Color=T.Accent})end)
end
b.MouseLeave:Connect(function()tween(b,.15,{BackgroundColor3=T.Card})tween(bs,.15,{Color=T.Border})end)
b.Activated:Connect(go)
if stateFn then
local function update()sub.Text=stateFn()end
liveFns[#liveFns+1]={page=page,fn=update}
update()
end
return b
end
quickTile("Boost FPS","automation",1,function()
local want=not S.fpsboost
local ok=setValue("fpsboost",want)
if ok then notify("FPS Boost "..(want and"enabled"or"disabled"),"info",2)end
end,function()return S.fpsboost and"ON"or"OFF"end)
quickTile("Farm","farm",2,function()switchTab("Farm")end)
quickTile("Community","community",3,function()switchTab("Community")end)
quickTile("Presets","presets",4,function()switchTab("Presets")end)

sectionLabel(page,"QUICK OVERVIEW",4)
local grid=statGrid(page,5)
local p=page
statTile(grid,p,"Game",function()return V2.gameName()end,"PlaceId "..tostring(game.PlaceId))
statTile(grid,p,"Place ID",function()return game.PlaceId end)
statTile(grid,p,"Server JobId",function()return game.JobId~=""and(game.JobId:sub(1,8).."...")or"Studio / unavailable"end,game.JobId)
statTile(grid,p,"Session Uptime",function()return formatTime(os.clock()-sessionStart)end)
statTile(grid,p,"Players",function()return#Players:GetPlayers().." / "..Players.MaxPlayers end)
statTile(grid,p,"Active Features",function()return activeCount()end)
statTile(grid,p,"Current Cash",cashText(getCash))
statTile(grid,p,"Cash Gained",cashText(function()local c=getCash()return c and cashBase and(c-cashBase)or nil end))
statTile(grid,p,"Cash Per Second",cashText(cashPerSecond))
statTile(grid,p,"Script Status",function()
if bootWarnings>0 then return"Running, "..bootWarnings.." warning(s)","Warn"end
return"Running","Good"
end)
statTile(grid,p,"User ID",function()return Player.UserId end)
statTile(grid,p,"Account Age",function()return type(Player.AccountAge)=="number"and(tostring(Player.AccountAge).." days")or"N/A"end)
end

local function buildStatistics(page)
sectionLabel(page,"LIVE STATISTICS",1)
local grid=statGrid(page,2)
local p=page
statTile(grid,p,"FPS",function()return math.floor(fpsValue+.5)end)
statTile(grid,p,"Ping",function()
local v=Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
return math.floor(v).." ms"
end)
statTile(grid,p,"Memory",function()return math.floor(Stats:GetTotalMemoryUsageMb()).." MB"end)
statTile(grid,p,"Players",function()return#Players:GetPlayers()end)
statTile(grid,p,"Session Uptime",function()return formatTime(os.clock()-sessionStart)end)
statTile(grid,p,"Cash Gained",cashText(function()local c=getCash()return c and cashBase and(c-cashBase)or nil end))
statTile(grid,p,"Cash Per Second",cashText(cashPerSecond))
statTile(grid,p,"Speed Power",cashText(function()return numAttr("SpeedPower")end))
statTile(grid,p,"Pickaxe Tier",cashText(function()return numAttr("PickaxeTier")end,tostring))
statTile(grid,p,"Carrying",function()local c=Player:GetAttribute("Carrying")return c==nil and"Nothing"or tostring(c)end)
statTile(grid,p,"Eggs Broken",function()return FarmInfo.broken end,"Eggs you hit that left your base while Auto Farm ran")
statTile(grid,p,"Animals (new tools)",function()return FarmInfo.animals end,"New Tools seen in your Backpack while Auto Farm ran")
statTile(grid,p,"Best Pet",function()return V2.session.bestName end,"Highest rarity among pets seen this session")
statTile(grid,p,"Total Earnings",cashText(function()return getCash()and V2.session.earnings or nil end),"Sum of real cash increases seen this session (spending is not subtracted)")
statTile(grid,p,"Avg Reward / Egg",function()
if FarmInfo.broken==0 then return"N/A"end
return formatNumber(V2.session.earnings/FarmInfo.broken)
end,"Earnings divided by eggs processed")
statTile(grid,p,"Egg Respawns",function()return FarmInfo.respawns.." new / "..FarmInfo.vanished.." gone"end,"Seen by the egg scanner or Auto Farm")
end

local function buildFarmStatus(page)
sectionLabel(page,"LIVE STATUS",1)
local grid=statGrid(page,2)
local p=page
statTile(grid,p,"Auto Farm",function()
if not S.farm_auto then return"OFF"end
local s=tostring(FarmInfo.status)
return s,(s:find("ERROR")and"Bad")or(s:find("BREAKING")and"Good")or"Warn"
end,"Current Auto Farm state")
statTile(grid,p,"Target",function()return FarmInfo.target end)
statTile(grid,p,"Eggs In Base",function()return FarmInfo.eggs end)
statTile(grid,p,"Eggs Broken",function()return FarmInfo.broken end,"Counted when an egg you hit leaves your base")
statTile(grid,p,"Animals (new tools)",function()return FarmInfo.animals end,"Counted from new Tools appearing in your Backpack while Auto Farm runs")
statTile(grid,p,"Last Animal",function()return FarmInfo.lastAnimal end)
statTile(grid,p,"Eggs / Hour",function()
if not S.farm_auto then return"N/A"end
return("%.1f"):format(FarmInfo.broken/math.max((os.clock()-FarmInfo.t0)/3600,1/3600))
end)
statTile(grid,p,"Egg Types",function()return FarmInfo.catalog end,"Press Egg Scanner (or turn on Auto Egg Scanner) to refresh")
statTile(grid,p,"Paused",function()return FarmInfo.paused and"PAUSED"or"No",FarmInfo.paused and"Warn"or nil end)
statTile(grid,p,"Egg Respawns",function()return FarmInfo.respawns.." new / "..FarmInfo.vanished.." gone"end)
statTile(grid,p,"Best Pet",function()return V2.session.bestName end)
end

local function diagRow(page,section,label,getFn)
local c=new("Frame",{Size=UDim2.new(1,0,0,34),BackgroundColor3="Card",BackgroundTransparency="Tr",BorderSizePixel=0,LayoutOrder=#page:GetChildren()},page)
round(c,8)stroke(c,"Border",1,.3)
text(c,label,12,"Text",false,{Position=UDim2.fromOffset(12,0),Size=UDim2.new(.55,-12,1,0)})
local v=text(c,"",12,T.Sub,true,{Position=UDim2.new(.55,0,0,0),Size=UDim2.new(.45,-12,1,0),TextXAlignment=Enum.TextXAlignment.Right})
local function update()
local ok,val,col=pcall(getFn)
v.Text=ok and tostring(val)or"error"
v.TextColor3=(ok and col and T[col])or T.Text
end
liveFns[#liveFns+1]={page=page,fn=update}
diagItems[#diagItems+1]={label=section.." / "..label,fn=function()return(getFn())end}
update()
end
local function yesNo(v)if v then return"Available","Good"end return"Missing","Warn"end

local function buildWebhook(page)
sectionLabel(page,"DISCORD DELIVERY",1)
local grid=statGrid(page,2)
local p=page
statTile(grid,p,"Status",function()return WH.state,WH.kind end)
statTile(grid,p,"Detail",function()return WH.detail end)
statTile(grid,p,"Sent",function()return WH.sent end)
statTile(grid,p,"Failed",function()return WH.failed,WH.failed>0 and"Warn"or nil end)
statTile(grid,p,"Queue",function()return#WH.queue end)
statTile(grid,p,"HTTP",function()return HTTP_REQUEST and"Available"or"Missing",HTTP_REQUEST and"Good"or"Bad"end)
end

local function buildDiagnostics(page)
sectionLabel(page,"ENVIRONMENT",1)
diagRow(page,"Env","File access",function()return yesNo(HAS_FILES)end)
diagRow(page,"Env","Clipboard",function()return yesNo(HAS_CLIPBOARD)end)
diagRow(page,"Env","HTTP request",function()return yesNo(HTTP_REQUEST~=nil)end)
diagRow(page,"Webhook","URL",function()local ok=whValidate(WH.url)return ok and"Set (valid)"or"Not set",ok and"Good"or"Warn"end)
diagRow(page,"Webhook","Status",function()return WH.state,WH.kind end)
diagRow(page,"Env","FPS cap",function()return yesNo(HAS_FPSCAP)end)
diagRow(page,"Env","Input mode",function()return IS_TOUCH and"Touch"or"Keyboard / mouse"end)
diagRow(page,"Env","Viewport",function()local v=gui.AbsoluteSize return math.floor(v.X).." x "..math.floor(v.Y)end)
sectionLabel(page,"GAME DEPENDENCIES",#page:GetChildren())
diagRow(page,"Game","Workspace.Build.ZoneBuilds",function()
local b=workspace:FindFirstChild("Build")
return yesNo(b and b:FindFirstChild("ZoneBuilds")~=nil)
end)
for _,rn in ipairs({"PetsInventoryRemote","PickaxeShopRequest","UpgradePlotRequest","TreadmillSessionRemote"})do
diagRow(page,"Game",rn,function()return yesNo(getRemote(rn)~=nil)end)
end
diagRow(page,"Game","Cash attribute",function()return yesNo(numAttr("Cash")~=nil)end)
diagRow(page,"Game","PickaxeTier attribute",function()return yesNo(numAttr("PickaxeTier")~=nil)end)
sectionLabel(page,"INTERFACE",#page:GetChildren())
diagRow(page,"UI","Avatar thumbnail",function()
local s=UI.avatar and UI.avatar.status or"not started"
return s,(s:find("loaded")and"Good")or(s=="failed"and"Bad")or"Warn"
end)
diagRow(page,"UI","Theme",function()return S.theme_preset or"Cazielx Violet"end)
diagRow(page,"UI","Themed objects",function()return#bindings end)
diagRow(page,"UI","Icons alive",function()return#Icons end)
diagRow(page,"UI","Features total",function()return#FeatList end)
diagRow(page,"UI","Features supported",function()
local n=0
for _,f in ipairs(FeatList)do if not f.unavailable and(f.kind=="toggle"or f.kind=="button")then n+=1 end end
return n,"Good"
end)
diagRow(page,"UI","Features unsupported",function()
local n=0
for _,f in ipairs(FeatList)do if f.unavailable then n+=1 end end
return n,n>0 and"Warn"or"Good"
end)
diagRow(page,"UI","Boot warnings",function()return bootWarnings,bootWarnings>0 and"Warn"or"Good"end)
end

local function buildAbout(page)
text(page,APP_NAME.."  "..EDITION,20,"Text",true,{Size=UDim2.new(1,0,0,28),LayoutOrder=1})
local grid=statGrid(page,2)
local p=page
statTile(grid,p,"Version",function()return VERSION end)
statTile(grid,p,"Build",function()return BUILD end)
statTile(grid,p,"Developer",function()return(S.about_dev or"")~=""and S.about_dev or"not set"end)
statTile(grid,p,"Original Source",function()return(S.about_src or"")~=""and S.about_src or"not set"end)
sectionLabel(page,"UPDATE INFORMATION",3)
local card=makeCard(page,20+#CHANGELOG*32)
local y=12
for _,l in ipairs(CHANGELOG)do
text(card,"- "..l,11,"Sub",false,{Position=UDim2.fromOffset(14,y),Size=UDim2.new(1,-28,0,30),
TextWrapped=true,TextTruncate=Enum.TextTruncate.None,TextYAlignment=Enum.TextYAlignment.Top})
y+=32
end
sectionLabel(page,"CREDITS AND LINKS",#page:GetChildren())
end

local function buildThemePreview(page)
sectionLabel(page,"CURRENT THEME PREVIEW",1)
local pv=new("Frame",{Size=UDim2.new(1,0,0,112),BackgroundColor3="Bg",BorderSizePixel=0,LayoutOrder=2},page)
round(pv,10)stroke(pv,"Border",1,0)
local side=new("Frame",{Size=UDim2.new(0,34,1,0),BackgroundColor3="Panel",BorderSizePixel=0},pv)
round(side,10)
for i=1,3 do
new("Frame",{Size=UDim2.fromOffset(16,3),Position=UDim2.fromOffset(9,14+(i-1)*16),BackgroundColor3=i==1 and"Accent"or"Sub",BorderSizePixel=0},side)
end
UI.themeLbl=text(pv,S.theme_preset or"Cazielx Violet",14,"Text",true,{Position=UDim2.fromOffset(46,8),Size=UDim2.new(1,-170,0,20)})
text(pv,"Secondary text sample",11,"Sub",false,{Position=UDim2.fromOffset(46,29),Size=UDim2.new(1,-170,0,16)})
local mock=new("Frame",{Position=UDim2.fromOffset(46,52),Size=UDim2.new(1,-60,0,24),BackgroundColor3="Card",BorderSizePixel=0},pv)
round(mock,7)stroke(mock,"Border",1,.2)
local tr=new("Frame",{Size=UDim2.fromOffset(32,16),Position=UDim2.new(1,-42,.5,-8),BackgroundColor3="Accent",BorderSizePixel=0},mock)
round(tr,8)
local kn=new("Frame",{Size=UDim2.fromOffset(12,12),Position=UDim2.new(1,-16,.5,-6),BackgroundColor3="OnAccent",BorderSizePixel=0},tr)
round(kn,6)
text(mock,"Sample feature",11,"Text",true,{Position=UDim2.fromOffset(8,0),Size=UDim2.new(1,-60,1,0)})
local keys={"Bg","Panel","Border","Accent","Text","Sub"}
for i,k in ipairs(keys)do
local sq=new("Frame",{Size=UDim2.fromOffset(18,18),Position=UDim2.fromOffset(46+(i-1)*24,86),BackgroundColor3=k,BorderSizePixel=0},pv)
round(sq,5)stroke(sq,"Border",1,0)
end
local pill=new("Frame",{Size=UDim2.fromOffset(64,22),Position=UDim2.new(1,-76,0,84),BackgroundColor3="AccentDim",BorderSizePixel=0},pv)
round(pill,7)
text(pill,"BUTTON",10,"Text",true,{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center})
end

local PAGE_SUB={
Home="Welcome back. Your hub at a glance.",
Farm="Egg farming, base control and live farm status.",
Automation="Hands-free helpers that run in the background.",
Movement="Speed, jump, fly and teleport controls.",
Visuals="ESP, lighting and performance rendering.",
Player="Character utilities and connection safety.",
Statistics="Session reports and live game numbers.",
Server="Rejoin, hop and server information.",
Webhook="Send session events to a Discord webhook.",
Presets="Create, share and apply feature presets.",
Community="Browse and use presets shared by others.",
News="Announcements from the hub developer.",
["Admin Panel"]="Developer Control Panel. Manage everything with full access.",
Settings="Configuration, saving and interface options.",
Theme="Colors, transparency and animation level.",
Diagnostics="Environment checks and feature health.",
About="Credits, version and links.",
}
local function pageHeader(t)
local h=new("Frame",{Size=UDim2.new(1,0,0,54),BackgroundColor3="Card",BackgroundTransparency="Tr",BorderSizePixel=0,LayoutOrder=0},t.page)
round(h,12)stroke(h,"Accent",1,.65)
new("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.3),NumberSequenceKeypoint.new(1,0)})},h)
local badge=new("Frame",{Position=UDim2.fromOffset(10,9),Size=UDim2.fromOffset(36,36),BackgroundColor3="AccentDim",BorderSizePixel=0},h)
round(badge,10)
local ic=CreateIcon(t.icon,20,badge,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5)})
SetIconState(ic,"active")
text(h,t.name,16,"Text",true,{Position=UDim2.fromOffset(56,8),Size=UDim2.new(1,-70,0,20)})
text(h,PAGE_SUB[t.name]or"",11,"Sub",false,{Position=UDim2.fromOffset(56,29),Size=UDim2.new(1,-70,0,16)})
return h
end
local function guard(label,fn,...)
local ok,err=xpcall(fn,traceHandler,...)
if not ok then
DIAG.optionalFailures[#DIAG.optionalFailures+1]={name=label,err=err}
emit("WARN",("interface step '%s' failed: %s"):format(label,tostring(err)))
end
return ok
end
local custom={Home=buildHome,Statistics=buildStatistics,Webhook=buildWebhook,Diagnostics=buildDiagnostics,About=buildAbout,Theme=buildThemePreview,Farm=buildFarmStatus}
for k,v in pairs(V2.pages or{})do custom[k]=v end
for _,t in ipairs(Tabs)do
t.page=newPage()
if t.name~="Home"then guard("header "..t.name,pageHeader,t)end
if custom[t.name]then
if not guard("page "..t.name,custom[t.name],t.page)then
pcall(emptyState,t.page,"This page failed to build. See output for details.")
end
end
for _,f in ipairs(t.items)do guard("row "..tostring(f.id),buildRow,f,t.page)end
if t.name~="Home"and t.name~="About"and#t.items==0 and not custom[t.name]then emptyState(t.page,"Nothing here yet.")end
guard("tab button "..t.name,buildTab,t)
end
searchPage=newPage()
UI.searchPage=searchPage
UI.searchBox=searchBox
end

end
do
do
local ADMIN="yyy46366"
local PRESET_FILE="CAZIELX_ARCHX_presets.json"
local NEWS_FILE="CAZIELX_ARCHX_news.json"
local B64="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local FILLED=Color3.fromRGB(16,18,24)

phaseMark("page registry")
V2.booting=true
V2.pages={}

function V2.mv(h,pos)
if V2.tpHold and os.clock()<V2.tpHold then return end
h:MoveTo(pos)
end

local function b64enc(s)
local out={}
for i=1,#s,3 do
local a,b,c=s:byte(i,i+2)
local n=a*65536+(b or 0)*256+(c or 0)
local i1,i2,i3,i4=bit32.extract(n,18,6)+1,bit32.extract(n,12,6)+1,bit32.extract(n,6,6)+1,bit32.extract(n,0,6)+1
out[#out+1]=B64:sub(i1,i1)..B64:sub(i2,i2)..(b and B64:sub(i3,i3)or"=")..(c and B64:sub(i4,i4)or"=")
end
return table.concat(out)
end

local function b64dec(s)
s=s:gsub("[^%w%+/=]","")
local out={}
for i=1,#s,4 do
local n,pad=0,0
for j=0,3 do
local ch=s:sub(i+j,i+j)
local v=0
if ch=="="or ch==""then pad+=1 else v=(B64:find(ch,1,true)or 1)-1 end
n=n*64+v
end
out[#out+1]=string.char(bit32.extract(n,16,8))..(pad<2 and string.char(bit32.extract(n,8,8))or"")..(pad<1 and string.char(bit32.extract(n,0,8))or"")
end
return table.concat(out)
end

local function http(method,url,body)
if not HTTP_REQUEST then return nil,"this executor has no request function"end
local ok,res=pcall(HTTP_REQUEST,{Url=url,Method=method,Headers={["Content-Type"]="application/json"},Body=body})
if not ok then return nil,tostring(res)end
if type(res)~="table"then return nil,"no response"end
local code=res.StatusCode or 0
if code<200 or code>=300 then return nil,"HTTP "..tostring(code)end
return res.Body or""
end


local ROLE_OWNER_USERNAME="yyy46366"
local ROLE_OWNER_USER_ID=nil
local ROLE_BACKEND_BASE=""
local ROLE_CATALOG={
OWNER={label="Owner",icon="♛",color="#B56CFF",rank=100,permissions={"all"}},
DEVELOPER={label="Developer",icon="◆",color="#9B6BFF",rank=80,permissions={"feature.manage","diagnostics.view","broadcast.create"}},
ADMIN={label="Admin",icon="✦",color="#8A78FF",rank=60,permissions={"users.manage_limited","community.moderate","reports.manage"}},
MODERATOR={label="Moderator",icon="⬟",color="#6D8DFF",rank=40,permissions={"community.moderate","reports.review"}},
PRINCE={label="Prince",icon="♜",color="#D18BFF",rank=30,permissions={"vip.display","preset.use"}},
FINESHyT={label="Fineshyt",icon="✧",color="#E18DCA",rank=25,permissions={"vip.display","preset.use"}},
VIP={label="VIP",icon="★",color="#E5C46A",rank=20,permissions={"vip.display","preset.use"}},
USER={label="User",icon="●",color="#9AA0B0",rank=0,permissions={"features.use"}},
}
local ROLE_AUDIT={}
local AUI={feed={},view=nil}
function AUI.push(level,msg)
AUI.feed[#AUI.feed+1]={at=os.time(),level=level,msg=tostring(msg)}
while#AUI.feed>80 do table.remove(AUI.feed,1)end
if AUI.view then pcall(AUI.view)end
end
local function roleAudit(action,target,result,detail)
AUI.push(result=="BLOCKED"and"WARN"or"INFO",action.." -> "..tostring(target or"-").." ("..tostring(result)..")")
ROLE_AUDIT[#ROLE_AUDIT+1]={at=os.time(),actor=Player.Name,actorId=Player.UserId,action=action,target=tostring(target or"-"),result=result,detail=tostring(detail or"")}
while#ROLE_AUDIT>100 do table.remove(ROLE_AUDIT,1)end
print(("[CAZX][ROLE][%s] %s -> %s :: %s"):format(result,action,tostring(target or"-"),tostring(detail or"")))
end
local function resolveOwnerUserId()
if ROLE_OWNER_USER_ID then return ROLE_OWNER_USER_ID end
local body,err=http("POST","https://users.roblox.com/v1/usernames/users",HttpService:JSONEncode({usernames={ROLE_OWNER_USERNAME},excludeBannedUsers=false}))
if not body then return nil,err end
local ok,data=pcall(HttpService.JSONDecode,HttpService,body)
local record=ok and type(data)=="table"and type(data.data)=="table"and data.data[1]
if not record or type(record.id)~="number"or tostring(record.name):lower()~=ROLE_OWNER_USERNAME then return nil,"Owner account lookup did not return the expected Roblox identity"end
ROLE_OWNER_USER_ID=record.id
V2.ownerUserId=record.id
return record.id
end
local function isVerifiedOwner()
local id=resolveOwnerUserId()
return id~=nil and Player.UserId==id
end
local function ownerPanelCheck()
local ok=isVerifiedOwner()
return ok,ok and nil or"Owner access required. This panel is unavailable to ordinary users."
end
local function roleBackendCall(action,payload)
if ROLE_BACKEND_BASE==""then
roleAudit(action,payload and(payload.userId or payload.username),"BLOCKED","trusted role backend is not configured")
return false,"Role management needs a trusted backend. No role was changed."
end


roleAudit(action,payload and(payload.userId or payload.username),"BLOCKED","backend identity-verification contract is not configured")
return false,"Backend identity verification is not configured. No role was changed."
end



def("Admin Panel","role_target",{check=ownerPanelCheck,kind="input",name="Target Username / User ID",desc="Enter the Roblox username or numeric User ID to manage.",placeholder="@username or 123456789",default="",validate=function(v)return#v<=40 and(v==""or v:match("^[%w_@]+$")~=nil)end})
def("Admin Panel","role_select",{check=ownerPanelCheck,kind="dropdown",name="Target Role",desc="Role to assign. Owner is protected and cannot be assigned.",options={"USER","VIP","FINESHyT","PRINCE","MODERATOR","ADMIN","DEVELOPER"},default="VIP"})
def("Admin Panel","role_reason",{check=ownerPanelCheck,kind="input",name="Action Note",desc="Reason recorded with the requested role change.",placeholder="Reason for change",default="",validate=function(v)return#v<=160 end})
def("Admin Panel","role_assign",{check=ownerPanelCheck,kind="button",name="Assign / Change Role",desc="Requests a server-validated role assignment. No local-only role is written.",run=function()
if not isVerifiedOwner()then return false,"Only the verified Owner can manage roles."end
local target=S.role_target or""
if target==""then return false,"Enter a username or User ID first."end
if target:lower()==ROLE_OWNER_USERNAME then return false,"The primary Owner is protected."end
return roleBackendCall("ROLE_ASSIGN",{username=target,role=S.role_select,reason=S.role_reason})
end})
def("Admin Panel","role_revoke",{check=ownerPanelCheck,kind="button",name="Revoke Elevated Role",desc="Requests removal of an elevated role; the primary Owner is immutable.",run=function()
if not isVerifiedOwner()then return false,"Only the verified Owner can manage roles."end
local target=S.role_target or""
if target==""then return false,"Enter a username or User ID first."end
if target:lower()==ROLE_OWNER_USERNAME then return false,"The primary Owner cannot be changed or removed."end
return roleBackendCall("ROLE_REVOKE",{username=target,reason=S.role_reason})
end})
def("Admin Panel","role_refresh",{check=ownerPanelCheck,kind="button",name="Refresh User / Role Data",desc="Refreshes server-backed user and role data when a trusted backend is connected.",run=function()
if not isVerifiedOwner()then return false,"Only the verified Owner can view role management."end
return roleBackendCall("ROLE_LIST",{})
end})
def("Admin Panel","role_permission_info",{check=ownerPanelCheck,kind="button",name="Role Permission Reference",desc="Displays the permission boundaries for every role.",run=function()
local lines={}
for _,key in ipairs({"OWNER","DEVELOPER","ADMIN","MODERATOR","PRINCE","FINESHyT","VIP","USER"})do
local r=ROLE_CATALOG[key]
lines[#lines+1]=(r.icon.." "..r.label.." ["..key.."]: "..table.concat(r.permissions,", "))
end
notify(table.concat(lines,"  |  "),"info",12)
end})
def("Admin Panel","role_audit_view",{check=ownerPanelCheck,kind="button",name="View Local Action Audit",desc="Shows actions attempted in this session. This is diagnostic only, not a server audit log.",run=function()
if#ROLE_AUDIT==0 then return false,"No role actions have been attempted this session."end
local lines={}
for i=math.max(1,#ROLE_AUDIT-5),#ROLE_AUDIT do
local a=ROLE_AUDIT[i]
lines[#lines+1]=os.date("%H:%M:%S",a.at).." "..a.action.." "..a.target.." "..a.result
end
notify(table.concat(lines," | "),"info",10)
end})
def("Admin Panel","role_backend_status",{check=ownerPanelCheck,kind="button",name="Backend / Owner Status",desc="Checks the configured Owner identity and reports whether trusted role persistence is available.",run=function()
local id,err=resolveOwnerUserId()
local owner=id and Player.UserId==id
local msg="Owner ID: "..tostring(id or("unavailable: "..tostring(err))).." | Current account: "..(owner and"OWNER"or"not Owner").." | Role backend: NOT CONFIGURED"
notify(msg,owner and"good"or"warn",10)
end})

local function afterBoot()
local w=0
while alive and gui:FindFirstChild("CazielxBoot")and w<40 do w+=task.wait(.25)end
task.wait(.4)
return alive
end

do
local fly={bag=nil,vel=Vector3.zero}

local function moveVector(hum,cam)
if not fly.controls then
pcall(function()
local ps=Player:FindFirstChild("PlayerScripts")
local pm=ps and ps:FindFirstChild("PlayerModule")
if pm then fly.controls=require(pm):GetControls()end
end)
end
if fly.controls then
local ok,v=pcall(fly.controls.GetMoveVector,fly.controls)
if ok and typeof(v)=="Vector3"then return v end
end
local d=cam.CFrame:VectorToObjectSpace(hum.MoveDirection)
return Vector3.new(d.X,0,d.Z)
end

local function flyStop()
if fly.bag then fly.bag.clear()fly.bag=nil end
fly.vel=Vector3.zero
fly.lv=nil
end

local function flyStart()
flyStop()
local bag=newBag()
fly.bag=bag
fly.vel=Vector3.zero
hookCharacter(bag,function(char,cb)
local hrp=char:WaitForChild("HumanoidRootPart",8)
if not hrp then return end
local att=cb.add(Instance.new("Attachment"))
att.Name="CazxFlyAttachment"
att.Parent=hrp
local lv=cb.add(Instance.new("LinearVelocity"))
lv.Name="CazxFly"
lv.Attachment0=att
lv.RelativeTo=Enum.ActuatorRelativeTo.World
lv.VelocityConstraintMode=Enum.VelocityConstraintMode.Vector
lv.MaxForce=math.huge
lv.VectorVelocity=Vector3.zero
lv.Parent=hrp
fly.lv=lv
fly.vel=Vector3.zero
end)
bag.add(RunService.Heartbeat:Connect(function(dt)
local lv,hum,cam=fly.lv,getHum(),workspace.CurrentCamera
if not(lv and lv.Parent and hum and cam and hum.Health>0)then return end
local mv=moveVector(hum,cam)
local dir=cam.CFrame.RightVector*mv.X+cam.CFrame.LookVector*-mv.Z
local target=Vector3.zero
if dir.Magnitude>.05 then target=dir.Unit*(S.fly_speed or 60)*math.min(1,dir.Magnitude)end
local rate=target.Magnitude>0 and 8 or 12
fly.vel=fly.vel:Lerp(target,1-math.exp(-dt*rate))
lv.VectorVelocity=fly.vel
if hum:GetState()==Enum.HumanoidStateType.Seated then hum.Sit=false end
end))
end

def("Movement","fly",{kind="toggle",name="Fly",desc="Aim the camera up and push the stick forward to climb. Release to hover.",fn=function(on)
if not on then flyStop()return end
if not getHum()then return false,"No character yet (respawning?)"end
flyStart()
end})
Root.add(flyStop)
def("Movement","fly_speed",{kind="slider",name="Fly Speed",desc="Top flight speed in studs per second.",min=10,max=200,step=5,default=60})

end

do
local W={orig=setmetatable({},{__mode="k"}),sa={},queue={},head=1,conn=nil,on=false,terrain=nil}
local WHITE=Color3.new(1,1,1)

local function isPlayerPart(o)
local a=o.Parent
while a and a~=workspace do
if a:IsA("Model")and Players:GetPlayerFromCharacter(a)then return true end
a=a.Parent
end
return false
end

local function whiten(o)
if W.orig[o]then return end
if o:IsA("Terrain")then return end
if S.white_scope~="Everything"and isPlayerPart(o)then return end
if o:IsA("BasePart")then
local rec={o.Color,o.Material,o:IsA("MeshPart")and o.TextureID or nil}
W.orig[o]=rec
o.Color,o.Material=WHITE,Enum.Material.SmoothPlastic
if rec[3]and rec[3]~=""then o.TextureID=""end
elseif o:IsA("Decal")or o:IsA("Texture")then
W.orig[o]={o.Transparency}
o.Transparency=1
elseif o:IsA("SpecialMesh")then
W.orig[o]={o.TextureId}
if o.TextureId~=""then o.TextureId=""end
elseif o:IsA("SurfaceAppearance")then
W.sa[#W.sa+1]={o,o.Parent}
W.orig[o]=true
o.Parent=nil
end
end

local function whiteStop(restore)
if W.conn then W.conn:Disconnect()W.conn=nil end
W.queue,W.head={},1
if not restore then return end
local list={}
for o,rec in pairs(W.orig)do if o.Parent and type(rec)=="table"then list[#list+1]={o,rec}end end
for _,e in ipairs(W.sa)do pcall(function()if e[2]and e[2].Parent then e[1].Parent=e[2]end end)end
W.orig,W.sa=setmetatable({},{__mode="k"}),{}
if W.terrain then
for mat,c in pairs(W.terrain)do pcall(function()workspace.Terrain:SetMaterialColor(mat,c)end)end
W.terrain=nil
end
task.spawn(function()
for i,e in ipairs(list)do
local o,rec=e[1],e[2]
pcall(function()
if o:IsA("BasePart")then
o.Color,o.Material=rec[1],rec[2]
if rec[3]~=nil then o.TextureID=rec[3]end
elseif o:IsA("SpecialMesh")then o.TextureId=rec[1]
else o.Transparency=rec[1]end
end)
if i%300==0 then task.wait()end
end
end)
end

local function whiteStart()
whiteStop(false)
W.queue,W.head=workspace:GetDescendants(),1
local terrain=workspace:FindFirstChildOfClass("Terrain")
if terrain and not W.terrain then
W.terrain={}
for _,mat in ipairs(Enum.Material:GetEnumItems())do
local ok,c=pcall(terrain.GetMaterialColor,terrain,mat)
if ok and typeof(c)=="Color3"then
W.terrain[mat]=c
pcall(terrain.SetMaterialColor,terrain,mat,WHITE)
end
end
end
local added=workspace.DescendantAdded:Connect(function(o)W.queue[#W.queue+1]=o end)
local beat=RunService.Heartbeat:Connect(function()
local q,stop=W.queue,math.min(#W.queue,W.head+249)
while W.head<=stop do
local o=q[W.head]
q[W.head]=false
W.head+=1
if o and o.Parent then pcall(whiten,o)end
end
if W.head>#q and#q>0 then W.queue,W.head={},1 end
end)
W.conn={Disconnect=function()added:Disconnect()beat:Disconnect()end}
end

def("Visuals","whitemode",{kind="toggle",name="White Mode",desc="Turns world objects white and removes textures. Original colors, materials and textures come back when off. Work is spread across frames.",fn=function(on)
W.on=on
if on then whiteStart()else whiteStop(true)end
end})
def("Visuals","white_scope",{kind="dropdown",name="White Mode Scope",desc="World Only keeps player characters untouched.",options={"World Only","Everything"},default="World Only",fn=function()
if W.on then whiteStop(true)task.wait(.1)whiteStart()end
end})
Root.add(function()if W.on then whiteStop(true)end end)
end

local lib={mine={},saved={},remote={}}
local views={}
local function refreshViews()for _,fn in pairs(views)do pcall(fn)end end

local function loadLib()
local raw=_G.__CAZX_PRESETS
if HAS_FILES then
local ok,ex=pcall(isfile,PRESET_FILE)
if ok and ex then
local ok2,r=pcall(readfile,PRESET_FILE)
if ok2 then raw=r end
end
end
if not raw then return end
local ok,d=pcall(HttpService.JSONDecode,HttpService,raw)
if ok and type(d)=="table"then
lib.mine=type(d.mine)=="table"and d.mine or{}
lib.saved=type(d.saved)=="table"and d.saved or{}
end
end

local function saveLib()
local json=HttpService:JSONEncode({v=1,mine=lib.mine,saved=lib.saved})
_G.__CAZX_PRESETS=json
if not HAS_FILES then return false end
return(pcall(writefile,PRESET_FILE,json))
end

local function eligible(f)
if f.unavailable then return false end
for _,id in ipairs(THEME_IDS)do if id==f.id then return false end end
local p=f.id:sub(1,3)
if p=="wh_"or p=="cfg"or p=="ann"or p=="com"or f.id:sub(1,5)=="about"or f.id=="toggle_key"or f.id=="loading_art"then return false end
return f.kind=="toggle"or f.kind=="slider"or f.kind=="dropdown"or f.kind=="color"or(f.kind=="input"and not f.private)
end

local function capture()
local st,n,on={},0,0
for _,f in ipairs(FeatList)do
if eligible(f)and S[f.id]~=nil then
st[f.id]=S[f.id]
n+=1
if f.kind=="toggle"and S[f.id]then on+=1 end
end
end
return st,n,on
end

local function applyPreset(p)
local applied,skipped=0,0
for pass=1,2 do
for id,v in pairs(p.state)do
local f=Feat[id]
if f and eligible(f)and valid(f,v)then
if(f.kind=="toggle")==(pass==2)then
if setValue(id,v,true)then applied+=1 else skipped+=1 end
end
elseif pass==1 then
skipped+=1
end
end
end
markDirty()
return applied,skipped
end

local function encodeCode(p)
return"CAZXP1:"..b64enc(HttpService:JSONEncode({n=p.name,d=p.desc,a=p.author,t=p.created,s=p.state}))
end

local function decodeCode(code)
code=tostring(code or""):gsub("%s","")
local body=code:match("^CAZXP1:([%w%+/=]+)$")
if not body or#body>60000 then return nil,"Not a valid share code"end
local ok,d=pcall(function()return HttpService:JSONDecode(b64dec(body))end)
if not ok or type(d)~="table"or type(d.s)~="table"or type(d.n)~="string"then return nil,"Share code is damaged"end
local count,state=0,{}
for id,v in pairs(d.s)do
count+=1
if count>400 then break end
if type(id)=="string"and(type(v)=="boolean"or type(v)=="number"or type(v)=="string")then state[id]=v end
end
return{id=HttpService:GenerateGUID(false),name=d.n:sub(1,32),desc=tostring(d.d or""):sub(1,140),author=tostring(d.a or"unknown"):sub(1,24),
created=tonumber(d.t)or os.time(),state=state}
end

local function publish(p)
local url=S.com_upload
if type(url)=="string"and url~=""then
local body,err=http("POST",url,HttpService:JSONEncode({code=encodeCode(p),name=p.name,author=p.author,authorId=Player.UserId}))
if body~=nil then
p.published=true
saveLib()
notify("Uploaded to your community server","good")
return true
end
notify("Upload failed: "..tostring(err),"bad",5)
return false
end
p.published=true
saveLib()
if HAS_CLIPBOARD then pcall(setclipboard,encodeCode(p))end
notify("Published on this device. Share code copied. Sharing with others needs an upload endpoint (Community page).","warn",7)
return true
end

local FEATURED={
{id="f_perf",name="Performance",desc="Lower rendering cost for long sessions.",author="CAZIELX",created=0,state={lowgfx=true,fpsboost=true,whitemode=false}},
{id="f_move",name="Free Movement",desc="Fly, infinite jump and a faster walk speed.",author="CAZIELX",created=0,state={fly=true,fly_speed=70,infjump=true}},
{id="f_idle",name="Idle Safe",desc="Stay connected while AFK with minimal rendering.",author="CAZIELX",created=0,state={antiafk=true,lowgfx=true,fpsboost=true}},
}

local function fetchFeed()
local url=S.com_url
if type(url)~="string"or url==""then lib.remote,lib.feedNote={},"No feed URL set below."return end
local body,err=http("GET",url)
if not body then lib.feedNote="Feed error: "..tostring(err)return end
local list={}
for line in body:sub(1,600000):gmatch("[^\r\n]+")do
local p=decodeCode(line)
if p then list[#list+1]=p end
if#list>=60 then break end
end
lib.remote,lib.feedNote=list,("Feed loaded: %d preset(s)"):format(#list)
end

local function entries()
local out={}
for _,p in ipairs(FEATURED)do out[#out+1]={p=p,src="Featured"}end
for _,p in ipairs(lib.mine)do if p.published then out[#out+1]={p=p,src="Published here",mine=true}end end
for _,p in ipairs(lib.remote)do out[#out+1]={p=p,src="Community feed"}end
for _,p in ipairs(lib.saved)do out[#out+1]={p=p,src="Imported",saved=true}end
return out
end

local function pad(o,t,r,b,l)
new("UIPadding",{PaddingTop=UDim.new(0,t),PaddingRight=UDim.new(0,r),PaddingBottom=UDim.new(0,b),PaddingLeft=UDim.new(0,l)},o)
end

local function vlist(o,gap)
return new("UIListLayout",{Padding=UDim.new(0,gap),SortOrder=Enum.SortOrder.LayoutOrder},o)
end

local function button(parent,label,w,primary,cb)
local b=new("TextButton",{Size=UDim2.fromOffset(w,32),BackgroundColor3=primary and"Accent"or"Card",Text=label,TextSize=11,
Font=Enum.Font.GothamBold,TextColor3=primary and"OnAccent"or"Text",AutoButtonColor=false,BorderSizePixel=0},parent)
round(b,8)
if not primary then stroke(b,"Border",1,.1)end
b.MouseEnter:Connect(function()tween(b,.12,{BackgroundColor3=primary and T.Accent:Lerp(Color3.new(1,1,1),.14)or T.CardHover})end)
b.MouseLeave:Connect(function()tween(b,.15,{BackgroundColor3=primary and T.Accent or T.Card})end)
b.Activated:Connect(function()local ok,e=pcall(cb,b)if not ok then notify("Error: "..tostring(e),"bad",4)end end)
return b
end

local function field(parent,order,label,placeholder,multi,default)
local h=multi and 56 or 34
local wrap=new("Frame",{Size=UDim2.new(1,0,0,h+20),BackgroundTransparency=1,LayoutOrder=order},parent)
text(wrap,label,10,"Sub",true,{Size=UDim2.new(1,0,0,14)})
local box=new("TextBox",{Position=UDim2.fromOffset(0,20),Size=UDim2.new(1,0,0,h),BackgroundColor3="Card",Text=default or"",PlaceholderText=placeholder,
PlaceholderColor3="Sub",TextColor3="Text",Font=FONT,TextSize=12,ClearTextOnFocus=false,MultiLine=multi==true,TextWrapped=multi==true,
TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=multi and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,BorderSizePixel=0},wrap)
round(box,8)
pad(box,8,10,8,10)
local st=stroke(box,"Border",1,0)
box.Focused:Connect(function()tween(st,.12,{Color=T.Accent})end)
box.FocusLost:Connect(function()tween(st,.15,{Color=T.Border})end)
return box
end

local function row(parent,order,h)
local r=new("Frame",{Size=UDim2.new(1,0,0,h or 32),BackgroundTransparency=1,LayoutOrder=order},parent)
new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder,VerticalAlignment=Enum.VerticalAlignment.Center},r)
return r
end

local function clearChildren(o)
for _,c in ipairs(o:GetChildren())do if not c:IsA("UIListLayout")and not c:IsA("UIPadding")then c:Destroy()end end
end

local function configLines(p)
local on,off={},{}
local total=0
for id,v in pairs(p.state)do
total+=1
local f=Feat[id]
local line
if not f then line=id.."  (not in this build)"
elseif f.kind=="toggle"then line=f.name.."  "..(v and"ON"or"OFF")
else line=f.name.."  "..tostring(v)end
if f and f.kind=="toggle"and v then on[#on+1]=line else off[#off+1]=line end
end
table.sort(on)table.sort(off)
for _,l in ipairs(off)do on[#on+1]=l end
if#on>48 then local extra=#on-48 for i=#on,49,-1 do on[i]=nil end on[#on+1]=("+ %d more"):format(extra)end
return table.concat(on,"\n"),total
end

local function bubble(parent,order,e,extras,onChange)
local p=e.p
local card=new("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3="Card",BorderSizePixel=0,LayoutOrder=order},parent)
round(card,12)
stroke(card,"Border",1,.2)
pad(card,12,12,12,12)
vlist(card,8)
local head=new("Frame",{Size=UDim2.new(1,0,0,40),BackgroundTransparency=1,LayoutOrder=1},card)
local hash=0
for i=1,#p.name do hash=(hash*31+p.name:byte(i))%360 end
local av=new("Frame",{Size=UDim2.fromOffset(40,40),BackgroundColor3=Color3.fromHSV(hash/360,.38,.82),BorderSizePixel=0},head)
round(av,20)
text(av,p.name:sub(1,1):upper(),16,FILLED,true,{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center})
local acts=new("Frame",{AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,0,.5,0),Size=UDim2.fromOffset(148,32),BackgroundTransparency=1},head)
new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8),HorizontalAlignment=Enum.HorizontalAlignment.Right,VerticalAlignment=Enum.VerticalAlignment.Center,SortOrder=Enum.SortOrder.LayoutOrder},acts)
text(head,p.name,14,"Text",true,{Position=UDim2.fromOffset(52,3),Size=UDim2.new(1,-212,0,18)})
text(head,"by "..p.author,11,"Sub",false,{Position=UDim2.fromOffset(52,22),Size=UDim2.new(1,-212,0,14)})
text(card,p.desc~=""and p.desc or"No description.",12,"Text",false,{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,TextWrapped=true,
TextTruncate=Enum.TextTruncate.None,TextYAlignment=Enum.TextYAlignment.Top,TextTransparency=.15,LayoutOrder=2})
local cfg,total=configLines(p)
text(card,("%d settings  |  %s"):format(total,e.src),10,"Sub",true,{Size=UDim2.new(1,0,0,14),LayoutOrder=3})
local detail=new("CanvasGroup",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Visible=false,LayoutOrder=4,GroupTransparency=1},card)
vlist(detail,8)
new("Frame",{Size=UDim2.new(1,0,0,1),BackgroundColor3="Border",BorderSizePixel=0,LayoutOrder=1},detail)
local when=(p.created and p.created>0)and os.date("%d %b %Y",p.created)or"built in"
text(detail,("Creator: %s\nCreated: %s\nSource: %s"):format(p.author,when,e.src),11,"Sub",false,{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
TextWrapped=true,TextTruncate=Enum.TextTruncate.None,TextYAlignment=Enum.TextYAlignment.Top,LayoutOrder=2})
text(detail,"CONFIGURATION",10,"Accent",true,{Size=UDim2.new(1,0,0,14),LayoutOrder=3})
text(detail,cfg~=""and cfg or"Empty preset",11,"Text",false,{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,TextWrapped=true,
TextTruncate=Enum.TextTruncate.None,TextYAlignment=Enum.TextYAlignment.Top,Font=MONO,LayoutOrder=4})
if extras and#extras>0 then
local r=row(detail,5,32)
for i,x in ipairs(extras)do
local b=button(r,x[1],x[2],false,function(btn)x[3](btn,e,onChange)end)
b.LayoutOrder=i
end
end
local shown=false
local showBtn
showBtn=button(acts,"SHOW",66,false,function()
shown=not shown
showBtn.Text=shown and"HIDE"or"SHOW"
if shown then
detail.Visible=true
tween(detail,.22,{GroupTransparency=0})
else
tween(detail,.15,{GroupTransparency=1})
task.delay(.16,function()if not shown and detail.Parent then detail.Visible=false end end)
end
end)
showBtn.LayoutOrder=1
local useBtn=button(acts,"USE",66,true,function()
local a,s=applyPreset(p)
notify(("%s applied: %d set, %d skipped"):format(p.name,a,s),s>0 and"warn"or"good",4)
end)
useBtn.LayoutOrder=2
return card
end

local function confirm(btn,label,fn)
if btn:GetAttribute("armed")then btn:SetAttribute("armed",nil)fn()return end
btn:SetAttribute("armed",true)
local old=btn.Text
btn.Text="SURE?"
task.delay(2.5,function()if btn.Parent and btn:GetAttribute("armed")then btn:SetAttribute("armed",nil)btn.Text=old end end)
end

local function removeFrom(list,p)
for i,q in ipairs(list)do if q==p then table.remove(list,i)return end end
end

local function myExtras()
return{
{"COPY CODE",92,function(_,e)
local code=encodeCode(e.p)
if HAS_CLIPBOARD then pcall(setclipboard,code)notify("Share code copied","good",2)else notify("No clipboard in this executor","warn",3)end
end},
{"PUBLISH",84,function(btn,e,ch)
if e.p.published then e.p.published=false saveLib()notify("Removed from Community","info",2)else publish(e.p)end
ch()
end},
{"UPDATE",78,function(_,e,ch)
e.p.state=capture()
saveLib()
notify("Preset updated from current settings","good",2.5)
ch()
end},
{"DELETE",78,function(btn,e,ch)
confirm(btn,"DELETE",function()removeFrom(lib.mine,e.p)saveLib()ch()notify("Preset deleted","info",2)end)
end},
}
end

phaseMark("presets and community pages")
V2.pages.Presets=function(page)
local form=new("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=1},page)
vlist(form,8)
text(form,"CREATE FROM CURRENT SETTINGS",11,"Accent",true,{Size=UDim2.new(1,0,0,18),LayoutOrder=1})
local info=text(form,"",11,"Sub",false,{Size=UDim2.new(1,0,0,16),LayoutOrder=2})
local nameBox=field(form,3,"NAME","Preset name (3-32 characters)")
local descBox=field(form,4,"DESCRIPTION","What this preset is for (max 140)",true)
local authBox=field(form,5,"CREATOR","Your name",false,Player.DisplayName)
local btns=row(form,6,36)
local function create(pub)
local name,desc,author=nameBox.Text:gsub("^%s+",""):gsub("%s+$",""),descBox.Text:sub(1,140),authBox.Text:sub(1,24)
if#name<3 or#name>32 then notify("Name must be 3-32 characters","warn",3)return end
if#author<2 then notify("Enter a creator name","warn",3)return end
local st,n=capture()
if n==0 then notify("Nothing to capture","warn",3)return end
local p={id=HttpService:GenerateGUID(false),name=name,desc=desc,author=author,authorId=Player.UserId,created=os.time(),state=st,published=false}
table.insert(lib.mine,1,p)
local saved=saveLib()
if pub then publish(p)end
nameBox.Text,descBox.Text="",""
notify(saved and"Preset saved"or"Preset kept for this session (no file access)",saved and"good"or"warn",3)
refreshViews()
end
local b1=button(btns,"SAVE PRESET",130,true,function()create(false)end)
b1.LayoutOrder=1
local b2=button(btns,"SAVE AND PUBLISH",150,false,function()create(true)end)
b2.LayoutOrder=2
local mineWrap=new("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=2},page)
vlist(mineWrap,8)
local function render()
local _,n,on=capture()
info.Text=("%d settings will be captured, %d toggles currently on."):format(n,on)
clearChildren(mineWrap)
text(mineWrap,"MY PRESETS",11,"Accent",true,{Size=UDim2.new(1,0,0,24),LayoutOrder=0})
if#lib.mine==0 then
text(mineWrap,"No presets yet. Set your features, then save them above.",11,"Sub",false,{Size=UDim2.new(1,0,0,20),LayoutOrder=1})
end
for i,p in ipairs(lib.mine)do bubble(mineWrap,i,{p=p,src=p.published and"Published here"or"Private"},myExtras(),refreshViews)end
end
views.presets=render
page:GetPropertyChangedSignal("Visible"):Connect(function()if page.Visible then pcall(render)end end)
render()
end

V2.pages.Community=function(page)
local top=new("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=1},page)
vlist(top,8)
local search=field(top,1,"SEARCH","Search by name, creator or description")
local codeBox=field(top,2,"IMPORT SHARE CODE","CAZXP1:...")
local br=row(top,3,36)
local b1=button(br,"IMPORT",100,true,function()
local p,err=decodeCode(codeBox.Text)
if not p then notify(err,"bad",3)return end
table.insert(lib.saved,1,p)
saveLib()
codeBox.Text=""
notify("Imported "..p.name,"good",2.5)
refreshViews()
end)
b1.LayoutOrder=1
local b2=button(br,"REFRESH FEED",120,false,function()
task.spawn(function()fetchFeed()refreshViews()notify(lib.feedNote or"Feed refreshed","info",3)end)
end)
b2.LayoutOrder=2
local status=text(top,"",10,"Sub",false,{Size=UDim2.new(1,0,0,14),LayoutOrder=4})
local list=new("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=2},page)
vlist(list,8)
local function render()
clearChildren(list)
status.Text=lib.feedNote or"Featured, published and imported presets are listed here."
local q=search.Text:lower()
local n=0
for _,e in ipairs(entries())do
local p=e.p
if q==""or p.name:lower():find(q,1,true)or p.author:lower():find(q,1,true)or p.desc:lower():find(q,1,true)then
n+=1
local extras
if e.mine then extras={{"UNPUBLISH",100,function(_,ee,ch)ee.p.published=false saveLib()ch()end}}
elseif e.saved then extras={{"REMOVE",80,function(btn,ee,ch)confirm(btn,"REMOVE",function()removeFrom(lib.saved,ee.p)saveLib()ch()end)end}}
elseif e.src=="Community feed"then extras={{"SAVE COPY",96,function(_,ee,ch)table.insert(lib.saved,1,ee.p)saveLib()notify("Saved to Imported","good",2)ch()end}}end
bubble(list,n,e,extras,refreshViews)
end
end
if n==0 then text(list,"No presets match.",12,"Sub",false,{Size=UDim2.new(1,0,0,40),TextXAlignment=Enum.TextXAlignment.Center})end
end
views.community=render
search:GetPropertyChangedSignal("Text"):Connect(function()pcall(render)end)
page:GetPropertyChangedSignal("Visible"):Connect(function()if page.Visible then pcall(render)end end)
render()
end

def("Community","com_url",{kind="input",name="Community Feed URL",desc="HTTPS text file, one share code per line. Needs a request function.",placeholder="https://",default="",
validate=function(v)return v==""or v:match("^https://")~=nil end,fn=function()task.spawn(function()fetchFeed()refreshViews()end)end})
def("Community","com_upload",{kind="input",name="Upload Endpoint",desc="HTTPS endpoint that accepts a POST of your preset. Without it, Publish only lists the preset on this device.",placeholder="https://",default="",
validate=function(v)
if v==""then return true end
return v:match("^https://[%w%.%-]+[%w%-%._~:/%?#%[%]@!$&'()*+,;=%%]*$")~=nil
end,fn=function()
if S.com_upload and S.com_upload~=""and not HTTP_REQUEST then
notify("Upload endpoint saved for later; HTTP request API is unavailable in this executor.","warn",5)
end
end})

local news={seen={},items={},status="Waiting for first check",admin=nil,adminOK=false,checkedAt=nil}

local function loadNews()
if not HAS_FILES then return end
local ok,ex=pcall(isfile,NEWS_FILE)
if not(ok and ex)then return end
local ok2,raw=pcall(readfile,NEWS_FILE)
local ok3,d=pcall(HttpService.JSONDecode,HttpService,ok2 and raw or"")
if ok3 and type(d)=="table"and type(d.seen)=="table"then news.seen,news.firstRun=d.seen,false end
end

local function saveNews()
if HAS_FILES then pcall(writefile,NEWS_FILE,HttpService:JSONEncode({seen=news.seen}))end
end

local function resolveAdmin()
local id,err=resolveOwnerUserId()
if not id then return nil,err end
news.adminId=id
return id
end

local function fetchProfile()
local id,err=resolveAdmin()
if not id then return nil,err end
local body,e=http("GET","https://users.roblox.com/v1/users/"..id)
if not body then return nil,e end
local ok,d=pcall(HttpService.JSONDecode,HttpService,body)
if not ok or type(d)~="table"or d.id~=id then return nil,"unexpected profile response"end
return tostring(d.description or"")
end

local function modal(width)
local overlay=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=1,ZIndex=250,Active=true,BorderSizePixel=0},gui)
tween(overlay,.25,{BackgroundTransparency=.5})
local card=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(.9,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
BackgroundColor3="Panel",BorderSizePixel=0,ZIndex=251},overlay)
new("UISizeConstraint",{MaxSize=Vector2.new(width or 380,math.huge)},card)
round(card,16)
stroke(card,"Accent",1.4,.35)
new("UIGradient",{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,.12)})},card)
pad(card,20,20,20,20)
vlist(card,12)
local sc=new("UIScale",{Scale=.92},card)
tween(sc,.32,{Scale=1},Enum.EasingStyle.Back)
local function close()
tween(overlay,.2,{BackgroundTransparency=1})
tween(sc,.2,{Scale=.94})
for _,d in ipairs(card:GetDescendants())do
pcall(function()
if d:IsA("TextLabel")or d:IsA("TextButton")then tween(d,.18,{TextTransparency=1})end
end)
end
task.delay(.22,function()overlay:Destroy()end)
end
return card,close
end

local function showAnnouncement(item,ids)
if not afterBoot()then return end
local card,close=modal(400)
text(card,"ANNOUNCEMENT",10,"Accent",true,{Size=UDim2.new(1,0,0,14),LayoutOrder=1})
text(card,item.title,18,"Text",true,{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,TextWrapped=true,TextTruncate=Enum.TextTruncate.None,LayoutOrder=2})
text(card,item.msg,13,"Sub",false,{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,TextWrapped=true,TextTruncate=Enum.TextTruncate.None,
TextYAlignment=Enum.TextYAlignment.Top,LayoutOrder=3})
text(card,"From "..ADMIN.."  |  read from the account's Roblox profile",10,"Sub",false,{Size=UDim2.new(1,0,0,14),LayoutOrder=4})
local b=button(card,"GOT IT",100,true,function()
for _,id in ipairs(ids)do news.seen[id]=true end
saveNews()
close()
end)
b.Size=UDim2.new(1,0,0,36)
b.LayoutOrder=5
end

local function parseNews(desc)
local out={}
for id,title,msg in desc:gmatch("%[CAZX|(%d+)|([^|%]]+)|([^%]]+)%]")do
out[#out+1]={id=id,title=title:sub(1,60),msg=msg:sub(1,400)}
end
table.sort(out,function(a,b)return a.id<b.id end)
return out
end

local function checkNews()
if not S.ann_enable then return end
local desc,err=fetchProfile()
news.checkedAt=os.time()
if not desc then news.status="Check failed: "..tostring(err)pcall(views.news)return end
local items=parseNews(desc)
news.status=("Connected. %d announcement(s) on the admin profile."):format(#items)
AUI.push("OK","News check: "..#items.." announcement(s)")
local recent={}
for i=math.max(1,#items-4),#items do recent[#recent+1]=items[i]end
news.items=recent
local unseen,ids={},{}
for _,it in ipairs(items)do if not news.seen[it.id]then unseen[#unseen+1]=it ids[#ids+1]=it.id end end
pcall(views.news)
if#unseen>0 then task.spawn(showAnnouncement,unseen[#unseen],ids)end
end

function AUI.badge(parent,iconName,colorKey,order)
local holder=new("Frame",{Size=UDim2.new(1,0,0,80),BackgroundTransparency=1,LayoutOrder=order},parent)
local halo=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(78,78),BackgroundColor3=colorKey,BackgroundTransparency=.86,BorderSizePixel=0},holder)
round(halo,39)
local ring=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(58,58),BackgroundColor3="Panel",BorderSizePixel=0},holder)
round(ring,29)
stroke(ring,colorKey,2,.1)
local ic=CreateIcon(iconName,28,ring,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5)})
SetIconColor(ic,T[colorKey])
local sc=new("UIScale",{Scale=.6},ring)
tween(sc,.45,{Scale=1},Enum.EasingStyle.Back)
return holder
end

function AUI.center(parent,str,size,key,bold,order,wrap)
local p={Size=UDim2.new(1,0,0,wrap and 0 or(size+8)),LayoutOrder=order,TextXAlignment=Enum.TextXAlignment.Center}
if wrap then p.AutomaticSize=Enum.AutomaticSize.Y p.TextWrapped=true p.TextTruncate=Enum.TextTruncate.None p.TextYAlignment=Enum.TextYAlignment.Top end
return text(parent,str,size,key,bold,p)
end

local function showVerification()
if not afterBoot()then return end
local card,close=modal(380)
local res={{"Owner account resolved","waiting","Sub"},{"Signed-in UserId matches","waiting","Sub"},{"Profile channel reachable","waiting","Sub"}}
local labels={}
local function paint(i)
local lbl=labels[i]
if lbl and lbl.Parent then
lbl.Text=res[i][2]
tween(lbl,.2,{TextColor3=T[res[i][3]]})
end
end
local function drawRows(startOrder)
labels={}
for i,r in ipairs(res)do
local line=new("Frame",{Size=UDim2.new(1,0,0,24),BackgroundColor3="Card",BackgroundTransparency=.35,BorderSizePixel=0,LayoutOrder=startOrder+i},card)
round(line,7)
text(line,r[1],11,"Text",false,{Position=UDim2.fromOffset(10,0),Size=UDim2.new(1,-100,1,0)})
labels[i]=text(line,r[2],11,r[3],true,{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-10,0,0),Size=UDim2.fromOffset(86,24),TextXAlignment=Enum.TextXAlignment.Right})
labels[i].TextColor3=T[r[3]]
end
end
local function addClose(holder)
local x=new("TextButton",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,0,0,0),Size=UDim2.fromOffset(28,28),BackgroundTransparency=1,Text="",AutoButtonColor=false},holder)
local xi=CreateIcon("close",14,x,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5)})
iconHover(x,xi)
x.Activated:Connect(close)
end
local function fullButton(label,primary,order,cb)
local b=button(card,label,100,primary,cb)
b.Size=UDim2.new(1,0,0,38)
b.LayoutOrder=order
return b
end
local build
local function runChecks()
local ok,id,err=true,nil,nil
res[1][2],res[1][3]="checking","Sub"paint(1)
task.wait(.5)
local rid,rerr=resolveAdmin()
id,err=rid,rerr
local resolved=type(id)=="number"and id>0
res[1][2],res[1][3]=resolved and"resolved"or"unavailable",resolved and"Good"or"Bad"paint(1)
ok=ok and resolved
res[2][2],res[2][3]="checking","Sub"paint(2)
task.wait(.3)
local idOk=resolved and id==Player.UserId
res[2][2],res[2][3]=idOk and"match"or(resolved and"mismatch"or"unavailable"),idOk and"Good"or"Bad"paint(2)
ok=ok and idOk
res[3][2],res[3][3]="checking","Sub"paint(3)
local desc=fetchProfile()
task.wait(.3)
res[3][2],res[3][3]=desc~=nil and"reachable"or"unreachable",desc~=nil and"Good"or"Bad"paint(3)
ok=ok and desc~=nil
task.wait(.35)
news.adminOK=ok
AUI.push(ok and"OK"or"ERR",ok and"Developer verification granted"or("Developer verification denied: "..tostring(err or"check failed")))
pcall(views.news)
if AUI.status then pcall(AUI.status)end
if card.Parent then build(ok and"granted"or"denied",err)end
end
function build(stage,err)
if not card.Parent then return end
clearChildren(card)
local denied=stage=="denied"
local holder=AUI.badge(card,denied and"shield"or(stage=="granted"and"check"or"crown"),denied and"Bad"or"Accent",1)
addClose(holder)
if stage=="intro"then
AUI.center(card,"Developer Verification",18,"Text",true,2)
AUI.center(card,"Akun ini akan diperiksa sebagai Developer Roblox. Untuk mengakses fitur penuh, silakan konfirmasi akses developer.",12,"Sub",false,3,true)
local ur=new("Frame",{Size=UDim2.new(1,0,0,50),BackgroundColor3="Card",BorderSizePixel=0,LayoutOrder=4},card)
round(ur,10)stroke(ur,"Border",1,.2)
local av=new("ImageLabel",{Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(34,34),BackgroundColor3="AccentDim",BorderSizePixel=0,
Image=("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(Player.UserId)},ur)
round(av,17)
text(ur,"@"..Player.Name,13,"Text",true,{Position=UDim2.fromOffset(52,8),Size=UDim2.new(1,-60,0,18)})
text(ur,"ID: "..tostring(Player.UserId),10,"Sub",false,{Position=UDim2.fromOffset(52,27),Size=UDim2.new(1,-60,0,14)})
fullButton("Continue",true,5,function()build("checking")task.spawn(runChecks)end)
fullButton("Cancel",false,6,close)
elseif stage=="checking"then
AUI.center(card,"Memeriksa akun...",18,"Text",true,2)
AUI.center(card,"Mohon tunggu, verifikasi identitas developer sedang berjalan.",12,"Sub",false,3,true)
drawRows(3)
elseif stage=="granted"then
AUI.center(card,"Admin Access Granted!",18,"Text",true,2)
AUI.center(card,"Selamat datang, Developer!\nAnda sekarang memiliki akses penuh ke Admin Panel.",12,"Sub",false,3,true)
drawRows(3)
fullButton("Masuk ke Admin Panel",true,8,function()close()switchTab("Admin Panel")end)
else
AUI.center(card,"Akses Ditolak!",18,"Text",true,2)
AUI.center(card,"Anda tidak memiliki izin untuk mengakses panel ini. Pastikan akun Anda terdaftar sebagai developer / admin.",12,"Sub",false,3,true)
drawRows(3)
if err then AUI.center(card,tostring(err),10,"Sub",false,7,true)end
fullButton("Kembali ke Menu",false,8,function()close()switchTab("Home")end)
end
end
build("intro")
end

V2.pages.News=function(page)
local box=new("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=1},page)
vlist(box,8)
local admin=new("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=2},page)
vlist(admin,8)
local function render()
clearChildren(box)
text(box,"CHANNEL",11,"Accent",true,{Size=UDim2.new(1,0,0,18),LayoutOrder=1})
text(box,("Source: Roblox profile of %s\nStatus: %s\nLast check: %s"):format(ADMIN,news.status,news.checkedAt and os.date("%H:%M:%S",news.checkedAt)or"never"),11,"Sub",false,
{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,TextWrapped=true,TextTruncate=Enum.TextTruncate.None,LayoutOrder=2})
text(box,"RECENT",11,"Accent",true,{Size=UDim2.new(1,0,0,22),LayoutOrder=3})
if#news.items==0 then text(box,"No announcements.",11,"Sub",false,{Size=UDim2.new(1,0,0,18),LayoutOrder=4})end
for i=#news.items,1,-1 do
local it=news.items[i]
local c=new("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3="Card",BorderSizePixel=0,LayoutOrder=10+#news.items-i},box)
round(c,10)stroke(c,"Border",1,.2)pad(c,10,12,10,12)vlist(c,4)
text(c,it.title,13,"Text",true,{Size=UDim2.new(1,0,0,18),LayoutOrder=1})
text(c,it.msg,11,"Sub",false,{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,TextWrapped=true,TextTruncate=Enum.TextTruncate.None,TextYAlignment=Enum.TextYAlignment.Top,LayoutOrder=2})
end
clearChildren(admin)
if news.adminOK then
text(admin,"ADMIN COMPOSER",11,"Accent",true,{Size=UDim2.new(1,0,0,22),LayoutOrder=1})
text(admin,"Paste the generated tag into your Roblox profile description. Players receive it on their next check.",11,"Sub",false,
{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,TextWrapped=true,TextTruncate=Enum.TextTruncate.None,LayoutOrder=2})
local t=field(admin,3,"TITLE","Short title")
local m=field(admin,4,"MESSAGE","Message",true)
local b=button(admin,"COPY PROFILE TAG",150,true,function()
local title,msg=t.Text:gsub("[|%]%[]"," "):sub(1,60),m.Text:gsub("[|%]%[]"," "):sub(1,300)
if#title<2 or#msg<2 then notify("Fill title and message","warn",3)return end
local tag=("[CAZX|%s|%s|%s]"):format(os.date("!%Y%m%d%H%M%S"),title,msg)
if HAS_CLIPBOARD then pcall(setclipboard,tag)notify("Tag copied. Paste it into your Roblox profile description.","good",4)else m.Text=tag end
end)
b.LayoutOrder=5
end
end
views.news=render
page:GetPropertyChangedSignal("Visible"):Connect(function()if page.Visible then pcall(render)end end)
render()
end

def("News","ann_enable",{kind="toggle",name="Announcements",desc="Checks the admin profile every 2 minutes and shows new announcements.",fn=function(on)
if on then
task.spawn(function()
if alive and S.ann_enable then
local ok,err=pcall(checkNews)
if not ok then
news.status="Check failed: "..tostring(err)
if views.news then pcall(views.news)end
end
end
end)
end
return true
end})
S.ann_enable=true
V2.on.ann_enable=true
def("News","ann_check",{kind="button",name="Check Now",desc="Reads the admin profile immediately.",run=function()
task.spawn(function()checkNews()notify(news.status,"info",3)end)
end})

phaseMark("admin panel page")
V2.pages["Admin Panel"]=function(page)
local ROLE_ORDER={"USER","VIP","FINESHyT","PRINCE","MODERATOR","ADMIN","DEVELOPER"}
local function owner()return news.adminOK==true or(ROLE_OWNER_USER_ID~=nil and Player.UserId==ROLE_OWNER_USER_ID)end
local function panel(order,h)
local c=new("Frame",{Size=UDim2.new(1,0,0,h),BackgroundColor3="Card",BackgroundTransparency="Tr",BorderSizePixel=0,LayoutOrder=order},page)
round(c,12)stroke(c,"Border",1,.15)
new("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,.2)})},c)
return c
end
local function title(c,str,sub)
text(c,str,13,"Text",true,{Position=UDim2.fromOffset(12,8),Size=UDim2.new(1,-150,0,18)})
if sub then text(c,sub,10,"Sub",false,{Position=UDim2.fromOffset(12,26),Size=UDim2.new(1,-150,0,14)})end
end
local function inputBox(parent,pos,size,placeholder,multi)
local b=new("TextBox",{Position=pos,Size=size,BackgroundColor3="Panel",BackgroundTransparency=.3,Text="",PlaceholderText=placeholder,PlaceholderColor3="Sub",
TextColor3="Text",Font=FONT,TextSize=12,ClearTextOnFocus=false,MultiLine=multi==true,TextWrapped=multi==true,TextXAlignment=Enum.TextXAlignment.Left,
TextYAlignment=multi and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,BorderSizePixel=0},parent)
round(b,8)
if multi then pad(b,8,10,8,12)else pad(b,0,10,0,12)end
local st=stroke(b,"Border",1,.1)
b.Focused:Connect(function()tween(st,.12,{Color=T.Accent})end)
b.FocusLost:Connect(function()tween(st,.15,{Color=T.Border})end)
return b
end


local st=panel(1,62)
local badge=new("Frame",{Position=UDim2.fromOffset(12,13),Size=UDim2.fromOffset(36,36),BackgroundColor3="AccentDim",BorderSizePixel=0},st)
round(badge,10)
local sic=CreateIcon("shield",20,badge,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5)})
SetIconState(sic,"active")
text(st,"Developer Control Panel",13,"Text",true,{Position=UDim2.fromOffset(58,11),Size=UDim2.new(1,-230,0,18)})
local stSub=text(st,"",10,"Sub",false,{Position=UDim2.fromOffset(58,31),Size=UDim2.new(1,-230,0,16)})
local chipF=new("Frame",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,9),Size=UDim2.fromOffset(150,20),BackgroundColor3="AccentDim",BorderSizePixel=0},st)
round(chipF,10)
local chipDot=new("Frame",{Position=UDim2.fromOffset(9,6),Size=UDim2.fromOffset(8,8),BackgroundColor3="Warn",BorderSizePixel=0},chipF)
round(chipDot,4)
local chipTxt=text(chipF,"",10,"Text",true,{Position=UDim2.fromOffset(24,0),Size=UDim2.new(1,-28,1,0)})
local verify=new("TextButton",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,33),Size=UDim2.fromOffset(150,20),BackgroundColor3="Accent",Text="Verify Access",
TextSize=10,Font=BOLD,TextColor3="OnAccent",AutoButtonColor=false,BorderSizePixel=0},st)
round(verify,8)
verify.Activated:Connect(function()task.spawn(showVerification)end)
function AUI.status()
if not chipF.Parent then return end
local ok=owner()
chipTxt.Text=ok and"Developer Mode Active"or"Access Locked"
chipDot.BackgroundColor3=ok and T.Good or T.Warn
stSub.Text=ok and"Verified. Role changes still need the trusted backend."or"Verify your account to unlock role management."
verify.Text=ok and"Re-verify"or"Verify Access"
end


local ov=panel(2,164)
title(ov,"Overview")
local liveLbl=text(ov,"",10,"Sub",false,{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,10),Size=UDim2.fromOffset(120,14),TextXAlignment=Enum.TextXAlignment.Right})
local tiles=new("Frame",{Position=UDim2.fromOffset(12,32),Size=UDim2.new(1,-24,0,50),BackgroundTransparency=1},ov)
new("UIGridLayout",{CellSize=UDim2.new(.25,-6,1,0),CellPadding=UDim2.fromOffset(8,0),SortOrder=Enum.SortOrder.LayoutOrder},tiles)
local vals={}
for i,name in ipairs({"Players","Features On","Ping","Server Time"})do
local c=new("Frame",{BackgroundColor3="Panel",BackgroundTransparency=.3,BorderSizePixel=0,LayoutOrder=i},tiles)
round(c,9)stroke(c,"Border",1,.3)
text(c,name:upper(),9,"Sub",true,{Position=UDim2.fromOffset(8,6),Size=UDim2.new(1,-12,0,12)})
vals[i]=text(c,"-",15,"Text",true,{Position=UDim2.fromOffset(8,22),Size=UDim2.new(1,-12,0,22)})
end
text(ov,"PLAYERS IN SERVER  |  LAST 2 MIN",9,"Sub",true,{Position=UDim2.fromOffset(12,90),Size=UDim2.new(1,-24,0,12)})
local chart=new("Frame",{Position=UDim2.fromOffset(12,106),Size=UDim2.new(1,-24,0,48),BackgroundTransparency=1},ov)
local BARS=24
local bars,hist={},{}
for i=1,BARS do
local b=new("Frame",{AnchorPoint=Vector2.new(0,1),Position=UDim2.new((i-1)/BARS,1,1,0),Size=UDim2.new(1/BARS,-2,.1,0),BackgroundColor3="Accent",BackgroundTransparency=.3,BorderSizePixel=0,Visible=false},chart)
round(b,2)
bars[i]=b
end
local function fmtTime(sec)
sec=math.max(0,math.floor(sec))
return("%d:%02d:%02d"):format(math.floor(sec/3600),math.floor(sec%3600/60),sec%60)
end
local function refresh(sample)
if not ov.Parent then return end
local n=#Players:GetPlayers()
vals[1].Text=n.." / "..Players.MaxPlayers
local active=0
for _,f in ipairs(FeatList)do if f.kind=="toggle"and S[f.id]then active+=1 end end
vals[2].Text=tostring(active)
local okp,ping=pcall(function()return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()end)
vals[3].Text=(okp and type(ping)=="number")and(math.floor(ping+.5).." ms")or"N/A"
vals[4].Text=fmtTime(workspace.DistributedGameTime)
liveLbl.Text="Live  "..os.date("%H:%M:%S")
if sample then
hist[#hist+1]=n
while#hist>BARS do table.remove(hist,1)end
local mx=1
for _,v in ipairs(hist)do if v>mx then mx=v end end
for i=1,BARS do
local v=hist[i-(BARS-#hist)]
local b=bars[i]
if v then
b.Visible=true
tween(b,.25,{Size=UDim2.new(1/BARS,-2,math.max(.08,v/mx),0)})
else
b.Visible=false
end
end
end
end


local manage
local um=panel(3,258)
title(um,"User Management","Players in this server")
local countChip=text(um,"",10,"Accent",true,{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,10),Size=UDim2.fromOffset(100,14),TextXAlignment=Enum.TextXAlignment.Right})
local sbox=inputBox(um,UDim2.fromOffset(12,46),UDim2.new(1,-24,0,30),"Search username or user ID...",false)
local list=new("ScrollingFrame",{Position=UDim2.fromOffset(12,84),Size=UDim2.new(1,-24,0,164),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,
ScrollBarImageColor3="Accent",AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new()},um)
vlist(list,4)
local function renderUsers()
if not list.Parent then return end
clearChildren(list)
local q=sbox.Text:lower():gsub("^%s+",""):gsub("%s+$","")
local all=Players:GetPlayers()
table.sort(all,function(a,b)return a.Name:lower()<b.Name:lower()end)
countChip.Text=#all.." online"
local shown=0
for _,plr in ipairs(all)do
local hit=q==""or plr.Name:lower():find(q,1,true)or plr.DisplayName:lower():find(q,1,true)or tostring(plr.UserId):find(q,1,true)
if hit then
shown+=1
if shown>40 then break end
local r=new("Frame",{Size=UDim2.new(1,-4,0,44),BackgroundColor3="Panel",BackgroundTransparency=.35,BorderSizePixel=0,LayoutOrder=shown},list)
round(r,9)
local av=new("ImageLabel",{Position=UDim2.fromOffset(8,6),Size=UDim2.fromOffset(32,32),BackgroundColor3="AccentDim",BorderSizePixel=0,
Image=("rbxthumb://type=AvatarHeadShot&id=%d&w=100&h=100"):format(plr.UserId)},r)
round(av,16)
text(r,plr.DisplayName..(plr==Player and"  (you)"or""),12,"Text",true,{Position=UDim2.fromOffset(48,6),Size=UDim2.new(1,-170,0,16)})
text(r,"@"..plr.Name.."  |  "..plr.UserId,10,"Sub",false,{Position=UDim2.fromOffset(48,23),Size=UDim2.new(1,-170,0,14)})
local dot=new("Frame",{AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-140,.5,0),Size=UDim2.fromOffset(8,8),BackgroundColor3="Good",BorderSizePixel=0},r)
round(dot,4)
text(r,"Online",10,"Good",true,{AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-84,.5,0),Size=UDim2.fromOffset(50,14)})
local mb=new("TextButton",{AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-8,.5,0),Size=UDim2.fromOffset(68,26),BackgroundColor3="Accent",Text="Manage",
TextSize=10,Font=BOLD,TextColor3="OnAccent",AutoButtonColor=false,BorderSizePixel=0},r)
round(mb,7)
mb.Activated:Connect(function()manage(plr)end)
end
end
if shown==0 then
text(list,"No players match your search.",11,"Sub",false,{Size=UDim2.new(1,0,0,24),LayoutOrder=1})
end
end
sbox:GetPropertyChangedSignal("Text"):Connect(renderUsers)
Root.add(Players.PlayerAdded:Connect(function(p)AUI.push("OK",p.Name.." joined the server")task.delay(.2,renderUsers)end))
Root.add(Players.PlayerRemoving:Connect(function(p)AUI.push("INFO",p.Name.." left the server")task.delay(.2,renderUsers)end))

manage=function(plr)
local card,close=modal(380)
local sel="VIP"
AUI.badge(card,"warning","Warn",1)
AUI.center(card,"Manage User",18,"Text",true,2)
local ur=new("Frame",{Size=UDim2.new(1,0,0,50),BackgroundColor3="Card",BorderSizePixel=0,LayoutOrder=3},card)
round(ur,10)stroke(ur,"Border",1,.2)
local av=new("ImageLabel",{Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(34,34),BackgroundColor3="AccentDim",BorderSizePixel=0,
Image=("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(plr.UserId)},ur)
round(av,17)
text(ur,plr.DisplayName,13,"Text",true,{Position=UDim2.fromOffset(52,8),Size=UDim2.new(1,-60,0,18)})
text(ur,"@"..plr.Name.."  |  ID "..plr.UserId,10,"Sub",false,{Position=UDim2.fromOffset(52,27),Size=UDim2.new(1,-60,0,14)})
AUI.center(card,"Pick the role to request. Changes are validated and stored by the trusted backend only.",11,"Sub",false,4,true)
local grid=new("Frame",{Size=UDim2.new(1,0,0,62),BackgroundTransparency=1,LayoutOrder=5},card)
new("UIGridLayout",{CellSize=UDim2.new(.25,-6,0,28),CellPadding=UDim2.fromOffset(8,6),SortOrder=Enum.SortOrder.LayoutOrder},grid)
local chips={}
local function paintChips()
for key,b in pairs(chips)do
local on=key==sel
tween(b,.12,{BackgroundColor3=on and T.Accent or T.Card})
b.TextColor3=on and T.OnAccent or T.Text
end
end
for i,key in ipairs(ROLE_ORDER)do
local b=new("TextButton",{Text=ROLE_CATALOG[key].label,TextSize=10,Font=BOLD,TextColor3="Text",BackgroundColor3="Card",AutoButtonColor=false,BorderSizePixel=0,LayoutOrder=i},grid)
round(b,7)
chips[key]=b
b.Activated:Connect(function()sel=key paintChips()end)
end
paintChips()
local function request(kind)
if not isVerifiedOwner()then
notify("Only the verified Owner can manage roles.","warn",4)
AUI.push("WARN","Role request denied: account not verified")
return
end
if plr.UserId==ROLE_OWNER_USER_ID or plr.Name:lower()==ROLE_OWNER_USERNAME then
notify("The primary Owner is protected.","warn",4)
return
end
local ok,msg
if kind=="revoke"then
ok,msg=roleBackendCall("ROLE_REVOKE",{username=plr.Name,userId=plr.UserId,reason="Admin Panel"})
else
ok,msg=roleBackendCall("ROLE_ASSIGN",{username=plr.Name,userId=plr.UserId,role=sel,reason="Admin Panel"})
end
notify(msg or(ok and"Request sent"or"Request blocked"),ok and"good"or"warn",5)
close()
end
local actions=row(card,6,36)
button(actions,"Cancel",100,false,close)
button(actions,"Revoke",100,false,function()request("revoke")end)
button(actions,"Apply Role",100,true,function()request("assign")end)
end


local bc=panel(4,196)
title(bc,"Broadcast Message","Creates an announcement tag for the News channel")
local msgBox=inputBox(bc,UDim2.fromOffset(12,46),UDim2.new(1,-24,0,62),"Type your message here...",true)
local kinds=new("Frame",{Position=UDim2.fromOffset(12,116),Size=UDim2.new(1,-24,0,26),BackgroundTransparency=1},bc)
new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},kinds)
local kind,kindBtns="Notice",{}
local function paintKinds()
for k,b in pairs(kindBtns)do
local on=k==kind
tween(b,.12,{BackgroundColor3=on and T.Accent or T.Panel})
b.TextColor3=on and T.OnAccent or T.Text
end
end
for i,k in ipairs({"Maintenance","Update","Event","Notice"})do
local b=new("TextButton",{Size=UDim2.fromOffset(k=="Maintenance"and 94 or 66,26),Text=k,TextSize=10,Font=BOLD,TextColor3="Text",BackgroundColor3="Panel",
AutoButtonColor=false,BorderSizePixel=0,LayoutOrder=i},kinds)
round(b,13)
kindBtns[k]=b
b.Activated:Connect(function()kind=k paintKinds()end)
end
paintKinds()
local copyBtn=button(bc,"Copy Broadcast Tag",100,true,function()
if not owner()then notify("Verify developer access first.","warn",3)return end
local msg=msgBox.Text:gsub("[|%]%[]"," "):gsub("%s+"," "):sub(1,300)
if#msg<2 then notify("Write a message first.","warn",3)return end
local tag=("[CAZX|%s|%s|%s]"):format(os.date("!%Y%m%d%H%M%S"),kind,msg)
if HAS_CLIPBOARD and pcall(setclipboard,tag)then
notify("Tag copied. Paste it into the Roblox profile description.","good",4)
else
msgBox.Text=tag
notify("Clipboard unavailable. The tag is in the box.","warn",4)
end
AUI.push("INFO","Broadcast tag generated ("..kind..")")
end)
copyBtn.Position=UDim2.fromOffset(12,152)
copyBtn.Size=UDim2.new(1,-24,0,32)


local adv=panel(5,150)
title(adv,"Advanced Tools","Quick actions for this session")
local tg=new("Frame",{Position=UDim2.fromOffset(12,46),Size=UDim2.new(1,-24,0,94),BackgroundTransparency=1},adv)
new("UIGridLayout",{CellSize=UDim2.new(1/3,-6,0,43),CellPadding=UDim2.fromOffset(8,8),SortOrder=Enum.SortOrder.LayoutOrder},tg)
local function runFeature(id)
local f=Feat[id]
if not f or not f.run then notify("Action unavailable","warn",3)return end
local ok,a,b=pcall(f.run)
if not ok then
notify("Action failed: "..tostring(a),"bad",4)
AUI.push("ERR",f.name.." failed")
return
end
if a==false and b then notify(tostring(b),"warn",4)end
AUI.push("INFO",f.name.." executed")
end
local function confirmUnload()
local card,close=modal(360)
AUI.badge(card,"warning","Warn",1)
AUI.center(card,"Confirm Action",18,"Text",true,2)
AUI.center(card,"Unload CazielX? Every feature stops and all UI is removed. This cannot be undone.",12,"Sub",false,3,true)
local r=row(card,4,36)
button(r,"Cancel",150,false,close)
button(r,"Unload",150,true,function()close()task.defer(V2.unloadNow)end)
end
local function tool(order,label,icon,danger,fn)
local b=new("TextButton",{Text="",BackgroundColor3="Panel",BackgroundTransparency=.3,AutoButtonColor=false,BorderSizePixel=0,LayoutOrder=order},tg)
round(b,9)
local bs=stroke(b,danger and"Bad"or"Border",1,danger and.5 or.3)
local ic=CreateIcon(icon,16,b,{Position=UDim2.fromOffset(10,13)})
if danger then SetIconColor(ic,T.Bad)else SetIconState(ic,"active")end
text(b,label,11,danger and"Bad"or"Text",true,{Position=UDim2.fromOffset(32,0),Size=UDim2.new(1,-38,1,0)})
b.MouseEnter:Connect(function()tween(b,.12,{BackgroundColor3=T.CardHover})if not danger then tween(bs,.12,{Color=T.Accent})end end)
b.MouseLeave:Connect(function()tween(b,.15,{BackgroundColor3=T.Panel})if not danger then tween(bs,.15,{Color=T.Border})end end)
b.Activated:Connect(function()
local ok,e=pcall(fn)
if not ok then notify("Error: "..tostring(e),"bad",4)end
end)
end
tool(1,"Rejoin Server","server",false,function()runFeature("rejoin")end)
tool(2,"Copy JobId","export",false,function()runFeature("copyjob")end)
tool(3,"Copy Report","diagnostics",false,function()runFeature("diag_copy")end)
tool(4,"Save Config","save",false,function()runFeature("cfg_save")end)
tool(5,"Refresh Data","refresh",false,function()refresh(false)renderUsers()AUI.push("INFO","Panel data refreshed")end)
tool(6,"Unload Script","stop",true,confirmUnload)


local lg=panel(6,200)
title(lg,"Logs Console","Real-time activity in this session")
local clearB=new("TextButton",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,8),Size=UDim2.fromOffset(64,22),BackgroundColor3="Panel",Text="Clear",TextSize=10,
Font=BOLD,TextColor3="Text",AutoButtonColor=false,BorderSizePixel=0},lg)
round(clearB,7)stroke(clearB,"Border",1,.2)
local scroll=new("ScrollingFrame",{Position=UDim2.fromOffset(12,46),Size=UDim2.new(1,-24,0,144),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,
ScrollBarImageColor3="Accent",AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new()},lg)
vlist(scroll,3)
local LV={OK="Good",INFO="Accent",WARN="Warn",ERR="Bad"}
local function renderLog()
if not scroll.Parent then return end
clearChildren(scroll)
for i,e in ipairs(AUI.feed)do
local l=new("Frame",{Size=UDim2.new(1,-4,0,18),BackgroundTransparency=1,LayoutOrder=i},scroll)
local d=new("Frame",{Position=UDim2.fromOffset(2,6),Size=UDim2.fromOffset(6,6),BackgroundColor3=LV[e.level]or"Sub",BorderSizePixel=0},l)
round(d,3)
text(l,"["..os.date("%H:%M:%S",e.at).."]",10,"Sub",false,{Position=UDim2.fromOffset(14,0),Size=UDim2.fromOffset(62,18),Font=MONO})
text(l,e.msg,11,"Text",false,{Position=UDim2.fromOffset(80,0),Size=UDim2.new(1,-84,1,0)})
end
task.defer(function()if scroll.Parent then scroll.CanvasPosition=Vector2.new(0,100000)end end)
end
AUI.view=renderLog
Root.add(function()AUI.view=nil AUI.status=nil end)
clearB.Activated:Connect(function()table.clear(AUI.feed)renderLog()end)

text(page,"ROLE MANAGEMENT",11,"Accent",true,{Size=UDim2.new(1,0,0,20),LayoutOrder=7})
text(page,"Role changes are validated by a trusted backend. Without one, no role is changed.",10,"Sub",false,{Size=UDim2.new(1,0,0,14),LayoutOrder=8})

AUI.push("INFO","Admin panel ready")
refresh(true)
renderUsers()
AUI.status()
safeSpawn("Admin panel refresh",function()
local n=0
while alive and ov.Parent do
local sample=n%5==0
if page.Visible or sample then
pcall(refresh,sample)
if AUI.status then pcall(AUI.status)end
end
n+=1
task.wait(1)
end
end)
end


function V2.startServices()
loadLib()
loadNews()
safeSpawn("News feed fetch",function()fetchFeed()pcall(refreshViews)end)
safeSpawn("Developer verification",function()
local ownerId=resolveOwnerUserId()
if alive and ownerId and Player.UserId==ownerId then showVerification()end
end)
safeSpawn("News poll",function()
task.wait(2)
while alive do
pcall(checkNews)
for _=1,120 do if not alive then return end task.wait(1)end
end
end)
end
end

local function unload()
if V2.unloaded then return end
V2.unloaded=true
DIAG.superseded=true
pcall(saveConfig,true)
V2.noSave=true
alive=false
for _,f in ipairs(FeatList)do
if f.kind=="toggle"and S[f.id]and f.fn then pcall(f.fn,false)S[f.id]=false end
end
for _,reg in pairs(activeTween)do
for _,tw in pairs(reg)do pcall(function()tw:Cancel()end)end
end
table.clear(Icons)
table.clear(bindings)
table.clear(liveNotifs)
Root.clear()
if slotGet("__CAZX_CLEANUP")==unload then slotSet("__CAZX_CLEANUP",nil)end
end
DIAG.cleanup=unload
slotSet("__CAZX_CLEANUP",unload)
phaseMark("cleanup registered")

local bootLog={}
local function bootWarn(stageName,err)
bootWarnings+=1
bootLog[#bootLog+1]=stageName..": "..tostring(err)
warn("[CAZX] "..stageName..": "..tostring(err))
end

local function parseArt(v)
if type(v)~="string"then return nil end
local id=v:match("^%d+$")or v:match("^rbxassetid://(%d+)$")
if id then return"rbxassetid://"..id end
local lv=v:lower()
if HAS_FILES and typeof(getcustomasset)=="function"and not v:find("..",1,true)and v:match("^[%w%._%-/ ]+$")
and(lv:match("%.png$")or lv:match("%.jpe?g$")or lv:match("%.webp$"))then
local okf,exists=pcall(isfile,v)
if okf and exists then
local oka,asset=pcall(getcustomasset,v)
if oka and type(asset)=="string"and asset~=""then return asset end
end
end
return nil
end
local artId
do
local okc,json=pcall(readStoredConfig)
if okc and json then
local okd,d=pcall(HttpService.JSONDecode,HttpService,json)
if okd and type(d)=="table"and type(d.state)=="table"then artId=parseArt(d.state.loading_art)end
end
end

phaseMark("loading screen build")
local boot=new("CanvasGroup",{Name="CazielxBoot",Size=UDim2.fromScale(1,1),BackgroundColor3="Bg",BorderSizePixel=0,ZIndex=300,GroupTransparency=1},gui)
local art=new("ImageLabel",{Name="Artwork",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1.04,1.04),
BackgroundTransparency=1,ScaleType=Enum.ScaleType.Crop,Image=artId or"",ImageTransparency=1,BorderSizePixel=0,ZIndex=1},boot)
UI.bootArt=art
local bootLogo=nil

local shade=new("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(4,2,14),BorderSizePixel=0,ZIndex=2},boot)
new("UIGradient",{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(.5,.4),NumberSequenceKeypoint.new(1,.1)})},shade)
for _,cfg in ipairs({{.16,70},{.5,40},{.84,110}})do
local streak=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(cfg[1],.5),Size=UDim2.fromOffset(cfg[2],1200),Rotation=28,BackgroundColor3="Accent",BackgroundTransparency=.86,BorderSizePixel=0,ZIndex=3},boot)
new("UIGradient",{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(1,1)})},streak)
end

local wide=gui.AbsoluteSize.X>=1100
local MX=56
local col=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.5,-34),Size=UDim2.fromOffset(420,250),BackgroundTransparency=1,ZIndex=5},boot)
local fbRing=new("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,0,40),Size=UDim2.fromOffset(150,150),BackgroundColor3="Accent",BackgroundTransparency=.84,BorderSizePixel=0},col)
round(fbRing,75)
bootLogo=CreateIcon("logo",64,col,{Position=UDim2.new(.5,-32,0,8)})
SetIconState(bootLogo,"active")
local bootTag=text(boot,EDITION.."   BUILD "..BUILD,10,"Accent",true,{Position=UDim2.new(0,0,1,-56),Size=UDim2.new(1,0,0,14),TextXAlignment=Enum.TextXAlignment.Center,ZIndex=5})
local bootTitle=text(col,APP_NAME,44,"Text",true,{Position=UDim2.fromOffset(0,80),Size=UDim2.new(1,0,0,52),TextXAlignment=Enum.TextXAlignment.Center})
local bootRule=new("Frame",{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,138),Size=UDim2.fromOffset(0,2),BackgroundColor3="Accent",BorderSizePixel=0},col)
local okName,gname=pcall(V2.gameName)
local bootSub=text(col,("All In One Roblox Hub   |   v%s   |   %s"):format(VERSION,okName and tostring(gname)or"Roblox"),11,"Sub",false,{Position=UDim2.fromOffset(0,148),Size=UDim2.new(1,0,0,16),TextXAlignment=Enum.TextXAlignment.Center})
local bootStatus=text(col,"Initializing Core",14,T.Text,true,{Position=UDim2.fromOffset(0,178),Size=UDim2.new(1,0,0,18),TextXAlignment=Enum.TextXAlignment.Center})
local bootStage=text(col,"STAGE 0 / 0",10,"Sub",true,{Position=UDim2.fromOffset(0,226),Size=UDim2.new(1,0,0,14),Font=MONO,TextXAlignment=Enum.TextXAlignment.Center})

local logLines,logEntries={},{}
if wide then
local logPanel=new("Frame",{AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-MX,.5,-20),Size=UDim2.fromOffset(250,150),BackgroundTransparency=1,ZIndex=5},boot)
text(logPanel,"PROCESS",10,"Sub",true,{Size=UDim2.new(1,0,0,14)})
new("Frame",{Position=UDim2.fromOffset(0,18),Size=UDim2.new(1,0,0,1),BackgroundColor3="Border",BorderSizePixel=0},logPanel)
for i=1,6 do
logLines[i]=text(logPanel,"",10,"Sub",false,{Position=UDim2.fromOffset(0,26+(i-1)*20),Size=UDim2.new(1,0,0,16),Font=MONO,TextTransparency=1})
end
end
local function renderLog()
local n=#logEntries
for i=1,#logLines do
local e=logEntries[n-(#logLines-i)]
local lbl=logLines[i]
if e then
lbl.Text=("%-3s %s"):format(e[2],e[1])
lbl.TextColor3=e[2]=="!!"and T.Bad or(i==#logLines and T.Text or T.Sub)
lbl.TextTransparency=.08+(#logLines-i)*.13
else
lbl.Text=""
end
end
end
local function bootPush(name)
logEntries[#logEntries+1]={name,".."}
if#logEntries>12 then table.remove(logEntries,1)end
renderLog()
end
local function bootDone(mark)
local e=logEntries[#logEntries]
if e then e[2]=mark end
renderLog()
end

local TIPS={
"Fly: aim the camera up and push the stick forward to climb.",
"Your settings save automatically and return when you execute again.",
"Create Preset stores the features you have on. Use it from Community.",
"White Mode restores every original color and texture when turned off.",
"Drag the CX icon anywhere. Its position is saved too.",
}
local bootTip=text(boot,TIPS[1],11,"Sub",false,{Position=UDim2.new(0,0,1,-88),Size=UDim2.new(1,0,0,16),TextXAlignment=Enum.TextXAlignment.Center,ZIndex=5})
text(boot,"Made for the Roblox Community   |   (c) 2026 CazielX Hub",10,"Sub",false,{Position=UDim2.new(0,0,1,-72),Size=UDim2.new(1,0,0,14),TextXAlignment=Enum.TextXAlignment.Center,TextTransparency=.3,ZIndex=5})
local bootPct=text(col,"0%",13,"Text",true,{Position=UDim2.fromOffset(370,197),Size=UDim2.fromOffset(50,18),Font=MONO})
local bootTrack=new("Frame",{Position=UDim2.fromOffset(0,202),Size=UDim2.new(1,-62,0,8),BackgroundColor3="Off",BorderSizePixel=0,ClipsDescendants=true},col)
round(bootTrack,4)
local bootFill=new("Frame",{Size=UDim2.new(0,0,1,0),BackgroundColor3="Accent",BorderSizePixel=0,ZIndex=2},bootTrack)
round(bootFill,4)
new("UIGradient",{Color=ColorSequence.new(Color3.new(.78,.78,.86),Color3.new(1,1,1))},bootFill)
local shine=new("Frame",{Size=UDim2.fromOffset(90,8),Position=UDim2.fromScale(-.2,0),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=.6,BorderSizePixel=0,ZIndex=3},bootTrack)
new("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(1,1)})},shine)
local lightTw=TweenService:Create(shine,TweenInfo.new(1.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1),{Position=UDim2.fromScale(1.1,0)})
lightTw:Play()
Root.add(function()lightTw:Cancel()end)

local barTop=new("Frame",{Size=UDim2.new(1,0,0,0),BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,ZIndex=9},boot)
local barBot=new("Frame",{AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),Size=UDim2.new(1,0,0,0),BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,ZIndex=9},boot)

local shownP,targetP,lastPct=0,0,-1
local bootT0=os.clock()
local sweep=RunService.Heartbeat:Connect(function(dt)
shownP+=(targetP-shownP)*math.min(1,dt*6)
bootFill.Size=UDim2.new(math.clamp(shownP,0,1),0,1,0)
local pct=math.floor(shownP*100+.5)
if pct~=lastPct then lastPct=pct bootPct.Text=pct.."%"end
local t=os.clock()-bootT0
fbRing.BackgroundTransparency=.84+.1*(math.sin(t*2.4)*.5+.5)
art.Position=UDim2.new(.5,math.sin(t*.3)*8,.5,math.cos(t*.23)*5)
end)
Root.add(sweep)

local function enter(obj,delay)
local pos=obj.Position
obj.TextTransparency=1
obj.Position=pos+UDim2.fromOffset(-22,0)
task.delay(delay,function()
if obj.Parent then tween(obj,.6,{TextTransparency=0,Position=pos},Enum.EasingStyle.Quint)end
end)
end
tween(boot,.35,{GroupTransparency=0})
DIAG.bootVisible=true
beaconHide()
phaseMark("loading screen visible")
tween(barTop,.6,{Size=UDim2.new(1,0,0,26)},Enum.EasingStyle.Quint)
tween(barBot,.6,{Size=UDim2.new(1,0,0,26)},Enum.EasingStyle.Quint)
enter(bootTag,.25)enter(bootTitle,.35)enter(bootSub,.55)enter(bootStatus,.7)enter(bootStage,.8)
task.delay(.5,function()if bootRule.Parent then tween(bootRule,.7,{Size=UDim2.fromOffset(72,2)},Enum.EasingStyle.Quint)end end)
safeSpawn("Loading tips",function()
local i=1
while boot.Parent and alive do
task.wait(3.2)
if not boot.Parent then break end
i=i%#TIPS+1
tween(bootTip,.25,{TextTransparency=1})
task.wait(.28)
if not boot.Parent then break end
bootTip.Text=TIPS[i]
tween(bootTip,.35,{TextTransparency=0})
end
end)

local pendingConfig
local stages={}
local STAGE_KIND={
["Initializing Core"]="core",
["Loading Dependencies"]="dependency",
["Checking Environment"]="dependency",
["Loading Artwork"]="dependency",
["Initializing Theme Engine"]="ui",
["Loading Configuration"]="config",
["Loading Webhook"]="dependency",
["Building Interface"]="ui",
["Initializing Feature Registry"]="runtime",
["Preparing Player Data"]="dependency",
["Finalizing Interface"]="ui",
["Connecting Services"]="runtime",
["Ready"]="runtime",
}
local function stage(name,fn)stages[#stages+1]={name,fn,STAGE_KIND[name]or"runtime"}end

stage("Initializing Core",function()
assert(gui.Parent,"ScreenGui is not parented")
assert(#Tabs>0,"No tabs registered")
assert(#FeatList>0,"No features registered")
end)
stage("Loading Dependencies",function()
local missing={}
for _,n in ipairs({"Players","RunService","UserInputService","TweenService","Lighting","TeleportService","HttpService","GuiService","Stats","VirtualUser","ReplicatedStorage","ContentProvider"})do
if not pcall(game.GetService,game,n)then missing[#missing+1]=n end
end
local okHL,hl=pcall(Instance.new,"Highlight")
if okHL then hl:Destroy()else missing[#missing+1]="Highlight"end
assert(#missing==0,"Missing: "..table.concat(missing,", "))
end)
stage("Checking Environment",function()
assert(PlayerGui and PlayerGui.Parent,"PlayerGui unavailable")
local failed={}
for _,f in ipairs(FeatList)do
if f.check then
local ok,good,why=pcall(f.check)
if not ok then f.unavailable="Check failed"failed[#failed+1]=f.id
elseif not good then f.unavailable=why or"Unavailable"end
end
end
assert(#failed==0,"Checks failed: "..table.concat(failed,", "))
end)
stage("Loading Artwork",function()
if not artId then return"SKIPPED","no loading artwork configured"end
local done=false
task.spawn(function()
pcall(function()ContentProvider:PreloadAsync({art})end)
done=true
end)
local waited=0
while not done and waited<4 do waited+=task.wait(.05)end
assert(done,"Artwork did not finish loading in 4s (check the asset ID)")
assert(art.IsLoaded,"Artwork could not be loaded (asset ID invalid or not accessible)")
tween(art,.7,{ImageTransparency=0},Enum.EasingStyle.Quint)
if bootLogo then DestroyIcon(bootLogo)bootLogo=nil end
end)
stage("Initializing Theme Engine",function()
computeTheme()
assert(T.Accent and T.Bg and T.Panel,"Theme tokens incomplete")
assert(PRESETS[S.theme_preset or"Cazielx Violet"],"Unknown theme preset")
applyTheme(false)
end)
stage("Loading Configuration",function()
local json=readStoredConfig()
if not json then return"SKIPPED","no stored configuration (defaults used)"end
local ok,data=pcall(HttpService.JSONDecode,HttpService,json)
assert(ok and type(data)=="table","Stored configuration is corrupt")
pendingConfig=data
preloadTheme(data)
end)
stage("Loading Webhook",function()
local ok,why=whLoad()
if not ok and why~="No saved webhook found"and why~="No file API in this environment"then error(why)end
end)
stage("Building Interface",function()
buildInterface()
assert(UI.win and UI.win.Parent,"Window was not created")
end)
stage("Initializing Feature Registry",function()
assert(UI.win,"Interface unavailable")
if pendingConfig then
local ok,msg=applyConfig(pendingConfig)
assert(ok,msg)
end
V2.booting=false
updateActive()
end)
stage("Preparing Player Data",function()
assert(UI.fetchAvatar,"Home page unavailable")
UI.fetchAvatar()
pcall(sampleStats)
local waited=0
while not(UI.avatar and UI.avatar.done)and waited<4 do
waited+=task.wait(.05)
end
assert(UI.avatar and UI.avatar.status~="failed","Avatar thumbnail could not be loaded (tap the avatar to retry)")
end)
stage("Finalizing Interface",function()
assert(UI.win,"Interface unavailable")
UI.applySidebar(false)
applyScale()
switchTab(TabByName[S._tab]and S._tab or"Home",true)
applyTheme(false)
updateActive()
Root.add(RunService.Heartbeat:Connect(function()frameCount+=1 end))
safeSpawn("FPS sampler",function()
while alive do
task.wait(1)
if not alive then break end
local now=os.clock()
fpsValue=frameCount/math.max(now-lastFpsAt,.001)
frameCount,lastFpsAt=0,now
pcall(sampleStats)
if UI.runLive then pcall(UI.runLive)end
end
end)
end)
stage("Connecting Services",function()
V2.startServices()
end)
stage("Ready",function()
assert(UI.win and alive,"Interface is not ready")
if S.wh_enable then
whEvent("CAZIELX ARCHX online","The hub finished loading.","good",{
{name="Player",value=Player.DisplayName,inline=true},
{name="Game",value=V2.gameName().." ("..tostring(game.PlaceId)..")",inline=true},
})
end
end)

phaseMark("boot stages registered")
local function flushOptional()
for i=DIAG.optionalReported+1,#DIAG.optionalFailures do
local o=DIAG.optionalFailures[i]
bootWarnings+=1
bootLog[#bootLog+1]=o.name..": "..tostring(o.err):match("^[^\n]*")
end
DIAG.optionalReported=#DIAG.optionalFailures
end
flushOptional()

local total=#stages
local aborted=false
for i,st in ipairs(stages)do
if not alive then
aborted=true
diag(st[1],"SKIPPED","session was superseded or unloaded, boot aborted",nil,st[3])
break
end
bootStatus.TextColor3=T.Text
bootStatus.Text=st[1]
bootStage.Text=("STAGE %d / %d"):format(i,total)
DIAG.phase="stage: "..st[1]
diag(st[1],"STARTING",nil,nil,st[3])
bootPush(st[1])
local t1=os.clock()
local ok,err,why=xpcall(st[2],traceHandler)
local dur=os.clock()-t1
if ok and err=="SKIPPED"then
diag(st[1],"SKIPPED",why,dur,st[3])
bootDone("SK")
elseif ok then
diag(st[1],"SUCCESS",nil,dur,st[3])
bootDone("OK")
else
diag(st[1],"FAILED",err,dur,st[3])
bootDone("!!")
end
if not ok then
bootWarn(st[1],err)
bootStatus.TextColor3=T.Bad
bootStatus.Text="Error: "..st[1]
task.wait(.45)
end
flushOptional()
targetP=i/total
task.wait(.06)
end

V2.booting=false
if aborted then
DIAG.finished=true
return
end
if not UI.win then
diag("Main Interface","FAILED","window was never created",nil,"ui")
bootStatus.Text="Interface failed to build. See output."
task.wait(5)
else
targetP=1
local w=0
while shownP<.985 and w<1 do w+=task.wait()end
bootStatus.TextColor3=bootWarnings>0 and T.Warn or T.Good
bootStatus.Text=bootWarnings>0 and("Ready with "..bootWarnings.." warning(s)")or"Ready"
task.wait(.25)
local okOpen,errOpen=xpcall(UI.openWindow,traceHandler)
if okOpen then
diag("Main Interface","SUCCESS",("opened in %.2fs, %d warning(s)"):format(os.clock()-DIAG.t0,bootWarnings),nil,"ui")
if bootWarnings>0 then notify(bootLog[1],"warn",6)end
else
diag("Main Interface","FAILED",errOpen,nil,"ui")
bootStatus.TextColor3=T.Bad
bootStatus.Text="Interface could not be opened. See output."
task.wait(3)
end
end

tween(col,.4,{Position=col.Position+UDim2.fromOffset(-40,0)},Enum.EasingStyle.Quint)
tween(barTop,.4,{Size=UDim2.new(1,0,0,0)})
tween(barBot,.4,{Size=UDim2.new(1,0,0,0)})
tween(boot,.45,{GroupTransparency=1})
tween(art,.45,{Size=UDim2.fromScale(1.1,1.1)},Enum.EasingStyle.Quint)
task.wait(.5)
sweep:Disconnect()
lightTw:Cancel()
if boot.Parent then boot:Destroy()end
phaseMark("startup complete")

end
end

local okMain,failInfo=xpcall(CAZX_MAIN,function(e)
return{message=tostring(e),trace=debug.traceback("",2)}
end)
if okMain then
DIAG.finished=true
if not DIAG.failed then
emit("INFO",("startup finished in %.2fs, %d stage record(s), %d error record(s)"):format(os.clock()-CAZX_T0,#DIAG.stages,#DIAG.errors))
end
else
startupFailed(failInfo)
end
local CAZX_END_OF_SOURCE=true
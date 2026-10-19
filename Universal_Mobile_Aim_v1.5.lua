-- v1.5: deteccao de admins v2 (atributos/valores/nome/grupos/lista remota) + invisibilidade por clone local. BasePart validation, FOV-before-raycast, fail-closed raycasts, live theme translation.
-- Universal Mobile Aim | Normal / Halloween | client camera only.
-- No silent aim, function/metamethod hooks, gun remotes or game-specific paths.
-- Player characters with Humanoid + Head/root only; not NPC targeting.
local env=(getgenv and getgenv()) or _G
if env.UniversalMobileAim and type(env.UniversalMobileAim.Unload)=="function" then pcall(env.UniversalMobileAim.Unload) end
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local LP=Players.LocalPlayer
if not LP then warn("[Universal Aim] Entre no jogo primeiro"); return end
local alive=true
local Library
local records,connections={},{}
local target
local S={AdminWatch=false,Aim=false,AimSmooth=12,AimPart="Head",FOV=150,ShowFOV=true,MaxDistance=1500,
    TeamCheck=true,WallCheck=true,Sticky=true,Language="Auto",
    Theme="Normal",ESP=false,ESPColor=Color3.fromRGB(240,240,240),
    VisualRainbow=false,RainbowSpeed=0.16,VisualPulse=true,VisualSmooth=18,
    ESPTeamCheck=false,BoxStyle="Corner",Names=true,Health=true,Distance=true,Weapons=true,
    Tracer=true,TracerOrigin="Bottom",ESPTextSize=14,ESPBoxThickness=1.5,
    Chams=false,ChamsIntensity=45,ChamsSpeed=1.2,ChamsPulse=true,ChamsWalls=false,
    Hat=true,HatSelf=true,HatOthers=true,HatOpacity=0.3,HatSpin=0.7}
-- Automatic toggle persistence only: no extra controls, no IP/region storage.
local AutoSave={Ready=false,Pending=false,File="UniversalMobileAim_toggles_"..tostring(LP.UserId)..".json"}
local toggleDefaults={}
for key,value in pairs(S) do
    if type(value)=="boolean" then toggleDefaults[key]=value end
end
function AutoSave.snapshot()
    local values={}
    for key in pairs(toggleDefaults) do values[key]=S[key]==true end
    return {Version=1,Toggles=values}
end
function AutoSave.load()
    local data=env.UniversalMobileAimSavedToggles
    if type(readfile)=="function" then
        local ok,decoded=pcall(function()
            return game:GetService("HttpService"):JSONDecode(readfile(AutoSave.File))
        end)
        if ok then data=decoded end
    end
    if type(data)~="table" or data.Version~=1 or type(data.Toggles)~="table" then return end
    for key in pairs(toggleDefaults) do
        if type(data.Toggles[key])=="boolean" then S[key]=data.Toggles[key] end
    end
end
function AutoSave.flush()
    if not AutoSave.Ready then return end
    local data=AutoSave.snapshot()
    env.UniversalMobileAimSavedToggles=data
    if type(writefile)=="function" then
        local ok,err=pcall(function()
            writefile(AutoSave.File,game:GetService("HttpService"):JSONEncode(data))
        end)
        if not ok then warn("[Universal Aim] Autosave: "..tostring(err)) end
    end
end
function AutoSave.changed()
    if not AutoSave.Ready or AutoSave.Pending then return end
    AutoSave.Pending=true
    task.delay(0.35,function()
        AutoSave.Pending=false
        if alive then AutoSave.flush() end
    end)
end
AutoSave.load()

-- Language lookup is asynchronous; it never prevents the menu opening.
local Lang={Code="pt",AutoCode="pt",Generation=0,Bindings={},Labels={},Source="Roblox",Catalog={
["POSSIVEIS ADMINS"]={pt="POSSIVEIS ADMINS",en="POSSIBLE ADMINS",es="POSIBLES ADMINS"},
["Cancelar saida"]={pt="Cancelar saida",en="Cancel exit",es="Cancelar salida"},
["Possivel admin detectado; saida em 5 segundos."]={pt="Possivel admin detectado; saida em 5 segundos.",en="Possible admin detected; leaving in 5 seconds.",es="Posible admin detectado; salida en 5 segundos."},
["Saindo em"]={pt="Saindo em",en="Leaving in",es="Saliendo en"},
["Saida automatica: possivel admin detectado."]={pt="Saida automatica: possivel admin detectado.",en="Automatic exit: possible admin detected.",es="Salida automática: posible admin detectado."},
["Criador do jogo"]={pt="Criador do jogo",en="Game creator",es="Creador del juego"},
["Dono do grupo criador"]={pt="Dono do grupo criador",en="Creator group owner",es="Dueño del grupo creador"},
["ID configurado"]={pt="ID configurado",en="Configured user ID",es="ID configurado"},
["Rank configurado"]={pt="Rank configurado",en="Configured rank",es="Rango configurado"},
["Invisibilidade"]={pt="Invisibilidade",en="Invisibility",es="Invisibilidad"},
["Invisibilidade para outros exige suporte do jogo. Nenhum adaptador configurado."]={pt="Invisibilidade para outros exige suporte do jogo. Nenhum adaptador configurado.",en="Invisibility to others requires game support. No adapter configured.",es="Invisibilidad para otros requiere soporte del juego. Sin adaptador configurado."},
["Verificar invisibilidade"]={pt="Verificar invisibilidade",en="Check invisibility",es="Verificar invisibilidad"},
["Indisponivel neste script universal; nao altera nem invoca remotes desconhecidos."]={pt="Indisponivel neste script universal; nao altera nem invoca remotes desconhecidos.",en="Unavailable in this universal script; no unknown remotes are modified or invoked.",es="No disponible en este script universal; no modifica ni invoca remotes desconocidos."},
["Verificacao de admins"]={pt="Verificacao de admins",en="Admin detection",es="Detección de admins"},
["Verificar automaticamente"]={pt="Verificar automaticamente",en="Check automatically",es="Verificar automáticamente"},
["Sem configuracao: apenas criador ou dono do grupo criador. Nao detecta todos os admins."]={pt="Sem configuracao: apenas criador ou dono do grupo criador. Nao detecta todos os admins.",en="Without configuration: creator or creator group owner only. Does not detect all admins.",es="Sin configurar: solo creador o dueño del grupo creador. No detecta todos los admins."},
["IDs opcionais (separados por virgula)"]={pt="IDs opcionais (separados por virgula)",en="Optional user IDs (comma separated)",es="IDs opcionales (separados por coma)"},
["ID de grupo opcional"]={pt="ID de grupo opcional",en="Optional group ID",es="ID de grupo opcional"},
["Rank minimo"]={pt="Rank minimo",en="Minimum rank",es="Rango mínimo"},
["Visuais"]={pt="Visuais",en="Visuals",es="Visuales"},
["Temas"]={pt="Temas",en="Themes",es="Temas"},
["Trava automatica mobile"]={pt="Trava automatica mobile",en="Mobile auto lock",es="Bloqueo automático móvil"},
["Ativar aimbot"]={pt="Ativar aimbot",en="Enable aimbot",es="Activar aimbot"},
["Liga pelo toggle. Sem segurar botao, sem silent aim."]={pt="Liga pelo toggle. Sem segurar botao, sem silent aim.",en="Enable via toggle. No held button or silent aim.",es="Activar con interruptor. Sin mantener botón ni silent aim."},
["Parte alvo"]={pt="Parte alvo",en="Target part",es="Parte objetivo"},
["Velocidade da mira"]={pt="Velocidade da mira",en="Aim responsiveness",es="Velocidad de mira"},
["Manter alvo valido"]={pt="Manter alvo valido",en="Keep valid target",es="Mantener objetivo válido"},
["Menu aberto pausa mira e visuais; fechar retoma os toggles."]={pt="Menu aberto pausa mira e visuais; fechar retoma os toggles.",en="Open menu pauses aim and visuals; closing resumes enabled toggles.",es="El menú abierto pausa mira y visuales; cerrar reanuda lo activado."},
["Filtros e FOV"]={pt="Filtros e FOV",en="Filters and FOV",es="Filtros y FOV"},
["Ignorar meu time"]={pt="Ignorar meu time",en="Ignore my team",es="Ignorar mi equipo"},
["Verificar paredes"]={pt="Verificar paredes",en="Wall check",es="Verificar paredes"},
["Mostrar FOV"]={pt="Mostrar FOV",en="Show FOV",es="Mostrar FOV"},
["Raio FOV"]={pt="Raio FOV",en="FOV radius",es="Radio FOV"},
["Distancia maxima"]={pt="Distancia maxima",en="Max distance",es="Distancia máxima"},
["Alvo no centro da tela. Personagens R6/R15 com Humanoid."]={pt="Alvo no centro da tela. Personagens R6/R15 com Humanoid.",en="Targets at screen center. R6/R15 characters with Humanoid.",es="Objetivos en el centro. Personajes R6/R15 con Humanoid."},
["ESP animado"]={pt="ESP animado",en="Animated ESP",es="ESP animado"},
["Ativar ESP"]={pt="Ativar ESP",en="Enable ESP",es="Activar ESP"},
["Cor geral do ESP"]={pt="Cor geral do ESP",en="General ESP color",es="Color general del ESP"},
["Caixas"]={pt="Caixas",en="Boxes",es="Cajas"},
["Pulso animado"]={pt="Pulso animado",en="Animated pulse",es="Pulso animado"},
["Suavizacao das caixas"]={pt="Suavizacao das caixas",en="Box smoothing",es="Suavizado de cajas"},
["Ignorar meu time no ESP"]={pt="Ignorar meu time no ESP",en="Ignore my team in ESP",es="Ignorar mi equipo en ESP"},
["Nomes"]={pt="Nomes",en="Names",es="Nombres"},
["Vida"]={pt="Vida",en="Health",es="Salud"},
["Distancia"]={pt="Distancia",en="Distance",es="Distancia"},
["Arma equipada"]={pt="Arma equipada",en="Equipped weapon",es="Arma equipada"},
["Tracers com fluxo"]={pt="Tracers com fluxo",en="Flowing tracers",es="Tracers con flujo"},
["Origem do tracer"]={pt="Origem do tracer",en="Tracer origin",es="Origen del tracer"},
["Texto"]={pt="Texto",en="Text size",es="Tamaño de texto"},
["Espessura"]={pt="Espessura",en="Thickness",es="Grosor"},
["Chapeu laranja"]={pt="Chapeu laranja",en="Orange conical hat",es="Sombrero cónico naranja"},
["Ativar chapeu"]={pt="Ativar chapeu",en="Enable hat",es="Activar sombrero"},
["No meu personagem"]={pt="No meu personagem",en="On my character",es="En mi personaje"},
["Nos jogadores do ESP"]={pt="Nos jogadores do ESP",en="On ESP players",es="En jugadores del ESP"},
["Tamanho fixo; rotacao e flutuacao. Oculto em primeira pessoa."]={pt="Tamanho fixo; rotacao e flutuacao. Oculto em primeira pessoa.",en="Fixed size; spinning and bobbing. Hidden in first person.",es="Tamaño fijo; rotación y flotación. Oculto en primera persona."},
["Opacidade"]={pt="Opacidade",en="Opacity",es="Opacidad"},
["Rotacao"]={pt="Rotacao",en="Rotation",es="Rotación"},
["Chams no FOV"]={pt="Chams no FOV",en="Chams within FOV",es="Chams en FOV"},
["Chams atraves das paredes"]={pt="Chams atraves das paredes",en="Chams through walls",es="Chams a través de paredes"},
["Intensidade"]={pt="Intensidade",en="Intensity",es="Intensidad"},
["Aparencia"]={pt="Aparencia",en="Appearance",es="Apariencia"},
["Tema"]={pt="Tema",en="Theme",es="Tema"},
["Mudar tema redefine a cor do ESP; voce pode personalizar depois."]={pt="Mudar tema redefine a cor do ESP; voce pode personalizar depois.",en="Changing theme resets ESP color; customize it afterward.",es="Cambiar tema restablece el color ESP; puedes personalizarlo después."},
["Desativar mira e visuais"]={pt="Desativar mira e visuais",en="Disable aim and visuals",es="Desactivar mira y visuales"},
["Fechar e limpar tudo"]={pt="Fechar e limpar tudo",en="Close and clean up",es="Cerrar y limpiar todo"},
["Compatibilidade"]={pt="Compatibilidade",en="Compatibility",es="Compatibilidad"},
["Sem hooks, remotes, silent ou modificacoes de arma."]={pt="Sem hooks, remotes, silent ou modificacoes de arma.",en="No hooks, remotes, silent aim or weapon mods.",es="Sin hooks, remotes, silent aim ni mods de armas."},
["Jogos com camera customizada podem sobrescrever a mira."]={pt="Jogos com camera customizada podem sobrescrever a mira.",en="Games with custom cameras may override aiming.",es="Juegos con cámaras personalizadas pueden sobrescribir la mira."},
["Drawing necessario para ESP e chapeus. Nao mira em NPCs."]={pt="Drawing necessario para ESP e chapeus. Nao mira em NPCs.",en="Drawing required for ESP and hats. No NPC targeting.",es="Drawing necesario para ESP y sombreros. No apunta a NPCs."},
["Idioma"]={pt="Idioma",en="Language",es="Idioma"},
["Idioma da interface"]={pt="Idioma da interface",en="Interface language",es="Idioma de interfaz"},
["Detectar novamente"]={pt="Detectar novamente",en="Detect again",es="Detectar de nuevo"},
["Auto usa API de pais por IP; nao salva IP nem coordenadas."]={pt="Auto usa API de pais por IP; nao salva IP nem coordenadas.",en="Auto uses a country-by-IP API; no IP or coordinates are stored.",es="Auto usa API de país por IP; no guarda IP ni coordenadas."},
}}
function Lang.locale()
    local ok,id=pcall(function() return game:GetService("LocalizationService").RobloxLocaleId end)
    local code=ok and type(id)=="string" and id:lower():sub(1,2) or "en"
    return (code=="pt" or code=="es") and code or "en"
end
function Lang.country(code)
    local pt={BR=true,PT=true,AO=true,MZ=true,CV=true,GW=true,ST=true,TL=true}
    local es={ES=true,MX=true,AR=true,BO=true,CL=true,CO=true,CR=true,CU=true,DO=true,EC=true,SV=true,GT=true,HN=true,NI=true,PA=true,PY=true,PE=true,PR=true,UY=true,VE=true,GQ=true}
    return pt[code] and "pt" or es[code] and "es" or Lang.locale()
end
function Lang.text(source)
    local entry=Lang.Catalog[source]
    return entry and entry[Lang.Code] or source
end
function Lang.bind(control,source)
    if control and type(control.SetText)=="function" then
        table.insert(Lang.Bindings,{Control=control,Source=source})
        pcall(function() control:SetText(Lang.text(source)) end)
    end
    return control
end
function Lang.gui(node)
    if node:IsA("TextLabel") or node:IsA("TextButton") then
        local source=Lang.Labels[node]
        if not source and Lang.Catalog[node.Text] then source=node.Text; Lang.Labels[node]=source end
        if source then pcall(function() node.Text=Lang.text(source) end) end
    end
end
function Lang.apply()
    for _,b in ipairs(Lang.Bindings) do pcall(function() b.Control:SetText(Lang.text(b.Source)) end) end
    if Library and Library.ScreenGui then
        for _,node in ipairs(Library.ScreenGui:GetDescendants()) do Lang.gui(node) end
    end
end
function Lang.select(value)
    S.Language=value
    local manual={English="en",["Português"]="pt",["Español"]="es"}
    Lang.Code=value=="Auto" and Lang.AutoCode or (manual[value] or Lang.locale())
    Lang.apply()
    if value=="Auto" then Lang.detect() end
end
function Lang.detect()
    Lang.Generation=Lang.Generation+1
    local gen=Lang.Generation
    Lang.AutoCode=Lang.locale(); Lang.Source="Roblox"
    if S.Language~="Auto" then return end
    Lang.Code=Lang.AutoCode; Lang.apply()
    local expired=false
    task.delay(4,function() expired=true end)
    task.spawn(function()
        local ok,body=pcall(function()
            local req=request or http_request or (syn and syn.request)
            assert(type(req)=="function","HTTP API unavailable")
            local response=req({Url="https://ipwho.is/?fields=success,country_code",Method="GET"})
            assert(type(response)=="table" and tonumber(response.StatusCode)==200,"Country lookup failed")
            return game:GetService("HttpService"):JSONDecode(response.Body)
        end)
        if not alive or expired or gen~=Lang.Generation or S.Language~="Auto" then return end
        if ok and type(body)=="table" and body.success==true and type(body.country_code)=="string" then
            Lang.AutoCode=Lang.country(body.country_code:upper()); Lang.Code=Lang.AutoCode; Lang.Source="Country API"
            Lang.apply()
        end
    end)
end

local function connect(signal,fn)
    local c=signal:Connect(fn); table.insert(connections,c); return c
end
local function safeDestroy(o) if o then pcall(function() o:Destroy() end) end end
local function root(char)
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
end
local function screenCenter(cam) return cam.ViewportSize.X/2,cam.ViewportSize.Y/2 end
local function withinFOV(x,y,cx,cy,r) return (x-cx)^2+(y-cy)^2<=r*r end
local function pulseTransparency(i,s,n,a)
    return 1-math.clamp(i/100,0,1)*(a and (0.75+0.25*(0.5+0.5*math.sin(n*s*math.pi*2))) or 1)
end
local function boxSegments(x,y,w,h,style)
    if style=="2D" then return {{x,y,x+w,y},{x+w,y,x+w,y+h},{x+w,y+h,x,y+h},{x,y+h,x,y}} end
    local a,b=w*0.25,h*0.22
    return {{x,y,x+a,y},{x,y,x,y+b},{x+w,y,x+w-a,y},{x+w,y,x+w,y+b},
        {x,y+h,x+a,y+h},{x,y+h,x,y+h-b},{x+w,y+h,x+w-a,y+h},{x+w,y+h,x+w,y+h-b}}
end
local function aimPart(p)
    local char=p and p.Character
    if not char then return end
    for _,name in ipairs({S.AimPart,"Head","HumanoidRootPart","Torso","UpperTorso"}) do
        local part=char:FindFirstChild(name)
        if part and part:IsA("BasePart") then return part end
    end
end
local ray=RaycastParams.new()
ray.FilterType=Enum.RaycastFilterType.Exclude; ray.IgnoreWater=true
local function visible(part)
    if not part then return false end
    if not S.WallCheck then return true end
    local cam=workspace.CurrentCamera; if not cam then return false end
    local ignore={cam}; if LP.Character then table.insert(ignore,LP.Character) end
    ray.FilterDescendantsInstances=ignore
    local direction=part.Position-cam.CFrame.Position
    if direction.Magnitude<0.01 then return true end
    local ok,hit=pcall(function() return workspace:Raycast(cam.CFrame.Position,direction,ray) end)
    -- Fail closed: do not aim through walls when a game's raycast fails.
    if not ok then return false end
    return not hit or (part.Parent and hit.Instance:IsDescendantOf(part.Parent))
end
local function eligible(p)
    if not p or p==LP or p.Parent~=Players then return false end
    if S.TeamCheck and LP.Team and p.Team==LP.Team and not LP.Neutral and not p.Neutral then return false end
    local char=p.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
    local r=root(char); local cam=workspace.CurrentCamera
    if not hum or hum.Health<=0 or not r or not cam then return false end
    return (r.Position-cam.CFrame.Position).Magnitude<=S.MaxDistance
end
local function targetScore(p,cam)
    if not eligible(p) then return end
    local part=aimPart(p); if not part then return end
    local v,on=cam:WorldToViewportPoint(part.Position)
    local cx,cy=screenCenter(cam)
    if not on or v.Z<=0 or not withinFOV(v.X,v.Y,cx,cy,S.FOV) then return end
    if not visible(part) then return end
    return (v.X-cx)^2+(v.Y-cy)^2
end
local function pick(cam)
    if S.Sticky and target and targetScore(target,cam) then return target end
    local best,score
    for _,p in ipairs(Players:GetPlayers()) do
        local value=targetScore(p,cam)
        if value and (not score or value<score) then best,score=p,value end
    end
    return best
end
local drawingOK=Drawing and type(Drawing.new)=="function"
local function draw(kind,props)
    if not drawingOK then return end
    local ok,d=pcall(function() return Drawing.new(kind) end)
    if not ok then return end
    for k,v in pairs(props or {}) do pcall(function() d[k]=v end) end
    return d
end
local function removeDrawing(d) if d then pcall(function() d:Remove() end) end end
local Visual={}
function Visual.rainbow(p,now,phase)
    return Color3.fromHSV((now*S.RainbowSpeed+(phase or 0)+(p.UserId%31)/100)%1,0.8,1)
end
function Visual.color(p,now,phase)
    if S.VisualRainbow then return Visual.rainbow(p,now,phase) end
    return S.ESPColor
end
function Visual.opacity(now,phase)
    return S.VisualPulse and (0.78+0.22*(0.5+0.5*math.sin(now*3+(phase or 0)))) or 1
end
function Visual.line(d,a,b,color,thickness,opacity)
    if not d then return end
    d.From=a; d.To=b; d.Color=color; d.Thickness=thickness
    d.Transparency=opacity; d.Visible=true
end
function Visual.hideHat(rec)
    for _,d in pairs(rec.hatFaces or {}) do d.Visible=false end
    for _,d in pairs(rec.hatRim or {}) do d.Visible=false end
    for _,d in pairs(rec.hatRibs or {}) do d.Visible=false end
end
local function newRecord(p)
    local rec={player=p,lines={},outlines={},texts={},hatFaces={},hatRim={},hatRibs={}}
    for i=1,12 do
        rec.lines[i]=draw("Line",{Visible=false,Transparency=1,ZIndex=3})
        rec.outlines[i]=draw("Line",{Visible=false,Transparency=1,Color=Color3.new(0,0,0),ZIndex=2})
    end
    for i=1,3 do rec.texts[i]=draw("Text",{Size=14,Center=true,Outline=true,Visible=false,Transparency=1}) end
    rec.health=draw("Line",{Thickness=3,Visible=false,Transparency=1})
    rec.healthBack=draw("Line",{Thickness=5,Visible=false,Transparency=1,Color=Color3.new(0,0,0)})
    rec.tracer=draw("Line",{Visible=false,Transparency=0.5})
    rec.flow=draw("Line",{Visible=false,Transparency=1})
    records[p]=rec; return rec
end
local function hideRecord(rec)
    for _,group in ipairs({rec.lines,rec.outlines,rec.texts}) do
        for _,d in pairs(group) do d.Visible=false end
    end
    for _,key in ipairs({"health","healthBack","tracer","flow"}) do if rec[key] then rec[key].Visible=false end end
    if rec.highlight then rec.highlight.Enabled=false end
    Visual.hideHat(rec)
end
local function deleteRecord(p)
    local rec=records[p]; if not rec then return end
    for _,group in ipairs({rec.lines,rec.outlines,rec.texts,rec.hatFaces,rec.hatRim,rec.hatRibs}) do
        for _,d in pairs(group) do removeDrawing(d) end
    end
    for _,key in ipairs({"health","healthBack","tracer","flow"}) do removeDrawing(rec[key]) end
    safeDestroy(rec.highlight); records[p]=nil
end
local edges={{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}
local offsets={{-1,1,-1},{1,1,-1},{1,-1,-1},{-1,-1,-1},{-1,1,1},{1,1,1},{1,-1,1},{-1,-1,1}}
local function characterBox(char,cam)
    -- Body parts only: tools/accessories no longer stretch the ESP box.
    local r=root(char); if not r then return end
    local minV,maxV=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
    for _,part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") then
            for _,o in ipairs(offsets) do
                local world=part.CFrame:PointToWorldSpace(Vector3.new(o[1]*part.Size.X/2,o[2]*part.Size.Y/2,o[3]*part.Size.Z/2))
                local v=r.CFrame:PointToObjectSpace(world)
                minV=Vector3.new(math.min(minV.X,v.X),math.min(minV.Y,v.Y),math.min(minV.Z,v.Z))
                maxV=Vector3.new(math.max(maxV.X,v.X),math.max(maxV.Y,v.Y),math.max(maxV.Z,v.Z))
            end
        end
    end
    if minV.X==math.huge then return end
    local center=(minV+maxV)/2; local size=maxV-minV
    local corners={}; local x,y,x2,y2=math.huge,math.huge,-math.huge,-math.huge
    for i,o in ipairs(offsets) do
        local world=r.CFrame:PointToWorldSpace(center+Vector3.new(o[1]*size.X/2,o[2]*size.Y/2,o[3]*size.Z/2))
        local v=cam:WorldToViewportPoint(world)
        if v.Z<=0.05 then return end
        corners[i]=Vector2.new(v.X,v.Y)
        x=math.min(x,v.X); y=math.min(y,v.Y); x2=math.max(x2,v.X); y2=math.max(y2,v.Y)
    end
    return x,y,x2-x,y2-y,corners
end
function Visual.hat(rec,cam,now)
    Visual.hideHat(rec)
    local p=rec.player
    if not drawingOK or not S.Hat or (p==LP and not S.HatSelf) or (p~=LP and (not S.HatOthers or not S.ESP)) then return end
    local char=p.Character; local head=char and char:FindFirstChild("Head")
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if not head or not hum or hum.Health<=0 then return end
    if p==LP and (cam.CFrame.Position-head.Position).Magnitude<1.1 then return end -- first person: avoid covering view
    local n=20 -- fixed mesh detail
    local radius=1.65; local bob=math.sin(now*2.8)*0.08
    local base=head.Position+Vector3.new(0,head.Size.Y/2+0.22+bob,0)
    local tip=base+Vector3.new(0,0.8,0)
    local top=cam:WorldToViewportPoint(tip)
    if top.Z<=0.05 then return end
    local center=cam:WorldToViewportPoint(base)
    if center.Z<=0.05 then return end
    local vp=cam.ViewportSize
    if center.X < -150 or center.X>vp.X+150 or center.Y < -150 or center.Y>vp.Y+150 then return end
    local points={}; local turn=now*S.HatSpin
    for i=1,n do
        local angle=(i-1)/n*math.pi*2+turn
        local v=cam:WorldToViewportPoint(base+Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius))
        if v.Z<=0.05 then return end
        points[i]=Vector2.new(v.X,v.Y)
    end
    local peak=Vector2.new(top.X,top.Y)
    for i=1,n do
        if not rec.hatFaces[i] then rec.hatFaces[i]=draw("Triangle",{Filled=true,Visible=false,ZIndex=1}) end
        if not rec.hatRim[i] then rec.hatRim[i]=draw("Line",{Visible=false,ZIndex=2}) end
        if not rec.hatRibs[i] then rec.hatRibs[i]=draw("Line",{Visible=false,ZIndex=2}) end
        local nextI=i%n+1; local color=Color3.fromRGB(255,130+math.floor(35*math.sin(now+i/n)),25)
        local opacity=Visual.opacity(now,i/n)
        local face=rec.hatFaces[i]
        if face then face.PointA=peak; face.PointB=points[i]; face.PointC=points[nextI]; face.Color=color
            face.Transparency=S.HatOpacity*opacity; face.Visible=true end
        Visual.line(rec.hatRim[i],points[i],points[nextI],color,1.5,opacity)
        if i%3==1 then Visual.line(rec.hatRibs[i],peak,points[i],color,1,opacity*0.65) end
    end
end
local function visualEligible(p,cam)
    if p==LP or p.Parent~=Players then return false end
    if S.ESPTeamCheck and LP.Team and p.Team==LP.Team and not LP.Neutral and not p.Neutral then return false end
    local char=p.Character; local hum=char and char:FindFirstChildOfClass("Humanoid"); local r=root(char)
    if not hum or hum.Health<=0 or not r then return false end
    local own=root(LP.Character)
    return (r.Position-(own and own.Position or cam.CFrame.Position)).Magnitude<=S.MaxDistance
end
local function updateRecord(rec,cam,now,dt)
    hideRecord(rec)
    local p=rec.player
    if not visualEligible(p,cam) then rec.smooth=nil; return end
    local char=p.Character; local r=root(char)
    if rec.char~=char then rec.char=char; rec.smooth=nil; rec.healthRatio=nil end
    local v=cam:WorldToViewportPoint(r.Position)
    if v.Z<=0.05 then rec.smooth=nil; return end
    local cx,cy=screenCenter(cam); local part=aimPart(p)
    local aimV=part and cam:WorldToViewportPoint(part.Position)
    local inFOV=aimV and aimV.Z>0 and withinFOV(aimV.X,aimV.Y,cx,cy,S.FOV)
    local color=Visual.color(p,now,0); local opacity=Visual.opacity(now,p.UserId%7)
    if S.Chams and eligible(p) and inFOV and part and visible(part) then
        if not rec.highlight or rec.highlight.Parent~=char then
            safeDestroy(rec.highlight); rec.highlight=Instance.new("Highlight")
            rec.highlight.Name="SharkChams"; rec.highlight.Parent=char
        end
        local h=rec.highlight
        h.Adornee=char; h.FillColor=color; h.OutlineColor=Visual.color(p,now,0.12)
        h.FillTransparency=pulseTransparency(S.ChamsIntensity,S.ChamsSpeed,now,S.ChamsPulse)
        h.OutlineTransparency=math.min(1,h.FillTransparency+0.1)
        h.DepthMode=S.ChamsWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
        h.Enabled=true
    end
    if not S.ESP or not drawingOK then return end
    Visual.hat(rec,cam,now)
    local x,y,w,h,corners=characterBox(char,cam)
    if not x then rec.smooth=nil; return end
    local vp=cam.ViewportSize
    if x+w<0 or y+h<0 or x>vp.X or y>vp.Y then rec.smooth=nil; return end
    local alpha=S.VisualSmooth<=0 and 1 or (1-math.exp(-S.VisualSmooth*math.clamp(dt or 1/60,0,0.1)))
    local previous=rec.smooth
    if previous and math.abs(x-previous[1])+math.abs(y-previous[2])<250 then
        x=previous[1]+(x-previous[1])*alpha; y=previous[2]+(y-previous[2])*alpha
        w=previous[3]+(w-previous[3])*alpha; h=previous[4]+(h-previous[4])*alpha
    end
    rec.smooth={x,y,w,h}
    local segments={}
    if S.BoxStyle=="3D" then
        for _,e in ipairs(edges) do table.insert(segments,{corners[e[1]],corners[e[2]]}) end
    elseif S.BoxStyle~="None" then
        for _,a in ipairs(boxSegments(x,y,w,h,S.BoxStyle)) do table.insert(segments,{Vector2.new(a[1],a[2]),Vector2.new(a[3],a[4])}) end
    end
    for i,segment in ipairs(segments) do
        Visual.line(rec.outlines[i],segment[1],segment[2],Color3.new(0,0,0),S.ESPBoxThickness+2,opacity*0.8)
        Visual.line(rec.lines[i],segment[1],segment[2],Visual.color(p,now,i/24),S.ESPBoxThickness,opacity)
    end
    for _,d in pairs(rec.texts) do d.Size=S.ESPTextSize end
    local name=rec.texts[1]
    if name and S.Names then name.Text=p.DisplayName.." (@"..p.Name..")"; name.Position=Vector2.new(x+w/2,y-S.ESPTextSize-4)
        name.Color=color; name.Transparency=opacity; name.Visible=true end
    local bottom={}; local own=root(LP.Character)
    if S.Distance then table.insert(bottom,tostring(math.floor((r.Position-(own and own.Position or cam.CFrame.Position)).Magnitude)).." studs") end
    if S.Weapons then local t=char:FindFirstChildOfClass("Tool"); if t then table.insert(bottom,t.Name) end end
    if rec.texts[2] and #bottom>0 then local d=rec.texts[2]; d.Text=table.concat(bottom," | "); d.Position=Vector2.new(x+w/2,y+h+3)
        d.Color=Visual.color(p,now,0.2); d.Transparency=opacity; d.Visible=true end
    local hum=char:FindFirstChildOfClass("Humanoid")
    local ratio=math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1)
    rec.healthRatio=(rec.healthRatio or ratio)+ (ratio-(rec.healthRatio or ratio))*alpha
    if S.Health then
        Visual.line(rec.healthBack,Vector2.new(x-6,y+h),Vector2.new(x-6,y),Color3.new(0,0,0),5,opacity)
        Visual.line(rec.health,Vector2.new(x-6,y+h),Vector2.new(x-6,y+h*(1-rec.healthRatio)),Visual.color(p,now,0.35),3,opacity)
        if rec.texts[3] then local d=rec.texts[3]; d.Text=tostring(math.ceil(hum.Health)); d.Position=Vector2.new(x-18,y+h*(1-rec.healthRatio)-S.ESPTextSize)
            d.Color=color; d.Transparency=opacity; d.Visible=true end
    end
    if S.Tracer then
        local origin=S.TracerOrigin=="Top" and Vector2.new(cx,0) or S.TracerOrigin=="Center" and Vector2.new(cx,cy) or Vector2.new(cx,cam.ViewportSize.Y)
        local dest=Vector2.new(x+w/2,y+h); local delta=dest-origin
        Visual.line(rec.tracer,origin,dest,color,1,opacity*0.45)
        local travel=(now*0.65+p.UserId%13/13)%1
        Visual.line(rec.flow,origin+delta*travel,origin+delta*math.min(1,travel+0.14),Visual.color(p,now,0.3),2.2,opacity)
    end
end


local Misc
local Invis={Active=false,Clone=nil,Parked=nil,OldSubject=nil,OldPos=nil,Conn=nil,CharConn=nil}
local fov=draw("Circle",{Visible=false,Thickness=1.2,Filled=false,NumSides=80,Transparency=0.8})
local function unload()
    if not alive then return end
    pcall(function() if Invis.Active then Invis.disable() end end)
    AutoSave.flush()
    if Misc then Misc.clearOverlay(); Misc.Version=Misc.Version+1 end
    alive=false; target=nil
    Lang.Generation=Lang.Generation+1; table.clear(Lang.Bindings); table.clear(Lang.Labels)
    for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    local list={}; for p in pairs(records) do table.insert(list,p) end
    for _,p in ipairs(list) do deleteRecord(p) end
    removeDrawing(fov)
    if Library and not Library.Unloaded then pcall(function() Library:Unload() end) end
    if env.UniversalMobileAim and env.UniversalMobileAim.Unload==unload then env.UniversalMobileAim=nil end
end
env.UniversalMobileAim={Unload=unload,Settings=S,Version="1.5"}
local function notify(t)
    warn("[Universal Aim] "..t)
    if Library then pcall(function() Library:Notify(t,5) end) end
end
-- Admin candidates: known creator/owner or explicitly configured rules only.
Misc={IDs={},Group=0,MinRank=255,Groups={},ListURL="",ListCache=nil,MarkVerified=false,Matches={},Suppressed={},Pending={},Token=0,Overlay=nil,UISignals={},Version=0}
-- Invisibilidade por troca de personagem: o corpo real fica estacionado (isca, continua
-- replicando no lugar onde voce estava) e voce controla um clone local que so voce ve.
-- Sem hooks e sem remotes. True-invisibility total exige suporte do servidor.
function Invis.enable()
    if Invis.Active then return end
    local char=LP.Character
    if not char then notify("Sem personagem no momento.") return end
    local hrp=char:FindFirstChild("HumanoidRootPart")
    local hum=char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then notify("Personagem incompleto (aguarda respawn).") return end
    local cam=workspace.CurrentCamera
    Invis.OldSubject=cam and cam.CameraSubject or nil
    Invis.OldPos=hrp.CFrame
    char.Archivable=true
    local ok,clone=pcall(function() return char:Clone() end)
    if not ok or not clone then notify("Falha ao clonar o personagem.") return end
    for _,d in ipairs(clone:GetDescendants()) do
        if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Animator") then pcall(function() d:Destroy() end) end
    end
    clone.Name="InvisibleClone"
    clone.Parent=workspace
    pcall(function() hrp.Anchored=true end) -- corpo real vira estatua (nao cai nem anda)
    pcall(function() LP.Character=clone end)
    if cam then pcall(function() cam.CameraSubject=clone:FindFirstChildOfClass("Humanoid") or Invis.OldSubject end) end
    Invis.Clone=clone; Invis.Parked=char; Invis.Active=true
    Invis.Conn=connect(hum.Died,function() Invis.cleanup() end)
    Invis.CharConn=connect(LP.CharacterAdded,function() Invis.cleanup() end)
    notify("Invisivel: corpo real estacionado como isca; voce controla um clone local. Sem respawn, use 'Forcar restaurar'.")
end
function Invis.cleanup()
    Invis.Active=false
    if Invis.Conn then pcall(function() Invis.Conn:Disconnect() end) Invis.Conn=nil end
    if Invis.CharConn then pcall(function() Invis.CharConn:Disconnect() end) Invis.CharConn=nil end
    Invis.Clone=nil; Invis.Parked=nil
end
function Invis.disable()
    if not Invis.Active then return end
    local clone=Invis.Clone
    local pos=nil
    if clone then local c=clone:FindFirstChild("HumanoidRootPart") if c then pos=c.CFrame end end
    if Invis.Parked and Invis.Parked.Parent then
        local hrp=Invis.Parked:FindFirstChild("HumanoidRootPart")
        if hrp then pcall(function() hrp.Anchored=false; hrp.CFrame=pos or Invis.OldPos or hrp.CFrame end) end
        pcall(function() LP.Character=Invis.Parked end)
    end
    if clone then pcall(function() clone:Destroy() end) end
    if workspace.CurrentCamera and Invis.OldSubject then pcall(function() workspace.CurrentCamera.CameraSubject=Invis.OldSubject end) end
    Invis.cleanup()
    if LP.Character==clone then pcall(function() LP:LoadCharacter() end) end
    notify("Invisibilidade desligada.")
end
function Invis.verify()
    if not Invis.Active then notify("Invisibilidade desligada.") return end
    local cam=workspace.CurrentCamera
    local subj=cam and cam.CameraSubject
    local isClone=(LP.Character==Invis.Clone)
    local parkedOk=Invis.Parked~=nil and Invis.Parked.Parent~=nil
    local camOnClone=subj~=nil and Invis.Clone~=nil and subj:IsDescendantOf(Invis.Clone)
    notify(string.format("Invisivel | clone e o personagem: %s | corpo real no jogo: %s | camera no clone: %s",
        tostring(isClone),tostring(parkedOk),tostring(camOnClone)))
    warn("[Invis] Confirmacao 100% (como os outros veem) so com amigo em jogo ou conta alternativa.")
end

-- Deteccao de admins/mods v2: atributos, ValueObjects, nome, multi-grupos e lista remota.
local STAFF_TOKENS={"admin","moder","staff","roblox","modera"}
local STAFF_ATTRS={"IsAdmin","IsModerator","IsMod","IsStaff","IsOwner","Admin","Staff","Moderator","Owner","GameAdmin"}
local function scanValues(root)
    if not root then return nil end
    for _,d in ipairs(root:GetChildren()) do
        if d:IsA("BoolValue") or d:IsA("StringValue") or d:IsA("IntValue") then
            local n=d.Name:lower()
            for _,k in ipairs(STAFF_TOKENS) do
                if n:find(k) and not (d:IsA("BoolValue") and d.Value==false) then
                    return "Valor: "..d.Name.."="..tostring(d.Value)
                end
            end
        end
    end
    return nil
end
local function attrHit(p)
    for _,n in ipairs(STAFF_ATTRS) do
        for _,root in ipairs({p,p.Character}) do
            local v=root and root:GetAttribute(n)
            if v==true or v=="true" or v=="yes" or v==1 then return "Atributo: "..n end
        end
    end
    return scanValues(p) or scanValues(p.Character)
end
local function nameHit(p)
    local n=((p.Name or "").." "..(p.DisplayName or "")):lower()
    for _,k in ipairs(STAFF_TOKENS) do if n:find(k) then return "Nome suspeito ('"..k.."')" end end
    return nil
end
local function groupHit(p)
    for _,g in ipairs(Misc.Groups) do
        local rank=Misc.rank(p,g.Id)
        if rank and rank>=g.MinRank then return "Grupo "..g.Id.." rank "..rank end
    end
    return nil
end
local function listHit(p)
    local cache=Misc.ListCache
    if not cache or cache=="" then return nil end
    if cache:find(","..p.UserId..",") then return "Lista remota de staff" end
    return nil
end
function Misc.fetchList()
    Misc.ListCache=nil
    if Misc.ListURL=="" then return end
    local ok,body=pcall(function() return game:HttpGet(Misc.ListURL,true) end)
    if not ok or type(body)~="string" or #body<3 then warn("[Universal Aim] Lista remota indisponivel.") return end
    if body:sub(1,1)=="[" then
        local okArr,arr=pcall(function() return game:GetService("HttpService"):JSONDecode(body) end)
        if okArr and type(arr)=="table" then
            local t={} for _,id in ipairs(arr) do t[#t+1]=tostring(id) end
            Misc.ListCache=","..table.concat(t,",")..","
        end
    else
        Misc.ListCache=","..body:gsub("[%s,]+",",")..","
    end
    if Misc.ListCache then print("[Universal Aim] Lista remota carregada."); Misc.scan() end
end

function Misc.rank(p,id)
    local ok,value=pcall(function() return p:GetRankInGroupAsync(id) end)
    if not ok then ok,value=pcall(function() return p:GetRankInGroup(id) end) end
    return ok and tonumber(value) or nil
end
function Misc.reason(p)
    if p==LP then return end
    if Misc.IDs[p.UserId] then return Lang.text("ID configurado") end
    if game.CreatorType==Enum.CreatorType.User and p.UserId==game.CreatorId then
        return Lang.text("Criador do jogo")
    end
    if game.CreatorType==Enum.CreatorType.Group and game.CreatorId>0 then
        if Misc.rank(p,game.CreatorId)==255 then return Lang.text("Dono do grupo criador") end
    end
    if Misc.Group>0 then
        local rank=Misc.rank(p,Misc.Group)
        if rank and rank>=Misc.MinRank then return Lang.text("Rank configurado")..": "..rank end
    end
    local r=groupHit(p) if r then return r end
    r=attrHit(p) if r then return r end
    r=listHit(p) if r then return r end
    r=nameHit(p) if r then return r end
    if Misc.MarkVerified and p.HasVerifiedBadge then return "Conta verificada (sinal fraco)" end
end
function Misc.clearOverlay()
    Misc.Token=Misc.Token+1
    for _,c in ipairs(Misc.UISignals) do pcall(function() c:Disconnect() end) end
    Misc.UISignals={}
    safeDestroy(Misc.Overlay); Misc.Overlay=nil
end
function Misc.list()
    local out={}
    for p,reason in pairs(Misc.Matches) do
        if p.Parent==Players and not Misc.Suppressed[p.UserId] then
            table.insert(out,p.DisplayName.." (@"..p.Name..", ID "..p.UserId..") — "..reason)
        end
    end
    table.sort(out); return out
end
function Misc.show()
    if Misc.Overlay or not alive or not S.AdminWatch or #Misc.list()==0 then return end
    Misc.clearOverlay()
    local token=Misc.Token
    local gui=Instance.new("ScreenGui")
    gui.Name="UniversalAdminWarning"; gui.IgnoreGuiInset=true; gui.ResetOnSpawn=false; gui.DisplayOrder=1000000
    gui.Parent=LP:FindFirstChildOfClass("PlayerGui")
    if not gui.Parent then gui:Destroy(); return end
    Misc.Overlay=gui
    local frame=Instance.new("Frame")
    frame.Size=UDim2.fromScale(1,1); frame.BackgroundColor3=Color3.new(0,0,0); frame.BorderSizePixel=0; frame.Active=true; frame.Parent=gui
    local function label(y,h,size)
        local t=Instance.new("TextLabel"); t.Size=UDim2.new(0.9,0,h,0); t.Position=UDim2.new(0.05,0,y,0)
        t.BackgroundTransparency=1; t.TextColor3=Color3.new(1,1,1); t.Font=Enum.Font.GothamBold
        t.TextSize=size; t.TextWrapped=true; t.Parent=frame; return t
    end
    local title=label(0.15,0.1,25); title.Text=Lang.text("POSSIVEIS ADMINS")
    local names=label(0.29,0.3,16)
    local timer=label(0.64,0.1,19)
    local cancel=Instance.new("TextButton")
    cancel.Size=UDim2.fromOffset(220,48); cancel.AnchorPoint=Vector2.new(0.5,0)
    cancel.Position=UDim2.fromScale(0.5,0.8); cancel.Text=Lang.text("Cancelar saida")
    cancel.BackgroundColor3=Color3.fromRGB(45,45,45); cancel.TextColor3=Color3.new(1,1,1)
    cancel.Font=Enum.Font.GothamBold; cancel.TextSize=17; cancel.Parent=frame
    table.insert(Misc.UISignals,cancel.Activated:Connect(function()
        for p in pairs(Misc.Matches) do Misc.Suppressed[p.UserId]=true end
        Misc.clearOverlay()
    end))
    notify(Lang.text("Possivel admin detectado; saida em 5 segundos."))
    -- Frame-driven countdown; no waiting thread or repeated polling task.
    local start=os.clock()
    table.insert(Misc.UISignals,RunService.RenderStepped:Connect(function()
        if not alive or not S.AdminWatch or token~=Misc.Token then return end
        local list=Misc.list()
        if #list==0 then Misc.clearOverlay(); return end
        local elapsed=os.clock()-start
        names.Text=table.concat(list,"\n")
        timer.Text=Lang.text("Saindo em").." "..math.max(0,math.ceil(5-elapsed)).."s"
        title.TextTransparency=0.15+0.15*math.sin(elapsed*4)
        if elapsed>=5 then
            Misc.clearOverlay()
            LP:Kick(Lang.text("Saida automatica: possivel admin detectado."))
        end
    end))
end
function Misc.check(p)
    if not alive or not S.AdminWatch or p==LP or Misc.Pending[p] then return end
    local version=Misc.Version; local ticket={}; Misc.Pending[p]=ticket
    task.spawn(function()
        local ok,reason=pcall(Misc.reason,p)
        if Misc.Pending[p]==ticket then Misc.Pending[p]=nil end
        if not alive or not S.AdminWatch or version~=Misc.Version or p.Parent~=Players then return end
        if ok and reason then Misc.Matches[p]=reason; Misc.show() end
    end)
end
function Misc.scan()
    Misc.Version=Misc.Version+1
    table.clear(Misc.Pending); table.clear(Misc.Matches)
    for _,p in ipairs(Players:GetPlayers()) do Misc.check(p) end
end
function Misc.ui(tab)
    local invisible=tab:AddLeftGroupbox(Lang.text("Invisibilidade"),"eye-off")
    invisible:AddLabel("Troca de personagem: seu corpo real fica estacionado onde voce estava (isca, continua visivel e replicando) e voce controla um clone local que so voce ve.")
    invisible:AddLabel("Invisibilidade total (ninguem ve nada) exige suporte do servidor; isto e o maximo client-side, sem hooks.")
    invisible:AddToggle("UMA_Invisible",{Text="Invisibilidade (clone local)",Default=false,Callback=function(v)
        if v then Invis.enable() else Invis.disable() end
    end})
    invisible:AddButton({Text=Lang.text("Verificar invisibilidade"),Func=function() Invis.verify() end})
    invisible:AddButton({Text="Forcar restaurar personagem",Func=function()
        Invis.disable(); task.wait(0.2); pcall(function() LP:LoadCharacter() end)
    end})
    local admin=tab:AddRightGroupbox(Lang.text("Verificacao de admins"),"shield-alert")
    Lang.bind(admin:AddToggle("UMA_AdminWatch",{Text=Lang.text("Verificar automaticamente"),Default=S.AdminWatch,
        Callback=function(v)
            S.AdminWatch=v; Misc.Version=Misc.Version+1; Misc.clearOverlay()
            if v then table.clear(Misc.Suppressed); Misc.scan() end
            AutoSave.changed()
        end}),"Verificar automaticamente")
    admin:AddLabel(Lang.text("Sem configuracao: apenas criador ou dono do grupo criador. Nao detecta todos os admins."))
    admin:AddInput("UMA_AdminIDs",{Text=Lang.text("IDs opcionais (separados por virgula)"),Default="",Finished=true,
        Callback=function(text)
            Misc.IDs={}; for id in tostring(text):gmatch("%d+") do Misc.IDs[tonumber(id)]=true end
            Misc.scan()
        end})
    admin:AddInput("UMA_AdminGroup",{Text="Grupos id:rank (virgula p/ varios)",Default="",Finished=true,
        Callback=function(text)
            Misc.Groups={}
            for id,rk in tostring(text):gmatch("(%d+)%s*:%s*(%d+)") do table.insert(Misc.Groups,{Id=tonumber(id),MinRank=tonumber(rk)}) end
            Misc.scan()
        end})
    admin:AddInput("UMA_AdminList",{Text="URL de lista remota de IDs (opcional)",Default="",Finished=true,
        Callback=function(text) Misc.ListURL=tostring(text):gsub("^%s*(.-)%s*$","%1"); Misc.fetchList() end})
    admin:AddToggle("UMA_MarkVerified",{Text="Marcar contas verificadas (sinal fraco)",Default=false,
        Callback=function(v) Misc.MarkVerified=v; Misc.scan() end})
    admin:AddButton({Text="Atualizar lista remota",Func=function() Misc.fetchList() end})
    admin:AddSlider("UMA_AdminRank",{Text=Lang.text("Rank minimo"),Default=255,Min=1,Max=255,Rounding=0,
        Callback=function(v) Misc.MinRank=v; Misc.scan() end})
    connect(Players.PlayerAdded,function(p)
        pcall(function() connect(p.AttributeChanged,function() Misc.check(p) end) end)
        Misc.check(p)
    end)
    connect(Players.PlayerRemoving,function(p)
        Misc.Matches[p]=nil; Misc.Suppressed[p.UserId]=nil; Misc.Pending[p]=nil
    end)
    if S.AdminWatch then Misc.scan() end
end

local function boot()
    Lang.detect()
    local source=game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua")
    local chunk,err=loadstring(source); if not chunk then error(err) end
    Library=chunk(); assert(type(Library)=="table" and type(Library.CreateWindow)=="function","Obsidian indisponivel")
    local window=Library:CreateWindow({Title="Universal Mobile Aim",Footer="Camera aim | Normal / Halloween",
        Icon="crosshair",Center=true,AutoShow=true,Size=UDim2.fromOffset(710,550),
        ShowCustomCursor=false,ShowMobileButtons=true,ToggleKeybind=Enum.KeyCode.RightControl})
    Library:OnUnload(unload)
    local aim=window:AddTab("Aimbot","crosshair")
    local visuals=window:AddTab("Visuais","eye")
    local settingsTab=window:AddTab("Temas","palette")
    local miscTab=window:AddTab("Misc","settings-2")
    local function toggle(g,key,text,after)
        return Lang.bind(g:AddToggle("UMA_"..key,{Text=Lang.text(text),Default=S[key],Callback=function(v) S[key]=v; if after then after(v) end; AutoSave.changed() end}),text)
    end
    local function slider(g,key,text,min,max,round)
        return Lang.bind(g:AddSlider("UMA_"..key,{Text=Lang.text(text),Default=S[key],Min=min,Max=max,Rounding=round or 0,Callback=function(v) S[key]=v end}),text)
    end
    local function dropdown(g,key,text,values)
        return Lang.bind(g:AddDropdown("UMA_"..key,{Text=Lang.text(text),Values=values,Default=S[key],Callback=function(v) S[key]=v; target=nil end}),text)
    end
    local lock=aim:AddLeftGroupbox("Trava automatica mobile","target")
    toggle(lock,"Aim","Ativar aimbot",function() target=nil end)
    lock:AddLabel("Liga pelo toggle. Sem segurar botao, sem silent aim.")
    dropdown(lock,"AimPart","Parte alvo",{"Head","Torso","UpperTorso","HumanoidRootPart"})
    slider(lock,"AimSmooth","Velocidade da mira",1,30,0)
    toggle(lock,"Sticky","Manter alvo valido")
    lock:AddLabel("Menu aberto pausa mira e visuais; fechar retoma os toggles.")
    local filters=aim:AddRightGroupbox("Filtros e FOV","filter")
    toggle(filters,"TeamCheck","Ignorar meu time")
    toggle(filters,"WallCheck","Verificar paredes")
    toggle(filters,"ShowFOV","Mostrar FOV")
    slider(filters,"FOV","Raio FOV",25,600,0)
    slider(filters,"MaxDistance","Distancia maxima",100,5000,0)
    filters:AddLabel("Alvo no centro da tela. Personagens R6/R15 com Humanoid.")
    local esp=visuals:AddRightGroupbox("ESP animado","scan")
    toggle(esp,"ESP","Ativar ESP",function(v) if v and not drawingOK then notify("Executor sem Drawing: ESP indisponivel") end end)
    local picker=esp:AddLabel("Cor geral do ESP"):AddColorPicker("UMA_ESPColor",{Default=S.ESPColor,Callback=function(c) S.ESPColor=c end})
    dropdown(esp,"BoxStyle","Caixas",{"None","2D","Corner","3D"})
    toggle(esp,"VisualPulse","Pulso animado")
    slider(esp,"VisualSmooth","Suavizacao das caixas",0,35,0)
    toggle(esp,"ESPTeamCheck","Ignorar meu time no ESP")
    toggle(esp,"Names","Nomes")
    toggle(esp,"Health","Vida")
    toggle(esp,"Distance","Distancia")
    toggle(esp,"Weapons","Arma equipada")
    toggle(esp,"Tracer","Tracers com fluxo")
    dropdown(esp,"TracerOrigin","Origem do tracer",{"Bottom","Center","Top"})
    slider(esp,"ESPTextSize","Texto",10,22,0)
    slider(esp,"ESPBoxThickness","Espessura",1,4,1)
    local hats=visuals:AddLeftGroupbox("Chapeu laranja","cone")
    toggle(hats,"Hat","Ativar chapeu")
    toggle(hats,"HatSelf","No meu personagem")
    toggle(hats,"HatOthers","Nos jogadores do ESP")
    hats:AddLabel("Tamanho fixo; rotacao e flutuacao. Oculto em primeira pessoa.")
    slider(hats,"HatOpacity","Opacidade",0,0.7,2)
    slider(hats,"HatSpin","Rotacao",0,2,1)
    local chams=visuals:AddLeftGroupbox("Chams","waves")
    toggle(chams,"Chams","Chams no FOV")
    toggle(chams,"ChamsWalls","Chams atraves das paredes")
    slider(chams,"ChamsIntensity","Intensidade",0,100,0)
    local themes=settingsTab:AddLeftGroupbox("Aparencia","palette")
    local palettes={
        Normal={MainColor=Color3.fromRGB(25,25,28),BackgroundColor=Color3.fromRGB(13,13,15),
            AccentColor=Color3.fromRGB(235,235,235),OutlineColor=Color3.fromRGB(67,67,72),FontColor=Color3.fromRGB(242,242,245)},
        Halloween={MainColor=Color3.fromRGB(29,23,20),BackgroundColor=Color3.fromRGB(14,11,10),
            AccentColor=Color3.fromRGB(255,135,30),OutlineColor=Color3.fromRGB(87,54,31),FontColor=Color3.fromRGB(255,239,220)}}
    local function applyTheme(value)
        S.Theme=value; local palette=palettes[value] or palettes.Normal
        for k,c in pairs(palette) do Library.Scheme[k]=c end
        Library:UpdateColorsUsingRegistry()
        S.ESPColor=value=="Halloween" and Color3.fromRGB(255,135,30) or Color3.fromRGB(240,240,240)
        if picker and type(picker.SetValueRGB)=="function" then picker:SetValueRGB(S.ESPColor) end
    end
    Lang.bind(themes:AddDropdown("UMA_Theme",{Text=Lang.text("Tema"),Values={"Normal","Halloween"},Default="Normal",Callback=applyTheme}),"Tema")
    themes:AddLabel("Mudar tema redefine a cor do ESP; voce pode personalizar depois.")
    themes:AddButton({Text="Desativar mira e visuais",Func=function()
        for _,key in ipairs({"Aim","ESP","Chams","Hat"}) do
            S[key]=false; local t=Library.Toggles["UMA_"..key]; if t then t:SetValue(false) end
        end
        target=nil
    end})
    themes:AddButton({Text="Fechar e limpar tudo",Func=unload})
    local info=settingsTab:AddRightGroupbox("Compatibilidade","info")
    info:AddLabel("Sem hooks, remotes, silent ou modificacoes de arma.")
    info:AddLabel("Jogos com camera customizada podem sobrescrever a mira.")
    info:AddLabel("Drawing necessario para ESP e chapeus. Nao mira em NPCs.")
    local language=settingsTab:AddRightGroupbox("Idioma","languages")
    Lang.bind(language:AddDropdown("UMA_Language",{Text=Lang.text("Idioma da interface"),
        Values={"Auto","Português","English","Español"},Default="Auto",Callback=Lang.select}),"Idioma da interface")
    language:AddLabel("Auto usa API de pais por IP; nao salva IP nem coordenadas.")
    language:AddButton({Text="Detectar novamente",Func=Lang.detect})
    Misc.ui(miscTab)
    Lang.apply()
    if Library.ScreenGui then
        connect(Library.ScreenGui.DescendantAdded,function(node)
            task.defer(function() if alive then Lang.gui(node) end end)
        end)
    end
    applyTheme("Normal")
    AutoSave.Ready=true
    AutoSave.flush()
    connect(LP.CharacterAdded,function() target=nil end)
    connect(Players.PlayerRemoving,function(p) deleteRecord(p); if target==p then target=nil end end)
    local lastError=0
    connect(RunService.RenderStepped,function(dt)
        if not alive then return end
        local ok,err=pcall(function()
            local cam=workspace.CurrentCamera; if not cam then return end
            -- Mandatory pause, including local hats and the FOV circle.
            if Library.Toggled or (Misc and Misc.Overlay) then
                target=nil
                if fov then fov.Visible=false end
                for _,rec in pairs(records) do hideRecord(rec); rec.smooth=nil end
                return
            end
            local now=os.clock(); local cx,cy=screenCenter(cam)
            if fov then fov.Position=Vector2.new(cx,cy); fov.Radius=S.FOV; fov.Color=S.ESPColor; fov.Visible=S.ShowFOV end
            local own=LP.Character; local hum=own and own:FindFirstChildOfClass("Humanoid")
            local canAim=S.Aim and hum and hum.Health>0 and not UIS:GetFocusedTextBox() and not Library.Toggled
            if canAim then
                target=pick(cam)
                local part=target and aimPart(target)
                if part then
                    local origin=cam.CFrame.Position
                    if (part.Position-origin).Magnitude>0.01 then
                        cam.CFrame=cam.CFrame:Lerp(CFrame.lookAt(origin,part.Position),1-math.exp(-S.AimSmooth*math.min(dt,0.1)))
                    end
                end
            else target=nil end
            if S.Hat and S.HatSelf and drawingOK then Visual.hat(records[LP] or newRecord(LP),cam,now)
            elseif records[LP] then Visual.hideHat(records[LP]) end
            if S.ESP or S.Chams then
                for _,p in ipairs(Players:GetPlayers()) do
                    if p~=LP then
                        local rec=records[p] or newRecord(p)
                        local success,problem=pcall(updateRecord,rec,cam,now,dt)
                        if not success then pcall(hideRecord,rec)
                            if now-(rec.lastError or 0)>5 then rec.lastError=now; warn("[Universal ESP] "..tostring(problem)) end
                        end
                    end
                end
            else for p,rec in pairs(records) do if p~=LP then hideRecord(rec) end end end
        end)
        if not ok and os.clock()-lastError>5 then lastError=os.clock(); notify(tostring(err)) end
    end)
end
local ok,err=xpcall(boot,function(e) return tostring(e).."\n"..debug.traceback() end)
if not ok then notify("Falha: "..tostring(err)); unload() end

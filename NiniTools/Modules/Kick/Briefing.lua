local ADDON_NAME = ...
local RDE = _G.NiniKick or {}
_G.NiniKick = RDE

local listening=false
local challengeStarted=false
local sessionConfigured=false
local currentInstanceID=0
local lastAppliedKey=""
local lastAppliedAt=0
local unassignedResetDone=false
local parserTestMode=false

local function secretValue(v)
  return type(issecretvalue)=="function" and issecretvalue(v)
end

local function safeChatText(v)
  if v==nil or secretValue(v) then return nil end
  local ok,s=pcall(tostring,v)
  return ok and s or nil
end

local function safeNumber(v)
  if v==nil or secretValue(v) then return nil end
  local ok,n=pcall(tonumber,v)
  return ok and n or nil
end

local MARKER_NAMES={"별","동그라미","다이아","세모","달","네모","가위표","해골"}
local MARKER_ALIASES={
  {id=1, aliases={"{rt1}","{star}","스타","별","★"}},
  {id=2, aliases={"{rt2}","{circle}","동그라미","동글","원형","원","●","○"}},
  {id=3, aliases={"{rt3}","{diamond}","다이아몬드","다이아","다야","마름모","◆","◇"}},
  {id=4, aliases={"{rt4}","{triangle}","역삼각","역삼","세모","삼각","▼","▽"}},
  {id=5, aliases={"{rt5}","{moon}","초승달","달","☾","☽"}},
  {id=6, aliases={"{rt6}","{square}","네모","사각","■","□"}},
  {id=7, aliases={"{rt7}","{cross}","가위표","가위","엑스","cross","x","×","✕","✖"}},
  {id=8, aliases={"{rt8}","{skull}","해골","스컬","☠"}},
}

-- 브리핑 참가자 정보는 저장 변수에 그대로 넣을 수 있는 값만 사용한다.
-- classFile/role은 실제 파티 unit token과 차단 쿨을 연결할 때 사용한다.
local CLASS_ALIAS_META={
  ["탱"]={kind="OTHER",role="TANK",label="탱"}, ["탱커"]={kind="OTHER",role="TANK",label="탱커"},

  ["죽"]={kind="OTHER",classFile="DEATHKNIGHT",label="죽"}, ["죽기"]={kind="OTHER",classFile="DEATHKNIGHT",label="죽기"},
  ["죽탱"]={kind="OTHER",classFile="DEATHKNIGHT",role="TANK",label="죽탱"},
  ["냉죽"]={kind="OTHER",classFile="DEATHKNIGHT",label="냉죽",specID=251}, ["부죽"]={kind="OTHER",classFile="DEATHKNIGHT",label="부죽",specID=252},
  ["혈죽"]={kind="OTHER",classFile="DEATHKNIGHT",role="TANK",label="혈죽",specID=250},

  ["악"]={kind="OTHER",classFile="DEMONHUNTER",label="악"}, ["악사"]={kind="OTHER",classFile="DEMONHUNTER",label="악사"},
  ["악탱"]={kind="OTHER",classFile="DEMONHUNTER",role="TANK",label="악탱"},
  ["파멸"]={kind="OTHER",classFile="DEMONHUNTER",label="파멸",specID=577}, ["복수"]={kind="OTHER",classFile="DEMONHUNTER",role="TANK",label="복수",specID=581},

  ["냥"]={kind="OTHER",classFile="HUNTER",label="냥"}, ["냥꾼"]={kind="OTHER",classFile="HUNTER",label="냥꾼"},
  ["사냥꾼"]={kind="OTHER",classFile="HUNTER",label="사냥꾼"}, ["야냥"]={kind="OTHER",classFile="HUNTER",label="야냥",specID=253},
  ["격냥"]={kind="OTHER",classFile="HUNTER",label="격냥",specID=254}, ["생냥"]={kind="OTHER",classFile="HUNTER",label="생냥",specID=255},

  ["법"]={kind="OTHER",classFile="MAGE",label="법"}, ["법사"]={kind="OTHER",classFile="MAGE",label="법사"},
  ["마법사"]={kind="OTHER",classFile="MAGE",label="마법사"}, ["비법"]={kind="OTHER",classFile="MAGE",label="비법",specID=62},
  ["화법"]={kind="OTHER",classFile="MAGE",label="화법",specID=63}, ["냉법"]={kind="OTHER",classFile="MAGE",label="냉법",specID=64},

  ["흑"]={kind="OTHER",classFile="WARLOCK",label="흑"}, ["흑마"]={kind="OTHER",classFile="WARLOCK",label="흑마"},
  ["흑마법사"]={kind="OTHER",classFile="WARLOCK",label="흑마법사"}, ["고흑"]={kind="OTHER",classFile="WARLOCK",label="고흑",specID=265},
  ["악흑"]={kind="OTHER",classFile="WARLOCK",label="악흑",specID=266}, ["파흑"]={kind="OTHER",classFile="WARLOCK",label="파흑",specID=267},

  ["술"]={kind="OTHER",classFile="SHAMAN",label="술"}, ["주술"]={kind="OTHER",classFile="SHAMAN",label="주술"},
  ["주술사"]={kind="OTHER",classFile="SHAMAN",label="주술사"}, ["정술"]={kind="OTHER",classFile="SHAMAN",label="정술",specID=262},
  ["고술"]={kind="OTHER",classFile="SHAMAN",label="고술",specID=263}, ["복술"]={kind="OTHER",classFile="SHAMAN",label="복술",specID=264},

  ["드"]={kind="OTHER",classFile="DRUID",label="드"}, ["드루"]={kind="OTHER",classFile="DRUID",label="드루"},
  ["드루이드"]={kind="OTHER",classFile="DRUID",label="드루이드"}, ["조드"]={kind="OTHER",classFile="DRUID",label="조드",specID=102},
  ["야드"]={kind="OTHER",classFile="DRUID",label="야드",specID=103}, ["회드"]={kind="OTHER",classFile="DRUID",label="회드",specID=105},
  ["수드"]={kind="OTHER",classFile="DRUID",role="TANK",label="수드",specID=104},

  ["전"]={kind="OTHER",classFile="WARRIOR",label="전"}, ["전사"]={kind="OTHER",classFile="WARRIOR",label="전사"},
  ["무전"]={kind="OTHER",classFile="WARRIOR",label="무전",specID=71}, ["분전"]={kind="OTHER",classFile="WARRIOR",label="분전",specID=72},
  ["전탱"]={kind="OTHER",classFile="WARRIOR",role="TANK",label="전탱",specID=73}, ["방전"]={kind="OTHER",classFile="WARRIOR",role="TANK",label="방전",specID=73},

  ["성"]={kind="OTHER",classFile="PALADIN",label="성"}, ["기사"]={kind="OTHER",classFile="PALADIN",label="기사"},
  ["성기사"]={kind="OTHER",classFile="PALADIN",label="성기사"}, ["보기"]={kind="OTHER",classFile="PALADIN",role="TANK",label="보기",specID=66},
  ["신기"]={kind="OTHER",classFile="PALADIN",label="신기",specID=65}, ["징기"]={kind="OTHER",classFile="PALADIN",label="징기",specID=70},

  ["사"]={kind="OTHER",classFile="PRIEST",label="사"}, ["사제"]={kind="OTHER",classFile="PRIEST",label="사제"},
  ["암사"]={kind="OTHER",classFile="PRIEST",label="암사",specID=258}, ["수사"]={kind="OTHER",classFile="PRIEST",label="수사",specID=256},
  ["신사"]={kind="OTHER",classFile="PRIEST",label="신사",specID=257},

  ["기"]={kind="OTHER",classFile="MONK",label="기"}, ["수도"]={kind="OTHER",classFile="MONK",label="수도"},
  ["수도사"]={kind="OTHER",classFile="MONK",label="수도사"}, ["양조"]={kind="OTHER",classFile="MONK",role="TANK",label="양조",specID=268},
  ["운무"]={kind="OTHER",classFile="MONK",label="운무",specID=270}, ["풍운"]={kind="OTHER",classFile="MONK",label="풍운",specID=269},

  ["용"]={kind="OTHER",classFile="EVOKER",label="용"}, ["기원사"]={kind="OTHER",classFile="EVOKER",label="기원사"},
  ["증강"]={kind="OTHER",classFile="EVOKER",label="증강",specID=1473}, ["황폐"]={kind="OTHER",classFile="EVOKER",label="황폐",specID=1467},
  ["보존"]={kind="OTHER",classFile="EVOKER",label="보존",specID=1468},

  ["도"]={kind="ROGUE",classFile="ROGUE",label="도"}, ["도적"]={kind="ROGUE",classFile="ROGUE",label="도적"},
  ["잠"]={kind="ROGUE",classFile="ROGUE",label="잠",specID=261}, ["잠행"]={kind="ROGUE",classFile="ROGUE",label="잠행",specID=261},
  ["무"]={kind="ROGUE",classFile="ROGUE",label="무",specID=260}, ["무법"]={kind="ROGUE",classFile="ROGUE",label="무법",specID=260},
  ["암살"]={kind="ROGUE",classFile="ROGUE",label="암살",specID=259}, ["암도"]={kind="ROGUE",classFile="ROGUE",label="암도",specID=259},
}

local TOKEN_SUFFIXES={
  "이었습니다","였습니다","입니다","이에요","예요","이네요","네요",
  "인데요","인데","이고","이면","이라면","일때만","일때","일 때만","일 때",
  "부터","까지","하고","이랑","랑","님께서","님이","님은","님도","님","께서","에게","한테",
  "으로","로","은","는","이","가","도","만","요",
}

local CONDITIONAL_WORDS={
  "있으면","있을때","있을 때","나오면","나올때","나올 때","생기면","보이면",
  "찍히면","찍으면","찍었을때","찍었을 때","찍혔을때","찍혔을 때","때만",
}

local SOLO_WORDS={"혼자","단독","솔로","혼차"}


local ENGLISH_MARKERS={
  star=1,circle=2,diamond=3,triangle=4,moon=5,square=6,cross=7,skull=8,
}

local function normalizeMessage(message)
  local raw=safeChatText(message)
  if not raw then return nil,"secret" end
  local ok,text=pcall(string.lower,raw)
  if not ok or not text then return nil,"invalid" end
  -- 레이드 징표가 {rtN}, {circle}, 텍스처/아틀라스 태그 등 어떤 형태여도 같은 토큰으로 통일한다.
  text=text:gsub("|[tT][^|]-[uU][iI]%-[rR]aid[tT]argeting[iI]con[_%-]?(%d)[^|]-|[tT]"," {rt%1} ")
  text=text:gsub("|[aA]:[^|]-[rR]aid[tT]arget[^|]-[_%-](%d)[^|]-|[aA]"," {rt%1} ")
  text=text:gsub("{([%a]+)}",function(name)
    local id=ENGLISH_MARKERS[name]
    return id and ("{rt"..id.."}") or ("{"..name.."}")
  end)
  -- Lua 패턴의 [] 문자 클래스는 UTF-8 문자를 바이트 단위로 처리하므로 한글까지 손상시킬 수 있다.
  -- 전각/유니코드 문장부호는 각각 정확한 문자열로 치환한다.
  text=text:gsub("，",","):gsub("、",",")
  text=text:gsub("；",";"):gsub("：",":")
  text=text:gsub("／","/"):gsub("｜","|")
  text=text:gsub("·"," "):gsub("ㆍ"," "):gsub("•"," ")
  text=text:gsub("[\r\n]+"," / ")
  return text
end

local function P(msg)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff00cfff니니차단|r "..tostring(msg)) end
end

local function startsWith(text,prefix)
  return text:sub(1,#prefix)==prefix
end

local function endsWith(text,suffix)
  return suffix~="" and #text>#suffix and text:sub(-#suffix)==suffix
end

local function containsAny(text,list)
  for _,word in ipairs(list) do
    if text:find(word,1,true) then return true end
  end
  return false
end

local function isSeparatorChar(ch)
  return ch=="" or ch:match("[%s,/%|:;%.%!%?%-%>%+%=%(%）%[%]%{%}]")~=nil
end

local function strictAliasBoundary(text,s,e,alias)
  -- 한 글자 징표 별칭은 일반 단어 속 오인식을 줄이기 위해 앞뒤 문맥을 제한한다.
  if #alias>3 or startsWith(alias,"{rt") then return true end
  local before=s>1 and text:sub(s-1,s-1) or ""
  local after=text:sub(e+1)
  local beforeOK=(s==1) or isSeparatorChar(before)
  local afterOK=(after=="") or isSeparatorChar(after:sub(1,1))
    or startsWith(after,"은") or startsWith(after,"는") or startsWith(after,"이") or startsWith(after,"가")
    or startsWith(after,"도") or startsWith(after,"만") or startsWith(after,"있") or startsWith(after,"없")
    or startsWith(after,"나오") or startsWith(after,"찍") or startsWith(after,"혼자") or startsWith(after,"단독")
  return beforeOK and afterOK
end

local function markerMentions(text)
  local candidates={}
  for _,entry in ipairs(MARKER_ALIASES) do
    for _,alias in ipairs(entry.aliases) do
      local pos=1
      while true do
        local s,e=text:find(alias,pos,true)
        if not s then break end
        if strictAliasBoundary(text,s,e,alias) then
          candidates[#candidates+1]={start=s,finish=e,marker=entry.id,alias=alias}
        end
        pos=e+1
      end
    end
  end
  table.sort(candidates,function(a,b)
    if a.start==b.start then return (a.finish-a.start)>(b.finish-b.start) end
    return a.start<b.start
  end)
  local out={}
  local lastFinish=0
  for _,item in ipairs(candidates) do
    if item.start>lastFinish then
      out[#out+1]=item
      lastFinish=item.finish
    end
  end
  return out
end

local function playerIsAssassination()
  if not GetSpecialization or not GetSpecializationInfo then return false end
  local spec=GetSpecialization()
  if not spec then return false end
  local ok,id=pcall(GetSpecializationInfo,spec)
  return ok and tonumber(id)==259
end

local function groupHasPriest()
  if UnitClass then
    local _,class=UnitClass("player")
    if class=="PRIEST" then return true end
    for i=1,4 do
      local unit="party"..i
      if UnitExists(unit) then
        local _,partyClass=UnitClass(unit)
        if partyClass=="PRIEST" then return true end
      end
    end
  end
  return false
end

local function currentPlayerIdentity()
  local classFile=nil
  if UnitClass then
    local ok,_,value=pcall(UnitClass,"player")
    if ok then classFile=value end
  end
  local specID=nil
  if GetSpecialization and GetSpecializationInfo then
    local spec=GetSpecialization()
    if spec then
      local ok,id=pcall(GetSpecializationInfo,spec)
      if ok then specID=tonumber(id) end
    end
  end
  local role=nil
  if UnitGroupRolesAssigned then
    local ok,value=pcall(UnitGroupRolesAssigned,"player")
    if ok and value and value~="NONE" then role=value end
  end
  if not role and GetSpecializationRole and GetSpecialization then
    local spec=GetSpecialization()
    if spec then
      local ok,value=pcall(GetSpecializationRole,spec)
      if ok and value and value~="NONE" then role=value end
    end
  end
  return classFile,specID,role
end

local function participantMatchesPlayer(meta)
  if type(meta)~="table" then return false end
  local classFile,specID,role=currentPlayerIdentity()
  local constrained=false
  if meta.classFile then
    constrained=true
    if classFile~=meta.classFile then return false end
  end
  if meta.specID then
    constrained=true
    if not specID or tonumber(meta.specID)~=tonumber(specID) then return false end
  end
  if meta.role then
    constrained=true
    if not role or role~=meta.role then return false end
  end
  return constrained
end

local function unitIdentityForMatch(unit)
  if not unit or not UnitExists or not UnitExists(unit) then return nil,nil,nil end
  local classFile=nil
  if UnitClass then
    local ok,_,cf=pcall(UnitClass,unit)
    if ok then classFile=cf end
  end
  local role=nil
  if UnitGroupRolesAssigned then
    local ok,value=pcall(UnitGroupRolesAssigned,unit)
    if ok and value and value~="NONE" then role=value end
  end
  local specID=nil
  if unit=="player" then
    local _,sid=currentPlayerIdentity()
    specID=sid
  elseif GetInspectSpecialization then
    local ok,sid=pcall(GetInspectSpecialization,unit)
    sid=ok and safeNumber(sid) or nil
    if sid and sid>0 then specID=sid end
  end
  return classFile,specID,role
end

local function unitCouldMatchMeta(unit,meta)
  if type(meta)~="table" then return false end
  local classFile,specID,role=unitIdentityForMatch(unit)
  if meta.classFile and classFile~=meta.classFile then return false end
  if meta.role and role and role~=meta.role then return false end
  if meta.role and not role then return false end
  if meta.specID then
    -- 파티원의 spec을 아직 공개 API로 확인하지 못한 경우 같은 직업이면
    -- '아닐 것'이라고 추측하지 않는다. 자동 브리핑에서는 보수적으로 중복 가능성으로 처리한다.
    if specID and tonumber(specID)~=tonumber(meta.specID) then return false end
    if not specID and meta.classFile and classFile~=meta.classFile then return false end
  end
  return meta.classFile~=nil or meta.role~=nil or meta.specID~=nil
end

local function playerDirectiveIsAmbiguous(meta)
  if parserTestMode or not participantMatchesPlayer(meta) then return false end
  local count=0
  for _,unit in ipairs({"player","party1","party2","party3","party4"}) do
    if unitCouldMatchMeta(unit,meta) then
      count=count+1
      if count>1 then return true end
    end
  end
  return false
end

local function copyMeta(meta,token)
  if not meta then return nil end
  return {
    kind=meta.kind,
    classFile=meta.classFile,
    role=meta.role,
    specID=meta.specID,
    token=meta.label or token,
  }
end

local function classifyBareAssassination()
  if not playerIsAssassination() then return nil,"암은 현재 도적 전문화와 불일치" end
  if groupHasPriest() then return nil,"암은 암살/암사 구분이 필요" end
  local meta={kind="ROGUE",classFile="ROGUE",label="암",specID=259}
  return "ROGUE",nil,copyMeta(meta,"암")
end

local function classifyToken(token)
  if token=="" then return nil end
  -- 실제 파티 브리핑에서 "저랑죽기님", "나랑법사님"처럼 조사/대명사를 붙여 쓰는 경우가 있다.
  -- 앞의 화자 표현만 제거해 뒤 직업 토큰을 정상 인식한다.
  for _,prefix in ipairs({"저랑","나랑","저와","나와","저하고","나하고"}) do
    if startsWith(token,prefix) and #token>#prefix then
      token=token:sub(#prefix+1)
      break
    end
  end
  local direct=CLASS_ALIAS_META[token]
  if direct then return direct.kind,nil,copyMeta(direct,token) end
  if token=="암" then return classifyBareAssassination() end

  for _,suffix in ipairs(TOKEN_SUFFIXES) do
    if endsWith(token,suffix) then
      local stem=token:sub(1,#token-#suffix)
      local stemMeta=CLASS_ALIAS_META[stem]
      if stemMeta then return stemMeta.kind,nil,copyMeta(stemMeta,stem) end
      if stem=="암" then return classifyBareAssassination() end
    end
  end
  return nil
end

local function tokensFromSegment(segment)
  local text=segment
  text=text:gsub("[,%/%|:;%(%)%[%]%{%}%+%=]"," ")
  text=text:gsub("%-%>"," ")
  text=text:gsub("→"," ")
  text=text:gsub("그리고"," ")
  local tokens={}
  for token in text:gmatch("%S+") do
    token=token:gsub("^[%.%!%?%-]+",""):gsub("[%.%!%?%-]+$","")
    if token~="" then tokens[#tokens+1]=token end
  end
  return tokens
end

local UNMARKED_WORDS={
  "무징표","징 없이","징없이","징표 없이","징표없이","마크 없이","마크없이",
  "징 안찍","징 안 찍","징표 안찍","징표 안 찍","마크 안찍","마크 안 찍",
  "징 없어","징표 없어","마크 없어","징 안나와","징표 안나와","징 안 나와","징표 안 나와",
}

local function hasPlayerDirective(text)
  for token in tostring(text or ""):gmatch("%S+") do
    token=token:gsub("^[,%/%|:;%(%)%[%]%{%}%+%=%.%!%?%-]+",""):gsub("[,%/%|:;%(%)%[%]%{%}%+%=%.%!%?%-]+$","")
    local _,_,meta=classifyToken(token)
    if meta and participantMatchesPlayer(meta) then return true end
  end
  return false
end

local function parseUnmarkedSoloDirective(message,text)
  if not hasPlayerDirective(text) then return nil end
  if not text:find("차단",1,true) then return nil end
  if not containsAny(text,UNMARKED_WORDS) then return nil end
  if not (text:find("전담",1,true) or text:find("봐주",1,true) or text:find("맡",1,true)
      or text:find("혼자",1,true) or text:find("단독",1,true)) then
    return nil
  end
  return {sourceText=message,clauses={},unmarkedSolo=true}
end

local function splitOrderedToken(token)
  local pure=token:match("^([123])$") or token:match("^([123])차$")
    or token:match("^([123])번$") or token:match("^([123])순$") or token:match("^([123])순번$")
  if pure then return tonumber(pure),nil,true end

  local order,rest=token:match("^([123])순번(.+)$")
  if not order then order,rest=token:match("^([123])번(.+)$") end
  if not order then order,rest=token:match("^([123])차(.+)$") end
  if not order then order,rest=token:match("^([123])[%.)](.+)$") end
  if not order then order,rest=token:match("^([123])(.+)$") end
  if order and rest and rest~="" then return tonumber(order),rest,false end

  local body,suffix=token:match("^(.+)([123])$")
  if body and suffix then return tonumber(suffix),body,false end
  return nil,token,false
end

local function parseSegmentInfo(segment)
  local entries={}
  local ambiguity=nil
  local pendingOrder=nil
  for _,token in ipairs(tokensFromSegment(segment)) do
    local explicitOrder,classToken,pureOrder=splitOrderedToken(token)
    if pureOrder then
      pendingOrder=explicitOrder
    else
      local lookup=classToken or token
      local kind,reason,meta=classifyToken(lookup)
      if reason and not ambiguity then ambiguity=reason end
      if kind then
        entries[#entries+1]={
          kind=kind,
          meta=meta or {kind=kind,token=lookup},
          order=explicitOrder or pendingOrder,
        }
        pendingOrder=nil
      end
    end
  end
  return {
    entries=entries,
    conditional=containsAny(segment,CONDITIONAL_WORDS),
    explicitSolo=containsAny(segment,SOLO_WORDS),
    ambiguity=ambiguity,
    segment=segment,
  }
end

local function buildClause(marker,infos)
  local slots={}
  local unnumbered={}
  local ambiguity=nil
  local conditional=false
  local explicitSolo=false
  local entryCount=0

  for _,info in ipairs(infos) do
    if info.ambiguity and not ambiguity then ambiguity=info.ambiguity end
    conditional=conditional or info.conditional
    explicitSolo=explicitSolo or info.explicitSolo
    for _,entry in ipairs(info.entries) do
      entryCount=entryCount+1
      local order=tonumber(entry.order)
      if order and order>=1 and order<=3 then
        -- 같은 순번이 두 번 명시되면 임의로 다음 빈칸에 밀어 넣지 않는다.
        -- 예: "동글 1 도적 동글 1 흑마"를 2인 로테로 오해하면 실전 차단 순서가 뒤집힐 수 있다.
        if slots[order] then
          return nil,"같은 차단 순번이 중복 지정됨"
        end
        slots[order]=entry
      else
        unnumbered[#unnumbered+1]=entry
      end
    end
  end

  if entryCount==0 then return nil,ambiguity end
  local nextSlot=1
  for _,entry in ipairs(unnumbered) do
    while nextSlot<=3 and slots[nextSlot] do nextSlot=nextSlot+1 end
    if nextSlot<=3 then
      slots[nextSlot]=entry
      nextSlot=nextSlot+1
    else
      slots[#slots+1]=entry
    end
  end

  local highest=0
  for index,entry in pairs(slots) do
    if entry and type(index)=="number" and index>highest then highest=index end
  end
  local size=math.max(entryCount,highest)
  local participants={}
  local playerIndex=nil
  local playerCount=0
  for index=1,size do
    local entry=slots[index]
    if entry then
      local meta=entry.meta
      if participantMatchesPlayer(meta) then
        if playerDirectiveIsAmbiguous(meta) then
          return nil,"동일 직업/전문화 파티원이 중복되어 담당자를 자동 식별할 수 없음"
        end
        playerCount=playerCount+1
        if not playerIndex then playerIndex=index end
        meta={
          kind="PLAYER", classFile=meta.classFile, role=meta.role, specID=meta.specID, token=meta.token,
        }
      end
      participants[index]=meta
    else
      participants[index]={kind="OTHER",token=tostring(index).."순번"}
    end
  end

  if not playerIndex then return nil,ambiguity end
  if playerCount>1 then return nil,"현재 캐릭터 담당 표기가 한 구문에 중복됨" end
  return {
    marker=marker,
    size=size,
    order=playerIndex,
    participants=participants,
    conditional=conditional,
    explicitSolo=explicitSolo,
    segment=table.concat((function()
      local out={}
      for _,info in ipairs(infos) do out[#out+1]=info.segment end
      return out
    end)()," / "),
  },ambiguity
end

local function parseMessage(message)
  local text,normalizeReason=normalizeMessage(message)
  if not text then return nil,normalizeReason or "메시지 접근 불가" end
  local unmarked=parseUnmarkedSoloDirective(message,text)
  local mentions=markerMentions(text)
  if #mentions==0 then
    if unmarked then return unmarked end
    return nil,"징표 없음"
  end

  -- 브리핑 말투는 크게 두 가지를 모두 지원한다.
  --   1) 징표 → 사람: "별 죽기님 도적님"
  --   2) 사람 → 징표: "저랑죽기님 다야, 도적님 냥꾼님 별"
  -- 첫 징표 앞에 직업 토큰이 있으면 그 문장은 '사람 → 징표' 형식으로 본다.
  -- 이렇게 해야 두 징표 사이의 참가자 묶음을 앞 징표에 잘못 붙이지 않는다.
  local preFirst=text:sub(1,mentions[1].start-1)
  local preFirstInfo=parseSegmentInfo(preFirst)
  local suffixMarkerStyle=#preFirstInfo.entries>0

  -- 같은 징표를 여러 번 적는 브리핑을 한 로테이션으로 합친다.
  -- 예: "동글 도적 동글 2 흑마"처럼 같은 징표가 반복되어도 현재 캐릭터의 담당 순번을 찾는다.
  local groups={}
  local groupOrder={}
  local ambiguity=nil
  for i,item in ipairs(mentions) do
    local segment
    if suffixMarkerStyle then
      local prevFinish=mentions[i-1] and mentions[i-1].finish or 0
      segment=text:sub(prevFinish+1,item.start-1)
    else
      local nextStart=mentions[i+1] and mentions[i+1].start or (#text+1)
      segment=text:sub(item.finish+1,nextStart-1)
    end
    local info=parseSegmentInfo(segment)
    if info.ambiguity and not ambiguity then ambiguity=info.ambiguity end
    if #info.entries>0 then
      local key=tostring(item.marker)..":"..(info.conditional and "conditional" or "base")
      if not groups[key] then
        groups[key]={marker=item.marker,infos={},first=i}
        groupOrder[#groupOrder+1]=key
      end
      groups[key].infos[#groups[key].infos+1]=info
    end
  end

  table.sort(groupOrder,function(a,b) return groups[a].first<groups[b].first end)
  local clauses={}
  for _,key in ipairs(groupOrder) do
    local group=groups[key]
    local clause,reason=buildClause(group.marker,group.infos)
    if clause then clauses[#clauses+1]=clause end
    if reason and not ambiguity then ambiguity=reason end
  end
  if #clauses==0 then return nil,ambiguity or "현재 캐릭터 담당 구문 없음" end

  local result={sourceText=message,clauses=clauses}
  for _,clause in ipairs(clauses) do
    if clause.size>3 then
      return nil,"4인 이상 로테이션은 자동 적용하지 않음"
    end
    if clause.conditional then
      if not result.override then
        result.override={marker=clause.marker,size=1,order=1,mode="solo"}
      end
    elseif not result.base then
      local size=math.max(1,clause.size)
      result.base={marker=clause.marker,size=size,order=clause.order,participants=clause.participants}
    elseif (clause.explicitSolo or clause.size==1) and not result.override then
      result.override={marker=clause.marker,size=1,order=1,mode="solo"}
    end
  end

  if unmarked then result.unmarkedSolo=true end
  if not result.base and not result.override and not result.unmarkedSolo then
    return nil,ambiguity or "적용 가능한 규칙 없음"
  end
  return result,ambiguity
end


function RDE.MarkBriefingSessionConfigured(source)
  sessionConfigured=true
  unassignedResetDone=true
end

local function getDB()
  return type(RogueDefensivesDB)=="table" and RogueDefensivesDB or nil
end

local function activeChallenge()
  if not (C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID) then return false end
  local ok,mapID=pcall(C_ChallengeMode.GetActiveChallengeMapID)
  return ok and tonumber(mapID) and tonumber(mapID)>0 or false
end

local function partyInstanceInfo()
  local inInstance,instanceType=IsInInstance()
  if not inInstance or instanceType~="party" then return false,0 end
  local instanceID=0
  if GetInstanceInfo then
    local ok,_,_,_,_,_,_,_,id=pcall(GetInstanceInfo)
    if ok then instanceID=tonumber(id) or 0 end
  end
  return true,instanceID
end

local function refreshListening()
  local db=getDB()
  if not db or db.autoBriefing==false then
    listening=false
    return
  end
  local inPartyInstance,instanceID=partyInstanceInfo()
  -- 돌을 꽂은 직후의 준비/카운트다운 중에도 읽고, 실제 CHALLENGE_MODE_START가 온 뒤에만 종료한다.
  listening=inPartyInstance and not challengeStarted
  if inPartyInstance and instanceID>0 then
    currentInstanceID=instanceID
    if tonumber(db.briefingSessionInstanceID or 0)~=instanceID then
      unassignedResetDone=false
      sessionConfigured=false
      if RDE.ClearAutoBriefingAssignment then RDE.ClearAutoBriefingAssignment("새 던전") end
      db.briefingSessionInstanceID=instanceID
    end
  end
end


local function applyParsed(result,sender)
  if not result then return false end
  local safeSender=safeChatText(sender) or ""
  local safeSource=safeChatText(result.sourceText) or ""
  result.sender=safeSender
  result.sourceText=safeSource
  local key=safeSource.."|"..safeSender
  local t=GetTime and GetTime() or 0
  if key==lastAppliedKey and t-lastAppliedAt<1.5 then return false end
  lastAppliedKey,lastAppliedAt=key,t
  if RDE.ApplyBriefingAssignment then
    local ok=RDE.ApplyBriefingAssignment(result)
    if ok then sessionConfigured=true; unassignedResetDone=true end
    return ok and true or false
  end
  return false
end

local function sameSender(sender,unit)
  sender=safeChatText(sender)
  if not sender or sender=="" or not UnitExists(unit) then return false end
  local name,realm=UnitName(unit)
  name=safeChatText(name)
  realm=safeChatText(realm)
  if not name then return false end
  local full=(realm and realm~="") and (name.."-"..realm) or name
  return sender==name or sender==full or sender:match("^([^%-]+)")==name
end

local function senderIsBriefingAuthority(sender)
  local units={"player","party1","party2","party3","party4"}
  for _,unit in ipairs(units) do
    if sameSender(sender,unit) then
      local roleRaw=UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"
      local role=safeChatText(roleRaw) or "NONE"
      local leaderRaw=UnitIsGroupLeader and UnitIsGroupLeader(unit) or false
      local leader=(not secretValue(leaderRaw) and leaderRaw==true) or false
      if role=="TANK" or leader then return true,"tank-or-leader" end
      -- 실제 쐐기에서는 역할 정보가 NONE으로 늦게 잡히거나 탱커가 파티장이 아닌 경우가 있다.
      -- 징표+현재 캐릭터 담당 구문이 완전히 파싱된 파티원 메시지는 허용하되 일반 문장은 parseMessage에서 걸러낸다.
      return true,"party-member"
    end
  end
  -- CHAT_MSG_PARTY/INSTANCE_CHAT에서 온 메시지는 roster 갱신 지연으로 unit을 못 찾더라도 패턴이 명확하면 허용한다.
  return true,"unresolved-party-member"
end

local function onChat(message,sender)
  local db=getDB()
  if not listening or not db or db.autoBriefing==false then return end
  local safeMessage=safeChatText(message)
  local safeSender=safeChatText(sender)
  -- Midnight protected chat payload can arrive as secret values. Never index/normalize those values.
  if not safeMessage or not safeSender then return end
  local result,reason=parseMessage(safeMessage)
  if not result then
    if reason and reason:find("암은",1,true) then
      P("브리핑의 '암'이 암살/암사 중 무엇인지 애매해 자동 적용하지 않았습니다.")
    elseif reason and reason:find("동일 직업/전문화",1,true) then
      P("동일 직업/전문화 파티원이 있어 직업명만으로는 내 담당을 확정할 수 없어 자동 적용하지 않았습니다.")
    end
    return
  end
  if not senderIsBriefingAuthority(safeSender) then return end
  applyParsed(result,safeSender)
end

function RDE.ApplyBriefingText(text,sender)
  local safeText=safeChatText(text)
  if not safeText then return false,"메시지 접근 불가" end
  local result,reason=parseMessage(safeText)
  if not result then return false,reason or "파서 결과 없음" end
  result.sourceText=safeText
  local applied=applyParsed(result,sender or "수동")
  return applied,applied and nil or "같은 설정이 이미 적용됨"
end

local function currentPlayerTestToken()
  local _,specID=currentPlayerIdentity()
  if tonumber(specID)==259 then return "암살" end
  if tonumber(specID)==260 then return "무법" end
  if tonumber(specID)==261 then return "잠행" end
  return "도적"
end

local function runParserTests()
  local me=currentPlayerTestToken()
  local cases={
    {name="징표→사람 2순", text="별 죽기님 "..me.."님", marker=1,size=2,order=2},
    {name="징표→사람 1순", text="별 "..me.."님 죽기님", marker=1,size=2,order=1},
    {name="사람→징표", text=me.."님 냥꾼님 별", marker=1,size=2,order=1},
    {name="실전 suffix형", text="저랑죽기님 다야, "..me.."님 냥꾼님 별 봐주시궁", marker=1,size=2,order=1},
    {name="반복징표+명시2", text="동글 "..me.." 동글 2 흑마", marker=2,size=2,order=1},
    {name="반복징표 자동2", text="동글 흑마 동글 "..me, marker=2,size=2,order=2},
    {name="앞 순번 비움", text="별 2 "..me, marker=1,size=2,order=2},
    {name="조건부 단독", text="다이아 있으면 "..me, override=3},
    {name="무징표 전담", text="무징표 "..me.." 전담 차단", unmarked=true},
    {name="중복 순번 거부", text="동글 1 "..me.." 동글 1 흑마", fail="같은 차단 순번"},
    {name="4인 거부", text="별 죽기 흑마 냥꾼 "..me, fail="4인 이상"},
  }
  local passed=0
  local failures={}
  parserTestMode=true
  local okRun,err=pcall(function()
    for _,case in ipairs(cases) do
      local result,reason=parseMessage(case.text)
      local ok=false
      if case.fail then
        ok=result==nil and type(reason)=="string" and reason:find(case.fail,1,true)~=nil
      elseif case.unmarked then
        ok=type(result)=="table" and result.unmarkedSolo==true
      elseif case.override then
        ok=type(result)=="table" and type(result.override)=="table" and tonumber(result.override.marker)==case.override
      else
        local base=type(result)=="table" and result.base or nil
        ok=type(base)=="table" and tonumber(base.marker)==case.marker and tonumber(base.size)==case.size and tonumber(base.order)==case.order
      end
      if ok then
        passed=passed+1
      else
        failures[#failures+1]=case.name.." ["..tostring(reason or "결과 불일치").."]"
      end
    end
  end)
  parserTestMode=false
  if not okRun then
    P("브리핑 파서 테스트 실행 오류 · "..tostring(err))
    return false
  end
  P(string.format("브리핑 파서 testall · %d/%d PASS",passed,#cases))
  for _,failure in ipairs(failures) do P("FAIL · "..failure) end
  return passed==#cases
end


function RDE.HandleBriefingCommand(input)
  local db=getDB()
  if not db then P("설정이 아직 초기화되지 않았습니다."); return end
  local cmd,arg=tostring(input or ""):match("^(%S*)%s*(.-)%s*$")
  cmd=(cmd or ""):lower()
  if cmd=="on" then
    db.autoBriefing=true
    refreshListening()
    P("브리핑 자동 감지 켜짐")
  elseif cmd=="off" then
    db.autoBriefing=false
    listening=false
    P("브리핑 자동 감지 꺼짐")
  elseif cmd=="clear" then
    if RDE.ClearBriefingAssignment then RDE.ClearBriefingAssignment(false) end
    P("브리핑 자동 설정 초기화")
  elseif cmd=="testall" then
    runParserTests()
  elseif cmd=="test" or cmd=="set" or cmd=="apply" or cmd=="manual" then
    if arg=="" then
      P("사용법: /rd briefing set 별 죽기 / 동글 도적,흑마")
      return
    end
    local sender=(cmd=="test") and "테스트" or "수동"
    local ok,reason=RDE.ApplyBriefingText(arg,sender)
    if ok then
      P((cmd=="test" and "파서 테스트" or "수동 브리핑").." 적용 완료")
    else
      P("브리핑 적용 실패 · "..tostring(reason or "알 수 없음"))
    end
  else
    local listenText=listening and "감지 중" or "대기/종료"
    local summary=RDE.GetBriefingSummary and RDE.GetBriefingSummary() or "미설정"
    P("브리핑 "..(db.autoBriefing==false and "꺼짐" or "켜짐").." · "..listenText.." · "..summary)
    if db.briefingLastText and db.briefingLastText~="" then P("마지막 문장: "..db.briefingLastText) end
    P("파서 회귀검사: /nk briefing testall")
  end
end

local frame=_G.NiniTools.EventDispatcher:CreateProxy("Kick.Briefing")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("CHALLENGE_MODE_START")
frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
frame:RegisterEvent("CHALLENGE_MODE_RESET")
frame:RegisterEvent("CHAT_MSG_PARTY")
frame:RegisterEvent("CHAT_MSG_PARTY_LEADER")
frame:RegisterEvent("CHAT_MSG_INSTANCE_CHAT")
frame:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER")
frame:SetScript("OnEvent",function(_,event,...)
  if event=="CHAT_MSG_PARTY" or event=="CHAT_MSG_PARTY_LEADER" or event=="CHAT_MSG_INSTANCE_CHAT" or event=="CHAT_MSG_INSTANCE_CHAT_LEADER" then
    local message,sender=...
    onChat(message,sender)
  elseif event=="CHALLENGE_MODE_START" then
    if not sessionConfigured and not unassignedResetDone and RDE.ResetUnassignedInterruptSession then
      RDE.ResetUnassignedInterruptSession("브리핑/수동 배정 없음")
      unassignedResetDone=true
    end
    challengeStarted=true
    listening=false
  elseif event=="CHALLENGE_MODE_COMPLETED" or event=="CHALLENGE_MODE_RESET" then
    challengeStarted=false
    sessionConfigured=false
    unassignedResetDone=false
    if RDE.ClearAutoBriefingAssignment then RDE.ClearAutoBriefingAssignment(event=="CHALLENGE_MODE_COMPLETED" and "쐐기 완료" or "쐐기 초기화") end
    refreshListening()
    C_Timer.After(.5,refreshListening)
  elseif event=="PLAYER_ENTERING_WORLD" then
    local initialLogin,isReloadingUi=...
    challengeStarted=activeChallenge() and true or false
    local inPartyInstance,instanceID=partyInstanceInfo()
    local db=getDB()
    if inPartyInstance and instanceID>0 and db and tonumber(db.briefingSessionInstanceID or 0)~=instanceID then
      unassignedResetDone=false
      sessionConfigured=false
      db.briefingSessionInstanceID=instanceID
    end
    -- 로딩 화면을 거쳐 새 쐐기 준비 구역으로 들어온 경우 이전 자동 배정을 한 번만 제거한다.
    -- /reload는 현재 브리핑을 보존하고, 진행 중인 쐐기도 건드리지 않는다.
    if inPartyInstance and not challengeStarted and not isReloadingUi and not unassignedResetDone then
      sessionConfigured=false
      if RDE.ResetUnassignedInterruptSession then
        RDE.ResetUnassignedInterruptSession(initialLogin and "던전에서 로그인" or "새 던전 준비")
      elseif RDE.ClearAutoBriefingAssignment then
        RDE.ClearAutoBriefingAssignment("던전 재입장")
      end
      unassignedResetDone=true
    end
    refreshListening()
    C_Timer.After(.5,refreshListening)
  elseif event=="PLAYER_LOGIN" then
    challengeStarted=activeChallenge() and true or false
    refreshListening()
    C_Timer.After(.5,refreshListening)
  elseif event=="GROUP_ROSTER_UPDATE" then
    if IsInGroup and not IsInGroup() then
      sessionConfigured=false
      unassignedResetDone=false
      if RDE.ClearAutoBriefingAssignment then RDE.ClearAutoBriefingAssignment("파티 해제") end
    end
    refreshListening()
    C_Timer.After(.5,refreshListening)
  end
end)

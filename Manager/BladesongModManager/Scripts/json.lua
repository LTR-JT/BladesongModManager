-- Bounded JSON codec. No load(), executable deserialization or metatable transfer.
local J={null={}}
function J.encode(v,depth)
 depth=(depth or 0)+1;assert(depth<=32,'JSON nesting limit')
 local t=type(v)
 if v==J.null or t=='nil'then return 'null'elseif t=='boolean'then return tostring(v)elseif t=='number'then assert(v==v and math.abs(v)<math.huge,'Non-finite number');return tostring(v)
 elseif t=='string'then return '"'..v:gsub('[%z\1-\31\\"]',function(c)return ({['"']='\\"',['\\']='\\\\',['\n']='\\n',['\r']='\\r',['\t']='\\t'})[c]or string.format('\\u%04x',c:byte())end)..'"'
 elseif t=='table'then
  local n,count=#v,0;for k in pairs(v)do count=count+1 end
  local parts={};if n>0 and count==n then for i=1,n do parts[#parts+1]=J.encode(v[i],depth)end;return '['..table.concat(parts,',')..']'end
  for k,value in pairs(v)do assert(type(k)=='string','JSON object keys must be strings');parts[#parts+1]=J.encode(k,depth)..':'..J.encode(value,depth)end;table.sort(parts);return '{'..table.concat(parts,',')..'}'
 end
 error('Unsupported JSON type '..t)
end
function J.decode(s)
 assert(type(s)=='string'and #s<=1048576,'Invalid JSON size');local i=1
 local function ws()local _,e=s:find('^[ \t\r\n]*',i);i=(e or i-1)+1 end
 local value
 local function str()
  assert(s:sub(i,i)=='"');i=i+1;local out={}
  while i<=#s do local c=s:sub(i,i);i=i+1
   if c=='"'then return table.concat(out)elseif c=='\\'then local e=s:sub(i,i);i=i+1;local m={['"']='"',['\\']='\\',['/']='/',b='\b',f='\f',n='\n',r='\r',t='\t'}
    if e=='u'then local h=s:sub(i,i+3);assert(h:match('^%x%x%x%x$'),'Invalid unicode');i=i+4;local cp=tonumber(h,16)
     if cp>=0xD800 and cp<=0xDBFF then assert(s:sub(i,i+1)=='\\u','Missing low surrogate');local low=tonumber(s:sub(i+2,i+5),16);assert(low and low>=0xDC00 and low<=0xDFFF);i=i+6;cp=0x10000+(cp-0xD800)*1024+low-0xDC00 end
     assert(not(cp>=0xD800 and cp<=0xDFFF),'Invalid surrogate');out[#out+1]=utf8.char(cp)
    else assert(m[e],'Invalid escape');out[#out+1]=m[e]end
   else assert(c:byte()>=32,'JSON control character');out[#out+1]=c end
  end;error('Unterminated JSON string')
 end
 value=function(depth)
  assert(depth<=32,'JSON nesting limit');ws();local c=s:sub(i,i)
  if c=='"'then return str()elseif c=='{'or c=='['then
   i=i+1;ws();local out={};local close=c=='{'and '}'or ']';if s:sub(i,i)==close then i=i+1;return out end
   while true do
    if c=='{'then ws();local k=str();assert(out[k]==nil,'Duplicate JSON key');ws();assert(s:sub(i,i)==':');i=i+1;out[k]=value(depth+1)else out[#out+1]=value(depth+1)end
    ws();local d=s:sub(i,i);i=i+1;if d==close then return out end;assert(d==',','JSON separator expected')
   end
  elseif s:sub(i,i+3)=='true'then i=i+4;return true elseif s:sub(i,i+4)=='false'then i=i+5;return false elseif s:sub(i,i+3)=='null'then i=i+4;return J.null
  else local token=s:match('^-?%d+%.?%d*[eE]?[+%-]?%d*',i);assert(token and not token:match('^-?0%d')and not token:match('%.$'),'Invalid JSON number');local n=tonumber(token);assert(n and n==n and math.abs(n)<math.huge);i=i+#token;return n end
 end
 local out=value(1);ws();assert(i>#s,'Trailing JSON data');return out
end
return J

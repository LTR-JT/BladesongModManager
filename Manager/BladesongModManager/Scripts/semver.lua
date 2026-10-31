local M={}
function M.parse(s)local a,b,c,pre=s:match('^(%d+)%.(%d+)%.(%d+)(.*)$');assert(a and (pre==''or pre:match('^%-[%w%.%-]+$')),'Invalid semantic version');return {tonumber(a),tonumber(b),tonumber(c),pre}end
function M.compare(a,b)
 a=M.parse(a);b=M.parse(b);for i=1,3 do if a[i]~=b[i]then return a[i]<b[i]and -1 or 1 end end
 if a[4]==b[4]then return 0 end;if a[4]==''then return 1 elseif b[4]==''then return -1 end
 local ap,bp={},{};for p in a[4]:sub(2):gmatch('[^.]+')do ap[#ap+1]=p end;for p in b[4]:sub(2):gmatch('[^.]+')do bp[#bp+1]=p end
 for i=1,math.max(#ap,#bp)do
  if not ap[i]then return -1 elseif not bp[i]then return 1 elseif ap[i]~=bp[i]then
   local an,bn=tonumber(ap[i]),tonumber(bp[i]);if an and bn then return an<bn and -1 or 1 elseif an then return -1 elseif bn then return 1 else return ap[i]<bp[i]and -1 or 1 end
  end
 end;return 0
end

function M.matches(v,range)
 assert(type(range)=='string'and #range>0,'Version range required')
 if range=='*'then return true end
 for token in range:gmatch('%S+')do
  local op,target=token:match('^([<>=%^]+)(.+)$');if not op then op='=';target=token end
  local cmp=M.compare(v,target)
  if op=='^'then local t=M.parse(target);local top=t[1]>0 and(t[1]+1)..'.0.0'or(t[2]>0 and '0.'..(t[2]+1)..'.0'or '0.0.'..(t[3]+1));if cmp<0 or M.compare(v,top)>=0 then return false end
  elseif not((op=='='and cmp==0)or(op=='>='and cmp>=0)or(op=='>'and cmp>0)or(op=='<='and cmp<=0)or(op=='<'and cmp<0))then return false end
 end;return true
end
return M

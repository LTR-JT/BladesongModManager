// Windows-only process adapter. No shell and no game-memory reads.
// The Lua entry uses the same Lua 5.4 integer TValue ABI as the existing adapters.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
typedef unsigned long long u64;
typedef long long i64;
static bool pointer(u64 p){return p>=0x10000&&p<0x800000000000ull;}
static bool integer(void* L,int n,u64& v){
 if(!L)return false;u64 ci=*(u64*)((u64)L+0x20);if(!pointer(ci))return false;
 u64 frame=*(u64*)ci;if(!pointer(frame))return false;u64 tv=frame+16ull*n;
 if(*(unsigned char*)(tv+8)!=3)return false;v=*(u64*)tv;return true;
}
static int result(void* L,i64 value){u64 top=*(u64*)((u64)L+0x10);if(!pointer(top))return 0;*(i64*)top=value;*(unsigned char*)(top+8)=3;*(u64*)((u64)L+0x10)=top+16;return 1;}
extern "C" __declspec(dllexport) DWORD bmf_spawn_worker(const wchar_t* executable,const wchar_t* job){
 if(!executable||!job||!executable[0]||!job[0])return 0;
 struct Buffer{wchar_t value[32768];};
 Buffer* buffer=(Buffer*)HeapAlloc(GetProcessHeap(),0,sizeof(Buffer));if(!buffer)return 0;
 wchar_t* command=buffer->value;unsigned i=0;
 for(const wchar_t* p=executable;*p;++p)if(*p==L'"'||*p<L' ')return 0;
 command[i++]=L'"';for(const wchar_t* p=executable;*p;++p){if(i>16000){HeapFree(GetProcessHeap(),0,buffer);return 0;}command[i++]=*p;}command[i++]=L'"';command[i++]=L' ';command[i++]=L'"';
 for(const wchar_t* p=job;*p;++p){if(i>=32765||*p==L'"'||*p<L' '){HeapFree(GetProcessHeap(),0,buffer);return 0;}command[i++]=*p;}command[i++]=L'"';command[i]=0;
 STARTUPINFOW start={};start.cb=sizeof(start);start.dwFlags=STARTF_USESHOWWINDOW;start.wShowWindow=SW_HIDE;
 PROCESS_INFORMATION process={};
 BOOL launched=CreateProcessW(executable,command,0,0,FALSE,CREATE_NO_WINDOW,0,0,&start,&process);HeapFree(GetProcessHeap(),0,buffer);if(!launched)return 0;
 DWORD pid=process.dwProcessId;CloseHandle(process.hThread);CloseHandle(process.hProcess);return pid;
}
extern "C" __declspec(dllexport) int bmf_launch(void* L){
 struct Buffers{char bytes[16001];wchar_t executable[16001],job[16001];};
 Buffers* memory=(Buffers*)HeapAlloc(GetProcessHeap(),0,sizeof(Buffers));if(!memory)return 0;
 int count=0;
 __try{__try{
  u64 size=0;if(!integer(L,1,size)||size<4||size>16000){count=result(L,0);__leave;}
  unsigned separator=0;bool good=true;
  for(unsigned i=0;i<size;++i){u64 v=0;if(!integer(L,2+i,v)||v>255){good=false;break;}memory->bytes[i]=(char)v;if(!v){if(separator){good=false;break;}separator=i;}}memory->bytes[size]=0;
  if(!good||!separator||separator>=size-1){count=result(L,0);__leave;}
  if(!MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,memory->bytes,-1,memory->executable,16001)||!MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,memory->bytes+separator+1,-1,memory->job,16001)){count=result(L,0);__leave;}
  count=result(L,bmf_spawn_worker(memory->executable,memory->job));
 }__except(EXCEPTION_EXECUTE_HANDLER){count=0;}}__finally{HeapFree(GetProcessHeap(),0,memory);}
 return count;
}

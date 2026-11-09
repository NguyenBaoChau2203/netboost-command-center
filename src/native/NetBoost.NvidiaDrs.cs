// Minimal DRS binding based on the public NVIDIA NVAPI SDK (MIT).
// See docs/cs2-research.md and assets/licenses/NVIDIA-NVAPI.txt.
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace NetBoost {
    public sealed class DriverSetting {
        public uint Id { get; set; }
        public uint Value { get; set; }
        public bool UserOverride { get; set; }
    }
    public sealed class DriverSnapshot {
        public string ProfileName { get; set; }
        public DriverSetting[] Settings { get; set; }
    }
    public sealed class NvidiaDrs : IDisposable {
        const int SettingSize=12320, ProfileSize=4116, ApplicationSize=20492;
        const int ValueOffset=8220, NotFound=-160;
        IntPtr library;
        IntPtr session, profile;
        readonly string profileName;
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate IntPtr Query(uint id);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int Initialize();
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int CreateSession(out IntPtr handle);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int SessionAction(IntPtr handle);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl,CharSet=CharSet.Unicode)] delegate int FindApp(IntPtr s,[MarshalAs(UnmanagedType.LPWStr)] string name,out IntPtr p,IntPtr app);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int GetBase(IntPtr s,out IntPtr p);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int GetProfile(IntPtr s,IntPtr p,IntPtr info);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int EnumApps(IntPtr s,IntPtr p,uint start,ref uint count,IntPtr app);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int GetSetting(IntPtr s,IntPtr p,uint id,IntPtr setting);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int SetSetting(IntPtr s,IntPtr p,IntPtr setting);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int DeleteSetting(IntPtr s,IntPtr p,uint id);
        [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr LoadLibraryEx(string path,IntPtr file,uint flags);
        [DllImport("kernel32.dll",CharSet=CharSet.Ansi,ExactSpelling=true)] static extern IntPtr GetProcAddress(IntPtr module,string name);
        [DllImport("kernel32.dll")] static extern bool FreeLibrary(IntPtr module);
        readonly Query query;
        T Function<T>(uint id) where T:class {
            var address=query(id);
            if(address==IntPtr.Zero) throw new InvalidOperationException("Installed NVIDIA driver does not expose required DRS API.");
            return Marshal.GetDelegateForFunctionPointer(address,typeof(T)) as T;
        }
        static void Check(int status,string action) { if(status!=0) throw new InvalidOperationException(action+" failed (NVAPI "+status+")."); }
        static IntPtr Buffer(int size,int version) {
            var p=Marshal.AllocHGlobal(size);
            Marshal.Copy(new byte[size],0,p,size);
            Marshal.WriteInt32(p,size|(version<<16));
            return p;
        }
        static void Allowed(uint id) {
            if(id!=274197361U && id!=6600001U) throw new InvalidOperationException("Setting is outside NetBoost's CS2 allowlist.");
        }
        public NvidiaDrs(string executable) {
            if(!System.IO.Path.IsPathRooted(executable) || !String.Equals(System.IO.Path.GetFileName(executable),"cs2.exe",StringComparison.OrdinalIgnoreCase)) throw new ArgumentException("A full cs2.exe path is required.");
            library=LoadLibraryEx(IntPtr.Size==8?"nvapi64.dll":"nvapi.dll",IntPtr.Zero,0x800);
            if(library==IntPtr.Zero) throw new InvalidOperationException("NVIDIA NVAPI is unavailable in the system directory.");
            try {
                query=(Query)Marshal.GetDelegateForFunctionPointer(GetProcAddress(library,"nvapi_QueryInterface"),typeof(Query));
                Check(Function<Initialize>(0x0150e828)(),"Initialize");
                Check(Function<CreateSession>(0x0694d52e)(out session),"Create DRS session");
                Check(Function<SessionAction>(0x375dbd6b)(session),"Load DRS settings");
                var app=Buffer(ApplicationSize,4);
                try { Check(Function<FindApp>(0xeee566b2)(session,executable,out profile,app),"Find CS2 application profile"); }
                finally { Marshal.FreeHGlobal(app); }
                IntPtr baseProfile;
                Check(Function<GetBase>(0xda8466a0)(session,out baseProfile),"Get base profile");
                if(profile==baseProfile) throw new InvalidOperationException("Refusing to edit the global NVIDIA profile.");
                var info=Buffer(ProfileSize,1);
                try {
                    Check(Function<GetProfile>(0x61cd6fd6)(session,profile,info),"Read CS2 profile identity");
                    profileName=Marshal.PtrToStringUni(IntPtr.Add(info,4));
                    if(String.IsNullOrWhiteSpace(profileName) || profileName.IndexOf("Base Profile",StringComparison.OrdinalIgnoreCase)>=0) throw new InvalidOperationException("Unsafe NVIDIA profile identity.");
                    int applicationCount=Marshal.ReadInt32(info,4108);
                    if(applicationCount<1 || applicationCount>8) throw new InvalidOperationException("NVIDIA profile is not isolated to CS2.");
                    var names=new List<string>();
                    for(uint index=0;index<applicationCount;index++) {
                        var application=Buffer(ApplicationSize,4);
                        try {
                            uint count=1;
                            Check(Function<EnumApps>(0x7fa2173a)(session,profile,index,ref count,application),"Check CS2 profile application scope");
                            if(count!=1) throw new InvalidOperationException("NVIDIA profile application list changed.");
                            names.Add(Marshal.PtrToStringUni(IntPtr.Add(application,8)));
                        } finally { Marshal.FreeHGlobal(application); }
                    }
                    ValidateApplicationNames(names.ToArray());
                } finally { Marshal.FreeHGlobal(info); }
            } catch { Dispose(); throw; }
        }
        public static void ValidateApplicationNames(string[] names) {
            if(names==null || names.Length==0) throw new InvalidOperationException("Empty NVIDIA application profile.");
            foreach(string name in names) {
                string executable=System.IO.Path.GetFileName(name);
                if(!String.Equals(executable,"cs2.exe",StringComparison.OrdinalIgnoreCase) && !String.Equals(executable,"csgos2.exe",StringComparison.OrdinalIgnoreCase)) throw new InvalidOperationException("NVIDIA profile is shared with another application; no changes are allowed.");
            }
        }
        DriverSetting Read(uint id) {
            Allowed(id);
            var p=Buffer(SettingSize,1);
            try {
                int status=Function<GetSetting>(0x73bf8338)(session,profile,id,p);
                if(status==NotFound) return new DriverSetting{Id=id,Value=0,UserOverride=false};
                Check(status,"Read driver setting");
                if(Marshal.ReadInt32(p,4104)!=0) throw new InvalidOperationException("Expected a DWORD driver setting.");
                return new DriverSetting{ Id=id, Value=unchecked((uint)Marshal.ReadInt32(p,ValueOffset)), UserOverride=Marshal.ReadInt32(p,4108)==0 && Marshal.ReadInt32(p,4112)==0 };
            } finally { Marshal.FreeHGlobal(p); }
        }
        public DriverSnapshot Capture() {
            return new DriverSnapshot{ProfileName=profileName,Settings=new[]{Read(274197361U),Read(6600001U)}};
        }
        public void Apply(DriverSnapshot snapshot) {
            if(!String.Equals(snapshot.ProfileName,profileName,StringComparison.Ordinal)) throw new InvalidOperationException("CS2 NVIDIA profile association changed; refusing to edit another profile.");
            if(snapshot.Settings==null || snapshot.Settings.Length!=2) throw new ArgumentException("Exactly two reviewed settings are required.");
            var seen=new HashSet<uint>();
            foreach(var setting in snapshot.Settings) { Allowed(setting.Id); if(!seen.Add(setting.Id)) throw new ArgumentException("Duplicate NVIDIA setting."); }
            foreach(var setting in snapshot.Settings) {
                if(!setting.UserOverride) {
                    int status=Function<DeleteSetting>(0xe4a26362)(session,profile,setting.Id);
                    if(status!=NotFound) Check(status,"Remove CS2 local override");
                } else {
                    var p=Buffer(SettingSize,1);
                    try {
                        Marshal.WriteInt32(p,4100,unchecked((int)setting.Id));
                        Marshal.WriteInt32(p,ValueOffset,unchecked((int)setting.Value));
                        Check(Function<SetSetting>(0x577dd202)(session,profile,p),"Write CS2 local override");
                    } finally { Marshal.FreeHGlobal(p); }
                }
            }
            Check(Function<SessionAction>(0xfcbc7e14)(session),"Save CS2 driver settings");
        }
        public void Dispose() {
            if(session!=IntPtr.Zero) { Function<SessionAction>(0xdad9cff8)(session); session=IntPtr.Zero; }
            if(library!=IntPtr.Zero) { FreeLibrary(library); library=IntPtr.Zero; }
        }
    }
}

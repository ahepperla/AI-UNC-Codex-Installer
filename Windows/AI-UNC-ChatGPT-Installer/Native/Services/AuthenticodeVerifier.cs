using System.Runtime.InteropServices;
using System.Security.Cryptography.X509Certificates;

namespace AIUNCChatGPTInstaller.Services;

internal static class AuthenticodeVerifier
{
    private static readonly Guid VerifyAction = new("00AAC56B-CD44-11d0-8CC2-00C04FC295EE");

    public static string VerifyMicrosoftSignedFile(string filePath)
    {
        var fileInfo = new WinTrustFileInfo(filePath);
        var data = new WinTrustData(fileInfo);
        try
        {
            var status = WinVerifyTrust(IntPtr.Zero, VerifyAction, data);
            if (status != 0)
            {
                throw new InvalidDataException($"Authenticode validation failed with status 0x{status:X8}.");
            }

#pragma warning disable SYSLIB0057
            using var certificate = new X509Certificate2(X509Certificate.CreateFromSignedFile(filePath));
#pragma warning restore SYSLIB0057
            if (!certificate.Subject.Contains("Microsoft Corporation", StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidDataException($"The installer signer was unexpected: {certificate.Subject}");
            }

            return certificate.Subject;
        }
        finally
        {
            data.Dispose();
            fileInfo.Dispose();
        }
    }

    [DllImport("wintrust.dll", ExactSpelling = true, PreserveSig = true, SetLastError = true)]
    private static extern int WinVerifyTrust(
        IntPtr windowHandle,
        [MarshalAs(UnmanagedType.LPStruct)] Guid actionId,
        WinTrustData trustData);

    private sealed class WinTrustFileInfo : IDisposable
    {
        public WinTrustFileInfo(string filePath)
        {
            var structure = new WinTrustFileInfoNative
            {
                StructureSize = (uint)Marshal.SizeOf<WinTrustFileInfoNative>(),
                FilePath = filePath,
                FileHandle = IntPtr.Zero,
                KnownSubject = IntPtr.Zero
            };

            Pointer = Marshal.AllocHGlobal(Marshal.SizeOf<WinTrustFileInfoNative>());
            Marshal.StructureToPtr(structure, Pointer, false);
        }

        public IntPtr Pointer { get; private set; }

        public void Dispose()
        {
            if (Pointer != IntPtr.Zero)
            {
                Marshal.DestroyStructure<WinTrustFileInfoNative>(Pointer);
                Marshal.FreeHGlobal(Pointer);
                Pointer = IntPtr.Zero;
            }
        }
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct WinTrustFileInfoNative
    {
        public uint StructureSize;
        [MarshalAs(UnmanagedType.LPWStr)]
        public string FilePath;
        public IntPtr FileHandle;
        public IntPtr KnownSubject;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private sealed class WinTrustData : IDisposable
    {
        public WinTrustData(WinTrustFileInfo fileInfo)
        {
            StructureSize = (uint)Marshal.SizeOf<WinTrustData>();
            PolicyCallbackData = IntPtr.Zero;
            SipClientData = IntPtr.Zero;
            UIChoice = 2;
            RevocationChecks = 0;
            UnionChoice = 1;
            FileInfo = fileInfo.Pointer;
            StateAction = 0;
            StateData = IntPtr.Zero;
            UrlReference = IntPtr.Zero;
            ProviderFlags = 0x00001000;
            UIContext = 0;
        }

        public uint StructureSize;
        public IntPtr PolicyCallbackData;
        public IntPtr SipClientData;
        public uint UIChoice;
        public uint RevocationChecks;
        public uint UnionChoice;
        public IntPtr FileInfo;
        public uint StateAction;
        public IntPtr StateData;
        public IntPtr UrlReference;
        public uint ProviderFlags;
        public uint UIContext;

        public void Dispose()
        {
        }
    }
}

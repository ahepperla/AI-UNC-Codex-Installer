using System.Runtime.InteropServices;

namespace AIUNCChatGPTInstaller.Services;

internal static class NativeMethods
{
    private static readonly IntPtr BroadcastHandle = new(0xffff);

    public static void BroadcastEnvironmentChange()
    {
        _ = SendMessageTimeout(
            BroadcastHandle,
            0x001A,
            UIntPtr.Zero,
            "Environment",
            0x0002,
            5000,
            out _);
    }

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr SendMessageTimeout(
        IntPtr hWnd,
        uint message,
        UIntPtr wParam,
        string lParam,
        uint flags,
        uint timeout,
        out UIntPtr result);
}

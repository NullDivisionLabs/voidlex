package com.voidlex.voidlex;

public final class XrayNativeProcess {
    static {
        System.loadLibrary("xray_process");
    }

    private XrayNativeProcess() {
    }

    public static native int[] start(
        String binaryPath,
        String configPath,
        String workingDirectory,
        String assetDirectory,
        int tunFd
    );

    public static native boolean isAlive(int pid);

    public static native void terminate(int pid, int timeoutMs);
}

#include <jni.h>

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#include <string>
#include <vector>

extern char **environ;

namespace {

constexpr int kChildTunFd = 100;
constexpr int kPollIntervalUs = 50 * 1000;

std::string toString(JNIEnv *env, jstring value) {
    if (value == nullptr) {
        return {};
    }
    const char *raw = env->GetStringUTFChars(value, nullptr);
    if (raw == nullptr) {
        return {};
    }
    std::string result(raw);
    env->ReleaseStringUTFChars(value, raw);
    return result;
}

void throwIllegalState(JNIEnv *env, const std::string &message) {
    jclass clazz = env->FindClass("java/lang/IllegalStateException");
    if (clazz != nullptr) {
        env->ThrowNew(clazz, message.c_str());
    }
}

std::vector<std::string> buildEnvironment(int tunFd, const std::string &assetDirectory) {
    std::vector<std::string> envValues;
    for (char **current = environ; current != nullptr && *current != nullptr; ++current) {
        const char *entry = *current;
        if (
            strncmp(entry, "XRAY_TUN_FD=", strlen("XRAY_TUN_FD=")) == 0 ||
            strncmp(entry, "xray.tun.fd=", strlen("xray.tun.fd=")) == 0 ||
            strncmp(entry, "XRAY_LOCATION_ASSET=", strlen("XRAY_LOCATION_ASSET=")) == 0 ||
            strncmp(entry, "xray.location.asset=", strlen("xray.location.asset=")) == 0
        ) {
            continue;
        }
        envValues.emplace_back(entry);
    }

    const std::string fdValue = std::to_string(tunFd);
    envValues.emplace_back("XRAY_TUN_FD=" + fdValue);
    envValues.emplace_back("xray.tun.fd=" + fdValue);
    if (!assetDirectory.empty()) {
        envValues.emplace_back("XRAY_LOCATION_ASSET=" + assetDirectory);
        envValues.emplace_back("xray.location.asset=" + assetDirectory);
    }
    return envValues;
}

std::vector<char *> toPointerVector(std::vector<std::string> &values) {
    std::vector<char *> pointers;
    pointers.reserve(values.size() + 1);
    for (std::string &value : values) {
        pointers.push_back(value.data());
    }
    pointers.push_back(nullptr);
    return pointers;
}

void clearCloseOnExec(int fd) {
    const int flags = fcntl(fd, F_GETFD);
    if (flags >= 0) {
        fcntl(fd, F_SETFD, flags & ~FD_CLOEXEC);
    }
}

} // namespace

extern "C" JNIEXPORT jintArray JNICALL
Java_com_voidlex_voidlex_XrayNativeProcess_start(
    JNIEnv *env,
    jclass,
    jstring binaryPath,
    jstring configPath,
    jstring workingDirectory,
    jstring assetDirectory,
    jint tunFd
) {
    const std::string binary = toString(env, binaryPath);
    const std::string config = toString(env, configPath);
    const std::string workDir = toString(env, workingDirectory);
    const std::string assetDir = toString(env, assetDirectory);
    if (binary.empty() || config.empty() || tunFd < 0) {
        throwIllegalState(env, "Invalid Xray native launcher arguments");
        return nullptr;
    }

    int outputPipe[2] = {-1, -1};
    if (pipe(outputPipe) != 0) {
        throwIllegalState(env, std::string("pipe failed: ") + strerror(errno));
        return nullptr;
    }

    std::vector<std::string> envValues = buildEnvironment(kChildTunFd, assetDir);
    std::vector<char *> envPointers = toPointerVector(envValues);

    pid_t pid = fork();
    if (pid < 0) {
        const int savedErrno = errno;
        close(outputPipe[0]);
        close(outputPipe[1]);
        throwIllegalState(env, std::string("fork failed: ") + strerror(savedErrno));
        return nullptr;
    }

    if (pid == 0) {
        close(outputPipe[0]);

        if (tunFd != kChildTunFd) {
            if (dup2(tunFd, kChildTunFd) < 0) {
                dprintf(outputPipe[1], "dup2 tun fd failed: %s\n", strerror(errno));
                _exit(126);
            }
        }
        clearCloseOnExec(kChildTunFd);

        dup2(outputPipe[1], STDOUT_FILENO);
        dup2(outputPipe[1], STDERR_FILENO);
        close(outputPipe[1]);

        if (!workDir.empty()) {
            chdir(workDir.c_str());
        }

        char *argv[] = {
            const_cast<char *>(binary.c_str()),
            const_cast<char *>("run"),
            const_cast<char *>("-config"),
            const_cast<char *>(config.c_str()),
            nullptr,
        };
        execve(binary.c_str(), argv, envPointers.data());
        dprintf(STDERR_FILENO, "execve xray failed: %s\n", strerror(errno));
        _exit(127);
    }

    close(outputPipe[1]);

    jintArray result = env->NewIntArray(2);
    if (result == nullptr) {
        close(outputPipe[0]);
        kill(pid, SIGTERM);
        return nullptr;
    }
    jint values[2] = {static_cast<jint>(pid), static_cast<jint>(outputPipe[0])};
    env->SetIntArrayRegion(result, 0, 2, values);
    return result;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_voidlex_voidlex_XrayNativeProcess_isAlive(JNIEnv *, jclass, jint pid) {
    if (pid <= 0) {
        return JNI_FALSE;
    }

    int status = 0;
    const pid_t waitResult = waitpid(static_cast<pid_t>(pid), &status, WNOHANG);
    if (waitResult == 0) {
        return JNI_TRUE;
    }
    return JNI_FALSE;
}

extern "C" JNIEXPORT void JNICALL
Java_com_voidlex_voidlex_XrayNativeProcess_terminate(
    JNIEnv *,
    jclass,
    jint pid,
    jint timeoutMs
) {
    if (pid <= 0) {
        return;
    }

    const pid_t childPid = static_cast<pid_t>(pid);
    if (kill(childPid, SIGTERM) < 0 && errno == ESRCH) {
        // Already reaped — nothing to wait on.
        return;
    }

    int status = 0;
    int waitedUs = 0;
    const int timeoutUs = timeoutMs > 0 ? timeoutMs * 1000 : 0;

    // Adaptive polling: xray typically exits within ~20-100 ms of SIGTERM,
    // so we burn-in with 5 ms ticks for the first 100 ms and back off to
    // 50 ms afterwards. The previous fixed 50 ms interval added up to half
    // the disconnect latency for the common-case fast exit.
    constexpr int kFastIntervalUs = 5 * 1000;
    constexpr int kSlowIntervalUs = 50 * 1000;
    constexpr int kFastWindowUs = 100 * 1000;

    while (waitedUs <= timeoutUs) {
        const pid_t waitResult = waitpid(childPid, &status, WNOHANG);
        if (waitResult == childPid || (waitResult < 0 && errno == ECHILD)) {
            return;
        }
        const int interval =
            waitedUs < kFastWindowUs ? kFastIntervalUs : kSlowIntervalUs;
        usleep(interval);
        waitedUs += interval;
    }

    kill(childPid, SIGKILL);
    waitpid(childPid, &status, 0);
}

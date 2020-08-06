#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <getopt.h>
#include <grp.h>
#include <poll.h>
#include <pwd.h>
#include <signal.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#ifdef DEBUG
static FILE *debug_fp = NULL;
#define INFO(MSG, ...) do { fprintf(debug_fp, "%d:" MSG "\n", microsecs(), ## __VA_ARGS__); fflush(debug_fp); } while (0)
#else
#define INFO(MSG, ...) ;
#endif

// asprintf can fail, but it's so rare that it's annoying to see the checks in the code.
#define checked_asprintf(MSG, ...) do { if (asprintf(MSG, ## __VA_ARGS__) < 0) err(EXIT_FAILURE, "asprintf"); } while (0)

static struct option long_options[] = {
    {"arg0", required_argument, 0, '0'},
    {"help",     no_argument,       0, 'h'},
    {"delay-to-sigkill", required_argument, 0, 'k'},
    {0,          0,                 0, 0 }
};

static int brutal_kill_wait_ms = 500;
static int signal_pipe[2] = { -1, -1};

static void usage()
{
    printf("Usage: port [OPTION] -- <program> <args>\n");
    printf("\n");
    printf("Options:\n");

    printf("--arg0,-0 <arg0>\n");
    printf("--delay-to-sigkill,-k <milliseconds>\n");
    printf("-- the program to run and its arguments come after this\n");
}

static int microsecs()
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (ts.tv_sec * 1000000) + (ts.tv_nsec / 1000);
}

void sigchild_handler(int signum)
{
    if (signal_pipe[1] >= 0 &&
            write(signal_pipe[1], &signum, sizeof(signum)) < 0)
        warn("write(signal_pipe)");
}

void enable_signal_handlers()
{
    struct sigaction sa;
    sa.sa_handler = sigchild_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;

    sigaction(SIGCHLD, &sa, NULL);
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGQUIT, &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);
}

void disable_signal_handlers()
{
    sigaction(SIGCHLD, NULL, NULL);
    sigaction(SIGINT, NULL, NULL);
    sigaction(SIGQUIT, NULL, NULL);
    sigaction(SIGTERM, NULL, NULL);
}

static int fork_exec(const char *path, char *const *argv)
{
    INFO("Running %s", path);
    for (char *const *arg = argv; *arg != NULL; arg++) {
        INFO("  arg: %s", *arg);
    }

    pid_t pid = fork();
    if (pid == 0) {
        // child
        execvp(path, argv);

        // Not supposed to reach here.
        exit(EXIT_FAILURE);
    } else {

        return pid;
    }
}



#ifdef DEBUG
static void read_proc_cmdline(int pid, char *cmdline)
{
    char *cmdline_filename;

    checked_asprintf(&cmdline_filename, "/proc/%d/cmdline", pid);
    FILE *fp = fopen(cmdline_filename, "r");
    if (fp) {
        size_t len = fread(cmdline, 1, 128, fp);
        if (len > 0)
            cmdline[len] = 0;
        else
            strcpy(cmdline, "<NULL>");
        fclose(fp);
    } else {
        sprintf(cmdline, "Error reading %s", cmdline_filename);
    }

    free(cmdline_filename);
}
#endif


static int wait_for_sigchld(pid_t pid_to_match, int timeout_ms)
{
    struct pollfd fds[1];
    fds[0].fd = signal_pipe[0];
    fds[0].events = POLLIN;

    int end_timeout_us = microsecs() + (1000 * timeout_ms);
    int next_time_to_wait_ms = timeout_ms;
    do {
        INFO("poll - %d ms", next_time_to_wait_ms);
        if (poll(fds, 1, next_time_to_wait_ms) < 0) {
            if (errno == EINTR)
                continue;

            warn("poll");
            return -1;
        }

        if (fds[0].revents) {
            int signal;
            ssize_t amt = read(signal_pipe[0], &signal, sizeof(signal));
            if (amt < 0) {
                warn("read signal_pipe");
                return -1;
            }

            INFO("signal_pipe - SIGNAL %d", signal);
            switch (signal) {
            case SIGCHLD: {
                int status;
                pid_t pid = wait(&status);
                if (pid_to_match == pid) {
                    INFO("cleaned up matching pid %d.", pid);
                    return 0;
                }
                INFO("cleaned up pid %d.", pid);
                break;
            }

            case SIGTERM:
            case SIGQUIT:
            case SIGINT:
                return -1;

            default:
                warn("unexpected signal: %d", signal);
                return -1;
            }
        }

        next_time_to_wait_ms = (end_timeout_us - microsecs()) / 1000;
    } while (next_time_to_wait_ms > 0);

    INFO("timed out waiting for pid %d", pid_to_match);
    return -1;
}

static void kill_child_nicely(pid_t child)
{
    // Start with SIGTERM
    int rc = kill(child, SIGTERM);
    INFO("kill -%d %d -> %d (%s)", SIGTERM, child, rc, rc < 0 ? strerror(errno) : "success");
    if (rc < 0)
        return;

    // Wait a little for the child to exit
    if (wait_for_sigchld(child, brutal_kill_wait_ms) < 0) {
        // Child didn't exit, so SIGKILL it.
        rc = kill(child, SIGKILL);
        INFO("kill -%d %d -> %d (%s)", SIGKILL, child, rc, rc < 0 ? strerror(errno) : "success");
        if (rc < 0)
            return;

        if (wait_for_sigchld(child, brutal_kill_wait_ms) < 0)
            warn("SIGKILL didn't work on %d", child);
    }
}

static int child_wait_loop(pid_t child_pid, int *still_running)
{
    struct pollfd fds[2];
    fds[0].fd = STDIN_FILENO;
    fds[0].events = POLLHUP; // POLLERR is implicit
    fds[1].fd = signal_pipe[0];
    fds[1].events = POLLIN;

    for (;;) {
        if (poll(fds, 2, -1) < 0) {
            if (errno == EINTR)
                continue;

            warn("poll");
            return EXIT_FAILURE;
        }

        if (fds[0].revents) {
            INFO("stdin closed. cleaning up...");
            return EXIT_FAILURE;
        }
        if (fds[1].revents) {
            int signal;
            ssize_t amt = read(signal_pipe[0], &signal, sizeof(signal));
            if (amt < 0) {
                warn("read signal_pipe");
                return EXIT_FAILURE;
            }

            switch (signal) {
            case SIGCHLD: {
                int status;
                pid_t dying_pid = wait(&status);
                if (dying_pid == child_pid) {
                    // Let the caller know that the child isn't running and has been cleaned up
                    *still_running = 0;

                    int exit_status;
                    if (WIFSIGNALED(status)) {
                        // Crash on signal, return the signal in the exit status. See POSIX:
                        // http://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_08_02
                        exit_status = 128 + WTERMSIG(status);
                        INFO("child terminated via signal %d. our exit status: %d", status, exit_status);
                    } else if (WIFEXITED(status)) {
                        exit_status = WEXITSTATUS(status);
                        INFO("child exited with exit status: %d", exit_status);
                    } else {
                        INFO("child terminated with unexpected status: %d", status);
                        exit_status = EXIT_FAILURE;
                    }
                    return exit_status;
                } else {
                    INFO("something else caused sigchild: pid=%d, status=%d. our child=%d", dying_pid, status, child_pid);
                }
                break;
            }

            case SIGTERM:
            case SIGQUIT:
            case SIGINT:
                return EXIT_FAILURE;

            default:
                warn("unexpected signal: %d", signal);
                return EXIT_FAILURE;
            }
        }
    }
}

int main(int argc, char *argv[])
{
#ifdef DEBUG
    char filename[64];
    sprintf(filename, "port-%d.log", getpid());
    debug_fp = fopen(filename, "w");
    if (!debug_fp)
        debug_fp = stderr;
#endif
    INFO("port argc=%d", argc);
    if (argc == 1) {
        usage();
        exit(EXIT_FAILURE);
    }

    int opt;
    char *argv0 = NULL;

    while ((opt = getopt_long(argc, argv, "hk:0:", long_options, NULL)) != -1) {
        switch (opt) {

        case 'h':
            usage();
            exit(EXIT_SUCCESS);

        case 'k': // --delay-to-sigkill
            brutal_kill_wait_ms = strtoul(optarg, NULL, 0);
            break;

        case '0': // --argv0
            argv0 = optarg;
            break;

        default:
            usage();
            exit(EXIT_FAILURE);
        }
    }

    if (argc == optind)
        errx(EXIT_FAILURE, "Specify a program to run");

    // Finished processing commandline. Initialize and run child.

    if (pipe(signal_pipe) < 0)
        err(EXIT_FAILURE, "pipe");
    if (fcntl(signal_pipe[0], F_SETFD, FD_CLOEXEC) < 0 ||
        fcntl(signal_pipe[1], F_SETFD, FD_CLOEXEC) < 0)
        warn("fcntl(FD_CLOEXEC)");

    enable_signal_handlers();

    const char *program_name = argv[optind];
    if (argv0)
        argv[optind] = argv0;
    pid_t pid = fork_exec(program_name, &argv[optind]);

    int still_running = 1;
    int exit_status = child_wait_loop(pid, &still_running);

    if (still_running) {
        // Kill our immediate child if it's still running
        kill_child_nicely(pid);
    }

    disable_signal_handlers();

    exit(exit_status);
}

// SPDX-FileCopyrightText: None
//
// SPDX-License-Identifier: CC0-1.0
//
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char **argv)
{
    sigset_t mask;
    sigemptyset(&mask);
    sigaddset(&mask, SIGTERM);
    sigprocmask(SIG_BLOCK, &mask, NULL);

    sleep(120);
    exit(0);
}

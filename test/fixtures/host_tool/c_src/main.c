#include <err.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[])
{
    if (argc != 2)
        errx(EXIT_FAILURE, "Tell me the filename");

    FILE *fp = fopen(argv[1], "w");
    if (!fp)
        err(EXIT_FAILURE, "fopen");

    fprintf(fp, "Hello, world!\n");
    fclose(fp);

    exit(EXIT_SUCCESS);
}

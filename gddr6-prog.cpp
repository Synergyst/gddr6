#include <stdio.h>
extern "C" {
#include <gddr6.h>
}
int main(int argc, char **argv) {
  fprintf(stderr, "%s : %s\n", argv[1], fetch_gddr6_gddr6x_temp(argv[1]));
  (void) argc;
  (void) argv;
  return 0;
}

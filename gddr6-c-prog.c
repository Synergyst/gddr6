#include <stdio.h>
#include <gddr6.h>
int main(int argc, char **argv) {
  (void) argc;
  fprintf(stderr, "%s\n", fetch_gddr6_gddr6x_temp(argv[1]));
  return 0;
}

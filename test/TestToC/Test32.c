#include <math.h>
#include <stdio.h>
#include <stdlib.h>

void test32(){
  double *ptr = malloc(sizeof(double) * 3);
  (ptr[0]) = 1.0;
  (ptr[1]) = -(ptr[0]);
  (ptr[2]) = -(ptr[1]);
  printf("%f ",(ptr[2]));
  free(ptr);
}
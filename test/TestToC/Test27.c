#include <math.h>
#include <stdio.h>
#include <stdlib.h>

void test27(){
  double *ptr = malloc(sizeof(double) * 5);
  (ptr[0]) = 1.0;
  (ptr[1]) = 15.0;
  (ptr[2]) = 3.0;
  (ptr[3]) = (ptr[1]) * (ptr[2]);
  (ptr[4]) = (ptr[3]) * (ptr[0]);
  printf("%f ",(ptr[4]));
  free(ptr);
}
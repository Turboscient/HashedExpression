#include <math.h>
#include <stdio.h>
#include <stdlib.h>

int main(){
  double *ptr = malloc(sizeof(double) * 5);
  (ptr[0]) = 1.0;
  (ptr[1]) = 15.0;
  (ptr[2]) = 3.0;
  (ptr[4]) = (ptr[2]) * (ptr[0]);
  (ptr[3]) = (ptr[1]) + (ptr[4]);
  //printf("%f ",(ptr[3]));
  free(ptr);
}
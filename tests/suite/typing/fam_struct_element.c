// Test FAM with struct element type
// FAM where each element is itself a struct

#include <stdlib.h>

struct point {
  int x;
  int y;
};

struct point_array {
  unsigned long count;
  struct point points[];  // FAM of structs
};

int main(void) {
  // Allocate with space for 3 point structs
  struct point_array *arr = malloc(sizeof(struct point_array) + 3 * sizeof(struct point));
  if (!arr) return 1;

  arr->count = 3;

  // Write to struct elements
  arr->points[0].x = 10;
  arr->points[0].y = 11;

  arr->points[1].x = 20;
  arr->points[1].y = 22;

  arr->points[2].x = 30;
  arr->points[2].y = 33;

  // Read back
  if (arr->points[0].x != 10) return 1;
  if (arr->points[0].y != 11) return 1;
  if (arr->points[1].x != 20) return 1;
  if (arr->points[1].y != 22) return 1;
  if (arr->points[2].x != 30) return 1;
  if (arr->points[2].y != 33) return 1;

  // Get pointer to individual struct in FAM
  struct point *p1 = &arr->points[1];
  if (p1->x != 20) return 1;
  if (p1->y != 22) return 1;

  // Modify through pointer
  p1->x = 99;
  if (arr->points[1].x != 99) return 1;

  free(arr);
  return 0;
}

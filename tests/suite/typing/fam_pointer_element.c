// Test FAM with pointer element type
// FAM where each element is a pointer

#include <stdlib.h>

struct ptr_array {
  unsigned long count;
  int *ptrs[];  // FAM of pointers
};

int main(void) {
  // Allocate with space for 3 pointers
  struct ptr_array *arr = malloc(sizeof(struct ptr_array) + 3 * sizeof(int *));
  if (!arr) return 1;

  arr->count = 3;

  // Allocate some ints to point to
  int *val1 = malloc(sizeof(int));
  int *val2 = malloc(sizeof(int));
  int *val3 = malloc(sizeof(int));
  if (!val1 || !val2 || !val3) return 1;

  *val1 = 100;
  *val2 = 200;
  *val3 = 300;

  // Store pointers in FAM
  arr->ptrs[0] = val1;
  arr->ptrs[1] = val2;
  arr->ptrs[2] = val3;

  // Access through FAM pointers
  if (*arr->ptrs[0] != 100) return 1;
  if (*arr->ptrs[1] != 200) return 1;
  if (*arr->ptrs[2] != 300) return 1;

  // Modify through FAM pointers
  *arr->ptrs[0] = 111;
  if (*val1 != 111) return 1;

  // NULL pointer in FAM
  arr->ptrs[1] = NULL;
  if (arr->ptrs[1] != NULL) return 1;

  free(val1);
  free(val2);
  free(val3);
  free(arr);
  return 0;
}

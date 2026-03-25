// Simple FAM test - just check we can work with FAM pointers
#include <stdlib.h>

struct buffer {
  unsigned long len;
  int data[];  // FAM
};

int main(void) {
  // Allocate buffer with space for 10 ints in FAM
  struct buffer *ptr = malloc(sizeof(struct buffer) + 10 * sizeof(int));
  if (!ptr) return 1;

  ptr->len = 10;

  // Get the FAM pointer
  int *fam_ptr = ptr->data;

  // Use the pointer
  fam_ptr[0] = 42;
  fam_ptr[1] = 43;

  // Read back
  int a = fam_ptr[0];
  int b = fam_ptr[1];

  free(ptr);
  return (a == 42 && b == 43) ? 0 : 1;
}

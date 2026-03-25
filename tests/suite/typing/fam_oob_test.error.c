// Test FAM out-of-bounds access (should fail)
// This test verifies that out-of-bounds FAM access is detected

#include <stdlib.h>

struct buffer {
  unsigned long len;
  int data[];  // FAM
};

int main(void) {
  // Allocate buffer with space for 5 ints in FAM
  struct buffer *ptr = malloc(sizeof(struct buffer) + 5 * sizeof(int));
  if (!ptr) return 1;

  ptr->len = 5;

  // Out-of-bounds access (index 10 > capacity 5) - should fail
  ptr->data[10] = 999;

  free(ptr);
  return 0;
}

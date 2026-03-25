// Test FAM bounds checking
// This test verifies that accessing FAM elements respects allocation bounds

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

  // In-bounds accesses (should succeed)
  ptr->data[0] = 1;
  ptr->data[1] = 2;
  ptr->data[2] = 3;
  ptr->data[3] = 4;
  ptr->data[4] = 5;

  // Read back
  int sum = 0;
  for (int i = 0; i < 5; i++) {
    sum += ptr->data[i];
  }

  free(ptr);
  return (sum == 15) ? 0 : 1;
}

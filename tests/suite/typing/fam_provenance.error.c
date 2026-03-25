// Test FAM pointer provenance
// Comparing pointers from different allocations should fail

#include <stdlib.h>

struct buffer {
  unsigned long len;
  int data[];
};

int main(void) {
  // Allocate two separate buffers
  struct buffer *buf1 = malloc(sizeof(struct buffer) + 5 * sizeof(int));
  struct buffer *buf2 = malloc(sizeof(struct buffer) + 5 * sizeof(int));
  if (!buf1 || !buf2) return 1;

  buf1->len = 5;
  buf2->len = 5;

  // Get FAM pointers from different allocations
  int *p1 = buf1->data;
  int *p2 = buf2->data;

  // Comparing pointers from different allocations
  // This violates provenance - pointers have different origins
  if (p1 < p2) {
    // Should not reach here - provenance violation
  }

  free(buf1);
  free(buf2);
  return 0;
}

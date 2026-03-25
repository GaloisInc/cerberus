// Test FAM negative index access (should fail)
// Accessing buf->data[-1] is out of bounds

#include <stdlib.h>

struct buffer {
  unsigned long len;
  int data[];
};

int main(void) {
  // Allocate buffer with space for 5 ints
  struct buffer *buf = malloc(sizeof(struct buffer) + 5 * sizeof(int));
  if (!buf) return 1;

  buf->len = 5;

  // Negative index - accesses before FAM start - OUT OF BOUNDS
  buf->data[-1] = 42;

  free(buf);
  return 0;
}

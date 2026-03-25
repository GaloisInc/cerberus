// Test use-after-free with FAM
// Accessing FAM after free should fail

#include <stdlib.h>

struct buffer {
  unsigned long len;
  int data[];
};

int main(void) {
  // Allocate buffer
  struct buffer *buf = malloc(sizeof(struct buffer) + 5 * sizeof(int));
  if (!buf) return 1;

  buf->len = 5;
  buf->data[0] = 42;

  // Free the buffer
  free(buf);

  // Use-after-free: access FAM after free
  int val = buf->data[0];  // INVALID - use after free

  (void)val;
  return 0;
}

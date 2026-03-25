// Test dereferencing one-past-end FAM pointer (should fail)
// While one-past-end is valid for arithmetic, dereferencing it is UB

#include <stdlib.h>

struct buffer {
  unsigned long len;
  int data[];
};

int main(void) {
  // Allocate buffer with space for 5 ints (indices 0-4)
  struct buffer *buf = malloc(sizeof(struct buffer) + 5 * sizeof(int));
  if (!buf) return 1;

  buf->len = 5;

  // One-past-end pointer - valid to create
  int *end = &buf->data[5];

  // But dereferencing it is OUT OF BOUNDS
  *end = 42;

  free(buf);
  return 0;
}

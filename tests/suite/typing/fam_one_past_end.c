// Test FAM one-past-end pointer
// C99 allows pointer to one past the end for arithmetic, but not dereference

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

  // One-past-end pointer (index 5) - VALID for pointer arithmetic
  int *end = &buf->data[5];

  // Using it for comparison is valid
  int *start = buf->data;

  // Pointer difference should be 5
  long diff = end - start;
  if (diff != 5) return 1;

  // Can compare pointers
  if (end <= start) return 1;

  free(buf);
  return 0;
}

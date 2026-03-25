// Test const-qualified FAM elements
// FAM with const element type

#include <stdlib.h>

struct const_buffer {
  unsigned long len;
  const int data[];  // FAM with const elements
};

int main(void) {
  // Allocate const FAM buffer
  // Note: the pointer is not const, but the elements are
  struct const_buffer *buf = malloc(sizeof(struct const_buffer) + 3 * sizeof(int));
  if (!buf) return 1;

  buf->len = 3;

  // Writing to const data requires cast (implementation-defined, but often works)
  // In strict C, this would be a constraint violation
  // For testing, we just verify we can read from it
  int *non_const = (int *)buf->data;
  non_const[0] = 10;
  non_const[1] = 20;
  non_const[2] = 30;

  // Read through const pointer
  const int *data = buf->data;
  if (data[0] != 10) return 1;
  if (data[1] != 20) return 1;
  if (data[2] != 30) return 1;

  free(buf);
  return 0;
}

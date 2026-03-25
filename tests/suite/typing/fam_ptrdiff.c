// Test pointer difference with FAM pointers
// Subtracting FAM pointers should give correct element count

#include <stdlib.h>

struct buffer {
  unsigned long len;
  int data[];
};

int main(void) {
  // Allocate buffer with space for 10 ints
  struct buffer *buf = malloc(sizeof(struct buffer) + 10 * sizeof(int));
  if (!buf) return 1;

  buf->len = 10;

  // Initialize some elements
  buf->data[2] = 100;
  buf->data[7] = 200;

  // Get pointers to these elements
  int *p1 = &buf->data[2];
  int *p2 = &buf->data[7];

  // Pointer difference should be 5 elements
  long diff = p2 - p1;
  if (diff != 5) return 1;

  // Difference in reverse should be -5
  long diff_reverse = p1 - p2;
  if (diff_reverse != -5) return 1;

  // Pointer to same element should have difference 0
  int *p3 = &buf->data[2];
  if (p1 - p3 != 0) return 1;

  free(buf);
  return 0;
}

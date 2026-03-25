// Test reading uninitialized FAM elements
// malloc doesn't initialize memory - reading should return unspecified value (not UB)

#include <stdlib.h>

struct buffer {
  unsigned long len;
  int data[];
};

int main(void) {
  // Allocate buffer WITHOUT initializing FAM elements
  struct buffer *buf = malloc(sizeof(struct buffer) + 5 * sizeof(int));
  if (!buf) return 1;

  buf->len = 5;

  // Read uninitialized FAM element
  // This is implementation-defined (unspecified value), NOT undefined behavior
  // The value could be anything, but the read itself is valid
  int val = buf->data[0];

  // Use the value (even though it's unspecified)
  // The program should not crash
  (void)val;

  // Now write and read back - should work normally
  buf->data[0] = 123;
  if (buf->data[0] != 123) return 1;

  free(buf);
  return 0;
}

// Test realloc with FAM struct
// Growing/shrinking FAM capacity via realloc

#include <stdlib.h>

struct buffer {
  unsigned long len;
  int data[];
};

int main(void) {
  // Initially allocate with capacity for 3 ints
  struct buffer *buf = malloc(sizeof(struct buffer) + 3 * sizeof(int));
  if (!buf) return 1;

  buf->len = 3;
  buf->data[0] = 10;
  buf->data[1] = 20;
  buf->data[2] = 30;

  // Grow to capacity for 6 ints
  buf = realloc(buf, sizeof(struct buffer) + 6 * sizeof(int));
  if (!buf) return 1;

  // Regular members should be preserved
  if (buf->len != 3) return 1;

  // Original FAM data should be preserved
  if (buf->data[0] != 10) return 1;
  if (buf->data[1] != 20) return 1;
  if (buf->data[2] != 30) return 1;

  // Can now use expanded capacity
  buf->len = 6;
  buf->data[3] = 40;
  buf->data[4] = 50;
  buf->data[5] = 60;

  // Verify new elements
  if (buf->data[3] != 40) return 1;
  if (buf->data[4] != 50) return 1;
  if (buf->data[5] != 60) return 1;

  // Shrink back to capacity for 2 ints
  buf = realloc(buf, sizeof(struct buffer) + 2 * sizeof(int));
  if (!buf) return 1;

  // Regular members still preserved
  if (buf->len != 6) return 1;

  // First 2 elements should still be there
  if (buf->data[0] != 10) return 1;
  if (buf->data[1] != 20) return 1;

  // Update len to reflect new capacity
  buf->len = 2;

  free(buf);
  return 0;
}

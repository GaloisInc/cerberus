// Test calloc with FAM struct
// calloc should zero-initialize both struct and FAM region

#include <stdlib.h>

struct buffer {
  unsigned long len;
  int data[];
};

int main(void) {
  // Use calloc to allocate and zero-initialize
  // Total size: sizeof(struct buffer) + 5 * sizeof(int)
  struct buffer *buf = calloc(1, sizeof(struct buffer) + 5 * sizeof(int));
  if (!buf) return 1;

  // Regular member should be zero
  if (buf->len != 0) return 1;

  // FAM elements should also be zero-initialized
  if (buf->data[0] != 0) return 1;
  if (buf->data[1] != 0) return 1;
  if (buf->data[2] != 0) return 1;
  if (buf->data[3] != 0) return 1;
  if (buf->data[4] != 0) return 1;

  // Now modify and verify
  buf->len = 5;
  buf->data[0] = 100;
  buf->data[4] = 500;

  if (buf->len != 5) return 1;
  if (buf->data[0] != 100) return 1;
  if (buf->data[4] != 500) return 1;

  free(buf);
  return 0;
}

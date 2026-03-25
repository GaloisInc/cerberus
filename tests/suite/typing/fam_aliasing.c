// Test FAM pointer aliasing
// Multiple pointers to same FAM element should work correctly

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

  // Get two pointers to the same FAM element
  int *p1 = &buf->data[2];
  int *p2 = &buf->data[2];

  // Write through first pointer
  *p1 = 42;

  // Read through second pointer - should see the write
  if (*p2 != 42) return 1;

  // Write through second pointer
  *p2 = 99;

  // Read through first pointer - should see the new write
  if (*p1 != 99) return 1;

  // Also check via direct access
  if (buf->data[2] != 99) return 1;

  free(buf);
  return 0;
}

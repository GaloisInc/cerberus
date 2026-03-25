// Test struct with ONLY a FAM (no regular members)
// This is a C99 edge case - struct has no size except FAM

#include <stdlib.h>
#include <stddef.h>

struct only_fam {
  int data[];  // FAM only, no regular members
};

int main(void) {
  // sizeof should be 0 or implementation-defined minimum
  // Most platforms will use 0 or minimum alignment size
  unsigned long base_size = sizeof(struct only_fam);

  // offsetof FAM in empty struct should be 0 or base_size
  unsigned long fam_offset = offsetof(struct only_fam, data);
  if (fam_offset != base_size) return 1;

  // Allocate with space for 5 ints
  struct only_fam *buf = malloc(sizeof(struct only_fam) + 5 * sizeof(int));
  if (!buf) return 1;

  // Access FAM elements
  buf->data[0] = 10;
  buf->data[1] = 20;
  buf->data[4] = 50;

  // Read back
  if (buf->data[0] != 10) return 1;
  if (buf->data[1] != 20) return 1;
  if (buf->data[4] != 50) return 1;

  free(buf);
  return 0;
}

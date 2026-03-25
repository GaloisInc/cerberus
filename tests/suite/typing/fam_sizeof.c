// Test sizeof with FAM structs
// sizeof(struct) should NOT include the flexible array member

#include <stdlib.h>
#include <stddef.h>

struct buffer {
  unsigned long len;  // 8 bytes
  int data[];         // FAM - NOT included in sizeof
};

struct small_fam {
  char c;             // 1 byte
  int data[];         // FAM - NOT included
};

int main(void) {
  // sizeof(struct buffer) should be just the size of regular members
  // On most platforms: sizeof(unsigned long) = 8
  if (sizeof(struct buffer) != 8) return 1;

  // offsetof should give where FAM starts
  if (offsetof(struct buffer, data) != 8) return 1;

  // sizeof small_fam should be sizeof(char) = 1 (plus any padding)
  // On most platforms this will be 4 due to alignment of following FAM
  if (sizeof(struct small_fam) < 1) return 1;

  // Allocate actual FAM struct with elements
  struct buffer *buf = malloc(sizeof(struct buffer) + 5 * sizeof(int));
  if (!buf) return 1;

  // The allocation size is different from sizeof(struct)
  // We allocated: 8 + (5 * 4) = 28 bytes
  // But sizeof(*buf) is still just 8

  free(buf);
  return 0;
}

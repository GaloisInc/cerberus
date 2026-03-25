// Test FAM alignment requirements
// FAM should start at properly aligned offset for its element type

#include <stdlib.h>
#include <stddef.h>
#include <stdalign.h>

struct char_before_int_fam {
  char c;        // 1 byte
  // Padding here to align FAM
  int data[];    // FAM - needs 4-byte alignment
};

struct long_fam {
  char c;        // 1 byte
  // Padding here to align FAM
  long data[];   // FAM - needs 8-byte alignment (on most 64-bit)
};

int main(void) {
  // Check that FAM starts at properly aligned offset

  // int FAM needs 4-byte alignment
  unsigned long int_fam_offset = offsetof(struct char_before_int_fam, data);
  if (int_fam_offset % alignof(int) != 0) return 1;

  // long FAM needs 8-byte alignment (typically)
  unsigned long long_fam_offset = offsetof(struct long_fam, data);
  if (long_fam_offset % alignof(long) != 0) return 1;

  // Allocate and test actual usage
  struct char_before_int_fam *buf = malloc(
    sizeof(struct char_before_int_fam) + 3 * sizeof(int)
  );
  if (!buf) return 1;

  // Check that data pointer is aligned
  unsigned long data_addr = (unsigned long)buf->data;
  if (data_addr % alignof(int) != 0) return 1;

  // Access should work without alignment faults
  buf->data[0] = 12345;
  buf->data[1] = 67890;
  buf->data[2] = 11111;

  if (buf->data[0] != 12345) return 1;
  if (buf->data[1] != 67890) return 1;
  if (buf->data[2] != 11111) return 1;

  free(buf);
  return 0;
}

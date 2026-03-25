// Test type punning with FAM (casting to different pointer type)
// Access int FAM as char* for byte-level access

#include <stdlib.h>

struct buffer {
  unsigned long len;
  int data[];
};

int main(void) {
  // Allocate buffer with space for 3 ints
  struct buffer *buf = malloc(sizeof(struct buffer) + 3 * sizeof(int));
  if (!buf) return 1;

  buf->len = 3;

  // Write an int value
  buf->data[0] = 0x12345678;

  // Access the same memory as bytes
  char *bytes = (char *)buf->data;

  // Read first byte (endianness-dependent, but should not crash)
  char b0 = bytes[0];
  char b1 = bytes[1];
  char b2 = bytes[2];
  char b3 = bytes[3];

  // Use the values (avoid warnings)
  (void)b0; (void)b1; (void)b2; (void)b3;

  // Write through char* alias
  bytes[4] = 0x11;
  bytes[5] = 0x22;
  bytes[6] = 0x33;
  bytes[7] = 0x44;

  // Read back as int (should work via type punning)
  int val = buf->data[1];
  (void)val;

  free(buf);
  return 0;
}

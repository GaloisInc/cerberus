// Test NULL pointer dereference with FAM
// Accessing FAM of NULL pointer should fail

#include <stdlib.h>

struct buffer {
  unsigned long len;
  int data[];
};

int main(void) {
  // NULL pointer
  struct buffer *buf = NULL;

  // Attempting to access FAM of NULL pointer - should fail
  int *data = buf->data;

  (void)data;
  return 0;
}

// Test struct assignment with FAM
// Assigning one FAM struct to another should ONLY copy regular members,
// NOT the flexible array member

#include <stdlib.h>

struct buffer {
  unsigned long len;
  int data[];
};

int main(void) {
  // Allocate two buffers with different FAM contents
  struct buffer *buf1 = malloc(sizeof(struct buffer) + 3 * sizeof(int));
  struct buffer *buf2 = malloc(sizeof(struct buffer) + 3 * sizeof(int));
  if (!buf1 || !buf2) return 1;

  // Initialize buf1
  buf1->len = 10;
  buf1->data[0] = 100;
  buf1->data[1] = 200;
  buf1->data[2] = 300;

  // Initialize buf2
  buf2->len = 20;
  buf2->data[0] = 111;
  buf2->data[1] = 222;
  buf2->data[2] = 333;

  // Struct assignment - should ONLY copy 'len', NOT 'data'
  *buf2 = *buf1;

  // buf2->len should now be 10 (copied from buf1)
  if (buf2->len != 10) return 1;

  // buf2->data should still have its original values (NOT copied)
  // The FAM is NOT part of the struct value
  if (buf2->data[0] != 111) return 1;
  if (buf2->data[1] != 222) return 1;
  if (buf2->data[2] != 333) return 1;

  free(buf1);
  free(buf2);
  return 0;
}

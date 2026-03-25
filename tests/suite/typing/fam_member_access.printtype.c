// Test flexible array member (FAM) typing
// FAMs should have pointer type, not array type

#include <stdlib.h>

struct buffer {
  unsigned long len;
  int data[];  // FAM
};

int main(void) {
  // Allocate buffer with space for 10 ints in FAM
  struct buffer *ptr = malloc(sizeof(struct buffer) + 10 * sizeof(int));
  if (!ptr) return 1;

  ptr->len = 10;
  ptr->data[0] = 42;
  ptr->data[1] = 43;

  // FAM member access via pointer (main use case)
  __cerb_printtype(ptr->data);  // int *

  // Subscript should work (pointer + integer)
  __cerb_printtype(ptr->data[0]);  // int
  __cerb_printtype(ptr->data[1]);  // int

  free(ptr);
  return 0;
}

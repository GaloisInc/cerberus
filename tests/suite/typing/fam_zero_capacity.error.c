// Test FAM with zero capacity (should fail)
// This is the critical edge case: malloc(sizeof(struct)) allocates no FAM space
// Even accessing index 0 should fail because no FAM elements were allocated

#include <stdlib.h>

struct buffer {
  unsigned long len;
  int data[];  // FAM
};

int main(void) {
  // Allocate buffer with NO space for FAM (only the struct itself)
  struct buffer *ptr = malloc(sizeof(struct buffer));
  if (!ptr) return 1;

  ptr->len = 0;

  // Accessing even index 0 should fail - no FAM space allocated
  ptr->data[0] = 42;

  free(ptr);
  return 0;
}

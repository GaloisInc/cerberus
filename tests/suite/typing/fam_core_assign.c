typedef struct {
  short a;
  int b[];
} s;

s c;
void d() {
  int *p = c.b;  // Assign FAM to pointer - clearly an rvalue
}

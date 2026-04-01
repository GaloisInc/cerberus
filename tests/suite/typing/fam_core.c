typedef struct {
  short a;
   int b[];
} s;

s c;
void d() {c.b;}

// Test that flexible array members have array type, not pointer type
// This is important for correct sizeof behavior and type compatibility

#ifndef __cerb__
#define __cerb_printtype(Z) Z
#endif

struct bar {
    unsigned int n;
    int x[];  // Flexible Array Member
};

void test_fam_types(struct bar *p)
{
    // FAM member access should have unbounded array type int[]
    // which decays to int* in most contexts
    __cerb_printtype(p->x);      // Should be: int[] (array), decays to int*

    // Element access gives element type
    __cerb_printtype(p->x[0]);   // Should be: int

    // Address of element gives pointer to element
    __cerb_printtype(&p->x[0]);  // Should be: int*

    // NOTE: Cannot test &p->x directly because FAMs are currently
    // implemented as rvalues, not lvalues, so &p->x is a constraint violation.
    // Ideally, &p->x should have type int (*)[] (pointer to array).

    // Verify element and pointer types via typeof
    typeof(p->x[0]) elem_var = 42;            // int
    typeof(&p->x[0]) elem_ptr_var = &elem_var; // int*
    typeof(*p->x) deref_var = 42;             // int

    // Suppress unused variable warnings
    (void)elem_var;
    (void)elem_ptr_var;
    (void)deref_var;
}

int main(void)
{
    return 0;
}

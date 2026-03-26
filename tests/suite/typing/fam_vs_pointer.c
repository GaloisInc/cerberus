// Compare FAM behavior with pointer and regular array members

#ifndef __cerb__
#define __cerb_printtype(Z) Z
#endif

struct with_pointer {
    unsigned int n;
    int *ptr;  // Pointer member
};

struct with_array {
    unsigned int n;
    int arr[10];  // Fixed array member
};

struct with_fam {
    unsigned int n;
    int fam[];  // Flexible Array Member
};

void test_types(struct with_pointer *p1, struct with_array *p2, struct with_fam *p3)
{
    // Pointer member: p1->ptr has type int*
    __cerb_printtype(p1->ptr);     // int*
    __cerb_printtype(p1->ptr[0]);  // int
    __cerb_printtype(&p1->ptr[0]); // int*

    // Array member: p2->arr has type int[10], decays to int*
    __cerb_printtype(p2->arr);     // Should be: int* (after decay from int[10])
    __cerb_printtype(p2->arr[0]);  // int
    __cerb_printtype(&p2->arr[0]); // int*

    // FAM: p3->fam should behave like an array, not a pointer
    __cerb_printtype(p3->fam);     // Should be: int* (after decay from int[])
    __cerb_printtype(p3->fam[0]);  // int
    __cerb_printtype(&p3->fam[0]); // int*
}

int main(void)
{
    return 0;
}

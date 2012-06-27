// RUN: %clang_cc1 %s -emit-llvm -triple x86_64-pc-linux -o - | FileCheck %s

typedef struct S_ { char data[20]; } S;
#pragma pack(push, 1)
typedef struct Unaligned_ { char ch; int i; } Unaligned;
#pragma pack(pop)

#pragma upc relaxed

char testc(shared char * ptr) { return *ptr; }
// CHECK: testc
// CHECK: %call = call zeroext i8 @__getqi2(i64 %{{[0-9]+}})

signed char testsc(shared signed char * ptr) { return *ptr; }
// CHECK: testsc
// CHECK: %call = call zeroext i8 @__getqi2(i64 %{{[0-9]+}})

unsigned char testuc(shared unsigned char * ptr) { return *ptr; }
// CHECK: testuc
// CHECK: %call = call zeroext i8 @__getqi2(i64 %{{[0-9]+}})

short tests(shared short * ptr) { return *ptr; }
// CHECK: tests
// CHECK: %call = call zeroext i16 @__gethi2(i64 %{{[0-9]+}})

unsigned short testus(shared unsigned short * ptr) { return *ptr; }
// CHECK: testus
// CHECK: %call = call zeroext i16 @__gethi2(i64 %{{[0-9]+}})

int testi(shared int * ptr) { return *ptr; }
// CHECK: testi
// CHECK: %call = call i32 @__getsi2(i64 %{{[0-9]+}})

unsigned int testui(shared unsigned int * ptr) { return *ptr; }
// CHECK: testui
// CHECK: %call = call i32 @__getsi2(i64 %{{[0-9]+}})

long testl(shared long * ptr) { return *ptr; }
// CHECK: testl
// CHECK: %call = call i64 @__getdi2(i64 %{{[0-9]+}})

unsigned long testul(shared unsigned long * ptr) { return *ptr; }
// CHECK: testul
// CHECK: %call = call i64 @__getdi2(i64 %{{[0-9]+}})

long long testll(shared long long * ptr) { return *ptr; }
// CHECK: testll
// CHECK: %call = call i64 @__getdi2(i64 %{{[0-9]+}})

unsigned long long testull(shared unsigned long long * ptr) { return *ptr; }
// CHECK: testull
// CHECK: %call = call i64 @__getdi2(i64 %{{[0-9]+}})

__int128_t test128(shared __int128_t * ptr) { return *ptr; }
// CHECK: test128
// CHECK: %call = call { i64, i64 } @__getti2(i64 %1)

__uint128_t testu128(shared __uint128_t * ptr) { return *ptr; }
// CHECK: testu128
// CHECK: %call = call { i64, i64 } @__getti2(i64 %1)

float testf(shared float * ptr) { return *ptr; }
// CHECK: testf
// CHECK: %call = call float @__getsf2(i64 %{{[0-9]+}})

double testd(shared double * ptr) { return *ptr; }
// CHECK: testd
// CHECK: %call = call double @__getdf2(i64 %{{[0-9]+}})

long double testld(shared long double * ptr) { return *ptr; }
// CHECK: testld
// CHECK: %call = call x86_fp80 @__gettf2(i64 %{{[0-9]+}})

int * testp(int * shared * ptr) { return *ptr; }
// CHECK: testp
// CHECK: %call = call i64 @__getdi2(i64 %{{[0-9]+}})

void testS(S * out, shared S * ptr) { *out = *ptr; }
// CHECK: testS
// CHECK: call void @__getblk3(i8* %2, i64 %{{[0-9]+}}, i64 20)

int testUnaligned(shared Unaligned * ptr) { return ptr->i; }
// CHECK: testUnaligned
// CHECK: call void @__getblk3(i8* %{{[0-9]+}}, i64 %{{[0-9]+}}, i64 4)

#pragma upc strict

char testcs(shared char * ptr) { return *ptr; }
// CHECK: testcs
// CHECK: %call = call zeroext i8 @__getsqi2(i64 %{{[0-9]+}})

signed char testscs(shared signed char * ptr) { return *ptr; }
// CHECK: testscs
// CHECK: %call = call zeroext i8 @__getsqi2(i64 %{{[0-9]+}})

unsigned char testucs(shared unsigned char * ptr) { return *ptr; }
// CHECK: testucs
// CHECK: %call = call zeroext i8 @__getsqi2(i64 %{{[0-9]+}})

short testss(shared short * ptr) { return *ptr; }
// CHECK: testss
// CHECK: %call = call zeroext i16 @__getshi2(i64 %{{[0-9]+}})

unsigned short testuss(shared unsigned short * ptr) { return *ptr; }
// CHECK: testuss
// CHECK: %call = call zeroext i16 @__getshi2(i64 %{{[0-9]+}})

int testis(shared int * ptr) { return *ptr; }
// CHECK: testis
// CHECK: %call = call i32 @__getssi2(i64 %{{[0-9]+}})

unsigned int testuis(shared unsigned int * ptr) { return *ptr; }
// CHECK: testuis
// CHECK: %call = call i32 @__getssi2(i64 %{{[0-9]+}})

long testls(shared long * ptr) { return *ptr; }
// CHECK: testls
// CHECK: %call = call i64 @__getsdi2(i64 %{{[0-9]+}})

unsigned long testuls(shared unsigned long * ptr) { return *ptr; }
// CHECK: testuls
// CHECK: %call = call i64 @__getsdi2(i64 %{{[0-9]+}})

long long testlls(shared long long * ptr) { return *ptr; }
// CHECK: testlls
// CHECK: %call = call i64 @__getsdi2(i64 %{{[0-9]+}})

unsigned long long testulls(shared unsigned long long * ptr) { return *ptr; }
// CHECK: testulls
// CHECK: %call = call i64 @__getsdi2(i64 %{{[0-9]+}})

__int128_t test128s(shared __int128_t * ptr) { return *ptr; }
// CHECK: test128s
// CHECK: %call = call { i64, i64 } @__getsti2(i64 %1)

__uint128_t testu128s(shared __uint128_t * ptr) { return *ptr; }
// CHECK: testu128s
// CHECK: %call = call { i64, i64 } @__getsti2(i64 %1)

float testfs(shared float * ptr) { return *ptr; }
// CHECK: testfs
// CHECK: %call = call float @__getssf2(i64 %{{[0-9]+}})

double testds(shared double * ptr) { return *ptr; }
// CHECK: testds
// CHECK: %call = call double @__getsdf2(i64 %{{[0-9]+}})

long double testlds(shared long double * ptr) { return *ptr; }
// CHECK: testlds
// CHECK: %call = call x86_fp80 @__getstf2(i64 %{{[0-9]+}})

int * testps(int * shared * ptr) { return *ptr; }
// CHECK: testps
// CHECK: %call = call i64 @__getsdi2(i64 %{{[0-9]+}})

void testSs(S * out, shared S * ptr) { *out = *ptr; }
// CHECK: testSs
// CHECK: call void @__getsblk3(i8* %2, i64 %{{[0-9]+}}, i64 20)

int testUnaligneds(shared Unaligned * ptr) { return ptr->i; }
// CHECK: testUnaligneds
// CHECK: call void @__getsblk3(i8* %{{[0-9]+}}, i64 %{{[0-9]+}}, i64 4)

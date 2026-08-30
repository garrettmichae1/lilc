#include <stddef.h>

typedef struct {
    const char *category;
    const char *name;
    const char *source;
    const char *expected;
} TestCase;

/* Helper macro to keep sources readable. */
#define SRC(...) #__VA_ARGS__

const TestCase kCases[] = {

/* ---------------- basics / printf ---------------- */
{"printf", "hello_world",
 "#include <stdio.h>\nint main(void){printf(\"hello\\n\");return 0;}",
 "hello\n"},

{"printf", "int_format",
 "#include <stdio.h>\nint main(void){printf(\"%d %d\\n\", 42, -7);return 0;}",
 "42 -7\n"},

{"printf", "multiple_types",
 "#include <stdio.h>\nint main(void){printf(\"%c %d %s\\n\",'A',5,\"hi\");return 0;}",
 "A 5 hi\n"},

{"printf", "float_precision",
 "#include <stdio.h>\nint main(void){printf(\"%.3f\\n\", 3.14159);return 0;}",
 "3.142\n"},

{"printf", "hex_octal",
 "#include <stdio.h>\nint main(void){printf(\"%x %o\\n\", 255, 8);return 0;}",
 "ff 10\n"},

{"printf", "width_pad",
 "#include <stdio.h>\nint main(void){printf(\"%5d|%-5d|\\n\", 42, 42);return 0;}",
 "   42|42   |\n"},

{"printf", "percent_literal",
 "#include <stdio.h>\nint main(void){printf(\"100%%\\n\");return 0;}",
 "100%\n"},

{"printf", "unsigned",
 "#include <stdio.h>\nint main(void){unsigned int u=4000000000U;printf(\"%u\\n\",u);return 0;}",
 "4000000000\n"},

{"printf", "long_format",
 "#include <stdio.h>\nint main(void){long x=1234567890L;printf(\"%ld\\n\",x);return 0;}",
 "1234567890\n"},

/* ---------------- arithmetic ---------------- */
{"arithmetic", "basic_ops",
 "#include <stdio.h>\nint main(void){printf(\"%d\\n\", 2+3*4-6/2);return 0;}",
 "11\n"},

{"arithmetic", "modulo",
 "#include <stdio.h>\nint main(void){printf(\"%d\\n\", 17%5);return 0;}",
 "2\n"},

{"arithmetic", "int_division",
 "#include <stdio.h>\nint main(void){printf(\"%d\\n\", 7/2);return 0;}",
 "3\n"},

{"arithmetic", "float_division",
 "#include <stdio.h>\nint main(void){printf(\"%.2f\\n\", 7.0/2.0);return 0;}",
 "3.50\n"},

{"arithmetic", "bitwise",
 "#include <stdio.h>\nint main(void){printf(\"%d %d %d %d\\n\", 6&3, 6|1, 6^2, ~0);return 0;}",
 "2 7 4 -1\n"},

{"arithmetic", "shifts",
 "#include <stdio.h>\nint main(void){printf(\"%d %d\\n\", 1<<4, 256>>2);return 0;}",
 "16 64\n"},

{"arithmetic", "compound_assign",
 "#include <stdio.h>\nint main(void){int x=10;x+=5;x*=2;x-=3;printf(\"%d\\n\",x);return 0;}",
 "27\n"},

{"arithmetic", "increment",
 "#include <stdio.h>\nint main(void){int i=5;printf(\"%d %d %d\\n\",i++,++i,i);return 0;}",
 "5 7 7\n"},

/* ---------------- control flow ---------------- */
{"control", "if_else",
 "#include <stdio.h>\nint main(void){int x=5;if(x>3)printf(\"big\\n\");else printf(\"small\\n\");return 0;}",
 "big\n"},

{"control", "for_loop",
 "#include <stdio.h>\nint main(void){int s=0;for(int i=1;i<=5;i++)s+=i;printf(\"%d\\n\",s);return 0;}",
 "15\n"},

{"control", "while_loop",
 "#include <stdio.h>\nint main(void){int i=0,s=0;while(i<5){s+=i;i++;}printf(\"%d\\n\",s);return 0;}",
 "10\n"},

{"control", "do_while",
 "#include <stdio.h>\nint main(void){int i=0;do{printf(\"%d\",i);i++;}while(i<3);printf(\"\\n\");return 0;}",
 "012\n"},

{"control", "switch",
 "#include <stdio.h>\nint main(void){int x=2;switch(x){case 1:printf(\"one\\n\");break;case 2:printf(\"two\\n\");break;default:printf(\"other\\n\");}return 0;}",
 "two\n"},

{"control", "break_continue",
 "#include <stdio.h>\nint main(void){for(int i=0;i<10;i++){if(i==3)continue;if(i==6)break;printf(\"%d\",i);}printf(\"\\n\");return 0;}",
 "01245\n"},

{"control", "nested_loops",
 "#include <stdio.h>\nint main(void){for(int i=0;i<2;i++)for(int j=0;j<2;j++)printf(\"%d%d \",i,j);printf(\"\\n\");return 0;}",
 "00 01 10 11 \n"},

{"control", "ternary",
 "#include <stdio.h>\nint main(void){int x=5;printf(\"%s\\n\", x>0?\"pos\":\"neg\");return 0;}",
 "pos\n"},

{"control", "goto",
 "#include <stdio.h>\nint main(void){int i=0;loop:if(i<3){printf(\"%d\",i);i++;goto loop;}printf(\"\\n\");return 0;}",
 "012\n"},

/* ---------------- functions ---------------- */
{"functions", "simple_call",
 "#include <stdio.h>\nint add(int a,int b){return a+b;}\nint main(void){printf(\"%d\\n\",add(3,4));return 0;}",
 "7\n"},

{"functions", "recursion",
 "#include <stdio.h>\nint fact(int n){return n<=1?1:n*fact(n-1);}\nint main(void){printf(\"%d\\n\",fact(5));return 0;}",
 "120\n"},

{"functions", "fib_recursive",
 "#include <stdio.h>\nint fib(int n){if(n<2)return n;return fib(n-1)+fib(n-2);}\nint main(void){printf(\"%d\\n\",fib(10));return 0;}",
 "55\n"},

{"functions", "void_func",
 "#include <stdio.h>\nvoid greet(void){printf(\"hi\\n\");}\nint main(void){greet();return 0;}",
 "hi\n"},

{"functions", "pass_by_pointer",
 "#include <stdio.h>\nvoid inc(int*p){(*p)++;}\nint main(void){int x=5;inc(&x);printf(\"%d\\n\",x);return 0;}",
 "6\n"},

{"functions", "mutual_recursion",
 "#include <stdio.h>\nint isodd(int);int iseven(int n){return n==0?1:isodd(n-1);}\nint isodd(int n){return n==0?0:iseven(n-1);}\nint main(void){printf(\"%d %d\\n\",iseven(10),isodd(7));return 0;}",
 "1 1\n"},

/* ---------------- pointers ---------------- */
{"pointers", "deref",
 "#include <stdio.h>\nint main(void){int x=42;int*p=&x;printf(\"%d\\n\",*p);return 0;}",
 "42\n"},

{"pointers", "pointer_arith",
 "#include <stdio.h>\nint main(void){int a[3]={10,20,30};int*p=a;printf(\"%d %d\\n\",*p,*(p+2));return 0;}",
 "10 30\n"},

{"pointers", "double_pointer",
 "#include <stdio.h>\nint main(void){int x=7;int*p=&x;int**pp=&p;printf(\"%d\\n\",**pp);return 0;}",
 "7\n"},

{"pointers", "pointer_to_pointer_swap",
 "#include <stdio.h>\nvoid swap(int*a,int*b){int t=*a;*a=*b;*b=t;}\nint main(void){int x=1,y=2;swap(&x,&y);printf(\"%d %d\\n\",x,y);return 0;}",
 "2 1\n"},

{"pointers", "null_check",
 "#include <stdio.h>\nint main(void){int*p=NULL;if(p==NULL)printf(\"null\\n\");return 0;}",
 "null\n"},

/* ---------------- arrays ---------------- */
{"arrays", "index",
 "#include <stdio.h>\nint main(void){int a[5]={1,2,3,4,5};printf(\"%d\\n\",a[2]);return 0;}",
 "3\n"},

{"arrays", "sum_loop",
 "#include <stdio.h>\nint main(void){int a[4]={1,2,3,4};int s=0;for(int i=0;i<4;i++)s+=a[i];printf(\"%d\\n\",s);return 0;}",
 "10\n"},

{"arrays", "2d_array",
 "#include <stdio.h>\nint main(void){int m[2][2]={{1,2},{3,4}};printf(\"%d\\n\",m[1][1]);return 0;}",
 "4\n"},

{"arrays", "array_modify",
 "#include <stdio.h>\nint main(void){int a[3]={0};a[1]=99;printf(\"%d %d\\n\",a[0],a[1]);return 0;}",
 "0 99\n"},

{"arrays", "char_array",
 "#include <stdio.h>\nint main(void){char s[6]=\"hello\";printf(\"%c%c\\n\",s[0],s[4]);return 0;}",
 "ho\n"},

/* ---------------- strings ---------------- */
{"strings", "strlen",
 "#include <stdio.h>\n#include <string.h>\nint main(void){printf(\"%d\\n\",(int)strlen(\"hello\"));return 0;}",
 "5\n"},

{"strings", "strcpy",
 "#include <stdio.h>\n#include <string.h>\nint main(void){char b[10];strcpy(b,\"world\");printf(\"%s\\n\",b);return 0;}",
 "world\n"},

{"strings", "strcmp",
 "#include <stdio.h>\n#include <string.h>\nint main(void){printf(\"%d\\n\",strcmp(\"abc\",\"abc\")==0);return 0;}",
 "1\n"},

{"strings", "strcat",
 "#include <stdio.h>\n#include <string.h>\nint main(void){char b[20]=\"foo\";strcat(b,\"bar\");printf(\"%s\\n\",b);return 0;}",
 "foobar\n"},

{"strings", "strchr",
 "#include <stdio.h>\n#include <string.h>\nint main(void){char*p=strchr(\"hello\",'l');printf(\"%c\\n\",*p);return 0;}",
 "l\n"},

{"strings", "sprintf",
 "#include <stdio.h>\nint main(void){char b[32];sprintf(b,\"x=%d\",42);printf(\"%s\\n\",b);return 0;}",
 "x=42\n"},

{"strings", "strncmp",
 "#include <stdio.h>\n#include <string.h>\nint main(void){printf(\"%d\\n\",strncmp(\"abcdef\",\"abcxyz\",3)==0);return 0;}",
 "1\n"},

/* ---------------- structs ---------------- */
{"structs", "basic_struct",
 "#include <stdio.h>\nstruct Point{int x;int y;};\nint main(void){struct Point p;p.x=3;p.y=4;printf(\"%d %d\\n\",p.x,p.y);return 0;}",
 "3 4\n"},

{"structs", "struct_init",
 "#include <stdio.h>\nstruct P{int x;int y;};\nint main(void){struct P p={1,2};printf(\"%d %d\\n\",p.x,p.y);return 0;}",
 "1 2\n"},

{"structs", "struct_pointer",
 "#include <stdio.h>\nstruct P{int x;};\nint main(void){struct P p;p.x=5;struct P*pp=&p;printf(\"%d\\n\",pp->x);return 0;}",
 "5\n"},

{"structs", "nested_struct",
 "#include <stdio.h>\nstruct Inner{int v;};struct Outer{struct Inner in;};\nint main(void){struct Outer o;o.in.v=9;printf(\"%d\\n\",o.in.v);return 0;}",
 "9\n"},

{"structs", "struct_in_function",
 "#include <stdio.h>\nstruct P{int x;int y;};\nint sum(struct P p){return p.x+p.y;}\nint main(void){struct P p={3,4};printf(\"%d\\n\",sum(p));return 0;}",
 "7\n"},

{"structs", "array_of_structs",
 "#include <stdio.h>\nstruct P{int x;};\nint main(void){struct P a[3];for(int i=0;i<3;i++)a[i].x=i*10;printf(\"%d\\n\",a[2].x);return 0;}",
 "20\n"},

{"structs", "typedef_struct",
 "#include <stdio.h>\ntypedef struct{int x;int y;}Point;\nint main(void){Point p;p.x=1;p.y=2;printf(\"%d\\n\",p.x+p.y);return 0;}",
 "3\n"},

/* ---------------- enums / typedef ---------------- */
{"enum_typedef", "enum_basic",
 "#include <stdio.h>\nenum Color{RED,GREEN,BLUE};\nint main(void){printf(\"%d %d %d\\n\",RED,GREEN,BLUE);return 0;}",
 "0 1 2\n"},

{"enum_typedef", "enum_explicit",
 "#include <stdio.h>\nenum E{A=5,B,C=10};\nint main(void){printf(\"%d %d %d\\n\",A,B,C);return 0;}",
 "5 6 10\n"},

{"enum_typedef", "typedef_int",
 "#include <stdio.h>\ntypedef int myint;\nint main(void){myint x=42;printf(\"%d\\n\",x);return 0;}",
 "42\n"},

/* ---------------- math library ---------------- */
{"math", "sqrt",
 "#include <stdio.h>\n#include <math.h>\nint main(void){printf(\"%.1f\\n\",sqrt(16.0));return 0;}",
 "4.0\n"},

{"math", "pow",
 "#include <stdio.h>\n#include <math.h>\nint main(void){printf(\"%.1f\\n\",pow(2.0,10.0));return 0;}",
 "1024.0\n"},

{"math", "trig",
 "#include <stdio.h>\n#include <math.h>\nint main(void){printf(\"%.2f\\n\",sin(0.0)+cos(0.0));return 0;}",
 "1.00\n"},

{"math", "floor_ceil",
 "#include <stdio.h>\n#include <math.h>\nint main(void){printf(\"%.0f %.0f\\n\",floor(3.7),ceil(3.2));return 0;}",
 "3 4\n"},

{"math", "fabs",
 "#include <stdio.h>\n#include <math.h>\nint main(void){printf(\"%.1f\\n\",fabs(-5.5));return 0;}",
 "5.5\n"},

/* ---------------- stdlib ---------------- */
{"stdlib", "abs",
 "#include <stdio.h>\n#include <stdlib.h>\nint main(void){printf(\"%d\\n\",abs(-42));return 0;}",
 "42\n"},

{"stdlib", "atoi",
 "#include <stdio.h>\n#include <stdlib.h>\nint main(void){printf(\"%d\\n\",atoi(\"123\"));return 0;}",
 "123\n"},

{"stdlib", "malloc_free",
 "#include <stdio.h>\n#include <stdlib.h>\nint main(void){int*p=malloc(sizeof(int)*3);p[0]=1;p[1]=2;p[2]=3;printf(\"%d\\n\",p[0]+p[1]+p[2]);free(p);return 0;}",
 "6\n"},

{"stdlib", "qsort",
 "#include <stdio.h>\n#include <stdlib.h>\nint cmp(const void*a,const void*b){return *(int*)a-*(int*)b;}\nint main(void){int a[5]={5,2,8,1,9};qsort(a,5,sizeof(int),cmp);for(int i=0;i<5;i++)printf(\"%d\",a[i]);printf(\"\\n\");return 0;}",
 "12589\n"},

/* ---------------- ctype ---------------- */
{"ctype", "isdigit_isalpha",
 "#include <stdio.h>\n#include <ctype.h>\nint main(void){printf(\"%d %d\\n\",isdigit('5')!=0,isalpha('A')!=0);return 0;}",
 "1 1\n"},

{"ctype", "toupper_tolower",
 "#include <stdio.h>\n#include <ctype.h>\nint main(void){printf(\"%c%c\\n\",toupper('a'),tolower('B'));return 0;}",
 "Ab\n"},

/* ---------------- advanced language features ---------------- */
{"advanced", "function_pointer",
 "#include <stdio.h>\nint add(int a,int b){return a+b;}\nint main(void){int(*f)(int,int)=add;printf(\"%d\\n\",f(3,4));return 0;}",
 "7\n"},

{"advanced", "sizeof_types",
 "#include <stdio.h>\nint main(void){printf(\"%d %d\\n\",(int)sizeof(int),(int)sizeof(char));return 0;}",
 "4 1\n"},

{"advanced", "static_local",
 "#include <stdio.h>\nint counter(void){static int c=0;return ++c;}\nint main(void){printf(\"%d%d%d\\n\",counter(),counter(),counter());return 0;}",
 "123\n"},

{"advanced", "global_var",
 "#include <stdio.h>\nint g=100;\nvoid bump(void){g+=5;}\nint main(void){bump();bump();printf(\"%d\\n\",g);return 0;}",
 "110\n"},

{"advanced", "const_var",
 "#include <stdio.h>\nint main(void){const int x=42;printf(\"%d\\n\",x);return 0;}",
 "42\n"},

{"advanced", "comma_operator",
 "#include <stdio.h>\nint main(void){int x=(1,2,3);printf(\"%d\\n\",x);return 0;}",
 "3\n"},

{"advanced", "string_escape",
 "#include <stdio.h>\nint main(void){printf(\"tab\\there\\n\");return 0;}",
 "tab\there\n"},

{"advanced", "multi_decl",
 "#include <stdio.h>\nint main(void){int a=1,b=2,c=3;printf(\"%d\\n\",a+b+c);return 0;}",
 "6\n"},

{"advanced", "char_arithmetic",
 "#include <stdio.h>\nint main(void){char c='A';printf(\"%c\\n\",c+1);return 0;}",
 "B\n"},

{"advanced", "preprocessor_define",
 "#include <stdio.h>\n#define SQUARE(x) ((x)*(x))\nint main(void){printf(\"%d\\n\",SQUARE(5));return 0;}",
 "25\n"},

{"advanced", "define_const",
 "#include <stdio.h>\n#define MAX 100\nint main(void){printf(\"%d\\n\",MAX);return 0;}",
 "100\n"},

{"advanced", "union_basic",
 "#include <stdio.h>\nunion U{int i;char c[4];};\nint main(void){union U u;u.i=0;u.c[0]=65;printf(\"%d\\n\",u.i);return 0;}",
 "65\n"},

/* ---------------- real-world style programs ---------------- */
{"programs", "bubble_sort",
 "#include <stdio.h>\nint main(void){int a[5]={5,1,4,2,8};for(int i=0;i<4;i++)for(int j=0;j<4-i;j++)if(a[j]>a[j+1]){int t=a[j];a[j]=a[j+1];a[j+1]=t;}for(int i=0;i<5;i++)printf(\"%d\",a[i]);printf(\"\\n\");return 0;}",
 "12458\n"},

{"programs", "prime_check",
 "#include <stdio.h>\nint isprime(int n){if(n<2)return 0;for(int i=2;i*i<=n;i++)if(n%i==0)return 0;return 1;}\nint main(void){for(int i=2;i<20;i++)if(isprime(i))printf(\"%d \",i);printf(\"\\n\");return 0;}",
 "2 3 5 7 11 13 17 19 \n"},

{"programs", "gcd",
 "#include <stdio.h>\nint gcd(int a,int b){return b==0?a:gcd(b,a%b);}\nint main(void){printf(\"%d\\n\",gcd(48,36));return 0;}",
 "12\n"},

{"programs", "string_reverse",
 "#include <stdio.h>\n#include <string.h>\nint main(void){char s[]=\"hello\";int n=(int)strlen(s);for(int i=0;i<n/2;i++){char t=s[i];s[i]=s[n-1-i];s[n-1-i]=t;}printf(\"%s\\n\",s);return 0;}",
 "olleh\n"},

{"programs", "count_vowels",
 "#include <stdio.h>\n#include <string.h>\nint main(void){char*s=\"programming\";int c=0;for(int i=0;s[i];i++)if(s[i]=='a'||s[i]=='e'||s[i]=='i'||s[i]=='o'||s[i]=='u')c++;printf(\"%d\\n\",c);return 0;}",
 "3\n"},

{"programs", "matrix_multiply",
 "#include <stdio.h>\nint main(void){int a[2][2]={{1,2},{3,4}};int b[2][2]={{5,6},{7,8}};int c[2][2]={{0,0},{0,0}};for(int i=0;i<2;i++)for(int j=0;j<2;j++)for(int k=0;k<2;k++)c[i][j]+=a[i][k]*b[k][j];printf(\"%d %d %d %d\\n\",c[0][0],c[0][1],c[1][0],c[1][1]);return 0;}",
 "19 22 43 50\n"},

/* ---------------- more edge cases a pro would hit ---------------- */
{"edge", "nested_ternary",
 "#include <stdio.h>\nint main(void){int x=5;const char*s=x<0?\"neg\":x==0?\"zero\":\"pos\";printf(\"%s\\n\",s);return 0;}",
 "pos\n"},

{"edge", "ternary_assign_side_effect",
 "#include <stdio.h>\nint main(void){int a=0,b=0;int c=1?(a=5):(b=9);printf(\"%d %d %d\\n\",a,b,c);return 0;}",
 "5 0 5\n"},

{"edge", "short_circuit_and",
 "#include <stdio.h>\nint calls=0;int side(void){calls++;return 1;}\nint main(void){int x=0;if(x!=0&&side()){}printf(\"%d\\n\",calls);return 0;}",
 "0\n"},

{"edge", "short_circuit_or",
 "#include <stdio.h>\nint calls=0;int side(void){calls++;return 1;}\nint main(void){int x=1;if(x==1||side()){}printf(\"%d\\n\",calls);return 0;}",
 "0\n"},

{"edge", "do_while_break",
 "#include <stdio.h>\nint main(void){int i=0;do{if(i==3)break;printf(\"%d\",i);i++;}while(1);printf(\"\\n\");return 0;}",
 "012\n"},

{"edge", "unsigned_overflow",
 "#include <stdio.h>\nint main(void){unsigned char c=255;c++;printf(\"%d\\n\",c);return 0;}",
 "0\n"},

{"edge", "array_of_pointers",
 "#include <stdio.h>\nint main(void){const char*days[3]={\"Mon\",\"Tue\",\"Wed\"};printf(\"%s\\n\",days[1]);return 0;}",
 "Tue\n"},

{"edge", "struct_assignment",
 "#include <stdio.h>\nstruct P{int x;int y;};\nint main(void){struct P a={1,2};struct P b;b=a;printf(\"%d %d\\n\",b.x,b.y);return 0;}",
 "1 2\n"},

{"edge", "static_array_string",
 "#include <stdio.h>\n#include <string.h>\nint main(void){char buf[32];memset(buf,0,32);strcpy(buf,\"hi\");printf(\"%d\\n\",(int)strlen(buf));return 0;}",
 "2\n"},

{"edge", "pointer_increment_string",
 "#include <stdio.h>\nint main(void){char*p=\"abc\";while(*p){putchar(*p);p++;}putchar('\\n');return 0;}",
 "abc\n"},

{"edge", "negative_modulo",
 "#include <stdio.h>\nint main(void){printf(\"%d\\n\",-7%3);return 0;}",
 "-1\n"},

{"edge", "chained_assignment",
 "#include <stdio.h>\nint main(void){int a,b,c;a=b=c=5;printf(\"%d %d %d\\n\",a,b,c);return 0;}",
 "5 5 5\n"},

{"edge", "sizeof_array",
 "#include <stdio.h>\nint main(void){int a[10];printf(\"%d\\n\",(int)(sizeof(a)/sizeof(a[0])));return 0;}",
 "10\n"},
};

const int kCaseCount = (int)(sizeof(kCases) / sizeof(kCases[0]));

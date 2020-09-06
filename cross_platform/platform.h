// NOTE: (ted)
//
// INTERNAL:
// 0 - Build for public release
// 1 - Build for developer only 
//
// SLOW:
// 0 - No slow code allowed!
// 1 - Slow code allowed

// TODO: (ted)  We are guranteed that __builtin_trap() will work with 
//              clang, but it is not-so-clear if it works on other platforms.
//              That may be why Casey used a null pointer dereference here. 
#if SLOW 
#define Assert(Expression) if(!(Expression)) { __builtin_trap(); }
#else
#define Assert(Expression)
#endif

#define Kilobytes(Value) ((Value)*1024LL)
#define Megabytes(Value) (Kilobytes(Value)*1024LL)
#define Gigabytes(Value) (Megabytes(Value)*1024LL)

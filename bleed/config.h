#define TCC_VERSION         "0.9.28rc"
#define TCC_TARGET_X86_64   1

#define CONFIG_TCC_STATIC         1     // tcc itself, theres no dlopen
#define CONFIG_TCC_STATIC_DEFAULT 1     // what it makes, theres no dynamic loader either
#define CONFIG_TCC_SEMLOCK        0
#define CONFIG_TCC_BCHECK         0
#define CONFIG_TCC_BACKTRACE      0
#define CONFIG_TCC_PREDEFS        1

#ifndef CONFIG_BLEED_ROOT
#define CONFIG_BLEED_ROOT   "/initrd"
#endif

#define CONFIG_TCCDIR               CONFIG_BLEED_ROOT "/lib/tcc"
#define CONFIG_TCC_SYSINCLUDEPATHS  "{B}/include:" CONFIG_BLEED_ROOT "/include"
#define CONFIG_TCC_LIBPATHS         "{B}:" CONFIG_BLEED_ROOT "/lib"
#define CONFIG_TCC_CRTPREFIX        CONFIG_BLEED_ROOT "/lib"
#define CONFIG_TCC_NO_RUN         1     // -run needs memory it can execute, bleed maps it all no-execute right now

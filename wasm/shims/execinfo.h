// Minimal execinfo.h shim for Emscripten/WebAssembly builds
// Provides no-op backtrace APIs to satisfy includes in third-party code.
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

static inline int backtrace(void ** /*buffer*/, int /*size*/) { return 0; }

static inline char **backtrace_symbols(void *const * /*buffer*/, int /*size*/) { return (char**)0; }

static inline void backtrace_symbols_fd(void *const * /*buffer*/, int /*size*/, int /*fd*/) {}

#ifdef __cplusplus
}
#endif


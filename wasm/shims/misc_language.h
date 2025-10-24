// Shim to neutralize problematic MARK_AS_POD_C11 specialization for WASM builds
// We include the original header, then override the macro to a no-op so
// downstream headers that call MARK_AS_POD_C11(T) do not specialize std::is_pod.
#pragma once

#include_next "misc_language.h"

#ifdef MARK_AS_POD_C11
#undef MARK_AS_POD_C11
#endif

#define MARK_AS_POD_C11(type)


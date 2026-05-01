BUILD_PATH="$1"

echo '' > "${BUILD_PATH}/version/misc_language.h"
echo '#define STRINGIFY_EXPAND(s) STRINGIFY(s)' >> "${BUILD_PATH}/version/misc_language.h"
echo '#define STRINGIFY(s) #s' >> "${BUILD_PATH}/version/misc_language.h"

echo '' > "${BUILD_PATH}/version/version.c"
echo '#include <stdio.h>' >> "${BUILD_PATH}/version/version.c"
echo '#include "version.h"' >> "${BUILD_PATH}/version/version.c"
echo 'int main() {' >> "${BUILD_PATH}/version/version.c"
echo '  printf(PROJECT_VERSION_LONG);' >> "${BUILD_PATH}/version/version.c"
echo '  return 0;' >> "${BUILD_PATH}/version/version.c"
echo '}' >> "${BUILD_PATH}/version/version.c"
gcc "${BUILD_PATH}/version/version.c" -I"${BUILD_PATH}/version" -o "${BUILD_PATH}/version/version"

"${BUILD_PATH}/version/version"
rm -f "${BUILD_PATH}/version/version.c" "${BUILD_PATH}/version/version"

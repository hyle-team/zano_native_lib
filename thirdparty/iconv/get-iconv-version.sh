BUILD_PATH=$(realpath "$1/stage/include")

echo '' > "${BUILD_PATH}/version.c"
echo '#include <stdio.h>' >> "${BUILD_PATH}/version.c"
echo '#include "iconv.h"' >> "${BUILD_PATH}/version.c"
echo 'int main() {' >> "${BUILD_PATH}/version.c"
echo '  int major = _LIBICONV_VERSION >> 8, minor = _LIBICONV_VERSION & 0xFF;' >> "${BUILD_PATH}/version.c"
echo '  printf("%d.%d", major, minor);' >> "${BUILD_PATH}/version.c"
echo '  return 0;' >> "${BUILD_PATH}/version.c"
echo '}' >> "${BUILD_PATH}/version.c"
gcc "${BUILD_PATH}/version.c" -I"${BUILD_PATH}" -o "${BUILD_PATH}/version"

"${BUILD_PATH}/version"
rm -f "${BUILD_PATH}/version.c" "${BUILD_PATH}/version"

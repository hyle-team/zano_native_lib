BUILD_PATH=$(realpath "$1/boost")

echo '' > "${BUILD_PATH}/version.c"
echo '#include <stdio.h>' >> "${BUILD_PATH}/version.c"
echo '#include "version.hpp"' >> "${BUILD_PATH}/version.c"
echo 'int main() {' >> "${BUILD_PATH}/version.c"
echo '  int major = BOOST_VERSION / 100000, minor = BOOST_VERSION / 100 % 1000, patch = BOOST_VERSION % 100;' >> "${BUILD_PATH}/version.c"
echo '  printf("%d.%d.%d", major, minor, patch);' >> "${BUILD_PATH}/version.c"
echo '  return 0;' >> "${BUILD_PATH}/version.c"
echo '}' >> "${BUILD_PATH}/version.c"
gcc "${BUILD_PATH}/version.c" -I"${BUILD_PATH}" -o "${BUILD_PATH}/version"

"${BUILD_PATH}/version"

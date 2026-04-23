To build Zano using GitHub Actions this workflows can be used:

- `00 - Build all` - rebuilds all dependencies, and then rebuilds Zano
- `05 - Pull Zano` - checkout new changes of Zano submodule to repository
- `10 - Build Zano` - rebuilds Zano
- `15 - Build Boost` - rebuilds Boost
- `15 - Build OpenSSL` - rebuilds OpenSSL
- `16 - Build iconv` - rebuilds iconv
- `20 - libzano Android prebuilds`
- `20 - libzano iOS prebuilds`
- `20 - libzano Linux prebuilds`
- `20 - libzano MacOSX prebuilds`
- `20 - libzano Windows prebuilds`
- `25 - libboost Android prebuilds`
- `25 - libboost iOS prebuilds`
- `25 - libboost Linux prebuilds`
- `25 - libboost MacOSX prebuilds`
- `25 - libboost Windows prebuilds`
- `25 - libopenssl Android prebuilds`
- `25 - libopenssl iOS prebuilds`
- `25 - libopenssl Linux prebuilds`
- `25 - libopenssl MacOSX prebuilds`
- `25 - libopenssl Windows prebuilds`
- `26 - libiconv Linux prebuilds`
- `26 - libiconv MacOSX prebuilds`

Every action respects dotenv files: `.env`, `.env.${PLATFORM}`

Environment variables:

- MIN_IOS_VERSION [16.6]
- MIN_MACOSX_VERSION [11.0]
- ANDROID_TARGET [26]
- OPENSSL_VERSION [3.1.8]
- OPENSSL_TAR_HASH
- BOOST_VERSION [1.84.0]
- BOOST_TAR_HASH
- ICONV_VERSION [1.18]
- ICONV_TAR_HASH

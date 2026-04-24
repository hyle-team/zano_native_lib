if [[ "$CI" == "true" ]]; then
  export PATH="$(dirname "$(which cl.exe)"):/c/Strawberry/perl/bin:$PATH"
fi

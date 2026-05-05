#!/usr/bin/env bash
# build.sh — clone upstream Foundation source, apply patches, build, verify md5.
#
# Requires: git, curl, dotnet SDK 8.0+. Tested on dotnet 8.0.420.
#
# Output: ./console-patch/dist/Landis.Console.dll and Landis.Utilities.dll matching
# the shipped checksums.

set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
WORK=$ROOT/.build

if ! command -v dotnet >/dev/null 2>&1; then
  echo "dotnet not on PATH. Install the dotnet 8.0 SDK first." >&2
  exit 1
fi

SDK_VER=$(dotnet --version | head -1)
echo "Using dotnet SDK $SDK_VER"

mkdir -p "$WORK"
cd "$WORK"

# 1. Clone upstream sources.
if [ ! -d Core-Model-v8-LINUX ]; then
  git clone --depth=1 https://github.com/LANDIS-II-Foundation/Core-Model-v8-LINUX.git
fi
if [ ! -d Library-Utilities ]; then
  git clone --depth=1 https://github.com/LANDIS-II-Foundation/Library-Utilities.git
fi

# 2. Restore patched files from this repo (App.cs and Loader.cs).
cp "$ROOT/console-patch/src/Tool-Console/App.cs" \
   Core-Model-v8-LINUX/Tool-Console/src/App.cs
cp "$ROOT/console-patch/src/Library-Utilities/Loader.cs" \
   Library-Utilities/src/plug-ins/Loader.cs

# 3. Fetch the support DLL Console.csproj depends on (Landis.Library.Metadata-v2).
mkdir -p Core-Model-v8-LINUX/Tool-Console/src/lib
if [ ! -f Core-Model-v8-LINUX/Tool-Console/src/lib/Landis.Library.Metadata-v2.dll ]; then
  curl -sL -o Core-Model-v8-LINUX/Tool-Console/src/lib/Landis.Library.Metadata-v2.dll \
    https://github.com/LANDIS-II-Foundation/Support-Library-Dlls-v8/raw/master/Landis.Library.Metadata-v2.dll
fi

# 4. Build Landis.Utilities (netstandard2.0).
echo
echo "Building Library-Utilities..."
cd Library-Utilities/src
dotnet restore Landis.Utilities.csproj
dotnet build -c Release --no-restore Landis.Utilities.csproj
cd "$WORK"

# 5. Build Tool-Console (net8.0).
echo
echo "Building Tool-Console..."
cd Core-Model-v8-LINUX/Tool-Console/src
dotnet restore Console.csproj
dotnet build -c Release --no-restore Console.csproj
cd "$WORK"

# 6. Stage built DLLs.
mkdir -p "$ROOT/console-patch/dist"
cp Core-Model-v8-LINUX/build/Release/Landis.Console.dll \
   "$ROOT/console-patch/dist/Landis.Console.dll"
cp Library-Utilities/src/bin/Release/netstandard2.0/Landis.Utilities.dll \
   "$ROOT/console-patch/dist/Landis.Utilities.dll"

# 7. Verify checksums against the shipped reference values.
EXPECTED_CONSOLE="a42d209f4faf2f2562cd5f63e32b8f8a"
EXPECTED_UTILITIES="c0be4b9f064b817b6352c61feb42be24"
GOT_CONSOLE=$(md5sum "$ROOT/console-patch/dist/Landis.Console.dll" | awk '{print $1}')
GOT_UTILITIES=$(md5sum "$ROOT/console-patch/dist/Landis.Utilities.dll" | awk '{print $1}')

echo
echo "Verification:"
printf "  Landis.Console.dll    expected %s got %s %s\n" \
  "$EXPECTED_CONSOLE" "$GOT_CONSOLE" \
  $([ "$EXPECTED_CONSOLE" = "$GOT_CONSOLE" ] && echo OK || echo MISMATCH)
printf "  Landis.Utilities.dll  expected %s got %s %s\n" \
  "$EXPECTED_UTILITIES" "$GOT_UTILITIES" \
  $([ "$EXPECTED_UTILITIES" = "$GOT_UTILITIES" ] && echo OK || echo MISMATCH)

# Refresh checksum files.
( cd "$ROOT/console-patch/dist" && \
  sha256sum *.dll > SHA256SUMS && \
  md5sum    *.dll > MD5SUMS )

echo
echo "Done. Patched DLLs in $ROOT/console-patch/dist/"

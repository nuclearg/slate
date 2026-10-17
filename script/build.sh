#!/bin/bash
#
# Build Slate for arm64 (Apple Silicon).
#
# The upstream project is from 2013: deployment target 10.6, SenTestingKit and
# a vendored Sparkle.framework with no arm64 slice.  This script rebuilds the
# app from the original sources against the current SDK.  The only source edit
# is a two-line arm64 compatibility fix in Slate/ShellUtils.m (the comment
# there explains it); every file that implements the script engine is compiled
# unchanged.
#
# What is deliberately NOT here:
#   * Sparkle auto-update (upstream is unmaintained).  build-support keeps a
#     no-op SUUpdater class so the original MainMenu.nib still unarchives and
#     "Check for Updates" does nothing.
#   * ibtool.  MainMenu.xib is unchanged, so the nib compiled for the original
#     release is reused from build/Release/Slate.app.
#
# Usage:
#   script/build.sh [--arch arm64|x86_64|universal] [--debug] [--sign ID]
#
# See BUILD-ARM64.md for the migration notes and the parity test.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ARCH="arm64"
CONFIG="release"
SIGN_ID="-"
MIN_OS="11.0"
# 发布流水线用 tag 覆盖 Info.plist 里的版本号；本地构建留空即沿用源码里的值
VERSION="${SLATE_VERSION:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --arch)   ARCH="$2"; shift 2 ;;
    --debug)  CONFIG="debug"; shift ;;
    --sign)   SIGN_ID="$2"; shift 2 ;;
    --help|-h) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

case "$ARCH" in
  arm64)     ARCH_FLAGS=(-arch arm64) ;;
  x86_64)    ARCH_FLAGS=(-arch x86_64) ;;
  universal) ARCH_FLAGS=(-arch arm64 -arch x86_64) ;;
  *) echo "unsupported arch: $ARCH" >&2; exit 2 ;;
esac

# Toolchain: prefer whatever xcode-select points at (Xcode or Command Line
# Tools); fall back to the Command Line Tools explicitly if xcrun is unusable
# (e.g. a freshly installed Xcode whose licence has not been accepted yet).
if [[ -n "${SLATE_CLANG:-}" && -n "${SLATE_SDK:-}" ]]; then
  CLANG="$SLATE_CLANG"
  SDK="$SLATE_SDK"
else
  CLANG="$(xcrun --find clang 2>/dev/null || true)"
  SDK="$(xcrun --show-sdk-path 2>/dev/null || true)"
  if [[ -z "$CLANG" || -z "$SDK" ]]; then
    CLANG="/Library/Developer/CommandLineTools/usr/bin/clang"
    SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
    echo "note: xcrun unavailable, using Command Line Tools toolchain"
  fi
fi

if [[ "$CONFIG" == "debug" ]]; then
  OPT_FLAGS=(-O0 -g -DDEBUG)
  OUT="$ROOT/build/debug-$ARCH/Slate.app"
else
  OPT_FLAGS=(-Os)
  OUT="$ROOT/build/release-$ARCH/Slate.app"
fi

OBJDIR="$ROOT/build/obj-$ARCH-$CONFIG"
rm -rf "$OUT" "$OBJDIR"
mkdir -p "$OBJDIR" "$OUT/Contents/MacOS" "$OUT/Contents/Resources"

# Mirrors the Slate target's PBXSourcesBuildPhase.  JSONKit.m is the only
# non-ARC file in the project and keeps its -fno-objc-arc.
SOURCES=(
  Slate/main.m Slate/SlateAppDelegate.m Slate/SlateConfig.m Slate/Binding.m
  Slate/Operation.m Slate/MoveOperation.m Slate/ExpressionPoint.m Slate/ResizeOperation.m
  Slate/Constants.m Slate/StringTokenizer.m Slate/ChainOperation.m Slate/AccessibilityWrapper.m
  Slate/WindowState.m Slate/Layout.m Slate/LayoutOperation.m Slate/ApplicationOptions.m
  Slate/ScreenWrapper.m Slate/ScreenState.m Slate/FocusOperation.m Slate/MathUtils.m
  Slate/WindowInfoView.m Slate/SnapshotOperation.m Slate/Snapshot.m Slate/WindowSnapshot.m
  Slate/SnapshotList.m Slate/JSONKit/JSONKit.m Slate/DeleteSnapshotOperation.m Slate/ActivateSnapshotOperation.m
  Slate/NSString+Levenshtein.m Slate/HintOperation.m Slate/HintWindow.m Slate/HintView.m
  Slate/ConfigurationHelperView.m Slate/SwitchOperation.m Slate/SwitchView.m Slate/SwitchWindow.m
  Slate/RunningApplications.m Slate/SwitchAppView.m Slate/SwitchAppQuittingOverlayView.m Slate/NSFileManager+ApplicationSupport.m
  Slate/GridOperation.m Slate/GridView.m Slate/GridWindow.m Slate/GridCellView.m
  Slate/NSString+Indicies.m Slate/SequenceOperation.m Slate/VisibilityOperation.m Slate/RelaunchOperation.m
  Slate/ShellOperation.m Slate/ShellUtils.m Slate/UndoOperation.m Slate/JSController.m
  Slate/PushOperation.m Slate/NudgeOperation.m Slate/ThrowOperation.m Slate/CornerOperation.m
  Slate/JSInfoWrapper.m Slate/JSWindowWrapper.m Slate/JSApplicationWrapper.m Slate/JSScreenWrapper.m
  Slate/JSWrapperUtils.m Slate/JSOperation.m Slate/JSOperationWrapper.m
  build-support/SUUpdaterStub.m
)

COMMON_FLAGS=(
  "${ARCH_FLAGS[@]}"
  -mmacosx-version-min="$MIN_OS"
  -isysroot "$SDK"
  -fobjc-arc
  -include Slate/Slate-Prefix.pch
  -I build-support
  -I Slate/JSONKit
  -Wno-deprecated-declarations
  # Match the original x86_64 build's ObjC bridge semantics: on arm64 clang
  # predefines __OBJC_BOOL_IS_BOOL=1, which makes BOOL a C99 bool ('B') instead
  # of signed char ('c').  WebKit's WebScriptObject bridge turns a 'B' return
  # into a JS boolean and a 'c' return into a JS number, so without this flag
  # slate.source() & friends would return false instead of 0.  objc.h honors
  # the override; the ABI (one byte, w0) is identical.
  -D__OBJC_BOOL_IS_BOOL=0
  -Wno-macro-redefined
  "${OPT_FLAGS[@]}"
)

echo "Building Slate ($ARCH, $CONFIG${VERSION:+, $VERSION})"
echo "  clang: $CLANG ($("$CLANG" --version | head -1))"
echo "  sdk:   $SDK"

OBJECTS=()
for src in "${SOURCES[@]}"; do
  obj="$OBJDIR/$(echo "$src" | tr '/' '_' | sed 's/\.m$/.o/')"
  extra_flags=()
  [[ "$src" == *JSONKit.m ]] && extra_flags+=(-fno-objc-arc -Wno-deprecated-objc-isa-usage)
  "$CLANG" "${COMMON_FLAGS[@]}" ${extra_flags[@]+"${extra_flags[@]}"} -c "$src" -o "$obj"
  OBJECTS+=("$obj")
done

# The app links WebKit (the script engine is WebScriptObject/WebView, not
# JavaScriptCore directly), Carbon (hot keys) and Cocoa.  No Sparkle.
"$CLANG" "${ARCH_FLAGS[@]}" -mmacosx-version-min="$MIN_OS" -isysroot "$SDK" \
  -o "$OUT/Contents/MacOS/Slate" "${OBJECTS[@]}" \
  -framework Cocoa -framework Carbon -framework WebKit -framework ApplicationServices

# ---- Resources -----------------------------------------------------------
# The nib is the one ibtool produced for the original release; MainMenu.xib has
# not changed, and ibtool ships only with Xcode.
PREBUILT="$ROOT/build/Release/Slate.app/Contents/Resources"
cp -R "$PREBUILT/en.lproj" "$OUT/Contents/Resources/"
for f in initialize.js utils.js underscore.js default.slate \
         ASCIIToCode.plist ASCIIToCode_Dvorak.plist ASCIIToCode_Colemak.plist ASCIIToCode_Azerty.plist \
         status.pdf statusActive.pdf icon.icns; do
  cp "$ROOT/Slate/$f" "$OUT/Contents/Resources/$f"
done
cp "$ROOT/Slate/en.lproj/InfoPlist.strings" "$OUT/Contents/Resources/en.lproj/InfoPlist.strings"
# Credits.rtf carries the About panel links; it lives in the repo and must
# override the copy that came from the original release bundle.
cp "$ROOT/Slate/en.lproj/Credits.rtf" "$OUT/Contents/Resources/en.lproj/Credits.rtf"

# Relaunch helper (see build-support/relaunch.m).
"$CLANG" "${ARCH_FLAGS[@]}" -mmacosx-version-min="$MIN_OS" -isysroot "$SDK" \
  -fobjc-arc -Wno-deprecated-declarations \
  -o "$OUT/Contents/Resources/relaunch" build-support/relaunch.m -framework Cocoa
chmod +x "$OUT/Contents/Resources/relaunch"

# ---- Info.plist ----------------------------------------------------------
python3 - "$ROOT/Slate/Slate-Info.plist" "$OUT/Contents/Info.plist" "$MIN_OS" "$VERSION" <<'PY'
import plistlib, sys
src, dst, min_os = sys.argv[1], sys.argv[2], sys.argv[3]
version = sys.argv[4] if len(sys.argv) > 4 else '' 
with open(src, 'rb') as f:
    p = plistlib.load(f)
sub = {
    '${EXECUTABLE_NAME}': 'Slate',
    '${PRODUCT_NAME:rfc1034identifier}': 'Slate',
    '${PRODUCT_NAME}': 'Slate',
    '${MACOSX_DEPLOYMENT_TARGET}': min_os,
}
for k, v in list(p.items()):
    if isinstance(v, str):
        for needle, repl in sub.items():
            v = v.replace(needle, repl)
        p[k] = v
if version:
    p['CFBundleShortVersionString'] = version
    p['CFBundleVersion'] = version
with open(dst, 'wb') as f:
    plistlib.dump(p, f, fmt=plistlib.FMT_XML, sort_keys=True)
PY
printf 'APPL????' > "$OUT/Contents/PkgInfo"

# ---- Sign ----------------------------------------------------------------
# Sign the relaunch helper first: it is nested code living in Resources/, and
# notarization rejects an unsigned executable there.  Re-signing it also
# changes the file, so it must happen before the outer bundle seal.
if [[ "$SIGN_ID" == "-" ]]; then
  codesign --force --sign - "$OUT/Contents/Resources/relaunch" >/dev/null 2>&1 || true
  codesign --force --sign - "$OUT" >/dev/null 2>&1 || true
else
  codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$OUT/Contents/Resources/relaunch"
  codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$OUT"
fi

echo "Built: $OUT"
file "$OUT/Contents/MacOS/Slate"

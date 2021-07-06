#!/usr/bin/env bash

set -e

# === Parse args ===

cmd="$1"

if [ -z "$cmd" ]; then
    echo "You have to provide a command to run."
    exit 1
fi

# === Constans ===

developmentTeam="$DEVELOPMENT_TEAM"
toolsDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
nativeDir="$(cd "$toolsDir/.." && pwd)"
projectDir="$(cd "$nativeDir/.." && pwd)"
buildDir="$projectDir/build/apple"
archivesDir="$buildDir/archives"
xcframeworksDir="$buildDir/Xcframeworks"

scheme=CBL_Dart_All
frameworks=(CouchbaseLiteDart CouchbaseLite)
declare -A platforms=([ios]=iOS [ios_simulator]="iOS Simulator" [macos]=macOS)

# === Commands ===

function clean() {
    rm -rf "$buildDir"
}

function build() {
    local platformIds="${1:-!platforms[@]}"
    local configuration="${2:-Release}"

    for platformId in "$platformIds"; do
        buildPlatform "$platformId" "$configuration"
    done

    createXcframeworks "$platformIds"

    _createLinksForDev
}

function createXcframeworks() {
    local platformIds="${1:-!platforms[@]}"

    for framework in "${frameworks[@]}"; do
        createXcframework "$framework" "$platformIds"
    done
}

function _createLinksForDev() {
    cd "$projectDir/packages/cbl_e2e_tests_standalone_dart"
    rm -f Frameworks
    ln -s "$archivesDir/macos.xcarchive/Products/Library/Frameworks"

    cd "$projectDir/packages/cbl_flutter"
    rm -f Xcframeworks
    ln -s "$xcframeworksDir"
}

function buildPlatform() {
    if [ -z "$developmentTeam" ]; then
        echo "You have to set the DEVELOPMENT_TEAM environment variable."
        exit 1
    fi

    cd "$nativeDir"

    local platformId="$1"
    local configuration="${2:-Release}"
    local platform="${platforms[$platformId]}"

    echo Building platform "$platform"

    local destination="generic/platform=$platform"

    export CCACHE_SLOPPINESS=include_file_ctime,include_file_mtime,pch_defines,time_macros

    xcodebuild archive \
        -scheme "$scheme" \
        -destination "$destination" \
        -configuration "$configuration" \
        -archivePath "$archivesDir/$platformId" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        DEVELOPMENT_TEAM=$developmentTeam \
        CODE_SIGN_IDENTITY="Apple Development" \
        CODE_SIGN_STYLE=Manual \
        CMAKE_OPTS="-DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache" \
        CC="/usr/local/opt/ccache/libexec/clang" \
        CXX="/usr/local/opt/ccache/libexec/clang++"
}

function createXcframework() {
    local framework="$1"
    local platformIds="$2"

    echo Creating xcframework "$framework"

    local frameworksArgs=()

    for platformId in "$platformIds"; do
        local archive="$archivesDir/$platformId.xcarchive"

        if [ ! -e "$archive" ]; then
            continue
        fi

        frameworksArgs+=(
            "-framework"
            "$archive/Products/Library/Frameworks/$framework.framework"
            "-debug-symbols"
            "$archive/dSYMs/$framework.framework.dSYM"
        )
    done

    xcodebuild -create-xcframework \
        "${frameworksArgs[@]}" \
        -output "$xcframeworksDir/$framework.xcframework"
}

"$@"

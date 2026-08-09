# C/Migemo build script for emacs-build

function action3_cmigemo ()
{
    local cmigemo_repo="https://github.com/koron/cmigemo.git"
    local cmigemo_branch="main"
    local cmigemo_source_dir="$emacs_build_git_dir/cmigemo"
    local cmigemo_install_dir="$emacs_build_install_dir/cmigemo-$architecture"
    local cmigemo_zip_file="$emacs_build_zip_dir/cmigemo-${architecture}.zip"

    if test -f "$cmigemo_zip_file"; then
        echo "File $cmigemo_zip_file already exists. Skipping C/Migemo rebuild."
        emacs_extensions="$cmigemo_zip_file $emacs_extensions"
        return 0
    fi

    echo "Building C/Migemo via CMake..."
    clone_repo "$cmigemo_branch" "$cmigemo_repo" "$cmigemo_source_dir" \
        && cmigemo_build "$cmigemo_source_dir" "$cmigemo_install_dir" \
        && cmigemo_package "$cmigemo_install_dir" "$cmigemo_zip_file" \
        && emacs_extensions="$cmigemo_zip_file $emacs_extensions"
}

function cmigemo_build ()
{
    local src_dir="$1"
    local inst_dir="$2"
    local build_dir="$src_dir/build"

    ensure_packages cmake perl curl gzip ${mingw_prefix}-iconv iconv

    local iconv_path=`type -p iconv 2>/dev/null`
    if test -z "$iconv_path" || test ! -f "$iconv_path"; then
        iconv_path="${MINGW_PREFIX}/bin/iconv.exe"
    fi
    if test ! -f "$iconv_path"; then
        iconv_path="/usr/bin/iconv.exe"
    fi

    local cc_compiler="${MINGW_PREFIX}/bin/gcc.exe"
    if test ! -f "$cc_compiler"; then
        cc_compiler="${MINGW_PREFIX}/bin/clang.exe"
    fi

    mkdir -p "$build_dir" "$inst_dir"
    cd "$src_dir"
    cmake -B "$build_dir" -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$inst_dir" -DCMAKE_C_COMPILER="$cc_compiler" -DICONV_EXECUTABLE="$iconv_path" \
        && cmake --build "$build_dir" \
        && cmake --install "$build_dir"

    # Also place migemo-dict directly under share/migemo for convenience
    if test -d "$inst_dir/share/cmigemo/utf-8"; then
        mkdir -p "$inst_dir/share/migemo"
        cp -rf "$inst_dir/share/cmigemo/utf-8"/* "$inst_dir/share/migemo/" 2>/dev/null || true
    fi
}

function cmigemo_package ()
{
    local inst_dir="$1"
    local zip_file="$2"
    cd "$inst_dir" && zip -9r "$zip_file" *
}

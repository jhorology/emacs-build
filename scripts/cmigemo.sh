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

    # perl and curl/gzip are needed for dict generation.
    # We bypass cmake's dict subdirectory (which needs iconv.exe) and generate
    # the dictionary ourselves using Perl's Encode module instead.
    ensure_packages cmake perl curl gzip

    # Skip cmake's dict build — we generate it ourselves using Perl below.
    sed -i 's/add_subdirectory(dict)/# add_subdirectory(dict)/' "$src_dir/CMakeLists.txt"

    local cc_compiler="${MINGW_PREFIX}/bin/gcc.exe"
    if test ! -f "$cc_compiler"; then
        cc_compiler="${MINGW_PREFIX}/bin/clang.exe"
    fi

    mkdir -p "$build_dir" "$inst_dir"
    cd "$src_dir"
    cmake -B "$build_dir" -G "Unix Makefiles" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$inst_dir" \
        -DCMAKE_C_COMPILER="$cc_compiler" \
        -DBUILD_TESTING=OFF \
        && cmake --build "$build_dir" \
        && cmake --install "$build_dir" \
        && cmigemo_generate_dict "$src_dir" "$inst_dir"
}

function cmigemo_generate_dict ()
{
    local src_dir="$1"
    local inst_dir="$2"
    local dict_src="$src_dir/dict"
    local dict_build="$src_dir/build/dict"
    local skkdict_url="https://skk-dev.github.io/dict/SKK-JISYO.L.gz"

    mkdir -p "$dict_build"
    cd "$dict_build"

    echo "Downloading SKK-JISYO.L..."
    curl -fsSL -o SKK-JISYO.L.gz "$skkdict_url"
    gzip -d SKK-JISYO.L.gz

    # Use Perl's Encode module to convert EUC-JP -> UTF-8.
    # This avoids the iconv.exe dependency entirely.
    echo "Converting SKK-JISYO.L from EUC-JP to UTF-8 using Perl..."
    perl -MEncode -e '
        binmode(STDIN, ":raw"); binmode(STDOUT, ":raw");
        my $in = do { local $/; <STDIN> };
        print Encode::encode("utf-8", Encode::decode("euc-jp", $in));
    ' < SKK-JISYO.L > SKK-JISYO.L.utf-8

    echo "Generating migemo-dict..."
    perl "$dict_src/skk2migemo.pl" < SKK-JISYO.L.utf-8 \
        | perl "$dict_src/optimize-dict.pl" > migemo-dict

    # Install UTF-8 dict (the primary encoding Emacs uses)
    local utf8_dest="$inst_dir/share/cmigemo/utf-8"
    mkdir -p "$utf8_dest"
    cp "$dict_build/migemo-dict" "$utf8_dest/migemo-dict"
    for dat in "$dict_src"/*.dat; do
        cp "$dat" "$utf8_dest/"
    done

    # Include the bundled Chinese dict if present
    if test -f "$dict_src/migemo-dict-zh"; then
        local zh_dest="$inst_dir/share/cmigemo/zh"
        mkdir -p "$zh_dest"
        cp "$dict_src/migemo-dict-zh" "$zh_dest/migemo-dict"
    fi

    # Place a copy in share/migemo/ for Emacs packages that look there
    mkdir -p "$inst_dir/share/migemo"
    cp -rf "$utf8_dest"/* "$inst_dir/share/migemo/" 2>/dev/null || true
}

function cmigemo_package ()
{
    local inst_dir="$1"
    local zip_file="$2"
    cd "$inst_dir" && zip -9r "$zip_file" *
}

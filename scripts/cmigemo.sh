# C/Migemo build script for emacs-build

function action3_cmigemo ()
{
    local cmigemo_repo="https://github.com/koron/cmigemo.git"
    local cmigemo_branch="master"
    local cmigemo_source_dir="$emacs_build_git_dir/cmigemo"
    local cmigemo_install_dir="$emacs_build_install_dir/cmigemo-$architecture"
    local cmigemo_zip_file="$emacs_build_zip_dir/cmigemo-${architecture}.zip"

    if test -f "$cmigemo_zip_file"; then
        echo "File $cmigemo_zip_file already exists. Skipping C/Migemo rebuild."
        emacs_extensions="$cmigemo_zip_file $emacs_extensions"
        return 0
    fi

    echo "Building C/Migemo..."
    clone_repo "$cmigemo_branch" "$cmigemo_repo" "$cmigemo_source_dir" \
        && cmigemo_build "$cmigemo_source_dir" \
        && cmigemo_install "$cmigemo_source_dir" "$cmigemo_install_dir" \
        && cmigemo_package "$cmigemo_install_dir" "$cmigemo_zip_file" \
        && emacs_extensions="$cmigemo_zip_file $emacs_extensions"
}

function cmigemo_build ()
{
    local src_dir="$1"
    cd "$src_dir"
    ./configure
    make gcc-all || make -f compile/make_gcc.mak
    make gcc-dict || make -f compile/make_gcc.mak dict
}

function cmigemo_install ()
{
    local src_dir="$1"
    local inst_dir="$2"
    local bindir="$inst_dir/bin"
    local dictdir="$inst_dir/share/migemo"
    mkdir -p "$bindir" "$dictdir"

    echo "Copying C/Migemo executables and dictionaries..."
    find "$src_dir" -name "cmigemo.exe" -exec cp -f {} "$bindir/" \;
    find "$src_dir" -name "migemo.dll" -exec cp -f {} "$bindir/" \;
    
    if test -d "$src_dir/dict"; then
        cp -rf "$src_dir/dict"/* "$dictdir/" 2>/dev/null || true
    fi
}

function cmigemo_package ()
{
    local inst_dir="$1"
    local zip_file="$2"
    cd "$inst_dir" && zip -9r "$zip_file" *
}

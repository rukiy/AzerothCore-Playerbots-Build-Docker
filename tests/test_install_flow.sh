#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/test_helper.sh"
load_installer

temp_dir="$(mktemp -d)"
trap 'rm -rf -- "$temp_dir"' EXIT

make_project_tree() {
    local root="$1"

    mkdir -p "$root/project/src"
    printf '#!/bin/bash\nprintf "%%s\\n" "$*" > "$AC_TEST_MARKER"\nexit "${AC_TEST_INSTALL_EXIT_CODE:-0}"\n' > "$root/project/ac.sh"
    printf '配置\n' > "$root/project/ac.conf"
    printf '#!/bin/bash\n' > "$root/project/src/lib.sh"
}

make_zip() {
    local source_root="$1"
    local archive="$2"

    (cd "$source_root" && zip -qry "$archive" .)
}

make_malicious_zip() {
    local archive="$1"
    local mode="$2"

    python3 - "$archive" "$mode" <<'PY'
import stat
import struct
import sys
import warnings
import zipfile

archive, mode = sys.argv[1:]
warnings.filterwarnings("ignore", message="Duplicate name:.*")

if mode == "empty":
    local = struct.pack("<IHHHHHIIIHH", 0x04034B50, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    central = struct.pack("<IHHHHHHIIIHHHHHII", 0x02014B50, 20, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    end = struct.pack("<IHHHHIIH", 0x06054B50, 0, 0, 1, 1, len(central), len(local), 0)
    open(archive, "wb").write(local + central + end)
    sys.exit(0)

def add(zf, name, data=b"x", attrs=None):
    info = zipfile.ZipInfo(name)
    if attrs is not None:
        info.create_system = 3
        info.external_attr = attrs << 16
    zf.writestr(info, data)

with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as zf:
    if mode == "multiple":
        add(zf, "one/a")
        add(zf, "two/b")
    elif mode == "top-file":
        add(zf, "project")
    elif mode == "missing":
        add(zf, "project/ac.conf")
        add(zf, "project/src/lib.sh")
    elif mode == "duplicate":
        add(zf, "project/ac.sh")
        add(zf, "project/ac.sh")
    elif mode == "many":
        for index in range(6):
            add(zf, f"project/{index}")
    elif mode == "ratio":
        add(zf, "project/large", b"0" * 10000)
    elif mode == "single-size":
        add(zf, "project/large", b"0" * 101)
    elif mode == "total-size":
        add(zf, "project/one", b"0" * 60)
        add(zf, "project/two", b"0" * 60)
    elif mode == "encrypted":
        add(zf, "project/ac.sh")
    elif mode in {"symlink", "device", "fifo", "socket"}:
        types = {
            "symlink": stat.S_IFLNK | 0o777,
            "device": stat.S_IFCHR | 0o600,
            "fifo": stat.S_IFIFO | 0o600,
            "socket": stat.S_IFSOCK | 0o600,
        }
        add(zf, "project/special", attrs=types[mode])
    else:
        names = {
            "backslash": "project\\evil",
            "absolute": "/project/evil",
            "unc": "//server/share",
            "drive": "C:/project/evil",
            "empty-component": "project//evil",
            "dot": "project/./evil",
            "dotdot": "project/../evil",
            "control": "project/evil\x01",
        }
        add(zf, names[mode])

if mode == "encrypted":
    data = bytearray(open(archive, "rb").read())
    # 本地文件头和中央目录中的通用标志都设置加密位。
    for signature, offset in ((b"PK\x03\x04", 6), (b"PK\x01\x02", 8)):
        position = data.find(signature)
        data[position + offset] |= 1
    open(archive, "wb").write(data)
PY
}

test_fetch_url_atomicity() {
    local work="$temp_dir/fetch"
    local output="$work/archive.zip"

    mkdir -p "$work"
    curl() {
        local destination=""
        while [ "$#" -gt 0 ]; do
            if [ "$1" = -o ]; then
                destination="$2"
                shift 2
                continue
            fi
            shift
        done
        printf 'partial' > "$destination"
        return 42
    }
    export -f curl
    if fetch_url "https://example.invalid/source.zip" "$output" >/dev/null 2>&1; then
        fail "下载失败时 fetch_url 应返回非零"
    fi
    [ ! -e "$output" ] || fail "下载失败不得生成最终文件"
    [ ! -e "$output.part" ] || fail "下载失败必须删除 .part 文件"

    curl() {
        local destination=""
        while [ "$#" -gt 0 ]; do
            if [ "$1" = -o ]; then
                destination="$2"
                shift 2
                continue
            fi
            shift
        done
        printf 'complete' > "$destination"
    }
    export -f curl
    fetch_url "https://example.invalid/source.zip" "$output"
    assert_eq "complete" "$(<"$output")" "成功下载应原子生成最终文件"
    [ ! -e "$output.part" ] || fail "成功下载后不得残留 .part 文件"
    unset -f curl
}

test_download_fallback() {
    local output="$temp_dir/fallback.zip"
    local calls="$temp_dir/download-calls"
    local messages status

    : > "$calls"
    fetch_url() {
        printf '%s\n' "$1" >> "$calls"
        case "$1" in
            https://gh.idayer.com/*) printf 'zip' > "$2" ;;
            *) echo "模拟失败: $1" >&2; return 17 ;;
        esac
    }
    export -f fetch_url
    AC_INSTALL_REPO="owner/repo"
    AC_INSTALL_BRANCH="branch"
    download_archive "$output" >/dev/null
    assert_eq "$(printf '%s\n' \
        'https://github.com/owner/repo/archive/refs/heads/branch.zip' \
        'https://gh-proxy.com/https://github.com/owner/repo/archive/refs/heads/branch.zip' \
        'https://gh.llkk.cc/https://github.com/owner/repo/archive/refs/heads/branch.zip' \
        'https://gh.idayer.com/https://github.com/owner/repo/archive/refs/heads/branch.zip')" \
        "$(<"$calls")" "下载地址回退顺序错误"
    assert_eq "zip" "$(<"$output")" "第三个代理成功后应保留归档"

    : > "$calls"
    fetch_url() {
        printf '%s\n' "$1" >> "$calls"
        echo "最终错误: $1" >&2
        return 29
    }
    export -f fetch_url
    set +e
    messages="$(download_archive "$output" 2>&1)"
    status=$?
    set -e
    assert_eq "29" "$status" "全部下载失败应透传最后一次状态"
    while IFS= read -r url; do
        assert_contains "$messages" "$url" "错误汇总应列出全部已尝试地址"
    done < <(download_candidates)
    assert_contains "$messages" "最终错误:" "错误汇总应保留最后一次下载错误"
    assert_contains "$messages" "最后状态：29" "错误汇总应包含最后一次下载状态"
    assert_eq "5" "$(wc -l < "$calls" | tr -d ' ')" "全部失败时应尝试五个地址"
    [ ! -e "$output.part" ] || fail "全部失败不得残留 .part 文件"
    unset -f fetch_url
}

assert_archive_rejected() {
    local archive="$1"
    local message="$2"
    local extract="$temp_dir/extract-$RANDOM"
    local output

    if output="$(extract_and_validate_archive "$archive" "$extract" 2>&1)"; then
        fail "$message"
    fi
}

test_archive_validation() {
    local fixture="$temp_dir/archives"
    local archive source_dir mode

    mkdir -p "$fixture"
    printf 'not a zip' > "$fixture/broken.zip"
    assert_archive_rejected "$fixture/broken.zip" "损坏 ZIP 应被拒绝"

    make_malicious_zip "$fixture/multiple.zip" multiple
    assert_archive_rejected "$fixture/multiple.zip" "多个顶层目录应被拒绝"

    make_malicious_zip "$fixture/top-file.zip" top-file
    assert_archive_rejected "$fixture/top-file.zip" "顶层普通文件应被拒绝"

    make_malicious_zip "$fixture/missing.zip" missing
    assert_archive_rejected "$fixture/missing.zip" "缺少关键文件应被拒绝"

    for mode in empty backslash absolute unc drive empty-component dot dotdot control duplicate encrypted symlink device fifo socket; do
        make_malicious_zip "$fixture/$mode.zip" "$mode"
        assert_archive_rejected "$fixture/$mode.zip" "恶意归档类型 $mode 应被拒绝"
    done

    make_malicious_zip "$fixture/many.zip" many
    AC_ZIP_MAX_ENTRIES=5 assert_archive_rejected "$fixture/many.zip" "条目数超限应被拒绝"
    make_malicious_zip "$fixture/single-size.zip" single-size
    AC_ZIP_MAX_FILE_SIZE=100 assert_archive_rejected "$fixture/single-size.zip" "单文件展开大小超限应被拒绝"
    make_malicious_zip "$fixture/total-size.zip" total-size
    AC_ZIP_MAX_TOTAL_SIZE=100 assert_archive_rejected "$fixture/total-size.zip" "总展开大小超限应被拒绝"
    make_malicious_zip "$fixture/ratio.zip" ratio
    AC_ZIP_MAX_RATIO=2 assert_archive_rejected "$fixture/ratio.zip" "压缩比超限应被拒绝"

    make_project_tree "$fixture/valid"
    make_zip "$fixture/valid" "$fixture/valid.zip"
    archive="$fixture/valid.zip"
    source_dir="$(extract_and_validate_archive "$archive" "$fixture/valid-extract")"
    assert_eq "$fixture/valid-extract/project" "$source_dir" "完整归档应返回唯一项目目录"
}

test_parent_security() {
    local parent="$temp_dir/unsafe-parent"
    local install="$parent/acore"
    local foreign_parent="$temp_dir/foreign-parent"

    mkdir -p "$parent"
    chmod 0777 "$parent"
    if validate_install_parent "$install" >/dev/null 2>&1; then
        fail "非 sticky 的 group/world 可写父目录应被拒绝"
    fi

    chmod 1777 "$parent"
    validate_install_parent "$install"

    mkdir -p "$foreign_parent"
    chown 65534:65534 "$foreign_parent"
    if validate_install_parent "$foreign_parent/acore" >/dev/null 2>&1; then
        fail "非 root 拥有的父目录应被拒绝"
    fi
}

test_prepare_install_parent_stops_on_unsafe_ancestor() {
    local ancestor="$temp_dir/unsafe-ancestor"
    local install="$ancestor/missing/parent/acore"
    local status

    mkdir -p "$ancestor"
    chmod 0777 "$ancestor"
    set +e
    prepare_install_parent "$install" >/dev/null 2>&1
    status=$?
    set -e
    [ "$status" -ne 0 ] || fail "不安全祖先应使父目录准备失败"
    [ ! -e "$ancestor/missing" ] || fail "不安全祖先下不得创建缺失父目录"
}

test_create_install_temp_dir_propagates_failures() {
    local install="$temp_dir/temp-failure/acore"
    local original_prepare
    local status

    original_prepare="$(declare -f prepare_install_parent)"
    AC_INSTALL_TMP_DIR=""
    AC_INSTALL_TMP_DIR_CREATED=""
    prepare_install_parent() { return 41; }
    set +e
    create_install_temp_dir "$install"
    status=$?
    set -e
    eval "$original_prepare"
    assert_eq "41" "$status" "父目录准备失败状态应透传"
    assert_eq "" "$AC_INSTALL_TMP_DIR" "父目录准备失败不得设置临时目录变量"
    assert_eq "" "$AC_INSTALL_TMP_DIR_CREATED" "父目录准备失败不得设置临时目录所有权标记"
    [ ! -e "$temp_dir/temp-failure" ] || fail "父目录准备失败不得创建目录"

    mkdir -p "$temp_dir/temp-failure"
    AC_INSTALL_TMP_DIR=""
    AC_INSTALL_TMP_DIR_CREATED=""
    mktemp() { return 47; }
    set +e
    create_install_temp_dir "$install"
    status=$?
    set -e
    unset -f mktemp
    assert_eq "47" "$status" "mktemp 失败状态应透传"
    assert_eq "" "$AC_INSTALL_TMP_DIR" "mktemp 失败不得设置临时目录变量"
    assert_eq "" "$AC_INSTALL_TMP_DIR_CREATED" "mktemp 失败不得设置临时目录所有权标记"
    assert_eq "0" "$(find "$temp_dir/temp-failure" -mindepth 1 -maxdepth 1 -type d -name '.acore-installer.*' | wc -l | tr -d ' ')" "mktemp 失败不得留下临时目录"
}

test_partial_install_preserved() {
    local source="$temp_dir/partial-source"
    local install="$temp_dir/partial-install"
    local install_tmp="$temp_dir/partial-tmp"
    local status

    mkdir -p "$source" "$install_tmp"
    AC_INSTALL_TMP_DIR="$install_tmp"
    printf one > "$source/one"
    printf two > "$source/two"
    claim_install_dir "$install"
    AC_TEST_MV_COUNT=0
    mv() {
        AC_TEST_MV_COUNT=$((AC_TEST_MV_COUNT + 1))
        if [ "$AC_TEST_MV_COUNT" -eq 2 ]; then
            return 31
        fi
        command mv "$@"
    }
    set +e
    install_validated_source "$source" "$install"
    status=$?
    set -e
    unset -f mv
    assert_eq "31" "$status" "内容迁移失败应返回原始状态"
    [ -d "$install" ] || fail "内容迁移失败后必须保留目标目录"
    assert_eq "1" "$(find "$install" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" "应保留已迁移内容用于诊断"
}

assert_find_failure_stops_install() {
    local mode="$1"
    local source="$temp_dir/find-source-$mode"
    local install="$temp_dir/find-install-$mode"
    local install_tmp="$temp_dir/find-tmp-$mode"
    local status

    mkdir -p "$source" "$install_tmp"
    printf one > "$source/one"
    printf two > "$source/two"
    claim_install_dir "$install"
    AC_INSTALL_TMP_DIR="$install_tmp"
    find() {
        printf '%s\0' "$source/one"
        [ "$mode" = partial ] || printf '%s\0' "$source/two"
        return 55
    }
    set +e
    install_validated_source "$source" "$install"
    status=$?
    set -e
    unset -f find
    assert_eq "55" "$status" "find 输出 $mode 条目后失败应透传状态"
    assert_eq "0" "$(find "$install" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" "find 失败后不得迁移任何条目"
}

test_main_stops_when_find_fails() {
    local fixture="$temp_dir/find-main-fixture"
    local archive="$temp_dir/find-main.zip"
    local install="$temp_dir/find-main-install"
    local marker="$temp_dir/find-main.log"
    local status

    make_project_tree "$fixture"
    make_zip "$fixture" "$archive"
    find() {
        printf '%s\0' "$1/src" "$1/ac.sh" "$1/ac.conf"
        return 55
    }
    set +e
    AC_TEST_MARKER="$marker" AC_TEST_INSTALL_EXIT_CODE=0 run_main_fixture "$install" "$archive"
    status=$?
    set -e
    unset -f find
    assert_eq "55" "$status" "main 应透传源码列表生成失败状态"
    [ ! -e "$marker" ] || fail "源码列表生成失败时不得执行 ac.sh"
    [ -d "$install" ] || fail "源码列表生成失败后应保留已声明目标目录"
}

run_main_fixture() {
    local install_dir="$1"
    local archive="$2"

    id() { [ "$1" = -u ] && printf '0\n'; }
    detect_platform() { :; }
    install_bootstrap_dependencies() { :; }
    check_bootstrap_commands() { :; }
    check_docker_environment() { :; }
    download_archive() { cp -- "$archive" "$1"; }
    export -f id detect_platform install_bootstrap_dependencies check_bootstrap_commands check_docker_environment download_archive
    AC_INSTALL_DIR="$install_dir" main
}

test_main_success_and_status() {
    local fixture="$temp_dir/main-fixture"
    local archive="$temp_dir/main.zip"
    local install_success="$temp_dir/install-success"
    local install_failure="$temp_dir/install-failure"
    local marker_success="$temp_dir/success.log"
    local marker_failure="$temp_dir/failure.log"
    local status

    make_project_tree "$fixture"
    make_zip "$fixture" "$archive"
    AC_TEST_MARKER="$marker_success" AC_TEST_INSTALL_EXIT_CODE=0 run_main_fixture "$install_success" "$archive"
    assert_eq "install" "$(<"$marker_success")" "主流程应调用 ac.sh install"
    [ -d "$install_success" ] || fail "成功安装后应保留项目目录"
    assert_eq "700" "$(stat -c %a -- "$install_success")" "原子声明的目标目录权限应为 0700"

    set +e
    AC_TEST_MARKER="$marker_failure" AC_TEST_INSTALL_EXIT_CODE=23 run_main_fixture "$install_failure" "$archive"
    status=$?
    set -e
    assert_eq "23" "$status" "ac.sh 状态 23 应由 main 原样返回"
    assert_eq "install" "$(<"$marker_failure")" "失败安装仍应记录 install 参数"
    [ -d "$install_failure" ] || fail "ac.sh 失败后应保留项目目录"
    assert_eq "0" "$(find "$temp_dir" -mindepth 1 -maxdepth 1 -type d -name '.acore-installer.*' | wc -l | tr -d ' ')" "ac.sh 失败后应清理临时目录"
}

assert_race_rejected() {
    local kind="$1"
    local fixture="$temp_dir/race-fixture-$kind"
    local archive="$temp_dir/race-$kind.zip"
    local install="$temp_dir/race-target-$kind"
    local attack="$temp_dir/attack-$kind"
    local attack_marker="$temp_dir/attack-$kind.log"
    local hook_marker="$temp_dir/hook-$kind.log"
    local status

    make_project_tree "$fixture"
    make_zip "$fixture" "$archive"
    mkdir -p "$attack"
    printf 'sentinel\n' > "$attack/sentinel"
    printf '#!/bin/bash\nprintf attacked > "%s"\n' "$attack_marker" > "$attack/ac.sh"
    chmod +x "$attack/ac.sh"
    AC_TEST_RACE_KIND="$kind"
    AC_TEST_RACE_INSTALL="$install"
    AC_TEST_RACE_ATTACK="$attack"
    AC_TEST_RACE_HOOK_MARKER="$hook_marker"
    mkdir() {
        if [ "$#" -eq 4 ] && [ "$1" = -m ] && [ "$2" = 0700 ] && [ "$3" = -- ] && [ "$4" = "$AC_TEST_RACE_INSTALL" ]; then
            printf 'called\n' > "$AC_TEST_RACE_HOOK_MARKER"
            case "$AC_TEST_RACE_KIND" in
                directory)
                    command mkdir -- "$AC_TEST_RACE_INSTALL"
                    cp -- "$AC_TEST_RACE_ATTACK/ac.sh" "$AC_TEST_RACE_ATTACK/sentinel" "$AC_TEST_RACE_INSTALL/"
                    ;;
                symlink) ln -s "$AC_TEST_RACE_ATTACK" "$AC_TEST_RACE_INSTALL" ;;
                broken-symlink) ln -s "$AC_TEST_RACE_ATTACK-missing" "$AC_TEST_RACE_INSTALL" ;;
            esac
        fi
        command mkdir "$@"
    }
    set +e
    run_main_fixture "$install" "$archive" >/dev/null 2>&1
    status=$?
    set -e
    [ "$status" -ne 0 ] || fail "并发出现 $kind 目标时必须失败"
    assert_eq "called" "$(<"$hook_marker")" "竞态钩子必须在最终声明前执行"
    [ ! -e "$attack_marker" ] || fail "不得执行并发目标中的 ac.sh"
    case "$kind" in
        directory) [ -f "$install/sentinel" ] || fail "不得删除或覆盖竞争目录" ;;
        symlink) [ -L "$install" ] && [ -f "$attack/sentinel" ] || fail "不得删除或覆盖竞争符号链接" ;;
        broken-symlink) [ -L "$install" ] || fail "不得删除断链符号链接" ;;
    esac
    assert_eq "0" "$(find "$temp_dir" -mindepth 1 -maxdepth 1 -type d -name '.acore-installer.*' | wc -l | tr -d ' ')" "竞态失败后应清理临时目录"
    unset -f mkdir
    unset AC_TEST_RACE_KIND AC_TEST_RACE_INSTALL AC_TEST_RACE_ATTACK AC_TEST_RACE_HOOK_MARKER
}

test_fetch_url_atomicity
test_download_fallback
test_archive_validation
test_parent_security
test_prepare_install_parent_stops_on_unsafe_ancestor
test_create_install_temp_dir_propagates_failures
test_partial_install_preserved
assert_find_failure_stops_install partial
assert_find_failure_stops_install all
test_main_success_and_status
test_main_stops_when_find_fails
assert_race_rejected directory
assert_race_rejected symlink
assert_race_rejected broken-symlink

echo "安装下载、归档与执行流程测试通过"

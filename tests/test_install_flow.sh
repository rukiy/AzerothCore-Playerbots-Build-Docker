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
    printf 'hidden\n' > "$root/project/.project-state"
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

test_fetch_url_move_failure_status() {
    local work="$temp_dir/fetch-move-failure"
    local output="$work/archive.zip"
    local status

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
        printf 'curl-complete' > "$destination"
    }
    mv() { return 37; }
    export -f curl mv
    set +e
    fetch_url "https://example.invalid/curl.zip" "$output" >/dev/null 2>&1
    status=$?
    set -e
    unset -f curl mv
    assert_eq "37" "$status" "curl 下载完成后 mv 失败应透传状态"
    [ ! -e "$output" ] || fail "curl 的 mv 失败不得生成目标文件"
    [ ! -e "$output.part" ] || fail "curl 的 mv 失败必须清理 .part 文件"

    command() {
        if [ "$1" = -v ] && [ "$2" = curl ]; then
            return 1
        fi
        builtin command "$@"
    }
    wget() {
        local destination="$2"
        printf 'wget-complete' > "$destination"
    }
    mv() { return 37; }
    export -f command wget mv
    set +e
    fetch_url "https://example.invalid/wget.zip" "$output" >/dev/null 2>&1
    status=$?
    set -e
    unset -f command wget mv
    assert_eq "37" "$status" "wget 下载完成后 mv 失败应透传状态"
    [ ! -e "$output" ] || fail "wget 的 mv 失败不得生成目标文件"
    [ ! -e "$output.part" ] || fail "wget 的 mv 失败必须清理 .part 文件"
}

test_move_failure_allows_proxy_fallback() {
    local output="$temp_dir/move-fallback.zip"
    local move_count_file="$temp_dir/move-fallback.count"

    printf '0\n' > "$move_count_file"
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
    mv() {
        local count
        count="$(<"$AC_TEST_MOVE_COUNT_FILE")"
        count=$((count + 1))
        printf '%s\n' "$count" > "$AC_TEST_MOVE_COUNT_FILE"
        if [ "$count" -eq 1 ]; then
            return 37
        fi
        command mv "$@"
    }
    export AC_TEST_MOVE_COUNT_FILE="$move_count_file"
    export -f curl mv
    AC_INSTALL_REPO="owner/repo"
    AC_INSTALL_BRANCH="branch"
    download_archive "$output" >/dev/null
    unset -f curl mv
    unset AC_TEST_MOVE_COUNT_FILE
    assert_eq "2" "$(<"$move_count_file")" "原站发布失败后应继续尝试代理"
    assert_eq "complete" "$(<"$output")" "代理回退成功后应生成完整目标文件"
}

test_download_candidates_direct_only() {
    local expected="https://github.com/owner/repo/archive/refs/heads/branch.zip"

    AC_INSTALL_REPO="owner/repo"
    AC_INSTALL_BRANCH="branch"
    assert_eq "5" "$(download_candidates | wc -l | tr -d ' ')" "默认应输出原站和四个代理"
    assert_eq "$expected" "$(AC_INSTALL_DIRECT_ONLY=1 download_candidates)" "仅直连模式不得输出代理地址"
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

test_atomic_publish_failure_is_invisible() {
    local parent="$temp_dir/publish-failure"
    local install="$parent/acore"
    local install_tmp="$parent/.acore-installer.ABC123"
    local source="$install_tmp/source/project"
    local mode_file="$temp_dir/publish-source-mode"
    local status

    mkdir -p "$source/src"
    printf '#!/bin/bash\n' > "$source/ac.sh"
    printf 'config\n' > "$source/ac.conf"
    printf '#!/bin/bash\n' > "$source/src/lib.sh"
    chmod 0755 "$source"
    AC_INSTALL_TMP_DIR="$install_tmp"
    python3() {
        stat -c %a -- "$2" > "$AC_TEST_SOURCE_MODE_FILE"
        return 39
    }
    export AC_TEST_SOURCE_MODE_FILE="$mode_file"
    export -f python3
    set +e
    atomic_publish_source "$source" "$install"
    status=$?
    set -e
    unset -f python3
    unset AC_TEST_SOURCE_MODE_FILE
    assert_eq "39" "$status" "rename helper 失败状态应原样透传"
    assert_eq "700" "$(<"$mode_file")" "发布前源码目录权限应收紧为 0700"
    [ ! -e "$install" ] && [ ! -L "$install" ] || fail "发布失败不得暴露目标目录"
    [ -d "$source" ] || fail "发布失败后完整源码目录应留在私有临时目录等待清理"
}

test_atomic_publish_rejects_outside_source() {
    local parent="$temp_dir/publish-outside"
    local install="$parent/acore"
    local install_tmp="$parent/.acore-installer.DEF456"
    local source="$parent/outside-source"
    local status

    mkdir -p "$install_tmp" "$source"
    AC_INSTALL_TMP_DIR="$install_tmp"
    set +e
    atomic_publish_source "$source" "$install" >/dev/null 2>&1
    status=$?
    set -e
    [ "$status" -ne 0 ] || fail "私有临时目录外的源码不得发布"
    [ ! -e "$install" ] && [ ! -L "$install" ] || fail "非法源码位置不得生成目标目录"
}

test_atomic_publish_success() {
    local parent="$temp_dir/publish-success"
    local install="$parent/acore"
    local install_tmp="$parent/.acore-installer.GHI789"
    local source="$install_tmp/source/project"

    make_project_tree "$install_tmp/source"
    source="$install_tmp/source/project"
    AC_INSTALL_TMP_DIR="$install_tmp"
    atomic_publish_source "$source" "$install"
    [ ! -e "$source" ] || fail "发布成功后源码目录应整体移出临时目录"
    [ -f "$install/ac.sh" ] || fail "发布成功时 ac.sh 应随目录整体出现"
    [ -f "$install/ac.conf" ] || fail "发布成功时 ac.conf 应随目录整体出现"
    [ -f "$install/src/lib.sh" ] || fail "发布成功时 src/lib.sh 应随目录整体出现"
    assert_eq "hidden" "$(<"$install/.project-state")" "发布成功时点文件应随目录整体出现"
    assert_eq "700" "$(stat -c %a -- "$install")" "发布后的目标目录权限应为 0700"
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
    [ -f "$install_success/ac.sh" ] && [ -f "$install_success/ac.conf" ] && [ -f "$install_success/src/lib.sh" ] || fail "成功发布后关键文件必须完整出现"
    assert_eq "hidden" "$(<"$install_success/.project-state")" "成功发布后点文件必须完整出现"

    set +e
    AC_TEST_MARKER="$marker_failure" AC_TEST_INSTALL_EXIT_CODE=23 run_main_fixture "$install_failure" "$archive"
    status=$?
    set -e
    assert_eq "23" "$status" "ac.sh 状态 23 应由 main 原样返回"
    assert_eq "install" "$(<"$marker_failure")" "失败安装仍应记录 install 参数"
    [ -d "$install_failure" ] || fail "ac.sh 失败后应保留项目目录"
    [ -f "$install_failure/ac.sh" ] && [ -f "$install_failure/ac.conf" ] && [ -f "$install_failure/src/lib.sh" ] || fail "ac.sh 返回 23 后应保留完整项目"
    assert_eq "hidden" "$(<"$install_failure/.project-state")" "ac.sh 返回 23 后应保留项目点文件"
    assert_eq "0" "$(find "$temp_dir" -mindepth 1 -maxdepth 1 -type d -name '.acore-installer.*' | wc -l | tr -d ' ')" "ac.sh 失败后应清理临时目录"
}

assert_race_rejected() {
    local kind="$1"
    local fixture="$temp_dir/race-fixture-$kind"
    local archive="$temp_dir/race-$kind.zip"
    local install="$temp_dir/race-target-$kind"
    local attack="$temp_dir/attack-$kind"
    local attack_marker="$temp_dir/attack-$kind.log"
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
    python3() {
        if [ "$1" = - ] && [ "$3" = "$AC_TEST_RACE_INSTALL" ]; then
            case "$AC_TEST_RACE_KIND" in
                directory)
                    command mkdir -- "$AC_TEST_RACE_INSTALL"
                    cp -- "$AC_TEST_RACE_ATTACK/ac.sh" "$AC_TEST_RACE_ATTACK/sentinel" "$AC_TEST_RACE_INSTALL/"
                    ;;
                symlink) ln -s "$AC_TEST_RACE_ATTACK" "$AC_TEST_RACE_INSTALL" ;;
                broken-symlink) ln -s "$AC_TEST_RACE_ATTACK-missing" "$AC_TEST_RACE_INSTALL" ;;
            esac
        fi
        command python3 "$@"
    }
    set +e
    run_main_fixture "$install" "$archive" >/dev/null 2>&1
    status=$?
    set -e
    [ "$status" -ne 0 ] || fail "并发出现 $kind 目标时必须失败"
    [ ! -e "$attack_marker" ] || fail "不得执行并发目标中的 ac.sh"
    case "$kind" in
        directory) [ -f "$install/sentinel" ] || fail "不得删除或覆盖竞争目录" ;;
        symlink) [ -L "$install" ] && [ -f "$attack/sentinel" ] || fail "不得删除或覆盖竞争符号链接" ;;
        broken-symlink) [ -L "$install" ] || fail "不得删除断链符号链接" ;;
    esac
    assert_eq "0" "$(find "$temp_dir" -mindepth 1 -maxdepth 1 -type d -name '.acore-installer.*' | wc -l | tr -d ' ')" "竞态失败后应清理临时目录"
    unset -f python3
    unset AC_TEST_RACE_KIND AC_TEST_RACE_INSTALL AC_TEST_RACE_ATTACK
}

test_fetch_url_atomicity
test_fetch_url_move_failure_status
test_move_failure_allows_proxy_fallback
test_download_candidates_direct_only
test_download_fallback
test_archive_validation
test_parent_security
test_prepare_install_parent_stops_on_unsafe_ancestor
test_create_install_temp_dir_propagates_failures
test_atomic_publish_failure_is_invisible
test_atomic_publish_rejects_outside_source
test_atomic_publish_success
test_main_success_and_status
assert_race_rejected directory
assert_race_rejected symlink
assert_race_rejected broken-symlink

echo "安装下载、归档与执行流程测试通过"

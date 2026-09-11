#!/usr/bin/python3
# SPDX-FileCopyrightText: Copyright (c) 2026 MR Dula Solutions
# SPDX-License-Identifier: MIT
"""Fd-relative path operations under $HOME with O_NOFOLLOW.

Walks from / to $HOME, then each relative component, using openat(
O_DIRECTORY|O_NOFOLLOW). mkdir, write, rename, and delete use those held
descriptors so a symlink in .local or opt cannot redirect the operation.
"""
from __future__ import annotations

import os
import stat
import sys
import secrets

O_FLAGS = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
UID = os.getuid()


def die(msg: str) -> None:
    print(msg, file=sys.stderr)
    raise SystemExit(1)


def home_path() -> str:
    home = os.environ.get("HOME") or ""
    if not home.startswith("/") or home == "/":
        die("HOME is unset or not an absolute path")
    parts = [p for p in home.split("/") if p]
    if not parts or any(p in (".", "..") for p in parts):
        die("HOME is not a usable directory")
    return home


def rel_parts(rel: str) -> list[str]:
    if not rel or rel.startswith("/") or rel.endswith("/"):
        die("relative path required")
    parts = rel.split("/")
    if any(p in ("", ".", "..") for p in parts):
        die("illegal path component")
    return parts


def fstat_dir(fd: int, must_own: bool) -> os.stat_result:
    st = os.fstat(fd)
    if not stat.S_ISDIR(st.st_mode):
        die("not a directory")
    if stat.S_ISLNK(st.st_mode):
        die("symlink directory")
    if must_own and st.st_uid != UID:
        die("directory not owned by current user")
    return st


def open_home() -> int:
    parts = rel_parts(home_path().lstrip("/"))
    fd = os.open("/", os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC)
    try:
        for i, part in enumerate(parts):
            nfd = os.open(part, O_FLAGS, dir_fd=fd)
            os.close(fd)
            fd = nfd
            last = i == len(parts) - 1
            fstat_dir(fd, must_own=last)
        return fd
    except Exception:
        os.close(fd)
        raise


def walk(home_fd: int, parts: list[str], create: bool) -> int:
    fd = os.dup(home_fd)
    try:
        for part in parts:
            try:
                nfd = os.open(part, O_FLAGS, dir_fd=fd)
            except FileNotFoundError:
                if not create:
                    os.close(fd)
                    die("missing directory component: " + part)
                try:
                    os.mkdir(part, 0o700, dir_fd=fd)
                    nfd = os.open(part, O_FLAGS, dir_fd=fd)
                except OSError as e:
                    os.close(fd)
                    die("cannot create %s: %s" % (part, e.strerror))
            except OSError as e:
                os.close(fd)
                die("cannot open %s: %s" % (part, e.strerror))
            os.close(fd)
            fd = nfd
            fstat_dir(fd, must_own=True)
        return fd
    except Exception:
        os.close(fd)
        raise


def cmd_ensure(rel: str) -> None:
    home_fd = open_home()
    try:
        dfd = walk(home_fd, rel_parts(rel), create=True)
        os.close(dfd)
    finally:
        os.close(home_fd)


def cmd_atomic_write(rel: str) -> None:
    parts = rel_parts(rel)
    name = parts[-1]
    home_fd = open_home()
    try:
        dfd = walk(home_fd, parts[:-1], create=True) if parts[:-1] else os.dup(home_fd)
        try:
            tmp = ".tmp." + secrets.token_hex(8)
            tfd = os.open(
                tmp,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC,
                0o600,
                dir_fd=dfd,
            )
            try:
                while True:
                    chunk = sys.stdin.buffer.read(1024 * 1024)
                    if not chunk:
                        break
                    os.write(tfd, chunk)
                os.fsync(tfd)
            except Exception:
                os.close(tfd)
                try:
                    os.unlink(tmp, dir_fd=dfd)
                except OSError:
                    pass
                raise
            os.close(tfd)
            os.rename(tmp, name, src_dir_fd=dfd, dst_dir_fd=dfd)
        finally:
            os.close(dfd)
    finally:
        os.close(home_fd)


def rmtree_fd(dfd: int) -> None:
    for name in os.listdir(dfd):
        if name in (".", ".."):
            continue
        st = os.lstat(name, dir_fd=dfd)
        if stat.S_ISDIR(st.st_mode) and not stat.S_ISLNK(st.st_mode):
            child = os.open(name, O_FLAGS, dir_fd=dfd)
            try:
                rmtree_fd(child)
            finally:
                os.close(child)
            os.rmdir(name, dir_fd=dfd)
        else:
            os.unlink(name, dir_fd=dfd)


def has_marker(dfd: int) -> bool:
    for marker in (".omarchy-pair-version", "nvpair"):
        try:
            st = os.lstat(marker, dir_fd=dfd)
        except FileNotFoundError:
            continue
        if stat.S_ISLNK(st.st_mode):
            continue
        if marker == "nvpair" and st.st_mode & 0o111 and stat.S_ISREG(st.st_mode):
            return True
        if marker == ".omarchy-pair-version" and stat.S_ISREG(st.st_mode):
            return True
    return False


def cmd_rm_tree(rel: str) -> None:
    parts = rel_parts(rel)
    name = parts[-1]
    home_fd = open_home()
    try:
        parent = walk(home_fd, parts[:-1], create=False) if parts[:-1] else os.dup(home_fd)
        try:
            try:
                st = os.lstat(name, dir_fd=parent)
            except FileNotFoundError:
                return
            if stat.S_ISLNK(st.st_mode) or not stat.S_ISDIR(st.st_mode):
                die("refusing to delete non-directory or symlink: " + rel)
            dfd = os.open(name, O_FLAGS, dir_fd=parent)
            try:
                if not has_marker(dfd):
                    die("refusing to delete unrecognized directory: " + rel)
                rmtree_fd(dfd)
            finally:
                os.close(dfd)
            os.rmdir(name, dir_fd=parent)
        finally:
            os.close(parent)
    finally:
        os.close(home_fd)


def cmd_unlink(rel: str) -> None:
    parts = rel_parts(rel)
    name = parts[-1]
    home_fd = open_home()
    try:
        parent = walk(home_fd, parts[:-1], create=False)
        try:
            try:
                st = os.lstat(name, dir_fd=parent)
            except FileNotFoundError:
                return
            if stat.S_ISLNK(st.st_mode) or not stat.S_ISREG(st.st_mode):
                die("refusing to unlink non-regular file: " + rel)
            os.unlink(name, dir_fd=parent)
        finally:
            os.close(parent)
    finally:
        os.close(home_fd)


def cmd_chmod(rel: str, mode_s: str) -> None:
    mode = int(mode_s, 8)
    parts = rel_parts(rel)
    name = parts[-1]
    home_fd = open_home()
    try:
        parent = walk(home_fd, parts[:-1], create=False)
        try:
            fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=parent)
            try:
                st = os.fstat(fd)
                if not stat.S_ISREG(st.st_mode):
                    die("chmod target is not a regular file")
                os.fchmod(fd, mode)
            finally:
                os.close(fd)
        finally:
            os.close(parent)
    finally:
        os.close(home_fd)


def cmd_copy_file(src: str, rel: str) -> None:
    if not src.startswith("/") or ".." in src.split("/"):
        die("source must be an absolute path")
    sfd = os.open(src, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        st = os.fstat(sfd)
        if not stat.S_ISREG(st.st_mode):
            die("source is not a regular file")
        parts = rel_parts(rel)
        name = parts[-1]
        home_fd = open_home()
        try:
            parent = walk(home_fd, parts[:-1], create=True)
            try:
                tmp = ".tmp." + secrets.token_hex(8)
                tfd = os.open(
                    tmp,
                    os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC,
                    0o644,
                    dir_fd=parent,
                )
                try:
                    while True:
                        chunk = os.read(sfd, 1024 * 1024)
                        if not chunk:
                            break
                        os.write(tfd, chunk)
                    os.fsync(tfd)
                except Exception:
                    os.close(tfd)
                    try:
                        os.unlink(tmp, dir_fd=parent)
                    except OSError:
                        pass
                    raise
                os.close(tfd)
                os.rename(tmp, name, src_dir_fd=parent, dst_dir_fd=parent)
            finally:
                os.close(parent)
        finally:
            os.close(home_fd)
    finally:
        os.close(sfd)


def cmd_publish_dir(src: str, rel: str) -> None:
    if not src.startswith("/") or any(p == ".." for p in src.split("/")):
        die("source must be an absolute path")
    src = src.rstrip("/")
    src_name = os.path.basename(src)
    src_parent = os.path.dirname(src)
    src_pfd = os.open(src_parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        st = os.lstat(src_name, dir_fd=src_pfd)
        if stat.S_ISLNK(st.st_mode) or not stat.S_ISDIR(st.st_mode):
            die("source is not a real directory")
        src_dfd = os.open(src_name, O_FLAGS, dir_fd=src_pfd)
        try:
            if not has_marker(src_dfd) and not _has_file(src_dfd, "nvpair"):
                die("source is not a PAIR tree")
        finally:
            os.close(src_dfd)
        parts = rel_parts(rel)
        dest_name = parts[-1]
        home_fd = open_home()
        try:
            dest_parent = walk(home_fd, parts[:-1], create=True)
            try:
                try:
                    st = os.lstat(dest_name, dir_fd=dest_parent)
                except FileNotFoundError:
                    st = None
                if st is not None:
                    if stat.S_ISLNK(st.st_mode) or not stat.S_ISDIR(st.st_mode):
                        die("destination exists and is not a real directory")
                    old = os.open(dest_name, O_FLAGS, dir_fd=dest_parent)
                    try:
                        if not has_marker(old):
                            die("refusing to replace unrecognized directory")
                        rmtree_fd(old)
                    finally:
                        os.close(old)
                    os.rmdir(dest_name, dir_fd=dest_parent)
                os.rename(src_name, dest_name, src_dir_fd=src_pfd, dst_dir_fd=dest_parent)
            finally:
                os.close(dest_parent)
        finally:
            os.close(home_fd)
    finally:
        os.close(src_pfd)


def _has_file(dfd: int, name: str) -> bool:
    try:
        st = os.lstat(name, dir_fd=dfd)
    except FileNotFoundError:
        return False
    return stat.S_ISREG(st.st_mode) and not stat.S_ISLNK(st.st_mode)


def _copy_pair_icons(stage_fd: int, home_fd: int) -> None:
    try:
        usr = os.open("usr", O_FLAGS, dir_fd=stage_fd)
    except FileNotFoundError:
        return
    try:
        share = os.open("share", O_FLAGS, dir_fd=usr)
        try:
            icons = os.open("icons", O_FLAGS, dir_fd=share)
            try:
                hicolor = os.open("hicolor", O_FLAGS, dir_fd=icons)
            except FileNotFoundError:
                return
            try:
                dest_hi = walk(home_fd, ["local", "share", "icons", "hicolor"], create=True)
                try:
                    for sz in os.listdir(hicolor):
                        try:
                            sz_fd = os.open(sz, O_FLAGS, dir_fd=hicolor)
                        except (FileNotFoundError, NotADirectoryError, OSError):
                            continue
                        try:
                            try:
                                apps = os.open("apps", O_FLAGS, dir_fd=sz_fd)
                            except FileNotFoundError:
                                continue
                            try:
                                try:
                                    src_st = os.lstat("nvpair.png", dir_fd=apps)
                                except FileNotFoundError:
                                    continue
                                if not stat.S_ISREG(src_st.st_mode) or stat.S_ISLNK(src_st.st_mode):
                                    continue
                                sfd = os.open(
                                    "nvpair.png",
                                    os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC,
                                    dir_fd=apps,
                                )
                                try:
                                    dest_sz = walk_from(dest_hi, [sz, "apps"], create=True)
                                    try:
                                        tmp = ".tmp." + secrets.token_hex(8)
                                        tfd = os.open(
                                            tmp,
                                            os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC,
                                            0o644,
                                            dir_fd=dest_sz,
                                        )
                                        try:
                                            while True:
                                                chunk = os.read(sfd, 1024 * 1024)
                                                if not chunk:
                                                    break
                                                os.write(tfd, chunk)
                                            os.fsync(tfd)
                                        except Exception:
                                            os.close(tfd)
                                            os.unlink(tmp, dir_fd=dest_sz)
                                            raise
                                        os.close(tfd)
                                        os.rename(
                                            tmp,
                                            "nvpair.png",
                                            src_dir_fd=dest_sz,
                                            dst_dir_fd=dest_sz,
                                        )
                                    finally:
                                        os.close(dest_sz)
                                finally:
                                    os.close(sfd)
                            finally:
                                os.close(apps)
                        finally:
                            os.close(sz_fd)
                finally:
                    os.close(dest_hi)
            finally:
                os.close(hicolor)
            os.close(icons)
        finally:
            os.close(share)
    finally:
        os.close(usr)


def walk_from(start_fd: int, parts: list[str], create: bool) -> int:
    fd = os.dup(start_fd)
    try:
        for part in parts:
            try:
                nfd = os.open(part, O_FLAGS, dir_fd=fd)
            except FileNotFoundError:
                if not create:
                    os.close(fd)
                    die("missing directory component: " + part)
                try:
                    os.mkdir(part, 0o700, dir_fd=fd)
                    nfd = os.open(part, O_FLAGS, dir_fd=fd)
                except OSError as e:
                    os.close(fd)
                    die("cannot create %s: %s" % (part, e.strerror))
            except OSError as e:
                os.close(fd)
                die("cannot open %s: %s" % (part, e.strerror))
            os.close(fd)
            fd = nfd
            fstat_dir(fd, must_own=True)
        return fd
    except Exception:
        os.close(fd)
        raise


def cmd_verify_file(rel: str, sha: str, size_s: str) -> None:
    import hashlib

    size = int(size_s)
    if len(sha) != 64 or any(c not in "0123456789abcdef" for c in sha):
        die("malformed sha256")
    parts = rel_parts(rel)
    name = parts[-1]
    home_fd = open_home()
    try:
        parent = walk(home_fd, parts[:-1], create=False)
        try:
            fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=parent)
            try:
                st = os.fstat(fd)
                if not stat.S_ISREG(st.st_mode):
                    die("not a regular file")
                if st.st_size != size:
                    die("size mismatch")
                h = hashlib.sha256()
                while True:
                    chunk = os.read(fd, 1024 * 1024)
                    if not chunk:
                        break
                    h.update(chunk)
                if h.hexdigest() != sha:
                    die("SHA-256 mismatch")
            finally:
                os.close(fd)
        finally:
            os.close(parent)
    finally:
        os.close(home_fd)


def cmd_extract_and_publish(rel: str) -> None:
    import subprocess
    import tarfile

    parts = rel_parts(rel)
    name = parts[-1]
    home_fd = open_home()
    try:
        state_fd = walk(home_fd, parts[:-1], create=True)
        try:
            deb_fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=state_fd)
            try:
                st = os.fstat(deb_fd)
                if not stat.S_ISREG(st.st_mode):
                    die("deb is not a regular file")
                staging = ".extract." + secrets.token_hex(8)
                os.mkdir(staging, 0o700, dir_fd=state_fd)
                stage_fd = os.open(staging, O_FLAGS, dir_fd=state_fd)
                try:
                    deb_path = "/proc/self/fd/%d" % deb_fd
                    cwd_path = "/proc/self/fd/%d" % stage_fd
                    r = subprocess.run(
                        ["/usr/bin/ar", "x", deb_path],
                        cwd=cwd_path,
                        check=False,
                        capture_output=True,
                    )
                    if r.returncode != 0:
                        die("ar x failed")
                    data_name = None
                    for entry in os.listdir(stage_fd):
                        if entry.startswith("data.tar.") and not entry.endswith(".deb"):
                            st_e = os.lstat(entry, dir_fd=stage_fd)
                            if stat.S_ISREG(st_e.st_mode) and not stat.S_ISLNK(st_e.st_mode):
                                data_name = entry
                                break
                    if not data_name:
                        die("deb has no data.tar.*")
                    data_fd = os.open(data_name, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=stage_fd)
                    try:
                        wanted = []
                        nvpair = False
                        with tarfile.open(fileobj=os.fdopen(os.dup(data_fd), "rb"), mode="r:*") as tf:
                            for member in tf.getmembers():
                                mname = member.name.lstrip("./")
                                bits = mname.split("/")
                                if mname.startswith("/") or any(p == ".." for p in bits):
                                    die("unsafe tar member")
                                if member.issym() or member.islnk() or member.isdev() or member.isfifo():
                                    die("refusing special tar member")
                                if not (member.isfile() or member.isdir()):
                                    continue
                                if not (
                                    mname == "opt/PAIR"
                                    or mname.startswith("opt/PAIR/")
                                    or mname.startswith("usr/share/icons/hicolor/")
                                ):
                                    continue
                                member.name = mname
                                wanted.append(member)
                                if mname == "opt/PAIR/nvpair" and member.isfile():
                                    nvpair = True
                            if not nvpair:
                                die("package did not contain opt/PAIR/nvpair")
                            kwargs = {"path": cwd_path, "members": wanted}
                            if hasattr(tarfile, "data_filter"):
                                kwargs["filter"] = "data"
                            tf.extractall(**kwargs)
                    finally:
                        os.close(data_fd)
                    opt_fd = os.open("opt", O_FLAGS, dir_fd=stage_fd)
                    try:
                        pair_st = os.lstat("PAIR", dir_fd=opt_fd)
                        if stat.S_ISLNK(pair_st.st_mode) or not stat.S_ISDIR(pair_st.st_mode):
                            die("extracted PAIR is not a real directory")
                        pair_fd = os.open("PAIR", O_FLAGS, dir_fd=opt_fd)
                        try:
                            if not _has_file(pair_fd, "nvpair"):
                                die("extracted nvpair missing")
                            nfd = os.open(
                                "nvpair",
                                os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC,
                                dir_fd=pair_fd,
                            )
                            try:
                                os.fchmod(nfd, 0o755)
                            finally:
                                os.close(nfd)
                        finally:
                            os.close(pair_fd)
                        dest_parent = walk(home_fd, ["local", "opt"], create=True)
                        try:
                            try:
                                old_st = os.lstat("PAIR", dir_fd=dest_parent)
                            except FileNotFoundError:
                                old_st = None
                            if old_st is not None:
                                if stat.S_ISLNK(old_st.st_mode) or not stat.S_ISDIR(old_st.st_mode):
                                    die("install path exists and is not a real directory")
                                old = os.open("PAIR", O_FLAGS, dir_fd=dest_parent)
                                try:
                                    if not has_marker(old):
                                        die("refusing to replace unrecognized directory")
                                    rmtree_fd(old)
                                finally:
                                    os.close(old)
                                os.rmdir("PAIR", dir_fd=dest_parent)
                            os.rename("PAIR", "PAIR", src_dir_fd=opt_fd, dst_dir_fd=dest_parent)
                        finally:
                            os.close(dest_parent)
                    finally:
                        os.close(opt_fd)
                    _copy_pair_icons(stage_fd, home_fd)
                finally:
                    rmtree_fd(stage_fd)
                    os.close(stage_fd)
                    os.rmdir(staging, dir_fd=state_fd)
            finally:
                os.close(deb_fd)
        finally:
            os.close(state_fd)
    finally:
        os.close(home_fd)


def _is_reg(dfd: int, name: str) -> bool:
    try:
        st = os.lstat(name, dir_fd=dfd)
    except FileNotFoundError:
        return False
    return stat.S_ISREG(st.st_mode) and not stat.S_ISLNK(st.st_mode)


def _is_dir(dfd: int, name: str) -> bool:
    try:
        st = os.lstat(name, dir_fd=dfd)
    except FileNotFoundError:
        return False
    return stat.S_ISDIR(st.st_mode) and not stat.S_ISLNK(st.st_mode)


def pair_config_guard(dfd: int) -> bool:
    """PAIR data dir: node-id.json plus cluster/ or settings.json."""
    if not _is_reg(dfd, "node-id.json"):
        return False
    return _is_dir(dfd, "cluster") or _is_reg(dfd, "settings.json")


def walk_optional(home_fd: int, parts: list[str]) -> int | None:
    fd = os.dup(home_fd)
    try:
        for part in parts:
            try:
                nfd = os.open(part, O_FLAGS, dir_fd=fd)
            except FileNotFoundError:
                os.close(fd)
                return None
            except OSError as e:
                os.close(fd)
                die("cannot open %s: %s" % (part, e.strerror))
            os.close(fd)
            fd = nfd
            fstat_dir(fd, must_own=True)
        return fd
    except Exception:
        os.close(fd)
        raise


def cmd_purge_pair_config() -> None:
    home_fd = open_home()
    try:
        config_fd = walk_optional(home_fd, [".config"])
        if config_fd is None:
            return
        try:
            try:
                nst = os.lstat("Nvidia Corporation", dir_fd=config_fd)
            except FileNotFoundError:
                return
            if stat.S_ISLNK(nst.st_mode) or not stat.S_ISDIR(nst.st_mode):
                die("Nvidia Corporation config path is not a real directory")
            leftover = None
            nvidia_fd = os.open("Nvidia Corporation", O_FLAGS, dir_fd=config_fd)
            try:
                try:
                    pst = os.lstat("Personal AI Router", dir_fd=nvidia_fd)
                except FileNotFoundError:
                    leftover = [n for n in os.listdir(nvidia_fd) if n not in (".", "..")]
                    pst = None
                if pst is not None:
                    if stat.S_ISLNK(pst.st_mode) or not stat.S_ISDIR(pst.st_mode):
                        die("PAIR config path is not a real directory")
                    cfg_fd = os.open("Personal AI Router", O_FLAGS, dir_fd=nvidia_fd)
                    try:
                        if not pair_config_guard(cfg_fd):
                            die("refusing to purge unrecognized NVIDIA config directory")
                        rmtree_fd(cfg_fd)
                    finally:
                        os.close(cfg_fd)
                    os.rmdir("Personal AI Router", dir_fd=nvidia_fd)
                    leftover = [n for n in os.listdir(nvidia_fd) if n not in (".", "..")]
            finally:
                os.close(nvidia_fd)
            if leftover == []:
                try:
                    os.rmdir("Nvidia Corporation", dir_fd=config_fd)
                except OSError:
                    pass
        finally:
            os.close(config_fd)
    finally:
        os.close(home_fd)


def cmd_merge_tray_hidden() -> None:
    import json

    raw_ids = sys.stdin.read(4096)
    ids = []
    for line in raw_ids.splitlines():
        item = line.strip()
        if not item or len(item) > 128:
            continue
        if "\x00" in item:
            continue
        ids.append(item)
        if len(ids) >= 8:
            break
    if not ids:
        return
    home_fd = open_home()
    try:
        parent = walk(home_fd, [".config", "omarchy"], create=False)
        try:
            fd = os.open("shell.json", os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=parent)
            try:
                st = os.fstat(fd)
                if not stat.S_ISREG(st.st_mode):
                    die("shell.json is not a regular file")
                if st.st_uid != UID:
                    die("shell.json not owned by current user")
                if st.st_size > 1_000_000:
                    die("shell.json exceeds size cap")
                data = b""
                while True:
                    chunk = os.read(fd, 65536)
                    if not chunk:
                        break
                    data += chunk
                    if len(data) > 1_000_000:
                        die("shell.json exceeds size cap")
            finally:
                os.close(fd)
            doc = json.loads(data.decode("utf-8"))
            changed = False
            bar = doc.get("bar")
            layout = bar.get("layout") if isinstance(bar, dict) else None
            if not isinstance(layout, dict):
                return
            for section in layout.values():
                if not isinstance(section, list):
                    continue
                for entry in section:
                    if not isinstance(entry, dict) or entry.get("id") != "omarchy.tray":
                        continue
                    hidden = entry.get("hidden", [])
                    if isinstance(hidden, str):
                        hidden = [hidden] if hidden else []
                        changed = True
                    if not isinstance(hidden, list):
                        hidden = []
                        changed = True
                    for item in ids:
                        if item not in hidden:
                            hidden.append(item)
                            changed = True
                    entry["hidden"] = hidden
            if not changed:
                return
            payload = (json.dumps(doc, indent=2) + "\n").encode("utf-8")
            tmp = ".tmp." + secrets.token_hex(8)
            tfd = os.open(
                tmp,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC,
                0o600,
                dir_fd=parent,
            )
            try:
                os.write(tfd, payload)
                os.fsync(tfd)
            except Exception:
                os.close(tfd)
                try:
                    os.unlink(tmp, dir_fd=parent)
                except OSError:
                    pass
                raise
            os.close(tfd)
            os.rename(tmp, "shell.json", src_dir_fd=parent, dst_dir_fd=parent)
        finally:
            os.close(parent)
    finally:
        os.close(home_fd)


def main() -> None:
    if len(sys.argv) < 2:
        die("usage: pathguard.py <command> ...")
    cmd = sys.argv[1]
    if cmd == "ensure" and len(sys.argv) == 3:
        cmd_ensure(sys.argv[2])
    elif cmd == "atomic-write" and len(sys.argv) == 3:
        cmd_atomic_write(sys.argv[2])
    elif cmd == "rm-tree" and len(sys.argv) == 3:
        cmd_rm_tree(sys.argv[2])
    elif cmd == "unlink" and len(sys.argv) == 3:
        cmd_unlink(sys.argv[2])
    elif cmd == "chmod" and len(sys.argv) == 4:
        cmd_chmod(sys.argv[2], sys.argv[3])
    elif cmd == "copy-file" and len(sys.argv) == 4:
        cmd_copy_file(sys.argv[2], sys.argv[3])
    elif cmd == "publish-dir" and len(sys.argv) == 4:
        cmd_publish_dir(sys.argv[2], sys.argv[3])
    elif cmd == "verify-file" and len(sys.argv) == 5:
        cmd_verify_file(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == "extract-and-publish" and len(sys.argv) == 3:
        cmd_extract_and_publish(sys.argv[2])
    elif cmd == "purge-pair-config" and len(sys.argv) == 2:
        cmd_purge_pair_config()
    elif cmd == "merge-tray-hidden" and len(sys.argv) == 2:
        cmd_merge_tray_hidden()
    else:
        die("usage: pathguard.py ensure|atomic-write|rm-tree|unlink|chmod|copy-file|publish-dir|verify-file|extract-and-publish|purge-pair-config|merge-tray-hidden ...")


if __name__ == "__main__":
    main()

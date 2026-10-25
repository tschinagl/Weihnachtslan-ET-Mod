#!/usr/bin/env python3
"""Linux x86_64 development tools for the ETLab gamecode mod (Python 3.10+)."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import re
import shutil
import socket
import subprocess
import sys
import tarfile
import time
import urllib.request
import uuid
import zipfile

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / ".cache/linux"
LOGS = ROOT / "logs/linux"
STATE = CACHE / "state.json"
LOCK = ROOT / "release-linux.lock.json"
PATCH = ROOT / "mod/etlab.patch"
PAKS = ("pak0.pk3", "pak1.pk3", "pak2.pk3")
MODULES = ("qagame.mp.x86_64.so", "cgame.mp.x86_64.so", "ui.mp.x86_64.so", "tvgame.mp.x86_64.so")


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    temporary.replace(path)


def digest(path, algorithm="sha256"):
    value = hashlib.new(algorithm)
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def run(*args, cwd=ROOT, capture=False):
    result = subprocess.run([str(x) for x in args], cwd=cwd, check=True,
                            stdout=subprocess.PIPE if capture else None)
    return result.stdout if capture else None


def git(source, *args):
    return run("git", "-C", source, *args, capture=True)


def source_diff(source):
    # Fixed prefixes/config make the portable patch independent of personal Git settings.
    return git(source, "-c", "diff.noprefix=false", "diff", "--binary", "--no-ext-diff",
               "--no-color", "--src-prefix=a/", "--dst-prefix=b/")


def state():
    if not STATE.exists():
        raise RuntimeError("Zuerst python3 scripts/etlab-linux.py build ausfuehren.")
    return read_json(STATE)


def check_source(saved, allow_edits=False):
    source = ROOT / saved["sourcePath"]
    if git(source, "diff", "--cached", "--name-only").strip():
        raise RuntimeError("Source-Checkout entstagen; neue Dateien mit git add -N erfassen.")
    unknown = git(source, "ls-files", "--others", "--exclude-standard", "-z").decode().split("\0")
    unknown = [x for x in unknown if x and not x.startswith("tests/")]
    if unknown:
        raise RuntimeError("Neue Source-Dateien zuerst mit git add -N markieren: " + ", ".join(unknown))
    if not allow_edits and hashlib.sha256(source_diff(source)).hexdigest() != saved["appliedDiffSha256"]:
        raise RuntimeError("Ungesicherte Gamecode-Aenderungen: zuerst etlab-linux.py save ausfuehren. Nichts wurde ueberschrieben.")


def latest_release():
    with urllib.request.urlopen("https://www.etlegacy.com/download", timeout=30) as response:
        html = response.read().decode("utf-8")
    version = re.search(r"ET: Legacy stable release\s+(\d+\.\d+\.\d+)", html)
    archive = re.search(r'data-href="(https://www\.etlegacy\.com/download/file/\d+)">x86_64 archive</a>(.*?)md5sum:\s*([a-fA-F0-9]{32})', html, re.S)
    if not version or not archive:
        raise RuntimeError("Offizieller Linux-x86_64-Stable-Release nicht eindeutig ermittelbar.")
    return dict(version=version[1], tag="v" + version[1],
                sourceUrl="https://github.com/etlegacy/etlegacy.git", commit="",
                downloadUrl=archive[1], archiveMd5=archive[3].lower(), archiveSha256="",
                platform="linux-x86_64", policy="latest-published-stable")


def copy_verified(source, target):
    if target.exists() and digest(source) == digest(target):
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    if digest(source) != digest(target):
        raise RuntimeError("Kopierpruefung fehlgeschlagen: " + str(target))


def prepare(locked=False):
    CACHE.mkdir(parents=True, exist_ok=True)
    LOGS.mkdir(parents=True, exist_ok=True)
    previous = read_json(STATE) if STATE.exists() else None
    if previous:
        check_source(previous)
    release = read_json(LOCK) if locked else latest_release()
    print("ET: Legacy Stable:", release["version"], flush=True)
    patch_hash = digest(PATCH)
    reuse = previous and previous["version"] == release["version"] and previous["patchSha256"] == patch_hash
    if reuse:
        source = ROOT / previous["sourcePath"]
    else:
        source = CACHE / "sources" / (release["tag"] + "-" + uuid.uuid4().hex[:8])
        source.parent.mkdir(parents=True, exist_ok=True)
        run("git", "-c", "core.autocrlf=false", "clone", "--branch", release["tag"], "--depth", "1", release["sourceUrl"], source)
        git(source, "config", "core.autocrlf", "false")
        git(source, "apply", "--check", PATCH)
        git(source, "apply", PATCH)
    commit = git(source, "rev-parse", "HEAD").decode().strip()
    if locked and release.get("commit") and commit != release["commit"]:
        raise RuntimeError("Source-Commit stimmt nicht mit dem Release-Lock ueberein.")
    run("git", "-C", source, "submodule", "update", "--init", "--recursive", "--jobs", "4")
    (source / "tests").mkdir(exist_ok=True)
    for test in (ROOT / "tests/native").iterdir():
        if test.is_file():
            copy_verified(test, source / "tests" / test.name)
    archive = ROOT / ".cache/downloads" / ("etlegacy-" + release["version"] + "-linux-x86_64.tar.gz")
    archive.parent.mkdir(parents=True, exist_ok=True)
    if not archive.exists():
        temporary = archive.with_suffix(".partial")
        with urllib.request.urlopen(release["downloadUrl"], timeout=120) as response, temporary.open("wb") as output:
            shutil.copyfileobj(response, output)
        if digest(temporary, "md5") != release["archiveMd5"].lower():
            raise RuntimeError("Offizielle Archiv-Pruefsumme stimmt nicht.")
        temporary.replace(archive)
    if digest(archive, "md5") != release["archiveMd5"].lower():
        raise RuntimeError("Archiv-MD5 stimmt nicht.")
    archive_hash = digest(archive)
    if locked and release.get("archiveSha256") and archive_hash != release["archiveSha256"].lower():
        raise RuntimeError("Archiv-SHA256 stimmt nicht mit dem Release-Lock ueberein.")
    runtime = ROOT / "runtime" / ("etlegacy-v" + release["version"] + "-x86_64")
    if not runtime.exists():
        runtime.parent.mkdir(parents=True, exist_ok=True)
        with tarfile.open(archive) as bundle:
            # Official archive contains files/directories only; reject path escapes and links.
            for member in bundle.getmembers():
                destination = (runtime.parent / member.name).resolve()
                if not destination.is_relative_to(runtime) or not (member.isfile() or member.isdir()):
                    raise RuntimeError("Unerwarteter Archivpfad/-typ: " + member.name)
            bundle.extractall(runtime.parent)
    for executable in ("etl.x86_64", "etlded.x86_64"):
        if not (runtime / executable).is_file():
            raise RuntimeError("Offizielle Engine fehlt: " + executable)
    for name in PAKS:
        asset = ROOT / "assets/etmain" / name
        if asset.exists():
            copy_verified(asset, runtime / "etmain" / name)
    release.update(commit=commit, archiveSha256=archive_hash)
    write_json(LOCK, release)
    saved = dict(version=release["version"], commit=commit, sourcePath=source.relative_to(ROOT).as_posix(),
                 runtimePath=runtime.relative_to(ROOT).as_posix(), patchSha256=patch_hash,
                 appliedDiffSha256=hashlib.sha256(source_diff(source)).hexdigest())
    write_json(STATE, saved)
    print("Source:", source, flush=True)
    return saved


def import_assets(directory):
    source = Path(directory).expanduser().resolve()
    for name in PAKS:
        target = ROOT / "assets/etmain" / name
        if not (source / name).is_file():
            raise RuntimeError("Original-Spieldatei fehlt: " + str(source / name))
        if target.exists() and digest(source / name) != digest(target):
            raise RuntimeError("Abweichende vorhandene Spieldatei wird nicht ersetzt: " + str(target))
        copy_verified(source / name, target)
    print("Original-PK3s lokal importiert und SHA256-geprueft.")


def save_changes():
    saved = state()
    check_source(saved, allow_edits=True)
    source = ROOT / saved["sourcePath"]
    for name in git(source, "diff", "--name-only").decode().splitlines():
        if name != "CMakeLists.txt" and not re.match(r"src/(game|cgame|ui|tvgame)/", name):
            raise RuntimeError("Aenderung ausserhalb des Mod-Gamecodes: " + name)
    shutil.copy2(PATCH, CACHE / ("patch-backup-" + uuid.uuid4().hex + ".patch"))
    PATCH.write_bytes(source_diff(source))
    saved.update(patchSha256=digest(PATCH), appliedDiffSha256=hashlib.sha256(source_diff(source)).hexdigest())
    write_json(STATE, saved)
    print("Gamecode in mod/etlab.patch gesichert. Im Mod-Repository reviewen und committen.")


def build(locked=False, jobs=4):
    saved = prepare(locked)
    source, runtime = ROOT / saved["sourcePath"], ROOT / saved["runtimePath"]
    inputs = [PATCH, LOCK, Path(__file__)] + sorted((ROOT / "tests/native").glob("*"))
    fingerprint = ":".join(digest(p) for p in inputs if p.is_file())
    manifest_path = LOGS / "build.json"
    old = read_json(manifest_path) if manifest_path.exists() else {}
    if old.get("input") == fingerprint and old.get("runtime") == saved["runtimePath"] and old.get("files"):
        if all((runtime / "etbudget" / name).is_file() and digest(runtime / "etbudget" / name) == sha for name, sha in old["files"].items()):
            print("Mod-Build ist aktuell und unveraendert.")
            return saved
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            executable = (entry / "exe").resolve(strict=True)
        except OSError:
            continue
        if executable.is_relative_to(runtime):
            raise RuntimeError("ETLab laeuft noch. Vor dem Build Spiel/Server schliessen.")
    build_dir = source / "build"
    options = dict(CMAKE_BUILD_TYPE="Release", CROSS_COMPILE32="OFF", BUNDLED_LIBS="ON", MODNAME="etbudget",
                   BUILD_CLIENT="OFF", BUILD_SERVER="OFF", BUILD_MOD="ON", INSTALL_EXTRA="OFF",
                   FEATURE_AUTOUPDATE="OFF", FEATURE_AUTH="OFF", FEATURE_TRACKER="OFF", FEATURE_CURL="OFF",
                   FEATURE_SSL="OFF", FEATURE_LUA="ON", ETLAB_BUILD_TESTS="ON",
                   FEATURE_IRC_CLIENT="OFF", FEATURE_IRC_SERVER="OFF")
    run("cmake", "-S", source, "-B", build_dir, "-G", "Ninja", *("-D" + k + "=" + v for k, v in options.items()))
    run("cmake", "--build", build_dir, "--parallel", str(jobs), "--target",
        "qagame", "cgame", "ui", "tvgame", "mod_pk3", "etlab_loadout_tests")
    run("ctest", "--test-dir", build_dir, "--output-on-failure")
    output = build_dir / "etbudget"
    files = [output / name for name in MODULES] + list(output.glob("etbudget_*.pk3"))
    if len(files) != 5 or not all(p.is_file() for p in files):
        raise RuntimeError("Unvollstaendige oder mehrdeutige Mod-Ausgabe.")
    destination = runtime / "etbudget"
    destination.mkdir(exist_ok=True)
    for old_pak in destination.glob("etbudget_*.pk3"):
        if old_pak.name not in [p.name for p in files]:
            if old.get("runtime") != saved["runtimePath"] or old_pak.name not in old.get("files", {}):
                raise RuntimeError("Unbekanntes altes Mod-PK3: " + str(old_pak))
            backup = ROOT / "archive" / uuid.uuid4().hex
            backup.mkdir(parents=True)
            shutil.move(str(old_pak), backup / old_pak.name)
    for path in files:
        copy_verified(path, destination / path.name)
    write_json(manifest_path, dict(input=fingerprint, runtime=saved["runtimePath"],
                                  files={p.name: digest(p) for p in files}))
    print("Build und CTest erfolgreich:", destination)
    return saved


def runtime_args(saved, profile, executable="etl.x86_64"):
    runtime = ROOT / saved["runtimePath"]
    for required in [runtime / executable, runtime / "etbudget" / MODULES[0]] + [runtime / "etmain" / p for p in PAKS]:
        if not required.is_file():
            raise RuntimeError("Datei fehlt; Build/Spieldatenimport erforderlich: " + str(required))
    profile.mkdir(parents=True, exist_ok=True)
    return [str(runtime / executable), "+set", "fs_basepath", str(runtime), "+set", "fs_homepath", str(profile),
            "+set", "fs_game", "etbudget", "+set", "net_enabled", "1", "+set", "cl_autoupdate", "0",
            "+set", "com_introplayed", "1", "+set", "logfile", "2"]


def available_port(bind, port):
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind((bind, port))


def local_config(map_name="oasis"):
    return f'''set sv_hostname "Weihnachtslan ET Mod"
set sv_advert 0
set sv_pure 1
set sv_allowDownload 0
set sv_wwwDownload 0
set sv_maxclients 8
set omnibot_enable 0
set g_gametype 2
set g_doWarmup 0
set g_warmup 0
set match_minplayers 1
set g_heavyWeaponRestriction 100
set team_maxPanzers -1
set team_maxFlamers -1
set g_luaModuleList ""
set lua_modules ""
set g_log "etlab-play.log"
set g_logSync 1
set g_etlabPractice 1
bind F6 "etlab_targets"
map {map_name}
'''


def start_game(args):
    saved = build(args.locked, args.jobs)
    runtime = ROOT / saved["runtimePath"]
    profile = ROOT / "profiles" / ("linux-smoke-" + uuid.uuid4().hex if args.mine_smoke else "linux-play")
    mod_profile = profile / "etbudget"
    mod_profile.mkdir(parents=True, exist_ok=True)
    available_port("127.0.0.1", args.port)
    command = runtime_args(saved, profile)
    command += ["+set", "dedicated", "0", "+set", "net_ip", "127.0.0.1", "+set", "net_port", str(args.port),
                "+set", "sv_advert", "0", "+exec", "etlab-play.cfg"]
    config = local_config(args.map)
    if args.mine_smoke or not (mod_profile / "etconfig.cfg").exists():
        config = "set r_fullscreen 0\nset r_mode -1\nset r_customwidth 1280\nset r_customheight 720\n" + config
    if args.mine_smoke:
        shutil.copy2(ROOT / "tests/mines-runtime.lua", mod_profile / "mines-runtime.lua")
        config = config.replace('set lua_modules ""', 'set lua_modules "mines-runtime.lua"').replace("map " + args.map, "devmap " + args.map)
        config = "set g_userAxisRespawnTime 1\nset g_userAlliedRespawnTime 1\n" + config
        config += "wait 180\nmap_restart 0\nwait 60\nteam r 0 5 0\n"
        command += ["+set", "com_maxfps", "60"]
    (mod_profile / "etlab-play.cfg").write_text(config, encoding="utf-8")
    if not args.mine_smoke:
        subprocess.run(command, cwd=runtime, check=True)
        return
    with (mod_profile / "driver.log").open("w", encoding="utf-8") as output:
        with subprocess.Popen(command, cwd=runtime, stdout=output, stderr=subprocess.STDOUT) as process:
            try:
                if process.wait(timeout=180) != 0:
                    raise RuntimeError("Client-Smoke fehlgeschlagen: " + str(mod_profile))
            except BaseException:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                raise
    log = (mod_profile / "etconsole.log").read_text(encoding="utf-8", errors="replace")
    if "ETLAB_MINES_RUNTIME_PASS" not in log or re.search(r"ETLAB_MINES_RUNTIME_FAIL|Lua error", log):
        raise RuntimeError("Gameplay-Smoke fehlgeschlagen: " + str(mod_profile))
    screenshot = mod_profile / "screenshots/etlab-mines-spotted.jpg"
    if not screenshot.is_file() or "Initializing etbudget cgame" not in log:
        raise RuntimeError("Client-/Screenshot-Nachweis fehlt: " + str(mod_profile))
    write_json(LOGS / "client-smoke.json", dict(passed=True, profile=str(profile),
               engineSha256=digest(runtime / "etl.x86_64"), files=read_json(LOGS / "build.json")["files"],
               timings=re.findall(r"ETLAB_DEFUSE_TIMING: ([^\r\n]+)", log)))
    print("PASS Linux-Client-Smoke:", screenshot)


def rcon(port, password, command):
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.settimeout(0.35)
        sock.connect(("127.0.0.1", port))
        sock.send(b"\xff" * 4 + f"rcon {password} {command}".encode("ascii"))
        reply = bytearray()
        while True:
            try:
                reply.extend(sock.recv(65535)[4:])
            except socket.timeout:
                return reply.decode("utf-8", errors="replace")


def assert_loopback_socket(pid, port):
    inodes = set()
    for fd in Path(f"/proc/{pid}/fd").iterdir():
        try:
            link = os.readlink(fd)
        except FileNotFoundError:
            continue
        if link.startswith("socket:["):
            inodes.add(link[8:-1])
    sockets = []
    for table in ("udp", "udp6"):
        for line in Path(f"/proc/{pid}/net/{table}").read_text(encoding="ascii").splitlines()[1:]:
            columns = line.split()
            if columns[9] in inodes:
                sockets.append(columns[1])
    expected = f"0100007F:{port:04X}"
    if expected not in sockets or any(not entry.startswith("0100007F:") for entry in sockets):
        raise RuntimeError("Unerwartete UDP-Bindung des Testservers: " + repr(sockets))


def smoke_server(port=27980):
    saved = state()
    runtime = ROOT / saved["runtimePath"]
    profile = ROOT / "profiles" / ("linux-server-smoke-" + uuid.uuid4().hex)
    mod_profile = profile / "etbudget"
    mod_profile.mkdir(parents=True)
    available_port("127.0.0.1", port)
    password = uuid.uuid4().hex
    shutil.copy2(ROOT / "tests/smoke.lua", mod_profile / "smoke.lua")
    config = local_config().replace('set lua_modules ""', 'set lua_modules "smoke.lua"')
    config = f'set rconPassword "{password}"\n' + config.replace("set g_etlabPractice 1", "set g_etlabPractice 0")
    (mod_profile / "smoke.cfg").write_text(config, encoding="utf-8")
    command = runtime_args(saved, profile, "etlded.x86_64")
    command += ["+set", "dedicated", "1", "+set", "net_ip", "127.0.0.1", "+set", "net_port", str(port), "+exec", "smoke.cfg"]
    with (mod_profile / "driver.log").open("w", encoding="utf-8") as output:
        process = subprocess.Popen(command, cwd=runtime, stdout=output, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 45
            console = mod_profile / "etconsole.log"
            while time.monotonic() < deadline:
                if process.poll() is not None:
                    raise RuntimeError("Server vorzeitig beendet: " + str(mod_profile))
                log = console.read_text(encoding="utf-8", errors="replace") if console.exists() else ""
                if "ETLAB_SMOKE_FRAMES_OK" in log:
                    break
                time.sleep(0.5)
            if "ETLAB_SMOKE_INIT_OK" not in log or "ETLAB_SMOKE_FRAMES_OK" not in log:
                raise RuntimeError("Lua/Map-Smoke fehlgeschlagen: " + str(mod_profile))
            if re.search(r"Lua.*(?:error|failed)|VM_Create.*failed|Sys_Error", log, re.I):
                raise RuntimeError("Laufzeitfehler im Serverlog: " + str(console))
            assert_loopback_socket(process.pid, port)
            status = rcon(port, password, "status")
            if not re.search(r"map\s*:\s+oasis", status):
                raise RuntimeError("Unerwartete RCON-Antwort: " + status)
            rcon(port, password, "quit")
            if process.wait(timeout=10) != 0:
                raise RuntimeError("Server-Exitcode ungleich null.")
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
    write_json(LOGS / "server-smoke.json", dict(passed=True, profile=str(profile),
               engineSha256=digest(runtime / "etlded.x86_64"), files=read_json(LOGS / "build.json")["files"]))
    print("PASS Linux-Server: offizielle Engine, Mod, Oasis, Lua, Loopback, RCON, sauberer Exit.")


def export_mod(jobs, windows_package=None):
    saved = build(locked=True, jobs=jobs)
    runtime = ROOT / saved["runtimePath"]
    binaries = {name: (runtime / "etbudget" / name).read_bytes() for name in read_json(LOGS / "build.json")["files"]}
    target_platform = "linux-x86_64"
    if windows_package:
        with zipfile.ZipFile(windows_package) as windows:
            manifest = json.loads(windows.read("manifest.json"))
            if (manifest["platform"] != "windows-x64" or manifest["commit"] != saved["commit"]
                    or manifest["patchSha256"].lower() != saved["patchSha256"].lower()):
                raise RuntimeError("Windows-Paket muss denselben Source-Commit und Mod-Patch verwenden.")
            win_files = {item["name"]: item["sha256"].lower() for item in manifest["files"]}
            for name in ("cgame_mp_x64.dll", "ui_mp_x64.dll", "qagame_mp_x64.dll", "tvgame_mp_x64.dll"):
                data = windows.read("etbudget/" + name)
                if hashlib.sha256(data).hexdigest() != win_files.get(name):
                    raise RuntimeError("Windows-Paket-Pruefsumme stimmt nicht: " + name)
                binaries[name] = data
        pak_name = next(name for name in binaries if name.endswith(".pk3"))
        combined = io.BytesIO()
        with zipfile.ZipFile(io.BytesIO(binaries[pak_name])) as base, zipfile.ZipFile(combined, "w", zipfile.ZIP_DEFLATED) as pak:
            for item in base.infolist():
                pak.writestr(item, base.read(item.filename))
            for name in ("cgame_mp_x64.dll", "ui_mp_x64.dll"):
                pak.writestr(name, binaries[name])
        binaries[pak_name] = combined.getvalue()
        target_platform = "windows-x64-linux-x86_64"
    output = ROOT / "dist" / ("etbudget-" + target_platform + "-" + saved["version"] + "-" + time.strftime("%Y%m%d-%H%M%S") + ".zip")
    output.parent.mkdir(exist_ok=True)
    manifest = dict(mod="etbudget", platform=target_platform, etLegacy=saved["version"], commit=saved["commit"],
                    patchSha256=saved["patchSha256"], buildSystem=platform.freedesktop_os_release().get("PRETTY_NAME", "Linux"),
                    libc=platform.libc_ver(), files={name: hashlib.sha256(data).hexdigest() for name, data in binaries.items()})
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, data in binaries.items():
            archive.writestr("etbudget/" + name, data)
        archive.write(ROOT / "LICENSE", "LICENSE")
        archive.write(ROOT / "docs/installation.md", "installation.md")
        archive.writestr("manifest.json", json.dumps(manifest, indent=2) + "\n")
    print("Mod-Paket:", output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("prepare", "build", "start", "server", "connect", "export", "smoke", "save", "import-assets"):
        child = commands.add_parser(name)
        if name in ("prepare", "build", "start", "server", "connect"):
            child.add_argument("--locked", action="store_true", help="Eingecheckten Linux-Release-Lock verwenden.")
        if name in ("build", "start", "server", "connect", "export"):
            child.add_argument("--jobs", type=int, choices=range(1, 33), default=min(8, os.cpu_count() or 4), metavar="1-32")
        if name in ("start", "server", "smoke"):
            child.add_argument("--port", type=int, default=27980)
        if name in ("start", "server"):
            child.add_argument("--map", default="oasis")
        if name == "start":
            child.add_argument("--mine-smoke", action="store_true", help="Gameplay-Test mit frischem Profil; schliesst den Client.")
        if name == "server":
            child.add_argument("--bind", default="127.0.0.1", help="Fuer LAN ausdruecklich 0.0.0.0 angeben.")
        if name == "connect":
            child.add_argument("--address", required=True, help="Servername/IP:Port")
        if name == "export":
            child.add_argument("--windows-package", type=Path, help="Passendes Windows-Mod-ZIP fuer gemeinsames LAN-Paket.")
        if name == "import-assets":
            child.add_argument("--source", required=True, help="etmain-Verzeichnis mit pak0/1/2.pk3")
    args = parser.parse_args()
    if sys.platform != "linux" or platform.machine() != "x86_64":
        parser.error("Dieses Werkzeug unter Linux x86_64 ausfuehren.")
    if hasattr(args, "map") and not re.fullmatch(r"[A-Za-z0-9_]+", args.map):
        parser.error("Ungueltiger Mapname.")
    if hasattr(args, "port") and not 1024 <= args.port <= 65535:
        parser.error("Port muss zwischen 1024 und 65535 liegen.")
    if args.command == "import-assets":
        import_assets(args.source)
    elif args.command == "prepare":
        prepare(args.locked)
    elif args.command == "build":
        build(args.locked, args.jobs)
    elif args.command == "save":
        save_changes()
    elif args.command == "smoke":
        smoke_server(args.port)
    elif args.command == "start":
        if args.mine_smoke and args.map != "oasis":
            parser.error("Der Gameplay-Smoke verwendet Oasis.")
        start_game(args)
    elif args.command == "export":
        export_mod(args.jobs, args.windows_package)
    else:
        if args.command == "connect" and not re.fullmatch(r"[A-Za-z0-9_.:-]+", args.address):
            parser.error("Ungueltige Serveradresse.")
        saved = build(args.locked, args.jobs)
        if args.command == "server":
            socket.inet_aton(args.bind)
            available_port(args.bind, args.port)
            profile = ROOT / "profiles/linux-server"
            command = runtime_args(saved, profile, "etlded.x86_64")
            command += ["+set", "dedicated", "1", "+set", "net_ip", args.bind, "+set", "net_port", str(args.port),
                        "+set", "sv_advert", "0", "+set", "sv_pure", "1", "+set", "sv_allowDownload", "0",
                        "+set", "sv_wwwDownload", "0", "+set", "omnibot_enable", "0", "+set", "g_etlabPractice", "0",
                        "+set", "g_gametype", "2", "+map", args.map]
        else:
            command = runtime_args(saved, ROOT / "profiles/linux-client") + ["+connect", args.address]
        subprocess.run(command, cwd=ROOT / saved["runtimePath"], check=True)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError, subprocess.SubprocessError) as error:
        print("FEHLER:", error, file=sys.stderr)
        sys.exit(1)

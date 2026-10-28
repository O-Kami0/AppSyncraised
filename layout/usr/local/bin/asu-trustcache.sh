#!/bin/sh
# asu-trustcache -- make sideloaded apps launchable on iOS 18 and later
#
# Background
# ----------
# AppSync Unified hooks two things:
#   * installd's MISValidateSignatureAndCopyInfoWithProgress()  -> lets the app INSTALL
#   * FrontBoard's trustStateForApplication: (returns 8)         -> marks it trusted
#
# Neither of those covers the check that actually happens at LAUNCH time on
# iOS 18+: AMFI validates each executable image against the trust cache before
# exec. A fakesigned binary that is not in the trust cache is killed with
# SIGKILL (exit 137 / "Killed: 9") even though it installed successfully and
# even though FrontBoard reports it as trusted.
#
# This script adds the cdhash of every Mach-O inside every installed .app
# bundle to the jailbreak trust cache, which is what makes those apps run.
#
# Requires: jbctl (Dopamine/roothide bootstrap) and ldid (Procursus).
#
# Usage:
#   asu-trustcache              scan all installed apps
#   asu-trustcache <path.app>   scan one bundle
#
# Re-run after installing a new IPA, or let the LaunchDaemon do it for you.

JBROOT="${JBROOT:-/var/jb}"
[ -d "$JBROOT" ] || JBROOT=""

PATH="$JBROOT/usr/bin:$JBROOT/usr/sbin:$JBROOT/bin:$JBROOT/sbin:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH

# Resolve the log path explicitly: postinst runs with HOME=/var/root, and the
# LaunchDaemon with no HOME at all, so $HOME is not a reliable base.
if [ -z "$ASU_TRUSTCACHE_LOG" ]; then
    if [ -d /var/mobile/Documents ] && [ -w /var/mobile/Documents ]; then
        ASU_TRUSTCACHE_LOG=/var/mobile/Documents/asu-trustcache.log
    else
        ASU_TRUSTCACHE_LOG=/tmp/asu-trustcache.log
    fi
fi
LOG="$ASU_TRUSTCACHE_LOG"
TMP="${TMPDIR:-/tmp}/.asu_tc_probe"

ADDED=0
SEEN=0
FAILED=0
SKIPPED=0
EXISTING="${TMPDIR:-/tmp}/.asu_tc_existing"

log() {
    { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >>"$LOG"; } 2>/dev/null
}

if ! command -v jbctl >/dev/null 2>&1; then
    echo "asu-trustcache: jbctl not found; nothing to do on this jailbreak." >&2
    log "skipped: jbctl not found (not a Dopamine/roothide jailbreak?)"
    exit 0
fi

if ! command -v ldid >/dev/null 2>&1; then
    echo "asu-trustcache: ldid not found (install the ldid package)." >&2
    log "ERROR: ldid not found"
    exit 1
fi

# At boot this job can start before the jailbreak root is mounted or before
# jbctl's trust cache is initialised. Retry briefly instead of failing once and
# leaving the cache empty until the next StartInterval tick.
_ready=0
for _i in 1 2 3 4 5 6 7 8 9 10; do
    if jbctl trustcache info >/dev/null 2>&1; then
        _ready=1
        break
    fi
    sleep 3
done
if [ "$_ready" -eq 0 ]; then
    echo "asu-trustcache: jbctl trustcache not ready yet; will retry on next interval." >&2
    log "postponed: jbctl trustcache not ready after 30s"
    exit 0
fi

# add_hashes <path-to-macho>
#
# ldid refuses to read Mach-O files that live inside an app container
# (_installd-owned, restricted), so stage a copy in /tmp first. The copy is
# byte-identical, so its cdhash is the binary's cdhash.
add_hashes() {
    _f="$1"
    [ -f "$_f" ] || return 0

    cp "$_f" "$TMP" 2>/dev/null || { FAILED=$((FAILED + 1)); return 0; }
    chmod 755 "$TMP" 2>/dev/null

    _info=$(ldid -h "$TMP" 2>/dev/null)
    rm -f "$TMP" 2>/dev/null

    if [ -z "$_info" ]; then
        FAILED=$((FAILED + 1))
        return 0
    fi

    # ldid prints "CandidateCDHash sha1=<40 hex>" -- note the space between the
    # label and the algorithm name. Both sha1 and sha256 forms are added
    # because the kernel accepts either.
    _hashes=$(printf '%s\n' "$_info" | grep -oE 'CandidateCDHash +(sha1|sha256)=[0-9a-f]{40,64}' | sed 's/.*=//')

    for _h in $_hashes; do
        SEEN=$((SEEN + 1))
        # jbctl appends without checking for duplicates, so re-running this
        # script every 30 minutes would grow the trust cache forever. Skip
        # hashes that are already present; load the existing set once.
        if [ -f "$EXISTING" ] && grep -qi "$_h" "$EXISTING"; then
            SKIPPED=$((SKIPPED + 1))
            continue
        fi
        if jbctl trustcache add "$_h" >/dev/null 2>&1; then
            ADDED=$((ADDED + 1))
            printf '%s\n' "$_h" >>"$EXISTING" 2>/dev/null
        fi
    done
}

scan_bundle() {
    _app="$1"
    [ -d "$_app" ] || return 0

    # Main executable, read from Info.plist rather than assuming it matches
    # the bundle name.
    _exe=$(sed -n 's:.*<key>CFBundleExecutable</key>[[:space:]]*<string>\([^<]*\)</string>.*:\1:p' "$_app/Info.plist" 2>/dev/null | head -1)
    [ -z "$_exe" ] && _exe=$(basename "$_app" .app)
    [ -f "$_app/$_exe" ] && add_hashes "$_app/$_exe"

    # Embedded frameworks
    for _fw in "$_app"/Frameworks/*.framework; do
        [ -d "$_fw" ] || continue
        _n=$(basename "$_fw" .framework)
        [ -f "$_fw/$_n" ] && add_hashes "$_fw/$_n"
    done

    # App extensions
    for _ext in "$_app"/PlugIns/*.appex; do
        [ -d "$_ext" ] || continue
        _n=$(basename "$_ext" .appex)
        [ -f "$_ext/$_n" ] && add_hashes "$_ext/$_n"
    done

    # Loose dylibs shipped next to the binary or under Frameworks/
    for _d in "$_app/Frameworks" "$_app"; do
        for _dy in "$_d"/*.dylib; do
            [ -f "$_dy" ] && add_hashes "$_dy"
        done
    done

    # Nested bundles (watch apps, extension hosts)
    for _sub in "$_app"/Watch/*.app "$_app"/Extensions/*.appex; do
        [ -d "$_sub" ] && scan_bundle "$_sub"
    done
}

log "=== asu-trustcache start ==="

# Prevent overlapping runs (the daemon and a manual invocation can race, and
# jbctl appends duplicates rather than deduplicating).
LOCK="${TMPDIR:-/tmp}/.asu_tc_lock"
if ! mkdir "$LOCK" 2>/dev/null; then
    echo "asu-trustcache: another instance is running; exiting." >&2
    log "skipped: another instance holds the lock"
    exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT INT TERM

# Snapshot the hashes already in the cache so re-runs are idempotent.
rm -f "$EXISTING" 2>/dev/null
jbctl trustcache info 2>/dev/null | grep -oE '[0-9A-Fa-f]{40,64}' | tr 'A-F' 'a-f' >"$EXISTING" 2>/dev/null
log "existing entries: $(wc -l <"$EXISTING" 2>/dev/null || echo 0)"

if [ -n "$1" ]; then
    if [ -d "$1" ]; then
        scan_bundle "$1"
    else
        echo "asu-trustcache: not a directory: $1" >&2
        exit 1
    fi
else
    for _app in /var/containers/Bundle/Application/*/*.app; do
        [ -d "$_app" ] || continue
        scan_bundle "$_app"
    done
fi

log "attempted=$SEEN added=$ADDED already-present=$SKIPPED unreadable=$FAILED"
log "=== asu-trustcache done ==="
rm -f "$EXISTING" 2>/dev/null

# Keep the log from growing without bound on devices that never rotate it.
if [ -f "$LOG" ]; then
    _lines=$(wc -l <"$LOG" 2>/dev/null || echo 0)
    if [ "$_lines" -gt 400 ]; then
        tail -300 "$LOG" >"$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
    fi
fi

exit 0

# AppSyncraised
###### A fork of AppSync Unified — the unified AppSync dynamic library for iOS 5 through iOS 18. Verified working on iOS 18.7.1; package metadata permits up to iOS 26.0.1.

## What is AppSync Unified?

AppSync Unified is a tweak that allows users to freely install ad-hoc signed, fakesigned, unsigned, or expired IPA app packages on their iOS devices that iOS would otherwise consider invalid.

Some popular use cases include:

* Installing freely-distributed apps that are unavailable from the App Store without having to re-sign the apps in question every 7 days (if the user does not have a subscription to the Apple Developer Program)
* Assisting in the development of iOS applications with Xcode
* Cloning or downgrading already-installed apps

---

## Compatibility

This is **AppSyncraised** (118.1), a fork of
[AppSync Unified](https://github.com/akemin-dayo/AppSync) by Karen/あけみ.
It raises the firmware ceiling and adds a trust-cache fix for launching
fakesigned apps on iOS 18+.

| iOS version | Status |
| --- | --- |
| 5.0 – 18.2 | Supported upstream |
| 18.3 – 18.7.x | Works; **iOS 18.7.1 verified** on rootless (palera1n) with ElleKit 1.2 |
| 18.8 – 26.0.1 | **Theoretical only** — installs and is expected to work, but untested |

The `Depends` line is `firmware (>= 5.0), firmware (<< 26.0.2)`. If a future iOS release changes the `installd` signature-validation API that AppSync hooks (`MISValidateSignatureAndCopyInfoWithProgress`), the tweak will need real code changes — bumping this ceiling cannot predict that.

The package identifier remains `ai.akemi.appsyncunified` and the version stays in
upstream's numbering (`118.0`), so this build **upgrades** an existing AppSync
Unified installation in place rather than installing alongside it. That is
deliberate: two copies of the dylib hooking `installd` would conflict.

### Why fakesigned apps still needed a fix on iOS 18

AppSync Unified hooks two things:

* `installd`'s `MISValidateSignatureAndCopyInfoWithProgress()` — lets an app **install**
* FrontBoard's `trustStateForApplication:` (returns `8`) — marks it **trusted**

Neither covers the check that actually happens at `exec` time on iOS 18+: AMFI
validates every executable image against the **trust cache** before the process
starts. A fakesigned binary that is not in the trust cache is `SIGKILL`ed
(exit 137, “Killed: 9”) even though it installed fine and FrontBoard reports it
as trusted. There is no crash report, because the process never spawns.

This fork adds `asu-trustcache`, which walks every installed `.app` and adds the
cdhash of every Mach-O it contains — main binary (resolved via
`CFBundleExecutable`), `Frameworks/*.framework`, `PlugIns/*.appex`, and loose
`.dylib`s — to the jailbreak trust cache. It runs from `postinst` and from a
LaunchDaemon (`ai.akemi.asu_trustcache`) at boot and every 30 minutes, so apps
installed *after* AppSync are covered too.

Run it manually at any time:

```sh
asu-trustcache.sh                 # all installed apps
asu-trustcache.sh /path/to/X.app  # one bundle
```

Results are appended to `/var/mobile/Documents/asu-trustcache.log`.

If apps that used to launch suddenly stop, check that log and `launchctl list | grep asu_trustcache`.
A second column of `78` means the daemon failed to start and the cache has gone stale — reload it:

```sh
launchctl unload /var/jb/Library/LaunchDaemons/ai.akemi.asu_trustcache.plist
launchctl load   /var/jb/Library/LaunchDaemons/ai.akemi.asu_trustcache.plist
```

(118.1 and later run the script through `/bin/sh`, which prevents that failure.)

**Limitation:** this only helps binaries whose signature block is otherwise
acceptable — i.e. ad-hoc or distribution-signed dumps. An app whose main binary
still carries the App Store DRM chain
(`Authority=Apple iPhone OS Application Signing`) is rejected by AMFI
independently of the trust cache and must be properly re-signed with a real
certificate. Adding its cdhash will not help.

---

## How do I install AppSyncraised on my jailbroken iOS device?

Upstream AppSync Unified is distributed via **Karen/あけみ's Repo: https://cydia.akemi.ai/** ([Tap here on your device to automatically add the repo!](https://cydia.akemi.ai/add.php)) — however, that build still caps installation at iOS 18.2.

This fork is **not** published to any APT repo. To install it on iOS > 18.2, build the `.deb` yourself (see [How do I build AppSyncraised?](#how-do-i-build-appsyncraised)) and install it with `dpkg -i`, or with a file manager such as Filza that can run `dpkg` as root.

If your package manager already shows AppSync Unified, it just means you have a repository added that hosts a copy under the same package ID.

**_Please_ only ever install builds you have built yourself or obtained from a source you trust.** Third-party modified versions from random repositories can and _have_ broken various users' iOS installations in the past.

By installing third-party modified versions of _any system tweak_ like AppSync Unified, you are putting the security and stability of your iOS device and your personal data at risk.

---

## Help! I installed AppSync Unified, but it doesn't seem to be working after I resprung from Cydia/Zebra/Sileo/etc.!

If AppSync Unified is not working after installation, please reboot your device or perform a userspace reboot (`launchctl reboot userspace`, `ldrestart`, etc.) to activate it. You will only need to do this ONCE.

This issue appears to be caused by what …seems like a Cydia Substrate/Substitute bug(?) that's resurfaced from years ago, and occurs _really_ rarely, so it's an absolute nightmare of a bug.

**For the curious developers among you:** AppSync Unified's `postinst` binary (see [pkg-actions.m](pkg-actions/pkg-actions.m)) restarts `installd` via `launchctl` — for some reason though, it seems like Cydia Substrate and/or Substitute doesn't always inject the dylib properly into `installd` when it is reloaded via `launchctl` in this way.

I tried _really_ hard to determine the cause of this, but I really have no idea what could be causing this. The dylib has _long_ since been written to the filesystem by the time `postinst` was _executed_, let alone when `launchctl` was even called by `posix_spawn`.

I guess for now, all I can do is inform people about the bug and how to resolve it.

Hopefully this can be properly resolved upstream in time.

---

## Regarding piracy…

**Please do NOT use AppSync Unified for piracy.**

AppSync Unified is a development tool designed for app developers first and foremost, alongside other valid legal uses.

**Software piracy is illegal.** Please support the developers of the iOS software you use, whether they be app developers on the App Store or tweak developers on Chariz/Dynastic/etc.

They're just trying to make a living too, much like you and I.

---

## How do I build AppSyncraised?

First, make sure you have [Theos](https://github.com/theos/theos) installed. If you don't, [please refer to the official documentation](https://theos.dev/docs/installation) on how to set up Theos on your operating system of choice.

Once you've confirmed that you have Theos installed, open up Terminal and run the following commands:

```shell
git clone https://github.com/O-Kami0/AppSyncraised.git
cd AppSyncraised/
make package THEOS_PACKAGE_SCHEME=rootless
```

And you should have a freshly built *.deb package file.

The `THEOS_PACKAGE_SCHEME=rootless` argument produces an `iphoneos-arm64`
package for rootless jailbreaks (Dopamine, palera1n, etc.). For a "rootful"
package, omit it — but note only the rootless variant has been tested by this
fork's maintainer. See [`contrib/README.md`](contrib/README.md) for the
rootless-specific `Depends` caveat.

---

## Do I need to do anything in order to use Xcode with AppSyncraised?

No, not unless you're using Xcode 6 or below.

As long as you're using a … _reasonably_ modern version of Xcode (7 or above, really), just use Xcode with your iOS device as you would normally!

That being said, if for some reason you _are_ using Xcode 6 or below, please follow this old tutorial written back in 2014: [Tutorial: How to use AppSync Unified for development with Xcode 6 or below](https://akemi.ai/?page/how2asu)

---

## I'm a developer — do you have a rough high-level explanation as to how this all works?

As of AppSync Unified 90.0, ASU is split into two separate dynamic libraries — `AppSyncUnified-installd` and `AppSyncUnified-FrontBoard`.

### `AppSyncUnified-installd`

`AppSyncUnified-installd` injects into — you guessed it — `installd`, which is where the vast majority of ASU's functionality resides in.

AppSync Unified utilises Cydia Substrate's dynamic hooking function `MSHookFunction()` (which is also shimmed appropriately for systems that use Substitute as their code injection platform instead) to bypass `installd`'s signature checks. For iOS 13 and below, the main function being modified is `MISValidateSignatureAndCopyInfo()`, while on iOS 14 and above, it is `MISValidateSignatureAndCopyInfoWithProgress()`.

Using `MSFindSymbol()`, AppSync Unified determines which function is present on the system it's currently running on and appropriately hooks the correct one.

When iOS makes a request to install an app, one of the two functions mentioned above will be called, and AppSync Unified's injected `ASU_MISValidateSignatureAndCopyInfo()` function will take over.

If the app in question has valid signing information, AppSync Unified will not make any modifications to it, and simply pass the information along to the original Apple-implemented function, letting the app installation process carry on as if the system was not modified at all.

On the other hand, if the app contains invalid signing information, AppSync Unified will generate the appropriate signing information required and pass it along to the system. As of AppSync Unified 90.0, this process also includes code directory hash value (`cdhash`) computation.

AppSync Unified also hooks two other functions — `SecCertificateCreateWithData()` and `SecCertificateCopySubjectSummary()`. The modifications work in pretty much the same way as above — if the original certificate is valid, don't touch anything at all. If it isn't valid, then just… present a valid certificate to iOS.

### `AppSyncUnified-FrontBoard`

AppSync Unified 90.0 introduced a second dynamic library that injects into the `FrontBoard` and `FrontBoardServices` private frameworks. This is done in order to bypass a set of signature verifications that are performed at app runtime, generally used for timed app expirations.

That being said, the modifications are actually… incredibly simple.

On iOS 9.3.x to iOS 13, AppSync Unified hooks the Objective-C methods `-(NSUInteger) trustStateWithTrustRequiredReasons:(NSUInteger *)reasons` and `-(NSUInteger) trustState` found in the class `FBApplicationTrustData`, and forces both methods to always return the value used to signal to iOS that the app that the user is attempting to launch is valid and trusted.

On iOS 14 and above, it's… basically the same thing, but targetting a different method — `-(NSUInteger) trustStateForApplication:(id)application` found in the class `FBSSignatureValidationService` — since Apple moved the relevant functionality from `FrontBoard` to `FrontBoardServices`.

…

And that's about it! This explanation is obviously _incredibly_ simplified (the best explanation is just to read the code!), but hopefully it gives you a grasp on how everything works. c:

---

## License

Licensed under [GPLv3](http://www.gnu.org/copyleft/gpl.html).

AppSync Unified is Copyright (C) Karen/あけみ and contributors, and is
distributed under the GPLv3. This fork is derived from
[upstream AppSync](https://github.com/akemin-dayo/AppSync) and remains under the
same licence. The upstream author does not maintain or endorse this fork;
please do not report fork-specific problems upstream.

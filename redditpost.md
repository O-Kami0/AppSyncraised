### Repository: https://github.com/O-Kami0/AppSyncraised

**AppSyncraised is an unofficial fork.** It is not published to any APT repo and is
not affiliated with, maintained by, or endorsed by the original author. For
upstream AppSync Unified (which still caps at iOS 18.2), see Karen/あけみ's Repo:
https://cydia.akemi.ai/

If you find AppSync Unified useful, the original author accepts support via
[Patreon](https://patreon.com/akemin_dayo), [PayPal (`karen@akemi.ai`)](https://paypal.me/akemindayo),
or [Cryptocurrency](https://akemi.ai/?page/links#crypto) — that is upstream's, not this fork's.

---

# Changelog for 118.0 (AppSyncraised)

* This is a fork: only package metadata changed, no code or dylib behaviour.
* Raised the supported firmware ceiling from iOS 18.2 to iOS 26.0.1. Support for iOS 18.3 through 26.0.1 is **theoretical** — the injection logic is unchanged and no iOS 19+ specific signature-check API changes are currently known, but those versions have not been verified.
* iOS 18.7.1 is **tested and confirmed working** (rootless, palera1n).
* Fixed the ElleKit conflict version syntax (`ellekit (< 1.1)` -> `ellekit (<< 1.1)`) so it is actually enforced by dpkg.
* No changes were made to AppSync Unified's functionality or code — this release only relaxes the package metadata that previously blocked installation on newer firmware.

---

# Unified AppSync dynamic library for iOS 5 through iOS 18 (verified on iOS 18.7.x, metadata permits up to iOS 26.0.1). Fork maintained at [https://github.com/O-Kami0/AppSyncraised](https://github.com/O-Kami0/AppSyncraised)!

AppSync Unified is a tweak that allows users to freely install ad-hoc signed, fakesigned, or unsigned IPA app packages on their iOS devices that iOS would otherwise consider invalid.

Some popular use cases include:

* Installing freely-distributed apps that are unavailable from the App Store without having to re-sign the apps in question every 7 days (if the user does not have a subscription to the Apple Developer Program)
* Assisting in the development of iOS applications with Xcode
* Cloning or downgrading already-installed apps

---

# Help! I installed AppSync Unified, but it doesn't seem to be working after I resprung from Cydia/Zebra/Sileo/etc.!

If AppSync Unified is not working after installation, please reboot your device or perform a userspace reboot (`launchctl reboot userspace`, `ldrestart`, etc.) to activate it. You will only need to do this ONCE.

This issue appears to be caused by what …seems like a Cydia Substrate/Substitute bug(?) that's resurfaced from years ago, and occurs _really_ rarely, so it's an absolute nightmare of a bug.

**For the curious developers among you:** AppSync Unified's `postinst` binary (see [pkg-actions.m](pkg-actions/pkg-actions.m)) restarts `installd` via `launchctl` — for some reason though, it seems like Cydia Substrate and/or Substitute doesn't always inject the dylib properly into `installd` when it is reloaded via `launchctl` in this way.

I tried _really_ hard to determine the cause of this, but I really have no idea what could be causing this. The dylib has _long_ since been written to the filesystem by the time `postinst` was _executed_, let alone when `launchctl` was even called by `posix_spawn`.

I guess for now, all I can do is inform people about the bug and how to resolve it.

Hopefully this can be properly resolved upstream in time.

---

# Regarding piracy…

**Please do NOT use AppSync Unified for piracy.**

AppSync Unified is a development tool designed for app developers first and foremost, alongside other valid legal uses.

**Software piracy is illegal.** Please support the developers of the iOS software you use, whether they be app developers on the App Store or tweak developers on Chariz/Dynastic/etc.

They're just trying to make a living too, much like you and I.

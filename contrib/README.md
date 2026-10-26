# Building a rootless (iphoneos-arm64) package with the raised ceiling

Upstream ships a single `control` file declaring `Architecture: iphoneos-arm`
for both rootful and rootless builds — Theos rewrites the architecture for
rootless packages, but it does **not** rewrite `Depends`.

This means the stock `control` also carries `firmware (>= 5.0)`, which is wrong
for a rootless package and, per
[upstream issue #239](https://github.com/akemin-dayo/AppSync/issues/239), causes
installation failures in some frontends on older 64-bit devices.

`control.rootless` is the rootless variant:

* `Architecture: iphoneos-arm64`
* `Depends: firmware (>= 15.0), ...` (no rootless jailbreak predates iOS 15)
* `firmware (<< 26.0.2)` ceiling

## Usage

```sh
# from the repository root, on a machine with Theos installed
cp contrib/control.rootless control
make package THEOS_PACKAGE_SCHEME=rootless
```

Or equivalently, set `THEOS_PACKAGE_SCHEME=rootless` and let Theos handle the
architecture, then only rewrite the `Depends` line:

```sh
make package THEOS_PACKAGE_SCHEME=rootless \
  THEOS_PACKAGE_ARCH=iphoneos-arm64
```

## Verifying the produced package

```sh
dpkg-deb -f debs/*.deb Package Version Architecture Depends Conflicts
```

Expect:

```
Package: ai.akemi.appsyncunified
Version: 118.0
Architecture: iphoneos-arm64
Depends: firmware (>= 15.0), mobilesubstrate (>= 0.9.5100), firmware (<< 26.0.2)
```

## Notes

* `contrib/control.rootless` is a build input, not part of the shipped tree.
  The canonical metadata file remains `control` at the repo root.
* If Theos' `THEOS_PACKAGE_SCHEME=rootless` support is in use, it will reject
  `Architecture: iphoneos-arm` mismatches — keep the two files in sync when
  bumping the version.

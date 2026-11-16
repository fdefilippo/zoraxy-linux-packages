# Build .deb and .rpm packages of Zoraxy from the official release binaries.
#
#   make packages            # .deb and .rpm for ARCH
#   make deb | rpm           # one format only
#   make all-arch            # .deb and .rpm for every supported architecture
#   make windows             # Windows x64 setup (.exe, NSIS + WinSW service)
#   make clean
#
# Variables:
#   VERSION     Zoraxy version without "v" (default: latest stable release)
#   ARCH        amd64 arm64 arm 386 riscv64 (default: host architecture)
#   RELEASE     package revision (default: 1)
#   BINARY      package this binary instead of downloading the release asset
#   MAINTAINER  maintainer/packager field
#
# Requirements: curl, python3, sha256sum; dpkg-deb for .deb, rpmbuild for .rpm,
# makensis for the Windows setup.
# Output: dist/

ARCHES     := amd64 arm64 arm 386 riscv64
HOST_ARCH  := $(shell uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/' -e 's/armv[67]l/arm/' -e 's/i[3-6]86/386/')

ARCH       ?= $(HOST_ARCH)
RELEASE    ?= 1
MAINTAINER ?= Defilippo srl <info@defilippo.org>
ifeq ($(VERSION),)
VERSION    := $(shell ./scripts/upstream.sh latest)
endif

OUT        := dist
BUILD      := build/$(VERSION)/$(ARCH)
BINARY     ?= $(BUILD)/zoraxy

DEB_ARCH_amd64   := amd64
DEB_ARCH_arm64   := arm64
DEB_ARCH_arm     := armhf
DEB_ARCH_386     := i386
DEB_ARCH_riscv64 := riscv64
RPM_ARCH_amd64   := x86_64
RPM_ARCH_arm64   := aarch64
RPM_ARCH_arm     := armv7hl
RPM_ARCH_386     := i686
RPM_ARCH_riscv64 := riscv64

# Windows service wrapper (https://github.com/winsw/winsw), pinned by SHA-256
WINSW_VERSION := 2.12.0
WINSW_SHA256  := b5066b7bbdfba1293e5d15cda3caaea88fbeab35bd5b38c41c913d492aadfc4f
WIN_BUILD     := build/$(VERSION)/windows
# x.x.x.x version for the setup metadata (pre-release suffix dropped)
VI_VERSION    := $(firstword $(subst -, ,$(VERSION))).$(RELEASE)

DEB_ARCH   := $(DEB_ARCH_$(ARCH))
RPM_ARCH   := $(RPM_ARCH_$(ARCH))
# "-" is not allowed in RPM versions; "~" sorts pre-releases (3.4.0~rc1) before the release
PKG_VERSION := $(subst -,~,$(VERSION))

.PHONY: packages deb rpm all-arch windows check check-version clean

packages: deb rpm

all-arch:
	@for a in $(ARCHES); do $(MAKE) --no-print-directory packages ARCH=$$a VERSION=$(VERSION) RELEASE=$(RELEASE) || exit 1; done

check-version:
	@test -n "$(VERSION)" || { echo "cannot find the latest Zoraxy release, set VERSION="; exit 1; }

check: check-version
	@test -n "$(DEB_ARCH)" || { echo "unsupported ARCH '$(ARCH)' ($(ARCHES))"; exit 1; }

$(BUILD)/zoraxy: | check
	./scripts/upstream.sh fetch $(VERSION) $(ARCH) $@

deb: check $(BINARY)
	rm -rf $(BUILD)/deb
	install -D -m 0755 $(BINARY) $(BUILD)/deb/usr/bin/zoraxy
	install -D -m 0644 zoraxy.service $(BUILD)/deb/usr/lib/systemd/system/zoraxy.service
	install -D -m 0644 zoraxy.default $(BUILD)/deb/etc/default/zoraxy
	install -D -m 0644 LICENSE $(BUILD)/deb/usr/share/doc/zoraxy/copyright
	install -d -m 0750 $(BUILD)/deb/var/lib/zoraxy
	install -d $(BUILD)/deb/DEBIAN
	install -m 0755 deb/postinst deb/prerm deb/postrm $(BUILD)/deb/DEBIAN/
	install -m 0644 deb/conffiles $(BUILD)/deb/DEBIAN/
	cd $(BUILD)/deb && find usr -type f -exec md5sum {} + > DEBIAN/md5sums
	size=$$(du -sk --exclude=DEBIAN $(BUILD)/deb | cut -f1); \
	sed -e 's|@VERSION@|$(PKG_VERSION)|' -e 's|@RELEASE@|$(RELEASE)|' -e 's|@ARCH@|$(DEB_ARCH)|' \
	    -e 's|@MAINTAINER@|$(MAINTAINER)|' -e "s|@SIZE@|$$size|" deb/control.in > $(BUILD)/deb/DEBIAN/control
	@mkdir -p $(OUT)
	dpkg-deb --root-owner-group -Zxz --build $(BUILD)/deb $(OUT)/zoraxy_$(PKG_VERSION)-$(RELEASE)_$(DEB_ARCH).deb

rpm: check $(BINARY)
	rm -rf $(BUILD)/rpm
	install -D -m 0755 $(BINARY) $(BUILD)/rpm/SOURCES/zoraxy
	install -m 0644 zoraxy.service zoraxy.default LICENSE $(BUILD)/rpm/SOURCES/
	rpmbuild -bb --target $(RPM_ARCH) \
		--define "_topdir $(abspath $(BUILD)/rpm)" \
		--define "zoraxy_version $(PKG_VERSION)" \
		--define "zoraxy_release $(RELEASE)" \
		--define "packager $(MAINTAINER)" \
		rpm/zoraxy.spec
	@mkdir -p $(OUT)
	cp $(BUILD)/rpm/RPMS/*/zoraxy-*.rpm $(OUT)/

$(WIN_BUILD)/zoraxy.exe: | check-version
	./scripts/upstream.sh fetch $(VERSION) windows_amd64 $@

$(WIN_BUILD)/zoraxy-service.exe:
	@mkdir -p $(WIN_BUILD)
	curl -fsSL --retry 3 -o $@.part https://github.com/winsw/winsw/releases/download/v$(WINSW_VERSION)/WinSW.NET461.exe
	echo "$(WINSW_SHA256)  $@.part" | sha256sum -c --quiet -
	mv $@.part $@

windows: check-version $(WIN_BUILD)/zoraxy.exe $(WIN_BUILD)/zoraxy-service.exe
	sed 's/$$/\r/' windows/zoraxy-service.xml > $(WIN_BUILD)/zoraxy-service.xml
	sed 's/$$/\r/' LICENSE > $(WIN_BUILD)/LICENSE.txt
	@mkdir -p $(OUT)
	makensis -V2 -DVERSION=$(VERSION) -DRELEASE=$(RELEASE) -DVI_VERSION=$(VI_VERSION) \
		-DSRCDIR=$(abspath $(WIN_BUILD)) \
		-DOUTFILE=$(abspath $(OUT))/zoraxy-$(VERSION)-$(RELEASE)-windows-amd64-setup.exe \
		windows/zoraxy.nsi

clean:
	rm -rf build $(OUT)

Name:           el-containerd
Version:        %{CONTAINERD_VERSION}+%{RUNC_VERSION}
Release:        1%{?dist}
Summary:        containerd runtime + runc + nerdctl for arch %{TOOLCHAIN_ARCH}%{?dist}
License:        Apache-2.0
URL:            https://containerd.io

# Each binary as its own source
Source0:        containerd
Source1:        containerd-shim-runc-v2
Source2:        containerd.service
Source3:        ctr
Source4:        runc
Source5:        nerdctl

BuildArch:      %{TOOLCHAIN_ARCH}
BuildRequires: systemd-rpm-macros
Requires(post): systemd
Requires(preun): systemd
Requires(postun): systemd

Provides:       containerd.io

%description
containerd %{CONTAINERD_VERSION} runc %{RUNC_VERSION} nerdctl %{NERDCTL_VERSION} for %{TOOLCHAIN_ARCH}%{?dist}

%prep
# Nothing.

%build
# Builds are done externally; this rpm only packages the pre-built binaries.

%install
# Main binaries
install -D -m 0755 %{SOURCE0} %{buildroot}/usr/bin/containerd
install -D -m 0755 %{SOURCE1} %{buildroot}/usr/bin/containerd-shim-runc-v2
install -D -m 0755 %{SOURCE3} %{buildroot}/usr/bin/ctr
install -D -m 0755 %{SOURCE4} %{buildroot}/usr/bin/runc
install -D -m 0755 %{SOURCE5} %{buildroot}/usr/bin/nerdctl

# systemd unit
install -D -m 0644 %{SOURCE2} %{buildroot}/usr/lib/systemd/system/containerd.service

%post
set -x
%systemd_post containerd.service

%preun
set -x
%systemd_preun containerd.service

%postun
set -x
%systemd_postun containerd.service

%files
/usr/bin/containerd
/usr/bin/containerd-shim-runc-v2
/usr/lib/systemd/system/containerd.service
/usr/bin/ctr
/usr/bin/runc
/usr/bin/nerdctl

%changelog
* Mon Jul 14 2025 Your Name <you@example.com> - %{CONTAINERD_VERSION}+%{RUNC_VERSION}-1
- containerd %{CONTAINERD_VERSION} and runc %{RUNC_VERSION} and nerdctl %{NERDCTL_VERSION}
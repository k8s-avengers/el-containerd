ARG BASE_IMAGE="rockylinux/rockylinux:9"
FROM ${BASE_IMAGE} AS build

ARG OS_ARCH="arm64"
ARG TOOLCHAIN_ARCH="aarch64"
ARG GOLANG_VERSION="1.24.5"

ARG RUNC_VERSION="v1.3.0"
ARG CONTAINERD_VERSION="v2.1.3"
ARG NERDCTL_VERSION="v2.1.3"


# runc cgo-links libseccomp-devel directly
# gcc is thus required to build runc
RUN dnf -y update && \
    dnf -y install tree git bash wget make gcc rpm-build rpmdevtools libseccomp-devel

SHELL ["/bin/bash", "-e", "-c"]

RUN wget --progress=dot:giga -O "/tmp/go.tgz" https://go.dev/dl/go${GOLANG_VERSION}.linux-${OS_ARCH}.tar.gz
RUN rm -rf /usr/local/go && tar -C /usr/local -xzf /tmp/go.tgz && rm -f /tmp/go.tgz
RUN ln -s /usr/local/go/bin/go /usr/local/bin/go
RUN go version

# Build runc from source; it defaults to having symbols
FROM build AS runc
WORKDIR /src
ARG RUNC_VERSION
RUN git -c advice.detachedHead=false clone --depth=1  --single-branch --branch=${RUNC_VERSION} https://github.com/opencontainers/runc /src/runc
WORKDIR /src/runc
RUN make

# Build containerd from source; enable GODEBUG so it has symbols
FROM build AS containerd
WORKDIR /src
ARG CONTAINERD_VERSION
RUN git -c advice.detachedHead=false clone --depth=1  --single-branch --branch=${CONTAINERD_VERSION} https://github.com/containerd/containerd /src/containerd
WORKDIR /src/containerd
RUN BUILDTAGS=no_btrfs GODEBUG=yes make

# Build nerdctl from source; it defaults to having symbols
FROM build AS nerdctl
WORKDIR /src
ARG NERDCTL_VERSION
RUN git -c advice.detachedHead=false clone --depth=1  --single-branch --branch=${NERDCTL_VERSION} https://github.com/containerd/nerdctl /src/nerdctl
WORKDIR /src/nerdctl
RUN make

# Prepare the results in /out
FROM build AS packager

WORKDIR /out/usr/bin
COPY --from=runc /src/runc/runc .
COPY --from=containerd /src/containerd/bin/* .
COPY --from=nerdctl /src/nerdctl/_output/nerdctl .

# Lets check the binaries for stripedness
RUN file /out/usr/bin/runc
RUN file /out/usr/bin/containerd

# Make sure they run and list their versions
RUN /out/usr/bin/runc --version
RUN /out/usr/bin/containerd --version
RUN /out/usr/bin/nerdctl --version

# Show against what they are linked, if not static (only nerdctl is static / cgo-free)
RUN ldd  /out/usr/bin/runc
RUN ldd  /out/usr/bin/containerd
# static RUN ldd /out/usr/bin/nerdctl # static

WORKDIR /pkg
RUN rpmdev-setuptree
RUN tree /root/rpmbuild

# copy the binaries to the rpmbuild SOURCES directory
RUN cp -prv /out/usr/bin/* /root/rpmbuild/SOURCES/

# add the spec file for the rpm package
COPY rpm/el-containerd.spec /root/rpmbuild/SPECS/el-containerd.spec
# add the systemd service file for containerd
COPY rpm/containerd.service /root/rpmbuild/SOURCES/containerd.service

RUN tree /root/rpmbuild

# build the rpm package
ARG RUNC_VERSION
ARG CONTAINERD_VERSION
ARG NERDCTL_VERSION
ARG TOOLCHAIN_ARCH

RUN rpmbuild -bb /root/rpmbuild/SPECS/el-containerd.spec --define "_topdir /root/rpmbuild" --define "OS_ARCH ${OS_ARCH}" --define "CONTAINERD_VERSION ${CONTAINERD_VERSION}" --define "NERDCTL_VERSION ${NERDCTL_VERSION}" --define "RUNC_VERSION ${RUNC_VERSION}" --define "TOOLCHAIN_ARCH ${TOOLCHAIN_ARCH}"
RUN tree /root/rpmbuild

# Show metadata of the built rpm package
RUN rpm -qip /root/rpmbuild/RPMS/*/*.rpm
RUN rpm -qlp /root/rpmbuild/RPMS/*/*.rpm
RUN rpm -qRp /root/rpmbuild/RPMS/*/*.rpm
RUN rpm -q --provides -p /root/rpmbuild/RPMS/*/*.rpm

# Now prepare the real output: a tarball of /out, and the rpm package
WORKDIR /artifacts
RUN cp -v /root/rpmbuild/RPMS/*/*.rpm /artifacts/
WORKDIR /out
RUN tar czvf /artifacts/el-containerd_${OS_ARCH}_$(cat /etc/os-release | grep "^PLATFORM_ID" | cut -d "\"" -f 2 | cut -d ":" -f 2).tar.gz *

# Final stage is just alpine so we can start a fake container just to get at its contents using docker in GHA
FROM alpine:3
COPY --from=packager /artifacts/* /out/


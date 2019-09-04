#!/bin/bash
#
# Copyright (c) 2019 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o nounset
set -o pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${script_dir}/../../scripts/lib.sh"
source "${script_dir}/../qemu.blacklist"

packaging_dir="${script_dir}/../.."
qemu_tar="kata-qemu-static.tar.gz"
qemu_tmp_tar="kata-qemu-static-tmp.tar.gz"

qemu_repo="${qemu_repo:-}"
qemu_version="${qemu_version:-}"

if [ -z "$qemu_repo" ]; then
	info "Get qemu information from runtime versions.yaml"
	qemu_url=$(get_from_kata_deps "assets.hypervisor.qemu.url")
fi
[ -n "$qemu_repo" ] || die "failed to get qemu repo"

[ -n "$qemu_version" ] || qemu_version=$(get_from_kata_deps "assets.hypervisor.qemu.version")
if ! (git ls-remote --heads "${qemu_url}" | grep -q "refs/heads/${qemu_version}"); then
	qemu_version=$(get_from_kata_deps "assets.hypervisor.qemu.tag")
fi
[ -n "$qemu_version" ] || die "failed to get qemu version"

qemu_virtiofsd_binary="virtiofsd-x86_64"
qemu_virtiofsd_release="https://gitlab.com/virtio-fs/qemu/-/tags/virtio-fs-v0.3"

info "Build ${qemu_repo} version: ${qemu_version}"

http_proxy="${http_proxy:-}"
https_proxy="${https_proxy:-}"
prefix="${prefix:-"/opt/kata"}"

sudo docker build \
	--no-cache \
	--build-arg http_proxy="${http_proxy}" \
	--build-arg https_proxy="${https_proxy}" \
	--build-arg QEMU_REPO="${qemu_repo}" \
	--build-arg QEMU_VERSION="${qemu_version}" \
	--build-arg PREFIX="${prefix}" \
	--build-arg VIRTIOFSD_RELEASE="${qemu_virtiofsd_release}" \
	--build-arg VIRTIOFSD="${qemu_virtiofsd_binary}" \
	"${packaging_dir}" \
	-f "${script_dir}/Dockerfile" \
	-t qemu-static

sudo docker run \
	-i \
	-v "${PWD}":/share qemu-static \
	mv "/tmp/qemu-static/${qemu_tar}" /share/

sudo chown ${USER}:${USER} "${PWD}/${qemu_tar}"

# Remove blacklisted binaries
gzip -d < "${qemu_tar}" | tar --delete --wildcards -f - ${qemu_black_list[*]} | gzip > "${qemu_tmp_tar}"
mv -f "${qemu_tmp_tar}" "${qemu_tar}"
#!/bin/bash

set -epux -o pipefail

mkdir -p tmp/install
DESTDIR="$(readlink -f "$(pwd)/tmp/install")"

make_refpolicy() {
    make DESTDIR="$DESTDIR" 'SEMODULE=/usr/sbin/semodule -v -p '"$DESTDIR"' -X 100 ' "$@"
}

do_run() {
	local b="$1"; shift

	git checkout "$b"

	make clean

	mkdir -p "$DESTDIR"/var/lib/selinux/targeted
	time make_refpolicy -j$(nproc)
	make_refpolicy -j$(nproc) load validate
	make_refpolicy NAME=devel install-headers

	d=a."$b"."$b_type"-"$b_distro"-"$b_unk"-"$b_di"-"$b_systemd"-"$b_ubac"-"$b_we"
	[ ! -d "$d" ]
	mkdir "$d"

	mv base.fc base.conf *.pp tmp "$d"
}

rnd() {
	local -n arr="$1"
	printf "%s" "${arr[$((( RANDOM % ${#arr[@]} )))]}"
}

a_we=(y n)
a_ubac=(y n)
a_systemd=(y n)
a_di=(y n)
a_unk=(allow deny reject)
a_distro=(redhat gentoo debian suse rhel4)
a_type=(standard mcs mls)

while true; do
	b_we=y
	b_ubac="$(rnd a_ubac)"
	b_systemd="$(rnd a_systemd)"
	b_di="$(rnd a_di)"
	b_unk="$(rnd a_unk)"
	b_distro="$(rnd a_distro)"
	b_type="$(rnd a_type)"

log=log."$b_type"-"$b_distro"-"$b_unk"-"$b_di"-"$b_systemd"-"$b_ubac"-"$b_we"
[ ! -f "$log" ] || continue

(

sed -ri '
s/^[# ]*?(TYPE *=).*/\1 '"$b_type"'/;
s/^[# ]*?(NAME *=).*/\1 targeted/;
s/^[# ]*?(DISTRO *=).*/\1 '"$b_distro"'/;
s/^[# ]*?(UNK_PERMS *=).*/\1 '"$b_unk"'/;
s/^[# ]*?(DIRECT_INITRC *=).*/\1 '"$b_di"'/;
s/^[# ]*?(SYSTEMD *=).*/\1 '"$b_systemd"'/;
s/^[# ]*?(MONOLITHIC *=).*/\1 n/;
s/^[# ]*?(UBAC *=).*/\1 '"$b_ubac"'/;
s/^[# ]*?(WERROR *=).*/\1 '"$b_we"'/;
' build.conf

make_refpolicy bare conf

do_run master
do_run make

diff -ur a.{master,make}."$b_type"-"$b_distro"-"$b_unk"-"$b_di"-"$b_systemd"-"$b_ubac"-"$b_we" || :

) > "$log".tmp 2>&1 && mv "$log".tmp "$log"

hardlink -c a.*

done

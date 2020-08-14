# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

MULTILIB_COMPAT=( abi_x86_{32,64} )

inherit flag-o-matic meson multilib-minimal ninja-utils

DESCRIPTION="A Vulkan-based translation layer for Direct3D 10/11"
HOMEPAGE="https://github.com/doitsujin/dxvk"

if [[ ${PV} == "9999" ]] ; then
	EGIT_REPO_URI="https://github.com/doitsujin/dxvk.git"
	EGIT_BRANCH="master"
	inherit git-r3
	SRC_URI=""
else
	SRC_URI="https://github.com/doitsujin/dxvk/archive/v${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="-* ~amd64"
fi

LICENSE="ZLIB"
SLOT=0
IUSE="custom-cflags dxvk-config video_cards_nvidia"
REQUIRED_USE="|| ( abi_x86_32 abi_x86_64 )"

RESTRICT="test"

RDEPEND="
	|| (
		video_cards_nvidia? ( >=x11-drivers/nvidia-drivers-440.41 )
		>=media-libs/mesa-19.2
	)
	|| (
		>=app-emulation/wine-vanilla-4.5:*[${MULTILIB_USEDEP},vulkan]
		>=app-emulation/wine-staging-4.5:*[${MULTILIB_USEDEP},vulkan]
	)"

DEPEND="${RDEPEND}
	dev-util/glslang
	dev-util/vulkan-headers"

BDEPEND="
	>=dev-util/meson-0.46"

# Convert PV to not doted integer
PVINT=$(echo "${PV//./}")
# Restore winelib builds that were removed after 1.6.1.
PATCHES=()
if [[ "${PV}" == "9999" ]]; then
	# Recent changes to upstream required a patch rebase.
	PATCHES+=("${FILESDIR}/dxvk-restore-winelib-9999.patch")
else
	PATCHES+=("${FILESDIR}/dxvk-restore-winelib.patch")
fi
if [[ "${PVINT}" -gt "161" ]]; then
	PATCHES+=(
		"${FILESDIR}/dxvk-restore-spec-files.patch"
		"${FILESDIR}/dxvk-revert-remove-vulkanfn.patch"
	)
fi

if [[ ${PV} != "9999" ]] ; then
	S="${WORKDIR}/dxvk-${PV}"
fi

bits() {
	[[ ${ABI} = "amd64" ]] && echo 64
	[[ ${ABI} = "x86" ]]   && echo 32
}

src_prepare() {
	if use dxvk-config; then
		PATCHES+=(
			"${FILESDIR}/add-dxvk_config-winelib-library.patch"
			"${FILESDIR}/add-dxvk_config-to-setup.patch"
		)
	fi
	if use custom-cflags; then
		PATCHES+=("${FILESDIR}/flags-winelib.patch")
	fi

	# From bobwya's dxvk ebuild.
	filter-flags "-Wl,--hash-style*"
	[[ "$(is-flag "-march=*")" == "true" ]] && append-flags "-mno-avx"

	replace-flags "-O3" "-O3 -fno-stack-protector"

	default

	# Rename final setup script in README.md
	sed -i -e "s|./setup_dxvk.sh|${PV}-setup|g" "${S}/README.md" \
		|| die "sed failed"
	sed -i -e "s#basedir=.*#basedir=\"${EPREFIX}/usr\"#" "${S}/setup_dxvk.sh" \
		|| die "sed failed"

	# From bobwya's dxvk ebuild.
	# Delete installation instructions for unused ABIs.
	if use abi_x86_32; then
		sed -i '\|installFile "$win32_sys_path"|d' "${S}/setup_dxvk.sh" \
			|| die "sed failed"
	fi
	if use abi_x86_64; then
		sed -i '\|installFile "$win64_sys_path"|d' "${S}/setup_dxvk.sh" \
			|| die "sed failed"
	fi

	bootstrap_dxvk() {
		# Set DXVK location for each ABI
		sed -e "s#x$(bits)#$(get_libdir)/${PN}#" -i "${S}/setup_dxvk.sh" \
			|| die "sed failed"

		# Add *FLAGS to cross-file
		sed -i \
			-e "s!@CFLAGS@!$(_meson_env_array "${CFLAGS}" -fpermissive)!" \
			-e "s!@CXXFLAGS@!$(_meson_env_array "${CXXFLAGS}" -fpermissive)!" \
			-e "s!@LDFLAGS@!$(_meson_env_array "${LDFLAGS}")!" \
			build-wine$(bits).txt \
			|| die "sed failed"
	}

	multilib_foreach_abi bootstrap_dxvk
}

multilib_src_configure() {
	local emesonargs=(
		--cross-file="${S}/build-wine$(bits).txt"
		--libdir="$(get_libdir)/${PN}"
		--bindir="$(get_libdir)/${PN}/bin"
		-Denable_tests=false
	)
	meson_src_configure
}

multilib_src_install() {
	meson_src_install
}

multilib_src_install_all() {
	newbin "setup_dxvk.sh" "${PN}-setup"

	dodoc "${S}/dxvk.conf"

	einstalldocs
}

pkg_postinst() {
	ewarn ""
	ewarn "This is the winelib version of dxvk."
	ewarn "As of versions greater than 1.6.1 winelib has been completely"
	ewarn "removed from upstream, and is no longer supported."
	ewarn ""
	ewarn "This ebuild restores winelib builds after 1.6.1."
	ewarn "So, if you run into any build related problems"
	ewarn "DO NOT REPORT THEM TO UPSTREAM."
	ewarn ""
	ewarn "You may report winelib build issues to my gentoo overlay at:"
	ewarn "<https://gitlab.com/TheGreatMcPain/thegreatmcpain-overlay>"
	ewarn ""
	elog ""
	elog "dxvk installed, but not activated. You have to install the DLLs to a WINEPREFIX."
	elog "To do this you just need to set WINEPREFIX: $ export WINEPREFIX=/path/to/prefix"
	elog "then run: $ ${PN}-setup install --symlink"
	elog ""
}

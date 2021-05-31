# Copyright 2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

PYTHON_COMPAT=( python3_8 )
inherit distutils-r1

DESCRIPTION="fork of ConcurrentLogHandler"
HOMEPAGE="https://github.com/Preston-Landers/concurrent-log-handler"
SRC_URI="
	https://github.com/Preston-Landers/concurrent-log-handler/archive/${PV}.tar.gz -> ${P}.tar.gz
"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64 ~x86"

DEPEND="
	dev-python/portalocker
"
RDEPEND="${DEPEND}"
BDEPEND=""
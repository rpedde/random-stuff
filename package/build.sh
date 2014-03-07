#!/bin/bash

PKGROOT=/srv/packages
#DISTRELEASES=${DISTRELEASES-ubuntu-maverick ubuntu-natty ubuntu-oneiric debian-squeeze debian-wheezy ubuntu-precise}
DISTRELEASES=${DISTRELEASES-ubuntu-oneiric debian-squeeze debian-wheezy ubuntu-precise}
PBUILDER_DIST=wheezy
SBUILDER_NAME=sbuilder

if [ "$1" != "" ]; then
    BUILDPKG=$1
else
    exit "Must specify package (dir) to build"
fi

# No user servicable parts below here
function log() {
    echo -e "$@" >&3
}

function do_exit() {
    if [ ${status} != 0 ]; then
	log "Last logs... /tmp/out.log for more\n\n"
	tail -n20 /tmp/out.log >&3
    fi
    trap - EXIT
    exit ${status}
}

set -e

exec 3>&1
exec >/tmp/out.log
exec 2>&1

set -x

trap 'prev=$this; this=$BASH_COMMAND' DEBUG
trap 'status=$?;echo -e "ERROR: exit $status due to $prev\n" >&3;do_exit' EXIT

# No user servicable parts below this mark

if [ ! -d ${BUILDPKG} ]; then
    if [ -d ${BUILDPKG}-buildpkg ]; then
	BUILDPKG=${BUILDPKG}-buildpkg
    else
	log "Must specify a valid package to build"
	do_exit
    fi
fi

PKG_BASE=$BUILDPKG
if [[ $BUILDPKG =~ -buildpkg ]]; then
    PKG_BASE=${BUILDPKG%-*}
fi

log "Building source for \"$BUILDPKG\" (base package: \"${PKG_BASE}\")"

rm -f ${PKG_BASE}_*

rm -rf sources
mkdir sources

# build a source package first.
pushd ${BUILDPKG}

# git reset --hard
# git clean -df

if [ -e .control ]; then
    source .control
fi

if ! (schroot --list --all-sessions | grep -q ${SBUILDER_NAME}); then
    schroot -c ${PBUILDER_DIST} -n ${SBUILDER_NAME} -b
fi

schroot -c ${SBUILDER_NAME} -r -u root -- apt-get update
schroot -c ${SBUILDER_NAME} -r -u root -- apt-get install git-buildpackage -y
schroot -c ${SBUILDER_NAME} -r -u root -- /usr/lib/pbuilder/pbuilder-satisfydepends
if [ ! -d .git ]; then
    schroot -c ${SBUILDER_NAME} -r -- dpkg-buildpackage -us -uc -tc -S
else
    schroot -c ${SBUILDER_NAME} -r -- git-buildpackage --git-pristine-tar -us -uc -tc -S --git-ignore-new --git-ignore-branch --git-force-create
fi

schroot -c ${SBUILDER_NAME} -e

popd

log "Source built."

mkdir -p sources

# drop all source files in "sources"
mv ${PKG_BASE}_* sources

pushd sources

# Walk through each distro and build the packages.
for distrelease in ${DISTRELEASES}; do
    distro=${distrelease%%-*}
    release=${distrelease##*-}

    dsc=$(ls *dsc)

    mkdir -p ${distro}/${release}
    pushd ${distro}/${release}

    log "Building ${BUILDPKG} for ${distro}-${release}"
    # -k key
    DEB_BUILD_OPTIONS="nodocs nocheck" sbuild \
	-n -A -d ${release} \
	--append-to-version=~${release} \
	-m "Ron Pedde <ron@pedde.com>" \
        -c ${release} ../../${dsc}
    log "  - Built"

    popd
done

log "Importing packages"

distros=$(find . -maxdepth 1 -type d ! -name ".*")
for distro in $distros; do
    distro=$(basename ${distro})
    source_packages=$(find . -name "*dsc")
    for pkg in $source_packages; do
	base_pkg=$(basename ${pkg})
	root_pkg=${base_pkg%%_*}
	releases=$(find ${distro}/* -maxdepth 1 -type d ! -name ".*")

	for release in $releases; do
	    release=$(basename ${release})
	    reprepro -b /srv/packages/${distro} remove ${release} ${root_pkg}
	done

	for release in $releases; do
	    release=$(basename ${release})
	    result=OK
	    if ( ! reprepro -b /srv/packages/${distro} -C main includedsc ${release} ${base_pkg}); then
		result=FAIL
	    fi
	    log "   - source: ${base_pkg} in ${release}: $result"

	    binary_packages=$(find ${distro}/${release} -name "*deb")
	    for binary_package in ${binary_packages}; do
		base_pkg=$(basename ${binary_package})
		root_pkg=${base_pkg%%_*}

		echo "base_pkg: ${base_pkg}, root_pkg: ${root_pkg}"

		if (! reprepro -b /srv/packages/${distro} -C main includedeb ${release} ${binary_package}); then
		    reprepro -b /srv/packages/${distro} remove ${release} ${root_pkg}
		    reprepro -b /srv/packages/${distro} -C main includedeb ${release} ${binary_package}
		fi

		log "   - binary: $(basename ${binary_package})"
	    done
	done
    done
done

popd

trap - EXIT

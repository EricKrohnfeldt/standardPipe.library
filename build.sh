#!/bin/bash

#
# This file is part of herbmarshall.com: standardPipe.library  ( hereinafter "standardPipe.library" ).
#
# standardPipe.library is free software: you can redistribute it and/or modify it under the terms of
# the GNU General Public License as published by the Free Software Foundation, either version 2 of the License,
# or (at your option) any later version.
#
# standardPipe.library is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with standardPipe.library.
# If not, see <https://www.gnu.org/licenses/>.
#

set -e

# Using non-cdlocal because may be ran by jenkins
cd "$( dirname "$( realpath "$( readlink -f "$0" )" )" )"

OPERATION='build'
DEST=
BUILD_DIR=$( pwd )
SKIP_CHECKS=
SKIP_TESTS=

printUsage() {
	echo 'Options:'
	echo -e "\t--docs          Run build javadoc operation"
	echo -e "\t-c --noChecks   Ignore run checkstyle"
	echo -e "\t-t --noTests    Dont run unit tests ( or coverage )"
	echo -e "\t-x              Both --noChecks and --noTests"
}

while test $# -gt 0
do
	case "$1" in
		?|-\?)
			printUsage
			exit 1
		;;
		--docs)
			OPERATION='docs'
		;;
		-c|--noChecks)
			SKIP_CHECKS='-Dcheckstyle.skip=true'
		;;
		-t|--noTests)
			SKIP_TESTS='-Dmaven.test.skip.exec'
		;;
		-x)
			SKIP_CHECKS='-Dcheckstyle.skip=true'
			SKIP_TESTS='-Dmaven.test.skip.exec'
		;;
		*)
			DEST="$1"
		;;
	esac
	shift
done


if [[ "build" == "${OPERATION}" ]]; then

	# Because maven.herb uses jenkins user instead of root
	WORK_DIR="/home/jenkins/workspace"
	M2_DIR="${HOME}/.m2"

	docker run -it --rm \
		-v "${M2_DIR}":/home/jenkins/.m2 \
		-v "${BUILD_DIR}":"${WORK_DIR}" \
		-w "${WORK_DIR}" \
		docker.herb.herbmarshall.com/maven.herb \
		mvn clean install javadoc:javadoc ${SKIP_CHECKS} ${SKIP_TESTS}

elif [[ "docs" == "${OPERATION}" ]]; then

	if [ -z "${DEST}" ]; then
		echo Destination folder required >&2
		exit 1
	elif [[ "${DEST}" != /* ]]; then
		DEST="${BUILD_DIR}/${DEST}"
	fi

	echo "Base: ${DEST}"

	for DOC_DIR in $( find . | grep -E 'target/site/apidocs$' | xargs realpath ); do
		cd "${DOC_DIR}/../.."
		ARTIFACT=$( find . -name '*.jar' | cut -c 3- | cut --delimiter=- -f1 | tail -n1 )
		VERSION=$( find . -name '*.jar' | cut -c 3- | cut --delimiter=- -f2 | tail -n1 )
		TARGET="${DEST}/${ARTIFACT}/${VERSION}"
		echo
		echo Processing: "${ARTIFACT} [ ${VERSION} ]   ->   ${TARGET}"
		mkdir -p "${DEST}/${ARTIFACT}/${VERSION}"
		cp -r "${DOC_DIR}"/* "${TARGET}"
		echo 'Complete'
		cd "${WORK_DIR}"
	done

fi

#!/bin/bash

_usage_and_exit()
{
	echo "Usage:"
	echo "  $0 <source directory> <target directory> [project name] [project version]"
	echo ""
	echo "Project name and version is optional, default values are \"unnamed\" and \"0.1.0\"."
	echo ""
	echo "Examples:"
	echo "  $0 src dist"
	echo "  $0 src dist test-project 0.9.3"
	exit 1
}

section_start()
{
	local section="$1"
	local message="$2"
	
	if [ "$TRAVIS" == "true" ]; then
		echo -en "travis_fold:start:${section}\\r"
	fi
	
	echo -e "\\e[1;33m${message}\\e[0;39m"
}

section_end()
{
	local section="$1"
	
	if [ "$TRAVIS" == "true" ]; then
		echo -en "travis_fold:end:${section}\\r"
	fi
}


if [ $# -lt 2 ] || [ $# -gt 4 ]; then
	_usage_and_exit
fi

PROG=`readlink -f "$0"`
ROOT_DIR=`dirname "$PROG"`

# override HOME to avoid trashing user's home
export HOME="$ROOT_DIR"
export PATH="$HOME/build/node-v8.9.4-linux-x64/bin:$PATH"

SOURCE_DIR=`readlink -f "$1" 2>/dev/null`
TARGET_DIR=`readlink -f "$2" 2>/dev/null`
PROJECT_NAME="$3"
PROJECT_VERSION="$4"

if [ "$SOURCE_DIR" == "" ]; then
	echo "ERROR: invalid source directory, exiting."
	exit 1
fi

if [ "$TARGET_DIR" == "" ]; then
	echo "ERROR: invalid target directory, exiting."
	exit 1
fi

if [ "$PROJECT_NAME" == "" ]; then
	PROJECT_NAME="unnamed"
fi

if [ "$PROJECT_VERSION" == "" ]; then
	PROJECT_VERSION="0.1.0"
fi


### preparing
section_start "nwjs_prepare" "Preparing..."

cd "$ROOT_DIR"

# create directories
mkdir -p cache
mkdir -p build

cd cache

# download node.js if not downloaded already
if [ ! -e "node-v8.9.4-linux-x64.tar.xz" ]; then
	wget https://nodejs.org/dist/v8.9.4/node-v8.9.4-linux-x64.tar.xz
fi

cd ..

cd build

# install node.js if not installed
if [ ! -e "node-v8.9.4-linux-x64" ]; then
	cat ../cache/node-v8.9.4-linux-x64.tar.xz | xz -d | tar -x
fi

# install  nwjs-builder-phoenix
npm install nwjs-builder-phoenix

# copy the original files here
cp -r "$SOURCE_DIR/"* ./

if [ -e "package.json" ]; then
	echo "WARNING: source contains a package.json file, it will be not included in distribution."
fi

# create a new package.json
cat "$ROOT_DIR/package.json.template" | sed -r "s/___project_name___/$PROJECT_NAME/g" | sed -r "s/___project_version___/$PROJECT_VERSION/g" > package.json

section_end "nwjs_prepare"

section_start "nwjs_build" "Building..."

# run the build
npm run nwjs-build
result=$?

if [ $result != 0 ]; then
	echo "ERROR: build returned status $result, exiting."
	exit 1
fi

section_end "nwjs_build"

# create the zip pacckages
cd dist

section_start "zip_build" "Creating ZIPs..."
for i in *; do
	if [ ! -d "$i" ]; then
		continue
	fi
	
	if [ -e "$TARGET_DIR/$i.zip" ]; then
		echo "WARNING: $i.zip already exists, skipping."
		continue
	fi
	
	# node is not needed in final ZIPs
	rm -r "$i"/node-*
	
	zip -r9 "$TARGET_DIR/$i.zip" "$i" | grep -vE '^  adding:'
done

section_end "zip_build"

cd "$ROOT_DIR/build/dist"

for i in *-win-*; do
	if [ ! -d "$i" ]; then
		continue
	fi
	echo "$i"
	
	section_start "nsis_build:$i:admin" "Building $i admin installer..."
	$ROOT_DIR/build_nsis.sh "$i" admin
	section_end "nsis_build:$i:admin"
	
	section_start "nsis_build:$i:user" "Building $i user installer..."
	$ROOT_DIR/build_nsis.sh "$i" user
	section_end "nsis_build:$i:user"
	
	mv *.exe "$TARGET_DIR/"
done

cd "$TARGET_DIR"

ls -alh

exit 0

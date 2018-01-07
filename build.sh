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

# run the build
npm run nwjs-build
result=$?

if [ $result != 0 ]; then
	echo "ERROR: build returned status $result, exiting."
	exit 1
fi

exit 0

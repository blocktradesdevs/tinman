#!/bin/bash

# Important! Before executing this script, it is necessary to install 'tinman' tool according to instructions from: 'https://github.com/steemit/tinman'

# 'source_blockchain_path' - path to current data directory for 'source' steemd('source' steemd -> steemd instance, filled by real data from real STEEM network)
# 'source_steemd_exe' -      path of 'source' steemd
# 'source_http' -            webserver-http-endpoint for 'source' steemd
# 'dest_blockchain_path'  -  path to current data directory for 'dest' steemd('dest' steemd -> steemd instance, filled by artificial data. That instance should be compiled with 'BUILD_STEEM_TESTNET': 'ON')
# 'dest_program_path' -      general path for execute files i.e. steemd, get_dev_key( changes keystrings to public keys ), sign_transaction( generates proper signatures to given transactions )
# 'txgen' 				-    basic settings needed during creating of transactions( names of owners, number transaction per block etc. )"
# 'fail_file'			-    if something is wrong during filling testnet, then an information is put inside this file
# Fast checking, after executing this script: curl --data '{"jsonrpc": "2.0", "method": "call", "params": ["condenser_api","get_dynamic_global_properties", [] ], "id": 1}' http://127.0.0.1:9990

# Important! In this script default value for HTTP_DEST is 'http://127.0.0.1:9990'
# If is necessary to change this value, value in 'config.ini' has to be changed from webserver-http-endpoint = 127.0.0.1:9990 to webserver-http-endpoint = ANY_NEW_HTTP_ADDRESS

# Important!
# 'source' steemd is based on 'master' branch
# 'dest' steemd is based on 'master' branch

function info
{
	echo "*****************************"
	echo "5-7 parameters are required."
	echo "'source_blockchain_path'   for example: '~/_data/any_path1/build/Release/programs/steemd/blockchain'"
	echo "'source_steemd_exe'        for example: '~/_data/any_path1/build/Release/programs/steemd/steemd/steemd'"
	echo "'source_http'              for example: 'http://127.0.0.1:9990'"
	echo "'dest_blockchain_path'     for example: '~/_data/any_path2/build/Release/programs/steemd/blockchain'"
	echo "'dest_program_path'        for example: '~/_data/any_path2/build/Release/programs'"
	echo "'txgen'                    default 'txgen._conf'"
	echo "'fail_file'                default 'fail.json'"
	echo "*****************************"
	echo "example: ./run_testnet_mm.sh ~/src/steem_data_src ~/src/03.STEEM/steem/build_release/programs/steemd/steemd http://127.0.0.1:9990 ~/src/steem_data ~/src/00.STEEM-CLEAR/steem/build_release/programs"
	echo "*****************************"
	exit $EXIT_CODE
}

if [ $# -lt 5 ] || [ $# -gt 7 ]
then
	info
fi

SOURCE_BLOCKCHAIN_PATH=$1
SOURCE_STEEMD_EXE=$2
SOURCE_HTTP=$3

DEST_BLOCKCHAIN_PATH=$4
DEST_GET_DEV_KEY_EXE=$5/util/get_dev_key
DEST_SIGN_EXE=$5/util/sign_transaction
DEST_STEEMD_EXE=$5/steemd/steemd

HTTP_DEST="http://127.0.0.1:8090"

TXGEN="txgen._conf"
FAIL_FILE="fail.json"

STEEMS=200001
VESTS=2000002
SBDS=500003

if [ $# -gt 5 ]
then
	TXGEN=$6
fi

if [ $# -gt 6 ]
then
	FAIL_FILE=$7
fi

function check_exe {
   echo Checking $1...
   if [ -x "$1" ]
   then
      echo OK: $1 is executable file.
   else
      echo FATAL: $1 is not executable file or found! && exit -1
   fi
}

check_exe $SOURCE_STEEMD_EXE
check_exe $DEST_GET_DEV_KEY_EXE
check_exe $DEST_SIGN_EXE
check_exe $DEST_STEEMD_EXE

DELETED_DIR="$DEST_BLOCKCHAIN_PATH/*"
rm -rf $DELETED_DIR

mkdir $DEST_BLOCKCHAIN_PATH
cp config.ini $DEST_BLOCKCHAIN_PATH

echo "**************Listening $DEST_STEEMD_EXE"
$DEST_STEEMD_EXE -d $DEST_BLOCKCHAIN_PATH &
PID_DEST_STEEMD_EXE=$!

echo "**************Listening $SOURCE_STEEMD_EXE"
$SOURCE_STEEMD_EXE -d $SOURCE_BLOCKCHAIN_PATH &
PID_SOURCE_STEEMD_EXE=$!

echo "**************Waiting"
sleep 10

echo "**************Generating snapshot from $SOURCE_HTTP steemd instance"
./tinman snapshot -s $SOURCE_HTTP -o snapshot.json

kill -9 $PID_SOURCE_STEEMD_EXE

echo "**************Creating transactions according to $TXGEN settings"
./tinman txgen -c $TXGEN -o tn.txlist -i true -s $STEEMS -v $VESTS -b $SBDS

echo "**************Key substitution - keystring->public key using $DEST_GET_DEV_KEY_EXE tool"
./tinman keysub -i tn.txlist -o tn2.txlist --get-dev-key $DEST_GET_DEV_KEY_EXE

echo "**************Filling testnet instance $HTTP_DEST using $DEST_SIGN_EXE tool"
./tinman submit -t $HTTP_DEST -i tn2.txlist --signer $DEST_SIGN_EXE -f $FAIL_FILE

sleep 5

kill -9 $PID_DEST_STEEMD_EXE

echo "done..."

exit 0

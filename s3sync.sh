#!/bin/bash

if test "x$SRCPATH" = "x"
then
    echo ENV SRCPATH not set
    exit 1
fi

if test "x$DSTPATH" = "x"
then
    echo ENV DSTPATH not set
    exit 2
fi

if test "x$CFGPATH" = "x"
then
    echo ENV CFGPATH not set
    exit 3
fi


cd "$SRCPATH"

for i in *
do
    date
    echo "Starting $i"
    /usr/local/bin/s3cmd sync -c "$CFGPATH"/s3cfg --no-check-md5 $S3EXTRA_PARAMS "$i" "$DSTPATH"
    date
    echo "Done $i"
done

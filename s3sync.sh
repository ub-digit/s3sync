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


cd "$SRCPATH"

for i in *
do
    date
    echo "Starting $i"
    /usr/local/bin/s3cmd sync --no-check-md5 "$i" "$DSTPATH"
    date
    echo "Done $i"
done

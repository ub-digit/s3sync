FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y python3-pip less \
 && apt-get clean

RUN pip3 install s3cmd
COPY s3sync.sh /usr/local/bin/

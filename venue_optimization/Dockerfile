FROM ubuntu:18.04
LABEL maintainer="Sertalp B. Cay <sertalp.cay@sas.com>"

RUN apt -y update && apt-get update
RUN apt-get install --no-install-recommends -y numactl libssl1.1 python3 python3-pip
RUN pip3 install --upgrade pip && pip3 install pandas swat

ENV LANG en_US.UTF-8

COPY . /app
WORKDIR /app

CMD python3 solve.py

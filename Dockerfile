FROM ubuntu:18.04

ENV DEBIAN_FRONTEND noninteractive


COPY ./setup.sh /
RUN /setup.sh

VOLUME /var/lib/mysql

EXPOSE 80
ENTRYPOINT ["/setup.sh"]

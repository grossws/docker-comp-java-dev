FROM grossws/java
MAINTAINER Konstantin Gribov <grossws@gmail.com>

ADD entrypoint.sh /

RUN yum -y install java-1.8.0-openjdk-devel which \
  && useradd --home-dir /app --gid users --no-create-home --no-user-group dev \
  && /entrypoint.sh bootstrap-tools \
  && /entrypoint.sh cleanup-tools \
  && yum clean all

WORKDIR "/app"
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash", "-l"]

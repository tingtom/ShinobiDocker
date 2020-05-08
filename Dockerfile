#
# Builds a custom docker image for ShinobiCCTV Pro
#
FROM node:8-alpine 

# Build arguments ...
# Shinobi's version information
ARG ARG_APP_VERSION 

# The channel or branch triggering the build.
ARG ARG_APP_CHANNEL

# The commit sha triggering the build.
ARG ARG_APP_COMMIT

# Update Shinobi on every container start?
#   manual:     Update Shinobi manually. New Docker images will always retrieve the latest version.
#   auto:       Update Shinobi on every container start.
ARG ARG_APP_UPDATE=auto

# Build data
ARG ARG_BUILD_DATE

# ShinobiPro branch, defaults to master
ARG ARG_APP_BRANCH=master

# Basic build-time metadata as defined at http://label-schema.org
LABEL org.label-schema.build-date=${ARG_BUILD_DATE} \
    org.label-schema.docker.dockerfile="/Dockerfile" \
    org.label-schema.license="GPLv3" \
    org.label-schema.name="MiGoller" \
    org.label-schema.vendor="MiGoller" \
    org.label-schema.version="${ARG_APP_VERSION}-${ARG_APP_BRANCH}" \
    org.label-schema.description="Shinobi Pro - The Next Generation in Open-Source Video Management Software" \
    org.label-schema.url="https://gitlab.com/users/MiGoller/projects" \
    org.label-schema.vcs-ref=${ARG_APP_COMMIT} \
    org.label-schema.vcs-type="Git" \
    org.label-schema.vcs-url="https://github.com/tingtom/Shinobi.git" \
    maintainer="MiGoller" \
    Author="MiGoller, mrproper, pschmitt & moeiscool"

# Persist app-reladted build arguments
ENV APP_VERSION=$ARG_APP_VERSION \
    APP_CHANNEL=$ARG_APP_CHANNEL \
    APP_COMMIT=$ARG_APP_COMMIT \
    APP_UPDATE=$ARG_APP_UPDATE \
    APP_BRANCH=${ARG_APP_BRANCH}

# Set environment variables to default values
# ADMIN_USER : the super user login name
# ADMIN_PASSWORD : the super user login password
# PLUGINKEY_MOTION : motion plugin connection key
# PLUGINKEY_OPENCV : opencv plugin connection key
# PLUGINKEY_OPENALPR : openalpr plugin connection key
ENV ADMIN_USER=admin@shinobi.video \
    ADMIN_PASSWORD=admin \
    CRON_KEY=fd6c7849-904d-47ea-922b-5143358ba0de \
    PLUGINKEY_MOTION=b7502fd9-506c-4dda-9b56-8e699a6bc41c \
    PLUGINKEY_OPENCV=f078bcfe-c39a-4eb5-bd52-9382ca828e8a \
    PLUGINKEY_OPENALPR=dbff574e-9d4a-44c1-b578-3dc0f1944a3c \
    #leave these ENVs alone unless you know what you are doing
    MYSQL_USER=majesticflame \
    MYSQL_PASSWORD=password \
    MYSQL_HOST=localhost \
    MYSQL_DATABASE=ccio \
    MYSQL_ROOT_PASSWORD=blubsblawoot \
    MYSQL_ROOT_USER=root 


# Create additional directories for: Custom configuration, working directory, database directory, scripts
RUN mkdir -p \
        /config \
        /opt/shinobi \
        /var/lib/mysql

# Assign working directory
WORKDIR /opt/shinobi

# Install package dependencies
RUN apk update && \
    apk add --no-cache \ 
        freetype-dev \ 
        gnutls-dev \ 
        lame-dev \ 
        libass-dev \ 
        libogg-dev \ 
        libtheora-dev \ 
        libvorbis-dev \ 
        libvpx-dev \ 
        libwebp-dev \ 
        libssh2 \ 
        opus-dev \ 
        rtmpdump-dev \ 
        x264-dev \ 
        x265-dev \ 
        yasm-dev && \
    apk add --no-cache --virtual \ 
        .build-dependencies \ 
        build-base \ 
        bzip2 \ 
        coreutils \ 
        gnutls \ 
        nasm \ 
        tar \ 
        x264

RUN apk update && \
    apk add --no-cache \
        ffmpeg \
        git \
        make \
        mariadb \
        mariadb-client \
        openrc \
        pkgconfig \
        python \
        wget \
        tar \
        xz

RUN sed -ie "s/^bind-address\s*=\s*127\.0\.0\.1$/#bind-address = 0.0.0.0/" /etc/my.cnf.d/mariadb-server.cnf && \
    sed -ie "s/^skip-networking$/#skip-networking/" /etc/my.cnf.d/mariadb-server.cnf

RUN git clone -b dev https://github.com/tingtom/Shinobi.git /opt/shinobi
	
# Install Shinobi app including NodeJS dependencies
#COPY ./ShinobiPro/ ./

RUN npm i npm@latest -g && \
    npm install pm2 -g && \
    npm install jsonfile && \
    npm install edit-json-file && \
    npm install ffbinaries && \
    npm install --unsafe-perm && \
    npm audit fix --force

# Copy code
COPY docker-entrypoint.sh ./docker-entrypoint.sh
COPY pm2Shinobi.yml ./
COPY /tools/modifyJson.js ./tools
RUN chmod -f +x ./*.sh

# Copy default configuration files
COPY ./config/conf.sample.json ./config/super.sample.json /opt/shinobi/

VOLUME ["/opt/shinobi/videos"]
VOLUME ["/opt/shinobi/snapshots"]
VOLUME ["/config"]
VOLUME ["/var/lib/mysql"]

EXPOSE 8080

ENTRYPOINT ["/opt/shinobi/docker-entrypoint.sh"]

CMD ["pm2-docker", "pm2Shinobi.yml"]

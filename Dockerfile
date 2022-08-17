FROM python:3.7-slim

LABEL "com.github.actions.name"="Deploy Pelican Site to GitHub Pages"
LABEL "com.github.actions.description"="Deploy Pelican Site to GitHub Pages"
LABEL "com.github.actions.icon"="home"
LABEL "com.github.actions.color"="red"

LABEL "repository"="https://github.com/justgoodin/pelican-to-github-pages"
LABEL "homepage"="https://github.com/justgoodin/pelican-to-github-pages"

ENV LC_ALL C.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

RUN apt-get update \
    && apt-get install --no-install-recommends -qy git curl bash

RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
RUN apt-get install -y nodejs

COPY entrypoint.sh /entrypoint.sh
RUN ["chmod", "+x", "/entrypoint.sh"]

ENTRYPOINT ["/entrypoint.sh"]


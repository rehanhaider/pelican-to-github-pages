FROM node:26-slim AS node

FROM python:3.13-slim

LABEL "com.github.actions.name"="Deploy Pelican Site to GitHub Pages"
LABEL "com.github.actions.description"="Deploy Pelican Site to GitHub Pages"
LABEL "com.github.actions.icon"="home"
LABEL "com.github.actions.color"="red"

LABEL "repository"="https://github.com/rehanhaider/pelican-to-github-pages"
LABEL "homepage"="https://github.com/rehanhaider/pelican-to-github-pages"

ENV LC_ALL=C.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8

# libatomic1 and libstdc++6 are the libraries the node binary needs.
RUN apt-get update \
    && apt-get install --no-install-recommends -qy git curl bash libatomic1 libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

# Node and npm, for PELICAN_THEME_FOLDER, come from the official Node image
# rather than a third-party apt repository.
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && node --version \
    && npm --version

COPY entrypoint.sh /entrypoint.sh
RUN ["chmod", "+x", "/entrypoint.sh"]

ENTRYPOINT ["/entrypoint.sh"]

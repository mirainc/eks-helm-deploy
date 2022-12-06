FROM python:3.8-slim-buster

COPY deploy.sh /usr/local/bin/deploy

# Helm plugins are normally per-user, and Github Actions changes the home
# directory when it runs inside a container.  Use a global, shared Helm
# plugin path to work around this.
ENV HELM_PLUGINS=/var/lib/helm/plugins

# Ignore flags like --wait and --atomic if they are passed to Helm Diff.
ENV HELM_DIFF_IGNORE_UNKNOWN_FLAGS=true

# Install the toolset.
RUN apt-get -y update && apt-get -y install curl git \
    && pip install awscli \
    && curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash \
    && curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x ./kubectl && mv ./kubectl /usr/local/bin/kubectl \
    && mkdir -p $HELM_PLUGINS \
    && helm plugin install https://github.com/databus23/helm-diff \
    && helm plugin install https://github.com/jkroepke/helm-secrets \
    && rm -rf /var/lib/apt

CMD deploy

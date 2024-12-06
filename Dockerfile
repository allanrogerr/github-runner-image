FROM ubuntu:latest

RUN apt update -y && apt upgrade -y && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends apt-utils software-properties-common vim snapd curl jq git build-essential  libssl-dev

# Prevents installdependencies.sh from prompting the user and blocking the image creation
ARG DEBIAN_FRONTEND=noninteractive

RUN useradd -m docker

ARG GH_RUNNER_USER="docker"
RUN LATEST=`curl -s -i https://github.com/actions/runner/releases/latest | grep location:` && \ 
LATEST=`echo $LATEST | sed 's#.*tag/v##'` && \
RUNNER_VERSION=`echo $LATEST | sed 's/\r//'` && cd /home/docker && mkdir actions-runner && cd actions-runner \
    && curl -O -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

RUN chown -R docker ~docker && /home/docker/actions-runner/bin/installdependencies.sh

# Avoid `too many open files` errors
RUN echo \"fs.inotify.max_user_watches = 1048576\" | tee -a /etc/sysctl.conf
RUN echo \"fs.inotify.max_user_instances = 512\" | tee -a /etc/sysctl.conf

# Helm
RUN curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg && apt-get install apt-transport-https -y && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list && apt-get update && apt-get install helm -y

# Python
RUN apt install -y python-is-python3 > /dev/null

# Golang
RUN apt-get remove golang-go -y
RUN apt-get remove --auto-remove golang-go -y
RUN add-apt-repository -y ppa:longsleep/golang-backports
RUN apt update -y
RUN apt install -y golang-go

RUN mkdir /home/docker/go
RUN chown -R docker:docker /home/docker/go
RUN export GOPATH=/home/docker/go

RUN mkdir -p /home/docker/.cache/go-build
RUN chown -R docker:docker /home/docker/.cache
RUN export GOCACHE=/home/docker/.cache

RUN go install github.com/docker/compose/v2/cmd@latest > /dev/null
RUN go install github.com/docker/buildx/cmd/buildx@latest > /dev/null
RUN apt-get install -y protobuf-compiler > /dev/null

# ubuntu uses a non-standard location so modules need to be symlinked to the expected location
RUN ln -sf /home/$GH_RUNNER_USER/go/bin/govulncheck /usr/local/bin/govulncheck
RUN ln -sf /home/$GH_RUNNER_USER/go/bin/mockery /usr/local/bin/mockery
RUN ln -sf /home/$GH_RUNNER_USER/go/bin/protoc-gen-go /usr/local/bin/protoc-gen-go
RUN ln -sf /home/$GH_RUNNER_USER/go/bin/protoc-gen-go-grpc /usr/local/bin/protoc-gen-go-grpc
RUN ln -sf /home/$GH_RUNNER_USER/go/bin/protoc-gen-grpc-gateway /usr/local/bin/protoc-gen-grpc-gateway
RUN ln -sf /home/$GH_RUNNER_USER/go/bin/protoc-gen-openapiv2 /usr/local/bin/protoc-gen-openapiv2
RUN ln -sf /home/$GH_RUNNER_USER/go/bin/staticcheck /usr/local/bin/staticcheck
RUN ln -sf /home/$GH_RUNNER_USER/go/bin/swagger /usr/local/bin/swagger

# Docker Compose
RUN mkdir -p ~/.docker/cli-plugins/
RUN mv ~/go/bin/cmd ~/.docker/cli-plugins/docker-compose
RUN mv ~/go/bin/buildx ~/.docker/cli-plugins/docker-buildx
RUN chmod +x ~/.docker/cli-plugins/docker-compose
RUN chmod +x ~/.docker/cli-plugins/docker-buildx

# Manage Docker as a non-root user
RUN apt-get remove -y docker.io make npm
RUN apt-get install -y docker.io make npm > /dev/null
RUN usermod -aG docker $GH_RUNNER_USER

RUN mv /usr/bin/docker /usr/bin/_docker
COPY docker /usr/bin/docker
RUN chmod +x /usr/bin/docker

# Kind
RUN curl -L "https://kind.sigs.k8s.io/dl/v0.24.0/kind-$(uname)-amd64" -o /usr/local/bin/kind && chmod +x /usr/local/bin/kind
RUN curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
RUN install -o root -g root -m 0755 kustomize /usr/local/bin/kustomize
RUN npm install -g corepack

#awscli
RUN apt-get install -y unzip > /dev/null
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
RUN unzip -q /tmp/awscliv2.zip -d /tmp
RUN rm /tmp/awscliv2.zip
RUN /tmp/aws/install --update
RUN rm -rf /tmp/aws/

# dind
ARG HOST_GID
ENV DOCKER_GID=$HOST_GID
RUN groupadd -g $DOCKER_GID vg
RUN usermod -aG vg $GH_RUNNER_USER

# Install cleanup scripts
COPY cleanup.sh /home/$GH_RUNNER_USER/cleanup.sh
RUN chmod +x /home/$GH_RUNNER_USER/cleanup.sh
RUN echo -n "ACTIONS_RUNNER_HOOK_JOB_STARTED=/home/$GH_RUNNER_USER/cleanup.sh" >> /home/$GH_RUNNER_USER/actions-runner/.env

COPY start.sh start.sh

# make the script executable
RUN chmod +x start.sh

# since the config and run script for actions are not allowed to be run by root,
# set the user to "docker" so all subsequent commands are run as the docker user
USER docker


ENTRYPOINT ["./start.sh"]
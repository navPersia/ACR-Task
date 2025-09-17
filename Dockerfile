FROM mcr.microsoft.com/powershell:latest

ENV DEBIAN_FRONTEND=noninteractive

# Install prerequisites, Azure CLI, and kubectl
RUN apt-get update && \
    apt-get install -y ca-certificates curl gnupg apt-transport-https lsb-release && \
    curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null && \
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/azure-cli.list && \
    apt-get update && apt-get install -y azure-cli && \
    curl -fsSL https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl && \
    az aks install-cli && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /scripts
COPY purge-images.ps1 .

CMD ["pwsh", "-File", "purge-images.ps1"]

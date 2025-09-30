# Instruction URL: https://www.hyperdx.io/docs/v2/local

# Command to start docker container
git clone -b main --depth 1 https://github.com/SigNoz/signoz.git
cd signoz/deploy/docker
docker compose up -d --remove-orphans

# Instruction URL: https://docs.coroot.com/installation/docker/

# Command to start docker container
curl -fsS https://raw.githubusercontent.com/coroot/coroot/main/deploy/docker-compose.yaml | \
  docker compose -f - up -d
# Instruction URL: https://www.hyperdx.io/docs/v2/local

# Command to start docker container
git clone --recurse-submodules --depth 1 https://github.com/highlight/highlight

REACT_APP_PRIVATE_GRAPH_URI=http://localhost:8082/private
REACT_APP_PUBLIC_GRAPH_URI=http://localhost:8082/public
REACT_APP_FRONTEND_URI=http://localhost

cd highlight/docker;
./run-hobby.sh;

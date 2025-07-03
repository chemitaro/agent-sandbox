#!/bin/bash
set -e

# Docker socket setup function
setup_docker_socket() {
    local socket_path="/var/run/docker.sock"
    
    if [ -S "$socket_path" ]; then
        echo "🔧 Setting up Docker socket permissions..."
        
        # Get socket GID
        local socket_gid=$(stat -c %g "$socket_path" 2>/dev/null || echo "999")
        
        echo "📊 Docker socket GID: $socket_gid"
        
        # Adjust docker group GID if necessary
        if [ "$socket_gid" != "999" ] && [ "$socket_gid" != "0" ]; then
            echo "🔄 Adjusting docker group GID to match host ($socket_gid)"
            groupmod -g "$socket_gid" docker 2>/dev/null || echo "⚠️  Could not change docker group GID"
        fi
        
        # Ensure node user is in docker group
        usermod -aG docker node 2>/dev/null || echo "⚠️  Could not add node to docker group"
        
        echo "✅ Docker socket permissions configured"
    else
        echo "⚠️  Docker socket not found at $socket_path"
        echo "    Docker commands will not be available in this container"
    fi
}

# Run setup as root then switch to node user
if [ "$(id -u)" = "0" ]; then
    echo "🐳 Running Docker-on-Docker setup..."
    
    # Setup Docker socket permissions
    setup_docker_socket
    
    # Run firewall setup if requested
    if [ "$1" = "init-firewall" ]; then
        echo "🔥 Running firewall initialization..."
        /usr/local/bin/init-firewall.sh
        shift
    fi
    
    # Switch to node user
    echo "🔄 Switching to node user..."
    exec gosu node "$0" "$@"
fi

# Running as node user from here
echo "✅ Docker-on-Docker environment ready!"
echo "🏠 Running as user: $(whoami)"

# Test Docker access
if docker version >/dev/null 2>&1; then
    echo "✅ Docker CLI access verified"
else
    echo "⚠️  Docker CLI access not available"
fi

# Execute the original command
exec "$@"
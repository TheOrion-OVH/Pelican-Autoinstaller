#!/bin/bash

# Pelican Panel Auto Installer
# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Banner
print_banner() {
    clear
    echo -e "${PURPLE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                   PELICAN PANEL INSTALLER                     ║"
    echo "║                     Auto Installation Script                  ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Main menu
show_menu() {
    print_banner
    echo -e "${CYAN}Please select an option:${NC}"
    echo ""
    echo -e "${WHITE}1)${NC} Install Panel only"
    echo -e "${WHITE}2)${NC} Install Wings only"
    echo -e "${WHITE}3)${NC} Install Panel + Wings (same machine)"
    echo -e "${WHITE}4)${NC} Exit"
    echo ""
    echo -n -e "${CYAN}Enter your choice [1-4]: ${NC}"
}

# Get user input for yes/no questions
get_yes_no() {
    local prompt="$1"
    local response
    
    while true; do
        echo -n -e "${CYAN}$prompt [y/N]: ${NC}"
        read -r response
        case $response in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo]|"")
                return 1
                ;;
            *)
                print_warning "Please answer yes (y) or no (n)"
                ;;
        esac
    done
}

# Get domain input
get_domain() {
    local domain
    while true; do
        echo -n -e "${CYAN}Enter your domain name (e.g., panel.example.com): ${NC}"
        read -r domain
        if [[ -n "$domain" ]]; then
            DOMAIN="$domain"
            break
        else
            print_warning "Domain cannot be empty"
        fi
    done
}

# Install Panel
install_panel() {
    print_status "Starting Panel installation..."
    
    # Get domain
    get_domain
    
    # Ask for SSL
    if get_yes_no "Do you want to install SSL certificate?"; then
        INSTALL_SSL=true
    else
        INSTALL_SSL=false
    fi
    
    print_status "Updating system packages..."
    apt update -y
    
    print_status "Installing required packages..."
    apt install -y curl nginx certbot python3-certbot-nginx
    apt install -y php php-fpm php-gd php-mysql php-mbstring php-bcmath php-xml php-curl php-zip php-intl php-sqlite3
    
    print_status "Creating Pelican directory..."
    mkdir -p /var/www/pelican
    cd /var/www/pelican
    
    print_status "Downloading Pelican Panel..."
    curl -L https://github.com/pelican-dev/panel/releases/latest/download/panel.tar.gz | tar -xzv
    
    print_status "Installing Composer..."
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    
    print_status "Installing PHP dependencies..."
    COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
    
    print_status "Configuring Nginx..."
    cat > /etc/nginx/sites-available/pelican.conf << EOF
server {
    listen 80;
    server_name $DOMAIN;
    root /var/www/pelican/public;
    index index.html index.htm index.php;
    charset utf-8;
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }
    access_log off;
    error_log  /var/log/nginx/pelican.app-error.log error;
    # allow larger file uploads and longer script runtimes
    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;
    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \\n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }
    location ~ /\.ht {
        deny all;
    }
}
EOF
    
    print_status "Enabling Nginx site..."
    ln -sf /etc/nginx/sites-available/pelican.conf /etc/nginx/sites-enabled/pelican.conf
    
    # SSL Certificate
    if [[ "$INSTALL_SSL" == true ]]; then
        print_status "Installing SSL certificate..."
        certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email
        if [[ $? -eq 0 ]]; then
            print_success "SSL certificate installed successfully"
        else
            print_warning "SSL certificate installation failed, continuing without SSL"
        fi
    fi
    
    print_status "Restarting Nginx..."
    systemctl restart nginx
    
    print_status "Setting up Pelican environment..."
    php artisan p:environment:setup
    
    print_status "Setting permissions..."
    chmod -R 755 storage/* bootstrap/cache/
    chown -R www-data:www-data /var/www/pelican
    
    print_success "Panel installation completed!"
    echo -e "${GREEN}Please complete the installation by visiting: ${WHITE}http${INSTALL_SSL:+s}://$DOMAIN/installer${NC}"
    echo ""
}

# Install Wings
install_wings() {
    print_status "Starting Wings installation..."
    
    print_status "Installing Docker..."
    curl -sSL https://get.docker.com/ | CHANNEL=stable sh
    systemctl enable docker
    systemctl start docker
    
    # Ask for domain for reverse proxy
    local wings_domain=""
    local wings_ssl=false
    
    if get_yes_no "Do you want to set up a domain for Wings (reverse proxy)?"; then
        echo -n -e "${CYAN}Enter your Wings domain name (e.g., wings.example.com): ${NC}"
        read -r wings_domain
        
        if [[ -n "$wings_domain" ]]; then
            if get_yes_no "Do you want to install SSL certificate for Wings?"; then
                wings_ssl=true
            fi
            
            print_status "Installing Nginx if not already installed..."
            apt install -y nginx certbot python3-certbot-nginx
            
            print_status "Creating Wings reverse proxy configuration..."
            cat > /etc/nginx/sites-available/wings.conf << EOF
server {
    listen 80;
    server_name $wings_domain;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
        proxy_request_buffering off;
    }
}
EOF
            
            print_status "Enabling Wings Nginx site..."
            ln -sf /etc/nginx/sites-available/wings.conf /etc/nginx/sites-enabled/wings.conf
            
            # SSL Certificate for Wings
            if [[ "$wings_ssl" == true ]]; then
                print_status "Installing SSL certificate for Wings..."
                certbot --nginx -d "$wings_domain" --non-interactive --agree-tos --register-unsafely-without-email
                if [[ $? -eq 0 ]]; then
                    print_success "SSL certificate installed successfully for Wings"
                else
                    print_warning "SSL certificate installation failed for Wings, continuing without SSL"
                fi
            fi
            
            print_status "Restarting Nginx..."
            systemctl restart nginx
        fi
    fi
    
    print_status "Creating Wings directories..."
    mkdir -p /etc/pelican /var/run/wings
    
    print_status "Downloading Wings binary..."
    curl -L -o /usr/local/bin/wings "https://github.com/pelican-dev/wings/releases/latest/download/wings_linux_$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")"
    chmod u+x /usr/local/bin/wings
    
    print_status "Creating Wings systemd service..."
    cat > /etc/systemd/system/wings.service << 'EOF'
[Unit]
Description=Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pelican
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    
    print_status "Enabling Wings service..."
    systemctl daemon-reload
    systemctl enable wings
    
    print_success "Wings installation completed!"
    if [[ -n "$wings_domain" ]]; then
        echo -e "${GREEN}Wings reverse proxy configured at: ${WHITE}http${wings_ssl:+s}://$wings_domain${NC}"
    fi
    print_warning "Don't forget to configure Wings with your panel configuration file"
    print_status "Configuration file should be placed at: /etc/pelican/config.yml"
    print_status "Start Wings with: systemctl start wings"
    echo ""
}

# Install both Panel and Wings
install_both() {
    print_status "Installing Panel and Wings on the same machine..."
    echo ""
    
    # Install Panel first
    install_panel
    
    echo -e "${CYAN}Panel installation completed!${NC}"
    echo ""
    
    # Ask if user wants to continue with Wings
    if get_yes_no "Do you want to continue with Wings installation?"; then
        echo ""
        install_wings
        print_success "Both Panel and Wings have been installed successfully!"
    else
        print_status "Wings installation skipped. You can run this script again to install Wings later."
    fi
}

# Main execution
main() {
    check_root
    
    while true; do
        show_menu
        read -r choice
        echo ""
        
        case $choice in
            1)
                install_panel
                echo ""
                echo -n -e "${CYAN}Press Enter to return to menu...${NC}"
                read -r
                ;;
            2)
                install_wings
                echo ""
                echo -n -e "${CYAN}Press Enter to return to menu...${NC}"
                read -r
                ;;
            3)
                install_both
                echo ""
                echo -n -e "${CYAN}Press Enter to return to menu...${NC}"
                read -r
                ;;
            4)
                print_success "Thanks for using Pelican Panel Auto Installer!"
                exit 0
                ;;
            *)
                print_error "Invalid option. Please choose 1-4."
                sleep 2
                ;;
        esac
    done
}

# Trap to handle script interruption
trap 'echo -e "\n${RED}Installation interrupted!${NC}"; exit 1' INT

# Run main function
main

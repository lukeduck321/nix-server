{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  ############################################################
  ## SYSTEM
  ############################################################

  system.stateVersion = "25.11";

  time.timeZone = "Australia/Adelaide";

  ############################################################
  ## BOOTLOADER + AUTO ROLLBACK
  ############################################################

  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 30;
    bootCounting.enable = true;
  };

  boot.loader.efi.canTouchEfiVariables = true;

  ############################################################
  ## LUKS + INITRD (REQUIRED FOR CLEVIS)
  ############################################################

  boot.initrd.systemd.enable = true;

  boot.initrd.availableKernelModules = [
    "cryptd"
  ];

  boot.initrd.luks.devices = {
    root = {
      device = "/dev/disk/by-uuid/YOUR-LUKS-UUID-HERE";
      preLVM = true;
      allowDiscards = true;
    };
  };

  ############################################################
  ## NETWORKING
  ############################################################

  networking.hostName = "server1";

  networking.networkmanager.enable = true;

  networking.useDHCP = false;

  networking.interfaces.enp0s31f6.ipv4.addresses = [
    {
      address = "192.168.1.117";
      prefixLength = 24;
    }
  ];

  networking.defaultGateway = "192.168.1.1";

  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
  ];

  ############################################################
  ## USERS
  ############################################################

  users.users.admin = {
    isNormalUser = true;
    description = "Administrator";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];

    initialPassword = "changeme";
  };

  ############################################################
  ## PACKAGES
  ############################################################

  environment.systemPackages = with pkgs; [

    vim
    nano
    git
    wget
    curl
    htop
    btop
    unzip
    zip
    tree
    tmux
    rsync

    freecad

    php
    nginx
    cloudflared

    # LUKS + TPM1 tools
    clevis
    clevis-tpm1
    cryptsetup
  ];

  ############################################################
  ## SSH
  ############################################################

  services.openssh = {
    enable = true;

    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
    };
  };

  ############################################################
  ## PHP
  ############################################################

  services.phpfpm.pools.web = {
    user = "nginx";
    group = "nginx";
    phpPackage = pkgs.php84;
  };

  ############################################################
  ## NGINX
  ############################################################

  services.nginx = {
    enable = true;

    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts = {

      "pintailprinted.com" = {
        serverAliases = [ "www.pintailprinted.com" ];

        listen = [ { addr = "0.0.0.0"; port = 80; } ];

        root = "/var/pintail/spin-click";

        index = [ "index.html" "index.htm" "index.php" ];

        locations."/" = {
          tryFiles = "$uri $uri/ =404";
        };

        locations."/back_end/" = {
          tryFiles = "$uri $uri/ =404";
        };

        locations."~ ^/back_end/(queue|inquiries)/" = {
          extraConfig = "deny all;";
        };

        locations."/admin/" = {
          tryFiles = "$uri $uri/ =404";
        };

        locations."~ ^/admin/(config|auth)\\.php$" = {
          extraConfig = "deny all;";
        };

        locations."~ \\.php$" = {
          extraConfig = ''
            fastcgi_pass unix:${config.services.phpfpm.pools.web.socket};
            include ${pkgs.nginx}/conf/fastcgi.conf;
          '';
        };
      };

      "tuftedgroup.org" = {
        serverAliases = [ "www.tuftedgroup.org" ];

        listen = [ { port = 8080; } ];

        root = "/var/www";

        index = [ "index.html" "index.htm" "index.php" ];

        locations."/" = {
          tryFiles = "$uri $uri/ =404";
        };

        locations."/back_end/" = {
          tryFiles = "$uri $uri/ =404";
        };

        locations."~ ^/back_end/(queue|inquiries)/" = {
          extraConfig = "deny all;";
        };

        locations."/admin/" = {
          tryFiles = "$uri $uri/ =404";
        };

        locations."~ ^/admin/(config|auth)\\.php$" = {
          extraConfig = "deny all;";
        };

        locations."~ \\.php$" = {
          extraConfig = ''
            fastcgi_pass unix:${config.services.phpfpm.pools.web.socket};
            include ${pkgs.nginx}/conf/fastcgi.conf;
          '';
        };
      };

      "bangonexcavations.com" = {
        serverAliases = [ "www.bangonexcavations.com" ];

        listen = [ { port = 8081; } ];

        root = "/var/bang-on";

        index = [ "index.html" ];

        locations."/" = {
          tryFiles = "$uri $uri/ =404";
        };

        locations."~* \\.(css|js|png|jpg|jpeg|gif|ico|svg|webp)$" = {
          extraConfig = ''
            expires 7d;
            add_header Cache-Control "public";
          '';
        };
      };
    };
  };

  ############################################################
  ## CLOUDFLARE TUNNEL
  ############################################################

  services.cloudflared = {
    enable = true;

    tunnels = {
      mytunnel = {
        credentialsFile = "/etc/cloudflared/credentials.json";

        default = "http_status:404";

        ingress = {
          "pintailprinted.com" = "http://localhost:80";
          "tuftedgroup.org" = "http://localhost:8080";
          "bangonexcavations.com" = "http://localhost:8081";
        };
      };
    };
  };

  ############################################################
  ## FIREWALL
  ############################################################

  networking.firewall = {
    enable = true;

    allowedTCPPorts = [
      22
      80
      8080
      8081
    ];
  };

  ############################################################
  ## SYSTEM MAINTENANCE
  ############################################################

  services.fstrim.enable = true;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nix.settings.auto-optimise-store = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}

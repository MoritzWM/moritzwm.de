{ config, lib, sops-nix, ... }:
{
	networking.firewall.allowedTCPPorts = [ 80 443 ];
    services.pihole-ftl = {
        enable = true;
        openFirewallDNS = true;
        settings = {
            dns.upstreams = [
                # Quad 9
                "9.9.9.9"
                "149.112.112.112"
                "2620:fe::fe"
                "2620:fe::9"
                # Cloudflare
                "1.1.1.1"
                "1.0.0.1"
                "2606:4700:4700::1111"
                "2606:4700:4700::1001"
            ];
        };
    };
    services.pihole-web = {
        enable = true;
        ports = [ "80r" "443s" ];
    };
}

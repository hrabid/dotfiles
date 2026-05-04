# Add cloudflared.repo to /etc/yum.repos.d/
# Stable
curl -fsSl https://pkg.cloudflare.com/cloudflared.repo | sudo tee /etc/yum.repos.d/cloudflared.repo
# Nightly
# curl -fsSl https://next.pkg.cloudflare.com/cloudflared.repo | sudo tee /etc/yum.repos.d/cloudflared.repo

#update repo
sudo yum update

# install cloudflared
sudo yum install cloudflared

// Script to install & setup latest Gitea from binary

import { $, permX, mkdirX, sudo, replace, checkSha256, createUser, exitErr } from '../utils.js'

const SHA_CHECKSUM = '310d7dfa48680f3eaa5fe2998ca7a8a1f707518c1772b64d85fb3b9e197188d3'
const GPG_KEY = '7C9E68152594688862D62AF62D9AE806EC1592E2'
const BINARY_URL = 'https://dl.gitea.com/gitea/1.22.2/gitea-1.22.2-linux-amd64'
const KEY_URL = 'https://dl.gitea.com/gitea/1.22.2/gitea-1.22.2-linux-amd64.asc'
const GITEA_WORKING_DIR = '/var/lib/gitea'

export function setupGitea({ giteaUser, giteaDomain, pgHost, pgDatabase }) {
  const binaryFile = '../giteaBin'
  const keyFile = '../giteaBin.asc'

  // Download Binary and key file
  $(`curl -Lo "${binaryFile}" "${BINARY_URL}" --no-progress-meter`)
  $(`curl -Lo "${keyFile}" "${KEY_URL}" --no-progress-meter`)

  // Check Package Authenticity
  checkSha256(SHA_CHECKSUM, binaryFile) // Check SHA256
  // Verify GPG signature
  $(`gpg --keyserver keys.openpgp.org --recv "${GPG_KEY}"`)
  const { stdErr: SIGNATURE } = $(`gpg --verify "${keyFile}" "${binaryFile}"`)
  if (!SIGNATURE.includes('Good signature')) {
    exitErr('GPG signature check failed')
  }
  $(`rm "${keyFile}"`)

  createUser(giteaUser) // Create user to run Gitea
  // Create required directory structure & set permissions
  sudo(mkdirX, `"${GITEA_WORKING_DIR}"/{custom,custom/public,data,log}`, 750, `${giteaUser}:${giteaUser}`)
  sudo(mkdirX, `/etc/gitea`, 750, `root:${giteaUser}`)

  // Setup the Gitea executable binary
  const giteaBin = '/usr/local/bin/gitea'
  $(`sudo mv "${binaryFile}" "${giteaBin}"`)
  permX(giteaBin, 'ug=rx,o=', `${giteaUser}:${giteaUser}`)

  // Setup the Gitea config
  const giteaConfig = '/etc/gitea/app.ini'
  $(`sudo cp gitea/app.ini "${giteaConfig}"`)
  permX(giteaConfig, 440, `${giteaUser}:${giteaUser}`)
  $(`sudo cp gitea/robots.txt "${GITEA_WORKING_DIR}/custom/public/robots.txt"`)
  replace('%%WORKING_DIR%%', GITEA_WORKING_DIR, giteaConfig)
  replace('%%GITEA_USER%%', giteaUser, giteaConfig)
  replace('%%DOMAIN.GITEA.COM%%', giteaDomain, giteaConfig)
  replace('%%DB_HOST%%', pgHost, giteaConfig)
  replace('%%DB_NAME%%', pgDatabase, giteaConfig)

  // Setup systemd service
  const systemdFile = '/etc/systemd/system/gitea.service'
  $(`sudo cp gitea/gitea.service "${systemdFile}"`)
  replace('%%GITEA_USER%%', giteaUser, systemdFile)
  replace('%%GITEA_WORKING_DIR%%', GITEA_WORKING_DIR, systemdFile)
  $('sudo mkdir -p /var/log/gitea') // Create Directory for Logging
  $('sudo systemctl enable --now gitea')

  // Setup nginx config
  const nginxConfig = `/etc/nginx/conf.d/${giteaDomain}.conf`
  $(`sudo cp gitea/nginx.conf "${nginxConfig}"`)
  replace('%%PLACEHOLDER.COM%%', giteaDomain, nginxConfig)
  $(`sudo mkdir -p "/usr/share/nginx/html/${giteaDomain}/"`)
  $('sudo nginx -s reload')

  // Fail2Ban setup
  $('sudo cp gitea/fail2ban.filter.conf /etc/fail2ban/filter.d/gitea.conf')
  $('sudo cp gitea/fail2ban.jail.conf /etc/fail2ban/jail.d/gitea.conf')
  $('sudo systemctl restart fail2ban')
}

#!/usr/bin/env bash

COIN_NAME='ANON' #no spaces
CODENAME='ANON'

#wallet information
WALLET_DOWNLOAD='https://github.com/alttankcanada/ANONMasternodeScript/raw/master/anon-linux.zip'
WALLET_TAR_FILE='anon-linux.zip'
ZIPTAR='unzip' #can be either unzip or tar -xfzg
EXTRACT_DIR='' #not always necessary, can be blank if zip/tar file has no subdirectories
CONFIG_FOLDER='/root/.anon'
CONFIG_FILE='anon.conf'
COIN_DAEMON='anond'
COIN_CLI='anon-cli'
COIN_PATH='/usr/bin'
ADDNODE1='172.245.97.67'
ADDNODE2='204.152.210.202'
ADDNODE3='96.126.112.77'
PORT='33130'
RPCPORT='19050'
DO_NET_CONF='/etc/network/interfaces.d/50-cloud-init.cfg'
ETH_INTERFACE='ens3'
IPV4_DOC_LINK='https://www.vultr.com/docs/add-secondary-ipv4-address'
NETWORK_CONFIG='/etc/rc.local'
NETWORK_BASE_TAG='579'
BOOTSTRAP='https://www.dropbox.com/s/raw/xu4c1twns4x7ove/anon-bootstrap.zip'
BOOTSTRAP_ZIP='anon-bootstrap.zip'

FETCHPARAMS='https://raw.githubusercontent.com/anonymousbitcoin/anon/master/anonutil/fetch-params.sh'
count='6002'

#end of required details
#
#
#


function prepare_mn_interfaces() {

    # this allows for more flexibility since every provider uses another default interface
    # current default is:
    # * ens3 (vultr) w/ a fallback to "eth0" (Hetzner, DO & Linode w/ IPv4 only)
    #

    # check for the default interface status
    if [ ! -f /sys/class/net/${ETH_INTERFACE}/operstate ]; then
        echo "Default interface doesn't exist, switching to eth0"
        export ETH_INTERFACE="eth0"
    fi

    # check for the nuse case <3
    if [ -f /sys/class/net/ens160/operstate ]; then
        export ETH_INTERFACE="ens160"
    fi

    # get the current interface state
    ETH_STATUS=$(cat /sys/class/net/${ETH_INTERFACE}/operstate)

    # check interface status
    if [[ "${ETH_STATUS}" = "down" ]] || [[ "${ETH_STATUS}" = "" ]]; then
        echo "Default interface is down, fallback didn't work. Break here."
        exit 1
    fi

    # DO ipv6 fix, are we on DO?
    # check for DO network config file
    if [ -f ${DO_NET_CONF} ]; then
        # found the DO config
        if ! grep -q "::8888" ${DO_NET_CONF}; then
            echo "ipv6 fix not found, applying!"
            sed -i '/iface eth0 inet6 static/a dns-nameservers 2001:4860:4860::8844 2001:4860:4860::8888 8.8.8.8 127.0.0.1' ${DO_NET_CONF}  
            ifdown ${ETH_INTERFACE}; ifup ${ETH_INTERFACE};  
        fi
    fi

    IPV6_INT_BASE="$(ip -6 addr show dev ${ETH_INTERFACE} | grep inet6 | awk -F '[ \t]+|/' '{print $3}' | grep -v ^fe80 | grep -v ^::1 | cut -f1-4 -d':' | head -1)" #&>> ${SCRIPT_LOGFILE}

    #validate_netchoice
    echo "IPV6_INT_BASE AFTER : ${IPV6_INT_BASE}"   

    # user opted for ipv6 (default), so we have to check for ipv6 support
    # check for vultr ipv6 box active
    if [ -z "${IPV6_INT_BASE}" ]; then
        echo "No IPv6 support on the VPS but IPv6 is the setup default. Please switch to ipv4 with flag \"-n 4\" if you want to continue."
        echo ""
   
        exit 1
    fi

    # generate the required ipv6 config
    #if [ "${net}" -eq 6 ]; then
        # vultr specific, needed to work
        sed -ie '/iface ${ETH_INTERFACE} inet6 auto/s/^/#/' ${NETWORK_CONFIG}

        # move current config out of the way first
        cp ${NETWORK_CONFIG} ${NETWORK_CONFIG}.${DATE_STAMP}.bkp

        # create the additional ipv6 interfaces, rc.local because it's more generic
       # for NUM in $(seq 1 ${count}); do

            # check if the interfaces exist
            ip -6 addr | grep -qi "${IPV6_INT_BASE}:${NETWORK_BASE_TAG}::${count}"
            if [ $? -eq 0 ]
            then
              echo "IP for masternode already exists, skipping creation"  
            else
              echo "Creating new IP address for ${CODENAME} masternode nr ${count}"  
              if [ "${NETWORK_CONFIG}" = "/etc/rc.local" ]; then
                # need to put network config in front of "exit 0" in rc.local
                sed -e '$i ip -6 addr add '"${IPV6_INT_BASE}"':'"${NETWORK_BASE_TAG}"'::'"${count}"'/64 dev '"${ETH_INTERFACE}"'\n' -i ${NETWORK_CONFIG}
              else
                # if not using rc.local, append normally
                  echo "ip -6 addr add ${IPV6_INT_BASE}:${NETWORK_BASE_TAG}::${count}/64 dev ${ETH_INTERFACE}" >> ${NETWORK_CONFIG}
              fi
              sleep 2
              ip -6 addr add ${IPV6_INT_BASE}:${NETWORK_BASE_TAG}::${count}/64 dev ${ETH_INTERFACE}  
            fi
      #  done # end forloop
    #fi # end ifneteq6
}

 echo "Preparing network interface, generating ipv6"
prepare_mn_interfaces

WANIP="[${IPV6_INT_BASE}:${NETWORK_BASE_TAG}::${count}]"

echo "New Ipv6 IP generated:  ${WANIP}"

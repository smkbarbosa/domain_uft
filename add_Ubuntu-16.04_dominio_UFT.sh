#!/bin/bash
# Script para adicionar o Ubuntu 16.04 no domínio
# Criado por Samuel Barbosa
# Roteiro base: https://github.com/yugolemom/LinuxActiveDirectory
#
# V. 1.0 -- 27-02-2018

PS3='Escolha uma opção: '
## atribuindo hostname atual para $hostn
host_atual=$(cat /etc/hostname)
options_init=("Renomear máquina" "Inserir no dominío" "Sair")
## Sufixo para indicar que a máquina é linux, já que o padrão de nome é SIGLA_CAMPUS-PATRIMONIO EX (RTA-08423L)
suf='L'
select opt in "${options_init[@]}"
do
    case $opt in
        "Renomear máquina")
            echo "Digite o patrimônio deste computador: "
            read novo_nome
            echo "Alterando nome da máquina e reiniciando. Você deverá executar este script novamente e selecionar a opção 2 após reiniciar"
            sudo sed -i "s/$host_atual/RTA-$novo_nome$suf/g" /etc/hosts
            sudo sed -i "s/$host_atual/RTA-$novo_nome$suf/g" /etc/hostname
            echo "Adicionando DNS padrão"
            sudo sh -c "echo 'nameserver 192.168.192.111\nnameserver 192.168.192.2' > /etc/resolvconf/resolv.conf.d/base"
            read -s -n 1 -p "Press uma tecla para reiniciar"
            sudo reboot
            ;;
        "Inserir no dominío")
            nss="hosts:          files  mdns4_minimal [NOTFOUND=return] dns"
            nss_new="hosts:          files dns mdns4_minimal [NOTFOUND=return]"
            sudo sed -i "s/$nss/$nss_new/g" /etc/nsswitch.conf
            echo "Instalando pacotes necessários"
            sudo apt update && sudo apt install -y realmd sssd sssd-tools samba-common krb5-user packagekit samba-common-bin samba-libs adcli ntp libpam-sss libnss-sss
            echo "Garantindo que o Kerberos será configurado:"
            sudo dpkg-reconfigure krb5-config
            echo "Sincronizando hora com o servidor"
            sudo ntpdate samba-ad.dominio.uft.edu.br
            echo "Criando arquivo realmd"
            sudo touch /etc/realmd.conf
            sudo sh -c "echo '[users]\ndefault-home = /home/%D/%U\ndefault-shell = /bin/bash\n[active-directory]\ndefault-client = sssd\nos-name = Ubuntu Desktop Linux\nos-version = 16.04\n[service]\nautomatic-install = no\n[dominio.uft.edu.br]\nfully-qualified-names = no\nautomatic-id-mapping = yes\nuser-principal = yes\nmanage-system = no' > /etc/realmd.conf"
            echo "Ativando ticket do Kerberos:"
            sudo kinit administrator@DOMINIO.UFT.EDU.BR
            echo "Adicionando computador no dominio"
            sudo realm --verbose join dominio.uft.edu.br -U administrator --computer-ou OU=Computadores,OU=Reitoria,DC=dominio,DC=uft,DC=edu,DC=br
            echo "Adicionando permissão para que qualquer usuário faça login no computador"
            sudo realm permit --all
            sssd_option='use_fully_qualified_names = True'
            sssd_option_new='use_fully_qualified_names = False'
            sudo sed -i "s/$sssd_option/$sssd_option_new/g" /etc/sssd/sssd.conf
            echo "Reiniciando serviço SSSD"
            sudo service sssd restart
            echo 'Adicionando administradores do dominio como admins do ubuntu'                        
            sudo sh -c "echo '%admins_ad ALL=(ALL) ALL' >> /etc/sudoers"
            echo "Configurando criação automática do home do usuário"
            sudo sh -c "echo '## UFT\nsession required pam_mkhomedir.so skel=/etc/skel/ umask=0077' >> /etc/pam.d/common-session"
            echo "Realizando ajustes finais"
            sudo touch /etc/lightdm/lightdm.conf
            sudo sh -c "echo '[SeatDefaults]\nallow-guest=false\ngreeter-hide-users=true\ngreeter-show-manual-login=true' >> /etc/lightdm/lightdm.conf"
            echo "Finalizado....... Reiniciando......"
            read -s -n 1 -p "Press any key to reboot"
            sudo reboot
            ;;

        "Sair")
            break
            ;;
        *) echo "Opção inválida";;
    esac
done
            
            

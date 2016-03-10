#cloud-config

bootcmd:
 - hostname web.${domain_name}.`curl http://169.254.169.254/latest/meta-data/instance-id`
 - echo 127.0.1.1 web.${domain_name}.`curl http://169.254.169.254/latest/meta-data/instance-id` >> /etc/hosts
 - echo web.${domain_name}.`curl http://169.254.169.254/latest/meta-data/instance-id` > /etc/hostname

preserve_hostname: true

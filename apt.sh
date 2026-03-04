#!/bin/bash
cat<< EOF > /etc/apt/sources.list.d/alt.list
# ftp.altlinux.org (ALT Linux, Moscow)
# ALT Platform 10
##rpm [p10] ftp://ftp.altlinux.org/pub/distributions/ALTLinux p10/branch/x86_64 classic
##rpm [p10] ftp://ftp.altlinux.org/pub/distributions/ALTLinux p10/branch/x86_64-i586 classic
##rpm [p10] ftp://ftp.altlinux.org/pub/distributions/ALTLinux p10/branch/noarch classic

#rpm [p10] http://ftp.altlinux.org/pub/distributions/ALTLinux p10/branch/x86_64 classic
#rpm [p10] http://ftp.altlinux.org/pub/distributions/ALTLinux p10/branch/x86_64-i586 classic
#rpm [p10] http://ftp.altlinux.org/pub/distributions/ALTLinux p10/branch/noarch classic

##rpm [p10] rsync://ftp.altlinux.org/ALTLinux p10/branch/x86_64 classic
##rpm [p10] rsync://ftp.altlinux.org/ALTLinux p10/branch/x86_64-i586 classic
##rpm [p10] rsync://ftp.altlinux.org/ALTLinux p10/branch/noarch classic

rpm http://10.0.50.50/sisa p10/x86_64 classic
rpm http://10.0.50.50/sisa p10/noarch classic
EOF

FROM debian:jessie

MAINTAINER MinhNguyen <ndminh9x@gmail.com>

# Install dependency
RUN apt-get update && apt-get install -y --force-yes wget
RUN wget -O - https://files.freeswitch.org/repo/deb/debian/freeswitch_archive_g0.pub | apt-key add -
 
RUN echo "deb http://files.freeswitch.org/repo/deb/freeswitch-1.6/ jessie main" > /etc/apt/sources.list.d/freeswitch.list
RUN apt-get update
RUN apt-get install -y --force-yes freeswitch-video-deps-most

# Configure Fail2ban
RUN apt-get install -y --force-yes fail2ban
ADD conf/fail2ban/freeswitch.conf /etc/fail2ban/filter.d/freeswitch.conf
ADD conf/fail2ban/freeswitch-dos.conf /etc/fail2ban/filter.d/freeswitch-dos.conf
ADD conf/fail2ban/jail.local /etc/fail2ban/jail.local

# Setup configure MySQL with unixODBC
WORKDIR /etc
RUN yes | apt-get install libmyodbc unixodbc-bin
ADD build/odbcinst.ini odbcinst.ini
ADD build/odbc.ini odbc.ini

# Download FreeSWITCH.
WORKDIR /usr/src
ENV GIT_SSL_NO_VERIFY=1
RUN git clone https://freeswitch.org/stash/scm/fs/freeswitch.git -bv1.6 freeswitch

# Bootstrap the build.
WORKDIR freeswitch
RUN git config pull.rebase true
RUN ./bootstrap.sh

# Enable the desired modules.
ADD build/modules.conf /usr/src/freeswitch/modules.conf

# Build FreeSWITCH.
RUN ./configure 
RUN make
RUN make install

# Install Perlmod
WORKDIR libs/esl
RUN make
RUN make perlmod-install 

# Setting FreeSWITCH Sysconfig.
ADD build/freeswitch /etc/init.d/freeswitch
ADD build/freeswitch.service /etc/systemd/system/freeswitch.service
RUN chmod -R 755 /etc/init.d/freeswitch

# Disable the example gateway and the IPv6 SIP profiles
WORKDIR /usr/local/freeswitch/conf
RUN mv directory/default/example.com.xml directory/default/example.com.xml.noload
#RUN mv sip_profiles/internal.xml sip_profiles/internal.xml.noload
#RUN mv sip_profiles/internal-ipv6.xml sip_profiles/internal-ipv6.xml.noload

# Config external profile to accept internet clients sign-in
ADD /conf/sip_profiles/external.xml /sip_profiles/external.xml

# Config dialplan to make call beetwen 2 clients
ADD /conf/dialplan/public.xml dialplan/public.xml
ADD /conf/dialplan/default.xml dialplan/default.xml

# Environment variable
ARG PUBLIC_IP
ARG MYSQL_USERNAME
ARG MYSQL_PASSWORD
ARG SIP_PASS_DEF=nt9user
ENV PUBLIC_IP = ${PUBLIC_IP}
ENV MYSQL_USERNAME = ${MYSQL_USERNAME}
ENV MYSQL_PASSWORD = ${MYSQL_PASSWORD}

# Set public IP address to SIP IP address
ADD conf/vars.xml vars.xml

# Custom auto_config
ADD conf/autoload_configs/modules.conf.xml autoload_configs/modules.conf.xml
ADD conf/autoload_configs/event_socket.conf.xml autoload_configs/event_socket.conf.xml
ADD conf/autoload_configs/xml_curl.conf.xml autoload_configs/xml_curl.conf.xml
ADD conf/autoload_configs/switch.conf.xml autoload_configs/switch.conf.xml
ADD conf/autoload_configs/acl.conf.xml autoload_configs/acl.conf.xml

# Remove build file
RUN rm -rf /usr/src/freeswitch

# Open the container up to the world.
#EXPOSE 5060/tcp 5060/udp 
EXPOSE 5080/tcp 5080/udp
EXPOSE 9090/tcp
EXPOSE 8021/tcp
EXPOSE 50000-51000/udp

CMD /usr/sbin/service freeswitch start

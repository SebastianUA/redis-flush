#!/bin/bash

# CREATED:
# vitaliy.natarov@yahoo.com
#
# Unix/Linux blog:
# http://linux-notes.org
# Vitaliy Natarov
#
# Set some colors for status OK, FAIL and titles
SETCOLOR_SUCCESS="echo -en \\033[1;32m"
SETCOLOR_FAILURE="echo -en \\033[1;31m"
SETCOLOR_NORMAL="echo -en \\033[0;39m"

SETCOLOR_TITLE="echo -en \\033[1;36m" #Fuscia
SETCOLOR_TITLE_GREEN="echo -en \\033[0;32m" #green
SETCOLOR_NUMBERS="echo -en \\033[0;34m" #BLUE

function Operation_status {
     if [ $? -eq 0 ]; then
         $SETCOLOR_SUCCESS;
         echo -n "$(tput hpa $(tput cols))$(tput cub 6)[OK]"
         $SETCOLOR_NORMAL;
             echo;
     else
        $SETCOLOR_FAILURE;
        echo -n "$(tput hpa $(tput cols))$(tput cub 6)[fail]"
        $SETCOLOR_NORMAL;
        echo;
     fi
}

# LOG
FlushCacheReport="/var/log/FlushCacheReport.log"
if [ ! -f "$FlushCacheReport" ]; then
    $SETCOLOR_TITLE
    echo "The flushall-caches.log file NOT FOUND in the folder /var/log";
    $SETCOLOR_NORMAL
    touch $FlushCacheReport
    $SETCOLOR_TITLE
    echo "The $FlushCacheReport file was CREATED";
    $SETCOLOR_NORMAL
else
    $SETCOLOR_TITLE
    echo "The '$FlushCacheReport' file allready exists"
    rm -f $FlushCacheReport
    touch $FlushCacheReport
    $SETCOLOR_NORMAL
fi

# Receiver email for reports
 List_of_emails="vnatarov@gorillagroup.com"

exec > >(tee -a ${FlushCacheReport} )
exec 2> >(tee -a ${FlushCacheReport} >&2)

echo "**************************************************************" >> $FlushCacheReport
echo "HOSTNAME: `hostname`" >> $FlushCacheReport
echo "**************************************************************" >> $FlushCacheReport

if ! type -path "expect" > /dev/null 2>&1; then
             yum install expect -y
             $SETCOLOR_TITLE
             echo "expect has been INSTALLED on this server: `hostname`";
             $SETCOLOR_NORMAL
else
        $SETCOLOR_TITLE
        echo "expect INSTALLED on this server: `hostname`";
        $SETCOLOR_NORMAL
fi

function Flush_Redis_Cache () {
    $SETCOLOR_TITLE_GREEN
    echo "**********************************************";
    echo "********************REDIS*********************";
    echo "**********************************************";
    $SETCOLOR_NORMAL  
    #
    # check redis IP
     CacheRedisIP=$(cat `echo $LocalXML` 2> /dev/null| grep Cache_Backend_Redis -A13 | grep "<server>"| uniq|cut -d ">" -f2 | cut -d "<" -f1|uniq)
      if [ -z "$CacheRedisIP" ]; then
               CacheRedisIP=$(cat `echo $LocalXML` 2> /dev/null| grep Cache_Backend_Redis -A13| grep "<server>"|uniq|cut -d "[" -f3| cut -d "]" -f1|uniq) 
      fi                      
      echo "Cache Redis server/IP: `echo $CacheRedisIP 2> /dev/null`";
      #
      #PORTS
       CacheRedisPorts=$(cat `echo $LocalXML` 2> /dev/null| grep Cache_Backend_Redis -A13  | cut -d '>' -f2| grep port | cut -d '<' -f1|uniq)
       if [ -z "$CacheRedisPorts" ]; then
       			CacheRedisPorts=$(cat `echo $LocalXML 2> /dev/null` |grep Cache_Backend_Redis -A13 | grep port | cut -d "[" -f3| cut -d "]" -f1|uniq| grep -Ev "gzip")
       fi		
       echo "Cache-redis-ports: `echo $CacheRedisPorts 2> /dev/null`";
      # PS 6381 - don't flush
        IgnoreCacheRedisPorts="6381"
      #
      # redis-cli -h 127.0.0.1 -p 6378 flushall   (sessions)
      # redis-cli -h 127.0.0.1 -p 6379 flushall   (cache)
      # redis-cli -h 127.0.0.1 -p 6380 flushall    (full_page_cache)
      #Check_DB
       CacheRedisDB=$(cat `echo $LocalXML` 2> /dev/null| grep Cache_Backend_Redis -A13 | grep database | cut -d ">" -f2 |cut -d "<" -f1|uniq)
       echo "CacheRedisDB = `echo $CacheRedisDB 2> /dev/null`"
      #
      # -n : string is not null.
      # -z : string is null, that is, has zero length
if [ ! -z "$CacheRedisIP" ]; then
    for ICacheRedisIP in `echo $CacheRedisIP|xargs -I{} -n1 echo {}` ; do
            echo "Cache Redis server: `echo $ICacheRedisIP`";
            for ICacheRedisPorts in `echo $CacheRedisPorts|xargs -I{} -n1 echo {}` ; do
                if [ "$ICacheRedisPorts" -ne "$IgnoreCacheRedisPorts" ]; then
                         #
                         if [ -z "$CacheRedisDB" ]; then
                                #
                                if [ -n "`whereis redis-cli| awk '{print $2}'`" ]; then
                                    #    
                                    R_flush=$(redis-cli -h `echo $ICacheRedisIP` -p `echo $ICacheRedisPorts` flushall)
                                    $SETCOLOR_TITLE
                                    echo "redis-cli -h `echo $ICacheRedisIP` -p `echo $ICacheRedisPorts` flushall";
                                    $SETCOLOR_NORMAL
                                 else
                                      echo "PLEASE USE TELNET!";
                                      #
                                      Flush_CacheRediss="flushall";
                                      Close_Expect_with_CacheRediss="quit";
                                      $SETCOLOR_TITLE
                                      echo $ICacheRedisIP '+' $ICacheRedisPorts
                                      $SETCOLOR_NORMAL
                                      expect <<EOF 
                                            spawn telnet $ICacheRedisIP $ICacheRedisPorts
                                            expect "Escape character is '^]'."
                                            send "$Flush_CacheRediss\n"
                                            expect "+OK"
                                            sleep 3
                                            send "$Close_Expect_with_CacheRediss\n"
EOF
                                 fi           
                          else
                                #flush_db
                                $SETCOLOR_TITLE
                                Server_port="SERVER::::> `echo $ICacheRedisIP` PORT::::> `echo $ICacheRedisPorts`";
                                $SETCOLOR_NORMAL
                                echo "`echo $Server_port`";
                                for ICacheRedisDB in `echo $CacheRedisDB|xargs -I{} -n1 echo {}` ; do
                                    echo "Need to flush DB `echo $ICacheRedisDB`";
                                    $SETCOLOR_TITLE
                                    echo "`echo $Server_port` DataBase::::> `echo $ICacheRedisDB`";
                                    $SETCOLOR_NORMAL
                                    # 
                                    CacheRedisDBAuth=$(cat `echo $LocalXML` 2> /dev/null| grep Cache_Backend_Redis -A13 | grep password | cut -d ">" -f2 |cut -d "<" -f1|uniq)
                                    if [ -z "$CacheRedisDBAuth" ]; then
                                            Flush_CacheRedisDB="flushdb";
                                            Close_Expect_with_CacheRedis="quit";
                                            Close_connection="Connection will be CLOSED now!";
                                            #
                                            #`which expect| grep -E expect`<< EOF
                                            expect <<EOF 
                                                spawn telnet $ICacheRedisIP $ICacheRedisPorts
                                                expect "Escape character is '^]'."
                                                send "SELECT $ICacheRedisDB\n"
                                                expect "+OK"
                                                send "$Flush_CacheRedisDB\n"
                                                expect "+OK"
                                                sleep 3
                                                send "$Close_connection\n"
                                                send "$Close_Expect_with_CacheRedis\n"                                             
EOF
                                    else
                                        $SETCOLOR_TITLE
                                        echo "AUTH Authentication required.";
                                        $SETCOLOR_NORMAL
                                        for ICacheRedisDBAuth in `echo $CacheRedisDBAuth|xargs -I{} -n1 echo {}` ; do
                                                Flush_CacheRedisDB="flushdb";
                                                Close_Expect_with_CacheRedis="quit";
                                                Close_connection="Connection will be CLOSED now!";
                                                #
                                                expect <<EOF 
                                                    spawn telnet $ICacheRedisIP $ICacheRedisPorts
                                                    expect "Escape character is '^]'."
                                                    send "AUTH $ICacheRedisDBAuth\n"
                                                    expect "+OK"
                                                    send "SELECT $ICacheRedisDB\n"
                                                    expect "+OK"
                                                    send "$Flush_CacheRedisDB\n"
                                                    expect "+OK"
                                                    sleep 3
                                                    send "$Close_connection\n"
                                                    send "$Close_Expect_with_CacheRedis\n"                                             
EOF
                                        done;
                                    fi    
                                done;     
                          fi         
                else
                     echo "Oops IgnoreCacheRedisPorts is '$IgnoreCacheRedisPorts' EXIT!";
                     break;
                fi
                echo "Flushed redis cache on $ICacheRedisPorts port";
            done;
     done;
    #
else
     #rm -rf
     $SETCOLOR_TITLE
     echo "Local Cache on server `hostname`";
     $SETCOLOR_NORMAL
     `rm -rf echo $Cache_Dir`
     $SETCOLOR_TITLE
     echo "Using LOCAL CACHE with command <rm -rf '$Cache_Dir' has been FLUSHED";
     $SETCOLOR_NORMAL 
fi	 	 
} 

function Flush_Memcached () {
        #MEMCACHED
        $SETCOLOR_TITLE_GREEN
        echo "**********************************************";
        echo "******************MEMCACHED*******************";
        echo "**********************************************";
        $SETCOLOR_NORMAL
        MemcachedServer=$(cat `echo $LocalXML` 2> /dev/null | grep '<memcached>' -A7| grep -E 'host|CDATA|port' | grep -v "ersistent"| grep host| cut -d "[" -f3| cut -d "]" -f1|uniq)
        MemcachedPort=$(cat `echo $LocalXML` 2> /dev/null | grep '<memcached>' -A7| grep -E 'host|CDATA|port' | grep -v "ersistent"| grep port| cut -d "[" -f3| cut -d "]" -f1|uniq)
        
        Close_Expect_with_Memcached="quit"
        Flush_Memcached="flush_all"
  
if [ ! -z "$MemcachedServer" ]; then
        $SETCOLOR_TITLE
        echo "Memcached Server => `echo $MemcachedServer`";
        echo "Memcached Port => `echo $MemcachedPort`";
        $SETCOLOR_NORMAL  
         `which expect | grep -E expect` <<EOF
                spawn telnet $MemcachedServer $MemcachedPort
                expect "Escape character is '^]'."
                send "$Flush_Memcached\n"
                expect "+OK"
                sleep 1
                send "$Close_Expect_with_Memcached\n"
EOF
        $SETCOLOR_TITLE
        echo "memcached has been flushed on server `hostname`";
        $SETCOLOR_NORMAL
else
        $SETCOLOR_TITLE
        echo "Din't find memcached on server `hostname`";
        $SETCOLOR_NORMAL
        break;
fi
}
#
for Iconfig in `ls -al /etc/nginx/conf.d/*.conf | grep "^-"| grep -vE "(default|geo|example)"|awk '{print $9}'|xargs -I{} -n1 echo {}` ; do
    #RootF=$(cat /etc/nginx/conf.d/*.conf 2> /dev/null| grep root|cut -d ";" -f1 | awk '{print $2}'|grep -vE "(SCRIPT_FILENAME|fastcgi_param|fastcgi_script_name|-f)"|uniq| grep -v "blog")
    #
    RootF=$(cat $Iconfig 2> /dev/null| grep root|cut -d ";" -f1 | awk '{print $2}'|grep -vE "(SCRIPT_FILENAME|fastcgi_param|fastcgi_script_name|log|-f)"|uniq| grep -v "blog")    
    #if [ -z "$RootF" ]; then
    #    $SETCOLOR_TITLE
    #    echo "No such file or directory (default for nginx)";
    #    RootF=$(cat /etc/httpd/conf.d/vhosts/*.conf 2> /dev/null | grep DocumentRoot| cut -d '"' -f2|uniq| grep -v "blog")
    #    $SETCOLOR_NORMAL
    #    #cat: /etc/nginx/conf.d/*.conf: No such file or directory 
    #fi
    # 
    # need to add a `echo $RootF >> RootF.log` 
    #
    for Roots in `echo $RootF|xargs -I{} -n1 echo {}` ; do
        #
        #Domain_Name=$()
        if [ ! -z "$Roots" ]; then
          #
          echo "-----------------------------------------------------------";
          echo "--------------------------SITE-----------------------------";
          echo "-----------------------------------------------------------";
          if [[ "$Roots" == */ ]]; then 
              $SETCOLOR_TITLE
              echo "Root-folder: `echo $Roots| grep -vE "DocumentRoot" 2> /dev/null`";
              $SETCOLOR_NORMAL
              #   
              XML="app/etc/local.xml";
              LocalXML="$Roots$XML"
              $SETCOLOR_TITLE
              echo "Root-XML with '/' : `echo $LocalXML| grep -vE "DocumentRoot"`";
              $SETCOLOR_NORMAL
              #  
              Var_Cache="var/cache/*";
              Cache_Dir="$Roots$Var_Cache"
              #Run Flush_Redis_Cache function
              Flush_Redis_Cache;
              #Run Flush_Memcached function
              Flush_Memcached;
          else
                LocalXML="$Roots/app/etc/local.xml"
                $SETCOLOR_TITLE
                echo "Root-folder: `echo $Roots| grep -vE "DocumentRoot" 2> /dev/null`";
                $SETCOLOR_NORMAL
                #
                $SETCOLOR_TITLE
                echo "Root-XML: `echo $LocalXML`";
                $SETCOLOR_NORMAL
                Cache_Dir="$Roots/var/cache/*"
                #Run Flush_Redis_Cache function
                Flush_Redis_Cache;
                #Run Flush_Memcached function
                Flush_Memcached;
          fi 
        fi   
  done;
done;
#
# Send report to email list
if [ -z "`rpm -qa | grep mailx`" ]; then
	yum install mailx -y
	$SETCOLOR_TITLE
	echo "service of mail has been installed on `hostname`";
	$SETCOLOR_NORMAL
else
	mail -s " HOSTNAME is `hostname`" $List_of_emails < $FlushCacheReport
fi	
rm -f $FlushCacheReport
#
echo "LOG_FILE= $FlushCacheReport has been sent";
#
echo "|---------------------------------------------------|";
echo "|--------------------FINISHED-----------------------|";
echo "|---------------------------------------------------|";
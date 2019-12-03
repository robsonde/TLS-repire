#!/bin/sh
######################################
#
# SSL testing tool.
#
# Derek Robson  03/10/2009
# used to test if an SSL cert is due to expire.
#  SSL_test.sh <server name>
#
#
######################################
#
# CONFIG SETTINGS
#
# Who to email if SSL cert is due 
EMAIL="bob@mycomany.com"

# how manys days before cert expires do we want to be alerted?
DAYS_WARNING=45

# Also email the cert owner?
MAIL_OWNER=NO

# if no SSL is running on server should we exit with what error code? 
NO_SSL=0;



date2unix() {
        # unix date from Gregorian calendar date
        # Since leap years add aday at the end of February, 
        # calculations are done from 1 March 0000 (a fictional year)
        d2j_tmpmonth=`expr 12 \* ${3} + ${1} - 3` 
        
        # If it is not yet March, the year is changed to the previous year
        d2j_tmpyear=`expr ${d2j_tmpmonth} / 12`
        
        # The number of days from 1 March 0000 is calculated
        # and the number of days from 1 Jan. 4713BC is added 
        d2j_tmpdays=`expr 734 \* ${d2j_tmpmonth} + 15`
 
        # this gives us the julian day number.
        d2j_JULIAN=`expr \( ${d2j_tmpdays} / 24 \) - \( 2 \* ${d2j_tmpyear} \) + \( ${d2j_tmpyear} / 4 \) - \( ${d2j_tmpyear} / 100 \) + \( ${d2j_tmpyear} / 400 \) + $2 + 1721119`

        # this convert julian day number to classic unix time number
        UNIX_date=`expr \( \( \( \( \( ${d2j_JULIAN} - 2440587 \) \* 24 \) + 12 + ${4} \) \* 60 \) + ${5} \) \* 60 `

        echo $UNIX_date 
}





GET_EXPIR_DATE() {
        #
        # get the SSL expire date from the web server.
        # returns a line like this "Not After : Nov 12 12:00:00 2011 GMT"
        # can be used on other port numbers by use of $2, assumes 443 if no $2 set.

        # what host are we checking?
        HOST=$1

        # What port number?
        PORT=443 
        
        # connect to server and get full SSL cert.
        FULL_SSL_BLOB=`echo "HEAD / HTTP/1.0\n Host: $1:443\n\n EOT\n" | openssl s_client -connect $1:443 2>&1`
        if [ $? -eq 0 ];then
        # cut out just the encoded SSL cert
        SSL_CERT=`echo "$FULL_SSL_BLOB" | sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' `

        # decode the SSL cert recover the "Not After" date      
        EXPIR_DATE=`echo "$SSL_CERT" | openssl x509 -noout -text -certopt no_signame 2>&1 | grep "Not After"  `
        
        echo $EXPIR_DATE
        else 
        echo "ERROR"
        fi 
}



GET_EXPIR_DATE_BUG() {
        #
        # get the SSL expire date from the web server and use works around an  SSL bug with some certs.
        # returns a line like this "Not After : Nov 12 12:00:00 2011 GMT"
        # can be used on other port numbers by use of $2, assumes 443 if no $2 set.

        # what host are we checking?
        HOST=$1

        # What port number?
        PORT=443 
 
        # connect to server and get full SSL cert.
        FULL_SSL_BLOB=`echo "HEAD / HTTP/1.0\n Host: $1:443\n\n EOT\n" | openssl s_client -prexit -connect $1:443 2>&1`
        if [ $? -eq 0 ];then
        # cut out just the encoded SSL cert
        SSL_CERT=`echo "$FULL_SSL_BLOB" | sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' `

        # decode the SSL cert recover the "Not After" date
        EXPIR_DATE=`echo "$SSL_CERT" | openssl x509 -noout -text -certopt no_signame 2>&1 | grep "Not After"  `
        
        echo $EXPIR_DATE
        else
        echo "ERROR"
        fi
}




GET_CERT_OWNER() {
        #
        # get the SSL owners email address from the web server.
        # returns an emial address
        # can be used on other port numbers by use of $2, assumes 443 if no $2 set.

        # what host are we checking?
        HOST=$1

        # What port number?
        PORT=443

        # connect to server and get full SSL cert.
        FULL_SSL_BLOB=`echo "HEAD / HTTP/1.0\n Host: $1:443\n\n EOT\n" | openssl s_client -prexit -connect $1:443 2>&1`

        # cut out just the encoded SSL cert
        SSL_CERT=`echo "$FULL_SSL_BLOB" | sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' `

        # decode the SSL cert recover the "Not After" date
        SSL_OWNER=`echo "$SSL_CERT" | openssl x509 -noout -text -certopt no_signame | grep "email" | sed -e 's/email://g'  `

        echo $SSL_OWNER
}




GET_MONTH() 
{
        # convert month name to number
    case ${1} in
        Jan) echo 1 ;;
        Feb) echo 2 ;;
        Mar) echo 3 ;;
        Apr) echo 4 ;;
        May) echo 5 ;;
        Jun) echo 6 ;;
        Jul) echo 7 ;;
        Aug) echo 8 ;;
        Sep) echo 9 ;;
        Oct) echo 10 ;;
        Nov) echo 11 ;;
        Dec) echo 12 ;;
          *) echo  0 ;;
    esac
}



#################### MAIN ###########################


         # setup with todays date/time
         NOW_YEAR=`date "+%Y"`
         NOW_MONTH=`date "+%m"`
         NOW_DAY=`date "+%d"`
         NOW_HOUR=`date "+%H"`
         NOW_MINUTE=`date "+%M"`

         # get the expire date of the SSL cert from server.
         BOB=`GET_EXPIR_DATE $1 $2`
         if [ "$BOB" = "" ];then
         # assume we need to use the SSL bug switch 
         BOB=`GET_EXPIR_DATE_BUG $1 $2`
         fi

         if [ "$BOB" = "ERROR" ];then
         exit $NO_SSL
         else         
         # take date from SSL cert and cut down to year, month, day, hour and minute
         SSL_YEAR=`echo $BOB | cut -f 7 -d " "`
         SSL_Month=`echo $BOB | cut -f 4 -d " "`
         # conver month from name to number         
         SSL_MONTH=`GET_MONTH $SSL_Month`
         SSL_DAY=`echo $BOB | cut -f 5 -d " "`
         SSL_HOUR=`echo $BOB | cut -f 6 -d " "| cut -f 1 -d ":"`
         SSL_MINUTE=`echo $BOB | cut -f 6 -d " "| cut -f 2 -d ":"`

         # convert both todays date and SSL cert dat to unix time.
         SSL_DATE=`date2unix $SSL_MONTH $SSL_DAY $SSL_YEAR $SSL_HOUR $SSL_MINUTE`
         NOW_DATE=`date2unix $NOW_MONTH $NOW_DAY $NOW_YEAR $NOW_HOUR $NOW_MINUTE`

         #calculate how many day to go until cert expires.
         DATE_DIFFRANCE=`expr $SSL_DATE - $NOW_DATE`
         DAY_DIFFRANCE=`expr $DATE_DIFFRANCE / 86400`

         # take action if needed.
         if [ $DAY_DIFFRANCE -lt $DAYS_WARNING ]; then

         OWNER=`GET_CERT_OWNER $1 $2`

         MESSG="The SSL certificate for $1 on port $2 will expire on $SSL_DAY/$SSL_MONTH/$SSL_YEAR\n\n"

         echo $MESSG | mailx -s "SSL cert due to expire" $EMAIL 

         if [ "$MAIL_OWNER" = "YES" ] ;then
         echo $MESSG | mailx -s "SSL cert due to expire" $OWNER
         fi

         else

         exit 0

         fi

         fi

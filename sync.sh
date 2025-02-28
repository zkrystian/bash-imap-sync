#!/bin/bash

SERVERNAME=$HOSTNAME
SCRIPT_NAME="$SERVERNAME - IMAP TO IMAP"
MAIL=/bin/mail
MAIL_RECIPIENT="admin@boost.pl"
LOCK_FILE="/tmp/$SERVERNAME.imapsync.lockfile"
LOGFILE="imapsync_log.txt"
ERROR_LOGFILE="login.err"

# Source & destination hosts
HOST1=old.server.com
DOMAIN1=mydomain.com
HOST2=new.server.com
DOMAIN2=mydomain.com

# progress bar function xD
progress_bar() {
    local progress=$1
    local total=$2
    local user=$3
    local status=$4
    local bar_length=50
    local filled_length=$((progress * bar_length / total))
    local empty_length=$((bar_length - filled_length))
    local percent=$((progress * 100 / total))
    printf "\r[%-${bar_length}s] %d%% (%d/%d) - %s: %s" \
        "$(printf '#%.0s' $(seq 1 $filled_length))$(printf ' %.0s' $(seq 1 $empty_length))" \
        $percent $progress $total "$user" "$status"
}

####################################################
###### Don't touch below this. Bad things will happen... lol
####################################################

if [ ! -e $LOCK_FILE ]; then
    touch $LOCK_FILE

    # Start logs
    TIME_NOW=$(date +"%Y-%m-%d %T")
    echo "" >> $LOGFILE
    echo "------------------------------------" >> $LOGFILE
    echo "IMAPSync started - $TIME_NOW" >> $LOGFILE
    echo "" >> $LOGFILE
    echo "IMAPSync Errors Log - $TIME_NOW" > $ERROR_LOGFILE

    # Let's see how many accounts we have
    total_users=$(wc -l < accounts.txt)
    current_user=0

    # Main sync loop
    while IFS=';' read -r u1 p1; do
        USER_NAME1="$u1@$DOMAIN1"
        USER_NAME2="$u1@$DOMAIN2"
        current_user=$((current_user + 1))

        # Progress bar for current account
        progress_bar $current_user $total_users "$USER_NAME1" "Starting"

        # Let's get things done... Magic is happening here
        imapsync --addheader --no-modulesversion --nosyncacls --nosslcheck --syncinternaldates \
            --host1 $HOST1 --user1 "$USER_NAME1" --password1 "$p1" \
            --host2 $HOST2 --user2 "$USER_NAME2" --password2 "$p1" --noauthmd5 >> $LOGFILE 2>> $ERROR_LOGFILE

        STATUS=$?
        if [ $STATUS -ne 0 ]; then
            echo "Error syncing $USER_NAME1. Check $ERROR_LOGFILE for details." >> $LOGFILE
            echo "$USER_NAME1; Error Code: $STATUS" >> $ERROR_LOGFILE
            # Update progress bar bitch!
            progress_bar $current_user $total_users "$USER_NAME1" "Error"
        else
            echo "Finished syncing $USER_NAME1 successfully." >> $LOGFILE
            # Update progress bar
            progress_bar $current_user $total_users "$USER_NAME1" "Success"
        fi
        echo "" >> $LOGFILE
    done < accounts.txt

    # Let's finish
    TIME_NOW=$(date +"%Y-%m-%d %T")
    echo "" >> $LOGFILE
    echo "IMAPSync Finished - $TIME_NOW" >> $LOGFILE
    echo "------------------------------------" >> $LOGFILE
    echo -e "\nSync completed!"

    rm -f $LOCK_FILE

else
    TIME_NOW=$(date +"%Y-%m-%d %T")
    echo "$SCRIPT_NAME at $TIME_NOW is still running" | $MAIL -s "[$SCRIPT_NAME] !!WARNING!! still running" $MAIL_RECIPIENT
    echo "$SCRIPT_NAME at $TIME_NOW is still running"
fi

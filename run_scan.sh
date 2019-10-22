#!/bin/bash

##########################################

# What: Website Monitor
# Who: Jan Macario
# When: 20190425
# How: This script will read URLs from a text file and then use curl to request the URL and get the response code.
# If the response code is anything other than 200, it will generate a notification email.
##########################################

# initialize
base_path=/home/ubuntu/website_monitor
url_file=/home/ubuntu/website_monitor/urls.txt
notification_email=janmacario@gmail.com
timestamp=$(date "+%Y%m%d %H%M")
scan_date=$(date "+%Y%m%d")
scan_time=$(date "+%H%M")
scan_date_formatted=$(date "+%m/%d/%Y")
scan_time_formatted=$(date "+%H:%M")
log_header="scan_mode,scan_date,scan_time,base_url,scanned_url,response_code"

# if we don't already have log files for this date, create them
# csv
if [ ! -f "$base_path/logs/log-$scan_date.csv" ]; then echo "$log_header" > $base_path/logs/log-$scan_date.csv; fi
#html
if [ ! -f "$base_path/logs/log-$scan_date.html" ]; then touch $base_path/logs/log-$scan_date.html; fi


# are we running as cron? look for this_is_cron variable set in chrontab
if [ -n "$THIS_IS_CRON" ]; then scan_mode="CRON"; else scan_mode="TERMINAL"; fi

# clear screen
if [ "$scan_mode" == "TERMINAL" ]; then clear; fi

# clear status file
> $base_path/status.html


# output intro info

echo "Running Website Scan"
echo "Mode: $scan_mode"
echo "Scan Time: $scan_date $scan_time"
echo "Reading URLs from: $url_file"
echo "Notification email: $notification_email"
echo "Starting scan..."

# loop through list of URLs to scan
# the list of files is produced by passing the urls text file through sed to delete any comment lines - lines beginning with # - as well as any blank lines (spaces or tabs). Then sed is used with the date command add a cache buster query string parameter to the end of each URL, then fix parameter delimiters ? and &
cat $url_file | sed '/^[\t #]*#/d' | sed '/^[ \t]*$/d' | sed "s/$/\&cache-buster=$scan_date-$scan_time/" | sed 's/\?/\&/g' | sed 's/\&/\?/' | while read URL; do

  # set simple URL
  simple_url=$(sed "s/\(.*\)[\?\&]cache-buster=.*$/\1/" <<< "$URL")

  # define short url
  # start with our working url $URL. Remove the leading http:// or https://. Remove the cache-buster parameter and value and it's preceding question mark or ampersand. Replace all periods with dashes. Replace one or more consecutive of any of slashes, question marks, ampersands, equals signs with dashes. Remove a trailing dash, if it exists.
  url_label=$(echo "$URL" | sed "s/https\?:\/\///" | sed 's/[\?\&]cache-buster=[0-9]\{8\}-[0-9]\{4\}//' | sed 's/\./\-/g' | sed 's/[\/\?\&\=]\+/\-/g' | sed 's/\-$//' )

  # output scan info
  #echo "URL: $simple_url"
  #echo "Time-stamped URL: $URL"
  #echo "URL Label: $url_label"

  # if log files for this URL and date don't exist, create them
  # csv
  if [ ! -f "$base_path/logs/log-$url_label-$scan_date.csv" ]; then echo "$log_header" > $base_path/logs/log-$url_label-$scan_date.csv; fi
  # html
  if [ ! -f "$base_path/logs/log-$url_label-$scan_date.html" ]; then touch $base_path/logs/log-$url_label-$scan_date.html; fi

  # get response code
  response_code=$(curl -Is --connect-timeout 30 $URL | head -n 1 | awk '{print $2}')
  # replace above with:
  #response_code=$(curl -Is --connect-timeout 30 -o /dev/null -w "%{http_code}" $URL)

  # if response code is blank, set response code
  if [ "$response_code" == "" ]; then response_code="NO RESPONSE"; fi

  # output response code
  #echo "Response Code: $response_code"

  # append to CSV log
  echo "$scan_mode,$scan_date,$scan_time,$simple_url,$URL,$response_code" >> $base_path/logs/log-$scan_date.csv

  # append to CSV log for individual URL
  echo "$scan_mode,$scan_date,$scan_time,$simple_url,$URL,$response_code" >> $base_path/logs/log-$url_label-$scan_date.csv

  if [ "$response_code" = 200 ]; then
    # display output
    if [ "$scan_mode" == "TERMINAL" ]; then tput setaf 2; fi
    echo "$simple_url"
    if [ "$scan_mode" == "TERMINAL" ]; then tput sgr0; fi
    # append to HTML log
    echo "<tr><td>$scan_date</td><td>$scan_time</td><td><a href='$simple_url' target='_blank'>$simple_url</a> <a href='view_log.php?date=$scan_date&url=$url_label'><img src='images/icon-magnifying-glass.png' class='icon-small' alt='See log for this URL' /></a></td><td>$response_code</td><td>OK</td></tr>" >> $base_path/logs/log-$scan_date.html
    # append to HTML log for individual URL
    echo "<tr><td><a href='?date=$scan_date'>$scan_date</a></td><td>$scan_time</td><td><a href='$simple_url' target='_blank'>$simple_url</a></td><td>$response_code</td><td>OK</td></tr>" >> $base_path/logs/log-$url_label-$scan_date.html
    # append to status output
    echo "<div class='status_update status_good'><div class='url'><a href='$simple_url' target='_blank'>$simple_url</a></div><div class='last-check'><div class='time'>$scan_time_formatted</div><div class='date'><a href='view_log.php?date=$scan_date&url=$url_label'>$scan_date_formatted</a></div></div><div class='response'>$response_code</div><div class='logs'><a href='view_log.php?url=$url_label&date=$scan_date'>View logs</a></div></div>" >> $base_path/status.html
  else
    # display output
    if [ "$scan_mode" == "TERMINAL" ]; then tput setaf 1; fi
    echo "$simple_url: $response_code"
    if [ "$scan_mode" == "TERMINAL" ]; then tput sgr0; fi
    # append to HTML log
    echo "<tr class='alert'><td>$scan_date</td><td>$scan_time</td><td><a href='$simple_url' target='_blank'>$simple_url</a> <a href='view_log.php?date=$scan_date&url=$url_label'><img src='images/icon-magnifying-glass.png' class='icon-small' alt='See log for this URL' /></a></td><td>$response_code</td><td>ERROR</td></tr>" >> $base_path/logs/log-$scan_date.html
    # append to HTML log for individual URL
    echo "<tr class='alert'><td><a href='?date=$scan_date'>$scan_date</a></td><td>$scan_time</td><td><a href='$simple_url' target='_blank'>$simple_url</a></td><td>$response_code</td><td>ERROR</td></tr>" >> $base_path/logs/log-$url_label-$scan_date.html
    # append to status output
    echo "<div class='status_update status_bad'><div class='url'><a href='$simple_url' target='_blank'>$simple_url</a></div><div class='last-check'><div class='time'>$scan_time_formatted</div><div class='date'><a href='view_log.php?date=$scan_date&url=$url_label'>$scan_date_formatted</a></div></div><div class='response'>$response_code</div><div class='logs'><a href='view_log.php?url=$url_label&date=$scan_date'>View logs</a></div></div>" >> $base_path/status.html
    # send notification email
    /usr/sbin/sendmail $notification_email << EOF
From: Website Monitor <website_monitor@ec2-34-204-50-220.compute-1.amazonaws.com>
Subject: Website Alert: $timestamp: $simple_url: $response_code

$simple_url: $response_code
EOF
  fi

done



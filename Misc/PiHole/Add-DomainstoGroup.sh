#!/bin/bash
# Adds all whitelist exact to all groups


# define path to pihole's databases and temporary database
GRAVITY="/etc/pihole/gravity.db"

#define and initialize variables
declare -a domain_ids
declare -a group_id

groupName='Microsoft'
domainComment='MSOnline'

group_id=(`sqlite3 $GRAVITY "select id from 'group' where name=$groupName"`)
domain_ids=(`sqlite3 $GRAVITY "select id from domainlist where comment=$domainComment"`)


for domain_id in "${domain_ids[@]}"; do
        sqlite3 $GRAVITY "insert or replace into domainlist_by_group(domainlist_id, group_id) values ($domain_id, $group_id);"
        sqlite3 $GRAVITY "DELETE FROM domainlist_by_group WHERE domainlist_id = $domain_id AND group_id = 0;"
done
#!/usr/bin/env zsh
posts_path='source/_posts';
today_date=$(date +%Y-%m-%d)

typeset title;
vared -p 'Post title: ' title;

filename=$(echo $title | tr -dc '[:alnum:] ' | tr '[:upper:] ' '[:lower:]-');
filepath="$posts_path/$today_date-$filename.markdown";

echo "Writing to file $filepath"

vim -c "insert
---
layout: post
title:  "$title"
---" $filepath
